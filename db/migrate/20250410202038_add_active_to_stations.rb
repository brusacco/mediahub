class AddActiveToStations < ActiveRecord::Migration[7.1]
  def change
    add_column :stations, :active, :boolean, default: true
  end
end
