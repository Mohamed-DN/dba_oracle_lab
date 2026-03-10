# Procedura Aggiunta Dischi ASM (da Produzione)

> **Origine**: Procedura operativa reale per espansione storage in ambiente Oracle RAC Enterprise.
> **Metodi coperti**: ASMLib (`oracleasm`) e AFD (`asmcmd afd_label`).

---

## Fase 1: Rescan dei Device SCSI (su ENTRAMBI i nodi)

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

## Fase 2: Partizionamento (solo NODO 1)

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

**Prima di iniziare**: Verifica dischi già in uso
```bash
/usr/sbin/oracleasm querydisk -p /dev/mapper/*
```

**Sul NODO 2**: Verifica che la partizione sia visibile
```bash
rescan-scsi-bus.sh     # oppure partprobe /dev/mapper/mpathX
multipath -ll | grep <LUN_ID>
/usr/sbin/oracleasm querydisk -p /dev/mapper/mpath*
```

---

## Fase 3a: Creazione Disco ASMLib (metodo standard del nostro laboratorio)

```bash
# === NODO 1 (root) ===
# Crea il disco ASMLib — il device DEVE terminare con "1" o "p1"
/etc/init.d/oracleasm createdisk DATA002 /dev/mapper/mpathXXX1

# === NODO 2 (root) ===
/etc/init.d/oracleasm scandisks
/etc/init.d/oracleasm listdisks     # Deve mostrare DATA002
```

---

## Fase 3b: Creazione Disco AFD (metodo alternativo)

```bash
# === NODO 1 (grid) ===
export ORACLE_BASE=/u01/app/gridbase
$GRID_HOME/bin/asmcmd afd_label DATA002 /dev/mapper/mpathXXXp1

# === NODO 2 (grid) ===
$GRID_HOME/bin/asmcmd afd_scan
$GRID_HOME/bin/asmcmd afd_lslbl     # Deve mostrare DATA002
```

---

## Fase 4: Aggiunta Disco al Disk Group (grid → sqlplus)

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
> **Caso speciale FRA**: Se si aggiunge una LUN al `FRADG`, ricordarsi di estendere anche il parametro del database:
> ```sql
> ALTER SYSTEM SET db_recovery_file_dest_size=950G SCOPE=BOTH SID='*';
> ```
