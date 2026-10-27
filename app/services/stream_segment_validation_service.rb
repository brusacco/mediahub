# frozen_string_literal: true

require 'open3'

# Validates that an FFmpeg segment contains plausible broadcast material before
# it is allowed to update a channel heartbeat or enter the import pipeline.
class StreamSegmentValidationService < ApplicationService
  MINIMUM_SEGMENT_SIZE = 1.megabyte
  MINIMUM_DURATION_SECONDS = 15.0
  SAMPLE_OFFSET_SECONDS = 5.0
  COMMAND_TIMEOUT_SECONDS = 20

  # The NPY expired-session slate is a saturated blue background with white
  # text. These values are intentionally conservative and must be present in
  # every sampled frame, so normal blue lower thirds do not fail validation.
  EXPIRED_SLATE_RULE = {
    yavg_max: 80.0,
    uavg_min: 210.0,
    vavg_max: 140.0,
    satavg_min: 80.0
  }.freeze

  def initialize(path)
    super()
    @path = path.to_s
  end

  def call
    return handle_error('Segment file does not exist') unless File.file?(@path)

    size = File.size(@path)
    return handle_error("Segment is too small (#{size} bytes; minimum #{MINIMUM_SEGMENT_SIZE})") if size < MINIMUM_SEGMENT_SIZE

    duration = probe_duration
    return handle_error('Segment does not contain a valid video duration') unless duration && duration >= MINIMUM_DURATION_SECONDS

    samples = [SAMPLE_OFFSET_SECONDS, [duration - SAMPLE_OFFSET_SECONDS, SAMPLE_OFFSET_SECONDS].max].uniq
    metrics = samples.filter_map { |offset| signal_metrics(offset) }
    return handle_error('Could not inspect segment video frames') if metrics.empty?

    return handle_error('Segment is the blue expired-session slate') if metrics.all? { |sample| expired_session_slate?(sample) }

    handle_success(duration: duration, samples: metrics.length)
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
end
