# INC-002 — High CPU Utilization
### Root Cause Analysis | AWS Cloud Operations Platform

---

## Executive Summary

A high CPU utilization scenario was simulated on the production EC2 instance using
AWS SSM Run Command. The CPU stress tool was executed remotely, monitored via
CloudWatch for 10 minutes, and terminated via a follow-up SSM kill command. The
CloudWatch alarm **did not trigger** due to insufficient CPU load and missing
CloudWatch agent on the replacement instance. The process was successfully killed
and CPU returned to idle immediately.

---

## Incident Details

| Field              | Detail                          |
|--------------------|---------------------------------|
| Incident ID        | INC-002                         |
| Date               | Wed Apr 1, 2026                 |
| Severity           | P2 — Performance degradation    |
| Affected Instance  | i-038e69f582b4f594d             |
| Incident Started   | 07:40:00 AM EDT                 |
| Resolved At        | 07:51:23 AM EDT                 |
| Total Duration     | **683 seconds (~11 min 23 sec)**|
| Alarm Triggered    | ❌ No                           |
| SSM Execution      | ✅ Successful                   |

---

## Timeline of Events

| Time (EDT)  | Event                                                              |
|-------------|--------------------------------------------------------------------|
| 07:39:53    | Incident 2 initiated — target instance identified                  |
| 07:40:00    | CPU stress launched via SSM — Command: `bac84214-3d7a-4cca-b0c3-b9e91fc6b991` |
| 07:41:00    | Minute 1 — Alarm: OK, CPU: 0.005%                                 |
| 07:42:00    | Minute 2 — Alarm: OK, CPU: 35.08% (peak)                         |
| 07:43:00    | Minute 3–5 — Alarm: OK, CPU: None (metric gaps)                   |
| 07:46:00    | Minute 6 — Alarm: OK, CPU: 0.21%                                  |
| 07:47:00    | Minute 7 — Alarm: OK, CPU: 0.18%                                  |
| 07:48:00    | Minute 8–10 — Alarm: OK, CPU: None (metric gaps)                  |
| 07:51:06    | Kill command sent via SSM — `c5ec8c5d-e5c7-4b7c-905c-474218aa60bf` |
| 07:51:23    | CPU confirmed idle: `100.0% idle, 0% user`                        |

---

## What Happened

A CPU stress simulation was launched remotely on instance `i-038e69f582b4f594d`
using AWS SSM Run Command — demonstrating the ability to execute commands on EC2
instances without SSH access.

The stress tool ran for approximately 360 seconds. However, it only drove CPU to
a peak of **35%** — well below the configured CloudWatch alarm threshold of 80%.
Additionally, multiple minutes of monitoring showed CPU as `None`, indicating
missing metric data from CloudWatch.

The CloudWatch `HighCPUAlarm` never transitioned to `ALARM` state.

The incident was remediated by sending a second SSM Run Command to identify and
kill the stress process. CPU returned to 100% idle immediately after termination.

---

## Root Cause

### Factor 1 — Stress tool did not generate sufficient CPU load
The CPU stress simulation ran inside an SSM document worker process. The SSM agent
itself consumed significant CPU (62% observed on `ssm-document-worker`), which
limited the effective stress load. Peak application CPU reached only 35% — 45
percentage points below the alarm threshold of 80%.

### Factor 2 — CloudWatch agent not running on replacement instance
The replacement instance (`i-038e69f582b4f594d`) was launched automatically by the
ASG during Incident 1 recovery. It was a fresh instance with no CloudWatch agent
bootstrapped — causing CPU metric data to be missing (`None`) for multiple
monitoring periods.

The alarm configuration required 2 consecutive 5-minute periods above 80% to fire.
With missing metrics and insufficient CPU load, the alarm condition was never met.

---

## Impact Assessment

| Category          | Impact                                              |
|-------------------|-----------------------------------------------------|
| Service           | Not affected — app remained healthy throughout     |
| Alarm detection   | Failed — no alert fired                             |
| Observability     | Degraded — metric gaps on replacement instance      |
| Remediation       | Successful — SSM kill command worked correctly      |

---

## Evidence

**Top processes at time of kill:**
```
USER    PID  %CPU  COMMAND
root   3411  62.0  ssm-document-worker
root   1220   0.7  ssm-agent-worker
root    429   0.5  snapd
root      1   0.2  /sbin/init
```

**CPU after kill:**
```
%Cpu(s): 0.0 us, 0.0 sy, 0.0 ni, 100.0 id
```

---

## Lessons Learned

- Alarm threshold of 80% over 2×5min periods is too high for detecting burst spikes
- SSM Run Command is a powerful remote execution tool — no SSH required
- CloudWatch agent must be bootstrapped at instance launch via SSM State Manager
- Metric gaps (`None`) silently prevent alarms from firing — a dangerous blind spot
- Stress tools running inside SSM workers have limited CPU impact due to agent overhead

---

## Corrective Actions

| Priority | Action Item                                                    | Owner | ETA    |
|----------|----------------------------------------------------------------|-------|--------|
| 🔴 High  | Bootstrap CloudWatch agent via SSM State Manager on all new instances | Infra | Week 1 |
| 🔴 High  | Add 60% CPU alarm with 1-period evaluation for burst detection | Ops   | Week 1 |
| 🟡 Med   | Switch stress tool to `stress-ng` with explicit worker count   | Infra | Week 2 |
| 🟡 Med   | Add `mem_used_percent` and `disk_used_percent` custom metrics  | Infra | Week 2 |
| 🟢 Low   | Create composite alarm combining CPU + memory thresholds       | Ops   | Week 3 |

---

## DR Validation Results

| Metric                    | Target      | Actual            | Status      |
|---------------------------|-------------|-------------------|-------------|
| CloudWatch alarm detection| < 5 min     | Did not trigger   | ❌ FAIL     |
| SSM remote execution      | Working     | Working           | ✅ PASS     |
| Remote process kill       | Working     | Working           | ✅ PASS     |
| CPU recovery after kill   | Immediate   | Immediate         | ✅ PASS     |
| CloudWatch metric stream  | Continuous  | Gaps present      | ⚠️ PARTIAL  |