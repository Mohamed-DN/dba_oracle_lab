# Guida Produzione: Single Instance Primary + Physical Standby Data Guard 19c Non-CDB

> Scopo: creare o migrare un database Oracle 19c non-CDB single instance e configurare uno standby fisico Data Guard su secondo nodo. La guida e' pensata per produzione: evidenze prima dei comandi, parametri dichiarati, metodi alternativi, validazione e rollback.

## Ambito

Architettura target:

```text
Primary single instance     -> Physical standby single instance
DB_NAME uguale              -> DB_NAME uguale
DB_UNIQUE_NAME diverso      -> DB_UNIQUE_NAME diverso
Redo transport              -> Standby redo log + real-time apply
Broker consigliato          -> DGMGRL come piano operativo
Architettura                -> Non-CDB
```

Esempio naming:

```text
Vecchio DB sorgente:        SOLE
Nuovo primary/migrato:      SOLE
Standby fisico:             M24
Primary host:               sole-pri01
Standby host:               m24-stby01
Listener app:               1521
Listener Data Guard:        1531
```

Nota importante:

```text
Uno standby fisico Data Guard non e' un database creato da zero con DBCA.
Deve essere una copia fisica del primary, con stesso DBID. Il metodo standard e'
RMAN DUPLICATE TARGET DATABASE FOR STANDBY, da backup o FROM ACTIVE DATABASE.
```

## Fonti Oracle ufficiali usate

- Oracle 19c Data Guard - Creating a Physical Standby Database: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/creating-oracle-data-guard-physical-standby.html
- Oracle 19c Data Guard - Creating a Standby Database with RMAN: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/creating-data-guard-standby-database-using-RMAN.html
- Oracle 19c RMAN - Duplicating Databases: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-duplicating-databases.html
- Oracle 19c Data Guard - Initialization Parameters: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-initialization-parameters-used-by-oracle-data-guard.html
- Oracle 19c Data Guard - Redo Transport Services: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-transport-services.html
- Oracle 19c HA Best Practices - Data Guard: https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/configure-and-deploy-oracle-data-guard.html
- Oracle 19c Admin Guide - Creating and Configuring a Database: https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/creating-and-configuring-an-oracle-database.html
- Oracle 19c DBCA silent mode: https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/silent-mode-of-database-configuration-assistant.html
- Oracle 19c deprecation note: non-CDB architecture is deprecated: https://docs.oracle.com/en/database/oracle/oracle-database/19/upgrd/oracle-database-changes-deprecations-desupports.html

## Decisione iniziale: cosa stai creando?

Prima di partire chiarisci il caso reale.

| Scenario | Metodo consigliato | DBID | Uso |
| --- | --- | --- | --- |
| Nuovo database primario vuoto ma simile al vecchio | DBCA createDatabase non-CDB | Nuovo | Migrazione logica, reload applicativo, Data Pump |
| Clone completo del vecchio DB come nuovo primary indipendente | RMAN DUPLICATE senza `FOR STANDBY` | Nuovo | Clone preprod o migrazione fisica indipendente |
| Standby fisico Data Guard del primary | RMAN `DUPLICATE ... FOR STANDBY` | Stesso del primary | Disaster recovery |
| Standby da backup offline | RMAN duplicate backup-based | Stesso del primary | Rete lenta, change window, backup gia disponibile |
| Copia storage snapshot | Snapshot + recover | Dipende dal metodo | Solo se supportata e validata |

Regola:

```text
DBCA Create Database va bene per creare il nuovo primary non-CDB.
DBCA Create Database non va bene per creare uno standby fisico Data Guard, perche'
genera un database indipendente con DBID diverso.
```

## Fase 0 - Raccolta evidenze dal vecchio database

Esegui sul DB sorgente e salva output in spool.

```sql
SET LINES 220 PAGES 500 TRIMSPOOL ON
COL name FORMAT A45
COL value FORMAT A120
SPOOL old_db_assessment_&&_DATE..log

SELECT name, dbid, db_unique_name, open_mode, database_role,
       log_mode, force_logging, flashback_on, protection_mode
FROM v$database;

SELECT instance_name, host_name, version, status, database_status,
       startup_time
FROM v$instance;

SELECT parameter, value
FROM nls_database_parameters
WHERE parameter IN (
  'NLS_CHARACTERSET',
  'NLS_NCHAR_CHARACTERSET',
  'NLS_LANGUAGE',
  'NLS_TERRITORY'
)
ORDER BY parameter;

SELECT comp_id, comp_name, version, status
FROM dba_registry
ORDER BY comp_id;

SELECT name, value, isspecified, isdefault, ismodified, isinstance_modifiable
FROM v$parameter
WHERE name IN (
  'db_name',
  'db_unique_name',
  'db_block_size',
  'compatible',
  'sga_target',
  'sga_max_size',
  'pga_aggregate_target',
  'memory_target',
  'processes',
  'sessions',
  'open_cursors',
  'undo_retention',
  'db_file_multiblock_read_count',
  'db_create_file_dest',
  'db_recovery_file_dest',
  'db_recovery_file_dest_size',
  'control_files',
  'local_listener',
  'listener_networks',
  'log_archive_config',
  'log_archive_dest_1',
  'log_archive_dest_2',
  'log_archive_dest_state_1',
  'log_archive_dest_state_2',
  'standby_file_management',
  'fal_server',
  'db_file_name_convert',
  'log_file_name_convert',
  'dg_broker_start'
)
ORDER BY name;

SELECT name, value
FROM v$spparameter
WHERE value IS NOT NULL
ORDER BY name, ordinal;

SELECT l.group#, l.thread#, l.sequence#, l.bytes/1024/1024 AS size_mb,
       l.members, l.status, lf.member
FROM v$log l
JOIN v$logfile lf ON lf.group# = l.group#
ORDER BY l.thread#, l.group#, lf.member;

SELECT group#, thread#, bytes/1024/1024 AS size_mb, status
FROM v$standby_log
ORDER BY thread#, group#;

SELECT file#, name, bytes/1024/1024 AS size_mb, status
FROM v$datafile
ORDER BY file#;

SELECT file#, name, bytes/1024/1024 AS size_mb, status
FROM v$tempfile
ORDER BY file#;

SELECT name, is_recovery_dest_file
FROM v$controlfile
ORDER BY name;

SELECT name,
       ROUND(space_limit/1024/1024/1024, 2) AS limit_gb,
       ROUND(space_used/1024/1024/1024, 2) AS used_gb,
       ROUND(space_reclaimable/1024/1024/1024, 2) AS reclaimable_gb
FROM v$recovery_file_dest;

SELECT dest_id, status, target, destination, error, db_unique_name
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;

SELECT supplemental_log_data_min, force_logging
FROM v$database;

SPOOL OFF
```

OS e listener:

```bash
echo $ORACLE_BASE
echo $ORACLE_HOME
echo $ORACLE_SID
srvctl status listener 2>/dev/null || true
lsnrctl status
lsnrctl services
tnsping <PRIMARY_DG_ALIAS>
tnsping <STANDBY_DG_ALIAS>
df -h
```

Se usi ASM:

```bash
asmcmd lsdg
asmcmd ls +DATA
asmcmd ls +FRA
```

## Fase 1 - Cosa puoi cambiare prima della creazione e cosa no

### Parametri/attributi da decidere prima della creazione

| Attributo | Cambiabile dopo? | Decisione |
| --- | --- | --- |
| `DB_NAME` | Non trattarlo come modificabile in produzione | Per standby deve essere uguale al primary |
| `DB_UNIQUE_NAME` | Statico, richiede restart/SPFILE | Deve essere unico per ogni database Data Guard |
| `DB_BLOCK_SIZE` | No | Deve essere scelto prima; spesso 8192 |
| Database character set | Praticamente no senza migrazione | Allineare a sorgente, es. AL32UTF8 |
| National character set | Praticamente no senza migrazione | Allineare a sorgente, es. AL16UTF16 |
| `COMPATIBLE` | Si puo alzare, downgrade difficile/non banale | Non alzare senza strategia di rollback |
| Non-CDB vs CDB | No | Qui richiesta esplicita: non-CDB |
| Componenti DBCA: JVM, Text, OLAP, Spatial | Non banale rimuovere dopo | Installare solo componenti presenti/necessari |
| Redo log size/layout | Modificabile, ma pianificarlo | Allineare a carico e Data Guard |
| Storage ASM/file system/OMF | Modificabile con migrazione file | Decidere naming e path prima |

Nota Oracle: `DB_BLOCK_SIZE` va impostato alla creazione e non va alterato dopo; Oracle 19c mantiene non-CDB ma lo dichiara architettura deprecata. Se il cliente richiede non-CDB per vincoli applicativi, documenta la decisione.

### Parametri statici o quasi statici

Questi possono richiedere restart o hanno impatto strutturale:

```text
db_name
db_unique_name
db_block_size
compatible
processes
sga_max_size
control_files
cluster_database
db_file_name_convert
log_file_name_convert
```

### Parametri modificabili con cautela

```text
sga_target
pga_aggregate_target
memory_target
undo_retention
open_cursors
db_recovery_file_dest_size
log_archive_dest_state_n
standby_file_management
dg_broker_start
```

Regola produzione:

```text
I parametri non si copiano tutti dal vecchio DB. Si classificano: identita,
compatibilita, storage, Data Guard, memoria/processi, optimizer, sicurezza.
Poi si decide cosa replicare e cosa adattare al nuovo host.
```

## Fase 2 - Piu database sullo stesso nodo

Puoi avere piu database Oracle sullo stesso server usando lo stesso `ORACLE_HOME` o Oracle Home diverse. La scelta migliore dipende da patching e isolamento.

### Stessa Oracle Home

Pro:

- meno spazio software;
- patching piu semplice se tutti i DB devono avere stesso livello;
- standard operativo unico.

Contro:

- patching impatta tutti i DB della home;
- devi governare bene variabili ambiente, servizi e listener.

Requisiti:

```text
ORACLE_SID diverso per ogni istanza
DB_UNIQUE_NAME diverso per ogni database
servizi applicativi distinti
directory diag separate
spfile/password file distinti
control file/datafile/redo/FRA separati o OMF sotto DB_UNIQUE_NAME
```

Esempio file system:

```text
/u01/app/oracle/product/19.0.0/dbhome_1
/u02/oradata/SOLE
/u03/fra/SOLE
/u02/oradata/M24
/u03/fra/M24
```

Esempio ASM/OMF:

```text
+DATA/SOLE/DATAFILE
+FRA/SOLE/ARCHIVELOG
+DATA/M24/DATAFILE
+FRA/M24/ARCHIVELOG
```

Ambiente:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=SOLE
export PATH=$ORACLE_HOME/bin:$PATH
```

### Oracle Home diverse

Usale se:

- database con patch level diversi;
- test upgrade separati;
- applicazioni con certificazioni diverse;
- rollback patch piu isolato.

Regola:

```text
Mai mischiare Grid Home e DB Home. DBCA, sqlplus database, rman database e dgmgrl
devono usare la DB Home corretta. L'errore DBT-10002 tipicamente indica che si
sta tentando di usare DBCA dalla Grid Infrastructure home.
```

### Primary e standby sullo stesso host

Solo per lab, test o ambienti temporanei. In produzione non e' DR reale: perdi host, storage locale o OS e perdi entrambi.

Se lo fai comunque:

```text
ORACLE_SID diverso
DB_UNIQUE_NAME diverso
INSTANCE_NAME diverso
password file diverso
servizi listener distinti
control file/datafile/redo/FRA in path separati
non usare NOFILENAMECHECK senza convert espliciti
```

Esempio path:

```text
/u02/oradata/SOLE_PRI
/u03/fra/SOLE_PRI
/u02/oradata/M24
/u03/fra/M24
```

In ASM:

```text
+DATA/SOLE_PRI
+FRA/SOLE_PRI
+DATA/M24
+FRA/M24
```

## Fase 3 - Creazione del nuovo primary non-CDB

Se devi creare un nuovo primary indipendente ma simile al vecchio, usa DBCA. Esempio silent con ASM:

```bash
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=SOLE
export PATH=$ORACLE_HOME/bin:$PATH

dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -gdbName SOLE \
  -sid SOLE \
  -createAsContainerDatabase false \
  -storageType ASM \
  -diskGroupName +SOLE_DATA \
  -recoveryAreaDestination +SOLE_FRA \
  -recoveryAreaSize 20480 \
  -characterSet AL32UTF8 \
  -nationalCharacterSet AL16UTF16 \
  -emConfiguration NONE \
  -sampleSchema false \
  -databaseType MULTIPURPOSE \
  -initParams \
    db_unique_name=SOLE,\
    db_block_size=8192,\
    sga_target=4096M,\
    pga_aggregate_target=1024M,\
    processes=2048,\
    undo_retention=86400,\
    db_file_multiblock_read_count=72,\
    dg_broker_start=TRUE
```

Se usi GUI DBCA:

```text
Create as Container Database: disattivato
Storage: ASM o file system, coerente con standard
FRA: attiva e dimensionata
Archive mode: attivo se deve entrare in Data Guard
Listener: usa listener esistenti, non crearne nuovi senza standard
Options: installa solo componenti presenti/necessari
Management: EM Express off se non usato
All Initialization Parameters: includi in SPFILE i parametri decisi
Redo: gruppi e membri multiplexati, dimensione coerente con sorgente/carico
```

Validazione post-DBCA:

```sql
SELECT name, dbid, db_unique_name, open_mode, log_mode, force_logging, flashback_on
FROM v$database;

SELECT comp_id, comp_name, status
FROM dba_registry
ORDER BY comp_id;

SELECT name, value
FROM v$parameter
WHERE name IN ('db_name','db_unique_name','db_block_size','processes',
               'sga_target','pga_aggregate_target','dg_broker_start')
ORDER BY name;
```

## Fase 4 - Preparazione Data Guard sul primary

Abilita prerequisiti.

```sql
ALTER DATABASE FORCE LOGGING;
```

Supplemental logging non e' un prerequisito generale per physical standby Data Guard. Abilitalo solo se richiesto da GoldenGate, replica logica, audit applicativo o standard aziendale:

```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
```

Se non e' in ARCHIVELOG:

```sql
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
```

Flashback consigliato per reinstate rapido dopo failover:

```sql
ALTER DATABASE FLASHBACK ON;
```

Controlli:

```sql
SELECT name, log_mode, force_logging, flashback_on, supplemental_log_data_min
FROM v$database;
```

### Standby redo log

Regola Oracle:

```text
Per ogni redo thread, standby redo log groups >= online redo log groups + 1.
La dimensione deve essere uguale agli online redo log.
Creali sia sul primary sia sullo standby per supportare role transition.
```

Esempio single instance con 3 online redo group da 200M:

```sql
SELECT group#, thread#, bytes/1024/1024 AS size_mb, members
FROM v$log
ORDER BY group#;

ALTER DATABASE ADD STANDBY LOGFILE THREAD 1
  GROUP 11 ('+SOLE_DATA') SIZE 200M,
  GROUP 12 ('+SOLE_DATA') SIZE 200M,
  GROUP 13 ('+SOLE_DATA') SIZE 200M,
  GROUP 14 ('+SOLE_DATA') SIZE 200M;

SELECT group#, thread#, bytes/1024/1024 AS size_mb, status
FROM v$standby_log
ORDER BY group#;
```

### Parametri Data Guard sul primary

Con broker, puoi tenere minima la configurazione manuale, ma questi parametri devono essere coerenti:

```sql
ALTER SYSTEM SET log_archive_config='DG_CONFIG=(SOLE,M24)' SCOPE=BOTH;

ALTER SYSTEM SET log_archive_dest_1=
  'LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=SOLE'
  SCOPE=BOTH;

ALTER SYSTEM SET log_archive_dest_2=
  'SERVICE=M24_DG ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=M24'
  SCOPE=BOTH;

ALTER SYSTEM SET standby_file_management=AUTO SCOPE=BOTH;
ALTER SYSTEM SET fal_server='M24_DG' SCOPE=BOTH;
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH;
```

Se lasci configurare il broker, evita doppie configurazioni incoerenti: verifica sempre `SHOW DATABASE VERBOSE`.

## Fase 5 - Rete, listener e password file

### TNS alias

Su entrambi gli host, in `$ORACLE_HOME/network/admin/tnsnames.ora`:

```text
SOLE_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = sole-pri01)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = SOLE_DG)
    )
  )

M24_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = m24-stby01)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = M24_DG)
    )
  )
```

Test incrociato:

```bash
tnsping SOLE_DG
tnsping M24_DG
sqlplus sys@SOLE_DG as sysdba
sqlplus sys@M24_DG as sysdba
```

### Static registration per auxiliary NOMOUNT

Durante RMAN duplicate, lo standby e' `NOMOUNT`; serve un listener che sappia raggiungerlo.

`listener.ora` standby, esempio:

```text
SID_LIST_LISTENER_DG =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = M24_DG)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = M24)
    )
  )
```

Reload:

```bash
lsnrctl reload LISTENER_DG
lsnrctl services LISTENER_DG
```

### Password file

Sul primary:

```bash
ls -l $ORACLE_HOME/dbs/orapw$ORACLE_SID
```

Copia verso standby e rinomina coerentemente col SID auxiliary:

```bash
scp $ORACLE_HOME/dbs/orapwSOLE oracle@m24-stby01:$ORACLE_HOME/dbs/orapwM24
```

Per active duplicate, RMAN richiede connettivita SYS verso target e auxiliary; prepara quindi un password file temporaneo/coerente sull'auxiliary. Durante active duplicate RMAN puo sovrascriverlo con la copia del target. Per backup-based duplicate, la copia del password file primary resta necessaria per il redo transport. Oracle 12.2+ propaga poi le modifiche password file dal primary agli standby tramite redo.

## Fase 6 - Preparare istanza standby NOMOUNT

Sul nodo standby:

```bash
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=M24
export PATH=$ORACLE_HOME/bin:$PATH
mkdir -p $ORACLE_BASE/admin/M24/adump
```

PFILE minimo `/tmp/initM24.ora`:

```text
db_name='SOLE'
db_unique_name='M24'
memory_target=0
sga_target=4096M
pga_aggregate_target=1024M
processes=2048
audit_file_dest='/u01/app/oracle/admin/M24/adump'
remote_login_passwordfile='EXCLUSIVE'
db_create_file_dest='+M24_DATA'
db_recovery_file_dest='+M24_FRA'
db_recovery_file_dest_size=20480M
standby_file_management='AUTO'
fal_server='SOLE_DG'
dg_broker_start=TRUE
```

Start:

```sql
sqlplus / as sysdba
STARTUP NOMOUNT PFILE='/tmp/initM24.ora';
CREATE SPFILE FROM PFILE='/tmp/initM24.ora';
SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT;
```

## Fase 7 - Creare standby con RMAN active duplicate

Dal primary o da un host con rete verso entrambi:

```bash
rman TARGET sys@SOLE_DG AUXILIARY sys@M24_DG
```

Metodo OMF/ASM con diskgroup standby dedicati:

```sql
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  ALLOCATE AUXILIARY CHANNEL a1 DEVICE TYPE DISK;

  DUPLICATE TARGET DATABASE
    FOR STANDBY
    FROM ACTIVE DATABASE
    DORECOVER
    SPFILE
      PARAMETER_VALUE_CONVERT 'SOLE','M24'
      SET DB_UNIQUE_NAME='M24'
      SET DB_CREATE_FILE_DEST='+M24_DATA'
      SET DB_RECOVERY_FILE_DEST='+M24_FRA'
      SET DB_RECOVERY_FILE_DEST_SIZE='20480M'
      SET FAL_SERVER='SOLE_DG'
      SET STANDBY_FILE_MANAGEMENT='AUTO'
      SET DG_BROKER_START='TRUE'
    NOFILENAMECHECK;
}
```

Attenzione:

```text
NOFILENAMECHECK e' accettabile solo se primary e standby sono su host separati
o se i path ASM/OMF sono certamente distinti. Se cloni sullo stesso host, usa
DB_FILE_NAME_CONVERT/LOG_FILE_NAME_CONVERT o OMF con DB_UNIQUE_NAME separato.
```

Metodo con path diversi:

```sql
DUPLICATE TARGET DATABASE
  FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
    SET DB_UNIQUE_NAME='M24'
    SET DB_FILE_NAME_CONVERT='+DATA/SOLE/','+DATA/M24/'
    SET LOG_FILE_NAME_CONVERT='+FRA/SOLE/','+FRA/M24/'
    SET FAL_SERVER='SOLE_DG'
    SET STANDBY_FILE_MANAGEMENT='AUTO';
```

## Fase 8 - Avviare apply e validare

Sul standby:

```sql
SELECT name, open_mode, database_role, db_unique_name
FROM v$database;

ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;
```

Controlli:

```sql
SELECT process, status, thread#, sequence#, block#
FROM v$managed_standby
WHERE process IN ('MRP0','RFS','ARCH')
ORDER BY process;

SELECT name, value, datum_time, time_computed
FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag','apply finish time');

SELECT * FROM v$archive_gap;
```

Forza switch log dal primary:

```sql
ALTER SYSTEM ARCHIVE LOG CURRENT;
```

Verifica ricezione/apply sullo standby:

```sql
SELECT thread#, MAX(sequence#) AS last_applied
FROM v$archived_log
WHERE applied='YES'
GROUP BY thread#;
```

## Fase 9 - Configurare Data Guard Broker

Su entrambi:

```sql
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH;
```

Da primary:

```bash
dgmgrl sys@SOLE_DG
```

```text
CREATE CONFIGURATION 'DG_SOLE' AS
  PRIMARY DATABASE IS 'SOLE'
  CONNECT IDENTIFIER IS SOLE_DG;

ADD DATABASE 'M24' AS
  CONNECT IDENTIFIER IS M24_DG
  MAINTAINED AS PHYSICAL;

ENABLE CONFIGURATION;

SHOW CONFIGURATION;
SHOW DATABASE 'SOLE';
SHOW DATABASE 'M24';
VALIDATE DATABASE 'M24';
```

Se i nomi broker non coincidono con `DB_UNIQUE_NAME`, correggi prima: in Data Guard moderno conviene usare `DB_UNIQUE_NAME` come nome database nel broker.

## Fase 10 - Metodi alternativi

### Backup-based duplicate

Usalo se:

- rete insufficiente;
- backup gia su storage condiviso;
- finestra di rete limitata;
- vuoi controllare il carico sul primary.

Passi:

```sql
RMAN> BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG TAG 'STBY_SEED';
RMAN> BACKUP CURRENT CONTROLFILE FOR STANDBY TAG 'STBY_CTL';
```

Copia backup sullo standby, cataloga:

```sql
RMAN> CATALOG START WITH '/backup/stby_seed/';
RMAN> DUPLICATE TARGET DATABASE FOR STANDBY BACKUP LOCATION '/backup/stby_seed/' DORECOVER;
```

### Manuale con standby controlfile

Usalo solo se RMAN duplicate non e' possibile:

```sql
ALTER DATABASE CREATE STANDBY CONTROLFILE AS '/tmp/stby.ctl';
```

Poi copia datafile/archivelog, monta standby, recover managed. E' piu verboso e piu esposto a errore operativo.

### DBCA standby

Oracle documenta anche opzioni DBCA per standby in alcune release/scenari. In produzione preferisci RMAN duplicate quando vuoi controllo trasparente di DBID, password file, path, parametri e log dell'operazione.

## Fase 11 - Switchover test

Prima:

```text
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE 'SOLE';
DGMGRL> VALIDATE DATABASE 'M24';
```

Switchover:

```text
DGMGRL> SWITCHOVER TO 'M24';
DGMGRL> SHOW CONFIGURATION;
```

Switchback:

```text
DGMGRL> SWITCHOVER TO 'SOLE';
DGMGRL> SHOW CONFIGURATION;
```

Non fare switchover in produzione senza change, backup recente, smoke test applicativo, rollback plan e finestra approvata.

## Fase 12 - Hardening operativo post-creazione

Questa fase e' spesso piu importante del duplicate: Data Guard puo essere tecnicamente attivo ma operativamente fragile se non governi backup, FRA, servizi, monitoring e reinstate.

### RMAN retention e archivelog deletion policy

Sul primary, dopo aver confermato che lo standby applica correttamente:

```sql
rman target /

CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
SHOW ALL;
```

Se lo standard richiede anche backup archivelog prima della cancellazione:

```sql
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY BACKED UP 1 TIMES TO DISK;
```

Regola:

```text
Non liberare FRA cancellando archivelog se non sai se sono stati applicati allo
standby e se servono a RMAN, GoldenGate o audit. Prima verifica, poi cancelli.
```

### Flashback per failover/reinstate

Consigliato su primary e standby:

```sql
ALTER SYSTEM SET db_flashback_retention_target=1440 SCOPE=BOTH;
ALTER DATABASE FLASHBACK ON;

SELECT name, flashback_on
FROM v$database;
```

Prima di change importanti:

```sql
CREATE RESTORE POINT rp_before_dg_change GUARANTEE FLASHBACK DATABASE;

SELECT name, time, guarantee_flashback_database, storage_size
FROM v$restore_point
ORDER BY time DESC;
```

Dopo validazione:

```sql
DROP RESTORE POINT rp_before_dg_change;
```

### Lost write, blocchi e corruzione

Valuta con lo standard aziendale:

```sql
ALTER SYSTEM SET db_lost_write_protect=TYPICAL SCOPE=BOTH;
```

Controlli periodici:

```sql
SELECT * FROM v$database_block_corruption;

RMAN> BACKUP VALIDATE CHECK LOGICAL DATABASE;
RMAN> RESTORE DATABASE VALIDATE;
```

### Servizi applicativi role-based

Se usi Grid Infrastructure anche su single instance, registra servizi separati:

```bash
srvctl add service -d SOLE -s SOLE_RW -role PRIMARY -policy AUTOMATIC
srvctl add service -d SOLE -s SOLE_RO -role PHYSICAL_STANDBY -policy AUTOMATIC
```

Se non usi GI, mantieni almeno alias TNS separati:

```text
SOLE_APP_RW  -> servizio primary
M24_APP_RO   -> servizio standby read only, solo se Active Data Guard e licenza valida
SOLE_DG/M24_DG -> solo traffico Data Guard e amministrazione
```

### Monitoring minimo da mettere in esercizio

Soglie consigliate da adattare:

| Controllo | Warning | Critical |
| --- | --- | --- |
| `transport lag` | > 60 secondi | > 5 minuti |
| `apply lag` | > 5 minuti | > 15 minuti |
| FRA used | > 80% | > 90% |
| `v$archive_dest.error` | non vuoto | immediato |
| MRP0 assente | immediato | immediato |
| ultimo backup DB | > 24h | > 48h |

Query:

```sql
SELECT name, value, datum_time, time_computed
FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag','apply finish time');

SELECT dest_id, status, error, db_unique_name
FROM v$archive_dest
WHERE target='STANDBY';

SELECT file_type, percent_space_used, percent_space_reclaimable, number_of_files
FROM v$flash_recovery_area_usage
ORDER BY percent_space_used DESC;

SELECT input_type, status, start_time, end_time, output_bytes_display
FROM v$rman_backup_job_details
WHERE start_time > SYSDATE - 2
ORDER BY start_time DESC;
```

### Checklist cutover/migrazione

Prima di un cutover applicativo:

- backup full o incremental recente validato;
- `RESTORE DATABASE VALIDATE` eseguito o restore test recente disponibile;
- Data Guard `SHOW CONFIGURATION` = `SUCCESS`;
- `VALIDATE DATABASE` senza errori bloccanti;
- log switch manuale e apply verificato;
- smoke test applicativo pronto;
- DNS/TNS/service name pronti;
- rollback plan scritto;
- restore point garantito se lo spazio FRA lo consente;
- owner applicativo e operation allineati su finestra e criteri go/no-go.

## Fase 13 - Patching in ambiente Data Guard Single Instance (Standby-First)

Il patching del software Oracle Database in una configurazione Data Guard deve seguire la metodologia **Standby-First** raccomandata da Oracle MAA per ridurre al minimo i rischi in produzione. 

Tuttavia, è fondamentale distinguere tra le patch **Database Release Update (RU)** standard e le patch **OJVM (Oracle Java Virtual Machine)**, in quanto presentano requisiti di compatibilità drasticamente diversi.

> [!IMPORTANT]
> **REGOLA D'ORO DEL PATCHING IN DATA GUARD**
> Non eseguire **MAI** il comando `datapatch` sul database Standby Fisico. Il tool `datapatch` effettua aggiornamenti e modifiche al dizionario dei dati SQL, operazione che richiede che il database sia in modalità Read/Write. Tali modifiche devono essere eseguite **esclusivamente sul database Primario attivo** e verranno replicate nativamente sul database Standby tramite il normale flusso di Redo Apply.

---

### 1. Prerequisiti Fondamentali e Gestione OPatch

Prima di applicare qualsiasi patch (sia essa una RU o OJVM), è obbligatorio aggiornare l'utility **OPatch** all'ultima versione disponibile per evitare errori di compilazione o conflitti di inventario.

1. **Download di OPatch:** Scarica l'ultima release di OPatch da My Oracle Support (MOS Note **274526.1**) adatta alla versione di rilascio del tuo DB (19c).
2. **Aggiornamento di OPatch (eseguito su entrambi i server):**
   ```bash
   # Esegui il backup della vecchia directory
   mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch_old_backup
   # Estrai il nuovo file zip di OPatch direttamente in ORACLE_HOME
   unzip -q p6880880_190000_Linux-x86-64.zip -d $ORACLE_HOME
   # Verifica della versione installata
   $ORACLE_HOME/OPatch/opatch version
   ```

---

### 2. Vincoli di Compatibilità OJVM in Data Guard

> [!WARNING]
> **OJVM E COMPATIBILITÀ CON DATA GUARD (MOS Note 1929745.1)**
> A differenza delle normali Database RU, le patch **OJVM non sono certificate come "Data Guard Standby-First Installable"**. Ciò significa che non è supportata una configurazione in cui lo standby esegue binari OJVM patchati mentre il primario esegue binari non aggiornati, in quanto potrebbero verificarsi disallineamenti di dizionario ed errori nel caricamento delle classi Java.

Per gestire il patching di OJVM all'interno di una topologia Data Guard, si possono seguire **tre opzioni operative**:

*   **Opzione A: Downtime Coordinato Standard (Consigliata per Semplicità):**
    Si arrestano sia il Primario che lo Standby, si applicano le patch binarie (RU + OJVM) a entrambe le Oracle Home contemporaneamente, quindi si avvia il primario in modalità normale e si esegue `datapatch` (le cui modifiche SQL vengono replicate via redo allo standby montato).
*   **Opzione B: Out-of-Place Patching (Consigliata per Massima Disponibilità):**
    Si creano due nuove Oracle Home a monte sia sul primario che sullo standby, installando sia la RU che la OJVM patchata. Nella finestra di manutenzione, si esegue lo switch dei database sulle nuove Home, azzerando i tempi di applicazione fisica delle patch binarie.
*   **Opzione C: Approccio Ibrido (Solo RU rolling + OJVM coordinata):**
    Si applicano prima le sole patch Database RU seguendo la normale procedura rolling Standby-First (in quanto le RU sono 100% Standby-First installabili). In una finestra coordinata successiva, si applica la parte OJVM e si esegue `datapatch`.

---

### 3. Procedura Operativa Coordinata (In-Place RU + OJVM)

Di seguito viene descritta la procedura standard per l'applicazione pulita di **Database RU + OJVM** con allineamento binario.

#### Parte A: Patching dei Binari sul server Standby (M24)
1. **Verifica dello stato iniziale:**
   Assicurarsi che la configurazione Data Guard sia in salute e che il Broker indichi `SUCCESS`:
   ```bash
   dgmgrl sys/pass@SOLE_DG "show configuration"
   ```
2. **Disattivazione temporanea del Redo Apply:**
   ```text
   DGMGRL> EDIT DATABASE 'M24' SET STATE='LOG-APPLY-OFF';
   ```
3. **Shutdown del database Standby e del Listener:**
   Sul server Standby (`m24-stby01`):
   ```sql
   sqlplus / as sysdba
   SHUTDOWN IMMEDIATE;
   ```
   Fermare il listener dedicato Data Guard:
   ```bash
   lsnrctl stop LISTENER_DG
   ```
4. **Applicazione delle patch binarie (Database RU + OJVM):**
   ```bash
   cd /path/to/patches/RU
   $ORACLE_HOME/OPatch/opatch apply -silent
   
   cd /path/to/patches/OJVM
   $ORACLE_HOME/OPatch/opatch apply -silent
   ```
5. **Avvio del database Standby e del Listener:**
   Avviare il listener e montare il database standby (in stato `MOUNT` o `READ ONLY` se in licenza ADG):
   ```bash
   lsnrctl start LISTENER_DG
   ```
   ```sql
   sqlplus / as sysdba
   STARTUP MOUNT;
   ```
   *(Nota: Il Redo Apply rimane al momento in LOG-APPLY-OFF).*

#### Parte B: Patching dei Binari sul server Primario (SOLE)
1. **Defer del Redo Transport sul Primario:**
   Evita che il primario tenti di inviare redo durante lo spegnimento:
   ```sql
   ALTER SYSTEM SET LOG_ARCHIVE_DEST_STATE_2=DEFER SCOPE=BOTH;
   ```
2. **Shutdown del database Primario e del Listener:**
   Sul server Primario (`sole-pri01`):
   ```sql
   sqlplus / as sysdba
   SHUTDOWN IMMEDIATE;
   ```
   Fermare il listener:
   ```bash
   lsnrctl stop LISTENER
   ```
3. **Applicazione delle patch binarie (Database RU + OJVM) sul Primario:**
   ```bash
   cd /path/to/patches/RU
   $ORACLE_HOME/OPatch/opatch apply -silent
   
   cd /path/to/patches/OJVM
   $ORACLE_HOME/OPatch/opatch apply -silent
   ```
4. **Avvio del database Primario e del Listener:**
   ```bash
   lsnrctl start LISTENER
   ```
   ```sql
   sqlplus / as sysdba
   STARTUP;
   ```

---

### 4. Esecuzione di Datapatch sul Primario e Validazione

Con entrambi i database aggiornati a livello binario (stesso livello di RU e OJVM), è possibile applicare le modifiche SQL a livello di dizionario.

1. **Esecuzione di Datapatch sul Primario (SOLE):**
   Eseguire il comando **esclusivamente sul database Primario**:
   ```bash
   cd $ORACLE_HOME/OPatch
   ./datapatch -verbose
   ```
2. **Ricompilazione degli Oggetti Invalidi:**
   Dopo l'applicazione delle patch SQL, ricompila eventuali oggetti di sistema o applicativi invalidati:
   ```sql
   sqlplus / as sysdba
   @?/rdbms/admin/utlrp.sql
   ```
3. **Verifica dei Log e dello Stato delle Patch SQL:**
   Interroga il dizionario sul primario per assicurarti che tutte le patch (sia RU che OJVM) siano in stato `SUCCESS`:
   ```sql
   SET LINES 200 PAGES 100
   COL version FORMAT A12
   COL status FORMAT A15
   COL description FORMAT A60
   SELECT patch_id, patch_uid, version, status, description 
   FROM dba_registry_sqlpatch
   ORDER BY action_time DESC;
   ```

---

### 5. Riattivazione del Flusso Data Guard

1. **Riattivazione del Redo Transport dal Primario:**
   ```sql
   ALTER SYSTEM SET LOG_ARCHIVE_DEST_STATE_2=ENABLE SCOPE=BOTH;
   ```
2. **Riattivazione del Redo Apply dallo Standby:**
   Dal Broker:
   ```text
   DGMGRL> EDIT DATABASE 'M24' SET STATE='APPLY-ON';
   ```
3. **Validazione finale:**
   Verifica che le modifiche al dizionario SQL siano state replicate correttamente via redo allo Standby e che la configurazione sia pulita:
   ```text
   DGMGRL> SHOW CONFIGURATION;
   DGMGRL> VALIDATE DATABASE 'M24';
   ```
   *(Nota: Il file alert.log del database standby M24 mostrerà l'applicazione ordinata delle modifiche SQL propagate dal primario).*

## Troubleshooting rapido

| Sintomo | Causa probabile | Azione |
| --- | --- | --- |
| DBCA `DBT-10002` Grid home | Ambiente punta a Grid Home | Carica profilo DB Home corretto |
| RMAN non si connette a auxiliary | Listener statico assente o password file errata | `lsnrctl services`, ricopia password file |
| Broker ORA-16664/ORA-12514 | Service DG non registrato | Static listener o local_listener |
| `WAIT_FOR_GAP` | Archivelog mancante | `v$archive_gap`, copia log o roll-forward |
| Apply lag cresce | I/O standby, SRL mancanti, rete o parallelismo | AWR/ASH standby, `v$managed_standby` |
| ORA-19504/OMF path | Diskgroup/path errato | Verifica ASM, OMF, `DB_FILE_NAME_CONVERT` |
| Redo non spedito | `LOG_ARCHIVE_DEST_2` errato | `v$archive_dest`, `error`, `tnsping` |

## Checklist produzione

Prima:

- output assessment sorgente salvato;
- backup RMAN e restore validate recenti;
- DBCA response o comando approvato;
- charset, block size, componenti e redo decisi;
- password file e TNS testati;
- FRA dimensionata;
- standby redo logs creati;
- `FORCE LOGGING` e ARCHIVELOG;
- supplemental logging solo se richiesto da standard/replica logica;
- change e rollback plan.

Dopo:

- `SHOW CONFIGURATION` = SUCCESS;
- `VALIDATE DATABASE` senza errori bloccanti;
- `transport lag` e `apply lag` coerenti;
- switchover test pianificato o almeno readiness validata;
- documentazione parametri finali;
- script di start/stop e monitoraggio aggiornati.
