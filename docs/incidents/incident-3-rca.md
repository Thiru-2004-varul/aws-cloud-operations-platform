# INC-003 — Secret Rotation Failure
### Root Cause Analysis | AWS Cloud Operations Platform

---

## Executive Summary

A secret rotation failure was simulated by injecting a broken value into AWS
Secrets Manager for the key `cloud-ops/dev/app/config`. The Flask application was
restarted via SSM to force secret reload. Failure was detected in **24 seconds**.
The automated rollback script failed due to a missing required parameter in the
AWS CLI command, leaving the secret in a broken state. The correct rollback
procedure is documented below.

---

## Incident Details

| Field              | Detail                                      |
|--------------------|---------------------------------------------|
| Incident ID        | INC-003                                     |
| Date               | Wed Apr 1, 2026                             |
| Severity           | P2 — Application configuration failure      |
| Affected Instance  | i-038e69f582b4f594d                         |
| Secret Affected    | `cloud-ops/dev/app/config`                  |
| Incident Started   | 07:51:35 AM EDT                             |
| Detected At        | 07:52:03 AM EDT                             |
| Detection Time     | ✅ **24 seconds**                           |
| Recovery Status    | ❌ Rollback script failed — bug identified  |

---

## Timeline of Events

| Time (EDT)  | Event                                                                 |
|-------------|-----------------------------------------------------------------------|
| 07:51:23    | Incident 3 initiated                                                  |
| 07:51:35    | Original secret backed up locally                                     |
| 07:51:35    | Secret `cloud-ops/dev/app/config` overwritten with broken value      |
| 07:51:35    | Broken version assigned: `637b4023-9392-43a0-89ff-62d5795c4b54` (AWSCURRENT) |
| 07:51:52    | SSM command sent — `systemctl restart flask-app`                     |
| 07:51:59    | Flask app restarted — loaded broken secret                           |
| 07:52:03    | Detection check — `/secret-test` returned `404 Not Found`            |
| 07:52:03    | **Failure confirmed — detection time: 24 seconds**                   |
| 07:52:03    | Recovery attempted — `UpdateSecretVersionStage` API call             |
| 07:52:03    | ❌ Rollback FAILED — `InvalidParameterException`                     |

---

## What Happened

The incident simulated a real-world secret rotation failure where a bad secret
value gets deployed to production. AWS Secrets Manager was updated with an invalid
configuration value for `cloud-ops/dev/app/config`. The Flask application was
then restarted via SSM Run Command to force it to reload configuration from
Secrets Manager on startup.

After restart, the application failed to initialize its secret-dependent API
routes (`/secret-test`, `/db-config`), which returned `404 Not Found`. Core
endpoints (`/health`, `/metrics`, `/`) remained fully operational at `200 OK`,
demonstrating that the failure was isolated to secret-dependent functionality.

**Detection was excellent at 24 seconds.** The failure point was the recovery step.

---

## Root Cause

### Primary — Broken secret caused partial app initialization failure
The Flask application reads secrets from Secrets Manager at startup. When the
secret value was invalid, the app could not initialize the secret-dependent
routes, causing targeted `404` errors while keeping core routes healthy.

### Secondary — Rollback script bug: missing `RemoveFromVersionId`

The recovery script called `UpdateSecretVersionStage` to promote the previous
version back to `AWSCURRENT`. The command failed with:
```
An error occurred (InvalidParameterException) when calling the
UpdateSecretVersionStage operation: The parameter RemoveFromVersionId
can't be empty. Staging label AWSCURRENT is currently attached to
version 637b4023-9392-43a0-89ff-62d5795c4b54, so you must explicitly
reference that version in RemoveFromVersionId.
```

AWS Secrets Manager requires you to explicitly declare which version you are
**removing** `AWSCURRENT` from when reassigning the label. The script omitted
the `--remove-from-version-id` parameter entirely.

---

## Secrets Manager State During Incident

| Version ID                              | Stage       | State    |
|-----------------------------------------|-------------|----------|
| `2ae30309-8635-99ee-1474-d5e759124d62`  | AWSPREVIOUS | ✅ Good  |
| `637b4023-9392-43a0-89ff-62d5795c4b54`  | AWSCURRENT  | ❌ Broken|

---

## Correct Recovery Procedure
```bash
# Step 1 — Rollback secret to previous known-good version
aws secretsmanager update-secret-version-stage \
  --secret-id cloud-ops/dev/app/config \
  --version-stage AWSCURRENT \
  --move-to-version-id 2ae30309-8635-99ee-1474-d5e759124d62 \
  --remove-from-version-id 637b4023-9392-43a0-89ff-62d5795c4b54 \
  --region ap-south-1

# Step 2 — Restart app to load restored secret
aws ssm send-command \
  --instance-ids i-038e69f582b4f594d \
  --document-name AWS-RunShellScript \
  --parameters commands=["systemctl restart flask-app"] \
  --region ap-south-1

# Step 3 — Verify recovery
curl -s http://<ALB-DNS>/secret-test
```

---

## Impact Assessment

| Category               | Impact                                          |
|------------------------|-------------------------------------------------|
| `/secret-test`         | ❌ 404 Not Found                               |
| `/db-config`           | ❌ 404 Not Found                               |
| `/health`              | ✅ 200 OK — unaffected                         |
| `/metrics`             | ✅ 200 OK — unaffected                         |
| `/`                    | ✅ 200 OK — unaffected                         |
| Detection time         | ✅ 24 seconds                                  |
| Secret rollback        | ❌ Failed — script bug                         |

---

## Lessons Learned

- AWS Secrets Manager versioning (`AWSCURRENT` / `AWSPREVIOUS`) works correctly
  and provides instant rollback capability — when the rollback script is correct
- Detection of secret failures is fast (24s) using SSM + app restart validation
- The `UpdateSecretVersionStage` API requires **both** `--move-to-version-id`
  AND `--remove-from-version-id` — omitting either causes `InvalidParameterException`
- Apps should implement graceful secret fallback — cache last known good value
  instead of hard-failing on bad secret at startup
- `/secret-test` returning `404` in normal pre-incident state makes it difficult
  to distinguish "route not registered" from "secret broken" without clear runbooks

---

## Corrective Actions

| Priority | Action Item                                                           | Owner | ETA    |
|----------|-----------------------------------------------------------------------|-------|--------|
| 🔴 High  | Fix rollback script — add `--remove-from-version-id` parameter       | Dev   | Week 1 |
| 🔴 High  | Implement secret caching in Flask with fallback to last good value    | Dev   | Week 1 |
| 🟡 Med   | Enable Secrets Manager rotation with Lambda pre-validation            | Infra | Week 2 |
| 🟡 Med   | Add CloudWatch alarm on Secrets Manager `ResourceNotFoundException`   | Ops   | Week 2 |
| 🟢 Low   | Create SSM Document runbook for standard secret rollback procedure    | Ops   | Week 3 |

---

## DR Validation Results

| Metric                  | Target    | Actual                    | Status      |
|-------------------------|-----------|---------------------------|-------------|
| Detection time          | < 60 sec  | **24 seconds**            | ✅ PASS     |
| SSM app restart         | Working   | Working                   | ✅ PASS     |
| Secret version history  | Available | 2 versions present        | ✅ PASS     |
| Core app availability   | Maintained| All core endpoints 200 OK | ✅ PASS     |
| Automated rollback      | Working   | Script bug — failed       | ❌ FAIL     |