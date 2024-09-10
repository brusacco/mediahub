# frozen_string_literal: true

ActiveAdmin.register Station do
  permit_params :name, :directory, :stream_url, :stream_status

  filter :name
  filter :stream_status, as: :select

  index do
    column :id
    column :name
    column :directory
    column :stream_status do |station|
      status_tag(station.stream_status)
    end
    column :created_at
    column :updated_at
  end
end
