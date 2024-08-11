# frozen_string_literal: true

class Topic < ApplicationRecord
  acts_as_taggable_on :tags
end
