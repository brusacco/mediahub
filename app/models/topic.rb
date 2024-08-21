# frozen_string_literal: true

class Topic < ApplicationRecord
  has_paper_trail on: [:create, :destroy, :update]
  has_many :user_topics, dependent: :destroy
  has_many :users, through: :user_topics  
  has_and_belongs_to_many :tags
  accepts_nested_attributes_for :tags
end
