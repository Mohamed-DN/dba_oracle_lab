# Analysis: Oracle Base Vagrant RAC vs Our Lab — Extracted Best Practices

> **Note**: This document is a comparative analysis. Our lab uses **ASMLib (`oracleasm`)** for ASM disks, not udev. Oracle Base uses udev in its Vagrant, but ASMLib remains supported and preferred for our educational approach.

> Source: [oraclebase/vagrant/rac/ol7_19](https://github.com/oraclebase/vagrant/tree/master/rac/ol7_19) + [oracle-base.com detailed article](https://oracle-base.com/articles/19c/oracle-db-19c-rac-installation-on-oracle-linux-7-using-virtualbox)

---

## Architecture Comparison

```
╔═══════════════════════════════╦══════════════════════╦═══════════════════════╗
║ Area                          ║ Nostro Lab           ║ Oracle Base Vagrant   ║
╠═══════════════════════════════╬══════════════════════╬═══════════════════════╣
║ DNS                           ║ BIND (su rac1)       ║ dnsmasq (VM dedicata) ║
║ Dischi ASM                    ║ oracleasm driver     ║ udev rules + scsi_id  ║
║ Time Sync                     ║ NTP/chrony           ║ chrony (burst+makestep)║
║ /u01                          ║ Dir su root disk     ║ Disco dedicato XFS    ║
║ CRS Redundancy                ║ EXTERNAL (1 disco)   ║ NORMAL (3 dischi+FG)  ║
║ NetworkManager                ║ Non configurato      ║ dns=none (protegge    ║
║                               ║                      ║ resolv.conf)          ║
║ Grid Install                  ║ GUI (consigliato)    ║ Silent mode (response ║
║                               ║                      ║ file documentato)     ║
║ Database Type                 ║ Non-CDB              ║ CDB + PDB            ║
║ PDB Auto-start                ║ Non configurato      ║ ALTER PDB SAVE STATE  ║
║ SSH Setup                     ║ Manuale              ║ sshpass + ssh-keyscan ║
║ cvuqdisk                      ║ Menzionato           ║ Installato esplicita. ║
║ ASM compatibility             ║ Non specificato       ║ compatible.asm=19.0   ║
║ SELinux                       ║ Disabled             ║ Permissive            ║
║ Disk partitioning             ║ oracleasm            ║ fdisk + udev symlinks ║
╚═══════════════════════════════╩══════════════════════╩═══════════════════════╝
```

---

## Top 10 Improvements to Integrate

### 1. 🔧 udev Rules for ASM Disks (Alternative to oracleasm)

Oracle Base uses **udev rules** instead of the `oracleasm` driver. This is the **Oracle-recommended method for 19c+** and does not require additional drivers.

```bash
# Identify disks with scsi_id
ASM_DISK1=$(/usr/lib/udev/scsi_id -g -u -d /dev/sdc)

# Create persistent udev rules
cat > /etc/udev/rules.d/99-oracle-asmdevices.rules <<EOF
KERNEL=="sd?1", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/\$parent", \
  RESULT=="${ASM_DISK1}", SYMLINK+="oracleasm/asm-crs-disk1", OWNER="oracle", GROUP="dba", MODE="0660"
EOF

# Reload udev
/sbin/udevadm control --reload-rules
/sbin/partprobe /dev/sdc1
```

**Advantage**: No need for `oracleasm init/scandisks/configure`. Disks appear as `/dev/oracleasm/asm-*` with correct permissions automatically after each reboot.

### 2. 🕐 chrony Time Sync (Modern)

```bash
systemctl enable chronyd
systemctl restart chronyd
chronyc -a 'burst 4/4'    # Sincronizza velocemente all'avvio
chronyc -a makestep         # Forza step di correzione
```

**Advantage**: Clusterware requires time synchronization between nodes. chrony is faster and more accurate than ntpd.

### 3. 🌐 NetworkManager dns=none

```bash
# Prevent NetworkManager from overwriting /etc/resolv.conf
sed -i -e "s|\[main\]|\[main\]\ndns=none|g" /etc/NetworkManager/NetworkManager.conf
systemctl restart NetworkManager.service
```

**Advantage**: Without this, NetworkManager can overwrite your `/etc/resolv.conf` and **break SCAN resolution** — an insidious issue that can appear after a reboot!

### 4. 📀 /u01 on Dedicated Disk (XFS)

```bash
echo -e "n\np\n1\n\n\nw" | fdisk /dev/sdb    # Partition
mkfs.xfs -f /dev/sdb1                           # Format XFS
UUID=$(blkid -o value /dev/sdb1 | grep -v xfs)
mkdir /u01
echo "UUID=${UUID}  /u01    xfs    defaults 1 2" >> /etc/fstab
mount /u01
```

**Advantage**: Separates Oracle binaries from the OS disk. If the OS disk fills up, Oracle continues to function.

### 5. 🏗️ CRS NORMAL Redundancy (3 Disks)

```
oracle.install.asm.diskGroup.name=CRS
oracle.install.asm.diskGroup.redundancy=NORMAL
oracle.install.asm.diskGroup.disksWithFailureGroupNames=\
  /dev/oracleasm/asm-crs-disk1,CRSFG1,\
  /dev/oracleasm/asm-crs-disk2,CRSFG2,\
  /dev/oracleasm/asm-crs-disk3,CRSFG3
```

**Advantage**: Even in the lab, using NORMAL with Failure Groups teaches you how real ASM redundancy works.

### 6. 📦 Grid Silent Install (Response File)

The full `gridSetup.sh` with command-line parameters — documented and reproducible:

```bash
${GRID_HOME}/gridSetup.sh -ignorePrereq -waitforcompletion -silent \
  -responseFile ${GRID_HOME}/install/response/gridsetup.rsp \
  oracle.install.option=CRS_CONFIG \
  oracle.install.crs.config.clusterNodes=node1:node1-vip:HUB,node2:node2-vip:HUB \
  oracle.install.crs.config.networkInterfaceList=eth0:192.168.56.0:1,eth1:192.168.1.0:5 \
  ...
```

### 7. 🗃️ CDB + PDB with Auto-Start

```bash
dbca -silent -createDatabase \
  -createAsContainerDatabase true \
  -numberOfPDBs 1 \
  -pdbName pdb1 ...

# IMPORTANT: save PDB state for auto-start!
ALTER PLUGGABLE DATABASE pdb1 SAVE STATE;
```

**Advantage**: Oracle 21c+ requires CDB. Better to learn it right away.

### 8. 🔑 Automated SSH with sshpass

```bash
ssh-keyscan -H ${NODE2_HOSTNAME} >> ~/.ssh/known_hosts
sshpass -f /tmp/temp.txt ssh-copy-id ${NODE2_HOSTNAME}
```

**Advantage**: Eliminates the manual "Are you sure you want to continue connecting?" interaction.

### 9. 📀 ASM Compatibility Attributes

```sql
CREATE DISKGROUP data EXTERNAL REDUNDANCY DISK '/dev/oracleasm/asm-data-disk1'
  ATTRIBUTE 'compatible.asm'='19.0','compatible.rdbms'='19.0';
```

**Advantage**: Without these attributes, ASM uses the lowest compatibility level, disabling new features.

### 10. 📦 cvuqdisk RPM (Grid Pre-requisite)

```bash
yum install -y ${GRID_HOME}/cv/rpm/cvuqdisk-1.0.10-1.rpm
# On ALL nodes!
```

**Advantage**: Without cvuqdisk, the Grid installer cannot discover ASM disks during configuration.

---

## Note on dnsmasq vs BIND

Oracle Base uses **dnsmasq** (lightweight, ~1 config file) on a dedicated VM. Our lab uses **BIND** (more powerful, but complex) on the same rac1 node. Both work. BIND is closer to a real enterprise setup; dnsmasq is simpler for the lab.

**Decision**: We keep BIND in our lab (more educational) but add a note on dnsmasq as a lightweight alternative.
