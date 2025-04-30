# frozen_string_literal: true

require 'open3'

desc 'Import Videos'
task import_videos: :environment do
  puts 'Importando videos...'
  Station.find_each do |station|
    begin
      Rails.logger.info "Procesando estación: #{station.name}"
      puts "Station: #{station.name}"
      directory_path = Rails.public_path.join('videos', station.directory, 'temp')
      puts "Directory path: #{directory_path}"

      # Verificar si el directorio existe
      unless Dir.exist?(directory_path)
        puts "Directorio no encontrado: #{directory_path}"
        next
      end

      Dir.glob(File.join(directory_path, '*.mp4')).each do |file|
        begin
          puts "File: #{file}"
          next if in_use?(file)

          filename = File.basename(file)
          puts "Filename: #{filename}"

          # Validar formato del nombre del archivo (ejemplo: 2025-04-25T19_45_17.mp4)
          unless filename.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}_\d{2}_\d{2}\.mp4\z/)
            puts "Nombre de archivo inválido: #{filename}"
            next
          end

          # Extraer y validar timestamp
          timestamp_str = filename.split('.')[0].gsub('_', ':')
          begin
            timestamp = Time.parse(timestamp_str)
          rescue ArgumentError
            puts "Timestamp inválido: #{timestamp_str}"
            next
          end

          # Verificar que el archivo sea un video válido
          unless valid_video?(file)
            puts "Archivo de video inválido: #{file}"
            next
          end

          # Crear o encontrar el video
          video = Video.find_or_create_by(location: filename, posted_at: timestamp, station_id: station.id) do |v|
            v.path = move_video(v, file)
            v.public_path = Pathname.new(v.path).relative_path_from(Rails.public_path).to_s
          end

          # Generar miniatura y guardar
          video.generate_thumbnail
          video.save!
          puts "Video guardado: id=#{video.id}, location=#{video.location}"
        rescue StandardError => e
          puts "Error procesando archivo #{file}: #{e.message}"
          Rails.logger.error "Error procesando archivo #{file}: #{e.message}"
        end
      end
    rescue StandardError => e
      puts "Error procesando estación #{station.name}: #{e.message}"
      Rails.logger.error "Error procesando estación #{station.name}: #{e.message}"
    end
  end
  puts 'Importación de videos completada.'
end

def move_video(video, file)
  year, month, day = video.directories
  subfolder_path = Rails.public_path.join('videos', video.station.directory, year, month, day)
  FileUtils.mkdir_p(subfolder_path)

  new_location = File.join(subfolder_path, video.location)
  if File.exist?(file)
    FileUtils.mv(file, new_location)
    Rails.logger.info "Video movido de #{file} a #{new_location}"
  else
    Rails.logger.warn "Archivo no encontrado para mover: #{file}"
  end

  new_location
end

def in_use?(file_path)
  command = "lsof -w #{file_path}"
  stdout, stderr, status = Open3.capture3(command)
  if status.success?
    !stdout.empty?
  else
    Rails.logger.warn "Error ejecutando lsof para #{file_path}: #{stderr}"
    false
  end
end

def valid_video?(file_path)
  command = "ffprobe -v error -show_streams -select_streams v:0 #{file_path}"
  _stdout, stderr, status = Open3.capture3(command)
  if status.success?
    true
  else
    Rails.logger.warn "Archivo de video inválido #{file_path}: #{stderr}"
    false
  end
end