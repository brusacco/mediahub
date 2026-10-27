# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'uri'

namespace :stream do
  desc 'Listen to a single station stream'
  task :listen_station, [:station_id] => :environment do |_t, args|
    station_id = args[:station_id]&.to_i

    unless station_id
      puts 'Error: station_id is required'
      puts 'Usage: rake stream:listen_station[STATION_ID]'
      exit 1
    end

    station = Station.find_by(id: station_id)

    unless station
      puts "Error: Station with ID #{station_id} not found"
      exit 1
    end

    unless station.active?
      puts "Station #{station.name} (ID: #{station.id}) is not active, exiting"
      exit 0
    end

    lock_path = Rails.root.join('tmp', 'locks', "capture-station-#{station.id}.lock")
    FileUtils.mkdir_p(lock_path.dirname)
    capture_lock = File.open(lock_path, File::RDWR | File::CREAT, 0o644)
    unless capture_lock.flock(File::LOCK_EX | File::LOCK_NB)
      puts "Station #{station.id} already has a capture owner; exiting"
      exit 0
    end

    update_station_from_worker = lambda do |attributes|
      ActiveRecord::Base.connection_pool.with_connection do
        Station.where(id: station_id).update_all(attributes.merge(updated_at: Time.current))
      end
    end

    # Keep signal handling deliberately minimal. Active Record calls from a
    # signal trap can deadlock while another thread owns a connection, which
    # leaves systemd waiting until TimeoutStopSec expires.
    shutdown = false
    ffmpeg_pid = nil
    %w[INT TERM HUP QUIT].each do |signal|
      Signal.trap(signal) do
        shutdown = true
        Process.kill('TERM', ffmpeg_pid) if ffmpeg_pid
        exit 0
      end
    end

    retry_count = 0
    max_retries = 10
    base_retry_delay = 5 # seconds
    loop do
      break if shutdown

      begin
        puts "[#{Time.current}] Connecting to station #{station.name} (ID: #{station.id})"
        station.add_log_entry("Iniciando conexión a la estación")
        
        # Reload station to get latest stream_url
        station.reload
        
        unless station.stream_url.present?
          error_msg = "No hay stream_url configurado"
          Rails.logger.error("Station #{station.id} has no stream_url")
          station.add_log_entry(error_msg, level: :error)
          station.update(stream_status: :disconnected)
          sleep base_retry_delay
          retry_count += 1
          next
        end

        # Define the base target directory
        base_directory = CaptureStorageService.staging_directory(station)
        FileUtils.mkdir_p(base_directory)

        # A transport connection is not enough to call a channel healthy: some
        # broadcasters return an error slate as a valid video stream. The
        # heartbeat worker marks the station connected only after it sees a
        # complete segment of a plausible size.
        station.update(stream_status: :disconnected, last_heartbeat_at: nil)
        capture_session = CaptureLifecycleService.start!(station, resolver: ENV.fetch('STREAM_DISCOVERY_METHOD', 'legacy'), source_url: station.stream_url)
        CaptureLifecycleService.transition!(capture_session, 'capturing')
        station.add_log_entry("Esperando un segmento válido para confirmar conexión")

        # Construct the ffmpeg command optimized for audio quality (critical for transcription)
        output_pattern = base_directory.join('%Y-%m-%dT%H_%M_%S.mp4').to_s
        command = [
          # Keep the system FFmpeg as the default. A listener can opt into a
          # side-by-side canary build with FFMPEG_BIN=/absolute/path/ffmpeg
          # without replacing /usr/bin/ffmpeg for Rails or other channels.
          ENV.fetch('FFMPEG_BIN', 'ffmpeg'),
          # These are input/protocol options and must be placed before `-i`.
          # Putting them after the input makes FFmpeg apply them to the output
          # (or ignore them), leaving HLS discontinuities and reconnects
          # insufficiently handled.
          '-fflags', '+genpts+discardcorrupt',
          '-analyzeduration', '10000000',
          '-probesize', '10000000',
          '-rw_timeout', '30000000', # 30 seconds in microseconds
          '-reconnect', '1',
          '-reconnect_at_eof', '1',
          '-reconnect_streamed', '1',
          '-reconnect_delay_max', '10',
          *ffmpeg_request_headers(station),
          '-i', station.stream_url,

          '-flags', '+global_header',

          # Audio codec settings - PRIORITY: High quality for transcription
          # HLS broadcasters can emit non-monotonic audio timestamps. Rebase
          # them before encoding so libavcodec never receives backward PTS.
          '-af', 'aresample=async=1:first_pts=0',
          '-c:a', 'aac',
          '-aac_coder', 'fast',
          '-b:a', '256k',           # High bitrate for better audio quality (was 128k)
          '-ar', '48000',           # Higher sample rate for better voice clarity (was 44100)
          '-ac', '2',               # Stereo audio (better for voice separation)
          # `fast` is deliberately explicit: do not fall back to the older
          # two-loop AAC search on malformed/discontinuous live inputs.
          
          # Video codec and quality settings (secondary priority)
          '-c:v', 'libx264',
          '-preset', 'veryfast',    # Faster preset to save CPU for audio processing
          '-crf', '25',             # Slightly lower video quality to prioritize audio
          '-profile:v', 'high',
          '-level', '4.0',
          '-maxrate', '1500k',      # Reduced video bitrate to allow more bandwidth for audio
          '-bufsize', '4000k',
          
          # Video scaling
          '-vf', 'scale=1024:-2:flags=lanczos',
          
          # Segmentation settings
          '-f', 'segment',
          '-segment_time', '60',
          '-segment_format', 'mp4',
          '-reset_timestamps', '1',
          '-strftime', '1',
          '-g', '60',
          '-keyint_min', '60',
          
          # MP4 optimization
          '-movflags', '+faststart',
          
          output_pattern
        ]

        Rails.logger.info("Starting FFmpeg for station #{station.id}: #{command.join(' ')}")
        station.add_log_entry("Iniciando FFmpeg con URL: #{station.redacted_stream_url}")

        # Track last file modification time for heartbeat
        connection_started_at = Time.current
        last_file_time = nil
        consecutive_invalid_segments = 0
        heartbeat_thread = nil
        disconnection_detected = false
        termination_reason = nil
        ffmpeg_stderr_tail = []
        ffmpeg_stderr_mutex = Mutex.new

        # Use popen3 to read stderr in real-time
        Open3.popen3(*command) do |stdin, _stdout, stderr, wait_thr|
          # Close stdin as we don't need to send input
          stdin.close
          ffmpeg_pid = wait_thr.pid

          # Start heartbeat monitoring thread
          heartbeat_thread = Thread.new do
            loop do
              sleep 30 # Check every 30 seconds
              break if shutdown

              segment_files = Dir.glob(base_directory.join('*.mp4').to_s).sort_by { |file| File.mtime(file) }
              # Files from a listener that ended earlier can remain in temp/.
              # They are not evidence that this FFmpeg process ever received
              # media, and must not suppress its initial-segment timeout.
              current_segment_files = segment_files.select do |file|
                File.mtime(file) >= connection_started_at
              end
              # The newest file can still be being written. Validate the last
              # completed segment instead, so a partial file cannot create a
              # false heartbeat.
              completed_file = current_segment_files[-2]

              # A process can keep an HLS connection open without ever
              # delivering its first completed segment. The previous stale
              # segment check only ran after a file existed, leaving this
              # state stuck in `capturing` forever. Treat it as a failed
              # initial heartbeat and let the outer loop renew the source.
              unless completed_file && File.exist?(completed_file)
                if Time.current - connection_started_at > 180
                  warning_msg = 'No se generó ningún segmento válido en 3 minutos, posible conexión estancada'
                  Rails.logger.warn("No initial segment generated for station #{station.id} in 3 minutes")
                  station.add_log_entry(warning_msg, level: :warn)
                  update_station_from_worker.call(
                    stream_status: Station.stream_statuses[:disconnected],
                    last_heartbeat_at: nil
                  )
                  disconnection_detected = true
                  termination_reason = warning_msg
                  Process.kill('TERM', wait_thr.pid) if wait_thr.alive?
                  break
                end

                next
              end

              if completed_file && File.exist?(completed_file)
                file_time = File.mtime(completed_file)

                ingestion_record = IngestionRecord.track_capture!(station, completed_file)
                validation = StreamSegmentValidationService.call(completed_file, station: station)

                unless validation.success?
                  consecutive_invalid_segments += 1
                  warning_msg = "Segmento inválido detectado: #{validation.error}"
                  Rails.logger.warn("Invalid segment for station #{station.id}: #{warning_msg}")
                  ingestion_record.fail!("Capture validation failed: #{validation.error}")
                  CaptureLifecycleService.transition!(capture_session, 'invalid_content', reason: validation.error)
                  FileUtils.rm_f(completed_file)

                  if consecutive_invalid_segments >= 2
                    station.add_log_entry(warning_msg, level: :error)
                    rollback_promoted_source(station, capture_session, warning_msg)
                    update_station_from_worker.call(stream_status: Station.stream_statuses[:disconnected], last_heartbeat_at: nil)
                    disconnection_detected = true
                    termination_reason = warning_msg
                    Process.kill('TERM', wait_thr.pid) if wait_thr.alive?
                    break
                  end
                  next
                end

                consecutive_invalid_segments = 0
                ingestion_record.mark_validated! if ingestion_record.captured? || ingestion_record.failed?
                if last_file_time.nil? || file_time > last_file_time
                  CaptureLifecycleService.valid_segment!(capture_session, path: completed_file, validation: validation.data || {})
                  last_file_time = file_time
                  if retry_count.positive?
                    station.add_log_entry("Conexión estabilizada; reiniciando contador de reintentos")
                    retry_count = 0
                  end
                  Rails.logger.debug("Validated heartbeat for station #{station.id} from #{File.basename(completed_file)}")
                end

                # If no new valid file in 3 minutes, consider disconnected
                if Time.current - file_time > 180
                  warning_msg = "No se generó nuevo archivo en 3 minutos, posible desconexión"
                  Rails.logger.warn("No new file generated for station #{station.id} in 3 minutes, may be disconnected")
                  station.add_log_entry(warning_msg, level: :warn)
                  update_station_from_worker.call(
                    stream_status: Station.stream_statuses[:disconnected],
                    last_heartbeat_at: nil
                  )
                  disconnection_detected = true
                  termination_reason = warning_msg
                  # FFmpeg can keep its transport connection open while no
                  # usable segments are produced. Stop it so the outer loop
                  # refreshes the manifest and reconnects instead of leaving
                  # a stale channel marked as connected.
                  Process.kill('TERM', wait_thr.pid) if wait_thr.alive?
                  break
                end
              end
            end
          end

          # Monitor stderr for errors in real-time
          stderr_thread = Thread.new do
            stderr.each_line do |line|
              break if shutdown
              
              line = sanitize_ffmpeg_diagnostic(line.chomp)
              ffmpeg_stderr_mutex.synchronize do
                ffmpeg_stderr_tail << line
                ffmpeg_stderr_tail.shift while ffmpeg_stderr_tail.size > 20
              end
              Rails.logger.debug("FFmpeg[#{station.id}]: #{line}")

              # Check for disconnection patterns
              if line.match?(%r{Connection refused|Server returned|Network is unreachable|HTTP error \d+|Unable to open|Connection timed out|Failed to resolve|Name or service not known}i)
                error_msg = "Desconexión detectada: #{line}"
                Rails.logger.error("Disconnection detected for station #{station.id}: #{line}")
                station.add_log_entry(error_msg, level: :error)
                disconnection_detected = true
                termination_reason = error_msg
                update_station_from_worker.call(stream_status: Station.stream_statuses[:disconnected], last_heartbeat_at: nil)
                Process.kill('TERM', wait_thr.pid) if wait_thr.alive?
                break
              end

              # Check for end of stream
              if line.match?(%r{End of file|Input/output error|Streaming ended}i)
                # `-reconnect_at_eof` is an input option. A live HLS playlist
                # can legitimately emit "Will reconnect … error=End of file"
                # between playlist windows. Let FFmpeg perform that recovery;
                # terminating it here turns every normal reconnect into a
                # fleet-wide disconnect.
                if line.match?(/Will reconnect/i)
                  Rails.logger.info("FFmpeg reconnecting station #{station.id}: #{line}")
                  station.add_log_entry("FFmpeg reconectando fuente: #{line}", level: :info)
                  next
                end

                warning_msg = "Stream finalizado: #{line}"
                Rails.logger.warn("Stream ended for station #{station.id}: #{line}")
                station.add_log_entry(warning_msg, level: :warn)
                disconnection_detected = true
                termination_reason = warning_msg
                update_station_from_worker.call(stream_status: Station.stream_statuses[:disconnected])
                Process.kill('TERM', wait_thr.pid) if wait_thr.alive?
                break
              end
            end
          rescue IOError
            # systemd can close the pipe while terminating the process group.
            # A shutdown is already in progress; no diagnostic work is safe
            # or useful from this background reader at that point.
            raise unless shutdown
          end

          # Wait for FFmpeg process to finish
          exit_status = wait_thr.value

          # Clean up threads
          heartbeat_thread&.kill
          stderr_thread&.kill
          diagnostic_lines = ffmpeg_stderr_mutex.synchronize { ffmpeg_stderr_tail.dup }
          diagnostic = ffmpeg_diagnostic_summary(diagnostic_lines)

          # Log FFmpeg exit status
          if exit_status.signaled?
            signal = exit_status.termsig
            message = "FFmpeg terminó por señal #{signal}#{termination_reason ? ": #{termination_reason}" : ''}"
            termination_reason ||= "FFmpeg detenido por señal #{signal}: #{diagnostic || 'sin detalle adicional'}"
            station.add_log_entry(message, level: disconnection_detected ? :warn : :error)
            Rails.logger.warn("FFmpeg for station #{station.id} received signal #{signal}: #{termination_reason}")
          elsif exit_status.success?
            station.add_log_entry("FFmpeg terminó exitosamente (exit status: #{exit_status.exitstatus})")
          elsif disconnection_detected
            station.add_log_entry("FFmpeg terminó por desconexión detectada (exit status: #{exit_status.exitstatus})", level: :warn)
          else
            exit_code = exit_status.exitstatus || 'no informado'
            error_msg = "FFmpeg terminó inesperadamente (código #{exit_code}): #{diagnostic || 'FFmpeg no entregó detalle en stderr'}"
            termination_reason = error_msg
            Rails.logger.error("FFmpeg exited with status #{exit_code} for station #{station.id}: #{diagnostic}")
            station.add_log_entry(error_msg, level: :error)
            station.update(stream_status: :disconnected, last_heartbeat_at: nil)
          end
          CaptureLifecycleService.finish!(capture_session, state: shutdown ? 'completed' : 'failed',
                                          reason: termination_reason || (disconnection_detected ? 'FFmpeg disconnection' : nil),
                                          exit_code: exit_status.exitstatus,
                                          metadata: { ffmpeg_diagnostic: diagnostic,
                                                      ffmpeg_signal: (exit_status.termsig if exit_status.signaled?),
                                                      ffmpeg_stderr_tail: diagnostic_lines.last(12) })
        end

        # If we get here, FFmpeg has stopped
        unless shutdown
          station.update(stream_status: :disconnected)
          station.add_log_entry("Estado actualizado a desconectado")
        end

        # Try to update stream URL if source is available
        if station.stream_source.present? && !shutdown
          Rails.logger.info("Attempting to update stream URL for station #{station.id}")
          station.add_log_entry("Intentando actualizar stream URL desde fuente")
          begin
            CaptureLifecycleService.transition!(capture_session, 'renewing') if capture_session
            Rake::Task['stream:update_stream_url'].reenable
            Rake::Task['stream:update_stream_url'].invoke(station.id)
            station.reload
            station.add_log_entry("Stream URL actualizado exitosamente")
          rescue StandardError => e
            error_msg = "Error al actualizar stream URL: #{e.message}"
            Rails.logger.error("Failed to update stream URL for station #{station.id}: #{e.message}")
            station.add_log_entry(error_msg, level: :error)
          end
        end

        # Calculate retry delay with exponential backoff
        if retry_count < max_retries && !shutdown
          retry_delay = [base_retry_delay * (2**retry_count), 60].min
          retry_msg = "Reintentando conexión en #{retry_delay} segundos (intento #{retry_count + 1}/#{max_retries})"
          puts "Station #{station.name} disconnected, retrying in #{retry_delay} seconds... (attempt #{retry_count + 1}/#{max_retries})"
          station.add_log_entry(retry_msg, level: :warn)
          sleep retry_delay
          retry_count += 1
        elsif retry_count >= max_retries
          error_msg = "Se alcanzó el máximo de reintentos (#{max_retries}), deteniendo proceso"
          Rails.logger.error("Max retries reached for station #{station.id}, giving up")
          station.add_log_entry(error_msg, level: :error)
          break
        end

      rescue StandardError => e
        error_msg = "Error procesando estación: #{e.message}"
        Rails.logger.error("Error processing station #{station.id}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        station.add_log_entry(error_msg, level: :error)
        station.add_log_entry("Backtrace: #{e.backtrace.first(3).join('; ')}", level: :error)
        station.update(stream_status: :disconnected, last_heartbeat_at: nil)
        
        unless shutdown
          retry_delay = [base_retry_delay * (2**retry_count), 60].min
          sleep retry_delay
          retry_count += 1
        end
      end
    end

    capture_lock.flock(File::LOCK_UN)
    capture_lock.close

    puts "Exiting stream listener for station #{station.name} (ID: #{station.id})"
  end
end

def ffmpeg_request_headers(station)
  headers = station.stream_headers.to_h
  options = []
  options += ['-referer', headers['Referer']] if headers['Referer'].present?
  options += ['-user_agent', headers['User-Agent']] if headers['User-Agent'].present?
  options += ['-headers', "Cookie: #{headers['Cookie']}\r\n"] if headers['Cookie'].present?
  options
end

def rollback_promoted_source(station, capture_session, reason)
  return if station.stream_previous_url.blank?

  station.with_lock do
    station.update!(stream_url: station.stream_previous_url,
                    stream_headers: station.stream_previous_headers,
                    stream_previous_url: nil, stream_previous_headers: nil)
  end
  CaptureLifecycleService.event!(station, capture_session, 'source_rolled_back', reason: reason)
  station.add_log_entry('La nueva fuente fue revertida después de dos segmentos inválidos', level: :warn)
rescue StandardError => e
  Rails.logger.error("Could not roll back source for station #{station.id}: #{e.message}")
end

# Persist a small, redacted FFmpeg tail. Stream URLs and request credentials
# must not reappear in the admin after the resolver has refreshed a source.
def sanitize_ffmpeg_diagnostic(line)
  line.to_s
      .gsub(%r{https?://[^\s'\"]+}) do |url|
        uri = URI.parse(url)
        "#{uri.scheme}://#{uri.host}#{uri.path}?[token oculto]"
      rescue URI::InvalidURIError
        '[URL no legible]'
      end
      .gsub(/(cookie|authorization):\s*[^\s]+/i, '\\1: [oculto]')
end

def ffmpeg_diagnostic_summary(lines)
  candidates = lines.reverse.find do |line|
    line.match?(%r{error|failed|invalid|unable|timed out|refused|not found|forbidden|denied|end of file|i/o}i)
  end
  (candidates || lines.last).to_s.strip.presence
end

