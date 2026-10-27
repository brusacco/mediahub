---
type: Decision
title: Persistent MediaHub processes run under systemd
description: Rails/Puma and mitmproxy are boot-enabled system services instead of terminal sessions or cron jobs.
tags: [systemd, deployment, operations]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: /etc/systemd/system/mediahub-web.service
---

# Decision

Run the Rails interface and m3u8 proxy under systemd. Each service restarts after a process failure and starts after a server reboot.

# Rationale

Cron is appropriate for short scheduled processing, but it cannot keep a web process or streaming proxy alive. Persistent capture components need explicit lifecycle supervision and inspectable logs.

# Consequences

Puma stays in the foreground when `SYSTEMD_SERVICE=1`. The service shell initializes RVM before Bundler. The proxy has a dedicated virtual environment and listens only on loopback.

# Related concepts

- [Rails web service](../services/web.md)
- [M3U8 capture proxy](../services/m3u8-proxy.md)
