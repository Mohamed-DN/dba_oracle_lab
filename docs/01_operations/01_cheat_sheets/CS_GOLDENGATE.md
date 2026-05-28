# Cheat Sheet GoldenGate 19c/21c — Enterprise Completo 🔄

> [!NOTE]
> **DOCUMENTI GOLDENGATE CORRELATI:**
> - **Guida Lab (Fase 7)**: [GUIDA_FASE7_GOLDENGATE.md](../../02_core_dba/07_replication_goldengate/GUIDA_FASE7_GOLDENGATE.md)
> - **Guida Completa 19c**: [GUIDA_GOLDENGATE_19C_COMPLETA.md](../../02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_19C_COMPLETA.md)
> - **Runbook End-to-End**: [GUIDA_GOLDENGATE_RUNBOOK_END_TO_END_19C.md](../../02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_RUNBOOK_END_TO_END_19C.md)
> - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](./CS_MASTER_DBA.md)

---

## 1. GGSCI — Connessione e Navigazione

```ggsci
-- Avvia GGSCI
cd $OGG_HOME
./ggsci

-- Login al database
DBLOGIN USERID ogg_admin PASSWORD "StrongP@ss!" 
DBLOGIN USERID ogg_admin@ORCL PASSWORD "StrongP@ss!"

-- Con wallet
DBLOGIN USERIDALIAS ogg_admin_alias
```

---

## 2. Info e Status — Monitoraggio Rapido

```ggsci
-- Status globale di tutti i processi
INFO ALL

-- Dettaglio singolo processo
INFO EXTRACT ext_prod
INFO EXTRACT ext_prod, DETAIL
INFO EXTRACT ext_prod, SHOWCH   -- mostra checkpoint

INFO REPLICAT rep_prod
INFO REPLICAT rep_prod, DETAIL

INFO MANAGER

-- Statistiche di performance
STATS EXTRACT ext_prod
STATS EXTRACT ext_prod, TOTAL
STATS EXTRACT ext_prod, HOURLY
STATS EXTRACT ext_prod, TABLE src_schema.orders

STATS REPLICAT rep_prod
STATS REPLICAT rep_prod, TOTAL, TABLE tgt_schema.orders

-- Lag di replica
LAG EXTRACT ext_prod
LAG REPLICAT rep_prod

-- Report (log del processo)
VIEW REPORT ext_prod
VIEW REPORT rep_prod
```

---

## 3. Manager — Configurazione

```ggsci
-- Editare parametri del Manager
EDIT PARAMS MGR
```

```text
-- Parametri Manager tipici
PORT 7809
DYNAMICPORTLIST 7810-7830
AUTORESTART EXTRACT *, RETRIES 5, WAITMINUTES 3
AUTORESTART REPLICAT *, RETRIES 5, WAITMINUTES 3
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPDAYS 3
LAGREPORTHOURS 1
LAGINFOMINUTES 5
LAGCRITICALMINUTES 30
```

```ggsci
-- Start / Stop / Restart Manager
START MANAGER
STOP MANAGER
STOP MANAGER !   -- force stop
INFO MANAGER
```

---

## 4. Extract — Cattura dal Source

### 4.1 Creare un Extract (Integrated Capture)
```ggsci
-- Aggiungere l'extract
ADD EXTRACT ext_prod, INTEGRATED TRANLOG, BEGIN NOW
ADD EXTTRAIL ./dirdat/et, EXTRACT ext_prod, MEGABYTES 200

-- Registrare nel database (Integrated Capture)
REGISTER EXTRACT ext_prod DATABASE
```

### 4.2 Parametri Extract tipici
```ggsci
EDIT PARAMS ext_prod
```
```text
EXTRACT ext_prod
USERID ogg_admin@ORCL, PASSWORD "StrongP@ss!"
EXTTRAIL ./dirdat/et
LOGALLSUPCOLS
UPDATERECORDFORMAT COMPACT

-- Tabelle da catturare
TABLE src_schema.customers;
TABLE src_schema.orders;
TABLE src_schema.order_items;

-- Oppure intero schema
TABLE src_schema.*;

-- Esclusioni
TABLEEXCLUDE src_schema.temp_*;
TABLEEXCLUDE src_schema.audit_log;
```

### 4.3 Data Pump (distribuito, per WAN)
```ggsci
-- Aggiungere Data Pump (extract secondario)
ADD EXTRACT pump_prod, EXTTRAILSOURCE ./dirdat/et
ADD RMTTRAIL ./dirdat/rt, EXTRACT pump_prod, MEGABYTES 200
```
```text
-- Parametri Data Pump
EXTRACT pump_prod
USERID ogg_admin@ORCL, PASSWORD "StrongP@ss!"
RMTHOST target-host, MGRPORT 7809
RMTTRAIL ./dirdat/rt
PASSTHRU
TABLE src_schema.*;
```

### 4.4 Operazioni Extract
```ggsci
START EXTRACT ext_prod
STOP EXTRACT ext_prod
KILL EXTRACT ext_prod

-- Posizionamento
ALTER EXTRACT ext_prod, BEGIN NOW
ALTER EXTRACT ext_prod, BEGIN 2026-05-01 00:00:00
ALTER EXTRACT ext_prod, EXTSEQNO 0, EXTRBA 0

-- Unregister (prima di delete)
UNREGISTER EXTRACT ext_prod DATABASE
DELETE EXTRACT ext_prod
```

---

## 5. Replicat — Applicazione sul Target

### 5.1 Creare un Replicat (Integrated Mode)
```ggsci
ADD REPLICAT rep_prod, INTEGRATED, EXTTRAIL ./dirdat/rt
```

### 5.2 Creare un Replicat (Parallel Integrated — alta performance)
```ggsci
ADD REPLICAT rep_prod, PARALLEL, EXTTRAIL ./dirdat/rt
```

### 5.3 Parametri Replicat tipici
```ggsci
EDIT PARAMS rep_prod
```
```text
REPLICAT rep_prod
USERID ogg_admin@ORCL, PASSWORD "StrongP@ss!"

-- Performance
BATCHSQL BATCHTRANSOPS 5000

-- Error handling
REPERROR (DEFAULT, DISCARD)
DISCARDFILE ./dirrpt/rep_prod.dsc, APPEND, MEGABYTES 500

-- Mapping
MAP src_schema.customers, TARGET tgt_schema.customers;
MAP src_schema.orders, TARGET tgt_schema.orders;
MAP src_schema.order_items, TARGET tgt_schema.order_items;

-- Oppure intero schema (nomi identici)
MAP src_schema.*, TARGET tgt_schema.*;

-- Con colonne calcolate o filtri
MAP src_schema.orders, TARGET tgt_schema.orders,
  FILTER (@STREQ(status, 'ACTIVE')),
  COLMAP (USEDEFAULTS,
    order_total = order_amount * 1.22,
    last_modified = @DATENOW());
```

### 5.4 Operazioni Replicat
```ggsci
START REPLICAT rep_prod
STOP REPLICAT rep_prod
KILL REPLICAT rep_prod

-- Posizionamento
ALTER REPLICAT rep_prod, BEGIN NOW
ALTER REPLICAT rep_prod, EXTSEQNO 0, EXTRBA 0

DELETE REPLICAT rep_prod
```

---

## 6. Initial Load (Caricamento Iniziale)

### Metodo 1: GoldenGate Direct Load
```ggsci
-- Extract per initial load
ADD EXTRACT initext, SOURCEISTABLE
```
```text
EXTRACT initext
USERID ogg_admin@ORCL, PASSWORD "StrongP@ss!"
RMTHOST target-host, MGRPORT 7809
RMTFILE ./dirdat/initload, MEGABYTES 2000
TABLE src_schema.*;
```

```ggsci
-- Replicat per initial load
ADD REPLICAT initrep, SPECIALRUN
```
```text
REPLICAT initrep
USERID ogg_admin@ORCL, PASSWORD "StrongP@ss!"
SOURCEDEFS ./dirdef/src_schema.def
DISCARDFILE ./dirrpt/initrep.dsc, PURGE
MAP src_schema.*, TARGET tgt_schema.*;
```

### Metodo 2: Data Pump Export/Import + GoldenGate Change Capture
```text
1. ADD EXTRACT ext_prod con BEGIN <timestamp prima dell'export>
2. Esegui Data Pump Export/Import
3. START EXTRACT ext_prod
4. START REPLICAT rep_prod con posizione dopo l'import
```

---

## 7. Heartbeat & Monitoring

```sql
-- Abilitare heartbeat table (auto-monitoring del lag)
-- Da SQL*Plus (target)
EXEC DBMS_GOLDENGATE_ADM.ADD_AUTO_CDR;

-- GoldenGate heartbeat (dalla 19.1+)
ADD HEARTBEATTABLE
INFO HEARTBEATTABLE
DELETE HEARTBEATTABLE
```

---

## 8. Troubleshooting Rapido

| Sintomo | Diagnostica | Fix |
|---|---|---|
| Extract ABENDED | `VIEW REPORT ext_prod` | Check alert log, ORA errors |
| Replicat ABENDED | `VIEW REPORT rep_prod` | Check discard file |
| LAG in crescita | `LAG EXTRACT ext_prod` | Increase parallelism, check I/O |
| OGG-00868: duplicate key | Discard file | `HANDLECOLLISIONS` temporaneo |
| Trail file pieno | `INFO EXTRACT ext_prod, DETAIL` | `PURGEOLDEXTRACTS` in MGR |
| OGG-01004: no data found | Tabella mancante sul target | DDL sync o creare la tabella |
| Integrated Capture stuck | `DBMS_GOLDENGATE_ADM` | Bouncing dell'extract |

### File di log importanti
```bash
# Report dei processi
$OGG_HOME/dirrpt/ext_prod.rpt
$OGG_HOME/dirrpt/rep_prod.rpt
$OGG_HOME/dirrpt/MGR.rpt

# Discard files
$OGG_HOME/dirrpt/rep_prod.dsc

# Trail files
$OGG_HOME/dirdat/et*
$OGG_HOME/dirdat/rt*
```

---

## 9. Quick Reference — Operazioni Quotidiane

```text
+---------------------------+----------------------------------------------+
| OPERAZIONE                | COMANDO                                      |
+---------------------------+----------------------------------------------+
| Status globale            | INFO ALL                                     |
| Lag di un processo        | LAG EXTRACT ext_prod                         |
| Statistiche               | STATS EXTRACT ext_prod, TOTAL                |
| Start processo            | START EXTRACT ext_prod                       |
| Stop processo             | STOP EXTRACT ext_prod                        |
| Kill forzato              | KILL EXTRACT ext_prod                        |
| Report errori             | VIEW REPORT ext_prod                         |
| Edit parametri            | EDIT PARAMS ext_prod                         |
| Riposizionare             | ALTER EXTRACT ext_prod, BEGIN NOW             |
| Cleanup trail             | PURGEOLDEXTRACTS in Manager params           |
| Registra nel DB           | REGISTER EXTRACT ext_prod DATABASE           |
| Initial load check        | INFO EXTRACT initext, SHOWCH                 |
+---------------------------+----------------------------------------------+
```
