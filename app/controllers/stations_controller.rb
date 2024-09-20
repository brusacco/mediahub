class StationsController < ApplicationController
  before_action :authenticate_user!

  def show
    if params[:name].present?
      @station = Station.find_by(name: params[:name]) 
    elsif params[:id].present?
      @station = Station.find(params[:id])
    end

    @clips = Video.normal_range.where(station: @station)
    @total_clips = @clips.size
  end



end
