# frozen_string_literal: true

# CLASS STATION
class Station < ApplicationRecord
  has_many :videos, dependent: :destroy

  enum stream_status: { disconnected: 0, connected: 1 }
end
