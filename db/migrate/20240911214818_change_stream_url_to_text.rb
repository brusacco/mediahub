class ChangeStreamUrlToText < ActiveRecord::Migration[7.1]
  def change
    change_column :stations, :stream_url, :text
  end
end
