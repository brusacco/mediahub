# frozen_string_literal: true

class CreateTopics < ActiveRecord::Migration[7.1]
  def change
    create_table :topics do |t|
      t.string :name
      t.boolean :status, default: true, null: false

      t.timestamps
    end
  end
end
