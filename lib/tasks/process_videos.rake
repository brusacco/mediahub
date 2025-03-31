# frozen_string_literal: true

desc 'Run task1 followed by task2, ensuring that it runs only once'
task process_videos: :environment do
  lock_file = 'tmp/process_videos.lock'

  if File.exist?(lock_file)
    puts 'Task is already running. Exiting...'
    exit
  else
    puts 'creando lock file'
    File.write(lock_file, Process.pid)

    begin
      ENV['RAILS_ENV'] = 'production'
      puts 'Se va a ejecutar el primer rake'
      Rake::Task['import_videos'].enhance do
        puts 'Se esta ejecutando el primer rake'
        Rake::Task['generate_transcription'].execute
        puts 'Termino el segundo rake'
      end
    ensure
      puts 'borrando lock file'
      FileUtils.rm_f(lock_file)
    end
  end
end
