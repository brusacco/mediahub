# frozen_string_literal: true

namespace :stream do
  desc 'Procesa transmisiones de video en vivo para cada estación'
  task listen: :environment do
    require 'open3'

    threads = []

    # Manejo de señales para una salida limpia
    %w[INT TERM HUP QUIT].each do |signal|
      Signal.trap(signal) do
        puts "\nSeñal #{signal} recibida. Desconectando todas las estaciones."
        Station.update_all(stream_status: :disconnected)
        threads.each(&:kill) # Termina los hilos
        exit 1
      end
    end

    # Procesa cada estación activa
    Station.active.find_each do |station|
      threads << Thread.new do
        Thread.current[:station_id] = station.id # Para contexto en logs
        max_retries = 5
        retry_count = 0

        loop do
          begin
            Rails.logger.info("Conectando a estación #{station.name} (ID: #{station.id})")
            base_directory = "public/videos/#{station.directory}/temp/"
            FileUtils.mkdir_p(base_directory)

            # Verifica permisos de escritura
            unless File.writable?(base_directory)
              Rails.logger.error("Directorio #{base_directory} no escribible para estación #{station.id}")
              break
            end

            station.update(stream_status: :connected)

            # Configuraciones de ffmpeg (pueden estar en el modelo Station)
            scale = station.respond_to?(:scale) ? station.scale : '1024:-1'
            segment_time = station.respond_to?(:segment_time) ? station.segment_time : 60
            command = "ffmpeg -i '#{station.stream_url}' -vf scale=#{scale} -f segment -segment_time #{segment_time} -reset_timestamps 1 -strftime 1 -preset veryfast '#{base_directory}%Y-%m-%dT%H_%M_%S.mp4'"

            stdout, stderr, status = Open3.capture3(command)
            Rails.logger.info("Estación #{station.id} ffmpeg: #{stderr}")

            unless status.success?
              Rails.logger.warn("Estación #{station.id} ffmpeg falló: #{stderr}")
              station.update(stream_status: :disconnected)
              retry_count += 1
              if retry_count >= max_retries
                Rails.logger.error("Estación #{station.id} alcanzó el máximo de reintentos (#{max_retries}).")
                break
              end
              sleep(2**retry_count) # Backoff exponencial: 2, 4, 8, 16, 32 segundos
              next
            end

            retry_count = 0 # Resetea reintentos tras éxito

            # Actualiza la URL del stream si es necesario
            if station.stream_source.present?
              begin
                Rake::Task['stream:update_stream_url'].reenable
                Rake::Task['stream:update_stream_url'].invoke(station.id)
                station.reload
              rescue StandardError => e
                Rails.logger.error("Error al actualizar URL de estación #{station.id}: #{e.message}")
              end
            end

          rescue StandardError => e
            Rails.logger.error("Error en estación #{station.id}: #{e.message}")
            station.update(stream_status: :disconnected)
            retry_count += 1
            break if retry_count >= max_retries
            sleep(2**retry_count)
          end
        end
      end
    end

    threads.each(&:join)
  end
end