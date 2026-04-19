# GUIDA CLOUD: GoldenGate verso Oracle Cloud Infrastructure (OCI ARM)

> **Obiettivo**: Configurare un target database GoldenGate su Oracle Cloud Free Tier (ARM Ampere A1) per creare un'architettura **ibrida on-prem → cloud**. Questo aggiunge esperienza cloud reale al tuo CV.

---

## Indice

1. [Cos'è Oracle Cloud Free Tier](#1-cosè-oracle-cloud-free-tier)
2. [Architettura Ibrida](#2-architettura-ibrida)
3. [Percorso di Lettura (Cosa Studiare Prima/Dopo)](#3-percorso-di-lettura)
4. [Setup OCI — Creare l'Infrastruttura Cloud](#4-setup-oci)
5. [Installare Oracle 19c su ARM](#5-installare-oracle-19c-su-arm)
6. [Installare GoldenGate su ARM](#6-installare-goldengate-su-arm)
7. [Networking Lab ↔ Cloud](#7-networking-lab-cloud)
8. [Configurare Replicat su OCI](#8-configurare-replicat-su-oci)
9. [Test End-to-End](#9-test-end-to-end)
10. [Troubleshooting Cloud](#10-troubleshooting-cloud)

---

## 1. Cos'è Oracle Cloud Free Tier

Oracle offre risorse cloud **gratuite per sempre** (Always Free). Quello che ci interessa:

```
╔══════════════════════════════════════════════════════════════════╗
║                  OCI ALWAYS FREE — Risorse                       ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  COMPUTE (VM.Standard.A1.Flex — ARM Ampere)                      ║
║  ┌─────────────────────────────────────────┐                     ║
║  │  • 4 OCPU (ARM, equivalenti a ~4 core)  │                     ║
║  │  • 24 GB RAM                            │                     ║
║  │  • Puoi dividere in 1-4 VM              │                     ║
║  │  • Oracle Linux 8 (aarch64)             │                     ║
║  └─────────────────────────────────────────┘                     ║
║                                                                  ║
║  STORAGE                                                         ║
║  ┌─────────────────────────────────────────┐                     ║
║  │  • 200 GB Block Volume totale           │                     ║
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

> **ARM vs x86**: Le CPU Ampere A1 sono ARM (aarch64), non x86_64. Devi scaricare i binari Oracle **per Linux ARM (aarch64)**, non quelli standard Linux x64!

---

## 2. Architettura Ibrida

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                     ARCHITETTURA IBRIDA ON-PREM → CLOUD                     ║
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
║   │   RAC STANDBY    │                                                       ║
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
║                            │   IP Pubblica: xxx.xxx.xxx.xxx         │        ║
║                            │   IP Privata: 10.0.0.x                 │        ║
║                            └────────────────────────────────────────┘        ║
║                                                                              ║
║   FLUSSO:                                                                    ║
║   App → RAC Primary → (DG Redo) → RAC Standby → (GG Extract+Pump)          ║
║       → SSH Tunnel → OCI ARM VM → (GG Replicat) → Target DB Cloud          ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

> **Perché questo è potente per il CV?** Dimostra che sai lavorare in ambienti ibridi (on-prem + cloud), che è esattamente quello che fanno le aziende che migrano a cloud.

---

## 3. Percorso di Lettura

### 📖 Cosa Leggere PRIMA (Prima di Toccare OCI)

```
╔═══════════════════════════════════════════════════════════════════╗
║  ORDINE DI LETTURA — PRIMA DI INIZIARE                           ║
╠═══╦═══════════════════════════════╦══════════════════════════════╣
║ # ║ Cosa Leggere                  ║ Perché                       ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 1 ║ GUIDA_ARCHITETTURA_ORACLE.md  ║ Capire SGA, PGA, Redo,      ║
║   ║                               ║ Undo, Temp — le basi         ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 2 ║ GUIDA_FASE0 + FASE1          ║ Capire networking, DNS,      ║
║   ║                               ║ configurazione OS            ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 3 ║ GUIDA_LISTENER_SERVICES_DBA   ║ Capire Listener, Services,   ║
║   ║                               ║ tnsnames.ora, SCAN           ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 4 ║ OCI Getting Started (Oracle)  ║ Console OCI, VCN, Subnet,    ║
║   ║ cloud.oracle.com/get-started  ║ Security List, SSH Keys      ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 5 ║ GUIDA_FASE7_GOLDENGATE.md     ║ Capire Extract, Pump,        ║
║   ║                               ║ Replicat prima del cloud     ║
╚═══╩═══════════════════════════════╩══════════════════════════════╝
```

### 📖 Cosa Leggere DOPO (Dopo Aver Completato il Lab Cloud)

```
╔═══╦═══════════════════════════════╦══════════════════════════════╗
║ # ║ Cosa Leggere                  ║ Perché                       ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 1 ║ GUIDA_MAA_BEST_PRACTICES.md   ║ Validare la tua architettura ║
║   ║                               ║ contro gli standard Oracle   ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 2 ║ GUIDA_ATTIVITA_DBA.md         ║ Batch jobs, AWR, patching,   ║
║   ║                               ║ Data Pump, security          ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 3 ║ GUIDA_DA_LAB_A_PRODUZIONE.md  ║ Sizing, HugePages, tuning    ║
║   ║                               ║ per produzione reale         ║
╠═══╬═══════════════════════════════╬══════════════════════════════╣
║ 4 ║ GUIDA_SWITCHOVER + FAILOVER   ║ Praticare DG operations      ║
║   ║                               ║ con il cloud come target     ║
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
3. Scegli la **Home Region** più vicina a te (es. `eu-milan-1` o `eu-frankfurt-1`)
4. Completa la registrazione (serve una carta di credito ma **NON ti addebiteranno** per le risorse Always Free)

> ⚠️ **IMPORTANTE**: La Home Region NON può essere cambiata dopo. Le risorse Always Free sono disponibili SOLO nella Home Region.

### 4.2 Creare il Networking (VCN)

```
╔════════════════════════════════════════════════════════╗
║  TOPOLOGIA RETE OCI (Virtual Cloud Network)            ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║  VCN: labnet (10.0.0.0/16)                             ║
║  ├── Subnet pubblica: 10.0.0.0/24                      ║
║  │   └── VM ARM (10.0.0.2, IP pubblica assegnata)      ║
║  ├── Internet Gateway (IGW)                            ║
║  ├── Route Table: 0.0.0.0/0 → IGW                     ║
║  └── Security List:                                    ║
║      ├── IN: TCP 22 (SSH) da 0.0.0.0/0                ║
║      ├── IN: TCP 1521 (Oracle) dal TUO IP pubblico    ║
║      ├── IN: TCP 7809 (GoldenGate) dal TUO IP         ║
║      └── OUT: Tutto (0.0.0.0/0)                       ║
╚════════════════════════════════════════════════════════╝
```

**Passo per passo nella Console OCI:**

```bash
# 1. Menu → Networking → Virtual Cloud Networks → Create VCN
#    Name: labnet
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

| Protocollo | Porta | Source CIDR | Descrizione |
|---|---|---|---|
| TCP | 22 | `0.0.0.0/0` | SSH |
| TCP | 1521 | `IL_TUO_IP/32` | Oracle Listener |
| TCP | 7809 | `IL_TUO_IP/32` | GoldenGate Manager |
| TCP | 7810-7820 | `IL_TUO_IP/32` | GoldenGate Dynamic Ports |
| ICMP | — | `0.0.0.0/0` | Ping |

> **SICUREZZA**: Non aprire 1521 e 7809 a `0.0.0.0/0`! Usa **solo il tuo IP pubblico** come source. Puoi trovarlo con `curl ifconfig.me`.

### 4.3 Creare la VM ARM

```bash
# Menu → Compute → Instances → Create Instance

# Configurazione:
#   Name:           oci-dbcloud
#   Compartment:    (root)
#   Placement:      AD-1 (o l'unico disponibile)
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
#     oppure:       Generate a key pair (scarica la private key!)
#
#   Boot Volume:    150 GB  (50 boot + lascia 50 per DB)
```

> **"Out of Capacity"?** Succede spesso con ARM Free Tier. Soluzioni:
> 1. Riprova dopo qualche ora/giorno
> 2. Prova una diversa Availability Domain
> 3. Converti a Pay-As-You-Go (PAYG) — non paghi se resti sotto i limiti free

### 4.4 Prima Connessione SSH

```bash
# Dal tuo PC Windows (PowerShell)
ssh -i C:\Users\<user>\.ssh\id_rsa opc@<IP_PUBBLICA_OCI>

# 'opc' è l'utente predefinito Oracle Linux su OCI
# Ha sudo senza password
```

### 4.5 Configurazione OS Iniziale

```bash
# Come opc (sudo)

# Aggiorna il sistema
sudo dnf update -y

# Installa prerequisiti Oracle
sudo dnf install -y oracle-database-preinstall-19c
# Su OL8 ARM, questo pacchetto configura automaticamente:
# - utente oracle
# - gruppi (oinstall, dba, oper, backupdba, dgdba, kmdba)
# - limiti kernel
# - parametri sysctl

# Crea directory Oracle
sudo mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
sudo mkdir -p /u01/app/oraInventory
sudo chown -R oracle:oinstall /u01/app
sudo chmod -R 775 /u01/app

# Configura il firewall OCI-interno
sudo firewall-cmd --permanent --add-port=1521/tcp
sudo firewall-cmd --permanent --add-port=7809/tcp
sudo firewall-cmd --permanent --add-port=7810-7820/tcp
sudo firewall-cmd --reload

# Imposta hostname
sudo hostnamectl set-hostname oci-dbcloud
echo "$(hostname -I | awk '{print $1}') oci-dbcloud" | sudo tee -a /etc/hosts
```

---

## 5. Installare Oracle 19c su ARM

### 5.1 Download Binari ARM

> ⚠️ **IMPORTANTE**: Devi scaricare la versione **Linux ARM (aarch64)**, NON Linux x64!

Vai su [edelivery.oracle.com](https://edelivery.oracle.com):
- Cerca: **Oracle Database 19c**
- Platform: **Linux ARM 64-bit (aarch64)**
- File: `LINUX.ARM64_1919000_db_home.zip`

Trasferisci il file sulla VM OCI:

```bash
# Dal tuo PC
scp -i ~/.ssh/id_rsa LINUX.ARM64_1919000_db_home.zip opc@<IP_OCI>:/tmp/

# Sulla VM OCI come oracle
sudo su - oracle

# Scompatta direttamente nell'ORACLE_HOME
cd /u01/app/oracle/product/19.0.0/dbhome_1
unzip /tmp/LINUX.ARM64_1919000_db_home.zip
```

### 5.2 Configurare Environment

```bash
# Come oracle
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

# Esegui come root
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

### 5.5 Configurare Listener

```bash
# Crea il listener
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

# Avvia il listener
lsnrctl start

# Configura auto-start
sqlplus / as sysdba <<EOF
ALTER SYSTEM SET local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=0.0.0.0)(PORT=1521))' SCOPE=BOTH;
ALTER SYSTEM REGISTER;
EOF
```

> **`HOST = 0.0.0.0`**: Ascolta su TUTTE le interfacce. Necessario perché le connessioni dal lab arrivano sull'IP pubblico OCI. La sicurezza è gestita dalla Security List OCI.

---

## 6. Installare GoldenGate su ARM

### 6.1 Download GoldenGate ARM

Da [edelivery.oracle.com](https://edelivery.oracle.com):
- Cerca: **Oracle GoldenGate 19c** (o 21c)
- Platform: **Linux ARM 64-bit (aarch64)**

```bash
# Trasferisci sulla VM
scp -i ~/.ssh/id_rsa fbo_ggs_Linux_arm64_Oracle_shiphome.zip opc@<IP_OCI>:/tmp/

# Come oracle
sudo su - oracle
mkdir -p /u01/app/goldengate
cd /u01/app/goldengate
unzip /tmp/fbo_ggs_Linux_arm64_Oracle_shiphome.zip
cd fbo_ggs_Linux_arm64_Oracle_shiphome/Disk1

# Installazione silente
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

### 6.3 Configurare Manager

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

### 7.1 Il Problema: Come Connettere Lab a Cloud?

Il tuo lab è su una rete locale (192.168.1.x), ma la VM OCI è su Internet. Il Data Pump GoldenGate deve raggiungere la porta 7809 della VM cloud.

```
╔══════════════════════════════════════════════════════════════════╗
║                  OPZIONI DI CONNESSIONE                          ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  OPZIONE 1: SSH Tunnel (Consigliato per Lab)                     ║
║  ─────────────────────────────────────────────                   ║
║  racstby1 ──SSH tunnel──→ OCI VM (porta 7809 + 1521)             ║
║  • Semplice, sicuro, gratuito                                    ║
║  • Basta un comando SSH                                          ║
║  • Perfetto per il lab                                           ║
║                                                                  ║
║  OPZIONE 2: VPN Site-to-Site                                     ║
║  ──────────────────────────                                      ║
║  Router locale ──IPSec──→ OCI DRG                                ║
║  • Richiede router compatibile                                   ║
║  • Più complesso da configurare                                  ║
║  • Soluzione enterprise (produzione)                             ║
║                                                                  ║
║  OPZIONE 3: IP Pubblico Diretto                                  ║
║  ────────────────────────────                                    ║
║  Pump punta direttamente all'IP pubblico OCI                     ║
║  • Richiede port forwarding sul router                           ║
║  • Meno sicuro senza encryption                                  ║
║  • Funziona se hai IP pubblico statico                           ║
╚══════════════════════════════════════════════════════════════════╝
```

### 7.2 Opzione 1: SSH Tunnel (Raccomandato)

```bash
# Sullo standby (racstby1), crea un tunnel persistente
# Questo mappa:
#   localhost:7809 → OCI_VM:7809 (GoldenGate Manager)
#   localhost:1522 → OCI_VM:1521 (Oracle Listener)

ssh -i /home/oracle/.ssh/oci_key \
    -L 7809:localhost:7809 \
    -L 1522:localhost:1521 \
    -N -f opc@<IP_PUBBLICA_OCI>

# Verifica che i tunnel funzionino
ss -tlnp | grep -E "7809|1522"
# Devi vedere le porte in LISTEN
```

### 7.3 TNS Configuration con Tunnel

```
# tnsnames.ora sullo standby (racstby1)
# Punta al tunnel locale (localhost:1522 → OCI:1521)

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

### 7.4 Opzione 3: Connessione Diretta (se hai IP statico)

Se il tuo router fa port forwarding o hai IP statico:

```
# tnsnames.ora — punta direttamente all'IP pubblico OCI
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
# RMTHOST punta all'IP OCI direttamente
RMTHOST <IP_PUBBLICA_OCI>, MGRPORT 7809
```

### 7.5 Script Tunnel Persistente (systemd)

Per mantenere il tunnel SSH attivo anche dopo reboot:

```bash
# Come root su racstby1
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

### 8.1 Preparazione Database Cloud

```sql
-- Sulla VM OCI come sysdba
sqlplus / as sysdba

-- Abilita GoldenGate
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;

-- Crea utente GoldenGate
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

-- Crea lo schema target (se non esiste)
-- Importalo con Data Pump dallo standby (vedi 8.2)
```

### 8.2 Initial Load con Data Pump

```bash
# Sullo Standby (racstby1) — esporta
expdp ggadmin/<password>@RACDB_STBY \
    schemas=HR \
    directory=DATA_PUMP_DIR \
    dumpfile=hr_cloud_init.dmp \
    logfile=hr_cloud_export.log

# Trasferisci via SSH
scp -i /home/oracle/.ssh/oci_key \
    /path/to/hr_cloud_init.dmp \
    opc@<IP_PUBBLICA_OCI>:/tmp/

# Sulla VM OCI — importa
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

-- Aggiungi Replicat
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

### 8.4 Modificare Data Pump sullo Standby

Il Pump sullo standby deve puntare al tunnel SSH (o all'IP OCI diretto):

```
# Sullo standby (racstby1), modifica il pump
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

### 8.5 Avvio

```
-- Sullo standby
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

-- 2. Attendi ~30 secondi (rede internet ha latenza)

-- 3. Sulla VM OCI
sqlplus hr/hr@CLOUDDB
SELECT * FROM employees WHERE employee_id = 9999;
-- Devi vedere la riga! 🎉
```

```
-- Verifica lag sullo standby
GGSCI> LAG EXTRACT ext_racdb
GGSCI> LAG EXTRACT pump_cloud

-- Verifica lag sul cloud
GGSCI> LAG REPLICAT rep_cloud
-- Il lag sarà più alto della versione locale (latenza internet)
-- Tipico: 5-30 secondi con SSH tunnel
```

---

## 10. Troubleshooting Cloud

| Problema | Causa | Soluzione |
|---|---|---|
| SSH timeout | Security List non apre porta 22 | Aggiungi regola ingress TCP 22 |
| `tnsping` timeout verso OCI | Security List non apre 1521 | Aggiungi regola TCP 1521 dal tuo IP |
| GG Pump `ABENDED` | Tunnel SSH caduto | Riavvia tunnel: `systemctl restart ssh-tunnel-oci` |
| `ORA-12170: TNS:Connect timeout` | Firewall OCI o locale | Controlla Security List + `firewall-cmd` |
| `OGG-00146: No manager` su OCI | Manager non avviato | `./ggsci` → `START MGR` |
| Lag altissimo (>60sec) | Banda internet lenta | Abilita compression nel Pump: `RMTHOST ... COMPRESS` |
| `ORA-01017: invalid user/pass` | Password diversa ARM/x86 | Ricrea utente `ggadmin` sulla VM OCI |
| **"Out of Capacity"** al create VM | ARM Free Tier esaurite nella regione | Riprova in orari diversi o cambia AD |
| Binario GG non parte | Download x64 invece di ARM | Scarica versione **aarch64** da eDelivery |

### Verifica Finale

```bash
# Sullo standby
GGSCI> INFO ALL
# ext_racdb:  RUNNING
# pump_cloud: RUNNING

# Sulla VM OCI
GGSCI> INFO ALL
# rep_cloud:  RUNNING

# Lag accettabile (< 60 sec con internet)
GGSCI> LAG REPLICAT rep_cloud
```

---

## Appendice: Auto-Start su OCI dopo Reboot

```bash
# Come root sulla VM OCI

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

> **Prossimo**: [GUIDA_ATTIVITA_DBA.md](./GUIDA_ATTIVITA_DBA.md) — Batch Jobs, AWR, Patching, Data Pump, Security
