# 11 — Review AWR Settimanale

> ⏱️ Tempo: 30-60 minuti | 📅 Frequenza: Ogni venerdì | 👤 Chi: DBA
> **Obiettivo**: Identificare trend, regressioni e aree di miglioramento prima che diventino incidenti.

---

## Step 1: Genera AWR Report (HTML)

```sql
sqlplus / as sysdba

-- Trova gli snapshot degli ultimi 7 giorni
SELECT snap_id,
       TO_CHAR(begin_interval_time, 'DD-MON HH24:MI') AS snap_time,
       ROUND(EXTRACT(EPOCH FROM end_interval_time - begin_interval_time)/60) AS interval_min
FROM dba_hist_snapshot
WHERE begin_interval_time > SYSDATE - 7
ORDER BY snap_id;

-- Genera AWR HTML (interattivo)
@$ORACLE_HOME/rdbms/admin/awrrpt.sql
-- Scegli: HTML, dbid, inizio settimana, fine settimana

-- Per RAC Global
@$ORACLE_HOME/rdbms/admin/awrgrpt.sql
```

```bash
# Alternativa non-interattiva (script)
sqlplus -S / as sysdba <<'EOF'
DEFINE snap_begin = &begin_snap_id
DEFINE snap_end   = &end_snap_id
DEFINE report_type = 'html'
DEFINE report_name = '/tmp/awr_weekly_report.html'
DEFINE dbid = &dbid
DEFINE inst_num = 0

@$ORACLE_HOME/rdbms/admin/awrrpti.sql
EOF
```

## Step 2: Sezioni Chiave del Report AWR

### 2A. Load Profile — Il "cruscotto"

```sql
-- Metriche chiave da confrontare settimana per settimana
SELECT stat_name,
       ROUND(value, 2) AS per_second
FROM dba_hist_sysstat s
JOIN dba_hist_snapshot sn ON s.snap_id = sn.snap_id
WHERE sn.begin_interval_time > SYSDATE - 7
  AND stat_name IN (
      'redo size',           -- redo generato
      'db block changes',    -- blocchi modificati
      'physical reads',      -- letture disco
      'execute count',       -- SQL eseguiti
      'user commits',        -- transazioni
      'user calls'           -- chiamate utente
  )
ORDER BY stat_name, sn.snap_id;
```

### 2B. Top 5 Foreground Wait Events

```sql
-- Evoluzione top wait events nell'ultima settimana
SELECT event_name, wait_class,
       ROUND(SUM(time_waited_micro)/1000000, 1) AS total_sec,
       SUM(total_waits) AS total_waits,
       ROUND(AVG(time_waited_micro/NULLIF(total_waits,0))/1000, 2) AS avg_wait_ms
FROM dba_hist_system_event
WHERE snap_id IN (
    SELECT snap_id FROM dba_hist_snapshot
    WHERE begin_interval_time > SYSDATE - 7
)
AND wait_class != 'Idle'
GROUP BY event_name, wait_class
ORDER BY total_sec DESC
FETCH FIRST 10 ROWS ONLY;
```

### 2C. Top SQL per Elapsed Time

```sql
-- Top 10 SQL della settimana
SELECT sql_id,
       ROUND(SUM(elapsed_time_delta)/1000000, 1) AS elapsed_sec,
       ROUND(SUM(cpu_time_delta)/1000000, 1) AS cpu_sec,
       SUM(executions_delta) AS execs,
       ROUND(SUM(buffer_gets_delta)/NULLIF(SUM(executions_delta),0)) AS gets_per_exec,
       ROUND(SUM(elapsed_time_delta)/1000000/NULLIF(SUM(executions_delta),0), 3) AS sec_per_exec
FROM dba_hist_sqlstat
WHERE snap_id IN (
    SELECT snap_id FROM dba_hist_snapshot
    WHERE begin_interval_time > SYSDATE - 7
)
GROUP BY sql_id
ORDER BY elapsed_sec DESC
FETCH FIRST 10 ROWS ONLY;
```

### 2D. Regressioni di Piano (SQL con cambio di performance)

```sql
-- SQL che hanno cambiato piano questa settimana
SELECT sql_id, plan_hash_value,
       MIN(TO_CHAR(sn.begin_interval_time, 'DD-MON')) AS first_seen,
       MAX(TO_CHAR(sn.begin_interval_time, 'DD-MON')) AS last_seen,
       ROUND(AVG(elapsed_time_delta/NULLIF(executions_delta,0))/1000, 1) AS avg_ms
FROM dba_hist_sqlstat s
JOIN dba_hist_snapshot sn ON s.snap_id = sn.snap_id AND s.dbid = sn.dbid
WHERE sn.begin_interval_time > SYSDATE - 7
  AND executions_delta > 0
GROUP BY sql_id, plan_hash_value
HAVING COUNT(DISTINCT plan_hash_value) > 1
ORDER BY avg_ms DESC;
```

## Step 3: Storage Trend

```sql
-- Crescita tablespace nell'ultima settimana
SELECT ts.tsname AS tablespace_name,
       ROUND(MIN(ts.tablespace_usedsize * 8192)/1024/1024) AS start_mb,
       ROUND(MAX(ts.tablespace_usedsize * 8192)/1024/1024) AS end_mb,
       ROUND(MAX(ts.tablespace_usedsize * 8192)/1024/1024) -
       ROUND(MIN(ts.tablespace_usedsize * 8192)/1024/1024) AS growth_mb
FROM dba_hist_tbspc_space_usage ts
JOIN v$tablespace t ON ts.tablespace_id = t.ts#
WHERE ts.snap_id IN (
    SELECT snap_id FROM dba_hist_snapshot
    WHERE begin_interval_time > SYSDATE - 7
)
GROUP BY ts.tsname
HAVING MAX(ts.tablespace_usedsize) - MIN(ts.tablespace_usedsize) > 0
ORDER BY growth_mb DESC;
```

## Step 4: ADDM — Raccomandazioni Automatiche

```sql
-- Genera ADDM report tra due snapshot
@$ORACLE_HOME/rdbms/admin/addmrpt.sql

-- Oppure programmaticamente
DECLARE
    l_task VARCHAR2(64) := 'ADDM_WEEKLY_' || TO_CHAR(SYSDATE, 'YYYYMMDD');
BEGIN
    DBMS_ADVISOR.CREATE_TASK('ADDM', l_task);
    DBMS_ADVISOR.SET_TASK_PARAMETER(l_task, 'START_SNAPSHOT', &begin_snap);
    DBMS_ADVISOR.SET_TASK_PARAMETER(l_task, 'END_SNAPSHOT', &end_snap);
    DBMS_ADVISOR.EXECUTE_TASK(l_task);
END;
/

SET LONG 100000
SELECT DBMS_ADVISOR.GET_TASK_REPORT(
    'ADDM_WEEKLY_' || TO_CHAR(SYSDATE, 'YYYYMMDD')
) AS report FROM dual;
```

## Step 5: Checklist Review

```
□ Load Profile stabile rispetto alla settimana precedente?
□ Top wait events invariati? Nuovi eventi comparsi?
□ Top SQL: qualche nuova query pesante?
□ Regressioni di piano SQL?
□ Tablespace: crescita anomala?
□ ADDM findings: azioni raccomandate?
□ ASM: spazio sufficiente per le prossime settimane?
□ Backup: tutti riusciti nella settimana?
□ Data Guard: lag medio nella norma?
```

---

## ✅ Output della Review

Compila un breve report settimanale (anche solo 5 righe):

```
REVIEW AWR — Settimana del ________

STATO GENERALE: [ ] Stabile  [ ] Attenzione  [ ] Critico

ISSUE TROVATI:
1. ___________
2. ___________

AZIONI PIANIFICATE:
1. ___________

PROSSIMA REVIEW: ________
```
