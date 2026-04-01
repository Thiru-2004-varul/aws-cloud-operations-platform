#!/bin/bash

LINES=${1:-50}

echo "========== LOG INVESTIGATION =========="
echo "Date: $(date)"
echo "Showing last $LINES lines per log"
echo ""

echo "--- System Log Errors ---"
tail -$LINES /var/log/syslog 2>/dev/null \
  | grep -E "ERROR|WARN|CRIT|error|warn|crit" \
  || echo "No errors in syslog"
echo ""

echo "--- Authentication Log ---"
echo "Recent sudo usage:"
grep "sudo" /var/log/auth.log 2>/dev/null | tail -10 \
  || echo "No sudo usage found"
echo ""

echo "Failed SSH attempts:"
grep "Failed\|Invalid\|error" /var/log/auth.log 2>/dev/null | tail -10 \
  || echo "No failed attempts"
echo ""

echo "--- Flask App Service Logs ---"
journalctl -u flask-app --no-pager -n $LINES 2>/dev/null \
  || echo "Flask app service not found"
echo ""

echo "--- CloudWatch Agent Logs ---"
tail -20 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log 2>/dev/null \
  || echo "CloudWatch agent log not found"
echo ""

echo "--- UFW Firewall Log ---"
tail -20 /var/log/ufw.log 2>/dev/null | grep -E "BLOCK|ALLOW" | tail -10 \
  || echo "No UFW logs found"
echo ""

echo "--- Kernel Messages ---"
dmesg | tail -20 | grep -E "error|fail|warn|crit" \
  || echo "No kernel errors"
echo ""

echo "--- Disk Space Warnings ---"
df -h | awk 'NR>1 {
  use=$5+0
  if (use > 80) print "WARNING: " $6 " is at " $5 " capacity"
}'
echo ""

echo "=========================================="