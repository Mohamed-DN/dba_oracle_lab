# FASE 8: Test di Verifica (Data Guard + RMAN + EM + GoldenGate)

> Questa fase è cruciale. Un sistema che non è stato testato è un sistema che non funziona. Qui eseguiamo test end-to-end per verificare che TUTTA la catena (RAC Primary → DG Standby → Backup → EM Alerts → GG Target) sia operativa.

---

## Obiettivo

Validare il laboratorio end-to-end e, opzionalmente, raccogliere evidenza runtime
del failover automatico configurato nella Fase 4B.

## Procedura Operativa

## 8.0 Ingresso da Fase 7 (preflight)

Questa fase e un test di sistema: non partire se la Fase 7 (GoldenGate) non e stabile, e se RMAN (Fase 5) o EM (Fase 6) non sono configurati.

Checklist minima:

```bash
# Data Guard
dgmgrl /@RACDB "show configuration;"

# GoldenGate sul PRIMARIO (rac1) — è lì che gira l'Extract
cd $OGG_HOME && ./ggsci
INFO ALL
```

```sql
-- Primario deve essere stabile
sqlplus / as sysdba
SELECT open_mode, database_role FROM v$database;
```

Requisiti:

- DGMGRL in `SUCCESS`
- Extract/Pump `RUNNING` sul **primario** (`rac1`)
- Replicat `RUNNING` sul **target** (`dbtarget`)
- Primary in `READ WRITE`, standby in apply

Per test avanzati usa la matrice completa in [GUIDA_FASE7_GOLDENGATE.md](../../02_core_dba/07_replication_goldengate/GUIDA_FASE7_GOLDENGATE.md) sezione 7.13.

## 8.1 Test Data Guard — Verifica Redo Transport

### Sul Primario: Genera traffico

```sql
sqlplus / as sysdba

-- Crea uno schema di test
CREATE USER testdg IDENTIFIED BY "<PASSWORD_TESTDG>"
    DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, CREATE TABLE TO testdg;

-- Inserisci dati
CONNECT testdg

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
dgmgrl /@RACDB

SHOW CONFIGURATION;
-- Configuration Status: SUCCESS

SHOW DATABASE RACDB_STBY;
-- Transport Lag: 0 seconds
-- Apply Lag: 0 seconds
-- Database Status: SUCCESS
```

---

## 8.2 Test Data Guard — Switchover Completo

```bash
dgmgrl /@RACDB

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
sqlplus testdg@RACDB_STBY

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
dgmgrl /@RACDB_STBY

SWITCHOVER TO RACDB;

SHOW CONFIGURATION;
-- Tutto torna come prima
```

---

## 8.3 Test GoldenGate — Verifica Replica End-to-End

### Sul Primario (rac1): Verifica stato processi GG

```bash
# L'Extract e il Pump girano sul PRIMARIO (rac1)
cd $OGG_HOME
./ggsci

INFO ALL
```

Output atteso:
```
Program     Status      Group       Lag at Chkpt  Time Since Chkpt
MANAGER     RUNNING
EXTRACT     RUNNING     ext_rac     00:00:02      00:00:05
EXTRACT     RUNNING     pump_rac    00:00:00      00:00:03
```

### Sul Target (dbtarget): Verifica stato Replicat

```bash
# Sul target locale (dbtarget), verifica il Replicat
cd $OGG_HOME
./ggsci

INFO ALL
```

Output atteso:
```
Program     Status      Group       Lag at Chkpt  Time Since Chkpt
MANAGER     RUNNING
REPLICAT    RUNNING     rep_rac     00:00:01      00:00:02
```

### Genera traffico e verifica

```sql
-- Sul Primario (RACDB) — rac1
sqlplus testdg@RACDB

INSERT INTO test_replica VALUES (100, 'GoldenGate Test 1', SYSTIMESTAMP);
INSERT INTO test_replica VALUES (101, 'GoldenGate Test 2', SYSTIMESTAMP);
INSERT INTO test_replica VALUES (102, 'GoldenGate Test 3', SYSTIMESTAMP);
COMMIT;
```

```sql
-- Sul Target (dbtarget) - dopo pochi secondi
sqlplus testdg@dbtarget

SELECT * FROM test_replica WHERE id >= 100;
-- Devi vedere le 3 righe inserite dal primario!
```

> Se le righe sono presenti sul target, la catena completa funziona:
> **RAC Primary (rac1) → GG Extract → GG Pump → rete → GG Replicat → Target DB (dbtarget)**
>
> In parallelo, Data Guard continua a proteggere: Primary → Standby (RACDB_STBY)

### Verifica statistiche GoldenGate

```
-- Sul Primario (rac1)
GGSCI> STATS EXTRACT ext_rac, LATEST
-- Mostra le tabelle e il numero di operazioni catturate

GGSCI> STATS EXTRACT pump_rac, LATEST

-- Sul Target (dbtarget)
GGSCI> STATS REPLICAT rep_rac, LATEST
-- Mostra INSERT/UPDATE/DELETE replicati
```

---

## 8.4 Test di Stress — Volume

```sql
-- Sul Primario
sqlplus testdg@RACDB

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

## 8.5 Test DML Completo (INSERT / UPDATE / DELETE)

```sql
-- Sul Primario
sqlplus testdg@RACDB

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

## 8.6 Tabella Riassuntiva Test

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
| 10 | Lag GG Replicat < 10s | GG | Lag REPTAR da UI Microservices | |

---

## 8.7 Test Node Failure — Simulazione Crash RAC

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

## 8.8 Test GoldenGate dopo Switchover

> CRITICO: Dopo un switchover Data Guard, l'Extract GoldenGate deve essere spostato o riconfigurato perché il primario è cambiato.

```
PRIMA dello switchover:
  Primary (RACDB, rac1) → GG Extract/Pump → Target (dbtarget)
                        → DG Redo → Standby (RACDB_STBY)

DOPO lo switchover:
  New-Primary (RACDB_STBY, racstby1)
  Old-Primary (RACDB, rac1, ora standby)

  ⚠️ L'Extract GG era su rac1, che ora è standby!
  → Devi FERMARE l'Extract su rac1 e RIAVVIARLO dal nuovo primario (racstby1)
  → Oppure usare la funzione Integrated Extract che si adatta automaticamente
     al nuovo primario (se configurato correttamente con DG Broker)
```

```bash
# 1. Fai switchover
dgmgrl /@RACDB
SWITCHOVER TO RACDB_STBY;

# 2. L'Extract era sul vecchio primario (rac1).
#    Con Integrated Extract registrato nel database,
#    devi fermarlo e riavviarlo dal nuovo primario.

# Su rac1 (ora standby): ferma l'Extract
cd $OGG_HOME && ./ggsci
STOP EXTRACT ext_rac
STOP EXTRACT pump_rac

# Su racstby1 (ora primario): avvia l'Extract
# (GoldenGate deve essere installato anche qui)
cd $OGG_HOME && ./ggsci
START EXTRACT ext_rac
START EXTRACT pump_rac
INFO ALL
# Extract e Pump devono essere RUNNING

# 3. Inserisci dati sul nuovo primario
sqlplus testdg@RACDB_STBY
INSERT INTO test_replica VALUES (6000, 'Post-Switchover GG Test', SYSTIMESTAMP);
COMMIT;

# 4. Verifica sul target
sqlplus testdg@dbtarget
SELECT * FROM test_replica WHERE id = 6000;
-- Deve esistere!
```

```bash
# 5. Switchback
dgmgrl /@RACDB_STBY
SWITCHOVER TO RACDB;

# 6. Sposta di nuovo l'Extract su rac1
# Su racstby1: STOP
STOP EXTRACT ext_rac
STOP EXTRACT pump_rac

# Su rac1 (di nuovo primario): START
START EXTRACT ext_rac
START EXTRACT pump_rac
INFO ALL
# Tutto RUNNING? → BRAVO!
```

---

## 8.8A Drill FSFO Opzionale — Crash Primary

Esegui questo drill solo dopo aver completato la
[Fase 4B: Observer Server e FSFO](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4B_FSFO_OBSERVER.md).
Il test è distruttivo: arresta tutte le VM e crea un cold backup completo delle
cartelle VirtualBox prima di iniziare.

> [!IMPORTANT]
> Non usare `SHUTDOWN IMMEDIATE`: Oracle non lo considera un evento FSFO. Simula
> invece il guasto improvviso dell'intero primary site spegnendo forzatamente le
> VM primary oppure isolandone la rete, lasciando attivi standby e `observer1`.

Prima del fault verifica:

```dgmgrl
SHOW CONFIGURATION;
VALIDATE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
SHOW OBSERVER;
```

Dopo il fault, collegati al database promosso e verifica:

```dgmgrl
SHOW CONFIGURATION;
SHOW FAST_START FAILOVER;
SHOW OBSERVER;
```

Conferma che `RACDB_STBY` sia diventato primary e che le applicazioni usino il
servizio corretto. Ripristina poi le VM del vecchio primary e valida il reinstate
automatico; se Flashback Database non è utilizzabile, esegui RMAN Duplicate
seguendo la [guida failover e reinstate](../../02_core_dba/04_high_availability_and_rac/GUIDA_FAILOVER_E_REINSTATE.md).

Come test separato e non distruttivo, arresta solo `observer1`: il database non
deve cambiare ruolo. Se hai configurato `observer2`, verifica che diventi master.

---

## 8.9 Troubleshooting — Problemi Comuni e Soluzioni

### Problemi Cluster (Clusterware)

| Problema | Causa Probabile | Soluzione |
|---|---|---|
| `crsctl check crs` fallisce | CRS non partito correttamente | `crsctl start crs` (come root) |
| Un nodo si "evict" dal cluster | Interconnect down o heartbeat perso | Controlla `ip addr show enp0s9`, ping nodo remoto |
| VIP non migra | Network mask errata | Verifica subnet VIP con `srvctl config vip -n rac1` |
| ORA-29702: error occurred | ocssd.log errori networking | Controlla `/u01/app/19.0.0/grid/log/<host>/ocssd/ocssd.log` |

### Problemi Data Guard

| Problema | Causa Probabile | Soluzione |
|---|---|---|
| Transport Lag cresce | Rete lenta o listener standby down | `lsnrctl status` su standby, controlla banda |
| Apply Lag cresce | Standby in "no apply" state | `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;` |
| ORA-16191: Primary log shipping disabled | `log_archive_dest_state_2` = DEFER | `ALTER SYSTEM SET log_archive_dest_state_2=ENABLE;` |
| GAP rilevato nel DGMGRL | Archivelog mancante | `ALTER SYSTEM SET fal_server='RACDB'` su standby, il FAL richiederà i log |
| DGMGRL mostra WARNING | Stale redo log detected | `ALTER SYSTEM SWITCH LOGFILE;` + verifica FAL |

### Problemi GoldenGate

| Problema | Causa Probabile | Soluzione |
|---|---|---|
| Extract ABENDED | Redo log non disponibile | `GGSCI> ALTER EXTRACT ext_racdb, BEGIN NOW` |
| Replicat ABENDED | Conflitto duplicato (PK) | Riavvia `REPTAR` da UI/AdminClient, risolvi conflitto e riparti dal checkpoint corretto |
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
# Per il replicat target (REPTAR) usa diagnostics/report dalla UI Microservices
```

---

## 8.10 Tabella Riassuntiva Test COMPLETA

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
| 10 | Lag GG Replicat < 10s | GG | Lag REPTAR da UI Microservices | |
| 11 | **Crash nodo rac2** → rac1 continua | RAC | DB OPEN su rac1, VIP migrato | |
| 12 | **Rejoin nodo rac2** → cluster intatto | RAC | Entrambe le istanze OPEN | |
| 13 | **GG dopo switchover** → replica intatta | DG+GG | Extract RUNNING, dati replicati | |
| 14 | RMAN backup da standby | RMAN | Backup completato senza errori | |
| 15 | RMAN RESTORE VALIDATE | RMAN | Restore simulato OK | |
| 16 | `observer1` registrato | FSFO | `SHOW OBSERVER` coerente | |
| 17 | Drill FSFO opzionale | FSFO | Promozione automatica e reinstate validato | |

## Validazione Finale

Conserva l'output delle verifiche completate. Il drill FSFO è opzionale, ma serve
come evidenza runtime prima di dichiarare FSFO implementato nel laboratorio.

---

## 🎉 Congratulazioni (Lab Oracle Completo)

Hai verificato accuratamente tutti i componenti dell'ecosistema. Questo conclude le guide passo-passo della tua infrastruttura di base.

---

**← [FASE 7: GoldenGate](../../02_core_dba/07_replication_goldengate/GUIDA_FASE7_GOLDENGATE.md)** | 📍 [Indice Percorso Lab](../../04_governance_learning/03_esami_e_carriera/README.md)
