# frozen_string_literal: true

ActiveAdmin.register Video do
  permit_params :location, :posted_at, :transcription, :posted_at, :station_id

  filter :station
  filter :transcription
  filter :created_at

  index do
    selectable_column
    id_column
    column :location
    column :posted_at
    column :station
    column :transcription

    # column 'Video' do |video|
    #   video(width: 320, height: 240, controls: true) do
    #     source(src: video.public_path, type: 'video/mp4')
    #   end
    # end

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

  show do |video|
    attributes_table do
      row :location
      row 'Fecha', &:posted_at
      row 'Estacion', &:station
      row :path
      row :thumbnail
      row :public_path
      row :transcription
      row :created_at
      row :updated_at
  
      row :video do |file| 
        video(width: 480, height: 320, controls: true, autobuffer: true) do
          source(src: file.public_path, type: 'video/mp4')
        end
        # video_tag url_for('https://www.youtube.com/watch?v=q1gnOM88OjU'), type: "video/mp4", controls: true, size: '480x320'
      end

    end
  end   
end
