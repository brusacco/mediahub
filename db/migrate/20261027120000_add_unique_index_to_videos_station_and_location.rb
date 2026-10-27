# frozen_string_literal: true

class AddUniqueIndexToVideosStationAndLocation < ActiveRecord::Migration[7.1]
  def change
    add_index :videos, %i[station_id location], unique: true
  end
end
