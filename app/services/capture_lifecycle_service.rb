# frozen_string_literal: true

require 'digest'

# Persists the operational history that Station#stream_status alone cannot
# express. Raw signed URLs are never written to the event log.
class CaptureLifecycleService
  def self.start!(station, resolver:, source_url: nil)
    station.with_lock do
      station.capture_sessions.open.update_all(
        state: 'failed', ended_at: Time.current,
        failure_reason: 'Superseded by a new capture owner', updated_at: Time.current
      )
      session = station.capture_sessions.create!(
        state: 'probing', resolver: resolver, started_at: Time.current,
        source_fingerprint: fingerprint(source_url), metadata: {}
      )
      event!(station, session, 'session_started', metadata: { resolver: resolver })
      session
    end
  end

  def self.transition!(session, state, reason: nil, metadata: {})
    raise ArgumentError, "Unknown capture state: #{state}" unless CaptureSession::STATES.include?(state.to_s)

    session.update!(state: state, failure_reason: reason.presence || session.failure_reason,
                    metadata: session.metadata.to_h.merge(metadata))
    event!(session.station, session, "state_#{state}", reason: reason, metadata: metadata)
    session
  end

  def self.valid_segment!(session, path:, validation: {})
    now = Time.current
    session.update!(state: 'capturing', last_valid_segment_at: now)
    session.station.update_columns(stream_status: Station.stream_statuses[:connected], last_heartbeat_at: now, updated_at: now)
    event!(session.station, session, 'valid_segment', metadata: validation.merge(file_name: File.basename(path)))
  end

  def self.finish!(session, state:, reason: nil, exit_code: nil, metadata: {})
    return unless session

    event_metadata = { state: state, exit_code: exit_code }.merge(metadata)
    session.update!(state: state, ended_at: Time.current, failure_reason: reason,
                    ffmpeg_exit_code: exit_code, metadata: session.metadata.to_h.merge(metadata))
    event!(session.station, session, 'session_finished', reason: reason,
           metadata: event_metadata)
  end

  def self.event!(station, session, event_type, reason: nil, metadata: {})
    event = CaptureEvent.create!(station: station, capture_session: session, event_type: event_type,
                                 reason: reason, metadata: metadata, occurred_at: Time.current)
    Rails.logger.info({ component: 'capture', station_id: station.id, capture_session_id: session&.id,
                        event: event_type, reason: reason, metadata: metadata }.to_json)
    event
  end

  def self.fingerprint(url)
    return if url.blank?

    Digest::SHA256.hexdigest(url.to_s)
  end
end
