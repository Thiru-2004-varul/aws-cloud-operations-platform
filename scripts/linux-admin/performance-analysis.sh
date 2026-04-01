#!/bin/bash

echo "========== PERFORMANCE ANALYSIS =========="
echo "Date: $(date)"
echo ""

echo "--- Top 10 CPU Consuming Processes ---"
ps aux --sort=-%cpu | awk 'NR==1 || NR<=11 {
  printf "%-10s %-8s %-8s %s\n", $1, $2, $3, $11
}'
echo ""

echo "--- Top 10 Memory Consuming Processes ---"
ps aux --sort=-%mem | awk 'NR==1 || NR<=11 {
  printf "%-10s %-8s %-8s %s\n", $1, $2, $4, $11
}'
echo ""

echo "--- Memory Details ---"
cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Cached|SwapTotal|SwapFree"
echo ""

echo "--- CPU Usage Per Core ---"
mpstat -P ALL 1 1 2>/dev/null || echo "mpstat not available - run: apt-get install sysstat"
echo ""

echo "--- Disk I/O Statistics ---"
iostat -x 1 1 2>/dev/null || echo "iostat not available - run: apt-get install sysstat"
echo ""

echo "--- Network I/O ---"
cat /proc/net/dev | awk 'NR>2 {
  printf "Interface: %-10s  RX bytes: %-15s  TX bytes: %s\n", $1, $2, $10
}'
echo ""

echo "--- System Resource Limits ---"
ulimit -a | grep -E "open files|max user processes|stack size"
echo ""

echo "--- Recent OOM Kills ---"
dmesg | grep -i "oom\|killed process" | tail -5 \
  || echo "No OOM kills found"
echo ""

echo "=========================================="