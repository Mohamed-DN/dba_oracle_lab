# PHASE 7: RMAN Backup Strategy on All Databases

> Backup is your last line of defense. It doesn't matter how sophisticated your HA solutions are (RAC, Data Guard, GoldenGate): if a human error deletes a table, only an RMAN backup can save you.

---

## 7.0 Entry from Phase 6 (operational gate)

Before setting the RMAN strategy, the system must be stable:

```bash
# Data Guard
dgmgrl sys/<password>@RACDB "show configuration;"

# GoldenGate standby side
cd $OGG_HOME && ./ggsci
INFO ALL
```

```sql
-- Spazio FRA (primario e standby)
sqlplus / as sysdba
SELECT name, space_limit/1024/1024 mb_limit, space_used/1024/1024 mb_used
FROM v$recovery_file_dest;
```

Check minimi:

- DGMGRL `SUCCESS`
- standby DD processes `RUNNING` (e replicat target `REPTAR` attivo)
- FRA non satura (idealmente < 80%)

Se hai gia creato gli script RMAN in test precedenti, non ricrearli: validali e aggiorna solo retention/schedule.

---

## 7.1 La Strategia di Backup

### Backup on ALL 3 Databases

```
                         ┌──────────────────────┐
                         │   RAC PRIMARY         │
                         │   (RACDB)             │
                         │   → Archivelog backup │───→ 🗄️ +FRA
                         │ → Level 1 light │ (every 2h + daily)
                         └──────────┬─────────────┘
                                    │ Redo Shipping
                                    ▼
                         ┌──────────────────────┐
                         │ RAC STANDBY (ADG) │
                         │   (RACDB_STBY)        │
                         │   → BACKUP PRINCIPALE │───→ 🗄️ +FRA
                         │   Level 0 + Level 1   │     (full + incr + arch)
                         └──────────┬─────────────┘
                                    │ GoldenGate
                                    ▼
                         ┌──────────────────────┐
                         │   TARGET DB           │
                         │   (dbtarget)          │
                         │   → Backup separato   │───→ 🗄️ Disco locale
                         └──────────────────────┘
```

> **Why backup MAIN on standby?** RMAN Level 0 (full) uses a lot of CPU and I/O. On standby these resources are not needed by clients. The backup done on the standby is **identical** to the one done on the primary.
>
> **Why ALSO backup on the primary?** For additional security: if the standby is under maintenance or crashes, backing up the archivelogs on the primary protects you from total loss. Additionally, a lightweight Level 1 provides a lower RPO (Recovery Point Objective).

---

## 7.2 Basic RMAN Configuration (Valid for all DBs)

### Connessione RMAN

```bash
# Sul Primario
rman TARGET /

# Sullo Standby
rman TARGET /

# Sul Target
rman TARGET /
```

### Initial Configuration (run on each DB)

```rman
-- Show the current configuration
SHOW ALL;

-- Configure the retention policy (keep backup for 7 days)
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;

-- Configura il backup automatico del controlfile e SPFILE
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '+FRA/%F';

-- Configura la parallelizzazione (2 canali per usare 2 CPU)
CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO COMPRESSED BACKUPSET;

-- Abilita la compressione (riduce lo spazio ~60-70%)
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';

-- Configura il formato dei backup
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '+FRA/RACDB/%U';

-- Enable optimization (skip already backed up files that haven't changed)
CONFIGURE BACKUP OPTIMIZATION ON;

-- Abilita block change tracking (accelera gli incrementali)
-- ONLY ON PRIMARY OR STANDBY, NOT BOTH
-- Recommended on Standby if you backup from there
```

> **Explanation:**
> - `RECOVERY WINDOW OF 7 DAYS`: Keeps enough backups to be able to restore the DB to any point in the last 7 days.
> - `COMPRESSED BACKUPSET`: Comprime i backup riducendo lo spazio disco.
> - `BACKUP OPTIMIZATION ON`: If you do a full backup and a datafile has not changed since the previous backup, RMAN skips it.

---

## 7.3 Block Change Tracking (BCT) — Accelera gli Incrementali

BCT keeps track of which blocks have changed, making incremental backups **10-100x faster**.

### On the Primary (RACDB) — if you backup from the primary:

```sql
sqlplus / as sysdba

ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+DATA/RACDB/bct_racdb.dbf';

-- Verifica
SELECT filename, status, bytes/1024/1024 size_mb FROM v$block_change_tracking;
```

### On Standby (RACDB_STBY) - ADVISED:

```sql
sqlplus / as sysdba

ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+DATA/RACDB_STBY/bct_racdb_stby.dbf';
```

### Sul Target (dbtarget):

```sql
sqlplus / as sysdba

ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '/u01/app/oracle/oradata/dbtarget/bct_dbtarget.dbf';
```

> **Why BCT?** Without BCT, an incremental backup must read EVERY database block to figure out if it has changed. With BCT, Oracle keeps a "diary" of changed blocks and RMAN only reads those. On a 100GB database, an incremental without BCT can take 30 minutes; with BCT, 2 minutes.

---

## 7.4 Backup Script — RAC Standby (Main Backup)

This is the **most important** backup of your infrastructure. Runs on ADG standby.

### Backup Level 0 (Full) — Domenica

```bash
cat > /home/oracle/scripts/rman_full_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_full_backup.sh — Backup Full (Level 0) dallo Standby
# Eseguire SOLO sullo Standby (RACDB_STBY)

source /home/oracle/.db_env
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_full_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
RUN {
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK;

    -- Backup Full Database (Level 0)
    BACKUP AS COMPRESSED BACKUPSET
        INCREMENTAL LEVEL 0
        DATABASE
        TAG 'FULL_WEEKLY'
        PLUS ARCHIVELOG
            TAG 'ARCH_WITH_FULL'
            DELETE INPUT;

    -- Backup del Controlfile e SPFILE
    BACKUP CURRENT CONTROLFILE TAG 'CTL_WEEKLY';
    BACKUP SPFILE TAG 'SPFILE_WEEKLY';

    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}

-- Rimuovi i backup obsoleti secondo la retention policy
DELETE NOPROMPT OBSOLETE;

-- Crosscheck per rimuovere riferimenti a backup cancellati manualmente
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT EXPIRED BACKUP;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
EOF

# Controlla se RMAN ha avuto errori
if grep -i "RMAN-" $LOG_FILE | grep -v "RMAN-08138" > /dev/null; then
    echo "ERRORE RMAN rilevato! Controlla il log: $LOG_FILE"
    # Qui puoi aggiungere una notifica email
else
    echo "Backup Full completato con successo."
fi
SCRIPT

chmod +x /home/oracle/scripts/rman_full_backup.sh
```

> **Explanation:**
> - `INCREMENTAL LEVEL 0`: Full backup of all blocks. It is the "base" for subsequent incrementals.
> - `PLUS ARCHIVELOG DELETE INPUT`: Also backs up archivelogs and deletes them after backup (frees up space on +FRA).
> - `DELETE NOPROMPT OBSOLETE`: Removes backups older than the retention window (7 days).
> - `CROSSCHECK`: Verify that backup files physically exist. If someone deleted them by hand, RMAN marks them as EXPIRED.

### Backup Level 1 (Incremental) — Every day

```bash
cat > /home/oracle/scripts/rman_incr_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_incr_backup.sh — Backup Incrementale (Level 1) dallo Standby

source /home/oracle/.db_env
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_incr_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
RUN {
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK;

    -- Backup Incrementale Level 1
    BACKUP AS COMPRESSED BACKUPSET
        INCREMENTAL LEVEL 1
        DATABASE
        TAG 'INCR_DAILY'
        PLUS ARCHIVELOG
            TAG 'ARCH_WITH_INCR'
            DELETE INPUT;

    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}

-- Pulizia
DELETE NOPROMPT OBSOLETE;
CROSSCHECK BACKUP;
DELETE NOPROMPT EXPIRED BACKUP;
EOF

if grep -i "RMAN-" $LOG_FILE | grep -v "RMAN-08138" > /dev/null; then
    echo "ERRORE RMAN rilevato! Controlla il log: $LOG_FILE"
else
    echo "Backup Incrementale completato con successo."
fi
SCRIPT

chmod +x /home/oracle/scripts/rman_incr_backup.sh
```

> **Why Level 1 and not Level 0 every day?** A Level 0 copies ALL blocks. A Level 1 ONLY copies blocks changed by Level 0 (or the previous Level 1). On a 50GB DB where 2GB of data changes every day, Level 1 is 25x faster and uses 25x less space.

### Backup Archivelog — Ogni 2 ore

```bash
cat > /home/oracle/scripts/rman_arch_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_arch_backup.sh — Backup Archivelog

source /home/oracle/.db_env

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_arch_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
BACKUP AS COMPRESSED BACKUPSET
    ARCHIVELOG ALL NOT BACKED UP 1 TIMES
    TAG 'ARCH_HOURLY'
    DELETE INPUT;
EOF
SCRIPT

chmod +x /home/oracle/scripts/rman_arch_backup.sh
```

> **Why every 2 hours?** Archivelogs accumulate in the FRA. If you don't backup and delete them regularly, the FRA fills up and the database stops (it can no longer write redo). `NOT BACKED UP 1 TIMES` ensures that they are backed up at least once before being deleted.

---

## 7.5 Script di Backup — Target (dbtarget)

The GoldenGate target has a simpler strategy because it can always be recreated by reloading data from the primary.

```bash
cat > /home/oracle/scripts/rman_target_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_target_backup.sh — Backup per il DB Target GoldenGate

source /home/oracle/.db_env

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_target_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 3 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/u01/backup/dbtarget/%F';
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/u01/backup/dbtarget/%U';

RUN {
    BACKUP AS COMPRESSED BACKUPSET
        INCREMENTAL LEVEL 1 CUMULATIVE
        DATABASE
        TAG 'TARGET_DAILY'
        PLUS ARCHIVELOG
            TAG 'TARGET_ARCH'
            DELETE INPUT;

    BACKUP CURRENT CONTROLFILE TAG 'TARGET_CTL';
}

DELETE NOPROMPT OBSOLETE;
EOF
SCRIPT

chmod +x /home/oracle/scripts/rman_target_backup.sh
```

> **Why `CUMULATIVE`?** A Level 1 Cumulative includes ALL changes from Level 0, not just those from the previous Level 1. The restore is faster because only the Level 0 + the last Level 1 Cumulative are needed (not all the intermediate Level 1s).

```bash
# Crea la directory di backup sul Target
mkdir -p /u01/backup/dbtarget
chown oracle:oinstall /u01/backup/dbtarget
```

---

## 7.5b Backup Script — PRIMARY RAC (RACDB)

The primary also has its backup — light but essential as a safety net.

```bash
cat > /home/oracle/scripts/rman_primary_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_primary_backup.sh — Backup dal Primario
# Level 1 incrementale + archivelog
# PIÙ LEGGERO di quello sullo standby

source /home/oracle/.db_env
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_primary_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
RUN {
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;

    -- Solo Level 1 (NON Level 0 full per non sovraccaricare)
    BACKUP AS COMPRESSED BACKUPSET
        INCREMENTAL LEVEL 1
        DATABASE
        TAG 'PRIMARY_INCR_DAILY'
        PLUS ARCHIVELOG
            TAG 'PRIMARY_ARCH'
            DELETE INPUT;

    -- Backup Controlfile + SPFILE
    BACKUP CURRENT CONTROLFILE TAG 'PRIMARY_CTL';
    BACKUP SPFILE TAG 'PRIMARY_SPFILE';

    RELEASE CHANNEL ch1;
}

DELETE NOPROMPT OBSOLETE;
EOF

if grep -i "RMAN-" $LOG_FILE | grep -v "RMAN-08138" > /dev/null; then
    echo "ERRORE RMAN rilevato! Controlla il log: $LOG_FILE"
else
    echo "Backup Primario completato con successo."
fi
SCRIPT

chmod +x /home/oracle/scripts/rman_primary_backup.sh
```

> **Why only Level 1 on the primary?** Level 0 (full) is heavy and already makes it standby on Sundays. The primary only does Level 1, which is light and fast thanks to the BCT. If the standby crashes, you still have a recent backup from the primary.

---

## 7.6 Schedulazione con Cron

```bash
# Come utente oracle, su OGNI macchina
crontab -e
```

### On the Primary (rac1):

```cron
# Backup Incrementale — Ogni giorno alle 04:00 (sfalsato dallo standby)
0 4 * * * /home/oracle/scripts/rman_primary_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1

# Backup Archivelog — Ogni 2 ore
0 */2 * * * /home/oracle/scripts/rman_arch_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1
```

### On Standby (racstby1):

```cron
# Backup Full — Domenica alle 02:00
0 2 * * 0 /home/oracle/scripts/rman_full_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1

# Backup Incrementale — Lun-Sab alle 02:00
0 2 * * 1-6 /home/oracle/scripts/rman_incr_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1

# Backup Archivelog — Ogni 2 ore
0 */2 * * * /home/oracle/scripts/rman_arch_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1
```

### Sul Target (dbtarget):

```cron
# Backup Daily — Ogni giorno alle 03:00
0 3 * * * /home/oracle/scripts/rman_target_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1
```

---

## 7.7 Verifying Backups

### Report dei backup

```rman
rman TARGET /

-- Lista tutti i backup
LIST BACKUP SUMMARY;

-- Lista backup recenti del DB
LIST BACKUP OF DATABASE COMPLETED AFTER 'SYSDATE-1';

-- Lista backup degli archivelog
LIST BACKUP OF ARCHIVELOG ALL;

-- Verifica l'integrità di tutti i backup (controlla che siano leggibili)
-- ATTENZIONE: questo legge fisicamente i file, può richiedere tempo
VALIDATE BACKUP;

-- Report dei file non backuppati
REPORT NEED BACKUP;

-- Report dei file unrecoverable
REPORT UNRECOVERABLE DATABASE;
```

### Script di Report Automatico

```bash
cat > /home/oracle/scripts/rman_report.sh <<'SCRIPT'
#!/bin/bash
source /home/oracle/.db_env

echo "=== RMAN BACKUP REPORT === $(date)"
echo ""

rman TARGET / <<EOF
LIST BACKUP SUMMARY;
REPORT NEED BACKUP;
CROSSCHECK BACKUP;
EOF
SCRIPT

chmod +x /home/oracle/scripts/rman_report.sh
```

---

## 7.8 Test di Restore (FONDAMENTALE!)

> **An untested backup is a backup that does not exist.** Test the restore regularly.

### Test 1: Restore a single table (Point-in-Time Recovery)

```rman
-- Questo test NON modifica il database reale
-- Usa RMAN Table Point-in-Time Recovery (TSPITR)

rman TARGET /

-- Verifica che il backup sia utilizzabile per il restore
RESTORE DATABASE PREVIEW;
RESTORE DATABASE VALIDATE;
```

### Test 2: Restore su una location alternativa

```rman
-- If you have space, you can do a full restore to a different path
-- per verificare che tutto funzioni

RUN {
    SET NEWNAME FOR DATAFILE 1 TO '/tmp/restore_test/system01.dbf';
    SET NEWNAME FOR DATAFILE 2 TO '/tmp/restore_test/sysaux01.dbf';
    -- ... etc.
    RESTORE DATABASE;
    -- DO NOT do RECOVER: it is just a test
}
```

### Test 3: Verify Restore from Standby to Primary

```rman
-- Connettiti al primario usando il catalog dello standby
rman TARGET sys/<password>@RACDB AUXILIARY sys/<password>@RACDB_STBY

-- Il backup fatto sullo standby è usabile per il primario
RESTORE DATABASE PREVIEW;
```

---

## 7.9 Summary Diagram of the Strategy

| Database | Tipo Backup | Frequenza | Retention | Dove |
|---|---|---|---|---|
| **RACDB (Primary)** | Level 1 Incremental | Every day 04:00 | 7 days | +FRA |
| **RACDB (Primary)** | Archivelog | Ogni 2 ore | — | +FRA |
| **RACDB_STBY (Standby)** | Level 0 Full | Domenica 02:00 | 7 days | +FRA |
| **RACDB_STBY (Standby)** | Level 1 Incr | Lun-Sab 02:00 | 7 days | +FRA |
| **RACDB_STBY (Standby)** | Archivelog | Ogni 2 ore | — | +FRA |
| **dbtarget (Target GG)** | Level 1 Cumulative | Every day 03:00 | 3 days | /u01/backup |

---

## 7.10 Statistiche, Health Check e Manutenzione Automatica

> **Why statistics?** Oracle uses object statistics (tables, indexes) to calculate the optimal query execution plan. Old stats = bad plans = slow queries. They are the optimizer's fuel.

### Statistics Collection (Automatic — already active by default)

Oracle raccoglie automaticamente le statistiche tramite il job `GATHER_STATS_JOB` which runs in the maintenance window (at night). Check that it is active:

```sql
-- Verifica che la raccolta automatica sia attiva
SELECT client_name, status FROM dba_autotask_client 
WHERE client_name = 'auto optimizer stats collection';
-- Deve mostrare: ENABLED

-- Vedi quando ha girato l'ultima volta
SELECT client_name, window_name, jobs_created, jobs_started, jobs_completed
FROM dba_autotask_client_history 
WHERE client_name LIKE '%stats%' 
ORDER BY window_start_time DESC FETCH FIRST 5 ROWS ONLY;
```

### Raccolta Statistiche Manuale (per tabelle specifiche)

```sql
-- Statistiche su uno schema intero
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('HR', CASCADE => TRUE, DEGREE => 4);

-- Statistiche su una tabella specifica
EXEC DBMS_STATS.GATHER_TABLE_STATS('HR', 'EMPLOYEES', CASCADE => TRUE);

-- Statistiche su TUTTO il database (pesante — fallo solo se necessario)
EXEC DBMS_STATS.GATHER_DATABASE_STATS(DEGREE => 4);
```

> **`CASCADE => TRUE`**: Also collects table index statistics.
> **`DEGREE => 4`**: Usa 4 processi paralleli per velocizzare.

### Check Tables with Old Statistics

```sql
-- Tabelle con statistiche più vecchie di 7 giorni e > 10% righe modificate
SELECT owner, table_name, last_analyzed, num_rows, stale_stats
FROM dba_tab_statistics 
WHERE stale_stats = 'YES' 
AND owner NOT IN ('SYS','SYSTEM','DBSNMP','OUTLN')
ORDER BY num_rows DESC;
```

### Complete Health Check Database

```sql
-- ============= HEALTH CHECK SCRIPT =============
-- Eseguilo una volta al giorno o dopo ogni intervento

-- 1. Stato dell'istanza
SELECT inst_id, instance_name, status, startup_time FROM gv$instance;

-- 2. Spazio Tablespace (> 85% = WARNING, > 95% = CRITICAL)
SELECT tablespace_name, 
       ROUND(used_percent, 1) AS "Used%",
       CASE WHEN used_percent > 95 THEN '🔴 CRITICAL'
            WHEN used_percent > 85 THEN '🟡 WARNING'
            ELSE '🟢 OK' END AS status
FROM dba_tablespace_usage_metrics
ORDER BY used_percent DESC;

-- 3. Spazio ASM
SELECT name, state, type, 
       ROUND(total_mb/1024,1) AS total_gb, 
       ROUND(free_mb/1024,1) AS free_gb,
       ROUND((1-free_mb/total_mb)*100,1) AS "Used%"
FROM v$asm_diskgroup;

-- 4. Alert log errori recenti (ORA-)
SELECT originating_timestamp, message_text 
FROM v$diag_alert_ext 
WHERE originating_timestamp > SYSDATE - 1
AND message_text LIKE '%ORA-%'
ORDER BY originating_timestamp DESC FETCH FIRST 20 ROWS ONLY;

-- 5. Sessioni attive per wait class
SELECT wait_class, COUNT(*) AS sessions
FROM gv$session WHERE status = 'ACTIVE' AND wait_class != 'Idle'
GROUP BY wait_class ORDER BY sessions DESC;

-- 6. Data Guard lag (solo sullo standby)
SELECT name, value, datum_time FROM v$dataguard_stats WHERE name LIKE '%lag%';

-- 7. Job falliti nelle ultime 24 ore
SELECT job_name, status, actual_start_date, run_duration
FROM dba_scheduler_job_run_details
WHERE actual_start_date > SYSDATE - 1 AND status = 'FAILED';

-- 8. Invalid objects
SELECT owner, object_type, object_name FROM dba_objects 
WHERE status = 'INVALID' 
AND owner NOT IN ('SYS','SYSTEM','PUBLIC')
ORDER BY owner, object_type;

-- 9. FRA usage
SELECT * FROM v$flash_recovery_area_usage;
SELECT ROUND(space_limit/1024/1024/1024,2) AS limit_gb, 
       ROUND(space_used/1024/1024/1024,2) AS used_gb,
       ROUND(space_reclaimable/1024/1024/1024,2) AS reclaimable_gb
FROM v$recovery_file_dest;
```

### Script Health Check Automatico

```bash
cat > /home/oracle/scripts/daily_health_check.sh <<'SCRIPT'
#!/bin/bash
# daily_health_check.sh — Report giornaliero del database
source /home/oracle/.db_env

LOG=/home/oracle/scripts/logs/health_$(date +%Y%m%d).log
echo "=== DAILY HEALTH CHECK — $(date) ===" > $LOG

sqlplus -s / as sysdba >> $LOG <<SQL
SET LINESIZE 200 PAGESIZE 100

PROMPT
PROMPT === INSTANCE STATUS ===
SELECT inst_id, instance_name, status FROM gv\$instance;

PROMPT
PROMPT === TABLESPACE USAGE ===
SELECT tablespace_name, ROUND(used_percent,1) AS pct_used FROM dba_tablespace_usage_metrics WHERE used_percent > 80 ORDER BY used_percent DESC;

PROMPT
PROMPT === ASM DISKGROUP ===
SELECT name, ROUND((1-free_mb/total_mb)*100,1) AS pct_used FROM v\$asm_diskgroup;

PROMPT
PROMPT === STALE STATISTICS ===
SELECT owner, COUNT(*) AS stale_tables FROM dba_tab_statistics WHERE stale_stats='YES' AND owner NOT IN ('SYS','SYSTEM') GROUP BY owner;

PROMPT
PROMPT === RECENT ORA ERRORS ===
SELECT originating_timestamp, SUBSTR(message_text,1,120) FROM v\$diag_alert_ext WHERE originating_timestamp > SYSDATE-1 AND message_text LIKE '%ORA-%' FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT === INVALID OBJECTS ===
SELECT owner, object_type, COUNT(*) FROM dba_objects WHERE status='INVALID' AND owner NOT IN ('SYS','SYSTEM','PUBLIC') GROUP BY owner, object_type;
SQL

echo "" >> $LOG
echo "=== END HEALTH CHECK ===" >> $LOG
cat $LOG
SCRIPT

chmod +x /home/oracle/scripts/daily_health_check.sh
```

Add to cron on ALL databases:

```cron
# Health Check giornaliero — Ogni giorno alle 08:00
0 8 * * * /home/oracle/scripts/daily_health_check.sh >> /home/oracle/scripts/logs/cron.log 2>&1
```

---

## ✅ End of Phase 7 Checklist

```bash
# 1. BCT attivo sui DB dove esegui incrementali
sqlplus -s / as sysdba <<< "SELECT status FROM v\$block_change_tracking;"

# 2. Backup eseguito con successo
rman TARGET / <<< "LIST BACKUP SUMMARY;"

# 3. Cron configurato
crontab -l

# 4. Restore testato
rman TARGET / <<< "RESTORE DATABASE VALIDATE;"
```

---

**→ Next recommended: [STEP 8: Enterprise Manager Cloud Control](./GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md)**

---

## 🎉 Congratulazioni (Core Stack Completato)

Hai completato il core dell'architettura Oracle (HA + DR + replica + backup):

```
RAC Primary (RACDB)
    ├── Data Guard → RAC Standby (RACDB_STBY)
    │                    ├── RMAN Backup (Level 0 + Level 1)
    │                    └── GoldenGate Extract
    │                            └── → Target DB (dbtarget)
    │                                      └── RMAN Backup (Cumulative)
    └── Force Logging + Archivelog Mode
```

Hai imparato:
1. **RAC**: High Availability locale con failover automatico.
2. **Data Guard**: Disaster Recovery with physical standby.
3. **GoldenGate**: Replica logica cross-platform verso un target indipendente.
4. **RMAN**: Professional Backup & Recovery on ALL databases.
5. **Statistiche & Maintenance**: Health check, statistiche dell'ottimizzatore, monitoraggio proattivo.
6. **Patching**: OPatch, opatchauto, datapatch per Grid e Database.

Natural next step: Centralize monitoring and governance with Enterprise Manager (Step 8).
