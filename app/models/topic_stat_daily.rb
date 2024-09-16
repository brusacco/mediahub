class TopicStatDaily < ApplicationRecord
  belongs_to :topic
  scope :normal_range, -> { where(topic_date: DAYS_RANGE.days.ago..) }
end
