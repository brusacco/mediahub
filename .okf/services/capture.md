---
type: Pipeline
title: Broadcast capture pipeline
description: Per-station FFmpeg listener that turns a live stream URL into dated one-minute MP4 clips.
tags: [ffmpeg, streams, video, stations]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: lib/tasks/stream/listen_station.rake
---

# Behavior

`stream:listen_station[station_id]` loads an active station, connects FFmpeg to its `stream_url`, and writes MP4 files with a 60-second segment duration. It confirms a connection only after a completed segment passes content validation: at least 1 MB, at least 15 seconds of video, and no saturated-blue expired-session slate across two sampled frames. This prevents a broadcaster error video from generating a false heartbeat.

When FFmpeg exits, the listener marks the station disconnected and attempts [stream URL discovery](stream-discovery.md). Two consecutive invalid segments stop FFmpeg, delete those temporary clips, and trigger the same recovery path. New clips go to `public/videos/<station>/temp`; [scheduled work](scheduling.md) imports them into dated archives and creates `Video` records. Import repeats the same validation as a second safeguard.

## NPY expired-session protection

NPY can serve HTTP-successful HLS video that only displays the blue message “Sesión expirada. Vuelva a cargar el video”. FFmpeg therefore has no transport error and file-size checks alone are insufficient. `StreamSegmentValidationService` samples each completed segment with FFmpeg `signalstats`; a persistent saturated-blue frame is rejected before the station becomes `connected`. It is also rejected during import, so a scheduling race cannot archive an invalid NPY clip.

# Runtime supervision

`mediahub-listener@<station-id>.service` runs each listener under systemd, initializes RVM before Bundler, restarts after a failure, and is enabled at boot.

RCC TV is station `36`, stores segments in `public/videos/rcc-tv`, and renews its manifest from `https://www.desdepylabs.com/External/video/rcctv`. Its listener is enabled and subject to the same segment validation as the existing channels.

Before enabling a new station, validate renewal using the [channel recovery runbook](../operations/channel-recovery.md).
