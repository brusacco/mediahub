# frozen_string_literal: true

class AddTaggingStateToVideos < ActiveRecord::Migration[7.1]
  def change
    add_column :videos, :tags_processed_at, :datetime
    add_column :videos, :tagging_error, :text
    add_column :videos, :tagging_attempts, :integer, null: false, default: 0
    add_index :videos, :tags_processed_at
  end
end
