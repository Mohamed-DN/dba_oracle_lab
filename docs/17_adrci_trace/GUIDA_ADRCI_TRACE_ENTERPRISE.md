# Guida ADRCI & Trace Log Enterprise — ADR, Alert Log, Incident

> Guida dettagliata e operativa per gestire ADRCI, alert log, trace file e incident package in ambiente enterprise.

---

## Obiettivo

- Capire **dove** Oracle scrive i log diagnostici (ADR, alert, trace).
- Usare **ADRCI** per filtrare e gestire incident, problem e trace.
- Definire una procedura ripetibile per troubleshooting e escalation.
- Gestire retention/purge in modo sicuro senza perdere evidenze.

---

## Procedura operativa

### 1) Concetti chiave ADR (ADR, problem, incident)

- **ADR (Automatic Diagnostic Repository)**: repository file-based unico per alert/trace/incident.
- **Problem**: errore critico (es. ORA-600/ORA-7445) con un **problem key**.
- **Incident**: singola occorrenza del problem con `incident_id` univoco.

### 2) Identifica la diagnostic destination (ADR base)

```sql
SHOW PARAMETER diagnostic_dest;

SELECT name, value
FROM v$diag_info
ORDER BY name;
```

Output chiave in `v$diag_info`:

- `ADR Base`
- `ADR Home`
- `Diag Trace`
- `Diag Alert`

### 3) Entra in ADRCI e seleziona il corretto home

```bash
adrci
show base
show homes
set homepath diag/rdbms/<db_unique_name>/<instance_name>
```

In RAC/ASM/Listener troverai homes diversi (es. `diag/asm`, `diag/tnslsnr`).

### 4) Struttura ADR (dove trovare cosa)

Tipico path:

```
$ORACLE_BASE/diag/rdbms/<db_unique_name>/<instance_name>/
```

Sottodirectory principali:

- `alert/` → alert log (XML + text)
- `trace/` → trace file background/server
- `incident/` → incident dumps
- `cdump/` → core dumps
- `hm/` → Health Monitor
- `metadata/` → metadata diagnostici

### 5) Alert log (lettura e filtro)

Con ADRCI:

```text
show alert -tail -f
show alert -p "message_text like '%ORA-%'"
```

Percorso tipico:

```
.../alert/alert_<SID>.log
```

Note:

- L’alert log è **cronologico** e non ruota da solo.
- Esiste anche la versione XML: `log.xml`.
- ADRCI legge l’XML e mostra il log senza tag.

Filtro per time window:

```text
show alert -p "originating_timestamp > SYSDATE-1"
```

Per contenere la crescita del log serve una **rotazione manuale** o archiviazione periodica.

### 6) Trace file (tipi e ricerca veloce)

Elenco e filtri:

```text
show tracefile
show tracefile -p "trace_filename like '%ora_%'"
show tracefile -t <trace_name>
```

Tipi comuni:

- **Server process**: sessioni utente
- **Background process**: DBWR/LGWR/SMON/PMON
- **Incident trace**: ORA-600/ORA-7445, con incident_id

Naming tipico:

- `<SID>_ora_<SPID>.trc` per sessioni utente
- `<SID>_lgwr_<PID>.trc`, `<SID>_dbw0_<PID>.trc` per background

Dimensione trace:

- Parametro `MAX_DUMP_FILE_SIZE` per limitare la crescita dei trace (escluso alert log).

### 7) Trace mirato e mapping sessione → trace file

Abilita tracing per una sessione specifica:

```sql
ALTER SESSION SET tracefile_identifier='APP_TRACE';
ALTER SESSION SET sql_trace = TRUE;
```

Oppure con DBMS\_MONITOR:

```sql
EXEC DBMS_MONITOR.SESSION_TRACE_ENABLE(sid=>123, serial#=>456, waits=>TRUE, binds=>TRUE);
```

Mappare una sessione al trace file:

```sql
SELECT s.sid, s.serial#, p.spid, p.tracefile
FROM v$session s
JOIN v$process p ON s.paddr = p.addr
WHERE s.sid = 123;
```

Con `oradebug` (solo DBA esperti):

```sql
ORADEBUG SETOSPID <spid>;
ORADEBUG TRACEFILE_NAME;
```

### 8) Incident e problem management

```text
show problem -mode detail
show incident -mode detail
```

Filtro per time window:

```text
show incident -p "incident_time > SYSDATE-1"
```

Filtro per errore:

```text
show problem -p "problem_key like '%ORA 600%'"
show incident -p "problem_key like '%ORA 7445%'"
```

### 9) Creazione package per Oracle Support (IPS)

```text
ips create package problem <problem_id>
ips add incident <incident_id> package <package_id>
ips generate package <package_id> in /tmp
```

Gestione package:

```text
ips show packages
ips add file <file_path> package <package_id>
ips generate package <package_id> in /tmp
```

### 10) Health Monitor (HM)

```text
show hm_run
show hm_run -p "run_id=<id>"
show hm_findings
```

Usalo per:

- Datafile/redo/undo corruption checks
- Consistenza metadata

### 11) Retention e purge ADR (con cautela)

```text
show control
set control (SHORTP_POLICY=720) (LONGP_POLICY=2160)
purge -age 4320 -type incident
```

Altri purge comuni:

```text
purge -age 4320 -type trace
purge -age 4320 -type alert
```

Best practice:

- Purge solo **dopo** aver esportato evidenze.
- Allinea policy con RPO/RTO e requisiti audit.

### 12) Checklist diagnosi rapida (runbook)

1. `show alert -tail -f` per timeline errori.
2. `show problem` + `show incident` per ID.
3. `show tracefile -t <trace>` per evidenze.
4. `ips create package ...` per escalation.
5. Correlazione con AWR/ASH e log applicativi.

### 13) Esempio operativo completo (incident ORA-600)

1. `show alert -tail -f` per identificare l’orario esatto.
2. `show problem -mode detail` per ottenere `problem_id`.
3. `show incident -p "problem_key like '%ORA 600%'"` per lista incident.
4. `show tracefile -t <trace>` per aprire il trace collegato.
5. `ips create package problem <problem_id>` + `ips generate package ...`.

---

## Validazione finale

- `v$diag_info` verificato (ADR base/home corretti).
- Alert log letto e timestamp coerenti con incidente.
- Trace file associati all’incident_id raccolti.
- Package IPS generato e salvato in path condiviso.
- Retention/purge aggiornati e documentati.

---

## Troubleshooting rapido

| Problema | Causa probabile | Azione |
| --- | --- | --- |
| `ADRCI: no homes` | ORACLE_BASE/diagnostic_dest errato | Verifica `diagnostic_dest` e permessi |
| Alert log vuoto | Stai leggendo home sbagliato | `show homes` + `set homepath` |
| Trace non trovato | Nome file errato o purge | Usa `show tracefile` e filtri |
| Incident non presente | Errore non critico | Cerca ORA in alert log, abilita tracing sessione |
| ADR pieno | Retention troppo alta | Valuta `SHORTP_POLICY/LONGP_POLICY` e purge |
| Log troppo grandi | Nessuna rotazione | Archivia e ruota manualmente |

---

## Runbook collegati

- [ADRCI Diagnostica Oracle (overview)](../05_performance/GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md)
- [Troubleshooting Completo](../05_performance/GUIDA_TROUBLESHOOTING_COMPLETO.md)
- [ORA Errors](../11_runbook_operativi/08_ORA_ERRORS.md)

---

## Riferimenti ufficiali

- Oracle ADRCI Utility: <https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-adr-command-interpreter-adrci.html>
- Oracle Diagnosing and Resolving Problems: <https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/diagnosing-and-resolving-problems.html>
- Oracle Monitoring Errors with Trace Files and Alert Log: <https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/monitoring-the-database.html>
- Oracle ADR Structure and Contents: <https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/diagnosing-and-resolving-problems.html#GUID-951A06EE-DDF7-4C2A-B0BB-B24418BB2E33>
