---
type: Service
title: M3U8 capture proxy
description: Local mitmproxy service that records m3u8 requests made by Selenium during stream URL discovery.
tags: [mitmproxy, m3u8, selenium, systemd]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: capture_m3u8.py
---

# Responsibility

`mediahub-mitmproxy.service` runs mitmproxy from `/opt/mediahub/.venv-mitmproxy`. It listens only on `127.0.0.1:8080` and loads `capture_m3u8.py`, which appends observed `.m3u8` request URLs to `/tmp/mitm_m3u8.log`.

# Operations

The service is enabled at boot. Check it with `systemctl status mediahub-mitmproxy.service`. It must own port 8080; no unrelated application may bind the port while MediaHub renews stream URLs.

The proxy is an internal dependency of [stream URL discovery](stream-discovery.md), not a public endpoint.
