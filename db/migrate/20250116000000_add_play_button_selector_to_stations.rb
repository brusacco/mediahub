# frozen_string_literal: true

class AddPlayButtonSelectorToStations < ActiveRecord::Migration[7.1]
  def change
    add_column :stations, :play_button_selector, :string
  end
end

