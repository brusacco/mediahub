# frozen_string_literal: true

ActiveAdmin.register Video do
  permit_params :location, :posted_at

  index do
    selectable_column
    id_column
    column :location
    column :posted_at
    column :station
    column :transcription
    actions
  end
end
