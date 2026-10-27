class VideosController < ApplicationController
  before_action :authenticate_user!

  def show
    @clip = Video.find(params[:id])
    # Use relative path for video URL (works in both development and production)
    @clip_path = "/#{@clip.public_path}"
    
    # Load only the immediate broadcast context. Loading the station's full
    # archive here made the most-used clip page progressively slower.
    preceding = @clip.station.videos.where('posted_at < ?', @clip.posted_at)
                     .order(posted_at: :desc).limit(3).to_a.reverse
    following = @clip.station.videos.where('posted_at > ?', @clip.posted_at)
                     .order(posted_at: :asc).limit(3).to_a

    @related_videos = preceding + [@clip] + following
  end
end
