#!/bin/bash

REGION="ap-south-1"
PROJECT="cloud-ops"
ENV="dev"

echo "=========================================="
echo "  DEPLOYING ALL STACKS"
echo "  $(date)"
echo "=========================================="
echo ""

deploy_stack() {
  STACK_NAME=$1
  TEMPLATE=$2

  echo "Deploying $STACK_NAME..."
  aws cloudformation deploy \
    --template-file $TEMPLATE \
    --stack-name $STACK_NAME \
    --parameter-overrides ProjectName=$PROJECT Environment=$ENV \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

  STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text)

  echo "$STACK_NAME : $STATUS"
  echo ""
}

deploy_stack cloud-ops-dev-network \
  cloudformation/stacks/network-stack.yaml

deploy_stack cloud-ops-dev-security \
  cloudformation/stacks/security-stack.yaml

deploy_stack cloud-ops-dev-compute \
  cloudformation/stacks/compute-stack.yaml

deploy_stack cloud-ops-dev-ssm \
  cloudformation/stacks/ssm-stack.yaml

deploy_stack cloud-ops-dev-secrets \
  cloudformation/stacks/secrets-stack.yaml

deploy_stack cloud-ops-dev-backup \
  cloudformation/stacks/backup-stack.yaml

deploy_stack cloud-ops-dev-monitoring \
  cloudformation/stacks/monitoring-stack.yaml

echo "=========================================="
echo "  ALL STACKS DEPLOYED"
echo ""

ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name cloud-ops-dev-compute \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text)

echo "  ALB DNS : $ALB_DNS"
echo ""
echo "  Testing app..."
curl -s http://$ALB_DNS/health
echo ""
echo "  Run: bash scripts/infra-down.sh to destroy and save cost"
echo "=========================================="