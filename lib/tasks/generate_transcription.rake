# frozen_string_literal: true

require 'open3'

desc 'Generate text transcription of video files'
task generate_transcription: :environment do
  batch_size = 4
  model = 'medium'

  Parallel.each(Video.where(transcription: nil).order(posted_at: :desc), in_processes: batch_size) do |video|
    next unless File.exist?(video.path)
    
    directory_path = Rails.public_path.join('videos', video.station.directory, 'temp')
    output_file = File.join(directory_path, video.location.gsub('.mp4', '.txt'))

    puts "Transforming #{video.path} to #{output_file}"

    # Run Wisper command to generate transcription
    # command = "whisper #{video.path} --language Spanish --output_format txt --output_dir #{directory_path}"
    # command = "whisper-ctranslate2 #{video.path} --language Spanish --output_format txt --compute_type int8 --output_dir #{directory_path}"
    # command = "whisper-ctranslate2 #{video.path} --model #{model} --language Spanish --output_format txt --device cuda --compute_type float16 --vad_filter True --output_dir #{directory_path}"
    command = "whisper-ctranslate2 #{video.path} --model #{model} --language Spanish --output_format txt --device cuda --compute_type float16 --output_dir #{directory_path}"

    _stdout, stderr, status = Open3.capture3(command)

    if status.success?
      if File.exist?(output_file)
        video.update(transcription: File.read(output_file))
        FileUtils.rm(output_file)
        puts "Transcription generated for #{video.location}."
      else
        puts "Transcription file not found for #{video.location}."
      end
    else
      puts "Failed to generate transcription for #{video.location}."
      puts "Error: #{stderr}"
    end
  end
end
