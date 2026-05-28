# Cheat Sheet RMAN (Essenziale)

> [!NOTE]
> **DOCUMENTI RMAN CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Cheat Sheet Operativo**: [CHEAT_SHEET_RMAN.md](./CHEAT_SHEET_RMAN.md) (scenari operativi comuni).
> - **Cheat Sheet Enterprise**: [RMAN_FULL_CHEATSHEET.md](./RMAN_FULL_CHEATSHEET.md) (scenari complessi, TDE, BMR e tuning).
> - **Manuale Comandi Core**: [GUIDA_RMAN_COMANDI_ENTERPRISE.md](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMANDI_ENTERPRISE.md) (riferimento completo dei parametri).
> - **Guida Architetturale Core**: [GUIDA_RMAN_COMPLETA_19C.md](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md) (fondamenti teorici e scenari avanzati).

## Obiettivo

Scheda ultra-rapida con i comandi RMAN più usati in operatività quotidiana.

## Connessione

```rman
rman target /
rman target / catalog rman/password@catdb
rman target sys/password@orcl
```

## Backup più comuni

```rman
BACKUP DATABASE;
BACKUP DATABASE PLUS ARCHIVELOG;
BACKUP DATABASE PLUS ARCHIVELOG DELETE INPUT;
BACKUP AS COMPRESSED BACKUPSET DATABASE;
BACKUP ARCHIVELOG ALL;
```

Incremental:

```rman
BACKUP INCREMENTAL LEVEL 0 DATABASE;
BACKUP INCREMENTAL LEVEL 1 DATABASE;
BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE;
```

## Restore / Recover

```rman
RESTORE DATABASE;
RECOVER DATABASE;

RESTORE DATABASE UNTIL TIME "TO_DATE('2024-01-15 10:00:00','YYYY-MM-DD HH24:MI:SS')";
RECOVER DATABASE UNTIL TIME "TO_DATE('2024-01-15 10:00:00','YYYY-MM-DD HH24:MI:SS')";
```

Post-PITR:

```sql
ALTER DATABASE OPEN RESETLOGS;
```

## Verifica e report

```rman
LIST BACKUP SUMMARY;
LIST BACKUP OF ARCHIVELOG ALL;
REPORT NEED BACKUP;
REPORT OBSOLETE;
SHOW ALL;
```

## Crosscheck e cleanup

```rman
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
DELETE EXPIRED BACKUP;
DELETE OBSOLETE;
DELETE NOPROMPT OBSOLETE;
```

## Configurazione base consigliata

```rman
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO COMPRESSED BACKUPSET;
```
