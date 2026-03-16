# PHASE 0: Machine Setup (VirtualBox)

> **This step must be completed BEFORE anything else.** Here we create the VMs in VirtualBox for the DNS, primary RAC, and standby RAC.
> **Basato su**: [Oracle Base RAC 19c Guide](https://oracle-base.com/articles/19c/oracle-db-19c-rac-installation-on-oracle-linux-7-using-virtualbox) — adapted for manual installation step by step.

### Overall view of the VirtualBox Lab

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                         IL TUO PC (HOST VIRTUALBOX)                             ║
║                                                                                  ║
║   ┌───────────────────────────────────────────────────────────────────────┐      ║
║ │ Host-Only Network #1 (192.168.56.0/24) │ ║
║ │ "Publish" for cluster │ ║
║   └──┬─────────┬────────┬──────────┬──────────┬──────────────────────────┘      ║
║      │         │        │          │          │                                  ║
║   ┌──┴───┐  ┌──┴──┐  ┌──┴──┐   ┌──┴──┐   ┌──┴──┐                              ║
║   │dns   │  │rac1 │  │rac2 │   │stby1│   │stby2│                               ║
║   │.56.50│  │.56.1│  │.56.2│   │.56.3│   │.56.4│   dbtarget + GG su cloud     ║
║   │1GB   │  │8GB  │  │8GB  │   │8GB  │   │8GB  │                               ║
║   │1CPU  │  │4CPU │  │4CPU │   │4CPU │   │4CPU │                               ║
║   └──────┘  └──┬──┘  └──┬──┘   └──┬──┘   └──┬──┘                               ║
║                │        │        │         │                                    ║
║             ┌──┴────────┴──┐  ┌──┴─────────┴──┐                                ║
║             │  Host-Only   │  │  Host-Only    │    (Reti Private Interconnect)  ║
║             │  #2: 192.168 │  │  #3: 192.168  │    Separate per ogni cluster   ║
║             │  .1.x (Prim) │  │  .2.x (Stby)  │                                ║
║             └──────────────┘  └───────────────┘                                ║
║                                                                                  ║
║ Shared Disks (Shareable VDI): ║
║   ┌────────────────────────┐    ┌────────────────────────┐                      ║
║   │ rac1 + rac2            │    │ racstby1 + racstby2    │                      ║
║   │ asm-crs-disk1  2GB     │    │ asm-stby-crs-1  2GB   │                      ║
║   │ asm-crs-disk2  2GB     │    │ asm-stby-crs-2  2GB   │                      ║
║   │ asm-crs-disk3  2GB     │    │ asm-stby-crs-3  2GB   │                      ║
║   │ asm-data-disk1 20GB    │    │ asm-stby-data   20GB  │                      ║
║   │ asm-reco-disk1 15GB    │    │ asm-stby-reco   15GB  │                      ║
║   └────────────────────────┘    └────────────────────────┘                      ║
╚══════════════════════════════════════════════════════════════════════════════════╝
```

### 📸 Visual References

![VM Settings — 8 GB RAM + 4 CPU](./images/virtualbox_vm_settings.png)

![Network Configuration](./images/virtualbox_network_config.png)

![Storage — ASM Shared Disks](./images/virtualbox_storage_disks.png)

---

## 0.1 What You Need (Hardware Requirements)

| Macchina | Tipo | RAM | CPU |OS disk| Disco /u01 | ASM discs |
|---|---|---|---|---|---|---|
| `dnsnode` | VM VirtualBox | **1 GB** | **1 vCPU** | 15 GB | — | — |
| `rac1` | VM VirtualBox | **8 GB** | **4 vCPU** | 50 GB | 100 GB |5 shared|
| `rac2` |VM (rac1 clone)| **8 GB** | **4 vCPU** | 50 GB | 100 GB |same as rac1|
| `racstby1` | VM VirtualBox | **8 GB** | **4 vCPU** | 50 GB | 100 GB |5 shared (own)|
| `racstby2` |VM (racstby1 clone)| **8 GB** | **4 vCPU** | 50 GB | 100 GB |same as racstby1|

> **Why a separate DNS?** Oracle Base recommends a dedicated DNS VM with **Dnsmasq** (lightweight alternative to BIND). So DNS doesn't stop when you reboot RAC nodes, and SCAN always works. It costs only 1 GB.
>
> **Why the separate /u01 disk?** Oracle software (Grid + DB) must be installed on a separate disk. Oracle Base uses this approach — separate binaries from the OS.
>
> **`dbtarget`and GoldenGate** run on **OCI cloud** or other machine, not on this PC.

### Complete IP Plan

| Hostname | Type | Public IP | Private IP | Notes |
|---|---|---|---|---|
| `dnsnode` | DNS Server | 192.168.56.50 | — | Dnsmasq |
| `rac1` | RAC Primary N.1 | 192.168.56.101 | 192.168.1.101 | |
| `rac2` | RAC Primary N.2 | 192.168.56.102 | 192.168.1.102 | |
| `rac1-vip` | VIP N.1 | 192.168.56.103 | — |Managed by the CRS|
| `rac2-vip` | VIP N.2 | 192.168.56.104 | — |Managed by the CRS|
| `rac-scan` | SCAN (3 IP) | 192.168.56.105-107 | — | Round-Robin DNS |
| `racstby1` | Standby No.1 | 192.168.56.111 | 192.168.2.111 | |
| `racstby2` | Standby No.2 | 192.168.56.112 | 192.168.2.112 | |
| `racstby1-vip` | VIP Standby N.1 | 192.168.56.113 | — |Managed by the CRS|
| `racstby2-vip` | VIP Standby No.2 | 192.168.56.114 | — |Managed by the CRS|
| `racstby-scan` | SCAN Standby | 192.168.56.115-117 | — | Round-Robin DNS |

### Software to Download BEFORE Starting

| Software | File | Link |Size|
|---|---|---|---|
| Oracle Linux 7.9 ISO | `OracleLinux-R7-U9-Server-x86_64-dvd.iso` | [yum.oracle.com](https://yum.oracle.com/oracle-linux-isos.html) | ~4.6 GB |
| Grid Infrastructure 19c | `LINUX.X64_193000_grid_home.zip` | [edelivery.oracle.com](https://edelivery.oracle.com) | ~2.7 GB |
| Database 19c | `LINUX.X64_193000_db_home.zip` | [edelivery.oracle.com](https://edelivery.oracle.com) | ~2.9 GB |
| GoldenGate 19c/21c | `fbo_ggs_Linux_x64_Oracle_shiphome.zip` | [edelivery.oracle.com](https://edelivery.oracle.com) | ~500 MB |
| VirtualBox | Ultimo | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) | ~100 MB |

### 🔧 Oracle Patches — How to Find Them (My Oracle Support)

| Patch | MOS Patch ID | How to Find It | Note |
|---|---|---|---|
| **OPatch** (utility) | **6880880** | [Download here](https://updates.oracle.com/Orion/PatchDetails/process_form?patch_num=6880880) | ALWAYS update before each RU. **Note**: For January 2026 patch you need v12.2.0.1.48+ |
| **Combo Patch (GI/DB RU + OJVM)** |Changes every quarter (e.g. **38658588**)| MOS → Patches & Updates → cerca `"Combo of OJVM Component Release Update 19... + Grid Infrastructure ..."` |A single .zip file that includes both the RU for the Grid/DB engine and the RU for Java (OJVM)|

> **How ​​to find the latest RU**: Go to MOS (Doc ID **2118136.2**) → table with ALL Release Updates for each version.
>
> **⚡ Download everything before you begin.** There's nothing worse than getting halfway through installation and finding that a 3GB file is missing.

---

## 0.2 Network Configuration in VirtualBox (ONLY ONCE)

Before creating any VMs, configure networks globally.

### Host-Only Network #1: Cluster "Public" (192.168.56.0/24)

1. Open VirtualBox → **File > Tools > Network Manager**
2. Tab **Reti Host-only**
3. Click **Create**
4. Configure:
- IPv4 address:`192.168.56.1`
   - Maschera: `255.255.255.0`
- **DHCP Server**: ❌ **DISABLED** (we use static IPs!)

### Host-Only Network #2: Primary RAC Interconnect (192.168.1.0/24)

5. Click **Create** again
6. Configure:
- IPv4 address:`192.168.1.1`
   - Maschera: `255.255.255.0`
   - **DHCP**: ❌ Disabilitato

### Host-Only Network #3: Interconnect RAC Standby (192.168.2.0/24)

7. Click **Create** one more time
8. Configure:
- IPv4 address:`192.168.2.1`
   - Maschera: `255.255.255.0`
   - **DHCP**: ❌ Disabilitato

> **Why 3 networks?** #1 is the traffic to the cluster LAN (public), #2 is the private interconnect of the primary, #3 is the private interconnect of the standby. In production they would be on separate physical switches.

---

## 0.3 Create the DNS VM (FIRST)

> **Build order**: DNS → rac2 → rac1 (Oracle Base installs the SW from rac1. In the manual lab you can also do rac1 → rac2).

### VM creation `dnsnode` in VirtualBox

1. **New** → Name: `dnsnode`, Tipo: Linux, Oracle (64-bit)
2. **RAM**: 1024 MB (1 GB)
3. **CPU**: 1
4. **Disk**: 15 GB (dynamically allocated)
5. **Net**:
- Adapter 1: **NAT** (for Internet access/yum)
   - Adapter 2: **Host Only Tab** → select network 192.168.56.0
6. **Install Oracle Linux 7.9** (minimal installation, no GUI)

### Configuring the Network (VirtualBox Console)

> ⚠️ **Copy-Paste Problem**: You have just entered the black console of VirtualBox. You cannot "copy and paste" the code below. First we need to give an IP to the machine, and then we will connect comfortably with MobaXterm!

From the VirtualBox terminal:
1. Log in as `root`
2. Type the command:`nmtui`
3. Choose **Edit a connection**
4. **ENABLE NAT (Internet)**: Select the FIRST tab (e.g. `enp0s3`), go to Edit, and check the **"Automatically connect"** box. This will enable Internet via VirtualBox's DHCP. Do OK.
5. **CONFIGURE STATIC IP**: Go to the SECOND tab (the host-only one, usually `enp0s8`), vai su Edit.
6. Change IPv4 Configuration to **Manual**
7. Enter the address:`192.168.56.50/24`(leave gateway blank)
8. Save, exit, and return to the prompt.
9. Digita: `systemctl restart network`
10. **MANDATORY**: Check that you have Internet before proceeding!
    `ping -c 2 google.com` (Se non risponde, torna in `nmtui` and make sure the first tab is active).
11. Check static IP: `ip addr show`

### Connect with MobaXterm (NOW YOU CAN COPY-PASTE!)

> 🛑 **ALT! STOP! ARE YOU STILL IN THE VIRTUALBOX BLACK SCREEN?**
>
> **ALL COMMANDS FROM HERE ON OUT MUST BE EXECUTED VIA MOBAXTERM!**
> Ora che la macchina ha l'IP `192.168.56.50` assegnato via `nmtui`, minimizes the VirtualBox window. The VirtualBox console does not support the copy-paste you need now.
> Open **MobaXterm** from your Windows PC and create an SSH session to that IP.
> 
> **Reference IP Table for MobaXterm:**
> - `dnsnode`: 192.168.56.50

Once inside MobaXterm as a user `root`, you can conveniently paste the following code blocks!

### Configurare Dnsmasq

```bash
#== RUN AS ROOT (now via MobaXterm) ==

#(Optional) Make the network configuration static via file for security
cat > /etc/sysconfig/network-scripts/ifcfg-enp0s8 <<EOF
TYPE=Ethernet
BOOTPROTO=static
NAME=enp0s8
DEVICE=enp0s8
ONBOOT=yes
IPADDR=192.168.56.50
NETMASK=255.255.255.0
EOF
systemctl restart network


# 2. Popola /etc/hosts con TUTTI gli hostname (FQDN + short)
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
EOF

#3. Install DNSmasq and network tools (nslookup)
yum install -y dnsmasq bind-utils

# Configura Dnsmasq
cat > /etc/dnsmasq.d/rac.conf <<EOF
# Listen on host-only interface
interface=enp0s8

# Avoid having your provider's router (e.g. Telecom) inject DNS suffixes
domain=localdomain
expand-hosts
local=/localdomain/
domain-needed
bogus-priv

# Use Google DNS for external names (fallback outcome)
no-resolv
server=8.8.8.8
server=8.8.4.4

# Logging
log-queries
EOF

#4. Enable and launch
systemctl enable dnsmasq
systemctl start dnsmasq

# 5. Apri porta DNS sul firewall
firewall-cmd --permanent --add-service=dns
firewall-cmd --reload

#6. TEST DNSMASQ (Essential before turning off the machine!)
# Test 1: Is the service running?
systemctl status dnsmasq

# Test 2: Local FQDN Resolution (Bypass your home router)
nslookup rac1.localdomain 192.168.56.50
nslookup rac-scan.localdomain 192.168.56.50      # ← DEVE ritornare 3 IP!
nslookup racstby-scan.localdomain 192.168.56.50  # ← DEVE ritornare 3 IP!

# Test 3: External Resolution (Internet)
nslookup google.com 192.168.56.50 # ← Google IP MUST return!
```

> 📸 **SNAP-DNS**: When Dnsmasq works, take snapshots of the dnsnode VM!

---

## 0.4 VM Creation `rac1` (Primary RAC — Node 1)

### Step-by-step in VirtualBox

1. Click **New** (New)
2. **Name and Operating System**:
   - Nome: `rac1`
   - Tipo: **Linux** → **Oracle (64-bit)**
3. **Memoria**: **8192 MB** (8 GB)
4. **CPU**: **4** processors
5. **Disco Rigido**:
- Select **Create a virtual disk now**
- Type: **VDI**, Dynamically Allocated
- Size: **50 GB**

### Hardware configuration

Select`rac1`→ **Settings**:

#### System > Processor
- ✅ Abilita **PAE/NX**

#### System > Motherboard
- Boot order: ❌ Remove **Floppy**
- Chipset: **ICH9** (recommended for Oracle Linux)

#### Network (3 network cards)

**Scheda 1 — NAT (accesso Internet per yum)**:
- ✅ Enable network card
- Connected to: **NAT**

**Sheet 2 — Cluster "Public" Network**:
- ✅ Enable network card
- Connessa a: **Scheda solo host (Host-only Adapter)**
- Name: Select the network **192.168.56.0** (created in step 0.2)
- Advanced → Type: **Intel PRO/1000 MT Desktop**
- Advanced → Promiscuous Mode: **Allow All**

**Scheda 3 — Interconnect Privata**:
- ✅ Enable network card
- Connessa a: **Scheda solo host (Host-only Adapter)**
- Name: Select the network **192.168.1.0** (primary interconnect)
- Advanced → Type: **Intel PRO/1000 MT Desktop**
- Advanced → Promiscuous mode: **Allow all**

> **Why 3 NICs?** Oracle Base uses this approach: NIC1=NAT (for yum/update), NIC2=Public cluster (SCAN, VIP, client connections), NIC3=Private interconnect (Cache Fusion). This is cleaner than Bridged because it doesn't depend on your home network.

#### Storage

1. In **Controller: IDE**, attacca la ISO `OracleLinux-R7-U9-Server-x86_64-dvd.iso`
2. Add a **second **100 GB** disk (for`/u01` — binari Oracle)

---

## 0.5 Creating ASM Shared Disks (for Primary RAC)

### Create 5 discs in Virtual Media Manager

VirtualBox → **File > Virtual Media Manager** (`Ctrl+D`) → **Crea**:

| Disco |Size| Tipo | Uso |
|---|---|---|---|
| `asm-crs-disk1.vdi` | **2 GB** |**Fixed Size**| OCR (Disk Group CRS) |
| `asm-crs-disk2.vdi` | **2 GB** |**Fixed Size**| Voting (Disk Group CRS) |
| `asm-crs-disk3.vdi` | **2 GB** |**Fixed Size**| Voting (Disk Group CRS) |
| `asm-data-disk1.vdi` | **20 GB** |**Fixed Size**| Datafile (Disk Group DATA) |
| `asm-reco-disk1.vdi` | **15 GB** |**Fixed Size**| Recovery (Disk Group RECO) |

> 💡 **Oracle Best Practices: Why 3 x 2GB disks for CRS?**
>
> 1. **Why three discs? (The Quorum Rule):** Cluster Ready Services (CRS) saves the cluster state to the *Voting Disk*. To avoid split-brain (when nodes do not communicate and try to write over each other's data), Oracle uses a majority system (Quorum): `(N/2) + 1`. 
>    - With **3 disks** (Normal Redundancy), to have the majority you need at least 2 active disks. If 1 disk fails, the cluster survives.
>    - If we used **2**, the quorum would be 2. If 1 disk fails, the cluster shuts down (no high reliability).
>    - Using **1 disk** (External Redundancy) is done in production only if you have a formidable SAN/NAS that guarantees high hardware reliability, but for a MAA lab we want to simulate software ASM redundancy.
> 
> 2. **Why 2 GB?** OCR (Oracle Cluster Registry) and Voting Disk together take up less than 500 MB. However, allocating 2 GB is the recommended best practice for Oracle 19c to smoothly handle future upgrades (Grid patching), automatic OCR backups (which are kept in the same disk group), and to ensure enough *Allocation Units* (AU) for ASM.

### Make Disks Shareable (CRITICAL!)

1. In the Virtual Media Manager, select each ASM disk
2. **Attributes** → Type: **Shareable** ✅
3. Click **Apply**
4. Repeat for all 5 discs

### Attach the discs to `rac1`

1. Select`rac1`→ **Settings > Storage**
2. Select **Controller: SATA**
3. Click the "Add Hard Drive" icon (+)
4. Add all 5 disks in order: crs1, crs2, crs3, data, reco

---

## 0.6 Installing Oracle Linux 7.9 on`rac1`

1. Avvia `rac1`→ Boots from the ISO → **Install Oracle Linux 7.9**

### Installation Screen

**Language**: English (recommended for consistency with logs and documentation)

**Software Selection**:
- Select: **Server with GUI** (GUI is needed for Grid/DB installer!)
- Aggiungi:
  - ✅ Development Tools
  - ✅ Compatibility Libraries

> **Why Server with GUI?** Oracle installers (gridSetup.sh, runInstaller, dbca) use Java/X11. Without GUI, you have to use response files in silent mode — possible but more complex for a lab.

**Installation Destination**:
- Select the 50GB (sda) disk — DO NOT touch the 100GB (sdb) disk, it will be /u01)
- Partitioning: **Automatic** va bene, oppure manuale:

| Mount Point | Size | Tipo |
|---|---|---|
| `/boot` | 1 GB | xfs |
| `swap` | 8 GB | swap |
| `/` |Rest (~41GB)| xfs |

> 💡 **E `/tmp`?** There is no need to create a disk partition for `/tmp` during installation. In Phase 1 (Section 1.5b) we will mount it as `tmpfs` — un filesystem velocissimo che vive direttamente in RAM e si pulisce automaticamente ad ogni riavvio.

![OS Disk Partitioning](./images/os_install_partitions.png)

> 💡 **Oracle Best Practices: How Much Swap Do You Really Need?**
> Allocating 8 GB of swap is Oracle's OFFICIAL and exact recommendation for a server with 8 GB of RAM. The official calculation matrix for Oracle 19c provides:
> - **RAM between 1 GB and 2 GB**: Swap = 1.5 times the RAM
> - **RAM between 2 GB and 16 GB**: Swap = equal to RAM (this is our case: 8 GB RAM = 8 GB Swap)
> - **RAM greater than 16 GB**: Swap = 16 GB fixed

**Network & Host Name**:
- Turn **ALL** interfaces ON
- Hostname: `rac1`
- DO NOT configure IPs here (we do them in Phase 1 with more control)

**Kdump**: ❌ Disable it (save RAM)

**Root Password**: `oracle` (per il lab)

3. Click **Begin Installation** → Wait (~15-20 minutes)
4. Al termine → **Reboot**
5. Accept the license on first launch

> 📸 **SNAPSHOT — "SNAP-01: OS_Base_Installato"**
> ```bash
> VBoxManage snapshot "rac1" take "SNAP-01: OS_Base_Installato"
> ```

---

## 0.7 Prepare the /u01 disk

After the first boot of `rac1`, open MobaXterm (or use the console if you haven't configured the network yet) and run these commands as a user `root` step by step.

### Step 1: Identify the correct disk
Make sure the 100GB disk is seen as `sdb`.

```bash
lsblk
```

### Step 2: Partition the disk (/dev/sdb)
Usa il tool `fdisk` interactively to create a new primary partition.

```bash
fdisk /dev/sdb
```
*(Press the key sequence:`n` [New], `p` [Primaria], `1` [Numero 1], `Invio`[First default sector],`Invio`[Last Sector Default],`w` [Write and save])*

### Step 3: Format the partition in XFS
The newly created partition will be called `sdb1`. Formattala con il file system XFS (lo standard di Oracle Linux 7).

```bash
mkfs.xfs -f /dev/sdb1
```

### Step 4: Create the mount folder (u01)
This is the directory where we will install all the Oracle software (Grid and Database).

```bash
mkdir -p /u01
```

### Step 5: Permanent Mounting (fstab)
To ensure that the disk does not dismount upon reboot, you must record it in`/etc/fstab`. Instead of the name`sdb1`(which may change), we use the disk's unique UUID.

> 💡 **Tip from DBA: How do you read the fstab file and why do we use 0 0?**
> The row we are about to add is made up of 6 fields separated by spaces/tabs:
> `<Device/UUID>  <Mount Point>  <File System>  <Opzioni>  <Dump>  <Fsck Pass>`
> Nel nostro caso: `UUID=... /u01 xfs defaults 0 0`
> - `defaults`: Usa le opzioni di mount standard (rw, suid, dev, exec, auto, nouser, async).
> - **Campo 5 (Dump)**: Abilita il backup dell'utility legacy `dump`. Per i filesystem `xfs` (the modern Oracle Linux standard), this tool is obsolete (it is used `xfsdump`). Pertanto, si imposta sempre a `0` (disabilitato).
> - **Field 6 (Pass)**: Indicates the order in which the tool`fsck` will scan disks on startup. It was used with old ext3/ext4 filesystems `1` per il root e `2` for the other discs. **But XFS doesn't use fsck at boot!** XFS handles consistency (journaling) internally at mount time.
> 
> That's why if you look at your `fstab`, you will see that the Root disk (`/`) ha impostato `0 0`. Per coerenza e best practice, assegniamo `0 0` to ours too `/u01` in XFS!

```bash
#Read the disk UUID
blkid /dev/sdb1

# Mentally copy the UUID and add this line to the bottom of the /etc/fstab file using 'vi' or 'nano':
# UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx /u01 xfs defaults 0 0

# Or, if you prefer a shortcut that does everything by itself:
UUID=$(blkid -s UUID -o value /dev/sdb1)
echo "UUID=${UUID}  /u01  xfs  defaults 0 0" >> /etc/fstab
```

### Step 6: Mount and Check
Scrivere in `fstab` tells the system what to do at the next reboot. To mount the disk *now* without rebooting, we use the global mount command which rereads the file.

```bash
mount -a
df -h
```
*(Cerca `/u01` in the list. Output should show ~100GB available and mounted).*

---

## 0.8 Configure ASMLib (oracleasm) for ASM Disks

> **ASMLib v3 vs UDEV (La caduta di ASMFD)**:  
> You are absolutely right! Until recently Oracle was pushing for the use of **ASMFD** (ASM Filter Driver) to replace ASMLib. However, in a dramatic about-face on recent releases (19c and the upcoming 23ai on Linux kernel 5.14+ as OEL 8/9), **Oracle has officially DEPRECATED ASMFD**.
> 
> *What is the current Enterprise standard (2026+)?*
> 1. **UDEV Rules**: Remains the universally recommended open-source Linux standard for pure configurations.
> 2. **The Return of ASMLib**: Oracle has released **ASMLib v3**, which now natively supports modern kernel APIs (io_uring) and provides the filtering features of ASMFD without its kernel compatibility issues.
> 
> Therefore, our educational choice to use ASMLib (`oracleasm`) in the lab not only greatly facilitates teaching compared to UDEV, but aligns perfectly with Oracle's current "backfire" towards this component!

### 1. Partitioning disks (== ONLY RUN ON rac1 ==)

All ASM disks must be partitioned before being assigned to ASMLib. Instead of using "blind" automatic scripts, we will logically map the disks to their ASM purposes (CRS, DATA, RECO) and partition them by hand. It's the basic job of a DBA!

> 💡 **Mapping Physical Disks → ASM Roles (Lab)**:
> - `sdc` (2GB) -> CRS Disk 1 (Quorum/OCR)
> - `sdd` (2GB) -> CRS Disk 2
> - `sde` (2GB) -> CRS Disk 3
> - `sdf` (20GB) -> DATA (Datafiles del DB)
> - `sdg` (15GB) -> RECO / FRA (Archivelog e Backup)
>
> **Compulsory**: Check the size of the disks with `lsblk` before partitioning to make sure you don't format the wrong disk.

#### Step 1: Run`fdisk` in Manual mode (Educational)
Dal terminale MobaXterm su `rac1` as a user `root`, lancia `fdisk`for the first disc:

```bash
fdisk /dev/sdc
```
1. Premi `n` (new partition)
2. Premi `p` (primary partition)
3. Premi `1` (partition number 1)
4. Premi `Invio`(accept first sector by default)
5. Premi `Invio`(accepts the last sector by default, taking the entire disk)
6. Premi `w` (write and exit)
7. Repeat the operation for the other disks: `fdisk /dev/sdd`, `fdisk /dev/sde`, `fdisk /dev/sdf`, e `fdisk /dev/sdg`.

#### Step 1.1: Metodo Veloce (Script Automatico Sicuro)
As an alternative to manual disk-by-disk fdisk, you can use this handy "copy and paste" script.

> ⚠️ **CUSTOM ATTENTION TO THE LETTERS OF THE DISCS!**
> Exactly as will happen in Phase 1 for the creation of ASM volumes, the ordering of the letters (`sdb`, `sdc`, `sdd`...) depends on how VirtualBox "attached" the disks and is not always sequential.
> **BEFORE RUNNING THE SCRIPT**, launch `lsblk` and write down on a piece of paper the 5 letters that correspond to your new empty disks (the 2G, 20G and 15G ones).
> Ignora `sda` (which has the operating system partitions and `/u01`).

Dal terminale su `rac1` as `root`, **EDIT disk list** in the first line with the REAL letters seen on `lsblk`, poi incolla e premi Invio:

```bash
# Replace "sdc sdd sde sdf sdg" with YOUR actual letters from the 5 blank disks!
for disk in /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg; do
  echo "Partizionando $disk..."
  echo -e "n\np\n1\n\n\nw" | fdisk $disk
done
```
*(The output will confirm that a new Linux partition has been created for each disk `sdX1` and the partition table has been synchronized).*

> 💡 **Tip from DBA: Why do we NOT format these disks in XFS or put them in fstab?**
> A differenza di `/u01` (which is a filesystem managed by Linux to contain folders and files), ASM disks must remain "raw" (raw block devices). Oracle ASM is a standalone file system (volume manager + file system combined). If I tried to mount them in `fstab`, Linux would look for an ext4/xfs folder structure that doesn't exist, sending the machine into kernel panic on startup! ASMLib will recognize them at boot and pass them to Oracle.

#### Step 3: Reread the table
We tell the kernel to update its disk map (otherwise ASMLib won't see them).

```bash
partprobe
```

### 2. ASMLib Installation and Configuration (==RUN ONLY ON rac1 ==)

> **NOTE FROM DBA:** We will install ASMLib only on node 1. Since at the end of Phase 1 we will clone this machine to generate `rac2` and standby nodes, this configuration will automatically be inherited across all clones!

```bash
#As root on rac1
yum install -y oracleasm-support
yum install -y kmod-oracleasm

#Install the ASMLib library (it is NOT in the YUM repos, it must be downloaded)
# Without this package the Grid installer DOES NOT see disks!
cd /tmp
wget https://download.oracle.com/otn_software/asmlib/oracleasmlib-2.0.15-1.el7.x86_64.rpm
rpm -ivh oracleasmlib-2.0.15-1.el7.x86_64.rpm

# Configure ASMLib
oracleasm configure -i
#Answer the questions as follows:
# Default user to own the driver interface []: grid
# Default group to own the driver interface []: asmadmin
# Start Oracle ASM library driver on boot (y/n) [n]: y
# Scan for Oracle ASM disks on boot (y/n) [y]: y

# Initialize the module
oracleasm init
```

> ⚠️ **WARNING: 3 packages, not 2!** ASMLib needs **3 components** to work properly:
>
> |Package| Ruolo |Installation|
> |---|---|---|
> | `kmod-oracleasm` | **kernel** module that manages disks | `yum install` (dai repo) |
> | `oracleasm-support` |**Command line** tools (`oracleasm listdisks`, ecc.) | `yum install` (dai repo) |
> | `oracleasmlib` | **Library** that the Grid installer uses to discover disks | ❗ Download manuale da oracle.com |
>
> Se dimentichi `oracleasmlib`, il comando `oracleasm listdisks` works but **Grid installer shows empty disk list!**

> **Check**: The command `oracleasm status` it should show that the driver is loaded and mounted. We won't create the disks now, we will do that in Phase 2.

> 🛠️ **Troubleshooting: Errore "Mounting ASMlib driver filesystem: failed"**
> Se `oracleasm init` fails with this error, it's **SELinux**'s fault which is locking the driver in memory. Even if you have disabled it in `/etc/selinux/config` in Step 1, you need to restart your machine to turn it off. 
> To fix **on the fly without rebooting**, run as root:
> `setenforce 0`
> And then repeat the command`oracleasm init`.

> 📸 **NOTA SNAPSHOT:**
> *The old "SNAP-02" here has been removed to save space. We will take the important snapshot "SNAP-02: Golden_Image_Ready" at the end of Phase 1, when rac1 has everything (users, network, packets).*

---

## 0.9 Cloning`rac1` → `rac2`

**DO NOT clone now!** First complete all **Phase 1** (OS configuration, packages, users, SSH) on `rac1`. 
Detailed step-by-step instructions for safely cloning can be found at the end of Phase 1 (in **Section 1.14**).

---

## 0.10 Preparing Disks for Standby (DISKS ONLY!)

To build our Data Guard, we need separate storage for the second cluster.

> 🛑 **ATTENTION:** At this stage **DO NOT create virtual machines** `racstby1` o `racstby2`. You will create them in 30 seconds by cloning the "Golden Image" at the end of Phase 1. Now you just need to create the "pieces of iron" (the .vdi disks) that they will use later.

### Creating ASM Shared Disks for Standby:
1.  Vai in VirtualBox -> **Virtual Media Manager** (`Ctrl+D`).
2.  Create 5 new discs **Fixed Size**: `asm-stby-crs1` (2GB), `asm-stby-crs2` (2GB), `asm-stby-crs3` (2GB), `asm-stby-data` (20GB), `asm-stby-reco` (15GB).
3.  Set them all as **Shareable**.
> **IMPORTANT**: Standby ASM disks are **PHYSICALLY DIFFERENT** disks from primary ASM disks!

### 💡 The DBA Trick: Clone from the Golden Image (SNAP-02)

Why reinstall the OS from scratch and redo all the OS preparation (Phase 1) for the standby nodes? It makes no sense and is prone to errors (typo, forgotten packages)! 
The smartest (and fastest) approach is to wait until you've finished the full **Phase 1 on `rac1`** and create the snapshot **SNAP-02: Golden_Image_Ready**. Use that snapshot as the "Golden Image" to clone.

At the end of Phase 1, from your `rac1`turned off, you will perform these clones in cascade, always generating **new MAC addresses**:
1. `rac1` -> Clona in `rac2` (as explained in Section 1.14).
2. `rac1` -> Clona in `racstby1`.
3. `rac1` -> Clona in `racstby2` (oppure clona `racstby1` in `racstby2`).

**What will you need to change on Standby clones?**
Exactly how you will do it `rac2`, you will need to launch the Standby clones one at a time from the VirtualBox black console and use `nmtui` per cambiare:
- **L'Hostname**: in `racstby1.localdomain` e `racstby2.localdomain`.
- **Public IP (Tab 2)**: in`192.168.56.111` e `192.168.56.112`.
- **L'IP Privato (Scheda 3)**: in `192.168.2.111` e `192.168.2.112` (**ATTENTION**: The standby private network is `.2.x`!).

After that you will have to go to the VirtualBox settings of the VMs `racstby1` e `racstby2` and connect the 5 new disks to them `asm-stby-xxx` creati al punto precedente.

---

## 0.11 Next Steps: The Heart of the Operating System

You have completed the hardware/hypervisor setup and installed Oracle Linux with the correct partitions.

All the operating system configuration (users, kernel parameters, Chrony, HugePages) is centralized in **[PHASE 1](./GUIDE_PHASE1_OS_PREPARATION.md)**. 
You will perform that step **ONLY on `rac1`**; it will become your **Golden Image** that you will clone to create all the other nodes. Don't do this now on the clones to save time.

---

## 0.12 How to Connect to VMs (MobaXterm)

> 💡 **IMPORTANT**: From this moment on, **DO NOT** use the VirtualBox console window to work. Use a professional SSH client like **MobaXterm** (free) from your Windows PC. Why?
> 1. You can copy-paste commands conveniently.
> 2. Supports multi-tabling (open`rac1` e `rac2`side by side).
> 3. **KEY**: It has a built-in X11 server to show you graphical windows (e.g. Oracle Grid installer).

### Configuring Sessions in MobaXterm

1. Download and open MobaXterm (Home/Portable version is fine).
2. Click on **Session** -> **SSH** at the top left.
3. **Remote host**: Enter the public IP (Host-Only Network #1) of the VM.
   - Es. `192.168.56.50` per `dnsnode`
   - Es. `192.168.56.101` per `rac1`
4. **Specify username**: Check the box and write`root` (o `oracle`).
5. **Advanced SSH settings** (scheda sotto):
   - Make sure **X11-Forwarding** is CHECKED ✅ (this is to see the graphics API).
6. Click **OK**. It will ask you for your password (enter your root pwd).

Repeat this process to create saved sessions for`dnsnode`, `rac1`, `rac2`, `racstby1`, `racstby2`.

---

> 📸 **Fundamental Snapshot Summary (Phase 0)**:
> - **SNAP-DNS**: VM `dnsnode`configured and working.
> - **SNAP-01_OS_Installed**: Only OS and base partitions on`rac1`.
> - **SNAP-02_Base_VM_Ready**: ASMLib and disks configured on `rac1`. 
> 
> *Note: Do not create snapshots for standby now. The standby will be a clone of `rac1` after Phase 1 (`SNAP-04`).*

**→ Next: [STEP 1: OS Preparation and Configuration](./GUIDE_PHASE1_OS_PREPARATION.md)**
