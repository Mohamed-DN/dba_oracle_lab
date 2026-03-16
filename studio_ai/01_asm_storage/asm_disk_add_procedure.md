# Procedure for Adding ASM Disks (from Production)

> **Source**: Real operating procedure for storage expansion in Oracle RAC Enterprise environment.
> **Metodi coperti**: ASMLib (`oracleasm`) e AFD (`asmcmd afd_label`).

---

## Phase 1: Rescan SCSI Devices (on BOTH nodes)

```bash
# Metodo 1: Script standard
rescan-scsi-bus.sh

# Metodo 2: Se rescan-scsi-bus.sh non funziona o non è presente
echo "1" > /sys/class/fc_host/hostX/issue_lip

# ⚠️ ATTENZIONE: issue_lip da eseguire tra un hostX e l'altro 
# con almeno 1 minuto di pausa per evitare interruzione I/O
# Controllare /var/log/messages e multipath -ll tra un'esecuzione e l'altra!

# Verifica presenza nuova LUN
multipath -ll
multipath -ll | grep -i <LUN_WWN>     # Grep per il WWN della nuova LUN
ls -ltr /dev/mapper/*
```

---

## Phase 2: Partitioning (NODE 1 only)

```bash
# Verifica optimal_io_size per determinare la sintassi corretta
cat /sys/block/mpathX/queue/optimal_io_size

# CASO 1: optimal_io_size = 0
parted -s /dev/mapper/mpathX unit s mklabel gpt mkpart primary "2048 -34"

# CASO 2: optimal_io_size <> 0 (tipico su Pure Storage / POD)
# Formula: partition_offset = (optimal_io_size – alignment_offset) / physical_block_size
parted -s /dev/mapper/mpathX unit s mklabel gpt mkpart primary "8192 -34"

# NUOVA SINTASSI (consigliata per le versioni recenti di parted):
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
# Crea il disco ASMLib — il device DEVE terminare con "1" o "p1"
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

-- 1. Verifica spazio attuale
SELECT NAME, ROUND(TOTAL_MB/1024) "TOTAL_GB", ROUND(COLD_USED_MB/1024) "USED_GB", 
       ROUND(FREE_MB/1024) "FREE_GB", ROUND(COLD_USED_MB/TOTAL_MB*100) "PCT_USED" 
FROM v$asm_diskgroup ORDER BY name;

-- 2. Verifica il nuovo disco: deve avere MOUNT_STATUS='CLOSED' e HEADER_STATUS='PROVISIONED'
SET LINES 222 PAGES 2222
COL path FOR a30
COL label FOR a20
COL name FOR a20
COL failgroup FOR a20

SELECT PATH, LABEL, NAME, FAILGROUP, OS_MB, MOUNT_STATUS, HEADER_STATUS, MODE_STATUS, STATE 
FROM v$asm_disk ORDER BY 1,2;

-- 3a. ADD disco (ASMLib)
ALTER DISKGROUP DATADG ADD DISK 'ORCL:DATA002' REBALANCE POWER 4;

-- 3b. ADD disco (AFD)
ALTER DISKGROUP DATADG ADD DISK 'AFD:DATA002' REBALANCE POWER 4;

-- 4. Monitora il rebalance
SELECT * FROM v$asm_operation;

-- 5. Verifica finale
SELECT NAME, ROUND(TOTAL_MB/1024) "TOTAL_GB", ROUND(FREE_MB/1024) "FREE_GB" 
FROM v$asm_diskgroup WHERE NAME = 'DATADG';
```

> [!IMPORTANT]
> **Special case FRA**: If you add a LUN to `FRADG`, remember to also extend the database parameter:
> ```sql
> ALTER SYSTEM SET db_recovery_file_dest_size=950G SCOPE=BOTH SID='*';
> ```
