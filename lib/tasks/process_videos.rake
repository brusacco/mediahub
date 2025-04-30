# frozen_string_literal: true

desc 'Run import_videos, generate_transcription, and remove_fail_videos sequentially, ensuring single execution'
task process_videos: :environment do
  lock_file = Rails.root.join('tmp', 'process_videos.lock')

  if File.exist?(lock_file)
    puts 'Task is already running. Exiting...'
    exit
  end

  puts 'Creando lock file'
  File.write(lock_file, Process.pid.to_s)

  begin
    ENV['RAILS_ENV'] ||= 'production' # Establecer solo si no está definido
    Rails.logger.info 'Iniciando process_videos'

    # Ejecutar primer task
    puts 'Se va a ejecutar el primer rake: import_videos'
    begin
      Rake::Task['import_videos'].invoke
      puts 'Terminó el primer rake: import_videos'
    rescue StandardError => e
      puts "Error en import_videos: #{e.message}"
      Rails.logger.error "Error en import_videos: #{e.message}"
    end

    # Ejecutar segundo task
    puts 'Se va a ejecutar el segundo rake: generate_transcription'
    begin
      Rake::Task['generate_transcription'].invoke
      puts 'Terminó el segundo rake: generate_transcription'
    rescue StandardError => e
      puts "Error en generate_transcription: #{e.message}"
      Rails.logger.error "Error en generate_transcription: #{e.message}"
    end

    # Ejecutar tercer task
    puts 'Se va a ejecutar el tercer rake: remove_fail_videos'
    begin
      Rake::Task['remove_fail_videos'].invoke
      puts 'Terminó el tercer rake: remove_fail_videos'
    rescue StandardError => e
      puts "Error en remove_fail_videos: #{e.message}"
      Rails.logger.error "Error en remove_fail_videos: #{e.message}"
    end

    Rails.logger.info 'Finalizó process_videos'
  ensure
    puts 'Borrando lock file'
    FileUtils.rm_f(lock_file)
  end
end