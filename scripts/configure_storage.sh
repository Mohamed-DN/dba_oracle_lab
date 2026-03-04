#!/bin/bash
# configure_storage.sh

# Partitioning
echo "Partitioning sdb..."
echo -e "n\np\n1\n\n\nw" | fdisk /dev/sdb
echo "Partitioning sdc..."
echo -e "n\np\n1\n\n\nw" | fdisk /dev/sdc
echo "Partitioning sdd..."
echo -e "n\np\n1\n\n\nw" | fdisk /dev/sdd
echo "Partitioning sde..."
echo -e "n\np\n1\n\n\nw" | fdisk /dev/sde

partprobe

# Udev Rules
# Assuming:
# sdb, sdc -> DATA
# sdd, sde -> RECO

cat > /etc/udev/rules.d/99-oracle-asmdevices.rules <<EOF
KERNEL=="sdb1", OWNER="grid", GROUP="asmadmin", MODE="0660", SYMLINK+="oracleasm/disks/DATA1"
KERNEL=="sdc1", OWNER="grid", GROUP="asmadmin", MODE="0660", SYMLINK+="oracleasm/disks/DATA2"
KERNEL=="sdd1", OWNER="grid", GROUP="asmadmin", MODE="0660", SYMLINK+="oracleasm/disks/RECO1"
KERNEL=="sde1", OWNER="grid", GROUP="asmadmin", MODE="0660", SYMLINK+="oracleasm/disks/RECO2"
EOF

/sbin/udevadm control --reload-rules
/sbin/udevadm trigger

ls -l /dev/oracleasm/disks/
