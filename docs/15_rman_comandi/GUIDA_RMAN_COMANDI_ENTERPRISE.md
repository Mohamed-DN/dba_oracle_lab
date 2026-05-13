# Guida RMAN Enterprise Completa — Comandi, Strategie, Multitenant, TDE e Troubleshooting

> Riferimento operativo completo per ambienti Oracle 19c/21c/23ai.
> Copre Single Instance, RAC, Data Guard, Multitenant e Encryption.

---

## 1. Prerequisiti Enterprise

### 1.1 Checklist Pre-Backup

Prima di operare con RMAN verificare **sempre**:

```sql
-- 1. Modalità database
SELECT name, db_unique_name, log_mode, database_role, open_mode, flashback_on, cdb
FROM v$database;

-- 2. Fast Recovery Area (FRA) — dimensionamento e utilizzo
SELECT name,
       ROUND(space_limit/1024/1024/1024,2) AS limit_gb,
       ROUND(space_used/1024/1024/1024,2) AS used_gb,
       ROUND(space_reclaimable/1024/1024/1024,2) AS reclaimable_gb,
       ROUND((space_used - space_reclaimable)/space_limit * 100, 1) AS pct_effective
FROM v$recovery_file_dest;

-- 3. Dettaglio utilizzo FRA per tipo di file
SELECT file_type,
       ROUND(percent_space_used,1) AS pct_used,
       ROUND(percent_space_reclaimable,1) AS pct_reclaimable,
       number_of_files
FROM v$flash_recovery_area_usage
WHERE percent_space_used > 0
ORDER BY percent_space_used DESC;

-- 4. Block Change Tracking (BCT) — velocizza incremental
SELECT status, filename, bytes/1024/1024 AS size_mb FROM v$block_change_tracking;

-- 5. Encryption Wallet/Keystore status
SELECT wrl_type, status, wallet_type, wallet_order FROM v$encryption_wallet;

-- 6. Ambiente OS
-- echo $ORACLE_HOME / echo $ORACLE_SID / tnsping PROD
```

### 1.2 Concetti Chiave da Padroneggiare

| Concetto | Descrizione |
|---|---|
| **Target** | Database di cui fai backup |
| **Auxiliary** | Database clone/duplicate/TSPITR |
| **Catalog** | Repository metadati backup centralizzato (opzionale ma consigliato) |
| **Backupset** | File logici compressi RMAN (default) |
| **Image Copy** | Copia byte-per-byte dei datafile (restore istantaneo con SWITCH) |
| **Level 0** | Baseline per catena incrementale |
| **Level 1 Differential** | Solo blocchi cambiati dall'ultimo L0 o L1 |
| **Level 1 Cumulative** | Solo blocchi cambiati dall'ultimo L0 |
| **Recovery Window** | Retention basata su giorni (es. 14 days) |
| **Redundancy** | Retention basata su numero copie |
| **FRA** | Oracle gestisce spazio e reclaim automaticamente |
| **BCT** | Block Change Tracking — riduce I/O per incremental |
| **SECTION SIZE** | Parallelismo intra-datafile per file grandi |
| **Backup Piece** | File fisico generato, contenuto nel backupset |

---

## 2. Connessioni RMAN

```bash
# Connessione locale (OS authentication)
rman target /

# Connessione con password (remota)
rman target sys/password@PROD

# Con Recovery Catalog
rman target / catalog rman_user/pwd@CATDB

# Con Auxiliary (per DUPLICATE)
rman target sys/pwd@PROD auxiliary sys/pwd@CLONE

# Logging su file
rman target / log=/backup/logs/rman_$(date +%Y%m%d).log append
```

---

## 3. Configurazione Enterprise Baseline

### 3.1 Single Instance (standard)

```rman
-- Visualizza configurazione corrente
SHOW ALL;

-- Retention: 14 giorni recovery window (allinea a SLA)
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;

-- Controlfile autobackup: SEMPRE ON
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '+RECO/%F';

-- Ottimizzazione: evita backup ridondanti di archivelog
CONFIGURE BACKUP OPTIMIZATION ON;

-- Parallelismo e compressione
CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO COMPRESSED BACKUPSET;
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';

-- Format: organizzato per data
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '+RECO/%d/%T/%U';

-- Snapshot controlfile (necessario per backup consistente)
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '+RECO/%d/snapcf_%d.f';
```

Abilita BCT per incremental veloci:
```sql
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+RECO/DB/bct.f';
```

### 3.2 Oracle RAC (Multi-Channel Load Balancing)

In RAC ogni canale si connette a un nodo specifico per distribuire il carico I/O:

```rman
CONFIGURE CHANNEL 1 DEVICE TYPE DISK CONNECT 'SYSBACKUP/pwd@PROD1' FORMAT '+RECO/%d/%T/%U';
CONFIGURE CHANNEL 2 DEVICE TYPE DISK CONNECT 'SYSBACKUP/pwd@PROD2' FORMAT '+RECO/%d/%T/%U';
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '+RECO/RACDB/snapcf_racdb.f';
```

### 3.3 Data Guard (Primary + Standby)

```rman
-- Primary: non cancellare archivelog finché non applicati su standby
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

-- Configurazione standby per backup offloading
CONFIGURE DB_UNIQUE_NAME 'STBY' CONNECT IDENTIFIER 'STBY';
CONFIGURE DEFAULT DEVICE TYPE TO DISK FOR DB_UNIQUE_NAME 'STBY';
```

**Backup da Standby (Active Data Guard — riduce carico I/O sul primary):**
```rman
rman target sys/pwd@STBY
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG TAG 'STBY_FULL';
```

### 3.4 Encryption (TDE Integration)

```rman
-- Cifratura trasparente (usa il Wallet/Keystore aperto)
CONFIGURE ENCRYPTION FOR DATABASE ON;

-- Cifratura con password (se wallet non disponibile al restore)
SET ENCRYPTION ON IDENTIFIED BY 'MyBackupPwd' ONLY;

-- Dual mode: decrypt con wallet O password
CONFIGURE ENCRYPTION FOR DATABASE ON;
SET ENCRYPTION IDENTIFIED BY 'MyBackupPwd';
```

> **IMPORTANTE**: Se perdi sia il wallet che la password, i backup cifrati sono IRRECUPERABILI.
> Backup del wallet: `cp -rp $ORACLE_BASE/admin/DB/wallet /backup/secure/wallet_bkp_$(date +%Y%m%d)`

### 3.5 SBT / Tape / Media Manager

```rman
-- Configurazione canale per tape (es. NetBackup, CommVault)
CONFIGURE CHANNEL DEVICE TYPE sbt
  PARMS 'SBT_LIBRARY=/usr/openv/netbackup/bin/libobk.so64,
         ENV=(NB_ORA_SERV=media_srv, NB_ORA_POLICY=oracle_full)';

CONFIGURE DEFAULT DEVICE TYPE TO sbt;
```

---

## 4. Strategie di Backup

### 4.1 Decision Tree — Quale Strategia Scegliere?

```
RPO < 1 ora?
  |-- SI --> Incremental + Archivelog frequente (ogni 15-30 min)
  |-- NO --> Full settimanale + Incremental giornaliero

RTO < 30 minuti?
  |-- SI --> Image Copy + Incremental Merge (SWITCH DATAFILE immediato)
  |-- NO --> Backupset standard

Database > 5 TB?
  |-- SI --> SECTION SIZE + Multi-channel + Backup da Standby
  |-- NO --> Configurazione standard

Compliance/Security?
  |-- SI --> CONFIGURE ENCRYPTION FOR DATABASE ON + Wallet backup
  |-- NO --> Senza cifratura
```

### 4.2 Full + Archivelog (strategia base)

```rman
RUN {
  SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";
  BACKUP AS COMPRESSED BACKUPSET DATABASE TAG 'FULL_DB';
  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL
    NOT BACKED UP 1 TIMES DELETE INPUT TAG 'ARCH_ALL';
  BACKUP CURRENT CONTROLFILE TAG 'CTRL_DAILY';
  BACKUP SPFILE TAG 'SPFILE_DAILY';
}
```

### 4.3 Incremental Level 0 / Level 1

```rman
-- Domenica: Level 0 (baseline)
BACKUP INCREMENTAL LEVEL 0 AS COMPRESSED BACKUPSET
  DATABASE TAG 'WEEKLY_L0'
  PLUS ARCHIVELOG DELETE INPUT;

-- Lun-Sab: Level 1 differential
BACKUP INCREMENTAL LEVEL 1 AS COMPRESSED BACKUPSET
  DATABASE TAG 'DAILY_L1'
  PLUS ARCHIVELOG DELETE INPUT;

-- Level 1 cumulative (alternativa: piu sicuro, piu grande)
BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE TAG 'DAILY_L1_CUM';
```

### 4.4 Incremental Merge (Instant Recovery)

Tecnica enterprise per RTO bassissimo: la image copy viene aggiornata in-place.

```rman
-- Giorno 1: Crea baseline image copy
BACKUP AS COPY DATABASE TAG 'INCR_MERGE_BASE';

-- Giorni successivi: Incrementale + merge
BACKUP INCREMENTAL LEVEL 1 FOR RECOVER OF COPY WITH TAG 'INCR_MERGE_BASE' DATABASE;
RECOVER COPY OF DATABASE WITH TAG 'INCR_MERGE_BASE';

-- Restore istantaneo (SWITCH, non copia!)
-- SWITCH DATABASE TO COPY;
-- RECOVER DATABASE;
```

### 4.5 Backup Multitenant (CDB/PDB)

```rman
-- Connesso a CDB root: backup intero container
BACKUP DATABASE PLUS ARCHIVELOG TAG 'CDB_FULL';

-- Backup singolo PDB
BACKUP PLUGGABLE DATABASE hr_pdb TAG 'PDB_HR';
BACKUP PLUGGABLE DATABASE sales_pdb, finance_pdb TAG 'PDB_MULTI';

-- Backup tablespace di un PDB specifico
BACKUP TABLESPACE hr_pdb:users TAG 'PDB_HR_USERS';

-- Restore/recover di un singolo PDB
ALTER PLUGGABLE DATABASE hr_pdb CLOSE IMMEDIATE;
RESTORE PLUGGABLE DATABASE hr_pdb;
RECOVER PLUGGABLE DATABASE hr_pdb;
ALTER PLUGGABLE DATABASE hr_pdb OPEN;
```

### 4.6 Backup per Datafile / Tablespace Mirato

```rman
BACKUP TABLESPACE users, indx TAG 'TS_USERS_INDX';
BACKUP DATAFILE 7 TAG 'DF7';
BACKUP DATAFILE '/u01/oradata/prod/users01.dbf' TAG 'DF_USERS01';
```

### 4.7 Backup Archivelog Dedicato

```rman
BACKUP ARCHIVELOG ALL TAG 'ARCH_ALL';
BACKUP ARCHIVELOG ALL DELETE INPUT;
BACKUP ARCHIVELOG ALL NOT BACKED UP 2 TIMES DELETE INPUT;
BACKUP ARCHIVELOG FROM SEQUENCE 100 UNTIL SEQUENCE 200;
BACKUP ARCHIVELOG FROM TIME 'SYSDATE-1';
```

### 4.8 SECTION SIZE per Datafile Grandi

```rman
BACKUP SECTION SIZE 8G DATABASE TAG 'PARALLEL_FULL';
```

---

## 5. Restore e Recovery

### 5.1 Restore Completo Database

```rman
STARTUP MOUNT;
RESTORE DATABASE;
RECOVER DATABASE;
ALTER DATABASE OPEN;
```

### 5.2 Point-in-Time Recovery (PITR)

```rman
STARTUP MOUNT;
RUN {
  SET UNTIL TIME "TO_DATE('2026-05-13 10:30:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE DATABASE;
  RECOVER DATABASE;
}
ALTER DATABASE OPEN RESETLOGS;
```

### 5.3 PITR con SCN o Sequence

```rman
RUN {
  SET UNTIL SCN 1234567;
  RESTORE DATABASE;
  RECOVER DATABASE;
}
ALTER DATABASE OPEN RESETLOGS;
```

### 5.4 Restore Singolo Datafile (Database OPEN)

```rman
SQL "ALTER DATABASE DATAFILE 7 OFFLINE";
RESTORE DATAFILE 7;
RECOVER DATAFILE 7;
SQL "ALTER DATABASE DATAFILE 7 ONLINE";
```

### 5.5 Restore Tablespace

```rman
SQL "ALTER TABLESPACE users OFFLINE IMMEDIATE";
RESTORE TABLESPACE users;
RECOVER TABLESPACE users;
SQL "ALTER TABLESPACE users ONLINE";
```

### 5.6 Tablespace Point-in-Time Recovery (TSPITR)

```rman
RECOVER TABLESPACE users
  UNTIL TIME "TO_DATE('2026-05-13 10:00:00','YYYY-MM-DD HH24:MI:SS')"
  AUXILIARY DESTINATION '/u01/aux';
```

### 5.7 Block Media Recovery (BMR)

```rman
BLOCKRECOVER DATAFILE 7 BLOCK 12345;
BLOCKRECOVER DATAFILE 7 BLOCK 12345, 12346, 12347;
BLOCKRECOVER DATAFILE 7 BLOCK 12345 FROM BACKUPSET;
```

### 5.8 Disaster Recovery — Perdita Totale (SPFILE + Controlfile + Datafile)

```rman
SET DBID 1234567890;
STARTUP FORCE NOMOUNT;
RESTORE SPFILE FROM AUTOBACKUP;
STARTUP FORCE NOMOUNT;
RESTORE CONTROLFILE FROM AUTOBACKUP;
ALTER DATABASE MOUNT;
CATALOG START WITH '+RECO/';
RESTORE DATABASE;
RECOVER DATABASE;
ALTER DATABASE OPEN RESETLOGS;
```

### 5.9 Restore Controlfile e SPFILE Isolati

```rman
STARTUP NOMOUNT;
RESTORE SPFILE FROM AUTOBACKUP;
RESTORE SPFILE TO '/tmp/spfile.ora' FROM AUTOBACKUP;
RESTORE CONTROLFILE FROM AUTOBACKUP;
RESTORE CONTROLFILE FROM '/backup/ctrl.bkp';
RESTORE CONTROLFILE FROM TAG 'CTRL_DAILY';
```

---

## 6. DUPLICATE (Clone, Test, Standby)

### 6.1 Active Duplicate (Rete diretta, no backup)

```rman
DUPLICATE TARGET DATABASE TO CLONE
  FROM ACTIVE DATABASE
  NOFILENAMECHECK
  SPFILE
    SET DB_UNIQUE_NAME='CLONE'
    SET CONTROL_FILES='+DATA/CLONE/controlfile/control01.ctl'
    SET LOG_FILE_NAME_CONVERT='+DATA/PROD','+DATA/CLONE','+RECO/PROD','+RECO/CLONE'
    SET DB_FILE_NAME_CONVERT='+DATA/PROD','+DATA/CLONE','+RECO/PROD','+RECO/CLONE';
```

### 6.2 Duplicate per Standby (Data Guard setup)

```rman
DUPLICATE TARGET DATABASE FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  NOFILENAMECHECK
  SPFILE
    SET DB_UNIQUE_NAME='STBY'
    SET FAL_SERVER='PROD'
    SET LOG_ARCHIVE_DEST_2='SERVICE=PROD ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=PROD';
```

### 6.3 Duplicate con PITR (Test/Dev)

```rman
DUPLICATE TARGET DATABASE TO TESTDB
  UNTIL TIME "TO_DATE('2026-05-13 08:00:00','YYYY-MM-DD HH24:MI:SS')"
  NOFILENAMECHECK
  DB_FILE_NAME_CONVERT '/u01/oradata/prod','/u02/oradata/test'
  SPFILE SET DB_UNIQUE_NAME='TESTDB';
```

---

## 7. Recovery Catalog & Virtual Private Catalog

### 7.1 Setup Catalog

```rman
RMAN TARGET / CATALOG rman_admin/pwd@CATDB
CREATE CATALOG;
REGISTER DATABASE;
RESYNC CATALOG;
IMPORT CATALOG rman_old/pwd@OLDCATDB;
```

### 7.2 Virtual Private Catalog (VPC)

```sql
CREATE USER vpc_dba_a IDENTIFIED BY pwd;
GRANT RECOVERY_CATALOG_OWNER TO vpc_dba_a;
```

```rman
RMAN CATALOG rman_admin/pwd@CATDB
GRANT CATALOG FOR DATABASE prod_a TO vpc_dba_a;
```

### 7.3 Stored Scripts nel Catalog

```rman
CREATE SCRIPT daily_full {
  BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG DELETE INPUT;
  BACKUP CURRENT CONTROLFILE;
  BACKUP SPFILE;
  DELETE NOPROMPT OBSOLETE;
}

RUN { EXECUTE SCRIPT daily_full; }

CREATE GLOBAL SCRIPT global_arch_backup {
  BACKUP ARCHIVELOG ALL NOT BACKED UP 1 TIMES DELETE INPUT;
}
```

---

## 8. Validazione e Verifica

```rman
RESTORE DATABASE VALIDATE;
RESTORE DATABASE VALIDATE CHECK LOGICAL;
VALIDATE DATABASE;
VALIDATE BACKUPSET 123;
RESTORE DATABASE PREVIEW;
RESTORE DATABASE PREVIEW SUMMARY;
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
CROSSCHECK COPY;
REPORT SCHEMA;
REPORT NEED BACKUP;
REPORT NEED BACKUP DAYS 3;
REPORT OBSOLETE;
REPORT UNRECOVERABLE;
LIST BACKUP SUMMARY;
LIST BACKUP OF DATABASE;
LIST BACKUP OF ARCHIVELOG ALL;
LIST BACKUP TAG 'WEEKLY_L0';
LIST EXPIRED BACKUP;
LIST INCARNATION;
LIST FAILURE;
LIST FAILURE ALL;
LIST RESTORE POINT ALL;
```

---

## 9. Manutenzione e Pulizia

```rman
DELETE NOPROMPT OBSOLETE;
CROSSCHECK BACKUP;
DELETE EXPIRED BACKUP;
DELETE EXPIRED ARCHIVELOG ALL;
DELETE BACKUPSET 123;
DELETE BACKUP COMPLETED BEFORE 'SYSDATE-30';
DELETE ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-7';
DELETE BACKUP TAG 'OLD_FULL';
CATALOG START WITH '/backup/imported/';
CATALOG BACKUPPIECE '/backup/external.bkp';
CATALOG DATAFILECOPY '/u01/copy/users01.dbf';
```

---

## 10. Scheduling Enterprise

### 10.1 Crontab (Linux)

```bash
# Full domenica 01:00, Incremental L1 lun-sab 01:00
0 1 * * 0 oracle /home/oracle/scripts/rman_full.sh >> /var/log/rman_full.log 2>&1
0 1 * * 1-6 oracle /home/oracle/scripts/rman_incr.sh >> /var/log/rman_incr.log 2>&1
# Archivelog ogni 30 minuti
*/30 * * * * oracle /home/oracle/scripts/rman_arch.sh >> /var/log/rman_arch.log 2>&1
# Pulizia obsoleti ogni sabato 06:00
0 6 * * 6 oracle /home/oracle/scripts/rman_cleanup.sh >> /var/log/rman_cleanup.log 2>&1
```

### 10.2 DBMS_SCHEDULER

```sql
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'RMAN_DAILY_L1',
    job_type        => 'EXECUTABLE',
    job_action      => '/home/oracle/scripts/rman_incr.sh',
    repeat_interval => 'FREQ=DAILY;BYHOUR=1;BYMINUTE=0',
    enabled         => TRUE,
    comments        => 'RMAN Incremental Level 1 giornaliero'
  );
END;
/
```

---

## 11. Monitoraggio Operativo

```sql
-- Status ultimi job RMAN
SELECT TO_CHAR(start_time,'DD-MON HH24:MI') started,
       TO_CHAR(end_time,'DD-MON HH24:MI') ended,
       status, input_type, output_device_type,
       output_bytes_display, time_taken_display
FROM v$rman_backup_job_details
ORDER BY start_time DESC FETCH FIRST 20 ROWS ONLY;

-- Corruzioni note
SELECT * FROM v$database_block_corruption;

-- Backup I/O performance
SELECT device_type, type, status,
       ROUND(bytes/1024/1024) AS mb,
       ROUND(effective_bytes_per_second/1024/1024) AS mb_per_sec
FROM v$backup_async_io
WHERE type != 'AGGREGATE' ORDER BY bytes DESC;

-- Archivelog non backuppati
SELECT sequence#, first_time, next_time, applied, backed_up
FROM v$archived_log
WHERE backed_up = 'NO' AND deleted = 'NO'
ORDER BY sequence# DESC FETCH FIRST 20 ROWS ONLY;
```

---

## 12. Format Specifiers Reference

| Specifier | Descrizione | Esempio |
|---|---|---|
| %d | Database name | PROD |
| %D | Giorno (DD) | 13 |
| %M | Mese (MM) | 05 |
| %Y | Anno (YYYY) | 2026 |
| %T | Data (YYYYMMDD) | 20260513 |
| %s | Backup set number | 42 |
| %p | Piece number | 1 |
| %c | Channel number | 2 |
| %U | Unique generated name | auto |
| %F | Unique format c-IIIIIIIIII-YYYYMMDD-QQ | auto |

---

## 13. Best Practice Enterprise Checklist

- ARCHIVELOG mode attivo
- FRA dimensionata (min 2x dimensione DB)
- CONTROLFILE AUTOBACKUP ON
- BCT (Block Change Tracking) abilitato
- BACKUP OPTIMIZATION ON
- Tag su ogni backup per audit trail
- Compressione MEDIUM (bilancia CPU/IO)
- Retention policy allineata a RPO/RTO (14-30 giorni)
- CROSSCHECK + DELETE OBSOLETE schedulati
- RESTORE VALIDATE test schedulato (settimanale)
- Encryption attiva se dati sensibili o backup off-site
- Wallet backup separato e sicuro
- Log centralizzati con alert su FAILED
- Backup da Standby per ridurre I/O su primary (Data Guard)
- Separazione storage (backup su target distinto)
- SYSBACKUP role (non SYSDBA) per duty separation

---

## 14. Troubleshooting Completo

| Errore | Causa | Diagnostica | Risoluzione |
|---|---|---|---|
| ORA-19809/ORA-19804 | FRA piena | v$recovery_file_dest | Aumenta FRA o DELETE OBSOLETE |
| ORA-19815 | FRA warning threshold | v$recovery_file_dest | Estendi o libera spazio |
| ORA-00257 | Archiver stuck | df -h, FRA usage | Libera FRA, backup archivelog |
| ORA-19502 | Write error disco pieno | df -h, ls -la, dmesg | Libera spazio, fix permessi |
| ORA-27072 | File I/O error OS | dmesg, /var/log/messages | Check hardware/mount |
| ORA-15041 | ASM diskgroup pieno | asmcmd lsdg | Aggiungi dischi al DG |
| RMAN-06059 | Archivelog cancellato con rm | LIST EXPIRED ARCHIVELOG | CROSSCHECK+DELETE EXPIRED |
| RMAN-06054 | Archivelog necessario non disponibile | LIST ARCHIVELOG ALL | Restore archivelog o SET UNTIL |
| RMAN-03009 | Channel failure | SHOW ALL, check MML | Verifica canali, SBT library |
| RMAN-10035 | Eccezione backup piece | V$RMAN_STATUS | Retry, check I/O |
| RMAN-08120 | Backup piece corrotto | VALIDATE BACKUPSET | Rigenera backup |
| ORA-01578 | Block corruption | V$DATABASE_BLOCK_CORRUPTION | BLOCKRECOVER+VALIDATE |
| RMAN-06169 | Catalog connection lost | tnsping, lsnrctl | Fix TNS, RESYNC CATALOG |
| ORA-28365 | Wallet non aperto TDE | V$ENCRYPTION_WALLET | Apri keystore |
| RMAN-12016 | TDE non disponibile | Licensing/wallet | SET ENCRYPTION con password |
| ORA-27040/ORA-27041 | Permessi OS file | ls -la path | chown oracle:oinstall |
| ORA-01031 | Insufficient privileges | USER, ROLE | GRANT SYSBACKUP |
| ORA-12154/ORA-12541 | TNS/listener down | tnsping, lsnrctl | Fix tnsnames, start listener |
| ORA-03113/ORA-03135 | Connection lost network | alert.log | Check network, retry |
| ORA-04031 | Shared pool exhaustion | V$SGASTAT | Aumenta shared_pool_size |

---

## 15. Riferimenti Ufficiali

- Oracle Database Backup and Recovery User's Guide 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/
- Oracle RMAN Reference 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/
- MOS Note: RMAN Backup Best Practices (Doc ID 394521.1)
- MOS Note: ORA-19809 Troubleshooting (Doc ID 315098.1)
- MOS Note: RMAN Encryption Overview (Doc ID 2575239.1)
