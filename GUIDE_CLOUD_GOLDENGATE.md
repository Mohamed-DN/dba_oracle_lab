# CLOUD GUIDE: GoldenGate towards Oracle Cloud Infrastructure (OCI ARM)

> **Goal**: Configure a GoldenGate database target on Oracle Cloud Free Tier (ARM Ampere A1) to create a **hybrid on-prem → cloud** architecture. This adds real cloud experience to your CV.

---

## Indice

1. [What is Oracle Cloud Free Tier](#1-what-is-oracle-cloud-free-tier)
2. [Hybrid Architecture](#2-hybrid-architecture)
3. [Reading Path (What to Study Before/After)](#3-reading-path)
4. [Setup OCI — Creare l'Infrastruttura Cloud](#4-setup-oci)
5. [Install Oracle 19c on ARM](#5-install-oracle-19c-on-arm)
6. [Install GoldenGate on ARM](#6-install-goldengate-on-arm)
7. [Networking Lab ↔ Cloud](#7-networking-lab-cloud)
8. [Configurare Replicat su OCI](#8-configurare-replicat-su-oci)
9. [Test End-to-End](#9-test-end-to-end)
10. [Troubleshooting Cloud](#10-troubleshooting-cloud)

---

## 1. What is Oracle Cloud Free Tier

Oracle offre risorse cloud **gratuite per sempre** (Always Free). Quello che ci interessa:

```
╔══════════════════════════════════════════════════════════════════╗
║                  OCI ALWAYS FREE — Risorse                       ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  COMPUTE (VM.Standard.A1.Flex — ARM Ampere)                      ║
║  ┌─────────────────────────────────────────┐                     ║
║ │ • 4 OCPUs (ARM, equivalent to ~4 cores) │ ║
║  │  • 24 GB RAM                            │                     ║
║ │ • You can split into 1-4 VMs │ ║
║  │  • Oracle Linux 8 (aarch64)             │                     ║
║  └─────────────────────────────────────────┘                     ║
║                                                                  ║
║  STORAGE                                                         ║
║  ┌─────────────────────────────────────────┐                     ║
║ │ • 200 GB Block Total Volume │ ║
║  │  • 10 GB Object Storage                 │                     ║
║  └─────────────────────────────────────────┘                     ║
║                                                                  ║
║  NETWORKING                                                      ║
║  ┌─────────────────────────────────────────┐                     ║
║  │  • 10 TB/mese outbound transfer         │                     ║
║  │  • 1 Load Balancer (10 Mbps)            │                     ║
║  │  • VCN, Subnet, Internet Gateway gratis  │                     ║
║  └─────────────────────────────────────────┘                     ║
║                                                                  ║
║  DATABASE                                                        ║
║  ┌─────────────────────────────────────────┐                     ║
║  │  • 2 Autonomous DB (1 OCPU, 20 GB)      │                     ║
║  │  • OPPURE: installa manualmente Oracle   │                     ║
║  │    19c EE su VM ARM (noi facciamo questo)│                     ║
║  └─────────────────────────────────────────┘                     ║
║                                                                  ║
║  💡 Per il LAB: 1 VM con 4 OCPU + 24 GB RAM → PERFETTA          ║
║     per un DB target GoldenGate single-instance!                 ║
╚══════════════════════════════════════════════════════════════════╝
```

> **ARM vs x86**: Ampere A1 CPUs are ARM (aarch64), not x86_64. You need to download the Oracle binaries **for Linux ARM (aarch64)**, not the standard Linux x64 ones!

---

##2. Hybrid Architecture

```
╔══════════════════════════════════════════════════════════════════════════════╗
║ HYBRID ARCHITECTURE ON-PREM → CLOUD ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║   IL TUO PC (VirtualBox)                       ORACLE CLOUD (OCI)           ║
║   ═════════════════════                       ═══════════════════           ║
║                                                                              ║
║   ┌──────────────────┐                                                       ║
║   │   RAC PRIMARY    │                                                       ║
║   │   rac1 + rac2    │                                                       ║
║   │   (192.168.1.x)  │                                                       ║
║   └────────┬─────────┘                                                       ║
║            │  Data Guard (Redo)                                              ║
║            ▼                                                                  ║
║   ┌──────────────────┐                                                       ║
║ │ RAC STANDBY │ ║
║   │   racstby1+stby2 │                                                       ║
║   │   (192.168.1.2xx)│                                                       ║
║   │                  │                                                       ║
║   │   GG Extract     │                                                       ║
║   │   GG Data Pump ──│──── SSH Tunnel / VPN ────────┐                       ║
║   └──────────────────┘     (porta 7809 + 1521)       │                       ║
║                                                       ▼                      ║
║                            ┌────────────────────────────────────────┐        ║
║                            │   OCI ARM VM (VM.Standard.A1.Flex)     │        ║
║                            │   ─────────────────────────────────    │        ║
║                            │   OS: Oracle Linux 8 (aarch64)        │        ║
║                            │   CPU: 4 OCPU ARM Ampere A1           │        ║
║                            │   RAM: 24 GB                          │        ║
║                            │   Storage: 150 GB Block Volume        │        ║
║                            │                                        │        ║
║                            │   Oracle 19c EE (ARM)                  │        ║
║                            │   + GoldenGate 19c (ARM)               │        ║
║                            │   + Replicat (Integrated)              │        ║
║                            │                                        │        ║
║ │ Public IP: xxx.xxx.xxx.xxx │ ║
║                            │   IP Privata: 10.0.0.x                 │        ║
║                            └────────────────────────────────────────┘        ║
║                                                                              ║
║   FLUSSO:                                                                    ║
║ App → RAC Primary → (DG Redo) → RAC Standby → (GG Extract+Pump) ║
║       → SSH Tunnel → OCI ARM VM → (GG Replicat) → Target DB Cloud          ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

> **Why is this powerful for your CV?** Show that you know how to work in hybrid environments (on-prem + cloud), which is exactly what companies migrating to the cloud do.

---

## 3. Reading Path

### 📖 What to Read BEFORE (Before Touching OCI)

```
╔═══════════════════════════════════════════════════════════════════╗
║ READING ORDER — BEFORE YOU START ║
╠═══╦═══════════════════════════════╦══════════════════════════════╣
║ # ║ What to read ║ Why ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 1 ║ GUIDE_ORACLE_ARCHITECTURE.md  ║ Capire SGA, PGA, Redo,      ║
║   ║                               ║ Undo, Temp — le basi         ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 2 ║ GUIDA_FASE0 + FASE1          ║ Capire networking, DNS,      ║
║ ║ ║ OS configuration ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 3 ║ GUIDA_LISTENER_SERVICES_DBA   ║ Understanding Listener, Services, ║
║   ║                               ║ tnsnames.ora, SCAN           ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 4 ║ OCI Getting Started (Oracle)  ║ Console OCI, VCN, Subnet,    ║
║   ║ cloud.oracle.com/get-started  ║ Security List, SSH Keys      ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 5 ║ GUIDE_PHASE5_GOLDENGATE.md     ║ Capire Extract, Pump,        ║
║ ║ ║ Replicat before the cloud ║
╚═══╩═══════════════════════════════╩══════════════════════════════╝
```

### 📖 What to Read NEXT (After Completing the Lab Cloud)

```
╔═══╦═══════════════════════════════╦══════════════════════════════╗
║ # ║ What to read ║ Why ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 1 ║ GUIDE_MAA_BEST_PRACTICES.md║ Validate your architecture ║
║ ║ ║ against Oracle standards ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 2 ║ GUIDE_DBA_ACTIVITIES.md         ║ Batch jobs, AWR, patching,   ║
║   ║                               ║ Data Pump, security          ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 3 ║ GUIDE_FROM_LAB_TO_PRODUCTION.md  ║ Sizing, HugePages, tuning    ║
║ ║ ║ for real production ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 4 ║ GUIDA_SWITCHOVER + FAILOVER   ║ Praticare DG operations      ║
║ ║ ║ with the cloud as target ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 5 ║ Oracle Cloud Documentation    ║ Approfondire OCI networking,  ║
║   ║ docs.oracle.com               ║ security, monitoring         ║
╚═══╩═══════════════════════════════╩══════════════════════════════╝
```

---

## 4. Setup OCI

### 4.1 Creare Account Oracle Cloud

1. Vai su [cloud.oracle.com](https://cloud.oracle.com)
2. Clicca **"Start for Free"**
3. Choose the **Home Region** closest to you (e.g. `eu-milan-1` o `eu-frankfurt-1`)
4. Complete registration (you need a credit card but **they will NOT charge you** for Always Free resources)

> ⚠️ **IMPORTANT**: The Home Region CANNOT be changed afterwards. Always Free resources are ONLY available in the Home Region.

### 4.2 Creare il Networking (VCN)

```
╔════════════════════════════════════════════════════════╗
║ OCI (Virtual Cloud Network) NETWORK TOPOLOGY ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║  VCN: labnet (10.0.0.0/16)                             ║
║ ├── Public subnet: 10.0.0.0/24 ║
║ │ └── ARM VM (10.0.0.2, public IP assigned) ║
║  ├── Internet Gateway (IGW)                            ║
║  ├── Route Table: 0.0.0.0/0 → IGW                     ║
║  └── Security List:                                    ║
║      ├── IN: TCP 22 (SSH) da 0.0.0.0/0                ║
║ ├── IN: TCP 1521 (Oracle) from YOUR public IP ║
║      ├── IN: TCP 7809 (GoldenGate) dal TUO IP         ║
║      └── OUT: Tutto (0.0.0.0/0)                       ║
╚════════════════════════════════════════════════════════╝
```

**Step by step in the OCI Console:**

```bash
# 1. Menu → Networking → Virtual Cloud Networks → Create VCN
# Name: labnet
#    CIDR: 10.0.0.0/16
#    [Create VCN]

# 2. Dentro la VCN → Create Subnet
#    Name: public-subnet
#    CIDR: 10.0.0.0/24
#    Subnet Type: Public
#    Route Table: Default
#    Security List: Default
#    [Create Subnet]

# 3. Internet Gateway → Create
#    Name: igw-lab
#    [Create]

# 4. Route Table → Add Route Rule
#    Target: Internet Gateway (igw-lab)
#    Destination CIDR: 0.0.0.0/0

# 5. Security List → Add Ingress Rules
```

**Security List — Regole Ingress:**

|Protocol| Porta | Source CIDR |Description|
|---|---|---|---|
| TCP | 22 | `0.0.0.0/0` | SSH |
| TCP | 1521 | `IL_TUO_IP/32` | Oracle Listener |
| TCP | 7809 | `IL_TUO_IP/32` | GoldenGate Manager |
| TCP | 7810-7820 | `IL_TUO_IP/32` | GoldenGate Dynamic Ports |
| ICMP | — | `0.0.0.0/0` | Ping |

> **SICUREZZA**: Non aprire 1521 e 7809 a `0.0.0.0/0`! Use **only your public IP** as source. You can find it with `curl ifconfig.me`.

### 4.3 Creare la VM ARM

```bash
# Menu → Compute → Instances → Create Instance

#Configuration:
#   Name:           oci-dbcloud
#   Compartment:    (root)
# Placement: AD-1 (or the only one available)
#
#   Image:          Oracle Linux 8 (aarch64)   ← IMPORTANTE: ARM!
#   Shape:          VM.Standard.A1.Flex
#     OCPU:         4
#     Memory:       24 GB
#
#   Networking:
#     VCN:          labnet
#     Subnet:       public-subnet
#     Public IP:    Assign a public IPv4 address  ← OBBLIGATORIO
#
#   SSH Key:        Upload your public key (.pub)
#or: Generate a key pair (download the private key!)
#
#   Boot Volume:    150 GB  (50 boot + lascia 50 per DB)
```

> **"Out of Capacity"?** Succede spesso con ARM Free Tier. Soluzioni:
> 1. Try again after a few hours/day
> 2. Try a different Availability Domain
> 3. Convert to Pay-As-You-Go (PAYG) — you don't pay if you stay under the free limits

### 4.4 First SSH Connection

```bash
# Dal tuo PC Windows (PowerShell)
ssh -i C:\Users\<user>\.ssh\id_rsa opc@<IP_PUBBLICA_OCI>

#'opc' is the default Oracle Linux user on OCI
# Has sudo without password
```

### 4.5 Initial OS Configuration

```bash
#Like opc (sudo)

# Update the system
sudo dnf update -y

# Install Oracle prerequisites
sudo dnf install -y oracle-database-preinstall-19c
# On OL8 ARM, this package automatically configures:
#- oracle user
# - gruppi (oinstall, dba, oper, backupdba, dgdba, kmdba)
# - limiti kernel
# - parametri sysctl

# Crea directory Oracle
sudo mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
sudo mkdir -p /u01/app/oraInventory
sudo chown -R oracle:oinstall /u01/app
sudo chmod -R 775 /u01/app

# Configure the OCI-internal firewall
sudo firewall-cmd --permanent --add-port=1521/tcp
sudo firewall-cmd --permanent --add-port=7809/tcp
sudo firewall-cmd --permanent --add-port=7810-7820/tcp
sudo firewall-cmd --reload

# Imposta hostname
sudo hostnamectl set-hostname oci-dbcloud
echo "$(hostname -I | awk '{print $1}') oci-dbcloud" | sudo tee -a /etc/hosts
```

---

## 5. Install Oracle 19c on ARM

### 5.1 Download Binari ARM

> ⚠️ **IMPORTANT**: You must download the **Linux ARM (aarch64)** version, NOT Linux x64!

Vai su [edelivery.oracle.com](https://edelivery.oracle.com):
- Cerca: **Oracle Database 19c**
- Platform: **Linux ARM 64-bit (aarch64)**
- File: `LINUX.ARM64_1919000_db_home.zip`

Transfer the file to the OCI VM:

```bash
# Dal tuo PC
scp -i ~/.ssh/id_rsa LINUX.ARM64_1919000_db_home.zip opc@<IP_OCI>:/tmp/

#On the OCI VM as oracle
sudo su - oracle

# Unpack directly intoORACLE_HOME
cd /u01/app/oracle/product/19.0.0/dbhome_1
unzip /tmp/LINUX.ARM64_1919000_db_home.zip
```

### 5.2 Configurare Environment

```bash
#Like oracle
cat >> ~/.bash_profile <<'EOF'

# Oracle Environment
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=CLOUDDB
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
EOF

source ~/.bash_profile
```

### 5.3 Installare il Software

```bash
cd $ORACLE_HOME

# Installazione silente (software only)
./runInstaller -silent -responseFile $ORACLE_HOME/install/response/db_install.rsp \
  oracle.install.option=INSTALL_DB_SWONLY \
  UNIX_GROUP_NAME=oinstall \
  INVENTORY_LOCATION=/u01/app/oraInventory \
  ORACLE_HOME=$ORACLE_HOME \
  ORACLE_BASE=$ORACLE_BASE \
  oracle.install.db.InstallEdition=EE \
  oracle.install.db.OSDBA_GROUP=dba \
  oracle.install.db.OSOPER_GROUP=oper \
  oracle.install.db.OSBACKUPDBA_GROUP=backupdba \
  oracle.install.db.OSDGDBA_GROUP=dgdba \
  oracle.install.db.OSKMDBA_GROUP=kmdba \
  oracle.install.db.OSRACDBA_GROUP=dba \
  DECLINE_SECURITY_UPDATES=true

#Run as root
sudo /u01/app/oraInventory/orainstRoot.sh
sudo $ORACLE_HOME/root.sh
```

### 5.4 Creare il Database

```bash
# DBCA silent mode
dbca -silent -createDatabase \
  -gdbName CLOUDDB \
  -sid CLOUDDB \
  -templateName General_Purpose.dbc \
  -characterSet AL32UTF8 \
  -nationalCharacterSet AL16UTF16 \
  -createAsContainerDatabase false \
  -memoryPercentage 50 \
  -storageType FS \
-datafileDestination /u01/app/oracle/oradata \
  -redoLogFileSize 100 \
-emConfiguration NONE \
  -sysPassword <password> \
  -systemPassword <password> \
  -databaseType MULTIPURPOSE
```

### 5.5 Configure Listener

```bash
# Create the listener
cat > $ORACLE_HOME/network/admin/listener.ora <<'EOF'
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = CLOUDDB)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = CLOUDDB)
    )
  )
EOF

# Start the listener
lsnrctl start

# Configure auto-start
sqlplus / as sysdba <<EOF
ALTER SYSTEM SET local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=0.0.0.0)(PORT=1521))' SCOPE=BOTH;
ALTER SYSTEM REGISTER;
EOF
```

> **`HOST = 0.0.0.0`**: Listen on ALL interfaces. Necessary because connections from the lab arrive on the OCI public IP. Security is managed by the OCI Security List.

---

## 6. Install GoldenGate on ARM

### 6.1 Download GoldenGate ARM

Da [edelivery.oracle.com](https://edelivery.oracle.com):
- Cerca: **Oracle GoldenGate 19c** (o 21c)
- Platform: **Linux ARM 64-bit (aarch64)**

```bash
# Transfer to VM
scp -i ~/.ssh/id_rsa fbo_ggs_Linux_arm64_Oracle_shiphome.zip opc@<IP_OCI>:/tmp/

#Like oracle
sudo su - oracle
mkdir -p /u01/app/goldengate
cd /u01/app/goldengate
unzip /tmp/fbo_ggs_Linux_arm64_Oracle_shiphome.zip
cd fbo_ggs_Linux_arm64_Oracle_shiphome/Disk1

# Silent installation
cat > /tmp/oggcore.rsp <<'EOF'
oracle.install.responseFileVersion=/oracle/install/rspfmt_ogginstall_response_schema_v19_1_0
INSTALL_OPTION=ORA19c
SOFTWARE_LOCATION=/u01/app/goldengate/ogg
INVENTORY_LOCATION=/u01/app/oraInventory
UNIX_GROUP_NAME=oinstall
EOF

./runInstaller -silent -responseFile /tmp/oggcore.rsp
```

### 6.2 Configurare Environment GoldenGate

```bash
cat >> ~/.bash_profile <<'EOF'

# GoldenGate Environment
export OGG_HOME=/u01/app/goldengate/ogg
export PATH=$OGG_HOME:$PATH
export LD_LIBRARY_PATH=$OGG_HOME/lib:$ORACLE_HOME/lib:$LD_LIBRARY_PATH
EOF

source ~/.bash_profile
```

### 6.3 Configure Manager

```bash
cd $OGG_HOME
./ggsci
```

```
GGSCI> CREATE SUBDIRS

GGSCI> EDIT PARAMS MGR

PORT 7809
DYNAMICPORTLIST 7810-7820
AUTORESTART REPLICAT *, RETRIES 3, WAITMINUTES 5, RESETMINUTES 60
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPHOURS 24

GGSCI> START MGR
GGSCI> INFO MGR
-- Output: Manager is running (port 7809).
```

---

## 7. Networking Lab ↔ Cloud

### 7.1 The Problem: How to Connect Lab to Cloud?

Your lab is on a local network (192.168.1.x), but the OCI VM is on the Internet. The GoldenGate Data Pump must reach port 7809 of the cloud VM.

```
╔══════════════════════════════════════════════════════════════════╗
║                  OPZIONI DI CONNESSIONE                          ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ OPTION 1: SSH Tunnel (Recommended for Lab) ║
║  ─────────────────────────────────────────────                   ║
║  racstby1 ──SSH tunnel──→ OCI VM (porta 7809 + 1521)             ║
║ • Simple, secure, free ║
║  • Basta un comando SSH                                          ║
║ • Perfect for the lab ║
║                                                                  ║
║  OPZIONE 2: VPN Site-to-Site                                     ║
║  ──────────────────────────                                      ║
║  Router locale ──IPSec──→ OCI DRG                                ║
║  • Richiede router compatibile                                   ║
║ • More complex to configure ║
║ • Enterprise solution (production) ║
║                                                                  ║
║ OPTION 3: Direct Public IP ║
║  ────────────────────────────                                    ║
║ Pump points directly to the OCI public IP ║
║  • Richiede port forwarding sul router                           ║
║  • Meno sicuro senza encryption                                  ║
║ • Works if you have static public IP ║
╚══════════════════════════════════════════════════════════════════╝
```

### 7.2 Option 1: SSH Tunnel (Recommended)

```bash
# Sullo standby (racstby1), crea un tunnel persistente
# This map:
#   localhost:7809 → OCI_VM:7809 (GoldenGate Manager)
#   localhost:1522 → OCI_VM:1521 (Oracle Listener)

ssh -i /home/oracle/.ssh/oci_key \
    -L 7809:localhost:7809 \
    -L 1522:localhost:1521 \
    -N -f opc@<IP_PUBBLICA_OCI>

#Verify that the tunnels are working
ss -tlnp | grep -E "7809|1522"
#You need to see the doors in LISTEN
```

### 7.3 TNS Configuration with Tunnel

```
# tnsnames.ora sullo standby (racstby1)
# Point to local tunnel (localhost:1522 → OCI:1521)

CLOUDDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1522))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = CLOUDDB)
    )
  )
```

```bash
# Test connessione
tnsping CLOUDDB
sqlplus ggadmin/<password>@CLOUDDB
```

### 7.4 Option 3: Direct Connection (if you have static IP)

Se il tuo router fa port forwarding o hai IP statico:

```
# tnsnames.ora — points directly to the OCI public IP
CLOUDDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <IP_PUBBLICA_OCI>)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = CLOUDDB)
    )
  )
```

```
# Parametro Data Pump GoldenGate
# RMTHOST points to the OCI IP directly
RMTHOST <IP_PUBBLICA_OCI>, MGRPORT 7809
```

### 7.5 Script Tunnel Persistente (systemd)

To keep the SSH tunnel active even after reboot:

```bash
#As root on racstby1
cat > /etc/systemd/system/ssh-tunnel-oci.service <<'EOF'
[Unit]
Description=SSH Tunnel to OCI for GoldenGate
After=network.target

[Service]
Type=simple
User=oracle
ExecStart=/usr/bin/ssh -i /home/oracle/.ssh/oci_key \
  -L 7809:localhost:7809 -L 1522:localhost:1521 \
  -N -o ServerAliveInterval=60 -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  opc@<IP_PUBBLICA_OCI>
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ssh-tunnel-oci
systemctl start ssh-tunnel-oci
systemctl status ssh-tunnel-oci
```

---

## 8. Configurare Replicat su OCI

### 8.1 Cloud Database Preparation

```sql
--On the OCI VM as sysdba
sqlplus / as sysdba

-- Abilita GoldenGate
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;

--Create GoldenGate user
CREATE USER ggadmin IDENTIFIED BY <password>
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

GRANT DBA TO ggadmin;
GRANT SELECT ANY DICTIONARY TO ggadmin;
GRANT CREATE SESSION TO ggadmin;
GRANT ALTER SESSION TO ggadmin;
GRANT RESOURCE TO ggadmin;

EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');

--Create the target schema (if it does not exist)
--Import it with Data Pump from standby (see 8.2)
```

### 8.2 Initial Load with Data Pump

```bash
# Sullo Standby (racstby1) — esporta
expdp ggadmin/<password>@RACDB_STBY \
    schemas=HR \
    directory=DATA_PUMP_DIR \
    dumpfile=hr_cloud_init.dmp \
    logfile=hr_cloud_export.log

# Transfer via SSH
scp -i /home/oracle/.ssh/oci_key \
    /path/to/hr_cloud_init.dmp \
    opc@<IP_PUBBLICA_OCI>:/tmp/

# On the OCI VM — import
impdp ggadmin/<password> \
    schemas=HR \
    directory=DATA_PUMP_DIR \
    dumpfile=hr_cloud_init.dmp \
    logfile=hr_cloud_import.log
```

### 8.3 Configurare Replicat su OCI

```bash
# Sulla VM OCI
cd $OGG_HOME
./ggsci
```

```
GGSCI> DBLOGIN USERID ggadmin PASSWORD <password>

-- Crea checkpoint table
GGSCI> ADD CHECKPOINTTABLE ggadmin.checkpoint

--Add Replicat
GGSCI> ADD REPLICAT rep_cloud, INTEGRATED, \
       EXTTRAIL ./dirdat/ra, \
       CHECKPOINTTABLE ggadmin.checkpoint

GGSCI> EDIT PARAMS rep_cloud
```

```
REPLICAT rep_cloud
USERID ggadmin, PASSWORD <password>
ASSUMETARGETDEFS
DISCARDFILE ./dirrpt/rep_cloud.dsc, APPEND, MEGABYTES 50

MAP HR.*, TARGET HR.*;
```

### 8.4 Changing Data Pump to Standby

The Pump on standby must point to the SSH tunnel (or direct OCI IP):

```
# On standby (racstby1), change the pump
GGSCI> EDIT PARAMS pump_cloud
```

```
EXTRACT pump_cloud
USERID ggadmin@RACDB_STBY, PASSWORD <password>

-- CON SSH TUNNEL (localhost:7809):
RMTHOST localhost, MGRPORT 7809

-- OPPURE CON IP DIRETTO:
-- RMTHOST <IP_PUBBLICA_OCI>, MGRPORT 7809

RMTTRAIL ./dirdat/ra
TABLE HR.*;
```

```
GGSCI> ADD EXTRACT pump_cloud, EXTTRAILSOURCE ./dirdat/ea
GGSCI> ADD RMTTRAIL ./dirdat/ra, EXTRACT pump_cloud, MEGABYTES 100
```

### 8.5 Startup

```
--On standby
GGSCI> START EXTRACT pump_cloud

-- Sulla VM OCI
GGSCI> START REPLICAT rep_cloud
```

---

## 9. Test End-to-End

```sql
-- 1. Sul PRIMARY (rac1)
sqlplus hr/hr@ORCL
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id)
VALUES (9999, 'Cloud', 'Test', 'cloud@test.com', SYSDATE, 'IT_PROG');
COMMIT;

--2. Wait ~30 seconds (internet has latency)

-- 3. Sulla VM OCI
sqlplus hr/hr@CLOUDDB
SELECT * FROM employees WHERE employee_id = 9999;
--You have to see the line! 🎉
```

```
--Check lag on standby
GGSCI> LAG EXTRACT ext_racdb
GGSCI> LAG EXTRACT pump_cloud

--Check for lag on the cloud
GGSCI> LAG REPLICAT rep_cloud
--Lag will be higher than local version (internet latency)
--Typical: 5-30 seconds with SSH tunnel
```

---

## 10. Troubleshooting Cloud

| Problema | Causa |Solution|
|---|---|---|
| SSH timeout | Security List does not open port 22 |Add TCP ingress rule 22|
| `tnsping` timeout verso OCI | Security List does not open 1521 |Add TCP rule 1521 from your IP|
| GG Pump `ABENDED` |SSH tunnel crashed| Riavvia tunnel: `systemctl restart ssh-tunnel-oci` |
| `ORA-12170: TNS:Connect timeout` |OCI or local firewall| Controlla Security List + `firewall-cmd` |
| `OGG-00146: No manager` su OCI |Manager not started| `./ggsci` → `START MGR` |
|Very high lag (>60sec)| Banda internet lenta |Enable compression in Pump:`RMTHOST ... COMPRESS` |
| `ORA-01017: invalid user/pass` | Different password ARM/x86 | Recreate user `ggadmin` on the OCI VM |
| **"Out of Capacity"** al create VM |ARM Free Tier sold out in the region|Please try again at different times or change AD|
| Binary GG does not start | Download x64 instead of ARM | Download **aarch64** version from eDelivery |

### Final Verification

```bash
# On standby
GGSCI> INFO ALL
# ext_racdb:  RUNNING
# pump_cloud: RUNNING

# Sulla VM OCI
GGSCI> INFO ALL
# rep_cloud:  RUNNING

# Acceptable lag (< 60 sec with internet)
GGSCI> LAG REPLICAT rep_cloud
```

---

## Appendix: Auto-Start on OCI after Reboot

```bash
#As root on the OCI VM

# 1. Auto-start listener + DB
cat > /etc/systemd/system/oracle-db.service <<'EOF'
[Unit]
Description=Oracle Database 19c
After=network.target

[Service]
Type=forking
User=oracle
Environment=ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
Environment=ORACLE_SID=CLOUDDB
ExecStart=/u01/app/oracle/product/19.0.0/dbhome_1/bin/dbstart /u01/app/oracle/product/19.0.0/dbhome_1
ExecStop=/u01/app/oracle/product/19.0.0/dbhome_1/bin/dbshut /u01/app/oracle/product/19.0.0/dbhome_1
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 2. Auto-start GoldenGate Manager
cat > /etc/systemd/system/goldengate-mgr.service <<'EOF'
[Unit]
Description=Oracle GoldenGate Manager
After=oracle-db.service
Requires=oracle-db.service

[Service]
Type=forking
User=oracle
Environment=ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
Environment=ORACLE_SID=CLOUDDB
Environment=OGG_HOME=/u01/app/goldengate/ogg
Environment=LD_LIBRARY_PATH=/u01/app/goldengate/ogg/lib:/u01/app/oracle/product/19.0.0/dbhome_1/lib
ExecStart=/bin/bash -c 'cd /u01/app/goldengate/ogg && echo "START MGR" | ./ggsci'
ExecStop=/bin/bash -c 'cd /u01/app/goldengate/ogg && echo "STOP MGR !" | ./ggsci'

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable oracle-db goldengate-mgr
```

---

> **Prossimo**: [GUIDE_DBA_ACTIVITIES.md](./GUIDE_DBA_ACTIVITIES.md) — Batch Jobs, AWR, Patching, Data Pump, Security
