class TopicsController < ApplicationController
  before_action :authenticate_user!
  
  def show
    @topic = Topic.find(params[:id])
    return redirect_to root_path, alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario o se encuentra deshabilitado' unless @topic.users.exists?(current_user.id) && @topic.status == true

    @tag_list = @topic.tags.map(&:name)

    @videos = Video.normal_range.tagged_with(@tag_list, any: true).joins(:station).order(posted_at: :desc)
    @total_videos = @videos.size

    @word_occurrences = @videos.word_occurrences

    @all_videos = Video.normal_range.joins(:station).order(posted_at: :desc)

    if @videos.any?
      total_count = @total_videos + @all_videos.size
      @topic_percentage = (Float(@total_videos) / total_count * 100).round(0)
      @all_percentage = (Float(@all_videos.size) / total_count * 100).round(0)
    end

    @tags = @videos.tag_counts_on(:tags).order(count: :desc).limit(20)
    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }    
  end
end
