# frozen_string_literal: true

require 'open3'

desc 'Import Videos'
task import_videos: :environment do
  # batch_size = 0
  # Parallel.each(Station.all, in_processes: batch_size) do |station|
  Station.find_each do |station|
    puts "Station: #{station.name}"
    directory_path = Rails.public_path.join('videos', station.directory, 'temp')
    puts "Directory path: #{station.directory}"
    
    # Check if the directory exists
    next unless Dir.exist?(directory_path)

    Dir.glob(File.join(directory_path, '*.mp4')).each do |file|
      puts "File: #{file}"
      next if in_use?(file)
      
      filename = File.basename(file)
      
      puts "Filename: #{filename}"

      timestamp = filename.split('.')[0].gsub('_', ':')
      next unless timestamp

      video = Video.find_or_create_by(location: filename, posted_at: timestamp, station_id: station.id)

      video.path = move_video(video, file)
      video.public_path = Pathname.new(video.path).relative_path_from(Rails.public_path).to_s
      video.generate_thumbnail
      video.save

      puts "Video saved!"
    end
  end
end

def move_video(video, file)
  year, month, day = video.directories
  subfolder_path = Rails.public_path.join('videos', video.station.directory, year, month, day)
  FileUtils.mkdir_p(subfolder_path)

  # Move the video file to the subfolder
  new_location = File.join(subfolder_path, video.location)
  FileUtils.mv(file, new_location) if File.exist?(file)

  new_location
end

def mp4_downloaded_complete?(file_path)
  command = "ffmpeg -v error -i #{file_path} -f null -"
  Open3.popen3(command) do |_stdin, _stdout, stderr, _wait_thr|
    error_message = stderr.read
    return error_message.empty? # If there are no errors, the file is likely complete
  end
end

def in_use?(file_path)
  command = "lsof -w #{file_path}"
  Open3.popen3(command) do |_stdin, stdout, _stderr, _wait_thr|
    !stdout.read.empty?
  end
end
