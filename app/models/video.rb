# frozen_string_literal: true

class Video < ApplicationRecord
  belongs_to :station

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id id_value location posted_at updated_at path]
  end

  def self.ransackable_associations(_auth_object = nil)
    ['station']
  end
end
