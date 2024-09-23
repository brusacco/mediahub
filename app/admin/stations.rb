# frozen_string_literal: true

ActiveAdmin.register Station do
  permit_params :name, :directory, :stream_url, :stream_status, :stream_source, :logo

  filter :name
  filter :stream_status, as: :select

  form do |f|
    f.inputs 'Estaciones' do
      f.input :name, label:'Nombre'
      f.input :logo, as: :file
      f.input :directory
      f.input :stream_url
      f.input :stream_status
      f.input :stream_source
    end

    f.actions
  end

  index do
    column :id
    column 'Logo' do |file|
      link_to image_tag(file.logo, width: 100), admin_station_path(file) if file.logo.present?
    end
    column :name
    column :directory
    tag_column :stream_status
    column :stream_source
    column :created_at
    column :updated_at
    actions
  end

  show do |station|
    attributes_table do
      row 'Nombre', &:name
      row 'Logo' do |file|
        image_tag(file.logo, width: 250) if file.logo.present?
      end
      row :name
      row :directory
      row :stream_status
      row :stream_source
      row :created_at
      row :updated_at
    end
  end

end
