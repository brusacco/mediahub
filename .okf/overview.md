---
type: System
title: MediaHub
description: Local platform for capturing online broadcast streams, storing clips, and extracting searchable metadata.
tags: [media-monitoring, rails, video, transcription]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: .
---

# Purpose

MediaHub monitors online television streams and is intended to support radio streams. It stores one-minute media segments, imports them into Rails, generates thumbnails and OCR text, and stores audio transcriptions for search and topic analysis.

The application runs on the local Ubuntu server at `192.168.0.32`. The user interface is described in [Rails web service](services/web.md); acquisition and URL renewal are described in [capture](services/capture.md) and [stream discovery](services/stream-discovery.md). Current production-readiness gaps and the delivery sequence are in the [roadmap](decisions/production-readiness-roadmap.md).

# Data flow

1. A station listener receives the current `stream_url` and starts FFmpeg.
2. FFmpeg writes one-minute MP4 segments under `public/videos/<station>/temp`.
3. Scheduled processing imports a complete segment, archives it by date, generates thumbnails and OCR, and runs transcription.
4. MySQL stores clip metadata, transcription, tags, topics, and station health.
5. Users access clips and administration through Rails.

# Current state

The Rails web application and m3u8-capture proxy are persistent services. Listeners are managed per station by systemd and must be considered healthy only after a content-valid segment is recorded. The platform is currently a supervised pilot; see the [production-readiness roadmap](decisions/production-readiness-roadmap.md) before treating it as unattended production.
