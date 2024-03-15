# frozen_string_literal: true

class Station < ApplicationRecord
  has_many :videos

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at directory id id_value name updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    ['videos']
  end
end
