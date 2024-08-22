# frozen_string_literal: true

# lib/tasks/video_processing.rake

namespace :stream do
  desc 'Process video streams for each station'
  task listen: :environment do
    require 'open3'

    # Create an array to keep track of threads
    threads = []

    # Iterate through each Station record
    Station.find_each do |station|
      threads << Thread.new do
        begin
          puts "Processing station #{station.name} (ID: #{station.id})"
          # Define the base target directory
          base_directory = "public/videos/#{station.directory}/temp/"

          # Ensure the directory exists
          FileUtils.mkdir_p(base_directory)

          # Construct the ffmpeg command with station's stream_url and target directory
          command = "ffmpeg -i '#{station.stream_url}' -f segment -segment_time 60 -reset_timestamps 1 -strftime 1 '#{base_directory}/%Y-%m-%dT%H_%M_%S.mp4'"

          # Execute the command
          stdout, stderr, status = Open3.capture3(command)

          # Log the output and errors
          Rails.logger.info("Processing station #{station.id}: #{stdout}")
          Rails.logger.error("Error processing station #{station.id}: #{stderr}") unless status.success?
        rescue => e
          Rails.logger.error("Thread error for station #{station.id}: #{e.message}")
        end
      end
    end

    # Wait for all threads to finish
    threads.each(&:join)
  end
end
