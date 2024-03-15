# frozen_string_literal: true

class AddThumToVideo < ActiveRecord::Migration[7.1]
  def change
    add_column :videos, :thumbnail, :string
  end
end
