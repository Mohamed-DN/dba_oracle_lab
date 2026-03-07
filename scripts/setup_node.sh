#!/bin/bash
# setup_node.sh

# 1. Host Resolution
cat >> /etc/hosts <<EOF
192.168.56.101 rac1.localdomain rac1
192.168.56.102 rac2.localdomain rac2
192.168.1.101  rac1-priv.localdomain rac1-priv
192.168.1.102  rac2-priv.localdomain rac2-priv
192.168.56.103 rac1-vip.localdomain rac1-vip
192.168.56.104 rac2-vip.localdomain rac2-vip
192.168.56.105 rac-scan.localdomain rac-scan
192.168.56.106 rac-scan.localdomain rac-scan
192.168.56.107 rac-scan.localdomain rac-scan
EOF

# 2. Yum Update & Pre-reqs
yum install -y oracle-database-preinstall-19c
yum install -y ksh libaio-devel

# 3. Disable Firewall & SELinux
systemctl stop firewalld
systemctl disable firewalld
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

# 4. Predictable Network Names (eth0, eth1)
sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 /g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

# 5. Create Groups & Users (if not full)
/usr/sbin/groupadd -g 54321 oinstall
/usr/sbin/groupadd -g 54322 dba
/usr/sbin/groupadd -g 54323 oper
/usr/sbin/groupadd -g 54324 backupdba
/usr/sbin/groupadd -g 54325 dgdba
/usr/sbin/groupadd -g 54326 kmdba
/usr/sbin/groupadd -g 54327 asmdba
/usr/sbin/groupadd -g 54328 asmoper
/usr/sbin/groupadd -g 54329 asmadmin
/usr/sbin/groupadd -g 54330 racdba

# Modify oracle user
usermod -g oinstall -G dba,oper,backupdba,dgdba,kmdba,racdba,asmdba oracle
echo "oracle:oracle" | chpasswd

# Create Grid User
useradd -u 54331 -g oinstall -G asmadmin,asmdba,asmoper,racdba grid
echo "grid:grid" | chpasswd

# 6. Directories
mkdir -p /u01/app/oracle
mkdir -p /u01/app/grid
mkdir -p /u01/app/19.0.0/grid
chown -R grid:oinstall /u01/app/grid
chown -R grid:oinstall /u01/app/19.0.0/grid
chown -R oracle:oinstall /u01/app/oracle
chmod -R 775 /u01

# 7. Configure Storage (Call the other script)
# chmod +x /vagrant/scripts/configure_storage.sh
# /vagrant/scripts/configure_storage.sh
