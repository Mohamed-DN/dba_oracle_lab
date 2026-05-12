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

Checklist OS/ambiente:

- `ORACLE_HOME` e `ORACLE_SID` corretti.
- Listener raggiungibile e TNS risolto.
- Password file presente per connessioni remote (`REMOTE_LOGIN_PASSWORDFILE`).
- Ora di sistema sincronizzata (NTP) per coerenza timeline backup.

Comandi utili:

```bash
echo $ORACLE_HOME
echo $ORACLE_SID
tnsping PROD
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
- **Controlfile vs Catalog**:
  - Solo controlfile = metadati limitati nel tempo (`CONTROL_FILE_RECORD_KEEP_TIME`).
  - Catalog = storico lungo, reporting avanzato e compliance.
- **Backup piece**: file fisico generato da RMAN, contenuto nel backupset.
- **Archivelog deletion policy**: evita cancellazioni premature in Data Guard.
- **FRA vs non-FRA**: in FRA RMAN gestisce spazio e reclaim, fuori FRA serve gestione manuale.

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

### 4.1) Canali e device type (DISK/TAPE)

```rman
ALLOCATE CHANNEL c1 DEVICE TYPE DISK FORMAT '/backup/%d/%T/%U' MAXPIECESIZE 10G;
ALLOCATE CHANNEL c2 DEVICE TYPE DISK FORMAT '/backup/%d/%T/%U' FILESPERSET 4;
BACKUP SECTION SIZE 2G DATABASE;
```

Note operative:

- `SECTION SIZE` abilita backup parallelo per datafile grandi.
- Per tape/SBT: `DEVICE TYPE SBT_TAPE` + libreria MML.
- Usa `MAXPIECESIZE` per limitare dimensione backup piece.

### 4.2) Block Change Tracking (BCT)

```sql
SELECT status, filename FROM v$block_change_tracking;
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+RECO/DB/bct_db.f';
```

Accelera gli incremental level 1 e riduce I/O.

### 4.3) Controlfile autobackup e snapshot controlfile

```rman
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '+RECO/%d/snapcf_%d.f';
```

Essenziale per recovery in assenza di catalog o controlfile aggiornato.

### 5) Strategie di backup e retention

- **Full settimanale + incremental giornaliero** con archivelog continuo.
- **Incremental merge** su image copy per restore rapido.
- **Backup archivelog** frequente per ridurre RPO.
- **Retention policy** allineata a SLA (es. 14-30 giorni) + `DELETE OBSOLETE`.
- **Crosscheck** periodico per allineare metadati a storage reale.

Esempio incremental merge:

```rman
BACKUP AS COPY DATABASE TAG 'INCR_MERGE_BASE';
BACKUP INCREMENTAL LEVEL 1 FOR RECOVER OF COPY WITH TAG 'INCR_MERGE_BASE' DATABASE;
RECOVER COPY OF DATABASE WITH TAG 'INCR_MERGE_BASE';
```

### 6) Comandi RMAN essenziali (con uso tipico)

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

### 7) Runbook operativi (scenari principali)

#### 7.1 Full + archivelog

```rman
RUN {
  SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";
  BACKUP AS COMPRESSED BACKUPSET DATABASE TAG 'FULL_DB';
  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL NOT BACKED UP 1 TIMES DELETE INPUT TAG 'ARCH_ALL';
  BACKUP CURRENT CONTROLFILE TAG 'CTRL_DAILY';
  BACKUP SPFILE TAG 'SPFILE_DAILY';
}
```

#### 7.2 Incremental Level 0 / Level 1

```rman
BACKUP INCREMENTAL LEVEL 0 DATABASE TAG 'WEEKLY_L0';
BACKUP INCREMENTAL LEVEL 1 DATABASE TAG 'DAILY_L1';
```

#### 7.3 Backup tablespace / datafile mirato

```rman
BACKUP TABLESPACE users, indx TAG 'TS_USERS';
BACKUP DATAFILE 7 TAG 'DF7';
```

#### 7.4 Restore e recovery database

```rman
RESTORE DATABASE;
RECOVER DATABASE;
```

#### 7.5 Point-in-Time Recovery (PITR)

```rman
RUN {
  SET UNTIL TIME "TO_DATE('2026-05-10 10:30:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE DATABASE;
  RECOVER DATABASE;
}
```

#### 7.6 Restore singolo datafile

```rman
RESTORE DATAFILE 7;
RECOVER DATAFILE 7;
```

#### 7.7 Duplicate per clone/test

```rman
DUPLICATE TARGET DATABASE TO CLONE
  NOFILENAMECHECK
  SET DB_UNIQUE_NAME='CLONE'
  SET CONTROL_FILES='+DATA/CLONE/control01.ctl';
```

#### 7.8 Catalog e metadata recovery

```rman
CREATE CATALOG;
REGISTER DATABASE;
RESYNC CATALOG;
CATALOG START WITH '/backup/rman/';
```

#### 7.9 Restore controlfile e SPFILE

```rman
STARTUP NOMOUNT;
RESTORE SPFILE FROM AUTOBACKUP;
SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT;
RESTORE CONTROLFILE FROM AUTOBACKUP;
ALTER DATABASE MOUNT;
RESTORE DATABASE;
RECOVER DATABASE;
```

#### 7.10 Block Media Recovery (BMR)

```rman
BLOCKRECOVER DATAFILE 7 BLOCK 12345, 12346;
```

Utile per corruzioni limitate senza restore completo.

#### 7.11 Recover tablespace (TSPITR semplificato)

```rman
RUN {
  SET UNTIL TIME "TO_DATE('2026-05-10 10:30:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE TABLESPACE users;
  RECOVER TABLESPACE users;
}
```

Per TSPITR complessi è necessario un **auxiliary** dedicato.

#### 7.12 Restore validate (prova recovery)

```rman
RESTORE DATABASE VALIDATE;
VALIDATE DATABASE;
```

#### 7.13 Duplicate per standby (Active Duplicate)

```rman
DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE
  DORECOVER
  NOFILENAMECHECK;
```

### 8) Monitoraggio e verifica continua

Query utili:

```sql
SELECT status, start_time, end_time, operation, object_type
FROM v$rman_status
ORDER BY start_time DESC;

SELECT file_type, percent_space_used, percent_space_reclaimable
FROM v$recovery_area_usage;

SELECT * FROM v$backup;
SELECT * FROM v$backup_piece;
SELECT * FROM v$backup_set_details;
SELECT * FROM v$rman_backup_job_details;
SELECT * FROM v$backup_async_io;
SELECT * FROM v$archived_log WHERE applied = 'NO';
```

RMAN:

```rman
LIST BACKUP SUMMARY;
LIST ARCHIVELOG ALL;
REPORT NEED BACKUP;
REPORT OBSOLETE;
SHOW ALL;
LIST BACKUP BY FILE;
LIST FAILURE;
```

### 9) Best practice enterprise

- **Tagga** tutti i backup (`TAG 'WEEKLY_L0'`) per audit.
- **Compressione** media per bilanciare CPU/IO.
- **Backup optimization** attivo per evitare duplicati inutili.
- **Autobackup controlfile** sempre ON.
- **BCT** (Block Change Tracking) attivo per incrementali veloci.
- **Retention policy** allineata a RPO/RTO.
- **Test di restore** schedulati (non solo backup).
- **Log centralizzati** con retention e alert su failure.
- **Cifratura** (`CONFIGURE ENCRYPTION`) se richiesto da policy.
- **Backup del catalogo** (se usato) e password file in copia sicura.
- **Separazione storage** (backup su target distinto dall’origin).
- **Documentazione runbook** aggiornata dopo ogni modifica.

#### Sicurezza e compliance

- `CONFIGURE ENCRYPTION FOR DATABASE ON;` con wallet gestito.
- `CONFIGURE COMPRESSION` compatibile con politiche di cifratura.
- Accessi RMAN separati (role `SYSBACKUP`).

#### Manutenzione periodica

- `CROSSCHECK BACKUP` + `DELETE EXPIRED` a frequenza fissa.
- `REPORT OBSOLETE` + `DELETE OBSOLETE` in finestra di manutenzione.
- Verifica `CONTROL_FILE_RECORD_KEEP_TIME` se usi solo controlfile.

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
| `RMAN-08120` | Backup piece corrotto | Rigenera backup, `VALIDATE` |
| `RMAN-06169` | Accesso catalog fallito | Verifica connessione e `RESYNC` |
| `ORA-19815` | FRA piena / uso eccessivo | Estendi FRA o `DELETE OBSOLETE` |

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
- Oracle Database Backup and Recovery User's Guide (HTML):  
  <https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/index.html>
