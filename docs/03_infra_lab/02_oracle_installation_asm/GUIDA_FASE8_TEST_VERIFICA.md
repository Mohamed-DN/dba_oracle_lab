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

# GoldenGate MA sul PRIMARIO (rac1)
$OGG_HOME/bin/adminclient
CONNECT https://rac1.localdomain:9012 AS oggadmin
# Inserisci la password nel prompt interattivo
INFO EXTRACT EXT_RAC
```

```sql
-- Primario deve essere stabile
sqlplus / as sysdba
SELECT open_mode, database_role FROM v$database;
```

Requisiti:

- DGMGRL in `SUCCESS`
- Extract `EXT_RAC` e Distribution Path WSS `RUNNING` sul **primario** (`rac1`)
- Replicat `REP_TGT` `RUNNING` sul **target** (`dbtarget`)
- Primary in `READ WRITE`, standby in apply

Per test avanzati usa la matrice completa in [GUIDA_FASE7_GOLDENGATE.md](../../02_core_dba/07_replication_goldengate/GUIDA_FASE7_GOLDENGATE.md) sezione 7.13.

## 8.1 Test Data Guard — Verifica Redo Transport

### Sul Primario: Genera traffico

```sql
sqlplus / as sysdba

-- Crea uno schema di test
ALTER SESSION SET CONTAINER=RACDBPDB;
ACCEPT testdg_password CHAR PROMPT 'Password temporanea TESTDG: ' HIDE
CREATE USER testdg IDENTIFIED BY "&testdg_password"
    DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, CREATE TABLE TO testdg;
UNDEFINE testdg_password

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

### Sullo Standby: verifica trasporto e apply

```sql
-- Funziona anche con standby mounted: Active Data Guard non è obbligatorio.
sqlplus / as sysdba

-- Verifica lo stato di apply
SELECT process, status, thread#, sequence#
FROM v$managed_standby
WHERE process IN ('MRP0','RFS');

-- Verifica il Transport Lag
SELECT name, value, datum_time FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag','apply finish time');
```

> **Output atteso:**
> - `transport lag`: 0 secondi — i redo arrivano in tempo reale.
> - `apply lag`: 0 secondi o pochi secondi — i redo vengono applicati immediatamente.

Se hai superato il gate licenza Active Data Guard e lo standby è aperto
`READ ONLY WITH APPLY`, verifica anche la riga applicativa tramite il servizio
PDB read-only role-based. Nel Data Guard base questa query non è richiesta.

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

```bash
# I servizi applicativi devono seguire il ruolo previsto
srvctl status service -db RACDB
srvctl status service -db RACDB_STBY
```

```sql
sqlplus testdg@RACDBPDB_PRY

INSERT INTO test_replica VALUES (3, 'Post-Switchover Test', SYSTIMESTAMP);
COMMIT;
```

```sql
-- Verifica apply sul NUOVO standby RACDB anche se resta mounted
sqlplus / as sysdba
SELECT name, value, datum_time FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag');
```

Se Active Data Guard è licenziato e attivo, esegui anche la query applicativa
tramite il servizio PDB read-only del nuovo standby.

### Switchover di ritorno

```bash
dgmgrl /@RACDB_STBY

SWITCHOVER TO RACDB;

SHOW CONFIGURATION;
-- Tutto torna come prima
```

---

## 8.3 Test GoldenGate — Verifica Replica End-to-End

### Sul Primario (rac1): verifica Extract e Distribution Path

```bash
$OGG_HOME/bin/adminclient
CONNECT https://rac1.localdomain:9012 AS oggadmin
# Inserisci la password nel prompt interattivo
INFO EXTRACT EXT_RAC
```

Apri quindi il Distribution Server MA e verifica che il path WSS
`RAC_TO_TGT` sia `RUNNING`. In MA il Distribution Path sostituisce il pump
Classic.

### Sul Target (dbtarget): Verifica stato Replicat

```bash
$OGG_HOME/bin/adminclient
CONNECT https://dbtarget.localdomain:9012 AS oggadmin
# Inserisci la password nel prompt interattivo
INFO REPLICAT REP_TGT
```

### Genera traffico e verifica

```sql
-- Preparazione una tantum: esegui sul source RACDBPDB e sul target Oracle.
-- APP deve essere incluso nel mapping e nel supplemental logging della Fase 7.
sqlplus / as sysdba
-- Sul target usa la PDB corrispondente; ometti la riga se è non-CDB.
ALTER SESSION SET CONTAINER=RACDBPDB;

CREATE TABLE app.gg_test_replica (
    id NUMBER PRIMARY KEY,
    note VARCHAR2(100),
    ts_insert TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Solo sul source RACDBPDB:
INSERT INTO app.gg_test_replica VALUES (100, 'GoldenGate Test 1', SYSTIMESTAMP);
INSERT INTO app.gg_test_replica VALUES (101, 'GoldenGate Test 2', SYSTIMESTAMP);
INSERT INTO app.gg_test_replica VALUES (102, 'GoldenGate Test 3', SYSTIMESTAMP);
COMMIT;
```

```sql
-- Sul target Oracle, dopo pochi secondi
SELECT * FROM app.gg_test_replica WHERE id >= 100;
-- Devi vedere le 3 righe inserite dal primario!
```

> Se le righe sono presenti sul target, la catena completa funziona:
> **RAC Primary → Extract → Distribution Path WSS → Replicat → Target**
>
> In parallelo, Data Guard continua a proteggere: Primary → Standby (RACDB_STBY)

### Verifica statistiche GoldenGate

```text
-- AdminClient sul source
STATS EXTRACT EXT_RAC, LATEST

-- AdminClient sul target
STATS REPLICAT REP_TGT, LATEST
```

---

## 8.4 Test di Stress — Volume

```sql
-- Sul Primario RACDBPDB
sqlplus / as sysdba
ALTER SESSION SET CONTAINER=RACDBPDB;

BEGIN
    FOR i IN 1000..2000 LOOP
        INSERT INTO app.gg_test_replica VALUES (i, 'Stress Test Row ' || i, SYSTIMESTAMP);
    END LOOP;
    COMMIT;
END;
/
```

```text
-- AdminClient sul source
LAG EXTRACT EXT_RAC

-- AdminClient sul target
LAG REPLICAT REP_TGT
```

```sql
-- Dopo qualche secondo, verifica sul Target
SELECT COUNT(*) FROM app.gg_test_replica;
-- Deve corrispondere al conteggio sul primario
```

---

## 8.5 Test DML Completo (INSERT / UPDATE / DELETE)

```sql
-- Sul Primario RACDBPDB
sqlplus / as sysdba
ALTER SESSION SET CONTAINER=RACDBPDB;

-- UPDATE
UPDATE app.gg_test_replica SET note = 'UPDATED ROW' WHERE id = 100;
COMMIT;

-- DELETE
DELETE FROM app.gg_test_replica WHERE id = 101;
COMMIT;

-- DDL (se hai configurato DDL replication in GG)
ALTER TABLE app.gg_test_replica ADD (email VARCHAR2(100));

-- INSERT con nuova colonna
INSERT INTO app.gg_test_replica VALUES (9999, 'DDL Test', SYSTIMESTAMP, 'test@oracle.com');
COMMIT;
```

```sql
-- Verifica sul Target
SELECT * FROM app.gg_test_replica WHERE id IN (100, 101, 9999);
-- id=100: note = 'UPDATED ROW'
-- id=101: NON deve esistere (deleted)
-- id=9999: deve esistere con email
```

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

```

```bash
# Controlla i servizi del cluster
crsctl stat res -t
# rac2 sarà OFFLINE, rac1 avrà entrambi i VIP

# Verifica la risorsa VIP senza modificare local_listener
srvctl status vip -n rac2

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

# Il VIP di rac2 deve essere nuovamente ONLINE sul nodo atteso
srvctl status vip -n rac2

# Verifica che il database si riapre
srvctl status database -d RACDB
# RACDB1 e RACDB2 entrambi running
```

---

## 8.8 Test GoldenGate dopo Switchover

> CRITICO: pianifica questo drill solo se GoldenGate MA è installato e
> configurato su entrambi i siti source. Lo switchover Data Guard non sposta
> automaticamente il deployment MA.

```
PRIMA dello switchover:
  Primary (RACDB, rac1) → Extract + Distribution Path → Target (dbtarget)
                        → DG Redo → Standby (RACDB_STBY)

DOPO lo switchover:
  New-Primary (RACDB_STBY, racstby1)
  Old-Primary (RACDB, rac1, ora standby)

  L'Extract GG era su rac1, che ora è standby.
  → Ferma il deployment source del vecchio primary.
  → Avvia Extract e Distribution Path sul nuovo primary.
  → Verifica checkpoint e lag prima di riaprire il traffico applicativo.
```

```dgmgrl
# 1. In DGMGRL fai switchover
SWITCHOVER TO RACDB_STBY;
```

```text
# 2. In AdminClient, sul deployment MA source del vecchio primary:
CONNECT https://rac1.localdomain:9012 AS oggadmin
STOP EXTRACT EXT_RAC
# Arresta anche il Distribution Path RAC_TO_TGT dalla UI MA.

# 3. Dal deployment MA predisposto sul nuovo primary:
CONNECT https://racstby1.localdomain:9012 AS oggadmin
START EXTRACT EXT_RAC
# Avvia RAC_TO_TGT dalla UI e verifica che il protocollo sia WSS.
INFO EXTRACT EXT_RAC
```

```sql
# 4. Inserisci dati sul nuovo primario, nella PDB applicativa
sqlplus / as sysdba
ALTER SESSION SET CONTAINER=RACDBPDB;
INSERT INTO app.gg_test_replica (id, note, ts_insert)
VALUES (6000, 'Post-Switchover GG Test', SYSTIMESTAMP);
COMMIT;

# 5. Verifica sul target
SELECT * FROM app.gg_test_replica WHERE id = 6000;
-- Deve esistere!
```

```dgmgrl
# 6. In DGMGRL esegui switchback
SWITCHOVER TO RACDB;
```

```text
# 7. Ripeti la transizione MA in senso inverso
CONNECT https://racstby1.localdomain:9012 AS oggadmin
STOP EXTRACT EXT_RAC
# Arresta RAC_TO_TGT dalla UI.

CONNECT https://rac1.localdomain:9012 AS oggadmin
START EXTRACT EXT_RAC
# Avvia RAC_TO_TGT dalla UI e registra checkpoint e lag.
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

Definisci prima del test il fencing del vecchio primary: console VirtualBox,
accesso ai due nodi e criterio di isolamento della rete devono essere
disponibili. Dopo la promozione non riaccendere né riconnettere il vecchio sito
finché il Broker non ne governa il reinstate. Questo evita split-brain.

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
| GAP rilevato nel DGMGRL | Archivelog mancante | Sullo standby verifica `V$ARCHIVE_GAP`, poi segui la ladder FAL → copia e `REGISTER PHYSICAL LOGFILE` → recovery from service → incremental `FROM SCN` |
| DGMGRL mostra WARNING | Stale redo log detected | `ALTER SYSTEM SWITCH LOGFILE;` + verifica FAL |

### Problemi GoldenGate

| Problema | Causa Probabile | Soluzione |
|---|---|---|
| Extract `EXT_RAC` ABENDED | Redo non disponibile o checkpoint da verificare | Analizza report e checkpoint da UI/AdminClient; non saltare redo con `BEGIN NOW` senza change autorizzato |
| Replicat ABENDED | Conflitto duplicato (PK) | Riavvia `REP_TGT` da UI/AdminClient, risolvi conflitto e riparti dal checkpoint corretto |
| Lag alto Extract | LogMiner lento | Verifica `v$goldengate_capture` per colli di bottiglia |
| Lag alto Replicat | Batch troppo piccolo | Aumenta `BATCHSQL` nel param Replicat |
| Trail pieno su disco | Distribution Path non trasmette | Verifica Receiver Server, rete WSS e stato del path `RAC_TO_TGT` dalla UI MA |

### Problemi RMAN

| Problema | Causa Probabile | Soluzione |
|---|---|---|
| ORA-19502: write error | FRA piena | Verifica spazio, deletion policy e stato DG; usa [DG-061](../../01_operations/02_runbooks_incidenti/RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md#dg-061---primary-fra-piena-per-standby-lag) |
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

# Log GoldenGate MA
# Usa Diagnostics/Report dalla UI MA o AdminClient per EXT_RAC e REP_TGT.
```

---

## 8.10 Tabella Riassuntiva Test COMPLETA

| # | Test | Dove | Risultato Atteso | ✅/❌ |
|---|---|---|---|---|
| 1 | INSERT e log switch sul primary | DG | Redo ricevuto e applicato; query dati solo con ADG opzionale | |
| 2 | Transport Lag = 0 | DG | dgmgrl SHOW DATABASE | |
| 3 | Apply Lag = 0 o ~secondi | DG | dgmgrl SHOW DATABASE | |
| 4 | Switchover + Switchback | DG | Nessuna perdita dati, SUCCESS | |
| 5 | INSERT su Primary → visibile su Target | GG | Righe replicate via GG | |
| 6 | UPDATE → replicato su Target | GG | Modifiche su target | |
| 7 | DELETE → replicato su Target | GG | Riga cancellata su target | |
| 8 | Stress 1000 righe → tutte su Target | GG | COUNT(*) identico | |
| 9 | Lag GG Extract < 10s | GG | LAG EXTRACT | |
| 10 | Lag GG Replicat < 10s | GG | Lag REP_TGT da UI Microservices | |
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
