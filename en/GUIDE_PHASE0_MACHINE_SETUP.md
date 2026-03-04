# PHASE 0: Machine Setup (VirtualBox)

> **Complete this phase BEFORE anything else.** Here we create all VirtualBox VMs for the primary RAC, standby RAC, and GoldenGate target.

### Lab Overview

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                        YOUR PC (VIRTUALBOX HOST)                             ║
║                                                                               ║
║   ┌─────────────────────────────────────────────────────────────────────┐     ║
║   │                  Bridged Network (192.168.1.0/24)                   │     ║
║   │              Connected to your physical Wi-Fi/Ethernet             │     ║
║   └──┬────────┬────────┬──────────┬──────────┬──────────┬──────────────┘     ║
║      │        │        │          │          │          │                     ║
║   ┌──┴──┐  ┌──┴──┐  ┌──┴──┐   ┌──┴──┐   ┌──┴──┐   ┌──┴──────┐             ║
║   │rac1 │  │rac2 │  │stby1│   │stby2│   │tgt  │   │ Your PC │             ║
║   │ .101│  │ .102│  │ .201│   │ .202│   │ .150│   │         │             ║
║   │4GB  │  │4GB  │  │4GB  │   │4GB  │   │2GB  │   │         │             ║
║   │2CPU │  │2CPU │  │2CPU │   │2CPU │   │1CPU │   │         │             ║
║   └──┬──┘  └──┬──┘  └──┬──┘   └──┬──┘   └─────┘   └─────────┘             ║
║      │        │        │         │                                           ║
║   ┌──┴────────┴──┐  ┌──┴─────────┴──┐                                       ║
║   │  Host-Only   │  │  Host-Only    │    (Separate Private Networks)         ║
║   │  10.10.10.x  │  │  10.10.10.x   │                                       ║
║   │  (Intercon.) │  │  (Intercon.)  │                                       ║
║   └──────────────┘  └───────────────┘                                       ║
║                                                                               ║
║   Shared Disks (Shareable VDI):                                              ║
║   ┌──────────────────┐    ┌───────────────────┐                              ║
║   │ rac1 + rac2      │    │ racstby1 + racstby2│                              ║
║   │ asm_crs.vdi  5GB │    │ asm_stby_crs  5GB │                              ║
║   │ asm_data.vdi 20GB│    │ asm_stby_data 20GB│                              ║
║   │ asm_fra.vdi  15GB│    │ asm_stby_fra  15GB│                              ║
║   └──────────────────┘    └───────────────────┘                              ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## 0.1 Hardware Requirements

| Machine | Type | Min RAM | CPU | OS Disk | ASM Disks |
|---|---|---|---|---|---|
| `rac1` | VirtualBox VM | 4 GB | 2 vCPU | 50 GB | 3 shared |
| `rac2` | VirtualBox VM (clone of rac1) | 4 GB | 2 vCPU | 50 GB | same as rac1 |
| `racstby1` | VirtualBox VM | 4 GB | 2 vCPU | 50 GB | 3 shared (own set) |
| `racstby2` | VirtualBox VM (clone of racstby1) | 4 GB | 2 vCPU | 50 GB | same as racstby1 |
| `dbtarget` | VirtualBox VM | 2 GB | 1 vCPU | 50 GB | 0 (filesystem) |

**Host PC**: Minimum 16 GB RAM (32 GB recommended). You don't need all VMs running simultaneously.

### Software to Download BEFORE Starting

| Software | File | Link | Size |
|---|---|---|---|
| Oracle Linux 7.9 ISO | `OracleLinux-R7-U9-Server-x86_64-dvd.iso` | [yum.oracle.com](https://yum.oracle.com/oracle-linux-isos.html) | ~4.6 GB |
| Grid Infrastructure 19c | `LINUX.X64_193000_grid_home.zip` | [edelivery.oracle.com](https://edelivery.oracle.com) | ~2.7 GB |
| Database 19c | `LINUX.X64_193000_db_home.zip` | [edelivery.oracle.com](https://edelivery.oracle.com) | ~2.9 GB |
| **OPatch** | `p6880880_230000_Linux-x86-64.zip` | [support.oracle.com](https://support.oracle.com) | ~100 MB |
| **Release Update (RU)** | `p37957391_190000_Linux-x86-64.zip` | [support.oracle.com](https://support.oracle.com) | ~1.5 GB |
| **OJVM Patch** | `p33803476_190000_Linux-x86-64.zip` | [support.oracle.com](https://support.oracle.com) | ~100 MB |
| GoldenGate 19c/21c | `fbo_ggs_Linux_x64_Oracle_shiphome.zip` | [edelivery.oracle.com](https://edelivery.oracle.com) | ~500 MB |
| VirtualBox | Latest | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) | ~100 MB |

> **Download everything first.** There's nothing worse than reaching mid-installation and discovering a 3GB file is missing.

---

## 0.2 VirtualBox Network Configuration (ONE TIME ONLY)

Before creating any VM, configure networks globally.

### Host-Only Network for Primary RAC Interconnect

1. Open VirtualBox → **File > Tools > Network Manager**
2. Tab **Host-only Networks**
3. Click **Create**
4. Configure:
   - IPv4 Address: `10.10.10.254`
   - Mask: `255.255.255.0`
   - **DHCP Server**: ❌ **DISABLED** (we use static IPs!)

### Host-Only Network for Standby Interconnect (separate)

5. Click **Create** again for a second host-only network
6. Configure:
   - IPv4 Address: `10.10.20.254`
   - Mask: `255.255.255.0`
   - **DHCP**: ❌ Disabled

> **Why two separate host-only networks?** Primary and standby interconnects must be isolated. In production, they would be on separate physical switches.

---

## 0.3 Creating VM `rac1` (Primary RAC — Node 1)

### Step-by-step in VirtualBox

1. Click **New**
2. **Name and Operating System**:
   - Name: `rac1`
   - Type: **Linux**
   - Version: **Oracle (64-bit)**
3. **Memory**: `4096 MB` (4 GB)
4. **Hard Disk**: Create a virtual hard disk now → **VDI** → **Dynamically allocated** → `50 GB`
5. Click **Create**

### Hardware Configuration

Select `rac1` → **Settings**:

#### System > Processor
- **CPU**: `2`
- ✅ Enable **PAE/NX**

#### System > Motherboard
- Boot order: ❌ Remove **Floppy**
- Chipset: **ICH9**

#### Network (CRITICAL — 2 adapters)

**Adapter 1 — Public Network**:
- ✅ Enable Network Adapter
- Attached to: **Bridged Adapter**
- Name: Select your **physical adapter** (Wi-Fi or Ethernet)
- Advanced → Adapter Type: **Intel PRO/1000 MT Desktop**
- Advanced → Promiscuous Mode: **Allow All**

> **Why Bridged?** The VM gets an IP on your physical LAN (192.168.1.x), allowing all machines to communicate directly.

**Adapter 2 — Private Network (RAC Interconnect)**:
- ✅ Enable Network Adapter
- Attached to: **Host-only Adapter**
- Name: Select the host-only network created in step 0.2 (10.10.10.254)
- Advanced → Adapter Type: **Intel PRO/1000 MT Desktop**
- Advanced → Promiscuous Mode: **Allow All**

> **Why Host-Only?** The interconnect is a PRIVATE, FAST network between cluster nodes. It must not be reachable from outside.

#### Storage — Installation ISO

1. Under **Controller: IDE**, click the empty optical disc icon
2. Click the CD icon → **Choose a disk file**
3. Select `OracleLinux-R7-U9-Server-x86_64-dvd.iso`

---

## 0.4 Creating Shared ASM Disks (for Primary RAC)

These disks will be used by **BOTH** `rac1` and `rac2` for shared ASM storage.

### Create disks from Virtual Media Manager

1. VirtualBox → **File > Virtual Media Manager** (`Ctrl+D`)
2. Click **Create**
3. Create 3 disks:

| Disk | Size | Purpose | Type |
|---|---|---|---|
| `asm_crs.vdi` | **5 GB** | OCR + Voting Disk | **Fixed Size** |
| `asm_data.vdi` | **20 GB** | Database datafiles | **Fixed Size** |
| `asm_fra.vdi` | **15 GB** | Fast Recovery Area | **Fixed Size** |

> **Why Fixed Size?** VirtualBox doesn't support sharing dynamically allocated disks. Only fixed-size disks can be marked as "Shareable".

### Make Disks Shareable (CRITICAL!)

4. In Virtual Media Manager, select each ASM disk
5. In the **Attributes** tab: Type: **Shareable** ✅
6. Click **Apply**
7. Repeat for all 3 disks

> **Why Shareable?** Without this, VirtualBox locks the disk when `rac1` uses it and `rac2` can't access it. In a RAC, both nodes must read/write to the SAME disk.

### Attach Disks to `rac1`

1. Select `rac1` → **Settings > Storage**
2. Select **Controller: SATA**
3. Click "Add hard disk" (+)
4. Select **Choose existing disk** → Select `asm_crs.vdi`
5. Repeat for `asm_data.vdi` and `asm_fra.vdi`

---

## 0.5 Installing Oracle Linux 7.9 on `rac1`

1. Start `rac1` (double-click or Start)
2. Boots from ISO → Select **Install Oracle Linux 7.9**

### Installation Screen

**Language**: English (recommended for log consistency)

**Software Selection**: **Server with GUI**
- Add: ✅ Development Tools, ✅ Compatibility Libraries

> **Why Server with GUI?** Oracle installers (gridSetup.sh, runInstaller, dbca, netca, asmca) use Java/X11 graphical interfaces. Without GUI, you'd need silent response files — doable but more complex.

**Installation Destination**: Select 50 GB disk (sda), **Automatic** partitioning

**Network & Host Name**: Turn ON both interfaces, Hostname: `rac1.oracleland.local`

**Kdump**: ❌ Disable (saves RAM) | **Root Password**: Set it (e.g., `oracle`)

3. Click **Begin Installation** → Wait (~15-20 minutes)
4. **Reboot** → Accept license

> 📸 **SNAPSHOT — "SNAP-01: OS Installed"**
> ```
> VBoxManage snapshot "rac1" take "SNAP-01_OS_Installed"
> ```

---

## 0.6 Cloning `rac1` → `rac2`

**DON'T clone now!** First complete all of **Phase 1** (OS configuration) on `rac1`, then clone. This saves you from repeating 13 configurations twice.

---

## 0.7 Standby Machines (`racstby1`, `racstby2`)

Same configuration as `rac1`/`rac2` with these differences:

| Parameter | Primary | Standby |
|---|---|---|
| VM Names | `rac1`, `rac2` | `racstby1`, `racstby2` |
| ASM Disks | `asm_crs/data/fra.vdi` | `asm_stby_crs/data/fra.vdi` |
| Public IPs | 192.168.1.101-102 | 192.168.1.201-202 |
| Private IPs | 10.10.10.1-2 | 10.10.10.11-12 |

> **IMPORTANT**: Standby ASM disks are DIFFERENT disks from primary! Each cluster has its own set.

---

## 0.8 Target Machine (`dbtarget`)

Simplest machine: single node, no RAC, no cluster.

1. **New** in VirtualBox → Name: `dbtarget` → Linux Oracle (64-bit)
2. RAM: `2048 MB` (2 GB) | CPU: 1 | Disk: 50 GB VDI
3. **Network**: Only **1 adapter** → **Bridged Adapter** (no private interconnect needed)
4. Install Oracle Linux 7.9

---

## 0.9 Recommended Work Order

```
Week 1:  Download software → rac1 setup → rac2 clone → Grid + DB (Phase 0-2)
Week 2:  Standby VMs → Phase 1-2 on standby → RMAN Duplicate (Phase 3)
Week 3:  Data Guard + GoldenGate + Backup (Phase 4-7)
```

---

> 📸 **Phase 0 Snapshot Summary**: SNAP-01 (rac1), SNAP-01-stby (racstby1), SNAP-01-target (dbtarget)

**→ Next: [PHASE 1: OS Preparation](./GUIDE_PHASE1_OS_PREPARATION.md)**
