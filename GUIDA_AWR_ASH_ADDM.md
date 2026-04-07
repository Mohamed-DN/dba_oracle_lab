# Guida AWR, ASH e ADDM — Diagnostica Performance Oracle 19c

> AWR, ASH e ADDM sono i "raggi X" del database Oracle. Ti permettono di diagnosticare problemi di performance con precisione chirurgica.

---

## 1. Teoria: I 3 Pilastri della Diagnostica Oracle

### 1.1 Mappa Concettuale

```
  ┌──────────────────────────────────────────────────────────────┐
  │                    DATABASE ORACLE                           │
  │                                                              │
  │  Ogni secondo, Oracle raccoglie:                             │
  │                                                              │
  │  ┌────────────────────────────────────────────────────────┐  │
  │  │ ASH (Active Session History)                           │  │
  │  │ Campiona OGNI SECONDO le sessioni attive               │  │
  │  │ Salva: SQL_ID, wait_event, session_state, ecc.         │  │
  │  │ Vista: V$ACTIVE_SESSION_HISTORY (in memoria, ~1 ora)   │  │
  │  └─────────────┬──────────────────────────────────────────┘  │
  │                │                                              │
  │                │ Ogni ora, MMON (Manageability Monitor):      │
  │                ▼                                              │
  │  ┌────────────────────────────────────────────────────────┐  │
  │  │ AWR (Automatic Workload Repository)                    │  │
  │  │ Snapshot statistiche ogni 30/60 min (configurabile)     │  │
  │  │ Salva: wait events, SQL stats, I/O, memory, ecc.       │  │
  │  │ Retention: 8 giorni (default, configurabile)            │  │
  │  │ Vista: DBA_HIST_* (su disco, persistente)               │  │
  │  └─────────────┬──────────────────────────────────────────┘  │
  │                │                                              │
  │                │ Automaticamente analizzato da:                │
  │                ▼                                              │
  │  ┌────────────────────────────────────────────────────────┐  │
  │  │ ADDM (Automatic Database Diagnostic Monitor)           │  │
  │  │ Analizza gli snapshot AWR e produce RACCOMANDAZIONI     │  │
  │  │ "Hai troppi full table scan → crea un indice"           │  │
  │  │ "Buffer cache troppo piccola → aumenta SGA"             │  │
  │  │ "SQL_ID abc123 consuma il 40% della CPU → tuning"       │  │
  │  └────────────────────────────────────────────────────────┘  │
  └──────────────────────────────────────────────────────────────┘
```

---

## 2. AWR — Automatic Workload Repository

### 2.1 Configurazione AWR

```sql
sqlplus / as sysdba

-- Verifica configurazione attuale
SELECT snap_interval, retention FROM dba_hist_wr_control;
-- Default: snap ogni 60 min, retention 8 giorni

-- Modifica: snapshot ogni 30 min, retention 30 giorni
EXEC DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(
    interval => 30,      -- minuti tra snapshot
    retention => 43200   -- minuti di retention (30 giorni)
);
```

### 2.2 Generare un Report AWR

```sql
-- Metodo 1: Script interattivo
@?/rdbms/admin/awrrpt.sql
-- Ti chiede: formato (html/text), DBID, num_days, begin_snap, end_snap
-- Genera un file HTML con l'analisi completa

-- Metodo 2: Elenca gli snapshot disponibili
SELECT snap_id, begin_interval_time, end_interval_time
FROM dba_hist_snapshot
ORDER BY snap_id DESC
FETCH FIRST 20 ROWS ONLY;

-- Metodo 3: Genera report AWR tra due snapshot specifici (in RAC)
@?/rdbms/admin/awrgrpt.sql
-- ^^^ awrGrpt = Global RAC report (aggrega tutti i nodi)
```

### 2.3 Come Leggere un Report AWR (Le 5 Sezioni Chiave)

```
1. REPORT SUMMARY
   - DB Time: tempo totale speso dalle sessioni nel database
   - Se DB Time >> Wall Clock Time × CPU Count → database saturo

2. TOP 5 TIMED FOREGROUND EVENTS
   ╔════════════════════════════════╦═══════════╦═════════╗
   ║ Event                         ║ % DB Time ║ Azione  ║
   ╠════════════════════════════════╬═══════════╬═════════╣
   ║ db file sequential read       ║ 45%       ║ I/O     ║
   ║ log file sync                 ║ 20%       ║ Commit  ║
   ║ CPU + Wait for CPU            ║ 15%       ║ CPU     ║
   ║ db file scattered read        ║ 10%       ║ FTS     ║
   ║ buffer busy waits             ║ 5%        ║ Contesa ║
   ╚════════════════════════════════╩═══════════╩═════════╝

   Interpretazione rapida:
   - db file sequential read = letture da indice (normale se non eccessivo)
   - db file scattered read = full table scan (possibile indice mancante)
   - log file sync = commit lenti (disco redo lento)
   - buffer busy waits = contesa sulla buffer cache (hot blocks)
   - enq: TX - row lock contention = lock tra sessioni

3. SQL STATISTICS
   - SQL ordered by Elapsed Time → le query più lente
   - SQL ordered by CPU Time → le query che consumano più CPU
   - SQL ordered by Gets → le query che leggono più blocchi (I/O logico)

4. INSTANCE ACTIVITY STATISTICS
   - Physical reads/writes per secondo
   - Redo generated per secondo
   - User calls per secondo

5. ADVISORY SECTIONS
   - Buffer Cache Advisory: "se aumenti la cache a X, risparmi Y I/O"
   - PGA Advisory: "se aumenti il PGA a X, riduci i sort su disco"
   - Shared Pool Advisory: "se aumenti lo shared pool, riduci i parse"
```

---

## 3. ASH — Active Session History

### 3.1 Query ASH in Tempo Reale

```sql
-- Top 5 SQL attivi ADESSO
SELECT sql_id,
       COUNT(*) AS active_sessions,
       MAX(event) AS current_wait
FROM v$active_session_history
WHERE sample_time > SYSDATE - INTERVAL '5' MINUTE
  AND session_state = 'ON CPU' OR session_state = 'WAITING'
GROUP BY sql_id
ORDER BY active_sessions DESC
FETCH FIRST 5 ROWS ONLY;

-- Sessioni in attesa raggruppate per tipo di wait
SELECT event,
       COUNT(*) AS sessions,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM v$active_session_history
WHERE sample_time > SYSDATE - INTERVAL '10' MINUTE
  AND session_state = 'WAITING'
GROUP BY event
ORDER BY sessions DESC;

-- Timeline di una query specifica
SELECT TO_CHAR(sample_time, 'HH24:MI:SS') AS time,
       session_state,
       event,
       blocking_session
FROM v$active_session_history
WHERE sql_id = '&sql_id'
  AND sample_time > SYSDATE - INTERVAL '1' HOUR
ORDER BY sample_time;
```

### 3.2 Generare un Report ASH

```sql
-- Report ASH per un periodo specifico
@?/rdbms/admin/ashrpt.sql
-- Ti chiede: begin_time, end_time, formato
-- Utile per analizzare UN INCIDENTE specifico
```

---

## 4. ADDM — Automatic Database Diagnostic Monitor

### 4.1 Generare un Report ADDM

```sql
-- Report ADDM tra due snapshot AWR
@?/rdbms/admin/addmrpt.sql
-- Ti chiede: begin_snap, end_snap
-- Genera un report con RACCOMANDAZIONI ACTIONABLE

-- Esempio output ADDM:
-- FINDING 1: SQL statements with high CPU usage
--   RECOMMENDATION: SQL Tuning Advisor for SQL_ID 'abc123def'
--   BENEFIT: 35% reduction in DB Time
--
-- FINDING 2: Buffer cache too small
--   RECOMMENDATION: Increase DB_CACHE_SIZE from 2G to 4G
--   BENEFIT: 20% reduction in physical reads
```

### 4.2 ADDM via PL/SQL (Automatizzato)

```sql
-- Crea un task ADDM tra due snapshot
DECLARE
    l_task_name VARCHAR2(100) := 'ADDM_MANUAL_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MI');
    l_task_id   NUMBER;
BEGIN
    DBMS_ADVISOR.CREATE_TASK('ADDM', l_task_id, l_task_name);
    DBMS_ADVISOR.SET_TASK_PARAMETER(l_task_name, 'START_SNAPSHOT', &begin_snap);
    DBMS_ADVISOR.SET_TASK_PARAMETER(l_task_name, 'END_SNAPSHOT', &end_snap);
    DBMS_ADVISOR.EXECUTE_TASK(l_task_name);
    DBMS_OUTPUT.PUT_LINE('Task: ' || l_task_name);
END;
/

-- Leggi i risultati
SELECT dbms_advisor.get_task_report('&task_name') FROM dual;
```

---

## 5. SQL Tuning Advisor

Quando AWR/ADDM identifica una query lenta, usa il SQL Tuning Advisor:

```sql
-- 1. Crea un task di tuning per una query specifica
DECLARE
    l_task_name VARCHAR2(100);
BEGIN
    l_task_name := DBMS_SQLTUNE.CREATE_TUNING_TASK(
        sql_id => '&sql_id',
        scope => DBMS_SQLTUNE.SCOPE_COMPREHENSIVE,
        time_limit => 300,
        task_name => 'TUNE_' || '&sql_id'
    );
    DBMS_SQLTUNE.EXECUTE_TUNING_TASK(task_name => l_task_name);
END;
/

-- 2. Leggi le raccomandazioni
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('TUNE_&sql_id') FROM dual;
-- Output tipico:
--   "Si raccomanda di creare il seguente indice:"
--   CREATE INDEX HR.IDX_EMP_DEPT ON HR.EMPLOYEES(DEPARTMENT_ID);
--   "Beneficio stimato: 95% riduzione elapsed time"

-- 3. Se raccomanda un SQL Profile, accettalo:
EXEC DBMS_SQLTUNE.ACCEPT_SQL_PROFILE(task_name => 'TUNE_&sql_id');
```

---

## 6. Workflow Pratico: "La Query X è Lenta"

```
PASSO 1: Identifica la query
  → SELECT sql_id, elapsed_time/1000000 AS secs, executions
    FROM v$sql ORDER BY elapsed_time DESC FETCH FIRST 10 ROWS ONLY;

PASSO 2: Guarda cosa aspetta
  → SELECT event, COUNT(*)
    FROM v$active_session_history
    WHERE sql_id = 'abc123' GROUP BY event;

PASSO 3: Guarda il piano di esecuzione
  → SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('abc123'));

PASSO 4: Lancia il SQL Tuning Advisor
  → DBMS_SQLTUNE.CREATE_TUNING_TASK(sql_id => 'abc123');

PASSO 5: Applica la raccomandazione
  → CREATE INDEX ... oppure ACCEPT SQL PROFILE
```

---

## 7. Fonti Oracle Ufficiali

- AWR Overview: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/automatic-performance-diagnostics.html
- ASH: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/active-session-history.html
- ADDM: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/automatic-database-diagnostic-monitor.html
- SQL Tuning Advisor: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/sql-tuning-advisor.html
