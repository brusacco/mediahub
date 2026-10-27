---
type: Runbook
title: Processing schedule
description: Systemd-owned schedule for MediaHub import, transcription, tagging, and topic statistics.
tags: [operations, systemd, processing, transcription, tagging]
resource: deploy/systemd
---

# Authority

Systemd timers are the only production scheduler. `config/schedule.rb` is intentionally empty: do not run `whenever --update-crontab`, and do not launch recurring Rake commands from user or root cron.

# Timers

| Timer | Cadence | Service | Work |
| --- | --- | --- | --- |
| `mediahub-processing.timer` | At least every three minutes; normally three minutes after the preceding run ends | `mediahub-processing.service` | `process_videos`: import, thumbnail/OCR for new clips, batch transcription at eight clips, and failure marking. |
| `mediahub-tagging.timer` | Every ten minutes | `mediahub-tagging.service` | Tags up to 250 transcribed clips whose tagging state is pending. |
| `mediahub-topic-stats.timer` | Daily at approximately 00:15 | `mediahub-topic-stats.service` | Updates daily topic statistics. |

Systemd never starts a second instance of an active `Type=oneshot` service. `process_videos` retains its own lock as an additional safeguard for a manual diagnostic invocation.

# Tagging policy

`tagger` marks a video as processed after either matching tags or correctly finding no match. It retains previous tags if an operational error occurs, records `tagging_error` and retries on a later scheduled pass. It no longer scans all videos from the last three months on every execution.

After changing tag definitions, intentionally reprocess existing transcriptions:

```bash
cd /opt/mediahub
source /etc/profile.d/rvm.sh
REPROCESS=1 TAGGING_LIMIT=500 RAILS_ENV=production bundle exec rake tagger
```

# Operations

```bash
mediahub start
mediahub stop
systemctl list-timers 'mediahub-*' --all
journalctl -u mediahub-processing.service -u mediahub-tagging.service -n 100 --no-pager
```

To process a single diagnostic batch without waiting for its timer, use `sudo systemctl start mediahub-processing.service`. Do not do this while it is already active.
