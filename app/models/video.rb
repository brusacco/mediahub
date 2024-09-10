# frozen_string_literal: true

require 'open3'

# VIDEO CLASS
class Video < ApplicationRecord
  acts_as_taggable_on :tags
  belongs_to :station

  after_destroy :cleanup_files

  # def self.ransackable_attributes(_auth_object = nil)
  #   %w[created_at id id_value location posted_at updated_at path public_path transcription thumbnail]
  # end

  # def self.ransackable_associations(_auth_object = nil)
  #   ['station']
  # end

  def directories
    location.split('T')[0].split('-')
  end

  def generate_thumbnail
    thumbnail_path = path.sub(/\.mp4\z/, '.png') # Change file extension to PNG
    public_thumbnail_path = public_path.sub(/\.mp4\z/, '.png') # Change file extension to PNG

    # Run ffmpeg command to generate thumbnail
    command = "ffmpeg -i #{path} -ss 00:00:01 -frames:v 1 #{thumbnail_path}"
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
