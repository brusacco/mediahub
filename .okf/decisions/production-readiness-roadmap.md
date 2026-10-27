---
type: Assessment
title: Production-readiness roadmap
description: Gap assessment and implementation roadmap for reliable online TV and radio monitoring.
tags: [production, reliability, streams, observability, transcription, roadmap]
generated: { by: process:codex, at: 2026-10-27T12:30:00-03:00 }
resource: .
---

# Decision

MediaHub is suitable for a supervised pilot, but is **not yet production-ready**. It can capture and transcribe, and it now prevents the known NPY expired-session slate from generating a heartbeat. It does not yet provide the reliability, audit trail, alerting, storage guarantees, or automated test coverage required for unattended long-term monitoring.

The near-term decision is to retain Rails, FFmpeg, the existing Selenium + mitmproxy discovery path, and systemd. Ferrum remains a manual diagnostic option only. Do not replace the capture stack wholesale before measuring the baseline and proving each change on a canary channel.

# What comparable open-source systems contribute

| Project | Useful capability | Adopt in MediaHub? | Reason |
| --- | --- | --- | --- |
| [MediaMTX](https://github.com/bluenviron/mediamtx) | Pull/proxy multiple live protocols, recording/playback, Control API, hooks and Prometheus metrics. | Pilot as an optional relay and recorder. | It is a strong boundary between unstable external inputs and local capture, but it does not discover browser-protected URLs. |
| [SRS](https://ossrs.io/lts/en-us/docs/v5/doc/introduction) | HLS/DASH/RTMP/SRT/WebRTC conversion, DVR, HTTP callbacks and Prometheus exporter. | Evaluate only if protocol conversion or multi-node distribution becomes a requirement. | It is more infrastructure than the current single-server capture need. |
| [Streamlink](https://streamlink.github.io/latest/) | Site-specific resolver plugins that return playable streams with session parameters. | Build a resolver adapter interface; trial Streamlink where a plugin exists. | It complements, rather than replaces, the legacy resolver and browser analysis. |
| [datarhei Restreamer](https://github.com/datarhei/restreamer) | Process reports, real-time stream metrics, FFmpeg lifecycle UI/API. | Use as a product/UX reference, not as a replacement. | Its monitoring and process observability are capabilities MediaHub needs in its own admin. |
| [WhisperX](https://github.com/m-bain/whisperX) | Voice activity detection, word alignment and optional speaker diarization. | Benchmark after capture reliability is established. | It improves research value of transcripts, but cannot compensate for invalid or missing source clips. |

# Target architecture

```text
station source page
        |
        v
source resolver registry ──> candidate validation ──> approved capture session
 legacy / Streamlink / Ferrum diagnostic                         |
                                                                  v
                                                        FFmpeg or MediaMTX relay
                                                                  |
                                                                  v
                     segment validator ──> immutable archive ──> processing queue
                            |                                      |       |
                            +--> invalid-content event             |       +--> OCR / ASR / topics
                                                                   v
                                                      metrics, logs, alerts, admin
```

The `Station` record remains channel configuration. Operational facts must move to append-only capture sessions and events so the admin can distinguish “transport connected”, “content valid”, “renewing URL”, and “processing delayed”.

# Required features

## P0 — correctness and operational safety

Implement these before calling the system production-ready.

1. **Capture state machine and event history**
   - Add `CaptureSession` and `CaptureEvent` records.
   - States: `disabled`, `probing`, `capturing`, `degraded`, `invalid_content`, `renewing`, `failed`.
   - Persist state transitions, reason, resolver used, FFmpeg exit code, URL fingerprint (never raw query tokens), validation result and timestamps.
   - Make `Station#stream_status` a projection of the latest successful session rather than the only operational record.

2. **Pluggable content validation**
   - Keep the current size, duration and saturated-blue NPY rule.
   - Add per-channel validation rules: repeated-frame/frozen video, black screen, silence, OCR phrases, HLS playlist progress, missing audio and codec changes.
   - Sample multiple points of a segment and retain validator metrics. Never mark a station healthy from socket/HTTP success alone.
   - Reject invalid clips before archive and preserve a bounded quarantine sample with its diagnostic metadata.

3. **Atomic source renewal**
   - Model a candidate source separately from the active source.
   - Preflight each candidate with FFprobe/FFmpeg for video, audio, playlist progress and content validation.
   - Promote a candidate atomically only after it passes; roll back automatically if the first two segments fail.
   - Store required `Referer`, `User-Agent`, cookies and expiry time with the capture session. Pass them explicitly to FFmpeg. Do not rely on an HLS URL alone when the provider requires browser context.

4. **One lifecycle owner**
   - Replace nested Rake invocations and overlapping cron ownership with an orchestrator job/service that has a per-station lease.
   - systemd should supervise the process, but the application owns retries, exponential backoff, circuit breaking and renewal decisions.
   - Ensure one FFmpeg process, one resolver attempt and one importer can own a station at any instant.

5. **Idempotent segment ingestion**
   - Use a unique station/timestamp/content-hash key.
   - Write to a staging path, validate, fsync/rename into archive, then create the database record in an idempotent transaction.
   - Add retention rules and explicit cleanup/quarantine jobs. Do not expose temporary files under the Rails public directory.

## P1 — production observability

6. **Metrics and alerts**
   - Export Prometheus metrics: capture state, valid segment age, input/output bitrate, FFmpeg restarts, source-renewal successes/failures, validator rejection reasons, queue depth, transcription lag, GPU utilization, disk free space and dropped/duplicate clips.
   - Create Grafana dashboards per station and fleet-wide.
   - Alert on: no valid segment for 3 minutes, repeated invalid content, renewals exhausted, archive/import backlog, disk threshold, transcription SLA breach and a resolver-wide failure spike.
   - Route and deduplicate alerts with Alertmanager; its grouping and inhibition avoid turning a provider outage into dozens of independent notifications.

7. **Structured logs and diagnostics**
   - Emit JSON logs with `station_id`, capture-session id, resolver, event type and error class.
   - Save a redacted resolver trace, FFmpeg stderr tail and two diagnostic frames for failed sessions with bounded retention.
   - Add an admin timeline that answers: what happened, when, which source was attempted and why it was rejected.

8. **Health definitions and SLOs**
   - Define “healthy” as a recent content-valid segment, not a running service.
   - Establish baseline measurements first, then enforce: detection under 90 seconds, automatic recovery under 5 minutes for a recoverable source, zero imported known-error slates, and a documented per-channel capture-availability target.

## P2 — scalable processing and research value

9. **Durable asynchronous processing**
   - Use a durable queue with retries, dead-letter handling, idempotency keys and per-GPU concurrency controls.
   - Split capture, import, thumbnail/OCR, transcription, indexing and topic extraction into independently observable jobs.
   - Prevent capture from being blocked by a transcription backlog.

10. **Transcript quality pipeline**
    - Preserve ASR JSON, model/version, language, confidence and source media checksum.
    - Add word timestamps, VAD and optional diarization through a benchmarked WhisperX/faster-whisper path.
    - Support transcript correction/versioning and searchable offsets that open the exact video time.

11. **Search and editorial workflow**
    - Index transcript, OCR, station, broadcast time, topics and named entities.
    - Provide saved searches, clips/exports with provenance, review flags and source/validator evidence.

## P3 — resilience and deployment discipline

12. **Test and release gates**
    - Create fixtures for valid broadcast, expired session slate, black screen, silent audio, HTML error response and token expiry.
    - Unit-test resolver adapters and validators; integration-test a simulated HLS source; run a canary station before each deploy.
    - Add database backups, archive checksum verification, restore drills and a documented rollback.

13. **Storage and capacity policy**
    - Move long-term clips to object storage or a dedicated mounted archive volume; keep only a short local working set.
    - Track capacity by channel and lifecycle stage. Define retention, legal hold and deletion policies before scaling to radio and more TV stations.

14. **Relay pilot, not a rewrite**
    - Run MediaMTX beside the existing stack with one non-critical channel.
    - Compare valid-segment continuity, restart count, latency, CPU/GPU/disk use, recovery time and operational effort for 14 days.
    - Adopt it for relay/recording only if it improves those measurements; retain Rails as the control plane and source resolver.

# Recommended order of work

| Phase | Scope | Exit criterion |
| --- | --- | --- |
| 1 | P0.1–P0.4 and fixtures for existing stations | Every outage and invalid slate has an auditable state transition; no concurrent ownership. |
| 2 | P1 metrics, dashboard and alerts | An operator detects and diagnoses a failed channel without SSH. |
| 3 | P0.5 plus durable queue | No duplicate/lost clip under restart or worker failure; capture continues during processing backlog. |
| 4 | Transcript quality and search | Timed, attributable transcripts are reviewable and searchable. |
| 5 | MediaMTX canary and capacity/backup drills | Measured decision to adopt or reject relay infrastructure; restore and failure drills pass. |

# Current operational policy

- Keep `STREAM_DISCOVERY_METHOD=legacy` for all listener services.
- Use Ferrum only through a manually invoked diagnostic run and record the result in the station log.
- Enable new channels only after one validated segment and a successful renewal drill.
- Do not run the backlog-wide `process_videos` or transcription tasks until their queues, rejection handling and capacity limits are in place.
