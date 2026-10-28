# frozen_string_literal: true

require 'open3'
require 'uri'

# A resolver never replaces a working URL directly. Candidate metadata is
# persisted first, preflighted for audio/video, then promoted in one DB update.
class StreamSourcePromotionService < ApplicationService
  PREFLIGHT_TIMEOUT_SECONDS = 20

  def self.call(station, url, resolver:, headers: {})
    new(station, url, resolver: resolver, headers: headers).call
  end

  def initialize(station, url, resolver:, headers: {})
    super()
    @station = station
    @url = url.to_s
    @resolver = resolver
    @headers = headers.compact
  end

  def call
    return handle_error('Candidate stream URL is blank') if @url.blank?

    persist_candidate!
    streams = preflight_streams
    return reject_candidate!('Candidate has no video stream') unless streams.include?('video')
    return reject_candidate!('Candidate has no audio stream') unless streams.include?('audio')

    @station.with_lock do
      @station.update!(stream_previous_url: @station.stream_url,
                       stream_previous_headers: @station.stream_headers,
                       stream_url: @url, stream_headers: @headers,
                       stream_url_expires_at: inferred_expiry,
                       stream_candidate_url: nil, stream_candidate_headers: nil,
                       stream_candidate_expires_at: nil)
    end
    CaptureLifecycleService.event!(@station, @station.capture_sessions.open.recent_first.first,
                                   'source_promoted', metadata: { resolver: @resolver, streams: streams })
    handle_success(@url)
  rescue StandardError => e
    Rails.logger.warn("Could not promote stream candidate for station #{@station&.id}: #{e.class}: #{e.message}")
    handle_error(e.message)
  end

  private

  def persist_candidate!
    @station.update!(stream_candidate_url: @url, stream_candidate_headers: @headers,
                     stream_candidate_expires_at: inferred_expiry)
    CaptureLifecycleService.event!(@station, @station.capture_sessions.open.recent_first.first,
                                   'source_candidate', metadata: { resolver: @resolver })
  end

  def preflight_streams
    command = ['timeout', '--kill-after=5s', "#{PREFLIGHT_TIMEOUT_SECONDS}s", ffprobe_binary, '-v', 'error',
               '-show_entries', 'stream=codec_type', '-of', 'default=noprint_wrappers=1:nokey=1']
    command += ['-referer', @headers['Referer']] if @headers['Referer'].present?
    command += ['-user_agent', @headers['User-Agent']] if @headers['User-Agent'].present?
    command += ['-headers', "Cookie: #{@headers['Cookie']}\r\n"] if @headers['Cookie'].present?
    command << @url
    stdout, _stderr, status = Open3.capture3(*command)
    return [] unless status.success?

    stdout.lines.map(&:strip).uniq
  end

  def reject_candidate!(reason)
    @station.update!(stream_candidate_url: nil, stream_candidate_headers: nil, stream_candidate_expires_at: nil)
    CaptureLifecycleService.event!(@station, @station.capture_sessions.open.recent_first.first,
                                   'source_rejected', reason: reason, metadata: { resolver: @resolver })
    handle_error(reason)
  end

  def inferred_expiry
    uri = URI.parse(@url)
    params = URI.decode_www_form(uri.query.to_s).to_h
    epoch = params['expires'] || params['exp'] || params['expiry']
    Time.at(epoch.to_i) if epoch.to_s.match?(/\A\d{9,}\z/)
  rescue URI::InvalidURIError
    nil
  end

  def ffprobe_binary
    ENV.fetch('FFPROBE_BIN') do
      ffmpeg = ENV.fetch('FFMPEG_BIN', 'ffmpeg')
      candidate = File.join(File.dirname(ffmpeg), 'ffprobe')
      File.executable?(candidate) ? candidate : 'ffprobe'
    end
  end
end
