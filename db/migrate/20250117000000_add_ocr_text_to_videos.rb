# frozen_string_literal: true

class AddOcrTextToVideos < ActiveRecord::Migration[7.1]
  def change
    add_column :videos, :ocr_text, :text
  end
end

