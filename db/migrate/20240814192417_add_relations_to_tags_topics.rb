class AddRelationsToTagsTopics < ActiveRecord::Migration[7.1]
  def change
    create_table :tags_topics, id: false do |t|
      t.integer :tag_id
      t.integer :topic_id
    end
    add_index :tags_topics, :topic_id
    add_index :tags_topics, :tag_id
  end
end
