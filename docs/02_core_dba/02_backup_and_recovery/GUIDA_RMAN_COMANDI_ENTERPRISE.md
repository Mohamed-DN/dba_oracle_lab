# Guida RMAN Enterprise Completa — Il Riferimento Definitivo

> [!NOTE]
> **DOCUMENTI RMAN CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Guida di Laboratorio (Fase 5)**: [GUIDA_FASE5_RMAN_BACKUP.md](./GUIDA_FASE5_RMAN_BACKUP.md) (impostazione della strategia di backup e cron).
> - **Manuale Comandi Core**: [GUIDA_RMAN_COMANDI_ENTERPRISE.md](./GUIDA_RMAN_COMANDI_ENTERPRISE.md) (questa guida - riferimento completo dei parametri RMAN).
> - **Guida Architetturale Core**: [GUIDA_RMAN_COMPLETA_19C.md](./GUIDA_RMAN_COMPLETA_19C.md) (fondamenti teorici e scenari avanzati).
> - **Cheat Sheet RMAN**: [CS_RMAN.md](../../01_operations/01_cheat_sheets/CS_RMAN.md) (comandi quotidiani, matrice 19c e scenari operativi).

> Guida operativa completa per Oracle RMAN 19c/21c/23ai.
> Copre OGNI aspetto: configurazione, backup, restore, recovery, duplicate, catalog,
> encryption, multitenant, Data Guard, RAC, tape, scheduling, monitoring e troubleshooting.
>
> **Target audience**: DBA Oracle in ambienti enterprise di produzione.

---

## Obiettivi didattici

- Consultare rapidamente sintassi e guardrail RMAN per operazioni enterprise.
- Distinguere backup, restore, recover, duplicate e manutenzione metadata.
- Validare ogni procedura con output osservabili prima di applicarla in produzione.

## Procedura operativa

Individua lo scenario, verifica target e prerequisiti, esegui prima i comandi di
diagnostica e applica la procedura in ambiente di test prima del change produttivo.

## Validazione finale

Conserva log RMAN, exit code, output di `LIST` o `REPORT` e risultato del test di
restore o recovery pertinente allo scenario.

## Troubleshooting rapido

Se il comando coinvolge FRA o archivelog in Data Guard, controlla deletion
policy e lag standby prima di cancellare file. Non usare `rm` sui file Oracle.

## PARTE I — FONDAMENTI E ARCHITETTURA

---

## 1. Architettura RMAN

### 1.1 Componenti RMAN

```
+-----------------------------------------------------+
|                    RMAN Client                       |
|  (CLI o script — genera i comandi di backup/restore) |
+----------+----------------------+--------------------+
           |                      |
    +------v------+        +------v------+
    |   TARGET    |        |  AUXILIARY  |
    |  Database   |        |  Database   |
    | (produzione)|        | (clone/DR)  |
    +------+------+        +-------------+
           |
    +------v------+        +-------------+
    | Controlfile |<------&gt;|  Recovery   |
    | (metadata   |        |  Catalog    |
    |  backup)    |        | (opzionale) |
    +------+------+        +-------------+
           |
    +------v------------------------------+
    |         Storage Layer               |
    |  +-----+  +-----+  +----------+   |
    |  |DISK |  | ASM |  |SBT(Tape) |   |
    |  |/NFS |  | +FRA|  |NetBackup |   |
    |  +-----+  +-----+  |CommVault |   |
    |                     +----------+   |
    +-------------------------------------+
```

### 1.2 Flusso di un Backup RMAN

1. RMAN legge i metadati dal **controlfile** (o catalog) per sapere cosa backuppare
2. Alloca uno o piu **channel** (processi server dedicati al backup)
3. Ogni channel legge i **datafile** blocco per blocco
4. I blocchi vengono compressi (se configurato) e scritti in **backup piece**
5. Piu backup piece formano un **backup set**
6. I metadati del backup vengono registrati nel **controlfile** e nel **catalog** (se presente)
7. RMAN verifica il checksum di ogni blocco durante la lettura (detection corruzione automatica)

### 1.3 Glossario Completo

| Termine | Definizione |
|---|---|
| **Target Database** | Il database di cui si fa backup/restore |
| **Auxiliary Database** | Database temporaneo per DUPLICATE o TSPITR |
| **Recovery Catalog** | Schema dedicato in un DB separato che memorizza i metadati RMAN |
| **Virtual Private Catalog (VPC)** | Sottoinsieme del catalog con accesso ristretto per duty separation |
| **Channel** | Processo server che esegue le operazioni I/O di backup/restore |
| **Backup Set** | Contenitore logico di uno o piu backup piece |
| **Backup Piece** | File fisico generato da RMAN (il file .bkp sul disco) |
| **Image Copy** | Copia esatta byte-per-byte di un datafile (come cp ma consistente) |
| **Incremental Level 0** | Backup di tutti i blocchi usati — baseline per la catena incrementale |
| **Incremental Level 1 Differential** | Solo blocchi cambiati dall'ultimo L0 o L1 |
| **Incremental Level 1 Cumulative** | Solo blocchi cambiati dall'ultimo L0 |
| **Incremental Merge** | Tecnica che applica L1 su image copy per avere sempre una copia aggiornata |
| **Block Change Tracking (BCT)** | File che traccia i blocchi modificati, accelera backup incrementali |
| **SECTION SIZE** | Divide un datafile grande in sezioni processabili in parallelo |
| **Fast Recovery Area (FRA)** | Directory gestita da Oracle per backup, archivelog, flashback log |
| **Recovery Window** | Retention basata su giorni (es. 14 days = posso recuperare fino a 14 gg fa) |
| **Redundancy** | Retention basata su numero di copie (es. 2 = tengo 2 copie di ogni backup) |
| **Obsolete** | Backup non piu necessario secondo la retention policy |
| **Expired** | Backup il cui file fisico non esiste piu sul disco |
| **DBID** | Identificatore univoco del database — necessario per restore senza controlfile |
| **Incarnation** | Versione del database dopo un OPEN RESETLOGS |
| **Tag** | Etichetta alfanumerica assegnata a un backup per identificazione rapida |
| **SYSBACKUP** | Privilegio dedicato per operazioni di backup (separazione da SYSDBA) |
| **Snapshot Controlfile** | Copia temporanea del controlfile usata durante il backup |
| **Controlfile Autobackup** | Backup automatico del controlfile dopo ogni backup RMAN |

---

## 2. Prerequisiti Enterprise

### 2.1 Checklist Pre-Operativa

```sql
-- ============================================
-- CHECKLIST PREREQUISITI RMAN — Esegui PRIMA di operare
-- ============================================

-- 1. Verifica modalita database
SELECT name, db_unique_name, dbid, log_mode, database_role, 
       open_mode, flashback_on, cdb, con_id
FROM v$database;

-- 2. Verifica ARCHIVELOG mode (OBBLIGATORIO per backup online)
ARCHIVE LOG LIST;
-- Se NON e in ARCHIVELOG:
-- SHUTDOWN IMMEDIATE;
-- STARTUP MOUNT;
-- ALTER DATABASE ARCHIVELOG;
-- ALTER DATABASE OPEN;

-- 3. Fast Recovery Area — dimensionamento
SELECT name,
       ROUND(space_limit/1024/1024/1024,2) AS limit_gb,
       ROUND(space_used/1024/1024/1024,2) AS used_gb,
       ROUND(space_reclaimable/1024/1024/1024,2) AS reclaimable_gb,
       ROUND((space_used - space_reclaimable)/space_limit * 100, 1) AS pct_net_used
FROM v$recovery_file_dest;

-- 4. Dettaglio FRA per tipo file
SELECT file_type,
       ROUND(percent_space_used,1) AS pct_used,
       ROUND(percent_space_reclaimable,1) AS pct_reclaimable,
       number_of_files
FROM v$flash_recovery_area_usage
WHERE percent_space_used > 0
ORDER BY percent_space_used DESC;

-- 5. Block Change Tracking
SELECT status, filename, ROUND(bytes/1024/1024,1) AS size_mb 
FROM v$block_change_tracking;
-- Se BCT non attivo:
-- ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+RECO/DB/bct.f';

-- 6. Encryption Wallet/Keystore
SELECT wrl_type, status, wallet_type, wallet_order, con_id 
FROM v$encryption_wallet;

-- 7. CONTROL_FILE_RECORD_KEEP_TIME (se NON usi catalog)
SHOW PARAMETER control_file_record_keep_time;
-- Consigliato: >= retention window + 7 giorni
-- ALTER SYSTEM SET control_file_record_keep_time=45 SCOPE=BOTH;

-- 8. Parametri rilevanti
SHOW PARAMETER db_recovery_file_dest;
SHOW PARAMETER db_recovery_file_dest_size;
SHOW PARAMETER db_flashback_retention_target;
SHOW PARAMETER compatible;

-- 9. Schema del database (datafile, tablespace)
-- RMAN> REPORT SCHEMA;
```

### 2.2 Ambiente OS

```bash
# Verifica variabili ambiente
echo $ORACLE_HOME
echo $ORACLE_SID
echo $ORACLE_BASE

# Verifica connettivita TNS
tnsping PROD
tnsping STBY
tnsping CATDB

# Verifica password file (necessario per connessioni remote)
ls -la $ORACLE_HOME/dbs/orapw*

# Verifica NTP/Chrony (timestamp consistenti)
timedatectl status
chronyc tracking
```

---

## 3. Connessioni RMAN

```bash
# ============================================
# TUTTE LE MODALITA DI CONNESSIONE RMAN
# ============================================

# 1. Connessione locale (OS authentication — piu comune)
rman target /

# 2. Connessione con password
rman target /@PROD

# 3. Connessione con SYSBACKUP (best practice — duty separation)
rman target '"/@PROD as sysbackup"'

# 4. Con Recovery Catalog
rman target / catalog rman_user@CATDB

# 5. Target + Catalog + Auxiliary (per DUPLICATE)
rman target /@PROD auxiliary /@CLONE catalog /@CATDB

# 6. NOCATALOG esplicito (usa solo controlfile)
rman target / nocatalog

# 7. Con logging su file
rman target / log=/backup/logs/rman_$(date +%Y%m%d_%H%M).log append

# 8. Con command file (scripting)
rman target / @/home/oracle/scripts/backup_full.rman

# 9. Con pipe per logging
rman target / | tee /backup/logs/rman_session.log

# 10. Connessione e comando inline
rman target / <<EOF
BACKUP DATABASE PLUS ARCHIVELOG;
EXIT;
EOF
```

### 3.1 Comandi di Sessione

```rman
-- Visualizza configurazione corrente
SHOW ALL;

-- Report schema (tutti i datafile)
REPORT SCHEMA;

-- Report bisogni di backup
REPORT NEED BACKUP;
REPORT NEED BACKUP DAYS 3;

-- Report file con operazioni unrecoverable
REPORT UNRECOVERABLE;

-- Report backup obsoleti
REPORT OBSOLETE;
```

---

## PARTE II — CONFIGURAZIONE ENTERPRISE

---

## 4. Configurazione Baseline Completa

### 4.1 Single Instance (Standard Production)

```rman
-- ============================================
-- CONFIGURAZIONE RMAN ENTERPRISE — SINGLE INSTANCE
-- ============================================

-- Retention: Recovery Window di 14 giorni (allinea a RPO/SLA)
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;
-- Alternativa: Redundancy (tengo N copie)
-- CONFIGURE RETENTION POLICY TO REDUNDANCY 2;

-- Controlfile autobackup: SEMPRE ON (critico per DR)
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '+RECO/%F';

-- Backup optimization: evita backup ridondanti di file gia backuppati
CONFIGURE BACKUP OPTIMIZATION ON;

-- Parallelismo e compressione
CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO COMPRESSED BACKUPSET;

-- Algoritmo compressione baseline senza opzioni aggiuntive
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
-- LOW, MEDIUM e HIGH richiedono gate licenza Advanced Compression.

-- Format path organizzato per data e database
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '+RECO/%d/%T/%U';

-- Snapshot controlfile (path accessibile, shared in RAC)
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '+RECO/%d/snapcf_%d.f';

-- Encryption (se richiesto da policy di sicurezza)
-- CONFIGURE ENCRYPTION FOR DATABASE ON;
-- CONFIGURE ENCRYPTION ALGORITHM 'AES256';

-- Esclusioni (tablespace che non serve backuppare)
-- CONFIGURE EXCLUDE FOR TABLESPACE temp_ts;

-- Max piece size (utile per tape o filesystem con limiti)
-- CONFIGURE MAXSETSIZE TO UNLIMITED;
-- CONFIGURE CHANNEL DEVICE TYPE DISK MAXPIECESIZE 50G;

-- Visualizza configurazione finale
SHOW ALL;
```

### 4.2 Oracle RAC (Multi-Channel Load Balancing)

```rman
-- ============================================
-- CONFIGURAZIONE RMAN — RAC (2+ Nodi)
-- ============================================

-- Canali dedicati per nodo: distribuisce I/O backup tra i nodi
CONFIGURE DEVICE TYPE DISK PARALLELISM 4;
CONFIGURE CHANNEL 1 DEVICE TYPE DISK 
  CONNECT '/@PROD1'
  FORMAT '+RECO/%d/%T/%U';
CONFIGURE CHANNEL 2 DEVICE TYPE DISK 
  CONNECT '/@PROD2'
  FORMAT '+RECO/%d/%T/%U';
CONFIGURE CHANNEL 3 DEVICE TYPE DISK 
  CONNECT '/@PROD1'
  FORMAT '+RECO/%d/%T/%U';
CONFIGURE CHANNEL 4 DEVICE TYPE DISK 
  CONNECT '/@PROD2'
  FORMAT '+RECO/%d/%T/%U';

-- Snapshot controlfile su shared storage (ASM obbligatorio in RAC)
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '+RECO/RACDB/snapcf_racdb.f';

-- NOTA: In RAC, RMAN puo fare backup da qualsiasi nodo.
-- Il load balancing dei canali evita hotspot I/O su un singolo nodo.
```

### 4.3 Data Guard (Primary + Standby)

```rman
-- ============================================
-- CONFIGURAZIONE RMAN — DATA GUARD
-- ============================================

-- Sul PRIMARY: non cancellare archivelog finche non applicati su TUTTE le standby
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

-- Registra la standby nel catalog/controlfile
CONFIGURE DB_UNIQUE_NAME 'STBY' CONNECT IDENTIFIER 'STBY';

-- Configura default device per la standby
CONFIGURE DEFAULT DEVICE TYPE TO DISK FOR DB_UNIQUE_NAME 'STBY';
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '+RECO/%d/%T/%U' FOR DB_UNIQUE_NAME 'STBY';

-- Per backup da ALL (sia primary che standby)
CONFIGURE DEFAULT DEVICE TYPE TO DISK FOR DB_UNIQUE_NAME ALL;
```

**Backup Offloading su Physical Standby:**
```rman
-- Connettiti alla STANDBY come target
rman target /@STBY

-- Backup dalla standby (riduce carico I/O sul primary)
BACKUP AS COMPRESSED BACKUPSET 
  DATABASE TAG 'STBY_FULL'
  PLUS ARCHIVELOG TAG 'STBY_ARCH';

-- NOTA: I backup fatti dalla standby sono utilizzabili per restore sia
-- sulla standby che sul primary (stessi DBID).
-- Il backup e' possibile anche con standby mounted. Active Data Guard serve
-- solo se lo standby deve restare OPEN READ ONLY WITH APPLY.
```

### 4.4 Encryption Completa (TDE Integration)

```rman
-- ============================================
-- CONFIGURAZIONE ENCRYPTION RMAN
-- ============================================

-- METODO 1: Transparent Encryption (usa Wallet/Keystore — RACCOMANDATO)
-- Prerequisito: TDE configurato e wallet OPEN
CONFIGURE ENCRYPTION FOR DATABASE ON;
CONFIGURE ENCRYPTION ALGORITHM 'AES256';  -- Default in 23ai

-- METODO 2: Password-based Encryption (se wallet non disponibile)
-- Usalo in sessione RUN{}, non persistente
SET ENCRYPTION ON IDENTIFIED BY '<BACKUP_ENCRYPTION_PASSWORD>' ONLY;

-- METODO 3: Dual-mode (decrypt con wallet O password — piu flessibile)
SET ENCRYPTION IDENTIFIED BY '<BACKUP_ENCRYPTION_PASSWORD>';
-- Questo permette di ripristinare usando wallet OPPURE password

-- METODO 4: Encryption per tablespace specifici
CONFIGURE ENCRYPTION FOR TABLESPACE users ON;
CONFIGURE ENCRYPTION FOR TABLESPACE hr_data ON;

-- Per DISABILITARE encryption
-- CONFIGURE ENCRYPTION FOR DATABASE OFF;
```

> **CRITICO**: Se perdi sia il wallet che la password, i backup cifrati sono IRRECUPERABILI.
> **SEMPRE** backuppare il wallet separatamente:
```bash
cp -rp $ORACLE_BASE/admin/$ORACLE_SID/wallet /backup/secure/wallet_$(date +%Y%m%d)
# O per auto-login wallet:
cp -rp $ORACLE_BASE/admin/$ORACLE_SID/tde_wallet /backup/secure/
```

### 4.5 SBT / Tape / Media Manager / Cloud

```rman
-- ============================================
-- CONFIGURAZIONE SBT (TAPE / CLOUD)
-- ============================================

-- NetBackup
CONFIGURE CHANNEL DEVICE TYPE sbt
  PARMS 'SBT_LIBRARY=/usr/openv/netbackup/bin/libobk.so64,
         ENV=(NB_ORA_SERV=media_server, NB_ORA_POLICY=oracle_full, NB_ORA_SCHED=full_sched)';
CONFIGURE DEFAULT DEVICE TYPE TO sbt;

-- CommVault
CONFIGURE CHANNEL DEVICE TYPE sbt
  PARMS 'SBT_LIBRARY=/opt/commvault/Base64/libobk.so,
         ENV=(CvInstanceName=Instance001, CvClientName=dbhost01)';

-- Oracle Cloud Infrastructure (OCI Object Storage)
CONFIGURE CHANNEL DEVICE TYPE sbt
  PARMS 'SBT_LIBRARY=$ORACLE_HOME/lib/libopc.so,
         ENV=(OPC_PFILE=/home/oracle/opc_wallet/opc.ora)';

-- Data Domain (Dell/EMC)
CONFIGURE CHANNEL DEVICE TYPE sbt
  PARMS 'SBT_LIBRARY=/usr/openv/netbackup/bin/libobk.so64,
         ENV=(STORAGE_HOST=datadomain01, STORAGE_PATH=/oracle_backup)';

-- Test SBT connection
-- $ sbttest test_file.tst
```

### 4.6 Block Change Tracking (BCT)

```sql
-- ============================================
-- BLOCK CHANGE TRACKING — Accelera backup incrementali
-- ============================================

-- Verifica stato attuale
SELECT status, filename, ROUND(bytes/1024/1024,1) AS size_mb 
FROM v$block_change_tracking;

-- Abilita BCT (su ASM o filesystem)
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING 
  USING FILE '+RECO/PROD/bct_prod.f';
-- Oppure su filesystem:
-- ALTER DATABASE ENABLE BLOCK CHANGE TRACKING 
--   USING FILE '/u01/oradata/prod/bct.dbf' REUSE;

-- Disabilita (se necessario)
-- ALTER DATABASE DISABLE BLOCK CHANGE TRACKING;

-- NOTA: BCT riduce il tempo di backup incrementale fino al 90%
-- perche RMAN legge solo i blocchi cambiati, senza scansione completa.
-- Il file BCT e piccolo (tipicamente < 1% della dimensione del DB).
-- In RAC, il file DEVE essere su shared storage (ASM).
```

---

## PARTE III — STRATEGIE DI BACKUP

---

## 5. Decision Tree — Quale Strategia Scegliere

```
                    +---------------------+
                    |  SCEGLI STRATEGIA   |
                    |     DI BACKUP       |
                    +---------+-----------+
                              |
                 +------------v------------+
                 | RPO (Recovery Point     |
                 | Objective) richiesto?   |
                 +------------+------------+
                    +---------+----------+
               < 1 ora                > 1 ora
                    |                    |
          +---------v---------+ +-------v--------+
          | Archivelog backup | | Full Weekly +  |
          | ogni 15-30 min + | | Incremental    |
          | Incremental L1   | | Daily L1       |
          | giornaliero      | +-------+--------+
          +---------+---------+        |
                    |         +--------v--------+
                    |         | RTO richiesto?  |
                    |         +--------+--------+
                    |           +------+-------+
                    |      < 30 min        > 30 min
                    |           |              |
                    |  +--------v--------+ +---v------------+
                    |  | Image Copy +   | | Backupset      |
                    |  | Incremental   | | standard       |
                    |  | Merge (SWITCH)| | (compresso)    |
                    |  +----------------+ +----------------+
                    |
           +--------v--------+
           | DB > 5 TB?      |
           +--------+--------+
             +------+------+
            SI            NO
             |              |
    +--------v--------+    Standard
    | SECTION SIZE   |
    | + Multi-channel|
    | + Backup da   |
    |   Standby     |
    +-----------------+
```

### 5.1 Strategia 1: Full + Archivelog (Base)

La strategia piu semplice e affidabile. Adatta a database < 500 GB.

```rman
-- Backup completo con archivelog
RUN {
  SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";
  BACKUP AS COMPRESSED BACKUPSET 
    DATABASE TAG 'FULL_DAILY'
    PLUS ARCHIVELOG NOT BACKED UP 1 TIMES TAG 'ARCH_DAILY';
  BACKUP CURRENT CONTROLFILE TAG 'CTRL_DAILY';
  BACKUP SPFILE TAG 'SPFILE_DAILY';
}
```

### 5.2 Strategia 2: Incremental (Weekly L0 + Daily L1)

La strategia piu comune in produzione. Riduce finestra di backup.

```rman
-- DOMENICA: Level 0 (baseline completa)
BACKUP INCREMENTAL LEVEL 0 AS COMPRESSED BACKUPSET 
  DATABASE TAG 'WEEKLY_L0'
  PLUS ARCHIVELOG NOT BACKED UP 1 TIMES;

-- LUN-SAB: Level 1 Differential
BACKUP INCREMENTAL LEVEL 1 AS COMPRESSED BACKUPSET 
  DATABASE TAG 'DAILY_L1'
  PLUS ARCHIVELOG NOT BACKED UP 1 TIMES;

-- Oppure Level 1 Cumulative (piu sicuro, piu grande)
-- BACKUP INCREMENTAL LEVEL 1 CUMULATIVE AS COMPRESSED BACKUPSET
--   DATABASE TAG 'DAILY_L1_CUM';
```

### 5.3 Strategia 3: Incremental Merge (Instant Recovery)

Per RTO bassissimo. La image copy viene aggiornata in-place ogni giorno.

```rman
-- Giorno 1: Baseline image copy
BACKUP AS COPY DATABASE TAG 'INCR_MERGE';

-- Giorni successivi (ogni giorno):
-- 1. Crea backup incrementale
BACKUP INCREMENTAL LEVEL 1 
  FOR RECOVER OF COPY WITH TAG 'INCR_MERGE' DATABASE;
-- 2. Applica incrementale sulla image copy
RECOVER COPY OF DATABASE WITH TAG 'INCR_MERGE';

-- Restore ISTANTANEO (switch, non copia!):
-- SWITCH DATABASE TO COPY;
-- RECOVER DATABASE;
-- ALTER DATABASE OPEN;
-- Tempo di restore: secondi, non ore!
```

### 5.4 Strategia 4: Multitenant (CDB/PDB)

```rman
-- ============================================
-- BACKUP MULTITENANT
-- ============================================

-- Connesso a CDB$ROOT come SYSBACKUP:

-- Backup intero Container Database (CDB root + tutti i PDB)
BACKUP DATABASE PLUS ARCHIVELOG TAG 'CDB_FULL';

-- Backup singolo PDB
BACKUP PLUGGABLE DATABASE hr_pdb TAG 'PDB_HR';

-- Backup multipli PDB
BACKUP PLUGGABLE DATABASE hr_pdb, sales_pdb, finance_pdb TAG 'PDB_MULTI';

-- Backup tablespace di un PDB specifico
BACKUP TABLESPACE hr_pdb:users TAG 'PDB_HR_USERS';

-- Backup datafile di un PDB specifico
BACKUP DATAFILE 15 TAG 'PDB_DF15';  -- datafile# del PDB

-- Backup solo CDB$ROOT (senza PDB)
BACKUP DATABASE ROOT TAG 'CDB_ROOT_ONLY';

-- Backup archivelog
BACKUP ARCHIVELOG ALL TAG 'ARCH_CDB';
```

### 5.5 Backup per Componenti Specifici

```rman
-- Tablespace
BACKUP TABLESPACE users, indx TAG 'TS_USERS_INDX';

-- Datafile per numero
BACKUP DATAFILE 7 TAG 'DF7';

-- Datafile per path
BACKUP DATAFILE '/u01/oradata/prod/users01.dbf' TAG 'DF_USERS01';

-- Controlfile
BACKUP CURRENT CONTROLFILE TAG 'CTRL_MANUAL';
BACKUP CURRENT CONTROLFILE TO '/backup/ctrl_backup.bkp';

-- SPFILE
BACKUP SPFILE TAG 'SPFILE_MANUAL';

-- Archivelog per range
BACKUP ARCHIVELOG FROM SEQUENCE 100 UNTIL SEQUENCE 200 THREAD 1;
BACKUP ARCHIVELOG FROM TIME 'SYSDATE-1';
BACKUP ARCHIVELOG ALL NOT BACKED UP 2 TIMES;
```

### 5.6 SECTION SIZE per Database Grandi

```rman
-- Divide ogni datafile in sezioni da 8 GB processate in parallelo
-- Ideale per datafile > 50 GB
BACKUP SECTION SIZE 8G 
  AS COMPRESSED BACKUPSET 
  DATABASE TAG 'MULTISECTION_FULL';

-- Con incrementale
BACKUP INCREMENTAL LEVEL 1 
  SECTION SIZE 4G 
  DATABASE TAG 'MULTISECTION_L1';

-- NOTA: Non usare SECTION SIZE con MAXPIECESIZE
-- NOTA: Max 256 sezioni per datafile (RMAN aggiusta automaticamente)
```

### 5.7 Backup da Physical Standby

```rman
-- ============================================
-- BACKUP OFFLOADING SU STANDBY
-- ============================================
-- Vantaggio: zero impatto I/O sul primary

-- 1. Connettiti alla standby
rman target /@STBY

-- 2. Backup completo dalla standby
BACKUP AS COMPRESSED BACKUPSET 
  DATABASE TAG 'STBY_FULL'
  PLUS ARCHIVELOG;

-- 3. Backup incrementale dalla standby
BACKUP INCREMENTAL LEVEL 1 
  DATABASE TAG 'STBY_L1'
  PLUS ARCHIVELOG;

-- NOTA: I backup della standby hanno lo stesso DBID del primary
-- e possono essere usati per restore su entrambi.
-- Lo standby puo' restare mounted. Il gate Active Data Guard e' necessario
-- solo per OPEN READ ONLY WITH APPLY.
```


---

## PARTE IV — RESTORE E RECOVERY

---

## 6. Restore e Recovery Completo

### 6.1 Restore Database Completo

```rman
-- Database in MOUNT
STARTUP MOUNT;
RESTORE DATABASE;
RECOVER DATABASE;
ALTER DATABASE OPEN;
```

### 6.2 Point-in-Time Recovery (PITR)

```rman
STARTUP MOUNT;
RUN {
  SET UNTIL TIME "TO_DATE('2026-05-13 10:30:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE DATABASE;
  RECOVER DATABASE;
}
ALTER DATABASE OPEN RESETLOGS;
```

### 6.3 PITR con SCN

```rman
STARTUP MOUNT;
RUN {
  SET UNTIL SCN 1234567;
  RESTORE DATABASE;
  RECOVER DATABASE;
}
ALTER DATABASE OPEN RESETLOGS;
```

### 6.4 PITR con Log Sequence

```rman
STARTUP MOUNT;
RUN {
  SET UNTIL SEQUENCE 500 THREAD 1;
  RESTORE DATABASE;
  RECOVER DATABASE;
}
ALTER DATABASE OPEN RESETLOGS;
```

### 6.5 Restore Singolo Datafile (Database OPEN)

```rman
-- Online recovery: il database resta aperto
SQL "ALTER DATABASE DATAFILE 7 OFFLINE";
RESTORE DATAFILE 7;
RECOVER DATAFILE 7;
SQL "ALTER DATABASE DATAFILE 7 ONLINE";
```

### 6.6 Restore Tablespace

```rman
SQL "ALTER TABLESPACE users OFFLINE IMMEDIATE";
RESTORE TABLESPACE users;
RECOVER TABLESPACE users;
SQL "ALTER TABLESPACE users ONLINE";
```

### 6.7 Tablespace Point-in-Time Recovery (TSPITR)

```rman
-- RMAN crea un'istanza auxiliary automaticamente
RECOVER TABLESPACE users
  UNTIL TIME "TO_DATE('2026-05-13 10:00:00','YYYY-MM-DD HH24:MI:SS')"
  AUXILIARY DESTINATION '/u01/aux';
```

### 6.7.1 Recover Table (DROP o DELETE accidentale)

```rman
-- Target aperto read-write, ARCHIVELOG attivo, connessione RMAN locale.
RECOVER TABLE HR.ORDERS
  UNTIL TIME 'SYSDATE-1'
  AUXILIARY DESTINATION '/u01/rman_table_aux'
  REMAP TABLE 'HR'.'ORDERS':'ORDERS_RECOVERED';

-- Variante PDB dalla root CDB. NOTABLEIMPORT crea il dump senza import automatico.
RECOVER TABLE HR.ORDERS OF PLUGGABLE DATABASE APPPDB
  UNTIL SCN 123456789
  AUXILIARY DESTINATION '/u01/rman_table_aux'
  DATAPUMP DESTINATION '/u01/rman_table_dump'
  DUMP FILE 'orders_recovered.dmp'
  NOTABLEIMPORT;
```

RMAN crea un auxiliary database temporaneo e usa Data Pump per importare la
tabella recuperata. Prima del comando verifica backup e archivelog continui,
spazio auxiliary e limiti Oracle. Per importare in uno schema differente gia'
esistente usa, da Oracle 12.2, una destinazione come
`REMAP TABLE 'HR'.'ORDERS':'RECOVERY_USER'.'ORDERS_RECOVERED'`.

### 6.8 Block Media Recovery (BMR)

```rman
-- Ripara blocchi corrotti senza restore completo
RECOVER DATAFILE 7 BLOCK 12345;
RECOVER DATAFILE 7 BLOCK 12345, 12346, 12347;
RECOVER DATAFILE 7 BLOCK 12345 FROM BACKUPSET;

-- Trova blocchi corrotti
-- SELECT file#, block#, blocks, corruption_type
-- FROM v$database_block_corruption;
```

### 6.9 Disaster Recovery — Perdita Totale Server

```rman
-- Scenario: persi SPFILE, Controlfile e Datafile

-- 1. Recupera il DBID (se non lo hai, cercalo nei log o nel catalog)
-- SELECT DBID FROM V$DATABASE; -- se hai accesso ad altra copia

-- 2. Avvia con pfile minimale
SET DBID 1234567890;
STARTUP FORCE NOMOUNT;

-- 3. Restore SPFILE da autobackup
RESTORE SPFILE FROM AUTOBACKUP;
-- Se autobackup non in FRA:
-- RESTORE SPFILE FROM AUTOBACKUP
--   DB_RECOVERY_FILE_DEST='/backup/fra';
STARTUP FORCE NOMOUNT;

-- 4. Restore Controlfile
RESTORE CONTROLFILE FROM AUTOBACKUP;
ALTER DATABASE MOUNT;

-- 5. Catalogare backup se su path non standard
CATALOG START WITH '+RECO/';
CATALOG START WITH '/backup/rman/';

-- 6. Restore e Recover
RESTORE DATABASE;
RECOVER DATABASE;

-- 7. Apertura con reset
ALTER DATABASE OPEN RESETLOGS;
```

### 6.10 Restore Controlfile e SPFILE Separati

```rman
-- SPFILE da autobackup
STARTUP NOMOUNT;
RESTORE SPFILE FROM AUTOBACKUP;
RESTORE SPFILE TO '/tmp/spfile_restored.ora' FROM AUTOBACKUP;
RESTORE SPFILE FROM AUTOBACKUP
  MAXSEQ 100 MAXDAYS 30;

-- Controlfile da autobackup
RESTORE CONTROLFILE FROM AUTOBACKUP;

-- Controlfile da backup specifico
RESTORE CONTROLFILE FROM '/backup/ctrl.bkp';
RESTORE CONTROLFILE FROM TAG 'CTRL_DAILY';
```

### 6.11 Restore Multitenant (PDB)

```rman
-- Restore/recover singolo PDB
ALTER PLUGGABLE DATABASE hr_pdb CLOSE IMMEDIATE;
RESTORE PLUGGABLE DATABASE hr_pdb;
RECOVER PLUGGABLE DATABASE hr_pdb;
ALTER PLUGGABLE DATABASE hr_pdb OPEN;

-- PITR di un PDB
ALTER PLUGGABLE DATABASE hr_pdb CLOSE IMMEDIATE;
RUN {
  SET UNTIL TIME "TO_DATE('2026-05-13 10:00:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE PLUGGABLE DATABASE hr_pdb;
  RECOVER PLUGGABLE DATABASE hr_pdb AUXILIARY DESTINATION '/u01/aux';
}
ALTER PLUGGABLE DATABASE hr_pdb OPEN RESETLOGS;
```

### 6.12 Restore con Preview (Dry Run)

```rman
-- Mostra cosa RMAN userebbe senza eseguire
RESTORE DATABASE PREVIEW;
RESTORE DATABASE PREVIEW SUMMARY;
RESTORE TABLESPACE users PREVIEW;
```

---

## PARTE V — DUPLICATE, CATALOG, VALIDAZIONE

---

## 7. DUPLICATE (Clone, Test, Standby)

### 7.1 Active Duplicate (Rete diretta)

```rman
DUPLICATE TARGET DATABASE TO CLONE
  FROM ACTIVE DATABASE
  NOFILENAMECHECK
  SPFILE
    SET DB_UNIQUE_NAME='CLONE'
    SET CONTROL_FILES='+DATA/CLONE/controlfile/control01.ctl'
    SET LOG_FILE_NAME_CONVERT='+DATA/PROD','+DATA/CLONE','+RECO/PROD','+RECO/CLONE'
    SET DB_FILE_NAME_CONVERT='+DATA/PROD','+DATA/CLONE','+RECO/PROD','+RECO/CLONE'
    SET AUDIT_FILE_DEST='/u01/app/oracle/admin/CLONE/adump'
    SET DIAGNOSTIC_DEST='/u01/app/oracle';
```

### 7.2 Duplicate per Standby

```rman
DUPLICATE TARGET DATABASE FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  NOFILENAMECHECK
  SPFILE
    SET DB_UNIQUE_NAME='STBY'
    SET FAL_SERVER='PROD'
    SET LOG_ARCHIVE_DEST_2='SERVICE=PROD ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=PROD';
```

### 7.3 Duplicate con PITR

```rman
DUPLICATE TARGET DATABASE TO TESTDB
  UNTIL TIME "TO_DATE('2026-05-13 08:00:00','YYYY-MM-DD HH24:MI:SS')"
  NOFILENAMECHECK
  DB_FILE_NAME_CONVERT '/u01/oradata/prod','/u02/oradata/test'
  SPFILE SET DB_UNIQUE_NAME='TESTDB';
```

### 7.4 Duplicate da Backup (Senza Rete al Source)

```rman
DUPLICATE TARGET DATABASE TO CLONE
  BACKUP LOCATION '/backup/rman/'
  NOFILENAMECHECK;
```

---

## 8. Recovery Catalog & Virtual Private Catalog

### 8.1 Setup Catalog

```sql
-- 1. Nel database del catalog, crea schema dedicato
CREATE TABLESPACE rman_ts DATAFILE SIZE 500M AUTOEXTEND ON MAXSIZE 5G;
CREATE USER rman_admin IDENTIFIED BY "<PASSWORD_CATALOGO>"
  DEFAULT TABLESPACE rman_ts
  QUOTA UNLIMITED ON rman_ts;
GRANT RECOVERY_CATALOG_OWNER TO rman_admin;
GRANT CREATE SESSION TO rman_admin;
```

```rman
-- 2. In RMAN: crea il catalog
RMAN CATALOG /@CATDB
CREATE CATALOG;

-- 3. Registra i database
RMAN TARGET / CATALOG /@CATDB
REGISTER DATABASE;

-- 4. Sincronizza
RESYNC CATALOG;
RESYNC CATALOG FROM DB_UNIQUE_NAME ALL;
```

### 8.2 Virtual Private Catalog (VPC)

```sql
-- Crea utente VPC per ogni team/database
CREATE USER vpc_team_a IDENTIFIED BY "<PASSWORD_VPC>"
  DEFAULT TABLESPACE rman_ts QUOTA UNLIMITED ON rman_ts;
GRANT RECOVERY_CATALOG_OWNER TO vpc_team_a;
```

```rman
-- Grant accesso solo a database specifici
RMAN CATALOG /@CATDB
GRANT CATALOG FOR DATABASE prod_a TO vpc_team_a;
GRANT CATALOG FOR DATABASE prod_b TO vpc_team_a;
-- REVOKE: REVOKE CATALOG FOR DATABASE prod_b FROM vpc_team_a;
```

### 8.3 Stored Scripts

```rman
-- Creare script locale (associato al target)
CREATE SCRIPT daily_full {
  BACKUP AS COMPRESSED BACKUPSET DATABASE
    PLUS ARCHIVELOG;
  BACKUP CURRENT CONTROLFILE;
  BACKUP SPFILE;
}

-- Creare script globale di diagnostica (tutti i DB nel catalog)
CREATE GLOBAL SCRIPT global_arch_report {
  SHOW ARCHIVELOG DELETION POLICY;
  LIST EXPIRED ARCHIVELOG ALL;
  REPORT OBSOLETE;
}

-- Eseguire
RUN { EXECUTE SCRIPT daily_full; }
RUN { EXECUTE GLOBAL SCRIPT global_arch_report; }

-- Gestione
LIST SCRIPT NAMES;
LIST ALL SCRIPT NAMES;
LIST GLOBAL SCRIPT NAMES;
PRINT SCRIPT daily_full;
PRINT GLOBAL SCRIPT global_arch_cleanup;
DELETE SCRIPT daily_full;
DELETE GLOBAL SCRIPT global_arch_cleanup;
```

---

## 9. Validazione e Verifica Continua

```rman
-- ============================================
-- VALIDAZIONE — Esegui SETTIMANALMENTE
-- ============================================

-- Verifica integrita backup (senza restore fisico)
RESTORE DATABASE VALIDATE;
RESTORE DATABASE VALIDATE CHECK LOGICAL;
VALIDATE DATABASE;
VALIDATE CHECK LOGICAL DATABASE;
VALIDATE BACKUPSET 123;

-- Preview restore (mostra cosa RMAN userebbe)
RESTORE DATABASE PREVIEW;
RESTORE DATABASE PREVIEW SUMMARY;

-- Crosscheck: allinea metadati RMAN a storage reale
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
CROSSCHECK COPY;
CROSSCHECK BACKUP OF CONTROLFILE;

-- Report
REPORT SCHEMA;
REPORT NEED BACKUP;
REPORT NEED BACKUP DAYS 3;
REPORT OBSOLETE;
REPORT UNRECOVERABLE;

-- LIST
LIST BACKUP SUMMARY;
LIST BACKUP OF DATABASE;
LIST BACKUP OF ARCHIVELOG ALL;
LIST BACKUP BY FILE;
LIST BACKUP TAG 'WEEKLY_L0';
LIST EXPIRED BACKUP;
LIST INCARNATION;
LIST RESTORE POINT ALL;
LIST COPY OF DATABASE;
LIST ARCHIVELOG ALL;
```

---

## 10. Manutenzione e Pulizia

Questa sezione non appartiene al job automatico di backup. Prima di cancellare
archivelog verifica spazio reale, deletion policy, transport lag, apply lag,
sequenze shipped/applied e `V$ARCHIVE_GAP` sullo standby. Registra change,
approvazione ed evidenze. Non usare `DELETE FORCE` salvo ultima scelta
autorizzata con degrado DR dichiarato.

```rman
-- Cancella backup obsoleti
DELETE NOPROMPT OBSOLETE;
CROSSCHECK BACKUP;
DELETE NOPROMPT EXPIRED BACKUP;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;

-- Cancella per data
DELETE BACKUP COMPLETED BEFORE 'SYSDATE-30';

-- Archivelog: applica la deletion policy, soprattutto in Data Guard.
SHOW ARCHIVELOG DELETION POLICY;
DELETE NOPROMPT ARCHIVELOG ALL;

-- Cancella per tag
DELETE BACKUP TAG 'OLD_TEST';

-- Cancella backup specifico
DELETE BACKUPSET 123;

-- Catalogare backup esterni
CATALOG START WITH '/backup/imported/';
CATALOG BACKUPPIECE '/backup/external.bkp';
CATALOG DATAFILECOPY '/u01/copy/users01.dbf';

-- Uncatalog (rimuovi da metadati senza cancellare file)
UNCATALOG BACKUPPIECE '/backup/old.bkp';
```

---

## PARTE VI — SCHEDULING, MONITORING, TROUBLESHOOTING

---

## 11. Scheduling Enterprise

### 11.1 Script Shell di Backup

```bash
#!/bin/bash
# /home/oracle/scripts/rman_backup.sh
# Uso: rman_backup.sh [FULL|INCR|ARCH]

export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=PROD
export PATH=$ORACLE_HOME/bin:$PATH
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

BACKUP_TYPE=${1:-INCR}
LOG_DIR=/backup/logs
LOG_FILE=${LOG_DIR}/rman_${BACKUP_TYPE}_$(date +%Y%m%d_%H%M).log
ALERT_EMAIL="dba-team@company.com"

mkdir -p $LOG_DIR

case $BACKUP_TYPE in
  FULL)
    rman target / log=$LOG_FILE <<EOF
BACKUP AS COMPRESSED BACKUPSET
  INCREMENTAL LEVEL 0
  DATABASE TAG 'FULL_$(date +%Y%m%d)'
  PLUS ARCHIVELOG NOT BACKED UP 1 TIMES;
BACKUP CURRENT CONTROLFILE TAG 'CTRL_$(date +%Y%m%d)';
BACKUP SPFILE TAG 'SPFILE_$(date +%Y%m%d)';
EXIT;
EOF
    ;;
  INCR)
    rman target / log=$LOG_FILE <<EOF
BACKUP AS COMPRESSED BACKUPSET
  INCREMENTAL LEVEL 1
  DATABASE TAG 'INCR_$(date +%Y%m%d)'
  PLUS ARCHIVELOG NOT BACKED UP 1 TIMES;
EXIT;
EOF
    ;;
  ARCH)
    rman target / log=$LOG_FILE <<EOF
BACKUP AS COMPRESSED BACKUPSET
  ARCHIVELOG ALL NOT BACKED UP 1 TIMES
  TAG 'ARCH_$(date +%Y%m%d_%H%M)';
EXIT;
EOF
    ;;
esac

# Check risultato
if grep -qi "RMAN-\|ORA-" $LOG_FILE; then
  echo "BACKUP $BACKUP_TYPE FAILED on $(hostname) at $(date)" | \
    mail -s "ALERT: RMAN Backup Failed - $ORACLE_SID" $ALERT_EMAIL
  exit 1
fi
exit 0
```

### 11.2 Crontab

```bash
# /etc/cron.d/rman_backup
# Full domenica 01:00
0 1 * * 0 oracle /home/oracle/scripts/rman_backup.sh FULL
# Incremental lun-sab 01:00
0 1 * * 1-6 oracle /home/oracle/scripts/rman_backup.sh INCR
# Archivelog ogni 30 minuti
*/30 * * * * oracle /home/oracle/scripts/rman_backup.sh ARCH
# Cleanup separato: schedulalo solo se lo script implementa i gate Data Guard,
# produce evidenze e l'automazione e' stata formalmente approvata.
# 0 6 * * 6 oracle /home/oracle/scripts/rman_cleanup_authorized.sh
# Validate ogni domenica 06:00
0 6 * * 0 oracle /home/oracle/scripts/rman_validate.sh
```

### 11.3 DBMS_SCHEDULER

```sql
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'RMAN_DAILY_L1',
    job_type        => 'EXECUTABLE',
    job_action      => '/home/oracle/scripts/rman_backup.sh',
    number_of_arguments => 1,
    repeat_interval => 'FREQ=DAILY;BYHOUR=1;BYMINUTE=0',
    enabled         => FALSE,
    comments        => 'RMAN Incremental Level 1 giornaliero'
  );
  DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('RMAN_DAILY_L1', 1, 'INCR');
  DBMS_SCHEDULER.ENABLE('RMAN_DAILY_L1');
END;
/
```

---

## 12. Monitoraggio Operativo

### 12.1 Query SQL per Dashboard

```sql
-- ============================================
-- MONITORAGGIO RMAN — Query per Dashboard/Alert
-- ============================================

-- 1. Status ultimi job RMAN
SELECT TO_CHAR(start_time,'DD-MON HH24:MI') started,
       TO_CHAR(end_time,'DD-MON HH24:MI') ended,
       status, input_type, output_device_type,
       output_bytes_display, time_taken_display
FROM v$rman_backup_job_details
ORDER BY start_time DESC FETCH FIRST 20 ROWS ONLY;

-- 2. Ultimo backup per tipo
SELECT input_type,
       MAX(TO_CHAR(start_time,'DD-MON-YY HH24:MI')) AS ultimo,
       ROUND(SYSDATE - MAX(start_time),1) AS giorni_fa
FROM v$rman_backup_job_details
WHERE status IN ('COMPLETED','COMPLETED WITH WARNINGS')
GROUP BY input_type ORDER BY MAX(start_time) DESC;

-- 3. Corruzioni note
SELECT file#, block#, blocks, corruption_type, corruption_change#
FROM v$database_block_corruption
ORDER BY file#, block#;

-- 4. FRA usage con alert
SELECT name,
       ROUND(space_limit/1024/1024/1024,1) AS limit_gb,
       ROUND(space_used/1024/1024/1024,1) AS used_gb,
       ROUND(space_used/space_limit*100,1) AS pct_used,
       CASE WHEN space_used/space_limit > 0.85 THEN 'CRITICAL'
            WHEN space_used/space_limit > 0.70 THEN 'WARNING'
            ELSE 'OK' END AS status
FROM v$recovery_file_dest;

-- 5. Backup I/O throughput
SELECT device_type, type, status,
       ROUND(bytes/1024/1024) AS mb,
       ROUND(effective_bytes_per_second/1024/1024) AS mb_per_sec
FROM v$backup_async_io
WHERE type != 'AGGREGATE' ORDER BY bytes DESC
FETCH FIRST 20 ROWS ONLY;

-- 6. Archivelog non backuppati
SELECT sequence#, first_time, next_time, applied, backed_up
FROM v$archived_log
WHERE backed_up = 'NO' AND deleted = 'NO'
ORDER BY sequence# DESC FETCH FIRST 20 ROWS ONLY;

-- 7. Alert: nessun backup nelle ultime 24h
SELECT 'ALERT: No backup in 24h for ' || d.name AS alert_msg
FROM v$database d
WHERE NOT EXISTS (
  SELECT 1 FROM v$rman_backup_job_details
  WHERE status = 'COMPLETED'
    AND input_type IN ('DB FULL','DB INCR')
    AND start_time > SYSDATE - 1
);

-- 8. Alert: FRA > 85%
SELECT 'ALERT: FRA at '||ROUND(space_used/space_limit*100,1)||'%'
FROM v$recovery_file_dest WHERE space_used/space_limit > 0.85;

-- 9. Job RMAN attualmente in esecuzione
SELECT sid, serial#, opname, sofar, totalwork,
       ROUND(sofar/totalwork*100,1) AS pct_done,
       time_remaining AS seconds_left
FROM v$session_longops
WHERE opname LIKE 'RMAN%' AND sofar < totalwork;
```

---

## 13. Format Specifiers Reference

| Specifier | Descrizione | Esempio Output |
|---|---|---|
| %d | Database name | PROD |
| %D | Giorno (DD) | 13 |
| %M | Mese (MM) | 05 |
| %Y | Anno (YYYY) | 2026 |
| %T | Data YYYYMMDD | 20260513 |
| %s | Backup set number | 42 |
| %p | Piece number | 1 |
| %c | Channel number | 2 |
| %t | Timestamp (backup set) | 1173293485 |
| %u | Unique 8-char name | 0dlu2fh4 |
| %U | Unique generated (%u_%p_%c) | 0dlu2fh4_1_2 |
| %F | Unique c-IIIIIIIIII-YYYYMMDD-QQ | c-1234567-20260513-01 |

---

## 14. Best Practice Enterprise Checklist

```
[x] ARCHIVELOG mode attivo
[x] FRA dimensionata (min 2x dimensione DB, consigliato 3x)
[x] CONTROLFILE AUTOBACKUP ON
[x] BCT (Block Change Tracking) abilitato
[x] BACKUP OPTIMIZATION ON
[x] CONTROL_FILE_RECORD_KEEP_TIME >= retention + 7 giorni
[x] Tag su OGNI backup per audit trail
[x] Compressione MEDIUM (bilancia CPU/IO)
[x] Retention policy allineata a RPO/RTO
[x] CROSSCHECK + DELETE OBSOLETE schedulati settimanalmente
[x] RESTORE VALIDATE schedulato settimanalmente
[x] VALIDATE CHECK LOGICAL DATABASE schedulato mensilmente
[x] Encryption attiva se dati sensibili o backup off-site
[x] Wallet/Keystore backup separato e verificato
[x] Log RMAN centralizzati con alert su FAILED via email
[x] Backup da Standby per ridurre I/O su primary
[x] Separazione storage (backup su target distinto)
[x] SYSBACKUP role (non SYSDBA) per duty separation
[x] Test di restore completo almeno trimestrale
[x] Script di backup con error handling e notifica
[x] Snapshot controlfile su shared storage (RAC)
[x] SECTION SIZE per datafile > 50 GB
[x] Documentazione runbook aggiornata dopo ogni modifica
```

---

## 15. Troubleshooting Completo

### Regola Aurea: Leggi l'Error Stack dal BASSO verso l'ALTO

Il root cause e sempre l'ULTIMO errore nello stack.

| # | Errore | Causa | Diagnostica | Risoluzione |
|---|---|---|---|---|
| 1 | ORA-19809/19804 | FRA piena | v$recovery_file_dest | Aumenta FRA o DELETE OBSOLETE |
| 2 | ORA-19815 | FRA warning | v$recovery_file_dest | Estendi prima che diventi critico |
| 3 | ORA-00257 | Archiver stuck | df -h, FRA usage | Libera FRA, backup archivelog |
| 4 | ORA-19502 | Write error disco | df -h, dmesg | Libera spazio, fix permessi |
| 5 | ORA-27072 | File I/O OS | dmesg, messages | Check hardware/mount |
| 6 | ORA-15041 | ASM DG pieno | asmcmd lsdg | Aggiungi dischi |
| 7 | ORA-19566 | Troppi blocchi corrotti | v$database_block_corruption | SET MAXCORRUPT o RECOVER ... BLOCK |
| 8 | ORA-01578 | Block corruption | v$database_block_corruption | RECOVER ... BLOCK |
| 9 | ORA-19511 | Media manager error | sbtio.log | Check MML vendor |
| 10 | ORA-27211 | SBT library fail | ls -la libobk | Fix path/permessi SBT |
| 11 | ORA-28365 | Wallet non aperto | v$encryption_wallet | Apri keystore |
| 12 | ORA-46658 | Keystore error | v$encryption_wallet | Check wallet path |
| 13 | ORA-27040/27041 | Permessi OS | ls -la path | chown oracle:oinstall |
| 14 | ORA-01031 | Privileges | USER, ROLE | GRANT SYSBACKUP |
| 15 | ORA-12154 | TNS not resolved | tnsping | Fix tnsnames.ora |
| 16 | ORA-12541 | Listener down | lsnrctl status | Start listener |
| 17 | ORA-03113/03135 | Connection lost | alert.log, network | Check network/timeout |
| 18 | ORA-04031 | Shared pool full | v$sgastat | Aumenta shared_pool |
| 19 | ORA-16014 | Log not archived | alert.log | Libera spazio archiver |
| 20 | RMAN-06059 | Archivelog missing | LIST EXPIRED ARCHIVELOG | CROSSCHECK+DELETE EXPIRED |
| 21 | RMAN-06054 | Recovery needs arch | LIST ARCHIVELOG | SET UNTIL prima del gap |
| 22 | RMAN-03009 | Channel failure | SHOW ALL | Fix canali/SBT |
| 23 | RMAN-10035 | Exception backup | v$rman_status | Retry, check I/O |
| 24 | RMAN-10038 | I/O error | OS logs | Check storage |
| 25 | RMAN-08120 | Piece corrotto | VALIDATE BACKUPSET | Rigenera backup |
| 26 | RMAN-06169 | Catalog lost | tnsping catdb | Fix TNS, RESYNC |
| 27 | RMAN-20242 | No matching backup | LIST BACKUP | CATALOG START WITH |
| 28 | RMAN-06004 | Recovery area error | v$recovery_file_dest | Fix FRA config |
| 29 | RMAN-12016 | TDE unavailable | licensing | Password encryption |
| 30 | RMAN-00569 | Error stack banner | Leggi stack completo | Analizza bottom-up |

---

## 16. Riferimenti Ufficiali

- Oracle Database Backup and Recovery User's Guide 19c
  https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/
- Oracle RMAN Reference 19c
  https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/
- Oracle Database 23ai RMAN New Features
  https://docs.oracle.com/en/database/oracle/oracle-database/23/bradv/
- MOS: RMAN Best Practices (Doc ID 394521.1)
- MOS: ORA-19809 (Doc ID 315098.1)
- MOS: RMAN Encryption (Doc ID 2575239.1)
- MOS: RMAN Troubleshooting (Doc ID 360416.1)
- MOS: BCT Best Practices (Doc ID 1472374.1)
- MOS: Backup Performance Tuning (Doc ID 1072545.1)

---

## Appendice Legacy

Le clausole `DELETE INPUT` e `DELETE ALL INPUT` sono sintassi valide, ma non
vanno incorporate nei job predefiniti: esegui il cleanup come fase separata.
`BLOCKRECOVER` e' una sintassi storica: negli esempi 19c usa
`RECOVER DATAFILE ... BLOCK` o `RECOVER CORRUPTION LIST`.

Il Data Recovery Advisor (`LIST FAILURE`, `ADVISE FAILURE`, `REPAIR FAILURE`,
`CHANGE FAILURE`) e' deprecato in Oracle Database 19c. Mantienilo solo come
conoscenza legacy; usa runbook diagnostici espliciti.

---

**Documento confidenziale ad uso interno DBA. Ultima revisione: Maggio 2026.**
