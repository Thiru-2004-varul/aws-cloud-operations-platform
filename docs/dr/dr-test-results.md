# DR Test Results

## Test 1 — EC2 Instance Failure

**Date:** Fill after running simulation
**Tester:** Thiruvarul G
**RTO Target:** 8 minutes

| Step | Time | Result |
|---|---|---|
| Instance stopped | T+0 | Simulated |
| CloudWatch alarm fired | T+X min | Fill after test |
| ALB routed to healthy instance | T+X min | Fill after test |
| Instance restored | T+X min | Fill after test |
| App health check passed | T+X min | Fill after test |

**Actual RTO achieved:** X minutes
**RPO:** 24 hours (daily backup schedule)
**Result:** Pass / Fail

---

## Test 2 — High CPU Incident

**Date:** Fill after running simulation
**Tester:** Thiruvarul G

| Step | Time | Result |
|---|---|---|
| CPU stress started | T+0 | Simulated |
| CloudWatch alarm fired | T+X min | Fill after test |
| Root cause identified via SSM | T+X min | Fill after test |
| Process killed | T+X min | Fill after test |
| CPU normalised | T+X min | Fill after test |

**Time to root cause:** X minutes
**Result:** Pass / Fail

---

## Test 3 — Secret Rotation Failure

**Date:** Fill after running simulation
**Tester:** Thiruvarul G

| Step | Time | Result |
|---|---|---|
| Secret changed manually | T+0 | Simulated |
| 5xx errors detected | T+X min | Fill after test |
| CloudWatch alarm fired | T+X min | Fill after test |
| Root cause identified | T+X min | Fill after test |
| Secret rolled back | T+X min | Fill after test |
| App recovered | T+X min | Fill after test |

**Time to recovery:** X minutes
**Result:** Pass / Fail