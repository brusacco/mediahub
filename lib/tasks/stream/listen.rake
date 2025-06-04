# frozen_string_literal: true

namespace :stream do
  desc 'Process video streams for each station'
  task listen: :environment do
    require 'open3'

    threads = []

    # Configuración de señales para terminar la ejecución de forma controlada.
    %w[INT TERM HUP QUIT].each do |signal|
      Signal.trap(signal) do
        Rails.logger.info("#{signal} signal received. Setting stream_status to :disconnected for all stations.")
        Station.update_all(stream_status: :disconnected) # rubocop:disable Rails/SkipsModelValidations
        exit 1
      end
    end

    # Itera sobre cada estación activa
    Station.active.find_each do |station|
      threads << Thread.new(station.id) do |station_id|
        begin
          loop do
            ActiveRecord::Base.connection_pool.with_connection do
              station = Station.find(station_id)
              Rails.logger.info("Connecting to station #{station.name} (ID: #{station.id})")
              base_directory = "public/videos/#{station.directory}/temp/"
              FileUtils.mkdir_p(base_directory)
              station.update(stream_status: :connected)

              # Construir el comando ffmpeg
              command = "ffmpeg -i '#{station.stream_url}' -vf scale=1024:-1 -f segment -segment_time 60 -reset_timestamps 1 -strftime 1 -preset veryfast '#{base_directory}%Y-%m-%dT%H_%M_%S.mp4'"

              _stdout, stderr, _status = Open3.capture3(command)
              Rails.logger.error("FFmpeg error for station #{station.id}: #{stderr}") unless stderr.blank?

              station.update(stream_status: :disconnected)
              Rails.logger.warn("Station #{station.name} disconnected, retrying in 5 seconds...")
              sleep 5

              next if station.stream_source.blank?

              # Invoca la tarea para actualizar la URL del stream
              Rake::Task['stream:update_stream_url'].reenable
              Rake::Task['stream:update_stream_url'].invoke(station.id)
              station.reload
            end
          end
        rescue => e
          Rails.logger.error("Thread error for station #{station_id}: #{e.message}")
          ActiveRecord::Base.connection_pool.with_connection do
            if (st = Station.find_by(id: station_id))
              st.update(stream_status: :disconnected)
            end
          end
        end
      end
    end

    threads.each(&:join)
  end
end