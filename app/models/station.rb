# frozen_string_literal: true

# CLASS STATION
class Station < ApplicationRecord
  has_many :videos, dependent: :destroy
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
end
