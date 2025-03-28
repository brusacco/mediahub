# frozen_string_literal: true

desc 'Run task1 followed by task2, ensuring that it runs only once'
task process_videos: :environment do
  lock_file = 'tmp/process_videos.lock'

  if File.exist?(lock_file)
    puts 'Task is already running. Exiting...'
    exit
  else
    File.write(lock_file, Process.pid)

    ENV['RAILS_ENV'] = 'production'
    Rake::Task['import_videos'].invoke
  end
end
