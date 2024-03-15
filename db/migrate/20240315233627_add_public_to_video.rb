class AddPublicToVideo < ActiveRecord::Migration[7.1]
  def change
    add_column :videos, :public_path, :string
  end
end
