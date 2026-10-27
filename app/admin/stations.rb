# frozen_string_literal: true

ActiveAdmin.register Station do
  permit_params :name, :directory, :stream_url, :stream_status, :stream_source, :logo, :active,
                :play_button_selector, :use_shadow_dom

  scope :all, default: true
  scope('Saludables') { |scope| scope.healthy }
  scope('Requieren atención') { |scope| scope.needs_attention }
  scope('Pausadas') { |scope| scope.where(active: false) }

  filter :name
  filter :active
  filter :stream_status, as: :select
  filter :last_heartbeat_at

  index title: 'Control de canales' do
    selectable_column
    column('Canal') { |station| link_to station.name, admin_station_path(station) }
    column('Salud') do |station|
      state_class = { healthy: 'status--success', renewing: 'status--progress', paused: 'status--warning', attention: 'status--error' }.fetch(station.capture_health)
      status_tag station.capture_health.to_s.humanize, class: state_class
    end
    column('Último segmento válido') { |station| station.latest_valid_segment_at || 'Aún no recibido' }
    column('Sesión') { |station| station.current_capture_session&.state&.humanize || 'Sin sesión activa' }
    column('Backlog') do |station|
      count = station.pending_ingestion_count
      status_tag(count.zero? ? 'Al día' : "#{count} pendiente#{count == 1 ? '' : 's'}", class: count.zero? ? 'status--success' : 'status--progress')
    end
    column('Atención') { |station| truncate(station.recent_capture_issue.to_s, length: 90).presence || '—' }
    column('Activo') { |station| status_tag(station.active? ? 'Sí' : 'No', class: station.active? ? 'status--success' : 'status--neutral') }
    actions
  end

  form do |f|
    f.inputs 'Identidad' do
      f.input :name
      f.input :logo, as: :file
      f.input :directory, hint: 'No cambiar después de iniciar captura.'
      f.input :active, label: 'Habilitado para captura'
    end
    f.inputs 'Fuente y descubrimiento' do
      f.input :stream_source, label: 'Página pública', hint: 'Se usa para renovar la playlist.'
      f.input :stream_url, label: 'Playlist temporal actual', hint: 'No pegar una URL expirada.'
      f.input :play_button_selector, hint: 'Selector CSS opcional para Play.'
      f.input :use_shadow_dom
    end
    f.actions
  end

  show title: :name do |station|
    columns do
      column do
        panel 'Estado operativo' do
          attributes_table_for station do
            row('Salud') do
              state_class = { healthy: 'status--success', renewing: 'status--progress', paused: 'status--warning', attention: 'status--error' }.fetch(station.capture_health)
              status_tag station.capture_health.to_s.humanize, class: state_class
            end
            row('Captura habilitada') { station.active? ? 'Sí' : 'No' }
            row('Último segmento válido') { station.latest_valid_segment_at || 'Aún no recibido' }
            row('Último heartbeat') { station.last_heartbeat_at || '—' }
            row('Backlog') { station.pending_ingestion_count }
            row('Motivo de atención') { station.recent_capture_issue || '—' }
          end
        end
      end
      column do
        panel 'Fuente' do
          attributes_table_for station do
            row('Página pública') { link_to station.stream_source, station.stream_source, target: '_blank', rel: 'noopener' if station.stream_source.present? }
            row('Playlist actual') { code station.redacted_stream_url }
            row('Expira') { station.stream_url_expires_at || 'No informado' }
            row('Selector Play') { station.play_button_selector.presence || 'No requiere' }
          end
        end
      end
    end

    panel 'Sesión actual' do
      session = station.current_capture_session
      if session
        attributes_table_for session do
          row :state; row :resolver; row :started_at; row :last_valid_segment_at; row :failure_reason; row :ffmpeg_exit_code
          row('Señal FFmpeg') { session.metadata.to_h['ffmpeg_signal'].presence || '—' }
          row('Diagnóstico FFmpeg') { session.metadata.to_h['ffmpeg_diagnostic'].presence || '—' }
          row('Últimas líneas FFmpeg') do
            lines = Array(session.metadata.to_h['ffmpeg_stderr_tail']).last(12)
            lines.any? ? pre(lines.join("\n")) : '—'
          end
        end
      else
        para 'No hay sesión activa.'
      end
    end

    panel 'Eventos recientes' do
      table_for station.capture_events.order(occurred_at: :desc).limit(12) do
        column('Hora', &:occurred_at)
        column('Evento', &:event_type)
        column('Motivo') { |event| event.reason.presence || '—' }
      end
    end

    panel 'Log reciente (URLs sanitizadas)' do
      pre station.sanitized_log.presence || 'No hay entradas en el log aún.'
      link_to 'Limpiar log', clear_log_admin_station_path(station), method: :post, class: 'button', data: { confirm: '¿Limpiar el log de este canal?' }
    end
  end

  member_action :clear_log, method: :post do
    resource.clear_log!
    redirect_to admin_station_path(resource), notice: 'Log limpiado exitosamente'
  end
end
