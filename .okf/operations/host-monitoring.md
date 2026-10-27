---
type: Operations
title: Host monitoring and crash evidence
description: Persistent host snapshots, crash evidence, and CPU-isolation guidance for the MediaHub server.
tags: [monitoring, systemd, gpu, cpu, crash, operations]
resource: bin/mediahub-host-monitor
---

# Host monitoring

`mediahub-host-monitor.timer` records a compact health snapshot every minute in `/var/log/mediahub/host-monitor.log` and the system journal. It records boot ID, load average, available RAM, root and media-disk utilization, Rails state, running listener count, failed systemd units, new core dumps, and NVIDIA GPU utilization/memory/temperature when available.

The monitor writes a journal warning for low available memory (under 8 GB), root or media storage above 85%, inactive Rails, failed units, new core dumps, GPU temperature at or above 85°C, or GPU memory at or above 90%.

Inspect it with:

```bash
systemctl status mediahub-host-monitor.timer
tail -n 120 /var/log/mediahub/host-monitor.log
journalctl -t mediahub-host-monitor --since '2 hours ago'
coredumpctl list --since '2 hours ago'
```

This captures evidence before a user-space crash. A total kernel freeze or power loss cannot write a final record, so compare the last snapshot's boot ID and timestamp to the next boot. A hardware watchdog may shorten recovery only after the machine exposes a reliable `/dev/watchdog`; do not enable one blindly.

Core dumps must be classified, not treated as a single incident. FFmpeg `SIGFPE` signal-8 failures have a timestamp-normalization mitigation and a dedicated [FFmpeg incident runbook](ffmpeg-sigfpe.md). Separate Ruby listener `SIGSEGV` dumps remain an open P0 investigation in [production open work](../decisions/open-work.md).

# CPU affinity and AI workloads

The server has an Intel i9-14900F with 32 online logical CPUs. The historic command `taskset -c 0-7,10-31 llama-server ...` excluded logical CPUs 8 and 9 **only for that one `llama-server` process**. On this host those two logical CPUs are the two threads of the same performance core (physical core 4), so the command deliberately leaves one complete P-core available to the operating system and competing work. It did not offline cores, change kernel scheduling, constrain Rails, or constrain FFmpeg. When that process exits, the restriction disappears.

Do not disable CPU cores globally as a response to these MediaHub crashes: current evidence does not show a CPU-core failure. This `taskset` pattern is a reasonable, narrow isolation measure for an explicitly launched `llama-server`; retain it if that is the AI runtime being used. If the AI runtime is Ollama instead, apply equivalent affinity and resource limits to Ollama's actual inference runner rather than assuming this old command affects it. Measure before reserving more cores; CPU pinning cannot resolve a kernel, driver, Ruby, or FFmpeg crash.
