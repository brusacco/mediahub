---
type: Runbook
title: Stream Rake tasks
description: Tasks that capture broadcast streams, refresh stream URLs, and manage listener services.
tags: [rake, streams, systemd, ffmpeg]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: lib/tasks/stream
---

# Production capture and renewal

| Task | What it does | How to use it | Notes |
| --- | --- | --- | --- |
| `stream:listen_station[station_id]` | Runs one FFmpeg listener, validates completed segments, updates heartbeat, and renews the URL when FFmpeg stops. | `bundle exec rake 'stream:listen_station[28]'` | Production is supervised by `mediahub-listener@28.service`; start it manually only for diagnosis. Source: `listen_station.rake`. |
| `stream:update_stream_url[station_id]` | Resolves `stream_source` into a fresh HLS/DASH URL through `StreamUrlUpdateService`. | `bundle exec rake 'stream:update_stream_url[28]'` | Mutates `station.stream_url`; requires the m3u8 proxy and Chrome. Source: `update_stream_url.rake`. |
| `stream:update_stream_urls` | Legacy bulk browser-based URL refresh for all stations with a source. | `bundle exec rake stream:update_stream_urls` | Do not use for normal production recovery; the current listener performs serialized renewal. Source: `update_stream_urls.rake`. |
| `stream:listen` | Legacy multithread listener for every station. | `bundle exec rake stream:listen` | Do not use alongside systemd listeners; it can create duplicate FFmpeg processes. Source: `listen.rake`. |
| `stream:listen_offlines` | Legacy multithread listener for stations recorded as disconnected. | `bundle exec rake stream:listen_offlines` | Do not use alongside systemd listeners. Source: `listen_offlines.rake`. |
| `stream:orchestrator` | Long-running monitor that starts and reconciles listener processes/services. | `ORCHESTRATOR_INTERVAL=60 bundle exec rake stream:orchestrator` | Review its configured `SERVICE_PREFIX` before production use; systemd already restarts listeners. Source: `orchestrator.rake`. |
| `stream:test` | Selenium request-interception smoke test against an example page. | `bundle exec rake stream:test` | Diagnostic only; it does not validate a station. Source: `update_stream_urls.rake`. |

# Systemd task family

These tasks operate on generated services and should be run on the server. Prefer direct `systemctl` for the installed `mediahub-listener@<id>` units, because the legacy generator's naming can differ from the deployed template.

| Task | What it does | Invocation |
| --- | --- | --- |
| `stream:systemd:generate[station_id]` | Prints/writes the service definition for one station. | `bundle exec rake 'stream:systemd:generate[28]'` |
| `stream:systemd:install[station_id]` | Installs and enables one generated service. Requires sudo. | `bundle exec rake 'stream:systemd:install[28]'` |
| `stream:systemd:uninstall[station_id]` | **Destructive:** stops, disables, and removes one generated service. Requires sudo. | `bundle exec rake 'stream:systemd:uninstall[28]'` |
| `stream:systemd:start[station_id]` | Starts one generated service. | `bundle exec rake 'stream:systemd:start[28]'` |
| `stream:systemd:stop[station_id]` | Stops one generated service. | `bundle exec rake 'stream:systemd:stop[28]'` |
| `stream:systemd:restart[station_id]` | Restarts one generated service. | `bundle exec rake 'stream:systemd:restart[28]'` |
| `stream:systemd:install_all` | Installs generated services for all active stations. Requires sudo. | `bundle exec rake stream:systemd:install_all` |
| `stream:systemd:start_all` | Starts generated services for all active stations. | `bundle exec rake stream:systemd:start_all` |
| `stream:systemd:stop_all` | Stops generated services for all active stations. | `bundle exec rake stream:systemd:stop_all` |
| `stream:systemd:status_all` | Prints listener/service/database status for active stations. | `bundle exec rake stream:systemd:status_all` |

# Related concepts

- [Capture pipeline](../services/capture.md)
- [Stream URL discovery](../services/stream-discovery.md)
- [Channel recovery](../operations/channel-recovery.md)
