# frozen_string_literal: true

namespace :dev do
  namespace :cleanup do
    # Helper method to ensure task only runs in development
    def ensure_development_only!
      unless Rails.env.development?
        puts 'ERROR: This task can only run in development environment!'
        puts "Current environment: #{Rails.env}"
        exit 1
      end
    end

    # Helper method to delete video and thumbnail files
    def delete_video_files(video)
      deleted_count = 0

      # Delete video file
      if video.path.present? && File.exist?(video.path)
        File.delete(video.path)
        deleted_count += 1
      end

      # Delete thumbnail file
      if video.thumbnail_path.present?
        thumbnail_path = Rails.root.join('public', video.thumbnail_path)
        if File.exist?(thumbnail_path)
          File.delete(thumbnail_path)
          deleted_count += 1
        end
      end

      deleted_count
    end

    desc 'Clean up all videos and video files (DEVELOPMENT ONLY)'
    task videos: :environment do
      ensure_development_only!

      puts '=' * 80
      puts 'WARNING: This will delete ALL videos and video files!'
      puts '=' * 80
      puts "Environment: #{Rails.env}"
      puts "Total videos in database: #{Video.count}"
      
      # Count files that will be deleted
      video_files_count = 0
      Video.find_each do |video|
        if video.path.present? && File.exist?(video.path)
          video_files_count += 1
        end
        if video.thumbnail_path.present?
          thumbnail_path = Rails.root.join('public', video.thumbnail_path)
          video_files_count += 1 if File.exist?(thumbnail_path)
        end
      end
      
      puts "Video files to delete: ~#{video_files_count}"
      puts '=' * 80
      print 'Are you sure you want to continue? (yes/no): '
      
      confirmation = $stdin.gets.chomp.downcase
      
      unless confirmation == 'yes'
        puts 'Cleanup cancelled.'
        exit 0
      end

      puts "\nStarting cleanup..."
      deleted_count = 0
      deleted_files = 0
      errors = []

      Video.find_each do |video|
        begin
          # Delete video and thumbnail files
          deleted_files += delete_video_files(video)

          # Delete database record
          video.destroy
          deleted_count += 1

          print '.' if deleted_count % 10 == 0
        rescue StandardError => e
          errors << "Video ID #{video.id}: #{e.message}"
        end
      end

      puts "\n\nCleanup complete!"
      puts "Deleted #{deleted_count} video records from database"
      puts "Deleted #{deleted_files} video/thumbnail files"
      
      if errors.any?
        puts "\nErrors encountered:"
        errors.each { |error| puts "  - #{error}" }
      end

      # Clean up empty directories
      puts "\nCleaning up empty directories..."
      cleanup_empty_directories
      
      # Clean up temp directories
      puts "\nCleaning up temp directories..."
      cleanup_temp_directories
      
      puts "\nDone!"
    end

    desc 'Clean up only video files (keeps DB records) (DEVELOPMENT ONLY)'
    task video_files: :environment do
      ensure_development_only!

      puts 'Cleaning up video files only (keeping database records)...'
      deleted_files = 0
      errors = []

      Video.find_each do |video|
        begin
          deleted_files += delete_video_files(video)
          print '.' if deleted_files % 10 == 0
        rescue StandardError => e
          errors << "Video ID #{video.id}: #{e.message}"
        end
      end

      puts "\n\nCleanup complete!"
      puts "Deleted #{deleted_files} video/thumbnail files"
      
      if errors.any?
        puts "\nErrors encountered:"
        errors.each { |error| puts "  - #{error}" }
      end

      cleanup_empty_directories
      cleanup_temp_directories
      puts "\nDone!"
    end

    desc 'Clean up only database records (keeps files) (DEVELOPMENT ONLY)'
    task video_records: :environment do
      ensure_development_only!

      puts 'Cleaning up video records only (keeping files)...'
      deleted_count = Video.count
      
      Video.delete_all
      
      puts "Deleted #{deleted_count} video records from database"
      puts "Done!"
    end

    desc 'Clean up temp directories (DEVELOPMENT ONLY)'
    task temp_directories: :environment do
      ensure_development_only!
      cleanup_temp_directories
      puts "Done!"
    end

    private

    def cleanup_temp_directories
      puts 'Cleaning up temp directories...'
      temp_base = Rails.root.join('public', 'videos')
      deleted_dirs = 0
      deleted_files = 0

      if Dir.exist?(temp_base)
        Station.find_each do |station|
          temp_dir = temp_base.join(station.directory, 'temp')
          if Dir.exist?(temp_dir)
            # Count files before deletion
            files = Dir.glob(temp_dir.join('*')).reject { |f| File.directory?(f) }
            deleted_files += files.count
            
            FileUtils.rm_rf(temp_dir)
            FileUtils.mkdir_p(temp_dir) # Recreate empty directory
            deleted_dirs += 1
            puts "  Cleaned temp directory for #{station.name} (#{files.count} files)" if files.count > 0
          end
        end
      end

      puts "  Cleaned #{deleted_dirs} temp directories (#{deleted_files} files total)" if deleted_dirs > 0
    end

    def cleanup_empty_directories
      videos_base = Rails.root.join('public', 'videos')
      return unless Dir.exist?(videos_base)

      cleaned = 0
      
      # Find all station directories
      Dir.glob(videos_base.join('*')).each do |station_dir|
        next unless File.directory?(station_dir)
        next if File.basename(station_dir) == 'temp' # Skip temp at root level
        
        # Clean up year/month/day directories
        Dir.glob(File.join(station_dir, '*', '*', '*')).each do |day_dir|
          next unless File.directory?(day_dir)
          
          # Check if directory is empty (except .gitkeep or similar)
          entries = Dir.entries(day_dir).reject { |e| e.start_with?('.') }
          if entries.empty?
            Dir.rmdir(day_dir)
            cleaned += 1
          end
        end
        
        # Clean up empty month directories
        Dir.glob(File.join(station_dir, '*', '*')).each do |month_dir|
          next unless File.directory?(month_dir)
          entries = Dir.entries(month_dir).reject { |e| e.start_with?('.') }
          if entries.empty?
            Dir.rmdir(month_dir)
            cleaned += 1
          end
        end
        
        # Clean up empty year directories
        Dir.glob(File.join(station_dir, '*')).each do |year_dir|
          next unless File.directory?(year_dir)
          next if File.basename(year_dir) == 'temp' # Skip temp directories
          entries = Dir.entries(year_dir).reject { |e| e.start_with?('.') }
          if entries.empty?
            Dir.rmdir(year_dir)
            cleaned += 1
          end
        end
      end
      
      puts "Cleaned up #{cleaned} empty directories" if cleaned > 0
    end
  end
end

