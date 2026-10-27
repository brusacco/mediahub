# frozen_string_literal: true

require 'open3'
require 'tmpdir'

# Validates that an FFmpeg segment contains plausible broadcast material before
# it is allowed to update a channel heartbeat or enter the import pipeline.
class StreamSegmentValidationService < ApplicationService
  MINIMUM_SEGMENT_SIZE = 1.megabyte
  MINIMUM_DURATION_SECONDS = 15.0
  SAMPLE_OFFSET_SECONDS = 5.0
  COMMAND_TIMEOUT_SECONDS = 20
  BLACK_FRAME_RULE = { yavg_max: 18.0, satavg_max: 18.0 }.freeze
  SILENCE_DB_MAX = -55.0

  # The NPY expired-session slate is a saturated blue background with white
  # text. These values are intentionally conservative and must be present in
  # every sampled frame, so normal blue lower thirds do not fail validation.
  EXPIRED_SLATE_RULE = {
    yavg_max: 80.0,
    uavg_min: 210.0,
    vavg_max: 140.0,
    satavg_min: 80.0
  }.freeze

  def initialize(path, station: nil)
    super()
    @path = path.to_s
    @station = station
  end

  def call
    return handle_error('Segment file does not exist') unless File.file?(@path)

    size = File.size(@path)
    return handle_error("Segment is too small (#{size} bytes; minimum #{MINIMUM_SEGMENT_SIZE})") if size < MINIMUM_SEGMENT_SIZE

    duration = probe_duration
    return handle_error('Segment does not contain a valid video duration') unless duration && duration >= MINIMUM_DURATION_SECONDS

    streams = probe_stream_types
    return handle_error('Segment does not contain a video stream') unless streams.include?('video')
    return handle_error('Segment does not contain an audio stream') if require_audio? && !streams.include?('audio')

    samples = [SAMPLE_OFFSET_SECONDS, [duration - SAMPLE_OFFSET_SECONDS, SAMPLE_OFFSET_SECONDS].max].uniq
    metrics = samples.filter_map { |offset| signal_metrics(offset) }
    if metrics.length != samples.length
      return handle_error("Could not inspect all segment video frames (#{metrics.length}/#{samples.length})")
    end

    return handle_error('Segment is the blue expired-session slate') if metrics.all? { |sample| expired_session_slate?(sample) }
    return handle_error('Segment is a black-screen slate') if reject_black_screen? && metrics.all? { |sample| black_frame?(sample) }
    return handle_error('Segment audio is silent') if reject_silence? && audio_silent?
    return handle_error('Segment video is frozen') if reject_frozen_video? && frozen_video?
    return handle_error('Segment contains a blocked on-screen phrase') if blocked_ocr_phrase?

    handle_success(duration: duration, samples: metrics.length, streams: streams)
  rescue StandardError => e
    Rails.logger.warn("Could not validate stream segment #{@path}: #{e.class}: #{e.message}")
    handle_error("Could not validate segment: #{e.message}")
  end

  private

  def probe_duration
    stdout, _stderr, status = Open3.capture3(
      'timeout', COMMAND_TIMEOUT_SECONDS.to_s,
      'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1', @path
    )
    return unless status.success?

    duration = Float(stdout.strip)
    duration.finite? ? duration : nil
  rescue ArgumentError
    nil
  end

  def probe_stream_types
    stdout, _stderr, status = Open3.capture3(
      'timeout', COMMAND_TIMEOUT_SECONDS.to_s,
      'ffprobe', '-v', 'error', '-show_entries', 'stream=codec_type',
      '-of', 'default=noprint_wrappers=1:nokey=1', @path
    )
    status.success? ? stdout.lines.map(&:strip).uniq : []
  end

  def signal_metrics(offset)
    stdout, _stderr, status = Open3.capture3(
      'timeout', COMMAND_TIMEOUT_SECONDS.to_s,
      'ffmpeg', '-v', 'error', '-ss', offset.to_s, '-i', @path,
      '-frames:v', '1', '-vf', 'scale=160:90,signalstats,metadata=print:file=-',
      '-f', 'null', '-'
    )
    return unless status.success?

    %w[YAVG UAVG VAVG SATAVG].to_h do |metric|
      value = stdout[/lavfi\.signalstats\.#{metric}=([\d.]+)/, 1]
      [metric.downcase.to_sym, Float(value)]
    end
  rescue ArgumentError, TypeError
    nil
  end

  def expired_session_slate?(sample)
    sample[:yavg] < EXPIRED_SLATE_RULE[:yavg_max] &&
      sample[:uavg] > EXPIRED_SLATE_RULE[:uavg_min] &&
      sample[:vavg] < EXPIRED_SLATE_RULE[:vavg_max] &&
      sample[:satavg] > EXPIRED_SLATE_RULE[:satavg_min]
  end

  def black_frame?(sample)
    sample[:yavg] < BLACK_FRAME_RULE[:yavg_max] && sample[:satavg] < BLACK_FRAME_RULE[:satavg_max]
  end

  def audio_silent?
    _stdout, stderr, status = Open3.capture3(
      'timeout', COMMAND_TIMEOUT_SECONDS.to_s,
      'ffmpeg', '-v', 'info', '-i', @path, '-t', '15', '-af', 'volumedetect', '-f', 'null', '-'
    )
    return false unless status.success?

    mean_volume = stderr[/mean_volume:\s*(-?[\d.]+) dB/, 1]
    mean_volume && Float(mean_volume) <= SILENCE_DB_MAX
  rescue ArgumentError
    false
  end

  def rules
    @station&.validation_rules.to_h
  end

  def require_audio?
    rules.fetch('require_audio', true)
  end

  def reject_black_screen?
    rules.fetch('reject_black_screen', true)
  end

  def reject_silence?
    rules.fetch('reject_silence', false)
  end

  def reject_frozen_video?
    rules.fetch('reject_frozen_video', true)
  end

  def frozen_video?
    _stdout, stderr, status = Open3.capture3(
      'timeout', COMMAND_TIMEOUT_SECONDS.to_s,
      'ffmpeg', '-v', 'info', '-i', @path, '-t', '20',
      '-vf', 'freezedetect=n=0.001:d=10', '-f', 'null', '-'
    )
    status.success? && stderr.include?('freeze_start:')
  end

  def blocked_ocr_phrase?
    phrases = Array(rules['blocked_ocr_phrases']).map { |phrase| phrase.to_s.downcase }.reject(&:blank?)
    return false if phrases.empty?

    Dir.mktmpdir('mediahub-validation') do |directory|
      frame = File.join(directory, 'lower-third.png')
      _stdout, _stderr, status = Open3.capture3(
        'timeout', COMMAND_TIMEOUT_SECONDS.to_s,
        'ffmpeg', '-v', 'error', '-ss', SAMPLE_OFFSET_SECONDS.to_s, '-i', @path,
        '-frames:v', '1', '-vf', 'crop=iw:ih/3:0:2*ih/3', frame
      )
      return false unless status.success? && File.file?(frame)

      ocr = OcrExtractionService.call(frame, lower_third_only: false)
      text = ocr.success? ? ocr.data.to_s.downcase : ''
      phrases.any? { |phrase| text.include?(phrase) }
    end
  rescue StandardError => e
    Rails.logger.warn("OCR validation skipped for #{@path}: #{e.class}: #{e.message}")
    false
  end
end
