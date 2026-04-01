#!/bin/bash
set -e

REGION="ap-south-1"
PROJECT="cloud-ops"

echo "=========================================="
echo "  INCIDENT 2 — HIGH CPU"
echo "  Start: $(date)"
echo "=========================================="
echo ""

INSTANCE_ID=$(aws ssm describe-instance-information \
  --region $REGION \
  --query 'InstanceInformationList[0].InstanceId' \
  --output text)

echo "Target instance: $INSTANCE_ID"
echo ""

echo "--- PRE-INCIDENT CPU ---"
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region $REGION \
  --query 'Datapoints[*].[Timestamp,Average]' \
  --output table

echo ""
echo "--- SIMULATING HIGH CPU at $(date) ---"
INCIDENT_EPOCH=$(date +%s)
INCIDENT_TIME=$(date)

COMMAND_ID=$(aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "apt-get install -y stress 2>/dev/null || true",
    "nohup stress --cpu 4 --timeout 360 > /tmp/stress.log 2>&1 &",
    "echo STRESS_PID=$! > /tmp/stress-pid.txt",
    "cat /tmp/stress-pid.txt",
    "echo Stress started at $(date)"
  ]' \
  --region $REGION \
  --query 'Command.CommandId' \
  --output text)

echo "SSM Command ID : $COMMAND_ID"
echo "CPU stress running for 360 seconds"
echo "Monitoring CloudWatch alarm..."
echo ""

DETECT_EPOCH=""
DETECT_TIME=""

for i in 1 2 3 4 5 6 7 8 9 10; do
  sleep 60
  STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "${PROJECT}-dev-high-cpu" \
    --region $REGION \
    --query 'MetricAlarms[0].StateValue' \
    --output text 2>/dev/null || echo "UNKNOWN")

  CPU=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=InstanceId,Value=$INSTANCE_ID \
    --start-time $(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Average \
    --region $REGION \
    --query 'Datapoints[0].Average' \
    --output text 2>/dev/null || echo "N/A")

  echo "Minute $i — Alarm: $STATE — CPU: ${CPU}%"

  if [ "$STATE" = "ALARM" ] && [ -z "$DETECT_EPOCH" ]; then
    DETECT_EPOCH=$(date +%s)
    DETECT_TIME=$(date)
    DETECTION_SECONDS=$((DETECT_EPOCH - INCIDENT_EPOCH))
    echo "ALARM FIRED — Detection time: $DETECTION_SECONDS seconds"
  fi
done

echo ""
echo "--- INVESTIGATION AND KILL ---"
KILL_COMMAND=$(aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "echo Top processes:",
    "ps aux --sort=-%cpu | head -5",
    "pkill stress || true",
    "echo Stress killed at $(date)",
    "sleep 5",
    "echo CPU after kill:",
    "top -bn1 | grep Cpu"
  ]' \
  --region $REGION \
  --query 'Command.CommandId' \
  --output text)

echo "Kill command ID: $KILL_COMMAND"
echo "Waiting 30 seconds for command to complete..."
sleep 30

echo ""
echo "--- KILL COMMAND OUTPUT ---"
aws ssm get-command-invocation \
  --command-id $KILL_COMMAND \
  --instance-id $INSTANCE_ID \
  --region $REGION \
  --query 'StandardOutputContent' \
  --output text

RESOLVE_EPOCH=$(date +%s)
RESOLVE_TIME=$(date)
TOTAL_SECONDS=$((RESOLVE_EPOCH - INCIDENT_EPOCH))
DETECT_SECONDS=${DETECTION_SECONDS:-"not triggered"}

echo ""
echo "=========================================="
echo "  INCIDENT 2 RESULTS — COPY THESE NUMBERS"
echo "  Instance          : $INSTANCE_ID"
echo "  Incident started  : $INCIDENT_TIME"
echo "  Alarm fired at    : $DETECT_TIME"
echo "  Resolved at       : $RESOLVE_TIME"
echo "  Detection time    : $DETECT_SECONDS seconds"
echo "  Total duration    : $TOTAL_SECONDS seconds"
echo "=========================================="