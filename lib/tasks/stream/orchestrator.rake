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
            process_running = File.exist?(pid_file) && dev_process_running?(File.read(pid_file).to_i)

            # Check if station needs attention
            if station.needs_attention?
              Rails.logger.warn("Station #{station.id} (#{station.name}) needs attention - Status: #{station.stream_status}, Heartbeat: #{station.last_heartbeat_at}")

              if !process_running
                Rails.logger.info("Starting process for station #{station.id}")
                dev_start_process(station.id)
              elsif station.stale_heartbeat?
                Rails.logger.warn("Restarting process for station #{station.id} due to stale heartbeat")
                dev_restart_process(station.id)
              end
            elsif station.healthy?
              unless process_running
                Rails.logger.info("Starting process for healthy station #{station.id}")
                dev_start_process(station.id)
              end
            end

            # Update station status based on process status
            if process_running && station.disconnected?
              station.update(stream_status: :connected)
              Rails.logger.info("Updated station #{station.id} status to connected (process is running)")
            elsif !process_running && station.connected?
              station.update(stream_status: :disconnected)
              Rails.logger.warn("Updated station #{station.id} status to disconnected (process not running)")
            end
          else
            # Production mode: use systemd
            service_name = "#{service_prefix}-#{station.id}"
            service_status = check_systemd_service(service_name)

            # Check if station needs attention
            if station.needs_attention?
              Rails.logger.warn("Station #{station.id} (#{station.name}) needs attention - Status: #{station.stream_status}, Heartbeat: #{station.last_heartbeat_at}")

              # If service is not running, start it
              if service_status != 'active'
                Rails.logger.info("Starting systemd service for station #{station.id}")
                start_systemd_service(service_name, station.id)
              elsif station.stale_heartbeat?
                # Service is running but heartbeat is stale - restart it
                Rails.logger.warn("Restarting systemd service for station #{station.id} due to stale heartbeat")
                restart_systemd_service(service_name)
              end
            elsif station.healthy?
              # Station is healthy
              if service_status != 'active'
                # Service should be running but isn't - start it
                Rails.logger.info("Starting systemd service for healthy station #{station.id}")
                start_systemd_service(service_name, station.id)
              else
                Rails.logger.debug("Station #{station.id} is healthy and service is active")
              end
            end

            # Update station status based on service status
            if service_status == 'active' && station.disconnected?
              # Service is running but station is marked as disconnected - update status
              station.update(stream_status: :connected)
              Rails.logger.info("Updated station #{station.id} status to connected (service is active)")
            elsif service_status != 'active' && service_status != 'inactive' && station.connected?
              # Service failed but station is marked as connected - update status
              station.update(stream_status: :disconnected)
              Rails.logger.warn("Updated station #{station.id} status to disconnected (service status: #{service_status})")
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

  def dev_start_process(station_id)
    pid_dir = Rails.root.join('tmp', 'pids', 'stream')
    FileUtils.mkdir_p(pid_dir)
    
    pid_file = pid_dir.join("stream-station-#{station_id}.pid")
    log_file = Rails.root.join('log', "stream-station-#{station_id}.log")
    
    command = "bundle exec rake stream:listen_station[#{station_id}]"
    pid = spawn(
      command,
      out: log_file.to_s,
      err: log_file.to_s,
      pgroup: true
    )
    
    File.write(pid_file, pid.to_s)
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

