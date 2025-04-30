# frozen_string_literal: true

require 'open3'

desc 'Generate text transcription of video files'
task generate_transcription: :environment do
  batch_size = 4
  model = 'medium'

  Parallel.each(Video.where(transcription: nil).order(posted_at: :desc), in_processes: batch_size) do |video|
    # Validar que video.path y video.location existan y sean válidos
    unless video.path && video.location && video.location.end_with?('.mp4')
      puts "Skipping invalid video: path=#{video.path}, location=#{video.location}"
      next
    end

    # Verificar que el archivo de video existe
    unless File.exist?(video.path)
      puts "Video file not found: #{video.path}"
      next
    end

    # Crear el directorio temporal si no existe
    directory_path = Rails.public_path.join('videos', video.station.directory, 'temp')
    FileUtils.mkdir_p(directory_path) unless Dir.exist?(directory_path)

    # Generar la ruta del archivo de salida
    output_file = File.join(directory_path, video.location.gsub('.mp4', '.txt'))

    puts "Transforming #{video.path} to #{output_file}"

    # generar la transcripción
    # command = "whisper-ctranslate2 #{video.path} --model #{model} --language Spanish --output_format txt --device cuda --compute_type float16 --vad_filter True --output_dir #{directory_path}"
    command = "whisper-ctranslate2 #{video.path} --model #{model} --language Spanish --output_format txt --device cuda --compute_type float16 --output_dir #{directory_path}"

    _stdout, stderr, status = Open3.capture3(command)

    if status.success?
      if File.exist?(output_file)
        video.update(transcription: File.read(output_file))
        FileUtils.rm(output_file) if File.exist?(output_file) # Limpieza segura
        puts "Transcription generated for #{video.location}"
      else
        puts "Transcription file not found for #{video.location}"
      end
    else
      puts "Failed to generate transcription for #{video.location}"
      puts "Error: #{stderr}"
    end
  rescue StandardError => e
    puts "Error processing video #{video.location}: #{e.message}"
  end
end
