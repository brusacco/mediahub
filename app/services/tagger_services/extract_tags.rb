# frozen_string_literal: true

module TaggerServices
  class ExtractTags < ApplicationService
    def initialize(video_id, tag_id = nil)
      @video_id = video_id
      @tag_id = tag_id
    end

    def call
      video = Video.find(@video_id)
      content = video.transcription
      tags_found = []

      if @tag_id.nil?
        tags = Tag.all
      else
        tags = Tag.where(id: @tag_id)
      end

      tags.each do |tag|
        tags_found << tag.name if content.match(/\b#{tag.name}\b/)
        if tag.variations
          alts = tag.variations.split(',')
          alts.each { |alt_tag| tags_found << tag.name if content.match(/\b#{alt_tag}\b/) }
        end
      end

      if tags_found.empty?
        handle_error('No tags found')
      else
        handle_success(tags_found)
      end
    rescue StandardError => e
      handle_error(e.message)
    end
  end
end
