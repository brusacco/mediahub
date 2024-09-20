# frozen_string_literal: true

desc 'Guardar valores diarios por topico'
task topic_stat_daily: :environment do
  topics = Topic.where(status: true)
  var_date = 7.days.ago.to_date..Date.today

  topics.each do |topic|
    puts "TOPICO: #{topic.name}"
    tag_list = topic.tags.map(&:name)
    # puts "- #{tag_list}"

    var_date.each do |day_date|
      video_quantity = Video.tagged_on_video_quantity(tag_list, day_date)

      stat = TopicStatDaily.find_or_create_by(topic_id: topic.id, topic_date: day_date)
      stat.video_quantity = video_quantity

      stat.save
      puts "#{day_date} - #{video_quantity}"
    end
    puts '-------------------------------------------------------------------------------------------------'
  end
end
