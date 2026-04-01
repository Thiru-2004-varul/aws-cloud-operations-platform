#!/bin/bash
set -e

REGION="ap-south-1"
PROJECT="cloud-ops"
ENV="dev"

echo "=========================================="
echo "  INCIDENT 1 — EC2 INSTANCE FAILURE"
echo "  $(date)"
echo "=========================================="
echo ""

ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name cloud-ops-dev-compute \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text)

INSTANCE_ID=$(aws ec2 describe-instances \
  --region $REGION \
  --filters \
    "Name=tag:Project,Values=$PROJECT" \
    "Name=tag:Environment,Values=$ENV" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

echo "ALB DNS     : $ALB_DNS"
echo "Instance    : $INSTANCE_ID"
echo ""

echo "--- PRE-FAILURE HEALTH CHECK ---"
curl -s http://$ALB_DNS/health
echo ""

echo "--- SIMULATING FAILURE ---"
FAILURE_TIME=$(date +%s)
echo "Stopping instance at $(date)..."

aws ec2 stop-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'StoppingInstances[0].CurrentState.Name' \
  --output text

echo ""
echo "Waiting 30 seconds for ALB to detect unhealthy instance..."
sleep 30

echo ""
echo "--- TESTING APP DURING FAILURE ---"
echo "ALB should route to the second healthy instance..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/health)
echo "Health check HTTP code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
  echo "ALB successfully routed to healthy instance"
else
  echo "WARNING: App is not responding — both instances may be down"
fi

echo ""
echo "--- RECOVERY ---"
echo "Starting instance back up..."
aws ec2 start-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'StartingInstances[0].CurrentState.Name' \
  --output text

echo "Waiting for instance to reach running state..."
aws ec2 wait instance-running \
  --instance-ids $INSTANCE_ID \
  --region $REGION

RECOVERY_TIME=$(date +%s)
RTO=$((RECOVERY_TIME - FAILURE_TIME))

echo ""
echo "--- POST-RECOVERY HEALTH CHECK ---"
sleep 30
curl -s http://$ALB_DNS/health
echo ""

echo "=========================================="
echo "  INCIDENT 1 RESULTS"
echo "  Failure time    : $(date -d @$FAILURE_TIME)"
echo "  Recovery time   : $(date -d @$RECOVERY_TIME)"
echo "  Total RTO       : $RTO seconds ($(($RTO/60)) minutes)"
echo "  Fill docs/incidents/incident-1-rca.md"
echo "=========================================="