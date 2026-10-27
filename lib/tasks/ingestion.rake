# frozen_string_literal: true

namespace :ingestion do
  desc 'Report capture backlog, import freshness, transcription queue, and recent ingestion failures'
  task status: :environment do
    now = Time.current
    elapsed = lambda do |time|
      next 'n/a' unless time

      seconds = (now - time).to_i
      next "#{seconds}s" if seconds < 60
      next "#{seconds / 60}m" if seconds < 3600

      "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
    end

    puts 'MediaHub ingestion status'
    puts "Generated: #{now.iso8601}"
    puts
    puts format('%-4s %-18s %10s %14s %21s %12s %10s %8s',
                'ID', 'Channel', 'Temp files', 'Oldest age', 'Latest imported', 'Import age', 'Tx queue', 'Failed')
    puts '-' * 114

    Station.active.order(:id).find_each do |station|
      temp_files = CaptureStorageService.pending_directories(station).flat_map do |temp_directory|
        Dir.glob(temp_directory.join('*.mp4').to_s)
      end
      oldest_temp = temp_files.filter_map { |file| File.mtime(file) rescue nil }.min
      latest_video = station.videos.order(posted_at: :desc).first
      transcription_queue = station.videos.left_joins(:ingestion_record)
                                 .where(transcription: nil)
                                 .where('ingestion_records.status IS NULL OR ingestion_records.status IN (?)',
                                        [IngestionRecord.statuses.fetch('imported'), IngestionRecord.statuses.fetch('thumbnail_ocr')])
                                 .count
      failed_count = station.ingestion_records.failed.count

      puts format('%-4s %-18s %10d %14s %21s %12s %10d %8d',
                  station.id,
                  station.name.to_s.truncate(18),
                  temp_files.length,
                  elapsed.call(oldest_temp),
                  latest_video&.posted_at&.iso8601 || 'none',
                  elapsed.call(latest_video&.posted_at),
                  transcription_queue,
                  failed_count)
    end

    puts
    puts "Tracked stages: #{IngestionRecord.group(:status).count.sort.to_h.inspect}"
    puts "Failed records: #{IngestionRecord.failed.count}"

    IngestionRecord.failed.includes(:station).order(last_attempt_at: :desc).limit(10).each do |record|
      puts "  [#{record.station.name}] #{record.file_name} retries=#{record.retry_count}: #{record.last_error}"
    end
  end

end
