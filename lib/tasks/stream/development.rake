# frozen_string_literal: true

require 'open3'
require 'fileutils'

namespace :stream do
  namespace :dev do
    PID_DIR = Rails.root.join('tmp', 'pids', 'stream')
    PID_FILE_PREFIX = 'stream-station'

    desc 'Setup development environment (create PID directory)'
    task setup: :environment do
      FileUtils.mkdir_p(PID_DIR)
      puts "Created PID directory: #{PID_DIR}"
    end

    desc 'Start stream listener for a station (development mode)'
    task :start, [:station_id] => [:environment, :setup] do |_t, args|
      station_id = args[:station_id]&.to_i

      unless station_id
        puts 'Error: station_id is required'
        puts 'Usage: rake stream:dev:start[STATION_ID]'
        exit 1
      end

      station = Station.find_by(id: station_id)

      unless station
        puts "Error: Station with ID #{station_id} not found"
        exit 1
      end

      pid_file = PID_DIR.join("#{PID_FILE_PREFIX}-#{station_id}.pid")

      # Check if already running
      if File.exist?(pid_file)
        pid = File.read(pid_file).to_i
        if process_running?(pid)
          puts "Station #{station.name} (ID: #{station_id}) is already running (PID: #{pid})"
          exit 0
        else
          # Stale PID file
          File.delete(pid_file)
        end
      end

      # Start process in background
      log_file = Rails.root.join('log', "stream-station-#{station_id}.log")
      command = "bundle exec rake stream:listen_station[#{station_id}]"
      
      pid = spawn(
        command,
        out: log_file.to_s,
        err: log_file.to_s,
        pgroup: true
      )

      # Save PID
      File.write(pid_file, pid.to_s)
      
      puts "Started station #{station.name} (ID: #{station_id}) with PID: #{pid}"
      puts "Logs: #{log_file}"
      puts "PID file: #{pid_file}"
    end

    desc 'Stop stream listener for a station (development mode)'
    task :stop, [:station_id] => :environment do |_t, args|
      station_id = args[:station_id]&.to_i

      unless station_id
        puts 'Error: station_id is required'
        puts 'Usage: rake stream:dev:stop[STATION_ID]'
        exit 1
      end

      station = Station.find_by(id: station_id)

      unless station
        puts "Error: Station with ID #{station_id} not found"
        exit 1
      end

      pid_file = PID_DIR.join("#{PID_FILE_PREFIX}-#{station_id}.pid")

      unless File.exist?(pid_file)
        puts "Station #{station.name} (ID: #{station_id}) is not running (no PID file)"
        exit 0
      end

      pid = File.read(pid_file).to_i

      unless process_running?(pid)
        puts "Station #{station.name} (ID: #{station_id}) is not running (process #{pid} not found)"
        File.delete(pid_file)
        exit 0
      end

      # Kill process group to ensure all children are killed
      begin
        Process.kill('TERM', -pid) # Negative PID kills process group
        sleep 1
        
        # Force kill if still running
        if process_running?(pid)
          Process.kill('KILL', -pid)
        end
      rescue Errno::ESRCH
        # Process already dead
      end

      File.delete(pid_file)
      puts "Stopped station #{station.name} (ID: #{station_id})"
    end

    desc 'Restart stream listener for a station (development mode)'
    task :restart, [:station_id] => :environment do |_t, args|
      station_id = args[:station_id]&.to_i

      unless station_id
        puts 'Error: station_id is required'
        puts 'Usage: rake stream:dev:restart[STATION_ID]'
        exit 1
      end

      Rake::Task['stream:dev:stop'].reenable
      Rake::Task['stream:dev:stop'].invoke(station_id)
      sleep 2
      Rake::Task['stream:dev:start'].reenable
      Rake::Task['stream:dev:start'].invoke(station_id)
    end

    desc 'Start stream listeners for all active stations (development mode)'
    task start_all: [:environment, :setup] do
      puts "Starting stream listeners for all active stations..."
      
      Station.active.find_each do |station|
        Rake::Task['stream:dev:start'].reenable
        Rake::Task['stream:dev:start'].invoke(station.id)
        sleep 1 # Small delay between starts
      end

      puts "\nDone! Use 'rake stream:dev:status' to check status"
    end

    desc 'Stop stream listeners for all stations (development mode)'
    task stop_all: :environment do
      puts "Stopping all stream listeners..."
      
      Dir.glob(PID_DIR.join("#{PID_FILE_PREFIX}-*.pid")).each do |pid_file|
        pid = File.read(pid_file).to_i
        station_id = File.basename(pid_file, '.pid').split('-').last.to_i
        
        if process_running?(pid)
          begin
            Process.kill('TERM', -pid)
            sleep 1
            Process.kill('KILL', -pid) if process_running?(pid)
          rescue Errno::ESRCH
          end
        end
        
        File.delete(pid_file) if File.exist?(pid_file)
        puts "Stopped station ID: #{station_id}"
      end

      puts "\nDone!"
    end

    desc 'Show status of all stream listeners (development mode)'
    task status: :environment do
      puts "Status of stream listeners (development mode):"
      puts '=' * 80

      Station.all.order(:id).each do |station|
        pid_file = PID_DIR.join("#{PID_FILE_PREFIX}-#{station.id}.pid")
        
        if File.exist?(pid_file)
          pid = File.read(pid_file).to_i
          
          if process_running?(pid)
            status_icon = '✓'
            status_text = 'running'
            
            # Try to get process info
            begin
              process_info = `ps -p #{pid} -o pid,pcpu,pmem,etime,command 2>/dev/null`.split("\n")[1]
            rescue
              process_info = nil
            end
            
            puts "#{status_icon} #{station.name.ljust(30)} (ID: #{station.id.to_s.ljust(3)}) - #{status_text.ljust(10)} (PID: #{pid}) - DB Status: #{station.stream_status} - Heartbeat: #{station.last_heartbeat_at || 'never'}"
            puts "  #{process_info}" if process_info
          else
            status_icon = '✗'
            status_text = 'stale PID'
            puts "#{status_icon} #{station.name.ljust(30)} (ID: #{station.id.to_s.ljust(3)}) - #{status_text.ljust(10)} (PID file exists but process not running)"
            File.delete(pid_file)
          end
        else
          status_icon = '○'
          status_text = 'not running'
          puts "#{status_icon} #{station.name.ljust(30)} (ID: #{station.id.to_s.ljust(3)}) - #{status_text.ljust(10)} - DB Status: #{station.stream_status}"
        end
      end

      puts '=' * 80
    end

    desc 'Start development orchestrator (development mode)'
    task orchestrator: :environment do
      puts "Starting development orchestrator..."
      puts "This will monitor stations and manage processes (not systemd)"
      puts "Press Ctrl+C to stop"
      puts '=' * 80

      check_interval = ENV['ORCHESTRATOR_INTERVAL']&.to_i || 60

      # Set up signal handling
      shutdown = false
      %w[INT TERM HUP QUIT].each do |signal|
        Signal.trap(signal) do
          puts "\n#{signal} signal received. Shutting down orchestrator..."
          shutdown = true
        end
      end

      loop do
        break if shutdown

        begin
          Station.active.find_each do |station|
            pid_file = PID_DIR.join("#{PID_FILE_PREFIX}-#{station.id}.pid")
            process_running = File.exist?(pid_file) && process_running?(File.read(pid_file).to_i)

            if station.needs_attention?
              Rails.logger.warn("Station #{station.id} (#{station.name}) needs attention")

              if !process_running
                puts "[#{Time.current}] Starting station #{station.id} (#{station.name})"
                Rake::Task['stream:dev:start'].reenable
                Rake::Task['stream:dev:start'].invoke(station.id)
              elsif station.stale_heartbeat?
                puts "[#{Time.current}] Restarting station #{station.id} (#{station.name}) due to stale heartbeat"
                Rake::Task['stream:dev:restart'].reenable
                Rake::Task['stream:dev:restart'].invoke(station.id)
              end
            elsif station.healthy?
              unless process_running
                puts "[#{Time.current}] Starting healthy station #{station.id} (#{station.name})"
                Rake::Task['stream:dev:start'].reenable
                Rake::Task['stream:dev:start'].invoke(station.id)
              end
            end

            # Clean up stale PID files
            if File.exist?(pid_file) && !process_running?(File.read(pid_file).to_i)
              File.delete(pid_file)
              station.update(stream_status: :disconnected) if station.connected?
            end
          end

          healthy_count = Station.healthy.count
          needs_attention_count = Station.needs_attention.count
          puts "[#{Time.current}] Check complete - Healthy: #{healthy_count}, Needs attention: #{needs_attention_count}"

        rescue StandardError => e
          Rails.logger.error("Error in orchestrator: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
        end

        sleep check_interval unless shutdown
      end

      puts "Development orchestrator stopped"
    end

    private

    def process_running?(pid)
      return false if pid.nil? || pid.zero?
      
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end
  end
end

