# MediaHub

MediaHub captures online TV streams as one-minute video segments, imports and transcribes valid clips, and exposes operational administration through Rails/ActiveAdmin.

## Operational documentation

The complete maintained Rake catalog is in [`.okf/tasks/index.md`](.okf/tasks/index.md). It documents every project task, its source, parameters, impact, and safe invocation; it also explains how to list all Rails and dependency tasks installed in the current environment.

- [Stream capture and systemd tasks](.okf/tasks/stream-management.md)
- [Import, transcription, tags, and statistics](.okf/tasks/media-processing.md)
- [OCR and development cleanup](.okf/tasks/analysis-maintenance.md)
- [Local development listener controls](.okf/tasks/development-listeners.md)
- [Rails/framework task reference](.okf/tasks/framework-tasks.md)

## Running a task on the production server

```bash
ssh artigas@192.168.0.32
source /etc/profile.d/rvm.sh
cd /opt/mediahub
RAILS_ENV=production bundle exec rake -T
```

Use `RAILS_ENV=production bundle exec rake <task>` to run a documented task. Quote tasks with arguments, for example:

```bash
RAILS_ENV=production bundle exec rake 'stream:update_stream_url[28]'
```

## Production services

The application is supervised through systemd:

```bash
systemctl status mediahub-web.service
systemctl status mediahub-mitmproxy.service
systemctl status mediahub-listener@28.service
```

Do not run duplicate stream listeners manually while a `mediahub-listener@<station-id>` service is active. See the [OKF system overview](.okf/overview.md) and [channel recovery runbook](.okf/operations/channel-recovery.md) before changing a source or service.
