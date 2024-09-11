class ChangeStreamSourceToText < ActiveRecord::Migration[7.1]
  def change
    change_column :stations, :stream_source, :text
  end
end
