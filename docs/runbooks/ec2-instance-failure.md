# Runbook: EC2 Instance Failure

**Severity:** P2
**RTO Target:** 8 minutes

## Detection
- CloudWatch alarm `cloud-ops-dev-ec2-status-check` fires
- ALB health check marks instance unhealthy
- SNS alert sent to team

## Immediate actions — L1

1. Check EC2 instance state
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=cloud-ops" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
  --output table \
  --region ap-south-1
```

2. Check ALB target health
```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region ap-south-1
```

3. If instance stopped — start it
```bash
aws ec2 start-instances \
  --instance-ids <INSTANCE_ID> \
  --region ap-south-1
```

4. Verify app recovered
```bash
curl http://<ALB_DNS>/health
```

## Escalation — L2

If instance does not recover in 5 minutes:

1. List available recovery points
```bash
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name cloud-ops-dev-backup-vault \
  --region ap-south-1
```

2. Restore from latest recovery point via AWS Console
   - Go to AWS Backup → Restore
   - Select latest recovery point
   - Restore to same subnet and security group
   - Attach same IAM instance profile

3. Verify SSM connects to restored instance
```bash
aws ssm describe-instance-information --region ap-south-1
```

4. Run Ansible baseline on restored instance
```bash
cd ansible
ansible-playbook playbooks/linux-baseline.yml
```

## Post incident

- Document actual RTO in docs/dr/dr-test-results.md
- Check if Auto Scaling replaced instance automatically
- Update this runbook if any steps were wrong