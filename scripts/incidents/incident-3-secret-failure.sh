#!/bin/bash
set -e

REGION="ap-south-1"
PROJECT="cloud-ops"
ENV="dev"
SECRET_NAME="${PROJECT}/${ENV}/app/config"

echo "=========================================="
echo "  INCIDENT 3 — SECRET ROTATION FAILURE"
echo "  $(date)"
echo "=========================================="
echo ""

ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name cloud-ops-dev-compute \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text)

echo "ALB DNS: $ALB_DNS"
echo ""

echo "--- PRE-INCIDENT CHECK ---"
echo "Testing secret-test endpoint..."
curl -s http://$ALB_DNS/secret-test
echo ""

echo "--- GETTING CURRENT SECRET VERSION ---"
CURRENT_VERSION=$(aws secretsmanager describe-secret \
  --secret-id $SECRET_NAME \
  --region $REGION \
  --query 'VersionIdsToStages' \
  --output text)
echo "Current versions: $CURRENT_VERSION"
echo ""

echo "--- SIMULATING ROTATION FAILURE ---"
INCIDENT_TIME=$(date +%s)
echo "Changing secret value to simulate failed rotation..."

aws secretsmanager put-secret-value \
  --secret-id $SECRET_NAME \
  --secret-string '{"flask_secret_key":"ROTATED_BUT_BROKEN","jwt_secret":"ROTATED_BUT_BROKEN","environment":"dev"}' \
  --region $REGION

echo "Secret changed at $(date)"
echo ""

INSTANCE_ID=$(aws ssm describe-instance-information \
  --region $REGION \
  --query 'InstanceInformationList[0].InstanceId' \
  --output text)

echo "Restarting app to pick up new (broken) secret..."
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl restart flask-app", "sleep 5", "curl -s http://localhost:80/secret-test"]' \
  --region $REGION \
  --output text

sleep 15

echo ""
echo "--- DETECTING FAILURE ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/secret-test)
echo "Secret test endpoint HTTP code: $HTTP_CODE"

DETECT_TIME=$(date +%s)
DETECTION=$((DETECT_TIME - INCIDENT_TIME))
echo "Detection time: $DETECTION seconds"

echo ""
echo "--- RECOVERY — ROLLING BACK SECRET ---"
echo "Getting previous secret version..."

PREV_VERSION=$(aws secretsmanager list-secret-version-ids \
  --secret-id $SECRET_NAME \
  --region $REGION \
  --query 'Versions[?contains(VersionStages,`AWSPREVIOUS`)].VersionId' \
  --output text)

echo "Previous version: $PREV_VERSION"

if [ ! -z "$PREV_VERSION" ]; then
  aws secretsmanager update-secret-version-stage \
    --secret-id $SECRET_NAME \
    --version-stage AWSCURRENT \
    --move-to-version-id $PREV_VERSION \
    --region $REGION
  echo "Secret rolled back to previous version"
else
  echo "No previous version found — restoring manually..."
  aws secretsmanager put-secret-value \
    --secret-id $SECRET_NAME \
    --secret-string '{"flask_secret_key":"super-secret-flask-key","jwt_secret":"super-secret-jwt-key","environment":"dev"}' \
    --region $REGION
fi

echo ""
echo "Restarting app with restored secret..."
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl restart flask-app", "sleep 5", "curl -s http://localhost:80/secret-test"]' \
  --region $REGION \
  --output text

sleep 15

RECOVERY_TIME=$(date +%s)
RTO=$((RECOVERY_TIME - INCIDENT_TIME))

echo ""
echo "--- POST-RECOVERY CHECK ---"
curl -s http://$ALB_DNS/secret-test
echo ""

echo "=========================================="
echo "  INCIDENT 3 RESULTS"
echo "  Incident started  : $(date -d @$INCIDENT_TIME)"
echo "  Detected at       : $(date -d @$DETECT_TIME)"
echo "  Recovered at      : $(date -d @$RECOVERY_TIME)"
echo "  Detection time    : $DETECTION seconds"
echo "  Total RTO         : $RTO seconds ($(($RTO/60)) minutes)"
echo "  Fill docs/incidents/incident-3-rca.md"
echo "=========================================="