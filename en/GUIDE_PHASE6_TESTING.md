# PHASE 6: End-to-End Testing and Troubleshooting

> A system that hasn't been tested is a system that doesn't work. Here we verify the entire chain: RAC Primary → DG Standby → GG Target.

---

## 6.1 Data Guard Redo Verification

```sql
-- On PRIMARY: create test data
CREATE USER testdg IDENTIFIED BY testdg123 DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, CREATE TABLE TO testdg;

CONNECT testdg/testdg123
CREATE TABLE test_replica (id NUMBER PRIMARY KEY, msg VARCHAR2(50), ts TIMESTAMP DEFAULT SYSTIMESTAMP);
INSERT INTO test_replica VALUES (1, 'Data Guard test', SYSTIMESTAMP);
INSERT INTO test_replica VALUES (2, 'Redo shipping verify', SYSTIMESTAMP);
COMMIT;
ALTER SYSTEM SWITCH LOGFILE;  -- Force redo shipping
```

```sql
-- On STANDBY: verify
SELECT * FROM testdg.test_replica;  -- Must show 2 rows
SELECT name, value FROM v$dataguard_stats WHERE name LIKE '%lag%';  -- 0 seconds
```

## 6.2 Switchover Test

```
DGMGRL> VALIDATE DATABASE RACDB_STBY;
DGMGRL> SWITCHOVER TO RACDB_STBY;   -- Roles reversed
DGMGRL> SWITCHOVER TO RACDB;         -- Restore original
```

## 6.3-6.6 GoldenGate + DML Tests

Insert/Update/Delete on Primary → verify on Target via GoldenGate.

## 6.7 Node Crash Simulation

```bash
# Kill rac2 brutally in VirtualBox → Verify rac1 continues serving
srvctl status database -d RACDB  # RACDB1 running, RACDB2 not running
# Restart rac2 → automatic cluster rejoin
```

## 6.8 GoldenGate After Switchover

After DG switchover, verify Extract still RUNNING and replication continues.

## 6.9 Troubleshooting Quick Reference

| Problem | Solution |
|---|---|
| CRS won't start | `crsctl start crs` (as root) |
| DG Transport Lag | Check listener on standby, network bandwidth |
| DG Apply Lag | `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;` |
| GG Extract ABENDED | `ALTER EXTRACT ext_racdb, BEGIN NOW` |
| GG Replicat ABENDED | Resolve PK conflict, `ALTER REPLICAT rep_racdb, BEGIN NOW` |
| RMAN FRA full | `DELETE NOPROMPT OBSOLETE;` |
| Node evicted | Check interconnect: `ping rac2-priv` |

### Log Locations

```bash
# Database Alert Log
adrci → SHOW ALERT -tail 50

# Cluster Log
/u01/app/19.0.0/grid/log/<host>/ocssd/ocssd.log

# GoldenGate
$OGG_HOME/dirrpt/ext_racdb.rpt
```

---

**→ Next: [PHASE 7: RMAN Backup](./GUIDE_PHASE7_RMAN_BACKUP.md)**
