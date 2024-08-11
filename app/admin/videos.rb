# frozen_string_literal: true

ActiveAdmin.register Video do
  permit_params :location, :posted_at, :transcription, :posted_at, :station_id

  index do
    selectable_column
    id_column
    column :location
    column :posted_at
    column :station
    column :transcription
    actions
  end

  form do |f|
    inputs 'Details' do
      f.input :location
      f.input :posted_at
      f.input :station
      f.input :transcription
    end
    actions
  end
end
