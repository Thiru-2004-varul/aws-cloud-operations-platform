#!/bin/bash
set -e

REGION="ap-south-1"
PROJECT="cloud-ops"
ENV="dev"

echo "=========================================="
echo "  INCIDENT 1 — EC2 INSTANCE FAILURE"
echo "  Start: $(date)"
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
PRE_RESPONSE=$(curl -s http://$ALB_DNS/health)
echo "Response    : $PRE_RESPONSE"
echo ""

echo "--- SIMULATING FAILURE at $(date) ---"
FAILURE_EPOCH=$(date +%s)
FAILURE_TIME=$(date)

aws ec2 stop-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'StoppingInstances[0].CurrentState.Name' \
  --output text

echo "Instance $INSTANCE_ID stopped"
echo ""

echo "Waiting 30 seconds for ALB to detect unhealthy instance..."
sleep 30

echo ""
echo "--- TESTING APP DURING FAILURE ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 10 http://$ALB_DNS/health || echo "000")
echo "ALB health check HTTP code : $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
  echo "ALB successfully routed to second healthy instance"
else
  echo "WARNING: App not responding — check second instance"
fi

echo ""
echo "--- ALB TARGET HEALTH ---"
TG_ARN=$(aws elbv2 describe-target-groups \
  --region $REGION \
  --query "TargetGroups[?contains(TargetGroupName,\`$PROJECT\`)].TargetGroupArn" \
  --output text)

aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $REGION \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table

echo ""
echo "--- RECOVERY at $(date) ---"
aws ec2 start-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'StartingInstances[0].CurrentState.Name' \
  --output text

echo "Waiting for instance to reach running state..."
aws ec2 wait instance-running \
  --instance-ids $INSTANCE_ID \
  --region $REGION

RECOVERY_EPOCH=$(date +%s)
RECOVERY_TIME=$(date)
RTO_SECONDS=$((RECOVERY_EPOCH - FAILURE_EPOCH))
RTO_MINUTES=$((RTO_SECONDS / 60))
RTO_REMAINING=$((RTO_SECONDS % 60))

echo "Waiting 30 more seconds for ALB health check to pass..."
sleep 30

echo ""
echo "--- POST-RECOVERY HEALTH CHECK ---"
POST_RESPONSE=$(curl -s http://$ALB_DNS/health)
echo "Response: $POST_RESPONSE"

echo ""
echo "--- FINAL ALB TARGET HEALTH ---"
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $REGION \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table

echo ""
echo "=========================================="
echo "  INCIDENT 1 RESULTS — COPY THESE NUMBERS"
echo "  Instance          : $INSTANCE_ID"
echo "  Failure time      : $FAILURE_TIME"
echo "  Recovery time     : $RECOVERY_TIME"
echo "  RTO               : $RTO_SECONDS seconds ($RTO_MINUTES min $RTO_REMAINING sec)"
echo "  Pre-failure app   : $PRE_RESPONSE"
echo "  Post-recovery app : $POST_RESPONSE"
echo "  ALB routing during failure HTTP code: $HTTP_CODE"
echo "=========================================="