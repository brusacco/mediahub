class TagsController < ApplicationController
  before_action :authenticate_user!

  def show
    @tag = Tag.find(params[:id])

    @videos = @tag.list_videos

    @total_videos = @videos.size

    @tags = @videos.tag_counts_on(:tags).order(count: :desc).limit(20)
    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }

    @word_occurrences = @videos.word_occurrences
    @bigram_occurrences = @videos.bigram_occurrences    
  end

  def videos_by_date
    date = Date.parse(params[:date]) rescue nil
    tag_id = params[:tag_id]
    
    if date && tag_id
      tag = Tag.find(tag_id)
      videos = tag.list_videos.where(posted_at: date.beginning_of_day..date.end_of_day)
      
      render partial: 'tags/videos_list', locals: { videos: videos, date: date }
    else
      render html: '<p class="text-gray-500">No se encontraron clips para esta fecha.</p>'.html_safe
    end
  end
end
