---
type: Schedule
title: Scheduled media processing
description: Systemd-owned schedule for importing clips, transcribing, tagging content, and updating topic statistics.
tags: [systemd, transcription, ocr, tagging]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: systemd/mediahub-processing.timer
---

# Schedule ownership

Production scheduling belongs exclusively to systemd timers. `config/schedule.rb` is intentionally empty: do not use `whenever --update-crontab`, and do not add recurring MediaHub commands to user or root cron.

`mediahub-processing.timer` runs the import/transcription pipeline, `mediahub-tagging.timer` runs incremental tagging, and `mediahub-topic-stats.timer` refreshes topic statistics. The complete frequency, locks and verification commands are in [processing schedule](../operations/processing-schedule.md).

# Boundary

Timers process clips already captured. They do not start, supervise, or repair live listeners; that belongs to [capture](capture.md), [system control](../operations/system-control.md), and [channel recovery](../operations/channel-recovery.md).

`whisper-ctranslate2` uses the configured production binary and the RTX 3090. Current transcription uses the `medium` model in GPU batches of eight; inspect backlog before changing either value.
