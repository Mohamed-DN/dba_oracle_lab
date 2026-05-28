# Cheat Sheet SQL Assessment & Tuning — Enterprise Completo 📊

> [!NOTE]
> **DOCUMENTI CORRELATI:**
> - **AWR/ASH/ADDM**: [GUIDA_AWR_ASH_ADDM.md](../../02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md)
> - **SQL Plan Management**: [GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md](../../02_core_dba/03_performance_and_diagnostics/GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md)
> - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](./CS_MASTER_DBA.md)

---

## 1. Identificare le Top SQL

### 1.1 Top SQL per Elapsed Time
```sql
SELECT sql_id, plan_hash_value,
       ROUND(elapsed_time/1e6, 2) AS elapsed_sec,
       executions,
       ROUND(elapsed_time/GREATEST(executions,1)/1e6, 4) AS sec_per_exec,
       ROUND(buffer_gets/GREATEST(executions,1)) AS gets_per_exec,
       ROUND(disk_reads/GREATEST(executions,1)) AS reads_per_exec,
       SUBSTR(sql_text, 1, 80) AS sql_preview
FROM V$SQL
WHERE elapsed_time > 0
ORDER BY elapsed_time DESC
FETCH FIRST 20 ROWS ONLY;
```

### 1.2 Top SQL per Buffer Gets (Logical I/O)
```sql
SELECT sql_id, plan_hash_value, executions,
       buffer_gets,
       ROUND(buffer_gets/GREATEST(executions,1)) AS gets_per_exec,
       SUBSTR(sql_text, 1, 80)
FROM V$SQL
WHERE buffer_gets > 100000
ORDER BY buffer_gets DESC
FETCH FIRST 20 ROWS ONLY;
```

### 1.3 Top SQL per CPU
```sql
SELECT sql_id, plan_hash_value, executions,
       ROUND(cpu_time/1e6, 2) AS cpu_sec,
       ROUND(cpu_time/GREATEST(executions,1)/1e6, 4) AS cpu_per_exec
FROM V$SQL
ORDER BY cpu_time DESC
FETCH FIRST 20 ROWS ONLY;
```

### 1.4 Top SQL per Disk Reads (Physical I/O)
```sql
SELECT sql_id, plan_hash_value, executions,
       disk_reads,
       ROUND(disk_reads/GREATEST(executions,1)) AS reads_per_exec
FROM V$SQL
WHERE disk_reads > 10000
ORDER BY disk_reads DESC
FETCH FIRST 15 ROWS ONLY;
```

---

## 2. Analisi Piano di Esecuzione

### 2.1 Piano corrente dalla Shared Pool
```sql
-- Piano dalla V$SQL
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('sql_id_here', NULL, 'ALLSTATS LAST'));

-- Tutti i piani per uno sql_id (child cursors)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('sql_id_here', NULL, 'ALL'));

-- Piano con statistiche di runtime
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('sql_id_here', NULL, 'ALLSTATS LAST ADVANCED'));
```

### 2.2 Piano da AWR (storico)
```sql
-- Piano da AWR (necessita Diagnostics Pack)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_AWR('sql_id_here'));

-- Piano specifico da AWR
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_AWR('sql_id_here', plan_hash_value => 123456789));
```

### 2.3 EXPLAIN PLAN
```sql
EXPLAIN PLAN FOR
SELECT * FROM orders WHERE order_date > SYSDATE - 30;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'ALL'));
```

### 2.4 Interpretazione rapida
```text
Operazioni da evitare nel piano:
  TABLE ACCESS FULL     → su tabelle grandi: serve un indice?
  NESTED LOOPS          → su join con molte righe: meglio HASH JOIN?
  SORT ORDER BY         → senza indice: serve un indice ordinato?
  CARTESIAN JOIN        → quasi sempre un errore: manca una condizione di join
  FILTER                → con subquery correlata: riscrivere come JOIN

Operazioni buone:
  INDEX RANGE SCAN      → accesso selettivo via indice
  INDEX UNIQUE SCAN     → accesso puntuale (PK/UK)
  HASH JOIN             → efficiente per join grandi
  PARTITION RANGE SCAN  → pruning delle partizioni
```

---

## 3. SQL Tuning Advisor

```sql
-- Creare un task di tuning
DECLARE
  l_task VARCHAR2(100);
BEGIN
  l_task := DBMS_SQLTUNE.CREATE_TUNING_TASK(
    sql_id      => 'sql_id_here',
    scope       => DBMS_SQLTUNE.SCOPE_COMPREHENSIVE,
    time_limit  => 300,
    task_name   => 'tune_sql_xyz'
  );
END;
/

-- Eseguire il task
EXEC DBMS_SQLTUNE.EXECUTE_TUNING_TASK('tune_sql_xyz');

-- Leggere i risultati
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('tune_sql_xyz') FROM DUAL;

-- Accettare un SQL Profile consigliato
EXEC DBMS_SQLTUNE.ACCEPT_SQL_PROFILE(task_name => 'tune_sql_xyz', replace => TRUE);

-- Drop del task
EXEC DBMS_SQLTUNE.DROP_TUNING_TASK('tune_sql_xyz');
```

---

## 4. SQL Monitor (Real-Time SQL Monitoring)

```sql
-- Query monitorate in tempo reale (solo con Diagnostics Pack)
SELECT sql_id, status, sql_plan_hash_value,
       elapsed_time/1e6 AS elapsed_sec,
       cpu_time/1e6 AS cpu_sec,
       buffer_gets, disk_reads,
       SUBSTR(sql_text, 1, 80)
FROM V$SQL_MONITOR
WHERE status = 'EXECUTING'
ORDER BY elapsed_time DESC;

-- Report dettagliato di una query specifica
SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(
  sql_id       => 'sql_id_here',
  type         => 'TEXT',
  report_level => 'ALL'
) FROM DUAL;

-- Report in HTML (più leggibile)
SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(
  sql_id => 'sql_id_here',
  type   => 'HTML'
) FROM DUAL;
```

---

## 5. Statistiche e Bind Variables

### 5.1 Gestione Statistiche dell'Optimizer
```sql
-- Raccolta statistiche su una tabella
EXEC DBMS_STATS.GATHER_TABLE_STATS('SCHEMA', 'TABLE_NAME', CASCADE => TRUE, ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE);

-- Raccolta statistiche su uno schema
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('SCHEMA', CASCADE => TRUE);

-- Verificare la freschezza delle statistiche
SELECT table_name, num_rows, last_analyzed,
       ROUND(SYSDATE - last_analyzed, 1) AS days_old,
       stale_stats
FROM DBA_TAB_STATISTICS
WHERE owner = 'SCHEMA'
ORDER BY last_analyzed NULLS FIRST;

-- Statistiche bloccate (no auto-raccolta)
EXEC DBMS_STATS.LOCK_TABLE_STATS('SCHEMA', 'TABLE_NAME');
EXEC DBMS_STATS.UNLOCK_TABLE_STATS('SCHEMA', 'TABLE_NAME');

-- Restore statistiche precedenti (rollback)
EXEC DBMS_STATS.RESTORE_TABLE_STATS('SCHEMA', 'TABLE_NAME', SYSTIMESTAMP - INTERVAL '1' DAY);
```

### 5.2 Bind Variable Peeking
```sql
-- Verificare i bind values usati per un sql_id
SELECT name, datatype_string, value_string
FROM V$SQL_BIND_CAPTURE
WHERE sql_id = 'sql_id_here'
ORDER BY position;

-- Adaptive Cursor Sharing (ACS) - verifica se attivo
SELECT sql_id, child_number, is_bind_sensitive, is_bind_aware, is_shareable
FROM V$SQL
WHERE sql_id = 'sql_id_here';
```

---

## 6. AWR / ASH Quick Queries

### 6.1 AWR Snapshots
```sql
-- Lista snapshot recenti
SELECT snap_id, begin_interval_time, end_interval_time
FROM DBA_HIST_SNAPSHOT
ORDER BY snap_id DESC
FETCH FIRST 20 ROWS ONLY;

-- Generare AWR Report (HTML)
@?/rdbms/admin/awrrpt.sql

-- Generare AWR Diff Report (confronto 2 periodi)
@?/rdbms/admin/awrddrpt.sql

-- Creare snapshot manuale
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT;
```

### 6.2 ASH (Active Session History)
```sql
-- Top Wait Events nell'ultima ora
SELECT event, COUNT(*) AS samples,
       ROUND(COUNT(*)*100/SUM(COUNT(*)) OVER(), 1) AS pct
FROM V$ACTIVE_SESSION_HISTORY
WHERE sample_time > SYSDATE - 1/24
  AND event IS NOT NULL
GROUP BY event
ORDER BY samples DESC
FETCH FIRST 10 ROWS ONLY;

-- Top SQL nell'ultima ora
SELECT sql_id, COUNT(*) AS samples,
       ROUND(COUNT(*)*100/SUM(COUNT(*)) OVER(), 1) AS pct
FROM V$ACTIVE_SESSION_HISTORY
WHERE sample_time > SYSDATE - 1/24
  AND sql_id IS NOT NULL
GROUP BY sql_id
ORDER BY samples DESC
FETCH FIRST 10 ROWS ONLY;

-- Sessioni bloccanti (in attesa di lock)
SELECT blocking_session, event, sql_id, COUNT(*)
FROM V$ACTIVE_SESSION_HISTORY
WHERE sample_time > SYSDATE - 1/24
  AND blocking_session IS NOT NULL
GROUP BY blocking_session, event, sql_id
ORDER BY COUNT(*) DESC;

-- ASH Report
@?/rdbms/admin/ashrpt.sql
```

### 6.3 ADDM (Automatic Database Diagnostic Monitor)
```sql
-- Generare ADDM report
@?/rdbms/admin/addmrpt.sql

-- Creare un task ADDM manuale
DECLARE
  l_task VARCHAR2(100);
BEGIN
  DBMS_ADVISOR.CREATE_TASK('ADDM', l_task);
  DBMS_ADVISOR.SET_TASK_PARAMETER(l_task, 'START_SNAPSHOT', 100);
  DBMS_ADVISOR.SET_TASK_PARAMETER(l_task, 'END_SNAPSHOT', 110);
  DBMS_ADVISOR.EXECUTE_TASK(l_task);
END;
/
```

---

## 7. Indici — Diagnostica e Ottimizzazione

```sql
-- Indici inutilizzati (monitoring attivo)
ALTER INDEX schema.idx_name MONITORING USAGE;
-- Dopo qualche giorno:
SELECT index_name, table_name, monitoring, used, start_monitoring
FROM V$OBJECT_USAGE;

-- Indici invisibili (test senza impatto)
ALTER INDEX schema.idx_name INVISIBLE;
ALTER INDEX schema.idx_name VISIBLE;

-- Ricostruire indice frammentato
ALTER INDEX schema.idx_name REBUILD ONLINE;
ALTER INDEX schema.idx_name REBUILD ONLINE PARALLEL 4;

-- Statistiche sugli indici
SELECT index_name, blevel, leaf_blocks, distinct_keys,
       clustering_factor, num_rows, last_analyzed
FROM DBA_INDEXES
WHERE owner = 'SCHEMA' AND table_name = 'TABLE_NAME';
```

---

## 8. Quick Reference

```text
+---------------------------+----------------------------------------------+
| OPERAZIONE                | COMANDO                                      |
+---------------------------+----------------------------------------------+
| Top SQL per elapsed       | V$SQL ORDER BY elapsed_time DESC             |
| Piano esecuzione          | DBMS_XPLAN.DISPLAY_CURSOR('sql_id')          |
| Piano da AWR              | DBMS_XPLAN.DISPLAY_AWR('sql_id')             |
| SQL Tuning Advisor        | DBMS_SQLTUNE.CREATE_TUNING_TASK              |
| SQL Monitor real-time     | DBMS_SQLTUNE.REPORT_SQL_MONITOR              |
| Raccolta statistiche      | DBMS_STATS.GATHER_TABLE_STATS                |
| AWR Report                | @?/rdbms/admin/awrrpt.sql                    |
| ASH Report                | @?/rdbms/admin/ashrpt.sql                    |
| ADDM Report               | @?/rdbms/admin/addmrpt.sql                   |
| Snapshot manuale           | DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT     |
| Bind variables             | V$SQL_BIND_CAPTURE                           |
+---------------------------+----------------------------------------------+
```
