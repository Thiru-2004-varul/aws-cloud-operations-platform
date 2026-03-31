# Runbook: High CPU Incident

**Severity:** P3
**Response time:** 10 minutes

## Detection
- CloudWatch alarm `cloud-ops-dev-high-cpu` fires
- CPU above 80 percent for 5 consecutive minutes
- SNS alert sent to team

## Immediate actions — L1

1. Identify which instance has high CPU
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=cloud-ops-dev-ubuntu-asg \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --region ap-south-1
```

2. Connect via SSM and find offending process
```bash
aws ssm start-session --target <INSTANCE_ID> --region ap-south-1
top -bn1 | head -20
ps aux --sort=-%cpu | head -10
```

3. Kill offending process if confirmed safe
```bash
kill -9 <PID>
```

4. Check CloudWatch Log Insights for errors
```
fields @timestamp, @message
| filter @logStream like /INSTANCE_ID/
| sort @timestamp desc
| limit 50
```

## Escalation — L2

If CPU remains high after killing process:
1. Check Auto Scaling is adding instances
2. Check ALB access logs for unusual traffic spike
3. Scale out manually if needed

## Post incident

- Document which process caused the spike
- Add specific process monitoring if recurring
- Consider right-sizing if CPU is consistently high