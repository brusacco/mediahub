desc 'Generate Video Thumbs'
task generate_thumbs: :environment do
  #Video.where(thumbnail_path: nil).find_each do |video|
  Video.find_each do |video|
    puts "Generating thumbnail for #{video.location}"
    video.generate_thumbnail
  end
end
