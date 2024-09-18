class VideosController < ApplicationController
  before_action :authenticate_user!

  def show
    @clip = Video.find(params[:id])

    host = 'https://www.mediahub.com.py/'
    @clip_path = host + @clip.public_path
  end
end
