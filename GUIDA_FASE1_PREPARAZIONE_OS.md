# FASE 1: Preparazione Nodi e OS (Oracle Linux 7.9)

> **Architettura di riferimento**: 2 nodi RAC primario (`rac1`, `rac2`) + 2 nodi RAC standby (`racstby1`, `racstby2`) + 1 nodo target GoldenGate (`dbtarget`).
> Tutti i comandi vanno eseguiti come `root` salvo dove diversamente indicato.
> I passaggi di questa fase vanno ripetuti su **tutti i nodi** salvo dove specificato.

---

### Cos'è il DNS e Perché Ci Serve?

**DNS (Domain Name System)** è il servizio che traduce i nomi in indirizzi IP. Quando digiti `rac-scan.oracleland.local`, il DNS risponde con `192.168.1.120, 192.168.1.121, 192.168.1.122`.

```
  Senza DNS:                          Con DNS:
  ══════════                          ═════════

  Applicazione:                       Applicazione:
  "Connettimi a                       "Connettimi a
   192.168.1.120"                      rac-scan.oracleland.local"
           │                                    │
           ▼                                    ▼
  ┌────────────────┐                  ┌────────────────┐
  │  Connessione   │                  │  DNS Server    │
  │  a UN solo IP  │                  │  Risponde con  │
  │  (se cambia,   │                  │  3 IP in round │
  │   tutto si     │                  │  robin:        │
  │   rompe!)      │                  │  .120 .121 .122│
  └────────────────┘                  └────────┬───────┘
                                               │
                                      Load balanced!
                                      Se cambi un IP,
                                      aggiorni solo il DNS
```

**Perché Oracle RAC lo richiede?**
- Lo **SCAN** (Single Client Access Name) DEVE risolvere a 3 IP tramite DNS
- `/etc/hosts` NON basta per lo SCAN (Oracle lo verifica esplicitamente)
- Il DNS permette il **round-robin**: le connessioni vengono distribuite automaticamente

**Tipi di record DNS che configuriamo:**

| Tipo | Esempio | Cosa fa |
|---|---|---|
| **A** | `rac1 → 192.168.1.101` | Nome → IP (forward) |
| **PTR** | `192.168.1.101 → rac1` | IP → Nome (reverse) |
| **SOA** | `oracleland.local` | Authority della zona |
| **NS** | `ns1.oracleland.local` | Chi risponde per questa zona |

---

## 1.1 Piano IP e Hostname

Prima di tutto, definiamo il piano di indirizzamento. Questo è il cuore di qualsiasi cluster: se sbagli gli IP, niente funziona.

| Ruolo | Hostname | IP Pubblica | IP Privata (Interconnect) | IP VIP |
|---|---|---|---|---|
| RAC Nodo 1 | rac1 | 192.168.1.101 | 10.10.10.1 | 192.168.1.111 |
| RAC Nodo 2 | rac2 | 192.168.1.102 | 10.10.10.2 | 192.168.1.112 |
| RAC SCAN | rac-scan | 192.168.1.120, .121, .122 | - | - |
| Standby Nodo 1 | racstby1 | 192.168.1.201 | 10.10.10.11 | 192.168.1.211 |
| Standby Nodo 2 | racstby2 | 192.168.1.202 | 10.10.10.12 | 192.168.1.212 |
| Standby SCAN | racstby-scan | 192.168.1.220, .221, .222 | - | - |
| Target GoldenGate | dbtarget | 192.168.1.150 | - | - |

> **Perché?** Oracle RAC necessita di minimo 3 tipi di IP per nodo: Pubblica (comunicazione client), Privata (Cache Fusion, il "sangue" del cluster), VIP (failover trasparente). Lo SCAN (Single Client Access Name) è un load balancer DNS integrato nel cluster.

### Come Funzionano le Reti del RAC

```
                     ┌───────────────────────────────────────────┐
                     │          RETE PUBBLICA (eth0)             │
                     │       192.168.1.0/24 (Bridged)           │
      Client App     │                                           │
          │          │  ┌──────┐  ┌──────┐  ┌──────┐            │
          ▼          │  │SCAN  │  │SCAN  │  │SCAN  │            │
    ┌──────────┐     │  │ .120 │  │ .121 │  │ .122 │            │
    │ SCAN     │◄────│──┤      │  │      │  │      │ DNS        │
    │ Listener │     │  └──────┘  └──────┘  └──────┘ Round-Robin│
    └────┬─────┘     │                                           │
         │           │  ┌─────────────┐   ┌─────────────┐       │
         ├──────────►│  │ rac1        │   │ rac2        │       │
         │           │  │ IP: .101    │   │ IP: .102    │       │
         │           │  │ VIP: .111   │   │ VIP: .112   │       │
         │           │  │ (Se rac1    │   │ (Se rac2    │       │
         │           │  │  muore, VIP │   │  muore, VIP │       │
         │           │  │  migra su   │   │  migra su   │       │
         │           │  │  rac2)      │   │  rac1)      │       │
         │           │  └──────┬──────┘   └──────┬──────┘       │
         │           └─────────┼──────────────────┼─────────────┘
         │                     │                  │
         │           ┌─────────┼──────────────────┼─────────────┐
         │           │         │  RETE PRIVATA    │   (eth1)    │
         │           │         │  10.10.10.0/24   │  Host-Only  │
         │           │  ┌──────┴──────┐   ┌──────┴──────┐      │
         │           │  │ rac1-priv   │   │ rac2-priv   │      │
         │           │  │ 10.10.10.1  │◄═►│ 10.10.10.2  │      │
         │           │  └─────────────┘   └─────────────┘      │
         │           │         Cache Fusion (GCS/GES)           │
         │           │    Blocchi dati trasferiti via RAM        │
         │           └─────────────────────────────────────────┘
```

> **VIP (Virtual IP)**: Quando un nodo crasha, il suo VIP "migra" sull'altro nodo in pochi secondi. I client connessi al VIP vengono re-indirizzati automaticamente senza cambiare configurazione.

> **SCAN**: I client si connettono SEMPRE allo SCAN, MAI direttamente ai nodi. Lo SCAN load-balancia le connessioni tra i nodi disponibili.

---

## 1.2 Configurazione /etc/hosts

Esegui su **TUTTI** i nodi:

```bash
cat >> /etc/hosts <<'EOF'
# === RAC PRIMARY ===
192.168.1.101   rac1.oracleland.local       rac1
192.168.1.102   rac2.oracleland.local       rac2
10.10.10.1      rac1-priv.oracleland.local  rac1-priv
10.10.10.2      rac2-priv.oracleland.local  rac2-priv
192.168.1.111   rac1-vip.oracleland.local   rac1-vip
192.168.1.112   rac2-vip.oracleland.local   rac2-vip

# === RAC STANDBY ===
192.168.1.201   racstby1.oracleland.local      racstby1
192.168.1.202   racstby2.oracleland.local      racstby2
10.10.10.11     racstby1-priv.oracleland.local racstby1-priv
10.10.10.12     racstby2-priv.oracleland.local racstby2-priv
192.168.1.211   racstby1-vip.oracleland.local  racstby1-vip
192.168.1.212   racstby2-vip.oracleland.local  racstby2-vip

# === TARGET GOLDENGATE ===
192.168.1.150   dbtarget.oracleland.local   dbtarget
EOF
```

> **Perché /etc/hosts e non solo DNS?** Oracle Clusterware verifica la risoluzione dei nomi PRIMA che il DNS sia attivo. Se metti tutto solo in DNS e il DNS non parte, il cluster non si avvia. Il file hosts è la "rete di sicurezza".

---

## 1.3 Configurazione Rete (Static IP)

Su ogni nodo, configura le due interfacce di rete. Esempio per `rac1`:

### Interfaccia Pubblica (eth0 o enp0s3)

```bash
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<'EOF'
TYPE=Ethernet
BOOTPROTO=static
NAME=eth0
DEVICE=eth0
ONBOOT=yes
IPADDR=192.168.1.101
NETMASK=255.255.255.0
GATEWAY=192.168.1.1
DNS1=192.168.1.101
DOMAIN=oracleland.local
EOF
```

### Interfaccia Privata (eth1 o enp0s8)

```bash
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 <<'EOF'
TYPE=Ethernet
BOOTPROTO=static
NAME=eth1
DEVICE=eth1
ONBOOT=yes
IPADDR=10.10.10.1
NETMASK=255.255.255.0
EOF
```

> **Perché BOOTPROTO=static?** L'interconnect del RAC NON deve MAI cambiare IP. Se usi DHCP e l'IP cambia, il cluster va in split-brain (i due nodi pensano di essere soli e corrompono i dati).

```bash
# Riavvia il networking
systemctl restart network

# Verifica
ip addr show eth0
ip addr show eth1
ping -c 2 rac2        # Da rac1
ping -c 2 rac2-priv   # Da rac1 (rete privata)
```

---

## 1.4 Configurazione DNS (BIND) su rac1

Lo SCAN richiede obbligatoriamente un DNS (non basta /etc/hosts per lo SCAN!).

```bash
# Installa BIND
yum install -y bind bind-utils
```

### Configurazione /etc/named.conf

```bash
cp /etc/named.conf /etc/named.conf.bkp

cat > /etc/named.conf <<'EOF'
options {
    listen-on port 53 { 127.0.0.1; 192.168.1.101; };
    listen-on-v6 port 53 { ::1; };
    directory       "/var/named";
    dump-file       "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    allow-query     { localhost; 192.168.1.0/24; };
    recursion yes;
    dnssec-enable yes;
    dnssec-validation yes;
};

logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};

zone "." IN {
    type hint;
    file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

// Forward Zone
zone "oracleland.local" IN {
    type master;
    file "forward.oracleland.local";
    allow-update { none; };
};

// Reverse Zone
zone "1.168.192.in-addr.arpa" IN {
    type master;
    file "reverse.oracleland.local";
    allow-update { none; };
};
EOF
```

> **Perché il DNS?** Oracle richiede che il nome SCAN risolva ad almeno 1 IP (consigliati 3) tramite DNS. Il file `/etc/hosts` NON viene usato per lo SCAN.

### Come Funziona la Risoluzione DNS nel Nostro Lab

```
Client → "Connettimi a rac-scan.oracleland.local"
    │
    ▼
┌──────────────────┐
│  /etc/resolv.conf │──→ nameserver 192.168.1.101 (rac1)
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  BIND DNS Server (su rac1, porta 53)     │
│                                          │
│  Zone: oracleland.local                  │
│  ┌────────────────────────────────────┐  │
│  │ rac-scan  →  192.168.1.120        │  │
│  │ rac-scan  →  192.168.1.121        │  │  ← 3 record A!
│  │ rac-scan  →  192.168.1.122        │  │    Round-robin
│  │ rac1      →  192.168.1.101        │  │
│  │ rac2      →  192.168.1.102        │  │
│  │ rac1-vip  →  192.168.1.111        │  │
│  │ ...                               │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
    │
    ▼ Risponde con 3 IP in ordine casuale
    192.168.1.121, 192.168.1.120, 192.168.1.122
```

### Zone Forward

```bash
cat > /var/named/forward.oracleland.local <<'EOF'
$TTL 86400
@ IN SOA rac1.oracleland.local. admin.oracleland.local. (
    2024030201 ; Serial
    3600       ; Refresh
    1800       ; Retry
    604800     ; Expire
    86400      ; Minimum TTL
)

; Name Server
@ IN NS rac1.oracleland.local.

; A Records - RAC Primary
rac1            IN  A   192.168.1.101
rac2            IN  A   192.168.1.102
rac1-vip        IN  A   192.168.1.111
rac2-vip        IN  A   192.168.1.112
rac-scan        IN  A   192.168.1.120
rac-scan        IN  A   192.168.1.121
rac-scan        IN  A   192.168.1.122

; A Records - RAC Standby
racstby1        IN  A   192.168.1.201
racstby2        IN  A   192.168.1.202
racstby1-vip    IN  A   192.168.1.211
racstby2-vip    IN  A   192.168.1.212
racstby-scan    IN  A   192.168.1.220
racstby-scan    IN  A   192.168.1.221
racstby-scan    IN  A   192.168.1.222

; A Records - Target GoldenGate
dbtarget        IN  A   192.168.1.150
EOF
```

### Zone Reverse

```bash
cat > /var/named/reverse.oracleland.local <<'EOF'
$TTL 86400
@ IN SOA rac1.oracleland.local. admin.oracleland.local. (
    2024030201 ; Serial
    3600       ; Refresh
    1800       ; Retry
    604800     ; Expire
    86400      ; Minimum TTL
)

@ IN NS rac1.oracleland.local.
rac1 IN A 192.168.1.101

; PTR Records
101 IN PTR rac1.oracleland.local.
102 IN PTR rac2.oracleland.local.
111 IN PTR rac1-vip.oracleland.local.
112 IN PTR rac2-vip.oracleland.local.
120 IN PTR rac-scan.oracleland.local.
121 IN PTR rac-scan.oracleland.local.
122 IN PTR rac-scan.oracleland.local.
201 IN PTR racstby1.oracleland.local.
202 IN PTR racstby2.oracleland.local.
150 IN PTR dbtarget.oracleland.local.
EOF
```

```bash
# Imposta permessi e owner
chown named:named /var/named/forward.oracleland.local
chown named:named /var/named/reverse.oracleland.local

# Verifica configurazione
named-checkconf /etc/named.conf
named-checkzone oracleland.local /var/named/forward.oracleland.local
named-checkzone 1.168.192.in-addr.arpa /var/named/reverse.oracleland.local

# Avvia il servizio
systemctl enable named
systemctl start named
```

### Configura resolv.conf su TUTTI i nodi

```bash
cat > /etc/resolv.conf <<'EOF'
search oracleland.local
nameserver 192.168.1.101
options timeout:1
options attempts:5
EOF

# Proteggilo da sovrascritture di NetworkManager
chattr +i /etc/resolv.conf
```

### Test DNS

```bash
nslookup rac-scan.oracleland.local
# Deve restituire 3 IP: 192.168.1.120, .121, .122

nslookup racstby-scan.oracleland.local
# Deve restituire 3 IP: 192.168.1.220, .221, .222

nslookup rac1.oracleland.local
```

> 📸 **SNAPSHOT — "SNAP-02: Rete e DNS Configurati"**
> Hai rete statica + DNS funzionante. Se qualcosa va storto dopo, puoi tornare qui.
> ```
> VBoxManage snapshot "rac1" take "SNAP-02_Rete_DNS_OK"
> ```

---

## 1.5 Disabilitare Firewall e SELinux

```bash
# Disabilita Firewall
systemctl stop firewalld
systemctl disable firewalld

# Disabilita SELinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
```

> **Perché?** In un ambiente di laboratorio, firewall e SELinux aggiungono complessità non necessaria. In produzione useresti regole specifiche, ma per imparare è meglio eliminarli.

---

## 1.6 Installazione Pacchetti Prerequisiti

```bash
# Installa il pacchetto preinstall che configura automatamente
# kernel params, limiti utente, gruppi e molto altro
yum install -y oracle-database-preinstall-19c

# Pacchetti aggiuntivi necessari
yum install -y ksh libaio-devel net-tools nfs-utils \
    smartmontools sysstat unzip wget xorg-x11-xauth \
    xorg-x11-utils xterm
```

> **Perché oracle-database-preinstall-19c?** Questo pacchetto RPM magico fa il 70% del lavoro di preparazione OS: crea l'utente `oracle`, configura i parametri kernel (`sysctl.conf`), imposta i limiti di risorse (`limits.conf`), installa le dipendenze RPM. Senza questo, dovresti fare tutto a mano.

---

## 1.7 Creazione Gruppi e Utenti

Il pacchetto preinstall crea l'utente `oracle` e il gruppo `oinstall`, ma per il RAC servono anche l'utente `grid` e i gruppi ASM.

```bash
# Gruppi ASM (se non esistono già)
groupadd -g 54327 asmdba   2>/dev/null
groupadd -g 54328 asmoper  2>/dev/null
groupadd -g 54329 asmadmin 2>/dev/null

# Modifica utente oracle per aggiungere asmdba
usermod -a -G asmdba oracle

# Crea utente grid
useradd -u 54331 -g oinstall -G dba,asmdba,asmadmin,asmoper,racdba grid

# Imposta password
echo "oracle" | passwd oracle --stdin
echo "grid"   | passwd grid   --stdin
```

> **Perché due utenti (oracle e grid)?** Questa è una best practice di sicurezza chiamata **Role Separation**. L'utente `grid` gestisce il cluster e lo storage (ASM), l'utente `oracle` gestisce solo il database. In caso di compromissione di un account, l'altro è protetto.

---

## 1.8 Creazione Directory

```bash
# Grid Infrastructure
mkdir -p /u01/app/19.0.0/grid        # GRID_HOME
mkdir -p /u01/app/grid                # GRID ORACLE_BASE
mkdir -p /u01/app/oraInventory        # Central Inventory

# Database
mkdir -p /u01/app/oracle              # DB ORACLE_BASE
mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1  # DB ORACLE_HOME

# Permessi
chown -R grid:oinstall   /u01/app/19.0.0/grid
chown -R grid:oinstall   /u01/app/grid
chown -R grid:oinstall   /u01/app/oraInventory
chown -R oracle:oinstall /u01/app/oracle
chmod -R 775 /u01
```

> **Perché questa struttura?** Oracle ha una convenzione storica: `/u01` per i binari. Il `GRID_HOME` deve essere in un path diverso da `ORACLE_BASE` per motivi di supporto Oracle (MOS Note 1373511.1).

---

## 1.9 Variabili d'Ambiente

### Per l'utente `grid`

```bash
cat > /home/grid/.grid_env <<'ENVEOF'
host=$(hostname -s)
if [ "$host" == "rac1" ]; then
    ORA_SID=+ASM1
elif [ "$host" == "rac2" ]; then
    ORA_SID=+ASM2
elif [ "$host" == "racstby1" ]; then
    ORA_SID=+ASM1
elif [ "$host" == "racstby2" ]; then
    ORA_SID=+ASM2
fi

export ORACLE_SID=$ORA_SID
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/19.0.0/grid
export ORACLE_TERM=xterm
export TNS_ADMIN=$ORACLE_HOME/network/admin
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
ENVEOF

echo '. ~/.grid_env' >> /home/grid/.bash_profile
chown grid:oinstall /home/grid/.grid_env
```

### Per l'utente `oracle`

```bash
cat > /home/oracle/.db_env <<'ENVEOF'
host=$(hostname -s)
if [ "$host" == "rac1" ]; then
    ORA_SID=RACDB1
elif [ "$host" == "rac2" ]; then
    ORA_SID=RACDB2
elif [ "$host" == "racstby1" ]; then
    ORA_SID=RACDB1
elif [ "$host" == "racstby2" ]; then
    ORA_SID=RACDB2
fi

export ORACLE_SID=$ORA_SID
export ORACLE_UNQNAME=RACDB
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_TERM=xterm
export TNS_ADMIN=$ORACLE_HOME/network/admin
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
ENVEOF

echo '. ~/.db_env' >> /home/oracle/.bash_profile
chown oracle:oinstall /home/oracle/.db_env
```

---

## 1.10 Parametri Kernel e Limiti (Verifica)

Il pacchetto `oracle-database-preinstall-19c` li ha già configurati, ma verifichiamo:

```bash
# Verifica sysctl
sysctl -a | grep -E "shm|sem|file-max|ip_local_port|rmem|wmem"
```

Valori attesi minimi:
```
kernel.shmmax = 4398046511104
kernel.shmall = 1073741824
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
fs.file-max = 6815744
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
```

```bash
# Verifica limits
cat /etc/security/limits.d/oracle-database-preinstall-19c.conf
```

Se i limits del grid user non esistono:

```bash
cp /etc/security/limits.d/oracle-database-preinstall-19c.conf \
   /etc/security/limits.d/grid-database-preinstall-19c.conf
sed -i 's/oracle/grid/g' /etc/security/limits.d/grid-database-preinstall-19c.conf
```

---

## 1.11 Configurazione NTP/Chrony

Oracle Clusterware richiede che i clock siano sincronizzati tra tutti i nodi (max 1 secondo di differenza):

```bash
# Configura Chrony
vim /etc/chrony.conf
# Aggiungi/modifica:
# server 0.pool.ntp.org iburst
# server 1.pool.ntp.org iburst

systemctl enable chronyd
systemctl restart chronyd

# Verifica
chronyc sources
```

> **Perché?** Se i clock dei nodi del cluster divergono troppo, il Clusterware forza un "node eviction" (espelle il nodo dal cluster) per proteggere i dati.

---

## 1.12 Configurazione SSH Passwordless

Necessario tra tutti i nodi del MEDESIMO cluster (non tra cluster diversi).

### Su rac1 e rac2, come utente `grid`:

```bash
su - grid
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
```

```bash
# Da rac1
ssh-copy-id grid@rac1
ssh-copy-id grid@rac2

# Da rac2
ssh-copy-id grid@rac1
ssh-copy-id grid@rac2

# Test (NON deve chiedere password)
ssh grid@rac1 date
ssh grid@rac2 date
```

### Stessa procedura per `oracle`:

```bash
su - oracle
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
```

```bash
# Da rac1
ssh-copy-id oracle@rac1
ssh-copy-id oracle@rac2

# Da rac2
ssh-copy-id oracle@rac1
ssh-copy-id oracle@rac2

# Test
ssh oracle@rac1 date
ssh oracle@rac2 date
```

> **Perché?** Durante l'installazione del Grid e del DB, Oracle copia i binari dal nodo 1 al nodo 2 via SSH. Se chiede la password, l'installazione fallisce.

### Fix per errore INS-06006 (SCP)

```bash
# Esegui su TUTTI i nodi come root
cp -p /usr/bin/scp /usr/bin/scp.bkp
echo '/usr/bin/scp.bkp -T $*' > /usr/bin/scp
```

> **Perché?** In OpenSSH 9+, il comando `scp` utilizza il protocollo SFTP per default. L'installer Oracle 19c non è compatibile con questo cambiamento e fallisce con l'errore INS-06006. Questo workaround forza il vecchio comportamento.

---

## 1.13 Central Inventory

```bash
cat > /etc/oraInst.loc <<'EOF'
inventory_loc=/u01/app/oraInventory
inst_group=oinstall
EOF

chmod 664 /etc/oraInst.loc
chown grid:oinstall /etc/oraInst.loc
```

> 📸 **SNAPSHOT — "SNAP-03: Prerequisiti Completi (Pre-Grid)" ⭐ MILESTONE**
> Questo è uno snapshot fondamentale! Hai OS, rete, DNS, utenti, SSH, kernel params tutti configurati.
> Se l'installazione Grid fallisce, torni qui e risparmi ore.
> **Fai questo snapshot su ENTRAMBE le VM (rac1 e rac2)!**
> ```
> VBoxManage snapshot "rac1" take "SNAP-03_Prerequisiti_Completi"
> VBoxManage snapshot "rac2" take "SNAP-03_Prerequisiti_Completi"
> ```

---

## ✅ Checklist Fine Fase 1

Esegui questi controlli prima di procedere alla Fase 2:

```bash
# 1. Hostname corretto
hostname

# 2. Tutti i nodi pingabili
ping -c 1 rac1 && ping -c 1 rac2 && ping -c 1 rac1-priv && ping -c 1 rac2-priv

# 3. DNS SCAN funzionante
nslookup rac-scan.oracleland.local

# 4. SSH senza password (grid e oracle)
su - grid -c "ssh rac2 hostname"
su - oracle -c "ssh rac2 hostname"

# 5. Firewall disabilitato
systemctl status firewalld

# 6. SELinux disabilitato
getenforce

# 7. Utenti e gruppi corretti
id oracle
id grid

# 8. Directory esistono con permessi corretti
ls -la /u01/app/
```

---

**→ Prossimo: [FASE 2: Installazione Grid Infrastructure e Oracle RAC Primario](./GUIDA_FASE2_GRID_E_RAC.md)**
