# DBA Commands & Useful Scripts

> Essential Oracle DBA commands organized by category. Curated from oracle-base.com and real-world use.

---

## 🔍 Instance & Database Status

```sql
-- Instance status (RAC: all instances)
SELECT inst_id, instance_name, host_name, status, startup_time FROM gv$instance;

-- Database info
SELECT name, db_unique_name, open_mode, log_mode, force_logging, database_role FROM v$database;

-- Database size
SELECT ROUND(SUM(bytes)/1024/1024/1024, 2) AS "DB Size (GB)" FROM dba_data_files;
```

## 📊 Performance & Wait Events

```sql
-- Top 10 wait events RIGHT NOW
SELECT event, total_waits, time_waited_micro/1000000 AS secs FROM v$system_event 
WHERE wait_class != 'Idle' ORDER BY time_waited_micro DESC FETCH FIRST 10 ROWS ONLY;

-- Active sessions (who's doing what)
SELECT sid, serial#, username, sql_id, event, wait_class, seconds_in_wait
FROM v$session WHERE status = 'ACTIVE' AND username IS NOT NULL;

-- Top SQL by elapsed time
SELECT sql_id, elapsed_time/1000000 AS secs, executions, sql_text
FROM v$sql ORDER BY elapsed_time DESC FETCH FIRST 10 ROWS ONLY;
```

## 💾 ASM & Storage

```sql
-- ASM disk group usage
SELECT name, state, type, total_mb, free_mb, 
       ROUND((1 - free_mb/total_mb)*100, 1) AS "Used%" FROM v$asm_diskgroup;

-- Tablespace usage
SELECT tablespace_name, ROUND(used_space*8/1024, 1) AS "Used MB",
       ROUND(tablespace_size*8/1024, 1) AS "Total MB",
       ROUND(used_percent, 1) AS "Used%"
FROM dba_tablespace_usage_metrics ORDER BY used_percent DESC;
```

## 🔄 Data Guard Monitoring

```sql
-- Standby lag
SELECT name, value, datum_time FROM v$dataguard_stats WHERE name LIKE '%lag%';

-- Archive gap check
SELECT * FROM v$archive_gap;

-- Applied archivelog sequences
SELECT thread#, MAX(sequence#) AS last_applied FROM v$archived_log 
WHERE applied='YES' GROUP BY thread#;
```

## 🛡️ RMAN Quick Reference

```bash
# Check backup status
rman target / <<< "LIST BACKUP SUMMARY;"

# Validate backups
rman target / <<< "RESTORE DATABASE VALIDATE;"

# Show RMAN configuration
rman target / <<< "SHOW ALL;"

# Crosscheck and clean
rman target / <<< "CROSSCHECK BACKUP; DELETE NOPROMPT EXPIRED BACKUP;"
```

## ⚙️ Cluster & RAC Commands (srvctl)

```bash
# Database status
srvctl status database -d RACDB
srvctl config database -d RACDB

# Start/Stop
srvctl stop database -d RACDB
srvctl start database -d RACDB
srvctl stop instance -d RACDB -i RACDB1

# Listener
srvctl status listener
srvctl status scan
srvctl status scan_listener

# ASM
srvctl status asm
asmcmd lsdg

# Cluster
crsctl stat res -t
crsctl check crs
olsnodes -n
```

## 🔧 Patching Commands

```bash
# Check installed patches
$ORACLE_HOME/OPatch/opatch lspatches

# Check OPatch version
$ORACLE_HOME/OPatch/opatch version

# Apply patch (Grid - as root)
$ORACLE_HOME/OPatch/opatchauto apply /path/to/patch -oh $ORACLE_HOME

# Apply patch (DB - as oracle)
cd /path/to/patch && $ORACLE_HOME/OPatch/opatch apply

# Apply SQL changes after patching
$ORACLE_HOME/OPatch/datapatch -verbose

# Verify in database
SELECT patch_id, action, status FROM dba_registry_sqlpatch ORDER BY action_time DESC;
```
