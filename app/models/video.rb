# frozen_string_literal: true

require 'open3'

# VIDEO CLASS
class Video < ApplicationRecord
  include VideoAnalysis

  acts_as_taggable_on :tags
  belongs_to :station

  after_destroy :cleanup_files

  scope :no_transcription, -> { where(transcription: nil) }
  scope :has_transcription, -> { where.not(transcription: nil) }
  scope :no_thumbnail, -> { where(thumbnail_path: nil) }
  scope :no_ocr_text, -> { where(ocr_text: nil).or(where(ocr_text: '')) }
  scope :has_ocr_text, -> { where.not(ocr_text: nil).where.not(ocr_text: '') }
  scope :normal_range, -> { where(posted_at: DAYS_RANGE.days.ago..) }

  def directories
    location.split('T')[0].split('-')
  end

  def generate_thumbnail
    # Set public path for thumbnail
    thumbnail_path = path.sub(/\.mp4\z/, '.png') # Change file extension to PNG
    big_thumbnail_path = path.sub(/\.mp4\z/, '-big.png') # Change file extension to PNG
    public_thumbnail_path = public_path.sub(/\.mp4\z/, '.png') # Change file extension to PNG

    # Run ffmpeg command to generate thumbnail
    command = "ffmpeg -y -i #{path} -ss 00:00:01 -frames:v 1 -vf 'scale=500:-1' #{thumbnail_path}"
    _stdout, stderr, status = Open3.capture3(command)

    if status.success?
      update(thumbnail_path: public_thumbnail_path)
      # Extract OCR text from thumbnail (focus on lower thirds/zócalos)
      extract_ocr_text
    else
      Rails.logger.error("Error generating thumbnail for #{location}: #{stderr}")
    end

    # Run ffmpeg command to generate BIG thumbnail
    command = "ffmpeg -y -i #{path} -ss 00:00:01 -frames:v 1 #{big_thumbnail_path}"
    _stdout, _stderr, _status = Open3.capture3(command)
  end

  def extract_ocr_text
    return unless thumbnail_path.present?

    thumbnail_full_path = Rails.public_path.join(thumbnail_path)
    return unless File.exist?(thumbnail_full_path)

    # Try to use big thumbnail if available (better quality for OCR)
    big_thumbnail_path = thumbnail_full_path.to_s.sub(/\.png\z/, '-big.png')
    image_path = File.exist?(big_thumbnail_path) ? big_thumbnail_path : thumbnail_full_path.to_s

    result = OcrExtractionService.call(image_path, lower_third_only: true)
    if result.success?
      update(ocr_text: result.data) if result.data.present?
    else
      Rails.logger.error("Error extracting OCR text for #{location}: #{result.error}")
    end
  rescue StandardError => e
    Rails.logger.error("Error in extract_ocr_text for #{location}: #{e.message}")
  end

  def all_tags
    all_tags = []
    tags.each do |tag|
      all_tags << tag.name
      tag.variations.split(',').each do |variation|
        all_tags << variation
      end
    end
    all_tags.uniq
  end

  def all_tags_boundarys
    all_tags = []
    tags.each do |tag|
      all_tags << /\b(#{tag.name})\b/i
      tag.variations.split(',').each do |variation|
        all_tags << /\b(#{variation})\b/i
      end
    end
    all_tags.uniq
  end

  private

  def remove_thumbnail
    return if thumbnail_path.blank?

    thumbnail_full_path = Rails.public_path.join(thumbnail_path)
    FileUtils.rm_rf(thumbnail_full_path) if File.exist?(thumbnail_full_path)
  end

  def cleanup_files
    return if path.blank?

    FileUtils.rm_rf(path)
    remove_thumbnail
  end

  # For TopicStatDaily
  scope :tagged_date, ->(date) { where(['videos.posted_at >= ? AND videos.posted_at <= ?', date, date + 1]) }

  def self.tagged_on_video_quantity(tag, date)
    tagged_with(tag, any: true).tagged_date(date).size
  end
end
