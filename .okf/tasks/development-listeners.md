---
type: Reference
title: Development listener Rake tasks
description: Local process-management tasks for stream development without systemd.
tags: [rake, streams, development]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: lib/tasks/stream/development.rake
---

# Local listener controls

These tasks use PID files under `tmp/pids/stream` and are for development machines. Production uses `mediahub-listener@<station-id>.service` instead.

| Task | What it does | Invocation |
| --- | --- | --- |
| `stream:dev:setup` | Creates the local PID directory. | `bundle exec rake stream:dev:setup` |
| `stream:dev:start[station_id]` | Starts a local background listener for one active station. | `bundle exec rake 'stream:dev:start[28]'` |
| `stream:dev:stop[station_id]` | Stops one local listener. | `bundle exec rake 'stream:dev:stop[28]'` |
| `stream:dev:restart[station_id]` | Restarts one local listener. | `bundle exec rake 'stream:dev:restart[28]'` |
| `stream:dev:start_all` | Starts local listeners for every active station. | `bundle exec rake stream:dev:start_all` |
| `stream:dev:stop_all` | Stops all local listener processes. | `bundle exec rake stream:dev:stop_all` |
| `stream:dev:status` | Prints process, database status, and heartbeat information. | `bundle exec rake stream:dev:status` |
| `stream:dev:orchestrator` | Starts the development-mode listener monitor. | `bundle exec rake stream:dev:orchestrator` |
