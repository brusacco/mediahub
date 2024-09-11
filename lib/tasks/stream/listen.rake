# frozen_string_literal: true

# lib/tasks/video_processing.rake

namespace :stream do
  desc 'Process video streams for each station'
  task listen: :environment do
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
    Station.where(stream_status: :disconnected).find_each do |station|
      threads << Thread.new do
        begin
          puts "Processing station #{station.name} (ID: #{station.id})"
          # Define the base target directory
          base_directory = "public/videos/#{station.directory}/temp/"

          # Ensure the directory exists
          FileUtils.mkdir_p(base_directory)

          # Update station status to connected while processing
          station.update(stream_status: :connected)

          max_retries = 5
          retries = 0

          begin
            # Construct the ffmpeg command with station's stream_url and target directory
            command = "ffmpeg -i '#{station.stream_url}' -f segment -segment_time 60 -reset_timestamps 1 -strftime 1 '#{base_directory}/%Y-%m-%dT%H_%M_%S.mp4'"
          rescue => e
            if retries < max_retries
              puts "Failed to connect to #{station.name}. Retrying..."
              retries += 1
              sleep(10)
              retry
            else
              puts "Failed to connect after #{max_retries} retries"
            end
          end

          # Execute the command
          stdout, stderr, status = Open3.capture3(command)

          # If ffmpeg fails or ends this station is disconnected
          station.update(stream_status: :disconnected)

          # Log the output and errors
          Rails.logger.info("Processing station #{station.id}: #{stdout}")
          Rails.logger.error("Error processing station #{station.id}: #{stderr}") unless status.success?
        rescue => e
          Rails.logger.error("Thread error for station #{station.id}: #{e.message}")
          station.update(status: :disconnected)
        end
      end
    end

    # Wait for all threads to finish
    threads.each(&:join)
  end
end
