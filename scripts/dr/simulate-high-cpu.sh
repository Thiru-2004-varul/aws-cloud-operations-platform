#!/bin/bash
set -e

REGION="ap-south-1"

echo "========== DR SIMULATION 2 — HIGH CPU INCIDENT =========="
echo "Start time: $(date)"
echo ""

INSTANCE_ID=$(aws ssm describe-instance-information \
  --region $REGION \
  --query 'InstanceInformationList[0].InstanceId' \
  --output text)

echo "Target instance: $INSTANCE_ID"
echo ""

COMMAND_ID=$(aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "apt-get install -y stress 2>/dev/null || true",
    "stress --cpu 4 --timeout 300 &",
    "echo CPU stress started for 300 seconds"
  ]' \
  --region $REGION \
  --query 'Command.CommandId' \
  --output text)

echo "SSM Run Command ID : $COMMAND_ID"
echo ""
echo "CPU stress running for 300 seconds"
echo "Watch CloudWatch — HighCPU alarm fires within 5 minutes"
echo ""
echo "Check alarm status:"
echo "aws cloudwatch describe-alarms --alarm-names cloud-ops-dev-high-cpu --region $REGION"
echo ""
echo "Check command output:"
echo "aws ssm get-command-invocation --command-id $COMMAND_ID --instance-id $INSTANCE_ID --region $REGION"