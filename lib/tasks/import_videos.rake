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

      video = Video.find_or_create_by(location: filename, posted_at: timestamp, station_id: station.id)

      year, month, day = video.directories
      subfolder_path = Rails.public_path.join('videos', station.directory, year, month, day)
      FileUtils.mkdir_p(subfolder_path)

      # Move the video file to the subfolder
      new_location = File.join(subfolder_path, video.location)
      FileUtils.mv(file, new_location) if File.exist?(file)

      video.path = new_location
      video.public_path = Pathname.new(new_location).relative_path_from(Rails.public_path).to_s
      video.save
    end
  end
end
