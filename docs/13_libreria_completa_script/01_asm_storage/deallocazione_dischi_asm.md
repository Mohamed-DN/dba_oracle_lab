# Deallocazione Dischi ASM

> **Scopo**: Rimuovere un disco da un Disk Group ASM, tipicamente durante una migrazione storage (es. da VMAX a Pure Storage).

---

## Procedura

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
> **Non rimuovere mai fisicamente la LUN dallo storage prima che il rebalance sia completato!**
> Il processo di DROP DISK sposta i dati dal disco da rimuovere verso gli altri dischi del Disk Group. Se il disco viene rimosso prima, si rischiano **data loss**.

---

## Pulizia lato OS (dopo il completamento)

```bash
# Rimuovi il disco da ASMLib
/etc/init.d/oracleasm deletedisk DATA_OLD001

# Oppure per AFD
$GRID_HOME/bin/asmcmd afd_unlabel DATA_OLD001

# Su entrambi i nodi
/etc/init.d/oracleasm scandisks       # ASMLib
$GRID_HOME/bin/asmcmd afd_scan        # AFD
```
