# Complete Guide: Data Guard Switchover (Step by Step)

> Switchover is a **planned** operation that reverses Primary and Standby roles with **zero data loss**.

---

## Before/After

```
BEFORE:  PRIMARY (RACDB) ──redo──► STANDBY (RACDB_STBY)
AFTER:   STANDBY (RACDB) ◄──redo── PRIMARY (RACDB_STBY)
```

## Preparation

```bash
dgmgrl sys/<password>@RACDB
SHOW CONFIGURATION;          # Must show SUCCESS
VALIDATE DATABASE RACDB_STBY; # Ready for Switchover: Yes
```

## Execute

```
DGMGRL> SWITCHOVER TO RACDB_STBY;
DGMGRL> SHOW CONFIGURATION;   # Roles reversed, SUCCESS
```

## Verify

```sql
-- New Primary (RACDB_STBY)
SELECT database_role FROM v$database;  -- PRIMARY
INSERT INTO test_replica VALUES (7777, 'Post-switchover', SYSTIMESTAMP);
COMMIT;

-- New Standby (RACDB) — data should replicate
SELECT * FROM testdg.test_replica WHERE id = 7777;
```

## Switchback

```
DGMGRL> SWITCHOVER TO RACDB;  -- Restore original roles
```

## Troubleshooting

| Problem | Solution |
|---|---|
| "Ready for Switchover: No" | Wait for apply lag = 0, force log switch |
| ORA-16467 not in sync | `ALTER SYSTEM SWITCH LOGFILE;` on primary |
| New standby not applying | Check listener and tnsnames |

---

**→ See also: [Failover + Reinstate](./GUIDE_FAILOVER_REINSTATE.md)**
