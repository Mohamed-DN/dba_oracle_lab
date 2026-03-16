# 06 — Backup & Recovery

> Procedure per backup RMAN, Flashback, e Restore Point in ambiente Oracle Enterprise.

---

## File Contents

### [flashback_restore_point.md](./flashback_restore_point.md)
Guide on using Flashback Database and Guaranteed Restore Point for secure operations (e.g. before an upgrade or deployment).

### [rman_checks.md](./rman_checks.md)
SQL query for monitoring the status of RMAN backups.

---

## Key Concepts

### Guaranteed Restore Point
A "guaranteed restore point" that allows you to go back in time without losing data:
```sql
--Creation (before a risky activity)
CREATE RESTORE POINT BEFORE_UPGRADE GUARANTEE FLASHBACK DATABASE;

--Verify
SELECT NAME, SCN, TIME, GUARANTEE_FLASHBACK_DATABASE FROM v$restore_point;

--Full rollback to restore point
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
FLASHBACK DATABASE TO RESTORE POINT BEFORE_UPGRADE;
ALTER DATABASE OPEN RESETLOGS;

--Cleaning after the success of the business
DROP RESTORE POINT BEFORE_UPGRADE;
```

> [!WARNING]
> Guaranteed Restore Points consume space in the FRA. Monitor`V$RECOVERY_FILE_DEST`to avoid filling!

---

## 🔗 Link
See also: [GUIDE_PHASE7_RMAN_BACKUP.md](../../GUIDE_PHASE7_RMAN_BACKUP.md)
