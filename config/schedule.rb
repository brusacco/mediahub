# frozen_string_literal: true

# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

set :environment, 'production'
set :output, 'log/whenever.log'

every 1.minute do
  rake 'process_videos'
end

every 5.minutes do
  rake 'tagger'
end

every :hour do
  rake 'topic_stat_daily'
end
