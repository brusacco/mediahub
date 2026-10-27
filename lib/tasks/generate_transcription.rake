# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'securerandom'

desc 'Generate text transcription of video files in GPU batches'
task generate_transcription: :environment do
  minimum_segment_size = 1.megabyte
  batch_size = ENV.fetch('TRANSCRIPTION_BATCH_SIZE', ENV.fetch('TRANSCRIPTION_CONCURRENCY', Rails.env.development? ? 1 : 8)).to_i
  batch_size = 1 if batch_size < 1

  model = Rails.env.development? ? 'small' : 'medium'
  device = Rails.env.development? ? 'cpu' : 'cuda'
  compute_type = Rails.env.development? ? 'int8' : 'float16'

  retry_failed = ENV['RETRY_FAILED'].to_s == '1' || ENV['VIDEO_ID'].present?
  videos = Video.where(transcription: nil).includes(:ingestion_record).order(posted_at: :desc)
  videos = videos.where(id: ENV['VIDEO_ID']) if ENV['VIDEO_ID'].present?
  unless retry_failed
    videos = videos.reject { |video| video.ingestion_record&.failed? }
  end
  videos = videos.to_a.select do |video|
    video.path.present? && File.exist?(video.path) && File.size(video.path) >= minimum_segment_size
  end
  videos = videos.first(ENV['TRANSCRIPTION_LIMIT'].to_i) if ENV['TRANSCRIPTION_LIMIT'].to_i.positive?

  if videos.empty?
    held_failures = IngestionRecord.failed.where.not(video_id: nil).count
    puts "No videos pending transcription#{"; #{held_failures} failed segment(s) held for review" if held_failures.positive?}"
    next
  end

  whisper_binary = ENV['WHISPER_CTRANSLATE2_BIN'].presence || File.expand_path('~/.local/bin/whisper-ctranslate2')
  whisper_binary = 'whisper-ctranslate2' unless File.executable?(whisper_binary)

  # Several stations can create a clip with the same timestamp. Whisper names
  # outputs from the input basename, so database ids avoid collisions in the
  # shared output directory used by the batched worker.
  work_directory = Rails.root.join('tmp', 'transcription_batches', SecureRandom.uuid)
  FileUtils.mkdir_p(work_directory)
  inputs = []

  begin
    videos.each do |video|
      ingestion_record = IngestionRecord.track_video!(video)
      input_path = work_directory.join("#{video.id}.mp4")
      File.symlink(video.path, input_path)
      inputs << { video: video, ingestion_record: ingestion_record, input_path: input_path }
    rescue StandardError => e
      ingestion_record&.fail!("Could not prepare transcription input: #{e.message}")
      puts "Skipping #{video.location}: #{e.message}"
    end

    if inputs.empty?
      puts 'No valid inputs could be prepared for transcription'
      next
    end

    puts "Transcribing #{inputs.length} video(s) with #{model} in GPU batches of #{batch_size}"
    command = [
      whisper_binary,
      *inputs.map { |input| input[:input_path].to_s },
      '--model', model,
      '--language', 'Spanish',
      '--output_format', 'txt',
      '--device', device,
      '--compute_type', compute_type,
      '--batched', 'True',
      '--batch_size', batch_size.to_s,
      '--output_dir', work_directory.to_s
    ]

    _stdout, stderr, status = Open3.capture3(*command)
    successful = 0
    failed = 0

    inputs.each do |input|
      video = input[:video]
      ingestion_record = input[:ingestion_record]
      output_files = [work_directory.join("#{video.id}.txt"), work_directory.join("#{video.id}.mp4.txt")]
      output_file = output_files.find { |path| File.exist?(path) }
      transcription = output_file ? File.read(output_file).gsub(/\s+/, ' ').strip : nil
      if status.success? && transcription.present?
        video.update!(transcription: transcription)
        ingestion_record.mark_transcribed!
        successful += 1
        puts "Transcription generated for #{video.location}"
      else
        error = if status.success? && transcription.blank?
                  "Whisper batch produced an empty transcription (outputs: #{Dir.glob(work_directory.join('*').to_s).map { |path| File.basename(path) }.join(', ')})"
                else
                  "Whisper batch failed or did not produce output: #{stderr.to_s.strip}"
                end
        ingestion_record.fail!(error)
        failed += 1
        puts "Failed to generate transcription for #{video.location}"
      end
    rescue StandardError => e
      ingestion_record.fail!("Transcription exception: #{e.message}")
      failed += 1
      puts "Error processing video #{video.location}: #{e.message}"
    end

    puts "Batch transcription completed. Successful: #{successful}, Failed: #{failed}"
  ensure
    FileUtils.rm_rf(work_directory)
  end
end
