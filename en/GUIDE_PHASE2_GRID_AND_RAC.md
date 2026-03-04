# PHASE 2: Grid Infrastructure and Oracle RAC Primary Installation

> All steps in this phase refer to **rac1** and **rac2** (Primary RAC) nodes.

### What We Build in This Phase

```
╔═══════════════════════════════════════════════════════════════════════╗
║                     THE RAC CLUSTER (rac1 + rac2)                    ║
║                                                                       ║
║    ┌──────────────────────────────────────────────────────────┐       ║
║    │              Oracle Database 19c + RU + OJVM             │       ║
║    │         ┌──────────────┐  ┌──────────────┐               │       ║
║    │         │  Instance    │  │  Instance    │               │       ║
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
║    │                  Shared ASM Disks                         │       ║
║    │  ┌─────────┐     ┌──────────┐     ┌──────────┐          │       ║
║    │  │ +CRS    │     │ +DATA    │     │ +FRA     │          │       ║
║    │  │  5 GB   │     │  20 GB   │     │  15 GB   │          │       ║
║    │  │ OCR,    │     │ Datafile,│     │ Archive, │          │       ║
║    │  │ Voting  │     │ Redo,    │     │ Backup,  │          │       ║
║    │  │ Disk    │     │ Control  │     │ Flashback│          │       ║
║    │  └─────────┘     └──────────┘     └──────────┘          │       ║
║    └──────────────────────────────────────────────────────────┘       ║
╚═══════════════════════════════════════════════════════════════════════╝
```

### Installation Order

```
Step 1:  ASM Disks          ━━━━━━━━━━━━━━━━━━━━━━━▶  oracleasm, partitions
Step 2:  cluvfy              ━━━━━━━━━━━━━━━━━━━━━━━▶  verify prerequisites
Step 3:  Grid Infrastructure  ━━━━━━━━━━━━━━━━━━━━━▶  gridSetup.sh + root.sh
Step 4:  DATA + FRA           ━━━━━━━━━━━━━━━━━━━━━▶  asmca / sqlplus
Step 5:  Patch Grid (RU)      ━━━━━━━━━━━━━━━━━━━━━▶  opatchauto (as root)
Step 6:  DB Software           ━━━━━━━━━━━━━━━━━━━━▶  runInstaller + root.sh
Step 7:  Patch DB Home (RU+OJVM)━━━━━━━━━━━━━━━━━━▶  opatchauto + opatch
Step 8:  DBCA                   ━━━━━━━━━━━━━━━━━━━▶  create RACDB database
Step 9:  datapatch               ━━━━━━━━━━━━━━━━━━▶  apply patches to dictionary
```

---

## 2.1 Shared Storage Preparation (ASM)

### Disk Partitioning (on rac1 as root)

```bash
lsblk  # Should see sdb, sdc, sdd
for disk in sdb sdc sdd; do
  echo -e "n\np\n1\n\n\nw" | fdisk /dev/$disk
done
partprobe
```

> **Why partition?** ASM can use raw disks or partitions. Partitions are safer — the partition table on block 0 acts as a "guard" against accidental overwrites.

### ASMLib Configuration (on BOTH nodes)

```bash
yum install -y oracleasm-support kmod-oracleasm
oracleasm configure -i
# Default user: grid | Default group: asmadmin | Start on boot: y | Scan on boot: y
oracleasm init
```

### Create ASM Disks (on rac1 ONLY)

```bash
oracleasm createdisk CRS  /dev/sdb1
oracleasm createdisk DATA /dev/sdc1
oracleasm createdisk FRA  /dev/sdd1
oracleasm listdisks  # Expected: CRS, DATA, FRA
```

### Scan Disks from Node 2 (on rac2)

```bash
oracleasm scandisks
oracleasm listdisks  # Expected: CRS, DATA, FRA
```

> 📸 **SNAPSHOT — "SNAP-04: ASM Disks Configured"**

---

## 2.2-2.5 Grid Infrastructure Installation

1. Unzip Grid in GRID_HOME: `unzip -q LINUX.X64_193000_grid_home.zip -d /u01/app/19.0.0/grid`
2. Install cvuqdisk RPM on both nodes
3. Run `cluvfy`: `./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose`

> 📸 **SNAPSHOT — "SNAP-05: cluvfy PASSED"** 🔴

4. Launch Grid installer: `./gridSetup.sh`
   - Configure for New Cluster → Standalone Cluster
   - SCAN: `rac-scan.oracleland.local` port 1521
   - Add rac2 node
   - Network: eth0=Public, eth1=ASM & Private
   - Create CRS disk group (External redundancy)

5. Run root scripts **ONE AT A TIME**, first rac1, then rac2:
```bash
# On rac1 as root (WAIT for completion before rac2!)
/u01/app/oraInventory/orainstRoot.sh
/u01/app/19.0.0/grid/root.sh

# Then on rac2 as root
/u01/app/oraInventory/orainstRoot.sh
/u01/app/19.0.0/grid/root.sh
```

> 📸 **SNAPSHOT — "SNAP-06: Grid Infrastructure Installed"** ⭐

6. Verify cluster: `crsctl check crs` → All ONLINE
7. Create DATA and FRA disk groups via `asmca` or SQL

---

## 2.8 Patching Grid Infrastructure (Release Update)

> **Why patch?** Oracle 19c base (19.3) was released in 2019. Release Updates contain security fixes, bug fixes, and stability improvements. In production, patching is **mandatory**.

### Step 1: Update OPatch in Grid Home
```bash
su - grid
mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bkp
unzip -q /tmp/p6880880_230000_Linux-x86-64.zip -d $ORACLE_HOME/
$ORACLE_HOME/OPatch/opatch version  # Must be 12.2.0.1.43+
# Repeat on rac2
```

### Step 2: Apply RU with opatchauto
```bash
# As root on rac1
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/OPatch/opatchauto apply /tmp/patch/37957391 -oh $ORACLE_HOME
# Repeat on rac2
```

> **Why opatchauto?** For Grid Infrastructure, you can't use simple `opatch apply`. `opatchauto` (as root) automatically stops CRS, applies the patch, and restarts CRS.

> 📸 **SNAPSHOT — "SNAP-07: Grid Patched"**

---

## 2.9-2.11 Database Software + Patching

1. Unzip DB home, run `runInstaller` → **Software Only** → RAC → both nodes
2. Run root.sh on both nodes

> 📸 **SNAPSHOT — "SNAP-08: DB Software Installed"**

3. Update OPatch in DB Home (same as Grid)
4. Apply RU: `opatchauto apply /tmp/patch/37957391 -oh $ORACLE_HOME`
5. Apply OJVM: `cd /tmp/patch/33803476 && $ORACLE_HOME/OPatch/opatch apply`
6. Verify: `$ORACLE_HOME/OPatch/opatch lspatches`

> 📸 **SNAPSHOT — "SNAP-08b: DB Home Patched"**

---

## 2.12 Create RAC Database with DBCA

```bash
su - oracle
dbca
```

Key DBCA settings:
- **Advanced Configuration** → **Oracle RAC** → Both nodes
- Database Name: `RACDB` | SID Prefix: `RACDB`
- Storage: **ASM** → `+DATA` | Recovery: `+FRA`
- ✅ **Enable archiving** (CRITICAL for Data Guard!)
- Character Set: **AL32UTF8**

After DBCA completes, run **datapatch**:
```bash
$ORACLE_HOME/OPatch/datapatch -verbose
```

Enable Force Logging:
```sql
ALTER DATABASE FORCE LOGGING;
```

> 📸 **SNAPSHOT — "SNAP-09: RACDB Created"** ⭐ (Most important snapshot!)

---

**→ Next: [PHASE 3: RAC Standby Creation](./GUIDE_PHASE3_RAC_STANDBY.md)**
