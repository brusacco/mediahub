# frozen_string_literal: true

desc 'Extract OCR text from video thumbnails'
namespace :ocr do
  desc 'Extract OCR text from all videos without OCR text'
  task extract_all: :environment do
    puts "Starting OCR extraction for videos without OCR text..."
    puts ""
    
    # Verify ImageMagick is installed
    unless system('which convert > /dev/null 2>&1') || system('which magick > /dev/null 2>&1')
      puts "❌ ERROR: ImageMagick is not installed!"
      puts ""
      puts "Install it with:"
      puts "  Ubuntu/Debian: sudo apt-get install imagemagick"
      puts "  CentOS/RHEL:   sudo yum install ImageMagick"
      puts ""
      exit 1
    end
    
    # Verify Tesseract is installed
    unless system('which tesseract > /dev/null 2>&1')
      puts "❌ ERROR: Tesseract OCR is not installed!"
      puts ""
      puts "Install it with:"
      puts "  Ubuntu/Debian: sudo apt-get install tesseract-ocr tesseract-ocr-spa"
      puts "  CentOS/RHEL:   sudo yum install tesseract tesseract-langpack-spa"
      puts ""
      exit 1
    end
    
    puts "✅ ImageMagick: OK"
    puts "✅ Tesseract: OK"
    puts ""
    
    videos = Video.no_ocr_text.where.not(thumbnail_path: nil)
    total = videos.count
    processed = 0
    success = 0
    errors = 0
    no_file = 0
    no_text = 0

    puts "Found #{total} videos to process"
    puts ""

    videos.find_each do |video|
      processed += 1
      
      # Check if thumbnail file exists
      thumbnail_full_path = Rails.public_path.join(video.thumbnail_path)
      file_exists = File.exist?(thumbnail_full_path)
      
      unless file_exists
        no_file += 1
        print "\r[#{processed}/#{total}] Video #{video.id}: ❌ Thumbnail file not found: #{video.thumbnail_path}"
        next
      end

      # Check file size
      file_size = File.size(thumbnail_full_path)
      
      # Check if big thumbnail exists
      big_thumbnail_path = thumbnail_full_path.to_s.sub(/\.png\z/, '-big.png')
      big_exists = File.exist?(big_thumbnail_path)
      big_size = big_exists ? File.size(big_thumbnail_path) : 0
      
      print "\r[#{processed}/#{total}] Video #{video.id}: 📷 File OK (#{file_size} bytes) | Big: #{big_exists ? '✅' : '❌'}"
      
      begin
        video.extract_ocr_text
        video.reload
        
        if video.ocr_text.present?
          success += 1
          print " | ✅ OCR: #{video.ocr_text.length} chars"
        else
          no_text += 1
          print " | ⚠️  No text extracted"
        end
      rescue StandardError => e
        errors += 1
        puts "\n❌ Error processing video #{video.id}: #{e.class} - #{e.message}"
        Rails.logger.error("Error processing video #{video.id}: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
      end
    end

    puts "\n\n" + "="*60
    puts "OCR extraction completed!"
    puts "="*60
    puts "Total processed: #{processed}"
    puts "✅ Successfully extracted: #{success}"
    puts "⚠️  No text found: #{no_text}"
    puts "❌ Files not found: #{no_file}"
    puts "❌ Errors: #{errors}"
    puts ""
    
    # Show sample of extracted text if any
    if success > 0
      sample = Video.has_ocr_text.order(updated_at: :desc).first
      if sample
        puts "Sample extracted text (Video ID: #{sample.id}):"
        puts "-" * 60
        puts sample.ocr_text[0..300]
        puts "-" * 60
      end
    end
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

