# Procedure for Adding ASM Disks (from Production)

> **Source**: Real operating procedure for storage expansion in Oracle RAC Enterprise environment.
> **Methods Covered**: ASMLib (`oracleasm`) e AFD (`asmcmd afd_label`).

---

## Phase 1: Rescan SCSI Devices (on BOTH nodes)

```bash
# Method 1: Standard script
rescan-scsi-bus.sh

# Metodo 2: Se rescan-scsi-bus.shdoes not work or is not present
echo "1" > /sys/class/fc_host/hostX/issue_lip

# ⚠️ ATTENZIONE: issue_lip da eseguire tra un hostX e l'altro 
# with at least 1 minute pause to avoid I/O interruption
# Check /var/log/messages and multipath -ll between runs!

# Check for new LUN
multipath -ll
multipath -ll | grep -i <LUN_WWN>     # Grep per il WWN della nuova LUN
ls -ltr /dev/mapper/*
```

---

## Phase 2: Partitioning (NODE 1 only)

```bash
# Check optimal_io_size to determine the correct syntax
cat /sys/block/mpathX/queue/optimal_io_size

# CASO 1: optimal_io_size = 0
parted -s /dev/mapper/mpathX unit s mklabel gpt mkpart primary "2048 -34"

#CASE 2: optimal_io_size <> 0 (typical on Pure Storage/POD)
# Formula: partition_offset = (optimal_io_size – alignment_offset) / physical_block_size
parted -s /dev/mapper/mpathX unit s mklabel gpt mkpart primary "8192 -34"

# NEW SYNTAX (recommended for recent versions of parted):
parted -s -a optimal /dev/mapper/mpathX mklabel gpt mkpart primary 0% 100%
```

**Before you begin**: Check disks already in use
```bash
/usr/sbin/oracleasm querydisk -p /dev/mapper/*
```

**On NODE 2**: Verify that the partition is visible
```bash
rescan-scsi-bus.sh     # oppure partprobe /dev/mapper/mpathX
multipath -ll | grep <LUN_ID>
/usr/sbin/oracleasm querydisk -p /dev/mapper/mpath*
```

---

## Phase 3a: ASMLib Disk Creation (standard method of our laboratory)

```bash
# === NODO 1 (root) ===
# Create ASMLib disk — device MUST end with "1" or "p1"
/etc/init.d/oracleasm createdisk DATA002 /dev/mapper/mpathXXX1

# === NODO 2 (root) ===
/etc/init.d/oracleasm scandisks
/etc/init.d/oracleasm listdisks     # Deve mostrare DATA002
```

---

## Step 3b: AFD Disk Creation (alternative method)

```bash
# === NODO 1 (grid) ===
export ORACLE_BASE=/u01/app/gridbase
$GRID_HOME/bin/asmcmd afd_label DATA002 /dev/mapper/mpathXXXp1

# === NODO 2 (grid) ===
$GRID_HOME/bin/asmcmd afd_scan
$GRID_HOME/bin/asmcmd afd_lslbl     # Deve mostrare DATA002
```

---

## Step 4: Adding Disk to Disk Group (grid → sqlplus)

```sql
su - grid
sqlplus / as sysasm

--1. Check current space
SELECT NAME, ROUND(TOTAL_MB/1024) "TOTAL_GB", ROUND(COLD_USED_MB/1024) "USED_GB", 
       ROUND(FREE_MB/1024) "FREE_GB", ROUND(COLD_USED_MB/TOTAL_MB*100) "PCT_USED" 
FROM v$asm_diskgroup ORDER BY name;

--2. Check the new disk: it must haveMOUNT_STATUS='CLOSED' e HEADER_STATUS='PROVISIONED'
SET LINES 222 PAGES 2222
COL path FOR a30
COL label FOR a20
COL name FOR a20
COL failgroup FOR a20

SELECT PATH, LABEL, NAME, FAILGROUP, OS_MB, MOUNT_STATUS, HEADER_STATUS, MODE_STATUS, STATE 
FROM v$asm_disk ORDER BY 1,2;

--3a. ADD disk (ASMLib)
ALTER DISKGROUP DATADG ADD DISK 'ORCL:DATA002' REBALANCE POWER 4;

--3b. ADD Disk (AFD)
ALTER DISKGROUP DATADG ADD DISK 'AFD:DATA002' REBALANCE POWER 4;

--4. Monitor the rebalance
SELECT * FROM v$asm_operation;

--5. Final check
SELECT NAME, ROUND(TOTAL_MB/1024) "TOTAL_GB", ROUND(FREE_MB/1024) "FREE_GB" 
FROM v$asm_diskgroup WHERE NAME = 'DATADG';
```

> [!IMPORTANT]
> **Special case FRA**: If you add a LUN to `FRADG`, remember to also extend the database parameter:
> ```sql
> ALTER SYSTEM SET db_recovery_file_dest_size=950G SCOPE=BOTH SID='*';
> ```
