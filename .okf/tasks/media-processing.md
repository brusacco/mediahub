---
type: Runbook
title: Media-processing Rake tasks
description: Import, transcribe, enrich, and remove MediaHub video records.
tags: [rake, videos, transcription, processing]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: lib/tasks
---

# Processing tasks

| Task | What it does | Invocation | Safety notes |
| --- | --- | --- | --- |
| `import_videos` | Imports completed temporary and unregistered archived MP4 files, moves new clips to dated folders, creates `Video` rows, and creates thumbnails. | `bundle exec rake import_videos` | Rejects in-use and undersized temporary segments. Source: `import_videos.rake`. |
| `generate_transcription` | Transcribes every valid `Video` without a transcription using `whisper-ctranslate2`; production uses CUDA, `medium`, and four processes. | `bundle exec rake generate_transcription` | GPU-intensive. Files smaller than 1 MB are skipped to avoid transcribing known error slates. Supports `VIDEO_ID=<id>`, `TRANSCRIPTION_LIMIT=<n>`, `TRANSCRIPTION_CONCURRENCY=<n>`, and `WHISPER_CTRANSLATE2_BIN=<path>` for controlled runs. Source: `generate_transcription.rake`. |
| `process_videos` | Runs `import_videos`, `generate_transcription`, and `remove_fail_videos` sequentially under a lock. | `bundle exec rake process_videos` | Preferred batch task. Never launch a second instance while `tmp/process_videos.lock` exists. Source: `process_videos.rake`. |
| `generate_thumbs` | Creates thumbnails for every video without one. | `bundle exec rake generate_thumbs` | Can be I/O intensive on historical backlogs. Source: `generate_thumbs.rake`. |
| `remove_fail_videos` | **Destructive:** deletes videos that remain untranscribed after 12 hours or have invalid location/path fields. | `bundle exec rake remove_fail_videos` | Review the candidate query before running manually. Source: `remove_fail_videos.rake`. |
| `tagger` | Extracts tags for videos posted within the last three months. | `bundle exec rake tagger` | Clears a video's tags if extraction raises an error. Source: `tagger.rake`. |
| `topic_stat_daily` | Stores daily video counts for each enabled topic for the last seven days through today. | `bundle exec rake topic_stat_daily` | Safe to rerun; records are found or created by topic/date. Source: `topic_stat_daily.rake`. |

# Recommended batch order

Use `process_videos` for the normal flow. Use the individual tasks only when diagnosing a phase or deliberately reprocessing a backlog. Validate capture health first with [service verification](../operations/service-verification.md).

To safely smoke-test transcription for one valid imported video, run `VIDEO_ID=<id> TRANSCRIPTION_CONCURRENCY=1 bundle exec rake generate_transcription`.
