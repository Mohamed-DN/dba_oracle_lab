# Guida Completa Troubleshooting e Performance Tuning — Oracle 19c RAC

> Questa guida ti insegna a diagnosticare e risolvere qualsiasi problema Oracle, partendo da zero. Non devi memorizzare comandi: devi capire il **metodo**. Una volta capito il metodo, i comandi sono solo strumenti.

---

## PARTE 1: IL METODO — Come Pensa un DBA

### 1.1 La Regola d'Oro: Non Indovinare Mai

```
❌ SBAGLIATO (il DBA istintivo):
  "Il database è lento → aumento la RAM"
  "C'è un errore → riavvio tutto"
  "Non so cosa sia → chiamo Oracle Support"

✅ GIUSTO (il DBA metodico):
  1. OSSERVA: qual è il SINTOMO esatto?
  2. MISURA: cosa dicono i DATI (AWR, ASH, v$session)?
  3. IPOTIZZA: basandoti sui dati, qual è la CAUSA più probabile?
  4. VERIFICA: il cambiamento ha risolto il problema?
  5. DOCUMENTA: scrivi cosa hai fatto per la prossima volta.
```

### 1.2 La Piramide del Tuning (Top-Down)

Oracle raccomanda un approccio **top-down**: parti dal livello più alto (business) e scendi verso il basso (hardware). Ogni livello ha un impatto decrescente.

```
               ▲ IMPATTO MASSIMO
              ╱ ╲
             ╱   ╲
            ╱  1  ╲   Business Rules & Requirements
           ╱───────╲   "Serve davvero questa query? Può girare di notte?"
          ╱    2    ╲   Data Design (Schema, Partitioning)
         ╱───────────╲   "La tabella ha 500M righe senza partizioni?"
        ╱      3      ╲   Application Design (SQL, round trips)
       ╱───────────────╲   "L'app fa 10.000 query per caricare una pagina?"
      ╱        4        ╲   SQL Tuning (Plan, Indici)
     ╱───────────────────╲   "La query fa full table scan su 500M righe?"
    ╱          5          ╲   Instance Tuning (SGA, PGA, parametri)
   ╱───────────────────────╲   "La buffer cache è troppo piccola?"
  ╱            6            ╲   I/O & Storage
 ╱─────────────────────────╲   "Il disco è saturo?"
╱              7              ╲   OS & Network
───────────────────────────────   "La CPU è al 100%?"
               ▼ IMPATTO MINIMO

REGOLA: Non ottimizzare il livello 7 se non hai verificato i livelli 1-6.
Un indice mancante (livello 4) ha più impatto di 100 GB di RAM extra (livello 5).
```

### 1.3 Il Concetto Fondamentale: DB Time e Wait Events

```
Cos'è il DB Time?
═══════════════════

DB Time = tempo TOTALE che TUTTE le sessioni hanno passato nel database.

Se in 1 ora hai 10 sessioni attive, ciascuna che lavora per 30 minuti:
  DB Time = 10 × 30 min = 300 minuti di DB Time in 1 ora di wall clock.

DB Time = CPU Time + Wait Time
  ├── CPU Time: il database stava ELABORANDO (eseguendo SQL)
  └── Wait Time: il database stava ASPETTANDO qualcosa
       ├── I/O: aspettava un blocco dal disco
       ├── Lock: aspettava che un'altra sessione rilasciasse un lock
       ├── Network: aspettava dati dalla rete (RAC interconnect)
       └── Altro: commit, latch, redo write, ecc.

PRINCIPIO: Se vuoi velocizzare il database, devi ridurre il DB Time.
Per ridurre il DB Time, devi capire DOVE lo passa.
Ed è qui che entrano i Wait Events.
```

### 1.4 Wait Events — Il Linguaggio del Database

```
Un wait event è il database che dice: "sto aspettando QUESTO."

Ogni volta che una sessione Oracle non può procedere, registra un wait event.
I wait events sono organizzati in Wait Classes:

  Wait Class        Significato                     Preoccupante?
  ──────────────────────────────────────────────────────────────────
  User I/O          Lettura/Scrittura dati          Dipende dal volume
  System I/O        I/O del sistema (redo, undo)    Raro
  Concurrency       Lock, mutex, latch              Sì, se alto
  Commit            Conferma transazione            Dipende
  Network           Comunicazione rete (RAC)        Sì se lento
  Application       Lock espliciti dell'applicazione Sì
  Configuration     Problema di configurazione      Sì
  Administrative    Azione DBA in corso             Temporaneo
  Idle              Sessione in attesa di lavoro     IGNORALO
  ──────────────────────────────────────────────────────────────────

⚠️ IMPORTANTE: IGNORA SEMPRE gli eventi "Idle"!
   "SQL*Net message from client" = il cliente non sta mandando query.
   Non è un problema del database, è il client che è lento/inattivo.
```

---

## PARTE 2: GLI STRUMENTI — La Cassetta degli Attrezzi

### 2.1 Mappa degli Strumenti

```
  URGENZA / TEMPO
  ▲
  │  "È ADESSO!"              "È successo IERI"           "Trend MENSILE"
  │
  │  ┌──────────────┐         ┌──────────────┐           ┌──────────────┐
  │  │ v$session     │         │ AWR Report   │           │ AWR Baseline │
  │  │ v$session_wait│         │ (30-60 min)  │           │ AWR Compare  │
  │  │ v$active_     │         │              │           │ Periods      │
  │  │  session_     │         │ ASH Report   │           │              │
  │  │  history      │         │ (periodo     │           │ ADDM History │
  │  │              │         │  specifico)  │           │              │
  │  │ TOP command  │         │              │           │ Statspack    │
  │  │ iostat       │         │ ADDM Report  │           │              │
  │  └──────────────┘         └──────────────┘           └──────────────┘
  │      REAL-TIME                STORICO                  TREND
  └────────────────────────────────────────────────────────────────────▶
```

### 2.2 Strumento 1: v$session — "Cosa sta succedendo ADESSO"

Questa è la vista più usata da un DBA. Ogni riga è una sessione connessa.

```sql
-- ═══════════════════════════════════════════════════════════════════
-- QUERY 1: "Chi è connesso e cosa sta facendo?"
-- ═══════════════════════════════════════════════════════════════════
SELECT
    s.sid,                    -- Session ID (numero univoco della sessione)
    s.serial#,                -- Serial number (per kill della sessione)
    s.username,               -- Chi è connesso (NULL = processo di sistema)
    s.status,                 -- ACTIVE = sta lavorando, INACTIVE = aspetta il client
    s.event,                  -- L'ultimo wait event (QUESTO è il dato chiave!)
    s.wait_class,             -- Categoria del wait
    s.seconds_in_wait,        -- Da quanto tempo sta aspettando
    s.sql_id,                 -- ID della query che sta eseguendo
    s.blocking_session,       -- Se c'è, chi lo sta bloccando
    s.machine,                -- Da quale computer viene la connessione
    s.program                 -- Programma client (sqlplus, java, ecc.)
FROM v$session s
WHERE s.status = 'ACTIVE'     -- Solo sessioni attive
  AND s.username IS NOT NULL   -- Escludi processi di sistema
ORDER BY s.seconds_in_wait DESC;

-- COME LEGGERE L'OUTPUT:
-- Se vedi: event = 'db file sequential read', seconds_in_wait = 120
-- Significa: questa sessione sta aspettando da 2 MINUTI che Oracle
--            legga un blocco dal disco. Probabilmente una query con
--            un piano di esecuzione pessimo.
```

```sql
-- ═══════════════════════════════════════════════════════════════════
-- QUERY 2: "Quali wait events stanno consumando più tempo?"
-- ═══════════════════════════════════════════════════════════════════
SELECT
    wait_class,
    event,
    COUNT(*) AS sessioni_in_attesa,
    ROUND(AVG(seconds_in_wait)) AS media_sec,
    MAX(seconds_in_wait) AS max_sec
FROM v$session
WHERE status = 'ACTIVE'
  AND username IS NOT NULL
  AND wait_class != 'Idle'     -- ← ESCLUDI sempre gli Idle!
GROUP BY wait_class, event
ORDER BY sessioni_in_attesa DESC;

-- COME LEGGERE L'OUTPUT:
-- WAIT_CLASS      EVENT                         SESSIONI  MEDIA_SEC
-- Concurrency     buffer busy waits             15        3
-- User I/O        db file sequential read       8         1
-- Application     enq: TX - row lock contention 3         45
--
-- TRADUZIONE: 15 sessioni competono per gli stessi blocchi (hot block).
-- 3 sessioni sono bloccate da un lock applicativo da 45 secondi.
```

```sql
-- ═══════════════════════════════════════════════════════════════════
-- QUERY 3: "Chi sta bloccando chi?" (Blocchi e Lock)
-- ═══════════════════════════════════════════════════════════════════
SELECT
    b.sid AS blocker_sid,
    b.serial# AS blocker_serial,
    b.username AS blocker_user,
    b.sql_id AS blocker_sql,
    b.event AS blocker_doing,
    '  →→→ blocca →→→  ' AS " ",
    w.sid AS victim_sid,
    w.serial# AS victim_serial,
    w.username AS victim_user,
    w.sql_id AS victim_sql,
    w.seconds_in_wait AS victim_waiting_secs
FROM v$session w
JOIN v$session b ON b.sid = w.blocking_session
WHERE w.blocking_session IS NOT NULL
ORDER BY w.seconds_in_wait DESC;

-- COME LEGGERE L'OUTPUT:
-- BLOCKER_SID  BLOCKER_USER  →→→  VICTIM_SID  VICTIM_USER  WAITING_SECS
-- 234          HR_APP              456         HR_BATCH     120
--
-- TRADUZIONE: La sessione 234 (utente HR_APP) sta bloccando
-- la sessione 456 (utente HR_BATCH) da 2 minuti.
-- La sessione 234 probabilmente ha un UPDATE senza COMMIT.
```

```sql
-- ═══════════════════════════════════════════════════════════════════
-- QUERY 4: "Qual è il testo SQL della query bloccante?"
-- ═══════════════════════════════════════════════════════════════════
SELECT sql_id, sql_text
FROM v$sql
WHERE sql_id = '&inserisci_sql_id';
-- ^^^ Prendi l'sql_id dalla query precedente.
```

```sql
-- ═══════════════════════════════════════════════════════════════════
-- QUERY 5: Kill di una sessione bloccante (EMERGENZA!)
-- ═══════════════════════════════════════════════════════════════════
ALTER SYSTEM KILL SESSION '234,56789' IMMEDIATE;
-- ^^^ 234 = SID, 56789 = SERIAL# (presi da v$session)
--     IMMEDIATE = non aspettare che la transazione finisca, uccidila
--     Oracle farà automaticamente ROLLBACK della transazione non committata.
--
-- ⚠️ USA CON CAUTELA! Stai uccidendo la sessione di qualcuno.
-- Verifica prima che sia veramente la causa del problema.
--
-- In RAC, se la sessione è su un'altra istanza:
ALTER SYSTEM KILL SESSION '234,56789,@2' IMMEDIATE;
-- ^^^ @2 = istanza 2 (INST_ID da gv$session)
```

### 2.3 Strumento 2: ASH — "Cosa è successo negli ultimi minuti"

ASH campiona le sessioni attive **ogni secondo**. È perfetto per problemi transitori.

```sql
-- ═══════════════════════════════════════════════════════════════════
-- QUERY 6: "Top SQL degli ultimi 10 minuti"
-- ═══════════════════════════════════════════════════════════════════
SELECT
    sql_id,
    COUNT(*) AS campioni,         -- Più campioni = più tempo = più impatto
    ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER(), 1) AS pct_dbtime,
    MAX(sql_plan_hash_value) AS plan_hash,
    MAX(event) AS ultimo_wait
FROM v$active_session_history
WHERE sample_time > SYSDATE - INTERVAL '10' MINUTE
  AND session_type = 'FOREGROUND'   -- Solo sessioni utente
GROUP BY sql_id
ORDER BY campioni DESC
FETCH FIRST 10 ROWS ONLY;

-- COME LEGGERE L'OUTPUT:
-- SQL_ID         CAMPIONI  PCT_DBTIME  ULTIMO_WAIT
-- abc123def456   450       62.5%       db file sequential read
-- ghi789jkl012   120       16.7%       CPU + Wait for CPU
-- mno345pqr678   80        11.1%       log file sync
--
-- TRADUZIONE: La query abc123 consuma il 62.5% del DB Time
-- ed è in attesa di I/O (letture da disco).
-- → AZIONE: guarda il piano di esecuzione di abc123!
```

```sql
-- ═══════════════════════════════════════════════════════════════════
-- QUERY 7: "In quali minuti il database era più carico?"
-- ═══════════════════════════════════════════════════════════════════
SELECT
    TO_CHAR(sample_time, 'HH24:MI') AS minuto,
    COUNT(*) AS sessioni_attive,
    SUM(CASE WHEN session_state = 'ON CPU' THEN 1 ELSE 0 END) AS su_cpu,
    SUM(CASE WHEN wait_class = 'User I/O' THEN 1 ELSE 0 END) AS su_io,
    SUM(CASE WHEN wait_class = 'Concurrency' THEN 1 ELSE 0 END) AS su_lock,
    SUM(CASE WHEN wait_class = 'Cluster' THEN 1 ELSE 0 END) AS su_rac
FROM v$active_session_history
WHERE sample_time > SYSDATE - INTERVAL '1' HOUR
GROUP BY TO_CHAR(sample_time, 'HH24:MI')
ORDER BY minuto;

-- COME LEGGERE L'OUTPUT:
-- MINUTO SESSIONI  CPU  IO  LOCK  RAC
-- 14:00  5         3    2   0     0    ← normale
-- 14:01  5         4    1   0     0    ← normale
-- 14:02  45        5    35  5     0    ← PICCO! Esplosione di I/O
-- 14:03  50        3    40  7     0    ← Ancora alto
-- 14:04  8         4    3   1     0    ← Tornato normale
--
-- TRADUZIONE: Alle 14:02-14:03 c'è stato un picco di I/O.
-- Probabilmente una query batch o un report che ha fatto un full scan.
```

```sql
-- ═══════════════════════════════════════════════════════════════════
-- QUERY 8: "Chi era attivo alle 14:02?" (Drill-down nel picco)
-- ═══════════════════════════════════════════════════════════════════
SELECT
    sql_id,
    session_id AS sid,
    event,
    COUNT(*) AS campioni
FROM v$active_session_history
WHERE sample_time BETWEEN
    TO_TIMESTAMP('2026-04-07 14:02:00', 'YYYY-MM-DD HH24:MI:SS') AND
    TO_TIMESTAMP('2026-04-07 14:04:00', 'YYYY-MM-DD HH24:MI:SS')
  AND session_type = 'FOREGROUND'
GROUP BY sql_id, session_id, event
ORDER BY campioni DESC
FETCH FIRST 10 ROWS ONLY;
```

### 2.4 Generare un Report ASH (per un periodo specifico)

```sql
-- Script interattivo Oracle
@?/rdbms/admin/ashrpt.sql
-- Ti chiede: formato (html/text), periodo start/end
-- Genera un report dettagliato con:
-- - Top SQL by DB Time
-- - Top Wait Events
-- - Top Sessions
-- - Activity Over Time (timeline)
```

### 2.5 Strumento 3: AWR — "Cosa è successo nelle ultime ore/giorni"

AWR fa una "fotografia" (snapshot) del database ogni 30-60 minuti. Il report AWR confronta 2 snapshot e mostra le differenze.

```sql
-- ═══════════════════════════════════════════════════════════════════
-- QUERY 9: Configurazione AWR
-- ═══════════════════════════════════════════════════════════════════
-- Verifica configurazione attuale
SELECT snap_interval, retention FROM dba_hist_wr_control;
-- Default: snap ogni 60 min, retention 8 giorni

-- Best Practice: snap ogni 30 min, retention 30 giorni
BEGIN
    DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(
        interval  => 30,     -- snapshot ogni 30 minuti
        retention => 43200   -- mantieni 30 giorni (43200 minuti)
    );
END;
/
-- ^^^ In produzione, 30 giorni ti permettono di confrontare
-- le performance di questa settimana con la stessa settimana del mese scorso.

-- Creare un snapshot manuale (prima di un test o intervento)
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();
```

```sql
-- ═══════════════════════════════════════════════════════════════════
-- QUERY 10: Lista snapshot disponibili
-- ═══════════════════════════════════════════════════════════════════
SELECT snap_id,
       TO_CHAR(begin_interval_time, 'DD-MON HH24:MI') AS inizio,
       TO_CHAR(end_interval_time, 'DD-MON HH24:MI') AS fine
FROM dba_hist_snapshot
ORDER BY snap_id DESC
FETCH FIRST 30 ROWS ONLY;
```

### 2.6 Generare e Leggere un Report AWR

```sql
-- Genera il report
@?/rdbms/admin/awrrpt.sql
-- Per RAC (aggregato su tutti i nodi):
@?/rdbms/admin/awrgrpt.sql

-- Ti chiede: formato (html/text), DBID, num_days, begin_snap, end_snap
-- Scegli HTML per grafici leggibili.
```

**Come leggere il report AWR — Le 7 sezioni che contano:**

```
SEZIONE 1: REPORT SUMMARY
═══════════════════════════

  Snap Id       Begin Snap        End Snap          Elapsed    DB Time
  --------      ---------------   ---------------   --------   --------
  1234          07-Apr 14:00      07-Apr 15:00      60.00 min  180.00 min

  INTERPRETAZIONE:
  - Elapsed = 60 min (1 ora di orologio)
  - DB Time = 180 min (il database ha "lavorato" 180 minuti in 1 ora)
  - Rapporto = 180/60 = 3.0
  - Significato: in media, 3 sessioni erano attive contemporaneamente.
  - Se il rapporto fosse 50/60 = 0.83, il database è poco utilizzato.
  - Se il rapporto fosse 500/60 = 8.3, il database è molto carico.

──────────────────────────────────────────────────────────────────────

SEZIONE 2: TOP 5 TIMED FOREGROUND EVENTS  ← LA PIÙ IMPORTANTE!
═══════════════════════════════════════════

  Event                          Waits     Time(s)  % DB time  Wait Class
  ------------------------------ --------- -------- --------- -----------
  db file sequential read        1,245,678 4,500    41.7%     User I/O
  CPU + Wait for CPU                       3,200    29.6%     CPU
  log file sync                  567,890   1,200    11.1%     Commit
  db file scattered read         234,567   800      7.4%     User I/O
  gc buffer busy acquire         89,012    500      4.6%     Cluster

  COME LEGGERE:
  ┌─────────────────────────────────────────────────────────────────┐
  │ 1. "db file sequential read" = 41.7% del tempo                │
  │    → Letture singolo-blocco (indice). Normal se < 30%.         │
  │    → Se alto: query con troppi accessi per indice               │
  │    → O indice non selettivo, o tabella molto grande             │
  │                                                                 │
  │ 2. "CPU" = 29.6%                                               │
  │    → Il database stava calcolando, non aspettando               │
  │    → Normale se non eccessivo. Se > 60% e il sistema rallenta,│
  │      cerca query con troppi logical reads (scansioni in cache). │
  │                                                                 │
  │ 3. "log file sync" = 11.1%                                     │
  │    → Tempo per COMMIT. Ogni COMMIT aspetta che LGWR finisca    │
  │      di scrivere il redo sul disco.                             │
  │    → Se alto: l'applicazione fa troppi COMMIT (es. 1 per riga) │
  │    → O il disco dei redo log è lento.                           │
  │                                                                 │
  │ 4. "db file scattered read" = 7.4%                             │
  │    → Letture multi-blocco (full table scan)                     │
  │    → Se alto: query senza indice o con indice non usato         │
  │    → O la tabella è piccola e Oracle sceglie il full scan       │
  │                                                                 │
  │ 5. "gc buffer busy acquire" = 4.6%                             │
  │    → SOLO IN RAC: contesa per blocchi tra nodi (Cache Fusion)   │
  │    → Un nodo chiede un blocco che un altro nodo sta usando      │
  │    → Se alto: le query fanno DML sulle stesse righe da nodi    │
  │      diversi → soluzione: partizionare servizi                  │
  └─────────────────────────────────────────────────────────────────┘

──────────────────────────────────────────────────────────────────────

SEZIONE 3: SQL ORDERED BY ELAPSED TIME
═══════════════════════════════════════

  Elapsed Time(s)  Executions  Elapsed per Exec(s)  SQL Id
  ---------------  ----------  -------------------  -------------
  2,345            12          195.4                 abc123def456
  1,890            890,000     0.002                 ghi789jkl012

  INTERPRETAZIONE:
  - abc123: 12 esecuzioni × 195 sec ciascuna = query molto lenta
    → VA OTTIMIZZATA (piano, indici, riscrittura)
  - ghi789: 890.000 esecuzioni × 0.002 sec = query veloce ma frequente
    → Il totale (1890s) è alto per il VOLUME non per la lentezza
    → Soluzione: ridurre il numero di esecuzioni (caching, batch)

──────────────────────────────────────────────────────────────────────

SEZIONE 4: SQL ORDERED BY CPU TIME
═══════════════════════════════════
  (Stessa struttura: mostra le query che consumano più CPU)

SEZIONE 5: SQL ORDERED BY GETS (Buffer Gets / Logical Reads)
═════════════════════════════════════════════════════════════
  - "Gets" = letture logiche (dalla buffer cache, senza I/O fisico)
  - Una query con milioni di Gets probabilmente ha un piano subottimale
  - Anche se non fa I/O fisico, consuma CPU per ogni blocco letto

──────────────────────────────────────────────────────────────────────

SEZIONE 6: INSTANCE ACTIVITY STATISTICS (per secondo)
═════════════════════════════════════════════════════

  Statistic                     Per Second    Per Transaction
  ────────────────────────────  ──────────    ───────────────
  physical reads                1,250         42
  physical writes               450           15
  redo size (bytes)              2,500,000     83,333
  user commits                   30            1
  user calls                     5,000         167
  parse count (total)            800           27
  parse count (hard)             5             0.17

  INTERPRETAZIONE:
  - physical reads 1250/s → il database legge 1250 blocchi al secondo
    dal disco. In un database cached, dovrebbe essere basso.
  - parse count (hard) 5/s → 5 hard parse al secondo.
    Hard parse = Oracle compila una nuova query da zero.
    Se alto (>50/s): l'applicazione non usa bind variables!
    → Soluzione: usa bind variables o CURSOR_SHARING=FORCE.

──────────────────────────────────────────────────────────────────────

SEZIONE 7: ADVISORY SECTIONS
═══════════════════════════════

  Buffer Pool Advisory:
    Se la buffer cache fosse 4 GB (attualmente 2 GB),
    le letture fisiche si ridurrebbero del 35%.
    → AZIONE: ALTER SYSTEM SET db_cache_size = 4G;

  PGA Advisory:
    Se il PGA fosse 1 GB (attualmente 512 MB),
    il 95% dei sort passerebbe in memoria.
    → AZIONE: ALTER SYSTEM SET pga_aggregate_target = 1G;
```

### 2.7 AWR Compare Periods — Confrontare "prima" e "dopo"

```sql
-- Genera un report che confronta due periodi
@?/rdbms/admin/awrddrpt.sql
-- Ti chiede: 2 coppie di snap_id (periodo buono vs periodo cattivo)
-- Mostra le DIFFERENZE: quali wait events sono aumentati? Quali SQL?
-- Perfetto per rispondere a: "Cosa è cambiato da ieri?"
```

### 2.8 Strumento 4: ADDM — "Il Consulente Automatico"

ADDM analizza gli snapshot AWR e produce **raccomandazioni** con beneficio stimato.

```sql
-- Genera un report ADDM
@?/rdbms/admin/addmrpt.sql

-- Per RAC (analisi globale su tutti i nodi):
-- Usa il modo "Database" non "Instance" per avere una vista completa.

-- Esempio di output ADDM:
--
-- FINDING 1: SQL statements consuming significant database time were found.
--   RECOMMENDATION 1: SQL Tuning
--     ACTION: Run SQL Tuning Advisor on SQL_ID "abc123def456"
--     BENEFIT: 35% of total DB Time could be saved.
--
-- FINDING 2: Buffer pool was not adequately sized.
--   RECOMMENDATION 2: Increase DB_CACHE_SIZE
--     ACTION: ALTER SYSTEM SET DB_CACHE_SIZE = 4G SCOPE=BOTH;
--     BENEFIT: 8% reduction in physical reads.
--
-- FINDING 3: PGA was over-allocated. Most work areas were in memory.
--   (No action needed - good configuration)
```

---

## PARTE 3: DIAGNOSTICA PRATICA — Scenari Reali

### 3.1 Scenario: "Il database è lento!"

```
MINDSET: "lento" non è una diagnosi. Devi scoprire COSA è lento e PERCHÉ.

STEP 1: "È lento per TUTTI o per UN utente?"
  → SELECT username, status, event, sql_id, seconds_in_wait
    FROM v$session WHERE status = 'ACTIVE' AND username IS NOT NULL;
  → Se TUTTI sono in attesa dello stesso evento → problema sistemico
  → Se solo UNO → è la sua query specifica

STEP 2: "COSA aspettano le sessioni?"
```

```sql
-- Dashboard rapida: "dove il database passa il tempo"
SELECT
    wait_class,
    COUNT(*) AS sessioni,
    '|' || RPAD('█', COUNT(*), '█') AS grafico
FROM v$session
WHERE status = 'ACTIVE'
  AND username IS NOT NULL
  AND wait_class != 'Idle'
GROUP BY wait_class
ORDER BY sessioni DESC;

-- OUTPUT ESEMPIO:
-- WAIT_CLASS     SESSIONI  GRAFICO
-- User I/O       12        |████████████
-- Concurrency    5         |█████
-- CPU            3         |███
-- Network        1         |█
--
-- DIAGNOSI: Il problema è I/O. 12 sessioni aspettano blocchi dal disco.
```

```
STEP 3: Identifica la query colpevole
```

```sql
SELECT
    s.sql_id,
    s.event,
    COUNT(*) AS sessioni,
    sq.sql_text
FROM v$session s
LEFT JOIN v$sql sq ON sq.sql_id = s.sql_id AND sq.child_number = 0
WHERE s.status = 'ACTIVE'
  AND s.username IS NOT NULL
  AND s.wait_class != 'Idle'
GROUP BY s.sql_id, s.event, sq.sql_text
ORDER BY sessioni DESC
FETCH FIRST 5 ROWS ONLY;
```

```
STEP 4: Guarda il piano di esecuzione della query colpevole
```

```sql
-- Piano di esecuzione dalla cache
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('&sql_id'));

-- COME LEGGERE IL PIANO:
--
-- Id | Operation                    | Name         | Rows | Cost
-- ---|------------------------------|--------------|------|-----
--  0 | SELECT STATEMENT             |              |      | 45678
--  1 |  HASH JOIN                   |              | 1000 | 45678
--  2 |   TABLE ACCESS FULL          | ORDERS       | 500K | 40000  ← MALE!
--  3 |   INDEX RANGE SCAN           | PK_CUSTOMER  | 50   | 10
--
-- TRADUZIONE:
-- Linea 2: "TABLE ACCESS FULL" su ORDERS (500K righe) = FULL TABLE SCAN!
-- Oracle sta leggendo TUTTE le 500.000 righe della tabella ORDERS
-- invece di usare un indice per prendere solo quelle che servono.
--
-- AZIONE: Serve un indice sulla colonna usata nel WHERE/JOIN
-- CREATE INDEX idx_orders_date ON ORDERS(ORDER_DATE);
```

### 3.2 Scenario: "Una sessione è bloccata da ore"

```sql
-- STEP 1: Trova chi blocca chi
SELECT
    blocker.sid AS chi_blocca,
    blocker.username AS utente_bloccante,
    blocker.event AS cosa_fa_il_bloccante,
    blocker.sql_id AS query_bloccante,
    (SELECT sql_text FROM v$sql WHERE sql_id = blocker.sql_id AND ROWNUM=1)
        AS testo_query_bloccante,
    victim.sid AS chi_e_bloccato,
    victim.username AS utente_bloccato,
    victim.seconds_in_wait AS da_quanti_secondi,
    victim.sql_id AS query_bloccata
FROM v$session victim
JOIN v$session blocker ON blocker.sid = victim.blocking_session
WHERE victim.blocking_session IS NOT NULL;

-- STEP 2: Decidi cosa fare
-- Se il bloccante è INACTIVE (aspetta il client): qualcuno ha dimenticato
-- di fare COMMIT. Contatta l'utente.
-- Se il bloccante è ACTIVE: sta lavorando su qualcos'altro. Aspetta.
-- Se è urgente: KILL la sessione bloccante.

-- STEP 3: Kill (solo se necessario!)
ALTER SYSTEM KILL SESSION '&blocker_sid,&blocker_serial' IMMEDIATE;
```

### 3.3 Scenario: "Lo spazio sta finendo"

```sql
-- ═══════════════════════════════════════════════════════════════════
-- Tablespace usage
-- ═══════════════════════════════════════════════════════════════════
SELECT
    tablespace_name,
    ROUND(used_percent, 1) AS pct_usato,
    CASE
        WHEN used_percent > 95 THEN '🔴 CRITICO'
        WHEN used_percent > 85 THEN '🟡 WARNING'
        ELSE '🟢 OK'
    END AS stato
FROM dba_tablespace_usage_metrics
ORDER BY used_percent DESC;

-- ═══════════════════════════════════════════════════════════════════
-- ASM disk groups
-- ═══════════════════════════════════════════════════════════════════
SELECT
    name,
    ROUND(total_mb/1024) AS total_gb,
    ROUND(free_mb/1024) AS free_gb,
    ROUND((1 - free_mb/total_mb)*100, 1) AS pct_usato,
    CASE
        WHEN (1 - free_mb/total_mb)*100 > 90 THEN '🔴 CRITICO'
        WHEN (1 - free_mb/total_mb)*100 > 80 THEN '🟡 WARNING'
        ELSE '🟢 OK'
    END AS stato
FROM v$asm_diskgroup;

-- ═══════════════════════════════════════════════════════════════════
-- FRA (Fast Recovery Area)
-- ═══════════════════════════════════════════════════════════════════
SELECT
    file_type,
    ROUND(percent_space_used, 1) AS pct_usato,
    ROUND(percent_space_reclaimable, 1) AS pct_liberabile,
    number_of_files
FROM v$recovery_area_usage
WHERE percent_space_used > 0
ORDER BY percent_space_used DESC;

-- Se FRA è piena (>90%):
-- 1. Cancella backup obsoleti:
--    rman TARGET / <<< "DELETE NOPROMPT OBSOLETE;"
-- 2. Cancella archivelog già applicati allo standby:
--    rman TARGET / <<< "DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-2';"
-- 3. Se non basta, aumenta la FRA:
--    ALTER SYSTEM SET db_recovery_file_dest_size = 25G SCOPE=BOTH SID='*';
```

### 3.4 Scenario: "I commit sono lenti" (log file sync)

```sql
-- DIAGNOSI:
-- "log file sync" alto nel Top 5 Events AWR = OGNI COMMIT aspetta il disco.

-- STEP 1: Verifica il tempo medio di COMMIT
SELECT
    event,
    total_waits,
    ROUND(time_waited_micro/total_waits/1000, 2) AS avg_wait_ms
FROM v$system_event
WHERE event = 'log file sync';
-- avg_wait_ms < 1 ms → perfetto
-- avg_wait_ms 1-5 ms → accettabile
-- avg_wait_ms > 10 ms → problema di I/O dei redo log

-- STEP 2: Verifica il volume di commit
SELECT
    stat_name,
    value
FROM v$sysstat
WHERE stat_name IN ('user commits', 'user rollbacks');
-- Se user commits > 500/sec → l'applicazione fa troppi COMMIT.
-- Soluzione: batch le operazioni (INSERT 1000 righe → 1 COMMIT, non 1000).

-- STEP 3: Verifica le performance del disco redo
SELECT
    group#,
    type,
    member,
    ROUND(bytes/1024/1024) AS size_mb
FROM v$logfile
JOIN v$log USING (group#)
ORDER BY group#;
-- Se i redo log sono piccoli (50 MB) e hai molti log switch:
-- Ingrandisci i redo log a 1-4 GB.
```

### 3.5 Scenario: "Contesa RAC (gc wait events)"

```sql
-- I wait events che iniziano con "gc" sono SPECIFICI di RAC.
-- gc = Global Cache (Cache Fusion)
-- Significano: un nodo chiede un blocco che è nella cache di un altro nodo.

-- STEP 1: Verifica i wait gc aggregati
SELECT
    event,
    total_waits,
    ROUND(time_waited_micro/total_waits/1000, 2) AS avg_wait_ms
FROM v$system_event
WHERE event LIKE 'gc%'
ORDER BY time_waited_micro DESC
FETCH FIRST 10 ROWS ONLY;

-- avg_wait < 1 ms → interconnect veloce, nessun problema
-- avg_wait 1-3 ms → accettabile
-- avg_wait > 5 ms → interconnect saturo o sotto-dimensionato

-- STEP 2: Verifica l'interconnect
SELECT
    inst_id,
    name,
    ip_address,
    is_public
FROM gv$cluster_interconnects;
-- Deve essere la rete privata (192.168.1.x), NON la pubblica!

-- STEP 3: Identifica i "hot objects" (oggetti contesi tra nodi)
SELECT
    current_file#,
    current_block#,
    COUNT(*) AS transfers
FROM gv$cache_transfer
GROUP BY current_file#, current_block#
ORDER BY transfers DESC
FETCH FIRST 10 ROWS ONLY;
-- I blocchi trasferiti più spesso sono "hot blocks".
-- Soluzione: partizionare l'accesso (es. nodo 1 usa servizio OLTP,
-- nodo 2 usa servizio BATCH → non competono per gli stessi blocchi).
```

---

## PARTE 4: SQL TUNING — Ottimizzare le Query

### 4.1 Come Funziona l'Ottimizzatore Oracle (CBO)

```
L'Ottimizzatore (Cost-Based Optimizer, CBO) decide COME eseguire una query.

Per ogni query, considera:
  - Quali tabelle sono coinvolte
  - Quali indici esistono
  - Le statistiche sulle tabelle (quante righe, distribuzione dati)
  - I parametri del database (memory, CPU, I/O cost)

E produce un PIANO DI ESECUZIONE: la sequenza di operazioni
(full scan, index scan, hash join, ecc.) che ritiene più efficiente.

SE LE STATISTICHE SONO VECCHIE O MANCANTI:
  Il CBO prende decisioni sbagliate → piani pessimi → query lente!

Soluzione: assicurati che le statistiche siano aggiornate.
```

```sql
-- ═══════════════════════════════════════════════════════════════════
-- Verifica quando sono state raccolte le statistiche
-- ═══════════════════════════════════════════════════════════════════
SELECT
    owner,
    table_name,
    num_rows,
    TO_CHAR(last_analyzed, 'DD-MON-YYYY HH24:MI') AS ultimo_analyze,
    stale_stats  -- YES = le statistiche sono vecchie!
FROM dba_tab_statistics
WHERE owner IN ('HR', 'APP')
  AND stale_stats = 'YES';

-- Se stale_stats = YES → raccogli le statistiche!
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('HR');
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('APP');

-- Per una tabella specifica con isterogrammi:
EXEC DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'HR',
    tabname => 'EMPLOYEES',
    method_opt => 'FOR ALL COLUMNS SIZE AUTO',
    cascade => TRUE  -- aggiorna anche le statistiche degli indici
);
```

### 4.2 SQL Tuning Advisor

```sql
-- STEP 1: Crea un task di tuning per una query problematica
DECLARE
    l_task VARCHAR2(100);
BEGIN
    l_task := DBMS_SQLTUNE.CREATE_TUNING_TASK(
        sql_id      => '&sql_id',              -- SQL_ID dalla v$sql o AWR
        scope       => DBMS_SQLTUNE.SCOPE_COMPREHENSIVE,
        time_limit  => 300,                     -- max 5 minuti di analisi
        task_name   => 'TUNE_' || '&sql_id'
    );
    DBMS_SQLTUNE.EXECUTE_TUNING_TASK(task_name => l_task);
END;
/

-- STEP 2: Leggi le raccomandazioni
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('TUNE_&sql_id') AS report FROM dual;

-- ESEMPIO DI OUTPUT:
-- ─────────────────────────────────────────────────
-- FINDING: La query esegue un Full Table Scan su HR.ORDERS
--          che contiene 2.500.000 righe.
--
-- RECOMMENDATION: Creare il seguente indice:
--   CREATE INDEX HR.IDX_ORDERS_CUST_DATE
--   ON HR.ORDERS(CUSTOMER_ID, ORDER_DATE);
--
-- RATIONALE: Con questo indice, la query leggerebbe
--   250 blocchi invece di 350.000 blocchi.
--   Estimated benefit: 99.9% reduction in elapsed time.
--
-- ALTERNATIVE: Accettare il seguente SQL Profile:
--   EXEC DBMS_SQLTUNE.ACCEPT_SQL_PROFILE(task_name => 'TUNE_abc123');
-- ─────────────────────────────────────────────────
```

### 4.3 Operazioni del Piano di Esecuzione — Cheat Sheet

```
OPERAZIONE                          SIGNIFICATO          BUONO/MALE?
────────────────────────────────────────────────────────────────────
TABLE ACCESS FULL                   Full Table Scan      🟡 Dipende
  → Scansiona TUTTA la tabella.
  → Buono su tabelle piccole (<1000 righe).
  → Male su tabelle grandi senza filtro selettivo.

TABLE ACCESS BY INDEX ROWID         Accesso per indice   🟢 Generalmente OK
  → Usa l'indice per trovare la riga.

INDEX UNIQUE SCAN                   Indice univoco       🟢 Perfetto
  → Trova esattamente 1 riga via PK/UK.

INDEX RANGE SCAN                    Scansione range      🟢 Generalmente OK
  → Trova un range di righe via indice.
  → Diventa male se il range è troppo grande (bassa selettività).

INDEX FULL SCAN                     Scan completo indice 🟡 Dipende
  → Legge tutto l'indice in ordine.
  → Usato per ORDER BY senza full scan.

INDEX FAST FULL SCAN                Scan parallelo indice 🟡 Dipende
  → Legge tutto l'indice, non in ordine.
  → Usato quando tutte le colonne sono nell'indice.

HASH JOIN                           Join con hash        🟢 OK per join grandi
  → Costruisce una hash table della tabella piccola,
    poi scansiona la tabella grande.

NESTED LOOPS                        Loop annidato        🟢 OK per poche righe
  → Per ogni riga della tabella esterna,
    cerca nella tabella interna (via indice).
  → Male se la tabella esterna ha molte righe.

SORT MERGE JOIN                     Join con ordinamento 🟡 Dipende
  → Ordina entrambe le tabelle, poi le unisce.
  → Costoso in memoria se le tabelle sono grandi.

SORT ORDER BY                       Ordinamento          🟡 Attenzione
  → Se il sort è grande, Oracle usa il disco (temp tablespace).

FILTER                              Filtro               🟡 Controlla
  → Può nascondere subquery correlate costose.
```

---

## PARTE 5: MONITORING PROATTIVO — Script da Schedulare

### 5.1 Script di Health Check Giornaliero

```sql
-- Salva come: /home/oracle/scripts/daily_health_check.sql
-- Esegui con: sqlplus -s / as sysdba @daily_health_check.sql

SET PAGESIZE 100
SET LINESIZE 200
SET FEEDBACK OFF

PROMPT
PROMPT === DATABASE STATUS ===
SELECT name, open_mode, database_role, db_unique_name FROM v$database;

PROMPT
PROMPT === ISTANZE RAC ===
SELECT inst_id, instance_name, host_name, status, startup_time
FROM gv$instance ORDER BY inst_id;

PROMPT
PROMPT === TABLESPACE USAGE (>80%) ===
SELECT tablespace_name, ROUND(used_percent, 1) AS pct_used
FROM dba_tablespace_usage_metrics
WHERE used_percent > 80 ORDER BY used_percent DESC;

PROMPT
PROMPT === ASM DISK GROUPS ===
SELECT name, ROUND(total_mb/1024) AS gb_tot,
       ROUND(free_mb/1024) AS gb_free,
       ROUND((1-free_mb/total_mb)*100,1) AS pct_used
FROM v$asm_diskgroup;

PROMPT
PROMPT === FRA USAGE ===
SELECT file_type, ROUND(percent_space_used,1) AS pct_used,
       number_of_files
FROM v$recovery_area_usage WHERE percent_space_used > 0;

PROMPT
PROMPT === DATA GUARD STATUS ===
SELECT database_role, protection_mode,
       (SELECT value FROM v$dataguard_stats WHERE name = 'transport lag') AS transport_lag,
       (SELECT value FROM v$dataguard_stats WHERE name = 'apply lag') AS apply_lag
FROM v$database;

PROMPT
PROMPT === ULTIMO BACKUP ===
SELECT input_type, status,
       TO_CHAR(start_time, 'DD-MON HH24:MI') AS start_time,
       TO_CHAR(end_time, 'DD-MON HH24:MI') AS end_time
FROM v$rman_backup_job_details
ORDER BY start_time DESC FETCH FIRST 5 ROWS ONLY;

PROMPT
PROMPT === SESSIONI BLOCCANTI ===
SELECT s.sid, s.serial#, s.username, s.event,
       s.seconds_in_wait, s.blocking_session
FROM v$session s
WHERE s.blocking_session IS NOT NULL;

PROMPT
PROMPT === ALERT LOG (ultime 20 righe con errori) ===
SELECT originating_timestamp, message_text
FROM v$diag_alert_ext
WHERE message_text LIKE '%ORA-%'
  AND originating_timestamp > SYSDATE - 1
ORDER BY originating_timestamp DESC
FETCH FIRST 20 ROWS ONLY;

EXIT;
```

### 5.2 Crontab per Health Check Automatico

```bash
# In crontab di oracle (crontab -e):
# Health check giornaliero alle 07:00
0 7 * * * /home/oracle/scripts/run_health_check.sh

# Script wrapper:
cat > /home/oracle/scripts/run_health_check.sh <<'EOF'
#!/bin/bash
source /home/oracle/.db_env
LOG=/home/oracle/scripts/logs/health_$(date +%Y%m%d).log
sqlplus -s / as sysdba @/home/oracle/scripts/daily_health_check.sql > $LOG 2>&1
# Invia email se ci sono errori
grep -q "ORA-\|CRITICO\|FAILED" $LOG && \
  mail -s "⚠️ Oracle Health Check Alert" dba@company.com < $LOG
EOF
chmod +x /home/oracle/scripts/run_health_check.sh
```

---

## PARTE 6: CHECKLIST OPERATIVA

### Checklist Giornaliera (5 minuti)

```
□ Alert log: ci sono nuovi ORA-errors?
  → adrci ; SHOW ALERT -tail 50
□ Tablespace: qualcuno supera 85%?
  → SELECT tablespace_name, used_percent FROM dba_tablespace_usage_metrics
□ FRA: è sotto il 90%?
  → SELECT * FROM v$recovery_area_usage
□ Backup: l'ultimo è SUCCESS?
  → SELECT * FROM v$rman_backup_job_details ORDER BY start_time DESC
□ Data Guard: apply lag < 10 min?
  → SELECT * FROM v$dataguard_stats
□ Sessioni bloccanti: ci sono lock > 5 min?
  → SELECT * FROM v$session WHERE blocking_session IS NOT NULL
```

### Checklist Settimanale (30 minuti)

```
□ AWR report: i Top 5 Events sono cambiati rispetto alla settimana scorsa?
□ ADDM report: ci sono nuove raccomandazioni?
□ ASM disk groups: spazio libero > 20%?
□ Redo log switch: frequenza normale (meno di 1 ogni 15 minuti)?
□ Invalid objects: ce ne sono di nuovi?
  → SELECT owner, object_name, object_type FROM dba_objects
    WHERE status = 'INVALID' ORDER BY owner, object_type;
□ Statistiche tabelle: ci sono tabelle con stale_stats = YES?
```

### Checklist Mensile (2 ore)

```
□ AWR Compare Periods: confronto con il mese scorso
□ Capacità: trend spazio disco negli ultimi 30 giorni
□ Test recovery: almeno 1 RESTORE VALIDATE
□ Patch review: ci sono nuove patch critiche su MOS?
□ Pulizia: archivelog, trace files, core dump
```

---

## PARTE 7: DIZIONARIO RAPIDO DEI WAIT EVENTS

| Wait Event | Wait Class | Cosa Significa | Azione |
|-----------|-----------|---------------|--------|
| `db file sequential read` | User I/O | Lettura singolo blocco (indice) | Verificare piano SQL, aggiungere indici |
| `db file scattered read` | User I/O | Full table scan multi-blocco | Serve un indice o la query va riscritta |
| `log file sync` | Commit | Attesa conferma COMMIT su disco | Ridurre frequenza commit o velocizzare disco redo |
| `log file parallel write` | System I/O | LGWR scrive redo su disco | Velocizzare disco redo |
| `buffer busy waits` | Concurrency | Due sessioni vogliono lo stesso blocco | Hot block: partizionare dati o hash cluster |
| `enq: TX - row lock contention` | Application | Lock a livello di riga | Trovare la sessione bloccante e investigare |
| `enq: TM - contention` | Application | Lock a livello di tabella | Verificare DDL o foreign key senza indice |
| `cursor: pin S wait on X` | Concurrency | Contesa per parsing di query | Usare bind variables! |
| `latch: shared pool` | Concurrency | Contesa nello shared pool | Parse eccessivo, usare bind variables |
| `latch: cache buffers chains` | Concurrency | Hot block nella buffer cache | Identificare e partizionare hot block |
| `gc buffer busy acquire` | Cluster (RAC) | Blocco conteso tra nodi RAC | Partizionare servizi tra nodi |
| `gc cr multi block request` | Cluster (RAC) | RAC: richiesta multi-blocco cross-nodo | Ridurre full scan cross-nodo |
| `gc current block busy` | Cluster (RAC) | RAC: blocco in modifica su altro nodo | Evitare DML concorrente sugli stessi dati |
| `direct path read` | User I/O | Lettura diretta (bypass cache) | Normale per sort/parallel query |
| `direct path write temp` | User I/O | Scrittura su temp tablespace | Sort/hash join grande, aumentare PGA |
| `read by other session` | User I/O | Un'altra sessione sta già leggendo quel blocco | Transitorio, normalmente non è un problema |
| `SQL*Net message from client` | **Idle** | **IGNORA!** Client non sta inviando query | Nessuna — è IDLE |
| `SQL*Net message to client` | Network | Invio risultati al client lento | Rete lenta o client lento |

---

## PARTE 8: DOVE TROVARE I LOG

```bash
# ═══════════════════════════════════════════════════════════════════
# ALERT LOG — IL FILE PIÙ IMPORTANTE DEL DATABASE
# ═══════════════════════════════════════════════════════════════════
# Contiene: startup/shutdown, errori ORA, switch redo log, checkpoint.
# Controllalo OGNI GIORNO.

# Metodo 1: Con ADRCI (il modo moderno)
adrci
SHOW ALERT -tail 100
# ^^^ Mostra le ultime 100 righe dell'alert log.

# Metodo 2: Direttamente il file
tail -200 $ORACLE_BASE/diag/rdbms/racdb/RACDB1/trace/alert_RACDB1.log

# Metodo 3: Da SQL (più filtrato)
SELECT originating_timestamp, message_text
FROM v$diag_alert_ext
WHERE originating_timestamp > SYSDATE - 1
  AND (message_text LIKE '%ORA-%' OR message_text LIKE '%error%')
ORDER BY originating_timestamp DESC;

# ═══════════════════════════════════════════════════════════════════
# TRACE FILES — Dettagli di un errore specifico
# ═══════════════════════════════════════════════════════════════════
# Quando Oracle ha un ORA-600 o un errore grave, scrive un trace file.
# L'alert log dice DOVE è il trace file.

# Trovare la directory dei trace:
SELECT value FROM v$diag_info WHERE name = 'Diag Trace';
# Output: /u01/app/oracle/diag/rdbms/racdb/RACDB1/trace/

# Trovare il trace file di una sessione specifica:
SELECT value FROM v$diag_info WHERE name = 'Default Trace File';

# ═══════════════════════════════════════════════════════════════════
# LOG CRS / GRID INFRASTRUCTURE
# ═══════════════════════════════════════════════════════════════════
# Problemi di cluster: nodo evicted, VIP non migra, ecc.
tail -100 /u01/app/19.0.0/grid/log/$(hostname)/alert$(hostname).log
# CSSD (membership):
tail -100 /u01/app/19.0.0/grid/log/$(hostname)/ocssd/ocssd.log
# CRSD (risorse):
tail -100 /u01/app/19.0.0/grid/log/$(hostname)/crsd/crsd.log
```

---

## PARTE 9: FONTI ORACLE UFFICIALI

### Documentazione Oracle 19c
- **Performance Tuning Guide** (LA bibbia del tuning): https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/
- **Wait Events Reference** (tutti i wait events spiegati): https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/database-wait-events-statistics.html
- **AWR & ADDM**: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/automatic-performance-diagnostics.html
- **ASH**: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/active-session-history.html
- **SQL Tuning Guide**: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/
- **RAC Performance Tuning**: https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/configuring-recovery-manager-and-archiving.html

### Letture Consigliate
- Oracle Database Performance Tuning Guide, Chapter 5: "Gathering Diagnostic Data" → spiega il metodo top-down
- Oracle Database Performance Tuning Guide, Chapter 7: "Resolving Transient Performance Problems" → ASH
- Oracle Database 2 Day + Performance Tuning Guide → versione semplificata per principianti
