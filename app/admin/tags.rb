ActiveAdmin.register Tag do
  permit_params :name, :variations, topic_ids: []

  filter :name
  filter :variations
  
  index do
    selectable_column
    id_column
    column 'Name' do |tag|
      link_to tag.name, admin_tag_path(tag)
    end
    column :variations
    column :created_at
    column :taggings_count
    column :topics
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :variations
      f.input :topics
    end
    f.actions
  end
  
end
