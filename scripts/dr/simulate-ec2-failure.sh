#!/bin/bash
set -e

REGION="ap-south-1"
PROJECT="cloud-ops"
ENV="dev"

echo "========== DR SIMULATION 1 — EC2 INSTANCE FAILURE =========="
echo "Start time: $(date)"
echo ""

INSTANCE_ID=$(aws ec2 describe-instances \
  --region $REGION \
  --filters \
    "Name=tag:Project,Values=$PROJECT" \
    "Name=tag:Environment,Values=$ENV" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

echo "Target instance: $INSTANCE_ID"
echo ""

ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name cloud-ops-dev-compute \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text)

echo "Testing app before failure..."
curl -s http://$ALB_DNS/health
echo ""

STOP_TIME=$(date +%s)
echo "Stopping instance $INSTANCE_ID to simulate failure..."
aws ec2 stop-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION

echo ""
echo "Waiting 60 seconds for CloudWatch alarm to detect failure..."
sleep 60

echo "Testing app after instance stop — ALB should route to healthy instance..."
curl -s http://$ALB_DNS/health
echo ""

echo "Starting instance back up to simulate recovery..."
aws ec2 start-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION

RECOVER_TIME=$(date +%s)
RTO=$((RECOVER_TIME - STOP_TIME))

echo ""
echo "========== RESULTS =========="
echo "Instance stopped at : $STOP_TIME"
echo "Instance recovered at: $RECOVER_TIME"
echo "Total RTO           : $RTO seconds"
echo "Fill in docs/dr/dr-test-results.md with these numbers"
echo "============================="