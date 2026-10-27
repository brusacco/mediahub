---
type: Service
title: Rails web service
description: Persistent Puma service that exposes MediaHub's user and ActiveAdmin interfaces.
tags: [rails, puma, systemd, admin]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: config/puma.rb
---

# Responsibility

`mediahub-web.service` runs Puma with the project's RVM Ruby environment and `RAILS_ENV=production`. It is enabled at boot and supervises the foreground Puma master process.

# Access and verification

The service listens on `0.0.0.0:3000`. On the trusted LAN, the admin entry point is `http://192.168.0.32:3000/admin`; `/up` is the health endpoint. Run `systemctl status mediahub-web.service` or `systemctl restart mediahub-web.service` when operating it.

The systemd unit sets `SYSTEMD_SERVICE=1`, `WEB_CONCURRENCY=2`, and `FORCE_SSL=false` for direct local-network access. The application defaults to SSL unless that explicit service variable is supplied.

# Related concepts

- [System overview](../overview.md)
- [Runtime decision](../decisions/service-managed-runtime.md)
