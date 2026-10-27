---
type: Incident runbook
title: FFmpeg SIGFPE during live capture
description: Diagnose and mitigate FFmpeg crashes caused by invalid or non-monotonic source timestamps.
tags: [operations, ffmpeg, sigfpe, capture, incident]
resource: lib/tasks/stream/listen_station.rake
---

# Meaning and scope

`FFmpeg terminó por señal 8` is a process signal (`SIGFPE`), **not** FFmpeg exit code `8`. In Ruby it is represented by `exitstatus=nil` and `termsig=8`. It means FFmpeg crashed before returning a normal exit status; it does not by itself prove a hardware failure or a literal division by zero in MediaHub.

The incident evidence collected on 2026-10-27 showed FFmpeg core dumps in `libavcodec` while sending encoded frames. Affected HLS inputs also emitted `Queue input is backward in time` from AAC processing. The capture command uses CPU `libx264` and AAC; it does not use NVENC, so the RTX 3090 driver is not the primary explanation for this failure family. Network/source failures remain a separate class and normally return an ordinary non-zero exit status.

# Mitigation deployed

The listener now applies HLS input/protocol options before `-i`, so generation of missing timestamps, corrupt-packet discard, reconnect behavior and read timeout apply to the source rather than the output. It also normalizes input audio timestamps before AAC encoding:

```text
-af aresample=async=1:first_pts=0
```

It explicitly uses `-aac_coder fast` and no longer forces `twoloop`. This specifically reduces risk from discontinuous HLS audio timestamps. It is a mitigation, not a guarantee that a malformed upstream stream cannot crash an older FFmpeg build.

For each FFmpeg exit, MediaHub retains a bounded, redacted stderr tail and signal number in the capture-session metadata and shows a diagnostic summary in the station administration view. Signed URLs, cookies, and tokens must never be copied into tickets or documentation.

# First response

1. Confirm the listener and recent segment age with `mediahub status` and the station page in `/admin`.
2. Read the listener journal and the most recent capture session diagnostic:

   ```bash
   sudo journalctl -u mediahub-listener@<station-id>.service -n 200 --no-pager
   ```

3. If the listener is not recovering by itself, restart only its supervised unit:

   ```bash
   sudo systemctl restart mediahub-listener@<station-id>.service
   ```

   Do not start FFmpeg manually beside a listener service; that creates competing capture ownership.

4. Distinguish the failure class before changing source configuration:

   | Evidence | Interpretation | Next action |
   | --- | --- | --- |
   | `termsig=8`, core dump, `SIGFPE` | FFmpeg crash, often timestamp/codec-path related | Preserve diagnostics; verify mitigation; use managed restart. |
   | `Queue input is backward in time` | Source timestamps are discontinuous | Confirm `aresample=async=1:first_pts=0` is active. |
   | HTTP/timeout/TLS/playlist failure with normal exit | Source or network failure | Follow [channel recovery](channel-recovery.md). |
   | Blue/black/invalid clip | Transport may work but content is invalid | Let validator reject it and trigger source renewal. |

# Evidence collection

Use core dumps only for diagnosis. They may be large and are host-sensitive operational data.

```bash
sudo coredumpctl list --since '2 hours ago'
sudo coredumpctl info <pid>
sudo coredumpctl debug <pid> --debugger-arguments='-batch -ex bt'
```

Verify the deployed command without printing complete process arguments, since those may contain temporary stream credentials:

```bash
ps -eo args | grep '^ffmpeg ' | grep -cF 'aresample=async=1:first_pts=0'
ps -eo args | grep '^ffmpeg ' | grep -cF 'aac_coder twoloop'
```

The first count should cover active FFmpeg captures; the second should be `0`.

# Version policy and follow-up

Ubuntu Jammy currently provides FFmpeg `4.4.2` from its standard repository. Do not replace it ad hoc on a live capture fleet. A newer managed build can be evaluated on one canary listener with a documented rollback, then compared for valid-segment continuity, core dumps, CPU use and recovery behavior for at least 24–72 hours.

Open follow-up work is tracked in [production open work](../decisions/open-work.md): validate the mitigation over time, triage the independent Ruby listener crashes, control core-dump retention, and execute a canary plan for a newer FFmpeg build.
