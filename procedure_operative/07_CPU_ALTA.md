# 07 — CPU Alta

> ⏱️ Tempo: 10-30 minuti | 📅 Frequenza: Su alert | 👤 Chi: DBA on-call
> **Scenario tipico**: Alert "CPU al 95%!" oppure "il database è lentissimo"

---

## Step 1: È Oracle o è qualcos'altro?

```bash
# A livello OS: chi sta usando CPU?
top -bn1 | head -20

# Processi Oracle ordinati per CPU
ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | grep -i ora | head -10
```

> Se i processi Oracle NON sono in top → il problema NON è il database.

## Step 2: Average Active Sessions (il "battito cardiaco")

```sql
sqlplus / as sysdba

-- AAS = media sessioni attive. Se > numero CPU → saturazione
SELECT metric_name,
       ROUND(value, 1) AS current_value
FROM v$sysmetric
WHERE metric_name IN (
    'Average Active Sessions',
    'CPU Usage Per Sec',
    'Host CPU Utilization (%)',
    'Database CPU Time Ratio'
)
AND group_id = 2;
```

## Step 3: Chi Sta Consumando CPU?

```sql
-- Top 10 sessioni per CPU adesso
SELECT s.inst_id, s.sid, s.serial#, s.username, s.program,
       s.sql_id, s.event, s.status,
       s.last_call_et AS seconds_active
FROM gv$session s
WHERE s.status = 'ACTIVE'
  AND s.type = 'USER'
  AND s.event NOT LIKE 'SQL*Net%'
ORDER BY s.last_call_et DESC
FETCH FIRST 10 ROWS ONLY;
```

```sql
-- Top SQL per CPU (dalla shared pool)
SELECT sql_id,
       ROUND(cpu_time/1000000, 1) AS cpu_sec,
       executions,
       ROUND(cpu_time/1000000/NULLIF(executions,0), 2) AS cpu_per_exec,
       ROUND(elapsed_time/1000000, 1) AS elapsed_sec,
       SUBSTR(sql_text, 1, 80) AS sql_preview
FROM gv$sql
WHERE cpu_time > 0
ORDER BY cpu_time DESC
FETCH FIRST 10 ROWS ONLY;
```

## Step 4: Analisi ASH (chi stava usando CPU?)

```sql
-- Top SQL per CPU nell'ultima ora
SELECT sql_id, sql_plan_hash_value,
       COUNT(*) AS samples,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER(), 1) AS pct_total,
       MIN(sample_time) AS first_seen,
       MAX(sample_time) AS last_seen
FROM v$active_session_history
WHERE session_state = 'ON CPU'
  AND sample_time > SYSDATE - 1/24
GROUP BY sql_id, sql_plan_hash_value
ORDER BY samples DESC
FETCH FIRST 10 ROWS ONLY;
```

```sql
-- Top eventi di attesa (se CPU non è l'unico problema)
SELECT event, wait_class, COUNT(*) AS samples,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM v$active_session_history
WHERE sample_time > SYSDATE - 1/24
GROUP BY event, wait_class
ORDER BY samples DESC
FETCH FIRST 10 ROWS ONLY;
```

## Step 5: Hard Parse Eccessivo?

```sql
-- Hard parse = CPU sprecata per parse nuove query
SELECT name, value FROM v$sysstat
WHERE name IN ('parse count (total)', 'parse count (hard)', 'parse count (failures)');

-- Ratio: se hard/total > 30% → troppi hard parse
-- Fix: usare bind variables nel codice applicativo
```

## Step 6: Parallelismo Fuori Controllo?

```sql
-- Sessioni parallele attive
SELECT qcsid, sid, inst_id, degree, req_degree
FROM gv$px_session
ORDER BY qcsid;

-- Se troppe → limita
ALTER SYSTEM SET parallel_max_servers = &new_value SCOPE=BOTH;
```

## Step 7: Azioni di Mitigazione

### Kill query runaway (se una singola query mangia tutto):

```sql
-- ⚠️ Solo dopo conferma con il team
ALTER SYSTEM KILL SESSION '&sid,&serial#,@&inst_id' IMMEDIATE;
```

### Limita risorse con Resource Manager:

```sql
-- Attiva il resource plan per limitare i consumer pesanti
ALTER SYSTEM SET resource_manager_plan = 'DEFAULT_PLAN';
```

### SQL Quarantine (19c — blocca SQL "killer"):

```sql
BEGIN
    DBMS_SQLQ.CREATE_QUARANTINE_BY_SQL_ID(
        sql_id          => '&bad_sql_id',
        plan_hash_value => &plan_hash,
        quarantine_name => 'Q_CPU_HOG'
    );
    DBMS_SQLQ.ALTER_QUARANTINE(
        quarantine_name   => 'Q_CPU_HOG',
        parameter_name    => 'CPU_TIME',
        parameter_value   => '120'  -- max 120 secondi CPU
    );
END;
/
```

---

## ✅ Check di Conferma

| Controllo | Atteso |
|---|---|
| Host CPU | < 80% |
| AAS | < numero CPU |
| Top SQL CPU | Nessuna query runaway |
| Hard parse ratio | < 30% |
