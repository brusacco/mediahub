class CreateTopicStatDailies < ActiveRecord::Migration[7.1]
  def change
    create_table :topic_stat_dailies do |t|
      t.integer :video_quantity
      t.date :topic_date
      t.references :topic, null: false, foreign_key: true

      t.timestamps
    end
  end
end
