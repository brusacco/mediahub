require 'open3'

desc 'Generate text transcription of video files'
task generate_transcription: :environment do
  Video.where(transcription: nil).order(posted_at: :desc).find_each do |video|
    output_file = video.location.gsub('.mp4', '.txt')

    puts "Transforming #{video.path} to #{output_file}"

    # Run Wisper command to generate transcription
    command = "whisper #{video.path} --model base --language Spanish --output_format txt"

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
