#!/bin/bash

echo "========== DISK MANAGEMENT =========="
echo "Date: $(date)"
echo ""

echo "--- Disk Usage Summary ---"
df -h | awk 'NR==1 || /\/$|\/opt|\/var|\/tmp/'
echo ""

echo "--- Inode Usage ---"
df -i | awk 'NR==1 || /\/$/'
echo ""

echo "--- Top 10 Largest Directories ---"
du -sh /* 2>/dev/null | sort -rh | head -10
echo ""

echo "--- Top 10 Largest Files in /var/log ---"
find /var/log -type f -exec du -sh {} + 2>/dev/null | sort -rh | head -10
echo ""

echo "--- Old Log Files older than 7 days ---"
find /var/log -type f -mtime +7 -name "*.log" 2>/dev/null | head -10
echo ""

echo "--- Temp Files Size ---"
du -sh /tmp 2>/dev/null
echo ""

echo "--- CloudWatch Agent Logs Size ---"
du -sh /opt/aws/amazon-cloudwatch-agent/logs/ 2>/dev/null \
  || echo "Not found"
echo ""

echo "--- Disk I/O Wait ---"
iostat -x 1 2 2>/dev/null | tail -5 \
  || echo "iostat not available - run: apt-get install sysstat"
echo ""

echo "=========================================="