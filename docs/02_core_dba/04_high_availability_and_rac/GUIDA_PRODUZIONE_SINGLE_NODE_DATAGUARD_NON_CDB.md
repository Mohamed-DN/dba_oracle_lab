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
Vecchio DB sorgente:        W4HMO
Nuovo primary/migrato:      W4UCIHMOC
Standby fisico:             W4HMOSEC oppure W4UCIHMOC_STBY
Primary host:               w4dwhdbpec01
Standby host:               w4dwhdbsec01
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
/u02/oradata/W4UCIHMOC
/u03/fra/W4UCIHMOC
/u02/oradata/W4TEST
/u03/fra/W4TEST
```

Esempio ASM/OMF:

```text
+DATA/W4UCIHMOC/DATAFILE
+FRA/W4UCIHMOC/ARCHIVELOG
+DATA/W4TEST/DATAFILE
+FRA/W4TEST/ARCHIVELOG
```

Ambiente:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=W4UCIHMOC
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
/u02/oradata/W4UCIHMOC_PRI
/u03/fra/W4UCIHMOC_PRI
/u02/oradata/W4UCIHMOC_STBY
/u03/fra/W4UCIHMOC_STBY
```

In ASM:

```text
+DATA/W4UCIHMOC_PRI
+FRA/W4UCIHMOC_PRI
+DATA/W4UCIHMOC_STBY
+FRA/W4UCIHMOC_STBY
```

## Fase 3 - Creazione del nuovo primary non-CDB

Se devi creare un nuovo primary indipendente ma simile al vecchio, usa DBCA. Esempio silent con ASM:

```bash
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=W4UCIHMOC
export PATH=$ORACLE_HOME/bin:$PATH

dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -gdbName W4UCIHMOC \
  -sid W4UCIHMOC \
  -createAsContainerDatabase false \
  -storageType ASM \
  -diskGroupName +W4DMUCI_DATA \
  -recoveryAreaDestination +W4DMUCI_FRA \
  -recoveryAreaSize 20480 \
  -characterSet AL32UTF8 \
  -nationalCharacterSet AL16UTF16 \
  -emConfiguration NONE \
  -sampleSchema false \
  -databaseType MULTIPURPOSE \
  -initParams \
    db_unique_name=W4UCIHMOC,\
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
  GROUP 11 ('+W4DMUCI_DATA') SIZE 200M,
  GROUP 12 ('+W4DMUCI_DATA') SIZE 200M,
  GROUP 13 ('+W4DMUCI_DATA') SIZE 200M,
  GROUP 14 ('+W4DMUCI_DATA') SIZE 200M;

SELECT group#, thread#, bytes/1024/1024 AS size_mb, status
FROM v$standby_log
ORDER BY group#;
```

### Parametri Data Guard sul primary

Con broker, puoi tenere minima la configurazione manuale, ma questi parametri devono essere coerenti:

```sql
ALTER SYSTEM SET log_archive_config='DG_CONFIG=(W4UCIHMOC,W4UCIHMOC_STBY)' SCOPE=BOTH;

ALTER SYSTEM SET log_archive_dest_1=
  'LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=W4UCIHMOC'
  SCOPE=BOTH;

ALTER SYSTEM SET log_archive_dest_2=
  'SERVICE=W4UCIHMOC_STBY_DG ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=W4UCIHMOC_STBY'
  SCOPE=BOTH;

ALTER SYSTEM SET standby_file_management=AUTO SCOPE=BOTH;
ALTER SYSTEM SET fal_server='W4UCIHMOC_STBY_DG' SCOPE=BOTH;
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH;
```

Se lasci configurare il broker, evita doppie configurazioni incoerenti: verifica sempre `SHOW DATABASE VERBOSE`.

## Fase 5 - Rete, listener e password file

### TNS alias

Su entrambi gli host, in `$ORACLE_HOME/network/admin/tnsnames.ora`:

```text
W4UCIHMOC_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = w4dwhdbpec01)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = W4UCIHMOC_DG)
    )
  )

W4UCIHMOC_STBY_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = w4dwhdbsec01)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = W4UCIHMOC_STBY_DG)
    )
  )
```

Test incrociato:

```bash
tnsping W4UCIHMOC_DG
tnsping W4UCIHMOC_STBY_DG
sqlplus sys@W4UCIHMOC_DG as sysdba
sqlplus sys@W4UCIHMOC_STBY_DG as sysdba
```

### Static registration per auxiliary NOMOUNT

Durante RMAN duplicate, lo standby e' `NOMOUNT`; serve un listener che sappia raggiungerlo.

`listener.ora` standby, esempio:

```text
SID_LIST_LISTENER_DG =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = W4UCIHMOC_STBY_DG)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = W4UCIHMOC_STBY)
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
scp $ORACLE_HOME/dbs/orapwW4UCIHMOC oracle@w4dwhdbsec01:$ORACLE_HOME/dbs/orapwW4UCIHMOC_STBY
```

Per active duplicate, RMAN richiede connettivita SYS verso target e auxiliary; prepara quindi un password file temporaneo/coerente sull'auxiliary. Durante active duplicate RMAN puo sovrascriverlo con la copia del target. Per backup-based duplicate, la copia del password file primary resta necessaria per il redo transport. Oracle 12.2+ propaga poi le modifiche password file dal primary agli standby tramite redo.

## Fase 6 - Preparare istanza standby NOMOUNT

Sul nodo standby:

```bash
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=W4UCIHMOC_STBY
export PATH=$ORACLE_HOME/bin:$PATH
mkdir -p $ORACLE_BASE/admin/W4UCIHMOC_STBY/adump
```

PFILE minimo `/tmp/initW4UCIHMOC_STBY.ora`:

```text
db_name='W4UCIHMOC'
db_unique_name='W4UCIHMOC_STBY'
memory_target=0
sga_target=4096M
pga_aggregate_target=1024M
processes=2048
audit_file_dest='/u01/app/oracle/admin/W4UCIHMOC_STBY/adump'
remote_login_passwordfile='EXCLUSIVE'
db_create_file_dest='+W4DMUCI_DATA'
db_recovery_file_dest='+W4DMUCI_FRA'
db_recovery_file_dest_size=20480M
standby_file_management='AUTO'
fal_server='W4UCIHMOC_DG'
dg_broker_start=TRUE
```

Start:

```sql
sqlplus / as sysdba
STARTUP NOMOUNT PFILE='/tmp/initW4UCIHMOC_STBY.ora';
CREATE SPFILE FROM PFILE='/tmp/initW4UCIHMOC_STBY.ora';
SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT;
```

## Fase 7 - Creare standby con RMAN active duplicate

Dal primary o da un host con rete verso entrambi:

```bash
rman TARGET sys@W4UCIHMOC_DG AUXILIARY sys@W4UCIHMOC_STBY_DG
```

Metodo OMF/ASM simmetrico:

```sql
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  ALLOCATE AUXILIARY CHANNEL a1 DEVICE TYPE DISK;

  DUPLICATE TARGET DATABASE
    FOR STANDBY
    FROM ACTIVE DATABASE
    DORECOVER
    SPFILE
      PARAMETER_VALUE_CONVERT 'W4UCIHMOC','W4UCIHMOC_STBY'
      SET DB_UNIQUE_NAME='W4UCIHMOC_STBY'
      SET DB_CREATE_FILE_DEST='+W4DMUCI_DATA'
      SET DB_RECOVERY_FILE_DEST='+W4DMUCI_FRA'
      SET DB_RECOVERY_FILE_DEST_SIZE='20480M'
      SET FAL_SERVER='W4UCIHMOC_DG'
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
    SET DB_UNIQUE_NAME='W4UCIHMOC_STBY'
    SET DB_FILE_NAME_CONVERT='+DATA/W4UCIHMOC/','+DATA/W4UCIHMOC_STBY/'
    SET LOG_FILE_NAME_CONVERT='+FRA/W4UCIHMOC/','+FRA/W4UCIHMOC_STBY/'
    SET FAL_SERVER='W4UCIHMOC_DG'
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
dgmgrl sys@W4UCIHMOC_DG
```

```text
CREATE CONFIGURATION 'DG_W4UCIHMOC' AS
  PRIMARY DATABASE IS 'W4UCIHMOC'
  CONNECT IDENTIFIER IS W4UCIHMOC_DG;

ADD DATABASE 'W4UCIHMOC_STBY' AS
  CONNECT IDENTIFIER IS W4UCIHMOC_STBY_DG
  MAINTAINED AS PHYSICAL;

ENABLE CONFIGURATION;

SHOW CONFIGURATION;
SHOW DATABASE 'W4UCIHMOC';
SHOW DATABASE 'W4UCIHMOC_STBY';
VALIDATE DATABASE 'W4UCIHMOC_STBY';
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
DGMGRL> VALIDATE DATABASE 'W4UCIHMOC';
DGMGRL> VALIDATE DATABASE 'W4UCIHMOC_STBY';
```

Switchover:

```text
DGMGRL> SWITCHOVER TO 'W4UCIHMOC_STBY';
DGMGRL> SHOW CONFIGURATION;
```

Switchback:

```text
DGMGRL> SWITCHOVER TO 'W4UCIHMOC';
DGMGRL> SHOW CONFIGURATION;
```

Non fare switchover in produzione senza change, backup recente, smoke test applicativo, rollback plan e finestra approvata.

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
