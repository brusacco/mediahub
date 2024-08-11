# frozen_string_literal: true

class Topic < ApplicationRecord
  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id id_value name status updated_at]
  end
end
