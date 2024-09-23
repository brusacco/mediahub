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

    @word_occurrences = @clips.word_occurrences
    @bigram_occurrences = @clips.bigram_occurrences

    @tags = @clips.tag_counts_on(:tags).order(count: :desc).limit(20)
    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }    
  end
end
