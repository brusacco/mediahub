# frozen_string_literal: true

desc 'Remove videos without transcription and older than...'
task remove_fail_videos: :environment do
  puts 'Eliminando videos fallidos...'
  fail_videos = Video.where(transcription: nil, created_at: ..36.hours.ago)
  deleted_count = 0

  begin
    fail_videos.find_each do |video|
      video.destroy
      deleted_count += 1
    end
  rescue StandardError => e
    puts "Error eliminando video ID: #{video.id} - #{e.message}"
  end

  puts "#{deleted_count} videos eliminados"
end
