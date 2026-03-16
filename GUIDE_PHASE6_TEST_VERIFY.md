# PHASE 6: Verification Test (Data Guard + GoldenGate)

> This phase is crucial. A system that has not been tested is a system that doesn't work. Here we perform end-to-end tests to verify that the ENTIRE chain (RAC Primary → DG Standby → GG Target) is operational.

---

## 6.0 Entry from Phase 5 (preflight)

This phase is a system test: do not start if Phase 5 is not stable.

Checklist minima:

```bash
# Data Guard
dgmgrl sys/<password>@RACDB "show configuration;"

# GoldenGate su standby
cd $OGG_HOME && ./ggsci
INFO ALL
```

```sql
-- Standby deve essere utilizzabile da GG
sqlplus / as sysdba
SELECT open_mode, database_role FROM v$database;
```

Requisiti:

- DGMGRL in `SUCCESS`
- Extract/Pump `RUNNING` on standby
- Replicat target (`REPTAR`) `RUNNING` su UI Microservices
- standby in a state consistent with testing (typically `READ ONLY WITH APPLY`)

For advanced testing use the full matrix in [GUIDE_PHASE5_GOLDENGATE.md](./GUIDE_PHASE5_GOLDENGATE.md) section 5.13.

## 6.1 Test Data Guard — Verify Redo Transport

### On the Primary: Generate traffic

```sql
sqlplus / as sysdba

-- Crea uno schema di test
CREATE USER testdg IDENTIFIED BY testdg123
    DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, CREATE TABLE TO testdg;

-- Inserisci dati
CONNECT testdg/testdg123

CREATE TABLE test_replica (
    id        NUMBER PRIMARY KEY,
    nome      VARCHAR2(50),
    ts_insert TIMESTAMP DEFAULT SYSTIMESTAMP
);

INSERT INTO test_replica VALUES (1, 'Test Data Guard', SYSTIMESTAMP);
INSERT INTO test_replica VALUES (2, 'Verifica Redo Shipping', SYSTIMESTAMP);
COMMIT;

-- Forza un log switch per accelerare la spedizione
CONNECT / AS SYSDBA
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
```

### On Standby: Verify that data has arrived

```sql
-- Lo standby deve essere in READ ONLY (Active Data Guard)
sqlplus / as sysdba

-- Verifica lo stato di apply
SELECT process, status, thread#, sequence#
FROM v$managed_standby
WHERE process IN ('MRP0','RFS');

-- Verifica i dati
SELECT * FROM testdg.test_replica;
-- Se vedi le 2 righe, Data Guard funziona!

-- Verifica il Transport Lag
SELECT name, value, datum_time FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag','apply finish time');
```

> **Output atteso:**
> - `transport lag`: 0 secondi — i redo arrivano in tempo reale.
> - `apply lag`: 0 secondi o pochi secondi — i redo vengono applicati immediatamente.
> - The data in the table `test_replica` are visible on standby.

### Check with DGMGRL

```bash
dgmgrl sys/<password>@RACDB

SHOW CONFIGURATION;
-- Configuration Status: SUCCESS

SHOW DATABASE RACDB_STBY;
-- Transport Lag: 0 seconds
-- Apply Lag: 0 seconds
-- Database Status: SUCCESS
```

---

## 6.2 Test Data Guard — Complete Switchover

```bash
dgmgrl sys/<password>@RACDB

-- Verifica che lo switchover sia possibile
VALIDATE DATABASE RACDB_STBY;
-- Deve mostrare: "Ready for Switchover: Yes"

-- Esegui lo switchover
SWITCHOVER TO RACDB_STBY;
```

After switchover:

```bash
SHOW CONFIGURATION;
-- RACDB_STBY è ora Primary
-- RACDB è ora Physical Standby

-- Verifica che la replica funzioni al contrario
-- Inserisci dati sul NUOVO primario (RACDB_STBY)
```

```sql
sqlplus testdg/testdg123@RACDB_STBY

INSERT INTO test_replica VALUES (3, 'Post-Switchover Test', SYSTIMESTAMP);
COMMIT;
```

```sql
-- Verifica sul NUOVO standby (RACDB, ora in mount/read only)
sqlplus / as sysdba

SELECT * FROM testdg.test_replica;
-- Devi vedere la riga con id=3
```

### Switchover di ritorno

```bash
dgmgrl sys/<password>@RACDB_STBY

SWITCHOVER TO RACDB;

SHOW CONFIGURATION;
-- Tutto torna come prima
```

---

## 6.3 GoldenGate Test — End-to-End Replication Verification

### On Standby: Check DD process status

```bash
cd $OGG_HOME
./ggsci

INFO ALL
```

Output atteso:
```
Program     Status      Group       Lag at Chkpt  Time Since Chkpt
MANAGER     RUNNING
EXTRACT     RUNNING     ext_racdb   00:00:02      00:00:05
EXTRACT     RUNNING     pump_racdb  00:00:00      00:00:03
```

### On Target: Check Replicat status

Sul target OCI con GoldenGate Microservices non usare `ggsci` classico.

Controlla da Web UI (Administration Server):

- replicat `REPTAR` in state `Running`
- checkpoint in avanzamento
- lag basso/stabile
- nessun errore in diagnostics

### Generate traffic and verify

```sql
-- Sul Primario (RACDB)
sqlplus testdg/testdg123@RACDB

INSERT INTO test_replica VALUES (100, 'GoldenGate Test 1', SYSTIMESTAMP);
INSERT INTO test_replica VALUES (101, 'GoldenGate Test 2', SYSTIMESTAMP);
INSERT INTO test_replica VALUES (102, 'GoldenGate Test 3', SYSTIMESTAMP);
COMMIT;
```

```sql
-- Sul Target (dbtarget) - dopo pochi secondi
sqlplus testdg/testdg123@dbtarget

SELECT * FROM test_replica WHERE id >= 100;
-- Devi vedere le 3 righe inserite dal primario!
```

> If the rows are present on the target, the complete chain works:
> **RAC Primary → (DG Redo) → RAC Standby → (GG Extract/Pump) → Target DB (GG Replicat)**

### Check GoldenGate statistics

```
-- Sullo Standby
GGSCI> STATS EXTRACT ext_racdb, LATEST
-- Mostra le tabelle e il numero di operazioni catturate

GGSCI> STATS EXTRACT pump_racdb, LATEST

-- Sul Target
-- verifica statistiche dal pannello del replicat REPTAR (Microservices UI)
-- e dalla sezione diagnostics / performance
```

---

## 6.4 Test di Stress — Volume

```sql
-- Sul Primario
sqlplus testdg/testdg123@RACDB

BEGIN
    FOR i IN 1000..2000 LOOP
        INSERT INTO test_replica VALUES (i, 'Stress Test Row ' || i, SYSTIMESTAMP);
    END LOOP;
    COMMIT;
END;
/
```

```
-- Monitora il lag in tempo reale su GoldenGate
GGSCI> LAG EXTRACT ext_racdb
-- Sul target verifica lag del replicat REPTAR da UI Microservices
```

```sql
-- Dopo qualche secondo, verifica sul Target
SELECT COUNT(*) FROM testdg.test_replica;
-- Deve corrispondere al conteggio sul primario
```

---

## 6.5 Complete DML Test (INSERT / UPDATE / DELETE)

```sql
-- Sul Primario
sqlplus testdg/testdg123@RACDB

-- UPDATE
UPDATE test_replica SET nome = 'UPDATED ROW' WHERE id = 1;
COMMIT;

-- DELETE
DELETE FROM test_replica WHERE id = 2;
COMMIT;

-- DDL (se hai configurato DDL replication in GG)
ALTER TABLE test_replica ADD (email VARCHAR2(100));

-- INSERT con nuova colonna
INSERT INTO test_replica VALUES (9999, 'DDL Test', SYSTIMESTAMP, 'test@oracle.com');
COMMIT;
```

```sql
-- Verifica sul Target
SELECT * FROM testdg.test_replica WHERE id IN (1, 2, 9999);
-- id=1: nome = 'UPDATED ROW'
-- id=2: NON deve esistere (deleted)
-- id=9999: deve esistere con email
```

---

## 6.6 Test Summary Table

| # | Test | Dove | Risultato Atteso | ✅/❌ |
|---|---|---|---|---|
| 1 | INSERT on Primary → visible on Standby | DG | Righe visibili in tempo reale | |
| 2 | Transport Lag = 0 | DG | dgmgrl SHOW DATABASE | |
| 3 | Apply Lag = 0 o ~secondi | DG | dgmgrl SHOW DATABASE | |
| 4 | Switchover + Switchback | DG | Nessuna perdita dati, SUCCESS | |
| 5 | INSERT su Primary → visibile su Target | GG | Righe replicate via GG | |
| 6 | UPDATE → replicato su Target | GG | Modifiche su target | |
| 7 | DELETE → replicato su Target | GG | Riga cancellata su target | |
| 8 | Stress 1000 lines → all on Target | GG | COUNT(*) identico | |
| 9 | Lag GG Extract < 10s | GG | LAG EXTRACT | |
| 10 | Lag GG Replicat < 10s | GG | Lag REPTAR da UI Microservices | |

---

## 6.7 Test Node Failure — Simulazione Crash RAC

> This is the most important test: the RAC must survive the loss of a node.

### Test: Brutal shutdown of a node

```bash
# In VirtualBox: seleziona rac2 → Tasto destro → Chiudi → Spegnimento brutale
# Oppure sulla console di rac2:
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger  # Crash immediato!
```

### Check on rac1 (must continue to work!)

```sql
sqlplus / as sysdba

-- Il database è ancora OPEN?
SELECT instance_name, status FROM gv$instance;
-- rac1: OPEN
-- rac2: non mostrato (è crashato)

-- Puoi ancora fare DML?
INSERT INTO testdg.test_replica VALUES (5000, 'Nodo 2 è crashato', SYSTIMESTAMP);
COMMIT;
-- Se funziona → RAC sta facendo il suo lavoro!

-- Verifica il VIP failover
SELECT name, value FROM v$parameter WHERE name = 'local_listener';
-- Il VIP di rac2 (.112) è migrato su rac1?
```

```bash
# Controlla i servizi del cluster
crsctl stat res -t
# rac2 sarà OFFLINE, rac1 avrà entrambi i VIP

# Controlla lo stato del database
srvctl status database -d RACDB
# Instance RACDB1 is running on node rac1
# Instance RACDB2 is not running
```

### Restart rac2 and check for rejoin

```bash
# In VirtualBox: Avvia rac2
# Aspetta 2-3 minuti per il boot

# Su rac2 dopo il boot, il cluster si riunisce automaticamente
crsctl stat res -t
# Entrambi i nodi ONLINE

# Verifica che il database si riapre
srvctl status database -d RACDB
# RACDB1 e RACDB2 entrambi running
```

---

## 6.8 GoldenGate Test after Switchover

> CRITICAL: After a Data Guard switchover, GoldenGate must continue to function.

```
BEFORE switchover:
  Primary (RACDB) → DG → Standby (RACDB_STBY) → GG Extract → Target

AFTER switchover:
  Old-Primary (RACDB, now standby) ← DG ← New-Primary (RACDB_STBY)
  The Extract GG still runs on RACDB_STBY (who is now the primary!)
  → Must continue to capture changes without interruption!
```

```bash
# 1. Fai switchover
dgmgrl sys/<password>@RACDB
SWITCHOVER TO RACDB_STBY;

# 2. Verifica GG sullo standby (ora primario)
cd $OGG_HOME && ./ggsci
INFO ALL
# Extract e Pump devono essere ancora RUNNING

# 3. Inserisci dati sul nuovo primario
sqlplus testdg/testdg123@RACDB_STBY
INSERT INTO test_replica VALUES (6000, 'Post-Switchover GG Test', SYSTIMESTAMP);
COMMIT;

# 4. Verifica sul target
sqlplus testdg/testdg123@dbtarget
SELECT * FROM test_replica WHERE id = 6000;
-- Deve esistere!
```

```bash
# 5. Switchback
dgmgrl sys/<password>@RACDB_STBY
SWITCHOVER TO RACDB;

# 6. Verifica
GGSCI> INFO ALL
# Tutto RUNNING? → BRAVO!
```

---

## 6.9 Troubleshooting — Problemi Comuni e Soluzioni

### Problemi Cluster (Clusterware)

| Problema | Causa Probabile | Soluzione |
|---|---|---|
| `crsctl check crs` fallisce | CRS non partito correttamente | `crsctl start crs` (as root) |
| A node "evicts" itself from the cluster | Interconnect down o heartbeat perso | Controlla `ip addr show enp0s9`, ping remote node |
| VIP non migra | Network mask errata | Check VIP subnet with `srvctl config vip -n rac1` |
| ORA-29702: error occurred | ocssd.log errori networking | Controlla `/u01/app/19.0.0/grid/log/<host>/ocssd/ocssd.log` |

### Problemi Data Guard

| Problema | Causa Probabile | Soluzione |
|---|---|---|
| Transport Lag cresce | Slow network or standby listener down | `lsnrctl status` on standby, check bandwidth |
| Apply Lag cresce | Standby in "no apply" state | `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;` |
| ORA-16191: Primary log shipping disabled | `log_archive_dest_state_2` = DEFER | `ALTER SYSTEM SET log_archive_dest_state_2=ENABLE;` |
| GAP rilevato nel DGMGRL | Archivelog missing | `ALTER SYSTEM SET fal_server='RACDB'` on standby, the FAL will request logs |
| DGMGRL mostra WARNING | Stale redo log detected | `ALTER SYSTEM SWITCH LOGFILE;` + check FAL |

### Problemi GoldenGate

| Problema | Causa Probabile | Soluzione |
|---|---|---|
| Extract ABENDED | Redo log non disponibile | `GGSCI> ALTER EXTRACT ext_racdb, BEGIN NOW` |
| Replicat ABENDED | Conflitto duplicato (PK) | Riavvia `REPTAR` da UI/AdminClient, risolvi conflitto e riparti dal checkpoint corretto |
| Lag alto Extract | LogMiner lento | Verify `v$goldengate_capture` per colli di bottiglia |
| Lag alto Replicat | Batch troppo piccolo | Aumenta `BATCHSQL` nel param Replicat |
| Trail pieno su disco | Pump non trasmette | Check network, `INFO EXTRACT pump_racdb` |

### Problemi RMAN

| Problema | Causa Probabile | Soluzione |
|---|---|---|
| ORA-19502: write error | FRA piena | `DELETE NOPROMPT OBSOLETE;`, aumenta FRA |
| RMAN-06059: expected numeric | Errore nel script | Controlla sintassi nel .sh |
| Backup lentissimo | BCT non attivo o PARALLELISM=1 | `CONFIGURE DEVICE TYPE DISK PARALLELISM 2;` |
| RESTORE fallisce | Backup corrotto o expired | `CROSSCHECK BACKUP; VALIDATE BACKUP;` |

### Problemi Performance

```sql
-- Top 5 SQL per tempo di esecuzione
SELECT sql_id, elapsed_time/1000000 AS secs, executions, 
       SUBSTR(sql_text, 1, 80) AS sql
FROM v$sql ORDER BY elapsed_time DESC FETCH FIRST 5 ROWS ONLY;

-- Sessioni bloccanti
SELECT blocking_session, sid, serial#, wait_class, event
FROM v$session WHERE blocking_session IS NOT NULL;

-- Tablespace quasi pieno
SELECT tablespace_name, ROUND(used_percent, 1) AS pct
FROM dba_tablespace_usage_metrics WHERE used_percent > 85;

-- ASM quasi pieno
SELECT name, ROUND((1-free_mb/total_mb)*100, 1) AS pct 
FROM v$asm_diskgroup WHERE (1-free_mb/total_mb) > 0.8;
```

### Dove Trovare i Log di Errore

```bash
# Alert Log del database (IL PIÙ IMPORTANTE)
adrci
SHOW ALERT -tail 50

# Alert Log via file
tail -100 $ORACLE_BASE/diag/rdbms/${ORACLE_SID}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log

# Log del cluster (CRS)
tail -100 /u01/app/19.0.0/grid/log/$(hostname)/alertrac1.log

# Log CSSD (cluster membership, eviction)
tail -100 /u01/app/19.0.0/grid/log/$(hostname)/ocssd/ocssd.log

# Log GoldenGate
cat $OGG_HOME/dirrpt/ext_racdb.rpt
# Per il replicat target (REPTAR) usa diagnostics/report dalla UI Microservices
```

---

## 6.10 COMPLETE Test Summary Table

| # | Test | Dove | Risultato Atteso | ✅/❌ |
|---|---|---|---|---|
| 1 | INSERT on Primary → visible on Standby | DG | Righe visibili in tempo reale | |
| 2 | Transport Lag = 0 | DG | dgmgrl SHOW DATABASE | |
| 3 | Apply Lag = 0 o ~secondi | DG | dgmgrl SHOW DATABASE | |
| 4 | Switchover + Switchback | DG | Nessuna perdita dati, SUCCESS | |
| 5 | INSERT su Primary → visibile su Target | GG | Righe replicate via GG | |
| 6 | UPDATE → replicato su Target | GG | Modifiche su target | |
| 7 | DELETE → replicato su Target | GG | Riga cancellata su target | |
| 8 | Stress 1000 lines → all on Target | GG | COUNT(*) identico | |
| 9 | Lag GG Extract < 10s | GG | LAG EXTRACT | |
| 10 | Lag GG Replicat < 10s | GG | Lag REPTAR da UI Microservices | |
| 11 | **rac2 node crash** → rac1 continues | RAC | DB OPEN su rac1, VIP migrato | |
| 12 | **Rejoin rac2 node** → cluster intact | RAC | Entrambe le istanze OPEN | |
| 13 | **DD after switchover** → replication intact | DG+GG | Extract RUNNING, dati replicati | |
| 14 | RMAN backup from standby | RMAN | Backup completato senza errori | |
| 15 | RMAN RESTORE VALIDATE | RMAN | Restore simulato OK | |

---

**→ Next: [STEP 7: RMAN Backup Strategy](./GUIDE_PHASE7_RMAN_BACKUP.md)**
