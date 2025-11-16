# frozen_string_literal: true

namespace :stream do
  desc 'Update stream URL for a station by extracting it from stream_source'
  task :update_stream_url, [:station_id] => :environment do |_t, args|
    station_id = args[:station_id]
    
    unless station_id
      puts 'Error: Station ID is required'
      exit 1
    end

    station = Station.find_by(id: station_id)
    unless station
      puts "Error: Station with ID #{station_id} not found"
      exit 1
    end

    result = StreamUrlUpdateService.call(station)

    if result.success?
      puts "Successfully updated stream URL for station #{station.name}: #{result.data}"
    else
      puts "Failed to update stream URL: #{result.error}"
      exit 1
    end
  end
end
