# Runbook: Secret Rotation Failure

**Severity:** P1
**Response time:** 5 minutes

## Detection
- CloudWatch alarm `cloud-ops-dev-alb-5xx-errors` fires
- Application returning 500 errors on database endpoints
- Triggered after a Secrets Manager rotation event

## Immediate actions — L1

1. Check 5xx error rate
```bash
aws cloudwatch describe-alarms \
  --alarm-names cloud-ops-dev-alb-5xx-errors \
  --region ap-south-1
```

2. Check Secrets Manager for recent rotation
```bash
aws secretsmanager describe-secret \
  --secret-id cloud-ops/dev/db/credentials \
  --region ap-south-1
```

3. List secret versions to find previous version
```bash
aws secretsmanager list-secret-version-ids \
  --secret-id cloud-ops/dev/db/credentials \
  --region ap-south-1
```

4. Rollback secret to previous version
```bash
aws secretsmanager update-secret-version-stage \
  --secret-id cloud-ops/dev/db/credentials \
  --version-stage AWSCURRENT \
  --move-to-version-id <PREVIOUS_VERSION_ID> \
  --region ap-south-1
```

5. Restart app to pick up rolled-back secret
```bash
aws ssm send-command \
  --targets "Key=tag:Project,Values=cloud-ops" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl restart flask-app"]' \
  --region ap-south-1
```

6. Verify app recovered
```bash
curl http://<ALB_DNS>/health
curl http://<ALB_DNS>/db-config
```

## Escalation — L2

If rollback does not fix the issue:
1. Manually verify DB password matches secret value
2. Check DB logs for authentication failures
3. Manually update secret to match current DB password

## Post incident

- Fix rotation Lambda to update DB password atomically
- Test rotation in dev before enabling in prod
- Add rotation failure alarm to Secrets Manager