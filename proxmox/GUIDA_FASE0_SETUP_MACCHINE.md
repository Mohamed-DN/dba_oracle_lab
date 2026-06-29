# FASE 0: Setup delle Macchine (Proxmox VE + Oracle Linux 8.10)

> **Questa fase va completata PRIMA di tutto il resto.** Qui creiamo le VM nell'hypervisor Proxmox per il DNS, il RAC primario e il RAC standby.
> **Basato su**: Esperienza architetturale Enterprise per installazioni bare-metal, adattato per una configurazione a singolo nodo Proxmox con Storage Locale.

## Obiettivo operativo

Preparare un laboratorio Proxmox riproducibile e di grado Enterprise per un CDB RAC primary `RACDB`, una PDB applicativa `RACDBPDB`, uno standby fisico RAC `RACDB_STBY` e gli Observer FSFO opzionali. Questa guida usa la release moderna **Oracle Linux 8.10** e il driver **ASMLib v3**.

## Procedura operativa

Completa in ordine: Creazione dei Linux Bridge (reti), VM `dnsnode`, VM `rac1`, provisioning storage `/u01`, configurazione dischi ASM condivisi. In questa fase gli snapshot di Proxmox sono ammessi solo per VM spente e prima dell'inizializzazione del Grid Infrastructure.

## Validazione finale

Prima di passare alla Fase 1 verifica: DNS resolving corretto, piano IP applicato su Proxmox, mount `/u01` stabile al reboot, mappa dei dischi ASM creata con `oracleasm listdisks` e corretta applicazione del flag `shared=1` sui file di configurazione Proxmox.

## Troubleshooting rapido

Se un device o un nome DNS non coincide con la guida, fermati e correggi l'inventario prima di clonare le VM. Non tentare fix sui dischi ASM finché non hai identificato con certezza device, dimensione e VM proprietaria.

### Vista d'Insieme del Lab Proxmox

```
+----------------------------------------------------------------------------------+
|                     IL TUO SERVER BARE-METAL (PROXMOX VE)                        |
|                                                                                  |
|   +-----------------------------------------------------------------------+      |
|   |                  Linux Bridge: vmbr1 (192.168.56.0/24)                |      |
|   |                    "Pubblica" per il cluster                          |      |
|   +--+---------+--------+----------+----------+--------------------------+      |
|      |         |        |          |          |                                  |
|   +--+---+  +--+--+  +--+--+   +--+--+   +--+--+                              |
|   |dns   |  |rac1 |  |rac2 |   |stby1|   |stby2|                               |
|   |.56.50|  |.56.1|  |.56.2|   |.56.3|   |.56.4|   dbtarget + GG su cloud     |
|   |1GB   |  |12GB |  |12GB |   |12GB |   |12GB |                               |
|   |1CPU  |  |4CPU |  |4CPU |   |4CPU |   |4CPU |                               |
|   +------+  +--+--+  +--+--+   +--+--+   +--+--+                               |
|                |        |        |         |                                    |
|             +--+--------+--+  +--+---------+--+                                |
|             |  vmbr2       |  |  vmbr3        |    (Linux Bridges Privati)     |
|             |  192.168.1.x |  |  192.168.2.x  |    Interconnect isolati        |
|             +--------------+  +---------------+                                |
|                                                                                  |
|   Dischi Condivisi su Storage Locale (RAW + shared=1):                          |
|   +------------------------+    +------------------------+                      |
|   | rac1 + rac2            |    | racstby1 + racstby2    |                      |
|   | asm-crs-disk1  2GB     |    | asm-stby-crs-1  2GB   |                      |
|   | asm-crs-disk2  2GB     |    | asm-stby-crs-2  2GB   |                      |
|   | asm-crs-disk3  2GB     |    | asm-stby-crs-3  2GB   |                      |
|   | asm-data-disk1 20GB    |    | asm-stby-data   20GB  |                      |
|   | asm-reco-disk1 15GB    |    | asm-stby-reco   15GB  |                      |
|   +------------------------+    +------------------------+                      |
+----------------------------------------------------------------------------------+
```

---

## 0.1 Cosa Ti Serve (Requisiti Hardware su Proxmox)

Rispetto a VirtualBox, Proxmox gestisce la memoria in modo molto più efficiente, ma per un RAC Enterprise raccomandiamo un nodo bare-metal con almeno 64GB di RAM e dischi NVMe/SSD veloci.

| Macchina | Tipo | RAM | CPU (Type=Host) | Disco OS | Disco /u01 | Dischi ASM |
|---|---|---|---|---|---|---|
| `dnsnode` | VM Proxmox | **1 GB** | **1 vCPU** | 15 GB | — | — |
| `rac1` | VM Proxmox | **8-12 GB** | **4 vCPU** | 50 GB | 100 GB | 5 condivisi |
| `rac2` | VM (clone) | **8-12 GB** | **4 vCPU** | 50 GB | 100 GB | stessi di rac1 |
| `racstby1` | VM Proxmox | **8-12 GB** | **4 vCPU** | 50 GB | 100 GB | 5 condivisi (propri) |
| `racstby2` | VM (clone) | **8-12 GB** | **4 vCPU** | 50 GB | 100 GB | stessi di racstby1 |
| `observer1` | VM Linux | **2 GB** | **1 vCPU** | 20 GB | — | — |
| `observer2` | VM opzionale | **2 GB** | **1 vCPU** | 20 GB | — | — |

> **Perché CPU "Host"?** Proxmox di default maschera le CPU come "kvm64" per massima compatibilità nelle migrazioni. Per un server Database, usare "Host" espone le istruzioni crittografiche (AES-NI) del processore fisico alla VM, riducendo drasticamente il carico CPU per le connessioni crittografate (TDE, SSH, ecc.).

### Piano IP Completo

| Hostname | Tipo | IP Pubblica | IP Privata | Note |
|---|---|---|---|---|
| `dnsnode` | DNS Server | 192.168.56.50 | — | Dnsmasq |
| `rac1` | RAC Primary N.1 | 192.168.56.101 | 192.168.1.101 | |
| `rac2` | RAC Primary N.2 | 192.168.56.102 | 192.168.1.102 | |
| `rac1-vip` | VIP N.1 | 192.168.56.103 | — | Gestito dal CRS |
| `rac2-vip` | VIP N.2 | 192.168.56.104 | — | Gestito dal CRS |
| `rac-scan` | SCAN (3 IP) | 192.168.56.105-107 | — | Round-Robin DNS |
| `racstby1` | Standby N.1 | 192.168.56.111 | 192.168.2.111 | |
| `racstby2` | Standby N.2 | 192.168.56.112 | 192.168.2.112 | |
| `racstby1-vip` | VIP Standby N.1 | 192.168.56.113 | — | Gestito dal CRS |
| `racstby2-vip` | VIP Standby N.2 | 192.168.56.114 | — | Gestito dal CRS |
| `racstby-scan` | SCAN Standby | 192.168.56.115-117 | — | Round-Robin DNS |
| `observer1` | FSFO Observer | 192.168.56.121 | — | Creato in Fase 4B |
| `observer2` | FSFO Backup | 192.168.56.122 | — | Opzionale |

### Software e ISO (Caricati su Proxmox)

Scarica la ISO di **Oracle Linux 8.10** (`OracleLinux-R8-U10-Server-x86_64-dvd.iso`) e caricala nello storage ISO del tuo nodo Proxmox (solitamente `local` -> ISO Images -> Upload).

### 🔧 Patch Oracle — Come Trovarli (My Oracle Support)

Compila l'inventario con la RU approvata prima di iniziare. Gli ID cambiano ogni
trimestre: non copiare ID patch da una vecchia esecuzione.

| Campo | Valore approvato |
|---|---|
| Versione OPatch minima richiesta | `<OPATCH_VERSION>` |
| Combo patch GI/DB RU + OJVM | `<COMBO_PATCH_ID>` |
| Grid/Database RU | `<RU_PATCH_ID>` |
| OJVM RU | `<OJVM_PATCH_ID>` |
| Data approvazione e change | `<CHANGE_ID> - <YYYY-MM-DD>` |

> **Come trovare l'ultima RU**: Vai su MOS (Doc ID **2118136.2**) → tabella con TUTTE le Release Update per ogni versione.

---

## 0.2 Configurazione Reti su Proxmox (Linux Bridge)

In Proxmox, le reti "Host-Only" di VirtualBox si replicano creando dei **Linux Bridge** senza IP gateway/collegamento fisico, creando di fatto degli switch virtuali isolati all'interno del server.

Dalla GUI di Proxmox -> Seleziona il tuo Nodo -> **Network** -> **Create** -> **Linux Bridge**

### 1. Rete "Pubblica" del Cluster (192.168.56.0/24)
- **Name:** `vmbr1`
- **IPv4/CIDR:** `192.168.56.1/24`
- **Bridge ports:** *(lascia vuoto)* -> Questo la isola dal mondo esterno.
   
### 2. Interconnect RAC Primario (192.168.1.0/24)
- **Name:** `vmbr2`
- **IPv4/CIDR:** `192.168.1.1/24`
- **Bridge ports:** *(lascia vuoto)*

### 3. Interconnect RAC Standby (192.168.2.0/24)
- **Name:** `vmbr3`
- **IPv4/CIDR:** `192.168.2.1/24`
- **Bridge ports:** *(lascia vuoto)*

> [!WARNING]
> In alto clicca su **Apply Configuration** per rendere attivi i nuovi bridge senza dover riavviare l'host Proxmox.

---

## 0.3 Creazione VM `dnsnode` 

### Creazione in Proxmox
1. Clicca **Create VM** in alto a destra.
2. **General:** Node: pve, VM ID: 100, Name: `dnsnode`
3. **OS:** Usa file ISO -> Seleziona `OracleLinux-R8-U10-Server-x86_64-dvd.iso`
4. **System:** Machine `q35`, SCSI Controller **VirtIO SCSI Single**.
5. **Disks:** Storage `local-lvm` (o tuo pool), Disk size: **15 GiB**, Format: **Raw**, spunta **Discard**.
6. **CPU:** 1 Core, Type: **Host**.
7. **Memory:** 1024 MiB. Disattiva il "Ballooning" per avere RAM statica e predicibile.
8. **Network:** Seleziona `vmbr0` (Rete NAT/Internet del tuo server fisico). Modello: **VirtIO (paravirtualized)**.

Dopo aver creato la VM, vai nelle impostazioni hardware di `dnsnode` e aggiungi una **seconda scheda di rete** collegata a `vmbr1` (la Rete Pubblica).

### Installazione OS 8.10 e IP
Avvia la VM e installa Oracle Linux 8.10 (Minimal Install).
Dalla console di Proxmox, esegui:
```bash
nmtui
```
- Modifica la scheda collegata a `vmbr0` per connettersi in DHCP (Auto).
- Modifica la scheda collegata a `vmbr1` con IP Statico: `192.168.56.50/24` (niente gateway).
- Riavvia il network: `nmcli connection reload; nmcli connection up <nome_profilo>`.

### Connettiti con MobaXterm (Copia-Incolla)
Ora dal tuo PC, apri MobaXterm e collegati via SSH a `192.168.56.50` (utente `root`). Incolla il seguente codice per installare Dnsmasq:

```bash
# == ESEGUI COME ROOT ==

# 1. Popola /etc/hosts con TUTTI gli hostname (FQDN + short)
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

# === FSFO OBSERVER ===
192.168.56.121   observer1.localdomain      observer1
192.168.56.122   observer2.localdomain      observer2
EOF

# 2. Installa Dnsmasq e tools (su OL8 usiamo dnf)
dnf install -y dnsmasq bind-utils

# 3. Configura Dnsmasq
# Modifica "eth1" con il nome reale della tua scheda su vmbr1 (es. ens19) se necessario.
cat > /etc/dnsmasq.d/rac.conf <<EOF
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

# 4. Avvia
systemctl enable dnsmasq --now

# 5. Apri porta DNS firewall
firewall-cmd --permanent --add-service=dns
firewall-cmd --reload

# 6. TEST
nslookup rac1.localdomain 192.168.56.50
nslookup rac-scan.localdomain 192.168.56.50      # ← DEVE ritornare 3 IP!
```

> 📸 Fai uno Snapshot Proxmox: `SNAP-DNS-Pronto`

---

## 0.4 Creazione VM `rac1` (RAC Primario)

1. **Create VM** -> Name: `rac1`
2. **OS:** ISO `OracleLinux-R8-U10-Server-x86_64-dvd.iso`
3. **System:** Machine `q35`, Qemu Agent `Yes`, SCSI Controller `VirtIO SCSI Single`.
4. **Disks:**
   - Disco 0 (OS): `50 GiB`, Format `Raw`, spunta **Discard**.
   - Clicca **Add** per aggiungere il Disco /u01: `100 GiB`, Format `Raw`, spunta **Discard**.
5. **CPU:** 4 Cores, Type: **Host** (Fondamentale per performance database).
6. **Memory:** 8192 MiB (o 12288 MiB), **Ballooning disattivato**.
7. **Network:** Seleziona `vmbr0` (Internet), Model `VirtIO`.

**Subito dopo**, vai nella tab **Hardware** della VM e aggiungi:
- `Network Device` collegato a `vmbr1` (Pubblica)
- `Network Device` collegato a `vmbr2` (Privata)

---

## 0.5 Creazione Dischi Condivisi ASM (Il "Segreto" di Proxmox)

In Proxmox la condivisione di storage simulato tipo SAN richiede l'utilizzo del flag `shared=1` e la **disattivazione assoluta della cache** sul disco. Senza questi attributi, i lock distribuiti del Clusterware falliscono in timeout.

### Step 1: Crea i dischi dalla GUI
Vai in **rac1** -> **Hardware** -> **Add** -> **Hard Disk**.
Crea 5 dischi sullo storage (es. `local-lvm`). 
Impostazioni per ciascuno:
- **Cache:** `No cache` (Obbligatorio per ASM)
- **Discard:** `Yes`
- **No Backup:** Spunta per evitare di backuppare l'inutile RAW ASM.
Dimensioni:
- 3 dischi da **2 GB** (+CRS)
- 1 disco da **20 GB** (+DATA)
- 1 disco da **15 GB** (+RECO)

> 💡 **Oracle Best Practices: Perché 3 dischi da 2 GB per il CRS?**
> Il Cluster Ready Services salva lo stato nel *Voting Disk*. Per evitare lo split-brain Oracle usa un quorum a maggioranza: `(N/2) + 1`. Con 3 dischi, bastano 2 attivi. Se 1 disco si rompe (o 1 LUN della SAN cede), il cluster sopravvive. Inoltre 2GB garantiscono spazio per aggiornamenti futuri.

### Step 2: Abilita il flag Shared (Da Terminale Proxmox)

L'interfaccia web di Proxmox non ha la spunta `Shared` per dischi locali. Apri la shell dell'host Proxmox e modifica il file della VM (sostituisci `101` con il tuo VM ID):

```bash
nano /etc/pve/qemu-server/101.conf
```

Aggiungi il flag `,shared=1` alla fine dei 5 dischi appena aggiunti:

```text
scsi2: local-lvm:vm-101-disk-2,cache=none,discard=on,size=2G,shared=1
scsi3: local-lvm:vm-101-disk-3,cache=none,discard=on,size=2G,shared=1
scsi4: local-lvm:vm-101-disk-4,cache=none,discard=on,size=2G,shared=1
scsi5: local-lvm:vm-101-disk-5,cache=none,discard=on,size=20G,shared=1
scsi6: local-lvm:vm-101-disk-6,cache=none,discard=on,size=15G,shared=1
```

---

## 0.6 Installazione Oracle Linux 8.10 su `rac1`

1. Avvia `rac1` e procedi all'installazione dal boot menu.
2. In **Software Selection**, scegli **Server with GUI** (Oracle Installer richiede X11/Java).
3. In **Installation Destination**, fai attenzione:
   > 🛑 **IL CONCETTO PIÙ IMPORTANTE**
   > L'installer mostrerà 7 dischi! **Seleziona SOLO il disco da 50 GB (`sda`).** Deseleziona esplicitamente tutti gli altri (sdb da 100GB, e sdc/d/e/f/g ASM).
4. Scegli Partizionamento **Custom**:
   - `/boot` (Standard, XFS) -> `1024 MiB`
   - `swap` (LVM) -> `8192 MiB` (Raccomandazione Oracle: RAM=Swap per macchine tra 2 e 16GB)
   - `/` (LVM, XFS) -> Tutto lo spazio rimanente (~41GB).
5. In **Network**, accendi le schede e imposta l'Hostname `rac1`. Non dare IP statici qui (lo facciamo in Fase 1).
6. Disabilita **Kdump** (risparmia RAM). Root password: `oracle`.
7. Clicca **Begin Installation**.

---

## 0.7 Preparare il Disco `/u01` (100 GB)

Dopo il riavvio, loggati come `root` via console o SSH.
Dobbiamo configurare il disco `sdb` (100GB) per ospitare il software Oracle.

### Step 1: Partizionamento e Formattazione
```bash
# Verifica che sdb sia da 100G
lsblk

# Partiziona sdb (n, p, 1, invio, invio, w)
fdisk /dev/sdb

# Formatta in XFS
mkfs.xfs -f /dev/sdb1

# Crea punto di mount
mkdir -p /u01
```

### Step 2: Montaggio Permanente (fstab)
Perché usiamo `0 0` nei campi finali di fstab? Il primo zero disabilita `dump`. Il secondo zero dice a `fsck` di ignorare questo filesystem al boot: XFS gestisce la consistenza col journaling integrato.

```bash
UUID=$(blkid -s UUID -o value /dev/sdb1)
echo "UUID=${UUID}  /u01  xfs  defaults 0 0" >> /etc/fstab
mount -a
df -h | grep u01
```

---

## 0.8 Configurare ASMLib v3 per i Dischi ASM

In Oracle Linux 8.10, i pacchetti legacy non sono ammessi. Usiamo il preinstall 19c ufficiale e ASMLib compilato per UEK/RHCK moderni.

```bash
# 1. Preinstall ufficiale 19c per OL8 (risolve kernel params e lib)
dnf install -y oracle-database-preinstall-19c

# 2. Installa ASMLib (già nei repo ol8_UEKR6/7 e ol8_addons)
dnf install -y oracleasm-support oracleasmlib

# 3. Configura
oracleasm configure -i
# Owner: grid
# Group: asmadmin
# Start on boot: y
# Scan on boot: y
```

### Partizionamento Dischi (Script Automatico)
> ⚠️ Verifica i device prima: assicurati che `sdc` - `sdg` siano i tuoi dischi RAW.
```bash
# Sostituisci lettere se necessario
for disk in /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg; do
  echo "Partizionando $disk..."
  echo -e "n\np\n1\n\n\nw" | fdisk $disk
done
partprobe
```

### Timbratura ASMLib
```bash
oracleasm createdisk CRS1 /dev/sdc1
oracleasm createdisk CRS2 /dev/sdd1
oracleasm createdisk CRS3 /dev/sde1
oracleasm createdisk DATA /dev/sdf1
oracleasm createdisk RECO /dev/sdg1

oracleasm scandisks
oracleasm listdisks
```

> 💡 **Nota per il Clone (rac2):** Quando creeremo `rac2`, i dischi condivisi saranno mappati da Proxmox. Sul nodo 2 non dovrai formattarli o etichettarli, ma ti basterà lanciare `oracleasm scandisks` per vederli.

---

## 0.9 Preparazione Dischi per lo Standby

Per il Data Guard, preparerai dei dischi identici ma isolati fisicamente.
In Proxmox, creerai 5 nuovi dischi liberi (non ancora attaccati a nessuna VM, o li creerai in futuro quando instanzierai `racstby1`). Il processo di condivisione `shared=1` sarà identico.

---

## 0.10 Prossimi Passi

Hai completato il layer hardware/hypervisor per l'intera farm!
Ora devi preparare il Sistema Operativo (tuning di fino, rete, SSH) su `rac1` nella **FASE 1**.
Una volta che `rac1` sarà perfetto, utilizzerai la funzionalità **Clone** di Proxmox per creare `rac2`, `racstby1` e `racstby2` in pochissimi minuti a partire dalla Golden Image che otterrai a fine Fase 1.

📍 [Indice Percorso Lab](../../04_governance_learning/03_esami_e_carriera/README.md) | **→ Prossimo: [FASE 1: Preparazione OS](./GUIDA_FASE1_PREPARAZIONE_OS.md)**
