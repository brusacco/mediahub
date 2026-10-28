# frozen_string_literal: true

desc 'Run import_videos, generate_transcription, and mark failed videos sequentially, ensuring single execution'
task process_videos: :environment do
  lock_file = Rails.root.join('tmp', 'process_videos.lock')
  FileUtils.mkdir_p(lock_file.dirname)
  lock_io = File.open(lock_file, File::RDWR | File::CREAT, 0o644)

  # Existence/PID locks are racy: two manual invocations can both observe a
  # stale file and start duplicate GPU work. The kernel-held advisory lock is
  # released automatically if this process crashes, so there is no stale-lock
  # recovery path to guess at.
  unless lock_io.flock(File::LOCK_EX | File::LOCK_NB)
    puts 'process_videos is already running; exiting without starting a second batch.'
    Rails.logger.info 'process_videos skipped because its advisory lock is held'
    lock_io.close
    next
  end

  lock_io.rewind
  lock_io.truncate(0)
  lock_io.write("#{Process.pid}\n")
  lock_io.flush
  puts 'Processing lock acquired'
  Rails.logger.info "process_videos advisory lock acquired by PID #{Process.pid}"

  begin
    ENV['RAILS_ENV'] ||= 'production'
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

    # Ejecutar tercer task: preserva los archivos y marca fallos para revisión.
    puts 'Se va a ejecutar el tercer rake: remove_fail_videos (marcar para revisión)'
    begin
      Rake::Task['remove_fail_videos'].invoke
      puts 'Terminó el tercer rake: remove_fail_videos'
    rescue StandardError => e
      puts "Error en remove_fail_videos: #{e.message}"
      Rails.logger.error "Error en remove_fail_videos: #{e.message}"
    end

    Rails.logger.info 'Finalizó process_videos'
  ensure
    lock_io&.flock(File::LOCK_UN)
    lock_io&.close
    FileUtils.rm_f(lock_file)
    Rails.logger.info 'process_videos advisory lock released'
  end
end
