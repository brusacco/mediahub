class TopicsController < ApplicationController
  before_action :authenticate_user!
  
  def show
    @topic = Topic.find(params[:id])
    return redirect_to root_path, alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario o se encuentra deshabilitado' unless @topic.users.exists?(current_user.id) && @topic.status == true

    @tag_list = @topic.tags.map(&:name)

    @videos = @topic.list_videos
    @total_videos = @videos.size

    @word_occurrences = @videos.word_occurrences
    @bigram_occurrences = @videos.bigram_occurrences

    @tags = @videos.tag_counts_on(:tags).order(count: :desc).limit(20)
    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }    
  end
end
