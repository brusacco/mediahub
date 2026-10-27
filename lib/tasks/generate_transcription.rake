# frozen_string_literal: true

require 'open3'

desc 'Generate text transcription of video files'
task generate_transcription: :environment do
  minimum_segment_size = 1.megabyte
  batch_size = ENV.fetch('TRANSCRIPTION_CONCURRENCY', Rails.env.development? ? 1 : 4).to_i
  batch_size = 1 if batch_size < 1

  # Configuración según el entorno
  model = Rails.env.development? ? 'small' : 'medium'
  device = Rails.env.development? ? 'cpu' : 'cuda'
  compute_type = Rails.env.development? ? 'int8' : 'float16'

  videos = Video.where(transcription: nil).order(posted_at: :desc)
  videos = videos.where(id: ENV['VIDEO_ID']) if ENV['VIDEO_ID'].present?
  videos = videos.to_a.select do |video|
    video.path.present? && File.exist?(video.path) && File.size(video.path) >= minimum_segment_size
  end
  videos = videos.first(ENV['TRANSCRIPTION_LIMIT'].to_i) if ENV['TRANSCRIPTION_LIMIT'].to_i.positive?

  whisper_binary = ENV['WHISPER_CTRANSLATE2_BIN'].presence || File.expand_path('~/.local/bin/whisper-ctranslate2')
  whisper_binary = 'whisper-ctranslate2' unless File.executable?(whisper_binary)

  Parallel.each(videos, in_processes: batch_size) do |video|
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

    command = [
      whisper_binary, video.path,
      '--model', model,
      '--language', 'Spanish',
      '--output_format', 'txt',
      '--device', device,
      '--compute_type', compute_type,
      '--output_dir', directory_path.to_s
    ]

    _stdout, stderr, status = Open3.capture3(*command)

    if status.success?
      if File.exist?(output_file)
        # Normalize transcription: replace all whitespace (including newlines) with single spaces
        transcription_content = File.read(output_file).gsub(/\s+/, ' ').strip
        video.update(transcription: transcription_content)
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
