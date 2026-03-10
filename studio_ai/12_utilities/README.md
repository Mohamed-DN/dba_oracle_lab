# 12 — Utilities (Strumenti di Supporto)

> Script utility per il monitoraggio e la manutenzione ordinaria del database.

---

## File Contenuti

### TEMP & UNDO Monitor
- `TEMP_and_UNDO_monitor.sql` — Script per il monitoraggio dell'utilizzo di TEMP e UNDO tablespace.
  Utile per identificare sessioni che consumano troppo spazio temporaneo (es. sort su disco).

### Gestione Tablespace
- `Job_monitoring_TEMP_e_UNDO.sql` — Job schedulato per il monitoraggio automatico con alert.
- `truncate_table_procedure.sql` — Procedura sicura per il troncamento di tabelle con tracking.

### Materialized View
- `mview_refresh_procedure.txt` — Procedura per il refresh automatizzato delle Materialized View.

### Flashback e Restore Point
- `FLASHBACK_RESTORPOINT.sql` — Script per gestire i Guaranteed Restore Point.
- `WAY4_PROD.txt`, `WAY4_STG.txt` — Esempi reali di Restore Point per ambienti WAY4.

### PkgDbaUtility
- `Install_pkg_Dba_Utility_v1_9_PROD.sql` — Package di utility DBA (v1.9, ultima versione).
  Contiene procedure per operazioni DBA comuni automatizzate.

### AFD Dump Recover
- `AFD_dump_recover.txt` — Procedura di recovery per ASM Filter Driver.
- `AFD_lista_virtual_disk.sh` — Script bash per listare i dischi virtuali AFD.

---

## Quick Reference: Monitoraggio TEMP e UNDO

```sql
-- Chi sta usando il TEMP?
SELECT s.sid, s.serial#, s.username, s.program,
       t.tablespace, ROUND(t.blocks * 8192/1024/1024) "TEMP_MB"
FROM v$session s, v$tempseg_usage t
WHERE s.saddr = t.session_addr
ORDER BY t.blocks DESC;

-- Chi sta usando l'UNDO?
SELECT s.sid, s.serial#, s.username, 
       r.usn, ROUND(r.rssize/1024/1024) "UNDO_MB"
FROM v$session s, v$transaction t, v$rollstat r
WHERE s.taddr = t.addr AND t.xidusn = r.usn
ORDER BY r.rssize DESC;
```
