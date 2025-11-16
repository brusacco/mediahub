class VideosController < ApplicationController
  before_action :authenticate_user!

  def show
    @clip = Video.find(params[:id])
    # Use relative path for video URL (works in both development and production)
    @clip_path = "/#{@clip.public_path}"
  end
end
