# frozen_string_literal: true

ActiveAdmin.register Station do
  permit_params :name, :directory, :stream_url, :stream_status, :stream_source

  filter :name
  filter :stream_status, as: :select

  index do
    column :id
    column :name
    column :directory
    tag_column :stream_status
    column :stream_source
    column :created_at
    column :updated_at
    actions
  end
end
