class TopicsController < ApplicationController
  before_action :authenticate_user!
  
  def show
    @topic = Topic.find(params[:id])
    return redirect_to root_path, alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario o se encuentra deshabilitado' unless @topic.users.exists?(current_user.id) && @topic.status == true

    @tag_list = @topic.tags.map(&:name)

    @videos = Video.normal_range.joins(:station).order(id: :desc).limit(5)
    @total_videos = @videos.size
  end
end
