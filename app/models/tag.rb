# frozen_string_literal: true

class Tag < ApplicationRecord
  has_and_belongs_to_many :topics
  accepts_nested_attributes_for :topics

  has_many :taggings, dependent: :destroy
  validates :name, uniqueness: true

  # def self.ransackable_attributes(auth_object = nil)
  #   ["created_at", "id", "id_value", "name", "taggings_count", "updated_at"]
  # end
end
