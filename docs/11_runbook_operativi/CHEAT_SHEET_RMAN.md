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

## RMAN Commands Cheat Sheet (Quick Reference)

### 1) Connessione a RMAN

```rman
rman target /
rman target / catalog rman/password@catdb
rman target sys/password@orcl
rman target / auxiliary sys/password@clone
```

### 2) Backup database

```rman
BACKUP DATABASE;
BACKUP DATABASE PLUS ARCHIVELOG;
BACKUP DATABASE PLUS ARCHIVELOG DELETE INPUT;
BACKUP AS COMPRESSED BACKUPSET DATABASE;
BACKUP DATABASE FORMAT '/backup/%d_%T_%s_%p.bkp';
```

### 3) Backup tablespace, datafile, controlfile, spfile

```rman
BACKUP TABLESPACE users, example;
BACKUP DATAFILE 4;
BACKUP DATAFILE '/u01/oradata/orcl/users01.dbf';
BACKUP CURRENT CONTROLFILE;
BACKUP SPFILE;
```

### 4) Backup incremental

```rman
BACKUP INCREMENTAL LEVEL 0 DATABASE;
BACKUP INCREMENTAL LEVEL 1 DATABASE;
BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE;
```

Block Change Tracking (prima abilita):

```sql
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING
  USING FILE '/u01/oradata/orcl/bct.dbf';
```

### 5) Backup archivelog

```rman
BACKUP ARCHIVELOG ALL;
BACKUP ARCHIVELOG ALL DELETE INPUT;
BACKUP ARCHIVELOG FROM SEQUENCE 100 UNTIL SEQUENCE 200;
BACKUP ARCHIVELOG FROM TIME 'SYSDATE-1';
```

### 6) Restore database, tablespace, datafile

```rman
RESTORE DATABASE;
RESTORE DATABASE UNTIL TIME "TO_DATE('2024-01-15 10:00:00','YYYY-MM-DD HH24:MI:SS')";
RESTORE DATABASE UNTIL SCN 1234567;
RESTORE TABLESPACE users;
RESTORE DATAFILE 4;
```

### 7) Restore controlfile e spfile

```rman
RESTORE CONTROLFILE FROM AUTOBACKUP;
RESTORE CONTROLFILE FROM '/backup/ctl_backup.bkp';
RESTORE SPFILE FROM AUTOBACKUP;
RESTORE SPFILE TO '/u01/app/oracle/dbs/spfileorcl.ora' FROM AUTOBACKUP;
```

### 8) Recovery

```rman
RECOVER DATABASE;
RECOVER DATABASE UNTIL TIME "TO_DATE('2024-01-15 10:00:00','YYYY-MM-DD HH24:MI:SS')";
RECOVER DATABASE UNTIL SCN 1234567;
RECOVER TABLESPACE users;
RECOVER DATAFILE 4;
```

Post PITR:

```sql
ALTER DATABASE OPEN RESETLOGS;
```

### 9) LIST

```rman
LIST BACKUP;
LIST BACKUP OF DATABASE;
LIST BACKUP SUMMARY;
LIST BACKUP OF ARCHIVELOG ALL;
LIST BACKUP TAG 'daily_full';
LIST EXPIRED BACKUP;
LIST INCARNATION;
LIST FAILURE;
```

### 10) REPORT

```rman
REPORT NEED BACKUP;
REPORT NEED BACKUP DAYS 2;
REPORT OBSOLETE;
REPORT SCHEMA;
REPORT UNRECOVERABLE;
```

### 11) CROSSCHECK e DELETE

```rman
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
CROSSCHECK BACKUPSET 123;
CROSSCHECK COPY;

DELETE EXPIRED BACKUP;
DELETE OBSOLETE;
DELETE BACKUPSET 123;
DELETE BACKUP COMPLETED BEFORE 'SYSDATE-7';
DELETE ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-7';
DELETE NOPROMPT OBSOLETE;
```

### 12) CONFIGURE

```rman
SHOW ALL;
CONFIGURE RETENTION POLICY TO REDUNDANCY 2;
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/backup/%d_%T_%s_%p.bkp';
CONFIGURE DEVICE TYPE DISK PARALLELISM 4;
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/backup/%F';
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE ENCRYPTION FOR DATABASE ON;
CONFIGURE RETENTION POLICY CLEAR;
```

### 13) CATALOG

```rman
CATALOG BACKUPPIECE '/backup/backup.bkp';
CATALOG START WITH '/backup/';
CATALOG DATAFILECOPY '/u01/copy/users01.dbf';
UNCATALOG EXPIRED BACKUP;
```

### 14) VALIDATE / PREVIEW

```rman
VALIDATE DATABASE;
VALIDATE DATAFILE 4;
VALIDATE BACKUPSET 123;
VALIDATE CHECK LOGICAL DATABASE;
RESTORE DATABASE PREVIEW;
RESTORE DATABASE PREVIEW SUMMARY;
```

### 15) DUPLICATE

```rman
DUPLICATE TARGET DATABASE TO newdb;
DUPLICATE TARGET DATABASE TO newdb FROM ACTIVE DATABASE;
DUPLICATE TARGET DATABASE TO newdb
  UNTIL TIME "TO_DATE('2024-01-15 10:00:00','YYYY-MM-DD HH24:MI:SS')";
DUPLICATE TARGET DATABASE TO newdb
  DB_FILE_NAME_CONVERT '/u01/oradata/prod', '/u02/oradata/clone'
  SPFILE
    SET DB_UNIQUE_NAME='newdb';
```

### 16) Block Recovery

```rman
BLOCKRECOVER DATAFILE 4 BLOCK 100;
BLOCKRECOVER DATAFILE 4 BLOCK 100,101,102;
BLOCKRECOVER DATAFILE 4 BLOCK 100 FROM BACKUPSET;
```

### 17) Scripting & Automation

```rman
@/scripts/backup.rman
CREATE SCRIPT daily_backup {
  BACKUP DATABASE PLUS ARCHIVELOG DELETE INPUT;
}
RUN { EXECUTE SCRIPT daily_backup; }
DELETE SCRIPT daily_backup;
PRINT SCRIPT daily_backup;
```

### 18) Tag utili

```rman
BACKUP DATABASE TAG 'weekly_full';
BACKUP INCREMENTAL LEVEL 1 DATABASE TAG 'daily_inc';
BACKUP ARCHIVELOG ALL TAG 'arch_backup';
RESTORE DATABASE FROM TAG 'weekly_full';
```

### 19) Format specifiers (RMAN)

| Specifier | Descrizione |
| --- | --- |
| `%d` | Database name |
| `%D` | Giorno (DD) |
| `%M` | Mese (MM) |
| `%Y` | Anno (YYYY) |
| `%T` | Data (YYYYMMDD) |
| `%s` | Backup set number |
| `%p` | Piece number |
| `%c` | Channel number |
| `%U` | Unique filename |
| `%F` | Unique format (c-IIIIIIIIII-YYYYMMDD-QQ) |

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
- Oracle ufficiale (User's Guide): <https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/>
- Oracle ufficiale (RMAN Reference): <https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/index.html>
- Cheat sheet esterna: <https://oracledaybyday.com/rman-commands-cheat-sheet/>
