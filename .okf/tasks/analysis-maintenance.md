---
type: Reference
title: OCR and maintenance Rake tasks
description: OCR extraction and destructive development-only cleanup commands.
tags: [rake, ocr, maintenance, development]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: lib/tasks
---

# OCR tasks

| Task | What it does | Invocation |
| --- | --- | --- |
| `ocr:extract_all` | Extracts OCR text from videos that have no OCR text. | `bundle exec rake ocr:extract_all` |
| `ocr:extract_range[start_date,end_date]` | Extracts OCR text for a date range. | `bundle exec rake 'ocr:extract_range[2026-10-01,2026-10-31]'` |
| `ocr:re_extract_all` | Forces OCR extraction for every video with a thumbnail. | `bundle exec rake ocr:re_extract_all` |

OCR expects generated thumbnails plus ImageMagick and Tesseract. It updates `Video#ocr_text` and does not alter the source MP4.

# Development-only cleanup tasks

All tasks in this table refuse to run outside `RAILS_ENV=development` and some request an interactive `yes` confirmation. Never use them on the production server.

| Task | Effect |
| --- | --- |
| `dev:cleanup:videos` | **Destructive:** deletes all video records, MP4s, thumbnails, and temporary files. |
| `dev:cleanup:video_files` | **Destructive:** deletes video and thumbnail files while retaining database records. |
| `dev:cleanup:video_records` | **Destructive:** deletes all `Video` rows while retaining files. |
| `dev:cleanup:temp_directories` | **Destructive:** clears and recreates every station temporary capture directory. |
| `dev:cleanup:chrome` | Stops hanging Selenium Chrome processes only; it is safe for a developer's regular browser. |
