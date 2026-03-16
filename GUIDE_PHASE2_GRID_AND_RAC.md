# PHASE 2: Installation of Grid Infrastructure and Oracle Primary RAC

> All steps in this phase refer to the **rac1** and **rac2** (Primary RAC) nodes.
> The shared storage must already be visible to both nodes before proceeding.

> 🛑 **BEFORE CONTINUING: CONNECT VIA MOBAXTERM!**
> This phase is full of scripts and graphic configurations. It is **required** to use MobaXterm with X11-Forwarding enabled. Open two tabs in MobaXterm to have both nodes at hand.
>
> **Reference IP Table (Public Network):**
> - `rac1`: 192.168.56.101
> - `rac2`: 192.168.56.102

### 📸 Visual References

![ASM Disk Groups Layout](./images/asm_diskgroups_layout.png)

![Grid Infrastructure Installer — Wizard Steps](./images/grid_installer_wizard.png)

![DBCA — RAC Database Creation](./images/dbca_create_database.png)

### What We Build in This Phase

```
╔═══════════════════════════════════════════════════════════════════════╗
║                     IL CLUSTER RAC (rac1 + rac2)                     ║
║                                                                       ║
║    ┌──────────────────────────────────────────────────────────┐       ║
║    │              Oracle Database 19c + RU + OJVM             │       ║
║    │         ┌──────────────┐  ┌──────────────┐               │       ║
║ │ │ Instance │ │ Instance │ │ ║
║    │         │  RACDB1      │  │  RACDB2      │               │       ║
║    │         │  (rac1)      │  │  (rac2)      │               │       ║
║    │         └──────┬───────┘  └──────┬───────┘               │       ║
║    └────────────────┼─────────────────┼───────────────────────┘       ║
║    ┌────────────────┼─────────────────┼───────────────────────┐       ║
║    │         Grid Infrastructure 19c + Release Update         │       ║
║    │         ┌──────┴───────┐  ┌──────┴───────┐               │       ║
║    │         │    ASM       │  │    ASM        │               │       ║
║    │         │  Instance    │  │  Instance     │               │       ║
║    │         │  (+ASM1)     │  │  (+ASM2)      │               │       ║
║    │         └──────┬───────┘  └──────┬───────┘               │       ║
║    │         Clusterware (CRS) ◄═══════════════►              │       ║
║    │           crsd, cssd, evmd, ohasd                        │       ║
║    └────────────────┼─────────────────┼───────────────────────┘       ║
║                     │                 │                               ║
║    ┌────────────────┴─────────────────┴───────────────────────┐       ║
║ │ Shared ASM Disks │ ║
║    │  ┌─────────┐     ┌──────────┐     ┌──────────┐          │       ║
║    │  │ +CRS    │     │ +DATA    │     │ +FRA     │          │       ║
║    │  │  5 GB   │     │  20 GB   │     │  15 GB   │          │       ║
║ │ │ OCR, │ │ Datafile,│ │ Archive, │ │ ║
║    │  │ Voting  │     │ Redo,    │     │ Backup,  │          │       ║
║    │  │ Disk    │     │ Control  │     │ Flashback│          │       ║
║    │  └─────────┘     └──────────┘     └──────────┘          │       ║
║    └──────────────────────────────────────────────────────────┘       ║
╚═══════════════════════════════════════════════════════════════════════╝
```

### Installation Order in This Phase

```
Step 1: ASM Disks ━━━━━━━━━━━━━━━━━━━━━━━▶ oracleasm, partitions
Step 2: cluvfy ━━━━━━━━━━━━━━━━━━━━━━━▶ check prerequisites
Step 3: Grid Infrastructure ━━━━━━━━━━━━━━━━━━━━━▶  gridSetup.sh + root.sh
Step 4: DATE + FRA ━━━━━━━━━━━━━━━━━━━━━▶ asmca / sqlplus
Step 5: Patch Grid (RU) ━━━━━━━━━━━━━━━━━━━━━▶ opatchauto (as root)
Step 6: DB Software ━━━━━━━━━━━━━━━━━━━━▶ runInstaller + root.sh
Step 7: Patch DB Home (RU+OJVM)━━━━━━━━━━━━━━━━━▶ opatchauto + opatch
Step 8: DBCA ━━━━━━━━━━━━━━━━━━━▶ create RACDB database
Step 9: datapatch ━━━━━━━━━━━━━━━━━━▶ patch dictionary
```

---

## 2.1 Shared Storage (ASM) Preparation

### Creating Shared Disks in VirtualBox

If you use VirtualBox, create disks from **Virtual Media Manager** (`Ctrl+D`):

| Disco |Size| Uso |
|---|---|---|
| `asm_crs.vdi`  | 5 GB  | OCR + Voting Disk (Clusterware) |
| `asm_data.vdi` | 20 GB | Disk Group DATA (Datafile) |
| `asm_fra.vdi`  | 15 GB | Disk Group FRA (Archive/Recovery) |

**Important properties**:
- **Fixed Size** — required for shared disks.
- After creation, select each disk → **Properties** → **Type: Shareable**.
- Add all 3 disks to the SATA controller of **both** VMs (`rac1` e `rac2`).

### Check Partitions (on rac1 as root)

The disks for ASM have already been manually partitioned in [Phase 0](./GUIDE_PHASE0_MACHINE_SETUP.md) tramite `fdisk`. Verifichiamo che le partizioni siano visibili:
```bash
lsblk
#You need to see sdc1, sdd1, sde1, sdf1, sdg1
```



---

## 2.2 Download and Preparation of Binaries

Download from the [Oracle eDelivery] site(https://edelivery.oracle.com):
- `LINUX.X64_193000_grid_home.zip` (Grid Infrastructure 19.3)
- `LINUX.X64_193000_db_home.zip` (Database 19.3)

Trasferisci i file su `rac1` (for example in `/tmp/`):

```bash
# Unpack Grid intoGRID_HOME(as grid user)
su - grid
unzip -q /tmp/LINUX.X64_193000_grid_home.zip -d /u01/app/19.0.0/grid
```

> **Why unpack directly into the GRID_HOME?** A partire da Oracle 18c, la GRID_HOME It's the software itself. There is no longer a separate "installer": unzip the zip and that becomes the home page.

---

## 2.3 CVU Disk Package Installation

> ⚠️ **ATTENZIONE**: Il file `cvuqdisk` si trova dentro la GRID_HOME that you just unpacked. Since the zip was extracted **only on `rac1`**, il path `/u01/app/19.0.0/grid/` **DOES NOT EXIST yet on `rac2`!** You must then copy the RPM file from `rac1` a `rac2` before installing it.

**Step 1: Su `rac1` (as `root`) — Install directly:**
```bash
#On rac1 the file already exists because you unpacked the Grid here
rpm -ivh /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm
```

**Step 2: Copy the RPM file to`rac2`:**
```bash
# Again from rac1, send the file to rac2 via scp
scp /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm root@rac2:/tmp/
```

**Step 3: Su `rac2` (as `root`) — Install from the copy in /tmp:**
```bash
# On rac2, install from the copy you just ported
rpm -ivh /tmp/cvuqdisk-1.0.10-1.rpm
```

> **Why cvuqdisk?** It is the Cluster Verification Utility package for disk discovery. Without this, the `runcluvfy.sh` and the Grid installer cannot find the shared disks. The Grid installer will then automatically copy all the binaries to `rac2` durante l'installazione — ma `cvuqdisk` it is needed **BEFORE** installation for pre-check.

---

## 2.3b Creare il file Oracle Inventory Pointer (`/etc/oraInst.loc`)

> ⚠️ **To be done on BOTH nodes (`rac1` e `rac2`) how `root`**, otherwise`cluvfy`fails with the error:`PRVG-10467: The default Oracle Inventory group could not be determined.`

**Why is it needed?** Oracle uses the file `/etc/oraInst.loc` to know where to save its "installation log" (the Inventory) and which Linux group owns it. This file is normally created automatically when you first install Oracle — but since you haven't installed anything yet, it doesn't exist! We have to create it by hand before launching the pre-check.

**Su `rac1` E `rac2`, as a user `root`:**

```bash
#1. Create the pointer file that tells Oracle where the Inventory is
cat > /etc/oraInst.loc <<'EOF'
inventory_loc=/u01/app/oraInventory
inst_group=oinstall
EOF

#2. Correct permissions on the file
chown root:oinstall /etc/oraInst.loc
chmod 644 /etc/oraInst.loc

#3. Create the Inventory directory (if it doesn't already exist)
mkdir -p /u01/app/oraInventory
chown grid:oinstall /u01/app/oraInventory
chmod 775 /u01/app/oraInventory

#4. Check
cat /etc/oraInst.loc
ls -ld /u01/app/oraInventory
```

## 2.3c Cleaning "Ghostly" Network Interfaces (Pre-Requisite for cluvfy)

> 🛑 **This step is MANDATORY before launching the cluvfy pre-check!**
> If you don't, cluvfy will report connectivity errors that have nothing to do with your RAC: virtual interfaces with duplicate IPs, IPv6 unreachable, useless bridge. These errors are confusing and scary, but the solution is simple.

### The Problem: What cluvfy sees (and what it should NOT see)

Quando lanci `cluvfy`, Oracle scans **ALL** network interfaces on the system, not just the ones the RAC will use. In our VM, after the clone, there are **4 active interfaces**, but Oracle only uses 2 of them:

```
╔══════════════════════════════════════════════════════════════════════════╗
║ NETWORK INTERFACES ON THE VM ║
╠═══════════╦══════════════════╦═══════════════════════════╦═════════════╣
║ Interface ║ IP ║ Role ║ Is it needed by RAC?║
╠═══════════╬══════════════════╬═══════════════════════════╬═════════════╣
║ enp0s8 ║ 192.168.56.x ║ 🌐 PUBLIC Network ║ ✅ YES ║
║ enp0s9 ║ 192.168.1.x ║ 🔗 INTERCONNECT private ║ ✅ YES ║
╠═══════════╬══════════════════╬═══════════════════════════╬═════════════╣
║ enp0s3    ║ 10.0.2.15        ║ NAT VirtualBox (internet) ║ ❌ NO       ║
║ virbr0    ║ 192.168.122.1    ║ Bridge libvirt (KVM)      ║ ❌ NO       ║
╚═══════════╩══════════════════╩═══════════════════════════╩═════════════╝
```

The two "useless" interfaces cause 3 specific errors:

| Errore cluvfy | Causa |Interface|
|---|---|---|
| `PRVG-1172`: Duplicate IP on multiple nodes | VirtualBox NAT gives `10.0.2.15` to ALL VMs | `enp0s3` |
| `PRVG-1172`: Duplicate IP on multiple nodes | `libvirtd` crea `192.168.122.1` on ALL VMs | `virbr0` |
| `PRVG-11891`: IPv6 non raggiungibile | Self-configured IPv6 on NAT does not know how to reach the other VM | `enp0s3` (IPv6) |

### Is it Oracle Best Practice? YES!

The Oracle documentation (MOS Doc ID 1585184.1 — "Grid Infrastructure Preinstallation Steps") explicitly recommends:
- **Disable unnecessary network interfaces** before installing Grid
- **Disable IPv6** if it is not used in the cluster (99% of labs don't use it)
- **Remove virtual bridges** as `virbr0` che non partecipano al cluster

The reason is that during installation, Grid Infrastructure **enumerates all interfaces** to decide which ones to use for the Cluster Interconnect and which ones for the public grid. Extra interfaces with duplicate or unreachable IPs can cause **errors not only in the pre-check, but also in the installer itself**.

### Commands to execute

**Su `rac1` e `rac2`, as a user `root`:**

```bash
# ============================================================
#1. DELETE virbr0 (libvirt/KVM bridge — not needed by RAC)
# ============================================================
#virbr0 is created by the libvirtd daemon, which is used to manage
#KVM virtual machines *inside* the VM itself.
# In our lab we will never do VM-in-VM, so we disable it.
systemctl stop libvirtd
systemctl disable libvirtd
ip link set virbr0 down
brctl delbr virbr0 2>/dev/null

#Check: virbr0 should no longer appear
ip addr show virbr0 2>&1
# Deve dire: "Device virbr0 does not exist."

# ============================================================
# 2. DISABILITA IPv6 SULLA NAT (enp0s3)
# ============================================================
# Auto-configured IPv6 on VirtualBox NAT generates addresses
# Different IPv6 on each VM, but they are NOT reachable to each other
#because NAT is isolated. Cluvfy tries to ping IPv6 and fails.
echo "net.ipv6.conf.enp0s3.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

#Check: enp0s3 should no longer show "inet6" addresses
ip -6 addr show enp0s3
# Must be empty or show only link-local

# ============================================================
# 3. (OPZIONALE) NOTA SULL'INTERFACCIA NAT (enp0s3)
# ============================================================
#The enp0s3 interface (10.0.2.15) is used to give internet to
# VM (package download, yum update). We do NOT disable it
#because we need it, but cluvfy will still give a WARNING because
#both VMs have the same IP 10.0.2.15 on the NAT.
#This WARNING is HARMLESS: Oracle will never use this network.
```

> 💡 **Why don't we disable it too `enp0s3`?** Because it is the only interface that gives Internet access to VMs (for `yum install`, download patch, ecc.). Il Warning di cluvfy sull'IP duplicato `10.0.2.15` is harmless: during Grid installation, we will choose manually `enp0s8` as a public network e `enp0s9` like interconnect. Oracle will never touch NAT.

---

## 2.3d Pre-Grid: Host Sync Block + Chrony hardening (MANDATORY)

Before building the Grid software, block the time synchronization imposed by the hypervisor and leave control of the time to `chronyd`.

Because: in the lab there is a "time war":
1. `chronyd`Inside Linux synchronizes time with NTP.
2. VirtualBox Guest Additions prova a riallineare l'ora al clock dell'host.
3. After reboot the hypervisor wins, the time skips and `cluvfy`/Grid possono segnalare errori NTP.

### 1) VirtualBox-first: disabilita time sync guest su `rac1` e `rac2`

Run on both nodes as `root`:

```bash
#Disable VBox services that can force the guest clock
if systemctl list-unit-files | grep -q '^vboxadd-service.service'; then
  systemctl disable --now vboxadd-service
fi

if systemctl list-unit-files | grep -q '^vboxservice.service'; then
  systemctl disable --now vboxservice
fi

#Check (if they don't exist it's normal)
systemctl is-enabled vboxadd-service 2>/dev/null || true
systemctl is-active vboxadd-service 2>/dev/null || true
systemctl is-enabled vboxservice 2>/dev/null || true
systemctl is-active vboxservice 2>/dev/null || true
```

Quick note other hypervisors:
- VMware: disattiva "Synchronize guest time with host" nelle opzioni VM.
- Proxmox/KVM: disable equivalent guest-side time sync policy, then leave alone`chronyd`.

### 2) Hardening Chrony su `rac1` e `rac2`

Run on both nodes as `root`:

```bash
# Set makestep to immediately fix drift >1s in the first 3 updates
if grep -q '^makestep' /etc/chrony.conf; then
  sed -i 's/^makestep.*/makestep 1.0 3/' /etc/chrony.conf
else
  echo 'makestep 1.0 3' >> /etc/chrony.conf
fi

systemctl enable chronyd
systemctl restart chronyd
sleep 8

chronyc sources -v
chronyc tracking
timedatectl
```

### 3) Persistence test after reboot (MANDATORY)

Su `rac1` e `rac2`:

```bash
reboot
```

After logging in on each node:

```bash
#Verify that VBox time sync remains disabled
systemctl is-active vboxadd-service 2>/dev/null || true
systemctl is-active vboxservice 2>/dev/null || true

#Check Chrony sync
chronyc sources -v
chronyc tracking
timedatectl
```

PASS/FAIL criterion:
- PASS: `chronyc tracking` mostra `Leap status     : Normal`.
- PASS: `chronyc sources -v` mostra almeno una sorgente valida (`*` o `+`).
- FAIL: `Leap status : Not synchronised`on one of the two nodes.

### 4) Advancement gate towards Grid

Go ahead with`2.4` (cluvfy) e `2.5`(Grid installation) only if both nodes are synchronized.

Important note:
- warning su NAT duplicata `10.0.2.15` (`enp0s3`) is benign in the VirtualBox lab and is separate from the NTP issue.

---

## 2.4 Pre-Check con Cluster Verification Utility

```bash
#As a grid user on rac1
su - grid
cd /u01/app/19.0.0/grid

./runcluvfy.sh stage -pre crsinst \
    -n rac1,rac2 \
    -verbose
```

> **What to expect?** The pre-check will probably report **FAILED** on:
> - **RAM** (7.49 GB instead of 8 GB) — this is normal in VirtualBox, the kernel reserves ~500 MB
> - **duplicate IP 10.0.2.15** — is the VirtualBox NAT, identical on each VM by design
>
> **Questi warning NON sono bloccanti!** Il `cluvfy` it's just a "consultant" who warns you. The real gate is the installer (`gridSetup.sh`), which will show you the same warnings but will have an **"Ignore All" checkbox** at the bottom left to proceed.
> **Importante**: questo vale per RAM/NAT; gli errori NTP (`PRVF-4664`) and SSH equivalence must be resolved before the Grid.
>
> **If you can afford it**, increase VM RAM to **9216 MB (9 GB)** in VirtualBox to eliminate the RAM warning.

### Errori da risolvere vs Warning da ignorare

| Errore | Tipo | Azione |
|---|---|---|
| `PRVF-7530`: RAM insufficiente | ⚠️ Warning |Proceed — installer says "Ignore All" (or raise RAM to 9GB)|
| `PRVG-1172`: Duplicate IP 10.0.2.15| ⚠️ Warning | Harmless — it's VirtualBox NAT, Oracle doesn't use it |
| `PRVG-11250`: RPM Database check | ℹ️ Info | Ignorable (you need root for this check) |
| `PRVF-4664`: NTP not configured| ❌ Errore | Applica `2.3d` (blocco sync host + hardening Chrony) e rilancia cluvfy |
| SSH user equivalence FAILED | ❌ Errore | Repeat SSH setup (Step 1.12) |

---

## 2.5 Grid Infrastructure Installation

### GUI method (Recommended for learning)

> ⚠️ **ATTENTION MOBAXTERM**: This step launches a graphical interface (GUI). The only way to see it from your Windows PC is to be logged in `rac1` via **MobaXterm** with the checkmark on **X11-Forwarding** (see Phase 0.12). 
> If you are connected from the VirtualBox black console or from a Putty without Xming, the command will fail saying "Display not set".

```bash
#As a grid user on rac1 (connected via MobaXterm)
# The DISPLAY is usually set automatically by MobaXterm.
#If you have problems, please check with`echo $DISPLAY`(should give you something like localhost:10.0)

# Start the installer
cd /u01/app/19.0.0/grid
./gridSetup.sh
```

### Step-by-Step dell'Installer GUI

**Step 1 — Configuration Option**:
- Seleziona: **Configure Oracle Grid Infrastructure for a New Cluster**

> This option installs Clusterware + ASM from scratch.

**Step 2 — Cluster Configuration**:
- Select: **Configure an Oracle Standalone Cluster**

> Standalone = a "normal" cluster (not Domain Services Cluster, which is for cloud/large infrastructure).

**Step 3 — Cluster Name e SCAN**:
- Cluster Name: `rac-cluster`
- SCAN Name: `rac-scan.localdomain`  
- SCAN Port: `1521`

> **The SCAN name must exactly match the one in the DNS!** The installer checks the DNS at this time.

**Step 4 — Cluster Nodes**:
- Aggiungi `rac2`by clicking "Add":
  - Public Hostname: `rac2.localdomain`
  - Virtual Hostname: `rac2-vip.localdomain`
- `rac1` will already be present:
  - Virtual Hostname: `rac1-vip.localdomain`
- Click **SSH Connectivity** → enter password `grid` → **Setup**
- Click **Test** to verify connectivity

**Step 5 — Network Interface Usage**:

> ⚠️ **ATTENZIONE**: Le interfacce si chiamano `enp0sX`, NON `eth0`/`eth1`! Configure like this:

| Interface | Subnet | Use for |
|---|---|---|
| `enp0s3` | 10.0.2.0 | ❌ **Do Not Use** (it's the NAT VirtualBox) |
| `enp0s8` | 192.168.56.0 | ✅ **Public** |
| `enp0s9` | 192.168.1.0 | ✅ **ASM & Private** |

![Step 5 - Network Interface Usage](./images/grid_network_interface_usage.png)

> **Why this configuration?**
> - `enp0s8` (192.168.56.0) → It is the **public** (Host-Only) network. Clients connect to the database across this network via SCAN.
> - `enp0s9` (192.168.1.0) → It is the **private** network (Internal Network). **Cache Fusion** transits here: copies of data blocks between nodes. NEVER mix it with the public network!
> - `enp0s3` (10.0.2.0) → It is VirtualBox's NAT (for Internet access). Oracle doesn't have to use it: every VM has the same IP `10.0.2.15` and they cannot communicate with each other over this network.

**Step 6 — Storage Option**:
- Seleziona: **Use Oracle Flex ASM for Storage**

**Step 7 — Grid Infrastructure Management Repository**:
- Select: **No** (we don't need the GIMR for a lab)

**Step 8 — Create ASM Disk Group** (per OCR e Voting Disk):

![Step 8 - Create ASM Disk Group — All 5 ASMLib disks visible](./images/grid_asm_disk_group.png)

**Step-by-step procedure:**

1. **Disk Group Name**: `CRS`
2. **Redundancy**: Select **Normal**
3. **Allocation Unit Size**: leave`4 MB` (default)
4. **Discovery Path**: clicca **"Change Discovery Path..."** e scrivi:
   ```text
   /dev/oracleasm/disks/*
   ```
5. **Select ONLY these 3 discs** (check ☑️):
   - ☑️ `/dev/oracleasm.../CRS1` (2047 MB)
   - ☑️ `/dev/oracleasm.../CRS2` (2047 MB)
   - ☑️ `/dev/oracleasm.../CRS3` (2047 MB)
6. **NON selezionare** `DATA` e `RECO`! You will use them later to create separate disk groups
7. **DO NOT select** "Configure Oracle ASM Filter Driver" (we use ASMLib, not AFD)
8. Click **Next**

> ⚠️ **Why NOT select DATE and RECO here?**
> Questo step crea il disk group `CRS` which will contain **only** the cluster metadata (OCR and Voting Disk). Disk groups `DATA` (per i datafile del database) e `RECO` (for RMAN backups and archived logs) will be created separately after Grid installation, with the tool `asmca` or via SQL. Mixing everything into one disk group is a violation of Oracle best practices!

### Why these choices? (Oracle Best Practices)

| Parametro | Scelta | Why |
|---|---|---|
| **Disk Group** | `CRS` separato da `DATA` e `RECO` |Oracle recommends separating cluster metadata from database data (MOS Doc 1373437.1). If the DATA disk group becomes corrupt, the cluster remains up.|
| **Redundancy** | Normal | Oracle requires **at least 3 Voting Disks** for quorum (majority voting). Normal = 3 disks, if you lose 1 the cluster stays up (2 out of 3). High = 5 discs. |
| **Allocation Unit** | 4 MB | Default Oracle is recommended for small disk groups like CRS (contains only a few MB of metadata). |
| **Discovery Path** | `/dev/oracleasm/disks/*` | We use the physical path of the operating system instead of the alias `ORCL:*`. Questo aggira un bug noto dell'installer (PRVG-11800) dove il check `cluvfy` in background fallisce nel caricare la libreria `oracleasmlib` da remoto. Passando il path OS diretto, l'installer usa i permessi standard Linux (`grid:asmadmin`) e non fallisce mai. |

**Step 9 — ASM Password**:

![Step 9 - Specify ASM Password](./images/grid_asm_password.png)

- Select: **"Use same passwords for these accounts"** (as in the screenshot)
- Enter your password in both "Specify Password" and "Confirm Password"
- In our lab we use the same password for all accounts (e.g. `oracle`) for simplicity

> ⚠️ **Warning INS-30011**: The installer displays a yellow warning that says *"The password entered does not conform to the Oracle recommended standards"*. This is because Oracle in production requires passwords of **at least 8 characters** with uppercase, lowercase, numbers and special characters (e.g. `Orcl_2024#`).
>
> **For the lab**: ignore the warning and click **Next → Yes**. Simple password works.
>
> **In Production (Oracle Best Practices)**: Use separate passwords for `SYS` e `ASMSNMP`, with a minimum complexity of 8 characters, and save them in a password vault (such as Oracle Key Vault). The user `ASMSNMP` it is used by Enterprise Manager to monitor ASM — in production it must not have the same password as `SYS`.

**Step 10 — IPMI**:
- Select: **Do not use IPMI**

**Step 11 — EM Registration**:
- Deseleziona: **Register with Enterprise Manager**

**Step 12 — OS Groups**:
- OSASM Group: `asmadmin`
- OSDBA for ASM: `asmdba`
- OSOPER for ASM: `asmoper`

**Step 13 — Installation Locations**:
- Oracle Base: `/u01/app/grid`
- Software Location: `/u01/app/19.0.0/grid`

**Step 14 — Root Script Execution**:
- **DESELECT** "Automatically run configuration scripts"
- We'll run them manually, one at a time, to understand what they do

**Step 15 — Prerequisite Checks**:

![Step 15 - Prerequisite Checks - Ignorare RAM, ma risolvere ASM](./images/grid_prereq_checks.png)

The installer will run a `cluvfy` internal. Here's how to interpret the results:

| Check |Result| What to do |
|---|---|---|
| **Physical Memory** (PRVF-7530) | ⚠️ Warning | **Ignore it**. You have 7.5 GB instead of 8 GB. This is normal in VirtualBox. |
| **RPM Package Manager** (PRVG-11250) | ℹ️ Info |**Ignore it**. Root is missing for this check.|
| **Network Interface** (PRVG-1172) | ⚠️ Warning |**Ignore this** only if it concerns IP NAT`10.0.2.15`. |
| 🛑 **Device Checks for ASM** (PRVG-11800) | ❌ Se **FAILED** | **YOU MUST FIX IT!** (See below) |

> 🛠️ **Troubleshooting: Errore PRVG-11800 (Failed to discover any devices...)**
> If you followed the guide but still get this FAILED, you've run into a **known installer bug on Oracle Linux 7**: background check (`cluvfy`) a volte non riesce a caricare la libreria `libasm.so` per risolvere l'alias `ORCL:*`, even if the GUI showed them to you in Step 8!
> 
> **The solution (official workaround):**
> 1. Clicca **Back** fino a tornare allo **Step 8 (Create ASM Disk Group)**.
> 2. Click **"Change Discovery Path..."** and write the native Linux path:`/dev/oracleasm/disks/*`
> 3. Click OK. The disks will appear with the new path. Select ONLY the three CRS1, CRS2, CRS3.
> 4. Go **Next** until you return to this Step 15. Now the check will pass using native filesystem permissions!

**If all FAILEDs are resolved (and only Warnings remain):**
- Check the **"Ignore All"** box at the top right.
- Clicca **Next → Yes** per proseguire.

The installer will stop at **Step 17** and show you a pop-up asking you to run 2 scripts like `root`.

![Execute Configuration Scripts](./images/grid_root_scripts.png)

> 🛑 **ATTENTION:** RUN THE SCRIPTS **ONE AT A TIME**, first on `rac1`, e **SOLO QUANDO HA FINITO** passali su `rac2`. If you run them in parallel, the cluster will be irremediably corrupted!

**Su `rac1` (as root)**:

```bash
/u01/app/oraInventory/orainstRoot.sh
```

> This script records the Central Inventory (oraInventory). It only needs to be done once.

```bash
/u01/app/19.0.0/grid/root.sh
```

> 💡 **What to answer to the prompt?**
> Once launched, the script will ask: `Enter the full pathname of the local bin directory: [/usr/local/bin]:`
> Simply press **Enter** to accept the default.
>
> **This is the most important script of the entire installation**. Executes:
> - Configura Oracle Clusterware (CRS) e OHAS
> - Create the CRS daemon (`crsd`, `cssd`, `evmd`)
> - Initialize the ASM disk group`CRS`
> - Start the cluster on this node
>
> **WAIT (this will take 5-10 minutes)** for it to finish completely and return to the command prompt before moving on to node 2!

**On rac2 (as root)**:

```bash
/u01/app/oraInventory/orainstRoot.sh
/u01/app/19.0.0/grid/root.sh
```

> On node 2, `root.sh` will add this node to the existing cluster (created from node 1).

Return to the installer GUI and click **OK** to complete the step.

The installer will perform a final automatic check (`stage -post crsinst`).

> 🛠️ **Troubleshooting: Errore PRVG-13606 (NTP/Chrony non sincronizzato)**
> Se il check finale fallisce con l'errore `chrony daemon is not synchronized with any external time source`, return to the section `2.3d` and realign time first.  
> **Solution:**
> 1. Apri un terminale `root` on the node indicated in the error (e.g. `rac2`).
> 2. Check that in `/etc/chrony.conf` ci sia `makestep 1.0 3`.
> 3. Run:`systemctl restart chronyd` e poi `chronyc tracking`.
> 4. Conferma `Leap status : Normal`.
> 5. Return to the installer GUI and click **Retry**.



---

### 🚨 TROUBLESHOOTING: What to do if the installation fails?

Se l'esecuzione di `root.sh` fails (e.g. due to SSH timeouts, network problems or badly formatted disks), the cluster remains halfway through configuration. If you try to raise `root.sh` o `gridSetup.sh`, you will get an error because the files are already there. 

**To clean up the failed installation and try again (do as `root`):**
```bash
#On the node where it failed (or on both if necessary)
/u01/app/19.0.0/grid/crs/install/rootcrs.sh -deconfig -force
```
> This script "unmounts" the cluster, cleans the interfaces, kills the daemons and resets the ASM disks (headers included) allowing you to start again cleanly.

---

## 2.6 Cluster Verification

```bash
#Like root or grid
# General status of the cluster
crsctl stat res -t

# Elenco nodi
olsnodes -n

# CRS Status (must be all ONLINE)
crsctl check crs

#Check ASM
su - grid
asmcmd lsdg
# Dovrai vedere il disk group CRS
```

Expected output of`crsctl check crs`:
```
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
```

> If you see everything ONLINE, your cluster is alive! 🎉

---

## 2.6b 📸 Security Snapshot (MILESTONE: SNAP-05)

This is the perfect time to "freeze" your car. You have a formatted and working Oracle 19c cluster, but still no database. If you make a mistake creating the data disk groups or database, you can come back here and try again without having to reinstall the entire Grid.

**Hot/Cold Snapshot Procedure:**

1. **Shut down the cluster cleanly (on`rac1` as root):**
   ```bash
   /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
   ```
   *Wait for all services (ASM, GNS, VIP, etc.) to go offline on both nodes.*

2. **Turn off the machines:**
   ```bash
   # Su rac1
   shutdown -h now
   # Su rac2
   shutdown -h now
   ```

3. **In VirtualBox, crea lo snapshot per ENTRAMBE le VM:**
   - Nome: `SNAP-05: Grid_Install_OK`
   - Description: "Grid Infrastructure 19c installed successfully. CRS active on 3 disks. No database created."

4. **Turn the machines back on** and wait a few minutes for the cluster to restart automatically at boot.

---

## 2.7 Creation of Disk Group DATA and RECO

Now that the cluster is active (and protected by snapshots), let's create the disk groups to host the actual database data:

```bash
#As a grid user (you can do it from any node, e.g. rac1)
su - grid
asmca
```

*(Con `asmca` the graphical interface will guide you in the creation. Remember to select disks using the Discovery Path `/dev/oracleasm/disks/*` se non li vedi!).*

**Or from sqlplus command line (faster):**

```sql
#As a grid user
su - grid

--Connect to local ASM instance (+ASM1)
sqlplus / as sysasm

--Create disk group DATA (We use the physical path as done in the installer!)
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY
  DISK '/dev/oracleasm/disks/DATA'
  ATTRIBUTE 'compatible.asm' = '19.0.0.0.0',
            'compatible.rdbms' = '19.0.0.0.0';

-- Crea disk group RECO
CREATE DISKGROUP RECO EXTERNAL REDUNDANCY
  DISK '/dev/oracleasm/disks/RECO'
  ATTRIBUTE 'compatible.asm' = '19.0.0.0.0',
            'compatible.rdbms' = '19.0.0.0.0';

--Verify
SELECT name, state, type, total_mb, free_mb FROM v$asm_diskgroup;

EXIT;
```

```bash
#Check from asmcmd
asmcmd lsdg
# You will need to see: CRS, DATA, RECO all MOUNTED
```

> **Why create separate DATA and RECO?** DATA contains the datafiles (the real data). The Fast Recovery Area (located in the RECO disk group) contains archivelogs, RMAN backups and flashback logs. Separating them is a fundamental best practice: if the DATA disk fills up, you still have space for recovery.

---

## 2.8 Patching Grid Infrastructure (Release Update)

> **Why patch?** Oracle 19c base (19.3) is the initial version released in 2019. Release Updates (RUs) contain security fixes, bug fixes, and stability improvements. In production, patching is **required**. In the lab, it teaches you the process you will use in the real world.

The patches you need (already present in your downloads):

| Patch |Description|Where it applies|
|---|---|---|
| **p6880880** | **OPatch** (utility per applicare patch) |Replace in everyORACLE_HOME |
| **p38658588** | **Combo Patch (GI RU + OJVM RU)** — Jan 2026 | Grid Home + DB Home |

### Step 1: Update OPatch in Grid Home

OPatch is the tool that applies patches. The version shipped with the base software 19.3 is too old. You must update it BEFORE applying any patches.

```bash
#⚠️ As ROOT on rac1 (OPatch directory has owner root after installation!)
su - root

#Backup of the old OPatch
mv /u01/app/19.0.0/grid/OPatch /u01/app/19.0.0/grid/OPatch.bkp.$(date +%Y%m%d)

# Unpack the new OPatch
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.0.0/grid/

#Put the correct permissions back to the grid user
chown -R grid:oinstall /u01/app/19.0.0/grid/OPatch

#Check version (back to grid)
su - grid
$ORACLE_HOME/OPatch/opatch version
# Deve mostrare: OPatch Version: 12.2.0.1.48 (o superiore per patch Gennaio 2026)
```

> **Why as root?** After installing Grid Infrastructure, the script `root.sh` change ownership of some Grid Home directories to `root`. La directory `OPatch` is among these, therefore the `mv` as a user `grid` will fail with "Permission denied".

> **⚠️ ATTENZIONE (Patch Gennaio 2026)**: Se stai applicando la Release Update di Gennaio 2026 (o successive), l'utility `opatch` **must** be at least version **12.2.0.1.48**. If you use an older version (e.g. .43 or .47), `opatchauto` will fail with error `CheckMinimumOPatchVersion`.

> **How ​​to download from MOS**: Go to [support.oracle.com](https://support.oracle.com) → Patches & Updates → cerca **6880880** → seleziona la piattaforma (`Linux x86-64`) e la versione **19.0.0.0**. Il numero `190000` in the file name indicates the database version (19c). Don't confuse with p6880880_**230000** which is for Oracle **23c**!

```bash
#Repeat on rac2 (still as root!)
ssh rac2
su - root
mv /u01/app/19.0.0/grid/OPatch /u01/app/19.0.0/grid/OPatch.bkp.$(date +%Y%m%d)
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.0.0/grid/
chown -R grid:oinstall /u01/app/19.0.0/grid/OPatch
su - grid
$ORACLE_HOME/OPatch/opatch version
```

### Step 2: Unpack the Combo Patch

> ⚠️ **ATTENZIONE**: NON scompattare la patch in `/tmp`! Nelle nostre VM, `/tmp` it is a RAM disk (tmpfs) of only 4GB. The extracted patch takes up more than 3GB, filling up `/tmp` to 100% and blocking the node. Always use `/u01` che ha 50GB di spazio!

```bash
#Unzip to rac1 (as root)
mkdir -p /u01/app/patch
cd /u01/app/patch
unzip -q /tmp/p38658588_190000_Linux-x86-64.zip
chown -R grid:oinstall /u01/app/patch

# Identify RU IDs within the Combo Patch:
ls -l /u01/app/patch/38658588
# You will see two numeric folders: one for OJVM (38523609) and one for the actual RU (38629535).
# Useremo il path 38629535 per opatchauto! 

# Repeat extraction on rac2!
#(The /u01 folder is not shared, so the patch must physically exist on both nodes)
ssh rac2
mkdir -p /u01/app/patch
cd /u01/app/patch
unzip -q /tmp/p38658588_190000_Linux-x86-64.zip
chown -R grid:oinstall /u01/app/patch
exit
```

### Step 3: Apply RU to Grid Home with opatchauto

> ⚠️ **Oracle Best Practice (MOS 2632107.1)**: Before applying any patch, ALWAYS run:
> 1. **Conflict check** — checks that there are no conflicts with patches already applied
> 2. **Space check** — checks for sufficient disk space  
> 3. **Backup dell'ORACLE_HOME** — to be able to rollback in case of problems

```bash
#As root on rac1
su - root

#--- BEST PRACTICE 1: Check disk space (you need at least 15 GB in /u01) ---
df -h /u01
#If you have less than 15 GB free, free up space before continuing!

# --- BEST PRACTICE 2: Backup dell'ORACLE_HOME (per rollback) ---
tar czf /u01/app/grid_home_backup_$(date +%Y%m%d).tar.gz -C /u01/app/19.0.0 grid --exclude='*.log'

# --- BEST PRACTICE 3: Pre-check with opatchauto analyze (dry run without applying!) ---
cd /u01/app/patch/38658588/38629535
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME -analyze
# Replace 38629535 with the real ID of the RU you found in step 2!
#If it shows conflict errors, resolve them BEFORE applying!
# Se mostra "Patch analysis is complete" → puoi proseguire.

#--- REAL APPLICATION (only after analyze is OK) ---
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME
```

> **Why opatchauto?** For Grid Infrastructure, you can't use plain `opatch apply`. You have to use `opatchauto` (as root), which:
> 1. Stop CRS automatically
> 2. Apply the patch
> 3. Restart the CRS
> It does everything in one go, even managing cluster service dependencies.

```bash
#Verify that the CRS has restarted
crsctl check crs
# Must show everything ONLINE

#Check the applied patch
su - grid
$ORACLE_HOME/OPatch/opatch lspatches
# Must show the RU patch number
```

```bash
#Repeat on rac2 as root
ssh rac2
cd /u01/app/patch/38658588/38629535
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME

#Verify
crsctl check crs
su - grid
$ORACLE_HOME/OPatch/opatch lspatches
```

> 📸 **SNAPSHOT — "SNAP-04: Grid_Installed_and_Patched" ⭐ MILESTONE**
> The cluster is active and updated to the latest Release Update. Reinstalling it would take hours. If the RDBMS Database installation fails, you can return here.
> ```bash
> VBoxManage snapshot "rac1" take "SNAP-04: Grid_Installato_e_Patchato"
> VBoxManage snapshot "rac2" take "SNAP-04: Grid_Installato_e_Patchato"
> ```

---

## 2.9 Installazione Software Database

```bash
#As an oracle user
su - oracle

# Unpack the DB into theORACLE_HOME
unzip -q /tmp/LINUX.X64_193000_db_home.zip -d $ORACLE_HOME
#Check the oracle user groups and assign the missing groups if necessary
id oracle 
usermod -g oinstall -G dba,asmdba,backupdba,dgdba,kmdba,racdba,oper oracle
id oracle
# Start the installer
cd $ORACLE_HOME
export DISPLAY=<IP_del_tuo_PC>:0.0
./runInstaller
```

### Step dell'Installer GUI

**Step 1**: Seleziona **Set Up Software Only**

> We ONLY install the tracks. We create the database later with DBCA. This is the professional method: first you install, then you build.

**Step 2**: Select **Oracle Real Application Clusters database installation**

**Step 3**: Select both nodes (`rac1`, `rac2`)

**Step 4**: Select **Enterprise Edition**

**Step 5**: Check the paths:
- Oracle Base: `/u01/app/oracle`
- Software Location: `/u01/app/oracle/product/19.0.0/dbhome_1`

**Step 6**: OS Groups:
- OSDBA: `dba`
- OSOPER: `oper`
- OSBACKUPDBA: `backupdba`
- OSDGDBA: `dgdba`
- OSKMDBA: `kmdba`
- OSRACDBA: `racdba`

**Step 7**: Uncheck automatic execution of root scripts

**Step 8**: Rivedi Summary e clicca **Install**

### Executionroot.sh

**On rac1 as root:**

```bash
/u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```

**On rac2 as root:**

```bash
/u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```



---

## 2.11 Patching Database Home (Release Update + OJVM)

> [!IMPORTANT]
> **ORDER OF OPERATIONS**: You must update the OPatch utility **BEFORE** launching `opatchauto apply`. If you try to apply the January 2026 RU with an older OPatch (version < 12.2.0.1.48), the operation will fail.

### Step 1: Update OPatch in the Home DB

```bash
#⚠️ As ROOT on rac1 (even the DB Home OPatch can have owner root afterroot.sh)
su - root

#Backup of the old OPatch
mv /u01/app/oracle/product/19.0.0/dbhome_1/OPatch /u01/app/oracle/product/19.0.0/dbhome_1/OPatch.bkp.$(date +%Y%m%d)

# Unpack the new OPatch
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/dbhome_1/

#Return the correct permissions to the oracle user
chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1/OPatch

#Verify (return to oracle)
su - oracle
$ORACLE_HOME/OPatch/opatch version

#Repeat on rac2 (as root!)
ssh rac2
su - root
mv /u01/app/oracle/product/19.0.0/dbhome_1/OPatch /u01/app/oracle/product/19.0.0/dbhome_1/OPatch.bkp.$(date +%Y%m%d)
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/dbhome_1/
chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1/OPatch
su - oracle
$ORACLE_HOME/OPatch/opatch version
```

### Step 2: Apply the RU to the Home DB

```bash
#As root on rac1
su - root

# Cambia ownership della patch directory a oracle, altrimenti opatchauto fallisce (OPATCHAUTO-72083)
chown -R oracle:oinstall /u01/app/patch

# Backup DB Home (Best Practice)
tar czf /u01/app/dbhome_backup_$(date +%Y%m%d).tar.gz -C /u01/app/oracle/product/19.0.0 dbhome_1 --exclude='*.log'

# Pre-check (dry run)
cd /u01/app/patch/38658588/38629535
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME -analyze

# Se analyze OK → applica
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME
```

> **Nota**: `opatchauto` automatically recognizes that it is a Home DB in a RAC cluster and handles patching accordingly.

```bash
# Ripeti su rac2
ssh rac2 "chown -R oracle:oinstall /u01/app/patch"
ssh rac2
cd /u01/app/patch/38658588/38629535
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME
```

### Step 3: Applica il Patch OJVM

The OJVM patch is bundled inside the Combo Patch. We have already unpacked everything in Step 2 of Grid, so the files are already ready in `/u01/app/patch/38658588/`. Si applica con `opatch apply` standard puntando alla sottocartella OJVM.

```bash
#As an oracle user on rac1
su - oracle
cd /u01/app/patch/38658588/38523609 # Use the real ID of the OJVM folder found before
$ORACLE_HOME/OPatch/opatch apply

# Quando chiede "Is the local system ready for patching?" rispondi: y

# Ripeti su rac2
ssh rac2
su - oracle
cd /u01/app/patch/38658588/38523609
$ORACLE_HOME/OPatch/opatch apply
```

> **Why is OJVM applied like this?** The OJVM (Oracle's internal Java Virtual Machine) is patched using classic `opatch apply` directly on the DB Home, unlike the Grid/DB engine which requires `opatchauto` to manage system lock/unlock. After applying it, the first time you start the database you will have to run `datapatch`.

### Step 4: Check Applied Patches and Cleaning

```bash
#Like oracle on rac1
$ORACLE_HOME/OPatch/opatch lspatches
```

Output atteso:
```
38629535;Database Release Update : 19.x.0.0.xxxxxx 
38523609;OJVM RELEASE UPDATE: 19.x.0.0.xxxxxx 
```

Once finished, remember to free up disk space by deleting the unzipped patch as `root`:
```bash
su - root
rm -rf /u01/app/patch/*
rm -f /tmp/p*.zip
# Ripeti su rac2
```
```

### Step 5: datapatch (after DB creation)

> **IMPORTANTE**: `datapatch`it must be performed AFTER creating the database with DBCA (next section). Don't run it now — you don't have a database yet!
> After DBCA, run:

```bash
# Like oracle, AFTER creating the database
su - oracle
$ORACLE_HOME/OPatch/datapatch -verbose
```

> **What is datapatch?** `opatch` update binaries (.o files, libraries). But some patches also require changes to the Data Dictionary (Oracle's internal tables). `datapatch` apply these SQL changes to the database. Without datapatch, the patch is only half applied.

```sql
-- Verify that datapatch was successful
SELECT patch_id, patch_uid, action, status, description
FROM dba_registry_sqlpatch
ORDER BY action_time DESC;
-- Must show SUCCESS for both patches
```

> 📸 **SNAPSHOT — "SNAP-05: DB_Software_Installato"**
> Database binaries are installed and fully patched with RU + OJVM. Ready for DBCA.
> ```bash
> VBoxManage snapshot "rac1" take "SNAP-05: DB_Software_Installato"
> VBoxManage snapshot "rac2" take "SNAP-05: DB_Software_Installato"
> ```

---

## 2.12 Creation of RAC Database with DBCA

> ⚠️ **ATTENZIONE MOBAXTERM**: Anche `dbca`launches a graphical interface (GUI). You must be connected to`rac1`via **MobaXterm** with the checkmark on **X11-Forwarding** (see Phase 0.12).

```bash
# As an oracle user on rac1 (connected via MobaXterm)
su - oracle
# The DISPLAY is usually set automatically by MobaXterm.
dbca
```

### Step dell'Installer GUI

**Step 1**: **Create a database**

**Step 2**: **Advanced Configuration** (to have full control)

**Step 3**: Database Type:
- **Oracle RAC database**
- Select both nodes

**Step 4**: Template:
- **Custom Database** (for maximum control)

**Step 5**: Database Identification:
- Global Database Name: `RACDB`
- SID Prefix: `RACDB`(will become RACDB1 on rac1, RACDB2 on rac2)
<img width="795" height="587" alt="image" src="https://github.com/user-attachments/assets/6abf8a34-a666-45cf-b121-e5d580e27e75" />

**Step 6**: Storage:
- Use following for the database storage: **Automatic Storage Management (ASM)**
- Database Area: `+DATA`
<img width="790" height="619" alt="image" src="https://github.com/user-attachments/assets/d5138491-8638-41fc-bb84-88a4145d5fdf" />

**Step 7**: Fast Recovery Area:
- Recovery Area: `+RECO`
- Size: `10000`MB (or as much as you have available)
- ✅ **Enable archiving** (FONDAMENTALE per Data Guard!)
<img width="793" height="628" alt="image" src="https://github.com/user-attachments/assets/13321d51-fd29-4ec9-b234-3a3bdd48a96c" />

> **Why Enable Archiving?** Without archivelog mode, Data Guard does not work. The archivelog is the "diary" of all changes. It's the one that gets sent to standby.

**Step 8**: Listener:
- Select the cluster listener (already configured by Grid)

**Step 9**: Database Options:
- You can deselect unnecessary components (Oracle Text, Spatial, etc.)

**Step 10**: Configuration Options:
- Memory: **Use Automatic Shared Memory Management**
- SGA: almeno 1500 MB
- PGA: almeno 500 MB
- Character Set: **AL32UTF8** (consigliato)
<img width="797" height="627" alt="image" src="https://github.com/user-attachments/assets/fcbaf6da-cbbe-42f4-9811-b80c62bb3551" />

**Step 11**: Management Options:
- Uncheck EM Express for simplicity

**Step 12**: Password:
- Imposta password per SYS, SYSTEM, etc.

**Step 13**: Creation Options:
- ✅ Create Database
- ✅ Save as a Database Template (opzionale)
- ✅ Generate Database Creation Scripts (utile per imparare!)

**Step 14**: Rivedi Summary → **Finish**
<img width="862" height="1389" alt="image" src="https://github.com/user-attachments/assets/70fa2936-2362-4f38-a113-9082fe158675" />

Installation will take 15-30 minutes depending on your hardware.

---

## 2.13 Post-Installation Database Verification

```bash
# As an oracle user
sqlplus / as sysdba

-- Check the instances
SELECT inst_id, instance_name, host_name, status FROM gv$instance;
```

Output atteso:
```
   INST_ID INSTANCE_NAME    HOST_NAME       STATUS
---------- ---------------- --------------- --------
         1 RACDB1           rac1            OPEN
         2 RACDB2           rac2            OPEN
```

```bash
# Check cluster services
srvctl status database -d RACDB
# Output: Instance RACDB1 is running on node rac1
#         Instance RACDB2 is running on node rac2

# Check SCAN listener
srvctl status scan
srvctl status scan_listener

# Check database services
srvctl config database -d RACDB
```

> 📸 **SNAPSHOT — "SNAP-06: Database_RAC_Creato" ⭐ MILESTONE**
> Your primary RAC is fully operational! This is the most important snapshot to NEVER have to repeat the cluster installation AGAIN.
> ```bash
> VBoxManage snapshot "rac1" take "SNAP-06: Database_RAC_Creato"
> VBoxManage snapshot "rac2" take "SNAP-06: Database_RAC_Creato"
> ```

### Enable Force Logging (required for Data Guard)

```sql
-- Like sysdba
ALTER DATABASE FORCE LOGGING;

-- Verify
SELECT force_logging FROM v$database;
-- Must return YES
```

> **Why Force Logging?** Some operations (such as`INSERT /*+ APPEND */ ...` o `CREATE TABLE ... NOLOGGING`) can bypass the redo log for speed. But if you don't generate redo, the standby doesn't receive the changes and the data becomes corrupted. Force Logging prevents this bypass.

---

## 2.14 Cleaning Temporary Files and Patches

I file delle patch che abbiamo scompattato in `/u01/app/patch` e `/tmp`they occupy several GB. Once the patches are applied and the database is created, they are **no longer needed** and can be deleted to free up valuable virtual disk space.

```bash
# As root on rac1
rm -rf /u01/app/patch
rm -f /tmp/p*.zip

# As root on rac2
ssh rac2 "rm -rf /u01/app/patch && rm -f /tmp/p*.zip"
```

> **Nota sui backup**: NON cancellare invece i backup dell'ORACLE_HOME (`/u01/app/*_backup_*.tar.gz`) that you created as a best practice. You'll need those if you need to rollback a bad patch in the future!

---

## ✅ End of Phase 2 Checklist

```bash
# 1. Operational cluster
crsctl stat res -t | grep -E "ONLINE|OFFLINE"

# 2. ASM Disk Groups
su - grid -c "asmcmd lsdg"
# CRS, DATA, RECO all MOUNTED

#3. Active RAC database
su - oracle -c "srvctl status database -d RACDB"

#4. Archive logging active
su - oracle -c "sqlplus -s / as sysdba <<< \"SELECT log_mode FROM v\\\$database;\""

#5. Force logging active
su - oracle -c "sqlplus -s / as sysdba <<< \"SELECT force_logging FROM v\\\$database;\""
```

---

**→ Next: [STEP 3: Preparing and Creating Oracle RAC Standby](./GUIDE_PHASE3_RAC_STANDBY.md)**
