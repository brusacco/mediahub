---
type: Runbook
title: Service verification
description: Health checks for MediaHub's web application and local m3u8 capture proxy.
tags: [operations, systemd, rails, mitmproxy]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: /etc/systemd/system
---

# Web application

Check `systemctl is-active mediahub-web.service`. The service must report `active`; `http://127.0.0.1:3000/up` must return HTTP 200.

# M3U8 proxy

Check `systemctl is-active mediahub-mitmproxy.service`. It must report `active`, and `ss -ltn` must show `127.0.0.1:8080`.

# Listener fleet and processing

`active` only proves systemd has a listener process. A channel is healthy only after a recent content-valid segment. Check both the fleet and the ingest backlog:

```bash
mediahub status
systemctl list-units --type=service --state=active 'mediahub-listener@*.service' --no-legend
systemctl list-timers 'mediahub-*' --all
cd /opt/mediahub && source /etc/profile.d/rvm.sh
RAILS_ENV=production bundle exec rake ingestion:status
```

Use the station's Admin page to inspect latest valid segment, capture-session state and redacted FFmpeg diagnostic. Signal-8 crashes follow the [FFmpeg SIGFPE runbook](ffmpeg-sigfpe.md), not the generic source-renewal path.

# Logs

Use `journalctl -u mediahub-web.service` and `journalctl -u mediahub-mitmproxy.service` for recent output. For a station, use `journalctl -u mediahub-listener@<station-id>.service -n 200 --no-pager`. Application task logs are under `log/` in the repository.
