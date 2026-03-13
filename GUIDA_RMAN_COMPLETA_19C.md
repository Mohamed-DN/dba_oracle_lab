# GUIDA LAB RMAN ORACLE 19C - COMPLETA (RAC + DATA GUARD + CDB/PDB)

Aggiornata al 13 marzo 2026.
Target: lab VirtualBox Oracle 19c (`RACDB` primary, `RACDB_STBY` standby, `dbtarget` ambiente test).

Questa guida e pensata per uso laboratorio: include configurazione, automazione, recovery e test pratici end-to-end.

## 0) Regole di sicurezza del lab

- Esegui i test distruttivi prima su `dbtarget` o su clone.
- Prima di ogni test importante crea snapshot VM VirtualBox.
- Mantieni un diario test (`data, scenario, risultato, tempo recovery`).
- Se fai test su RAC primary/standby, isola una finestra lab dedicata.

## 1) Obiettivi e metriche (RPO/RTO)

Definisci per ogni database:

- RPO: massimo dato perdibile (esempio 30 min su primary critico)
- RTO: tempo massimo di ripristino (esempio 2 ore)

Mappatura esempio per il tuo lab:

| Database | Ruolo | RPO target | RTO target | Nodo backup principale |
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
- `CONTROL_FILE_RECORD_KEEP_TIME` coerente con retention
- sincronizzazione oraria tra nodi RAC e standby

## 3) Fondamentali RMAN 19c da rispettare

- `CONTROLFILE AUTOBACKUP` sempre ON.
- In RAC configura `SNAPSHOT CONTROLFILE` su storage condiviso.
- In Data Guard imposta policy archivelog coerente con apply standby.
- Preferisci backupset compressi su disco per lab.
- Usa Recovery Catalog se gestisci piu database/ruoli/switchover frequenti.

Nota importante Oracle 19c:

- Data Recovery Advisor (DRA) e deprecato. La recovery va gestita con runbook RMAN/SQL espliciti.

## 4) Configurazione RMAN baseline (per tutti i DB)

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

Data Guard (sul primary):

```rman
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```

## 5) Block Change Tracking (BCT)

Abilita BCT sul database dove esegui incrementali principali.

```sql
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING
USING FILE '+DATA/RACDB_STBY/bct_racdb_stby.ctf';

SELECT status, filename FROM v$block_change_tracking;
```

## 6) Strategia backup completa per il tuo lab

### 6.1 Piano consigliato

| Frequenza | `RACDB_STBY` | `RACDB` | `dbtarget` |
|---|---|---|---|
| Domenica 01:00 | L0 + arch + controlfile/spfile | arch | full |
| Lun-Sab 01:00 | L1 + arch + controlfile/spfile | arch | L1 |
| Ogni ora | archivelog | archivelog (opzionale ridondanza) | archivelog |
| Giornaliero | crosscheck + delete obsolete | crosscheck + delete obsolete | idem |
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

### 7.5 Cron esempio

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

Comandi RMAN:

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

### 9.1 Creazione owner catalog

```sql
CREATE USER rman IDENTIFIED BY "StrongPwd#1"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;

GRANT RECOVERY_CATALOG_OWNER TO rman;
```

### 9.2 Creazione catalog e registrazione DB

```rman
RMAN CATALOG rman/StrongPwd#1@CATDB;
CREATE CATALOG;

RMAN TARGET / CATALOG rman/StrongPwd#1@CATDB;
REGISTER DATABASE;
RESYNC CATALOG;
```

## 10) Runbook completo di recovery (casi principali)

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

### 10.8 PDB PITR (solo PDB)

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

## 11) DUPLICATE: clone e standby

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

## 12) Data Guard e RMAN: regole pratiche

- backup pesanti su standby per ridurre impatto sul primary
- `CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY` sul primary
- verifica apply lag prima di cancellare archivelog
- dopo switchover/failover rivedi cron, canali, path FRA e policy
- con catalog, registra sia primary che standby

## 13) RAC e RMAN: punti critici

- usa servizio dedicato backup (evita connessioni casuali ai nodi)
- snapshot controlfile su shared storage
- evita job duplicati simultanei da nodi diversi
- controlla `gv$instance` e carico I/O durante backup

## 14) LAB TEST SUITE COMPLETA (VirtualBox)

Ogni test ha: obiettivo, setup, esecuzione, verifica, rollback.

### Test 00 - Baseline backup/validate

Obiettivo: confermare che la catena backup e valida.

1. Esegui L0 o L1.
2. Esegui `RESTORE DATABASE PREVIEW SUMMARY`.
3. Esegui `RESTORE DATABASE VALIDATE`.
4. Salva output log.

Esito atteso: nessun errore RMAN/ORA.

### Test 01 - Recovery datafile

Obiettivo: recuperare un datafile offline.

1. Porta datafile offline.
2. `RESTORE DATAFILE` + `RECOVER DATAFILE`.
3. Riporta online.

Esito atteso: tablespace nuovamente accessibile.

### Test 02 - Recovery tablespace

Obiettivo: ripristino completo tablespace applicativo.

1. `ALTER TABLESPACE ... OFFLINE IMMEDIATE`.
2. `RESTORE/RECOVER TABLESPACE`.
3. `ALTER TABLESPACE ... ONLINE`.

Esito atteso: oggetti leggibili e scrivibili.

### Test 03 - Block corruption

Obiettivo: verificare block media recovery.

1. Individua blocchi corrotti con `v$database_block_corruption`.
2. `RECOVER CORRUPTION LIST`.
3. Riesegui validate.

Esito atteso: nessuna corruption residua.

### Test 04 - DBPITR

Obiettivo: annullare errore umano con recovery a tempo.

1. Crea tabella test e inserisci righe.
2. Annota timestamp T0.
3. Esegui operazione distruttiva dopo T0.
4. Esegui DBPITR a T0.

Esito atteso: dati tornano allo stato T0.

### Test 05 - PDB PITR

Obiettivo: recovery puntuale di una singola PDB.

1. Crea evento errore in `PDBAPP`.
2. Esegui `RECOVER PLUGGABLE DATABASE ... UNTIL TIME`.
3. Verifica schema applicativo.

Esito atteso: solo la PDB target torna indietro nel tempo.

### Test 06 - Recover table

Obiettivo: recupero tabella senza DBPITR globale.

1. Crea tabella `APP.RMAN_TEST`.
2. Esegui `DROP TABLE`.
3. Esegui comando `RECOVER TABLE`.
4. Importa dump se `NOTABLEIMPORT`.

Esito atteso: tabella ripristinata con dati.

### Test 07 - TSPITR

Obiettivo: recuperare solo un tablespace a T0.

1. Crea dati in `APP_TS`.
2. Danno logico dopo T0.
3. Esegui `RECOVER TABLESPACE ... UNTIL TIME`.

Esito atteso: tablespace coerente al tempo T0.

### Test 08 - Controlfile recovery

Obiettivo: ripartire da controlfile autobackup.

1. Simula perdita controlfile (solo clone/lab).
2. `RESTORE CONTROLFILE FROM AUTOBACKUP`.
3. mount + recover + open resetlogs.

Esito atteso: database aperto e consistente.

### Test 09 - SPFILE recovery

Obiettivo: recuperare parametri istanza da backup.

1. Simula perdita spfile su clone.
2. `RESTORE SPFILE FROM AUTOBACKUP`.
3. restart database.

Esito atteso: startup regolare con parametri corretti.

### Test 10 - Restore su host alternativo

Obiettivo: DR drill completo.

1. Prepara host clone con Oracle Home compatibile.
2. Catalog/trasferisci backup.
3. restore + recover + open resetlogs.

Esito atteso: DB operativo su host alternativo.

### Test 11 - Duplicate clone

Obiettivo: creare ambiente test da produzione lab.

1. `DUPLICATE ... FROM ACTIVE DATABASE`.
2. Apri clone e valida applicazione.

Esito atteso: clone coerente e utilizzabile.

### Test 12 - Switchover + backup continuity

Obiettivo: verificare continuita backup dopo cambio ruoli DG.

1. Esegui switchover.
2. Aggiorna scheduling backup.
3. Esegui nuovo ciclo L1 + arch.

Esito atteso: backup corretti anche con ruoli invertiti.

## 15) Troubleshooting rapido

- `ORA-19809: limit exceeded for recovery files`
  - aumenta FRA o esegui cleanup (`DELETE OBSOLETE`, `DELETE EXPIRED`).
- `RMAN-06059: expected archived log not found`
  - `CROSSCHECK ARCHIVELOG ALL` + `DELETE EXPIRED ARCHIVELOG ALL`.
- archivelog non cancellati
  - verifica policy Data Guard e stato apply.
- backup lenti
  - rivedi parallelism, compressione, throughput storage.
- restore non trova backup
  - cataloga path con `CATALOG START WITH ... NOPROMPT`.

## 16) Checklist operativa

Giornaliera:

- verifica esito job RMAN
- controlla FRA usage
- verifica apply lag DG

Settimanale:

- restore validate
- report obsolete/need backup
- revisione trend spazio

Mensile:

- test recovery reale documentato
- test almeno 1 scenario logico (table/pitr)
- test almeno 1 scenario fisico (datafile/controlfile)

## 17) Cosa tenere nel repository GitHub

- guida RMAN completa
- script schedulazione backup
- runbook incidenti
- log template test
- report test mensili (cartella `docs/tests/rman/` consigliata)

## 18) Fonti usate (Oracle ufficiali + Oracle-Base)

Oracle ufficiale 19c:

- Backup and Recovery User's Guide: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/
- RMAN backup concepts: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-backup-concepts.html
- Configurazione RMAN base: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/configuring-rman-client-basic.html
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

## 19) Stato di completamento

La guida e completa quando:

- backup L0/L1/archivelog funzionano da cron
- esiste almeno 1 restore testato negli ultimi 7 giorni
- esiste almeno 1 test logico (PITR o RECOVER TABLE) negli ultimi 30 giorni
- i runbook sono versionati nel repo
- dopo ogni RU patching viene ripetuto almeno un restore validate
