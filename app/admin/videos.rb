# frozen_string_literal: true

ActiveAdmin.register Video do
  permit_params :location, :posted_at, :transcription, :posted_at, :station_id

  filter :station
  filter :transcription_cont, label: 'Transcripción'
  filter :tags
  filter :posted_at, as: :date_range

  index do
    selectable_column
    column 'Thumb' do |video|
      image_tag "/#{video.thumbnail_path}", width: 200 unless video.thumbnail_path.nil?
    end
    column :posted_at
    column :station
    column :transcription do |video|
      if video.tag_list.present?
        all_tags = video.tags.map do |tag|
          tag_variations = tag.variations || ''
          "#{tag.name}, #{tag_variations}"
        end.split(',').flatten
        highlighted_transcription = highlight(video.transcription, all_tags, highlighter: '<span class="highlight">\1</span>')
        highlighted_transcription.html_safe
      else
        video.transcription
      end
    end
    column :tag_list
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
      row :thumbnail_path
      row "Thumbnail" do |video|
        image_tag "/#{video.thumbnail_path}", width: 500 unless video.thumbnail_path.nil?
      end
      row :public_path
      row :transcription
      row :tag_list
      row :created_at
      row :updated_at

      row :video do |file|
        video(width: 480, height: 320, controls: true, autobuffer: true) do
          source(src: root_url + file.public_path, type: 'video/mp4')
        end
      end

      # row :preview do |file|
      #   video_tag root_url+file.public_path, controls: true, size: '480x320'
      # end
    end
  end
end
