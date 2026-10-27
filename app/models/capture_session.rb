# frozen_string_literal: true

class CaptureSession < ApplicationRecord
  STATES = %w[disabled probing capturing degraded invalid_content renewing failed completed].freeze

  # See Station: MariaDB's JSON compatibility type needs an explicit coder.
  serialize :metadata, coder: JSON, type: Hash

  belongs_to :station
  has_many :capture_events, dependent: :nullify

  validates :state, inclusion: { in: STATES }
  validates :started_at, presence: true

  scope :open, -> { where(ended_at: nil) }
  scope :recent_first, -> { order(started_at: :desc) }

  def open?
    ended_at.nil?
  end
end
