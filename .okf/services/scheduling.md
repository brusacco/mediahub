---
type: Schedule
title: Scheduled media processing
description: Cron schedule for importing clips, transcribing, tagging content, and updating topic statistics.
tags: [cron, transcription, ocr, tagging]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: config/schedule.rb
---

# Schedule

The `whenever` definition runs `process_videos` every minute, tagging every five minutes, and topic statistics hourly. `process_videos` invokes import, transcription, and removal of failed videos in sequence.

# Boundary

Cron processes clips that already exist. It does not start, supervise, or repair live listeners; that is the responsibility of [capture](capture.md) and [channel recovery](../operations/channel-recovery.md).

`whisper-ctranslate2` is resolved from `WHISPER_CTRANSLATE2_BIN` when provided, then from `~/.local/bin/whisper-ctranslate2`, and finally from `PATH`. The RTX 3090 must have sufficient free memory before transcription is enabled.
