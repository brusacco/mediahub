# frozen_string_literal: true

desc 'Extract OCR text from video thumbnails'
namespace :ocr do
  desc 'Extract OCR text from all videos without OCR text'
  task extract_all: :environment do
    puts "Starting OCR extraction for videos without OCR text..."
    
    videos = Video.no_ocr_text.where.not(thumbnail_path: nil)
    total = videos.count
    processed = 0
    success = 0
    errors = 0

    videos.find_each do |video|
      processed += 1
      print "\rProcessing #{processed}/#{total} videos... (#{success} success, #{errors} errors)"

      begin
        video.extract_ocr_text
        success += 1 if video.reload.ocr_text.present?
      rescue StandardError => e
        errors += 1
        Rails.logger.error("Error processing video #{video.id}: #{e.message}")
      end
    end

    puts "\n\nOCR extraction completed!"
    puts "Total processed: #{processed}"
    puts "Successfully extracted: #{success}"
    puts "Errors: #{errors}"
  end

  desc 'Extract OCR text from videos in date range'
  task :extract_range, %i[start_date end_date] => :environment do |_t, args|
    start_date = Date.parse(args[:start_date]) if args[:start_date]
    end_date = Date.parse(args[:end_date]) if args[:end_date]

    unless start_date && end_date
      puts "Usage: rake ocr:extract_range[start_date,end_date]"
      puts "Example: rake ocr:extract_range[2024-01-01,2024-01-31]"
      exit
    end

    puts "Extracting OCR text from videos between #{start_date} and #{end_date}..."

    videos = Video.where(posted_at: start_date.beginning_of_day..end_date.end_of_day)
                  .where.not(thumbnail_path: nil)
    total = videos.count
    processed = 0
    success = 0
    errors = 0

    videos.find_each do |video|
      processed += 1
      print "\rProcessing #{processed}/#{total} videos... (#{success} success, #{errors} errors)"

      begin
        video.extract_ocr_text
        success += 1 if video.reload.ocr_text.present?
      rescue StandardError => e
        errors += 1
        Rails.logger.error("Error processing video #{video.id}: #{e.message}")
      end
    end

    puts "\n\nOCR extraction completed!"
    puts "Total processed: #{processed}"
    puts "Successfully extracted: #{success}"
    puts "Errors: #{errors}"
  end

  desc 'Re-extract OCR text from all videos (force update)'
  task re_extract_all: :environment do
    puts "Re-extracting OCR text from all videos with thumbnails..."
    
    videos = Video.where.not(thumbnail_path: nil)
    total = videos.count
    processed = 0
    success = 0
    errors = 0

    videos.find_each do |video|
      processed += 1
      print "\rProcessing #{processed}/#{total} videos... (#{success} success, #{errors} errors)"

      begin
        video.extract_ocr_text
        success += 1 if video.reload.ocr_text.present?
      rescue StandardError => e
        errors += 1
        Rails.logger.error("Error processing video #{video.id}: #{e.message}")
      end
    end

    puts "\n\nOCR re-extraction completed!"
    puts "Total processed: #{processed}"
    puts "Successfully extracted: #{success}"
    puts "Errors: #{errors}"
  end
end

