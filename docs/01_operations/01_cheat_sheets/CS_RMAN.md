# Cheat Sheet RMAN 19c — Riferimento Operativo Enterprise

## Obiettivi

Usare un solo riferimento operativo per scegliere il comando RMAN corretto,
capire quando applicarlo e riconoscere le operazioni che richiedono un change
autorizzato. Gli esempi predefiniti non cancellano archivelog durante il backup.

## Procedura Operativa

1. Parti dall'indice per scenario e raccogli evidenze prima di modificare file.
2. Verifica ruolo database, FRA, catalogo e stato Data Guard.
3. Esegui backup, restore o recovery sul target corretto.
4. Se devi liberare spazio, usa la procedura di cleanup separata e registra le
   sequenze eliminate.

## Validazione Finale

Conserva log RMAN, `LIST BACKUP SUMMARY`, `REPORT OBSOLETE`, risultato del
restore drill pertinente e, in Data Guard, transport lag, apply lag e
`V$ARCHIVE_GAP` consultata sullo standby.

## Troubleshooting Rapido

- `ORA-00257` o FRA piena: non cancellare per età; verifica spazio reale,
  deletion policy e sequenze shipped/applied.
- Backup non trovato: esegui `CROSSCHECK`, poi `CATALOG START WITH` se i piece
  esistono ma non sono registrati.
- Corruzione: usa `VALIDATE CHECK LOGICAL DATABASE`, consulta
  `V$DATABASE_BLOCK_CORRUPTION` e valuta `RECOVER ... BLOCK`.

## Indice Per Scenario

| Scenario | Apri |
|---|---|
| Configurare retention, autobackup e policy DG | [Configurazione](#2-configurazione-rman-show--configure) |
| Backup full, incrementali, archivelog, tape o NFS | [Backup](#3-backup--scenari-operativi) |
| Restore completo, PITR, tablespace o datafile | [Restore e recovery](#4-restore-e-recovery--scenari-operativi) |
| Manutenzione metadata e cleanup autorizzato | [Validate, crosscheck e cleanup](#5-validate-crosscheck-report-e-cleanup-autorizzato) |
| Clone o standby | [Duplicate](#6-rman-duplicate-clonazione--standby) |
| Recuperare una tabella cancellata | [Recover table](#7a-recover-table-errore-umano-drop-o-delete) |
| Riallineare uno standby senza rebuild | [Recover standby from service](#7b-recover-standby-database-from-service-19c--riallineamento-standby) |
| Corruzione di pochi blocchi | [Block media recovery](#103-block-media-recovery-bmr--ripristino-singoli-blocchi) |
| Trovare un comando raro | [Matrice completa](#17-matrice-completa-dei-comandi-rman-19c) |
| Capire sintassi storiche | [Appendice legacy](#18-appendice-legacy-e-comandi-rischiosi) |

> [!NOTE]
> **DOCUMENTI RMAN CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Guida di Laboratorio (Fase 5)**: [GUIDA_FASE5_RMAN_BACKUP.md](../../02_core_dba/02_backup_and_recovery/GUIDA_FASE5_RMAN_BACKUP.md) (impostazione della strategia di backup e cron).
> - **Manuale Comandi Core**: [GUIDA_RMAN_COMANDI_ENTERPRISE.md](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMANDI_ENTERPRISE.md) (riferimento completo dei parametri RMAN).
> - **Guida Architetturale Core**: [GUIDA_RMAN_COMPLETA_19C.md](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md) (fondamenti teorici e scenari avanzati).
> - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](./CS_MASTER_DBA.md) (tutti i comandi consolidati).

---

## 1. Connessione RMAN

Gli alias remoti `/@ALIAS` presuppongono un wallet SEPS. Per una sessione locale
usa OS authentication con `/`; non inserire password nella command line.

```rman
-- Connessione locale (OS Auth)
rman target /

-- Connessione remota tramite wallet SEPS (non-CDB / CDB Root)
rman target /@RACDB

-- Connessione con catalog
rman target / catalog /@catdb

-- Connessione target + auxiliary (per duplicate)
rman target /@RACDB auxiliary /@RACDB_STBY

-- Connessione a CDB root
rman target /@CDB1

-- Connessione diagnostica (solo lettura, senza recovery catalog)
rman checksyntax
```

---

## 2. Configurazione RMAN (SHOW / CONFIGURE)

### 2.1 Visualizzare la configurazione corrente
```rman
SHOW ALL;
SHOW RETENTION POLICY;
SHOW DEFAULT DEVICE TYPE;
SHOW CONTROLFILE AUTOBACKUP;
SHOW ENCRYPTION FOR DATABASE;
```

### 2.2 Configurazione Enterprise consigliata
```rman
-- Retention: Recovery Window di 7 giorni (per produzione usare 14-30)
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;

-- Autobackup del controlfile (FONDAMENTALE per bare-metal recovery)
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/backup/rman/%F';

-- Ottimizzazione: non ri-backuppare file già backuppati
CONFIGURE BACKUP OPTIMIZATION ON;

-- Parallelismo e compressione
CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO COMPRESSED BACKUPSET;
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
-- LOW, MEDIUM e HIGH richiedono gate licenza Advanced Compression.

-- Per ambienti con tape library (SBT)
-- CONFIGURE DEVICE TYPE sbt PARALLELISM 2;
-- CONFIGURE DEFAULT DEVICE TYPE TO sbt;

-- Snapshot controlfile (per hot backup consistente)
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '/backup/rman/snapcf_racdb.f';

-- Archivelog deletion policy per Data Guard
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```

La FRA si dimensiona da SQL*Plus, non con `CONFIGURE`:

```sql
ALTER SYSTEM SET db_recovery_file_dest_size=100G SCOPE=BOTH;
```

### 2.3 Reset configurazione al default
```rman
CONFIGURE RETENTION POLICY CLEAR;
CONFIGURE CONTROLFILE AUTOBACKUP CLEAR;
CONFIGURE BACKUP OPTIMIZATION CLEAR;
CONFIGURE DEVICE TYPE DISK CLEAR;
```

---

## 3. Backup — Scenari Operativi

### 3.1 Backup Completo (Full / Level 0)
```rman
-- Backup full database (NON incrementale)
BACKUP DATABASE;

-- Backup full + archivelog (standard quotidiano)
BACKUP DATABASE PLUS ARCHIVELOG;

-- Backup full + archivelog senza cancellazione incorporata
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG;

-- Backup full con tag identificativo
BACKUP DATABASE TAG 'FULL_WEEKLY_20260529' PLUS ARCHIVELOG;
```

### 3.2 Backup Incrementale (Level 0 / Level 1)
```rman
-- Level 0 (base per gli incrementali successivi)
BACKUP INCREMENTAL LEVEL 0 DATABASE;

-- Level 1 differenziale (solo blocchi cambiati dall'ultimo L0 o L1)
BACKUP INCREMENTAL LEVEL 1 DATABASE;

-- Level 1 cumulativo (tutti i blocchi cambiati dall'ultimo L0)
BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE;

-- Strategia incrementale completa
-- Domenica: BACKUP INCREMENTAL LEVEL 0 DATABASE TAG 'L0_WEEKLY';
-- Lun-Sab:  BACKUP INCREMENTAL LEVEL 1 DATABASE TAG 'L1_DAILY';
```

### 3.3 Block Change Tracking (BCT) — Velocizzare gli incrementali
```sql
-- Abilitare BCT (da SQL*Plus, una sola volta)
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+DATA/RACDB/bct_racdb.ctf';

-- ASM: il file BCT va in un diskgroup
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+DATA/RACDB/bct.chg';

-- Verificare stato BCT
SELECT filename, status, bytes/1024/1024 AS mb FROM V$BLOCK_CHANGE_TRACKING;

-- Disabilitare
ALTER DATABASE DISABLE BLOCK CHANGE TRACKING;
```

### 3.4 Backup di Componenti Specifici
```rman
-- Solo tablespace
BACKUP TABLESPACE users, tools;

-- Solo datafile
BACKUP DATAFILE 5, 7;
BACKUP DATAFILE '/u01/oradata/RACDB/users01.dbf';

-- Solo archivelog (ultimi 2 giorni)
BACKUP ARCHIVELOG FROM TIME 'SYSDATE-2';
BACKUP ARCHIVELOG ALL NOT BACKED UP 1 TIMES;

-- Solo controlfile
BACKUP CURRENT CONTROLFILE;

-- Solo SPFILE
BACKUP SPFILE;

-- Controlfile + SPFILE esplicito
BACKUP CURRENT CONTROLFILE FORMAT '/backup/rman/cf_%U.bkp';
BACKUP SPFILE FORMAT '/backup/rman/spfile_%U.bkp';
```

### 3.5 Backup con Encryption (TDE / Password)
```rman
-- Se TDE è già attivo sul database (Transparent mode - automatico)
BACKUP DATABASE;  -- i backup saranno già criptati

-- Encryption con password RMAN (se TDE NON è attivo)
SET ENCRYPTION ON IDENTIFIED BY '<BACKUP_ENCRYPTION_PASSWORD>' ONLY;
BACKUP DATABASE;

-- Encryption duale (TDE + password, per trasferimento offsite)
SET ENCRYPTION ON IDENTIFIED BY '<BACKUP_ENCRYPTION_PASSWORD>';
BACKUP DATABASE FORMAT '/backup/offsite/%U.bkp';

-- Verificare stato encryption
SELECT * FROM V$RMAN_ENCRYPTION_ALGORITHMS;
```

### 3.6 Backup su Tape (SBT) e NFS
```rman
-- Backup diretto su tape (richiede media management)
BACKUP DEVICE TYPE sbt DATABASE PLUS ARCHIVELOG;

-- Backup con formato personalizzato e path NFS
BACKUP DATABASE FORMAT '/nfs_backup/rman/%d_%T_%U.bkp'
  PLUS ARCHIVELOG FORMAT '/nfs_backup/rman/arch_%d_%T_%U.bkp';
```

### 3.7 Backup Multisection (per file molto grandi, >50GB)
```rman
-- Backup multisection: divide i datafile grandi in "sezioni" parallele
BACKUP SECTION SIZE 10G DATABASE;
BACKUP SECTION SIZE 5G TABLESPACE bigdata;
```

### 3.8 Formati di naming (%d, %T, %U, %F)
```text
%d  = DB_NAME
%T  = Data (YYYYMMDD)
%t  = Timestamp (epoch)
%U  = Unique name generato da RMAN
%s  = Backup set number
%p  = Backup piece number
%F  = Format unico per autobackup controlfile: c-DBID-YYYYMMDD-QQ
```

---

## 4. Restore e Recovery — Scenari Operativi

### 4.1 Complete Recovery (nessuna perdita dati)
```rman
-- Database completo da backup
STARTUP MOUNT;
RESTORE DATABASE;
RECOVER DATABASE;
ALTER DATABASE OPEN;
```

### 4.2 Point-in-Time Recovery (PITR)
```rman
STARTUP MOUNT;
-- Per data e ora
RESTORE DATABASE UNTIL TIME "TO_DATE('2026-05-29 08:00:00','YYYY-MM-DD HH24:MI:SS')";
RECOVER DATABASE UNTIL TIME "TO_DATE('2026-05-29 08:00:00','YYYY-MM-DD HH24:MI:SS')";
ALTER DATABASE OPEN RESETLOGS;

-- Per SCN
RESTORE DATABASE UNTIL SCN 123456789;
RECOVER DATABASE UNTIL SCN 123456789;
ALTER DATABASE OPEN RESETLOGS;

-- Per Log Sequence
RESTORE DATABASE UNTIL SEQUENCE 1500 THREAD 1;
RECOVER DATABASE UNTIL SEQUENCE 1500 THREAD 1;
ALTER DATABASE OPEN RESETLOGS;
```

### 4.3 Restore Tablespace
```rman
-- Offline il tablespace, restore, recover, online
ALTER TABLESPACE users OFFLINE IMMEDIATE;
RESTORE TABLESPACE users;
RECOVER TABLESPACE users;
ALTER TABLESPACE users ONLINE;
```

### 4.4 Restore Datafile Singolo
```rman
-- Datafile singolo (database aperto se il file non è di SYSTEM/UNDO)
ALTER DATABASE DATAFILE 5 OFFLINE;
RESTORE DATAFILE 5;
RECOVER DATAFILE 5;
ALTER DATABASE DATAFILE 5 ONLINE;

-- Oppure per path
RESTORE DATAFILE '/u01/oradata/RACDB/users01.dbf';
RECOVER DATAFILE '/u01/oradata/RACDB/users01.dbf';
```

### 4.5 Restore Controlfile (Bare Metal Recovery)
```rman
-- Se hai perso i controlfile ma hai l'autobackup
STARTUP NOMOUNT;
-- Imposta DBID se serve
SET DBID 123456789;
RESTORE CONTROLFILE FROM AUTOBACKUP;
ALTER DATABASE MOUNT;
RESTORE DATABASE;
RECOVER DATABASE;
ALTER DATABASE OPEN RESETLOGS;
```

### 4.6 Restore SPFILE
```rman
-- Da autobackup del controlfile
STARTUP FORCE NOMOUNT;
SET DBID 123456789;
RESTORE SPFILE FROM AUTOBACKUP;
STARTUP FORCE;
```

### 4.7 Restore su Path Diversi (SET NEWNAME)
```rman
-- Quando i path di destinazione sono diversi da quelli originali
RUN {
  SET NEWNAME FOR DATAFILE 1 TO '/new_path/system01.dbf';
  SET NEWNAME FOR DATAFILE 2 TO '/new_path/sysaux01.dbf';
  SET NEWNAME FOR DATAFILE 3 TO '/new_path/undotbs01.dbf';
  SET NEWNAME FOR DATAFILE 4 TO '/new_path/users01.dbf';
  RESTORE DATABASE;
  SWITCH DATAFILE ALL;
  RECOVER DATABASE;
}
```

### 4.8 Restore in ambiente ASM
```rman
RUN {
  SET NEWNAME FOR DATABASE TO '+DATA';
  RESTORE DATABASE;
  SWITCH DATAFILE ALL;
  RECOVER DATABASE;
}
```

---

## 5. Validate, Crosscheck, Report e Cleanup Autorizzato

### 5.1 Validazione Backup (senza restore effettivo)
```rman
-- Valida che i backup siano leggibili e integri
VALIDATE BACKUPSET 123;
VALIDATE DATABASE;
VALIDATE TABLESPACE users;
VALIDATE DATAFILE 5;

-- Valida anche la corruzione logica
VALIDATE CHECK LOGICAL DATABASE;

-- Restore preview (mostra cosa serve senza fare nulla)
RESTORE DATABASE PREVIEW;
RESTORE DATABASE PREVIEW SUMMARY;
```

### 5.2 Crosscheck (sincronizza catalogo RMAN con media)
```rman
-- Crosscheck tutti i backup
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
CROSSCHECK COPY;

-- Crosscheck solo un device
CROSSCHECK BACKUP DEVICE TYPE DISK;
CROSSCHECK BACKUP DEVICE TYPE sbt;
```

### 5.3 Cleanup Backup Scaduti / Obsoleti
```rman
-- Elimina backup scaduti (non più sul media)
DELETE EXPIRED BACKUP;
DELETE EXPIRED ARCHIVELOG ALL;

-- Elimina backup obsoleti (oltre la retention policy)
DELETE OBSOLETE;
DELETE NOPROMPT OBSOLETE;

-- Elimina backup specifici
DELETE BACKUP TAG 'OLD_FULL_20260101';
DELETE BACKUPSET 456;

-- Elimina solo archivelog eleggibili secondo la deletion policy configurata.
-- Prima esegui il gate Data Guard descritto sotto.
SHOW ARCHIVELOG DELETION POLICY;
DELETE NOPROMPT ARCHIVELOG ALL;
```

Prima di `DELETE NOPROMPT ARCHIVELOG ALL`:

1. verifica spazio reale e FRA;
2. controlla transport lag e apply lag;
3. consulta `V$ARCHIVE_GAP` sullo standby;
4. registra sequenze shipped/applied;
5. ottieni l'autorizzazione prevista dal change.

Non usare `DELETE FORCE` salvo ultima scelta autorizzata con degrado DR
esplicitamente dichiarato.

### 5.4 Report
```rman
-- Backup che servono (file non backuppati di recente)
REPORT NEED BACKUP;
REPORT NEED BACKUP DAYS 3;
REPORT NEED BACKUP INCREMENTAL 2;

-- Backup obsoleti secondo la retention
REPORT OBSOLETE;

-- Schema del database (tutti i datafile)
REPORT SCHEMA;
REPORT SCHEMA AT SCN 123456;

-- File non recuperabili (perché non backuppati)
REPORT UNRECOVERABLE;
```

### 5.5 List
```rman
-- Lista tutti i backup
LIST BACKUP SUMMARY;
LIST BACKUP;
LIST BACKUP OF DATABASE;
LIST BACKUP OF TABLESPACE users;
LIST BACKUP OF ARCHIVELOG ALL;
LIST BACKUP OF CONTROLFILE;
LIST BACKUP OF SPFILE;

-- Lista copie (image copy)
LIST COPY;
LIST COPY OF DATABASE;

-- Lista backup completati nelle ultime 24h
LIST BACKUP COMPLETED AFTER 'SYSDATE-1';

-- Lista archivelog
LIST ARCHIVELOG ALL;
```

---

## 6. RMAN Duplicate (Clonazione / Standby)

### 6.1 Active Duplicate (via rete, senza backup)
```rman
-- Da eseguire dallo standby verso il primary
rman target /@RACDB auxiliary /@CLONEDB

DUPLICATE TARGET DATABASE TO CLONEDB
  FROM ACTIVE DATABASE
  SPFILE
    SET DB_UNIQUE_NAME='CLONEDB'
    SET DB_FILE_NAME_CONVERT='+DATA/RACDB/','+DATA/CLONEDB/'
    SET LOG_FILE_NAME_CONVERT='+DATA/RACDB/','+DATA/CLONEDB/','+RECO/RACDB/','+RECO/CLONEDB/'
    SET CONTROL_FILES='+DATA/CLONEDB/controlfile/control01.ctl'
    SET LOCAL_LISTENER='(ADDRESS=(PROTOCOL=TCP)(HOST=clone-host)(PORT=1521))'
  NOFILENAMECHECK;
```

### 6.2 Active Duplicate FOR STANDBY (Data Guard)
```rman
rman target /@RACDB auxiliary /@RACDB_STBY

DUPLICATE TARGET DATABASE FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
    SET DB_UNIQUE_NAME='RACDB_STBY'
    SET FAL_SERVER='RACDB'
    SET LOG_ARCHIVE_DEST_2='SERVICE=RACDB ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB'
  NOFILENAMECHECK;
```

### 6.3 Duplicate da Backup (Backup-Based)
```rman
rman auxiliary /@CLONE

DUPLICATE TARGET DATABASE TO CLONEDB
  BACKUP LOCATION '/backup/rman/'
  SPFILE
    SET DB_UNIQUE_NAME='CLONEDB'
  NOFILENAMECHECK;
```

---

## 7. Tablespace Point-in-Time Recovery (TSPITR)

```rman
-- Recover un tablespace a un punto nel tempo precedente (senza toccare il resto del DB)
-- RMAN crea automaticamente un'istanza ausiliaria
RECOVER TABLESPACE users
  UNTIL TIME "TO_DATE('2026-05-28 14:00:00','YYYY-MM-DD HH24:MI:SS')"
  AUXILIARY DESTINATION '/tmp/rman_aux';

-- Verifica post-TSPITR
ALTER TABLESPACE users ONLINE;
```

---

## 7A. Recover Table (Errore Umano: DROP o DELETE)

```rman
-- Esegui RMAN localmente sul target aperto read-write e in ARCHIVELOG mode.
RECOVER TABLE HR.ORDERS
  UNTIL TIME 'SYSDATE-1'
  AUXILIARY DESTINATION '/tmp/rman_table_aux'
  REMAP TABLE 'HR'.'ORDERS':'ORDERS_RECOVERED';

-- Variante PDB: collegati localmente alla root CDB.
RECOVER TABLE HR.ORDERS OF PLUGGABLE DATABASE RACDBPDB
  UNTIL SCN 123456789
  AUXILIARY DESTINATION '/tmp/rman_table_aux'
  DATAPUMP DESTINATION '/tmp/rman_table_dump'
  DUMP FILE 'orders_recovered.dmp'
  NOTABLEIMPORT;
```

RMAN crea un auxiliary database temporaneo, recupera l'oggetto al PITR richiesto
e usa Data Pump. Verifica backup e archivelog continui, spazio auxiliary e limiti
Oracle prima del comando. Approfondimento:
[Fase 5 RMAN](../../02_core_dba/02_backup_and_recovery/GUIDA_FASE5_RMAN_BACKUP.md).

---

## 7B. Recover Standby Database FROM SERVICE (19c — Riallineamento Standby)

Quando uno standby Data Guard ha un gap irrecuperabile (archivelog persi, FRA
piena, standby rimasto spento a lungo), il metodo moderno Oracle 19c per
riallinearlo **senza rebuild completo** è `RECOVER STANDBY DATABASE FROM SERVICE`.

RMAN contatta il primary via rete, identifica la divergenza SCN ed esegue un
backup incrementale automatico, applicandolo direttamente allo standby.

### Prerequisiti
```text
1. Connettività TNS dallo standby verso il primary (net service name funzionante)
2. Password file identico su primary e standby
3. COMPATIBLE >= 12.0 su entrambi i database
4. MRP (Managed Recovery Process) FERMO sullo standby
5. Standby in stato MOUNT (in RAC: una sola istanza attiva)
```

### Procedura operativa
```sql
-- Step 1: Fermare MRP sullo standby
-- Se usi Broker:
-- DGMGRL> EDIT DATABASE 'STANDBY_DB' SET STATE = 'APPLY-OFF';
-- Se non usi Broker:
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
```

```rman
-- Step 2: Connetti RMAN allo standby
rman target /

-- Step 3: Esegui il recovery dalla rete (il primary service è l'alias TNS)
RECOVER STANDBY DATABASE FROM SERVICE RACDB;

-- RMAN automaticamente:
--   a) Ripristina il controlfile dal primary
--   b) Monta il database
--   c) Identifica il gap SCN
--   d) Esegue un backup incrementale via rete
--   e) Applica l'incrementale allo standby
--   f) Rinomina datafile/tempfile se necessario
```

```sql
-- Step 4: Riattivare MRP dopo il completamento
-- Se usi Broker:
-- DGMGRL> EDIT DATABASE 'STANDBY_DB' SET STATE = 'APPLY-ON';
-- Se non usi Broker:
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

### Post-recovery checks
```sql
-- Verificare che il lag torni a zero
SELECT name, value, datum_time FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag');

-- Sullo STANDBY: verificare che non ci siano gap residui
SELECT * FROM v$archive_gap;

-- Verificare che MRP sia attivo
SELECT process, status, thread#, sequence# FROM v$managed_standby WHERE process='MRP0';
```

### Fallback: Incremental FROM SCN (se FROM SERVICE non è possibile)
```rman
-- Sul PRIMARY: genera un backup incrementale dalla SCN dello standby
-- (ottieni la SCN dallo standby con: SELECT CURRENT_SCN FROM V$DATABASE)
BACKUP INCREMENTAL FROM SCN <standby_scn> DATABASE
  FORMAT '/backup/standby_resync_%U.bkp';

-- Trasferisci i file sullo standby, poi:
-- Sullo STANDBY:
CATALOG START WITH '/backup/standby_resync_';
RECOVER DATABASE NOREDO;
```

> **Ref**: Oracle 19c RMAN Reference — RECOVER command, FROM SERVICE clause.
> https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/

---

## 8. Flashback Database (Complemento RMAN)

```sql
-- Prerequisiti (da SQL*Plus)
ALTER DATABASE FLASHBACK ON;

-- Flashback a un punto nel tempo (alternativa al PITR)
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
FLASHBACK DATABASE TO TIMESTAMP TO_TIMESTAMP('2026-05-28 14:00:00','YYYY-MM-DD HH24:MI:SS');
ALTER DATABASE OPEN RESETLOGS;

-- Flashback a un restore point garantito
CREATE RESTORE POINT before_upgrade GUARANTEE FLASHBACK DATABASE;
-- ... dopo il disastro ...
FLASHBACK DATABASE TO RESTORE POINT before_upgrade;
ALTER DATABASE OPEN RESETLOGS;

-- Verifica Flashback
SELECT oldest_flashback_scn, oldest_flashback_time, flashback_on FROM V$DATABASE;
SELECT * FROM V$RESTORE_POINT;
```

---

## 9. Image Copy e Switch (Strategia Alternativa)

```rman
-- Creare una image copy (copia 1:1 dei datafile, più veloce in restore)
BACKUP AS COPY DATABASE;

-- Switch: il DB usa direttamente le copie (restore istantaneo!)
SWITCH DATABASE TO COPY;
RECOVER DATABASE;
ALTER DATABASE OPEN;

-- Strategia "Incrementally Updated Backup" (IUB)
-- Giorno 0: Image copy
BACKUP AS COPY DATABASE TAG 'IUB_COPY';
-- Giorni 1-6: Applica incrementali sulla copia
BACKUP INCREMENTAL LEVEL 1 FOR RECOVER OF COPY WITH TAG 'IUB_COPY' DATABASE;
RECOVER COPY OF DATABASE WITH TAG 'IUB_COPY';
-- In caso di disastro: SWITCH DATABASE TO COPY; -> recover -> open
```

---

## 10. Diagnostica Corruzione (RMAN + DBMS_REPAIR)

### 10.1 Verifica Corruzione con RMAN
```rman
-- Check corruzione fisica
BACKUP VALIDATE DATABASE;

-- Check corruzione fisica + logica
BACKUP VALIDATE CHECK LOGICAL DATABASE;

-- Verifica un singolo datafile
VALIDATE DATAFILE 5;

-- Verifica un singolo backupset
VALIDATE BACKUPSET 123;
```

### 10.2 Verificare blocchi corrotti
```sql
-- Dopo VALIDATE, i blocchi corrotti finiscono qui
SELECT * FROM V$DATABASE_BLOCK_CORRUPTION;

-- Dettaglio
SELECT file#, block#, blocks, corruption_change#, corruption_type
FROM V$DATABASE_BLOCK_CORRUPTION
ORDER BY file#, block#;
```

### 10.3 Block Media Recovery (BMR) — Ripristino Singoli Blocchi
```rman
-- Ripristino chirurgico di blocchi corrotti (DB rimane APERTO!)
RECOVER DATAFILE 5 BLOCK 1234;
RECOVER DATAFILE 5 BLOCK 1234, 1235, 1236;

-- Recupera TUTTI i blocchi marcati corrotti
RECOVER CORRUPTION LIST;
```

---

## 11. RMAN in Ambienti Multitenant (CDB/PDB)

```rman
-- Backup dell'intero CDB
BACKUP DATABASE;

-- Backup di una singola PDB
BACKUP PLUGGABLE DATABASE RACDBPDB;

-- Backup di tablespace in una PDB
BACKUP TABLESPACE RACDBPDB:users;

-- Restore/Recover di una PDB
ALTER PLUGGABLE DATABASE RACDBPDB CLOSE;
RESTORE PLUGGABLE DATABASE RACDBPDB;
RECOVER PLUGGABLE DATABASE RACDBPDB;
ALTER PLUGGABLE DATABASE RACDBPDB OPEN;

-- PITR di una singola PDB
ALTER PLUGGABLE DATABASE RACDBPDB CLOSE;
RESTORE PLUGGABLE DATABASE RACDBPDB UNTIL TIME "TO_DATE('2026-05-28 14:00:00','YYYY-MM-DD HH24:MI:SS')";
RECOVER PLUGGABLE DATABASE RACDBPDB UNTIL TIME "TO_DATE('2026-05-28 14:00:00','YYYY-MM-DD HH24:MI:SS')";
ALTER PLUGGABLE DATABASE RACDBPDB OPEN RESETLOGS;
```

---

## 12. Performance & Tuning RMAN

### 12.1 Parallelismo
```rman
-- Aumenta canali per backup più veloci (1 canale per CPU/disco)
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c2 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c3 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c4 DEVICE TYPE DISK;
  BACKUP DATABASE PLUS ARCHIVELOG;
}

-- Oppure (persistente)
CONFIGURE DEVICE TYPE DISK PARALLELISM 4;
```

### 12.2 Rate Limiting (per non saturare I/O in produzione)
```rman
-- Limita la velocità a 200 MB/sec totali
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK RATE 50M;
  ALLOCATE CHANNEL c2 DEVICE TYPE DISK RATE 50M;
  ALLOCATE CHANNEL c3 DEVICE TYPE DISK RATE 50M;
  ALLOCATE CHANNEL c4 DEVICE TYPE DISK RATE 50M;
  BACKUP DATABASE;
}
```

### 12.3 Monitoraggio Backup in Corso
```sql
-- Progresso backup RMAN in tempo reale (da SQL*Plus)
SELECT sid, serial#, opname, sofar, totalwork,
       ROUND(sofar/totalwork*100, 2) AS pct_complete,
       time_remaining AS secs_remaining
FROM V$SESSION_LONGOPS
WHERE opname LIKE 'RMAN%' AND totalwork > 0
ORDER BY start_time DESC;

-- Sessioni RMAN attive
SELECT s.sid, s.serial#, s.program, s.status,
       io.block_changes, io.physical_reads
FROM V$SESSION s
JOIN V$SESS_IO io ON s.sid = io.sid
WHERE s.program LIKE '%rman%';
```

### 12.4 MAXSETSIZE e FILESPERSET
```rman
-- Limita la dimensione del backupset (utile per NFS/tape)
BACKUP DATABASE MAXSETSIZE 10G;

-- Massimo file per backupset (aiuta il parallelismo)
BACKUP DATABASE FILESPERSET 4;
```

---

## 13. Catalog Management

```rman
-- Registrare un database nel catalog
REGISTER DATABASE;

-- Resincronizzare il catalog
RESYNC CATALOG;

-- Cancellare un database dal catalog
UNREGISTER DATABASE;

-- Reset incarnation dopo RESETLOGS
RESET DATABASE TO INCARNATION 3;
LIST INCARNATION;

-- Upgrade catalog dopo upgrade RMAN
UPGRADE CATALOG;
```

---

## 14. Comandi di Emergenza — Quick Reference

| Scenario | Comandi |
|---|---|
| **DB non si apre** | `STARTUP MOUNT; RESTORE DATABASE; RECOVER DATABASE; ALTER DATABASE OPEN;` |
| **PITR urgente** | `STARTUP MOUNT; RESTORE DB UNTIL TIME ...; RECOVER DB UNTIL TIME ...; ALTER DATABASE OPEN RESETLOGS;` |
| **Controlfile perso** | `STARTUP NOMOUNT; SET DBID xxx; RESTORE CONTROLFILE FROM AUTOBACKUP; ALTER DATABASE MOUNT; RESTORE DB; RECOVER DB; ALTER DATABASE OPEN RESETLOGS;` |
| **SPFILE perso** | `STARTUP FORCE NOMOUNT; SET DBID xxx; RESTORE SPFILE FROM AUTOBACKUP; STARTUP FORCE;` |
| **Blocco corrotto** | `RECOVER CORRUPTION LIST;` |
| **Verifica backup ok** | `RESTORE DATABASE PREVIEW SUMMARY;` |
| **Tablespace perso** | `ALTER TABLESPACE x OFFLINE IMMEDIATE; RESTORE TABLESPACE x; RECOVER TABLESPACE x; ALTER TABLESPACE x ONLINE;` |
| **Archivelogs mancanti** | `RESTORE ARCHIVELOG FROM SEQUENCE xxx;` |
| **Pulizia spazio disco** | `CROSSCHECK BACKUP; DELETE EXPIRED BACKUP; DELETE OBSOLETE;` |
| **Clonare un DB** | `DUPLICATE TARGET DATABASE TO CLONE FROM ACTIVE DATABASE ...;` |

---

## 15. Script Cron per Backup Schedulato

```bash
#!/bin/bash
# /scripts/rman_backup_daily.sh
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=RACDB1
export PATH=$ORACLE_HOME/bin:$PATH

LOG="/backup/rman/logs/rman_backup_$(date +%Y%m%d_%H%M).log"

${ORACLE_HOME}/bin/rman target / <<EOF > ${LOG} 2>&1
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c2 DEVICE TYPE DISK;
  BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE
    TAG 'DAILY_INC_L1'
    FORMAT '/backup/rman/%d_%T_%U.bkp';
  BACKUP ARCHIVELOG ALL
    NOT BACKED UP 1 TIMES
    FORMAT '/backup/rman/arch_%d_%T_%U.bkp';
}
EXIT;
EOF

# Check esito
if grep -q "RMAN-" ${LOG}; then
  echo "RMAN BACKUP FAILED - check ${LOG}" | mail -s "RMAN ALERT $(hostname)" dba@company.com
fi
```

Crontab:
```text
# Backup incrementale giornaliero alle 01:00
0 1 * * * /scripts/rman_backup_daily.sh > /dev/null 2>&1
# Backup full la domenica alle 23:00
0 23 * * 0 /scripts/rman_backup_full.sh > /dev/null 2>&1
```

---

## 16. Riferimenti Oracle Ufficiali

- Oracle 19c RMAN Reference: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/
- Oracle 19c Summary of RMAN Commands: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/about-rman-commands.html
- Oracle 19c CONFIGURE: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/CONFIGURE.html
- Oracle 19c BACKUP: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/BACKUP.html
- Oracle 19c DELETE: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/DELETE.html
- Oracle 19c Deprecated RMAN Syntax: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/deprecated-rman-syntax.html
- Oracle 19c Backup and Recovery User's Guide: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/
- MOS Doc ID 360416.1 — RMAN Backup and Recovery Best Practices
- MOS Doc ID 1526085.1 — Block Media Recovery
- MOS Doc ID 469691.1 — RMAN Backup Validation

---

## 17. Matrice Completa Dei Comandi RMAN 19c

Questa matrice copre i comandi top-level della reference Oracle 19c. I comandi
distruttivi richiedono sempre target verificato, evidenze e change autorizzato.

| Comando | Quando usarlo | Nota operativa |
|---|---|---|
| `@` | Eseguire un command file RMAN versionato | Preferisci file revisionati e log persistenti. |
| `@@` | Richiamare un command file dalla directory dello script corrente | Utile per modularizzare script RMAN versionati. |
| `ADVISE FAILURE` | Consultare workflow DRA storici | Deprecato in 19c: vedi appendice legacy. |
| `ALLOCATE CHANNEL` | Definire channel manuali dentro `RUN` | Usalo per parallelismo, device e rate limit puntuali. |
| `ALLOCATE CHANNEL FOR MAINTENANCE` | Eseguire manutenzione su DISK o SBT specifico | Utile per `CHANGE`, `DELETE` e `CROSSCHECK` su media manager. |
| `BACKUP` | Creare backupset o image copy | Non incorporare cancellazioni nel job predefinito. |
| `CATALOG` | Registrare piece, copy o archivelog esistenti | Usa `CATALOG START WITH` dopo restore o trasferimenti controllati. |
| `CHANGE` | Cambiare stato metadata o uncatalog | Verifica prima `LIST`; non confondere metadata e file fisici. |
| `CHANGE FAILURE` | Aggiornare failure DRA storiche | Deprecato in 19c. |
| `CONFIGURE` | Impostare default persistenti RMAN | Rivedi dopo switchover e cambio storage. |
| `CONNECT` | Collegare target, catalog o auxiliary | Usa OS auth locale, wallet SEPS o prompt interattivo. |
| `CONVERT` | Convertire datafile o tablespace cross-platform | Verifica endian format e percorso XTTS. |
| `CREATE CATALOG` | Creare schema recovery catalog | Esegui nel database catalog dedicato. |
| `CREATE SCRIPT` | Salvare stored script nel catalogo | Versiona comunque la sorgente nel repository. |
| `CROSSCHECK` | Sincronizzare metadata e presenza su media | Non elimina file; marca `EXPIRED` quando assenti. |
| `DELETE` | Rimuovere file e metadata RMAN | Separalo dal backup e applica i gate DG. |
| `DELETE SCRIPT` | Eliminare stored script dal catalogo | Verifica dipendenze operative prima della rimozione. |
| `DESCRIBE` | Ispezionare oggetti del recovery catalog | Utile per reporting catalog personalizzato. |
| `DROP CATALOG` | Eliminare recovery catalog | Distruttivo: solo decommission approvato. |
| `DROP DATABASE` | Eliminare database target registrato | Distruttivo: solo decommission con target verificato. |
| `DUPLICATE` | Creare clone o physical standby | Usa auxiliary `NOMOUNT`, password file coerente e TNS validato. |
| `EXECUTE SCRIPT` | Eseguire stored script del catalogo | Registra nome script, parametri e log. |
| `EXIT` | Terminare sessione RMAN | Verifica exit code negli script shell. |
| `FLASHBACK DATABASE` | Riportare database a SCN, tempo o restore point | Richiede flashback log adeguati e apertura `RESETLOGS`. |
| `GRANT` | Delegare privilegi sul recovery catalog | Applica least privilege. |
| `HOST` | Eseguire comando OS da RMAN | Evitalo negli script se non indispensabile. |
| `IMPORT CATALOG` | Consolidare cataloghi RMAN | Esegui backup catalog e rehearsal prima della migrazione. |
| `LIST` | Elencare backup, copy, archivelog e incarnation | Primo comando diagnostico prima di restore o cleanup. |
| `PRINT SCRIPT` | Visualizzare stored script | Confrontalo con la versione Git prima dell'esecuzione. |
| `QUIT` | Terminare sessione RMAN | Sinonimo di `EXIT`. |
| `RECOVER` | Applicare redo o riparare blocchi, tabelle e standby | Usa la variante adatta allo scenario. |
| `REGISTER DATABASE` | Registrare target nel catalogo | Verifica DBID e ambiente prima di registrare. |
| `RELEASE CHANNEL` | Rilasciare channel manuale | Necessario solo per allocazioni esplicite. |
| `REPAIR FAILURE` | Applicare remediation DRA storiche | Deprecato in 19c; preferisci runbook espliciti. |
| `REPLACE SCRIPT` | Aggiornare stored script catalogo | Mantieni Git come fonte revisionata. |
| `REPORT` | Valutare schema, obsolete e copertura backup | Usa `REPORT OBSOLETE` prima del cleanup. |
| `RESET DATABASE` | Gestire incarnation dopo `RESETLOGS` | Elenca prima con `LIST INCARNATION`. |
| `RESTORE` | Ripristinare file dai backup | Usa `PREVIEW` o `VALIDATE` prima del drill reale. |
| `RESYNC CATALOG` | Riallineare catalogo e controlfile | Esegui dopo riconnessione catalogo o cambi ruolo DG. |
| `REVOKE` | Revocare privilegi catalogo | Applica segregazione dei compiti. |
| `RMAN` | Avviare il client dal sistema operativo | Usa `rman target /` localmente o wallet SEPS da remoto. |
| `RUN` | Raggruppare comandi e variabili di sessione | Usalo per restore e backup multi-step. |
| `SEND` | Inviare stringhe al media manager | Dipende dal vendor SBT; registra il payload nel change. |
| `SET` | Impostare valori di sessione RMAN | Utile per `DBID`, `UNTIL`, encryption e newname. |
| `SHOW` | Visualizzare configurazione persistente | Esegui `SHOW ALL` nel preflight. |
| `SHUTDOWN` | Arrestare il target da RMAN | Solo in runbook con impatto dichiarato. |
| `SPOOL` | Salvare output RMAN su file | Usalo per evidenze di change e drill. |
| `SQL` | Eseguire SQL dal client RMAN | Preferisci istruzioni minime e tracciabili. |
| `SQL` quoted legacy | Eseguire SQL con la vecchia forma quotata | Preferisci la sintassi `SQL` moderna. |
| `STARTUP` | Avviare istanza target o auxiliary | Verifica stato richiesto: `NOMOUNT`, `MOUNT` o `OPEN`. |
| `SWITCH` | Puntare controlfile a copy o newname | Valida path e backup prima dello switch. |
| `TRANSPORT TABLESPACE` | Preparare trasporto tablespace | Usa XTTS per scenari cross-platform approvati. |
| `UNREGISTER DATABASE` | Rimuovere target dal catalogo | Non elimina il database; usa solo per decommission o correzione catalogo. |
| `UPGRADE CATALOG` | Aggiornare schema recovery catalog | Esegui backup catalog e verifica compatibilità client. |
| `VALIDATE` | Leggere file o backup senza restore effettivo | Usa `CHECK LOGICAL` quando serve rilevare corruzione logica. |

---

## 18. Appendice Legacy E Comandi Rischiosi

### 18.1 `DELETE INPUT` e `DELETE ALL INPUT`

Sono clausole Oracle valide, ma non appartengono ai job automatici predefiniti:

```rman
-- LEGACY / SOLO CHANGE AUTORIZZATO:
BACKUP ARCHIVELOG ALL DELETE INPUT;
BACKUP ARCHIVELOG ALL DELETE ALL INPUT;
```

`DELETE INPUT` rimuove la copia letta dal channel; `DELETE ALL INPUT` può
rimuovere tutte le copie corrispondenti. In Data Guard usa una fase di cleanup
separata dopo avere verificato policy, lag e gap.

### 18.2 `BLOCKRECOVER`

La sintassi storica:

```rman
-- LEGACY:
BLOCKRECOVER DATAFILE 5 BLOCK 1234;
```

va sostituita negli esempi operativi 19c con:

```rman
RECOVER DATAFILE 5 BLOCK 1234;
RECOVER CORRUPTION LIST;
```

### 18.3 Data Recovery Advisor

`LIST FAILURE`, `ADVISE FAILURE`, `REPAIR FAILURE` e `CHANGE FAILURE` sono
deprecati in Oracle Database 19c. Possono apparire in documenti storici, ma i
runbook operativi devono usare diagnostica e remediation esplicite.
