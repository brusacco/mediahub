---
type: Runbook
title: Channel recovery
description: Safe sequence for restoring one disconnected station and validating source renewal before broad rollout.
tags: [operations, streams, recovery, ffmpeg]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: lib/tasks/stream/listen_station.rake
---

# Preconditions

1. Confirm `mediahub-mitmproxy.service` is active and owns `127.0.0.1:8080`.
2. Confirm [Rails web service](../services/web.md) and MySQL are healthy.
3. Confirm Chrome can run headlessly and the station has a usable `stream_source`.
4. Confirm GPU work will not conflict with transcription capacity.

# Recover one station

1. Verify that no unrelated process owns port 8080.
2. Run discovery for one station and validate the resulting URL with a short FFmpeg probe.
3. Start its `mediahub-listener@<station-id>.service` instance and verify a new segment and heartbeat within three minutes.
4. If renewal fails, inspect that instance's journal and the station source or play selector. For pages that declare a manifest in their HTML, verify the embedded HLS/DASH URL; for Dailymotion, verify the public player metadata has an HLS quality.
5. Enable further stations only after the first listener produces a segment.

If FFmpeg exits by signal 8 or diagnostics report discontinuous audio timestamps, keep the source candidate unchanged and use the [FFmpeg SIGFPE runbook](ffmpeg-sigfpe.md). This failure family is different from a failed URL renewal.

# Rollback

Stop the listener for the tested station and preserve its logs. Do not overwrite a known-good URL until the candidate passes the FFmpeg probe.

# Related concepts

- [Capture pipeline](../services/capture.md)
- [Stream URL discovery](../services/stream-discovery.md)
- [Service verification](service-verification.md)
