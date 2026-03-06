# FASE 1: Preparazione Nodi e OS (Oracle Linux 7.9)

> **Architettura di riferimento**: 2 nodi RAC primario (`rac1`, `rac2`) + 2 nodi RAC standby (`racstby1`, `racstby2`).
> Tutti i comandi vanno eseguiti come `root` salvo dove diversamente indicato.
> I passaggi di questa fase vanno ripetuti su **tutti i nodi** salvo dove specificato.

### 📸 Riferimenti Visivi

![Partizionamento Disco OS](./images/os_install_partitions.png)

![Architettura DNS BIND](./images/dns_bind_architecture.png)

---

### Cos'è il DNS e Perché Ci Serve?

**DNS (Domain Name System)** è il servizio che traduce i nomi in indirizzi IP. Quando digiti `rac-scan.localdomain`, il DNS risponde con `192.168.56.105, 192.168.56.106, 192.168.56.107`.

```
  Senza DNS:                          Con DNS:
  ══════════                          ═════════

  Applicazione:                       Applicazione:
  "Connettimi a                       "Connettimi a
   192.168.56.105"                      rac-scan.localdomain"
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
- Lo **SCAN** (Single Client Access Name) DEVE risolvere a 3 IP simultaneamente.
- `/etc/hosts` **NON** basta per lo SCAN. Non supporta il Round-Robin. Se metti 3 IP per `rac-scan` nel file hosts, Linux userà sempre e solo il primo.
- Il DNS invece permette il **round-robin**: le connessioni dei client vengono distribuite automaticamente tra i 3 IP.

**Che DNS usiamo nel Lab? (Dnsmasq vs BIND)**
In produzione si usano server DNS complessi come **BIND** o Microsoft DNS. In laboratorio, installare BIND richiede decine di file di configurazione composti da sintassi ostica.
Per **semplificare enormemente**, noi useremo **Dnsmasq**. Dnsmasq è un DNS leggerissimo che fa una cosa magica: **legge il suo file `/etc/hosts` e lo trasforma in record DNS interrogabili dalla rete**.

```
  Il trucco di Dnsmasq:
  ═════════════════════
  1. Compiliamo /etc/hosts sul nodo 'dnsnode' con tutti gli IP (inclusi i 3 SCAN)
  2. Avviamo dnsmasq
  3. dnsmasq legge quel file e "serve" quelle traduzioni agli altri nodi (rac1, rac2)
  4. Quando rac1 chiede "chi è rac-scan?", dnsmasq restituisce i 3 IP in round-robin!
```

**Tipi di record DNS che configuriamo:**

| Tipo | Esempio | Cosa fa |
|---|---|---|
| **A** | `rac1 → 192.168.56.101` | Nome → IP (forward) |
| **PTR** | `192.168.56.101 → rac1` | IP → Nome (reverse) |
| **SOA** | `localdomain` | Authority della zona |
| **NS** | `ns1.localdomain` | Chi risponde per questa zona |

---

## 1.1 Piano IP e Hostname

Prima di tutto, definiamo il piano di indirizzamento. Questo è il cuore di qualsiasi cluster: se sbagli gli IP, niente funziona.

| Ruolo | Hostname | IP Pubblica | IP Privata (Interconnect) | IP VIP |
|---|---|---|---|---|
| RAC Nodo 1 | rac1 | 192.168.56.101 | 192.168.1.101 | 192.168.56.103 |
| RAC Nodo 2 | rac2 | 192.168.56.102 | 192.168.1.102 | 192.168.56.104 |
| RAC SCAN | rac-scan | 192.168.56.105, .121, .122 | - | - |
| Standby Nodo 1 | racstby1 | 192.168.56.111 | 192.168.2.111 | 192.168.56.113 |
| Standby Nodo 2 | racstby2 | 192.168.56.112 | 192.168.2.112 | 192.168.56.114 |
| Standby SCAN | racstby-scan | 192.168.56.115, .221, .222 | - | - |
| Target GoldenGate | dbtarget | 192.168.56.150 | - | - |

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
         │           │         │  192.168.1.0/24   │  Host-Only  │
         │           │  ┌──────┴──────┐   ┌──────┴──────┐      │
         │           │  │ rac1-priv   │   │ rac2-priv   │      │
         │           │  │ 192.168.1.101  │◄═►│ 192.168.1.102  │      │
         │           │  └─────────────┘   └─────────────┘      │
         │           │         Cache Fusion (GCS/GES)           │
         │           │    Blocchi dati trasferiti via RAM        │
         │           └─────────────────────────────────────────┘
```

> **VIP (Virtual IP)**: Quando un nodo crasha, il suo VIP "migra" sull'altro nodo in pochi secondi. I client connessi al VIP vengono re-indirizzati automaticamente senza cambiare configurazione.

> **SCAN**: I client si connettono SEMPRE allo SCAN, MAI direttamente ai nodi. Lo SCAN load-balancia le connessioni tra i nodi disponibili.

---

## 1.2 Il Problema del Copia-Incolla (MobaXterm)

> ⚠️ **ATTENZIONE**: Appena installato il sistema operativo, ti trovi nella console nera di VirtualBox dove **non puoi incollare testo**. Tutte le configurazioni successive (come l'`/etc/hosts`) sono file lunghissimi. 
> Per procedere devi **prima dare un IP** alla macchina usando l'interfaccia testuale, e poi collegarti dal tuo PC tramite **MobaXterm**. Questo vale per **TUTTE le macchine** (`rac1`, `rac2`, `racstby1`, etc.) man mano che le crei.

**Passo 1: Assegna un IP Temporaneo (dalla console VirtualBox)**
1. Fai login come `root` sulla VM che stai preparando.
2. Esegui: `nmtui`
3. Seleziona **Edit a connection**.
4. **ATTIVA IL NAT (Internet)**: Seleziona la PRIMA scheda (es. `enp0s3`), vai su Edit, e assicurati che la casella **"Automatically connect"** sia SPUNTATA. Fai OK. Questo garantisce l'accesso a Internet via DHCP di VirtualBox.
5. **CONFIGURA L'IP PUBBLICO**: Seleziona la SECONDA scheda (es. `enp0s8` host-only), vai su Edit.
6. Cambia IPv4 Configuration in **Manual**.
7. Inserisci l'IP pubblico corretto per questo nodo (vedi piano IP della FASE 0):
   - *Es. per rac1: `192.168.56.101/24`*
   - *Es. per rac2: `192.168.56.102/24`*
   - *Es. per racstby1: `192.168.56.111/24`*
   - *Es. per racstby2: `192.168.56.112/24`*
   - *Es. per dbtarget: `192.168.56.150/24`*
8. Salva, esci e torna al prompt.
9. Riavvia la rete: `systemctl restart network`
10. **TASSATIVO**: Verifica di avere Internet: `ping -c 2 google.com`
11. Verifica l'IP statico: `ip addr`

**Passo 2: Connettiti tramite MobaXterm**
1. Apri MobaXterm sul tuo PC Windows.
2. Crea una nuova sessione SSH verso quell'IP come utente `root`.
3. Ricorda di spuntare **X11-Forwarding**.
4. **Ora puoi fare copia-incolla di tutti i comandi seguenti per questo nodo!**

---

## 1.3 Configurazione Rete (File Statici)

Ora che sei su MobaXterm, rendiamo permanente e rigorosa la configurazione scrivendo i file. 
> ⚠️ **ATTENZIONE AI NOMI DELLE SCHEDE**: I nomi fisici dipendono dall'OS. In Oracle Linux 7, di solito l'Adattatore 1 (NAT) si chiama `enp0s3`, l'Adattatore 2 (Pubblica) si chiama `enp0s8`, e l'Adattatore 3 (Privata) si chiama `enp0s9`. Sostituisci i nomi negli script se necessario controllando `ip addr`.

Esempio per `rac1`:

### 1. Interfaccia NAT (Internet) $\rightarrow$ `enp0s3`
Non usare IP statici qui. Deve prendere IP, Gateway e DNS dal DHCP di VirtualBox.
```bash
cat > /etc/sysconfig/network-scripts/ifcfg-enp0s3 <<'EOF'
TYPE=Ethernet
BOOTPROTO=dhcp
NAME=enp0s3
DEVICE=enp0s3
ONBOOT=yes
EOF
```

### 2. Interfaccia Pubblica (192.168.56.x) $\rightarrow$ `enp0s8`
Questa è la rete del Lab dove i nodi comunicano tra loro e con il tuo PC.
```bash
cat > /etc/sysconfig/network-scripts/ifcfg-enp0s8 <<'EOF'
TYPE=Ethernet
BOOTPROTO=static
NAME=enp0s8
DEVICE=enp0s8
ONBOOT=yes
IPADDR=192.168.56.101
NETMASK=255.255.255.0
DOMAIN=localdomain
EOF
```
> *(Nota: Abbiamo omesso volontariamente il GATEWAY qui per evitare che scavalchi il NAT interrompendo l'accesso a Internet)*

### 3. Interfaccia Privata (192.168.1.x o o 2.x) $\rightarrow$ `enp0s9`
L'interconnect per il traffico esclusivo del cluster. **NIENTE GATEWAY QUI**.
```bash
cat > /etc/sysconfig/network-scripts/ifcfg-enp0s9 <<'EOF'
TYPE=Ethernet
BOOTPROTO=static
NAME=enp0s9
DEVICE=enp0s9
ONBOOT=yes
IPADDR=192.168.1.101
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
ping -c 2 rac2        # Da rac1 (dopo aver configurato hosts)
ping -c 2 rac2-priv   # Da rac1 (rete privata)
```

---

## 1.4 Configurazione /etc/hosts

Esegui su **TUTTI** i nodi (sempre da MobaXterm!):

```bash
cat >> /etc/hosts <<'EOF'
# === RAC PRIMARY ===
192.168.56.101   rac1.localdomain       rac1
192.168.56.102   rac2.localdomain       rac2
192.168.1.101    rac1-priv.localdomain  rac1-priv
192.168.1.102    rac2-priv.localdomain  rac2-priv
192.168.56.103   rac1-vip.localdomain   rac1-vip
192.168.56.104   rac2-vip.localdomain   rac2-vip

# === RAC STANDBY ===
192.168.56.111   racstby1.localdomain      racstby1
192.168.56.112   racstby2.localdomain      racstby2
192.168.2.111    racstby1-priv.localdomain racstby1-priv
192.168.2.112    racstby2-priv.localdomain racstby2-priv
192.168.56.113   racstby1-vip.localdomain  racstby1-vip
192.168.56.114   racstby2-vip.localdomain  racstby2-vip

# === TARGET GOLDENGATE ===
192.168.56.150   dbtarget.localdomain   dbtarget
EOF
```

> **Perché /etc/hosts e non solo DNS?** Oracle Clusterware verifica la risoluzione dei nomi PRIMA che il DNS sia attivo. Se metti tutto solo in DNS e il DNS non parte, il cluster non si avvia. Il file hosts è la "rete di sicurezza".

---

## 1.4 Configurazione DNS (Dnsmasq su VM separata)

> **Il DNS è già stato configurato nella Fase 0** sulla VM `dnsnode` con Dnsmasq.
> Se non hai ancora completato la [Fase 0 — sezione 0.3](./GUIDA_FASE0_SETUP_MACCHINE.md), torna indietro e falla ora.
>
> **Perché una VM DNS separata?** (Oracle Base approach)
> - Il DNS non si ferma quando riavvii i nodi RAC
> - Lo SCAN funziona sempre, anche durante i restart del cluster
> - Dnsmasq legge `/etc/hosts` e lo espone come DNS — zero configurazione di zone
> - Costa solo 1 GB di RAM

### Configura resolv.conf su TUTTI i nodi RAC

```bash
# == ESEGUI SU OGNI NODO (rac1, rac2, racstby1, racstby2) ==

# Punta al DNS server (la VM dnsnode)
cat > /etc/resolv.conf <<'EOF'
search localdomain
nameserver 192.168.56.50
EOF

# CRITICO: Impedisci a NetworkManager di sovrascrivere resolv.conf
sed -i -e "s|\[main\]|\[main\]\ndns=none|g" /etc/NetworkManager/NetworkManager.conf
systemctl restart NetworkManager.service

# Proteggilo anche con chattr per sicurezza extra
chattr +i /etc/resolv.conf
```

> **Cosa fa dns=none?** Dice a NetworkManager di NON toccare `/etc/resolv.conf` dopo un reboot. Senza questo fix, dopo ogni restart il file viene riscritto e il SCAN smette di funzionare. È uno dei bug più insidiosi!

### Test DNS (da ogni nodo)

```bash
# Verifica che il DNS risolve gli hostname
nslookup rac1 192.168.56.50
nslookup rac2 192.168.56.50

# SCAN deve ritornare 3 IP!
nslookup rac-scan 192.168.56.50
# Server:  192.168.56.50
# Address: 192.168.56.50#53
# Name:    rac-scan.localdomain
# Address: 192.168.56.105
# Name:    rac-scan.localdomain
# Address: 192.168.56.106
# Name:    rac-scan.localdomain
# Address: 192.168.56.107

# Standby SCAN
nslookup racstby-scan 192.168.56.50
```

### (Opzionale ma Consigliato) Configurare il DNS su Windows (Host)

Se vuoi accedere a EM Express o altri servizi web del lab direttamente dal browser del tuo PC fisico usando i nomi (es. `https://rac1.localdomain:5500/em`), devi dire a Windows di usare il tuo `dnsnode`.

1. Su Windows, apri **Impostazioni di rete** -> **Modifica opzioni scheda**.
2. Trova la scheda **VirtualBox Host-Only Network** (quella relativa a `192.168.56.x`).
3. Tasto destro -> **Proprietà** -> Doppio clic su **Protocollo Internet versione 4 (TCP/IPv4)**.
4. Seleziona **Utilizza i seguenti indirizzi server DNS**.
5. Server DNS preferito: inserisci l'IP del dnsnode (`192.168.56.50`).
6. Clicca OK. Ora dal tuo browser Windows puoi navigare usando gli hostname del lab!

> **Se il DNS non funziona, NON procedere!** Il Grid installer fallirà se non riesce a risolvere lo SCAN.

> 📸 **SNAPSHOT — "SNAP-02: Rete e DNS Configurati"**
> Hai rete statica + DNS funzionante. Se qualcosa va storto dopo, puoi tornare qui.
> ```
> VBoxManage snapshot "rac1" take "SNAP-02_Rete_DNS_OK"

```bash
# Installa BIND
yum install -y bind bind-utils
```

### Configurazione /etc/named.conf

```bash
cp /etc/named.conf /etc/named.conf.bkp

cat > /etc/named.conf <<'EOF'
options {
    listen-on port 53 { 127.0.0.1; 192.168.56.101; };
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
zone "localdomain" IN {
    type master;
    file "forward.localdomain";
    allow-update { none; };
};

// Reverse Zone
zone "1.168.192.in-addr.arpa" IN {
    type master;
    file "reverse.localdomain";
    allow-update { none; };
};
EOF
```

> **Perché il DNS?** Oracle richiede che il nome SCAN risolva ad almeno 1 IP (consigliati 3) tramite DNS. Il file `/etc/hosts` NON viene usato per lo SCAN.

### Come Funziona la Risoluzione DNS nel Nostro Lab

```
Client → "Connettimi a rac-scan.localdomain"
    │
    ▼
┌──────────────────┐
│  /etc/resolv.conf │──→ nameserver 192.168.56.101 (rac1)
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  BIND DNS Server (su rac1, porta 53)     │
│                                          │
│  Zone: localdomain                  │
│  ┌────────────────────────────────────┐  │
│  │ rac-scan  →  192.168.56.105        │  │
│  │ rac-scan  →  192.168.56.106        │  │  ← 3 record A!
│  │ rac-scan  →  192.168.56.107        │  │    Round-robin
│  │ rac1      →  192.168.56.101        │  │
│  │ rac2      →  192.168.56.102        │  │
│  │ rac1-vip  →  192.168.56.103        │  │
│  │ ...                               │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
    │
    ▼ Risponde con 3 IP in ordine casuale
    192.168.56.106, 192.168.56.105, 192.168.56.107
```

### Zone Forward

```bash
cat > /var/named/forward.localdomain <<'EOF'
$TTL 86400
@ IN SOA rac1.localdomain. admin.localdomain. (
    2024030201 ; Serial
    3600       ; Refresh
    1800       ; Retry
    604800     ; Expire
    86400      ; Minimum TTL
)

; Name Server
@ IN NS rac1.localdomain.

; A Records - RAC Primary
rac1            IN  A   192.168.56.101
rac2            IN  A   192.168.56.102
rac1-vip        IN  A   192.168.56.103
rac2-vip        IN  A   192.168.56.104
rac-scan        IN  A   192.168.56.105
rac-scan        IN  A   192.168.56.106
rac-scan        IN  A   192.168.56.107

; A Records - RAC Standby
racstby1        IN  A   192.168.56.111
racstby2        IN  A   192.168.56.112
racstby1-vip    IN  A   192.168.56.113
racstby2-vip    IN  A   192.168.56.114
racstby-scan    IN  A   192.168.56.115
racstby-scan    IN  A   192.168.56.116
racstby-scan    IN  A   192.168.56.117

; A Records - Target GoldenGate
dbtarget        IN  A   192.168.56.150
EOF
```

### Zone Reverse

```bash
cat > /var/named/reverse.localdomain <<'EOF'
$TTL 86400
@ IN SOA rac1.localdomain. admin.localdomain. (
    2024030201 ; Serial
    3600       ; Refresh
    1800       ; Retry
    604800     ; Expire
    86400      ; Minimum TTL
)

@ IN NS rac1.localdomain.
rac1 IN A 192.168.56.101

; PTR Records
101 IN PTR rac1.localdomain.
102 IN PTR rac2.localdomain.
111 IN PTR rac1-vip.localdomain.
112 IN PTR rac2-vip.localdomain.
120 IN PTR rac-scan.localdomain.
121 IN PTR rac-scan.localdomain.
122 IN PTR rac-scan.localdomain.
201 IN PTR racstby1.localdomain.
202 IN PTR racstby2.localdomain.
150 IN PTR dbtarget.localdomain.
EOF
```

```bash
# Imposta permessi e owner
chown named:named /var/named/forward.localdomain
chown named:named /var/named/reverse.localdomain

# Verifica configurazione
named-checkconf /etc/named.conf
named-checkzone localdomain /var/named/forward.localdomain
named-checkzone 1.168.192.in-addr.arpa /var/named/reverse.localdomain

# Avvia il servizio
systemctl enable named
systemctl start named
```

### Configura resolv.conf su TUTTI i nodi

```bash
cat > /etc/resolv.conf <<'EOF'
search localdomain
nameserver 192.168.56.101
options timeout:1
options attempts:5
EOF

# Proteggilo da sovrascritture di NetworkManager
chattr +i /etc/resolv.conf
```

### Test DNS

```bash
nslookup rac-scan.localdomain
# Deve restituire 3 IP: 192.168.56.105, .121, .122

nslookup racstby-scan.localdomain
# Deve restituire 3 IP: 192.168.56.115, .221, .222

nslookup rac1.localdomain
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
nslookup rac-scan.localdomain

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
