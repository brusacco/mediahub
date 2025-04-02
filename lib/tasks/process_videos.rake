# frozen_string_literal: true

desc 'Run task1 followed by task2, ensuring that it runs only once'
task process_videos: :environment do
  lock_file = 'tmp/process_videos.lock'

  if File.exist?(lock_file)
    puts 'Task is already running. Exiting...'
    exit
  else
    puts 'Creando lock file'
    File.write(lock_file, Process.pid)

    begin
      ENV['RAILS_ENV'] = 'production'
      puts 'Se va a ejecutar el primer rake'
      Rake::Task['import_videos'].invoke
      puts 'Terminó el primer rake'

      puts 'Se va a ejecutar el segundo rake'
      Rake::Task['generate_transcription'].invoke
      puts 'Terminó el segundo rake'
    ensure
      puts 'Borrando lock file'
      FileUtils.rm_f(lock_file)
    end
  end
end
