# frozen_string_literal: true

class AddLogToStations < ActiveRecord::Migration[7.1]
  def change
    add_column :stations, :log, :text
  end
end

