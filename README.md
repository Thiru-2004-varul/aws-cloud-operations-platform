# aws-cloud-operations-platform

Production-grade AWS cloud infrastructure and operations platform built with
CloudFormation, Systems Manager, Secrets Manager, Ansible, and CloudWatch.
Covers the full operations lifecycle — provisioning, security, automation,
monitoring, disaster recovery, and incident response.

---

## Architecture
```
Internet
    │
    ▼
Application Load Balancer  (public, multi-AZ)
    │               │
    ▼               ▼
Ubuntu EC2      Ubuntu EC2
Private         Private
Subnet AZ-1     Subnet AZ-2
    │
    ├── Flask Application    (systemd, port 80)
    ├── CloudWatch Agent     (metrics and logs to CloudWatch)
    ├── SSM Agent            (zero-port server access)
    └── AWS Secrets Manager  (runtime credential fetch)
         │
    NAT Gateway (outbound only — AWS APIs, package installs)
```

- All EC2 instances in private subnets — no public IP
- Port 22 never opened — SSM Session Manager only
- IAM role on EC2 authenticates to all AWS services
- All sessions logged to S3 and CloudTrail automatically

---

## Stack dependency order
```
network-stack   →   security-stack   →   compute-stack
                                              │
                                         ssm-stack
                                         secrets-stack
                                         backup-stack
                                         monitoring-stack
```

Each stack exports values consumed by the next via `!ImportValue`.
Deploy in this order. Destroy in reverse.

---

## Prerequisites

- AWS CLI v2 configured
- Python 3.8+
- Git
```bash
aws sts get-caller-identity
aws configure get region
```

---

## Deploy
```bash
git clone https://github.com/Thiru-2004-varul/aws-cloud-operations-platform.git
cd aws-cloud-operations-platform

bash scripts/infra-up.sh
```

Deploys all 7 stacks in dependency order and prints the ALB DNS on completion.
Takes approximately 10 to 15 minutes.

---

## Verify
```bash
bash scripts/verify-all.sh
```

Checks all stack statuses, EC2 states, SSM registration, ALB target health,
and all application endpoints.

---

## Destroy
```bash
bash scripts/infra-down.sh
```

Deletes all stacks in reverse dependency order. Code is preserved in Git.
Cost drops to zero immediately after deletion.

---

## Connect to EC2

No SSH key. No open port. IAM identity only.
```bash
INSTANCE_ID=$(aws ec2 describe-instances \
  --region ap-south-1 \
  --filters \
    "Name=tag:Project,Values=cloud-ops" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

aws ssm start-session \
  --target $INSTANCE_ID \
  --region ap-south-1
```

---

## Ansible

Applies OS hardening, CloudWatch agent, SSM agent verification, and Flask app
deployment to all tagged instances simultaneously.
```bash
source venv/bin/activate
pip install ansible boto3 botocore
ansible-galaxy collection install amazon.aws

cd ansible
ansible-inventory -i inventory/aws_ec2.yaml --graph

ansible-playbook playbooks/linux-baseline.yml \
  -i inventory/aws_ec2.yaml \
  -e "ansible_connection=aws_ssm" \
  -e "ansible_aws_ssm_region=ap-south-1" \
  -v
```

---

## Administration

Run scripts on all EC2s via SSM Run Command — no SSH required.
```bash
aws ssm send-command \
  --targets "Key=tag:Project,Values=cloud-ops" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["bash /tmp/health-check.sh"]' \
  --region ap-south-1

aws ssm get-command-invocation \
  --command-id <COMMAND_ID> \
  --instance-id <INSTANCE_ID> \
  --region ap-south-1
```

| Script | Purpose |
|---|---|
| `health-check.sh` | CPU, memory, disk, services, network |
| `performance-analysis.sh` | Top processes, I/O, memory breakdown |
| `log-investigation.sh` | Syslog, auth, app, firewall logs |
| `service-management.sh` | Start, stop, restart, status |
| `disk-management.sh` | Usage, large files, cleanup |
| `network-troubleshoot.sh` | Ports, routes, DNS, AWS endpoints |

---

## Incident simulation
```bash
bash scripts/incidents/incident-1-ec2-failure.sh
bash scripts/incidents/incident-2-high-cpu.sh
bash scripts/incidents/incident-3-secret-failure.sh
```

Each script measures and prints detection time and RTO.
Results documented in `docs/incidents/` and `docs/dr/`.

---

## Application endpoints

| Endpoint | Description |
|---|---|
| `GET /` | Project name and environment |
| `GET /health` | Health check — used by ALB |
| `GET /metrics` | Uptime and status |
| `GET /secret-test` | Fetch app config from Secrets Manager |
| `GET /db-config` | Fetch DB credentials from Secrets Manager |
```bash
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name cloud-ops-dev-compute \
  --region ap-south-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text)

curl http://$ALB_DNS/health
curl http://$ALB_DNS/secret-test
```

---

## Monitoring

| Alarm | Threshold |
|---|---|
| EC2 status check failed | > 0 for 2 minutes |
| High CPU utilization | > 80% for 5 minutes |
| ALB 5xx error rate | > 10 in 3 minutes |
| Application error count | > 10 in 5 minutes |

All alarms notify via SNS. Dashboard available in CloudWatch console
under `cloud-ops-dev-operations`.

---

## CI/CD

Every push to `cloudformation/` runs cfn-lint and validate on all 7 templates.
Every push to `ansible/` runs ansible-lint and deploys baseline if EC2s are running.

---

## Security

| Control | Implementation |
|---|---|
| Network | EC2 in private subnets, no public IP |
| Access | Zero open ports, SSM Session Manager only |
| IAM | Least-privilege roles, no wildcard permissions |
| Secrets | KMS-encrypted, fetched at runtime |
| OS | Root login disabled, UFW firewall, idle timeout |
| Patching | SSM Patch Manager, weekly maintenance window |
| Audit | CloudTrail, SSM session logs to S3 |

---

## Environment

| Parameter | Value |
|---|---|
| Region | ap-south-1 |
| OS | Ubuntu Server 22.04 LTS |
| Instance type | t3.micro |
| VPC CIDR | 10.0.0.0/16 |
| Availability zones | ap-south-1a, ap-south-1b |
| ASG min / desired / max | 1 / 2 / 4 |

---

## Author

**Thiruvarul G**
[github.com/Thiru-2004-varul](https://github.com/Thiru-2004-varul) 

[linkedin.com/in/thiruvarul-g-051690260](https://linkedin.com/in/thiruvarul-g-051690260)