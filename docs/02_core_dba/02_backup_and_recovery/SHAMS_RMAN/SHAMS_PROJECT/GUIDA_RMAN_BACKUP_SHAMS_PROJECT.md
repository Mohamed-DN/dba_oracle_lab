# SHAMS Project: Setup Backup RMAN Enterprise

## Obiettivo operativo

Installare un sistema RMAN ordinato per `M24SHAMS`, con repository durevole,
recovery catalog, backup full/cumulative/differential/archivelog, log
monitorabili e cleanup separato. La logica riprende lo script aziendale passato
nei TXT: config esterna, role detection, blocco backup concorrenti e schedule
cron.

## Architettura directory

Root unica:

```text
/backup/rman/<DB_UNIQUE_NAME>/
+-- pieces/
|   +-- database/
|   +-- archivelog/
|   +-- controlfile/
|   +-- spfile/
+-- metadata/
+-- logs/
+-- reports/
+-- evidence/
```

Per SHAMS:

```text
/backup/rman/M24SHAMSPEC
/backup/rman/M24SHAMSSEC
```

La FRA ASM non e' il repository backup. `+M24SHAMS_FRA` serve per archivelog,
flashback e file gestiti da Oracle; `/backup/rman` deve essere storage durevole
e monitorato.

## Procedura operativa

Eseguire i passi da 1 a 5 nell'ordine indicato. Il wrapper deve essere installato
prima della schedule e il cleanup deve restare separato dal backup, cosi' ogni
cancellazione passa da RMAN e dalle query di controllo.

## 1. Installazione script SHAMS

Sul nodo che esegue i job RMAN:

```bash
export SCRIPT_DIR=/opt/oracle/rman_scripts
mkdir -p "$SCRIPT_DIR"/{cfg,rman,logs}
mkdir -p /backup/rman/M24SHAMSPEC /backup/rman/M24SHAMSSEC
chown -R oracle:oinstall "$SCRIPT_DIR" /backup/rman/M24SHAMSPEC /backup/rman/M24SHAMSSEC
chmod 750 "$SCRIPT_DIR" /backup/rman/M24SHAMSPEC /backup/rman/M24SHAMSSEC
```

Copiare dal repository:

```bash
cp docs/02_core_dba/02_backup_and_recovery/SHAMS_RMAN/SHAMS_PROJECT/scripts/rman_backup.sh "$SCRIPT_DIR/"
cp docs/02_core_dba/02_backup_and_recovery/SHAMS_RMAN/SHAMS_PROJECT/scripts/encrypt_pwd.sh "$SCRIPT_DIR/"
cp docs/02_core_dba/02_backup_and_recovery/SHAMS_RMAN/SHAMS_PROJECT/scripts/rman/*.rcv "$SCRIPT_DIR/rman/"
cp docs/02_core_dba/02_backup_and_recovery/SHAMS_RMAN/SHAMS_PROJECT/scripts/crontab_shams_example "$SCRIPT_DIR/"
chmod 750 "$SCRIPT_DIR/rman_backup.sh" "$SCRIPT_DIR/encrypt_pwd.sh"
chmod 640 "$SCRIPT_DIR/rman/"*.rcv
```

Creare una config per ogni `DB_UNIQUE_NAME`:

```bash
cp docs/02_core_dba/02_backup_and_recovery/SHAMS_RMAN/SHAMS_PROJECT/scripts/cfg/rman_backup_M24SHAMSSEC.conf.example \
  "$SCRIPT_DIR/cfg/rman_backup_M24SHAMSSEC.conf"
cp docs/02_core_dba/02_backup_and_recovery/SHAMS_RMAN/SHAMS_PROJECT/scripts/cfg/rman_backup_M24SHAMSPEC.conf.example \
  "$SCRIPT_DIR/cfg/rman_backup_M24SHAMSPEC.conf"
vi "$SCRIPT_DIR/cfg/rman_backup_M24SHAMSSEC.conf"
vi "$SCRIPT_DIR/cfg/rman_backup_M24SHAMSPEC.conf"
chmod 640 "$SCRIPT_DIR"/cfg/rman_backup_*.conf
```

Esempio standby:

```bash
ORACLE_HOME=<ORACLE_HOME>
ORACLE_BASE=<ORACLE_BASE>
ORACLE_SID=M24SHAMSSEC
ORACLE_UNQNAME=M24SHAMSSEC
BCKDIR=/backup/rman/M24SHAMSSEC
BCKDIR_MOUNTPOINT=/backup/rman
REQUIRE_BCKDIR_MOUNT=YES
RMAN_CATALOG_CONNECT=/@RMAN_CATALOG
RMAN_TARGET_CONNECT=/
EXEC_DATAFILE_BACKUP_WHEN=STANDBY
PARALLEL_CHANNELS=4
SECTION_SIZE=32G
ARCHIVELOG_FROM_TIME="SYSDATE - 4/24"
LOG_RETENTION_DAYS=30
IGNORE_RMAN_ERRORS="RMAN-08137"
MAIL_TO=
```

Usare wallet/SEPS per `RMAN_CATALOG_CONNECT`; non scrivere password nel file.

## 2. Configurazione RMAN iniziale

Sul primary:

```bash
rman target / catalog /@RMAN_CATALOG
```

```rman
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 30 DAYS;
CONFIGURE BACKUP OPTIMIZATION OFF;
CONFIGURE DEFAULT DEVICE TYPE TO DISK;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO
  '/backup/rman/M24SHAMSPEC/pieces/controlfile/cf_M24SHAMSPEC_%F';
CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO BACKUPSET;
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT
  '/backup/rman/M24SHAMSPEC/pieces/database/bkp_%d_%T_%U.bkp';
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
CONFIGURE DB_UNIQUE_NAME 'M24SHAMSPEC' CONNECT IDENTIFIER 'M24SHAMSPEC_DG';
CONFIGURE DB_UNIQUE_NAME 'M24SHAMSSEC' CONNECT IDENTIFIER 'M24SHAMSSEC_DG';
CONFIGURE RMAN OUTPUT TO KEEP FOR 21 DAYS;
CONFIGURE ARCHIVELOG DELETION POLICY TO
  APPLIED ON ALL STANDBY BACKED UP 1 TIMES TO DEVICE TYPE DISK;
CONFIGURE SNAPSHOT CONTROLFILE NAME TO
  '/backup/rman/M24SHAMSPEC/metadata/snapcf_M24SHAMSPEC.f';
SHOW ALL;
```

Sullo standby:

```rman
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 30 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO
  '/backup/rman/M24SHAMSSEC/pieces/controlfile/cf_M24SHAMSSEC_%F';
CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO BACKUPSET;
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT
  '/backup/rman/M24SHAMSSEC/pieces/database/bkp_%d_%T_%U.bkp';
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
CONFIGURE ARCHIVELOG DELETION POLICY TO
  BACKED UP 1 TIMES TO DEVICE TYPE DISK;
CONFIGURE SNAPSHOT CONTROLFILE NAME TO
  '/backup/rman/M24SHAMSSEC/metadata/snapcf_M24SHAMSSEC.f';
SHOW ALL;
```

In Data Guard il recovery catalog distingue i siti tramite `DB_UNIQUE_NAME`.
Registrare il primary e poi validare la visibilita' dello standby:

```rman
LIST DB_UNIQUE_NAME OF DATABASE;
RESYNC CATALOG;
```

## 3. Schedule consigliato

Esempio per backup offload sullo standby:

```cron
00 21 * * 0 /opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC full >/dev/null 2>&1
10 21 * * 3 /opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC cumulative >/dev/null 2>&1
10 21 * * 1,2,4,5 /opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC differential >/dev/null 2>&1
49 * * * * /opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC archive >/dev/null 2>&1
```

Se vuoi eseguire solo archivelog sul primary e datafile sullo standby, usa:

```bash
EXEC_DATAFILE_BACKUP_WHEN=STANDBY
```

nel file config dello standby e `EXEC_DATAFILE_BACKUP_WHEN=NEVER` nel config
del primary, mantenendo pero' il job `archive`.

Per produzione `M24SHAMSPEP/M24SHAMSSEP` puo' essere richiesta la policy
opposta, cioe' full/incremental sul primary e nessun datafile backup sullo
standby:

```bash
# cfg/rman_backup_M24SHAMSPEP.conf
EXEC_DATAFILE_BACKUP_WHEN=PRIMARY

# cfg/rman_backup_M24SHAMSSEP.conf
EXEC_DATAFILE_BACKUP_WHEN=NEVER
```

Questa scelta non e' un errore: e' una policy operativa diversa dall'offload su
standby. Documentarla nel change, mantenere backup archivelog e verificare che
`REPORT NEED BACKUP` e `RESTORE DATABASE VALIDATE` restino verdi.

## 4. Esecuzione manuale

```bash
/opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC full
/opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC cumulative
/opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC differential
/opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC archive
```

Controlli:

```bash
tail -100 /opt/oracle/rman_scripts/logs/full_M24SHAMSSEC.log
find /backup/rman/M24SHAMSSEC -maxdepth 3 -type f | sort | tail
```

In RMAN:

```rman
LIST BACKUP SUMMARY;
LIST BACKUP OF DATABASE COMPLETED AFTER 'SYSDATE-7';
LIST BACKUP OF ARCHIVELOG FROM TIME 'SYSDATE-1';
REPORT NEED BACKUP;
RESTORE DATABASE VALIDATE;
```

## 5. Cleanup separato

Il backup non deve cancellare backup piece. Il cleanup gira solo dopo questi
gate:

```sql
SELECT COUNT(*) AS level0_count
FROM v$backup_set
WHERE incremental_level = 0
  AND status = 'A'
  AND completion_time >= SYSDATE - 35;

SELECT COUNT(*) AS controlfile_count
FROM v$backup_set
WHERE controlfile_included = 'YES'
  AND status = 'A'
  AND completion_time >= SYSDATE - 35;

SELECT COUNT(*) AS spfile_count
FROM v$backup_set
WHERE spfile_included = 'YES'
  AND status = 'A'
  AND completion_time >= SYSDATE - 35;

SELECT * FROM v$archive_gap;

SELECT name, value, unit
FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag');
```

Solo se i gate sono verdi:

```bash
rman target / catalog /@RMAN_CATALOG \
  cmdfile /opt/oracle/rman_scripts/rman/rman_cleanup_gated.rcv \
  log /opt/oracle/rman_scripts/logs/cleanup_M24SHAMSSEC.log
```

Vietato:

```bash
rm /backup/rman/M24SHAMSSEC/pieces/*.bkp
find /backup/rman/M24SHAMSSEC -name '*.bkp' -delete
```

## Validazione finale

Per ogni finestra salvare:

```rman
SHOW ALL;
LIST DB_UNIQUE_NAME OF DATABASE;
LIST BACKUP SUMMARY;
REPORT OBSOLETE;
RESTORE DATABASE VALIDATE;
```

Per Data Guard:

```sql
SELECT name, db_unique_name, database_role, open_mode FROM v$database;
SELECT process, status, sequence# FROM v$managed_standby WHERE process='MRP0';
SELECT * FROM v$archive_gap;
```

La procedura e' accettata solo quando almeno un `RESTORE DATABASE VALIDATE`
finisce senza errori RMAN/ORA bloccanti.

## Troubleshooting rapido

| Sintomo | Controllo | Azione |
| --- | --- | --- |
| Job non parte | `tail -100 /opt/oracle/rman_scripts/logs/rman_*.log` | verificare config, permessi e `ORACLE_HOME` |
| Catalogo non raggiungibile | `tnsping RMAN_CATALOG` e wallet alias | correggere wallet/TNS senza mettere password in chiaro |
| Backup concorrente bloccato | status file in `logs/` e `V$RMAN_BACKUP_JOB_DETAILS` | attendere il job attivo o chiudere il lock solo dopo verifica processo |
| Cleanup non cancella nulla | `REPORT OBSOLETE` | controllare retention e presenza di level 0 valido |
| `RESTORE VALIDATE` fallisce | log RMAN completo | correggere prima canali, path o piece mancanti, poi ripetere validate |
