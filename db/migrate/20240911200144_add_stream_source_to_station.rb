class AddStreamSourceToStation < ActiveRecord::Migration[7.1]
  def change
    add_column :stations, :stream_source, :string
  end
end
