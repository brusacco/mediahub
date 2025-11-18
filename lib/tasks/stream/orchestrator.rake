# frozen_string_literal: true

namespace :stream do
  desc 'Orchestrate stream listeners - monitors stations and manages systemd services (or dev processes)'
  task orchestrator: :environment do
    require 'open3'

    check_interval = ENV['ORCHESTRATOR_INTERVAL']&.to_i || 60 # seconds
    service_prefix = ENV['SERVICE_PREFIX'] || 'mediahub-stream'
    
    # Detect if we're in development mode (no systemd)
    development_mode = Rails.env.development? || !systemd_available?

    if development_mode
      puts "[#{Time.current}] Starting stream orchestrator in DEVELOPMENT MODE (check interval: #{check_interval}s)"
      puts "Using process management instead of systemd"
      Rails.logger.info("Stream orchestrator started in development mode with interval: #{check_interval}s")
    else
      puts "[#{Time.current}] Starting stream orchestrator (check interval: #{check_interval}s)"
      Rails.logger.info("Stream orchestrator started with interval: #{check_interval}s")
    end

    # Set up signal handling for graceful shutdown
    shutdown = false
    %w[INT TERM HUP QUIT].each do |signal|
      Signal.trap(signal) do
        puts "\n#{signal} signal received. Shutting down orchestrator..."
        Rails.logger.info("Orchestrator shutdown requested via #{signal}")
        shutdown = true
      end
    end

    loop do
      break if shutdown

      begin
        # Get all active stations
        active_stations = Station.active.to_a

        active_stations.each do |station|
          if development_mode
            # Development mode: use process management
            pid_file = Rails.root.join('tmp', 'pids', 'stream', "stream-station-#{station.id}.pid")
            
            # Check if process is running - first check PID file, then check by command line as backup
            process_running = false
            if File.exist?(pid_file)
              pid = File.read(pid_file).to_i
              process_running = dev_process_running?(pid)
            end
            
            # If PID file check failed, check by command line (safety check)
            unless process_running
              found_pid = dev_find_process_by_station(station.id)
              if found_pid && dev_process_running?(found_pid)
                Rails.logger.warn("Found running process for station #{station.id} (PID: #{found_pid}) but PID file missing or incorrect - updating PID file")
                FileUtils.mkdir_p(File.dirname(pid_file))
                File.write(pid_file, found_pid.to_s)
                process_running = true
              end
            end

            # If process is running, DON'T TOUCH IT - just sync status
            if process_running
              # Process is running, so station should be marked as connected
              if station.disconnected?
                station.update(stream_status: :connected)
                Rails.logger.info("Updated station #{station.id} status to connected (process is running)")
              end
              # Don't restart even if heartbeat is stale - process is running, let it be
              # The process itself will handle reconnection if needed
            else
              # Process is NOT running
              # First, sync status: if DB says connected but process isn't running, mark as disconnected
              if station.connected?
                station.update(stream_status: :disconnected)
                Rails.logger.warn("Updated station #{station.id} status to disconnected (process not running)")
              end
              
              # Now check if we need to start the process
              # Start if station is disconnected (needs attention)
              if station.disconnected?
                Rails.logger.warn("Station #{station.id} (#{station.name}) is disconnected - starting process")
                Rails.logger.info("Starting process for disconnected station #{station.id}")
                dev_start_process(station.id)
              elsif station.stale_heartbeat?
                # Station has stale heartbeat but process not running - start it
                Rails.logger.warn("Station #{station.id} (#{station.name}) has stale heartbeat and process not running - starting process")
                dev_start_process(station.id)
              elsif station.healthy? && !process_running
                # Station is healthy but process not running - start it (shouldn't happen but safety check)
                Rails.logger.info("Starting process for healthy station #{station.id} (process not running)")
                dev_start_process(station.id)
              end
            end
          else
            # Production mode: use systemd
            service_name = "#{service_prefix}-#{station.id}"
            service_status = check_systemd_service(service_name)

            # If service is active, DON'T TOUCH IT - just sync status
            if service_status == 'active'
              # Service is active, so station should be marked as connected
              if station.disconnected?
                station.update(stream_status: :connected)
                Rails.logger.info("Updated station #{station.id} status to connected (service is active)")
              end
              # Don't restart even if heartbeat is stale - service is running, let it be
              # The service itself will handle reconnection if needed
            else
              # Service is NOT active
              # First, sync status: if DB says connected but service isn't active, mark as disconnected
              if station.connected?
                station.update(stream_status: :disconnected)
                Rails.logger.warn("Updated station #{station.id} status to disconnected (service status: #{service_status})")
              end
              
              # Now check if we need to start the service
              # Start if station is disconnected (needs attention)
              if station.disconnected?
                Rails.logger.warn("Station #{station.id} (#{station.name}) is disconnected - starting service")
                Rails.logger.info("Starting systemd service for disconnected station #{station.id}")
                start_systemd_service(service_name, station.id)
              elsif station.stale_heartbeat?
                # Station has stale heartbeat but service not running - start it
                Rails.logger.warn("Station #{station.id} (#{station.name}) has stale heartbeat and service not running - starting service")
                start_systemd_service(service_name, station.id)
              elsif station.healthy? && service_status != 'active'
                # Station is healthy but service not running - start it (shouldn't happen but safety check)
                Rails.logger.info("Starting systemd service for healthy station #{station.id} (service not running)")
                start_systemd_service(service_name, station.id)
              end
            end
          end
        end

        # Log summary
        healthy_count = Station.healthy.count
        needs_attention_count = Station.needs_attention.count
        Rails.logger.info("Orchestrator check complete - Healthy: #{healthy_count}, Needs attention: #{needs_attention_count}")

      rescue StandardError => e
        Rails.logger.error("Error in orchestrator: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end

      # Sleep until next check
      sleep check_interval unless shutdown
    end

    puts "[#{Time.current}] Stream orchestrator stopped"
    Rails.logger.info("Stream orchestrator stopped")
  end

  private

  def systemd_available?
    # Check if systemd is available (not on macOS)
    return false if RUBY_PLATFORM.include?('darwin')
    
    # Try to check if systemctl exists
    _stdout, _stderr, status = Open3.capture3('which', 'systemctl')
    status.success?
  rescue
    false
  end

  def dev_process_running?(pid)
    return false if pid.nil? || pid.zero?
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH, Errno::EPERM
    false
  end

  def dev_find_process_by_station(station_id)
    # Check if there's already a process running for this station by checking command line
    # This is a safety check in case PID file is missing or corrupted
    begin
      # Use pgrep to find processes matching the rake task for this station
      stdout, _stderr, status = Open3.capture3('pgrep', '-f', "stream:listen_station\\[#{station_id}\\]")
      if status.success? && !stdout.strip.empty?
        pids = stdout.strip.split("\n").map(&:to_i).reject(&:zero?)
        return pids.first if pids.any?
      end
    rescue StandardError => e
      Rails.logger.debug("Error checking for existing process for station #{station_id}: #{e.message}")
    end
    nil
  end

  def dev_start_process(station_id)
    pid_dir = Rails.root.join('tmp', 'pids', 'stream')
    FileUtils.mkdir_p(pid_dir)
    
    pid_file = pid_dir.join("stream-station-#{station_id}.pid")
    
    # CRITICAL: Check if process is already running before starting a new one
    # First check PID file
    if File.exist?(pid_file)
      pid = File.read(pid_file).to_i
      if dev_process_running?(pid)
        Rails.logger.warn("Process for station #{station_id} is already running (PID: #{pid}), skipping start")
        return false # Don't start, process is already running
      else
        # Stale PID file - remove it
        Rails.logger.debug("Removing stale PID file for station #{station_id}")
        File.delete(pid_file)
      end
    end
    
    # Also check by command line as a safety measure (in case PID file is missing)
    found_pid = dev_find_process_by_station(station_id)
    if found_pid && dev_process_running?(found_pid)
      Rails.logger.warn("Found running process for station #{station_id} (PID: #{found_pid}) via command line check, skipping start")
      # Update PID file for future reference
      FileUtils.mkdir_p(File.dirname(pid_file))
      File.write(pid_file, found_pid.to_s)
      return false # Don't start, process is already running
    end
    
    log_file = Rails.root.join('log', "stream-station-#{station_id}.log")
    command = "bundle exec rake stream:listen_station[#{station_id}]"
    
    pid = spawn(
      command,
      out: log_file.to_s,
      err: log_file.to_s,
      pgroup: true
    )
    
    File.write(pid_file, pid.to_s)
    Rails.logger.info("Started process for station #{station_id} (PID: #{pid})")
    true
  rescue StandardError => e
    Rails.logger.error("Error starting process for station #{station_id}: #{e.message}")
    false
  end

  def dev_restart_process(station_id)
    pid_file = Rails.root.join('tmp', 'pids', 'stream', "stream-station-#{station_id}.pid")
    
    if File.exist?(pid_file)
      pid = File.read(pid_file).to_i
      if dev_process_running?(pid)
        begin
          Process.kill('TERM', -pid)
          sleep 2
          Process.kill('KILL', -pid) if dev_process_running?(pid)
        rescue Errno::ESRCH
        end
      end
      File.delete(pid_file) if File.exist?(pid_file)
    end
    
    sleep 1
    dev_start_process(station_id)
  end

  def check_systemd_service(service_name)
    # Check if systemd service exists and is active
    full_service_name = "#{service_name}.service"
    
    # Check if service exists
    _stdout, _stderr, status = Open3.capture3('systemctl', 'is-enabled', full_service_name, '2>/dev/null')
    return 'not-found' unless status.success?

    # Check service status
    stdout, _stderr, status = Open3.capture3('systemctl', 'is-active', full_service_name)
    return stdout.chomp if status.success?

    'inactive'
  rescue StandardError => e
    Rails.logger.error("Error checking systemd service #{service_name}: #{e.message}")
    'error'
  end

  def start_systemd_service(service_name, station_id)
    full_service_name = "#{service_name}.service"
    
    # Check if service exists, if not, it needs to be created first
    _stdout, _stderr, status = Open3.capture3('systemctl', 'is-enabled', full_service_name, '2>/dev/null')
    
    unless status.success?
      Rails.logger.warn("Service #{full_service_name} does not exist. Run 'rake stream:systemd:install[#{station_id}]' first")
      return false
    end

    stdout, stderr, status = Open3.capture3('systemctl', 'start', full_service_name)
    
    if status.success?
      Rails.logger.info("Started systemd service #{full_service_name}")
      true
    else
      Rails.logger.error("Failed to start systemd service #{full_service_name}: #{stderr}")
      false
    end
  rescue StandardError => e
    Rails.logger.error("Error starting systemd service #{service_name}: #{e.message}")
    false
  end

  def restart_systemd_service(service_name)
    full_service_name = "#{service_name}.service"
    
    stdout, stderr, status = Open3.capture3('systemctl', 'restart', full_service_name)
    
    if status.success?
      Rails.logger.info("Restarted systemd service #{full_service_name}")
      true
    else
      Rails.logger.error("Failed to restart systemd service #{full_service_name}: #{stderr}")
      false
    end
  rescue StandardError => e
    Rails.logger.error("Error restarting systemd service #{service_name}: #{e.message}")
    false
  end
end

