# FASE 6: Test di Verifica (Data Guard + GoldenGate)

> Questa fase è cruciale. Un sistema che non è stato testato è un sistema che non funziona. Qui eseguiamo test end-to-end per verificare che TUTTA la catena (RAC Primary → DG Standby → GG Target) sia operativa.

---

## 6.1 Test Data Guard — Verifica Redo Transport

### Sul Primario: Genera traffico

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

### Sullo Standby: Verifica che i dati siano arrivati

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
> - I dati nella tabella `test_replica` sono visibili sullo standby.

### Verifica con DGMGRL

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

## 6.2 Test Data Guard — Switchover Completo

```bash
dgmgrl sys/<password>@RACDB

-- Verifica che lo switchover sia possibile
VALIDATE DATABASE RACDB_STBY;
-- Deve mostrare: "Ready for Switchover: Yes"

-- Esegui lo switchover
SWITCHOVER TO RACDB_STBY;
```

Dopo lo switchover:

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
sqlplus / as sysdba @RACDB

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

## 6.3 Test GoldenGate — Verifica Replica End-to-End

### Sullo Standby: Verifica stato processi GG

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

### Sul Target: Verifica stato Replicat

```bash
cd $OGG_HOME
./ggsci

INFO ALL
```

Output atteso:
```
Program     Status      Group       Lag at Chkpt  Time Since Chkpt
MANAGER     RUNNING
REPLICAT    RUNNING     rep_racdb   00:00:03      00:00:04
```

### Genera traffico e verifica

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

> Se le righe sono presenti sul target, la catena completa funziona:
> **RAC Primary → (DG Redo) → RAC Standby → (GG Extract/Pump) → Target DB (GG Replicat)**

### Verifica statistiche GoldenGate

```
-- Sullo Standby
GGSCI> STATS EXTRACT ext_racdb, LATEST
-- Mostra le tabelle e il numero di operazioni catturate

GGSCI> STATS EXTRACT pump_racdb, LATEST

-- Sul Target
GGSCI> STATS REPLICAT rep_racdb, LATEST
-- Mostra le tabelle e il numero di operazioni applicate
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
GGSCI> LAG REPLICAT rep_racdb
```

```sql
-- Dopo qualche secondo, verifica sul Target
SELECT COUNT(*) FROM testdg.test_replica;
-- Deve corrispondere al conteggio sul primario
```

---

## 6.5 Test DML Completo (INSERT / UPDATE / DELETE)

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

## 6.6 Tabella Riassuntiva Test

| # | Test | Dove | Risultato Atteso | ✅/❌ |
|---|---|---|---|---|
| 1 | INSERT su Primary → visibile su Standby | DG | Righe visibili in tempo reale | |
| 2 | Transport Lag = 0 | DG | dgmgrl SHOW DATABASE | |
| 3 | Apply Lag = 0 o ~secondi | DG | dgmgrl SHOW DATABASE | |
| 4 | Switchover + Switchback | DG | Nessuna perdita dati, SUCCESS | |
| 5 | INSERT su Primary → visibile su Target | GG | Righe replicate via GG | |
| 6 | UPDATE → replicato su Target | GG | Modifiche su target | |
| 7 | DELETE → replicato su Target | GG | Riga cancellata su target | |
| 8 | Stress 1000 righe → tutte su Target | GG | COUNT(*) identico | |
| 9 | Lag GG Extract < 10s | GG | LAG EXTRACT | |
| 10 | Lag GG Replicat < 10s | GG | LAG REPLICAT | |

---

## 6.7 Test Node Failure — Simulazione Crash RAC

> Questo è il test più importante: il RAC deve sopravvivere alla perdita di un nodo.

### Test: Spegnimento brutale di un nodo

```bash
# In VirtualBox: seleziona rac2 → Tasto destro → Chiudi → Spegnimento brutale
# Oppure sulla console di rac2:
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger  # Crash immediato!
```

### Verifica su rac1 (deve continuare a funzionare!)

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

### Riavvia rac2 e verifica il rejoin

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

## 6.8 Test GoldenGate dopo Switchover

> CRITICO: Dopo un switchover Data Guard, GoldenGate deve continuare a funzionare.

```
PRIMA dello switchover:
  Primary (RACDB) → DG → Standby (RACDB_STBY) → GG Extract → Target

DOPO lo switchover:
  Old-Primary (RACDB, ora standby) ← DG ← New-Primary (RACDB_STBY)
  L'Extract GG gira ancora su RACDB_STBY (che ora è il primario!)
  → Deve continuare a catturare modifiche senza interruzione!
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
| `crsctl check crs` fallisce | CRS non partito correttamente | `crsctl start crs` (come root) |
| Un nodo si "evict" dal cluster | Interconnect down o heartbeat perso | Controlla `ifconfig eth1`, ping nodo remoto |
| VIP non migra | Network mask errata | Verifica subnet VIP con `srvctl config vip -n rac1` |
| ORA-29702: error occurred | ocssd.log errori networking | Controlla `/u01/app/19.0.0/grid/log/<host>/ocssd/ocssd.log` |

### Problemi Data Guard

| Problema | Causa Probabile | Soluzione |
|---|---|---|
| Transport Lag cresce | Rete lenta o listener standby down | `lsnrctl status` su standby, controlla banda |
| Apply Lag cresce | Standby in "no apply" state | `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;` |
| ORA-16191: Primary log shipping disabled | `log_archive_dest_state_2` = DEFER | `ALTER SYSTEM SET log_archive_dest_state_2=ENABLE;` |
| GAP rilevato nel DGMGRL | Archivelog mancante | `ALTER SYSTEM SET fal_server='RACDB'` su standby, il FAL richiederà i log |
| DGMGRL mostra WARNING | Stale redo log detected | `ALTER SYSTEM SWITCH LOGFILE;` + verifica FAL |

### Problemi GoldenGate

| Problema | Causa Probabile | Soluzione |
|---|---|---|
| Extract ABENDED | Redo log non disponibile | `GGSCI> ALTER EXTRACT ext_racdb, BEGIN NOW` |
| Replicat ABENDED | Conflitto duplicato (PK) | `GGSCI> ALTER REPLICAT rep_racdb, BEGIN NOW`, risolvere il conflitto |
| Lag alto Extract | LogMiner lento | Verifica `v$goldengate_capture` per colli di bottiglia |
| Lag alto Replicat | Batch troppo piccolo | Aumenta `BATCHSQL` nel param Replicat |
| Trail pieno su disco | Pump non trasmette | Verifica rete, `INFO EXTRACT pump_racdb` |

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
cat $OGG_HOME/dirrpt/rep_racdb.rpt
```

---

## 6.10 Tabella Riassuntiva Test COMPLETA

| # | Test | Dove | Risultato Atteso | ✅/❌ |
|---|---|---|---|---|
| 1 | INSERT su Primary → visibile su Standby | DG | Righe visibili in tempo reale | |
| 2 | Transport Lag = 0 | DG | dgmgrl SHOW DATABASE | |
| 3 | Apply Lag = 0 o ~secondi | DG | dgmgrl SHOW DATABASE | |
| 4 | Switchover + Switchback | DG | Nessuna perdita dati, SUCCESS | |
| 5 | INSERT su Primary → visibile su Target | GG | Righe replicate via GG | |
| 6 | UPDATE → replicato su Target | GG | Modifiche su target | |
| 7 | DELETE → replicato su Target | GG | Riga cancellata su target | |
| 8 | Stress 1000 righe → tutte su Target | GG | COUNT(*) identico | |
| 9 | Lag GG Extract < 10s | GG | LAG EXTRACT | |
| 10 | Lag GG Replicat < 10s | GG | LAG REPLICAT | |
| 11 | **Crash nodo rac2** → rac1 continua | RAC | DB OPEN su rac1, VIP migrato | |
| 12 | **Rejoin nodo rac2** → cluster intatto | RAC | Entrambe le istanze OPEN | |
| 13 | **GG dopo switchover** → replica intatta | DG+GG | Extract RUNNING, dati replicati | |
| 14 | RMAN backup da standby | RMAN | Backup completato senza errori | |
| 15 | RMAN RESTORE VALIDATE | RMAN | Restore simulato OK | |

---

**→ Prossimo: [FASE 7: Strategia RMAN Backup](./GUIDA_FASE7_RMAN_BACKUP.md)**
