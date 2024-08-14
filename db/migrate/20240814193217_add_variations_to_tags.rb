class AddVariationsToTags < ActiveRecord::Migration[7.1]
  def change
    add_column :tags, :variations, :string
  end
end
