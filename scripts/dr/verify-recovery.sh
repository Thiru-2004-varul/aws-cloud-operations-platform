#!/bin/bash

REGION="ap-south-1"
PROJECT="cloud-ops"
ENV="dev"

echo "========== RECOVERY VERIFICATION =========="
echo "Time: $(date)"
echo ""

ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name cloud-ops-dev-compute \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text)

echo "--- App Health Check ---"
curl -s http://$ALB_DNS/health
echo ""

echo "--- EC2 Instance States ---"
aws ec2 describe-instances \
  --region $REGION \
  --filters \
    "Name=tag:Project,Values=$PROJECT" \
    "Name=tag:Environment,Values=$ENV" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]' \
  --output table

echo ""
echo "--- SSM Connected Instances ---"
aws ssm describe-instance-information \
  --region $REGION \
  --query 'InstanceInformationList[*].[InstanceId,PingStatus,PlatformName]' \
  --output table

echo ""
echo "--- CloudWatch Alarms Status ---"
aws cloudwatch describe-alarms \
  --alarm-name-prefix "cloud-ops-dev" \
  --region $REGION \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table

echo ""
echo "--- Recent Backup Recovery Points ---"
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name cloud-ops-dev-backup-vault \
  --region $REGION \
  --query 'RecoveryPoints[0:3].[Status,CreationDate]' \
  --output table

echo ""
echo "=========================================="