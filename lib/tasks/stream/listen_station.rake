# frozen_string_literal: true

require 'open3'

namespace :stream do
  desc 'Listen to a single station stream'
  task :listen_station, [:station_id] => :environment do |_t, args|
    station_id = args[:station_id]&.to_i

    unless station_id
      puts 'Error: station_id is required'
      puts 'Usage: rake stream:listen_station[STATION_ID]'
      exit 1
    end

    station = Station.find_by(id: station_id)

    unless station
      puts "Error: Station with ID #{station_id} not found"
      exit 1
    end

    unless station.active?
      puts "Station #{station.name} (ID: #{station.id}) is not active, exiting"
      exit 0
    end

    # Set up signal handling for graceful shutdown
    shutdown = false
    %w[INT TERM HUP QUIT].each do |signal|
      Signal.trap(signal) do
        puts "\n#{signal} signal received for station #{station.name} (ID: #{station.id})"
        shutdown = true
        station.update(stream_status: :disconnected)
        exit 0
      end
    end

    retry_count = 0
    max_retries = 10
    base_retry_delay = 5 # seconds

    loop do
      break if shutdown

      begin
        puts "[#{Time.current}] Connecting to station #{station.name} (ID: #{station.id})"
        
        # Reload station to get latest stream_url
        station.reload
        
        unless station.stream_url.present?
          Rails.logger.error("Station #{station.id} has no stream_url")
          station.update(stream_status: :disconnected)
          sleep base_retry_delay
          retry_count += 1
          next
        end

        # Define the base target directory
        base_directory = Rails.root.join('public', 'videos', station.directory, 'temp')
        FileUtils.mkdir_p(base_directory)

        # Update station status to connected
        station.update(stream_status: :connected, last_heartbeat_at: Time.current)

        # Construct the ffmpeg command optimized for audio quality (critical for transcription)
        output_pattern = base_directory.join('%Y-%m-%dT%H_%M_%S.mp4').to_s
        command = [
          'ffmpeg',
          '-i', station.stream_url,
          
          # Audio codec settings - PRIORITY: High quality for transcription
          '-c:a', 'aac',
          '-b:a', '256k',           # High bitrate for better audio quality (was 128k)
          '-ar', '48000',           # Higher sample rate for better voice clarity (was 44100)
          '-ac', '2',               # Stereo audio (better for voice separation)
          '-aac_coder', 'twoloop',  # Better AAC encoding quality
          
          # Video codec and quality settings (secondary priority)
          '-c:v', 'libx264',
          '-preset', 'fast',        # Faster preset to save CPU for audio processing
          '-crf', '25',             # Slightly lower video quality to prioritize audio
          '-profile:v', 'high',
          '-level', '4.0',
          '-maxrate', '2000k',      # Reduced video bitrate to allow more bandwidth for audio
          '-bufsize', '4000k',
          
          # Video scaling
          '-vf', 'scale=1024:-2:flags=lanczos',
          
          # Segmentation settings
          '-f', 'segment',
          '-segment_time', '60',
          '-segment_format', 'mp4',
          '-reset_timestamps', '1',
          '-strftime', '1',
          '-g', '60',
          '-keyint_min', '60',
          
          # Timeout and reconnection settings
          '-timeout', '10000000', # 10 seconds timeout in microseconds
          '-reconnect', '1',
          '-reconnect_at_eof', '1',
          '-reconnect_streamed', '1',
          '-reconnect_delay_max', '2',
          
          # MP4 optimization
          '-movflags', '+faststart',
          
          output_pattern
        ]

        Rails.logger.info("Starting FFmpeg for station #{station.id}: #{command.join(' ')}")

        # Track last file modification time for heartbeat
        last_file_time = nil
        heartbeat_thread = nil

        # Use popen3 to read stderr in real-time
        Open3.popen3(*command) do |stdin, _stdout, stderr, wait_thr|
          # Close stdin as we don't need to send input
          stdin.close

          # Start heartbeat monitoring thread
          heartbeat_thread = Thread.new do
            loop do
              sleep 30 # Check every 30 seconds
              break if shutdown

              # Check if new files are being created
              latest_file = Dir.glob(base_directory.join('*.mp4').to_s).max_by { |f| File.mtime(f) }
              
              if latest_file && File.exist?(latest_file)
                file_time = File.mtime(latest_file)
                
                # If file is newer than last check, update heartbeat
                if last_file_time.nil? || file_time > last_file_time
                  station.update_column(:last_heartbeat_at, Time.current)
                  last_file_time = file_time
                  Rails.logger.debug("Heartbeat updated for station #{station.id} from file #{File.basename(latest_file)}")
                end

                # If no new file in 3 minutes, consider disconnected
                if Time.current - file_time > 180
                  Rails.logger.warn("No new file generated for station #{station.id} in 3 minutes, may be disconnected")
                end
              end
            end
          end

          # Monitor stderr for errors in real-time
          disconnection_detected = false
          stderr_thread = Thread.new do
            stderr.each_line do |line|
              break if shutdown
              
              line = line.chomp
              Rails.logger.debug("FFmpeg[#{station.id}]: #{line}")

              # Check for disconnection patterns
              if line.match?(%r{Connection refused|Server returned|Network is unreachable|HTTP error \d+|Unable to open|Connection timed out|Failed to resolve|Name or service not known}i)
                Rails.logger.error("Disconnection detected for station #{station.id}: #{line}")
                disconnection_detected = true
                station.update(stream_status: :disconnected, last_heartbeat_at: nil)
                Process.kill('TERM', wait_thr.pid) if wait_thr.alive?
                break
              end

              # Check for end of stream
              if line.match?(%r{End of file|Input/output error|Streaming ended}i)
                Rails.logger.warn("Stream ended for station #{station.id}: #{line}")
                disconnection_detected = true
                station.update(stream_status: :disconnected)
                Process.kill('TERM', wait_thr.pid) if wait_thr.alive?
                break
              end
            end
          end

          # Wait for FFmpeg process to finish
          exit_status = wait_thr.value

          # Clean up threads
          heartbeat_thread&.kill
          stderr_thread&.kill

          # If process exited unexpectedly and no disconnection was detected, mark as disconnected
          unless exit_status.success? || disconnection_detected
            Rails.logger.error("FFmpeg exited with status #{exit_status.exitstatus} for station #{station.id}")
            station.update(stream_status: :disconnected, last_heartbeat_at: nil)
          end
        end

        # If we get here, FFmpeg has stopped
        station.update(stream_status: :disconnected) unless shutdown

        # Try to update stream URL if source is available
        if station.stream_source.present? && !shutdown
          Rails.logger.info("Attempting to update stream URL for station #{station.id}")
          begin
            Rake::Task['stream:update_stream_url'].reenable
            Rake::Task['stream:update_stream_url'].invoke(station.id)
            station.reload
          rescue StandardError => e
            Rails.logger.error("Failed to update stream URL for station #{station.id}: #{e.message}")
          end
        end

        # Calculate retry delay with exponential backoff
        if retry_count < max_retries && !shutdown
          retry_delay = [base_retry_delay * (2**retry_count), 60].min
          puts "Station #{station.name} disconnected, retrying in #{retry_delay} seconds... (attempt #{retry_count + 1}/#{max_retries})"
          sleep retry_delay
          retry_count += 1
        elsif retry_count >= max_retries
          Rails.logger.error("Max retries reached for station #{station.id}, giving up")
          break
        end

      rescue StandardError => e
        Rails.logger.error("Error processing station #{station.id}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        station.update(stream_status: :disconnected, last_heartbeat_at: nil)
        
        unless shutdown
          retry_delay = [base_retry_delay * (2**retry_count), 60].min
          sleep retry_delay
          retry_count += 1
        end
      end
    end

    puts "Exiting stream listener for station #{station.name} (ID: #{station.id})"
  end
end

