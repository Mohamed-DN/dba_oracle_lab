# 07 — CPU Alta

<!-- RUNBOOK_NAV_START -->
## Casi piu frequenti da aprire prima
- CPU host sopra soglia e bisogna capire se e Oracle.
- Una o poche sessioni consumano CPU continuamente.
- Hard parse elevato o library cache contention.
- Parallel query fuori controllo.
- Serve mitigazione rapida senza riavviare il database.

## Indice rapido
- [Casi piu frequenti da aprire prima](#casi-piu-frequenti-da-aprire-prima)
- [Obiettivi](#obiettivi)
- [Procedura Operativa](#procedura-operativa)
  - [Step 1: È Oracle o è qualcos'altro?](#step-1-è-oracle-o-è-qualcosaltro)
  - [Step 2: Average Active Sessions (il "battito cardiaco")](#step-2-average-active-sessions-il-battito-cardiaco)
  - [Step 3: Chi Sta Consumando CPU?](#step-3-chi-sta-consumando-cpu)
  - [Step 4: Analisi ASH (chi stava usando CPU?)](#step-4-analisi-ash-chi-stava-usando-cpu)
  - [Step 5: Hard Parse Eccessivo?](#step-5-hard-parse-eccessivo)
  - [Step 6: Parallelismo Fuori Controllo?](#step-6-parallelismo-fuori-controllo)
  - [Step 7: Azioni di Mitigazione](#step-7-azioni-di-mitigazione)
  - [Kill query runaway (se una singola query mangia tutto):](#kill-query-runaway-se-una-singola-query-mangia-tutto)
  - [Limita risorse con Resource Manager:](#limita-risorse-con-resource-manager)
  - [SQL Quarantine (19c — blocca SQL "killer"):](#sql-quarantine-19c-blocca-sql-killer)
- [Validazione Finale](#validazione-finale)
- [Troubleshooting](#troubleshooting)
<!-- RUNBOOK_NAV_END -->

<!-- READY_SCRIPTS_START -->
## Script pronti collegati

Usali per raccogliere evidenze rapide dopo aver letto lo scenario del runbook.

- [07_performance_quick.sql](../03_scripts_pronti/07_performance_quick.sql) - top SQL, wait event, ASH real-time, piani SQL.
- [06_sessioni_lock.sql](../03_scripts_pronti/06_sessioni_lock.sql) - sessioni attive, blocker/waiter, DDL lock, kill command generator.
<!-- READY_SCRIPTS_END -->
> ⏱️ Tempo: 10-30 minuti | 📅 Frequenza: Su alert | 👤 Chi: DBA on-call
> **Scenario tipico**: Alert "CPU al 95%!" oppure "il database è lentissimo"

---

## Obiettivi

Monitorare, diagnosticare e mitigare picchi di carico CPU che possono compromettere la stabilità del database Oracle.

## Procedura Operativa

### Step 1: È Oracle o è qualcos'altro?

```bash
# A livello OS: chi sta usando CPU?
top -bn1 | head -20

# Processi Oracle ordinati per CPU
ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | grep -i ora | head -10
```

> Se i processi Oracle NON sono in top → il problema NON è il database.

> [!TIP]
> **🚀 L'approccio "Top Tier" (Senior DBA)**
> Smetti di faticare con le viste `gv$`. Utilizza gli script operativi della tua libreria per diagnosticare immediatamente la root cause della CPU assorbita:
> - **Chi Consuma CPU ADESSO**: `@../../01_operations/04_libreria_script_completa/03_monitoring_scripts/View_Cpu_Consumer.sql`
> - **Trend CPU Storico**: `@../../01_operations/04_libreria_script_completa/03_monitoring_scripts/View_Cpu_Hist.sql`
> - **Top SQL CPU da AWR**: `@../../01_operations/04_libreria_script_completa/07_performance_tuning/community_scripts/ash_awr/top10-sql-awr.sql`
> Esegui questi script invece di assemblare query lunghe.

### Step 2: Average Active Sessions (il "battito cardiaco")

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

### Step 3: Chi Sta Consumando CPU?

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

### Step 4: Analisi ASH (chi stava usando CPU?)

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

### Step 5: Hard Parse Eccessivo?

```sql
-- Hard parse = CPU sprecata per parse nuove query
SELECT name, value FROM v$sysstat
WHERE name IN ('parse count (total)', 'parse count (hard)', 'parse count (failures)');

-- Ratio: se hard/total > 30% → troppi hard parse
-- Fix: usare bind variables nel codice applicativo
```

### Step 6: Parallelismo Fuori Controllo?

```sql
-- Sessioni parallele attive
SELECT qcsid, sid, inst_id, degree, req_degree
FROM gv$px_session
ORDER BY qcsid;

-- Se troppe → limita
ALTER SYSTEM SET parallel_max_servers = &new_value SCOPE=BOTH;
```

### Step 7: Azioni di Mitigazione

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

## Validazione Finale

| Controllo | Atteso |
|---|---|
| Host CPU | < 80% |
| AAS | < numero CPU |
| Top SQL CPU | Nessuna query runaway |
| Hard parse ratio | < 30% |

## Troubleshooting

1. **CPU rimane alta dopo kill**: Verificare se ci sono processi paralleli (`PX`) rimasti orfani o se il processo OS è in stato "defunct".
2. **Log Switch eccessivi**: Se la CPU è alta a causa di LGWR, aumentare la dimensione dei Redo Log File.
3. **Paging/Swapping**: Se la CPU è usata da processi `kswapd`, il problema è la memoria RAM (SGA/PGA troppo grandi rispetto alla RAM fisica).
