---
type: Pipeline
title: Stream URL discovery
description: Selenium/mitmproxy default workflow and optional Ferrum CDP recovery for renewed HLS or DASH stream URLs.
tags: [selenium, mitmproxy, ferrum, cdp, m3u8, mpd, recovery]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: app/services/stream_url_update_service.rb
---

# Behavior

`StreamUrlUpdateService` opens `station.stream_source` in Chrome, routes the browser through the local [m3u8 capture proxy](m3u8-proxy.md), optionally clicks the configured play selector, and reads manifest URLs from `/tmp/mitm_m3u8.log`. A selected candidate becomes `station.stream_url`.

Discovery is serialized with a process lock because mitmproxy writes to a shared capture file. If the browser does not emit the stream request, the service reads HLS/DASH manifest URLs declared in both the rendered DOM and the original source HTML. Dailymotion embeds are resolved through their player metadata endpoint. If those mechanisms do not return a URL, the service falls back to Chrome's headless DOM renderer through the same proxy.

## Ferrum: experimental analysis path

Ferrum is an independent CDP browser path reserved for manual analysis and trials. It does not use ChromeDriver or mitmproxy: it plays the source page and reads the browser's network traffic for `.m3u8` or `.mpd` requests. When a station has `play_button_selector`, Ferrum waits for that selector and sends a native Chrome CDP click, allowing players that require a trusted user gesture to start.

Production listeners use only the legacy Selenium + mitmproxy mechanism. Do not set `STREAM_DISCOVERY_METHOD` in their systemd environment while Ferrum remains under evaluation.

Choose the route only for the process being tested:

```bash
# Test only Ferrum for one station; no legacy browser or proxy is used.
STREAM_DISCOVERY_METHOD=ferrum RAILS_ENV=production bundle exec rake 'stream:update_stream_url[29]'

# Prefer Ferrum but preserve automatic recovery to the existing mechanism.
STREAM_DISCOVERY_METHOD=ferrum_then_legacy RAILS_ENV=production bundle exec rake 'stream:update_stream_url[29]'

# Keep the current mechanism first, using Ferrum only if it fails.
STREAM_DISCOVERY_METHOD=legacy_then_ferrum RAILS_ENV=production bundle exec rake 'stream:update_stream_url[29]'
```

Unset `STREAM_DISCOVERY_METHOD`, or set it to `legacy`, to return immediately to the existing Selenium + mitmproxy behavior. The fallback modes are available for controlled manual testing only.

# Dependencies

- Google Chrome or Chromium running headlessly.
- `mediahub-mitmproxy.service` active on `127.0.0.1:8080`.
- A valid source page and, when needed, a station-specific play selector.
- For Dailymotion sources, public player metadata must include an HLS quality.

Ferrum trials only require Chrome/Chromium and the `ferrum` gem; mitmproxy is not required for that path.

# Known limitations

The capture log is shared by all renewal attempts; the discovery lock prevents concurrent renewals from mixing results. A failed renewal raises a normal task error, which the listener records before retrying instead of terminating its process.
