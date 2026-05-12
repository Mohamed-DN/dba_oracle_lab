# Guida RMAN Enterprise — Comandi, Procedure e Troubleshooting

> Guida completa e operativa ai comandi RMAN con focus enterprise: backup, restore, recovery, catalog, validazione e troubleshooting.

---

## Obiettivo

- Fornire un riferimento unico ai comandi RMAN realmente usati in produzione.
- Spiegare quando e perché usare ogni comando (non solo la sintassi).
- Coprire scenari completi: full/incremental, archivelog, restore mirato, PITR, duplicate, catalog.
- Offrire checklist di validazione e troubleshooting rapido per incidenti.

---

## Procedura operativa

### 1) Prerequisiti minimi

Prima di eseguire RMAN:

- Database in **ARCHIVELOG**.
- FRA (Fast Recovery Area) dimensionata.
- Privilegi: `SYSDBA` o `SYSBACKUP`.
- Se usi catalog: **Recovery Catalog** online e sincronizzato.

Comandi SQL di verifica:

```sql
SELECT name, log_mode, database_role, open_mode FROM v$database;
SHOW PARAMETER db_recovery_file_dest;
SHOW PARAMETER db_recovery_file_dest_size;
SELECT * FROM v$recovery_area_usage;
```

### 2) Concetti chiave da ricordare

- **Target**: il database di cui fai il backup.
- **Auxiliary**: database clone/duplicate.
- **Catalog**: repository centrale per metadati backup.
- **Backupset** vs **Image Copy**:
  - Backupset = file compressi/logici.
  - Image copy = copia byte-per-byte dei datafile.
- **Incremental**:
  - **Level 0** = baseline.
  - **Level 1** = delta (cumulative o differential).
- **Retention policy**: recovery window o redundancy.

### 3) Connessioni e sessione RMAN

```rman
RMAN TARGET /
RMAN TARGET sys@PROD CATALOG rman@CATALOG
RMAN TARGET sys@PROD AUXILIARY sys@CLONE CATALOG rman@CATALOG
```

Comandi di controllo sessione:

```rman
SHOW ALL;
REPORT SCHEMA;
REPORT NEED BACKUP;
```

### 4) Configurazione baseline consigliata (enterprise)

```rman
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO COMPRESSED BACKUPSET;
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '+RECO/%d/%T/%U';
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '+RECO/%F';
```

Data Guard (primary):

```rman
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```

RAC:

```rman
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '+RECO/RACDB/snapcf_racdb.f';
```

### 5) Comandi RMAN essenziali (con uso tipico)

| Comando | Quando lo usi | Note operative |
| --- | --- | --- |
| `BACKUP` | Backup database/archivelog/controlfile | Usa tag e compression per tracciabilità |
| `RESTORE` | Ripristino file | Spesso seguito da `RECOVER` |
| `RECOVER` | Media recovery | Supporta PITR e recovery database |
| `VALIDATE` | Test di backup | Non scrive, verifica integrità |
| `LIST` | Elenca backup | `LIST BACKUP`, `LIST ARCHIVELOG` |
| `REPORT` | Gap/needs/obsolete | `REPORT NEED BACKUP` |
| `CROSSCHECK` | Reconcile metadati | Essenziale prima di delete |
| `DELETE` | Pulizia backup/archivelog | Usa `DELETE OBSOLETE` |
| `DUPLICATE` | Clone database | Per test, DR, refresh |
| `CATALOG` | Importa backup esterni | `CATALOG START WITH` |
| `RESYNC CATALOG` | Sync catalog | Dopo backup o failover |
| `SQL` | Esegue SQL in RMAN | `SQL "ALTER SYSTEM..."` |
| `RUN` | Blocco atomico | Raggruppa comandi |

### 6) Runbook operativi (scenari principali)

#### 6.1 Full + archivelog

```rman
RUN {
  SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";
  BACKUP AS COMPRESSED BACKUPSET DATABASE TAG 'FULL_DB';
  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL NOT BACKED UP 1 TIMES DELETE INPUT TAG 'ARCH_ALL';
  BACKUP CURRENT CONTROLFILE TAG 'CTRL_DAILY';
  BACKUP SPFILE TAG 'SPFILE_DAILY';
}
```

#### 6.2 Incremental Level 0 / Level 1

```rman
BACKUP INCREMENTAL LEVEL 0 DATABASE TAG 'WEEKLY_L0';
BACKUP INCREMENTAL LEVEL 1 DATABASE TAG 'DAILY_L1';
```

#### 6.3 Backup tablespace / datafile mirato

```rman
BACKUP TABLESPACE users, indx TAG 'TS_USERS';
BACKUP DATAFILE 7 TAG 'DF7';
```

#### 6.4 Restore e recovery database

```rman
RESTORE DATABASE;
RECOVER DATABASE;
```

#### 6.5 Point-in-Time Recovery (PITR)

```rman
RUN {
  SET UNTIL TIME "TO_DATE('2026-05-10 10:30:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE DATABASE;
  RECOVER DATABASE;
}
```

#### 6.6 Restore singolo datafile

```rman
RESTORE DATAFILE 7;
RECOVER DATAFILE 7;
```

#### 6.7 Duplicate per clone/test

```rman
DUPLICATE TARGET DATABASE TO CLONE
  NOFILENAMECHECK
  SET DB_UNIQUE_NAME='CLONE'
  SET CONTROL_FILES='+DATA/CLONE/control01.ctl';
```

#### 6.8 Catalog e metadata recovery

```rman
CREATE CATALOG;
REGISTER DATABASE;
RESYNC CATALOG;
CATALOG START WITH '/backup/rman/';
```

### 7) Monitoraggio e verifica continua

Query utili:

```sql
SELECT status, start_time, end_time, operation, object_type
FROM v$rman_status
ORDER BY start_time DESC;

SELECT file_type, percent_space_used, percent_space_reclaimable
FROM v$recovery_area_usage;

SELECT * FROM v$backup;
SELECT * FROM v$backup_piece;
SELECT * FROM v$archived_log WHERE applied = 'NO';
```

RMAN:

```rman
LIST BACKUP SUMMARY;
LIST ARCHIVELOG ALL;
REPORT NEED BACKUP;
REPORT OBSOLETE;
```

### 8) Best practice enterprise

- **Tagga** tutti i backup (`TAG 'WEEKLY_L0'`) per audit.
- **Compressione** media per bilanciare CPU/IO.
- **Backup optimization** attivo per evitare duplicati inutili.
- **Autobackup controlfile** sempre ON.
- **BCT** (Block Change Tracking) attivo per incrementali veloci.
- **Retention policy** allineata a RPO/RTO.
- **Test di restore** schedulati (non solo backup).
- **Log centralizzati** con retention e alert su failure.
- **Cifratura** (`CONFIGURE ENCRYPTION`) se richiesto da policy.

---

## Validazione finale

Checklist da eseguire dopo ogni variazione di policy/backup:

1. `SHOW ALL;` per verificare la configurazione.
2. `LIST BACKUP SUMMARY;` per controllare i backup recenti.
3. `REPORT NEED BACKUP;` per gap di copertura.
4. `VALIDATE DATABASE;` per integrità.
5. `RESTORE DATABASE VALIDATE;` per prova restore.
6. `SELECT * FROM v$rman_status;` per errori.

---

## Troubleshooting rapido

| Errore | Causa tipica | Azione rapida |
| --- | --- | --- |
| `ORA-19809` / `ORA-19804` | FRA piena | Aumenta FRA o `DELETE OBSOLETE`/`DELETE ARCHIVELOG` |
| `RMAN-06054` | Archivelog mancante | Ripristina archivelog o usa `SET UNTIL` |
| `RMAN-03009` | Backup fallito | Controlla storage, permessi, canali |
| `ORA-19502` | Write error su device | Verifica filesystem/ASM |
| `RMAN-06059` | File datafile mancante | `RESTORE DATAFILE` e `RECOVER` |
| `ORA-27072` | Permessi OS/ASM | Verifica owner e path |

Azioni rapide:

- `CROSSCHECK BACKUP;` + `CROSSCHECK ARCHIVELOG ALL;`
- `REPORT OBSOLETE;` + `DELETE OBSOLETE;`
- Verifica canali e format path.
- Verifica spazio su FRA e filesystem ASM.

---

## Riferimenti ufficiali e fonti consigliate

- Oracle Database Backup and Recovery User's Guide (PDF):  
  <https://docs.oracle.com/cd/F19136_01/bradv/oracle-ai-database-backup-and-recovery-users-guide.pdf>
- Oracle RMAN Reference (command syntax):  
  <https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/index.html>
- Oracle Database Backup and Recovery Concepts:  
  <https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/index.html>
