# frozen_string_literal: true

# Production scheduling is owned by systemd timers:
# - mediahub-processing.timer
# - mediahub-tagging.timer
# - mediahub-topic-stats.timer
#
# This empty Whenever definition intentionally prevents an accidental
# `whenever --update-crontab` from creating duplicate workers. See
# .okf/operations/processing-schedule.md.
