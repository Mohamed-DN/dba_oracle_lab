# FASE 0: Setup delle Macchine (Proxmox VE + Oracle Linux 8.10)

> **Questa fase va completata PRIMA di tutto il resto.** Qui creiamo le VM nell'hypervisor Proxmox per il DNS, il RAC primario e il RAC standby.
> **Questa è una versione modernizzata ed Enterprise** del lab classico, progettata per girare su un hypervisor bare-metal e utilizzando Oracle Linux 8.10.

## Obiettivo operativo

Preparare un laboratorio Proxmox riproducibile e isolato per un CDB RAC primary `RACDB`, una PDB applicativa `RACDBPDB`, uno standby fisico RAC `RACDB_STBY` e gli Observer FSFO. 
Questa guida utilizza **Oracle Linux 8.10** e sfrutta **ASMLib v3**.

## 0.1 Cosa Ti Serve (Requisiti Hardware su Proxmox)

Rispetto a VirtualBox, Proxmox gestisce la memoria (KSM) in modo molto più efficiente, ma per un RAC Enterprise raccomandiamo un nodo bare-metal con almeno 64GB di RAM e dischi NVMe/SSD.

| Macchina | Tipo | RAM | CPU (Type=Host) | Disco OS | Disco /u01 | Dischi ASM |
|---|---|---|---|---|---|---|
| `dnsnode` | VM Proxmox | **1 GB** | **1 vCPU** | 15 GB | — | — |
| `rac1` | VM Proxmox | **8-12 GB** | **4 vCPU** | 50 GB | 100 GB | 5 condivisi |
| `rac2` | VM (clone) | **8-12 GB** | **4 vCPU** | 50 GB | 100 GB | stessi di rac1 |
| `racstby1` | VM Proxmox | **8-12 GB** | **4 vCPU** | 50 GB | 100 GB | 5 condivisi |
| `racstby2` | VM (clone) | **8-12 GB** | **4 vCPU** | 50 GB | 100 GB | stessi di racstby1 |

### Piano IP Completo (Immutato dal Lab Classico)

| Hostname | Tipo | IP Pubblica | IP Privata | Note |
|---|---|---|---|---|
| `dnsnode` | DNS Server | 192.168.56.50 | — | Dnsmasq |
| `rac1` | RAC Primary N.1 | 192.168.56.101 | 192.168.1.101 | |
| `rac2` | RAC Primary N.2 | 192.168.56.102 | 192.168.1.102 | |
| `rac1-vip` | VIP N.1 | 192.168.56.103 | — | Gestito dal CRS |
| `rac2-vip` | VIP N.2 | 192.168.56.104 | — | Gestito dal CRS |
| `rac-scan` | SCAN (3 IP) | 192.168.56.105-107 | — | Round-Robin DNS |

### Software da Caricare su Proxmox (ISO Storage)

Scarica la ISO di **Oracle Linux 8.10** (`OracleLinux-R8-U10-Server-x86_64-dvd.iso`) e caricala nello storage ISO del tuo nodo Proxmox (solitamente `local`).

---

## 0.2 Configurazione Reti su Proxmox (Linux Bridge)

In Proxmox, le reti "Host-Only" di VirtualBox si replicano creando dei **Linux Bridge** senza IP gateway/collegamento fisico, creando di fatto degli switch virtuali isolati.

Dalla GUI di Proxmox -> Seleziona il tuo Nodo -> **Network** -> **Create** -> **Linux Bridge**

1. **Rete Pubblica del Cluster:**
   - Name: `vmbr1`
   - IPv4/CIDR: `192.168.56.1/24`
   - Bridge ports: *(vuoto)* -> Questo la rende isolata dall'esterno (stile Host-Only).
   
2. **Interconnect RAC Primario:**
   - Name: `vmbr2`
   - IPv4/CIDR: `192.168.1.1/24`
   - Bridge ports: *(vuoto)*

3. **Interconnect RAC Standby:**
   - Name: `vmbr3`
   - IPv4/CIDR: `192.168.2.1/24`
   - Bridge ports: *(vuoto)*

> [!WARNING]
> Clicca su **Apply Configuration** per rendere attivi i nuovi bridge senza dover riavviare l'host Proxmox.

---

## 0.3 Creazione VM `dnsnode` 

1. **Create VM** in alto a destra.
2. **OS:** Scegli la ISO di Oracle Linux 8.10.
3. **System:** Machine `q35`, SCSI Controller `VirtIO SCSI Single` (Standard per performance).
4. **Disks:** `local-lvm` (o tuo storage), 15GB, Format `Raw`, attiva **Discard** (TRIM).
5. **CPU:** 1 Core, Type: **Host** (Cruciale per performance crittografiche AES-NI).
6. **Memory:** 1024 MB, Disattiva "Ballooning".
7. **Network:** Seleziona il bridge `vmbr0` (NAT/Internet) e aggiungi una SECONDA scheda di rete su `vmbr1` (Rete Pubblica 192.168.56.x).

Installa OL8.10 (Minimal Install), assegna `192.168.56.50` all'interfaccia su `vmbr1`.
Configura **dnsmasq** esattamente come nella guida per OL7, ricordando di usare `dnf install -y dnsmasq bind-utils`.

---

## 0.4 Creazione VM `rac1` (RAC Primario — Nodo 1)

1. **Create VM**
   - Name: `rac1`
2. **System:** Qemu Agent: YES, SCSI Controller: **VirtIO SCSI Single**.
3. **Disks:**
   - Disco 0 (OS): 50GB su `local-lvm`, Format: `Raw`, Discard: YES.
   - Disco 1 (/u01): Aggiungi subito un altro disco cliccando `Add`. 100GB, Discard: YES.
4. **CPU:** 4 Cores, Type: **Host** (Fondamentale).
5. **Memory:** 8192 MB (o 12288 se hai RAM abbondante).
6. **Network (3 Schede):**
   - `net0`: `vmbr0` (Internet per Yum/DNF)
   - `net1`: `vmbr1` (Pubblica Cluster)
   - `net2`: `vmbr2` (Privata Interconnect Primario)

---

## 0.5 Creazione Dischi Condivisi ASM (Il "Segreto" di Proxmox)

In Proxmox la condivisione di dischi richiede l'utilizzo del flag `shared=1` e la **disattivazione assoluta della cache** sul disco, per permettere al Clusterware di gestire i lock correttamente.

### Step 1: Crea i dischi dalla GUI
Vai in **rac1** -> **Hardware** -> **Add** -> **Hard Disk**.
Crea 5 dischi. Assicurati che **Cache** sia impostato su `No cache` o `Direct sync` (raccomandato `No cache` per ASM) e metti la spunta su **No Backup**.
- 3 dischi da **2 GB** (+CRS)
- 1 disco da **20 GB** (+DATA)
- 1 disco da **15 GB** (+RECO)

### Step 2: Abilita il flag Shared (da CLI dell'Host Proxmox)

La GUI di Proxmox attualmente non ha una checkbox "Shareable". Devi accedere via SSH all'host Proxmox e modificare il file della VM.

```bash
# Sostituisci 101 con l'ID della tua VM rac1
nano /etc/pve/qemu-server/101.conf
```

Cerca le righe che definiscono i dischi ASM appena creati, ad esempio:
`scsi2: local-lvm:vm-101-disk-2,size=2G`

Aggiungi il flag `,shared=1` alla fine di **tutti e 5 i dischi ASM**.

Risultato atteso:
```text
scsi2: local-lvm:vm-101-disk-2,cache=none,size=2G,shared=1
scsi3: local-lvm:vm-101-disk-3,cache=none,size=2G,shared=1
scsi4: local-lvm:vm-101-disk-4,cache=none,size=2G,shared=1
scsi5: local-lvm:vm-101-disk-5,cache=none,size=20G,shared=1
scsi6: local-lvm:vm-101-disk-6,cache=none,size=15G,shared=1
```
*(Nota: I nomi dei dischi `vm-101-disk-X` dipendono dal tuo storage model).*

---

## 0.6 Installazione Oracle Linux 8.10 su `rac1`

1. Avvia la VM.
2. In **Software Selection**, scegli **Server with GUI** (Oracle Installer richiede X11/Java).
3. In **Installation Destination**, fai molta attenzione a selezionare **SOLO il disco da 50GB (`sda`)**. Lascia deselezionato il disco da 100GB (`sdb`) e tutti i dischi piccoli ASM (`sdc`, `sdd`...).
4. Partizionamento Manuale (LVM):
   - `/boot` (Standard Partition, XFS) -> `1024 MiB`
   - `swap` (LVM) -> `8192 MiB`
   - `/` (LVM) -> Lascia vuoto per usare lo spazio rimanente (~41GB).

Installa e fai reboot. 

---

## 0.7 Preparare il Disco `/u01` e ASMLib v3 per OL8

Dopo il riavvio, accedi via SSH a `rac1`.

### Montaggio `/u01`
Identifica il disco da 100GB (es. `/dev/sdb`), partizionalo e formattalo in XFS, esattamente come su VirtualBox.

```bash
fdisk /dev/sdb # n, p, 1, invio, invio, w
mkfs.xfs -f /dev/sdb1
mkdir -p /u01
UUID=$(blkid -s UUID -o value /dev/sdb1)
echo "UUID=${UUID}  /u01  xfs  defaults 0 0" >> /etc/fstab
mount -a
```

### Installazione Dipendenze OL8
Usa il preinstall ufficiale per Oracle Database 19c su OL8:
```bash
dnf install -y oracle-database-preinstall-19c
```

### Partizionamento e Etichettatura ASMLib (OL8)

Installa ASMLib (supportato e compilato per kernel OL8/RHCK/UEK):
```bash
dnf install -y oracleasm-support oracleasmlib
oracleasm configure -i
# Rispondi: grid, asmadmin, y, y
```

Partiziona tutti e 5 i dischi ASM (es da `sdc` a `sdg`):
```bash
for disk in sdc sdd sde sdf sdg; do
  echo -e "n\np\n1\n\n\nw" | fdisk /dev/$disk
done
```

Etichettali:
```bash
oracleasm createdisk CRS1 /dev/sdc1
oracleasm createdisk CRS2 /dev/sdd1
oracleasm createdisk CRS3 /dev/sde1
oracleasm createdisk DATA /dev/sdf1
oracleasm createdisk RECO /dev/sdg1

oracleasm scandisks
oracleasm listdisks
```

> [!NOTE]
> Su **rac2** (quando clonerai o costruirai la VM), i dischi condivisi saranno mappati da Proxmox. Sul nodo 2 non dovrai formattarli o etichettarli, ma ti basterà installare `oracleasm-support` e lanciare `oracleasm scandisks` per vederli.

## Conclusione Fase 0

A questo punto hai `rac1` configurato, `/u01` montato, dipendenze OL8 risolte e dischi ASM formattati e timbrati tramite ASMLib v3.

Sei pronto a procedere alla Fase 1 (Preparazione OS avanzata per l'utente Grid/Oracle).
