# 05 — Query Lenta — Diagnosi Rapida

> ⏱️ Tempo: 10-30 minuti | 📅 Frequenza: Su ticket | 👤 Chi: DBA
> **Scenario tipico**: "Questa query ci mette 10 minuti, prima ci metteva 2 secondi!"

---

## Step 1: Identifica la Query (hai il SQL_ID?)

### Se hai il SQL_ID:

```sql
-- Testo della query
SELECT sql_id, sql_text FROM v$sql WHERE sql_id = '&sql_id';
```

### Se NON hai il SQL_ID (devi trovarlo):

```sql
-- Query attive adesso più pesanti
SELECT sql_id, elapsed_time/1000000 AS elapsed_sec,
       executions, buffer_gets,
       ROUND(elapsed_time/1000000/NULLIF(executions,0), 2) AS sec_per_exec,
       SUBSTR(sql_text, 1, 120) AS sql_preview
FROM gv$sql
WHERE executions > 0
  AND elapsed_time/1000000/NULLIF(executions,0) > 5  -- più di 5 sec per esecuzione
ORDER BY elapsed_time DESC
FETCH FIRST 10 ROWS ONLY;
```

```sql
-- Cerca per parte del testo SQL
SELECT sql_id, executions,
       ROUND(elapsed_time/1000000, 1) AS total_sec,
       SUBSTR(sql_text, 1, 120)
FROM gv$sql
WHERE UPPER(sql_text) LIKE '%NOME_TABELLA%'
  AND sql_text NOT LIKE '%v$sql%'
ORDER BY elapsed_time DESC;
```

## Step 2: Piano di Esecuzione Attuale

```sql
-- Piano REALE con statistiche runtime
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('&sql_id', NULL, 'ALLSTATS LAST'));
```

```sql
-- Se non è in memory, cerca in AWR
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_AWR('&sql_id'));
```

**Cosa cercare nel piano:**
| Segnale | Significato | Possibile Fix |
|---|---|---|
| `TABLE ACCESS FULL` su tabella grande | Full table scan | Manca indice? |
| `NESTED LOOPS` con alta cardinalità | Join sbagliato | Statistiche stale? |
| `Rows (E-Time)` molto diverso da `Rows (A-Rows)` | Stima cardinalità errata | Raccogli statistiche |
| `SORT ORDER BY` con TempSpc | Sort su disco | PGA troppo piccola? |
| `HASH JOIN` con TempSpc enorme | Join grande su disco | Memoria insufficiente |

## Step 3: Le Statistiche Sono Aggiornate?

```sql
-- Controlla statistiche delle tabelle coinvolte
SELECT owner, table_name, num_rows, last_analyzed,
       stale_stats, stattype_locked
FROM dba_tab_statistics
WHERE table_name IN ('&TABELLA1', '&TABELLA2')
ORDER BY last_analyzed;

-- ⚠️ Se last_analyzed > 7 giorni → raccogli statistiche!
-- ⚠️ Se stale_stats = YES → sicuramente da aggiornare!
```

```sql
-- Raccogli statistiche se necessario
EXEC DBMS_STATS.GATHER_TABLE_STATS('&OWNER', '&TABLE_NAME',
     METHOD_OPT => 'FOR ALL COLUMNS SIZE AUTO',
     CASCADE => TRUE);
```

## Step 4: Il Piano è Cambiato? (Regressione)

```sql
-- Storico piani da AWR: il piano è cambiato di recente?
SELECT snap_id, plan_hash_value,
       ROUND(elapsed_time_total/1000000, 1) AS total_sec,
       executions_total,
       ROUND(elapsed_time_total/1000000/NULLIF(executions_total,0), 2) AS sec_per_exec
FROM dba_hist_sqlstat
WHERE sql_id = '&sql_id'
  AND snap_id > (SELECT MIN(snap_id) FROM dba_hist_snapshot
                 WHERE begin_interval_time > SYSDATE - 7)
ORDER BY snap_id;

-- Se plan_hash_value è cambiato → regressione di piano!
```

## Step 5: Dove il Tempo Viene Speso?

```sql
-- Wait events per questa query (da ASH)
SELECT event, wait_class, COUNT(*) AS samples,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM v$active_session_history
WHERE sql_id = '&sql_id'
  AND sample_time > SYSDATE - 1/24  -- ultima ora
GROUP BY event, wait_class
ORDER BY samples DESC;
```

| Wait Event | Significato |
|---|---|
| `db file sequential read` | Letture singole da disco (index scan) |
| `db file scattered read` | Full table scan |
| `direct path read temp` | Sort/hash su disco |
| `ON CPU` | La query lavora, nessuna attesa |
| `gc buffer busy` | Contesa RAC tra nodi |

## Step 6: SQL Tuning Advisor (automatico)

```sql
-- Chiedi ad Oracle di analizzare la query
DECLARE
    l_task VARCHAR2(64);
BEGIN
    l_task := DBMS_SQLTUNE.CREATE_TUNING_TASK(
        sql_id      => '&sql_id',
        scope       => DBMS_SQLTUNE.SCOPE_COMPREHENSIVE,
        time_limit  => 300,
        task_name   => 'TUNE_' || '&sql_id'
    );
    DBMS_SQLTUNE.EXECUTE_TUNING_TASK('TUNE_' || '&sql_id');
END;
/

-- Leggi le raccomandazioni
SET LONG 100000
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('TUNE_' || '&sql_id') AS report FROM dual;
```

## Step 7: Fix Rapidi

### Se mancano statistiche:
```sql
EXEC DBMS_STATS.GATHER_TABLE_STATS('&OWNER', '&TABLE', CASCADE => TRUE);
```

### Se il piano è regredito (forza il piano vecchio):
```sql
-- Crea SQL Plan Baseline dal piano buono in AWR
DECLARE
    l_plans PLS_INTEGER;
BEGIN
    l_plans := DBMS_SPM.LOAD_PLANS_FROM_AWR(
        sql_id          => '&sql_id',
        plan_hash_value => &good_plan_hash
    );
    DBMS_OUTPUT.PUT_LINE('Plans loaded: ' || l_plans);
END;
/
```

### Se manca un indice (consigliato da Tuning Advisor):
```sql
-- ⚠️ PRIMA in ambiente di test, poi in produzione!
CREATE INDEX owner.idx_name ON owner.table_name(column1, column2)
    ONLINE TABLESPACE &tablespace;
```

---

## ✅ Check di Conferma

| Controllo | Atteso |
|---|---|
| sec_per_exec | Tornato al valore normale |
| Piano di esecuzione | Stabile |
| Statistiche | Aggiornate |
| Utente/App | Confermano miglioramento |
