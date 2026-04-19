# Guida AWR, ASH, ADDM — Comandi Avanzati e Automazione

> Questa guida è il **compagno pratico** della [GUIDA_TROUBLESHOOTING_COMPLETO.md](./GUIDA_TROUBLESHOOTING_COMPLETO.md). Quella insegna il METODO e la teoria. Questa contiene tutti i COMANDI avanzati, gli script automatizzati, e le tecniche di tuning SQL.

---

## 1. Configurazione AWR — Best Practice

```sql
-- ═══════════════════════════════════════════════════════════════════
-- Configurazione consigliata per produzione/lab
-- ═══════════════════════════════════════════════════════════════════
BEGIN
    DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(
        interval  => 30,      -- snapshot ogni 30 min (default: 60)
        retention => 43200    -- mantieni 30 giorni (default: 8)
    );
END;
/

-- Verifica
SELECT
    EXTRACT(MINUTE FROM snap_interval) AS snap_min,
    EXTRACT(DAY FROM retention) AS retention_days
FROM dba_hist_wr_control;
```

### 1.1 Baselines: Congelare un Periodo "Buono"

```sql
-- Una baseline salva un periodo di performance "buona" per confronti futuri.
-- I suoi snapshot NON vengono cancellati dalla retention automatica.

-- Crea una baseline del periodo "tutto ok" (es. settimana normale)
BEGIN
    DBMS_WORKLOAD_REPOSITORY.CREATE_BASELINE(
        start_snap_id => 1000,     -- primo snapshot del periodo buono
        end_snap_id   => 1048,     -- ultimo snapshot del periodo buono
        baseline_name => 'SETTIMANA_NORMALE_APR2026'
    );
END;
/

-- Lista baselines
SELECT baseline_name, start_snap_id, end_snap_id,
       start_snap_time, end_snap_time
FROM dba_hist_baseline;

-- Confronta il periodo corrente con la baseline
@?/rdbms/admin/awrddrpt.sql
-- Seleziona la baseline come periodo 1 e il periodo attuale come periodo 2
```

---

## 2. Report AWR — Generazione Automatizzata

### 2.1 Generare AWR via PL/SQL (senza interazione)

```sql
-- Genera un report AWR HTML tra 2 snapshot specifici
-- Utile per automazione (script cron che genera report ogni giorno)

SPOOL /tmp/awr_report.html

SELECT output FROM TABLE(
    DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(
        l_dbid     => (SELECT dbid FROM v$database),
        l_inst_num => 1,          -- istanza 1 (per RAC)
        l_bid      => &begin_snap,
        l_eid      => &end_snap
    )
);

SPOOL OFF
```

### 2.2 AWR Global Report per RAC (tutti i nodi)

```sql
-- AWR Global = aggregato su TUTTI i nodi RAC
SPOOL /tmp/awr_global_report.html

SELECT output FROM TABLE(
    DBMS_WORKLOAD_REPOSITORY.AWR_GLOBAL_REPORT_HTML(
        l_dbid     => (SELECT dbid FROM v$database),
        l_inst_num => '',         -- vuoto = tutti i nodi
        l_bid      => &begin_snap,
        l_eid      => &end_snap
    )
);

SPOOL OFF
```

---

## 3. ASH — Query Avanzate

### 3.1 Heat Map: Minuto per Minuto

```sql
-- Visualizza il carico del database minuto per minuto nell'ultima ora
-- con una "barra grafica" per capire a colpo d'occhio i picchi

SELECT
    TO_CHAR(sample_time, 'HH24:MI') AS minuto,
    COUNT(*) AS attive,
    SUM(CASE WHEN session_state = 'ON CPU' THEN 1 ELSE 0 END) AS cpu,
    SUM(CASE WHEN wait_class = 'User I/O' THEN 1 ELSE 0 END) AS io,
    SUM(CASE WHEN wait_class = 'Concurrency' THEN 1 ELSE 0 END) AS lock,
    SUM(CASE WHEN wait_class = 'Cluster' THEN 1 ELSE 0 END) AS rac,
    '|' || RPAD('C', LEAST(SUM(CASE WHEN session_state='ON CPU' THEN 1 ELSE 0 END), 30), 'C')
        || RPAD('I', LEAST(SUM(CASE WHEN wait_class='User I/O' THEN 1 ELSE 0 END), 30), 'I')
        || RPAD('L', LEAST(SUM(CASE WHEN wait_class='Concurrency' THEN 1 ELSE 0 END), 30), 'L')
    AS grafico
FROM v$active_session_history
WHERE sample_time > SYSDATE - INTERVAL '1' HOUR
GROUP BY TO_CHAR(sample_time, 'HH24:MI')
ORDER BY minuto;

-- OUTPUT:
-- MINUTO ATTIVE CPU IO LOCK GRAFICO
-- 14:00  4      2   1  1    |CCILLL
-- 14:01  5      3   2  0    |CCCII
-- 14:02  35     3   30 2    |CCCIIIIIIIIIIIIIIIIIIIIIIIIIIIILL  ← PICCO!
-- 14:03  38     2   33 3    |CCIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIILLL
-- 14:04  6      4   2  0    |CCCCII  ← Tornato normale
```

### 3.2 Top SQL per Periodo Storico (DBA_HIST_ACTIVE_SESS_HISTORY)

```sql
-- ASH storico (su disco, persiste dopo lo svuotamento della SGA)
-- Usa DBA_HIST_ACTIVE_SESS_HISTORY per analisi di ieri/settimana scorsa

SELECT
    sql_id,
    COUNT(*) AS campioni,
    ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER(), 1) AS pct_dbtime,
    MAX(event) AS wait_predominante
FROM dba_hist_active_sess_history
WHERE sample_time BETWEEN
    TO_TIMESTAMP('2026-04-06 14:00', 'YYYY-MM-DD HH24:MI') AND
    TO_TIMESTAMP('2026-04-06 16:00', 'YYYY-MM-DD HH24:MI')
  AND session_type = 'FOREGROUND'
GROUP BY sql_id
ORDER BY campioni DESC
FETCH FIRST 10 ROWS ONLY;
```

### 3.3 Chi Bloccava Chi? (Analisi Storica)

```sql
-- Ricostruisci le catene di blocking dalla storia ASH
SELECT
    TO_CHAR(sample_time, 'HH24:MI:SS') AS quando,
    session_id AS vittima,
    blocking_session AS bloccante,
    event,
    sql_id
FROM dba_hist_active_sess_history
WHERE blocking_session IS NOT NULL
  AND sample_time BETWEEN
    TO_TIMESTAMP('2026-04-06 14:00', 'YYYY-MM-DD HH24:MI') AND
    TO_TIMESTAMP('2026-04-06 14:30', 'YYYY-MM-DD HH24:MI')
ORDER BY sample_time;
```

---

## 4. ADDM — Automazione

### 4.1 Creare un Task ADDM Manuale

```sql
DECLARE
    l_task  VARCHAR2(100) := 'ADDM_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MI');
    l_id    NUMBER;
BEGIN
    DBMS_ADVISOR.CREATE_TASK('ADDM', l_id, l_task);
    DBMS_ADVISOR.SET_TASK_PARAMETER(l_task, 'START_SNAPSHOT', &begin_snap);
    DBMS_ADVISOR.SET_TASK_PARAMETER(l_task, 'END_SNAPSHOT',   &end_snap);
    -- Per RAC, analizza TUTTI i nodi:
    DBMS_ADVISOR.SET_TASK_PARAMETER(l_task, 'INSTANCE', 0);  -- 0 = database mode
    DBMS_ADVISOR.EXECUTE_TASK(l_task);
    DBMS_OUTPUT.PUT_LINE('Task creato: ' || l_task);
END;
/

-- Leggi il report
SELECT DBMS_ADVISOR.GET_TASK_REPORT('&task_name') FROM dual;
```

### 4.2 Lista dei Findings ADDM

```sql
-- Tutti i finding ADDM con il beneficio stimato
SELECT
    task_name,
    type,
    message,
    ROUND(benefit_pct, 1) AS beneficio_pct
FROM dba_advisor_findings f
JOIN dba_advisor_tasks t USING (task_id)
WHERE t.advisor_name = 'ADDM'
  AND t.status = 'COMPLETED'
ORDER BY t.execution_end DESC, benefit_pct DESC
FETCH FIRST 20 ROWS ONLY;
```

---

## 5. SQL Tuning Avanzato

### 5.1 SQL Monitor (query in esecuzione in tempo reale)

```sql
-- SQL Monitor cattura automaticamente le query che:
-- - Durano più di 5 secondi
-- - Usano parallelismo
-- - Sono monitorate manualmente con MONITOR hint

-- Lista query monitorate
SELECT
    sql_id,
    status,
    username,
    elapsed_time/1000000 AS secs,
    cpu_time/1000000 AS cpu_secs,
    buffer_gets,
    disk_reads,
    sql_text
FROM v$sql_monitor
WHERE status = 'EXECUTING'
ORDER BY elapsed_time DESC;

-- Report dettagliato di una query (formato HTML)
SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(
    sql_id       => '&sql_id',
    report_level => 'ALL',
    type         => 'HTML'
) FROM dual;
```

### 5.2 SQL Plan Management (SPM) — Congelare un Piano Buono

```sql
-- Se hai trovato un piano buono e vuoi che l'optimizer lo usi SEMPRE:

-- 1. Carica il piano dalla cache SQL
DECLARE
    l_plans PLS_INTEGER;
BEGIN
    l_plans := DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(
        sql_id => '&sql_id',
        plan_hash_value => &good_plan_hash
    );
    DBMS_OUTPUT.PUT_LINE('Piani caricati: ' || l_plans);
END;
/

-- 2. Verifica
SELECT sql_handle, plan_name, enabled, accepted, fixed
FROM dba_sql_plan_baselines
ORDER BY created DESC FETCH FIRST 5 ROWS ONLY;

-- 3. Fissa il piano (impedisce all'optimizer di cambiarle)
DECLARE
    l_result PLS_INTEGER;
BEGIN
    l_result := DBMS_SPM.ALTER_SQL_PLAN_BASELINE(
        sql_handle      => '&sql_handle',
        plan_name       => '&plan_name',
        attribute_name  => 'FIXED',
        attribute_value => 'YES'
    );
END;
/
```

### 5.3 SQL Quarantine (19c) — Bloccare Query Pericolose

```sql
-- Se una query impazzisce e consuma troppe risorse,
-- puoi metterla in "quarantena" = Oracle la blocca automaticamente.

BEGIN
    DBMS_SQLQ.CREATE_QUARANTINE_BY_SQL_ID(
        sql_id         => '&sql_id',
        plan_hash_value => &bad_plan_hash,
        elapsed_time   => 300    -- blocca se dura più di 300 secondi
    );
END;
/

-- Lista query in quarantena
SELECT name, sql_text, elapsed_time, enabled
FROM dba_sql_quarantine;
```

---

## 6. Script di Report Automatico

```bash
#!/bin/bash
# /home/oracle/scripts/generate_awr_report.sh
# Genera automaticamente il report AWR dell'ultimo periodo

source /home/oracle/.db_env
LOG_DIR=/home/oracle/scripts/reports
mkdir -p $LOG_DIR

REPORT_FILE=$LOG_DIR/awr_$(date +%Y%m%d_%H%M).html

sqlplus -s / as sysdba <<'SQL' > $REPORT_FILE
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF LINESIZE 32767 TRIMSPOOL ON

-- Trova gli ultimi 2 snapshot
COLUMN bid NEW_VALUE begin_snap
COLUMN eid NEW_VALUE end_snap
SELECT snap_id AS bid FROM (
    SELECT snap_id FROM dba_hist_snapshot ORDER BY snap_id DESC
    FETCH FIRST 2 ROWS ONLY
) WHERE ROWNUM = 1;
SELECT snap_id AS eid FROM (
    SELECT snap_id FROM dba_hist_snapshot ORDER BY snap_id DESC
) WHERE ROWNUM = 1;

-- Genera il report
SELECT output FROM TABLE(
    DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(
        (SELECT dbid FROM v$database), 1, &begin_snap, &end_snap
    )
);
SQL

echo "Report generato: $REPORT_FILE"
```

---

## 7. Fonti Oracle Ufficiali

- **AWR Reference**: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/gathering-database-statistics.html
- **ASH**: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/active-session-history.html
- **ADDM**: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/automatic-database-diagnostic-monitor.html
- **SQL Tuning**: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/
- **SQL Monitor**: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/monitoring-database-operations.html
- **SQL Plan Management**: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/managing-sql-plan-baselines.html
- **SQL Quarantine**: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/managing-sql-plan-baselines.html#GUID-503E3F48-E949-43C2-9D97-E03B30C8D83D
