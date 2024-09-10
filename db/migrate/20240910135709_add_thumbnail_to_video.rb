class AddThumbnailToVideo < ActiveRecord::Migration[7.1]
  def change
    add_column :videos, :thumbnail_path, :string
  end
end
