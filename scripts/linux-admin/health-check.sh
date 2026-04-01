#!/bin/bash

echo "========== SYSTEM HEALTH CHECK =========="
echo "Date       : $(date)"
echo "Hostname   : $(hostname)"
echo "Uptime     : $(uptime -p)"
echo ""

echo "--- OS Info ---"
cat /etc/os-release | grep -E "^NAME|^VERSION="
echo ""

echo "--- CPU ---"
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'%' -f1)
CPU_USED=$(echo "100 - $CPU_IDLE" | bc)
echo "CPU Used   : ${CPU_USED}%"
echo "Load Avg   : $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
echo ""

echo "--- Memory ---"
free -h | awk '/^Mem:/ {
  printf "Total      : %s\nUsed       : %s\nFree       : %s\nAvailable  : %s\n", $2, $3, $4, $7
}'
echo ""

echo "--- Disk ---"
df -h / | awk 'NR==2 {
  printf "Total      : %s\nUsed       : %s\nAvailable  : %s\nUse%%       : %s\n", $2, $3, $4, $5
}'
echo ""

echo "--- Services ---"
for service in flask-app amazon-cloudwatch-agent snap.amazon-ssm-agent.amazon-ssm-agent ufw; do
  STATUS=$(systemctl is-active $service 2>/dev/null || echo "not-found")
  printf "%-45s %s\n" "$service" "$STATUS"
done
echo ""

echo "--- Network Connectivity ---"
curl -s --max-time 5 https://aws.amazon.com > /dev/null \
  && echo "Internet               : REACHABLE" \
  || echo "Internet               : UNREACHABLE"

curl -s --max-time 5 https://ssm.ap-south-1.amazonaws.com > /dev/null \
  && echo "SSM endpoint           : REACHABLE" \
  || echo "SSM endpoint           : UNREACHABLE"

curl -s --max-time 5 https://secretsmanager.ap-south-1.amazonaws.com > /dev/null \
  && echo "Secrets Manager        : REACHABLE" \
  || echo "Secrets Manager        : UNREACHABLE"

curl -s --max-time 5 http://localhost:80/health \
  && echo "" \
  || echo "Flask app              : NOT RESPONDING"
echo ""

echo "--- Open Ports ---"
ss -tlnp | grep LISTEN
echo ""

echo "--- Last 5 Failed Login Attempts ---"
grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 \
  || echo "No failed logins found"
echo ""

echo "=========================================="