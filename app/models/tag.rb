# frozen_string_literal: true

class Tag < ApplicationRecord
  has_and_belongs_to_many :topics
  accepts_nested_attributes_for :topics

  has_many :taggings, dependent: :destroy
  validates :name, uniqueness: true

  def list_videos
    tag_list = name
    result = Video.normal_range.tagged_with(tag_list, any: true).order(posted_at: :desc)
    Video.where(id: result.map(&:id)).joins(:station)
  end


end
