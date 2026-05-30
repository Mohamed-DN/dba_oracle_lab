# Cheat Sheet RMAN — Enterprise Completo 🔥

> [!NOTE]
> **DOCUMENTI RMAN CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Guida di Laboratorio (Fase 5)**: [GUIDA_FASE5_RMAN_BACKUP.md](../../02_core_dba/02_backup_and_recovery/GUIDA_FASE5_RMAN_BACKUP.md) (impostazione della strategia di backup e cron).
> - **Manuale Comandi Core**: [GUIDA_RMAN_COMANDI_ENTERPRISE.md](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMANDI_ENTERPRISE.md) (riferimento completo dei parametri RMAN).
> - **Guida Architetturale Core**: [GUIDA_RMAN_COMPLETA_19C.md](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md) (fondamenti teorici e scenari avanzati).
> - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](./CS_MASTER_DBA.md) (tutti i comandi consolidati).

---

## 1. Connessione RMAN

```rman
-- Connessione locale (OS Auth)
rman target /

-- Connessione con password (non-CDB / CDB Root)
rman target sys/password@orcl

-- Connessione con catalog
rman target / catalog rman/password@catdb

-- Connessione target + auxiliary (per duplicate)
rman target sys/pass@PRIMARY auxiliary sys/pass@STANDBY

-- Connessione a CDB root
rman target sys/pass@CDB1

-- Connessione diagnostica (solo lettura, senza recovery catalog)
rman checksyntax
```

---

## 2. Configurazione RMAN (SHOW / CONFIGURE)

### 2.1 Visualizzare la configurazione corrente
```rman
SHOW ALL;
SHOW RETENTION POLICY;
SHOW DEFAULT DEVICE TYPE;
SHOW CONTROLFILE AUTOBACKUP;
SHOW ENCRYPTION FOR DATABASE;
```

### 2.2 Configurazione Enterprise consigliata
```rman
-- Retention: Recovery Window di 7 giorni (per produzione usare 14-30)
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;

-- Autobackup del controlfile (FONDAMENTALE per bare-metal recovery)
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/backup/rman/%F';

-- Ottimizzazione: non ri-backuppare file già backuppati
CONFIGURE BACKUP OPTIMIZATION ON;

-- Parallelismo e compressione
CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO COMPRESSED BACKUPSET;

-- Per ambienti con tape library (SBT)
-- CONFIGURE DEVICE TYPE sbt PARALLELISM 2;
-- CONFIGURE DEFAULT DEVICE TYPE TO sbt;

-- Snapshot controlfile (per hot backup consistente)
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '/backup/rman/snapcf_orcl.f';

-- Archivelog deletion policy per Data Guard
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY BACKED UP 1 TIMES TO DISK;

-- Sezione backup: FRA (Fast Recovery Area)
CONFIGURE DB_RECOVERY_FILE_DEST_SIZE = 100G;
```

### 2.3 Reset configurazione al default
```rman
CONFIGURE RETENTION POLICY CLEAR;
CONFIGURE CONTROLFILE AUTOBACKUP CLEAR;
CONFIGURE BACKUP OPTIMIZATION CLEAR;
CONFIGURE DEVICE TYPE DISK CLEAR;
```

---

## 3. Backup — Tutti gli Scenari

### 3.1 Backup Completo (Full / Level 0)
```rman
-- Backup full database (NON incrementale)
BACKUP DATABASE;

-- Backup full + archivelog (standard quotidiano)
BACKUP DATABASE PLUS ARCHIVELOG;

-- Backup full + archivelog con cancellazione archivelog già backuppati
BACKUP DATABASE PLUS ARCHIVELOG DELETE INPUT;

-- Backup full con compressione (risparmio ~60-70% spazio)
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG DELETE ALL INPUT;

-- Backup full con tag identificativo
BACKUP DATABASE TAG 'FULL_WEEKLY_20260529' PLUS ARCHIVELOG;
```

### 3.2 Backup Incrementale (Level 0 / Level 1)
```rman
-- Level 0 (base per gli incrementali successivi)
BACKUP INCREMENTAL LEVEL 0 DATABASE;

-- Level 1 differenziale (solo blocchi cambiati dall'ultimo L0 o L1)
BACKUP INCREMENTAL LEVEL 1 DATABASE;

-- Level 1 cumulativo (tutti i blocchi cambiati dall'ultimo L0)
BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE;

-- Strategia incrementale completa
-- Domenica: BACKUP INCREMENTAL LEVEL 0 DATABASE TAG 'L0_WEEKLY';
-- Lun-Sab:  BACKUP INCREMENTAL LEVEL 1 DATABASE TAG 'L1_DAILY';
```

### 3.3 Block Change Tracking (BCT) — Velocizzare gli incrementali
```sql
-- Abilitare BCT (da SQL*Plus, una sola volta)
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+DATA/orcl/bct_orcl.ctf';

-- ASM: il file BCT va in un diskgroup
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+DATA/orcl/bct.chg';

-- Verificare stato BCT
SELECT filename, status, bytes/1024/1024 AS mb FROM V$BLOCK_CHANGE_TRACKING;

-- Disabilitare
ALTER DATABASE DISABLE BLOCK CHANGE TRACKING;
```

### 3.4 Backup di Componenti Specifici
```rman
-- Solo tablespace
BACKUP TABLESPACE users, tools;

-- Solo datafile
BACKUP DATAFILE 5, 7;
BACKUP DATAFILE '/u01/oradata/orcl/users01.dbf';

-- Solo archivelog (ultimi 2 giorni)
BACKUP ARCHIVELOG FROM TIME 'SYSDATE-2';
BACKUP ARCHIVELOG ALL DELETE INPUT;
BACKUP ARCHIVELOG ALL NOT BACKED UP 1 TIMES;

-- Solo controlfile
BACKUP CURRENT CONTROLFILE;

-- Solo SPFILE
BACKUP SPFILE;

-- Controlfile + SPFILE esplicito
BACKUP CURRENT CONTROLFILE FORMAT '/backup/rman/cf_%U.bkp';
BACKUP SPFILE FORMAT '/backup/rman/spfile_%U.bkp';
```

### 3.5 Backup con Encryption (TDE / Password)
```rman
-- Se TDE è già attivo sul database (Transparent mode - automatico)
BACKUP DATABASE;  -- i backup saranno già criptati

-- Encryption con password RMAN (se TDE NON è attivo)
SET ENCRYPTION ON IDENTIFIED BY 'backup_encrypt_pass' ONLY;
BACKUP DATABASE;

-- Encryption duale (TDE + password, per trasferimento offsite)
SET ENCRYPTION ON IDENTIFIED BY 'offsite_pass';
BACKUP DATABASE FORMAT '/backup/offsite/%U.bkp';

-- Verificare stato encryption
SELECT * FROM V$RMAN_ENCRYPTION_ALGORITHMS;
```

### 3.6 Backup su Tape (SBT) e NFS
```rman
-- Backup diretto su tape (richiede media management)
BACKUP DEVICE TYPE sbt DATABASE PLUS ARCHIVELOG;

-- Backup con formato personalizzato e path NFS
BACKUP DATABASE FORMAT '/nfs_backup/rman/%d_%T_%U.bkp'
  PLUS ARCHIVELOG FORMAT '/nfs_backup/rman/arch_%d_%T_%U.bkp';
```

### 3.7 Backup Multisection (per file molto grandi, >50GB)
```rman
-- Backup multisection: divide i datafile grandi in "sezioni" parallele
BACKUP SECTION SIZE 10G DATABASE;
BACKUP SECTION SIZE 5G TABLESPACE bigdata;
```

### 3.8 Formati di naming (%d, %T, %U, %F)
```text
%d  = DB_NAME
%T  = Data (YYYYMMDD)
%t  = Timestamp (epoch)
%U  = Unique name generato da RMAN
%s  = Backup set number
%p  = Backup piece number
%F  = Format unico per autobackup controlfile: c-DBID-YYYYMMDD-QQ
```

---

## 4. Restore e Recovery — Tutti gli Scenari

### 4.1 Complete Recovery (nessuna perdita dati)
```rman
-- Database completo da backup
STARTUP MOUNT;
RESTORE DATABASE;
RECOVER DATABASE;
ALTER DATABASE OPEN;
```

### 4.2 Point-in-Time Recovery (PITR)
```rman
STARTUP MOUNT;
-- Per data e ora
RESTORE DATABASE UNTIL TIME "TO_DATE('2026-05-29 08:00:00','YYYY-MM-DD HH24:MI:SS')";
RECOVER DATABASE UNTIL TIME "TO_DATE('2026-05-29 08:00:00','YYYY-MM-DD HH24:MI:SS')";
ALTER DATABASE OPEN RESETLOGS;

-- Per SCN
RESTORE DATABASE UNTIL SCN 123456789;
RECOVER DATABASE UNTIL SCN 123456789;
ALTER DATABASE OPEN RESETLOGS;

-- Per Log Sequence
RESTORE DATABASE UNTIL SEQUENCE 1500 THREAD 1;
RECOVER DATABASE UNTIL SEQUENCE 1500 THREAD 1;
ALTER DATABASE OPEN RESETLOGS;
```

### 4.3 Restore Tablespace
```rman
-- Offline il tablespace, restore, recover, online
ALTER TABLESPACE users OFFLINE IMMEDIATE;
RESTORE TABLESPACE users;
RECOVER TABLESPACE users;
ALTER TABLESPACE users ONLINE;
```

### 4.4 Restore Datafile Singolo
```rman
-- Datafile singolo (database aperto se il file non è di SYSTEM/UNDO)
ALTER DATABASE DATAFILE 5 OFFLINE;
RESTORE DATAFILE 5;
RECOVER DATAFILE 5;
ALTER DATABASE DATAFILE 5 ONLINE;

-- Oppure per path
RESTORE DATAFILE '/u01/oradata/orcl/users01.dbf';
RECOVER DATAFILE '/u01/oradata/orcl/users01.dbf';
```

### 4.5 Restore Controlfile (Bare Metal Recovery)
```rman
-- Se hai perso i controlfile ma hai l'autobackup
STARTUP NOMOUNT;
-- Imposta DBID se serve
SET DBID 123456789;
RESTORE CONTROLFILE FROM AUTOBACKUP;
ALTER DATABASE MOUNT;
RESTORE DATABASE;
RECOVER DATABASE;
ALTER DATABASE OPEN RESETLOGS;
```

### 4.6 Restore SPFILE
```rman
-- Da autobackup del controlfile
STARTUP FORCE NOMOUNT;
SET DBID 123456789;
RESTORE SPFILE FROM AUTOBACKUP;
STARTUP FORCE;
```

### 4.7 Restore su Path Diversi (SET NEWNAME)
```rman
-- Quando i path di destinazione sono diversi da quelli originali
RUN {
  SET NEWNAME FOR DATAFILE 1 TO '/new_path/system01.dbf';
  SET NEWNAME FOR DATAFILE 2 TO '/new_path/sysaux01.dbf';
  SET NEWNAME FOR DATAFILE 3 TO '/new_path/undotbs01.dbf';
  SET NEWNAME FOR DATAFILE 4 TO '/new_path/users01.dbf';
  RESTORE DATABASE;
  SWITCH DATAFILE ALL;
  RECOVER DATABASE;
}
```

### 4.8 Restore in ambiente ASM
```rman
RUN {
  SET NEWNAME FOR DATABASE TO '+DATA';
  RESTORE DATABASE;
  SWITCH DATAFILE ALL;
  RECOVER DATABASE;
}
```

---

## 5. Validate, Crosscheck, Report — Manutenzione

### 5.1 Validazione Backup (senza restore effettivo)
```rman
-- Valida che i backup siano leggibili e integri
VALIDATE BACKUPSET 123;
VALIDATE DATABASE;
VALIDATE TABLESPACE users;
VALIDATE DATAFILE 5;

-- Valida anche la corruzione logica
VALIDATE CHECK LOGICAL DATABASE;

-- Restore preview (mostra cosa serve senza fare nulla)
RESTORE DATABASE PREVIEW;
RESTORE DATABASE PREVIEW SUMMARY;
```

### 5.2 Crosscheck (sincronizza catalogo RMAN con media)
```rman
-- Crosscheck tutti i backup
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
CROSSCHECK COPY;

-- Crosscheck solo un device
CROSSCHECK BACKUP DEVICE TYPE DISK;
CROSSCHECK BACKUP DEVICE TYPE sbt;
```

### 5.3 Cleanup Backup Scaduti / Obsoleti
```rman
-- Elimina backup scaduti (non più sul media)
DELETE EXPIRED BACKUP;
DELETE EXPIRED ARCHIVELOG ALL;

-- Elimina backup obsoleti (oltre la retention policy)
DELETE OBSOLETE;
DELETE NOPROMPT OBSOLETE;

-- Elimina backup specifici
DELETE BACKUP TAG 'OLD_FULL_20260101';
DELETE BACKUPSET 456;

-- Elimina solo archivelog eleggibili secondo la deletion policy configurata.
-- In Data Guard verifica prima transport/apply lag.
SHOW ARCHIVELOG DELETION POLICY;
DELETE NOPROMPT ARCHIVELOG ALL;
```

### 5.4 Report
```rman
-- Backup che servono (file non backuppati di recente)
REPORT NEED BACKUP;
REPORT NEED BACKUP DAYS 3;
REPORT NEED BACKUP INCREMENTAL 2;

-- Backup obsoleti secondo la retention
REPORT OBSOLETE;

-- Schema del database (tutti i datafile)
REPORT SCHEMA;
REPORT SCHEMA AT SCN 123456;

-- File non recuperabili (perché non backuppati)
REPORT UNRECOVERABLE;
```

### 5.5 List
```rman
-- Lista tutti i backup
LIST BACKUP SUMMARY;
LIST BACKUP;
LIST BACKUP OF DATABASE;
LIST BACKUP OF TABLESPACE users;
LIST BACKUP OF ARCHIVELOG ALL;
LIST BACKUP OF CONTROLFILE;
LIST BACKUP OF SPFILE;

-- Lista copie (image copy)
LIST COPY;
LIST COPY OF DATABASE;

-- Lista backup completati nelle ultime 24h
LIST BACKUP COMPLETED AFTER 'SYSDATE-1';

-- Lista archivelog
LIST ARCHIVELOG ALL;
```

---

## 6. RMAN Duplicate (Clonazione / Standby)

### 6.1 Active Duplicate (via rete, senza backup)
```rman
-- Da eseguire dallo standby verso il primary
rman target sys/pass@PRIMARY auxiliary sys/pass@CLONE

DUPLICATE TARGET DATABASE TO CLONEDB
  FROM ACTIVE DATABASE
  SPFILE
    SET DB_UNIQUE_NAME='CLONEDB'
    SET DB_FILE_NAME_CONVERT='+DATA/PRIMARY/','+DATA/CLONEDB/'
    SET LOG_FILE_NAME_CONVERT='+DATA/PRIMARY/','+DATA/CLONEDB/','+RECO/PRIMARY/','+RECO/CLONEDB/'
    SET CONTROL_FILES='+DATA/CLONEDB/controlfile/control01.ctl'
    SET LOCAL_LISTENER='(ADDRESS=(PROTOCOL=TCP)(HOST=clone-host)(PORT=1521))'
  NOFILENAMECHECK;
```

### 6.2 Active Duplicate FOR STANDBY (Data Guard)
```rman
rman target sys/pass@PRIMARY auxiliary sys/pass@STANDBY

DUPLICATE TARGET DATABASE FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
    SET DB_UNIQUE_NAME='STANDBY_DG'
    SET FAL_SERVER='PRIMARY'
    SET LOG_ARCHIVE_DEST_2='SERVICE=PRIMARY ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=PRIMARY'
  NOFILENAMECHECK;
```

### 6.3 Duplicate da Backup (Backup-Based)
```rman
rman auxiliary sys/pass@CLONE

DUPLICATE TARGET DATABASE TO CLONEDB
  BACKUP LOCATION '/backup/rman/'
  SPFILE
    SET DB_UNIQUE_NAME='CLONEDB'
  NOFILENAMECHECK;
```

---

## 7. Tablespace Point-in-Time Recovery (TSPITR)

```rman
-- Recover un tablespace a un punto nel tempo precedente (senza toccare il resto del DB)
-- RMAN crea automaticamente un'istanza ausiliaria
RECOVER TABLESPACE users
  UNTIL TIME "TO_DATE('2026-05-28 14:00:00','YYYY-MM-DD HH24:MI:SS')"
  AUXILIARY DESTINATION '/tmp/rman_aux';

-- Verifica post-TSPITR
ALTER TABLESPACE users ONLINE;
```

---

## 7A. Recover Table (Errore Umano: DROP o DELETE)

```rman
-- Esegui RMAN localmente sul target aperto read-write e in ARCHIVELOG mode.
RECOVER TABLE HR.ORDERS
  UNTIL TIME 'SYSDATE-1'
  AUXILIARY DESTINATION '/tmp/rman_table_aux'
  REMAP TABLE 'HR'.'ORDERS':'ORDERS_RECOVERED';

-- Variante PDB: collegati localmente alla root CDB.
RECOVER TABLE HR.ORDERS OF PLUGGABLE DATABASE APPPDB
  UNTIL SCN 123456789
  AUXILIARY DESTINATION '/tmp/rman_table_aux'
  DATAPUMP DESTINATION '/tmp/rman_table_dump'
  DUMP FILE 'orders_recovered.dmp'
  NOTABLEIMPORT;
```

RMAN crea un auxiliary database temporaneo, recupera l'oggetto al PITR richiesto
e usa Data Pump. Verifica backup e archivelog continui, spazio auxiliary e limiti
Oracle prima del comando. Approfondimento:
[Fase 5 RMAN](../../02_core_dba/02_backup_and_recovery/GUIDA_FASE5_RMAN_BACKUP.md).

---

## 8. Flashback Database (Complemento RMAN)

```sql
-- Prerequisiti (da SQL*Plus)
ALTER DATABASE FLASHBACK ON;

-- Flashback a un punto nel tempo (alternativa al PITR)
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
FLASHBACK DATABASE TO TIMESTAMP TO_TIMESTAMP('2026-05-28 14:00:00','YYYY-MM-DD HH24:MI:SS');
ALTER DATABASE OPEN RESETLOGS;

-- Flashback a un restore point garantito
CREATE RESTORE POINT before_upgrade GUARANTEE FLASHBACK DATABASE;
-- ... dopo il disastro ...
FLASHBACK DATABASE TO RESTORE POINT before_upgrade;
ALTER DATABASE OPEN RESETLOGS;

-- Verifica Flashback
SELECT oldest_flashback_scn, oldest_flashback_time, flashback_on FROM V$DATABASE;
SELECT * FROM V$RESTORE_POINT;
```

---

## 9. Image Copy e Switch (Strategia Alternativa)

```rman
-- Creare una image copy (copia 1:1 dei datafile, più veloce in restore)
BACKUP AS COPY DATABASE;

-- Switch: il DB usa direttamente le copie (restore istantaneo!)
SWITCH DATABASE TO COPY;
RECOVER DATABASE;
ALTER DATABASE OPEN;

-- Strategia "Incrementally Updated Backup" (IUB)
-- Giorno 0: Image copy
BACKUP AS COPY DATABASE TAG 'IUB_COPY';
-- Giorni 1-6: Applica incrementali sulla copia
BACKUP INCREMENTAL LEVEL 1 FOR RECOVER OF COPY WITH TAG 'IUB_COPY' DATABASE;
RECOVER COPY OF DATABASE WITH TAG 'IUB_COPY';
-- In caso di disastro: SWITCH DATABASE TO COPY; -> recover -> open
```

---

## 10. Diagnostica Corruzione (RMAN + DBMS_REPAIR)

### 10.1 Verifica Corruzione con RMAN
```rman
-- Check corruzione fisica
BACKUP VALIDATE DATABASE;

-- Check corruzione fisica + logica
BACKUP VALIDATE CHECK LOGICAL DATABASE;

-- Verifica un singolo datafile
VALIDATE DATAFILE 5;

-- Verifica un singolo backupset
VALIDATE BACKUPSET 123;
```

### 10.2 Verificare blocchi corrotti
```sql
-- Dopo VALIDATE, i blocchi corrotti finiscono qui
SELECT * FROM V$DATABASE_BLOCK_CORRUPTION;

-- Dettaglio
SELECT file#, block#, blocks, corruption_change#, corruption_type
FROM V$DATABASE_BLOCK_CORRUPTION
ORDER BY file#, block#;
```

### 10.3 Block Media Recovery (BMR) — Ripristino Singoli Blocchi
```rman
-- Ripristino chirurgico di blocchi corrotti (DB rimane APERTO!)
BLOCKRECOVER DATAFILE 5 BLOCK 1234;
BLOCKRECOVER DATAFILE 5 BLOCK 1234, 1235, 1236;

-- Recupera TUTTI i blocchi marcati corrotti
BLOCKRECOVER CORRUPTION LIST;
```

---

## 11. RMAN in Ambienti Multitenant (CDB/PDB)

```rman
-- Backup dell'intero CDB
BACKUP DATABASE;

-- Backup di una singola PDB
BACKUP PLUGGABLE DATABASE pdb1;

-- Backup di tablespace in una PDB
BACKUP TABLESPACE pdb1:users;

-- Restore/Recover di una PDB
ALTER PLUGGABLE DATABASE pdb1 CLOSE;
RESTORE PLUGGABLE DATABASE pdb1;
RECOVER PLUGGABLE DATABASE pdb1;
ALTER PLUGGABLE DATABASE pdb1 OPEN;

-- PITR di una singola PDB
ALTER PLUGGABLE DATABASE pdb1 CLOSE;
RESTORE PLUGGABLE DATABASE pdb1 UNTIL TIME "TO_DATE('2026-05-28 14:00:00','YYYY-MM-DD HH24:MI:SS')";
RECOVER PLUGGABLE DATABASE pdb1 UNTIL TIME "TO_DATE('2026-05-28 14:00:00','YYYY-MM-DD HH24:MI:SS')";
ALTER PLUGGABLE DATABASE pdb1 OPEN RESETLOGS;
```

---

## 12. Performance & Tuning RMAN

### 12.1 Parallelismo
```rman
-- Aumenta canali per backup più veloci (1 canale per CPU/disco)
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c2 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c3 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c4 DEVICE TYPE DISK;
  BACKUP DATABASE PLUS ARCHIVELOG;
}

-- Oppure (persistente)
CONFIGURE DEVICE TYPE DISK PARALLELISM 4;
```

### 12.2 Rate Limiting (per non saturare I/O in produzione)
```rman
-- Limita la velocità a 200 MB/sec totali
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK RATE 50M;
  ALLOCATE CHANNEL c2 DEVICE TYPE DISK RATE 50M;
  ALLOCATE CHANNEL c3 DEVICE TYPE DISK RATE 50M;
  ALLOCATE CHANNEL c4 DEVICE TYPE DISK RATE 50M;
  BACKUP DATABASE;
}
```

### 12.3 Monitoraggio Backup in Corso
```sql
-- Progresso backup RMAN in tempo reale (da SQL*Plus)
SELECT sid, serial#, opname, sofar, totalwork,
       ROUND(sofar/totalwork*100, 2) AS pct_complete,
       time_remaining AS secs_remaining
FROM V$SESSION_LONGOPS
WHERE opname LIKE 'RMAN%' AND totalwork > 0
ORDER BY start_time DESC;

-- Sessioni RMAN attive
SELECT s.sid, s.serial#, s.program, s.status,
       io.block_changes, io.physical_reads
FROM V$SESSION s
JOIN V$SESS_IO io ON s.sid = io.sid
WHERE s.program LIKE '%rman%';
```

### 12.4 MAXSETSIZE e FILESPERSET
```rman
-- Limita la dimensione del backupset (utile per NFS/tape)
BACKUP DATABASE MAXSETSIZE 10G;

-- Massimo file per backupset (aiuta il parallelismo)
BACKUP DATABASE FILESPERSET 4;
```

---

## 13. Catalog Management

```rman
-- Registrare un database nel catalog
REGISTER DATABASE;

-- Resincronizzare il catalog
RESYNC CATALOG;

-- Cancellare un database dal catalog
UNREGISTER DATABASE;

-- Reset incarnation dopo RESETLOGS
RESET DATABASE TO INCARNATION 3;
LIST INCARNATION;

-- Upgrade catalog dopo upgrade RMAN
UPGRADE CATALOG;
```

---

## 14. Comandi di Emergenza — Quick Reference

| Scenario | Comandi |
|---|---|
| **DB non si apre** | `STARTUP MOUNT; RESTORE DATABASE; RECOVER DATABASE; ALTER DATABASE OPEN;` |
| **PITR urgente** | `STARTUP MOUNT; RESTORE DB UNTIL TIME ...; RECOVER DB UNTIL TIME ...; ALTER DATABASE OPEN RESETLOGS;` |
| **Controlfile perso** | `STARTUP NOMOUNT; SET DBID xxx; RESTORE CONTROLFILE FROM AUTOBACKUP; ALTER DATABASE MOUNT; RESTORE DB; RECOVER DB; ALTER DATABASE OPEN RESETLOGS;` |
| **SPFILE perso** | `STARTUP FORCE NOMOUNT; SET DBID xxx; RESTORE SPFILE FROM AUTOBACKUP; STARTUP FORCE;` |
| **Blocco corrotto** | `BLOCKRECOVER CORRUPTION LIST;` |
| **Verifica backup ok** | `RESTORE DATABASE PREVIEW SUMMARY;` |
| **Tablespace perso** | `ALTER TABLESPACE x OFFLINE IMMEDIATE; RESTORE TABLESPACE x; RECOVER TABLESPACE x; ALTER TABLESPACE x ONLINE;` |
| **Archivelogs mancanti** | `RESTORE ARCHIVELOG FROM SEQUENCE xxx;` |
| **Pulizia spazio disco** | `CROSSCHECK BACKUP; DELETE EXPIRED BACKUP; DELETE OBSOLETE;` |
| **Clonare un DB** | `DUPLICATE TARGET DATABASE TO CLONE FROM ACTIVE DATABASE ...;` |

---

## 15. Script Cron per Backup Schedulato

```bash
#!/bin/bash
# /scripts/rman_backup_daily.sh
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH

LOG="/backup/rman/logs/rman_backup_$(date +%Y%m%d_%H%M).log"

${ORACLE_HOME}/bin/rman target / <<EOF > ${LOG} 2>&1
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c2 DEVICE TYPE DISK;
  BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE
    TAG 'DAILY_INC_L1'
    FORMAT '/backup/rman/%d_%T_%U.bkp';
  BACKUP ARCHIVELOG ALL
    NOT BACKED UP 1 TIMES
    DELETE INPUT
    FORMAT '/backup/rman/arch_%d_%T_%U.bkp';
  DELETE NOPROMPT OBSOLETE;
}
EXIT;
EOF

# Check esito
if grep -q "RMAN-" ${LOG}; then
  echo "RMAN BACKUP FAILED - check ${LOG}" | mail -s "RMAN ALERT $(hostname)" dba@company.com
fi
```

Crontab:
```text
# Backup incrementale giornaliero alle 01:00
0 1 * * * /scripts/rman_backup_daily.sh > /dev/null 2>&1
# Backup full la domenica alle 23:00
0 23 * * 0 /scripts/rman_backup_full.sh > /dev/null 2>&1
```

---

## 16. Riferimenti Oracle Ufficiali

- Oracle 19c RMAN Reference: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/
- Oracle 19c Backup and Recovery User's Guide: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/
- MOS Doc ID 360416.1 — RMAN Backup and Recovery Best Practices
- MOS Doc ID 1526085.1 — Block Media Recovery
- MOS Doc ID 469691.1 — RMAN Backup Validation
