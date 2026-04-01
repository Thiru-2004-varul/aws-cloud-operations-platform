# INC-001 — EC2 Instance Failure
### Root Cause Analysis | AWS Cloud Operations Platform

---

## Executive Summary

A production EC2 instance hosting the Flask application experienced an unexpected
failure, causing complete service unavailability. The Auto Scaling Group detected
the failure and automatically launched a replacement instance. Full service was
restored within **78 seconds**, well within the 5-minute RTO target.

---

## Incident Details

| Field              | Detail                        |
|--------------------|-------------------------------|
| Incident ID        | INC-001                       |
| Date               | Wed Apr 1, 2026               |
| Severity           | P1 — Complete service outage  |
| Affected Instance  | i-04be8906c585ddf96           |
| Failure Time       | 07:38:01 AM EDT               |
| Recovery Time      | 07:39:19 AM EDT               |
| Total Downtime     | **78 seconds**                |
| RTO Target         | 5 minutes                     |
| RTO Achieved       | ✅ 1 minute 18 seconds        |

---

## Timeline of Events

| Time (EDT)  | Event                                                                 |
|-------------|-----------------------------------------------------------------------|
| 07:37:56    | Pre-failure health check passed — `{"status":"healthy","uptime":1817s}` |
| 07:38:01    | EC2 instance `i-04be8906c585ddf96` stopped — failure triggered       |
| 07:38:31    | ALB detected unhealthy target — HTTP response code `000`             |
| 07:38:31    | ALB marked instance as `unused` — traffic routing stopped            |
| 07:38:58    | Recovery initiated — EC2 start command issued                         |
| 07:39:19    | Instance reached `running` state — ASG launched replacement          |
| 07:39:49    | Post-recovery check — `502 Bad Gateway` (new instance in `initial`)  |

---

## What Happened

The sole EC2 instance running the Flask application was stopped, simulating an
unplanned instance failure. The Application Load Balancer (ALB) detected the
unhealthy target within 30 seconds and stopped routing traffic to it.

During the failure window, all incoming requests returned HTTP `000` (connection
refused) — meaning the application was completely unreachable.

On recovery, the Auto Scaling Group launched a replacement instance
(`i-038e69f582b4f594d`). However, a brief `502 Bad Gateway` window occurred
because the original instance was in `draining` state while the new instance was
still completing its ALB health check (`initial` state). Once the new instance
passed health checks, traffic resumed normally.

---

## Root Cause

The core issue was **no redundancy** — the ASG was configured with a minimum
capacity of 1 instance in a single Availability Zone.

When that single instance failed:
- The ALB had zero healthy targets
- No warm standby instance existed to absorb traffic immediately
- The new instance required a full cold boot + ALB registration cycle
- This created an unavoidable hard downtime window of 78 seconds

---

## Impact Assessment

| Category          | Impact                                              |
|-------------------|-----------------------------------------------------|
| Service           | 100% unavailable for 78 seconds                    |
| Requests affected | All requests returned HTTP `000` or `502`           |
| Data loss         | None — Flask app is stateless                       |
| Revenue impact    | Minimal (dev environment)                           |
| Users affected    | All users during failure window                     |

---

## Resolution Steps

1. EC2 start command issued via AWS CLI
2. ASG detected capacity deficit and launched replacement instance
3. ALB registered new instance and began health checks
4. Traffic resumed after new instance passed 2 consecutive health checks

---

## Lessons Learned

- Single-instance ASG provides **zero fault tolerance**
- ALB health check interval (30s) directly determines detection-to-failover time
- `502 Bad Gateway` after recovery means health check grace period needs tuning
- No automated alerting fired during the outage — monitoring gap identified

---

## Corrective Actions

| Priority | Action Item                                              | Owner | ETA    |
|----------|----------------------------------------------------------|-------|--------|
| 🔴 High  | Set ASG min capacity to 2 instances across 2 AZs        | Infra | Week 1 |
| 🔴 High  | Enable EC2 Auto Recovery for hardware-level failures     | Infra | Week 1 |
| 🟡 Med   | Reduce ALB health check interval from 30s to 10s        | Infra | Week 2 |
| 🟡 Med   | Set ALB healthy threshold to 2 for faster re-registration| Infra | Week 2 |
| 🟢 Low   | Add CloudWatch alarm on `UnHealthyHostCount > 0`        | Ops   | Week 3 |

---

## DR Validation Results

| Metric              | Target      | Actual              | Status      |
|---------------------|-------------|---------------------|-------------|
| RTO                 | < 5 min     | 78 seconds          | ✅ PASS     |
| Auto-recovery       | Yes         | Yes — ASG relaunched| ✅ PASS     |
| Zero data loss      | Yes         | Yes — stateless app | ✅ PASS     |
| Zero-downtime failover | Yes      | 502 briefly observed| ⚠️ PARTIAL  |