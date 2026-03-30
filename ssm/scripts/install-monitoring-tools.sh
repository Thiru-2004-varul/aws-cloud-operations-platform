#!/bin/bash
echo "Installing monitoring tools..."

apt-get update -y

apt-get install -y \
  htop \
  iotop \
  nethogs \
  nload \
  sysstat \
  netstat-nat \
  net-tools \
  jq \
  wget \
  unzip

systemctl enable sysstat
systemctl start sysstat

echo "Monitoring tools installed successfully"
echo "Tools available: htop, iotop, nethogs, nload, sysstat, jq"