# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

set :environment, 'production'
# set :output, "/path/to/my/cron_log.log"

every 5.minutes do
 rake 'process_videos'
end
