class TagsController < ApplicationController
  before_action :authenticate_user!

  def show
    @tag = Tag.find(params[:id])

    @videos = @tag.list_videos

    @total_videos = @videos.size
  end
end
