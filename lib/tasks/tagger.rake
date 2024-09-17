desc 'Tagger'
task tagger: :environment do
  Video.where(posted_at: 3.months.ago..Time.current).find_each do |video|
    result = TaggerServices::ExtractTags.call(video.id)
    next unless result.success?

    video.tag_list = result.data
    host = 'https://www.mediahub.com.py/'
    url = host + video.public_path
    puts url
    puts video.location
    puts video.posted_at
    puts video.tag_list
    puts '---------------------------------------------------'

    video.save!
  rescue StandardError => e
    video.update(tag_list: nil)
    puts e.message
    retry
  end
end
