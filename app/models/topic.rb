# frozen_string_literal: true

class Topic < ApplicationRecord
  has_and_belongs_to_many :tags
  accepts_nested_attributes_for :tags

  # def self.ransackable_attributes(_auth_object = nil)
  #   %w[created_at id id_value name status updated_at]
  # end
end
