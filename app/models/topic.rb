# frozen_string_literal: true

class Topic < ApplicationRecord
  has_paper_trail on: [:create, :destroy, :update]
  has_many :topic_stat_dailies, dependent: :destroy
  has_many :user_topics, dependent: :destroy
  has_many :users, through: :user_topics  
  has_and_belongs_to_many :tags
  accepts_nested_attributes_for :tags

  def list_videos
    tag_list = tags.map(&:name)
    result = Video.normal_range.tagged_with(tag_list, any: true).order(posted_at: :desc)
    Video.where(id: result.map(&:id)).joins(:station)
  end
end
