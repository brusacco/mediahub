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
| `import_videos` | Imports completed temporary and unregistered archived MP4 files, moves new clips to dated folders, creates `Video` rows, and creates thumbnails. | `bundle exec rake import_videos` | Records every segment in the ingestion ledger: `captured → validated → imported → thumbnail_ocr`, or `failed` with an error and retry count. Source: `import_videos.rake`. |
| `generate_transcription` | Transcribes every eligible `Video` using one CUDA `medium` worker that loads the model once and feeds it GPU batches of eight clips. | `bundle exec rake generate_transcription` | Advances successful ledger records to `transcribed`. A Whisper failure is retained as `failed` with its error and is excluded from normal batches. Retry one reviewed clip with `VIDEO_ID=<id> bundle exec rake generate_transcription`, or deliberately retry all failures with `RETRY_FAILED=1 bundle exec rake generate_transcription`. Files smaller than 1 MB are skipped. Supports `TRANSCRIPTION_LIMIT=<n>`, `TRANSCRIPTION_BATCH_SIZE=<n>` (default `8`), and `WHISPER_CTRANSLATE2_BIN=<path>`. Source: `generate_transcription.rake`. |
| `ingestion:status` | Reports pending capture files, oldest pending-file age, latest imported video, transcription queue depth, stage counts, and recent failures by channel. | `bundle exec rake ingestion:status` | Read-only operational check. Run before and after a manual processing batch. Source: `ingestion.rake`. |
| `process_videos` | Runs `import_videos`, `generate_transcription`, and `remove_fail_videos` sequentially under a lock. | `bundle exec rake process_videos` | Preferred batch task. The final phase only marks failures for review; it never deletes clips. Never launch a second instance while `tmp/process_videos.lock` exists. Source: `process_videos.rake`. |
| `generate_thumbs` | Creates thumbnails for every video without one. | `bundle exec rake generate_thumbs` | Can be I/O intensive on historical backlogs. Source: `generate_thumbs.rake`. |
| `remove_fail_videos` | Marks videos with invalid metadata or no transcription after 12 hours as `failed` in the ingestion ledger. | `bundle exec rake remove_fail_videos` | Non-destructive: preserves the video, thumbnails, and database row for later review and retry. Source: `remove_fail_videos.rake`. |
| `tagger` | Tags newly transcribed videos once. | `bundle exec rake tagger` | A no-match result is completed; operational errors preserve existing tags, record `tagging_error`, and retry later. Use `REPROCESS=1` only after changing tag definitions. Source: `tagger.rake`. |
| `topic_stat_daily` | Stores daily video counts for each enabled topic for the last seven days through today. | `bundle exec rake topic_stat_daily` | Safe to rerun; records are found or created by topic/date. Source: `topic_stat_daily.rake`. |

# Recommended batch order

Use `process_videos` for the normal flow. Use the individual tasks only when diagnosing a phase or deliberately reprocessing a backlog. Validate capture health first with [service verification](../operations/service-verification.md).

In production the normal invocation is `mediahub-processing.timer`, not cron/Whenever or a manually repeated Rake command. Incremental tags run through `mediahub-tagging.timer`; topic statistics through `mediahub-topic-stats.timer`. See the [processing schedule](../operations/processing-schedule.md).

To safely smoke-test transcription for one valid imported video, run `VIDEO_ID=<id> TRANSCRIPTION_BATCH_SIZE=1 bundle exec rake generate_transcription`.

## Ingestion ledger

`IngestionRecord` is the durable state record for a segment. The listener records a completed segment as `captured`, validates it before setting `validated`, and the import/transcription tasks advance it through the remaining stages. A failure records `last_error`, `last_attempt_at`, and increments `retry_count`. Failed records are held for review and are not retried by the normal batch; use the explicit commands above only after diagnosis. The record is keyed by channel and filename, so deliberate retries do not create duplicate ledger entries.
