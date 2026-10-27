# frozen_string_literal: true

ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc { I18n.t('active_admin.dashboard') }
  content title: 'Centro de operaciones' do
    stations = Station.order(:name)
    attention = stations.select(&:needs_attention?)
    pending_statuses = %i[captured validated imported thumbnail_ocr]
    pending_records = IngestionRecord.where(status: pending_statuses)
    failed_records = IngestionRecord.failed

    div class: 'admin-operations' do
    columns do
      column do
        panel 'Canales' do
          para "#{Station.active.count} activos de #{Station.count} configurados"
          para status_tag("#{Station.healthy.count} saludables", class: 'status--success')
          para status_tag("#{attention.count} requieren atención", class: attention.empty? ? 'status--success' : 'status--error')
          para link_to('Abrir control de canales', admin_stations_path, class: 'button')
        end
      end

      column do
        panel 'Procesamiento' do
          para "#{pending_records.count} segmentos pendientes"
          para "#{IngestionRecord.pending_transcription.count} en cola de transcripción"
          para status_tag("#{failed_records.count} para revisión", class: failed_records.empty? ? 'status--success' : 'status--error')
          para link_to('Abrir cola de ingestión', admin_ingestion_records_path, class: 'button')
        end
      end

      column do
        panel 'Última actividad' do
          latest_segment = CaptureSession.maximum(:last_valid_segment_at)
          latest_import = Video.maximum(:created_at)
          para "Segmento válido: #{latest_segment || 'sin datos'}"
          para "Video importado: #{latest_import || 'sin datos'}"
          para link_to('Ver control de canales', admin_stations_path, class: 'button')
        end
      end
    end

    panel 'Canales que requieren atención' do
      if attention.any?
        table_for attention do
          column('Canal') { |station| link_to station.name, admin_station_path(station) }
          column('Situación') { |station| status_tag station.capture_health.to_s.humanize, class: 'status--error' }
          column('Último segmento válido', &:latest_valid_segment_at)
          column('Motivo') { |station| station.recent_capture_issue || 'Sin detalle' }
          column('Acción') { |station| link_to 'Ver diagnóstico', admin_station_path(station) }
        end
      else
        para 'Todos los canales activos están reportando un heartbeat reciente.'
      end
    end

    panel 'Eventos de captura recientes' do
      events = CaptureEvent.includes(:station).order(occurred_at: :desc).limit(10)
      if events.any?
        table_for events do
          column('Hora', &:occurred_at)
          column('Canal') { |event| link_to event.station.name, admin_station_path(event.station) }
          column('Evento', &:event_type)
          column('Detalle') { |event| event.reason.presence || '—' }
        end
      else
        para 'Aún no hay eventos de captura registrados.'
      end
    end
    end
  end
end
