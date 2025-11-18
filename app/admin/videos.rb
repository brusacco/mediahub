# frozen_string_literal: true

ActiveAdmin.register Video do
  permit_params :location, :posted_at, :transcription, :posted_at, :station_id

  # Set the default sort order for the index page
  config.sort_order = 'posted_at_desc'

  filter :station, label: 'Estación'
  filter :transcription_cont, label: 'Transcripción'
  filter :ocr_text_cont, label: 'Texto OCR'
  filter :tags, label: 'Etiquetas'
  filter :posted_at, as: :date_range

  scope :all
  scope :no_transcription
  scope :no_thumbnail
  scope :no_ocr_text, label: 'Sin OCR'
  scope :has_ocr_text, label: 'Con OCR'

  index do
    selectable_column
    column 'Thumb' do |video|
      image_tag "/#{video.thumbnail_path}", width: 200 unless video.thumbnail_path.nil?
    end
    column :posted_at
    column :station
    column :transcription do |video|
      if video.tag_list.present?
        highlight(video.transcription, video.all_tags_boundarys, highlighter: '<span class="highlight">\1</span>')
      else
        video.transcription
      end
    end
    column :ocr_text do |video|
      truncate(video.ocr_text, length: 100) if video.ocr_text.present?
    end
    column :tag_list
    column :created_at
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
      row 'Transcripción' do |video|
        highlight(video.transcription, video.all_tags_boundarys, highlighter: '<span class="highlight">\1</span>')
      end
      row 'Texto OCR (Zócalos)' do |video|
        if video.ocr_text.present?
          content_tag(:div, video.ocr_text, style: 'white-space: pre-wrap; background-color: #f5f5f5; padding: 10px; border-radius: 4px;')
        else
          content_tag(:span, 'No disponible', style: 'color: #999;')
        end
      end
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
