# frozen_string_literal: true

require 'uri'

# CLASS STATION
class Station < ApplicationRecord
  # MariaDB reports JSON columns as LONGTEXT to this Rails adapter. Explicit
  # coders keep request headers and validation rules valid JSON on disk.
  serialize :stream_headers, coder: JSON, type: Hash
  serialize :stream_candidate_headers, coder: JSON, type: Hash
  serialize :stream_previous_headers, coder: JSON, type: Hash
  serialize :validation_rules, coder: JSON, type: Hash

  has_many :videos, dependent: :destroy
  has_many :ingestion_records, dependent: :destroy
  has_many :capture_sessions, dependent: :destroy
  has_many :capture_events, dependent: :destroy
  has_one_attached :logo
  
  enum stream_status: { disconnected: 0, connected: 1 }

  scope :active, -> { where(active: true) }
  scope :needs_attention, -> { active.where(stream_status: :disconnected) }
  scope :healthy, -> { active.where(stream_status: :connected).where('last_heartbeat_at > ?', 3.minutes.ago) }
  scope :stale_heartbeat, -> { active.where(stream_status: :connected).where('last_heartbeat_at < ? OR last_heartbeat_at IS NULL', 3.minutes.ago) }

  # Check if station is healthy (connected and recent heartbeat)
  def healthy?
    active? && connected? && heartbeat_recent?
  end

  # Check if heartbeat is recent (within last 3 minutes)
  def heartbeat_recent?(threshold_minutes: 3)
    return false unless last_heartbeat_at.present?
    last_heartbeat_at > threshold_minutes.minutes.ago
  end

  # Check if station needs attention (disconnected or stale heartbeat)
  def needs_attention?
    return false unless active?
    disconnected? || stale_heartbeat?
  end

  # Check if heartbeat is stale
  def stale_heartbeat?(threshold_minutes: 3)
    return true if last_heartbeat_at.nil?
    last_heartbeat_at < threshold_minutes.minutes.ago
  end

  # Update heartbeat timestamp
  def update_heartbeat!
    update_column(:last_heartbeat_at, Time.current)
  end

  def current_capture_session
    capture_sessions.open.recent_first.first
  end

  def capture_health
    return :paused unless active?
    return :healthy if healthy?
    return :renewing if current_capture_session&.state == 'renewing'

    :attention
  end

  def latest_valid_segment_at
    current_capture_session&.last_valid_segment_at || capture_sessions.maximum(:last_valid_segment_at)
  end

  def pending_ingestion_count
    ingestion_records.where(status: %i[captured validated imported thumbnail_ocr]).count
  end

  def recent_capture_issue
    return if healthy?

    current_capture_session&.failure_reason.presence || capture_events.where.not(reason: [nil, '']).order(occurred_at: :desc).pick(:reason)
  end

  def redacted_stream_url
    redact_url(stream_url)
  end

  def sanitized_log
    log.to_s.gsub(%r{https?://[^\s]+}) { |url| redact_url(url) }
  end

  # Logging methods
  MAX_LOG_SIZE = 10_000 # Keep last 10,000 characters

  # Add a log entry with timestamp
  def add_log_entry(message, level: :info)
    timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S')
    log_entry = "[#{timestamp}] [#{level.to_s.upcase}] #{message}\n"
    
    current_log = log || ''
    new_log = current_log + log_entry
    
    # Truncate if too long, keeping the most recent entries
    if new_log.length > MAX_LOG_SIZE
      new_log = new_log[-MAX_LOG_SIZE..-1]
      # Find first newline to avoid cutting in the middle of a log entry
      first_newline = new_log.index("\n")
      new_log = new_log[first_newline + 1..-1] if first_newline
    end
    
    update_column(:log, new_log)
  end

  # Clear the log
  def clear_log!
    update_column(:log, nil)
  end

  # Get recent log entries (last N lines)
  def recent_log_entries(lines: 50)
    return [] unless log.present?
    log.split("\n").last(lines)
  end

  private

  def redact_url(url)
    uri = URI.parse(url.to_s)
    return '[sin URL]' if uri.host.blank?
    "#{uri.scheme}://#{uri.host}#{uri.path}?[token oculto]"
  rescue URI::InvalidURIError
    '[URL no legible]'
  end
end
