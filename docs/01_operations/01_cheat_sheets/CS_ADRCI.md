# Cheat Sheet ADRCI — Enterprise Completo 🔍

> [!NOTE]
> **DOCUMENTI CORRELATI:**
> - **Guida ADRCI Diagnostica**: [GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md](../../02_core_dba/03_performance_and_diagnostics/GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md)
> - **Housekeeping Automatico**: [GUIDA_HOUSEKEEPING_ADRCI_AUTOMATICO.md](../../02_core_dba/06_monitoring_systems/GUIDA_HOUSEKEEPING_ADRCI_AUTOMATICO.md)
> - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](./CS_MASTER_DBA.md)

---

## 1. Avvio e Navigazione

```bash
# Avvio ADRCI
adrci

# Esecuzione diretta (one-liner, per script)
adrci exec="show homes"
adrci exec="set homepath diag/rdbms/orcl/orcl1; show alert -tail 50"
```

### ADR Home
```adrci
-- Mostrare tutti gli ADR Home disponibili (DB, Listener, ASM, Grid)
SHOW HOMES;

-- Impostare il contesto su un home specifico
SET HOMEPATH diag/rdbms/orcl/orcl1

-- Oppure per ASM
SET HOMEPATH diag/asm/+asm/+ASM1

-- Oppure per Listener
SET HOMEPATH diag/tnslsnr/rac1/listener

-- Verificare home corrente
SHOW HOME;
```

---

## 2. Alert Log — Lettura e Ricerca

```adrci
-- Ultimi 100 record dell'alert log (formato strutturato XML)
SHOW ALERT -TAIL 100

-- Alert log in tempo reale (come tail -f)
SHOW ALERT -TAIL -F

-- Ultime 24 ore
SHOW ALERT -P "MESSAGE_TEXT LIKE '%ORA-%'" -TERM

-- Filtrare per messaggio (errori ORA)
SHOW ALERT -P "MESSAGE_TEXT LIKE '%ORA-600%'"
SHOW ALERT -P "MESSAGE_TEXT LIKE '%ORA-4031%'"
SHOW ALERT -P "MESSAGE_TEXT LIKE '%ORA-00060%'"  -- deadlock

-- Filtrare per periodo di tempo
SHOW ALERT -P "ORIGINATING_TIMESTAMP > SYSTIMESTAMP - INTERVAL '2' HOUR"
SHOW ALERT -P "ORIGINATING_TIMESTAMP BETWEEN
  TO_TIMESTAMP('2026-05-28 08:00:00','YYYY-MM-DD HH24:MI:SS') AND
  TO_TIMESTAMP('2026-05-28 12:00:00','YYYY-MM-DD HH24:MI:SS')"

-- Output su file
SHOW ALERT -TERM > /tmp/alert_extract.txt
```

---

## 3. Incident Management

### 3.1 Visualizzare Incidenti
```adrci
-- Lista incidenti recenti
SHOW INCIDENT

-- Con dettaglio
SHOW INCIDENT -MODE DETAIL

-- Filtrare per tipo
SHOW INCIDENT -P "INCIDENT_ID=12345"
SHOW INCIDENT -P "ECID='oracle-ecid-123'"
SHOW INCIDENT -P "PROBLEM_KEY LIKE '%ORA 600%'"

-- Dettaglio di un problema (raggruppa incidenti simili)
SHOW PROBLEM
SHOW PROBLEM -P "PROBLEM_ID=5"
```

### 3.2 Creare un Package Diagnostico (per Oracle Support)
```adrci
-- Crea un package IPS (Incident Packaging Service)
IPS CREATE PACKAGE INCIDENT 12345

-- Aggiungi incidenti correlati
IPS ADD INCIDENT 12346 PACKAGE 1
IPS ADD INCIDENT 12347 PACKAGE 1

-- Aggiungi un range temporale
IPS ADD FILE /u01/trace/orcl_ora_12345.trc PACKAGE 1

-- Finalizza il package
IPS GENERATE PACKAGE 1 IN /tmp/support_pkg

-- Package con tutto compresso automaticamente (one-shot)
IPS PACK INCIDENT 12345 IN /tmp/support_pkg
```

### 3.3 Gestione Flood Control
```adrci
-- Controllare il flood (incident burst)
SHOW INCIDENT -P "CREATE_TIME > SYSTIMESTAMP - INTERVAL '1' HOUR" -MODE DETAIL

-- Cambiare la policy di flood
-- (dalla 12.2+) i parametri sono in V$DIAG_ALERT_EXT
```

---

## 4. Trace Files

```adrci
-- Lista trace files
SHOW TRACEFILE

-- Filtrare per nome
SHOW TRACEFILE %ora_12345%
SHOW TRACEFILE %pmon%
SHOW TRACEFILE %lgwr%

-- Filtrare per dimensione (file > 10MB)
SHOW TRACEFILE -P "FILE_SIZE > 10485760"

-- Filtrare per data
SHOW TRACEFILE -P "CHANGE_TIME > SYSTIMESTAMP - INTERVAL '1' DAY"

-- Aprire un trace file
-- (usare un editor esterno, ADRCI non ha un viewer inline per trace)
```

---

## 5. Purge — Gestione Spazio

```adrci
-- Purge per tipo (trace, incident, cdump, alert)
PURGE -TYPE TRACE
PURGE -TYPE INCIDENT
PURGE -TYPE CDUMP

-- Purge con retention (in minuti)
-- 14 giorni = 20160 minuti
PURGE -AGE 20160 -TYPE TRACE
PURGE -AGE 43200 -TYPE INCIDENT   -- 30 giorni

-- Purge tutto (attenzione: usa la policy di default)
PURGE

-- Mostrare la policy di retention corrente
SHOW CONTROL

-- Modificare la retention policy (in secondi)
-- SHORTP_POLICY: per trace normali (default 720 ore = 30 giorni)
-- LONGP_POLICY: per incidenti (default 8760 ore = 365 giorni)
SET CONTROL (SHORTP_POLICY = 720)
SET CONTROL (LONGP_POLICY = 8760)
```

---

## 6. HM (Health Monitor) — Controlli Diagnostici

```adrci
-- Eseguire un check diagnostico
RUN CHECK logical    -- check corruzione logica
RUN CHECK physical   -- check corruzione fisica
RUN CHECK undo       -- check undo
RUN CHECK data_block_integrity  -- integrità blocchi

-- Visualizzare risultati dei check
SHOW CHECK
SHOW CHECK logical
SHOW CHECK -P "RUN_ID=1"

-- Elenco check disponibili
LIST CHECK
```

---

## 7. Script One-Liner per Cron/Automazione

```bash
# Status rapido di tutti gli home
adrci exec="show homes" | while read home; do
  echo "=== $home ==="
  adrci exec="set homepath $home; show incident -mode brief"
done

# Pulizia automatica (14 giorni trace, 30 giorni incident)
adrci exec="set homepath diag/rdbms/orcl/orcl1; purge -age 20160 -type trace"
adrci exec="set homepath diag/rdbms/orcl/orcl1; purge -age 43200 -type incident"

# Estrarre errori ORA dall'alert log delle ultime 2 ore
adrci exec="set homepath diag/rdbms/orcl/orcl1; show alert -P \"MESSAGE_TEXT LIKE '%ORA-%'\" -TERM" | grep ORA-

# Creare package per SR (Service Request)
adrci exec="set homepath diag/rdbms/orcl/orcl1; ips pack incident 12345 in /tmp/sr_pkg"
```

---

## 8. Quick Reference

```text
+---------------------------+----------------------------------------------+
| OPERAZIONE                | COMANDO                                      |
+---------------------------+----------------------------------------------+
| Mostra ADR homes          | SHOW HOMES;                                  |
| Imposta home              | SET HOMEPATH diag/rdbms/orcl/orcl1           |
| Alert log tail            | SHOW ALERT -TAIL 50                          |
| Alert log live            | SHOW ALERT -TAIL -F                          |
| Cerca errori ORA          | SHOW ALERT -P "MSG LIKE '%ORA-%'"            |
| Lista incidenti           | SHOW INCIDENT                                |
| Dettaglio incidente       | SHOW INCIDENT -P "INCIDENT_ID=123"           |
| Crea package SR           | IPS PACK INCIDENT 123 IN /tmp/pkg            |
| Lista trace file          | SHOW TRACEFILE                               |
| Purge trace (14gg)        | PURGE -AGE 20160 -TYPE TRACE                 |
| Purge incidenti (30gg)    | PURGE -AGE 43200 -TYPE INCIDENT              |
| Mostra retention          | SHOW CONTROL                                 |
| Health Check              | RUN CHECK physical                           |
+---------------------------+----------------------------------------------+
```
