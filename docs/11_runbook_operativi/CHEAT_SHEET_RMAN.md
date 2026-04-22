# Cheat Sheet RMAN (Operativa)

## Obiettivo

Fornire una scheda rapida RMAN per backup, restore, recovery e monitoraggio quotidiano in ambienti Oracle 19c.

## Teoria

- **RMAN** è il tool nativo Oracle per backup/recovery consistenti.
- Riduce rischi operativi rispetto a backup OS raw (`cp`, `tar`) su DB online.
- Punti chiave: retention policy, catalogazione, validazione, restore test.

## Quando usarla

- Verifica giornaliera backup
- Finestra di manutenzione
- Pre-patching/pre-upgrade
- Incident response (restore/recover)

## Comandi essenziali

### Read-only (sicuri)

- `LIST BACKUP SUMMARY;` → inventario backup
- `REPORT OBSOLETE;` → backup fuori policy
- `SHOW ALL;` → configurazione RMAN
- `CROSSCHECK BACKUP;` → verifica coerenza catalogo/supporto
- `RESTORE DATABASE VALIDATE;` → simula restore senza ripristinare

### Impattanti (usare con change approvata)

- `DELETE NOPROMPT OBSOLETE;` → cancella backup fuori retention
- `DELETE EXPIRED BACKUP;` → elimina record/file expired
- `RESTORE DATABASE;` + `RECOVER DATABASE;` → recovery reale
- `CONFIGURE RETENTION POLICY ...` → cambia policy globale

## Procedura operativa

### 1) Pre-check

1. Verifica modalità archive log: `ARCHIVE LOG LIST;`
2. Verifica FRA: `SELECT * FROM v$recovery_file_dest;`
3. Verifica ultimi job:

```sql
SELECT start_time, end_time, status, input_type
FROM v$rman_backup_job_details
ORDER BY start_time DESC FETCH FIRST 10 ROWS ONLY;
```

### 2) Backup baseline (esempio)

```rman
RUN {
  BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG;
  BACKUP CURRENT CONTROLFILE;
}
```

### 3) Validazione post-backup

```rman
LIST BACKUP SUMMARY;
RESTORE DATABASE VALIDATE;
```

## Validazione finale

- Ultimo backup `COMPLETED`
- Nessun gap tra backup DB e archivelog richiesti
- `RESTORE ... VALIDATE` senza errori
- FRA sotto soglia operativa (es. < 80%)

## Monitoraggio operativo

### SQL rapide

```sql
-- Stato job RMAN
SELECT start_time, end_time, status, output_device_type
FROM v$rman_backup_job_details
ORDER BY start_time DESC;

-- Corruzioni note
SELECT * FROM v$database_block_corruption;

-- Recovery area
SELECT name, space_limit, space_used, space_reclaimable
FROM v$recovery_file_dest;
```

## Troubleshooting rapido

- **RMAN-06059 / archivelog missing**: sincronizza catalogo (`CROSSCHECK` + `DELETE EXPIRED`), verifica retention
- **FRA piena (ORA-19815/ORA-00257)**: libera spazio con policy coerente e backup offload
- **Backup lenti**: verifica I/O, compressione, parallelismo canali
- **Restore non testato**: aggiungi restore drill periodico

## Link correlati

- Runbook: [02_VERIFICA_BACKUP](./02_VERIFICA_BACKUP.md)
- Guida estesa: [GUIDA_FASE5_RMAN_BACKUP](../03_backup_recovery/GUIDA_FASE5_RMAN_BACKUP.md)
- Guida completa: [GUIDA_RMAN_COMPLETA_19C](../03_backup_recovery/GUIDA_RMAN_COMPLETA_19C.md)
- Oracle ufficiale: <https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/>
