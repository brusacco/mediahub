# frozen_string_literal: true

class AddCaptureReliabilityModels < ActiveRecord::Migration[7.1]
  def change
    add_column :stations, :stream_headers, :json
    add_column :stations, :stream_url_expires_at, :datetime
    add_column :stations, :stream_candidate_url, :text
    add_column :stations, :stream_candidate_headers, :json
    add_column :stations, :stream_candidate_expires_at, :datetime
    add_column :stations, :stream_previous_url, :text
    add_column :stations, :stream_previous_headers, :json
    add_column :stations, :validation_rules, :json

    create_table :capture_sessions do |t|
      t.references :station, null: false, foreign_key: true
      t.string :state, null: false, default: 'probing'
      t.string :resolver
      t.string :source_fingerprint
      t.integer :ffmpeg_pid
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.datetime :last_valid_segment_at
      t.integer :ffmpeg_exit_code
      t.text :failure_reason
      t.json :metadata
      t.timestamps
    end
    add_index :capture_sessions, %i[station_id state]
    add_index :capture_sessions, :started_at

    create_table :capture_events do |t|
      t.references :station, null: false, foreign_key: true
      t.references :capture_session, foreign_key: true
      t.string :event_type, null: false
      t.text :reason
      t.json :metadata
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :capture_events, %i[station_id occurred_at]
    add_index :capture_events, %i[capture_session_id occurred_at]
  end
end
