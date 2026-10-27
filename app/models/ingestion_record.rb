# frozen_string_literal: true

# Durable ledger for each captured segment. It is intentionally separate from
# Video because a segment must be observable before it is safe to import it.
class IngestionRecord < ApplicationRecord
  belongs_to :station
  belongs_to :video, optional: true

  enum status: {
    captured: 0,
    validated: 1,
    imported: 2,
    thumbnail_ocr: 3,
    transcribed: 4,
    failed: 5
  }

  validates :file_name, presence: true

  # Failed segments are held for diagnosis. They are retried only through an
  # explicit operator request, never by the normal minute-by-minute batch.
  scope :pending_transcription, -> { where(status: %i[imported thumbnail_ocr]) }

  def self.track_capture!(station, path)
    file_name = File.basename(path)
    record = create_or_find_by!(station: station, file_name: file_name)

    record.with_lock do
      record.source_path = path.to_s
      record.captured_at ||= File.mtime(path)
      record.save! if record.changed?
    end
    record
  rescue Errno::ENOENT
    record ||= create_or_find_by!(station: station, file_name: file_name)
    record.with_lock do
      record.source_path = path.to_s
      record.captured_at ||= Time.current
      record.save! if record.changed?
    end
    record
  end

  def self.track_video!(video)
    record = create_or_find_by!(station: video.station, file_name: video.location)
    record.with_lock do
      record.video = video
      record.source_path = video.path
      record.captured_at ||= video.posted_at || video.created_at
      unless record.transcribed? || record.failed?
        record.status = video.thumbnail_path.present? ? :thumbnail_ocr : :imported
      end
      record.save! if record.changed?
    end
    record
  end

  def mark_validated!
    advance_to!(:validated)
  end

  def mark_imported!(video)
    with_lock do
      update!(video: video, source_path: video.path, status: :imported,
              last_error: nil, last_attempt_at: Time.current)
    end
  end

  def mark_thumbnail_ocr!
    advance_to!(:thumbnail_ocr)
  end

  def mark_transcribed!
    with_lock do
      update!(status: :transcribed, last_error: nil, last_attempt_at: Time.current,
              completed_at: Time.current)
    end
  end

  def defer!(reason)
    with_lock do
      update!(last_error: reason, last_attempt_at: Time.current)
    end
  end

  def fail!(error)
    with_lock do
      update!(status: :failed, retry_count: retry_count + 1, last_error: error.to_s,
              last_attempt_at: Time.current)
    end
  end

  private

  def advance_to!(next_status)
    with_lock do
      update!(status: next_status, last_error: nil, last_attempt_at: Time.current)
    end
  end
end
