# frozen_string_literal: true

class CreateVideos < ActiveRecord::Migration[7.1]
  def change
    create_table :videos do |t|
      t.string :location
      t.datetime :posted_at

      t.timestamps
    end
  end
end
