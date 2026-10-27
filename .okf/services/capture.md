---
type: Pipeline
title: Broadcast capture pipeline
description: Per-station FFmpeg listener that turns a live stream URL into dated one-minute MP4 clips.
tags: [ffmpeg, streams, video, stations]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: lib/tasks/stream/listen_station.rake
---

# Behavior

`stream:listen_station[station_id]` loads an active station, acquires an exclusive per-channel lock, connects FFmpeg to its `stream_url`, and writes 60-second MP4 files to private staging under `storage/capture/<station>/temp`. It confirms a connection only after a completed segment passes content validation: at least 1 MB, at least 15 seconds of video and audio, no saturated-blue expired-session slate, and no black-screen slate across two sampled frames. This prevents a broadcaster error video from generating a false heartbeat.

When FFmpeg exits, the listener records the session outcome, marks the station disconnected and attempts [stream URL discovery](stream-discovery.md). A listener that produces no completed segment at all within three minutes is also treated as a stale connection: it is stopped and follows the same renewal path instead of remaining indefinitely in `capturing`. Two consecutive invalid segments stop FFmpeg, revert a newly promoted source when available, delete those temporary clips, and trigger the same recovery path. [Scheduled work](scheduling.md) imports staging files into dated public archives and creates `Video` records. Import repeats the same validation as a second safeguard. Legacy temporary files under `public/videos/<station>/temp` are imported during migration but new capture never writes there.

For HLS inputs, FFmpeg also limits consecutive playlist reloads with no new media sequence. This protects against providers that keep an HTTP connection open while serving a frozen playlist: FFmpeg exits, and the normal source-renewal path takes over.

## Audit trail

`CaptureSession` and `CaptureEvent` record every capture owner, source candidate/promotion/rejection, state transition, valid segment, FFmpeg exit and source rollback. Events store a URL fingerprint and resolver metadata rather than raw signed URLs. Application logs emit the same fields as JSON.

For HLS audio with discontinuous timestamps, the FFmpeg command normalizes audio with `aresample=async=1:first_pts=0` before native AAC encoding. It does not force the slow `twoloop` AAC coder. On an FFmpeg exit, a bounded redacted stderr tail is stored with the session so the Admin station view can distinguish a source/network failure from an FFmpeg signal crash. See [FFmpeg SIGFPE](../operations/ffmpeg-sigfpe.md).

## NPY expired-session protection

NPY can serve HTTP-successful HLS video that only displays the blue message “Sesión expirada. Vuelva a cargar el video”. FFmpeg therefore has no transport error and file-size checks alone are insufficient. `StreamSegmentValidationService` samples each completed segment with FFmpeg `signalstats`; a persistent saturated-blue frame is rejected before the station becomes `connected`. It is also rejected during import, so a scheduling race cannot archive an invalid NPY clip.

# Runtime supervision

`mediahub-listener@<station-id>.service` runs each listener under systemd, initializes RVM before Bundler, and restarts after an unexpected process failure. A listener that exhausts its bounded source-renewal attempts exits cleanly and remains stopped, avoiding an endless Chrome/FFmpeg loop against an unavailable broadcaster. Boot activation is intentional and is controlled per channel through `mediahub enable` / `mediahub disable`; it is not implied by a one-time start.

After a listener produces its first newly written, validated segment, it resets its exponential retry counter. Files left in `temp/` by an earlier listener process never count as a new heartbeat, preventing a stale segment from reporting a false connection or shortening a needed backoff.

RCC TV is station `36`, stores segments in `public/videos/rcc-tv`, and renews its manifest from `https://www.desdepylabs.com/External/video/rcctv`. Its listener is enabled and subject to the same segment validation as the existing channels.

Before enabling a new station, validate renewal using the [channel recovery runbook](../operations/channel-recovery.md).
