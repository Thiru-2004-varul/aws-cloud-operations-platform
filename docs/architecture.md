# AWS Cloud Operations Platform — Architecture

## Overview
End-to-end AWS infrastructure and operations platform demonstrating
build, operate, secure, automate, and recover capabilities.

## Architecture diagram
```
Internet
    |
    v
Application Load Balancer (public, multi-AZ)
    |
    v
Ubuntu EC2 Auto Scaling Group (private subnets, 2 AZs)
    |
    +-- Flask app (systemd service, port 80)
    +-- CloudWatch agent (metrics + logs)
    +-- SSM agent (Session Manager access)
    +-- AWS Secrets Manager (runtime credentials)
    +-- HashiCorp Vault (enterprise secrets)
```

## Infrastructure layers

| Layer | Tool | Stack |
|---|---|---|
| Network | CloudFormation | network-stack.yaml |
| Security | CloudFormation | security-stack.yaml |
| Compute | CloudFormation | compute-stack.yaml |
| Operations | CloudFormation | ssm-stack.yaml |
| Secrets | CloudFormation | secrets-stack.yaml |
| Backup | CloudFormation | backup-stack.yaml |
| Monitoring | CloudFormation | monitoring-stack.yaml |

## Security design

- EC2 in private subnets — no public IP
- No open SSH ports — SSM Session Manager only
- IAM least-privilege roles
- KMS encryption for all secrets
- UFW firewall on every instance
- Automatic OS patching via SSM Patch Manager

## Monitoring and alerting

| Alarm | Threshold | Action |
|---|---|---|
| EC2 status check failed | > 0 for 2 min | SNS alert |
| High CPU | > 80% for 5 min | SNS alert |
| ALB 5xx errors | > 10 in 3 min | SNS alert |
| App error count | > 10 in 5 min | SNS alert |

## DR capability

| Scenario | RTO | RPO | Method |
|---|---|---|---|
| EC2 failure | < 8 min | 24 hours | AWS Backup restore |
| AZ failure | < 2 min | 0 | ALB multi-AZ routing |
| Secret rotation failure | < 5 min | 0 | Secret version rollback |