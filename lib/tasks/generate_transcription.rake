# frozen_string_literal: true

require 'open3'

desc 'Generate text transcription of video files'
task generate_transcription: :environment do
  batch_size = 8
  model = 'medium'

  Parallel.each(Video.where(transcription: nil).order(posted_at: :desc), in_processes: batch_size) do |video|
    directory_path = Rails.public_path.join('videos', video.station.directory, 'temp')
    output_file = File.join(directory_path, video.location.gsub('.mp4', '.txt'))

    puts "Transforming #{video.path} to #{output_file}"

    # Run Wisper command to generate transcription
    # command = "whisper #{video.path} --language Spanish --output_format txt --output_dir #{directory_path}"
    # command = "whisper-ctranslate2 #{video.path} --language Spanish --output_format txt --compute_type int8 --output_dir #{directory_path}"
    command = "whisper-ctranslate2 #{video.path} --model #{model} --language Spanish --output_format txt --device cuda --compute_type int8 --vad_filter True --output_dir #{directory_path}"

    _stdout, stderr, status = Open3.capture3(command)

    if status.success?
      # Update the transcription field in the Video model
      video.update(transcription: File.read(output_file))

      # Delete the output file
      FileUtils.rm(output_file)

      puts "Transcription generated for #{video.location}."
    else
      puts "Failed to generate transcription for #{video.location}: #{stderr}"
    end
  end
end
