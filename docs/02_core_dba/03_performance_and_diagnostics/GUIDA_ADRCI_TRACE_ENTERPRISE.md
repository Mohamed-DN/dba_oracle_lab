# Guida ADRCI & Diagnostica Oracle Enterprise — Il Riferimento Definitivo

## Obiettivo operativo

Raccogliere diagnostica ADR e trace minimizzando impatto e perdita di evidenze.

## Procedura operativa

Identifica ADR home, finestra temporale e incidente; abilita trace mirato e disabilitalo appena raccolto.

## Validazione finale

Conserva alert log, incident package, trace e timeline nel ticket.

## Troubleshooting rapido

Se manca il trace atteso, controlla ADR home, privilegi, sessione target e finestra di raccolta.


> Guida operativa completa per ADRCI, Alert Log, Trace File, SQL Trace, TKPROF,
> Oradebug, Hanganalyze, Incident Management e IPS in ambienti Oracle 19c/21c/23ai.
>
> Copre Single Instance, RAC, Data Guard, ASM, Listener e Clusterware.
>
> **Target audience**: DBA Oracle in ambienti enterprise di produzione.

---

## PARTE I — ARCHITETTURA E NAVIGAZIONE ADR

---

## 1. Architettura ADR (Automatic Diagnostic Repository)

### 1.1 Cos'e ADR

ADR e un repository diagnostico file-based, gerarchico e indipendente dal database.
Funziona anche quando il database e DOWN — fondamentale per diagnosticare crash e hang.
Introdotto in Oracle 11g, e il framework standard per tutta la diagnostica Oracle.

### 1.2 Struttura Directory Completa

Path base: `$ORACLE_BASE/diag/`

```
$ORACLE_BASE/diag/
|
+-- rdbms/<db_unique_name>/<instance>/     # Database Instance
|   +-- alert/          # Alert log XML (log.xml) + testo (alert_SID.log)
|   +-- trace/          # File .trc e .trm (background processes + user sessions)
|   +-- incident/       # Incident dumps organizzati per incdir_N/
|   +-- incpkg/         # Incident packages generati con IPS
|   +-- cdump/          # Core dumps (crash OS-level)
|   +-- hm/             # Health Monitor reports e findings
|   +-- metadata/       # Metadata diagnostici interni
|   +-- sweep/          # Dati purgati in attesa di rimozione
|   +-- ir/             # Incident reports
|   +-- lck/            # Lock files interni ADR
|
+-- asm/+asm/<+ASM_instance>/              # ASM Instance
|   +-- alert/
|   +-- trace/
|   +-- incident/
|
+-- tnslsnr/<hostname>/<listener_name>/    # Listener
|   +-- alert/
|   +-- trace/
|
+-- crs/<hostname>/crs/                    # Clusterware (Grid Infrastructure)
|   +-- alert/
|   +-- trace/
|
+-- clients/<hostname>/user_oracle/        # Client diagnostics
|
+-- asmtool/<hostname>/asmtool/            # ASM tools
```

### 1.3 Identificare il Diagnostic Dest

```sql
-- Parametro di inizializzazione
SHOW PARAMETER diagnostic_dest;

-- Tutte le informazioni diagnostiche dell'istanza corrente
SELECT name, value FROM v$diag_info ORDER BY name;
```

Output chiave da `v$diag_info`:

| Name | Descrizione | Esempio |
|---|---|---|
| ADR Base | Root di tutti gli ADR Home | /u01/app/oracle |
| ADR Home | Home specifico dell'istanza | /u01/app/oracle/diag/rdbms/prod/prod1 |
| Diag Trace | Directory dei .trc | .../trace |
| Diag Alert | Directory dell'alert log | .../alert |
| Diag Incident | Directory degli incident | .../incident |
| Default Trace File | Trace file della sessione corrente | .../trace/prod1_ora_12345.trc |

### 1.4 Naming Convention dei Trace File

```
<SID>_<process>_<PID>.trc     -- Trace file
<SID>_<process>_<PID>.trm     -- Metadata del trace (dimensioni ridotte)
```

Esempi:
- `prod1_ora_12345.trc` — Sessione utente (server process), PID 12345
- `prod1_dbrm_5678.trc` — Database Resource Manager
- `prod1_lgwr_9012.trc` — Log Writer
- `prod1_smon_3456.trc` — System Monitor
- `prod1_pmon_7890.trc` — Process Monitor
- `prod1_arc0_1111.trc` — Archiver processo 0
- `prod1_mmon_2222.trc` — Manageability Monitor (AWR snapshots)
- `prod1_mman_3333.trc` — Memory Manager
- `prod1_reco_4444.trc` — Recoverer (distributed transactions)
- `prod1_j000_5555.trc` — Job Queue processo 0

---

## 2. ADRCI — Navigazione e Comandi

### 2.1 Avvio e Selezione Home

```bash
# Avvia ADRCI
adrci

# Mostra la base directory
adrci> show base

# Lista TUTTI gli ADR Home disponibili
adrci> show homes

# Output tipico in ambiente RAC con DG:
# diag/rdbms/prod/prod1        (Database nodo 1)
# diag/rdbms/prod/prod2        (Database nodo 2)
# diag/asm/+asm/+ASM1          (ASM nodo 1)
# diag/asm/+asm/+ASM2          (ASM nodo 2)
# diag/tnslsnr/node1/listener  (Listener nodo 1)
# diag/tnslsnr/node2/listener  (Listener nodo 2)
# diag/crs/node1/crs           (CRS nodo 1)

# Seleziona l'home del database
adrci> set homepath diag/rdbms/prod/prod1

# Verifica selezione
adrci> show homepath
```

### 2.2 Alert Log — Lettura e Filtro

```text
-- Live tail (equivalente a tail -f)
adrci> show alert -tail -f

-- Ultimi N messaggi
adrci> show alert -tail 100
adrci> show alert -tail 500

-- Filtra per QUALSIASI errore ORA-
adrci> show alert -p "message_text like '%ORA-%'"

-- Filtra per errore specifico
adrci> show alert -p "message_text like '%ORA-00600%'"
adrci> show alert -p "message_text like '%ORA-07445%'"
adrci> show alert -p "message_text like '%ORA-04031%'"
adrci> show alert -p "message_text like '%ORA-01578%'"

-- Filtra per finestra temporale (ultimo giorno)
adrci> show alert -p "originating_timestamp > systimestamp - 1"

-- Filtra per intervallo specifico
adrci> show alert -p "originating_timestamp between
  TO_TIMESTAMP('2026-05-14 08:00:00','YYYY-MM-DD HH24:MI:SS') and
  TO_TIMESTAMP('2026-05-14 12:00:00','YYYY-MM-DD HH24:MI:SS')"

-- Filtra per testo generico
adrci> show alert -p "message_text like '%shutdown%'"
adrci> show alert -p "message_text like '%checkpoint%'"
adrci> show alert -p "message_text like '%Archived Log%'"

-- Combinazione di filtri
adrci> show alert -p "message_text like '%ORA-%' and
  originating_timestamp > systimestamp - 7"
```


### 2.3 Alert Log — Parsing da Shell (per scripting e monitoring)

```bash
# Path diretto all'alert log testo
ALERT_LOG=$ORACLE_BASE/diag/rdbms/$DB_UNIQUE_NAME/$ORACLE_SID/trace/alert_$ORACLE_SID.log

# Ultimi 100 errori ORA-
grep -i 'ORA-' $ALERT_LOG | tail -100

# Errori con contesto (2 righe prima e dopo)
grep -B2 -A2 'ORA-' $ALERT_LOG | tail -200

# Cerca startup/shutdown
grep -E 'Starting ORACLE|shutting down|ALTER DATABASE' $ALERT_LOG | tail -20

# Monitoring continuo con highlight errori
tail -f $ALERT_LOG | grep --color=always -E 'ORA-|RMAN-|WARNING|ERROR|^'
```

### 2.4 Trace File — Ricerca e Analisi

```text
-- Lista tutti i trace file
adrci> show tracefile

-- Filtra per PID
adrci> show tracefile -p "trace_filename like '%ora_12345%'"

-- Filtra per processo background
adrci> show tracefile -p "trace_filename like '%lgwr%'"
adrci> show tracefile -p "trace_filename like '%smon%'"

-- Apri un trace file
adrci> show tracefile -t prod1_ora_12345.trc
```

### 2.5 Mapping Sessione -> Trace File (SQL)

```sql
-- Trace file per un SID specifico
SELECT s.sid, s.serial#, s.username, s.program, s.status,
       p.spid AS os_pid, p.tracefile
FROM v$session s
JOIN v$process p ON s.paddr = p.addr
WHERE s.sid = &sid;

-- Trace file per TUTTE le sessioni attive
SELECT s.sid, s.serial#, s.username, s.status, s.sql_id,
       p.spid AS os_pid, p.tracefile
FROM v$session s
JOIN v$process p ON s.paddr = p.addr
WHERE s.status = 'ACTIVE' AND s.type != 'BACKGROUND'
ORDER BY s.sid;

-- Trace file per processi background
SELECT s.sid, s.paddr, p.spid, p.program, p.tracefile
FROM v$session s
JOIN v$process p ON s.paddr = p.addr
WHERE s.type = 'BACKGROUND'
ORDER BY p.program;

-- Impostare un identificatore per il trace
ALTER SESSION SET tracefile_identifier = 'MY_DEBUG_SESSION';
```

---

## PARTE II — SQL TRACE, TKPROF E EVENT DIAGNOSTICI

---

## 3. SQL Trace (10046 Event)

### 3.1 Abilitare SQL Trace — Tutti i Metodi

```sql
-- METODO 1: ALTER SESSION (sessione corrente)
ALTER SESSION SET sql_trace = TRUE;
ALTER SESSION SET sql_trace = FALSE;

-- METODO 2: Con identificatore (RACCOMANDATO)
ALTER SESSION SET tracefile_identifier = 'SLOW_QUERY_ANALYSIS';
ALTER SESSION SET sql_trace = TRUE;

-- METODO 3: DBMS_MONITOR (su ALTRA sessione)
EXEC DBMS_MONITOR.SESSION_TRACE_ENABLE(
  session_id  => 123,
  serial_num  => 456,
  waits       => TRUE,
  binds       => TRUE
);
EXEC DBMS_MONITOR.SESSION_TRACE_DISABLE(
  session_id  => 123,
  serial_num  => 456
);

-- METODO 4: DBMS_MONITOR per SERVICE/MODULE/ACTION
EXEC DBMS_MONITOR.SERV_MOD_ACT_TRACE_ENABLE(
  service_name => 'HR_APP',
  module_name  => DBMS_MONITOR.ALL_MODULES,
  action_name  => DBMS_MONITOR.ALL_ACTIONS,
  waits        => TRUE,
  binds        => TRUE
);
EXEC DBMS_MONITOR.SERV_MOD_ACT_TRACE_DISABLE(
  service_name => 'HR_APP'
);

-- METODO 5: DBMS_SESSION
EXEC DBMS_SESSION.SESSION_TRACE_ENABLE(waits => TRUE, binds => TRUE);
EXEC DBMS_SESSION.SESSION_TRACE_DISABLE;
```

### 3.2 Event 10046 (Trace Dettagliato con Livelli)

```sql
-- Level 1: Solo SQL statements (come sql_trace=TRUE)
ALTER SESSION SET EVENTS '10046 trace name context forever, level 1';

-- Level 4: + Bind variables
ALTER SESSION SET EVENTS '10046 trace name context forever, level 4';

-- Level 8: + Wait events
ALTER SESSION SET EVENTS '10046 trace name context forever, level 8';

-- Level 12: Bind + Wait (IL PIU COMPLETO — usa questo)
ALTER SESSION SET EVENTS '10046 trace name context forever, level 12';

-- Disabilitare
ALTER SESSION SET EVENTS '10046 trace name context off';

-- Su un'altra sessione tramite ORADEBUG
ORADEBUG SETOSPID 12345;
ORADEBUG EVENT 10046 trace name context forever, level 12;
-- Disabilita:
ORADEBUG EVENT 10046 trace name context off;
```

| Livello | Contenuto | Quando Usarlo |
|---|---|---|
| 1 | SQL text, parse, exec, fetch | Analisi base |
| 4 | + Bind variables | Quando serve sapere i valori dei parametri |
| 8 | + Wait events | Quando serve capire DOVE il tempo e speso |
| 12 | Bind + Wait | **Default raccomandato per troubleshooting** |

### 3.3 Event 10053 (Optimizer Trace)

Per capire PERCHE l'optimizer sceglie un piano di esecuzione specifico:

```sql
-- Abilita trace optimizer
ALTER SESSION SET EVENTS '10053 trace name context forever, level 1';

-- Esegui la query da analizzare
SELECT /*+ GATHER_PLAN_STATISTICS */ * FROM hr.employees WHERE department_id = 10;

-- Disabilita
ALTER SESSION SET EVENTS '10053 trace name context off';

-- Il trace file contiene:
-- - Parametri dell'optimizer
-- - Statistiche delle tabelle/indici considerate
-- - Access path analysis
-- - Join order evaluation
-- - Cost calculations per ogni piano candidato
-- - Piano finale scelto e perche
```

> **NOTA**: Il trace 10053 genera file MOLTO grandi. Usalo solo per query specifiche,
> mai in modo generico su tutte le sessioni.

### 3.4 TKPROF — Processare il Trace File

```bash
# Sintassi base
tkprof input.trc output.txt

# Con ordinamento per elapsed time (RACCOMANDATO)
tkprof prod1_ora_12345.trc /tmp/report.txt \
  sort=exeela,fchela,prsela \
  explain=/@PROD \
  sys=no \
  aggregate=yes \
  waits=yes

# Parametri importanti:
# sort=exeela    -> ordina per execute elapsed time
# sort=fchela    -> ordina per fetch elapsed time
# sort=prsela    -> ordina per parse elapsed time
# explain=       -> aggiunge execution plan
# sys=no         -> esclude query SYS (recursive SQL)
# aggregate=yes  -> raggruppa statement identici
# waits=yes      -> include wait events
# print=20       -> mostra solo top 20 statements
# record=out.sql -> salva SQL statements in file separato
```

**Come leggere l'output TKPROF:**
```
call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute      1      0.00       0.00          0          0          0           0
Fetch      101      1.20       3.45        500       2000          0       10000
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total      103      1.20       3.45        500       2000          0       10000

# cpu:     tempo CPU in secondi
# elapsed: tempo totale (CPU + wait)
# disk:    blocchi letti da disco (physical reads)
# query:   blocchi letti da buffer cache (consistent gets)
# current: blocchi letti in current mode (per DML)
# rows:    righe processate
```


---

## 4. ORADEBUG — Diagnostica Avanzata

### 4.1 Comandi Fondamentali

```sql
-- Connettiti come SYSDBA
-- ORADEBUG funziona SOLO da SQL*Plus con SYSDBA

-- Attach al processo corrente
ORADEBUG SETMYPID;

-- Attach a un processo tramite OS PID
ORADEBUG SETOSPID 12345;

-- Attach a un processo tramite Oracle PID
ORADEBUG SETORAPID 42;

-- Mostra il nome del trace file corrente
ORADEBUG TRACEFILE_NAME;

-- Abilitare trace 10046 su un processo
ORADEBUG EVENT 10046 trace name context forever, level 12;
ORADEBUG EVENT 10046 trace name context off;

-- Flush il trace file su disco
ORADEBUG FLUSH;

-- Disconnetti dal processo
ORADEBUG CLOSE_TRACE;
```

### 4.2 Hanganalyze — Diagnostica Database Hang

Quando il database sembra "bloccato" e le sessioni non rispondono:

```sql
-- REGOLA: Esegui 3 volte con 30 secondi di intervallo
-- per distinguere processi "bloccati" da processi "lenti"

ORADEBUG SETMYPID;

-- Livello 3: mostra la catena di blocchi
ORADEBUG HANGANALYZE 3;

-- Aspetta 30 secondi
-- HOST sleep 30;  (o aspetta manualmente)

ORADEBUG HANGANALYZE 3;

-- Aspetta 30 secondi

ORADEBUG HANGANALYZE 3;

ORADEBUG TRACEFILE_NAME;
-- Leggi il trace file per la chain analysis
```

**Livelli Hanganalyze:**

| Livello | Descrizione |
|---|---|
| 1 | Solo processi in attesa |
| 3 | Processi + catena di blocchi (RACCOMANDATO) |
| 10 | Dump completo di tutti i processi (genera file enormi) |

**Come leggere l'output:**
```
Chain 1:
  Oracle session identified by:
    {sid: 100, serial: 12345, inst: 1}
    is waiting for 'enq: TX - row lock contention'
    and is blocked by
    {sid: 200, serial: 67890, inst: 1}
    which is waiting for 'log file sync'
```

### 4.3 Systemstate Dump — Snapshot Completo

Per un'analisi completa dello stato del database:

```sql
ORADEBUG SETMYPID;

-- Level 266: include short stack per ogni processo (RACCOMANDATO)
ORADEBUG DUMP SYSTEMSTATE 266;

-- Aspetta 30 secondi
ORADEBUG DUMP SYSTEMSTATE 266;

-- Aspetta 30 secondi  
ORADEBUG DUMP SYSTEMSTATE 266;

ORADEBUG TRACEFILE_NAME;
```

> **ATTENZIONE**: Systemstate dump level 266 puo generare file di centinaia di MB
> su database con molte sessioni. Usare con cautela in produzione.

### 4.4 Altri Dump Utili

```sql
-- Error stack (quando una sessione ha un errore)
ORADEBUG DUMP ERRORSTACK 3;

-- Process state (singolo processo)
ORADEBUG DUMP PROCESSSTATE 10;

-- Redo log dump
ORADEBUG DUMP REDOHDR 2;

-- Controlfile dump
ORADEBUG DUMP CONTROLF 10;

-- Library cache dump (per problemi di hard parse)
ORADEBUG DUMP LIBRARY_CACHE 10;
```

### 4.5 RAC: Hanganalyze/Systemstate su Tutti i Nodi

```sql
-- In RAC, esegui su TUTTI i nodi contemporaneamente
ORADEBUG SETMYPID;

-- Cluster-wide hanganalyze
ORADEBUG -G ALL HANGANALYZE 3;

-- Cluster-wide systemstate
ORADEBUG -G ALL DUMP SYSTEMSTATE 266;
```

---

## PARTE III — INCIDENT MANAGEMENT E IPS

---

## 5. Incident e Problem Management

### 5.1 Concetti Fondamentali

- **Problem**: La "firma" di un errore (es. "ORA 600 [12345]"). Ha un `problem_key`.
- **Incident**: Una singola occorrenza del problem. Ha un `incident_id` univoco.
- **Flood Control**: Oracle limita automaticamente la creazione di incident
  per lo stesso problem (max 5 in un'ora) per evitare disk full.
- **ADR Purge**: Gli incident vengono automaticamente purgati secondo la LONGP_POLICY.

### 5.2 Visualizzare Problem e Incident

```text
-- Lista problemi (summary)
adrci> show problem

-- Problemi con dettaglio
adrci> show problem -mode detail

-- Lista incidenti
adrci> show incident

-- Incidenti con dettaglio completo
adrci> show incident -mode detail

-- Filtra per ID specifico
adrci> show incident -p "incident_id = 98765"

-- Filtra per errore
adrci> show problem -p "problem_key like '%ORA 600%'"
adrci> show incident -p "problem_key like '%ORA 7445%'"
adrci> show incident -p "problem_key like '%ORA 4031%'"

-- Filtra per finestra temporale
adrci> show incident -p "incident_time > systimestamp - 1"
adrci> show incident -p "incident_time > systimestamp - 7"

-- Conta incident per problem
adrci> show problem -p "lastinc_time > systimestamp - 30"
```

### 5.3 SQL per Incident Analysis

```sql
-- Problemi diagnostici recenti
SELECT problem_id, problem_key, first_incident, last_incident, 
       impact1, impact2, impact3, impact4
FROM v$diag_problem
ORDER BY last_incident DESC;

-- Incidenti recenti con dettaglio
SELECT incident_id, problem_id, 
       TO_CHAR(create_time,'DD-MON HH24:MI:SS') AS created,
       status, error_facility, error_number, error_arg
FROM v$diag_incident
WHERE create_time > SYSDATE - 7
ORDER BY create_time DESC;

-- Alert log entries recenti
SELECT TO_CHAR(originating_timestamp,'DD-MON HH24:MI:SS') AS ts,
       message_text
FROM v$diag_alert_ext
WHERE originating_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
  AND message_text LIKE '%ORA-%'
ORDER BY originating_timestamp DESC;
```

### 5.4 Creazione IPS Package per Oracle Support

Quando apri una Service Request (SR), DEVI allegare un IPS package:

```text
-- 1. Crea package logico dall'incident
adrci> ips create package incident 98765
-- Output: Created package 1 based on incident id 98765, correlation level typical

-- 2. Oppure da un problem
adrci> ips create package problem 42

-- 3. Oppure da un intervallo temporale
adrci> ips create package time '2026-05-14 08:00:00' to '2026-05-14 12:00:00'

-- 4. (Opzionale) Aggiungi file extra al package
adrci> ips add file /path/to/custom_log.txt package 1
adrci> ips add file /path/to/awr_report.html package 1

-- 5. (Opzionale) Rivedi contenuto del package
adrci> ips show package 1
adrci> ips show package 1 detail

-- 6. (Opzionale) Rimuovi informazioni sensibili
adrci> ips remove sensitive_data package 1

-- 7. Genera il file ZIP fisico
adrci> ips generate package 1 in /tmp
-- Output: Generated package 1 in file /tmp/ORA600pkg_20260514_1.zip

-- 8. Invia il file ZIP a Oracle Support nella SR
```

### 5.5 TFA (Trace File Analyzer) — Per RAC e Exadata

In ambienti complessi, preferisci TFA ad ADRCI perche raccoglie log di tutti i nodi:

```bash
# Installazione (se non gia presente)
# $ORACLE_HOME/suptools/tfa/release/tfa_home/bin/tfactl

# Status TFA
tfactl status

# Raccolta diagnostica per ORA-600
tfactl diagcollect -srdc ora600

# Raccolta per ORA-7445
tfactl diagcollect -srdc ora7445

# Raccolta per intervallo temporale
tfactl diagcollect -from "May/14/2026 08:00:00" -to "May/14/2026 12:00:00"

# Raccolta per database specifico
tfactl diagcollect -database PROD

# Raccolta completa (tutti i componenti)
tfactl diagcollect -all

# Analisi automatica dei trace
tfactl analyze -from "May/14/2026 08:00:00" -to "May/14/2026 12:00:00"
```


---

## PARTE IV — DIAGNOSTICA PER COMPONENTE

---

## 6. Diagnostica Database

### 6.1 ORA-00600 (Internal Error)

Errore nel codice Oracle. Il primo argomento `[xxxx]` identifica il modulo.

```sql
-- Verifica incident recenti ORA-600
SELECT problem_key, first_incident, last_incident
FROM v$diag_problem
WHERE problem_key LIKE '%ORA 600%'
ORDER BY last_incident DESC;
```

**Workflow:**
1. Identifica il primo argomento: `ORA-00600: internal error code, arguments: [12345], ...`
2. Cerca su MOS: "ORA-600/ORA-7445/ORA-700 Error Look-up Tool"
3. `oerr ora 600` da OS per descrizione base
4. Genera IPS package: `ips create package incident <id>`
5. Apri SR se non c'e patch nota

### 6.2 ORA-07445 (OS Exception)

Crash a livello OS (segfault). Genera core dump in `cdump/`.

```sql
-- Verifica core dumps recenti
-- ls -la $ORACLE_BASE/diag/rdbms/prod/prod1/cdump/
```

**Workflow**: Come ORA-600, ma raccogli anche il core dump dalla directory `cdump/`.

### 6.3 ORA-04031 (Shared Pool Exhaustion)

```sql
-- Shared Pool usage per componente
SELECT pool, name, ROUND(bytes/1024/1024,1) AS mb
FROM v$sgastat
WHERE pool = 'shared pool'
ORDER BY bytes DESC FETCH FIRST 20 ROWS ONLY;

-- Sub-pool fragmentation
SELECT ksmssnam AS subpool, ksmdsidx AS subpool_id,
       ROUND(SUM(ksmsslen)/1024/1024,1) AS total_mb
FROM x$ksmss
GROUP BY ksmssnam, ksmdsidx
ORDER BY total_mb DESC FETCH FIRST 20 ROWS ONLY;

-- Verifica hard parse rate
SELECT ROUND(100 * (1 - gets.value / pins.value), 2) AS hard_parse_pct
FROM v$sysstat gets, v$sysstat pins
WHERE gets.name = 'parse count (hard)' AND pins.name = 'parse count (total)';
```

### 6.4 ORA-04030 (PGA Exhaustion)

```sql
-- PGA target advice
SELECT pga_target_for_estimate/1024/1024 AS target_mb,
       estd_pga_cache_hit_percentage, estd_overalloc_count
FROM v$pga_target_advice;

-- Top sessioni per PGA
SELECT s.sid, s.username, s.program,
       ROUND(p.pga_used_mem/1024/1024,1) AS pga_used_mb,
       ROUND(p.pga_alloc_mem/1024/1024,1) AS pga_alloc_mb,
       ROUND(p.pga_max_mem/1024/1024,1) AS pga_max_mb
FROM v$session s JOIN v$process p ON s.paddr = p.addr
WHERE p.pga_alloc_mem > 50*1024*1024
ORDER BY p.pga_alloc_mem DESC FETCH FIRST 20 ROWS ONLY;
```

### 6.5 ORA-01555 (Snapshot Too Old)

```sql
-- Verifica undo usage
SELECT tablespace_name, status, SUM(bytes)/1024/1024 AS mb
FROM dba_undo_extents
GROUP BY tablespace_name, status;

-- Undo retention corrente
SHOW PARAMETER undo_retention;

-- Undo advisor
SELECT * FROM v$undostat ORDER BY begin_time DESC FETCH FIRST 10 ROWS ONLY;
```

---

## 7. Diagnostica Listener / TNS

```bash
# Seleziona ADR Home del listener
adrci> set homepath diag/tnslsnr/hostname/listener

# Alert log del listener
adrci> show alert -tail -f

# Cerca connessioni rifiutate
adrci> show alert -p "message_text like '%TNS-12518%' or message_text like '%TNS-12500%'"

# Cerca errori di registrazione servizi
adrci> show alert -p "message_text like '%service_register%' or message_text like '%service_update%'"
```

```bash
# Verifica stato listener da OS
lsnrctl status LISTENER
lsnrctl services LISTENER
lsnrctl trace on   # abilita trace dettagliato
tnsping PROD
```

**Errori Listener Comuni:**

| Errore | Causa | Risoluzione |
|---|---|---|
| TNS-12541 | Listener non in esecuzione | `lsnrctl start` |
| TNS-12514 | Servizio non registrato | Verifica `service_names`, attendi registrazione |
| TNS-12518 | Listener non accetta nuove connessioni | Check max processes OS, listener log |
| TNS-12500 | Listener failed to start | Check porta in uso, permessi |
| TNS-01150 | Indirizzo gia in uso | Altro processo sulla stessa porta |
| ORA-12154 | TNS alias non risolvibile | Fix tnsnames.ora, check LDAP |
| ORA-12170 | TNS connect timeout | Network issue, firewall |

---

## 8. Diagnostica ASM

```bash
# ADR Home ASM
adrci> set homepath diag/asm/+asm/+ASM1
adrci> show alert -tail 50

# Cerca disk errors
adrci> show alert -p "message_text like '%ORA-15%' or message_text like '%disk error%'"

# Cerca rebalance
adrci> show alert -p "message_text like '%rebalance%'"
```

```sql
-- ASM disk status (problemi)
SELECT group_number, disk_number, name, path, state, 
       total_mb, free_mb, os_mb, repair_timer
FROM v$asm_disk
WHERE state != 'NORMAL';

-- ASM diskgroup status
SELECT name, state, type, total_mb, free_mb,
       ROUND(free_mb/total_mb*100,1) AS pct_free
FROM v$asm_diskgroup;

-- ASM operations in corso (rebalance)
SELECT group_number, operation, state, power, est_minutes
FROM v$asm_operation;
```

---

## 9. Diagnostica Clusterware / CRS

```bash
# ADR Home CRS
adrci> set homepath diag/crs/hostname/crs

# Cerca errori cluster
adrci> show alert -p "message_text like '%CRS-%' or message_text like '%evict%'"

# Cerca split brain / network partition
adrci> show alert -p "message_text like '%interconnect%' or message_text like '%network%'"
```

```bash
# Comandi CRS da OS (come root o grid user)
crsctl check cluster -all
crsctl stat res -t
crsctl stat res -t -init
ocrcheck
ocrcheck -local
crsctl query css votedisk

# Log CRS (fuori da ADR)
tail -100 $GRID_HOME/log/$(hostname)/alert$(hostname).log
```

---

## 10. Diagnostica Data Guard

### 10.1 Sul Primary

```text
adrci> show alert -p "message_text like '%LNS%' or message_text like '%Error%shipping%' or message_text like '%LGWR%async%'"
```

### 10.2 Sulla Standby

```text
adrci> show alert -p "message_text like '%MRP0%' or message_text like '%RFS%' or message_text like '%FAL%' or message_text like '%Media Recovery%'"
```

### 10.3 Query Diagnostiche Data Guard

```sql
-- Gap detection: eseguire sullo standby
SELECT thread#, low_sequence#, high_sequence# FROM v$archive_gap;

-- Transport/Apply lag
SELECT name, value, time_computed, datum_time
FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag','apply finish time');

-- Processo MRP (apply) status
SELECT process, status, thread#, sequence#, block#
FROM v$managed_standby
WHERE process LIKE 'MRP%' OR process LIKE 'RFS%' OR process LIKE 'LNS%'
ORDER BY process;

-- Ultimo archivelog ricevuto e applicato
SELECT MAX(sequence#) AS max_applied
FROM v$archived_log
WHERE applied = 'YES' AND dest_id = 1;

SELECT MAX(sequence#) AS max_received
FROM v$archived_log
WHERE dest_id = 1;
```

---

## PARTE V — CORRELAZIONE, HEALTH MONITOR, RETENTION

---

## 11. Correlazione ADR con AWR/ASH

Per root cause analysis, correla gli errori nel alert log con i dati performance:

```sql
-- ASH: cosa faceva il database nell'intervallo dell'errore
SELECT TO_CHAR(sample_time,'HH24:MI:SS') AS ts,
       session_id, session_serial#, sql_id, 
       event, wait_class, session_state,
       blocking_session, blocking_session_serial#
FROM v$active_session_history
WHERE sample_time BETWEEN
  TO_TIMESTAMP('2026-05-14 10:00:00','YYYY-MM-DD HH24:MI:SS') AND
  TO_TIMESTAMP('2026-05-14 10:15:00','YYYY-MM-DD HH24:MI:SS')
ORDER BY sample_time;

-- Top wait events nell'intervallo
SELECT event, wait_class, COUNT(*) AS samples,
       ROUND(COUNT(*)*100/SUM(COUNT(*)) OVER(), 1) AS pct
FROM v$active_session_history
WHERE sample_time BETWEEN
  TO_TIMESTAMP('2026-05-14 10:00:00','YYYY-MM-DD HH24:MI:SS') AND
  TO_TIMESTAMP('2026-05-14 10:15:00','YYYY-MM-DD HH24:MI:SS')
  AND session_state = 'WAITING'
GROUP BY event, wait_class
ORDER BY samples DESC FETCH FIRST 10 ROWS ONLY;

-- AWR snapshot nell'intervallo
SELECT snap_id, begin_interval_time, end_interval_time
FROM dba_hist_snapshot
WHERE begin_interval_time > SYSDATE - 1
ORDER BY snap_id DESC;

-- Top SQL nell'intervallo AWR
SELECT sql_id, 
       SUM(executions_delta) AS execs,
       ROUND(SUM(elapsed_time_delta)/1e6,1) AS elapsed_sec,
       SUM(buffer_gets_delta) AS gets,
       SUM(disk_reads_delta) AS reads
FROM dba_hist_sqlstat
WHERE snap_id BETWEEN &begin_snap AND &end_snap
GROUP BY sql_id
ORDER BY elapsed_sec DESC FETCH FIRST 10 ROWS ONLY;

-- Generare AWR report per l'intervallo
-- @?/rdbms/admin/awrrpt.sql
-- @?/rdbms/admin/awrddrpt.sql  (compare due periodi)
-- @?/rdbms/admin/ashrpt.sql    (ASH report)
```

---

## 12. Health Monitor (HM)

Oracle Health Monitor esegue checker automatici per problemi critici:

```text
adrci> show hm_run
adrci> show hm_run -p "run_id = 1"
adrci> show hm_findings
```

### 12.1 Checker Disponibili

| Checker | Cosa Verifica |
|---|---|
| DB Structure Integrity Check | Datafile, controlfile, redo log |
| Data Block Integrity Check | Corruzione blocchi dati |
| Redo Integrity Check | Corruzione redo log |
| Dictionary Integrity Check | Metadata del data dictionary |
| Transaction Integrity Check | Transazioni in stato anomalo |

### 12.2 Esecuzione Manuale

```sql
-- Eseguire un checker
EXEC DBMS_HM.RUN_CHECK('DB Structure Integrity Check', 'my_check_1');
EXEC DBMS_HM.RUN_CHECK('Data Block Integrity Check', 'block_check_1');

-- Vedere risultati
SELECT run_id, name, check_name, status
FROM v$hm_run ORDER BY run_id DESC;

-- Findings
SELECT run_id, name, type, status, description
FROM v$hm_finding ORDER BY run_id DESC;

-- Recommendations
SELECT run_id, hm_run_id, type, description
FROM v$hm_recommendation ORDER BY run_id DESC;
```

---

## 13. Retention e Purge Enterprise

### 13.1 Policy di Retention

| Policy | Default | Cosa Copre |
|---|---|---|
| SHORTP_POLICY | 720 ore (30 giorni) | Trace, cdump, IPC |
| LONGP_POLICY | 8760 ore (365 giorni) | Incident, alert log XML, sweep |

```text
-- Visualizza policy correnti
adrci> show control

-- Modifica SHORT (es. 14 giorni = 336 ore)
adrci> set control (SHORTP_POLICY = 336)

-- Modifica LONG (es. 90 giorni = 2160 ore)
adrci> set control (LONGP_POLICY = 2160)
```

### 13.2 Purge Manuale

```text
-- Purge trace > 14 giorni (20160 minuti)
adrci> purge -age 20160 -type trace

-- Purge incident > 30 giorni
adrci> purge -age 43200 -type incident

-- Purge alert log > 90 giorni
adrci> purge -age 129600 -type alert

-- Purge TUTTO > 7 giorni (EMERGENZA: filesystem pieno)
adrci> purge -age 10080

-- Purge per home specifico
adrci> set homepath diag/rdbms/prod/prod1
adrci> purge -age 20160 -type trace
```

> **ATTENZIONE**: Mai purgare prima di aver esportato evidenze per incidenti aperti.

### 13.3 Script Automatizzato per Purge

```bash
#!/bin/bash
# /home/oracle/scripts/adr_purge.sh
# Cron: 0 6 * * 0 oracle /home/oracle/scripts/adr_purge.sh

export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_BASE=/u01/app/oracle

$ORACLE_HOME/bin/adrci << EOF
set homepath diag/rdbms/prod/prod1
purge -age 20160 -type trace
purge -age 43200 -type incident
set homepath diag/asm/+asm/+ASM1
purge -age 20160 -type trace
set homepath diag/tnslsnr/$(hostname)/listener
purge -age 20160 -type trace
exit
EOF

echo "ADR Purge completed at $(date)" >> /var/log/adr_purge.log
```

### 13.4 Limitare la Dimensione dei Trace File

```sql
-- Limite globale per trace file individuali (default UNLIMITED)
ALTER SYSTEM SET max_dump_file_size = '100M' SCOPE=BOTH;

-- Attenzione: se troppo basso, potresti perdere informazioni diagnostiche
-- Raccomandato: 100M - 500M
```

---

## PARTE VI — WORKFLOW, TROUBLESHOOTING, RIFERIMENTI

---

## 14. Workflow Completi per Scenari Comuni

### 14.1 Scenario: Picco ORA-600

1. `adrci> show alert -tail 50` — identifica timestamp e argomenti
2. `adrci> show problem -mode detail` — ottieni problem_id
3. `adrci> show incident -p "problem_key like '%ORA 600%'"` — lista incident
4. `adrci> show tracefile -t <trace_file>` — analizza il dump
5. Query ASH/AWR nell'intervallo dell'errore
6. `adrci> ips create package incident <id>`
7. `adrci> ips generate package <pkg> in /tmp`
8. Cerca su MOS: "ORA-600 Lookup Tool" con primo argomento
9. Apri SR allegando IPS package

### 14.2 Scenario: Database Hang

1. Da SQL*Plus come SYSDBA (se riesci a connetterti):
   ```sql
   ORADEBUG SETMYPID;
   ORADEBUG HANGANALYZE 3;
   -- attendere 30 sec
   ORADEBUG HANGANALYZE 3;
   -- attendere 30 sec
   ORADEBUG HANGANALYZE 3;
   ORADEBUG DUMP SYSTEMSTATE 266;
   ORADEBUG TRACEFILE_NAME;
   ```
2. Se non riesci a connetterti, usa `kill -3 <pmon_pid>` (genera trace)
3. Analizza la catena di blocchi nel trace
4. `adrci> ips create package time '<start>' to '<end>'`

### 14.3 Scenario: Query Lenta

1. Identifica il sql_id: `SELECT sql_id FROM v$session WHERE sid = &sid;`
2. Abilita trace: `EXEC DBMS_MONITOR.SESSION_TRACE_ENABLE(&sid, &serial, TRUE, TRUE);`
3. Attendi l'esecuzione
4. Disabilita: `EXEC DBMS_MONITOR.SESSION_TRACE_DISABLE(&sid, &serial);`
5. Trova il trace: `SELECT tracefile FROM v$process WHERE addr = (SELECT paddr FROM v$session WHERE sid = &sid);`
6. TKPROF: `tkprof input.trc output.txt sort=exeela explain=sys/pwd sys=no`
7. Analizza l'output per SQL con piu elapsed time

### 14.4 Scenario: Listener Non Accetta Connessioni

1. `lsnrctl status LISTENER` — verifica stato
2. `adrci> set homepath diag/tnslsnr/hostname/listener`
3. `adrci> show alert -tail 100` — cerca errori TNS-
4. Check: `netstat -tlnp | grep 1521` — porta in uso?
5. Check: `ulimit -n` — file descriptors esauriti?
6. `lsnrctl reload` o `lsnrctl stop; lsnrctl start`

---

## 15. Troubleshooting Rapido

| Problema | Causa | Azione |
|---|---|---|
| ADRCI: no homes | ORACLE_BASE errato | Verifica diagnostic_dest e permessi |
| Alert log vuoto | Home sbagliato | `show homes` + `set homepath` |
| Trace non trovato | Purgato o nome errato | `show tracefile` con filtri |
| Incident mancante | Non e ORA-600/7445 | Cerca nel alert log |
| ADR pieno (fs 100%) | Retention alta | Purge urgente |
| Core dump enorme | ORA-7445 | Check `ulimit -c`, purge cdump |
| IPS package vuoto | Incident purgato | Rigenera da trace residui |
| ADRCI lento | Troppi file in trace/ | Purge + review max_dump_file_size |
| Listener trace mancante | Home non selezionato | `set homepath diag/tnslsnr/...` |
| CRS alert non visibile | Permessi (root vs oracle) | Esegui come root o grid |
| 10046 non genera trace | sql_trace non abilitato | Verifica con v$session |
| TKPROF output vuoto | Trace file troncato | Aumenta max_dump_file_size |
| Hanganalyze: no chain | Nessun blocco attivo | Il hang e intermittente, riprova |
| Systemstate troppo grande | Molte sessioni | Usa level 10 invece di 266 |

---

## 16. Riferimenti Ufficiali

- Oracle ADRCI Utility 19c
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-adr-command-interpreter-adrci.html
- Oracle Diagnosing and Resolving Problems 19c
  https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/diagnosing-and-resolving-problems.html
- Oracle SQL Trace and TKPROF 19c
  https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/performing-application-tracing.html
- Oracle Performance Tuning Guide 19c (10046/10053)
  https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/
- MOS: How to Use ADRCI (Doc ID 459641.1)
- MOS: ORA-600/ORA-7445 Lookup Tool (Doc ID 153788.1)
- MOS: How to Collect Diagnostics for Hang (Doc ID 452358.1)
- MOS: ORADEBUG Reference (Doc ID 138.1)
- MOS: TFA Installation and Usage (Doc ID 1513912.1)

---

**Documento confidenziale ad uso interno DBA. Ultima revisione: Maggio 2026.**
