# frozen_string_literal: true

class AddStationToVideo < ActiveRecord::Migration[7.1]
  def change
    add_reference :videos, :station, null: false, foreign_key: true
  end
end
