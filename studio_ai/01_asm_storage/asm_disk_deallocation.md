# ASM Disk Deallocation

> **Purpose**: Remove a disk from an ASM Disk Group, typically during a storage migration (e.g. from VMAX to Pure Storage).

---

## Procedure

```sql
--1. Check current status of disks in Disk Group
SELECT PATH, LABEL, NAME, FAILGROUP, OS_MB, MOUNT_STATUS, HEADER_STATUS 
FROM v$asm_disk WHERE GROUP_NUMBER = (SELECT GROUP_NUMBER FROM v$asm_diskgroup WHERE NAME = 'DATADG');

--2. Disk DROP (ASM automatically starts data rebalancing)
ALTER DISKGROUP DATADG DROP DISK DATA_OLD001 REBALANCE POWER 4;

--3. Monitor the rebalance (wait for it to complete before physically deallocating!)
SELECT * FROM v$asm_operation;

--4. After the rebalance completes, verify that the disk is no longer in the Disk Group
SELECT PATH, LABEL, NAME FROM v$asm_disk WHERE GROUP_NUMBER = (SELECT GROUP_NUMBER FROM v$asm_diskgroup WHERE NAME = 'DATADG');
```

> [!WARNING]
> **Never physically remove the LUN from storage before the rebalance is complete!**
> The DROP DISK process moves data from the disk to be removed to the other disks in the Disk Group. If the disk is removed beforehand, there is a risk of **data loss**.

---

## OS side cleanup (after completion)

```bash
# Remove disk from ASMLib
/etc/init.d/oracleasm deletedisk DATA_OLD001

# Oppure per AFD
$GRID_HOME/bin/asmcmd afd_unlabel DATA_OLD001

# Su entrambi i nodi
/etc/init.d/oracleasm scandisks       # ASMLib
$GRID_HOME/bin/asmcmd afd_scan        # AFD
```
