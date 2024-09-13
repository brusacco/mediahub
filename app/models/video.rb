# frozen_string_literal: true

require 'open3'

# VIDEO CLASS
class Video < ApplicationRecord
  acts_as_taggable_on :tags
  belongs_to :station

  after_destroy :cleanup_files

  scope :no_transcription, -> { where(transcription: nil) }
  scope :no_thumbnail, -> { where(thumbnail_path: nil) }
  scope :normal_range, -> { where(posted_at: DAYS_RANGE.days.ago..) }

  def directories
    location.split('T')[0].split('-')
  end

  def generate_thumbnail
    # Set public path for thumbnail
    thumbnail_path = path.sub(/\.mp4\z/, '.png') # Change file extension to PNG
    public_thumbnail_path = public_path.sub(/\.mp4\z/, '.png') # Change file extension to PNG

    # Run ffmpeg command to generate thumbnail
    command = "ffmpeg -y -i #{path} -ss 00:00:01 -frames:v 1 -vf 'scale=500:-1' #{thumbnail_path}"
    _stdout, stderr, status = Open3.capture3(command)

    if status.success?
      update(thumbnail_path: public_thumbnail_path)
    else
      Rails.logger.error("Error generating thumbnail for #{location}: #{stderr}")
    end
  end

  private

  def remove_thumbnail
    FileUtils.rm_rf(path.sub(/\.mp4\z/, '.png'))
  end

  def cleanup_files
    FileUtils.rm_rf(path)
    remove_thumbnail
  end
end
