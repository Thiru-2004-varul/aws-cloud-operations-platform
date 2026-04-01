#!/bin/bash

REGION="ap-south-1"
PROJECT="cloud-ops"
ENV="dev"

echo "=========================================="
echo "  FULL SYSTEM VERIFICATION"
echo "  $(date)"
echo "=========================================="
echo ""

echo "--- CLOUDFORMATION STACKS ---"
aws cloudformation list-stacks \
  --region $REGION \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --query 'StackSummaries[*].[StackName,StackStatus]' \
  --output table

echo ""
echo "--- EC2 INSTANCES ---"
aws ec2 describe-instances \
  --region $REGION \
  --filters \
    "Name=tag:Project,Values=$PROJECT" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress,SubnetId]' \
  --output table

echo ""
echo "--- SSM CONNECTED INSTANCES ---"
aws ssm describe-instance-information \
  --region $REGION \
  --query 'InstanceInformationList[*].[InstanceId,PingStatus,PlatformName,AgentVersion]' \
  --output table

echo ""
echo "--- ALB TARGET HEALTH ---"
TG_ARN=$(aws elbv2 describe-target-groups \
  --region $REGION \
  --query "TargetGroups[?contains(TargetGroupName,\`$PROJECT\`)].TargetGroupArn" \
  --output text)

aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $REGION \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Description]' \
  --output table

echo ""
echo "--- APP ENDPOINTS ---"
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name cloud-ops-dev-compute \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text)

echo "ALB DNS: $ALB_DNS"
echo ""

for endpoint in health metrics "" secret-test db-config; do
  if [ -z "$endpoint" ]; then
    URL="http://$ALB_DNS/"
  else
    URL="http://$ALB_DNS/$endpoint"
  fi
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 $URL || echo "000")
  BODY=$(curl -s --max-time 10 $URL || echo "no response")
  echo "GET $URL"
  echo "HTTP: $CODE | Response: $BODY"
  echo ""
done

echo "--- CLOUDWATCH ALARMS ---"
aws cloudwatch describe-alarms \
  --alarm-name-prefix "cloud-ops-dev" \
  --region $REGION \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table

echo ""
echo "--- SECRETS MANAGER ---"
aws secretsmanager list-secrets \
  --region $REGION \
  --query 'SecretList[?contains(Name,`cloud-ops`)].Name' \
  --output table

echo ""
echo "=========================================="
echo "  VERIFICATION COMPLETE"
echo "  If all EC2s show healthy and endpoints return 200"
echo "  you are ready to run incident simulations"
echo "=========================================="