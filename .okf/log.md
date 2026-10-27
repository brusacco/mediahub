# 2026-10-27

- Created the initial MediaHub knowledge bundle.
- Documented the Rails/Puma and mitmproxy services on the local server.
- Recorded capture and stream-renewal limitations before enabling listeners.
- Added boot-enabled per-station listener services and documented serialized stream renewal with headless Chrome fallback.
- Added the complete project Rake task catalog, framework-task reference, and README operational entrypoint.
- Reconciled scheduling documentation: production recurring processing is owned by systemd timers, not Cron/Whenever.
- Documented the `mediahub` start/stop/status/boot-policy control surface and all-stack verification.
- Added FFmpeg `SIGFPE` incident evidence, timestamp-normalization mitigation, safe diagnostic procedure, and managed-upgrade canary policy.
- Recorded remaining production P0/P1/P2 work, including Ruby listener crashes, OCR integration repair, failed-ingestion triage, alerting, and backup/restore discipline.
