# Analisi: Oracle Base Vagrant RAC vs Nostro Lab — Best Practice Estratte

> **Note**: This document is a comparative analysis. Our lab uses **ASMLib (`oracleasm`)** for ASM discs, not udev. Oracle Base uses udev in its Vagrant, but ASMLib remains supported and preferred for our teaching approach.

> Fonte: [oraclebase/vagrant/rac/ol7_19](https://github.com/oraclebase/vagrant/tree/master/rac/ol7_19) + [oracle-base.com articolo dettagliato](https://oracle-base.com/articles/19c/oracle-db-19c-rac-installation-on-oracle-linux-7-using-virtualbox)

---

## Confronto Architettura

```
╔═══════════════════════════════╦══════════════════════╦═══════════════════════╗
║ Area                          ║ Nostro Lab           ║ Oracle Base Vagrant   ║
╠═══════════════════════════════╬══════════════════════╬═══════════════════════╣
║ DNS                           ║ BIND (su rac1)       ║ dnsmasq (VM dedicata) ║
║ ASM disks ║ oracleasm driver ║ udev rules + scsi_id ║
║ Time Sync                     ║ NTP/chrony           ║ chrony (burst+makestep)║
║ /u01                          ║ Dir su root disk     ║ Disco dedicato XFS    ║
║ CRS Redundancy ║ EXTERNAL (1 disc) ║ NORMAL (3 discs+FG) ║
║ NetworkManager                ║ Non configurato      ║ dns=none (protegge    ║
║                               ║                      ║ resolv.conf)          ║
║ Grid Install ║ GUI (recommended) ║ Silent mode (response ║
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

## Top 10 Miglioramenti da Integrare

### 1. 🔧 udev Rules per ASM Disks (Alternativa a oracleasm)

Oracle Base usa **udev rules** invece del driver `oracleasm`. This is the **Oracle recommended method for 19c+** and requires no additional drivers.

```bash
# Identifica i dischi con scsi_id
ASM_DISK1=$(/usr/lib/udev/scsi_id -g -u -d /dev/sdc)

# Crea regole udev persistenti
cat > /etc/udev/rules.d/99-oracle-asmdevices.rules <<EOF
KERNEL=="sd?1", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/\$parent", \
  RESULT=="${ASM_DISK1}", SYMLINK+="oracleasm/asm-crs-disk1", OWNER="oracle", GROUP="dba", MODE="0660"
EOF

# Reload udev
/sbin/udevadm control --reload-rules
/sbin/partprobe /dev/sdc1
```

**Advantage**: No need `oracleasm init/scandisks/configure`. The discs appear as `/dev/oracleasm/asm-*` with permissions automatically corrected after each reboot.

### 2. 🕐 chrony Time Sync (Moderno)

```bash
systemctl enable chronyd
systemctl restart chronyd
chronyc -a 'burst 4/4'    # Sincronizza velocemente all'avvio
chronyc -a makestep         # Forza step di correzione
```

**Advantage**: Clusterware requires time synchronization between nodes. chrony is faster and more accurate than ntpd.

### 3. 🌐 NetworkManager dns=none

```bash
# Impedisce a NetworkManager di sovrascrivere /etc/resolv.conf
sed -i -e "s|\[main\]|\[main\]\ndns=none|g" /etc/NetworkManager/NetworkManager.conf
systemctl restart NetworkManager.service
```

**Advantage**: Without this, NetworkManager can overwrite yours `/etc/resolv.conf` and **break SCAN resolution** — a sneaky problem that can appear after a reboot!

### 4. 📀 /u01 su Disco Dedicato (XFS)

```bash
echo -e "n\np\n1\n\n\nw" | fdisk /dev/sdb    # Partiziona
mkfs.xfs -f /dev/sdb1                           # Formatta XFS
UUID=$(blkid -o value /dev/sdb1 | grep -v xfs)
mkdir /u01
echo "UUID=${UUID}  /u01    xfs    defaults 1 2" >> /etc/fstab
mount /u01
```

**Vantaggio**: Separa i binari Oracle dal disco OS. Se il disco OS si riempie, Oracle continua a funzionare.

### 5. 🏗️ CRS NORMAL Redundancy (3 Discs)

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

Tutto il `gridSetup.sh` con parametri in linea di comando — documentato e riproducibile:

```bash
${GRID_HOME}/gridSetup.sh -ignorePrereq -waitforcompletion -silent \
  -responseFile ${GRID_HOME}/install/response/gridsetup.rsp \
  oracle.install.option=CRS_CONFIG \
  oracle.install.crs.config.clusterNodes=node1:node1-vip:HUB,node2:node2-vip:HUB \
  oracle.install.crs.config.networkInterfaceList=eth0:192.168.56.0:1,eth1:192.168.1.0:5 \
  ...
```

### 7. 🗃️ CDB + PDB con Auto-Start

```bash
dbca -silent -createDatabase \
  -createAsContainerDatabase true \
  -numberOfPDBs 1 \
  -pdbName pdb1 ...

# IMPORTANTE: salva lo stato della PDB per auto-start!
ALTER PLUGGABLE DATABASE pdb1 SAVE STATE;
```

**Vantaggio**: Oracle 21c+ richiede CDB. Meglio imparare subito.

### 8. 🔑 SSH Automatizzato con sshpass

```bash
ssh-keyscan -H ${NODE2_HOSTNAME} >> ~/.ssh/known_hosts
sshpass -f /tmp/temp.txt ssh-copy-id ${NODE2_HOSTNAME}
```

**Vantaggio**: Elimina l'interazione manuale "Are you sure you want to continue connecting?"

### 9. 📀 ASM Compatibility Attributes

```sql
CREATE DISKGROUP data EXTERNAL REDUNDANCY DISK '/dev/oracleasm/asm-data-disk1'
  ATTRIBUTE 'compatible.asm'='19.0','compatible.rdbms'='19.0';
```

**Advantage**: Without these attributes, ASM uses the lowest compatibility level, disabling new features.

### 10. 📦 cvuqdisk RPM (Pre-requisito Grid)

```bash
yum install -y ${GRID_HOME}/cv/rpm/cvuqdisk-1.0.10-1.rpm
# Su TUTTI i nodi!
```

**Advantage**: Without cvuqdisk, the Grid installer fails to discover ASM disks during setup.

---

## Nota su dnsmasq vs BIND

Oracle Base uses **dnsmasq** (lightweight, ~1 config file) on a dedicated VM. In our lab we use **BIND** (more powerful, but complex) on the same rac1 node. Both work. BIND is closer to a real enterprise setup, dnsmasq is easier for the lab.

**Decision**: We keep BIND in our lab (more educational) but add a note about dnsmasq as a lightweight alternative.
