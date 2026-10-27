# frozen_string_literal: true

# Operational ledger for captured files. It is deliberately read-only: retrying
# a failed transcription remains an explicit processing operation, not a UI
# side effect.
ActiveAdmin.register IngestionRecord do
  actions :index, :show

  scope :all, default: true
  scope('Pendientes') { |scope| scope.where(status: %i[captured validated imported thumbnail_ocr]) }
  scope('En transcripción') { |scope| scope.pending_transcription }
  scope :failed
  scope :transcribed

  filter :station
  filter :status, as: :select, collection: IngestionRecord.statuses.keys
  filter :file_name
  filter :captured_at
  filter :last_attempt_at

  index title: 'Cola de ingestión' do
    column('Canal') { |record| link_to record.station.name, admin_station_path(record.station) }
    column('Archivo') { |record| record.file_name }
    column('Estado') do |record|
      status_class = if record.failed?
                       'status--error'
                     elsif record.validated? || record.transcribed?
                       'status--success'
                     else
                       'status--progress'
                     end
      status_tag record.status.humanize, class: status_class
    end
    column('Capturado', &:captured_at)
    column('Último intento', &:last_attempt_at)
    column('Reintentos', &:retry_count)
    column('Error') { |record| truncate(record.last_error.to_s, length: 120).presence || '—' }
    column('Video') { |record| link_to('Ver video', admin_video_path(record.video)) if record.video }
    actions
  end

  show title: :file_name do |record|
    attributes_table do
      row('Canal') { link_to record.station.name, admin_station_path(record.station) }
      row :file_name
      row :status
      row :source_path
      row :captured_at
      row :last_attempt_at
      row :completed_at
      row :retry_count
      row('Error') { record.last_error.presence || '—' }
      row('Video') { link_to('Abrir video', admin_video_path(record.video)) if record.video }
    end

    para 'Los registros fallidos se conservan para diagnóstico y sólo se reintentan mediante una acción explícita de procesamiento.' if record.failed?
  end
end
