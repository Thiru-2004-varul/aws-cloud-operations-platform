# Linux Troubleshooting Guide

## Scenario 1 — EC2 is slow or high CPU
```bash
top -bn1 | head -20
ps aux --sort=-%cpu | head -10
cat /proc/loadavg
uptime
iostat -x 1 3
ps aux | awk '$3 > 50 {print $0}'
kill -9 <PID>
```

**Root causes to check:**
- Runaway process — kill it
- High I/O wait — disk bottleneck
- Memory pressure causing swap — check free -h
- DDoS or traffic spike — check ALB access logs

---

## Scenario 2 — App returning 500 errors
```bash
systemctl status flask-app
journalctl -u flask-app -n 50 --no-pager
curl -v http://localhost:80/health
ss -tlnp | grep :80
systemctl restart flask-app
sleep 5
curl http://localhost:80/health
```

**Root causes to check:**
- Service crashed — check journalctl for Python traceback
- Port not listening — another process took port 80
- Secrets Manager unreachable — IAM role issue
- Dependency missing — check pip3 list

---

## Scenario 3 — Disk is full
```bash
df -h
du -sh /* 2>/dev/null | sort -rh | head -10
find /var/log -type f -exec du -sh {} + | sort -rh | head -10
journalctl --vacuum-size=100M
find /var/log -name "*.gz" -mtime +7 -delete
lsof | grep deleted | awk '{print $1, $2, $7}'
```

**Root causes to check:**
- Log files grown too large — truncate or delete old logs
- Core dumps in /var/crash — delete them
- Deleted files still held open by process — restart the process

---

## Scenario 4 — Cannot connect via SSM Session Manager
```bash
aws ssm describe-instance-information \
  --region ap-south-1 \
  --query 'InstanceInformationList[*].[InstanceId,PingStatus]'

aws iam list-attached-role-policies \
  --role-name cloud-ops-dev-ec2-role

aws ssm send-command \
  --instance-ids <ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["curl -s https://ssm.ap-south-1.amazonaws.com"]' \
  --region ap-south-1
```

**Root causes to check:**
- SSM agent stopped — start it via EC2 console user data
- IAM role missing SSM policy — check attached policies
- NAT Gateway deleted — private EC2 cannot reach SSM endpoint
- Instance in stopped state — start it first

---

## Scenario 5 — Service crashed and will not restart
```bash
systemctl status flask-app --no-pager
journalctl -u flask-app -n 100 --no-pager
ss -tlnp | grep :80
fuser -k 80/tcp
python3 -c "import flask, boto3; print('Dependencies OK')"
cd /opt/app && python3 app.py
systemctl restart flask-app
```

**Root causes to check:**
- Port already in use — kill the process holding port 80
- Missing Python dependency — reinstall with pip3
- Syntax error in app.py — run python3 directly to see traceback
- Permissions issue — check file ownership with ls -la /opt/app

---

## Scenario 6 — High memory usage
```bash
free -h
ps aux --sort=-%mem | head -10
cat /proc/meminfo | grep -E "MemAvailable|SwapTotal|SwapFree"
pmap -x <PID> | tail -5
```

**Root causes to check:**
- Memory leak in Flask app — restart service
- Too many processes — check ps aux count
- Swap exhausted — add swap or scale up instance
- OOM killer fired — check dmesg | grep oom