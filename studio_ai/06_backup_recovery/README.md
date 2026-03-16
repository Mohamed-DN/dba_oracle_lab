# 06 — Backup & Recovery

> Procedure per backup RMAN, Flashback, e Restore Point in ambiente Oracle Enterprise.

---

## File Contenuti

### [flashback_restore_point.md](./flashback_restore_point.md)
Guide on using Flashback Database and Guaranteed Restore Point for secure operations (e.g. before an upgrade or deployment).

### [rman_checks.md](./rman_checks.md)
SQL query for monitoring the status of RMAN backups.

---

## Concetti Chiave

### Guaranteed Restore Point
A "guaranteed restore point" that allows you to go back in time without losing data:
```sql
-- Creazione (prima di un'attività rischiosa)
CREATE RESTORE POINT BEFORE_UPGRADE GUARANTEE FLASHBACK DATABASE;

-- Verifica
SELECT NAME, SCN, TIME, GUARANTEE_FLASHBACK_DATABASE FROM v$restore_point;

-- Rollback completo al punto di ripristino
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
FLASHBACK DATABASE TO RESTORE POINT BEFORE_UPGRADE;
ALTER DATABASE OPEN RESETLOGS;

-- Pulizia dopo il successo dell'attività
DROP RESTORE POINT BEFORE_UPGRADE;
```

> [!WARNING]
> I Guaranteed Restore Point consumano spazio nella FRA. Monitorare `V$RECOVERY_FILE_DEST` per evitare il riempimento!

---

## 🔗 Collegamento
See also: [GUIDE_PHASE7_RMAN_BACKUP.md](../../GUIDE_PHASE7_RMAN_BACKUP.md)
