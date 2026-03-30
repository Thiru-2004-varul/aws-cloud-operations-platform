#!/bin/bash
echo "Applying OS hardening..."

# Disable root login via SSH
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Disable password authentication - SSM Session Manager only
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Set idle timeout - auto logout after 15 minutes
echo "TMOUT=900" >> /etc/environment
echo "readonly TMOUT" >> /etc/environment

# Enable UFW firewall
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 80/tcp
ufw allow 8080/tcp

# Disable unused services
systemctl disable bluetooth 2>/dev/null || true
systemctl disable cups 2>/dev/null || true

# Set file permissions on sensitive files
chmod 600 /etc/ssh/sshd_config
chmod 644 /etc/passwd
chmod 640 /etc/shadow

# Enable automatic security updates
apt-get install -y unattended-upgrades
echo 'Unattended-Upgrade::Allowed-Origins:: "${distro_id}:${distro_codename}-security";' \
  > /etc/apt/apt.conf.d/50unattended-upgrades

systemctl restart sshd

echo "OS hardening applied successfully"
echo "Root login: DISABLED"
echo "Password auth: DISABLED"
echo "UFW firewall: ENABLED"
echo "Auto security updates: ENABLED"