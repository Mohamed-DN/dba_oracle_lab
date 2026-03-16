# ORACLE 19C RMAN LAB GUIDE - COMPLETE (RAC + DATA GUARD + CDB/PDB)

Aggiornata al 13 marzo 2026.
Target: VirtualBox Oracle 19c lab (`RACDB` primary, `RACDB_STBY` standby, `dbtarget` test environment).

This guide is designed for laboratory use: it includes configuration, automation, recovery and end-to-end practical tests.

## 0) Regole di sicurezza del lab

- Perform destructive testing first on `dbtarget` or clone.
- Before every important test create VirtualBox VM snapshots.
- Mantieni un diario test (`data, scenario, risultato, tempo recovery`).
- If you test on RAC primary/standby, isolate a dedicated lab window.

## 1) Obiettivi e metriche (RPO/RTO)

Definisci per ogni database:

- RPO: maximum data that can be lost (example 30 min on critical primary)
- RTO: maximum recovery time (example 2 hours)

Example mapping for your lab:

| Database | Ruolo | RPO target | RTO target | Primary backup node |
|---|---|---|---|---|
| `RACDB` | Primary RAC | 30-60 min | 1-3 ore | `RACDB_STBY` |
| `RACDB_STBY` | Physical Standby | 60 min | 1-3 ore | `RACDB_STBY` |
| `dbtarget` | Target/clone | 4 ore | 2-6 ore | locale |

## 2) Prerequisiti tecnici obbligatori

Esegui su ogni DB.

```sql
SELECT name, db_unique_name, database_role, open_mode, log_mode, force_logging, flashback_on
FROM v$database;

SHOW PARAMETER db_recovery_file_dest;
SHOW PARAMETER db_recovery_file_dest_size;
SHOW PARAMETER control_file_record_keep_time;

SELECT file_type, percent_space_used, percent_space_reclaimable, number_of_files
FROM v$recovery_area_usage
ORDER BY file_type;

SELECT inst_id, instance_name, host_name, status
FROM gv$instance
ORDER BY inst_id;
```

Controlli minimi:

- `LOG_MODE = ARCHIVELOG`
- FRA configurata e dimensionata
- `CONTROL_FILE_RECORD_KEEP_TIME` consistent with retention
- time synchronization between RAC and standby nodes

## 3) Fondamentali RMAN 19c da rispettare

- `CONTROLFILE AUTOBACKUP` sempre ON.
- In RAC configura `SNAPSHOT CONTROLFILE` su storage condiviso.
- In Data Guard, set archivelog policy consistent with apply standby.
- Preferisci backupset compressi su disco per lab.
- Usa Recovery Catalog se gestisci piu database/ruoli/switchover frequenti.

Nota importante Oracle 19c:

- Data Recovery Advisor (DRA) is deprecated. Recovery must be managed with explicit RMAN/SQL runbooks.

## 4) Baseline RMAN configuration (for all DBs)

Da `rman target /`:

```rman
SHOW ALL;

CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE BACKUP OPTIMIZATION ON;

CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO COMPRESSED BACKUPSET;
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';

CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '+RECO/%d/%T/%U';
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '+RECO/%F';
```

RAC (da fare su DB RAC):

```rman
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '+RECO/RACDB/snapcf_racdb.f';
```

Data Guard (on primary):

```rman
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```

## 5) Block Change Tracking (BCT)

Enable BCT on the database where you run major incrementals.

```sql
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING
USING FILE '+DATA/RACDB_STBY/bct_racdb_stby.ctf';

SELECT status, filename FROM v$block_change_tracking;
```

## 6) Complete backup strategy for your lab

### 6.1 Recommended plan

| Frequenza | `RACDB_STBY` | `RACDB` | `dbtarget` |
|---|---|---|---|
| Domenica 01:00 | L0 + arch + controlfile/spfile | arch | full |
| Lun-Sab 01:00 | L1 + arch + controlfile/spfile | arch | L1 |
| Ogni ora | archivelog | archivelog (opzionale ridondanza) | archivelog |
| Daily | crosscheck + delete obsolete | crosscheck + delete obsolete | idem |
| Settimanale | restore validate | restore validate | restore validate |
| Mensile | test recovery reale | test recovery reale | test recovery reale |

### 6.2 Naming standard

- `WK_L0_STBY`
- `DY_L1_STBY`
- `ARCH_1H`
- `CTRL_SPFILE_DAILY`
- `VAL_WEEKLY`

## 7) Script operativi consigliati

Path suggeriti:

- `/home/oracle/scripts/rman`
- `/home/oracle/scripts/rman/log`

### 7.1 Level 0 (standby)

```bash
#!/bin/bash
set -euo pipefail
export ORACLE_SID=RACDB1
export ORAENV_ASK=NO
. oraenv >/dev/null 2>&1

LOGDIR=/home/oracle/scripts/rman/log
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/rman_l0_$(date +%F_%H%M).log"

rman target / log="$LOGFILE" <<'RMAN'
RUN {
  SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";
  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 0 DATABASE TAG 'WK_L0_STBY';
  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL NOT BACKED UP 1 TIMES DELETE INPUT TAG 'ARCH_1H';
  BACKUP CURRENT CONTROLFILE TAG 'CTRL_SPFILE_DAILY';
  BACKUP SPFILE TAG 'CTRL_SPFILE_DAILY';
  DELETE NOPROMPT OBSOLETE;
}
RMAN
```

### 7.2 Level 1 (standby)

```bash
#!/bin/bash
set -euo pipefail
export ORACLE_SID=RACDB1
export ORAENV_ASK=NO
. oraenv >/dev/null 2>&1

LOGDIR=/home/oracle/scripts/rman/log
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/rman_l1_$(date +%F_%H%M).log"

rman target / log="$LOGFILE" <<'RMAN'
RUN {
  SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";
  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 DATABASE TAG 'DY_L1_STBY';
  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL NOT BACKED UP 1 TIMES DELETE INPUT TAG 'ARCH_1H';
  BACKUP CURRENT CONTROLFILE TAG 'CTRL_SPFILE_DAILY';
  BACKUP SPFILE TAG 'CTRL_SPFILE_DAILY';
}
RMAN
```

### 7.3 Archivelog frequente

```bash
#!/bin/bash
set -euo pipefail
export ORACLE_SID=RACDB1
export ORAENV_ASK=NO
. oraenv >/dev/null 2>&1

LOGDIR=/home/oracle/scripts/rman/log
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/rman_arch_$(date +%F_%H%M).log"

rman target / log="$LOGFILE" <<'RMAN'
RUN {
  SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";
  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL NOT BACKED UP 1 TIMES DELETE INPUT TAG 'ARCH_1H';
}
RMAN
```

### 7.4 Maintenance + validate

```bash
#!/bin/bash
set -euo pipefail
export ORACLE_SID=RACDB1
export ORAENV_ASK=NO
. oraenv >/dev/null 2>&1

LOGDIR=/home/oracle/scripts/rman/log
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/rman_maint_$(date +%F_%H%M).log"

rman target / log="$LOGFILE" <<'RMAN'
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT EXPIRED BACKUP;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
DELETE NOPROMPT OBSOLETE;
RESTORE DATABASE PREVIEW SUMMARY;
RESTORE DATABASE VALIDATE;
BACKUP VALIDATE CHECK LOGICAL DATABASE;
RMAN
```

### 7.5 Cron example

```cron
# L0 domenica
0 1 * * 0 /home/oracle/scripts/rman/rman_l0_stby.sh

# L1 lun-sab
0 1 * * 1-6 /home/oracle/scripts/rman/rman_l1_stby.sh

# Archivelog ogni ora
0 * * * * /home/oracle/scripts/rman/rman_arch.sh

# Maintenance + validate settimanale
30 2 * * 6 /home/oracle/scripts/rman/rman_maint_validate.sh
```

## 8) Reporting e monitoraggio

RMAN commands:

```rman
LIST BACKUP SUMMARY;
LIST BACKUP OF DATABASE COMPLETED AFTER 'SYSDATE-7';
LIST BACKUP OF ARCHIVELOG FROM TIME 'SYSDATE-1';
REPORT NEED BACKUP DAYS 7 DATABASE;
REPORT OBSOLETE;
SHOW ALL;
```

Query SQL:

```sql
SELECT session_key,
       input_type,
       status,
       TO_CHAR(start_time,'YYYY-MM-DD HH24:MI') start_time,
       TO_CHAR(end_time,'YYYY-MM-DD HH24:MI') end_time,
       ROUND(output_bytes/1024/1024/1024,2) output_gb
FROM v$rman_backup_job_details
ORDER BY session_key DESC
FETCH FIRST 30 ROWS ONLY;

SELECT file_type, percent_space_used, percent_space_reclaimable, number_of_files
FROM v$recovery_area_usage
ORDER BY file_type;
```

## 9) Recovery Catalog (raccomandato)

### 9.1 Creation of owner catalogue

```sql
CREATE USER rman IDENTIFIED BY "StrongPwd#1"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;

GRANT RECOVERY_CATALOG_OWNER TO rman;
```

### 9.2 Catalog creation and DB registration

```rman
RMAN CATALOG rman/StrongPwd#1@CATDB;
CREATE CATALOG;

RMAN TARGET / CATALOG rman/StrongPwd#1@CATDB;
REGISTER DATABASE;
RESYNC CATALOG;
```

## 10) Complete recovery runbook (main cases)

### 10.1 Datafile recovery (media failure)

```rman
SQL "ALTER DATABASE DATAFILE 7 OFFLINE";
RESTORE DATAFILE 7;
RECOVER DATAFILE 7;
SQL "ALTER DATABASE DATAFILE 7 ONLINE";
```

### 10.2 Tablespace recovery

```rman
SQL "ALTER TABLESPACE APP_TS OFFLINE IMMEDIATE";
RESTORE TABLESPACE APP_TS;
RECOVER TABLESPACE APP_TS;
SQL "ALTER TABLESPACE APP_TS ONLINE";
```

### 10.3 Block media recovery

```sql
SELECT file#, block#, corruption_type
FROM v$database_block_corruption;
```

```rman
RECOVER CORRUPTION LIST;
-- oppure puntuale:
RECOVER DATAFILE 8 BLOCK 13;
```

### 10.4 Complete database recovery (nessuna perdita redo)

```rman
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
RESTORE DATABASE;
RECOVER DATABASE;
ALTER DATABASE OPEN;
```

### 10.5 Incomplete database recovery / DBPITR

```rman
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
RUN {
  SET UNTIL TIME "TO_DATE('2026-03-13 10:15:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE DATABASE;
  RECOVER DATABASE;
}
ALTER DATABASE OPEN RESETLOGS;
```

### 10.6 Control file recovery da autobackup

```rman
SET DBID 1234567890;
STARTUP NOMOUNT;
RESTORE CONTROLFILE FROM AUTOBACKUP;
ALTER DATABASE MOUNT;
CATALOG START WITH '+RECO/RACDB/' NOPROMPT;
RECOVER DATABASE;
ALTER DATABASE OPEN RESETLOGS;
```

### 10.7 SPFILE recovery da autobackup

```rman
SET DBID 1234567890;
STARTUP FORCE NOMOUNT;
RESTORE SPFILE FROM AUTOBACKUP;
STARTUP FORCE NOMOUNT;
```

### 10.8 PDB PITR (PDB only)

```rman
RUN {
  RECOVER PLUGGABLE DATABASE PDBAPP
  UNTIL TIME "TO_DATE('2026-03-13 10:15:00','YYYY-MM-DD HH24:MI:SS')"
  AUXILIARY DESTINATION '/u02/rman_aux';
}
```

### 10.9 TSPITR (tablespace point-in-time recovery)

```rman
RUN {
  RECOVER TABLESPACE APP_TS
  UNTIL TIME "TO_DATE('2026-03-13 10:15:00','YYYY-MM-DD HH24:MI:SS')"
  AUXILIARY DESTINATION '/u02/rman_aux';
}
```

### 10.10 Recover table (errore umano: DROP/DELETE)

```rman
RECOVER TABLE APP.RMAN_TEST
  OF PLUGGABLE DATABASE PDBAPP
  UNTIL TIME "TO_DATE('2026-03-13 10:15:00','YYYY-MM-DD HH24:MI:SS')"
  AUXILIARY DESTINATION '/u02/rman_aux'
  DATAPUMP DESTINATION '/u02/rman_aux'
  DUMP FILE 'rman_test.dmp'
  NOTABLEIMPORT;
```

Import manuale (se usi `NOTABLEIMPORT`):

```bash
impdp \"/ as sysdba\" directory=DATA_PUMP_DIR dumpfile=rman_test.dmp logfile=imp_rman_test.log
```

### 10.11 Restore su host alternativo (disaster drill)

```rman
STARTUP NOMOUNT;
RESTORE CONTROLFILE FROM AUTOBACKUP;
ALTER DATABASE MOUNT;

RUN {
  SET NEWNAME FOR DATABASE TO '/u03/oradata/CLONEDR/%b';
  RESTORE DATABASE;
  SWITCH DATAFILE ALL;
  RECOVER DATABASE;
}
ALTER DATABASE OPEN RESETLOGS;
```

## 11) DUPLICATE: clone and standby

### 11.1 Duplicate per clone/test

```rman
CONNECT TARGET sys@RACDB;
CONNECT AUXILIARY sys@CLONEDB;

DUPLICATE TARGET DATABASE TO CLONEDB
  FROM ACTIVE DATABASE
  SPFILE
    PARAMETER_VALUE_CONVERT 'RACDB','CLONEDB'
    SET db_unique_name='CLONEDB'
  NOFILENAMECHECK;
```

### 11.2 Duplicate for standby

```rman
CONNECT TARGET sys@RACDB;
CONNECT AUXILIARY sys@RACDB_STBY;

DUPLICATE TARGET DATABASE FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  NOFILENAMECHECK;
```

## 12) Data Guard and RMAN: rules of thumb

- heavy backups on standby to reduce impact on primary
- `CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY` on the primary
- check apply lag before deleting archivelog
- after switchover/failover review cron, channels, FRA path and policy
- with catalog, register both primary and standby

## 13) RAC e RMAN: punti critici

- usa servizio dedicato backup (evita connessioni casuali ai nodi)
- snapshot controlfile su shared storage
- evita job duplicati simultanei da nodi diversi
- check `gv$instance` and I/O load during backup

## 14) COMPLETE LAB TEST SUITE (VirtualBox)

Each test has: objective, setup, execution, verification, rollback.

### Test 00 - Baseline backup/validate

Obiettivo: confermare che la catena backup e valida.

1. Esegui L0 o L1.
2. Esegui `RESTORE DATABASE PREVIEW SUMMARY`.
3. Esegui `RESTORE DATABASE VALIDATE`.
4. Save log output.

Esito atteso: nessun errore RMAN/ORA.

### Test 01 - Recovery datafile

Obiettivo: recuperare un datafile offline.

1. Porta datafile offline.
2. `RESTORE DATAFILE` + `RECOVER DATAFILE`.
3. Riporta online.

Esito atteso: tablespace nuovamente accessibile.

### Test 02 - Recovery tablespace

Objective: Complete application tablespace recovery.

1. `ALTER TABLESPACE ... OFFLINE IMMEDIATE`.
2. `RESTORE/RECOVER TABLESPACE`.
3. `ALTER TABLESPACE ... ONLINE`.

Esito atteso: oggetti leggibili e scrivibili.

### Test 03 - Block corruption

Obiettivo: verificare block media recovery.

1. Locate corrupt blocks with `v$database_block_corruption`.
2. `RECOVER CORRUPTION LIST`.
3. Riesegui validate.

Esito atteso: nessuna corruption residua.

### Test 04 - DBPITR

Objective: eliminate human error with timed recovery.

1. Create test table and insert rows.
2. Annota timestamp T0.
3. Perform destructive operation after T0.
4. Esegui DBPITR a T0.

Expected outcome: data returns to state T0.

### Test 05 - PDB PITR

Obiettivo: recovery puntuale di una singola PDB.

1. Crea evento errore in `PDBAPP`.
2. Esegui `RECOVER PLUGGABLE DATABASE ... UNTIL TIME`.
3. Check application scheme.

Expected outcome: only the target PDB goes back in time.

### Test 06 - Recover table

Objective: Table recovery without global DBPITR.

1. Create table `APP.RMAN_TEST`.
2. Esegui `DROP TABLE`.
3. Esegui comando `RECOVER TABLE`.
4. Importa dump se `NOTABLEIMPORT`.

Expected outcome: table restored with data.

### Test 07 - TSPITR

Goal: Recover only one tablespace at T0.

1. Crea dati in `APP_TS`.
2. Logical damage after T0.
3. Esegui `RECOVER TABLESPACE ... UNTIL TIME`.

Esito atteso: tablespace coerente al tempo T0.

### Test 08 - Controlfile recovery

Obiettivo: ripartire da controlfile autobackup.

1. Simulate controlfile loss (clone/lab only).
2. `RESTORE CONTROLFILE FROM AUTOBACKUP`.
3. mount + recover + open resetlogs.

Esito atteso: database aperto e consistente.

### Test 09 - SPFILE recovery

Objective: Recover instance parameters from backup.

1. Simula perdita spfile su clone.
2. `RESTORE SPFILE FROM AUTOBACKUP`.
3. restart database.

Expected outcome: regular startup with correct parameters.

### Test 10 - Restore su host alternativo

Objective: DR drill complete.

1. Prepare clone hosts with compatible Oracle Home.
2. Catalog/trasferisci backup.
3. restore + recover + open resetlogs.

Expected outcome: DB operational on alternative host.

### Test 11 - Duplicate clone

Objective: create test environment from lab production.

1. `DUPLICATE ... FROM ACTIVE DATABASE`.
2. Apri clone e valida applicazione.

Esito atteso: clone coerente e utilizzabile.

### Test 12 - Switchover + backup continuity

Objective: verify backup continuity after change of DG roles.

1. Esegui switchover.
2. Aggiorna scheduling backup.
3. Execute new cycle L1 + arch.

Expected outcome: correct backups even with reversed roles.

## 15) Troubleshooting rapido

- `ORA-19809: limit exceeded for recovery files`
  - aumenta FRA o esegui cleanup (`DELETE OBSOLETE`, `DELETE EXPIRED`).
- `RMAN-06059: expected archived log not found`
  - `CROSSCHECK ARCHIVELOG ALL` + `DELETE EXPIRED ARCHIVELOG ALL`.
- archivelog non cancellati
  - check Data Guard policy and apply status.
- backup lenti
  - rivedi parallelism, compressione, throughput storage.
- restore non trova backup
  - catalog path with `CATALOG START WITH ... NOPROMPT`.

## 16) Operational checklist

Giornaliera:

- check RMAN job outcome
- controlla FRA usage
- check apply lag DG

Settimanale:

- restore validate
- report obsolete/need backup
- revisione trend spazio

Mensile:

- test recovery reale documentato
- test almeno 1 scenario logico (table/pitr)
- test almeno 1 scenario fisico (datafile/controlfile)

## 17) What to keep in the GitHub repository

- Complete RMAN guide
- script schedulazione backup
- runbook incidenti
- log template test
- report test mensili (cartella `docs/tests/rman/` consigliata)

## 18) Fonti usate (Oracle ufficiali + Oracle-Base)

Oracle ufficiale 19c:

- Backup and Recovery User's Guide: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/
- RMAN backup concepts: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-backup-concepts.html
- Basic RMAN configuration: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/configuring-rman-client-basic.html
- Complete database recovery: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-complete-database-recovery.html
- Advanced recovery: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-performing-advanced-database-recovery.html
- Flashback/DBPITR: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-performing-flashback-dbpitr.html
- Managing recovery catalog: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/managing-recovery-catalog.html
- Duplicating databases: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-duplicating-databases.html
- RMAN RECOVER reference: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/RECOVER.html
- RMAN BACKUP reference: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/BACKUP.html
- RAC backup/recovery notes: https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/configuring-recovery-manager-and-archiving.html
- Data Guard Concepts and Administration: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/

Riferimento storico (non normativo per 19c):

- Oracle-Base RMAN 9i article: https://oracle-base.com/articles/9i/recovery-manager-9i

## 19) Completion status

The guide is complete when:

- backup L0/L1/archivelog funzionano da cron
- there is at least 1 restore tested in the last 7 days
- there is at least 1 logical test (PITR or RECOVER TABLE) in the last 30 days
- i runbook sono versionati nel repo
- after each RU patching at least one restore validate is repeated
