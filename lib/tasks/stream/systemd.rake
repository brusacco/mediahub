# frozen_string_literal: true

require 'open3'

namespace :stream do
  namespace :systemd do
    SERVICE_PREFIX = 'mediahub-stream'
    SERVICE_DIR = '/etc/systemd/system'
    USER = ENV['SERVICE_USER'] || ENV['USER'] || 'www-data'
    WORKING_DIR = Rails.root.to_s
    RAILS_ENV = Rails.env

    desc 'Generate systemd service file for a station'
    task :generate, [:station_id] => :environment do |_t, args|
      station_id = args[:station_id]&.to_i

      unless station_id
        puts 'Error: station_id is required'
        puts 'Usage: rake stream:systemd:generate[STATION_ID]'
        exit 1
      end

      station = Station.find_by(id: station_id)

      unless station
        puts "Error: Station with ID #{station_id} not found"
        exit 1
      end

      service_name = "#{SERVICE_PREFIX}-#{station.id}"
      service_file = "#{SERVICE_DIR}/#{service_name}.service"

      # Generate service file content
      service_content = <<~SERVICE
        [Unit]
        Description=MediaHub Stream Listener for #{station.name} (ID: #{station.id})
        After=network.target

        [Service]
        Type=simple
        User=#{USER}
        WorkingDirectory=#{WORKING_DIR}
        Environment="RAILS_ENV=#{RAILS_ENV}"
        ExecStart=/usr/bin/env bundle exec rake stream:listen_station[#{station.id}]
        Restart=always
        RestartSec=5
        StandardOutput=journal
        StandardError=journal
        SyslogIdentifier=#{service_name}

        # Resource limits
        MemoryLimit=512M
        CPUQuota=50%

        [Install]
        WantedBy=multi-user.target
      SERVICE

      puts "Service file content for #{station.name} (ID: #{station.id}):"
      puts '=' * 80
      puts service_content
      puts '=' * 80
      puts "\nTo install this service, run:"
      puts "  sudo rake stream:systemd:install[#{station_id}]"
    end

    desc 'Install systemd service for a station (requires sudo)'
    task :install, [:station_id] => :environment do |_t, args|
      station_id = args[:station_id]&.to_i

      unless station_id
        puts 'Error: station_id is required'
        puts 'Usage: rake stream:systemd:install[STATION_ID]'
        exit 1
      end

      station = Station.find_by(id: station_id)

      unless station
        puts "Error: Station with ID #{station_id} not found"
        exit 1
      end

      service_name = "#{SERVICE_PREFIX}-#{station.id}"
      service_file = "#{SERVICE_DIR}/#{service_name}.service"

      # Generate service file content
      service_content = <<~SERVICE
        [Unit]
        Description=MediaHub Stream Listener for #{station.name} (ID: #{station.id})
        After=network.target

        [Service]
        Type=simple
        User=#{USER}
        WorkingDirectory=#{WORKING_DIR}
        Environment="RAILS_ENV=#{RAILS_ENV}"
        ExecStart=/usr/bin/env bundle exec rake stream:listen_station[#{station.id}]
        Restart=always
        RestartSec=5
        StandardOutput=journal
        StandardError=journal
        SyslogIdentifier=#{service_name}

        # Resource limits
        MemoryLimit=512M
        CPUQuota=50%

        [Install]
        WantedBy=multi-user.target
      SERVICE

      # Write service file (requires sudo)
      puts "Installing systemd service for #{station.name} (ID: #{station.id})..."
      
      temp_file = "/tmp/#{service_name}.service"
      File.write(temp_file, service_content)
      
      # Copy to systemd directory
      stdout, stderr, status = Open3.capture3('sudo', 'cp', temp_file, service_file)
      
      unless status.success?
        puts "Error copying service file: #{stderr}"
        File.delete(temp_file) if File.exist?(temp_file)
        exit 1
      end

      # Reload systemd
      stdout, stderr, status = Open3.capture3('sudo', 'systemctl', 'daemon-reload')
      
      unless status.success?
        puts "Error reloading systemd: #{stderr}"
        exit 1
      end

      # Enable service
      stdout, stderr, status = Open3.capture3('sudo', 'systemctl', 'enable', "#{service_name}.service")
      
      unless status.success?
        puts "Error enabling service: #{stderr}"
        exit 1
      end

      File.delete(temp_file) if File.exist?(temp_file)

      puts "Service installed successfully!"
      puts "To start the service, run: rake stream:systemd:start[#{station_id}]"
    end

    desc 'Uninstall systemd service for a station (requires sudo)'
    task :uninstall, [:station_id] => :environment do |_t, args|
      station_id = args[:station_id]&.to_i

      unless station_id
        puts 'Error: station_id is required'
        puts 'Usage: rake stream:systemd:uninstall[STATION_ID]'
        exit 1
      end

      station = Station.find_by(id: station_id)

      unless station
        puts "Error: Station with ID #{station_id} not found"
        exit 1
      end

      service_name = "#{SERVICE_PREFIX}-#{station.id}"
      service_file = "#{SERVICE_DIR}/#{service_name}.service"

      # Stop service first
      stdout, stderr, _status = Open3.capture3('sudo', 'systemctl', 'stop', "#{service_name}.service")

      # Disable service
      stdout, stderr, status = Open3.capture3('sudo', 'systemctl', 'disable', "#{service_name}.service")
      
      unless status.success?
        puts "Warning: Error disabling service: #{stderr}"
      end

      # Remove service file
      if File.exist?(service_file)
        stdout, stderr, status = Open3.capture3('sudo', 'rm', service_file)
        
        unless status.success?
          puts "Error removing service file: #{stderr}"
          exit 1
        end
      end

      # Reload systemd
      stdout, stderr, status = Open3.capture3('sudo', 'systemctl', 'daemon-reload')
      
      unless status.success?
        puts "Warning: Error reloading systemd: #{stderr}"
      end

      puts "Service uninstalled successfully!"
    end

    desc 'Start systemd service for a station'
    task :start, [:station_id] => :environment do |_t, args|
      station_id = args[:station_id]&.to_i

      unless station_id
        puts 'Error: station_id is required'
        puts 'Usage: rake stream:systemd:start[STATION_ID]'
        exit 1
      end

      station = Station.find_by(id: station_id)

      unless station
        puts "Error: Station with ID #{station_id} not found"
        exit 1
      end

      service_name = "#{SERVICE_PREFIX}-#{station.id}"

      stdout, stderr, status = Open3.capture3('sudo', 'systemctl', 'start', "#{service_name}.service")
      
      if status.success?
        puts "Service started successfully for #{station.name} (ID: #{station.id})"
      else
        puts "Error starting service: #{stderr}"
        exit 1
      end
    end

    desc 'Stop systemd service for a station'
    task :stop, [:station_id] => :environment do |_t, args|
      station_id = args[:station_id]&.to_i

      unless station_id
        puts 'Error: station_id is required'
        puts 'Usage: rake stream:systemd:stop[STATION_ID]'
        exit 1
      end

      station = Station.find_by(id: station_id)

      unless station
        puts "Error: Station with ID #{station_id} not found"
        exit 1
      end

      service_name = "#{SERVICE_PREFIX}-#{station.id}"

      stdout, stderr, status = Open3.capture3('sudo', 'systemctl', 'stop', "#{service_name}.service")
      
      if status.success?
        puts "Service stopped successfully for #{station.name} (ID: #{station.id})"
      else
        puts "Error stopping service: #{stderr}"
        exit 1
      end
    end

    desc 'Restart systemd service for a station'
    task :restart, [:station_id] => :environment do |_t, args|
      station_id = args[:station_id]&.to_i

      unless station_id
        puts 'Error: station_id is required'
        puts 'Usage: rake stream:systemd:restart[STATION_ID]'
        exit 1
      end

      station = Station.find_by(id: station_id)

      unless station
        puts "Error: Station with ID #{station_id} not found"
        exit 1
      end

      service_name = "#{SERVICE_PREFIX}-#{station.id}"

      stdout, stderr, status = Open3.capture3('sudo', 'systemctl', 'restart', "#{service_name}.service")
      
      if status.success?
        puts "Service restarted successfully for #{station.name} (ID: #{station.id})"
      else
        puts "Error restarting service: #{stderr}"
        exit 1
      end
    end

    desc 'Install systemd services for all active stations'
    task install_all: :environment do
      puts "Installing systemd services for all active stations..."
      
      Station.active.find_each do |station|
        puts "\nInstalling service for #{station.name} (ID: #{station.id})..."
        Rake::Task['stream:systemd:install'].reenable
        Rake::Task['stream:systemd:install'].invoke(station.id)
      end

      puts "\nAll services installed!"
    end

    desc 'Start systemd services for all active stations'
    task start_all: :environment do
      puts "Starting systemd services for all active stations..."
      
      Station.active.find_each do |station|
        service_name = "#{SERVICE_PREFIX}-#{station.id}"
        stdout, stderr, status = Open3.capture3('sudo', 'systemctl', 'start', "#{service_name}.service")
        
        if status.success?
          puts "Started service for #{station.name} (ID: #{station.id})"
        else
          puts "Error starting service for #{station.name} (ID: #{station.id}): #{stderr}"
        end
      end

      puts "\nDone!"
    end

    desc 'Stop systemd services for all active stations'
    task stop_all: :environment do
      puts "Stopping systemd services for all active stations..."
      
      Station.active.find_each do |station|
        service_name = "#{SERVICE_PREFIX}-#{station.id}"
        stdout, stderr, status = Open3.capture3('sudo', 'systemctl', 'stop', "#{service_name}.service")
        
        if status.success?
          puts "Stopped service for #{station.name} (ID: #{station.id})"
        else
          puts "Error stopping service for #{station.name} (ID: #{station.id}): #{stderr}"
        end
      end

      puts "\nDone!"
    end

    desc 'Show status of all systemd services'
    task status_all: :environment do
      puts "Status of systemd services for all stations:"
      puts '=' * 80
      
      Station.all.order(:id).each do |station|
        service_name = "#{SERVICE_PREFIX}-#{station.id}"
        full_service_name = "#{service_name}.service"
        
        # Check if service exists
        _stdout, _stderr, status = Open3.capture3('systemctl', 'is-enabled', full_service_name, '2>/dev/null')
        
        if status.success?
          stdout, _stderr, _status = Open3.capture3('systemctl', 'is-active', full_service_name)
          service_status = stdout.chomp
          
          status_icon = service_status == 'active' ? '✓' : '✗'
          puts "#{status_icon} #{station.name.ljust(30)} (ID: #{station.id.to_s.ljust(3)}) - Service: #{service_status.ljust(10)} - DB Status: #{station.stream_status} - Heartbeat: #{station.last_heartbeat_at || 'never'}"
        else
          puts "✗ #{station.name.ljust(30)} (ID: #{station.id.to_s.ljust(3)}) - Service: not installed"
        end
      end
      
      puts '=' * 80
    end
  end
end





