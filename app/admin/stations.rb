# frozen_string_literal: true

ActiveAdmin.register Station do
  permit_params :name, :directory, :stream_url, :stream_status, :stream_source, :logo, :active, :play_button_selector, :use_shadow_dom

  filter :name
  filter :stream_status, as: :select

  form do |f|
    f.inputs 'Estaciones' do
      f.input :name, label: 'Nombre'
      f.input :logo, as: :file
      f.input :directory
      f.input :stream_url
      f.input :stream_status
      f.input :stream_source
      f.input :play_button_selector, hint: 'CSS selector, class name, tag name, or XPath for play button'
      f.input :use_shadow_dom, hint: 'Use Shadow DOM strategy to play video (for custom elements like mux-video)'
      f.input :active
    end

    f.actions
  end

  index do
    column :id
    column 'Logo' do |file|
      link_to image_tag(file.logo, width: 100), admin_station_path(file) if file.logo.present?
    end
    column :name
    column :directory
    # column :stream_url
    tag_column :stream_status
    # column :stream_source
    column :active
    column 'Log' do |station|
      if station.log.present?
        recent_entries = station.recent_log_entries(lines: 3)
        div style: 'font-size: 11px; color: #666; max-width: 300px;' do
          recent_entries.map do |entry|
            div style: 'overflow: hidden; text-overflow: ellipsis; white-space: nowrap;' do
              entry
            end
          end.join.html_safe
        end
      else
        span 'Sin log', style: 'color: #999;'
      end
    end
    column :created_at
    column :updated_at
    actions
  end

  show do |station|
    attributes_table do
      row 'Nombre', &:name
      row 'Logo' do |file|
        image_tag(file.logo, width: 250) if file.logo.present?
      end
      row :name
      row :directory
      row :stream_url
      row :stream_status
      row :stream_source
      row :active
      row :created_at
      row :updated_at
      row :last_heartbeat_at
    end

    panel 'Log de la Estación' do
      div do
        if station.log.present?
          div style: 'max-height: 500px; overflow-y: auto; background-color: #1e1e1e; color: #d4d4d4; padding: 15px; border-radius: 4px; font-family: monospace; font-size: 12px; white-space: pre-wrap; word-wrap: break-word;' do
            station.log
          end
        else
          para 'No hay entradas en el log aún.'
        end
      end
      
      div style: 'margin-top: 15px;' do
        link_to 'Limpiar Log', clear_log_admin_station_path(station), method: :post, 
                class: 'button', 
                data: { confirm: '¿Estás seguro de que quieres limpiar el log? Esta acción no se puede deshacer.' }
      end
    end
  end

  member_action :clear_log, method: :post do
    resource.clear_log!
    redirect_to admin_station_path(resource), notice: 'Log limpiado exitosamente'
  end

end
