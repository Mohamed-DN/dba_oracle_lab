# Guida ADRCI & Trace Log Enterprise — Diagnostica Completa

> Guida operativa completa per ADRCI, alert log, trace file, incident management e diagnostica avanzata
> in ambienti Oracle 19c/21c/23ai (Single Instance, RAC, Data Guard, ASM, Listener).

---

## 1. Architettura ADR (Automatic Diagnostic Repository)

### 1.1 Cos'e ADR

ADR e un repository diagnostico file-based, gerarchico e indipendente dal database.
Funziona anche se il database e DOWN — fondamentale per il troubleshooting di crash.

### 1.2 Struttura Directory

Path base: `$ORACLE_BASE/diag/`

```
$ORACLE_BASE/diag/
  rdbms/<db_unique_name>/<instance>/   # Database
    alert/     --> alert log XML (log.xml) + testo (alert_SID.log)
    trace/     --> file .trc e .trm (background + user sessions)
    incident/  --> incident dumps (incdir_N/)
    cdump/     --> core dumps
    hm/        --> Health Monitor reports
    metadata/  --> metadata diagnostici
    sweep/     --> dati purgati
  asm/+asm/<+ASM_instance>/            # ASM
  tnslsnr/<hostname>/<listener>/       # Listener
  crs/<hostname>/crs/                  # Clusterware (Grid Infrastructure)
```

### 1.3 Identificare il Diagnostic Dest

```sql
SHOW PARAMETER diagnostic_dest;

SELECT name, value
FROM v$diag_info
ORDER BY name;
```

Output chiave da `v$diag_info`:
- **ADR Base**: root di tutti gli ADR Home
- **ADR Home**: home specifico dell'istanza
- **Diag Trace**: dove stanno i .trc
- **Diag Alert**: dove sta l'alert log

---

## 2. ADRCI — Navigazione e Comandi Base

### 2.1 Avvio e Selezione Home

```bash
adrci

# Mostra la base directory
adrci> show base

# Lista tutti gli ADR Home disponibili (DB, ASM, Listener, CRS)
adrci> show homes

# Seleziona l'home del database target
adrci> set homepath diag/rdbms/prod/prod1

# In RAC: seleziona il nodo specifico
adrci> set homepath diag/rdbms/prod/prod2
```

### 2.2 Alert Log — Lettura e Filtro

```text
-- Live tail (come tail -f)
adrci> show alert -tail -f

-- Ultimi N messaggi
adrci> show alert -tail 100

-- Filtra per errori ORA-
adrci> show alert -p "message_text like '%ORA-%'"

-- Filtra per ORA-600 specifico
adrci> show alert -p "message_text like '%ORA-00600%'"

-- Filtra per finestra temporale (ultimo giorno)
adrci> show alert -p "originating_timestamp > systimestamp - 1"

-- Filtra per intervallo specifico
adrci> show alert -p "originating_timestamp between
  TO_TIMESTAMP('2026-05-13 08:00:00','YYYY-MM-DD HH24:MI:SS') and
  TO_TIMESTAMP('2026-05-13 12:00:00','YYYY-MM-DD HH24:MI:SS')"
```

**Parsing da shell (alternativa per scripting):**
```bash
# Ultimi errori ORA- nell'alert log
grep -i "ORA-" $ORACLE_BASE/diag/rdbms/prod/prod1/trace/alert_prod1.log | tail -50

# Errori con timestamp (grep contestuale)
grep -B2 -A2 "ORA-" $ORACLE_BASE/diag/rdbms/prod/prod1/trace/alert_prod1.log | tail -100

# Conta errori per tipo (ultimi 7 giorni)
awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2}/{ts=$0} /ORA-/{print ts, $0}' alert_prod1.log | sort | uniq -c | sort -rn
```

### 2.3 Trace File — Ricerca e Analisi

```text
-- Lista tutti i trace file
adrci> show tracefile

-- Filtra per nome (es. cercare un PID specifico)
adrci> show tracefile -p "trace_filename like '%ora_12345%'"

-- Filtra per processo background (es. LGWR)
adrci> show tracefile -p "trace_filename like '%lgwr%'"

-- Apri un trace file specifico
adrci> show tracefile -t prod1_ora_12345.trc
```

### 2.4 Mapping Sessione -> Trace File

```sql
-- Trovare il trace file per un SID specifico
SELECT s.sid, s.serial#, s.username, s.program,
       p.spid AS os_pid, p.tracefile
FROM v$session s
JOIN v$process p ON s.paddr = p.addr
WHERE s.sid = &sid;

-- Trovare il trace file per TUTTE le sessioni attive
SELECT s.sid, s.serial#, s.username, s.status,
       p.spid, p.tracefile
FROM v$session s
JOIN v$process p ON s.paddr = p.addr
WHERE s.status = 'ACTIVE' AND s.type != 'BACKGROUND'
ORDER BY s.sid;
```

**Con oradebug (solo DBA esperti):**
```sql
-- Connetti a un processo tramite OS PID
ORADEBUG SETOSPID <spid>;
ORADEBUG TRACEFILE_NAME;
```

---

## 3. SQL Trace e TKPROF — Analisi Performance

### 3.1 Abilitare SQL Trace su una Sessione

```sql
-- Trace base (solo statement)
ALTER SESSION SET sql_trace = TRUE;

-- Trace con identificatore per ritrovare il file
ALTER SESSION SET tracefile_identifier = 'APP_SLOW_QUERY';
ALTER SESSION SET sql_trace = TRUE;

-- Trace su un'altra sessione (remoto)
EXEC DBMS_MONITOR.SESSION_TRACE_ENABLE(
  session_id  => 123,
  serial_num  => 456,
  waits       => TRUE,
  binds       => TRUE
);

-- Disabilitare
EXEC DBMS_MONITOR.SESSION_TRACE_DISABLE(
  session_id  => 123,
  serial_num  => 456
);
```

### 3.2 Event 10046 (Trace Dettagliato)

```sql
-- Level 4: Bind variables
ALTER SESSION SET EVENTS '10046 trace name context forever, level 4';

-- Level 8: Wait events
ALTER SESSION SET EVENTS '10046 trace name context forever, level 8';

-- Level 12: Bind + Wait (il piu completo)
ALTER SESSION SET EVENTS '10046 trace name context forever, level 12';

-- Disabilitare
ALTER SESSION SET EVENTS '10046 trace name context off';
```

### 3.3 Event 10053 (Optimizer Trace)

Per capire perche l'optimizer sceglie un piano di esecuzione:

```sql
ALTER SESSION SET EVENTS '10053 trace name context forever, level 1';
-- Esegui la query da analizzare
SELECT ...;
ALTER SESSION SET EVENTS '10053 trace name context off';
```

### 3.4 TKPROF — Processare il Trace File

```bash
# Genera report leggibile dal trace raw
tkprof /path/to/trace/prod1_ora_12345.trc /tmp/output_report.txt \
  sort=exeela \
  explain=sys/pwd@PROD \
  sys=no

# Parametri utili:
# sort=exeela    -> ordina per elapsed time
# sort=fchela    -> ordina per fetch elapsed
# explain=       -> aggiunge execution plan
# sys=no         -> esclude query di sistema
# aggregate=yes  -> raggruppa statement identici
```

---

## 4. Incident e Problem Management

### 4.1 Concetti

- **Problem**: Classe di errore (es. "ORA 600 [12345]"). Ha un `problem_key`.
- **Incident**: Singola occorrenza del problem. Ha un `incident_id` univoco.
- **Flood Control**: Oracle limita automaticamente gli incident per evitare disk full.

### 4.2 Visualizzare Problem e Incident

```text
-- Lista problemi
adrci> show problem
adrci> show problem -mode detail

-- Lista incidenti
adrci> show incident
adrci> show incident -mode detail

-- Filtra per ID specifico
adrci> show incident -p "incident_id = 98765"

-- Filtra per errore
adrci> show problem -p "problem_key like '%ORA 600%'"
adrci> show incident -p "problem_key like '%ORA 7445%'"

-- Filtra per finestra temporale
adrci> show incident -p "incident_time > systimestamp - 1"
```

### 4.3 Creazione IPS Package per Oracle Support

Quando apri una Service Request (SR), **devi** allegare un IPS package:

```text
-- 1. Crea package logico dall'incident
adrci> ips create package incident 98765
-- Output: Created package 1 based on incident id 98765

-- 2. (Opzionale) Aggiungi file extra
adrci> ips add file /path/to/custom_log.txt package 1

-- 3. (Opzionale) Rivedi contenuto
adrci> ips show package 1 detail

-- 4. Genera ZIP fisico
adrci> ips generate package 1 in /tmp
-- Output: Generated package 1 in /tmp/ORA600pkg_... .zip
```

**Con TFA (Trace File Analyzer) — alternativa enterprise per RAC:**
```bash
# Raccoglie automaticamente trace di tutti i nodi cluster
tfactl diagcollect -srdc ora600
tfactl diagcollect -srdc ora7445

# Raccolta basata su intervallo temporale
tfactl diagcollect -from "May/13/2026 08:00:00" -to "May/13/2026 12:00:00"
```

---

## 5. Diagnostica per Componente

### 5.1 Database — ORA-600, ORA-7445

**ORA-600 (Internal Error):**
- Errore nel codice Oracle. Il primo argomento `[xxxx]` identifica il modulo.
- Cerca su MOS il "ORA-600/ORA-7445/ORA-700 Error Look-up Tool".
- Genera IPS package e apri SR.

**ORA-7445 (OS Exception):**
- Crash a livello OS (segfault). Genera core dump.
- Raccogli il core dump da `cdump/` e il trace dall'`incident/` dir.

```sql
-- Verifica incident recenti
SELECT problem_key, first_incident, last_incident
FROM v$diag_problem
ORDER BY last_incident DESC;
```

### 5.2 Database — ORA-04031 (Shared Pool) / ORA-04030 (PGA)

```sql
-- Shared Pool usage
SELECT pool, name, bytes/1024/1024 AS mb
FROM v$sgastat
WHERE pool = 'shared pool'
ORDER BY bytes DESC FETCH FIRST 20 ROWS ONLY;

-- PGA target advice
SELECT pga_target_for_estimate/1024/1024 AS target_mb,
       estd_pga_cache_hit_percentage
FROM v$pga_target_advice;

-- Sessioni top memory consumer
SELECT s.sid, s.username, s.program,
       ROUND(p.pga_used_mem/1024/1024,1) AS pga_used_mb,
       ROUND(p.pga_alloc_mem/1024/1024,1) AS pga_alloc_mb
FROM v$session s JOIN v$process p ON s.paddr = p.addr
ORDER BY p.pga_alloc_mem DESC FETCH FIRST 20 ROWS ONLY;
```

### 5.3 Listener / TNS

```bash
# Seleziona l'ADR Home del listener
adrci> set homepath diag/tnslsnr/hostname/listener

# Alert log del listener
adrci> show alert -tail -f

# Cerca connessioni rifiutate
adrci> show alert -p "message_text like '%TNS-12518%' or message_text like '%TNS-12500%'"
```

```bash
# Verifica stato listener da OS
lsnrctl status LISTENER
lsnrctl services LISTENER
tnsping PROD
```

### 5.4 ASM

```bash
# ADR Home ASM
adrci> set homepath diag/asm/+asm/+ASM1
adrci> show alert -tail 50

# Cerca disk errors
adrci> show alert -p "message_text like '%ORA-15%' or message_text like '%disk error%'"
```

```sql
-- ASM disk status
SELECT group_number, disk_number, name, path, state, total_mb, free_mb
FROM v$asm_disk
WHERE state != 'NORMAL';
```

### 5.5 Clusterware / CRS (Grid Infrastructure)

```bash
# ADR Home CRS
adrci> set homepath diag/crs/hostname/crs

# Cerca errori cluster
adrci> show alert -p "message_text like '%CRS-%' or message_text like '%has been evicted%'"
```

```bash
# Comandi CRS da OS
crsctl check cluster -all
crsctl stat res -t
ocrcheck
ocrcheck -local
```

### 5.6 Data Guard — Alert Log Analysis

**Sul Primary** cerca:
```text
adrci> show alert -p "message_text like '%LNS%' or message_text like '%Error%shipping%'"
```

**Sulla Standby** cerca:
```text
adrci> show alert -p "message_text like '%MRP0%' or message_text like '%RFS%' or message_text like '%FAL%' or message_text like '%Media Recovery%'"
```

```sql
-- Gap detection
SELECT thread#, low_sequence#, high_sequence# FROM v$archive_gap;

-- Transport/Apply lag
SELECT name, value, time_computed, datum_time
FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag','apply finish time');
```

---

## 6. Correlazione ADR con AWR/ASH

Per root cause analysis, correla gli errori nel alert log con i dati performance:

```sql
-- ASH: cosa stava facendo il database nell'intervallo dell'errore
SELECT TO_CHAR(sample_time,'HH24:MI:SS') AS ts,
       session_id, session_serial#, sql_id, event,
       wait_class, session_state
FROM v$active_session_history
WHERE sample_time BETWEEN
  TO_TIMESTAMP('2026-05-13 10:00:00','YYYY-MM-DD HH24:MI:SS') AND
  TO_TIMESTAMP('2026-05-13 10:15:00','YYYY-MM-DD HH24:MI:SS')
ORDER BY sample_time;

-- AWR snapshot nell'intervallo
SELECT snap_id, begin_interval_time, end_interval_time
FROM dba_hist_snapshot
WHERE begin_interval_time > SYSDATE - 1
ORDER BY snap_id DESC;

-- Top SQL nell'intervallo
SELECT sql_id, executions_delta, elapsed_time_delta/1e6 AS elapsed_sec,
       buffer_gets_delta, disk_reads_delta
FROM dba_hist_sqlstat
WHERE snap_id BETWEEN &begin_snap AND &end_snap
ORDER BY elapsed_time_delta DESC FETCH FIRST 10 ROWS ONLY;
```

---

## 7. Health Monitor (HM)

Oracle Health Monitor esegue checker automatici per problemi critici:

```text
-- Lista esecuzioni Health Monitor
adrci> show hm_run

-- Dettaglio di un run specifico
adrci> show hm_run -p "run_id = 1"

-- Findings (risultati dei checker)
adrci> show hm_findings
```

**Checker disponibili:**
- **DB Structure Integrity Check**: verifica datafile, controlfile, redo
- **Data Block Integrity Check**: corruzione blocchi
- **Redo Integrity Check**: corruzione redo log
- **Dictionary Integrity Check**: metadata del dizionario

```sql
-- Eseguire un checker manualmente
EXEC DBMS_HM.RUN_CHECK('DB Structure Integrity Check', 'my_check_1');

-- Vedere risultati
SELECT run_id, name, check_name, status
FROM v$hm_run
ORDER BY run_id DESC;
```

---

## 8. Retention e Purge Enterprise

### 8.1 Policy di Retention

ADR ha due policy:
- **SHORTP_POLICY** (default 720 ore = 30 giorni): trace, cdump, IPC
- **LONGP_POLICY** (default 8760 ore = 365 giorni): incident, alert log XML, sweep

```text
-- Visualizza policy correnti
adrci> show control

-- Modifica (es. SHORT=14gg, LONG=90gg)
adrci> set control (SHORTP_POLICY = 336)
adrci> set control (LONGP_POLICY = 2160)
```

### 8.2 Purge Manuale

```text
-- Purge trace > 10 giorni
adrci> purge -age 14400 -type trace

-- Purge incident > 30 giorni
adrci> purge -age 43200 -type incident

-- Purge alert log > 90 giorni
adrci> purge -age 129600 -type alert

-- Purge tutto > 7 giorni (EMERGENZA: filesystem pieno)
adrci> purge -age 10080
```

> **ATTENZIONE**: Mai purgare prima di aver esportato le evidenze per incidenti aperti o SR Oracle.

### 8.3 Script Automatizzato per Purge

```bash
#!/bin/bash
# /home/oracle/scripts/adr_purge.sh
# Eseguire settimanalmente via cron

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
```

---

## 9. Esempio Completo: Workflow Incidente ORA-600

1. **Alert**: Ricevi notifica ORA-600 da monitoring
2. **Triage**: `adrci> show alert -tail 50` — identifica timestamp e argomenti
3. **Problem**: `adrci> show problem -mode detail` — ottieni `problem_id`
4. **Incident**: `adrci> show incident -p "problem_key like '%ORA 600%'"` — lista incident
5. **Trace**: `adrci> show tracefile -t <trace_file>` — analizza il dump
6. **Correlazione**: Query ASH/AWR nell'intervallo dell'errore
7. **Package**: `adrci> ips create package incident <id>` + `ips generate package <pkg> in /tmp`
8. **MOS Lookup**: Cerca il primo argomento nel "ORA-600 Lookup Tool" su My Oracle Support
9. **SR**: Apri Service Request allegando il package IPS

---

## 10. Troubleshooting Rapido

| Problema | Causa | Azione |
|---|---|---|
| ADRCI: no homes | ORACLE_BASE o diagnostic_dest errato | Verifica `diagnostic_dest` e permessi |
| Alert log vuoto | Home sbagliato selezionato | `show homes` + `set homepath` corretto |
| Trace non trovato | Nome errato o gia purgato | `show tracefile` con filtri, check purge policy |
| Incident non presente | Errore non critico (non ORA-600/7445) | Cerca nel alert log direttamente |
| ADR pieno (filesystem) | Retention troppo alta o molti incident | Purge urgente + review SHORTP/LONGP |
| Core dump enorme | ORA-7445 con stack trace grande | Check `ulimit -c`, purge vecchi cdump |
| IPS package vuoto | Incident gia purgato | Rigenera da trace residui se possibile |
| ADRCI lento | Troppi file nella directory trace | Purge + review MAX_DUMP_FILE_SIZE |
| Listener trace mancante | Home listener non selezionato | `set homepath diag/tnslsnr/...` |
| CRS alert non visibile | Permessi (root vs oracle) | Esegui adrci come root o grid user |

---

## 11. Riferimenti Ufficiali

- Oracle ADRCI Utility: https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-adr-command-interpreter-adrci.html
- Oracle Diagnosing and Resolving Problems: https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/diagnosing-and-resolving-problems.html
- Oracle Monitoring Errors: https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/monitoring-the-database.html
- MOS: How to Use ADRCI (Doc ID 459641.1)
- MOS: ORA-600/ORA-7445 Lookup Tool (Doc ID 153788.1)
