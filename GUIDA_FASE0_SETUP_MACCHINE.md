# FASE 0: Setup delle Macchine (VirtualBox + PC Fisico)

> **Questa fase va completata PRIMA di tutto il resto.** Qui creiamo le macchine virtuali in VirtualBox per il RAC primario, il RAC standby e il target GoldenGate. Spiega anche come preparare il PC fisico con Oracle Linux 8.10 (se applicabile).

### Vista d'Insieme del Lab VirtualBox

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                        IL TUO PC (HOST VIRTUALBOX)                           ║
║                                                                               ║
║   ┌─────────────────────────────────────────────────────────────────────┐     ║
║   │                  Rete Bridged (192.168.1.0/24)                      │     ║
║   │              Collegata alla tua scheda Wi-Fi/Ethernet               │     ║
║   └──┬────────┬────────┬──────────┬──────────────────────────────────────┘     ║
║      │        │        │          │                                           ║
║   ┌──┴──┐  ┌──┴──┐  ┌──┴──┐   ┌──┴──┐                                       ║
║   │rac1 │  │rac2 │  │stby1│   │stby2│   dbtarget + GG sono su cloud/         ║
║   │ .101│  │ .102│  │ .201│   │ .202│   altra macchina (non su questo PC)    ║
║   │8GB  │  │8GB  │  │8GB  │   │8GB  │                                       ║
║   │4CPU │  │4CPU │  │4CPU │   │4CPU │                                       ║
║   └──┬──┘  └──┬──┘  └──┬──┘   └──┬──┘                                       ║
║      │        │        │         │                                           ║
║   ┌──┴────────┴──┐  ┌──┴─────────┴──┐                                       ║
║   │  Host-Only   │  │  Host-Only    │    (Reti Private Separate)             ║
║   │  10.10.10.x  │  │  10.10.10.x   │                                       ║
║   │  (Intercon.) │  │  (Intercon.)  │                                       ║
║   └──────────────┘  └───────────────┘                                       ║
║                                                                               ║
║   Dischi Condivisi (Shareable VDI):                                          ║
║   ┌──────────────────┐    ┌───────────────────┐                              ║
║   │ rac1 + rac2      │    │ racstby1 + racstby2│                              ║
║   │ asm_crs.vdi  5GB │    │ asm_stby_crs  5GB │                              ║
║   │ asm_data.vdi 20GB│    │ asm_stby_data 20GB│                              ║
║   │ asm_fra.vdi  15GB│    │ asm_stby_fra  15GB│                              ║
║   └──────────────────┘    └───────────────────┘                              ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

> **Leggi il diagramma**: Ogni VM ha 2 schede di rete. La rete Bridged (sopra) le collega tutte alla tua LAN di casa. La rete Host-Only (sotto) è privata e isolata — serve SOLO per il traffico Cache Fusion tra i nodi RAC dello stesso cluster.

## 0.1 Cosa Ti Serve (Requisiti Hardware)

| Macchina | Tipo | RAM | CPU | Disco OS | Dischi ASM |
|---|---|---|---|---|---|
| `rac1` | VM VirtualBox | **8 GB** | **4 vCPU** | 50 GB | 3 condivisi |
| `rac2` | VM VirtualBox (clone di rac1) | **8 GB** | **4 vCPU** | 50 GB | stessi di rac1 |
| `racstby1` | VM VirtualBox | **8 GB** | **4 vCPU** | 50 GB | 3 condivisi (propri) |
| `racstby2` | VM VirtualBox (clone di racstby1) | **8 GB** | **4 vCPU** | 50 GB | stessi di racstby1 |

> **⚠️ Note**: `dbtarget` e GoldenGate girano su **cloud OCI** o altra macchina, non su questo PC.
>
> **PC host consigliato**: 32 GB RAM, 8+ core, SSD. Con 4 VM × 8 GB = 32 GB allocati, il sistema regge perché le VM non usano tutta la RAM contemporaneamente (Oracle usa ~4-5 GB effettivi per lab).

### Software da Scaricare PRIMA di Iniziare

| Software | File | Link | Dimensione |
|---|---|---|---|
| Oracle Linux 7.9 ISO | `OracleLinux-R7-U9-Server-x86_64-dvd.iso` | [yum.oracle.com](https://yum.oracle.com/oracle-linux-isos.html) | ~4.6 GB |
| Grid Infrastructure 19c | `LINUX.X64_193000_grid_home.zip` | [edelivery.oracle.com](https://edelivery.oracle.com) | ~2.7 GB |
| Database 19c | `LINUX.X64_193000_db_home.zip` | [edelivery.oracle.com](https://edelivery.oracle.com) | ~2.9 GB |
| GoldenGate 19c/21c | `fbo_ggs_Linux_x64_Oracle_shiphome.zip` | [edelivery.oracle.com](https://edelivery.oracle.com) | ~500 MB |
| VirtualBox | Ultimo | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) | ~100 MB |

### 🔧 Patch Oracle — Come Trovarli (My Oracle Support)

I patch si scaricano da [My Oracle Support (MOS)](https://support.oracle.com). Servono:

| Patch | MOS Patch ID | Come Trovarlo | Note |
|---|---|---|---|
| **OPatch** (utility) | **6880880** | [Scarica qui](https://updates.oracle.com/Orion/PatchDetails/process_form?patch_num=6880880) | Aggiorna SEMPRE prima di ogni RU |
| **Release Update (RU)** | Cambia ogni trimestre | MOS → Patches & Updates → cerca `"Database Release Update 19"` | Ogni 3 mesi esce una nuova RU |
| **OJVM Patch** | Accompagna la RU | MOS → cerca `"OJVM Release Update 19"` | Stesso trimestre della RU |
| **Grid RU** | Accompagna la RU | Cerca `"GI Release Update 19"` | Stesso numero della DB RU |

> **Come trovare l'ultima RU**: Vai su MOS (Doc ID **2118136.2**) → "Oracle Database — Critical Patch Update and Release Update". Trovi la tabella con TUTTE le Release Update disponibili per ogni versione.
>
> **Come cercare un patch**: MOS → scheda "Patches & Updates" → digita il numero del patch nella barra di ricerca → seleziona piattaforma `Linux x86-64` → scarica.
>
> **⚡ Scarica tutto prima di iniziare.** Non c'è niente di peggio che arrivare a metà installazione e scoprire che manca un file da 3 GB.

### 📸 Immagini di Riferimento Setup VirtualBox

> Le immagini seguenti mostrano le configurazioni VirtualBox da replicare:

![Impostazioni VM — 8 GB RAM + 4 CPU](./images/virtualbox_vm_settings.png)

![Configurazione Rete — Bridged + Host-Only](./images/virtualbox_network_config.png)

![Storage — Dischi condivisi ASM](./images/virtualbox_storage_disks.png)

---

## 0.2 Configurazione Rete in VirtualBox (UNA SOLA VOLTA)

Prima di creare qualsiasi VM, configura le reti a livello globale.

### Rete Host-Only per Interconnect RAC Primario

1. Apri VirtualBox → **File > Strumenti > Gestore di Rete (Network Manager)**
2. Tab **Reti Host-only (Schede solo host)**
3. Clicca **Crea**
4. Configura:
   - Nome: `VirtualBox Host-Only Ethernet Adapter` (verrà assegnato automaticamente)
   - Indirizzo IPv4 dell'adattatore: `10.10.10.254`
   - Maschera: `255.255.255.0`
   - **DHCP Server**: ❌ **DISABILITATO** (usiamo IP statici!)

### Rete Host-Only per Interconnect Standby (separata)

5. Clicca **Crea** di nuovo per una seconda rete host-only
6. Configura:
   - Indirizzo IPv4: `10.10.20.254`
   - Maschera: `255.255.255.0`
   - **DHCP**: ❌ Disabilitato

> **Perché due reti host-only separate?** L'interconnect del primario e dello standby devono essere isolati. In produzione sarebbero su switch fisici diversi.

---

## 0.3 Creazione VM `rac1` (RAC Primario — Nodo 1)

### Step-by-step in VirtualBox

1. Clicca **Nuova** (New)
2. **Nome e Sistema Operativo**:
   - Nome: `rac1`
   - Cartella: Lascia il default o scegli un disco capiente
   - Tipo: **Linux**
   - Versione: **Oracle (64-bit)**
3. **Memoria**: `4096 MB` (4 GB)
   - Se hai 32 GB di RAM totali, puoi dare 6-8 GB per performance migliori
4. **Disco Rigido**:
   - Seleziona **Crea un disco virtuale adesso**
   - Tipo: **VDI**
   - Allocazione: **Allocato Dinamicamente** (risparmi spazio)
   - Dimensione: `50 GB`
5. Clicca **Crea**

### Configurazione Hardware

Seleziona `rac1` → **Impostazioni** (Settings):

#### Sistema > Processore
- **CPU**: `2`
- ✅ Abilita **PAE/NX**

#### Sistema > Scheda Madre
- Ordine di avvio: ❌ Togli **Floppy**
- Chipset: **ICH9** (consigliato per Oracle Linux)

#### Rete (FONDAMENTALE — 2 schede)

**Scheda 1 — Rete Pubblica (per comunicare con il mondo esterno)**:
- ✅ Abilita scheda di rete
- Connessa a: **Scheda con bridge (Bridged Adapter)**
- Nome: Seleziona la tua **scheda fisica** (Wi-Fi o Ethernet)
- Avanzate → Tipo: **Intel PRO/1000 MT Desktop**
- Avanzate → Modalità promiscua: **Permetti tutto (Allow All)**

> **Perché Bridged?** La VM ottiene un IP sulla tua rete LAN fisica (192.168.1.x). Così il PC fisico standby può comunicare direttamente con le VM.

**Scheda 2 — Rete Privata (Interconnect RAC)**:
- ✅ Abilita scheda di rete
- Connessa a: **Scheda solo host (Host-only Adapter)**
- Nome: Seleziona la rete host-only creata al punto 0.2 (10.10.10.254)
- Avanzate → Tipo: **Intel PRO/1000 MT Desktop**
- Avanzate → Modalità promiscua: **Permetti tutto**

> **Perché Host-Only?** L'interconnect è una rete PRIVATA e VELOCE tra i nodi del cluster. Non deve essere raggiungibile dall'esterno.

#### Archiviazione (Storage) — ISO di Installazione

1. In **Controller: IDE**, clicca sull'icona del disco ottico (vuota)
2. Clicca l'icona del CD a destra → **Scegli un file disco**
3. Seleziona la ISO `OracleLinux-R7-U9-Server-x86_64-dvd.iso`

---

## 0.4 Creazione Dischi Condivisi ASM (per RAC Primario)

Questi dischi saranno usati da **ENTRAMBI** i nodi `rac1` e `rac2` per lo storage condiviso ASM.

### Crea i dischi dal Virtual Media Manager

1. VirtualBox → **File > Gestore Supporti Virtuali (Virtual Media Manager)** (oppure `Ctrl+D`)
2. Clicca **Crea** (o "Add" → "Create")
3. Crea 3 dischi con queste caratteristiche:

| Disco | Dimensione | Uso | Tipo |
|---|---|---|---|
| `asm_crs.vdi` | **5 GB** | OCR + Voting Disk | **Dimensione Fissa** |
| `asm_data.vdi` | **20 GB** | Datafile del database | **Dimensione Fissa** |
| `asm_fra.vdi` | **15 GB** | Fast Recovery Area | **Dimensione Fissa** |

> **Perché Dimensione Fissa?** VirtualBox non supporta la condivisione di dischi ad allocazione dinamica. Solo i dischi a dimensione fissa possono essere marcati come "Shareable".

### Rendi i dischi Condivisibili (CRITICO!)

4. Nel Virtual Media Manager, seleziona ogni disco ASM uno alla volta
5. Nella tab **Attributi** (o Properties):
   - Tipo: **Condivisibile (Shareable)** ✅
6. Clicca **Applica**
7. Ripeti per tutti e 3 i dischi

> **Perché Shareable?** Se non lo fai, VirtualBox blocca il disco quando `rac1` lo usa e `rac2` non può accedervi. In un RAC, entrambi i nodi devono leggere/scrivere sullo STESSO disco.

### Attacca i dischi a `rac1`

1. Seleziona `rac1` → **Impostazioni > Archiviazione**
2. Seleziona **Controller: SATA**
3. Clicca l'icona "Aggiungi disco rigido" (+)
4. Seleziona **Scegli un disco esistente** → Seleziona `asm_crs.vdi`
5. Ripeti per `asm_data.vdi` e `asm_fra.vdi`

---

## 0.5 Installazione Oracle Linux 7.9 su `rac1`

1. Avvia `rac1` (doppio click o Start)
2. Si avvia dalla ISO → Seleziona **Install Oracle Linux 7.9**

### Schermata di Installazione

**Lingua**: Italiano (o Inglese — consiglio Inglese per coerenza con i log)

**Software Selection**:
- Seleziona: **Server with GUI** (serve il GUI per l'installer Grid/DB!)
- Aggiungi:
  - ✅ Development Tools
  - ✅ Compatibility Libraries

> **Perché Server with GUI?** Gli installer Oracle (gridSetup.sh, runInstaller, dbca, netca, asmca) usano interfacce grafiche Java/X11. Senza GUI, devi usare i response file in silente — possibile ma molto più complesso.

**Installation Destination**:
- Seleziona il disco da 50 GB (sda)
- Partitioning: **Automatic** va bene, oppure manuale se vuoi più controllo:

| Mount Point | Size | Tipo |
|---|---|---|
| `/boot` | 1 GB | xfs |
| `/boot/efi` | 200 MB | vfat (solo se UEFI) |
| `swap` | 8 GB | swap |
| `/` | Resto (~41 GB) | xfs |

> **Perché 8 GB di swap?** Oracle richiede swap uguale alla RAM se hai < 16 GB di RAM. Con 4 GB di RAM → 4-8 GB di swap.

**Network & Host Name**:
- Attiva **ENTRAMBE** le interfacce (ON)
- Hostname: `rac1.oracleland.local`
- NON configurare gli IP qui (li facciamo dopo con più controllo)

**Kdump**: ❌ Disabilitalo (risparmi RAM)

**Security Policy**: Nessuna

**Date & Time**: Seleziona il tuo fuso orario

**Root Password**: Imposta una password (es. `oracle`)

**User Creation**: Non creare utenti ora (li creiamo con il preinstall package)

3. Clicca **Begin Installation** → Aspetta (~15-20 minuti)
4. Al termine → **Reboot**
5. Accetta la licenza al primo avvio

> 📸 **SNAPSHOT — "SNAP-01: OS Installato"**
> ```
> VBoxManage snapshot "rac1" take "SNAP-01_OS_Installato" --description "OL 7.9 installato, prima di configurare la rete"
> ```
> **Questo è il tuo punto di ritorno se sbagli la configurazione rete.**

---

## 0.6 Clonazione `rac1` → `rac2`

**NON clonare adesso!** Prima completa tutta la **Fase 1** (configurazione OS) su `rac1`, poi clona. Questo ti evita di ripetere 13 configurazioni due volte.

Il momento giusto per clonare è alla fine della Fase 1 (dopo SSH, utenti, pacchetti), **MA PRIMA** dell'installazione Grid. Ti verrà indicato con un messaggio specifico.

---

## 0.7 Setup Macchine Standby (`racstby1`, `racstby2`)

Le macchine standby hanno la **stessa identica configurazione** di `rac1`/`rac2`, con queste differenze:

| Parametro | Primario | Standby |
|---|---|---|
| Nomi VM | `rac1`, `rac2` | `racstby1`, `racstby2` |
| Rete Host-Only | Adattatore 1 (10.10.10.x) | Adattatore 2 (10.10.10.x) |
| Dischi ASM | `asm_crs.vdi`, `asm_data.vdi`, `asm_fra.vdi` | `asm_stby_crs.vdi`, `asm_stby_data.vdi`, `asm_stby_fra.vdi` |
| IP Pubbliche | 192.168.1.101-102 | 192.168.1.201-202 |
| IP Private | 10.10.10.1-2 | 10.10.10.11-12 |

> **IMPORTANTE**: I dischi ASM dello standby sono dischi **DIVERSI** da quelli del primario! Ogni cluster ha i propri dischi.

### Procedura

1. Crea `racstby1` esattamente come hai creato `rac1` (stessi passaggi 0.3-0.5)
2. Crea dischi ASM separati per lo standby: `asm_stby_crs.vdi`, `asm_stby_data.vdi`, `asm_stby_fra.vdi`
3. Marcali come Shareable
4. Installa Oracle Linux 7.9 su `racstby1`
5. Completa la Fase 1 su `racstby1`
6. Clona `racstby1` → `racstby2`

---

## 0.8 Setup Macchina Target GoldenGate (`dbtarget`)

Questa è la macchina più semplice: un singolo nodo, niente RAC, niente cluster.

### Creazione VM

1. **Nuova** in VirtualBox
2. Nome: `dbtarget`
3. Tipo: Linux → Oracle (64-bit)
4. RAM: `2048 MB` (2 GB)
5. Disco: 50 GB VDI, allocato dinamicamente
6. CPU: 1
7. **Rete**: Solo **1 scheda** → **Bridged Adapter** (non serve l'interconnect privato)
8. Installa Oracle Linux 7.9 (uguale a rac1)

> **Perché solo Bridged?** Il target non è in un cluster, non ha bisogno di interconnect. Deve solo essere raggiungibile dalla rete LAN.

---

## 0.9 Ordine di Lavoro Consigliato

```
Settimana 1:
  1. Scarica tutto il software (ISO, Grid, DB, GG)
  2. Crea e configura rac1 (Fase 0 + Fase 1)
  3. Clona rac1 → rac2 (aggiusta hostname/IP)
  4. Installa Grid e Database (Fase 2)
     📸 Snapshot dopo ogni operazione critica!

Settimana 2:
  5. Crea racstby1, racstby2, dbtarget (Fase 0)
  6. Configura OS su standby (Fase 1)
  7. Installa Grid e DB Software (solo SW, no DB) su standby
  8. RMAN Duplicate (Fase 3)

Settimana 3:
  9. Configura Data Guard + DGMGRL (Fase 4)
  10. Test switchover/failover
  11. Installa GoldenGate (Fase 5)
  12. Test end-to-end (Fase 6)
  13. Configura backup RMAN (Fase 7)
```

---

## 0.10 Best Practice da Oracle Base (Opzionale ma Consigliato)

> Le seguenti best practice sono estratte dalla guida [oracle-base.com — 19c RAC on VirtualBox](https://oracle-base.com/articles/19c/oracle-db-19c-rac-installation-on-oracle-linux-7-using-virtualbox) e dal repo [oraclebase/vagrant](https://github.com/oraclebase/vagrant/tree/master/rac/ol7_19). Integrarle rende il lab più vicino alla produzione.

### A) udev Rules per ASM Disks (Alternativa a oracleasm)

Il metodo **raccomandato da Oracle per 19c+** è usare le regole udev invece del driver `oracleasm`. Non richiede pacchetti aggiuntivi e funziona su tutte le distribuzioni.

```bash
# 1. Abilita scsi_id per VirtualBox
cat > /etc/scsi_id.config <<EOF
options=-g
EOF

# 2. Partiziona ogni disco condiviso (su UN SOLO nodo)
echo -e "n\np\n1\n\n\nw" | fdisk /dev/sdc   # CRS disk 1
echo -e "n\np\n1\n\n\nw" | fdisk /dev/sdd   # DATA disk
echo -e "n\np\n1\n\n\nw" | fdisk /dev/sde   # FRA disk

# 3. Identifica gli ID univoci dei dischi
ASM_CRS=$(/usr/lib/udev/scsi_id -g -u -d /dev/sdc)
ASM_DATA=$(/usr/lib/udev/scsi_id -g -u -d /dev/sdd)
ASM_FRA=$(/usr/lib/udev/scsi_id -g -u -d /dev/sde)

# 4. Crea regole udev persistenti (SU OGNI NODO)
cat > /etc/udev/rules.d/99-oracle-asmdevices.rules <<EOF
KERNEL=="sd?1", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/\$parent", RESULT=="${ASM_CRS}", SYMLINK+="oracleasm/asm-crs-disk1", OWNER="oracle", GROUP="dba", MODE="0660"
KERNEL=="sd?1", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/\$parent", RESULT=="${ASM_DATA}", SYMLINK+="oracleasm/asm-data-disk1", OWNER="oracle", GROUP="dba", MODE="0660"
KERNEL=="sd?1", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/\$parent", RESULT=="${ASM_FRA}", SYMLINK+="oracleasm/asm-reco-disk1", OWNER="oracle", GROUP="dba", MODE="0660"
EOF

# 5. Ricarica e verifica (esegui 2 volte per sicurezza)
/sbin/partprobe /dev/sdc1 /dev/sdd1 /dev/sde1
sleep 5
/sbin/udevadm control --reload-rules
sleep 5
/sbin/partprobe /dev/sdc1 /dev/sdd1 /dev/sde1
/sbin/udevadm control --reload-rules
sleep 5

# Verifica
ls -la /dev/oracleasm/
# asm-crs-disk1 -> ../../sdc1
# asm-data-disk1 -> ../../sdd1
# asm-reco-disk1 -> ../../sde1
```

> **Vantaggio vs oracleasm**: Niente `oracleasm init/scandisks`. I link simbolici si ricreano automaticamente ad ogni reboot. Oracle raccomanda udev per 19c+.

### B) /u01 su Disco Dedicato (XFS)

Aggiungere un disco VDI addizionale per `/u01` separa i binari Oracle dal disco OS.

```bash
# In VirtualBox: Aggiungi un disco da 100 GB alla VM
# Nella VM come root:
echo -e "n\np\n1\n\n\nw" | fdisk /dev/sdb
mkfs.xfs -f /dev/sdb1
UUID=$(blkid -o value /dev/sdb1 | grep -v xfs)
mkdir -p /u01
echo "UUID=${UUID}  /u01  xfs  defaults 1 2" >> /etc/fstab
mount /u01
```

### C) NetworkManager dns=none (IMPORTANTE!)

```bash
# Impedisce a NetworkManager di sovrascrivere /etc/resolv.conf dopo reboot
sed -i -e "s|\[main\]|\[main\]\ndns=none|g" /etc/NetworkManager/NetworkManager.conf
systemctl restart NetworkManager.service
```

> ⚠️ **Senza questo fix**, dopo un reboot NetworkManager può sovrascrivere il tuo `/etc/resolv.conf` e **rompere la risoluzione SCAN**. Questo è uno dei bug più insidiosi e difficili da diagnosticare!

### D) chrony Time Sync (Invece di NTP)

```bash
yum install -y chrony
systemctl enable chronyd
systemctl restart chronyd
chronyc -a 'burst 4/4'    # Sincronizza velocemente
chronyc -a makestep        # Applica la correzione immediatamente
```

### E) CRS NORMAL Redundancy (3 Dischi)

Se hai abbastanza spazio, usa **3 dischi CRS** con **NORMAL redundancy** e Failure Groups:

```
# In VirtualBox: crea 3 dischi CRS condivisi (2 GB ciascuno)
asm_crs_disk1.vdi  (2 GB, Shareable, Multi-Attach)
asm_crs_disk2.vdi  (2 GB, Shareable, Multi-Attach)
asm_crs_disk3.vdi  (2 GB, Shareable, Multi-Attach)

# Nel Grid installer:
Disk Group: CRS
Redundancy: NORMAL
Failure Groups: CRSFG1 (disk1), CRSFG2 (disk2), CRSFG3 (disk3)
```

> **Vantaggio**: NORMAL redundancy con Failure Groups è lo standard in produzione. Se un disco muore, ASM continua a funzionare!

---

> 📸 **Riepilogo Snapshot Fase 0**:
> - **SNAP-01** (dopo install OS su `rac1`)
> - **SNAP-01-stby** (dopo install OS su `racstby1`)
> - **SNAP-01-target** (dopo install OS su `dbtarget`)

**→ Prossimo: [FASE 1: Preparazione OS e Configurazione](./GUIDA_FASE1_PREPARAZIONE_OS.md)**
