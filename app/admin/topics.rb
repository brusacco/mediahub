# frozen_string_literal: true

ActiveAdmin.register Topic do
  permit_params :name, :status, tag_ids: []

  filter :name
  filter :status

  index do
    selectable_column
    id_column

    column 'Name' do |topic|
      link_to topic.name, admin_topic_path(topic)
    end

    column :tags

    column :status
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :name
      row :tags
      row :status
      row :created_at
      row :updated_at
    end
  end

  form html: { enctype: 'multipart/form-data', multipart: true } do |f|
    columns do
      column do
        f.inputs 'Crear Tópico', multipart: true do
          f.input :name
          f.input :tags, as: :tags
          f.input :status
        end
      end
    end

    f.actions
  end
end
