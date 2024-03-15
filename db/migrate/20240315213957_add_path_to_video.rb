class AddPathToVideo < ActiveRecord::Migration[7.1]
  def change
    add_column :videos, :path, :string
  end
end
