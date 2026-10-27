# frozen_string_literal: true

desc 'Mark failed videos for review without deleting their records or media'
task remove_fail_videos: :environment do
  puts 'Marcando videos fallidos para revisión...'
  marked_count = 0
  unchanged_count = 0
  threshold = 12.hours.ago

  Video.find_each do |video|
    reason = if video.location.blank? || !video.location.end_with?('.mp4')
               'Invalid video location'
             elsif video.path.blank?
               'Video path is missing'
             elsif video.created_at <= threshold && video.transcription.blank?
               'No transcription after 12 hours'
             end
    next unless reason

    record = IngestionRecord.track_video!(video)
    if record.failed? && record.last_error == reason
      unchanged_count += 1
      next
    end

    record.fail!(reason)
    marked_count += 1
    puts "Video marcado como fallido: id=#{video.id}, location=#{video.location}, reason=#{reason}"
  rescue StandardError => e
    puts "Error marcando video ID: #{video.id}, location: #{video.location} - #{e.message}"
  end

  held_transcription_failures = IngestionRecord.failed.where.not(video_id: nil).count
  puts "#{marked_count} videos marcados como fallidos; #{unchanged_count} ya estaban marcados"
  puts "#{held_transcription_failures} fallos con video retenidos para revisión; no se reintentarán automáticamente"
end
