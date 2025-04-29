# frozen_string_literal: true

desc 'Remove videos without transcription and older than...'
task remove_fail_videos: :environment do
  puts 'Eliminando videos fallidos...'
  deleted_count = 0

  # Consulta para videos con transcription: nil, location/path vacíos o location inválida, creados hace más de...
  fail_videos = Video.where(created_at: ..18.hours.ago)
                     .where('transcription IS NULL OR location IS NULL OR location = ? OR path IS NULL OR path = ? OR location NOT LIKE ?', '', '', '%.mp4')

  fail_videos.find_each do |video|
    begin
      video.destroy
      deleted_count += 1
      puts "Video eliminado: id=#{video.id}, location=#{video.location}"
    rescue StandardError => e
      puts "Error eliminando video ID: #{video.id}, location: #{video.location} - #{e.message}"
    end
  end

  puts "#{deleted_count} videos eliminados"
end
