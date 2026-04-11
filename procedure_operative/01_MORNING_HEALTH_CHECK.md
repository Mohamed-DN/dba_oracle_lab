# 01 — Morning Health Check

> ⏱️ Tempo: 5-10 minuti | 📅 Frequenza: Ogni mattina | 👤 Chi: DBA on-call

---

## Obiettivo

Verifica rapida che l'ambiente Oracle (RAC + Data Guard + Backup) sia sano prima dell'inizio della giornata lavorativa.

---

## Step 1: Stato Database e Istanze

```sql
-- Connettiti al PRIMARY
sqlplus / as sysdba

-- 1A. Stato database
SELECT name, db_unique_name, open_mode, log_mode,
       database_role, protection_mode, force_logging, flashback_on
FROM v$database;

-- ATTESO: OPEN_MODE=READ WRITE, LOG_MODE=ARCHIVELOG,
--         DATABASE_ROLE=PRIMARY, FORCE_LOGGING=YES
```

```sql
-- 1B. Stato di tutte le istanze RAC
SELECT inst_id, instance_name, host_name, status,
       TO_CHAR(startup_time, 'DD-MON HH24:MI') AS up_since,
       ROUND(sysdate - startup_time) AS uptime_days
FROM gv$instance
ORDER BY inst_id;

-- ATTESO: tutte le istanze in STATUS=OPEN
-- ⚠️ Se un'istanza è giù, escalare immediatamente
```

## Step 2: Cluster e Risorse

```bash
# 2A. Stato risorse CRS (come grid o oracle)
crsctl stat res -t

# ATTESO: tutte le risorse ONLINE
# ⚠️ ATTENZIONE a risorse in OFFLINE o INTERMEDIATE

# 2B. Stato database RAC
srvctl status database -d RACDB -v

# 2C. Listener e SCAN
srvctl status listener
srvctl status scan_listener
```

## Step 3: Alert Log — Errori Recenti

```bash
# 3A. Ultimi errori ORA- (ultime 24h)
# Adatta il path al tuo ambiente
ALERT_LOG=$ORACLE_BASE/diag/rdbms/racdb/RACDB1/trace/alert_RACDB1.log

# Errori delle ultime 24 ore
awk -v d="$(date -d 'yesterday' '+%a %b %d')" \
    '/^[A-Z][a-z]{2} [A-Z][a-z]{2} [0-9]{2}/{found=0} $0 ~ d{found=1} found && /ORA-/' \
    $ALERT_LOG

# Alternativa rapida: ultimi 20 errori
grep -i "ORA-" $ALERT_LOG | tail -20
```

```sql
-- 3B. Alternativa da SQL (19c)
SELECT originating_timestamp, message_text
FROM v$diag_alert_ext
WHERE originating_timestamp > SYSDATE - 1
  AND message_text LIKE '%ORA-%'
ORDER BY originating_timestamp DESC
FETCH FIRST 20 ROWS ONLY;
```

## Step 4: Spazio (Tablespace + ASM + FRA)

```sql
-- 4A. Tablespace critici (> 80%)
SELECT tablespace_name,
       ROUND(used_space * 8192 / 1024 / 1024) AS used_mb,
       ROUND(tablespace_size * 8192 / 1024 / 1024) AS total_mb,
       ROUND(used_percent, 1) AS pct_used
FROM dba_tablespace_usage_metrics
WHERE used_percent > 80
ORDER BY used_percent DESC;

-- ⚠️ > 85% = pianifica espansione
-- 🔴 > 95% = urgente!
```

```sql
-- 4B. ASM Disk Groups
SELECT name, state, type,
       ROUND(total_mb/1024) AS total_gb,
       ROUND(free_mb/1024) AS free_gb,
       ROUND((1 - free_mb/total_mb) * 100, 1) AS pct_used
FROM v$asm_diskgroup
ORDER BY pct_used DESC;

-- ⚠️ > 80% = pianifica aggiunta dischi
```

```sql
-- 4C. Flash Recovery Area
SELECT name,
       ROUND(space_limit/1024/1024/1024, 1) AS limit_gb,
       ROUND(space_used/1024/1024/1024, 1) AS used_gb,
       ROUND(space_used/space_limit * 100, 1) AS pct_used,
       ROUND(space_reclaimable/1024/1024/1024, 1) AS reclaimable_gb
FROM v$recovery_file_dest;

-- ⚠️ > 85% = esegui RMAN DELETE OBSOLETE o espandi FRA
```

## Step 5: Backup RMAN — Ultimo Ciclo

```sql
-- 5A. Ultimo backup completato
SELECT input_type, status,
       TO_CHAR(start_time, 'DD-MON HH24:MI') AS start_time,
       TO_CHAR(end_time, 'DD-MON HH24:MI') AS end_time,
       ROUND(elapsed_seconds/60) AS minutes
FROM v$rman_backup_job_details
WHERE start_time > SYSDATE - 1
ORDER BY start_time DESC;

-- ATTESO: STATUS = COMPLETED
-- 🔴 Se STATUS = FAILED → vedi procedura 02_VERIFICA_BACKUP
```

## Step 6: Data Guard — Lag e Stato

```sql
-- 6A. Sul PRIMARY: stato destinazione standby
SELECT dest_id, status, error,
       DECODE(status, 'VALID', '✅', '🔴 ' || error) AS check_result
FROM v$archive_dest
WHERE dest_id = 2;
```

```sql
-- 6B. Sullo STANDBY: lag e stato apply
SELECT name, value, datum_time
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag', 'apply finish time');

-- ATTESO: lag < 1 minuto per MaxPerformance
```

```bash
# 6C. Broker (se attivo)
dgmgrl / "SHOW CONFIGURATION"
# ATTESO: SUCCESS - ogni membro deve essere OK
```

## Step 7: Job Scheduler Falliti

```sql
SELECT job_name, status, error#,
       TO_CHAR(actual_start_date, 'DD-MON HH24:MI') AS started,
       additional_info
FROM dba_scheduler_job_run_details
WHERE status = 'FAILED'
  AND actual_start_date > SYSDATE - 1
ORDER BY actual_start_date DESC;

-- 0 righe = OK
-- ⚠️ Se ci sono fallimenti, investiga il job specifico
```

---

## ✅ Check di Conferma

| Controllo | Atteso | Azione se KO |
|---|---|---|
| Istanze RAC | Tutte OPEN | Escalare, `srvctl start instance` |
| CRS Resources | Tutte ONLINE | `crsctl stat res -t`, restart componente |
| Alert log | Nessun ORA- critico | Investigare errore specifico |
| Tablespace | < 85% | Aggiungi datafile |
| ASM | < 80% | Pianifica aggiunta dischi |
| FRA | < 85% | `RMAN> DELETE OBSOLETE` |
| Backup | COMPLETED | Procedura 02 |
| Data Guard | Lag < soglia | Procedura 03 |
| Job falliti | Nessuno | Investigare job specifico |
