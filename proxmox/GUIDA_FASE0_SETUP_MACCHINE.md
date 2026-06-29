# FASE 0: Setup delle Macchine (Proxmox VE + Oracle Linux 8.10)

> **Questa fase va completata PRIMA di tutto il resto.** Qui creiamo le VM nell'hypervisor Proxmox per il DNS, il RAC primario e il RAC standby.
> **Basato su**: Esperienza architetturale Enterprise per installazioni bare-metal, adattato per una configurazione a singolo nodo Proxmox con Storage Locale.

## Obiettivo operativo

Preparare un laboratorio Proxmox riproducibile di grado Enterprise per un CDB RAC primary `RACDB`, una PDB applicativa `RACDBPDB`, uno standby fisico RAC `RACDB_STBY` e gli Observer FSFO opzionali. Questa guida usa una base OS moderna, **Oracle Linux 8.10**, e sfrutta **ASMLib v3**.

## Procedura operativa

Completa in ordine DNS, reti Linux Bridge, VM `rac1`, storage `/u01`, dischi ASM e Golden Image. In questa fase gli snapshot sono ammessi solo per VM spente e prima della creazione di Grid Infrastructure o database.

## Validazione finale

Prima di passare alla Fase 1 verifica DNS, piano IP, mount `/u01`, mappa dei dischi ASM e presenza della Golden Image pre-Grid.

## Troubleshooting rapido

Se un device o un nome DNS non coincide con la guida, fermati e correggi l'inventario prima di clonare le VM. Non tentare fix sui dischi ASM finché non hai identificato con certezza device, dimensione e VM proprietaria.

### Vista d'Insieme del Lab Proxmox

```text
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
|   Dischi Condivisi su Storage Locale (RAW + shared=1 + No Cache):               |
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

| Macchina | Tipo | RAM | CPU (Type=Host) | Disco OS | Disco /u01 | Dischi ASM |
|---|---|---|---|---|---|---|
| `dnsnode` | VM Proxmox | **1 GB** | **1 vCPU** | 15 GB | — | — |
| `rac1` | VM Proxmox | **8-12 GB** | **4 vCPU** | 50 GB | 100 GB | 5 condivisi |
| `rac2` | VM (clone di rac1) | **8-12 GB** | **4 vCPU** | 50 GB | 100 GB | stessi di rac1 |
| `racstby1` | VM Proxmox | **8-12 GB** | **4 vCPU** | 50 GB | 100 GB | 5 condivisi (propri) |
| `racstby2` | VM (clone di racstby1) | **8-12 GB** | **4 vCPU** | 50 GB | 100 GB | stessi di racstby1 |
| `observer1` | VM Linux | **2 GB** | **1 vCPU** | 20 GB | — | — |
| `observer2` | VM opzionale | **2 GB** | **1 vCPU** | 20 GB | — | — |

> **Perché CPU "Host"?** Proxmox di default maschera le CPU come "kvm64" per massima compatibilità nelle migrazioni. Per un server Database, usare "Host" espone le istruzioni crittografiche (AES-NI) del processore fisico alla VM, riducendo drasticamente il carico CPU per le connessioni crittografate (TDE, SSH, ecc.).
>
> **Perché un DNS separato?** Oracle Base consiglia una VM DNS dedicata con **Dnsmasq** (alternativa leggera a BIND). Così il DNS non si ferma quando riavvii i nodi RAC, e SCAN funziona sempre. Costa solo 1 GB.
>
> **Perché il disco /u01 separato?** Il software Oracle (Grid + DB) va installato su un disco a parte. Separa binari dal SO.

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
| `observer1` | FSFO Observer dedicato | 192.168.56.121 | — | Creato in Fase 4B |
| `observer2` | FSFO Backup | 192.168.56.122 | — | Opzionale |

### Software da Caricare PRIMA di Iniziare

Scarica la ISO di **Oracle Linux 8.10** (`OracleLinux-R8-U10-Server-x86_64-dvd.iso`) e caricala nello storage ISO del tuo nodo Proxmox (solitamente `local` -> ISO Images -> Upload).
Scarica e tieni pronti i file zip di Grid 19c e Database 19c (Linux x86_64).

### 🔧 Patch Oracle — Come Trovarli (My Oracle Support)

Compila l'inventario con la RU approvata prima di iniziare. Gli ID cambiano ogni trimestre: non copiare ID patch da una vecchia esecuzione.

| Campo | Valore approvato |
|---|---|
| Versione OPatch minima richiesta | `<OPATCH_VERSION>` |
| Combo patch GI/DB RU + OJVM | `<COMBO_PATCH_ID>` |
| Grid/Database RU | `<RU_PATCH_ID>` |
| OJVM RU | `<OJVM_PATCH_ID>` |
| Data approvazione e change | `<CHANGE_ID> - <YYYY-MM-DD>` |

> **Come trovare l'ultima RU**: Vai su MOS (Doc ID **2118136.2**) → tabella con TUTTE le Release Update per ogni versione.

---

## 0.2 Configurazione Reti su Proxmox (UNA SOLA VOLTA)

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

> **Perché 3 reti?** La #1 è il traffico alla LAN del cluster (pubblica), la #2 è l'interconnect privato del primario, la #3 è l'interconnect privato dello standby. In produzione sarebbero su switch fisici o VLAN separate.

---

## 0.3 Creare la VM DNS (PRIMA DI TUTTO)

> **Ordine di build**: DNS → rac1 → cloni.

### Creazione VM `dnsnode` in Proxmox
1. Clicca **Create VM** in alto a destra.
2. **General:** Name: `dnsnode`
3. **OS:** Usa file ISO -> Seleziona `OracleLinux-R8-U10-Server-x86_64-dvd.iso`
4. **System:** Machine `q35`, SCSI Controller **VirtIO SCSI Single**.
5. **Disks:** Storage `local-lvm` (o tuo pool), Disk size: **15 GiB**, Format: **Raw**, spunta **Discard**.
6. **CPU:** 1 Core, Type: **Host**.
7. **Memory:** 1024 MiB. Disattiva il "Ballooning".
8. **Network:** Seleziona `vmbr0` (Rete NAT/Internet del tuo server fisico). Modello: **VirtIO**.

**Subito dopo la creazione**, vai nelle impostazioni **Hardware** di `dnsnode` e aggiungi una **seconda scheda di rete** collegata a `vmbr1` (la Rete Pubblica).

### Installazione OS 8.10 e IP
Avvia la VM e installa Oracle Linux 8.10 (Minimal Install, no GUI necessaria).
Dalla console VNC di Proxmox, loggati come `root` ed esegui:
```bash
nmtui
```
- Seleziona **Edit a connection**.
- **ATTIVA IL NAT (Internet)**: Sulla prima scheda (vmbr0), vai su Edit, assicurati che sia in DHCP (Auto) e spunta **"Automatically connect"**.
- **CONFIGURA L'IP STATICO**: Sulla seconda scheda (vmbr1), vai su Edit. Cambia IPv4 Configuration in **Manual**. Inserisci l'indirizzo `192.168.56.50/24` (lascia vuoto il gateway). Spunta **"Automatically connect"**.
- Riavvia il network: `systemctl restart NetworkManager`.
- **TASSATIVO**: Verifica di avere Internet: `ping -c 2 google.com`.

### Connettiti con MobaXterm (Copia-Incolla)

> 🛑 **ALT! FERMATI! SEI ANCORA NELLA CONSOLE DI PROXMOX?**
>
> **TUTTI I COMANDI DA QUI IN POI VANNO ESEGUITI VIA MOBAXTERM!**
> Ora che la macchina ha l'IP `192.168.56.50` assegnato via `nmtui`, apri **MobaXterm** dal tuo PC Windows e crea una sessione SSH verso quell'IP. Ti servirà per fare copia-incolla del file hosts!

### Configurare Dnsmasq (su OL 8.10)

Una volta dentro MobaXterm come utente `root`, incolla questi blocchi:

```bash
# == ESEGUI COME ROOT (via MobaXterm) ==

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

# 2. Installa Dnsmasq e tools di rete
dnf install -y dnsmasq bind-utils

# 3. Configura Dnsmasq
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

# 4. Abilita e avvia
systemctl enable dnsmasq
systemctl start dnsmasq

# 5. Apri porta DNS sul firewall
firewall-cmd --permanent --add-service=dns
firewall-cmd --reload

# 6. TESTARE DNSMASQ (Fondamentale!)
nslookup rac1.localdomain 192.168.56.50
nslookup rac-scan.localdomain 192.168.56.50      # ← DEVE ritornare 3 IP!
nslookup racstby-scan.localdomain 192.168.56.50  # ← DEVE ritornare 3 IP!
nslookup google.com 192.168.56.50                # ← DEVE ritornare l'IP di Google!
```

> 📸 **SNAP-DNS**: Quando Dnsmasq funziona, spegni la VM e fai uno snapshot Proxmox!

---

## 0.4 Creazione VM `rac1` (RAC Primario)

### Configurazione Base
1. **Create VM** -> Name: `rac1`
2. **OS:** ISO `OracleLinux-R8-U10-Server-x86_64-dvd.iso`
3. **System:** Machine `q35`, Qemu Agent `Yes`, SCSI Controller `VirtIO SCSI Single`.
4. **CPU:** 4 Cores, Type: **Host** (Fondamentale) ed **Enable NUMA** spuntato.
5. **Memory:** 8192 MiB (o 12288 MiB), **Disattiva Ballooning**.

### Archiviazione — OS + Disco `/u01`
Nella tab **Disks**:
- **Disco 0 (OS):** `50 GiB`, Format `Raw`, spunta **Discard**.
- Clicca **Add -> Hard Disk** per aggiungere il **Disco /u01**: `100 GiB`, Format `Raw`, spunta **Discard**.

### Rete (3 schede di rete)
Durante la creazione, lascia la prima scheda su `vmbr0` (Internet). Subito dopo la creazione, vai in **Hardware** -> **Add** -> **Network Device** e crea:
- **Scheda 2:** `vmbr1` (Rete Pubblica del Cluster)
- **Scheda 3:** `vmbr2` (Interconnect Privato Primario)

> **Perché 3 NIC?** Oracle Base usa questo approccio: NIC1=NAT (per dnf/update via vmbr0), NIC2=Pubblica cluster (SCAN, VIP via vmbr1), NIC3=Privata interconnect (Cache Fusion via vmbr2). Questo è più pulito e ricalca gli standard Enterprise.

---

## 0.5 Creazione Dischi Condivisi ASM (Il "Segreto" di Proxmox)

> 🏗️ **Panoramica**: Creeremo 5 dischi virtuali che saranno **condivisi** tra `rac1` e `rac2`. Simuleranno una LUN SAN: entrambi i nodi li vedranno e Oracle ASM li gestirà. 

### Il Dilemma: Thin Provisioning vs RAW Thick Provisioning
In Proxmox, i dischi possono essere Thin-provisioned (come LVM-Thin o ZFS) o Raw (pre-allocati o mappati 1:1 sui blocchi).
Per il disco OS (50GB) e `/u01` (100GB) l'allocazione Thin va benissimo: occupano solo lo spazio usato.
Per i dischi ASM **condivisi**, dobbiamo disattivare le cache intermedie dell'hypervisor e segnalare a QEMU che il disco subisce scritture concorrenti.

### Step 1: Crea i dischi ASM in Proxmox
Vai in **rac1** -> **Hardware** -> **Add** -> **Hard Disk**. Crea 5 dischi.
**TASSATIVO per i dischi ASM:**
- **Cache:** `No cache` (o `Direct sync`). ASM **esige** il controllo diretto sui flush disk.
- **Discard:** `Yes`
- **Advanced -> iothread:** `Spuntato` (assegna un thread fisico per l'I/O).
- **No Backup:** `Spuntato` (evita di bloccare i dischi ASM durante i backup Proxmox).

| # | Dimensione | Disk Group ASM | Ruolo |
|---|---|---|---|
| 1 | **2 GB** | +CRS | OCR (Oracle Cluster Registry) |
| 2 | **2 GB** | +CRS | Voting Disk |
| 3 | **2 GB** | +CRS | Voting Disk |
| 4 | **20 GB** | +DATA | Datafile del Database |
| 5 | **15 GB** | +RECO | Recovery / Fast Recovery Area |

> 💡 **Oracle Best Practices: Perché 3 dischi da 2 GB per il CRS?**
> Il Cluster Ready Services (CRS) salva lo stato del cluster nel *Voting Disk*. Per evitare lo split-brain (quando i nodi non comunicano e cercano di scriversi sopra), Oracle usa un sistema a maggioranza (Quorum): `(N/2) + 1`. 
> Con **3 dischi**, per avere la maggioranza servono almeno 2 dischi attivi. Se 1 disco si rompe, il cluster sopravvive. Inoltre, 2 GB garantiscono spazio sufficiente per gestire gli upgrade di Grid Infrastructure.

### Step 2: Rendi i dischi Condivisibili (CRITICO! Da CLI Proxmox)

L'interfaccia web di Proxmox **non ha** un flag grafico "Shareable" per dischi su storage locale. 
Apri la shell dell'host Proxmox (via Web GUI o SSH) e modifica il file della VM (es. ID `101`):

```bash
nano /etc/pve/qemu-server/101.conf
```

Aggiungi il flag `,shared=1,iothread=1` alla fine dei 5 dischi appena aggiunti:

```text
scsi2: local-lvm:vm-101-disk-2,cache=none,discard=on,size=2G,shared=1,iothread=1
scsi3: local-lvm:vm-101-disk-3,cache=none,discard=on,size=2G,shared=1,iothread=1
scsi4: local-lvm:vm-101-disk-4,cache=none,discard=on,size=2G,shared=1,iothread=1
scsi5: local-lvm:vm-101-disk-5,cache=none,discard=on,size=20G,shared=1,iothread=1
scsi6: local-lvm:vm-101-disk-6,cache=none,discard=on,size=15G,shared=1,iothread=1
```

*(Se ometti `shared=1`, appena accendi `rac2` corromperai il filesystem ASM o avrai dei lock kernel-level che congeleranno la VM).*

---

## 0.6 Installazione Oracle Linux 8.10 su `rac1`

1. Avvia `rac1` e procedi all'installazione dal boot menu.
2. In **Software Selection**, scegli **Server with GUI** (Oracle Installer richiede X11/Java).

### Installation Destination (Selezione Disco)

> 🛑 **ATTENZIONE — IL CONCETTO PIÙ IMPORTANTE DI QUESTA SEZIONE**
>
> L'installer mostrerà 7 dischi!
>
> | Disco | Dimensione | Ruolo | Quando si configura |
> |---|---|---|---|
> | **sda** (50 GB) | Sistema Operativo | `/boot`, `swap`, `/` | **ORA** — durante l'installazione |
> | **sdb** (100 GB) | Binari Oracle (`/u01`) | Grid + Database | **DOPO** — al primo boot (Sezione 0.7) |
> | **sdc...sdg** | Dischi ASM | Storage Condiviso | **DOPO** — (Sezione 0.8) |
>
> **Devi selezionare SOLO il disco da 50 GB (`sda`).** Assicurati che solo `sda` abbia il segno di spunta nero. Se tocchi gli altri, li formatterai accidentalmente.

### Partizionamento Manuale del Disco OS (Step-by-Step Visivo)

Seleziona **Custom** sotto Storage Configuration e clicca **Done**.
Lascia il dropdown in alto su **LVM**. Crea le partizioni cliccando sul pulsante `+` in basso:

1. **Partizione 1:** Mount Point: `/boot`, Capacity: `1024 MiB`. (Premi Add). Cambia il file system in `xfs`.
2. **Partizione 2:** Mount Point: `swap`, Capacity: `8192 MiB`. (Premi Add).
3. **Partizione 3:** Mount Point: `/`, Capacity: *(lascia vuoto per usare il resto)*. (Premi Add). Cambia file system in `xfs`.

| Mount Point | Size | File System | Device Type | Note |
|---|---|---|---|---|
| `/boot` | **1024 MiB** | xfs | Standard Partition (sda1) | Kernel e bootloader |
| `/` | **~41 GiB** | xfs | LVM (ol-root) | Sistema operativo |
| `swap` | **8192 MiB** | swap | LVM (ol-swap) | Area di swap |

> 💡 **Oracle Best Practices: Quanta Swap serve davvero?**
> Assegnare 8 GB di swap è la raccomandazione UFFICIALE di Oracle per un server con 8 GB di RAM. La matrice per Oracle 19c prevede:
> - **RAM < 2 GB**: Swap = 1.5x RAM
> - **RAM 2 GB - 16 GB**: Swap = uguale alla RAM (es. 8GB -> 8GB Swap)
> - **RAM > 16 GB**: Swap = 16 GB fissi

### Altre Impostazioni dell'Installer
- **Network & Host Name**: Attiva tutte le interfacce e imposta l'Hostname a `rac1`. Non impostare IP qui.
- **Kdump**: Disabilitalo (risparmi RAM in caso di kernel panic).
- **Root Password**: `oracle` (per il lab).
- Clicca **Begin Installation**. A fine installazione, Reboot.

---

## 0.7 Preparare il Disco `/u01` (Binari Oracle — 100 GB)

> 🏗️ **IL CONCETTO: Perché un Disco Separato per `/u01`?**
>
> ```text
> +-----------------------------------------------------------------------+
> |                    ARCHITETTURA DISCHI DI rac1                       |
> +-----------------------------+----------------------------------------+
> |  DISCO 1: sda (50 GB)      |  DISCO 2: sdb (100 GB)               |
> |  -------------------------  |  -----------------------------------  |
> |  /boot   → Kernel          |  /u01    → Software Oracle           |
> |  swap    → Swap            |           +-- Grid Infrastructure    |
> |  /       → OS              |           +-- Database 19c           |
> |                             |           +-- OPatch & Patch         |
> |  Gestito dall'installer     |                                      |
> |  (FATTO in Sez 0.6)         |  Gestito MANUALMENTE in Sez 0.7      |
> +-----------------------------+----------------------------------------+
> |  PERCHÉ SEPARARE?                                                   |
> |  1. Se il SO si corrompe → reinstalli l'OS senza perdere Oracle    |
> |  2. Se /u01 si riempie → il SO continua a funzionare              |
> |  3. Backup separati: salvi /u01 senza portarti 50GB di OS          |
> |  4. Requisito della Oracle Flexible Architecture (OFA)             |
> +---------------------------------------------------------------------+
> ```

Loggati come `root` via console o MobaXterm.

### Step 1: Identifica il disco corretto
```bash
lsblk
```
Assicurati che `sdb` sia il disco vuoto da 100GB senza partizioni.

### Step 2: Partiziona il disco
Usa `fdisk` in modo interattivo:
```bash
fdisk /dev/sdb
```
*(Sequenza: `n` [Nuova], `p` [Primaria], `1` [Numero 1], `Invio` [Default], `Invio` [Default], `w` [Scrivi e salva])*

### Step 3: Formatta in XFS
```bash
mkfs.xfs -f /dev/sdb1
```

### Step 4: Crea la cartella di mount
```bash
mkdir -p /u01
```

### Step 5: Montaggio Permanente (fstab)

> 💡 **Tip da DBA: Come si legge il file fstab e perché usiamo 0 0?**
> La riga in fstab ha 6 campi: `<Device>  <Mount>  <FS>  <Opzioni>  <Dump>  <Fsck Pass>`
> Nel nostro caso usiamo `0 0` alla fine.
> - **Campo 5 (Dump)** = 0: Disabilita il backup dell'utility legacy `dump` (su XFS si usa xfsdump, quindi il dump legacy è inutile).
> - **Campo 6 (Pass)** = 0: Indica a `fsck` di non scansionare il disco al boot. XFS gestisce la consistenza internamente con il journaling, non ha bisogno di fsck al boot!

```bash
UUID=$(blkid -s UUID -o value /dev/sdb1)
echo "UUID=${UUID}  /u01  xfs  defaults 0 0" >> /etc/fstab
```

### Step 6: Monta e Verifica
```bash
mount -a
df -h | grep u01
# Deve ritornare /dev/sdb1  100G  33M  100G  1% /u01
```

---

## 0.8 Configurare ASMLib v3 per i Dischi ASM

ASMLib in Oracle Linux 8.10 è pienamente supportato, ma i pacchetti e i comandi si differenziano rispetto al vecchio track OL7.

### 1. Partizionamento dei dischi (== ESEGUI SOLO SU rac1 ==)

Invece di usare script automatici "ciechi", mapperemo logicamente i dischi ai loro scopi ASM (CRS, DATA, RECO).

> 💡 **Mapping Dischi Fisici → Ruoli ASM (Lab)**:
> - `sdc` (2GB) -> CRS Disk 1
> - `sdd` (2GB) -> CRS Disk 2
> - `sde` (2GB) -> CRS Disk 3
> - `sdf` (20GB) -> DATA 
> - `sdg` (15GB) -> RECO 

**Metodo Veloce (Script Automatico Sicuro)**
> ⚠️ **ATTENZIONE TASSATIVA ALLE LETTERE DEI DISCHI!**
> Esegui `lsblk` per assicurarti che `sdc, sdd, sde, sdf, sdg` siano i 5 dischi RAW.

```bash
for disk in /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg; do
  echo "Partizionando $disk..."
  echo -e "n\np\n1\n\n\nw" | fdisk $disk
done
partprobe
```

### 2. Installazione e Configurazione ASMLib

Su Oracle Linux 8, la Oracle preinstall RPM e ASMLib sono integrati nei repository ufficiali (UEKR6/7 e ol8_addons). Non devi scaricare nulla dal sito Oracle!

```bash
# 1. Installa il pacchetto ufficiale che predispone kernel params, utenti (oracle, grid) e librerie
dnf install -y oracle-database-preinstall-19c

# 2. Installa ASMLib
dnf install -y oracleasm-support oracleasmlib
```

> ⚠️ **ATTENZIONE: 3 pacchetti, non 2!** Come su OL7, ASMLib ha bisogno del modulo kernel (`kmod-oracleasm` integrato nell'UEK di OL8), il tool da riga di comando (`oracleasm-support`) e la libreria API usata dall'installer Grid (`oracleasmlib`). Se dimentichi `oracleasmlib`, l'installer Grid mostrerà la lista dischi vuota!

```bash
# 3. Configura ASMLib
oracleasm configure -i
# Rispondi:
# Default user: grid
# Default group: asmadmin
# Start on boot: y
# Scan on boot: y

# 4. Inizializza il modulo
oracleasm init
```

### 3. Timbratura dei Dischi
```bash
oracleasm createdisk CRS1 /dev/sdc1
oracleasm createdisk CRS2 /dev/sdd1
oracleasm createdisk CRS3 /dev/sde1
oracleasm createdisk DATA /dev/sdf1
oracleasm createdisk RECO /dev/sdg1

oracleasm scandisks
oracleasm listdisks
```

> 💡 **Nota per il Clone (rac2):** Quando cloneremo `rac1` in `rac2` a fine Fase 1, `rac2` riceverà automaticamente la configurazione di ASMLib. Non dovrai partizionare o etichettare nulla! Basterà dare un `oracleasm scandisks` e `rac2` scoprirà i dischi formattati da `rac1`.

---

## 0.9 Clonazione `rac1` → `rac2`

**NON clonare adesso!** Prima completa tutta la **Fase 1** (tuning OS avanzato, SSH equivalence, sync del tempo) su `rac1`. Le istruzioni dettagliate per clonare in modo sicuro si trovano alla fine della Fase 1 (nella Sezione 1.14).

---

## 0.10 Preparazione Dischi per lo Standby (SOLO DISCHI!)

Per costruire il nostro Data Guard, abbiamo bisogno di uno storage separato per il secondo cluster. 

> 🛑 **ATTENZIONE:** **NON creare le macchine virtuali** `racstby1` o `racstby2`. Le creerai in 30 secondi clonando la "Golden Image" di `rac1` alla fine della Fase 1. Ora devi solo preparare lo storage fisico in Proxmox.

### 💡 Il Trucco del DBA: La Golden Image
Reinstallare il sistema operativo e rifare tutto il tuning per i nodi standby è inutile e rischioso. Alla fine della Fase 1, dal tuo `rac1` spento, eseguirai queste clonazioni in cascata in Proxmox (generando nuovi indirizzi MAC):
1. `rac1` -> Clona in `rac2`.
2. `rac1` -> Clona in `racstby1`.
3. `rac1` -> Clona in `racstby2` (oppure clona `racstby1` in `racstby2`).

**Cosa dovrai fare su Proxmox per lo standby?**
Esattamente come per `rac1`, dovrai creare 5 nuovi dischi (`asm-stby-crs1`, `asm-stby-data`, ecc.) in Proxmox, assegnarli a `racstby1` e impostare il flag `shared=1` nel file conf di Proxmox.

---

## 0.11 Come Connettersi alle VM (MobaXterm)

> 💡 **IMPORTANTE**: Da questo momento in poi, **NON** usare la console VNC di Proxmox per lavorare. Usa un client SSH professionale come **MobaXterm** dal tuo PC. Perché?
> 1. Puoi fare copia-incolla nativo.
> 2. Supporta il multi-tabling (apri `rac1` e `rac2` affiancati).
> 3. **FONDAMENTALE**: Ha un server X11 integrato per farti vedere le finestre grafiche (X-Forwarding) per l'installer di Oracle Grid 19c. Senza questo, l'installer non parte.

### Configurare le Sessioni in MobaXterm
1. Scarica e apri MobaXterm (versione Home/Portable).
2. Clicca in alto a sinistra su **Session** -> **SSH**.
3. **Remote host**: Inserisci l'IP pubblico (vmbr1). Es. `192.168.56.101` per `rac1`.
4. **Specify username**: Spunta la casella e scrivi `root` (o `oracle`).
5. **Advanced SSH settings**:
   - Assicurati che **X11-Forwarding** sia SPUNTATO ✅.
6. Clicca **OK**. Inserisci la tua pwd di root.

---

## 0.12 Prossimi Passi: Il Cuore del Sistema Operativo

Hai completato il setup hardware/hypervisor e installato Oracle Linux con le partizioni corrette. Tutta la configurazione del sistema operativo (utenti, kernel parameters, Chrony, HugePages) è centralizzata nella **[FASE 1](./GUIDA_FASE1_PREPARAZIONE_OS.md)**. 
Eseguirai quella fase **SOLO su `rac1`**; diventerà la tua **Golden Image** che clonerai per creare tutti gli altri nodi.

📍 [Indice Percorso Lab](README.md) | **→ Prossimo: [FASE 1: Preparazione OS](GUIDA_FASE1_PREPARAZIONE_OS.md)**
