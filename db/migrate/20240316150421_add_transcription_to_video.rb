# frozen_string_literal: true

class AddTranscriptionToVideo < ActiveRecord::Migration[7.1]
  def change
    add_column :videos, :transcription, :text
  end
end
