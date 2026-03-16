# Essential DBA Commands + Oracle-Base.com Scripts (with Explanations)

> Organized collection of the most useful DBA commands for your lab, with queries selected from [oracle-base.com/dba/scripts](https://oracle-base.com/dba/scripts), spiegate e valutate.

---

## 1. 🔍 Quick Health Check — "How is my DB?"

Run these queries after each step of the lab to check the status of the database.

### 1.1 Database Information

```sql
--General database information
-- Fonte: oracle-base.com/dba/monitoring/db_info.sql
--✅ FUNDAMENTAL: always carry out as a first check
SELECT dbid, name, db_unique_name, open_mode, log_mode,
       force_logging, flashback_on, database_role,
       protection_mode, switchover_status
FROM v$database;
```

> **Why?** Show all at once: Is the DB open? Is it in archivelog? Is it primary or standby? Is force logging enabled? This query alone tells you 50% of the status of the DB.

```sql
--Version and patch applied
-- Fonte: oracle-base.com/dba/monitoring/patch_registry.sql
--✅ USEFUL: to know exactly which version and patch are installed
SELECT * FROM dba_registry_sqlpatch ORDER BY action_time DESC;
```

### 1.2 Instance Status (RAC)

```sql
--Status of all cluster instances
--✅ FUNDAMENTAL for RAC: check that both instances are OPEN
SELECT inst_id, instance_name, host_name, status, startup_time,
       ROUND(sysdate - startup_time) AS uptime_days
FROM gv$instance
ORDER BY inst_id;
```

---

## 2. 📊 Monitoring Performance

### 2.1 Active Sessions

```sql
--Active sessions with SQL running
-- Fonte: oracle-base.com/dba/monitoring/active_sessions.sql
--✅ KEY: The first place to look if the DB is slow
SELECT s.inst_id, s.sid, s.serial#, s.username, s.program,
       s.status, s.event, s.wait_class,
       s.sql_id, s.last_call_et AS "Seconds Active",
       sq.sql_text
FROM gv$session s
LEFT JOIN gv$sql sq ON s.sql_id = sq.sql_id AND s.inst_id = sq.inst_id
WHERE s.status = 'ACTIVE'
  AND s.type = 'USER'
ORDER BY s.last_call_et DESC;
```

> **Why?** If someone complains that the DB is slow, this query shows WHO is doing WHAT and for HOW LONG.

### 2.2 Heaviest Queries (Top SQL)

```sql
-- Top 10 SQL per elapsed time
-- Fonte: oracle-base.com/dba/monitoring/top_sql.sql
--✅ USEFUL: Identify the most expensive queries
SELECT * FROM (
    SELECT sql_id, elapsed_time/1000000 AS elapsed_sec,
           cpu_time/1000000 AS cpu_sec,
           executions, buffer_gets, disk_reads,
           ROUND(buffer_gets/NULLIF(executions,0)) AS gets_per_exec,
           SUBSTR(sql_text,1,100) AS sql_preview
    FROM gv$sql
    WHERE executions > 0
    ORDER BY elapsed_time DESC
) WHERE ROWNUM <= 10;
```

### 2.3 Wait Events — Dove il DB "perde tempo"

```sql
--System events (system wait events)
-- Fonte: oracle-base.com/dba/monitoring/system_events.sql
--✅ USEFUL: Understand where the system spends time waiting
SELECT event, total_waits, time_waited_micro/1000000 AS time_waited_sec,
       average_wait_micro/1000 AS avg_wait_ms, wait_class
FROM gv$system_event
WHERE wait_class NOT IN ('Idle')
ORDER BY time_waited_micro DESC
FETCH FIRST 15 ROWS ONLY;
```

> **Why?** Wait events are Oracle's "language" to tell you what slows it down. If you see `db file sequential read` = troppe letture da disco. Se vedi `log file sync` = the redo disk is slow. If you see `gc buffer busy` = contesa tra nodi RAC.

### 2.4 Session Waits in Tempo Reale

```sql
-- Wait events per sessione (live)
-- Fonte: oracle-base.com/dba/monitoring/session_waits.sql
--✅ HELPFUL: During a live problem, see what awaits EACH session
SELECT inst_id, sid, event, wait_class,
       seconds_in_wait, state
FROM gv$session_wait
WHERE wait_class != 'Idle'
ORDER BY seconds_in_wait DESC;
```

---

## 3. 💾 Storage e Tablespace

### 3.1 Tablespace

```sql
-- Uso tablespace con percentuali
-- Fonte: oracle-base.com/dba/monitoring/ts_full.sql
--✅ KEY: if a tablespace fills to 100%, the DB crashes
SELECT tablespace_name,
       ROUND(SUM(bytes)/1024/1024) AS total_mb,
       ROUND(SUM(bytes - NVL(free_bytes,0))/1024/1024) AS used_mb,
       ROUND(SUM(NVL(free_bytes,0))/1024/1024) AS free_mb,
       ROUND((SUM(bytes - NVL(free_bytes,0)) / SUM(bytes)) * 100, 1) AS pct_used
FROM (
    SELECT df.tablespace_name, df.bytes,
           (SELECT SUM(fs.bytes)
            FROM dba_free_space fs
            WHERE fs.tablespace_name = df.tablespace_name
              AND fs.file_id = df.file_id) AS free_bytes
    FROM dba_data_files df
)
GROUP BY tablespace_name
ORDER BY pct_used DESC;
```

> **Quando preoccuparsi?** Se `pct_used` > 85%, you need to add space. If > 95%, it is urgent!

### 3.2 Datafiles

```sql
--Info datafile with autoextend
-- Fonte: oracle-base.com/dba/monitoring/datafiles.sql
--✅ USEFUL: Check autoextend and maximum size
SELECT file_name, tablespace_name,
       ROUND(bytes/1024/1024) AS size_mb,
       ROUND(maxbytes/1024/1024) AS max_mb,
       autoextensible, status
FROM dba_data_files
ORDER BY tablespace_name, file_name;
```

### 3.3 ASM Disk Group (specific to our lab)

```sql
-- Stato ASM Disk Groups
--✅ FUNDAMENTAL for our RAC lab
SELECT name, state, type, total_mb, free_mb,
       ROUND((1 - free_mb/total_mb) * 100, 1) AS pct_used
FROM v$asm_diskgroup;
```

---

## 4. 🔒 Lock e Contesa

### 4.1 Oggetti Lockati

```sql
--Objects with active lock
-- Fonte: oracle-base.com/dba/monitoring/locked_objects.sql
--✅ KEY: When a session "hangs", look here
SELECT lo.inst_id, lo.session_id AS sid, lo.oracle_username,
       lo.os_user_name, do.object_name, do.object_type,
       lo.locked_mode,
       DECODE(lo.locked_mode,
           0, 'None', 1, 'Null', 2, 'Row Share',
           3, 'Row Exclusive', 4, 'Share',
           5, 'Share Row Exc', 6, 'Exclusive') AS lock_type
FROM gv$locked_object lo
JOIN dba_objects do ON lo.object_id = do.object_id
ORDER BY lo.oracle_username;
```

### 4.2 Blocks and Who's Blocking Who

```sql
--Blockchain: Who is blocking whom?
--✅ FUNDAMENTAL: identify the "culprit" who blocks everyone else
SELECT
    s1.inst_id AS blocker_inst, s1.sid AS blocker_sid, s1.serial# AS blocker_serial,
    s1.username AS blocker_user, s1.program AS blocker_program,
    s2.inst_id AS waiter_inst, s2.sid AS waiter_sid, s2.serial# AS waiter_serial,
    s2.username AS waiter_user
FROM gv$lock l1
JOIN gv$session s1 ON l1.sid = s1.sid AND l1.inst_id = s1.inst_id
JOIN gv$lock l2 ON l1.id1 = l2.id1 AND l1.id2 = l2.id2 AND l1.block = 1 AND l2.request > 0
JOIN gv$session s2 ON l2.sid = s2.sid AND l2.inst_id = s2.inst_id;
```

### 4.3 Killing a Blocking Session

```sql
--Kill session (WARNING: use with caution!)
--🔶 DANGEROUS: user session ends, transaction is rolled back
ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;

--For RAC (specify instance):
ALTER SYSTEM KILL SESSION 'sid,serial#,@inst_id' IMMEDIATE;
```

---

## 5. 📋 Redo Log e Archive

### 5.1 Redo Log Status

```sql
--Online Status Redo Log
-- Fonte: oracle-base.com/dba/monitoring/logfiles.sql
-- ✅ FONDAMENTALE per Data Guard
SELECT group#, thread#, sequence#, bytes/1024/1024 AS size_mb,
       members, archived, status, first_time
FROM v$log
ORDER BY thread#, group#;
```

> **Status**: `CURRENT` = in uso ora, `ACTIVE` = necessario per recovery, `INACTIVE` = can be overridden.

### 5.2 Redo generation (to understand the load)

```sql
--Redo generated per day
-- Fonte: oracle-base.com/dba/monitoring/redo_by_day.sql
--✅ USEFUL: understand how much redo generates the DB (impacts DG and GG)
SELECT TRUNC(first_time) AS day,
       thread#,
       COUNT(*) AS log_switches,
       ROUND(SUM(blocks * block_size)/1024/1024) AS redo_mb
FROM v$archived_log
WHERE first_time > SYSDATE - 7
GROUP BY TRUNC(first_time), thread#
ORDER BY day DESC, thread#;
```

### 5.3 Redo Generation for Now

```sql
--Redo for now (more granular)
-- Fonte: oracle-base.com/dba/monitoring/redo_by_hour.sql
--✅ USEFUL: identify peaks of activity
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS hour,
       thread#,
       COUNT(*) AS switches
FROM v$archived_log
WHERE first_time > SYSDATE - 1
GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD HH24'), thread#
ORDER BY hour DESC;
```

---

## 6. 👥 Users and Security

### 6.1 Database Users

```sql
--List of users with status
--✅ USEFUL: check who is locked, expired, etc.
SELECT username, account_status, profile, default_tablespace,
       created, expiry_date, last_login
FROM dba_users
WHERE oracle_maintained = 'N'
ORDER BY username;
```

### 6.2 Privileges of a User

```sql
--System privileges of a user
-- Fonte: oracle-base.com/dba/monitoring/system_privs.sql
--✅ USEFUL for security audits
SELECT grantee, privilege, admin_option
FROM dba_sys_privs
WHERE grantee = UPPER('&username')
ORDER BY privilege;

--Roles assigned
-- Fonte: oracle-base.com/dba/monitoring/role_privs.sql
SELECT grantee, granted_role, admin_option
FROM dba_role_privs
WHERE grantee = UPPER('&username')
ORDER BY granted_role;
```

---

## 7. ⚡ Data Guard Monitoring

```sql
--Data Guard Status (run on STANDBY)
--✅ FUNDAMENTAL for our lab
SELECT name, value, datum_time, time_computed
FROM v$dataguard_stats;
```

```sql
--DG processes active on standby
SELECT process, pid, status, thread#, sequence#,
       block#, blocks
FROM v$managed_standby
ORDER BY process;
```

```sql
--Archivelog gap (must return 0 lines = no gaps)
SELECT * FROM v$archive_gap;
```

```sql
--Last log applied on standby
SELECT thread#, MAX(sequence#) AS last_applied,
       MAX(next_time) AS last_time
FROM v$archived_log
WHERE applied = 'YES'
GROUP BY thread#;
```

---

## 8. 🔧 Everyday DBA Commands

### 8.1 Startup / Shutdown

```sql
--Startup sequence
STARTUP;            -- Avvia: NOMOUNT → MOUNT → OPEN
STARTUP NOMOUNT;    -- Solo istanza (per creare DB o restore)
STARTUP MOUNT;      -- Monta il controlfile (per DG, maintenance)
STARTUP RESTRICT;   -- Apri ma solo DBA possono connettersi

-- Shutdown
SHUTDOWN IMMEDIATE;    -- Ferma, rollback delle transazioni attive, chiudi
SHUTDOWN ABORT;        -- EMERGENZA: termina immediatamente (richiede recovery)
SHUTDOWN TRANSACTIONAL; -- Aspetta fine transazioni, poi chiudi
SHUTDOWN NORMAL;       -- Wait for everyone to log out (can wait forever)
```

> **Rule**: Use`SHUTDOWN IMMEDIATE`in 99% of cases.`ABORT` only if IMMEDIATE is blocked.

### 8.2 srvctl (RAC)

```bash
# RAC database status
srvctl status database -d RACDB

# Avvia/ferma database
srvctl start database -d RACDB
srvctl stop database -d RACDB

# Start/stop single instance
srvctl start instance -d RACDB -i RACDB1
srvctl stop instance -d RACDB -i RACDB2

# Listener status
srvctl status listener
srvctl status scan_listener

#Complete setup
srvctl config database -d RACDB

#Status of all CRS services
crsctl stat res -t

# Cluster status
crsctl check crs
olsnodes -n -s
```

### 8.3 Tablespace Management

```sql
-- Crea tablespace
CREATE TABLESPACE app_data
    DATAFILE '+DATA' SIZE 500M
    AUTOEXTEND ON NEXT 100M MAXSIZE 5G;

-- Aggiungi datafile
ALTER TABLESPACE app_data
    ADD DATAFILE '+DATA' SIZE 500M AUTOEXTEND ON;

--Resize datafile
ALTER DATABASE DATAFILE '+DATA/RACDB/...filename...' RESIZE 1G;

--Take tablespace offline (maintenance)
ALTER TABLESPACE app_data OFFLINE;
ALTER TABLESPACE app_data ONLINE;
```

### 8.4 User Management

```sql
--Create user
CREATE USER app_user IDENTIFIED BY "Password123!"
    DEFAULT TABLESPACE app_data
    TEMPORARY TABLESPACE temp
UNLIMITED QUOTE ON app_data;

--Assign permissions
GRANT CONNECT, RESOURCE TO app_user;
GRANT CREATE VIEW, CREATE SYNONYM TO app_user;

-- Cambia password
ALTER USER app_user IDENTIFIED BY "NuovaPassword!";

--Lock/Unlock user
ALTER USER app_user ACCOUNT LOCK;
ALTER USER app_user ACCOUNT UNLOCK;

--Password profile (no expiration for lab)
CREATE PROFILE lab_profile LIMIT
    PASSWORD_LIFE_TIME UNLIMITED
    PASSWORD_REUSE_TIME UNLIMITED
    PASSWORD_REUSE_MAX UNLIMITED
    FAILED_LOGIN_ATTEMPTS UNLIMITED;

ALTER USER app_user PROFILE lab_profile;
```

### 8.5 Statistiche e Performance

```sql
--Collect statistics (after data upload)
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('HR');
EXEC DBMS_STATS.GATHER_DATABASE_STATS;

--Invalid Items (After Patching)
-- Fonte: oracle-base.com/dba/monitoring/invalid_objects.sql
SELECT owner, object_type, object_name, status
FROM dba_objects
WHERE status = 'INVALID'
ORDER BY owner, object_type, object_name;

--Recompile all invalid objects
@$ORACLE_HOME/rdbms/admin/utlrp.sql
```

### 8.6 Alert Log — The DBA's "Diary".

```bash
# Find the alert log
adrci
ADRCI> SHOW ALERT

# Or directly:
tail -200 $ORACLE_BASE/diag/rdbms/racdb/RACDB1/trace/alert_RACDB1.log

# Look for ORA- errors in the alert
grep "ORA-" $ORACLE_BASE/diag/rdbms/racdb/RACDB1/trace/alert_RACDB1.log | tail -20
```

> **Read the alert log EVERY DAY.** This is the first place to look for problems.

### 8.7 AWR Report (Performance Historica)

```sql
-- Genera un AWR Report (HTML)
--✅ FUNDAMENTAL for performance analysis
@$ORACLE_HOME/rdbms/admin/awrrpt.sql

--Clean up old AWR snapshots
EXEC DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(retention => 7*24*60, interval => 60);
```

---

## 9. 🔄 Unused Items and Cleaning

```sql
--Unused indices (for optimization)
-- Fonte: oracle-base.com/dba/monitoring/index_usage.sql
--🔶 ATTENTION: monitor for at least one complete business cycle
ALTER INDEX hr.emp_name_idx MONITORING USAGE;

--After a while, check:
SELECT * FROM v$object_usage;

-- Recyclebin (cestino Oracle)
-- Fonte: oracle-base.com/dba/monitoring/recyclebin.sql
SELECT owner, original_name, object_name, type, droptime
FROM dba_recyclebin
ORDER BY droptime DESC;

--Empty the trash
PURGE DBA_RECYCLEBIN;
```

---

## 10. oracle-base.com Scripts — Selection and Evaluation

### ⬇️ Script da Scaricare e Usare

| Script | Categoria |Assessment|Description|
|---|---|---|---|
| `active_sessions.sql` |Monitoring|✅ **Essential**|Active sessions with SQL|
| `sessions.sql` |Monitoring|✅ **Essential**| All sessions |
| `top_sql.sql` |Monitoring|✅ **Essential**| More expensive queries |
| `locked_objects.sql` |Monitoring|✅ **Essential**|Locked objects|
| `ts_full.sql` |Monitoring|✅ **Essential**|Tablespace space|
| `datafiles.sql` |Monitoring| ✅ **Helpful** |Datafile info|
| `logfiles.sql` |Monitoring| ✅ **Helpful** | Redo log status |
| `redo_by_day.sql` |Monitoring| ✅ **Helpful** | Redo volume per day |
| `redo_by_hour.sql` |Monitoring| ✅ **Helpful** | Volume redo per ora |
| `invalid_objects.sql` |Monitoring|✅ **Essential**| Oggetti INVALID |
| `session_waits.sql` |Monitoring|✅ **Essential**| Wait events per sessione |
| `system_events.sql` |Monitoring| ✅ **Helpful** | Wait system events |
| `parameters_non_default.sql` |Monitoring| ✅ **Helpful** |Parameters changed|
| `patch_registry.sql` |Monitoring| ✅ **Helpful** | Patch installate |
| `cache_hit_ratio.sql` |Monitoring| ✅ **Helpful** |Cache buffer efficiency|
| `free_space.sql` |Monitoring| ✅ **Helpful** |Free space|
| `longops.sql` |Monitoring| ✅ **Helpful** |Long operations|
| `recovery_status.sql` |Monitoring| ✅ **Helpful** | Recovery status |
| `db_info.sql` |Monitoring|✅ **Essential**| Info database |
| `sessions_rac.sql` | RAC |✅ **RAC essential**| Sessions for all instances |
| `locked_objects_rac.sql` | RAC |✅ **RAC essential**| Lock on all instances |
| `session_waits_rac.sql` | RAC |✅ **RAC essential**| Wait on all instances |
| `monitor_memory_rac.sql` | RAC | ✅ **Useful RAC** | Memory usage per instance |
| `compile_all.sql` | Misc |🔶 **Situational**| Recompile everything (after patch) |
| `login.sql` | Misc | ✅ **Recommended** |Customize SQL*Plus prompt|
| `health.sql` |Monitoring|✅ **Essential**| Health check complessivo |

### ❌ Scripts NOT to use in your Lab

| Script | Motivo |
|---|---|
| `drop_all.sql` | 🚨 Dangerous! Clear ALL schema objects |
| `analyze_all.sql` | Obsoleto, usa `DBMS_STATS` |
| `dispatchers.sql` | Solo per Shared Server (noi usiamo Dedicated) |
| `pipes.sql` |Only forDBMS_PIPE(very specific use)|

### How to Download Scripts

```bash
# Crea la directory degli script DBA
mkdir -p /home/oracle/dba_scripts

#Download the essential scripts
cd /home/oracle/dba_scripts
for script in active_sessions sessions top_sql locked_objects ts_full \
              datafiles logfiles redo_by_day invalid_objects session_waits \
              system_events db_info health free_space longops; do
    wget -q "https://oracle-base.com/dba/monitoring/${script}.sql"
done

# Script RAC
for script in sessions_rac locked_objects_rac session_waits_rac monitor_memory_rac; do
    wget -q "https://oracle-base.com/dba/rac/${script}.sql"
done

# Login.sqlto customize SQL*Plus
wget -q "https://oracle-base.com/dba/miscellaneous/login.sql"
# Copy to oracle home
cp login.sql /home/oracle/login.sql
```

---

## 11. 🏁 Checklist DBA di Fine Lab

Perform all these checks as a final check of your environment:

```sql
-- ==============================
-- CHECKLIST DBA FINALE
--Run as SYS on each DB
-- ==============================

--1. Database open and in archivelog?
SELECT name, open_mode, log_mode, force_logging, database_role FROM v$database;

-- 2. Tutte le istanze RAC online?
SELECT inst_id, instance_name, status FROM gv$instance;

-- 3. Tablespace non pieni?
SELECT tablespace_name,
       ROUND((used_space/tablespace_size)*100) AS pct_used
FROM dba_tablespace_usage_metrics
WHERE ROUND((used_space/tablespace_size)*100) > 80;

--4. Invalid items?
SELECT COUNT(*) AS invalid_count FROM dba_objects WHERE status = 'INVALID';

--5. Data Guard synchronized?
SELECT * FROM v$archive_gap;  -- 0 righe = OK

-- 6. RMAN backup recente?
SELECT input_type, status, start_time, end_time
FROM v$rman_backup_job_details
WHERE start_time > SYSDATE - 1
ORDER BY start_time DESC;

-- 7. Alert log errori recenti?
--(run from bash)
-- grep "ORA-" $ORACLE_BASE/diag/rdbms/*/*/trace/alert_*.log | tail -10

--8. ASM space?
SELECT name, total_mb, free_mb,
       ROUND((1-free_mb/total_mb)*100) AS pct_used
FROM v$asm_diskgroup;
```
