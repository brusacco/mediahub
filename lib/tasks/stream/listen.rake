# frozen_string_literal: true

# lib/tasks/video_processing.rake

namespace :stream do # rubocop:disable Metrics/BlockLength
  desc 'Process video streams for each station'
  task listen: :environment do # rubocop:disable Metrics/BlockLength
    require 'open3'

    # Create an array to keep track of threads
    threads = []

    # Set up signal handling for Ctrl+C (SIGINT)
    # Handle various termination signals
    %w[INT TERM HUP QUIT].each do |signal|
      Signal.trap(signal) do
        puts "\n#{signal} signal received. Setting stream_status to :disconnected for all stations."
        Station.update_all(stream_status: :disconnected) # rubocop:disable Rails/SkipsModelValidations
        exit 1
      end
    end

    # Iterate through each Station record
    Station.active.find_each do |station|
      threads << Thread.new do
        begin
          loop do
            puts "Connecting to station #{station.name} (ID: #{station.id})"
            # Define the base target directory
            base_directory = "public/videos/#{station.directory}/temp/"

            # Ensure the directory exists
            FileUtils.mkdir_p(base_directory)

            # Update station status to connected while processing
            station.update(stream_status: :connected)

            # Construct the ffmpeg command with station's stream_url and target directory
            # command = "ffmpeg -i '#{station.stream_url}' -vf scale=800x600 -f segment -segment_time 60 -reset_timestamps 1 -strftime 1 -preset veryfast '#{base_directory}/%Y-%m-%dT%H_%M_%S.mp4'"
            command = "ffmpeg -i '#{station.stream_url}' -vf scale=1024:-1 -f segment -segment_time 60 -reset_timestamps 1 -strftime 1 -preset veryfast '#{base_directory}%Y-%m-%dT%H_%M_%S.mp4'"

            # Execute the command
            _stdout, stderr, _status = Open3.capture3(command)
            puts stderr

            # If ffmpeg fails or ends this station is disconnected
            station.update(stream_status: :disconnected)
            puts "Station #{station.name} disconnected, retrying in 5 seconds..."
            sleep 5

            next if station.stream_source.blank?

            # Update stream URL by invoking the stream:update_stream_url task
            Rake::Task['stream:update_stream_url'].reenable
            Rake::Task['stream:update_stream_url'].invoke(station.id)

            # Reload the station to get the updated stream_url
            station.reload
          end
        rescue => e
          Rails.logger.error("Thread error for station #{station.id}: #{e.message}")
          station.update(stream_status: :disconnected)
        end
      end
    end

    # Wait for all threads to finish
    threads.each(&:join)
  end
end
