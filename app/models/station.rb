# frozen_string_literal: true

# CLASS STATION
class Station < ApplicationRecord
  has_many :videos, dependent: :destroy
  has_one_attached :logo
  
  enum stream_status: { disconnected: 0, connected: 1 }

  scope :active, -> { where(active: true) }
end
