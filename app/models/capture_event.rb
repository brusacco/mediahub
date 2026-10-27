# frozen_string_literal: true

class CaptureEvent < ApplicationRecord
  serialize :metadata, coder: JSON, type: Hash

  belongs_to :station
  belongs_to :capture_session, optional: true

  validates :event_type, :occurred_at, presence: true
end
