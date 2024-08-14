# frozen_string_literal: true

class Tagging < ApplicationRecord
  belongs_to :tag, touch: true
end
