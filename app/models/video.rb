# frozen_string_literal: true

require 'open3'

# VIDEO CLASS
class Video < ApplicationRecord
  belongs_to :station

  after_destroy :cleanup_files

  def directories
    location.split('T')[0].split('-')
  end

  private

  def generate_thumbnail
    thumbnail_path = path.sub(/\.mp4\z/, '.png') # Change file extension to PNG

    # Run ffmpeg command to generate thumbnail
    command = "ffmpeg -i #{path} -ss 00:00:01 -vframes 1 #{thumbnail_path}"
    _stdout, stderr, status = Open3.capture3(command)

    if status.success?
      update(thumbnail: thumbnail_path)
    else
      Rails.logger.error("Error generating thumbnail for #{location}: #{stderr}")
    end
  end

  def remove_thumbnail
    FileUtils.rm_rf(thumbnail)
  end

  def cleanup_files
    FileUtils.rm_rf(path)
  end
end
