#!/bin/bash
set -e

REGION="ap-south-1"
PROJECT="cloud-ops"

echo "=========================================="
echo "  INCIDENT 2 — HIGH CPU"
echo "  $(date)"
echo "=========================================="
echo ""

INSTANCE_ID=$(aws ssm describe-instance-information \
  --region $REGION \
  --query 'InstanceInformationList[0].InstanceId' \
  --output text)

echo "Target instance: $INSTANCE_ID"
echo ""

echo "--- PRE-INCIDENT CPU CHECK ---"
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --region $REGION \
  --query 'Datapoints[*].[Timestamp,Average]' \
  --output table

echo ""
echo "--- SIMULATING HIGH CPU ---"
INCIDENT_TIME=$(date +%s)

COMMAND_ID=$(aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "apt-get install -y stress 2>/dev/null || true",
    "stress --cpu 4 --timeout 360 &",
    "echo PID=$! > /tmp/stress-pid.txt",
    "echo Stress started at $(date)"
  ]' \
  --region $REGION \
  --query 'Command.CommandId' \
  --output text)

echo "Stress command ID: $COMMAND_ID"
echo "CPU stress running for 360 seconds"
echo ""
echo "--- MONITOR ALARM ---"
echo "Check alarm status every 60 seconds..."
echo ""

for i in 1 2 3 4 5; do
  sleep 60
  STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "${PROJECT}-dev-high-cpu" \
    --region $REGION \
    --query 'MetricAlarms[0].StateValue' \
    --output text 2>/dev/null || echo "UNKNOWN")
  echo "Minute $i — Alarm state: $STATE"
  if [ "$STATE" = "ALARM" ]; then
    DETECT_TIME=$(date +%s)
    DETECTION_SECONDS=$((DETECT_TIME - INCIDENT_TIME))
    echo "Alarm fired — Detection time: $DETECTION_SECONDS seconds"
    break
  fi
done

echo ""
echo "--- INVESTIGATION ---"
echo "Finding offending process via SSM Run Command..."
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "ps aux --sort=-%cpu | head -10",
    "cat /tmp/stress-pid.txt",
    "kill $(cat /tmp/stress-pid.txt | cut -d= -f2) 2>/dev/null || pkill stress",
    "echo Stress process killed at $(date)"
  ]' \
  --region $REGION \
  --query 'Command.CommandId' \
  --output text

RESOLVE_TIME=$(date +%s)
TOTAL=$((RESOLVE_TIME - INCIDENT_TIME))

echo ""
echo "=========================================="
echo "  INCIDENT 2 RESULTS"
echo "  Incident started : $(date -d @$INCIDENT_TIME)"
echo "  Resolved at      : $(date -d @$RESOLVE_TIME)"
echo "  Total duration   : $TOTAL seconds"
echo "  Fill docs/incidents/incident-2-rca.md"
echo "=========================================="