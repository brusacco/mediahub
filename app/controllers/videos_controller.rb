class VideosController < ApplicationController
  before_action :authenticate_user!

  def show
    @clip = Video.find(params[:id])
    # Use relative path for video URL (works in both development and production)
    @clip_path = "/#{@clip.public_path}"
    
    # Get timeline videos: 3 before and 3 after the current video
    # Videos from the same station, ordered chronologically by posted_at
    station_videos = Video.where(station_id: @clip.station_id)
                         .order(posted_at: :asc)
                         .to_a
    
    current_index = station_videos.index(@clip)
    
    if current_index
      start_index = [0, current_index - 3].max
      end_index = [station_videos.length - 1, current_index + 3].min
      @related_videos = station_videos[start_index..end_index] || []
      @current_index_in_related = current_index - start_index
    else
      @related_videos = []
      @current_index_in_related = 0
    end
  end
end
