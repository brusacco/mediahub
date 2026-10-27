---
type: Pipeline
title: Stream URL discovery
description: Selenium/mitmproxy default workflow and optional Ferrum CDP recovery for renewed HLS or DASH stream URLs.
tags: [selenium, mitmproxy, ferrum, cdp, m3u8, mpd, recovery]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: app/services/stream_url_update_service.rb
---

# Behavior

`StreamUrlUpdateService` opens `station.stream_source` in Chrome, routes the browser through the local [m3u8 capture proxy](m3u8-proxy.md), optionally clicks the configured play selector, and reads manifest URLs from `/tmp/mitm_m3u8.log`. A selected candidate is saved separately, preflighted with FFprobe for both video and audio, and only then promoted atomically to `station.stream_url`. Selenium renewals also retain the browser-cookie header when playback is bound to that session. The promotion stores this request context, inferred token expiry when present, and the previous active source for automatic rollback after two invalid segments.

Discovery is serialized with a process lock because mitmproxy writes to a shared capture file. It first resolves HLS/DASH manifests declared in an iframe, then falls back to the browser/proxy flow when that direct configuration path is unavailable. The player page is fetched with the public source as `Referer` and a cache-busting query so an expired, cached signed URL is never reused. Browser fallback reads manifests declared in both the rendered DOM and original source HTML; Dailymotion embeds are resolved through their metadata endpoint, followed by Chrome's headless DOM renderer if needed.

## GEN (`station_id=34`)

GEN embeds its real Video.js player at `gentv.desdepylabs.com`; its public page contains no direct manifest. The player configuration contains a short-lived signed HLS URL and the embed host rejects direct requests without `Referer: https://www.gen.com.py/`. Do not configure `iframe` as a play-button selector: clicking the outer iframe cannot trigger the inner player. The embedded-player resolver retrieves the configuration directly with the required referer and renews the manifest without relying on that click.

## Critical model: the playlist is a temporary browser-derived credential

For many broadcasters, `station.stream_url` is **not** a durable source address. The public source page creates a browser session, the player receives a real interaction such as Play, and only then the broadcaster returns an HLS/DASH manifest with a short-lived signed token. In some cases the manifest is usable only with the browser's `Referer`, `User-Agent`, cookies or other request headers.

The actual flow is:

```text
public channel page
  -> browser session / consent / cookies
  -> player or iframe loads
  -> Play gesture
  -> temporary manifest + signed token
  -> capture while its lease is valid
  -> renewal before expiry or after a validated capture failure
```

Agents must never treat a discovered `.m3u8` or `.mpd` URL as a permanent channel configuration, nor infer that an HTTP-successful playlist carries valid broadcast content. A URL can remain syntactically playable while showing an expired-session slate.

### Requirements for every resolver

- Keep a stable `stream_source` page separate from the temporary manifest.
- Capture and persist the discovery time, resolver method, expiry when available, and a redacted URL fingerprint; never expose signed query tokens in logs or documentation.
- Capture the minimum request context needed by FFmpeg: `Referer`, `User-Agent`, cookies and relevant headers.
- Drive configured Play selectors with a real browser interaction; support iframe and consent flows when a channel requires them.
- Validate a candidate by checking video, audio, playlist progress and content before promoting it for capture.
- Renew proactively when expiry is known, and reactively on HTTP authorization failures, no playlist progress, FFmpeg failure, or content-validator rejection.
- Promote a candidate atomically and retain the former active source until the first valid segments confirm the replacement.

### Tool boundaries

Selenium/mitmproxy and Ferrum are browser/session resolvers. Streamlink may provide a resolver for supported providers. MediaMTX, SRS and Restreamer are downstream relays, recorders or monitors: they cannot obtain a browser-only manifest by themselves. Use those tools only after a source resolver has produced and validated a usable temporary stream.

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
