# 06 — Backup & Recovery

> Procedure per backup RMAN, Flashback, e Restore Point in ambiente Oracle Enterprise.

---

## File Contenuti

### [flashback_restore_point.md](./flashback_restore_point.md)
Guida sull'uso di Flashback Database e Guaranteed Restore Point per operazioni sicure (es. prima di un upgrade o deploy).

### [rman_checks.md](./rman_checks.md)
Query SQL per il monitoraggio dello stato dei backup RMAN.

---

## Concetti Chiave

### Guaranteed Restore Point
Un "punto di ripristino garantito" che permette di tornare indietro nel tempo senza perdere dati:
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
Vedi anche: [GUIDA_FASE5_RMAN_BACKUP.md](../../GUIDA_FASE5_RMAN_BACKUP.md)
