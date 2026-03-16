# GUIDE: Essential DBA Tasks — Batch, AWR, Patching, Data Pump, Security

> **Goal**: This guide covers the daily DBA tasks that were missing from the lab: batch jobs, performance analysis (AWR/ADDM/ASH), patching, Data Pump import/export, security hardening, and tablespace management.
>
> Each section includes lab-ready commands and production notes.

---

## Indice

1. [Batch Jobs con DBMS_SCHEDULER](#1-batch-jobs)
2. [AWR, ADDM e ASH — Performance Analysis](#2-awr-addm-ash)
3. [Oracle Patching Workflow](#3-oracle-patching)
4. [Data Pump Import/Export](#4-data-pump)
5. [Security Hardening](#5-security-hardening)
6. [Tablespace Management Avanzato](#6-tablespace-management)

---

## 1. Batch Jobs

### 1.1 What is it DBMS_SCHEDULER?

DBMS_SCHEDULER is Oracle's scheduling system. Replaces the old one DBMS_JOB and it is much more powerful.

```
╔══════════════════════════════════════════════════════════════════╗
║                 COMPONENTI DBMS_SCHEDULER                        ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ PROGRAM ──────── What to run (PL/SQL, script, executable) ║
║       │                                                          ║
║  SCHEDULE ─────── Quando eseguire (cron-like)                    ║
║       │                                                          ║
║  JOB ──────────── Combina Program + Schedule                     ║
║       │                                                          ║
║  WINDOW ───────── Finestra temporale per resource management     ║
║       │                                                          ║
║ JOB CLASS ────── Group jobs for resource management ║
║                                                                  ║
║  Hierarchy:                                                      ║
║  ┌──────────┐    ┌──────────┐                                    ║
║  │ PROGRAM  │ +  │ SCHEDULE │ = JOB                              ║
║  └──────────┘    └──────────┘                                    ║
╚══════════════════════════════════════════════════════════════════╝
```

### 1.2 Create a Statistics Collection Job (Lab)

```sql
-- ═══════════════════════════════════════════════════════
--Job: Collect statistics every night at 02:00
--(Crucial for the optimizer!)
-- ═══════════════════════════════════════════════════════

BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'JOB_GATHER_STATS',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN
                          DBMS_STATS.GATHER_DATABASE_STATS(
                            estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
                            method_opt       => ''FOR ALL COLUMNS SIZE AUTO'',
                            cascade          => TRUE,
                            options          => ''GATHER STALE''
                          );
                        END;',
start_date => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY; BYHOUR=2; BYMINUTE=0; BYSECOND=0',
    enabled         => TRUE,
auto_drop => FALSE,
comments => 'Nightly statistics collection - stale tables only'
  );
END;
/
```

### 1.3 Archivelog Cleanup Job

```sql
-- ═══════════════════════════════════════════════════════
--Job: Cleaning old archivelogs every 4 hours
-- ═══════════════════════════════════════════════════════

BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'JOB_PURGE_ARCHIVELOG',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN
                          --Call RMAN to delete already backed up archivelogs
                          --PL/SQL alternative: useDBMS_BACKUP_RESTORE
NULL; -- In production, run RMAN via external script
                        END;',
start_date => SYSTIMESTAMP,
    repeat_interval => 'FREQ=HOURLY; INTERVAL=4',
    enabled         => TRUE,
auto_drop => FALSE,
    comments        => 'Pulizia archivelog backed-up ogni 4 ore'
  );
END;
/
```

### 1.4 Job di Health Check Automatico

```sql
-- ═══════════════════════════════════════════════════════
-- Job: Health Check ogni 30 minuti
-- ═══════════════════════════════════════════════════════

--First, create the results table
CREATE TABLE dba_health_log (
    check_time   TIMESTAMP DEFAULT SYSTIMESTAMP,
    check_name   VARCHAR2(50),
    check_value  VARCHAR2(200),
    check_status VARCHAR2(10)  -- OK / WARNING / CRITICAL
);

BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'JOB_HEALTH_CHECK',
    job_type        => 'PLSQL_BLOCK',
    job_action      => q'[BEGIN
      -- Controlla tablespace > 85%
      INSERT INTO dba_health_log (check_name, check_value, check_status)
      SELECT 'TS_USAGE', tablespace_name || ': ' || ROUND(used_percent,1) || '%',
             CASE WHEN used_percent > 90 THEN 'CRITICAL'
                  WHEN used_percent > 85 THEN 'WARNING'
                  ELSE 'OK' END
      FROM dba_tablespace_usage_metrics
      WHERE used_percent > 85;

      --Check active sessions
      INSERT INTO dba_health_log (check_name, check_value, check_status)
      SELECT 'ACTIVE_SESSIONS', TO_CHAR(COUNT(*)),
             CASE WHEN COUNT(*) > 100 THEN 'WARNING' ELSE 'OK' END
      FROM v$session WHERE status = 'ACTIVE' AND username IS NOT NULL;

      --Check DG lag (if applicable)
      INSERT INTO dba_health_log (check_name, check_value, check_status)
      SELECT 'DG_LAG', value,
             CASE WHEN TO_NUMBER(REGEXP_SUBSTR(value,'\d+')) > 300 THEN 'CRITICAL'
                  WHEN TO_NUMBER(REGEXP_SUBSTR(value,'\d+')) > 60  THEN 'WARNING'
                  ELSE 'OK' END
      FROM v$dataguard_stats WHERE name = 'apply lag';

      COMMIT;
    END;]',
start_date => SYSTIMESTAMP,
    repeat_interval => 'FREQ=MINUTELY; INTERVAL=30',
    enabled         => TRUE,
auto_drop => FALSE,
comments => 'Automatic health check every 30 minutes'
  );
END;
/
```

### 1.5 Job Monitoring

```sql
-- Tutti i job schedulati
SELECT job_name, job_type, state, enabled,
       last_start_date, next_run_date, run_count, failure_count
FROM   dba_scheduler_jobs
WHERE  owner NOT IN ('SYS','ORACLE_MAINTENANCE')
ORDER BY job_name;

--History of executions (last 20)
SELECT job_name, status, actual_start_date,
run_duration, error#, additional_info
FROM   dba_scheduler_job_run_details
ORDER BY actual_start_date DESC
FETCH FIRST 20 ROWS ONLY;

-- Job falliti
SELECT job_name, status, error#, additional_info
FROM   dba_scheduler_job_run_details
WHERE  status = 'FAILED'
ORDER BY actual_start_date DESC;

-- Gestione job
EXEC DBMS_SCHEDULER.ENABLE('JOB_HEALTH_CHECK');
EXEC DBMS_SCHEDULER.DISABLE('JOB_HEALTH_CHECK');
EXEC DBMS_SCHEDULER.RUN_JOB('JOB_HEALTH_CHECK');        -- run now
EXEC DBMS_SCHEDULER.DROP_JOB('JOB_HEALTH_CHECK', TRUE); -- rimuovi
```

---

## 2. AWR, ADDM e ASH

### 2.1 What is AWR?

**AWR = Automatic Workload Repository**. Oracle takes "snapshots" of database activity every hour and keeps them for 8 days (default). You can generate reports that show what happened between two snapshots.

```
╔══════════════════════════════════════════════════════════════════╗
║                    AWR / ADDM / ASH                              ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  AWR (Automatic Workload Repository)                             ║
║ ├── Snapshot every 60 minutes (configurable) ║
║ ├── Retention: 8 days (configurable) ║
║ ├── Contains: SQL stats, wait events, SGA, I/O, etc.            ║
║  └── Report: HTML confronto tra 2 snapshot                       ║
║                                                                  ║
║ ADDM (Automatic Database Diagnostic Monitor) ║
║ ├── Automatically analyze each AWR snapshot ║
║ ├── Generate recommendations (e.g. "add more memory") ║
║ └── The database "doctor" ║
║                                                                  ║
║  ASH (Active Session History)                                    ║
║ ├── Sample active sessions every second ║
║  ├── In memoria (V$ACTIVE_SESSION_HISTORY)                       ║
║ ├── History on disk (DBA_HIST_ACTIVE_SESS_HISTORY)             ║
║ └── Perfect for "what was happening 10 minutes ago?"          ║
║                                                                  ║
║  RELAZIONE:                                                      ║
║ ASH (real-time, 1 sec) → AWR (aggregate, 1 hour) → ADDM (analysis)║
╚══════════════════════════════════════════════════════════════════╝
```

### 2.2 Generare un Report AWR

```sql
--1. List of available snapshots
SELECT snap_id, begin_interval_time, end_interval_time
FROM   dba_hist_snapshot
ORDER BY snap_id DESC
FETCH FIRST 20 ROWS ONLY;

-- 2. Genera report AWR (HTML)
--Take note of two snap_ids (start and end of the period you want to analyze)
@$ORACLE_HOME/rdbms/admin/awrrpt.sql
--It will ask you:
--   report type: html
--   num_days: 1
--begin snap_id: <start_id>
--   end snap_id: <id_fine>
--   report name: awr_report.html

-- 3. Per RAC (report cross-instance):
@$ORACLE_HOME/rdbms/admin/awrgrpt.sql
```

### 2.3 ADDM Report (Automatic Recommendations)

```sql
-- Genera report ADDM
@$ORACLE_HOME/rdbms/admin/addmrpt.sql
--It will ask you begin/end snap_id as AWR

--Or via PL/SQL:
DECLARE
  v_task_name VARCHAR2(100) := 'ADDM_MANUAL_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MI');
  v_begin_snap NUMBER;
  v_end_snap   NUMBER;
BEGIN
  SELECT MAX(snap_id) - 1, MAX(snap_id)
  INTO   v_begin_snap, v_end_snap
  FROM   dba_hist_snapshot;

  DBMS_ADVISOR.CREATE_TASK('ADDM', v_task_name);
  DBMS_ADVISOR.SET_TASK_PARAMETER(v_task_name, 'START_SNAPSHOT', v_begin_snap);
  DBMS_ADVISOR.SET_TASK_PARAMETER(v_task_name, 'END_SNAPSHOT', v_end_snap);
  DBMS_ADVISOR.EXECUTE_TASK(v_task_name);
END;
/

--View the results
SELECT finding_name, type, message
FROM   dba_advisor_findings
WHERE  task_name LIKE 'ADDM_MANUAL_%'
ORDER BY impact DESC;
```

### 2.4 ASH — Real-Time Analysis

```sql
-- Top 5 wait events nell'ultima ora
SELECT event, wait_class, COUNT(*) AS samples,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
AND    event IS NOT NULL
GROUP BY event, wait_class
ORDER BY 3 DESC
FETCH FIRST 5 ROWS ONLY;

--Top SQL in the last hour
SELECT sql_id, COUNT(*) AS samples,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
AND    sql_id IS NOT NULL
GROUP BY sql_id
ORDER BY 2 DESC
FETCH FIRST 10 ROWS ONLY;

--Full ASH report
@$ORACLE_HOME/rdbms/admin/ashrpt.sql

--ASH for a specific SQL
@$ORACLE_HOME/rdbms/admin/ashrpti.sql
```

### 2.5 Configurare AWR

```sql
--See current configuration
SELECT * FROM dba_hist_wr_control;

--Change retention (30 days) and interval (30 minutes)
EXEC DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(
retention => 30 * 24 * 60, -- 30 days in minutes
    interval  => 30             -- snapshot ogni 30 minuti
);

--Create a manual snapshot (before/after a test)
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT;
```

> **Note**: AWR requires the **Diagnostic Pack** license (included with Enterprise Edition). In the lab there is no problem. In production, check your license.

---

## 3. Oracle Patching

### 3.1 Workflow di Patching

```
╔══════════════════════════════════════════════════════════════════╗
║              WORKFLOW PATCHING ORACLE 19c                        ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  1. PREPARAZIONE                                                 ║
║     ├── Download patch da My Oracle Support (MOS)                ║
║ ├── Read the patch's README ║
║ ├── Check prerequisites (OPatch version, conflicts) ║
║     └── SNAPSHOT VM! 📸                                          ║
║                                                                  ║
║  2. PRE-CHECK                                                    ║
║ ├── OPatch lsinventory (current status) ║
║     ├── Analyze mode (dry run)                                    ║
║     └── Backup ORACLE_HOME                                       ║
║                                                                  ║
║  3. APPLICAZIONE                                                 ║
║     ├── RAC: opatchauto apply (gestisce rolling)                 ║
║     ├── Single: OPatch apply                                     ║
║     └── OJVM: separato, richiede shutdown                        ║
║                                                                  ║
║  4. POST-PATCH                                                   ║
║ ├── datapatch -verbose (SQL patch in dictionary) ║
║     ├── utlrp.sql(refill invalid) ║
║ └── Check: OPatch lsinventory ║
╚══════════════════════════════════════════════════════════════════╝
```

### 3.2 Update OPatch

```bash
#First of all, always update OPatch!
# Download da MOS: Patch 6880880

#Backup of the old OPatch
mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch_bak

# Unpack the new one
unzip p6880880_*_Linux-x86-64.zip -d $ORACLE_HOME/

#Verify
$ORACLE_HOME/OPatch/opatch version
# Deve essere >= 12.2.0.1.37 per RU recenti
```

### 3.3 Applicare Release Update (RU)

```bash
# ═══════════════════════════════════════════════════════
# APPLY RU on RAC (Rolling — no downtime!)
# ═══════════════════════════════════════════════════════

# 1. Pre-check (dry run)
$ORACLE_HOME/OPatch/opatchauto apply /path/to/patch_dir \
    -analyze -oh $ORACLE_HOME

#2. Application (as root, node by node)
#On node 1:
sudo $ORACLE_HOME/OPatch/opatchauto apply /path/to/patch_dir \
    -oh $ORACLE_HOME

#On node 2 (after node 1 is completed):
sudo $ORACLE_HOME/OPatch/opatchauto apply /path/to/patch_dir \
    -oh $ORACLE_HOME

#3. Post-patch (like oracle, on a single node)
sqlplus / as sysdba
@$ORACLE_HOME/rdbms/admin/catbundle.sql psu apply
-- Oppure per 19c+:
$ORACLE_HOME/OPatch/datapatch -verbose

#4. Recompile invalid objects
@$ORACLE_HOME/rdbms/admin/utlrp.sql

#5. Check
$ORACLE_HOME/OPatch/opatch lsinventory
```

### 3.4 Applicare su Single Instance (Target/Cloud)

```bash
# Shutdown database
sqlplus / as sysdba <<< "SHUTDOWN IMMEDIATE"
lsnrctl stop

# Apply patches
cd /path/to/patch_number
$ORACLE_HOME/OPatch/opatch apply

# Riavvia
lsnrctl start
sqlplus / as sysdba <<< "STARTUP"

# Post-patch
$ORACLE_HOME/OPatch/datapatch -verbose
sqlplus / as sysdba @$ORACLE_HOME/rdbms/admin/utlrp.sql
```

---

## 4. Data Pump

### 4.1 Data Pump Architecture

```
╔══════════════════════════════════════════════════════════════════╗
║ DATA PUMP ARCHITECTURE ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  expdp (Export)          impdp (Import)                          ║
║  ┌──────────┐            ┌──────────┐                            ║
║  │ Client   │            │ Client   │                            ║
║  │ (CLI)    │            │ (CLI)    │                            ║
║  └────┬─────┘            └────┬─────┘                            ║
║       │                       │                                  ║
║       ▼                       ▼                                  ║
║  ┌──────────────────────────────────────────┐                    ║
║  │  Data Pump Engine (Server-side!)         │                    ║
║ │ - Master Table (track progress) │ ║
║  │  - Worker Processes (paralleli)           │                    ║
║  │  - Direct Path / External Table mode      │                    ║
║  └────────────────────┬─────────────────────┘                    ║
║                       │                                          ║
║                       ▼                                          ║
║  ┌────────────────────────────────────────────┐                  ║
║  │  Dump File (.dmp) su DIRECTORY Oracle       │                  ║
║ │ (must be a SERVER path, not client)│ ║
║  └────────────────────────────────────────────┘                  ║
║                                                                  ║
║  KEY: I file .dmp sono SEMPRE sul server, mai sul client!        ║
╚══════════════════════════════════════════════════════════════════╝
```

### 4.2 Creare Directory Oracle

```sql
-- Crea directory per Data Pump
CREATE OR REPLACE DIRECTORY DPUMP_DIR AS '/u01/app/oracle/dpump';
GRANT READ, WRITE ON DIRECTORY DPUMP_DIR TO ggadmin;

-- Crea la directory OS
--As oracle:
mkdir -p /u01/app/oracle/dpump
```

### 4.3 Export — Vari Livelli

```bash
# ═══════════════════════════════════════════════════════
# EXPORT FULL DATABASE
# ═══════════════════════════════════════════════════════
expdp system/<password> \
    full=y \
    directory=DPUMP_DIR \
    dumpfile=fulldb_%U.dmp \
    filesize=5G \
    logfile=fulldb_export.log \
parallel=4 \
compression=ALL \
    reuse_dumpfiles=y

# ═══════════════════════════════════════════════════════
#EXPORT SCHEME (most common)
# ═══════════════════════════════════════════════════════
expdp system/<password> \
    schemas=HR,OE \
    directory=DPUMP_DIR \
    dumpfile=schemas_hr_oe.dmp \
    logfile=schemas_export.log \
compression=ALL

# ═══════════════════════════════════════════════════════
# EXPORT TABELLE SPECIFICHE
# ═══════════════════════════════════════════════════════
expdp hr/<password> \
    tables=HR.EMPLOYEES,HR.DEPARTMENTS \
    directory=DPUMP_DIR \
    dumpfile=tables_emp_dept.dmp \
    logfile=tables_export.log

# ═══════════════════════════════════════════════════════
# EXPORT WITH FILTER (recent data only)
# ═══════════════════════════════════════════════════════
expdp hr/<password> \
    tables=HR.EMPLOYEES \
    directory=DPUMP_DIR \
    dumpfile=emp_recent.dmp \
    query=HR.EMPLOYEES:"WHERE hire_date > DATE'2020-01-01'"
```

### 4.4 Import

```bash
# ═══════════════════════════════════════════════════════
# IMPORT SCHEMA SUL TARGET
# ═══════════════════════════════════════════════════════
impdp system/<password>@CLOUDDB \
    schemas=HR \
    directory=DPUMP_DIR \
    dumpfile=schemas_hr_oe.dmp \
    logfile=schemas_import.log \
    table_exists_action=REPLACE

# ═══════════════════════════════════════════════════════
# IMPORT CON REMAP (cambia schema/tablespace)
# ═══════════════════════════════════════════════════════
impdp system/<password>@CLOUDDB \
    schemas=HR \
    remap_schema=HR:HR_CLOUD \
    remap_tablespace=USERS:CLOUD_DATA \
    directory=DPUMP_DIR \
    dumpfile=schemas_hr_oe.dmp

# TABLE_EXISTS_ACTION:
#   SKIP     — salta se esiste (default)
# APPEND — add lines
# TRUNCATE — empty and re-import
#   REPLACE  — drop + ricrea
```

### 4.5 Network Mode (Database Link)

```bash
# Direct import via DB Link (without .dmp files!)
# Useful when you don't have space to dump

impdp system/<password>@CLOUDDB \
    network_link=RACDB_STBY_LINK \
    schemas=HR \
    logfile=network_import.log \
parallel=2
```

---

## 5. Security Hardening

### 5.1 Password Profile

```sql
-- ═══════════════════════════════════════════════════════
-- Creare un profilo password sicuro
-- ═══════════════════════════════════════════════════════
CREATE PROFILE SECURE_PROFILE LIMIT
    PASSWORD_LIFE_TIME90 -- expires every 90 days
    PASSWORD_GRACE_TIME7 -- 7 days of grace
    PASSWORD_REUSE_TIME365 -- do not reuse for 1 year
    PASSWORD_REUSE_MAX      12      -- min 12 password diverse
    PASSWORD_LOCK_TIME1 -- lock for 1 day after attempts
    FAILED_LOGIN_ATTEMPTS5 -- 5 attempts max
    PASSWORD_VERIFY_FUNCTION ORA12C_VERIFY_FUNCTION;

--Assign profile to application users
ALTER USER hr PROFILE SECURE_PROFILE;
ALTER USER ggadmin PROFILE SECURE_PROFILE;

--Check profiles
SELECT username, profile, account_status
FROM   dba_users
WHERE  oracle_maintained = 'N';
```

### 5.2 Unified Auditing

```sql
-- ═══════════════════════════════════════════════════════
--Enable audits on critical operations
-- ═══════════════════════════════════════════════════════

--Audit on failed logins
CREATE AUDIT POLICY pol_failed_login
    ACTIONS LOGON;
AUDIT POLICY pol_failed_login WHENEVER NOT SUCCESSFUL;

--Audit on DDL operations (CREATE/ALTER/DROP)
CREATE AUDIT POLICY pol_ddl_changes
    ACTIONS CREATE TABLE, ALTER TABLE, DROP TABLE,
            CREATE USER, ALTER USER, DROP USER,
            GRANT, REVOKE;
AUDIT POLICY pol_ddl_changes;

--Audit on sensitive data access
CREATE AUDIT POLICY pol_sensitive_data
    ACTIONS SELECT ON HR.EMPLOYEES,
            UPDATE ON HR.EMPLOYEES,
            DELETE ON HR.EMPLOYEES;
AUDIT POLICY pol_sensitive_data;

--Check active audit
SELECT policy_name, enabled_option, entity_name
FROM   audit_unified_enabled_policies
ORDER BY policy_name;

--View audit logs
SELECT event_timestamp, dbusername, action_name,
       object_schema, object_name, sql_text
FROM   unified_audit_trail
WHERE  event_timestamp > SYSDATE - 1
ORDER BY event_timestamp DESC
FETCH FIRST 20 ROWS ONLY;
```

### 5.3 Transparent Data Encryption (TDE) — Concetti

```
╔══════════════════════════════════════════════════════════════════╗
║ TDE — How It Works ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  ┌──────────────┐                                                ║
║ │ Wallet │ ← Master Key (password protected) ║
║  │  (keystore)  │                                                ║
║  └──────┬───────┘                                                ║
║         │                                                        ║
║         ▼                                                        ║
║  ┌──────────────┐                                                ║
║ │Table Keys │ ← One key per table/tablespace ║
║  │(encriptate   │   (encriptata con la Master Key)               ║
║  │ con master)  │                                                ║
║  └──────┬───────┘                                                ║
║         │                                                        ║
║         ▼                                                        ║
║  ┌──────────────┐                                                ║
║ │ Datafile │ ← Block-level encrypted data ║
║ │ (.dbf) │ Transparent to the application ║
║  └──────────────┘                                                ║
║                                                                  ║
║  ATTENZIONE:                                                     ║
║ • TDE encrypts data ON DISK, not in memory ║
║ • Performance drops ~5-10% (CPU for encrypt/decrypt) ║
║ • The wallet MUST be backed up separately!               ║
╚══════════════════════════════════════════════════════════════════╝
```

```sql
-- Setup TDE (lab)
-- 1. Configura la directory del wallet
-- In sqlnet.ora:
-- ENCRYPTION_WALLET_LOCATION =
--   (SOURCE = (METHOD = FILE) (METHOD_DATA = (DIRECTORY = /u01/app/oracle/admin/RACDB/wallet)))

-- 2. Crea il keystore
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE '/u01/app/oracle/admin/RACDB/wallet'
    IDENTIFIED BY <wallet_password>;

-- 3. Apri il keystore
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
    IDENTIFIED BY <wallet_password>;

-- 4. Crea la master key
ADMINISTER KEY MANAGEMENT SET KEY
    IDENTIFIED BY <wallet_password>
    WITH BACKUP USING 'tde_master_backup';

-- 5. Encripta un tablespace
ALTER TABLESPACE USERS ENCRYPTION ONLINE ENCRYPT;
```

### 5.4 Network Encryption

```bash
# In sqlnet.ora (su server e client)

# Server
SQLNET.ENCRYPTION_SERVER = REQUIRED
SQLNET.ENCRYPTION_TYPES_SERVER = (AES256)
SQLNET.CRYPTO_CHECKSUM_SERVER = REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER = (SHA256)

# Client
SQLNET.ENCRYPTION_CLIENT = REQUIRED
SQLNET.ENCRYPTION_TYPES_CLIENT = (AES256)
SQLNET.CRYPTO_CHECKSUM_CLIENT = REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_CLIENT = (SHA256)
```

---

## 6. Tablespace Management

### 6.1 Common Operations

```sql
-- ═══════════════════════════════════════════════════════
-- CREARE UN TABLESPACE
-- ═══════════════════════════════════════════════════════

-- Standard (autoextend, max 32G)
CREATE TABLESPACE APP_DATA
    DATAFILE '+DATA' SIZE 500M
    AUTOEXTEND ON NEXT 100M MAXSIZE 32G
    EXTENT MANAGEMENT LOCAL AUTOALLOCATE
    SEGMENT SPACE MANAGEMENT AUTO;

--Additional TEMP tablespace (for large operations)
CREATE TEMPORARY TABLESPACE TEMP_LARGE
    TEMPFILE '+DATA' SIZE 2G
    AUTOEXTEND ON NEXT 500M MAXSIZE 10G;

-- ═══════════════════════════════════════════════════════
-- GESTIRE DATAFILE
-- ═══════════════════════════════════════════════════════

--Add datafile
ALTER TABLESPACE APP_DATA
    ADD DATAFILE '+DATA' SIZE 1G AUTOEXTEND ON;

--Resize datafile
ALTER DATABASE DATAFILE '+DATA/RACDB/datafile/app_data01.dbf' RESIZE 2G;

-- ═══════════════════════════════════════════════════════
-- MONITORING TABLESPACE
-- ═══════════════════════════════════════════════════════

--Quick usage view
SELECT tablespace_name,
       ROUND(used_percent, 1) AS pct_used,
       CASE WHEN used_percent > 90 THEN '🔴 CRITICAL'
            WHEN used_percent > 80 THEN '🟡 WARNING'
            ELSE '🟢 OK' END AS status
FROM   dba_tablespace_usage_metrics
ORDER BY used_percent DESC;

--Tablespace with autoextend disabled (risk!)
SELECT file_name, tablespace_name, autoextensible,
       ROUND(bytes/1024/1024) AS size_mb,
       ROUND(maxbytes/1024/1024) AS max_mb
FROM dba_data_files
WHERE  autoextensible = 'NO';
```

### 6.2 Undo Management

```sql
--Check Undo configuration
SHOW PARAMETER undo;
-- undo_tablespace: UNDOTBS1
--undo_retention: 900 (15 minutes default)

--In production, it increases retention
ALTER SYSTEM SET undo_retention = 3600 SCOPE=BOTH;  -- 1 ora

--Monitor Undo usage
SELECT tablespace_name, status,
       ROUND(SUM(bytes)/1024/1024) AS mb
FROM   dba_undo_extents
GROUP BY tablespace_name, status;
--ACTIVE: transactions in progress
--UNEXPIRED: within retention, reusable if necessary
--EXPIRED: beyond retention, freely reusable
```

### 6.3 Temp Tablespace Management

```sql
-- Uso corrente temp
SELECT tablespace_name,
       ROUND(tablespace_size/1024/1024) AS total_mb,
       ROUND(allocated_space/1024/1024) AS allocated_mb,
       ROUND(free_space/1024/1024) AS free_mb
FROM   dba_temp_free_space;

--Who is using TEMP?
SELECT s.sid, s.serial#, s.username, s.program,
       ROUND(t.blocks * 8 / 1024) AS temp_mb
FROM   v$session s, v$tempseg_usage t
WHERE  s.saddr = t.session_addr
ORDER BY t.blocks DESC;

--Shrink tempfile (after checking it is empty)
ALTER DATABASE TEMPFILE '+DATA/RACDB/tempfile/temp01.dbf' RESIZE 500M;
```

---

## Daily DBA Activities Checklist

```
╔═══════════════════════════════════════════════════════════════════╗
║ DBA CHECKLIST — Daily Activities ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  MATTINA (15 min)                                                ║
║ ☐ Check alert log for errors NOW- ║
║ ☐ Check tablespace space (>85% = warning) ║
║ ☐ Verify RMAN backup completed successfully ║
║ ☐ Check DG lag (< 60 sec) ║
║ ☐ Check failed scheduled jobs ║
║                                                                   ║
║ WEEKLY (30 min) ║
║ ☐ Generate AWR report for the week ║
║ ☐ Review ADDM recommendations ║
║ ☐ Check datafile growth ║
║ ☐ Verify backup validity (RESTORE VALIDATE) ║
║ ☐ Check available patches on MOS ║
║                                                                   ║
║ MONTHLY (1-2 hours) ║
║  ☐ Report capacity planning (crescita storage)                   ║
║ ☐ Security review (users, privileges, audits) ║
║ ☐ Test RMAN restore on test environment ║
║ ☐ Apply security patches (CPU/PSU) ║
║ ☐ Check updated statistics ║
╚═══════════════════════════════════════════════════════════════════╝
```

---

> **Prossimo**: [GUIDE_MAA_BEST_PRACTICES.md](./GUIDE_MAA_BEST_PRACTICES.md) — Lab validation against Oracle MAA
