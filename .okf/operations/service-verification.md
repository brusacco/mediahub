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

# Logs

Use `journalctl -u mediahub-web.service` and `journalctl -u mediahub-mitmproxy.service` for recent output. Application task logs are under `log/` in the repository.
