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
end
