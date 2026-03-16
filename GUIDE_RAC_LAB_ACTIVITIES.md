# 🔬 RAC Laboratory Activities — Practical Exercises

> **Prerequisite**: You have completed Steps 0-7 and your RAC lab is operational with:
> - 2 nodi RAC primary (rac1, rac2)
> - 2 standby RAC nodes (racstby1, racstby2) with Data Guard active
> - GoldenGate configurato e funzionante
> - RMAN backup configurato
>
> **Objective**: Practice Enterprise DBA skills using scripts from the collection `studio_ai/`.

---

## 🎯 Exercise 1: Complete Cluster Health Check (30 min)

> **Scenario**: You are the DBA on duty. First thing in the morning: Check that everything is in order.

### 1.1 Verifiche Clusterware (da root o grid)
```bash
# Stato CRS su tutti i nodi
crsctl check crs
crsctl stat res -t

# Verifiche OCR e Voting Disk
ocrcheck
crsctl query css votedisk
```

### 1.2 Verifiche Database (da oracle, sqlplus)
```sql
-- Connettiti al database
sqlplus / as sysdba

-- Stato istanze RAC
SELECT inst_id, instance_name, status, database_status FROM gv$instance;

-- Verifica alert log recente (ultimi errori)
SELECT originating_timestamp, message_text 
FROM v$diag_alert_ext 
WHERE originating_timestamp > SYSDATE - 1 
AND message_text LIKE '%ORA-%' ORDER BY 1 DESC;
```

### 1.3 ASM verification (from grid, sqlplus +ASM)
```sql
-- Connettiti ad ASM
sqlplus / as sysasm

-- Usa il nostro script o query diretta
SELECT NAME, STATE, TYPE, ROUND(TOTAL_MB/1024) "TOTAL_GB", 
       ROUND(FREE_MB/1024) "FREE_GB",
       ROUND((1-FREE_MB/TOTAL_MB)*100) "PCT_USED"
FROM v$asm_diskgroup ORDER BY name;
```

### 1.4 Data Guard verification
```sql
-- Connettiti al primary
dgmgrl sys/<password>
DGMGRL> show configuration;
DGMGRL> show database verbose 'RACDB';
DGMGRL> show database verbose 'RACDB_STBY';
```

### 1.5 GoldenGate Verification
```bash
# Connettiti a GGSCI
ggsci
GGSCI> info all
GGSCI> lag extract EXTMAIN
```

> 📋 **Script utili**: `studio_ai/03_monitoring_scripts/community_jkstill/ash_awr/aas.sql` per AAS baseline

---

## 🎯 Esercizio 2: Analisi Performance in Tempo Reale (45 min)

> **Scenario**: A user complains that the database is slow. You need to diagnose the problem.

### 2.1 Panoramica rapida
```sql
-- Chi sta facendo cosa adesso?
-- Usa: @studio_ai/03_monitoring_scripts/community_jkstill/locks_waits/active_status.sql

-- Versione manuale:
SELECT s.sid, s.serial#, s.username, s.program, s.status,
       s.event, s.wait_class, s.seconds_in_wait,
       ROUND(s.last_call_et/60) "MIN_ATTIVO"
FROM gv$session s
WHERE s.status = 'ACTIVE' AND s.username IS NOT NULL
ORDER BY s.last_call_et DESC;
```

### 2.2 Top SQL per consumo risorse
```sql
-- Usa: @studio_ai/03_monitoring_scripts/community_gwenshap/top-sql.sql
-- Oppure: @studio_ai/03_monitoring_scripts/community_jkstill/ash_awr/top10-sql-ash.sql

-- Versione manuale:
SELECT sql_id, plan_hash_value, 
       executions, ROUND(elapsed_time/1e6) "ELAPSED_SEC",
       ROUND(elapsed_time/GREATEST(executions,1)/1e6,3) "AVG_SEC",
       ROUND(buffer_gets/GREATEST(executions,1)) "AVG_LIO",
       SUBSTR(sql_text,1,80) "SQL_TEXT"
FROM gv$sql
WHERE elapsed_time > 0
ORDER BY elapsed_time DESC
FETCH FIRST 20 ROWS ONLY;
```

### 2.3 Waits — what is the database waiting for?
```sql
-- Usa: @studio_ai/03_monitoring_scripts/community_jkstill/locks_waits/sesswait.sql
-- O il leggendario: @studio_ai/03_monitoring_scripts/community_jkstill/locks_waits/snapper.sql

-- Top waits nel sistema:
SELECT wait_class, event, total_waits, 
       ROUND(time_waited_micro/1e6) "TIME_SEC"
FROM gv$system_event
WHERE wait_class NOT IN ('Idle')
ORDER BY time_waited_micro DESC
FETCH FIRST 15 ROWS ONLY;
```

### 2.4 Lock e sessioni bloccanti
```sql
-- Usa: @studio_ai/03_monitoring_scripts/community_gwenshap/locks.sql
-- O: @studio_ai/03_monitoring_scripts/community_jkstill/locks_waits/showlock2.sql

-- Chi blocca chi:
SELECT 
  s1.inst_id "BLOCKER_INST", s1.sid "BLOCKER_SID", s1.username "BLOCKER_USER",
  s2.inst_id "WAITER_INST", s2.sid "WAITER_SID", s2.username "WAITER_USER",
  s2.event "WAIT_EVENT", s2.seconds_in_wait "WAIT_SEC"
FROM gv$lock l1, gv$session s1, gv$lock l2, gv$session s2
WHERE s1.sid = l1.sid AND s2.sid = l2.sid AND l1.BLOCK > 0 
AND l2.request > 0 AND l1.id1 = l2.id1 AND l1.id2 = l2.id2;
```

---

## 🎯 Esercizio 3: Generare e Analizzare un Report AWR (30 min)

> **Scenario**: Vuoi confrontare le performance di oggi con quelle di ieri.

### 3.1 Generare uno snapshot manuale
```sql
-- Crea un AWR snapshot adesso
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT;
```

### 3.2 Generare un report AWR
```sql
-- Interattivo (ti chiede begin/end snap_id):
@$ORACLE_HOME/rdbms/admin/awrrpt.sql

-- Non-interattivo (usa lo script della community):
-- @studio_ai/03_monitoring_scripts/community_jkstill/ash_awr/awr_defined.sql
-- Per RAC: @studio_ai/03_monitoring_scripts/community_jkstill/ash_awr/awr_RAC_defined.sql
```

### 3.3 Analizzare il report
Look for these key sections in the report:
1. **Top 10 Foreground Events** — i principali colli di bottiglia
2. **SQL ordered by Elapsed Time** — slowest queries
3. **Instance Activity Stats** — statistiche globali
4. **Buffer Pool Statistics** — hit ratio (must be > 95%)

> 📋 **Vai oltre**: Genera un report ASH per un intervallo specifico: `@$ORACLE_HOME/rdbms/admin/ashrpt.sql`

---

## 🎯 Exercise 4: Tablespace and Storage Management (30 min)

> **Scenario**: You receive an alert that a tablespace is at 90%.

### 4.1 Controlla lo spazio
```sql
-- Usa: @studio_ai/03_monitoring_scripts/community_gwenshap/tablespace.sql
-- O: @studio_ai/03_monitoring_scripts/community_jkstill/storage/showtbs.sql

-- Versione manuale:
SELECT tablespace_name, 
       ROUND(used_space * 8192/1024/1024/1024, 1) "USED_GB",
       ROUND(tablespace_size * 8192/1024/1024/1024, 1) "SIZE_GB",
       ROUND(used_percent, 1) "PCT_USED"
FROM dba_tablespace_usage_metrics
ORDER BY used_percent DESC;
```

### 4.2 Controlla i datafile
```sql
-- Usa: @studio_ai/03_monitoring_scripts/community_jkstill/storage/showdf.sql

SELECT file_name, tablespace_name, 
       ROUND(bytes/1024/1024) "SIZE_MB",
       ROUND(maxbytes/1024/1024) "MAX_MB",
       autoextensible
FROM dba_data_files ORDER BY tablespace_name;
```

### 4.3 Estendi il tablespace
```sql
-- Metodo 1: Abilita autoextend
ALTER DATABASE DATAFILE '/u01/app/oracle/oradata/RACDB/users01.dbf' AUTOEXTEND ON NEXT 100M MAXSIZE 2G;

-- Metodo 2: Aggiungi un datafile
ALTER TABLESPACE USERS ADD DATAFILE '+DATA' SIZE 1G AUTOEXTEND ON NEXT 100M MAXSIZE 4G;
```

---

## 🎯 Esercizio 5: Monitoraggio I/O e Redo (20 min)

> **Scenario**: You want to understand the I/O load of the database.

```sql
-- I/O per tablespace
-- Usa: @studio_ai/03_monitoring_scripts/community_jkstill/io/ioweight.sql

-- Redo generation rate
-- Usa: @studio_ai/03_monitoring_scripts/community_jkstill/io/redo-rate.sql

-- Versione manuale:
SELECT ROUND(SUM(value)/1024/1024) "REDO_MB_TOTAL"
FROM gv$sysstat WHERE name = 'redo size';

-- Diagnosi logfile sync (fondamentale!)
-- Usa: @studio_ai/03_monitoring_scripts/community_jkstill/io/lfsdiag.sql
```

---

## 🎯 Exercise 6: Statistics Management (20 min)

> **Scenario**: Queries are slow. Maybe the statistics are old?

```sql
-- Tabelle con statistiche obsolete
-- Usa: @studio_ai/03_monitoring_scripts/community_jkstill/stats_optimizer/show-stale-stats.sql

-- Ultimo analyze:
SELECT owner, table_name, num_rows, last_analyzed, stale_stats
FROM dba_tab_statistics 
WHERE owner NOT IN ('SYS','SYSTEM','DBSNMP')
ORDER BY last_analyzed NULLS FIRST
FETCH FIRST 20 ROWS ONLY;

-- Rigenera statistiche su uno schema
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('HR', METHOD_OPT => 'FOR ALL COLUMNS SIZE AUTO');
```

---

## 🎯 Esercizio 7: Test Switchover Data Guard (30 min)

> **Scenario**: Simulazione manutenzione pianificata — switch al sito di DR.

```sql
-- 1. Verifica stato iniziale
dgmgrl sys/<password>
DGMGRL> show configuration;

-- 2. Switchover
DGMGRL> switchover to 'RACDB_STBY';

-- 3. Verifica
DGMGRL> show configuration;
-- Deve mostrare RACDB_STBY come PRIMARY e RACDB come STANDBY

-- 4. Verifica GoldenGate (deve continuare a funzionare!)
-- da shell: ggsci > info all

-- 5. Switchback (torna alla situazione originale)
DGMGRL> switchover to 'RACDB';
```

> 📋 **Approfondisci**: Vedi `studio_ai/02_dataguard/` for post-reboot recovery procedures and GAP verification

---

## 🎯 Esercizio 8: Simulazione di Problema e Kill Sessione (15 min)

> **Scenario**: A session is consuming too much CPU or is hung.

```sql
-- 1. Identifica la sessione problematica
-- Usa: @studio_ai/03_monitoring_scripts/community_gwenshap/check_and_kill.sql

-- 2. Trova il SID da killare
SELECT sid, serial#, username, program, status, event,
       ROUND(last_call_et/60) "MIN_IDLE"
FROM gv$session 
WHERE username IS NOT NULL AND status = 'ACTIVE'
ORDER BY last_call_et DESC;

-- 3. Kill (con grazia)
ALTER SYSTEM KILL SESSION 'SID,SERIAL#' IMMEDIATE;

-- 4. Se non muore, kill a livello OS
SELECT spid FROM v$process WHERE addr = (SELECT paddr FROM v$session WHERE sid = &SID);
-- Poi da OS: kill -9 <spid>
```

---

## 🎯 Esercizio 9: Monitoraggio RAC — Cache Fusion e Interconnect (20 min)

> **Scenario**: Verificare che la comunicazione tra i 2 nodi RAC sia efficiente.

```sql
-- Global Cache statistics (Cache Fusion)
SELECT inst_id, name, value 
FROM gv$sysstat 
WHERE name LIKE 'gc%' AND value > 0
ORDER BY inst_id, name;

-- Verifica latenza interconnect
SELECT inst_id, 
       ROUND(AVG(CASE WHEN name = 'gc cr block receive time' THEN value END) /
             GREATEST(AVG(CASE WHEN name = 'gc cr blocks received' THEN value END), 1) * 10, 2) "AVG_CR_LATENCY_MS"
FROM gv$sysstat 
WHERE name IN ('gc cr block receive time', 'gc cr blocks received')
GROUP BY inst_id;
-- Deve essere < 2ms. Se > 5ms → problema di interconnect!

-- Verifica traffico interconnect
SELECT inst_id, name, ROUND(value/1024/1024) "MB" 
FROM gv$sysstat 
WHERE name LIKE 'gc%bytes%' AND value > 0 
ORDER BY inst_id, name;
```

---

## 🎯 Esercizio 10: Test GoldenGate End-to-End (15 min)

> **Scenario**: Verificare che la replica GoldenGate funzioni correttamente.

```bash
# 1. Stato processi
ggsci
GGSCI> info all
GGSCI> stats EXTMAIN, LATEST
GGSCI> stats REPMAIN, LATEST

# 2. Verifica lag
GGSCI> lag extract EXTMAIN
GGSCI> lag replicat REPMAIN
```

```sql
-- 3. Test DML: INSERT sul primary
INSERT INTO hr.test_gg VALUES (SYSDATE, 'Test GoldenGate '||SYS_CONTEXT('USERENV','INSTANCE_NAME'));
COMMIT;

-- 4. Verifica sul target (dopo qualche secondo)
-- Connettiti al target DB
SELECT * FROM hr.test_gg ORDER BY 1 DESC FETCH FIRST 5 ROWS ONLY;
```

---

## 📚 Script Index for Activities

| Activity | Script Consigliati |
|---|---|
| Health Check mattutino | `aas.sql`, `tablespace.sql`, Data Guard `show configuration` |
| Performance lenta | `top-sql.sql`, `active_status.sql`, `snapper.sql`, `sesswait.sql` |
| Lock/Blocchi | `locks.sql` (gwenshap), `showlock2.sql` (jkstill), `ash_blocking.sql` |
| Analisi AWR | `awr_defined.sql`, `awr_RAC_defined.sql`, `awr-top-5-events.sql` |
| Spazio disco/tablespace | `tablespace.sql`, `showtbs.sql`, `showdf.sql`, `undo_space.sql` |
| Redo/I/O | `redo-rate.sql`, `lfsdiag.sql`, `ioweight.sql`, `avg_disk_times.sql` |
| ASM monitoring | `asm_diskgroups.sql`, `asm_disks.sql`, `asm_disk_errors.sql` |
| Statistiche obsolete | `show-stale-stats.sql`, `table-last-analyzed.sql` |
| SQL Tuning | `dbms-sqltune-sqlid.sql`, `find-expensive-sql.sql`, `explain_plan.sql` |

---

*Torna al [README principale](./README.md) — See also the [Study Plan](./DAILY_STUDY_PLAN.md)*
