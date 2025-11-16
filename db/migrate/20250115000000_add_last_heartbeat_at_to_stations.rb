# frozen_string_literal: true

class AddLastHeartbeatAtToStations < ActiveRecord::Migration[7.1]
  def change
    add_column :stations, :last_heartbeat_at, :datetime
    add_index :stations, :last_heartbeat_at
  end
end





