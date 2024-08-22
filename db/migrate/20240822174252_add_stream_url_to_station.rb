class AddStreamUrlToStation < ActiveRecord::Migration[7.1]
  def change
    add_column :stations, :stream_url, :string
  end
end
