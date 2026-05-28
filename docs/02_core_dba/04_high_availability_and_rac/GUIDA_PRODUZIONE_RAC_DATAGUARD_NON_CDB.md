# Guida Produzione: RAC Primary + Physical Standby Data Guard 19c Non-CDB

> Scopo: costruire o migrare un database Oracle 19c non-CDB in RAC e configurare un physical standby Data Guard. La configurazione raccomandata e' RAC primary verso RAC standby; e' inclusa anche la variante RAC primary verso standby single instance.

## Ambito

Architettura target raccomandata:

```text
Primary RAC 2 nodi        -> Physical standby RAC 2 nodi
DB_NAME uguale            -> DB_NAME uguale
DB_UNIQUE_NAME diverso    -> DB_UNIQUE_NAME diverso
Thread redo per istanza   -> SRL per ogni thread
SCAN/listener app         -> SCAN/listener app
Listener/Data Guard       -> listener o service dedicato DG
Broker                    -> DGMGRL
Architettura              -> Non-CDB
```

Variante supportata:

```text
Primary RAC 2 nodi        -> Physical standby single instance
Thread redo multipli      -> Standby riceve/applica redo di tutti i thread
Uso tipico                -> DR a costo ridotto, non HA locale sul sito standby
```

Esempio naming:

```text
DB_NAME:                 W4RAC
Primary DB_UNIQUE_NAME:  W4RAC_PRI
Standby DB_UNIQUE_NAME:  W4RAC_STBY
Primary instances:       W4RAC1, W4RAC2
Standby instances:       W4RACS1, W4RACS2
Primary SCAN:            w4rac-pri-scan
Standby SCAN:            w4rac-stby-scan
ASM DATA/FRA primary:    +DATA_PRI, +FRA_PRI
ASM DATA/FRA standby:    +DATA_STBY, +FRA_STBY
```

## Fonti Oracle ufficiali usate

- Oracle 19c RAC DBCA silent mode: https://docs.oracle.com/en/database/oracle/oracle-database/19/riwin/dbca-commands-for-noninteractive-silent-configuration-of-rac.html
- Oracle 19c Data Guard - Creating a Physical Standby Database: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/creating-oracle-data-guard-physical-standby.html
- Oracle 19c Data Guard - RMAN standby creation: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/creating-data-guard-standby-database-using-RMAN.html
- Oracle 19c RMAN DUPLICATE: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-duplicating-databases.html
- Oracle 19c Data Guard initialization parameters: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-initialization-parameters-used-by-oracle-data-guard.html
- Oracle 19c Redo Transport Services: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-transport-services.html
- Oracle 19c Data Guard best practices / standby redo logs: https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/configure-and-deploy-oracle-data-guard.html
- Oracle 19c Admin Guide - database creation and static/dynamic parameters: https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/creating-and-configuring-an-oracle-database.html

## Principi RAC + Data Guard

1. Lo standby fisico deve avere lo stesso `DB_NAME` e DBID del primary.
2. Ogni database nella configurazione deve avere `DB_UNIQUE_NAME` diverso.
3. In RAC, ogni istanza primary usa un redo thread; lo standby deve poter ricevere/applicare redo per tutti i thread.
4. Gli standby redo log devono esistere per ogni thread e devono essere almeno uno in piu degli online redo log del thread.
5. Per creare lo standby RAC si duplica normalmente da una sola istanza auxiliary `NOMOUNT`, poi si registra il database in Grid Infrastructure e si aggiungono le altre istanze.
6. Durante RMAN duplicate e' spesso piu semplice tenere `cluster_database=FALSE`; dopo la duplicazione si imposta `TRUE` e si gestisce con `srvctl`.

## Fase 0 - Raccolta evidenze dal RAC sorgente

Esegui sul primary RAC.

```sql
SET LINES 240 PAGES 500 TRIMSPOOL ON
COL name FORMAT A45
COL value FORMAT A120
SPOOL rac_old_db_assessment_&&_DATE..log

SELECT name, dbid, db_unique_name, open_mode, database_role,
       log_mode, force_logging, flashback_on, protection_mode
FROM v$database;

SELECT inst_id, instance_name, host_name, version, status,
       thread#, startup_time
FROM gv$instance
ORDER BY inst_id;

SELECT thread#, status, enabled
FROM v$thread
ORDER BY thread#;

SELECT inst_id, name, value, isspecified, isdefault, ismodified,
       isinstance_modifiable
FROM gv$parameter
WHERE name IN (
  'db_name',
  'db_unique_name',
  'instance_name',
  'instance_number',
  'thread',
  'undo_tablespace',
  'cluster_database',
  'db_block_size',
  'compatible',
  'sga_target',
  'pga_aggregate_target',
  'processes',
  'open_cursors',
  'local_listener',
  'remote_listener',
  'listener_networks',
  'db_create_file_dest',
  'db_recovery_file_dest',
  'db_recovery_file_dest_size',
  'log_archive_config',
  'log_archive_dest_1',
  'log_archive_dest_2',
  'standby_file_management',
  'fal_server',
  'dg_broker_start'
)
ORDER BY name, inst_id;

SELECT parameter, value
FROM nls_database_parameters
WHERE parameter IN ('NLS_CHARACTERSET','NLS_NCHAR_CHARACTERSET',
                    'NLS_LANGUAGE','NLS_TERRITORY')
ORDER BY parameter;

SELECT comp_id, comp_name, version, status
FROM dba_registry
ORDER BY comp_id;

SELECT l.thread#, l.group#, l.bytes/1024/1024 AS size_mb,
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

SELECT name, value
FROM v$spparameter
WHERE value IS NOT NULL
ORDER BY sid, name, ordinal;

SELECT service_id, name, network_name, creation_date
FROM dba_services
ORDER BY name;

SELECT dest_id, status, target, destination, error, db_unique_name
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;

SPOOL OFF
```

Cluster evidence:

```bash
srvctl config database -d <DB_UNIQUE_NAME>
srvctl status database -d <DB_UNIQUE_NAME> -v
srvctl config service -d <DB_UNIQUE_NAME>
srvctl status service -d <DB_UNIQUE_NAME>
srvctl status listener
srvctl status scan
srvctl status scan_listener
crsctl stat res -t
olsnodes -n
asmcmd lsdg
```

## Fase 1 - Parametri da decidere prima della creazione RAC

| Area | Parametri/oggetti | Regola |
| --- | --- | --- |
| Identita DB | `DB_NAME`, DBID | Stesso su primary e standby; non creare standby con DBCA indipendente |
| Identita sito | `DB_UNIQUE_NAME` | Unico per primary e standby |
| RAC instances | `ORACLE_SID`, `instance_name`, `instance_number`, `thread` | Unici per nodo/istanza |
| Block size | `DB_BLOCK_SIZE` | Scelto alla creazione, non cambiarlo dopo |
| Charset | DB charset/NCHAR | Allineare a sorgente se migri |
| Non-CDB | `-createAsContainerDatabase false` | Decisione strutturale |
| Redo | gruppi per thread, dimensione | Coerente per primary e standby |
| SRL | standby log per thread | almeno online groups + 1 per thread |
| Undo | undo tablespace per istanza | verificare parametri instance-specific |
| Storage | ASM/OMF o file system | preferire ASM/OMF simmetrico |
| Services | servizi app e DG | usare role e policy con `srvctl` |

Non copiare alla cieca tutti i parametri dal vecchio RAC. Classifica:

```text
Globali:     db_name, db_unique_name, compatible, db_block_size, control_files
Per istanza: instance_number, thread, undo_tablespace, local_listener
Storage:     db_create_file_dest, db_recovery_file_dest, control_files
DG:          log_archive_config, log_archive_dest_n, fal_server, broker
Risorse:     sga_target, pga_aggregate_target, processes, open_cursors
```

## Fase 2 - Piu database RAC sullo stesso cluster

E' normale avere piu database nello stesso cluster RAC, ma serve isolamento logico.

Regole:

```text
DB_UNIQUE_NAME diverso per ogni database
ORACLE_SID diverso per ogni istanza
instance_number diverso per istanza nello stesso database
thread redo dedicato per istanza
servizi applicativi distinti
SRL separati per database e thread
FRA dimensionata per ogni DB_UNIQUE_NAME
```

Esempio:

```text
DB W4RAC_PRI:
  node1 ORACLE_SID=W4RAC1 thread=1 instance_number=1
  node2 ORACLE_SID=W4RAC2 thread=2 instance_number=2

DB W4BATCH_PRI:
  node1 ORACLE_SID=W4BATCH1 thread=1 instance_number=1
  node2 ORACLE_SID=W4BATCH2 thread=2 instance_number=2
```

ASM con OMF:

```text
+DATA/W4RAC_PRI/DATAFILE
+FRA/W4RAC_PRI/ARCHIVELOG
+DATA/W4BATCH_PRI/DATAFILE
+FRA/W4BATCH_PRI/ARCHIVELOG
```

Non usare la stessa directory file system per due database se non c'e' un naming chiaramente separato. In ASM preferisci OMF e `DB_UNIQUE_NAME` distinto.

## Fase 3 - Creare un nuovo primary RAC non-CDB con DBCA

Esempio silent, 2 nodi, ASM:

```bash
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -gdbName W4RAC \
  -sid W4RAC \
  -createAsContainerDatabase false \
  -databaseConfigType RAC \
  -nodelist racpri1,racpri2 \
  -storageType ASM \
  -diskGroupName +DATA_PRI \
  -recoveryAreaDestination +FRA_PRI \
  -recoveryAreaSize 102400 \
  -characterSet AL32UTF8 \
  -nationalCharacterSet AL16UTF16 \
  -emConfiguration NONE \
  -sampleSchema false \
  -databaseType MULTIPURPOSE \
  -initParams \
    db_unique_name=W4RAC_PRI,\
    db_block_size=8192,\
    sga_target=8192M,\
    pga_aggregate_target=2048M,\
    processes=2048,\
    undo_retention=86400,\
    dg_broker_start=TRUE
```

Validazione:

```bash
srvctl status database -d W4RAC_PRI -v
srvctl config database -d W4RAC_PRI
crsctl stat res -t
```

```sql
SELECT inst_id, instance_name, host_name, status, thread#
FROM gv$instance
ORDER BY inst_id;

SELECT name, db_unique_name, log_mode, force_logging, flashback_on
FROM v$database;
```

## Fase 4 - Preparare primary RAC per Data Guard

Abilitazioni:

```sql
ALTER DATABASE FORCE LOGGING;
```

Supplemental logging non e' un prerequisito generale per physical standby Data Guard. Abilitalo solo se richiesto da GoldenGate, replica logica, audit applicativo o standard aziendale:

```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
```

Se ARCHIVELOG non e' attivo:

```bash
srvctl stop database -d W4RAC_PRI
sqlplus / as sysdba
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
srvctl start database -d W4RAC_PRI
```

Flashback:

```sql
ALTER DATABASE FLASHBACK ON;
```

Controlli:

```sql
SELECT name, log_mode, force_logging, flashback_on, supplemental_log_data_min
FROM v$database;
```

### Standby redo log per ogni thread

Verifica online redo:

```sql
SELECT thread#, group#, bytes/1024/1024 AS size_mb, members, status
FROM v$log
ORDER BY thread#, group#;
```

Se ogni thread ha 3 online redo group da 1024M, crea 4 SRL per thread:

```sql
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1
  GROUP 101 ('+DATA_PRI') SIZE 1024M,
  GROUP 102 ('+DATA_PRI') SIZE 1024M,
  GROUP 103 ('+DATA_PRI') SIZE 1024M,
  GROUP 104 ('+DATA_PRI') SIZE 1024M;

ALTER DATABASE ADD STANDBY LOGFILE THREAD 2
  GROUP 201 ('+DATA_PRI') SIZE 1024M,
  GROUP 202 ('+DATA_PRI') SIZE 1024M,
  GROUP 203 ('+DATA_PRI') SIZE 1024M,
  GROUP 204 ('+DATA_PRI') SIZE 1024M;
```

Verifica:

```sql
SELECT thread#, group#, bytes/1024/1024 AS size_mb, status
FROM v$standby_log
ORDER BY thread#, group#;
```

Questi SRL vanno creati anche sullo standby dopo la duplicazione, se RMAN non li ha creati come richiesto o se serve correggere layout.

## Fase 5 - Rete RAC e servizi Data Guard

### Alias TNS

Usa SCAN quando appropriato, ma per broker e duplicate assicurati che il servizio risolva verso istanze raggiungibili.

```text
W4RAC_PRI_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = w4rac-pri-scan)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = W4RAC_PRI_DG)
    )
  )

W4RAC_STBY_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = w4rac-stby-scan)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = W4RAC_STBY_DG)
    )
  )
```

Test:

```bash
tnsping W4RAC_PRI_DG
tnsping W4RAC_STBY_DG
sqlplus sys@W4RAC_PRI_DG as sysdba
sqlplus sys@W4RAC_STBY_DG as sysdba
```

### Servizi RAC role-based

Dopo la configurazione, crea servizi applicativi governati dal ruolo:

```bash
srvctl add service -d W4RAC_PRI -s W4RAC_APP_RW \
  -preferred W4RAC1,W4RAC2 \
  -role PRIMARY \
  -policy AUTOMATIC

srvctl add service -d W4RAC_PRI -s W4RAC_APP_RO \
  -preferred W4RAC1,W4RAC2 \
  -role PHYSICAL_STANDBY \
  -policy AUTOMATIC
```

Adatta sintassi alle opzioni disponibili nella tua release/OS (`srvctl add service -help`).

## Fase 6 - Password file e prerequisiti standby RAC

In RAC il password file puo trovarsi in ASM o in filesystem, a seconda dello standard.

Controlla primary:

```bash
srvctl config database -d W4RAC_PRI | grep -i "Password"
srvctl config database -d W4RAC_PRI
```

Se file system, prepara almeno un password file temporaneo/coerente sull'auxiliary per consentire la connessione SYS via Oracle Net:

```bash
scp $ORACLE_HOME/dbs/orapwW4RAC1 oracle@racstby1:$ORACLE_HOME/dbs/orapwW4RACS1
scp $ORACLE_HOME/dbs/orapwW4RAC1 oracle@racstby2:$ORACLE_HOME/dbs/orapwW4RACS2
```

Durante active duplicate RMAN puo sovrascrivere il password file auxiliary con quello del target. Per backup-based duplicate, la copia del password file primary resta necessaria per il redo transport.

Se ASM, usa lo standard del cliente (`asmcmd pwcopy`, `orapwd input_file=... file=+DATA/...`) e poi registra con `srvctl modify database -pwfile`.

## Fase 7 - Creare standby RAC con RMAN duplicate

Metodo operativo robusto:

```text
1. Avvia una sola istanza auxiliary sul primo nodo standby in NOMOUNT.
2. Usa cluster_database=FALSE durante duplicate.
3. Esegui RMAN DUPLICATE FOR STANDBY FROM ACTIVE DATABASE.
4. Dopo duplicate, imposta parametri RAC e cluster_database=TRUE.
5. Registra database e istanze standby in Grid Infrastructure con srvctl.
6. Avvia tutte le istanze standby in MOUNT.
7. Avvia apply tramite broker o SQL.
```

Sul primo nodo standby:

```bash
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=W4RACS1
export PATH=$ORACLE_HOME/bin:$PATH
mkdir -p $ORACLE_BASE/admin/W4RAC_STBY/adump
```

PFILE `/tmp/initW4RACS1.ora`:

```text
db_name='W4RAC'
db_unique_name='W4RAC_STBY'
cluster_database=FALSE
instance_name='W4RACS1'
instance_number=1
thread=1
remote_login_passwordfile='EXCLUSIVE'
audit_file_dest='/u01/app/oracle/admin/W4RAC_STBY/adump'
sga_target=8192M
pga_aggregate_target=2048M
processes=2048
db_create_file_dest='+DATA_STBY'
db_recovery_file_dest='+FRA_STBY'
db_recovery_file_dest_size=102400M
standby_file_management='AUTO'
fal_server='W4RAC_PRI_DG'
dg_broker_start=TRUE
```

Start:

```sql
sqlplus / as sysdba
STARTUP NOMOUNT PFILE='/tmp/initW4RACS1.ora';
CREATE SPFILE='+DATA_STBY/W4RAC_STBY/PARAMETERFILE/spfileW4RAC_STBY.ora'
  FROM PFILE='/tmp/initW4RACS1.ora';
SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT SPFILE='+DATA_STBY/W4RAC_STBY/PARAMETERFILE/spfileW4RAC_STBY.ora';
```

RMAN:

```bash
rman TARGET sys@W4RAC_PRI_DG AUXILIARY sys@W4RAC_STBY_DG
```

Duplicate:

```sql
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c2 DEVICE TYPE DISK;
  ALLOCATE AUXILIARY CHANNEL a1 DEVICE TYPE DISK;
  ALLOCATE AUXILIARY CHANNEL a2 DEVICE TYPE DISK;

  DUPLICATE TARGET DATABASE
    FOR STANDBY
    FROM ACTIVE DATABASE
    DORECOVER
    SPFILE
      PARAMETER_VALUE_CONVERT 'W4RAC_PRI','W4RAC_STBY'
      SET DB_UNIQUE_NAME='W4RAC_STBY'
      SET CLUSTER_DATABASE='FALSE'
      SET DB_CREATE_FILE_DEST='+DATA_STBY'
      SET DB_RECOVERY_FILE_DEST='+FRA_STBY'
      SET DB_RECOVERY_FILE_DEST_SIZE='102400M'
      SET FAL_SERVER='W4RAC_PRI_DG'
      SET STANDBY_FILE_MANAGEMENT='AUTO'
      SET DG_BROKER_START='TRUE'
    NOFILENAMECHECK;
}
```

Se primary e standby usano diskgroup o path diversi e non OMF, usa:

```sql
SET DB_FILE_NAME_CONVERT='+DATA_PRI/W4RAC_PRI/','+DATA_STBY/W4RAC_STBY/'
SET LOG_FILE_NAME_CONVERT='+FRA_PRI/W4RAC_PRI/','+FRA_STBY/W4RAC_STBY/'
```

Attenzione:

```text
NOFILENAMECHECK e' pericoloso se primary e standby sono sullo stesso cluster o
se i path possono collidere. In stesso cluster/lab usa convert espliciti o OMF
con DB_UNIQUE_NAME separato.
```

## Fase 8 - Convertire standby duplicato in RAC gestito da GI

Dopo duplicate, sullo standby:

```sql
sqlplus / as sysdba
SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT;

ALTER SYSTEM SET cluster_database=TRUE SCOPE=SPFILE;
ALTER SYSTEM SET instance_number=1 SID='W4RACS1' SCOPE=SPFILE;
ALTER SYSTEM SET thread=1 SID='W4RACS1' SCOPE=SPFILE;
ALTER SYSTEM SET undo_tablespace='UNDOTBS1' SID='W4RACS1' SCOPE=SPFILE;

ALTER SYSTEM SET instance_number=2 SID='W4RACS2' SCOPE=SPFILE;
ALTER SYSTEM SET thread=2 SID='W4RACS2' SCOPE=SPFILE;
ALTER SYSTEM SET undo_tablespace='UNDOTBS2' SID='W4RACS2' SCOPE=SPFILE;

SHUTDOWN IMMEDIATE;
```

Registra nel cluster standby:

```bash
srvctl add database -d W4RAC_STBY \
  -oraclehome /u01/app/oracle/product/19.0.0/dbhome_1 \
  -spfile +DATA_STBY/W4RAC_STBY/PARAMETERFILE/spfileW4RAC_STBY.ora \
  -role PHYSICAL_STANDBY \
  -startoption MOUNT \
  -stopoption IMMEDIATE \
  -dbname W4RAC

srvctl add instance -d W4RAC_STBY -i W4RACS1 -n racstby1
srvctl add instance -d W4RAC_STBY -i W4RACS2 -n racstby2

srvctl start database -d W4RAC_STBY -o mount
srvctl status database -d W4RAC_STBY -v
```

Se usi password file in ASM:

```bash
srvctl modify database -d W4RAC_STBY -pwfile +DATA_STBY/W4RAC_STBY/PASSWORD/pwdW4RAC_STBY
```

## Fase 9 - Verificare redo thread e SRL sullo standby

Sul standby:

```sql
SELECT inst_id, instance_name, status, thread#
FROM gv$instance
ORDER BY inst_id;

SELECT thread#, group#, bytes/1024/1024 AS size_mb, status
FROM v$standby_log
ORDER BY thread#, group#;

SELECT thread#, MAX(sequence#) last_archived
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;
```

Se SRL mancanti:

```sql
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1
  GROUP 101 ('+DATA_STBY') SIZE 1024M,
  GROUP 102 ('+DATA_STBY') SIZE 1024M,
  GROUP 103 ('+DATA_STBY') SIZE 1024M,
  GROUP 104 ('+DATA_STBY') SIZE 1024M;

ALTER DATABASE ADD STANDBY LOGFILE THREAD 2
  GROUP 201 ('+DATA_STBY') SIZE 1024M,
  GROUP 202 ('+DATA_STBY') SIZE 1024M,
  GROUP 203 ('+DATA_STBY') SIZE 1024M,
  GROUP 204 ('+DATA_STBY') SIZE 1024M;
```

## Fase 10 - Configurare Broker in ambiente RAC

Su primary e standby:

```sql
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';
```

Da primary:

```bash
dgmgrl sys@W4RAC_PRI_DG
```

```text
CREATE CONFIGURATION 'DG_W4RAC' AS
  PRIMARY DATABASE IS 'W4RAC_PRI'
  CONNECT IDENTIFIER IS W4RAC_PRI_DG;

ADD DATABASE 'W4RAC_STBY' AS
  CONNECT IDENTIFIER IS W4RAC_STBY_DG
  MAINTAINED AS PHYSICAL;

ENABLE CONFIGURATION;

SHOW CONFIGURATION;
SHOW DATABASE 'W4RAC_PRI';
SHOW DATABASE 'W4RAC_STBY';
VALIDATE DATABASE 'W4RAC_PRI';
VALIDATE DATABASE 'W4RAC_STBY';
```

Controlla proprieta utili:

```text
SHOW DATABASE VERBOSE 'W4RAC_PRI';
SHOW DATABASE VERBOSE 'W4RAC_STBY';
```

Se necessario:

```text
EDIT DATABASE 'W4RAC_PRI' SET PROPERTY LogXptMode='ASYNC';
EDIT DATABASE 'W4RAC_STBY' SET PROPERTY LogXptMode='ASYNC';
```

Per zero data loss si valuta `SYNC/AFFIRM` solo con rete e latenza compatibili.

## Fase 11 - Avviare apply e monitoraggio

Se non usi broker:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;
```

Con broker, l'apply viene governato dal broker:

```text
DGMGRL> EDIT DATABASE 'W4RAC_STBY' SET STATE='APPLY-ON';
```

Controlli SQL:

```sql
SELECT process, status, thread#, sequence#, block#
FROM v$managed_standby
WHERE process IN ('MRP0','RFS','ARCH')
ORDER BY process, thread#;

SELECT name, value, datum_time, time_computed
FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag','apply finish time');

SELECT * FROM v$archive_gap;
```

Forza log switch per ogni thread dal primary:

```sql
ALTER SYSTEM ARCHIVE LOG CURRENT;
```

Oppure su istanze specifiche:

```sql
ALTER SYSTEM SWITCH LOGFILE;
```

Verifica applicazione per thread:

```sql
SELECT thread#, MAX(sequence#) AS last_applied
FROM v$archived_log
WHERE applied='YES'
GROUP BY thread#
ORDER BY thread#;
```

## Fase 12 - Variante: RAC primary verso standby single instance

Quando usarla:

- DR economico;
- standby non deve offrire HA locale;
- accetti che, dopo failover, il database diventi single instance finche non viene riconvertito/ricostruito.

Differenze:

```text
Lo standby single instance deve ricevere redo di tutti i thread del RAC primary.
Deve quindi avere standby redo log per thread 1, thread 2, ecc.
L'istanza standby applica redo in MRP, ma non ha istanze multiple.
```

PFILE standby single:

```text
db_name='W4RAC'
db_unique_name='W4RAC_STBY'
cluster_database=FALSE
instance_name='W4RACSTBY'
remote_login_passwordfile='EXCLUSIVE'
db_create_file_dest='+DATA_STBY'
db_recovery_file_dest='+FRA_STBY'
standby_file_management='AUTO'
fal_server='W4RAC_PRI_DG'
dg_broker_start=TRUE
```

RMAN duplicate e broker restano simili, ma non registri piu istanze con `srvctl add instance`; registri un database single instance se GI e' presente, oppure lo gestisci fuori cluster.

## Fase 13 - Metodi alternativi

### Backup-based duplicate

Indicato se il primary non puo sostenere copia active via rete:

```sql
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG TAG 'RAC_STBY_SEED';
BACKUP CURRENT CONTROLFILE FOR STANDBY TAG 'RAC_STBY_CTL';
```

Sul sito standby:

```sql
CATALOG START WITH '/backup/rac_stby_seed/';
DUPLICATE TARGET DATABASE FOR STANDBY BACKUP LOCATION '/backup/rac_stby_seed/' DORECOVER;
```

### Storage snapshot

Possibile solo con storage enterprise e procedura validata:

```text
1. freeze/change window o snapshot consistente;
2. copia snapshot su sito standby;
3. restore standby controlfile;
4. mount standby;
5. recover managed;
6. validazione gap/apply.
```

Richiede test e runbook storage specifico.

### DBCA standby

Oracle fornisce automazioni DBCA in alcuni scenari, ma per produzione con RAC, path ASM, thread multipli e requisiti di audit, RMAN duplicate resta il metodo piu trasparente.

## Fase 14 - Switchover e failover

Readiness:

```text
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE 'W4RAC_PRI';
DGMGRL> VALIDATE DATABASE 'W4RAC_STBY';
```

Switchover:

```text
DGMGRL> SWITCHOVER TO 'W4RAC_STBY';
DGMGRL> SHOW CONFIGURATION;
```

Switchback:

```text
DGMGRL> SWITCHOVER TO 'W4RAC_PRI';
```

Failover:

```text
DGMGRL> FAILOVER TO 'W4RAC_STBY';
```

Dopo failover, valuta reinstate del vecchio primary:

```text
DGMGRL> REINSTATE DATABASE 'W4RAC_PRI';
```

Prerequisito pratico per reinstate veloce: Flashback Database attivo e FRA sufficiente.

## Troubleshooting RAC Data Guard

| Sintomo | Causa probabile | Azione |
| --- | --- | --- |
| RMAN auxiliary non raggiungibile | Static listener/SCAN/service errato | `lsnrctl services`, TNS diretto al nodo |
| Duplicate fallisce su file path | OMF/conversion errata | Correggi `DB_CREATE_FILE_DEST` o convert |
| CRS non avvia standby | database non registrato o spfile/pwfile errato | `srvctl config database`, `srvctl modify database` |
| Un thread non applica | SRL mancanti per quel thread | crea SRL thread-specific |
| Broker warning su static connect | listener non registra NOMOUNT/MOUNT | configura static connect identifier |
| Apply lag solo su RAC | I/O standby, redo burst, thread squilibrato | AWR/ASH, `v$managed_standby`, redo size |
| ORA-10458 / standby requires recovery | Apply fermo/gap | `v$archive_gap`, recover managed |
| DBT-10002 | DBCA eseguito da Grid Home | carica DB Home corretta |

## Checklist produzione

Prima:

- assessment RAC sorgente salvato;
- livelli patch primary/standby compatibili;
- Grid Infrastructure e DB Home corretti;
- SCAN/listener/TNS testati;
- password file gestito secondo standard;
- `FORCE LOGGING`, ARCHIVELOG, Flashback;
- supplemental logging solo se richiesto da standard/replica logica;
- SRL per ogni thread;
- ASM/FRA dimensionati;
- backup RMAN e restore validate recenti;
- change e rollback plan.

Dopo:

- `srvctl status database` OK su primary e standby;
- `SHOW CONFIGURATION` = SUCCESS;
- `VALIDATE DATABASE` OK;
- `transport lag` e `apply lag` coerenti;
- log switch di tutti i thread applicato;
- servizi role-based verificati;
- switchover test pianificato;
- documento parametri finali salvato.
