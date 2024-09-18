class VideosController < ApplicationController
  before_action :authenticate_user!

  def show
    @clip = Video.find(params[:id])
  end
end
