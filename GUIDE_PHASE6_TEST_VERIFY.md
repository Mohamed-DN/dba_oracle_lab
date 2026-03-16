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
--Standby must be usable from DD
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

--Create a test pattern
CREATE USER testdg IDENTIFIED BY testdg123
    DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, CREATE TABLE TO testdg;

--Enter data
CONNECT testdg/testdg123

CREATE TABLE test_replica (
    id        NUMBER PRIMARY KEY,
    nome      VARCHAR2(50),
    ts_insert TIMESTAMP DEFAULT SYSTIMESTAMP
);

INSERT INTO test_replica VALUES (1, 'Test Data Guard', SYSTIMESTAMP);
INSERT INTO test_replica VALUES (2, 'Verify Redo Shipping', SYSTIMESTAMP);
COMMIT;

--Force a log switch to speed up shipping
CONNECT / AS SYSDBA
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
```

### On Standby: Verify that data has arrived

```sql
-- Lo standby deve essere in READ ONLY (Active Data Guard)
sqlplus / as sysdba

--Check the status of apply
SELECT process, status, thread#, sequence#
FROM v$managed_standby
WHERE process IN ('MRP0','RFS');

--Check the data
SELECT * FROM testdg.test_replica;
--If you see the 2 lines, Data Guard works!

--Check Transport Lag
SELECT name, value, datum_time FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag','apply finish time');
```

> **Output atteso:**
> - `transport lag`: 0 seconds — redos arrive in real time.
> - `apply lag`: 0 seconds or a few seconds — redos are applied immediately.
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

--Verify that switchover is possible
VALIDATE DATABASE RACDB_STBY;
-- Deve mostrare: "Ready for Switchover: Yes"

--Perform the switchover
SWITCHOVER TO RACDB_STBY;
```

After switchover:

```bash
SHOW CONFIGURATION;
-- RACDB_STBYis now Primary
--RACDB is now Physical Standby

--Verify that replication works in reverse
--Enter data on the NEW primary (RACDB_STBY)
```

```sql
sqlplus testdg/testdg123@RACDB_STBY

INSERT INTO test_replica VALUES (3, 'Post-Switchover Test', SYSTIMESTAMP);
COMMIT;
```

```sql
--Check on NEW standby (RACDB, now in mount/read only)
sqlplus / as sysdba

SELECT * FROM testdg.test_replica;
--You need to see the line with id=3
```

### Switchover di ritorno

```bash
dgmgrl sys/<password>@RACDB_STBY

SWITCHOVER TO RACDB;

SHOW CONFIGURATION;
--Everything goes back to how it was before
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

Sul target OCI con GoldenGate Microservices non usare `ggsci`classic.

Controlla da Web UI (Administration Server):

- replicat `REPTAR` in state `Running`
- progress checkpoint
- lag basso/stabile
- no errors in diagnostics

### Generate traffic and verify

```sql
--On the Primary (RACDB)
sqlplus testdg/testdg123@RACDB

INSERT INTO test_replica VALUES (100, 'GoldenGate Test 1', SYSTIMESTAMP);
INSERT INTO test_replica VALUES (101, 'GoldenGate Test 2', SYSTIMESTAMP);
INSERT INTO test_replica VALUES (102, 'GoldenGate Test 3', SYSTIMESTAMP);
COMMIT;
```

```sql
--On Target (dbtarget) - after a few seconds
sqlplus testdg/testdg123@dbtarget

SELECT * FROM test_replica WHERE id >= 100;
--You must see the 3 lines inserted by the head doctor!
```

> If the rows are present on the target, the complete chain works:
> **RAC Primary → (DG Redo) → RAC Standby → (GG Extract/Pump) → Target DB (GG Replicat)**

### Check GoldenGate statistics

```
-- Sullo Standby
GGSCI> STATS EXTRACT ext_racdb, LATEST
--Shows the tables and the number of operations captured

GGSCI> STATS EXTRACT pump_racdb, LATEST

-- Sul Target
--check statistics from the REPTAR replicat panel (Microservices UI)
--and from the diagnostics / performance section
```

---

## 6.4 Test di Stress — Volume

```sql
--On the Primary
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
--Monitor real-time lag on GoldenGate
GGSCI> LAG EXTRACT ext_racdb
--On the target check lag of the REPTAR replicat from UI Microservices
```

```sql
--After a few seconds, check on Target
SELECT COUNT(*) FROM testdg.test_replica;
--Must match the count on the primary
```

---

## 6.5 Complete DML Test (INSERT / UPDATE / DELETE)

```sql
--On the Primary
sqlplus testdg/testdg123@RACDB

-- UPDATE
UPDATE test_replica SET nome = 'UPDATED ROW' WHERE id = 1;
COMMIT;

-- DELETE
DELETE FROM test_replica WHERE id = 2;
COMMIT;

--DDL (if you have configured DDL replication in GG)
ALTER TABLE test_replica ADD (email VARCHAR2(100));

--INSERT with new column
INSERT INTO test_replica VALUES (9999, 'DDL Test', SYSTIMESTAMP, 'test@oracle.com');
COMMIT;
```

```sql
--Check on the Target
SELECT * FROM testdg.test_replica WHERE id IN (1, 2, 9999);
--id=1: name = 'UPDATED ROW'
-- id=2: NON deve esistere (deleted)
-- id=9999: deve esistere con email
```

---

## 6.6 Test Summary Table

| # | Test | Dove |Expected Result| ✅/❌ |
|---|---|---|---|---|
| 1 | INSERT on Primary → visible on Standby | DG |Lines visible in real time| |
| 2 | Transport Lag = 0 | DG | dgmgrl SHOW DATABASE | |
| 3 | Apply Lag = 0 o ~secondi | DG | dgmgrl SHOW DATABASE | |
| 4 | Switchover + Switchback | DG |No data loss, SUCCESS| |
| 5 | INSERT su Primary → visibile su Target | GG | Righe replicate via GG | |
| 6 |UPDATE → replicated on Target| GG |Changes on target| |
| 7 |DELETE → replicated to Target| GG |Line deleted on target| |
| 8 | Stress 1000 lines → all on Target | GG |COUNT(*) identical| |
| 9 | Lag GG Extract < 10s | GG | LAG EXTRACT | |
| 10 | Lag GG Replicat < 10s | GG |REPTAR lag from UI Microservices| |

---

## 6.7 Test Node Failure — Simulazione Crash RAC

> This is the most important test: the RAC must survive the loss of a node.

### Test: Brutal shutdown of a node

```bash
# In VirtualBox: Select rac2 → Right Click → Close → Brutal Shutdown
# Or on the rac2 console:
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger  # Crash immediato!
```

### Check on rac1 (must continue to work!)

```sql
sqlplus / as sysdba

--Is the database still OPEN?
SELECT instance_name, status FROM gv$instance;
-- rac1: OPEN
--rac2: not shown (crashed)

--Can you still do DML?
INSERT INTO testdg.test_replica VALUES (5000, 'Node 2 has crashed', SYSTIMESTAMP);
COMMIT;
--If it works → RAC is doing its job!

--Test VIP failover
SELECT name, value FROM v$parameter WHERE name = 'local_listener';
--Has rac2 VIP (.112) migrated to rac1?
```

```bash
#Check cluster services
crsctl stat res -t
#rac2 will be OFFLINE, rac1 will have both VIPs

# Check the database status
srvctl status database -d RACDB
# Instance RACDB1 is running on node rac1
# Instance RACDB2 is not running
```

### Restart rac2 and check for rejoin

```bash
# In VirtualBox: Avvia rac2
# Wait 2-3 minutes to boot

#On rac2 after booting, the cluster joins together automatically
crsctl stat res -t
# Both nodes ONLINE

#Verify that the database reopens
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

#2. Check DD on standby (primary time)
cd $OGG_HOME && ./ggsci
INFO ALL
# Extract e Pump devono essere ancora RUNNING

#3. Enter data on the new primary
sqlplus testdg/testdg123@RACDB_STBY
INSERT INTO test_replica VALUES (6000, 'Post-Switchover GG Test', SYSTIMESTAMP);
COMMIT;

#4. Check on the target
sqlplus testdg/testdg123@dbtarget
SELECT * FROM test_replica WHERE id = 6000;
-- Deve esistere!
```

```bash
# 5. Switchback
dgmgrl sys/<password>@RACDB_STBY
SWITCHOVER TO RACDB;

#6. Check
GGSCI> INFO ALL
# Everything RUNNING? → BRAVO!
```

---

## 6.9 Troubleshooting — Problemi Comuni e Soluzioni

### Problemi Cluster (Clusterware)

| Problema | Causa Probabile |Solution|
|---|---|---|
| `crsctl check crs` fallisce |CRS did not start correctly| `crsctl start crs` (as root) |
| A node "evicts" itself from the cluster | Interconnect down o heartbeat perso | Controlla `ip addr show enp0s9`, ping remote node |
| VIP non migra | Network mask errata | Check VIP subnet with `srvctl config vip -n rac1` |
| ORA-29702: error occurred | ocssd.log errori networking | Controlla `/u01/app/19.0.0/grid/log/<host>/ocssd/ocssd.log` |

### Problemi Data Guard

| Problema | Causa Probabile |Solution|
|---|---|---|
| Transport Lag cresce | Slow network or standby listener down | `lsnrctl status` on standby, check bandwidth |
| Apply Lag cresce | Standby in "no apply" state | `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;` |
| ORA-16191: Primary log shipping disabled | `log_archive_dest_state_2` = DEFER | `ALTER SYSTEM SET log_archive_dest_state_2=ENABLE;` |
|GAP detected in the DGMGRL| Archivelog missing | `ALTER SYSTEM SET fal_server='RACDB'` on standby, the FAL will request logs |
|DGMGRL shows WARNING| Stale redo log detected | `ALTER SYSTEM SWITCH LOGFILE;` + check FAL |

### Problemi GoldenGate

| Problema | Causa Probabile |Solution|
|---|---|---|
| Extract ABENDED |Redo log not available| `GGSCI> ALTER EXTRACT ext_racdb, BEGIN NOW` |
| Replicat ABENDED |Duplicate Conflict (PK)| Riavvia `REPTAR`from UI/AdminClient, resolve the conflict and restart from the correct checkpoint|
| Lag alto Extract | LogMiner lento | Verify `v$goldengate_capture`for bottlenecks|
|High lag Replicat|Batch too small| Aumenta `BATCHSQL`in the Replicat param|
|Full trail on disc|Pump does not transmit| Check network, `INFO EXTRACT pump_racdb` |

### Problemi RMAN

| Problema | Causa Probabile |Solution|
|---|---|---|
| ORA-19502: write error | FRA piena | `DELETE NOPROMPT OBSOLETE;`, aumenta FRA |
| RMAN-06059: expected numeric |Error in script|Check syntax in .sh|
| Backup lentissimo |BCT not active or PARALLELISM=1| `CONFIGURE DEVICE TYPE DISK PARALLELISM 2;` |
|RESTORE fails| Backup corrotto o expired | `CROSSCHECK BACKUP; VALIDATE BACKUP;` |

### Problemi Performance

```sql
--Top 5 SQL by execution time
SELECT sql_id, elapsed_time/1000000 AS secs, executions, 
       SUBSTR(sql_text, 1, 80) AS sql
FROM v$sql ORDER BY elapsed_time DESC FETCH FIRST 5 ROWS ONLY;

--Blocking sessions
SELECT blocking_session, sid, serial#, wait_class, event
FROM v$session WHERE blocking_session IS NOT NULL;

-- Tablespace quasi pieno
SELECT tablespace_name, ROUND(used_percent, 1) AS pct
FROM dba_tablespace_usage_metrics WHERE used_percent > 85;

--ASM almost full
SELECT name, ROUND((1-free_mb/total_mb)*100, 1) AS pct 
FROM v$asm_diskgroup WHERE (1-free_mb/total_mb) > 0.8;
```

### Dove Trovare i Log di Errore

```bash
#Database Alert Log (MOST IMPORTANT)
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
# For the replicat target (REPTAR) use diagnostics/report from the Microservices UI
```

---

## 6.10 COMPLETE Test Summary Table

| # | Test | Dove |Expected Result| ✅/❌ |
|---|---|---|---|---|
| 1 | INSERT on Primary → visible on Standby | DG |Lines visible in real time| |
| 2 | Transport Lag = 0 | DG | dgmgrl SHOW DATABASE | |
| 3 | Apply Lag = 0 o ~secondi | DG | dgmgrl SHOW DATABASE | |
| 4 | Switchover + Switchback | DG |No data loss, SUCCESS| |
| 5 | INSERT su Primary → visibile su Target | GG | Righe replicate via GG | |
| 6 |UPDATE → replicated on Target| GG |Changes on target| |
| 7 |DELETE → replicated to Target| GG |Line deleted on target| |
| 8 | Stress 1000 lines → all on Target | GG |COUNT(*) identical| |
| 9 | Lag GG Extract < 10s | GG | LAG EXTRACT | |
| 10 | Lag GG Replicat < 10s | GG |REPTAR lag from UI Microservices| |
| 11 | **rac2 node crash** → rac1 continues | RAC | DB OPEN su rac1, VIP migrato | |
| 12 | **Rejoin rac2 node** → cluster intact | RAC | Entrambe le istanze OPEN | |
| 13 | **DD after switchover** → replication intact | DG+GG | Extract RUNNING, dati replicati | |
| 14 | RMAN backup from standby | RMAN |Backup completed without errors| |
| 15 | RMAN RESTORE VALIDATE | RMAN |Simulated restore OK| |

---

**→ Next: [STEP 7: RMAN Backup Strategy](./GUIDE_PHASE7_RMAN_BACKUP.md)**
