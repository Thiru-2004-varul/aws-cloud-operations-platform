#!/bin/bash

echo "========== NETWORK TROUBLESHOOTING =========="
echo "Date: $(date)"
echo ""

echo "--- Network Interfaces ---"
ip addr show | grep -E "^[0-9]|inet "
echo ""

echo "--- Routing Table ---"
ip route show
echo ""

echo "--- DNS Resolution ---"
echo "Resolving aws.amazon.com..."
dig aws.amazon.com +short 2>/dev/null || nslookup aws.amazon.com
echo ""

echo "--- Open Ports ---"
ss -tlnp | grep LISTEN
echo ""

echo "--- Established Connections ---"
ss -tnp | grep ESTAB | head -20
echo ""

echo "--- AWS Endpoint Connectivity Tests ---"
for endpoint in \
  "https://aws.amazon.com AWS-General" \
  "https://ssm.ap-south-1.amazonaws.com SSM" \
  "https://secretsmanager.ap-south-1.amazonaws.com SecretsManager" \
  "https://logs.ap-south-1.amazonaws.com CloudWatchLogs" \
  "https://monitoring.ap-south-1.amazonaws.com CloudWatchMetrics" \
  "https://s3.ap-south-1.amazonaws.com S3"; do
  URL=$(echo $endpoint | awk '{print $1}')
  NAME=$(echo $endpoint | awk '{print $2}')
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 $URL)
  if [ "$HTTP_CODE" != "000" ]; then
    echo "$NAME : REACHABLE (HTTP $HTTP_CODE)"
  else
    echo "$NAME : UNREACHABLE"
  fi
done
echo ""

echo "--- UFW Firewall Status ---"
ufw status verbose 2>/dev/null || echo "UFW not available"
echo ""

echo "--- Public IP via AWS ---"
curl -s --max-time 5 https://checkip.amazonaws.com && echo ""
echo ""

echo "=========================================="