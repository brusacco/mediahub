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
    whisper_command = lambda do |batch, batched:, worker_batch_size:|
      [
        whisper_binary,
        *batch.map { |input| input[:input_path].to_s },
        '--model', model,
        '--language', 'Spanish',
        '--output_format', 'txt',
        '--device', device,
        '--compute_type', compute_type,
        '--batched', batched.to_s,
        '--batch_size', worker_batch_size.to_s,
        '--output_dir', work_directory.to_s
      ]
    end
    transcription_for = lambda do |input|
      output_files = [work_directory.join("#{input[:video].id}.txt"), work_directory.join("#{input[:video].id}.mp4.txt")]
      output_file = output_files.find { |path| File.file?(path) }
      output_file ? File.read(output_file).gsub(/\s+/, ' ').strip : nil
    end
    successful = 0
    failed = 0

    # Keep a malformed media file from poisoning every pending clip. The
    # worker still performs GPU inference in batches of eight, but a failed
    # batch is isolated to one-clip retries so only the actual bad input is
    # held for review.
    inputs.each_slice(batch_size) do |batch|
      _stdout, stderr, status = Open3.capture3(*whisper_command.call(batch, batched: true, worker_batch_size: batch_size))

      batch.each do |input|
        video = input[:video]
        ingestion_record = input[:ingestion_record]
        transcription = status.success? ? transcription_for.call(input) : nil

        if transcription.present?
          video.update!(transcription: transcription)
          ingestion_record.mark_transcribed!
          successful += 1
          puts "Transcription generated for #{video.location}"
          next
        end

        # Retry each missing result separately. This also yields an actionable
        # error instead of the same opaque batch-level error on every record.
        _single_stdout, single_stderr, single_status = Open3.capture3(
          *whisper_command.call([input], batched: false, worker_batch_size: 1)
        )
        transcription = transcription_for.call(input) if single_status.success?
        if transcription.present?
          video.update!(transcription: transcription)
          ingestion_record.mark_transcribed!
          successful += 1
          puts "Transcription generated after isolated retry for #{video.location}"
        else
          diagnostic = (single_status.success? ? stderr : single_stderr).to_s.strip.last(2_000)
          error = "Whisper produced no transcription after isolated retry: #{diagnostic.presence || 'no output file'}"
          ingestion_record.fail!(error)
          failed += 1
          puts "Failed to generate transcription for #{video.location}"
        end
      rescue StandardError => e
        ingestion_record.fail!("Transcription exception: #{e.message}")
        failed += 1
        puts "Error processing video #{video.location}: #{e.message}"
      end
    end

    puts "Batch transcription completed. Successful: #{successful}, Failed: #{failed}"
  ensure
    FileUtils.rm_rf(work_directory)
  end
end
