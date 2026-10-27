# frozen_string_literal: true

class CreateIngestionRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :ingestion_records do |t|
      t.references :station, null: false, foreign_key: true
      t.references :video, foreign_key: true
      t.string :file_name, null: false
      t.string :source_path
      t.datetime :captured_at
      t.integer :status, null: false, default: 0
      t.integer :retry_count, null: false, default: 0
      t.text :last_error
      t.datetime :last_attempt_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :ingestion_records, %i[station_id file_name], unique: true
    add_index :ingestion_records, :status
  end
end
