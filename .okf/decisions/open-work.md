---
type: Decision register
title: Production open work
description: Prioritized reliability, processing, and operational work remaining after the current supervised-pilot implementation.
tags: [production, backlog, reliability, operations]
resource: .
---

# Current position

MediaHub is operating as a supervised pilot. Capture, validation, import state, batching, systemd ownership, and administrative diagnostics are implemented, but the following items must be closed before calling the system unattended production-ready. This register is intentionally actionable; it does not treat a running listener as proof of healthy content.

# P0 — resolve before unattended operation

1. **Prove the FFmpeg SIGFPE mitigation.** Observe every active channel after the timestamp-normalization change; compare valid-segment continuity, restart count, stderr diagnostics and core dumps for 24–72 hours. Prepare a one-channel rollback-safe canary for a maintained FFmpeg build; do not upgrade the whole host ad hoc. See [FFmpeg SIGFPE runbook](../operations/ffmpeg-sigfpe.md).
2. **Triage Ruby listener `SIGSEGV` crashes.** Systemd restarts the service, but a native Ruby/process crash is not an acceptable steady-state recovery mechanism. Preserve the backtrace, identify the extension/runtime involved, and reproduce or remove the trigger before broadening the fleet. One-shot Rails tooling bypasses Bootsnap while this remains under investigation.
3. **Verify OCR recovery in the application.** The `RTesseract` API mismatch (`undefined method config=`) was repaired and the underlying Tesseract invocation was smoke-tested. Run a bounded re-extraction batch and verify the Admin OCR filters/search results before closing this item. OCR is distinct from transcription: it indexes visible lower-third/chyron text, while transcription indexes spoken audio.
4. **Triage held ingestion failures without deleting evidence.** Use Admin → Ingestion Records to group by error reason, inspect a representative sample, retry only recoverable entries and retain failed records plus reason for review.
5. **Verify boot policy intentionally.** After a successful canary/recovery drill, use `mediahub enable --stations …` only for the channels authorized to start after host reboot. Keep paused/testing stations disabled.

# P1 — required operating maturity

- Export fleet and per-station metrics: latest valid segment age, FFmpeg restarts, source-renewal outcome, invalid-content reason, staging backlog, transcription depth, GPU use and free disk.
- Add alert routing for no valid segment, repeated invalid content, exhausted renewal, disk pressure, transcription SLA breach and fleet-wide resolver failure. A dashboard without notification is insufficient for unattended operation.
- Add capture fixtures and release checks for expired-session blue slate, black video, silent audio, malformed playlist, token expiry, discontinuous timestamps and HTML error bodies.
- Define backup, restore, archive checksum, retention and core-dump cleanup policies; run and record a restore drill.
- Add a clear operator view of last successful segment, current session, last failure reason and retry timing for every channel.

# P2 — capacity and product evolution

- Move processing to a durable queue with retry/dead-letter semantics and separate observability for import, thumbnail/OCR, transcription, tags and topic statistics.
- Benchmark WhisperX/VAD/diarization only after capture continuity is stable; retain model, language, confidence and media checksum with transcript results.
- Evaluate MediaMTX as a one-channel relay/recording canary, not as a replacement for browser-derived source discovery.
- Establish archive/object-storage policy and a measured capacity plan before scaling to twenty channels or radio monitoring.

# Completion criteria

Production readiness requires measured evidence: no unresolved recurring native crashes, validated content continuity through a source-renewal drill, recoverable processing retries with reasons, tested restore path, and alerts that reach an operator before a channel is silently missing coverage.
