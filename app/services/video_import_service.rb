# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'shellwords'

class VideoImportService < ApplicationService
  FILENAME_PATTERN = /\A\d{4}-\d{2}-\d{2}T\d{2}_\d{2}_\d{2}\.mp4\z/.freeze

  def self.call(station, file)
    new(station, file).call
  end

  def initialize(station, file)
    super()
    @station = station
    @file = file
    @filename = File.basename(file)
  end

  def call
    # Check if file exists
    unless File.exist?(@file)
      return handle_error('File does not exist')
    end
    
    # Only check if file is in use if it's in temp directory (being written)
    if file_in_temp_directory? && file_in_use?
      return handle_error('File is in use')
    end
    
    unless valid_filename?
      return handle_error('Invalid filename format')
    end
    
    unless (timestamp = parse_timestamp)
      return handle_error('Invalid timestamp')
    end
    
    unless valid_video?
      return handle_error('Invalid video file')
    end

    # Calculate destination path
    destination_path = calculate_destination_path
    
    # Check if video already exists in DB
    existing_video = Video.find_by(location: @filename, station_id: @station.id)
    if existing_video
      # Video exists, ensure path is correct
      if existing_video.path != destination_path && File.exist?(destination_path)
        existing_video.update(path: destination_path, public_path: Pathname.new(destination_path).relative_path_from(Rails.public_path).to_s)
      end
      generate_thumbnail_if_needed(existing_video)
      return handle_success(existing_video)
    end

    # Move file to final location FIRST (before creating DB record)
    final_path = move_file_to_destination(destination_path)
    unless final_path
      Rails.logger.error("Failed to move file to destination: #{@filename}")
      return handle_error('Failed to move file to destination')
    end

    # NOW create the video record with the final path
    video = create_video_record(timestamp, final_path)
    unless video
      Rails.logger.error("Failed to create video record: #{@filename}")
      return handle_error('Failed to create video record')
    end

    generate_thumbnail_if_needed(video)

    handle_success(video)
  rescue StandardError => e
    Rails.logger.error("VideoImportService error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    handle_error(e.message)
  end

  private

  def file_in_temp_directory?
    @file.include?('/temp/')
  end

  def file_in_use?
    return false unless File.exist?(@file)

    command = "lsof -w #{Shellwords.escape(@file)}"
    stdout, _stderr, status = Open3.capture3(command)
    
    status.success? && !stdout.empty?
  rescue StandardError
    false
  end

  def valid_filename?
    @filename.match?(FILENAME_PATTERN)
  end

  def parse_timestamp
    timestamp_str = @filename.split('.').first.gsub('_', ':')
    Time.parse(timestamp_str)
  rescue ArgumentError
    nil
  end

  def valid_video?
    command = "ffprobe -v error -show_streams -select_streams v:0 #{Shellwords.escape(@file)}"
    _stdout, _stderr, status = Open3.capture3(command)
    status.success?
  rescue StandardError
    false
  end

  def create_video_record(timestamp, final_path)
    video = Video.new(
      location: @filename,
      posted_at: timestamp,
      station_id: @station.id,
      path: final_path,
      public_path: Pathname.new(final_path).relative_path_from(Rails.public_path).to_s
    )

    video.save!
    video
  rescue ActiveRecord::RecordNotUnique
    # Race condition: video was created by another process
    video = Video.find_by(location: @filename, station_id: @station.id)
    if video
      # Update path if needed
      if video.path != final_path && File.exist?(final_path)
        video.update(path: final_path, public_path: Pathname.new(final_path).relative_path_from(Rails.public_path).to_s)
      end
      video
    else
      Rails.logger.error("Video was created but not found after RecordNotUnique: #{@filename}")
      nil
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to save video: #{e.message}")
    nil
  end

  def calculate_destination_path
    date_part = @filename.split('T').first
    year, month, day = date_part.split('-')
    
    subfolder_path = Rails.public_path.join('videos', @station.directory, year, month, day)
    File.join(subfolder_path, @filename)
  end

  def move_file_to_destination(destination_path)
    # If file is already in the correct location, return that path
    return destination_path if @file == destination_path && File.exist?(destination_path)

    # If destination already exists, return that path (don't overwrite)
    return destination_path if File.exist?(destination_path)

    # Create destination directory and move file
    FileUtils.mkdir_p(File.dirname(destination_path))
    FileUtils.mv(@file, destination_path)
    
    destination_path
  rescue StandardError => e
    Rails.logger.error("Error moving file: #{e.message}")
    nil
  end

  def generate_thumbnail_if_needed(video)
    return if video.thumbnail_path.present? && File.exist?(video.path)

    video.generate_thumbnail
    video.save!
  rescue StandardError => e
    Rails.logger.error("Error generating thumbnail: #{e.message}")
  end
end

