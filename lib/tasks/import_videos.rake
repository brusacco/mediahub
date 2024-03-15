# frozen_string_literal: true

desc 'Import Videos'
task import_videos: :environment do
  Station.find_each do |station|
    directory_path = Rails.public_path.join('videos', station.directory)

    # Check if the directory exists
    next unless Dir.exist?(directory_path)

    Dir.glob(File.join(directory_path, '*.mp4')).each do |file|
      filename = File.basename(file)
      timestamp = filename.split('.')[0].gsub('_', ':')
      next unless timestamp

      Video.find_or_create_by(location: filename, posted_at: timestamp, station_id: station.id)
    end
  end
end
