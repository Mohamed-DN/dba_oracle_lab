# Guida AWR, ASH, ADDM ÔÇö Comandi Avanzati e Automazione

> Questa guida +¿ il **compagno pratico** della [GUIDA_TROUBLESHOOTING_COMPLETO.md](./GUIDA_TROUBLESHOOTING_COMPLETO.md). Quella insegna il METODO e la teoria. Questa contiene tutti i COMANDI avanzati, gli script automatizzati, e le tecniche di tuning SQL.

---

## 1. Configurazione AWR ÔÇö Best Practice

```sql
-- ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ
-- Configurazione consigliata per produzione/lab
-- ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ
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

## 2. Report AWR ÔÇö Generazione Automatizzata

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

## 3. ASH ÔÇö Query Avanzate

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
-- 14:02  35     3   30 2    |CCCIIIIIIIIIIIIIIIIIIIIIIIIIIIILL  ÔåÉ PICCO!
-- 14:03  38     2   33 3    |CCIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIILLL
-- 14:04  6      4   2  0    |CCCCII  ÔåÉ Tornato normale
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

## 4. ADDM ÔÇö Automazione

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
-- - Durano pi++ di 5 secondi
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

### 5.2 SQL Plan Management (SPM) ÔÇö Congelare un Piano Buono

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

### 5.3 SQL Quarantine (19c) ÔÇö Bloccare Query Pericolose

```sql
-- Se una query impazzisce e consuma troppe risorse,
-- puoi metterla in "quarantena" = Oracle la blocca automaticamente.

BEGIN
    DBMS_SQLQ.CREATE_QUARANTINE_BY_SQL_ID(
        sql_id         => '&sql_id',
        plan_hash_value => &bad_plan_hash,
        elapsed_time   => 300    -- blocca se dura pi++ di 300 secondi
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


================================================================================

# [SEZIONE AGGIUNTIVA] APPROFONDIMENTO MONUMENTALE


## [ARCHITETTURA VISIVA] AWR, ASH e ADDM
```text

(SGA) V$ACTIVE_SESSION_HISTORY ---> Campionamento 1/sec
         |
         +--> Flush ogni 10/sec ---> DBA_HIST_ASH (Disco)

Statistiche di Sistema (Memoria) ---> Snapshot 60/min ---> AWR (DBA_HIST_WR...)
                                                               |
                                                               v
                                                       ADDM Engine (AI)
                                                               |
                                                               v
                                                     Report Diagnostico
```

# GUIDA MONUMENTALE: AWR, ASH e ADDM per Performance Tuning Avanzato (19c/21c/23ai)

> [!NOTE]
> **DOCUMENTI DI PERFORMANCE CORRELATI:**
> - **SQL Tuning Advisor & STS**: [GUIDA_SQL_TUNING_SET_ADVISORS.md](./GUIDA_SQL_TUNING_SET_ADVISORS.md)
> - **SQL Plan Management**: [GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md](./GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md)
> - **Troubleshooting Wait Events**: [GUIDA_TROUBLESHOOTING_COMPLETO.md](./GUIDA_TROUBLESHOOTING_COMPLETO.md)

L'ecosistema diagnostico di Oracle (Automatic Workload Repository, Active Session History e Automatic Database Diagnostic Monitor) costituisce il "Flight Recorder" (scatola nera) del database. Padroneggiare questi tre strumenti è il requisito fondamentale per passare da DBA Operativo a **Performance Tuning Expert**. 

Questa guida fornisce l'arsenale per analizzare colli di bottiglia complessi, sia reattivamente (incidente in corso) che proattivamente (analisi di un rallentamento di ieri notte).

---

## 1. Automatic Workload Repository (AWR)

L'AWR è il repository persistente delle statistiche di sistema. Ogni ora (di default), Oracle scatta uno "Snapshot" (fotografia) di migliaia di contatori (metriche in memoria V$) e li salva su disco all'interno dello schema `SYS` (tablespace `SYSAUX`), nelle viste del dizionario `DBA_HIST_%`.

Un "AWR Report" è semplicemente un'analisi differenziale (Delta) tra due Snapshot (es. lo Snapshot delle 10:00 e quello delle 11:00). Oracle ti dice quanto tempo è stato speso e quante I/O sono state fatte *in quell'intervallo*.

### 1.1 Configurazione della Retention e dell'Intervallo
Nelle istanze di produzione critiche, l'intervallo di 60 minuti potrebbe essere troppo ampio per catturare un picco transitorio di 5 minuti ("micro-burst"). E la retention di default di 8 giorni è troppo breve per fare paragoni di fine mese (es. "Perché le chiusure contabili di questo mese sono più lente del mese scorso?").

**Modifica dei Parametri AWR (Best Practice Enterprise):**
```sql
sqlplus / as sysdba

-- Controlla le impostazioni attuali
SELECT extract(day from snap_interval) *24*60+extract(hour from snap_interval) *60+extract(minute from snap_interval) as Snapshot_Min,
       extract(day from retention) as Retention_Days
FROM dba_hist_wr_control;

-- Imposta l'intervallo a 15 o 30 minuti, e la retention a 45 giorni
BEGIN
  DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(
    retention => 45 * 24 * 60, -- 45 Giorni (in minuti)
    interval  => 30            -- Snapshot ogni 30 minuti
  );
END;
/
```
> [!WARNING]
> Aumentare la frequenza e la retention aumenterà drasticamente l'occupazione del tablespace `SYSAUX`. Monitorare costantemente con `@?/rdbms/admin/awrinfo.sql`.

### 1.2 Generazione dei Report AWR

Esistono numerosi script forniti da Oracle all'interno di `$ORACLE_HOME/rdbms/admin`:

*   `awrrpt.sql`: Report AWR standard per una singola istanza.
*   `awrrpti.sql`: Report AWR per un'istanza diversa (su RAC).
*   `awrsqrpt.sql`: AWR Report focalizzato esclusivamente su uno specifico `SQL_ID`. Fondamentale per vedere come è cambiato il piano o i costi di I/O nel tempo.
*   `awrddrpt.sql`: AWR Compare Period Report. Compara due AWR di giorni/settimane diversi (es. "Ieri vs Oggi"). Ottimo per isolare regressioni post-rilascio.
*   `awrgdrpt.sql`: Global AWR (tutti i nodi RAC sommati).

**Come estrarre un AWR in modo testuale (non interattivo) per invio mail:**
Se hai decine di database, generare AWR interattivi è lento. Usa l'API PL/SQL.
```sql
SET HEADING OFF PAGESIZE 0 TERMOUT OFF ECHO OFF
SPOOL awr_report_123_124.html
SELECT output FROM TABLE(
  DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(
    l_dbid     => 123456789, -- Ottieni da v$database
    l_inst_num => 1,         -- Istanza
    l_bid      => 123,       -- Snapshot ID inizio
    l_eid      => 124        -- Snapshot ID fine
  )
);
SPOOL OFF
```

---

## 2. Analisi Pratica di un Report AWR

Quando apri un report AWR, troverai centinaia di sezioni. Ecco la mappa per i Tuning Expert. Non leggere dall'inizio alla fine, salta alle sezioni critiche:

1.  **Top 10 Foreground Events**: È il riassunto dell'incidente. In quale Wait Class il database ha speso il maggior tempo?
    *   *User I/O (db file sequential read)*: Problemi sui dischi, indici mancanti (Full table scan nascosti).
    *   *Concurrency (library cache lock, enq: TX)*: Lock applicativi, row-level locking, problemi di parsing duro.
    *   *Network (SQL*Net message from client)*: Il DB è veloce, ma l'applicazione è lenta a processare i dati o la rete è satura. Spesso è un falso allarme o un problema architetturale.
    *   *Cluster (gc buffer busy)*: Esclusivo RAC. I blocchi viaggiano troppo spesso sull'interconnessione privata. Cattivo partizionamento o applicazioni non affini per nodo.
2.  **Load Profile**: Controlla `Logical reads (blocks)` vs `Physical reads (blocks)`. Se i logical reads esplodono all'improvviso, un piano di esecuzione è degradato.
3.  **SQL ordered by Elapsed Time / CPU Time / Gets**:
    Qui trovi il colpevole. L'SQL che ha consumato più risorse nel periodo dello snapshot. Copia il `SQL_ID` e passa all'analisi ASH o STS.

---

## 3. Active Session History (ASH)

L'AWR è "macroscopico". Ti dice che dalle 10 alle 11 c'è stato un problema di I/O, e ti elenca le top query.
Ma se l'incidente è durato solo 40 secondi, alle 10:15, l'AWR lo nasconderà in una media oraria perfetta (diluizione statistica).

**ASH (Active Session History)** risolve questo problema. Ogni 1 secondo in memoria (`V$ACTIVE_SESSION_HISTORY`), e ogni 10 secondi su disco (`DBA_HIST_ACTIVE_SESS_HISTORY`), Oracle fa un campionamento (sampling) di cosa stiano facendo ESATTAMENTE tutte le sessioni attive (non idle).

### 3.1 Estrazione del Report ASH
```sql
@?/rdbms/admin/ashrpt.sql
-- Ti chiederà data di inizio (es. -15 per iniziare 15 minuti fa) e durata in minuti.
```

### 3.2 ASH Analytics: Query PL/SQL Avanzate
I DBA Senior interrogano direttamente le viste ASH invece di usare il report precompilato.

**Scenario 1: Chi (Username/Machine) stava bloccando la CPU o facendo I/O ieri alle 14:15?**
```sql
SELECT session_state, event, module, machine, user_id, count(*) as campionamenti
FROM   dba_hist_active_sess_history
WHERE  sample_time BETWEEN TO_TIMESTAMP('2023-10-15 14:15:00', 'YYYY-MM-DD HH24:MI:SS') 
                       AND TO_TIMESTAMP('2023-10-15 14:20:00', 'YYYY-MM-DD HH24:MI:SS')
GROUP BY session_state, event, module, machine, user_id
ORDER BY campionamenti DESC;
```
*(Nota: moltiplicando `campionamenti` * 10, ottieni un'approssimazione dei secondi effettivi spesi nella wait).*

**Scenario 2: Analisi dei Lock a Livello di Riga (Blocking Tree)**
Quale sessione ha scatenato la reazione a catena (Deadlock o Blocking Lock)?
ASH traccia sia il SID bloccato, sia il `BLOCKING_SESSION`.
```sql
SELECT sample_time, session_id, blocking_session, event, sql_id, current_obj#
FROM   v$active_session_history
WHERE  event = 'enq: TX - row lock contention'
ORDER BY sample_time DESC;
```
L'`obj#` ti permette di fare la join con `DBA_OBJECTS` per capire esattamente su quale tabella e blocco è avvenuto lo stallo.

---

## 4. Automatic Database Diagnostic Monitor (ADDM)

ADDM è l'Intelligenza Artificiale integrata (Rule Engine) di Oracle. Mentre un DBA "umano" apre un AWR report e cerca di dedurre i problemi analizzando i numeri, l'ADDM analizza automaticamente i due snapshot AWR appena generati e produce un report diagnostico in lingua naturale, con tanto di "Impact %" e "Recommendations" (soluzioni proposte).

ADDM è eccezionale per due motivi:
1.  **Approccio Top-Down (DB Time)**: Ignora i falsi positivi (es. processi in attesa della rete senza impatto sul business). Analizza solo i colli di bottiglia che consumano gran parte del DB Time.
2.  **Sintesi**: In pochi secondi ti dà un quadro chiaro e un albero diagnostico.

### 4.1 Generazione ed Esecuzione ADDM
L'ADDM gira automaticamente in background dopo ogni snapshot AWR, popolando viste come `DBA_ADVISOR_FINDINGS`.
Puoi generare il report testo per un intervallo a tuo piacimento:

```sql
@?/rdbms/admin/addmrpt.sql
-- Ti chiederà i due Snapshot ID di inizio e fine.
```

### 4.2 ADDM Findings e Recommendation Types
Il report generato ti fornirà raccomandazioni categorizzate in:
*   **Hardware Changes**: Es. "La CPU è satura al 99%, aumentare le risorse o spostare i batch".
*   **Database Configuration**: Es. "La Shared Pool è troppo piccola (Shared Pool Thrashing). Aumenta SGA_TARGET".
*   **Schema Design**: Es. "Aggiungere l'indice X alla tabella Y per ridurre il buffer get della query Z". (Questa recommendation richiama indirettamente il SQL Tuning Advisor).
*   **Application Design**: Es. "Trovati 1500 SQL ID identici ma senza bind variables. Problema di Hard Parsing. Cambiare l'applicazione o impostare CURSOR_SHARING=FORCE".

### 4.3 ADDM su Eventi Puntuali e RAC
In un ambiente RAC, l'AWR normale (singolo nodo) e l'ADDM normale ignorano le dinamiche globali. Oracle espone:
*   `@?/rdbms/admin/addmrpti.sql`: ADDM Report mirato su un nodo specifico (Instance-level).
*   **ADDM in Real-Time (Solo via Enterprise Manager)**: Una funzionalità esclusiva che permette ad ADDM di analizzare un'istanza freezata (hung system) collegandosi in Diagnostic Mode (senza impattare la SGA principale), estraendo dati dalla PGA e da un piccolo dump file OS, fondamentale per risolvere blocchi totali ("L'istanza non risponde a SQL*Plus").
