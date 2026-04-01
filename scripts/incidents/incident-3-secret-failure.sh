#!/bin/bash
set -e

REGION="ap-south-1"
PROJECT="cloud-ops"
ENV="dev"
SECRET_NAME="${PROJECT}/${ENV}/app/config"

echo "=========================================="
echo "  INCIDENT 3 — SECRET ROTATION FAILURE"
echo "  Start: $(date)"
echo "=========================================="
echo ""

ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name cloud-ops-dev-compute \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text)

INSTANCE_ID=$(aws ssm describe-instance-information \
  --region $REGION \
  --query 'InstanceInformationList[0].InstanceId' \
  --output text)

echo "ALB DNS     : $ALB_DNS"
echo "Instance    : $INSTANCE_ID"
echo ""

echo "--- PRE-INCIDENT CHECK ---"
PRE_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/secret-test)
PRE_BODY=$(curl -s http://$ALB_DNS/secret-test)
echo "Secret test HTTP code : $PRE_CODE"
echo "Secret test response  : $PRE_BODY"
echo ""

echo "--- SAVING ORIGINAL SECRET ---"
ORIGINAL_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id $SECRET_NAME \
  --region $REGION \
  --query 'SecretString' \
  --output text)
echo "Original secret saved"
echo ""

echo "--- SIMULATING ROTATION FAILURE at $(date) ---"
INCIDENT_EPOCH=$(date +%s)
INCIDENT_TIME=$(date)

aws secretsmanager put-secret-value \
  --secret-id $SECRET_NAME \
  --secret-string '{"flask_secret_key":"BROKEN_ROTATED_KEY","jwt_secret":"BROKEN_ROTATED_JWT","environment":"dev"}' \
  --region $REGION

echo "Secret changed to broken value"
echo ""

echo "Restarting app to pick up broken secret..."
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl restart flask-app", "sleep 5"]' \
  --region $REGION \
  --output text

sleep 20

echo ""
echo "--- DETECTING FAILURE ---"
FAIL_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 10 http://$ALB_DNS/secret-test || echo "000")
FAIL_BODY=$(curl -s http://$ALB_DNS/secret-test || echo "no response")

DETECT_EPOCH=$(date +%s)
DETECT_TIME=$(date)
DETECTION_SECONDS=$((DETECT_EPOCH - INCIDENT_EPOCH))

echo "Secret test HTTP code : $FAIL_CODE"
echo "Secret test response  : $FAIL_BODY"
echo "Detection time        : $DETECTION_SECONDS seconds"
echo ""

echo "--- CHECKING SECRETS MANAGER VERSIONS ---"
aws secretsmanager list-secret-version-ids \
  --secret-id $SECRET_NAME \
  --region $REGION \
  --query 'Versions[*].[VersionId,VersionStages]' \
  --output table

PREV_VERSION=$(aws secretsmanager list-secret-version-ids \
  --secret-id $SECRET_NAME \
  --region $REGION \
  --query 'Versions[?contains(VersionStages,`AWSPREVIOUS`)].VersionId' \
  --output text)

echo ""
echo "Previous version: $PREV_VERSION"
echo ""

echo "--- RECOVERY at $(date) ---"
if [ ! -z "$PREV_VERSION" ] && [ "$PREV_VERSION" != "None" ]; then
  echo "Rolling back to previous version..."
  aws secretsmanager update-secret-version-stage \
    --secret-id $SECRET_NAME \
    --version-stage AWSCURRENT \
    --move-to-version-id $PREV_VERSION \
    --region $REGION
  echo "Secret rolled back to previous version"
else
  echo "No previous version found - restoring original value..."
  aws secretsmanager put-secret-value \
    --secret-id $SECRET_NAME \
    --secret-string "$ORIGINAL_SECRET" \
    --region $REGION
  echo "Secret restored to original value"
fi

echo ""
echo "Restarting app with restored secret..."
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl restart flask-app", "sleep 5"]' \
  --region $REGION \
  --output text

sleep 20

RECOVERY_EPOCH=$(date +%s)
RECOVERY_TIME=$(date)
RTO_SECONDS=$((RECOVERY_EPOCH - INCIDENT_EPOCH))
RTO_MINUTES=$((RTO_SECONDS / 60))
RTO_REMAINING=$((RTO_SECONDS % 60))

echo ""
echo "--- POST-RECOVERY CHECK ---"
POST_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/secret-test)
POST_BODY=$(curl -s http://$ALB_DNS/secret-test)
echo "Secret test HTTP code : $POST_CODE"
echo "Secret test response  : $POST_BODY"

echo ""
echo "=========================================="
echo "  INCIDENT 3 RESULTS — COPY THESE NUMBERS"
echo "  Instance            : $INSTANCE_ID"
echo "  Incident started    : $INCIDENT_TIME"
echo "  Failure detected at : $DETECT_TIME"
echo "  Recovered at        : $RECOVERY_TIME"
echo "  Detection time      : $DETECTION_SECONDS seconds"
echo "  Total RTO           : $RTO_SECONDS seconds ($RTO_MINUTES min $RTO_REMAINING sec)"
echo "  Pre-incident code   : $PRE_CODE"
echo "  During failure code : $FAIL_CODE"
echo "  Post-recovery code  : $POST_CODE"
echo "=========================================="