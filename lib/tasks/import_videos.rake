# frozen_string_literal: true

desc 'Import Videos'
task import_videos: :environment do
  processed_count = 0
  error_count = 0
  error_summary = Hash.new(0)
  
  Station.find_each do |station|
    # Process files from temp directory (new recordings)
    temp_directory = Rails.public_path.join('videos', station.directory, 'temp')
    
    if Dir.exist?(temp_directory)
      Dir.glob(File.join(temp_directory, '*.mp4')).each do |file|
        result = VideoImportService.call(station, file)
        
        if result.success?
          processed_count += 1
        else
          error_count += 1
          error_type = result.error || 'Unknown error'
          error_summary[error_type] += 1
        end
      end
    end

    # Process files from organized directories (already moved videos without DB entries)
    base_directory = Rails.public_path.join('videos', station.directory)
    
    if Dir.exist?(base_directory)
      organized_files = Dir.glob(File.join(base_directory, '*', '*', '*', '*.mp4'))
      
      organized_files.each do |file|
        filename = File.basename(file)
        existing_video = Video.find_by(location: filename, station_id: station.id)
        
        if existing_video
          unless existing_video.path == file
            existing_video.update(path: file, public_path: Pathname.new(file).relative_path_from(Rails.public_path).to_s)
          end
          next
        end
          
        result = VideoImportService.call(station, file)
        
        if result.success?
          processed_count += 1
        else
          error_count += 1
          error_type = result.error || 'Unknown error'
          error_summary[error_type] += 1
        end
      end
    end
  rescue StandardError => e
    error_count += 1
    Rails.logger.error "Error processing station #{station.name}: #{e.message}"
  end
  
  Rails.logger.info "Video import completed. Processed: #{processed_count}, Errors: #{error_count}"
  if error_summary.any?
    Rails.logger.info "Error breakdown:"
    error_summary.each { |error_type, count| Rails.logger.info "  - #{error_type}: #{count}" }
  end
end