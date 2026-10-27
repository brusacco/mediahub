# How to run a task

Run project tasks from the application root. On the Ubuntu server, load RVM first:

```bash
source /etc/profile.d/rvm.sh
cd /opt/mediahub
RAILS_ENV=production bundle exec rake <task>
```

Arguments use brackets and should be quoted by the shell, for example `bundle exec rake 'stream:listen_station[28]'`.

# Operational catalog

- [Capture and source recovery](stream-management.md): listeners, URL renewal, legacy listeners, and systemd controls.
- [Media processing](media-processing.md): import, transcription, thumbnails, failed-video cleanup, tags, and topic statistics.
- [OCR and maintenance](analysis-maintenance.md): OCR extraction and development-only cleanup tasks.
- [Development listeners](development-listeners.md): local process controls that must not be used on the production server.
- [Rails and dependency tasks](framework-tasks.md): standard framework tasks and how to list their current installed set.

# Safety rules

- Prefer the `mediahub-listener@<station-id>.service` units in production; do not start duplicate `stream:listen_station` tasks by hand.
- Do not run more than one `process_videos` instance; it owns `tmp/process_videos.lock` while active.
- Tasks tagged **destructive** delete data or files. Read their entry before running them.
- Confirm service state after a stream task with `systemctl status mediahub-listener@<station-id>.service` and the Rails admin.
