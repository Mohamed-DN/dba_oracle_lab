# ASM Disk Deallocation

> **Purpose**: Remove a disk from an ASM Disk Group, typically during a storage migration (e.g. from VMAX to Pure Storage).

---

## Procedure

```sql
-- 1. Verifica stato attuale dei dischi nel Disk Group
SELECT PATH, LABEL, NAME, FAILGROUP, OS_MB, MOUNT_STATUS, HEADER_STATUS 
FROM v$asm_disk WHERE GROUP_NUMBER = (SELECT GROUP_NUMBER FROM v$asm_diskgroup WHERE NAME = 'DATADG');

-- 2. DROP del disco (ASM avvia automaticamente il rebalance dei dati)
ALTER DISKGROUP DATADG DROP DISK DATA_OLD001 REBALANCE POWER 4;

-- 3. Monitora il rebalance (attendere che si completi prima di deallocare fisicamente!)
SELECT * FROM v$asm_operation;

-- 4. Dopo il completamento del rebalance, verifica che il disco non sia più nel Disk Group
SELECT PATH, LABEL, NAME FROM v$asm_disk WHERE GROUP_NUMBER = (SELECT GROUP_NUMBER FROM v$asm_diskgroup WHERE NAME = 'DATADG');
```

> [!WARNING]
> **Never physically remove the LUN from storage before the rebalance is complete!**
> The DROP DISK process moves data from the disk to be removed to the other disks in the Disk Group. If the disk is removed beforehand, there is a risk of **data loss**.

---

## OS side cleanup (after completion)

```bash
# Rimuovi il disco da ASMLib
/etc/init.d/oracleasm deletedisk DATA_OLD001

# Oppure per AFD
$GRID_HOME/bin/asmcmd afd_unlabel DATA_OLD001

# Su entrambi i nodi
/etc/init.d/oracleasm scandisks       # ASMLib
$GRID_HOME/bin/asmcmd afd_scan        # AFD
```
