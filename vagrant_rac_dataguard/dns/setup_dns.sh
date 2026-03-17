#!/bin/bash
# Vagrant Provisioning Script for DNS Node

echo "******************************************************************************"
echo "Configure /etc/hosts with Oracle RAC and Data Guard IPs."
echo "******************************************************************************"

cat >> /etc/hosts <<EOF

# === RAC PRIMARY ===
192.168.56.101   rac1.localdomain       rac1
192.168.56.102   rac2.localdomain       rac2
192.168.1.101    rac1-priv.localdomain  rac1-priv
192.168.1.102    rac2-priv.localdomain  rac2-priv
192.168.56.103   rac1-vip.localdomain   rac1-vip
192.168.56.104   rac2-vip.localdomain   rac2-vip
192.168.56.105   rac-scan.localdomain   rac-scan
192.168.56.106   rac-scan.localdomain   rac-scan
192.168.56.107   rac-scan.localdomain   rac-scan

# === RAC STANDBY ===
192.168.56.111   racstby1.localdomain      racstby1
192.168.56.112   racstby2.localdomain      racstby2
192.168.2.111    racstby1-priv.localdomain racstby1-priv
192.168.2.112    racstby2-priv.localdomain racstby2-priv
192.168.56.113   racstby1-vip.localdomain  racstby1-vip
192.168.56.114   racstby2-vip.localdomain  racstby2-vip
192.168.56.115   racstby-scan.localdomain  racstby-scan
192.168.56.116   racstby-scan.localdomain  racstby-scan
192.168.56.117   racstby-scan.localdomain  racstby-scan
EOF

echo "******************************************************************************"
echo "Install and configure dnsmasq."
echo "******************************************************************************"
yum install -y dnsmasq bind-utils

cat > /etc/dnsmasq.d/rac.conf <<EOF
interface=eth1
domain=localdomain
expand-hosts
local=/localdomain/
domain-needed
bogus-priv
no-resolv
server=8.8.8.8
server=8.8.4.4
log-queries
EOF

systemctl enable dnsmasq
systemctl start dnsmasq

echo "******************************************************************************"
echo "Configure Firewall."
echo "******************************************************************************"
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-service=dns
firewall-cmd --reload

echo "******************************************************************************"
echo "DNS Masq setup complete."
echo "******************************************************************************"
