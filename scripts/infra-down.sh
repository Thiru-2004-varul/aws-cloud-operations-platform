#!/bin/bash

REGION="ap-south-1"

echo "=========================================="
echo "  DESTROYING ALL STACKS"
echo "  $(date)"
echo "=========================================="
echo ""
echo "Your code is safe in GitHub."
echo "Redeploy anytime with: bash scripts/infra-up.sh"
echo ""
read -p "Type YES to confirm: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
  echo "Cancelled."
  exit 0
fi

echo ""

delete_stack() {
  STACK=$1
  echo "Deleting $STACK..."

  aws cloudformation delete-stack \
    --stack-name $STACK \
    --region $REGION 2>/dev/null || echo "$STACK does not exist - skipping"

  aws cloudformation wait stack-delete-complete \
    --stack-name $STACK \
    --region $REGION 2>/dev/null \
    && echo "$STACK deleted" \
    || echo "$STACK already gone"

  echo ""
}

delete_stack cloud-ops-dev-monitoring
delete_stack cloud-ops-dev-backup
delete_stack cloud-ops-dev-secrets
delete_stack cloud-ops-dev-ssm
delete_stack cloud-ops-dev-compute
delete_stack cloud-ops-dev-security
delete_stack cloud-ops-dev-network

echo "=========================================="
echo "  ALL STACKS DELETED — COST IS NOW ZERO"
echo "  $(date)"
echo "=========================================="