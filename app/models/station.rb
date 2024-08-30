# frozen_string_literal: true

# CLASS STATION
class Station < ApplicationRecord
  has_many :videos, dependent: :destroy

  enum stream_status: { disconnected: 0, connected: 1 }

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at directory id id_value name updated_at stream_url stream_status]
  end

  def self.ransackable_associations(_auth_object = nil)
    ['videos']
  end
end
