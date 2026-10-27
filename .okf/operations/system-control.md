---
type: Runbook
title: MediaHub system control
description: Safe start, stop, status, and boot-policy control for the production capture stack.
tags: [operations, systemd, capture, runbook]
resource: bin/mediahub
---

# Purpose

`mediahub` is the single human-facing control command on `/opt/mediahub`. It delegates all process ownership to systemd: it never starts Rails, FFmpeg, or Rake listeners in the shell.

# Commands

```bash
mediahub status
mediahub start
mediahub stop
mediahub start --stations 28,34
mediahub enable --stations 28,34
mediahub disable --stations 28,34
```

Without `--stations`, `start`, `enable`, and `disable` select the current active stations from the database. `MEDIAHUB_STATION_IDS=28,34 mediahub start` is the equivalent for scripted use.

`start` starts the m3u8 discovery proxy, Rails, the host-monitor timer, the import/transcription, tagging and topic-statistics timers, then one systemd listener per selected station. `stop` stops processing timers and their currently running jobs, every selected/currently-running listener, then the proxy and Rails. It intentionally leaves the host-monitor timer enabled so a stopped stack remains observable.

`enable` and `disable` affect only boot behavior for the selected listener units. They are separate from `start` and `stop`: bringing a channel up for a test must not accidentally make it start on every subsequent server boot.

# Safe activation

1. Run `mediahub status` and confirm the previous controlled stop is complete.
2. Start one canary channel: `mediahub start --stations <id>`.
3. Confirm a newly validated segment and heartbeat within three minutes.
4. Start the remaining chosen channels only after that check.
5. Use `mediahub enable --stations ...` only after the channel has passed its renewal drill.

After an all-stack start, verify the service fleet and schedule:

```bash
mediahub status
systemctl list-timers 'mediahub-*' --all
RAILS_ENV=production bundle exec rake ingestion:status
```

`--stations` scopes the listener selection for `start`, `enable` and `disable`. The current `stop` implementation always stops processing, proxy and Rails as an orderly stack shutdown; with `--stations` it limits only the listener units it explicitly stops. To isolate one channel while leaving the site and schedulers up, use its managed listener unit directly:

```bash
sudo systemctl stop mediahub-listener@<station-id>.service
```

Restart it with the corresponding `systemctl start` command after diagnosis, or use `mediahub start --stations <station-id>` if the stack is intentionally being brought back up.

# Emergency stop

Use `mediahub stop` for an orderly pause of all currently running capture. If Rails is unresponsive, systemd commands remain valid: `sudo systemctl stop 'mediahub-listener@*.service' mediahub-processing.timer mediahub-tagging.timer mediahub-topic-stats.timer mediahub-mitmproxy.service mediahub-web.service`.
