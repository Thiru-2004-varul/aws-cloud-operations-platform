# Linux Administration Commands Reference

## CPU Investigation
```bash
top -bn1                                     # snapshot of all processes
ps aux --sort=-%cpu | head -10               # top CPU processes
mpstat -P ALL 1 3                            # per-core CPU usage
cat /proc/loadavg                            # load average 1 5 15 min
pidstat 1 5                                  # per-process CPU over time
```

## Memory Investigation
```bash
free -h                                      # memory summary
cat /proc/meminfo                            # detailed memory breakdown
ps aux --sort=-%mem | head -10               # top memory processes
vmstat 1 5                                   # virtual memory stats
pmap -x <PID>                                # memory map of a process
```

## Disk Investigation
```bash
df -h                                        # disk usage per filesystem
du -sh /*                                    # size of top level dirs
find /var/log -type f -mtime +7              # files older than 7 days
lsof | grep deleted                          # deleted files still held open
iostat -x 1 5                                # disk I/O stats over time
```

## Network Investigation
```bash
ss -tlnp                                     # listening ports with process
ss -tnp state established                    # active connections
ip route show                                # routing table
curl -v https://aws.amazon.com               # test connectivity verbose
dig <hostname>                               # DNS lookup
tcpdump -i eth0 port 80 -n                   # capture HTTP traffic
```

## Service Management
```bash
systemctl status <service>                   # service status
systemctl restart <service>                  # restart service
systemctl enable <service>                   # enable on boot
journalctl -u <service> -f                   # follow service logs
journalctl -u <service> --since "1 hour ago" # logs from last hour
journalctl -p err -b                         # all errors since boot
```

## Log Investigation
```bash
tail -f /var/log/syslog                      # follow system log
grep "ERROR" /var/log/syslog | tail -50      # find errors
zcat /var/log/syslog.1.gz | grep "ERROR"     # search rotated logs
journalctl --since "2025-01-01 00:00:00"     # logs from specific time
```

## Process Management
```bash
kill -9 <PID>                                # force kill process
lsof -p <PID>                                # files opened by process
strace -p <PID>                              # trace system calls
pgrep -a flask                               # find flask processes
nohup python3 app.py > app.log 2>&1 &        # run process detached
```

## Security Checks
```bash
last -20                                     # recent logins
lastb -20                                    # failed login attempts
grep "sudo" /var/log/auth.log | tail -20     # sudo usage history
ss -tlnp | grep -v "127.0.0.1"              # externally listening ports
find / -perm -4000 2>/dev/null               # find SUID files
crontab -l                                   # current user crontab
cat /etc/cron.d/*                            # system crontabs
```

## SSM Run Command — Run Scripts Without SSH
```bash
aws ssm send-command \
  --targets "Key=tag:Project,Values=cloud-ops" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["bash /tmp/health-check.sh"]' \
  --region ap-south-1

aws ssm get-command-invocation \
  --command-id <COMMAND_ID> \
  --instance-id <INSTANCE_ID> \
  --region ap-south-1
```