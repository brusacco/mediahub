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

      return handle_error('No transcription') if content.blank?

      if @tag_id.nil?
        tags = Tag.all
      else
        tags = Tag.where(id: @tag_id)
      end

      return handle_error('No tags in database') if tags.empty?

      tags.each do |tag|
        pattern = build_tag_pattern(tag.name)
        if pattern && content.match?(pattern)
          tags_found << tag.name
        end
        if tag.variations.present?
          alts = tag.variations.split(',')
          alts.each do |alt_tag|
            next if alt_tag.strip.blank?
            alt_pattern = build_tag_pattern(alt_tag.strip)
            if alt_pattern && content.match?(alt_pattern)
              tags_found << tag.name
            end
          end
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

    private

    def build_tag_pattern(tag_name)
      return nil if tag_name.blank?
      
      # Escape special regex characters and search for exact tag name
      escaped_tag = Regexp.escape(tag_name.strip)
      # Build regex with word boundaries, case-sensitive (exact match)
      Regexp.new("\\b#{escaped_tag}\\b")
    end
  end
end
