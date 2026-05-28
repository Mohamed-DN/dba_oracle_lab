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
DB_NAME:                 SOLE
Primary DB_UNIQUE_NAME:  SOLE
Standby DB_UNIQUE_NAME:  M24
Primary instances:       SOLE1, SOLE2
Standby instances:       M241, M242
Primary SCAN:            sole-pri-scan
Standby SCAN:            m24-stby-scan
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
DB SOLE:
  node1 ORACLE_SID=SOLE1 thread=1 instance_number=1
  node2 ORACLE_SID=SOLE2 thread=2 instance_number=2

DB M24:
  node1 ORACLE_SID=M241 thread=1 instance_number=1
  node2 ORACLE_SID=M242 thread=2 instance_number=2
```

ASM con OMF:

```text
+DATA/SOLE/DATAFILE
+FRA/SOLE/ARCHIVELOG
+DATA/M24/DATAFILE
+FRA/M24/ARCHIVELOG
```

Non usare la stessa directory file system per due database se non c'e' un naming chiaramente separato. In ASM preferisci OMF e `DB_UNIQUE_NAME` distinto.

## Fase 3 - Creare un nuovo primary RAC non-CDB con DBCA

Esempio silent, 2 nodi, ASM:

```bash
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -gdbName SOLE \
  -sid SOLE \
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
    db_unique_name=SOLE,\
    db_block_size=8192,\
    sga_target=8192M,\
    pga_aggregate_target=2048M,\
    processes=2048,\
    undo_retention=86400,\
    dg_broker_start=TRUE
```

Validazione:

```bash
srvctl status database -d SOLE -v
srvctl config database -d SOLE
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
srvctl stop database -d SOLE
sqlplus / as sysdba
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
srvctl start database -d SOLE
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
SOLE_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = sole-pri-scan)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = SOLE_DG)
    )
  )

M24_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = m24-stby-scan)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = M24_DG)
    )
  )
```

Test:

```bash
tnsping SOLE_DG
tnsping M24_DG
sqlplus sys@SOLE_DG as sysdba
sqlplus sys@M24_DG as sysdba
```

### Servizi RAC role-based

Dopo la configurazione, crea servizi applicativi governati dal ruolo:

```bash
srvctl add service -d SOLE -s SOLE_APP_RW \
  -preferred SOLE1,SOLE2 \
  -role PRIMARY \
  -policy AUTOMATIC

srvctl add service -d SOLE -s SOLE_APP_RO \
  -preferred SOLE1,SOLE2 \
  -role PHYSICAL_STANDBY \
  -policy AUTOMATIC
```

Adatta sintassi alle opzioni disponibili nella tua release/OS (`srvctl add service -help`).

## Fase 6 - Password file e prerequisiti standby RAC

In RAC il password file puo trovarsi in ASM o in filesystem, a seconda dello standard.

Controlla primary:

```bash
srvctl config database -d SOLE | grep -i "Password"
srvctl config database -d SOLE
```

Se file system, prepara almeno un password file temporaneo/coerente sull'auxiliary per consentire la connessione SYS via Oracle Net:

```bash
scp $ORACLE_HOME/dbs/orapwSOLE1 oracle@racstby1:$ORACLE_HOME/dbs/orapwM241
scp $ORACLE_HOME/dbs/orapwSOLE1 oracle@racstby2:$ORACLE_HOME/dbs/orapwM242
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
export ORACLE_SID=M241
export PATH=$ORACLE_HOME/bin:$PATH
mkdir -p $ORACLE_BASE/admin/M24/adump
```

PFILE `/tmp/initM241.ora`:

```text
db_name='SOLE'
db_unique_name='M24'
cluster_database=FALSE
instance_name='M241'
instance_number=1
thread=1
remote_login_passwordfile='EXCLUSIVE'
audit_file_dest='/u01/app/oracle/admin/M24/adump'
sga_target=8192M
pga_aggregate_target=2048M
processes=2048
db_create_file_dest='+DATA_STBY'
db_recovery_file_dest='+FRA_STBY'
db_recovery_file_dest_size=102400M
standby_file_management='AUTO'
fal_server='SOLE_DG'
dg_broker_start=TRUE
```

Start:

```sql
sqlplus / as sysdba
STARTUP NOMOUNT PFILE='/tmp/initM241.ora';
CREATE SPFILE='+DATA_STBY/M24/PARAMETERFILE/spfileM24.ora'
  FROM PFILE='/tmp/initM241.ora';
SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT SPFILE='+DATA_STBY/M24/PARAMETERFILE/spfileM24.ora';
```

RMAN:

```bash
rman TARGET sys@SOLE_DG AUXILIARY sys@M24_DG
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
      PARAMETER_VALUE_CONVERT 'SOLE','M24'
      SET DB_UNIQUE_NAME='M24'
      SET CLUSTER_DATABASE='FALSE'
      SET DB_CREATE_FILE_DEST='+DATA_STBY'
      SET DB_RECOVERY_FILE_DEST='+FRA_STBY'
      SET DB_RECOVERY_FILE_DEST_SIZE='102400M'
      SET FAL_SERVER='SOLE_DG'
      SET STANDBY_FILE_MANAGEMENT='AUTO'
      SET DG_BROKER_START='TRUE'
    NOFILENAMECHECK;
}
```

Se primary e standby usano diskgroup o path diversi e non OMF, usa:

```sql
SET DB_FILE_NAME_CONVERT='+DATA_PRI/SOLE/','+DATA_STBY/M24/'
SET LOG_FILE_NAME_CONVERT='+FRA_PRI/SOLE/','+FRA_STBY/M24/'
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
ALTER SYSTEM SET instance_number=1 SID='M241' SCOPE=SPFILE;
ALTER SYSTEM SET thread=1 SID='M241' SCOPE=SPFILE;
ALTER SYSTEM SET undo_tablespace='UNDOTBS1' SID='M241' SCOPE=SPFILE;

ALTER SYSTEM SET instance_number=2 SID='M242' SCOPE=SPFILE;
ALTER SYSTEM SET thread=2 SID='M242' SCOPE=SPFILE;
ALTER SYSTEM SET undo_tablespace='UNDOTBS2' SID='M242' SCOPE=SPFILE;

SHUTDOWN IMMEDIATE;
```

Registra nel cluster standby:

```bash
srvctl add database -d M24 \
  -oraclehome /u01/app/oracle/product/19.0.0/dbhome_1 \
  -spfile +DATA_STBY/M24/PARAMETERFILE/spfileM24.ora \
  -role PHYSICAL_STANDBY \
  -startoption MOUNT \
  -stopoption IMMEDIATE \
  -dbname SOLE

srvctl add instance -d M24 -i M241 -n racstby1
srvctl add instance -d M24 -i M242 -n racstby2

srvctl start database -d M24 -o mount
srvctl status database -d M24 -v
```

Se usi password file in ASM:

```bash
srvctl modify database -d M24 -pwfile +DATA_STBY/M24/PASSWORD/pwdM24
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
VALIDATE DATABASE 'SOLE';
VALIDATE DATABASE 'M24';
```

Controlla proprieta utili:

```text
SHOW DATABASE VERBOSE 'SOLE';
SHOW DATABASE VERBOSE 'M24';
```

Se necessario:

```text
EDIT DATABASE 'SOLE' SET PROPERTY LogXptMode='ASYNC';
EDIT DATABASE 'M24' SET PROPERTY LogXptMode='ASYNC';
```

Per zero data loss si valuta `SYNC/AFFIRM` solo con rete e latenza compatibili.

## Fase 11 - Avviare apply e monitoraggio

Se non usi broker:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;
```

Con broker, l'apply viene governato dal broker:

```text
DGMGRL> EDIT DATABASE 'M24' SET STATE='APPLY-ON';
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
db_name='SOLE'
db_unique_name='M24'
cluster_database=FALSE
instance_name='M24'
remote_login_passwordfile='EXCLUSIVE'
db_create_file_dest='+DATA_STBY'
db_recovery_file_dest='+FRA_STBY'
standby_file_management='AUTO'
fal_server='SOLE_DG'
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
```

Failover:

```text
DGMGRL> FAILOVER TO 'M24';
```

Dopo failover, valuta reinstate del vecchio primary:

```text
DGMGRL> REINSTATE DATABASE 'SOLE';
```

Prerequisito pratico per reinstate veloce: Flashback Database attivo e FRA sufficiente.

## Fase 15 - Hardening operativo post-creazione RAC

Questa fase chiude la configurazione per produzione. In RAC non basta che il broker dica `SUCCESS`: devi verificare backup, FRA, servizi role-based, thread redo, reinstate e monitoraggio per ogni istanza.

### RMAN retention e archivelog deletion policy

Sul primary:

```sql
rman target /

CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
SHOW ALL;
```

Se lo standard richiede backup prima della cancellazione:

```sql
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY BACKED UP 1 TIMES TO DISK;
```

Regola:

```text
In RAC + Data Guard la cancellazione archivelog deve considerare tutti i thread.
Non cancellare per liberare FRA senza verificare apply, backup e possibili consumer
come GoldenGate.
```

### Flashback e reinstate

Consigliato su primary e standby:

```sql
ALTER SYSTEM SET db_flashback_retention_target=1440 SCOPE=BOTH SID='*';
ALTER DATABASE FLASHBACK ON;

SELECT name, flashback_on
FROM v$database;
```

Prima di patch, switchover o cambio parametri critico:

```sql
CREATE RESTORE POINT rp_before_rac_dg_change GUARANTEE FLASHBACK DATABASE;
```

Dopo validazione:

```sql
DROP RESTORE POINT rp_before_rac_dg_change;
```

### Lost write, corruzione e validate

Valuta con lo standard aziendale:

```sql
ALTER SYSTEM SET db_lost_write_protect=TYPICAL SCOPE=BOTH SID='*';
```

Controlli periodici:

```sql
SELECT * FROM v$database_block_corruption;

RMAN> BACKUP VALIDATE CHECK LOGICAL DATABASE;
RMAN> RESTORE DATABASE VALIDATE;
```

### Servizi role-based dopo switchover

I servizi applicativi devono seguire il ruolo:

```bash
srvctl config service -d SOLE
srvctl status service -d SOLE
srvctl config service -d M24
srvctl status service -d M24
```

Esempio concettuale:

```bash
srvctl add service -d SOLE -s SOLE_RW \
  -preferred SOLE1,SOLE2 \
  -role PRIMARY \
  -policy AUTOMATIC

srvctl add service -d M24 -s M24_RO \
  -preferred M241,M242 \
  -role PHYSICAL_STANDBY \
  -policy AUTOMATIC
```

Adatta sempre alle opzioni della tua release (`srvctl add service -help`). Non esporre servizi read only sullo standby se non hai licenza Active Data Guard o se lo standby resta solo `MOUNTED`.

### Monitoring minimo per RAC Data Guard

Soglie consigliate da adattare:

| Controllo | Warning | Critical |
| --- | --- | --- |
| `transport lag` | > 60 secondi | > 5 minuti |
| `apply lag` | > 5 minuti | > 15 minuti |
| FRA used | > 80% | > 90% |
| `v$archive_dest.error` | non vuoto | immediato |
| MRP0 assente | immediato | immediato |
| thread senza archivelog recente | > 30 minuti | > 60 minuti |
| istanza RAC offline | immediato | immediato |
| ultimo backup DB | > 24h | > 48h |

Query:

```sql
SELECT inst_id, instance_name, host_name, status, thread#
FROM gv$instance
ORDER BY inst_id;

SELECT name, value, datum_time, time_computed
FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag','apply finish time');

SELECT dest_id, status, error, db_unique_name
FROM v$archive_dest
WHERE target='STANDBY';

SELECT thread#, MAX(sequence#) AS last_applied
FROM v$archived_log
WHERE applied='YES'
GROUP BY thread#
ORDER BY thread#;

SELECT file_type, percent_space_used, percent_space_reclaimable, number_of_files
FROM v$flash_recovery_area_usage
ORDER BY percent_space_used DESC;
```

Cluster:

```bash
crsctl stat res -t
srvctl status database -d SOLE -v
srvctl status database -d M24 -v
srvctl status service -d SOLE
srvctl status service -d M24
```

### Checklist cutover/switchover produzione

Prima:

- `SHOW CONFIGURATION` = `SUCCESS`;
- `VALIDATE DATABASE 'SOLE'` e `VALIDATE DATABASE 'M24'`;
- log switch manuale su tutti i thread e apply verificato;
- servizi role-based documentati;
- backup e restore validate recenti;
- restore point garantito se FRA sufficiente;
- owner applicativo pronto per smoke test;
- DNS/TNS/service name preparati;
- piano di ritorno approvato.

Dopo:

- servizi RW attivi solo sul nuovo primary;
- servizi RO coerenti con licensing e ruolo;
- `transport lag`/`apply lag` azzerati dopo switchback o nuova direzione;
- backup job aggiornati al nuovo primary;
- monitoring aggiornato con nuovo ruolo;
- ticket/change chiuso con evidenze before/after.

### Fase 16 - Patching in ambiente RAC Data Guard (Standby-First)

Il patching in ambienti RAC con Data Guard unisce i concetti di **Rolling Patching** (a livello di singolo cluster) e **Standby-First** (a livello di disaster recovery). Questa combinazione consente di mantenere la massima disponibilità sul sito primario durante il patching del sito di DR, per poi effettuare uno switchover controllato.

Tuttavia, il patching in ambienti complessi (RAC + Data Guard) richiede una gestione rigorosa delle patch binarie e delle patch **OJVM (Oracle Java Virtual Machine)**, oltre all'aggiornamento preliminare dei tool di installazione.

> [!IMPORTANT]
> **REGOLA D'ORO DEL PATCHING IN CONFIGURAZIONI RAC + DG**
> 1. Non eseguire **MAI** `datapatch` sul database Standby Fisico (sia RAC che single instance). Il comando deve essere lanciato esclusivamente dal nuovo cluster Primario attivo dopo lo switchover.
> 2. `opatchauto` è lo strumento preferito per ambienti RAC perché patcha in un unico comando sia la Grid Home che la Database Home come utente `root`. Tuttavia, sulle configurazioni Standby Fisiche, `opatchauto` salta automaticamente l'applicazione di `datapatch` (oppure lo si può forzare con l'opzione `-binary` per impedire errori).

---

### 1. Prerequisiti Fondamentali e Aggiornamento OPatch sui Nodi RAC

Prima di procedere con `opatchauto`, è fondamentale aggiornare manualmente l'utility **OPatch** in **tutte le Oracle Home** (sia Grid Infrastructure che RDBMS Database) su **tutti i nodi** di entrambi i cluster (sito primary e standby).

1. **Download di OPatch:** Scarica l'ultima release di OPatch da My Oracle Support (Note **274526.1**) adatta al rilascio 19c.
2. **Aggiornamento di OPatch (da eseguire su ciascun nodo come utente `grid` per la GI Home e `oracle` per la DB Home):**
   ```bash
   # Come utente grid (nella GI Home)
   mv $GRID_HOME/OPatch $GRID_HOME/OPatch_old_backup
   unzip -q p6880880_190000_Linux-x86-64.zip -d $GRID_HOME
   
   # Come utente oracle (nella RDBMS Home)
   mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch_old_backup
   unzip -q p6880880_190000_Linux-x86-64.zip -d $ORACLE_HOME
   ```

---

### 2. Vincoli di Compatibilità OJVM in Ambienti RAC Data Guard

> [!WARNING]
> **OJVM NON È STANDBY-FIRST INSTALLABLE (MOS Note 1929745.1)**
> Le patch **OJVM non supportano l'interoperabilità tra versioni diverse**. Se applichi una patch OJVM al cluster Standby, non dovresti far comunicare i due siti in modalità attiva/mista prima di aver applicato la patch OJVM anche sul Primario.

Per gli ambienti RAC in produzione, sono adottabili tre strategie:

*   **Opzione A: Out-of-Place Patching Completo (Consigliata per zero downtime dei binari):**
    Si clonano e patchano a monte sia la Grid Home che la DB Home su tutti i nodi di entrambi i siti. Al momento dello switch, si esegue il boot delle istanze sulle nuove Home e si applica `datapatch` sul primario.
*   **Opzione B: Manutenzione In-Place con Redo Apply Fermo:**
    Si ferma temporaneamente l'applicazione dei log. Si esegue il rolling patch (RU + OJVM) tramite `opatchauto` sul cluster Standby. Si esegue quindi lo switchover, si patcha il vecchio primario (ora standby) e infine si lancia `datapatch` sul primario attivo.
*   **Opzione C: Applicazione Separata (RU Rolling + OJVM a database spento):**
    Si patchano in modalità rolling e Standby-First solo le RU (Database e GI). Successivamente, si ferma il database per applicare la parte OJVM in una finestra di manutenzione ridotta.

---

### 3. Procedura Operativa di Patching Rolling + Standby-First (Opzione B)

Di seguito viene illustrata la procedura dettagliata passo-passo per il patching in-place coordinato.

#### A. Preparazione e Sicurezza
1. Disabilitare il Fast-Start Failover (FSFO) dal Broker se attivo per evitare failover indesiderati durante i riavvii dei nodi:
   ```text
   DGMGRL> DISABLE FAST_START FAILOVER;
   ```
2. Verificare lo stato della configurazione:
   ```text
   DGMGRL> SHOW CONFIGURATION;
   ```

#### B. Patching del Cluster Standby (M24 - 2 nodi)
Il patching si esegue in modalità rolling (nodo per nodo).

1. **Disattivazione del Redo Apply dal Broker:**
   ```text
   DGMGRL> EDIT DATABASE 'M24' SET STATE='LOG-APPLY-OFF';
   ```
2. **Patching del Nodo 1 Standby (`racstby1`):**
   Collegarsi come utente `root` sul primo nodo standby ed eseguire `opatchauto`. Questo comando arresterà automaticamente lo stack Grid Infrastructure, le istanze ASM e l'istanza DB locale su questo nodo, applicherà le patch alla Grid Home e alla DB Home, e riavvierà tutti i servizi:
   ```bash
   # Come root su racstby1
   $GRID_HOME/OPatch/opatchauto apply /path/to/patch_dir -binary
   ```
   *(Nota: Il flag `-binary` istruisce opatchauto a non tentare l'esecuzione di datapatch sul database Standby, operazione che fallirebbe).*
3. **Patching del Nodo 2 Standby (`racstby2`):**
   Una volta che tutti i servizi sul Nodo 1 sono ripartiti e stabili, procedere sul secondo nodo standby:
   ```bash
   # Come root su racstby2
   $GRID_HOME/OPatch/opatchauto apply /path/to/patch_dir -binary
   ```
4. **Riattivazione temporanea del Redo Apply per allineamento:**
   Assicurarsi che tutte le istanze dello standby siano tornate attive in stato `MOUNT` (o `READ ONLY`) e riattivare il Redo Apply:
   ```text
   DGMGRL> EDIT DATABASE 'M24' SET STATE='APPLY-ON';
   ```
   Lasciare allineare lo standby, quindi disattivarlo nuovamente prima dello switchover se necessario per evitare comunicazioni OJVM miste prolungate.

#### C. Ruoli in Transizione (Switchover)
Promuovere il cluster standby (con i binari RU + OJVM già patchati) a nuovo Primario:
```text
DGMGRL> SWITCHOVER TO 'M24';
```
Ora il traffico applicativo è reindirizzato sul nuovo cluster primario `M24` che esegue i binari patchati.

#### D. Patching del vecchio Cluster Primario (SOLE - 2 nodi, ora Standby)
Seguire la stessa identica procedura rolling nodo per nodo su `SOLE`:

1. **Disattivazione del Redo Apply su SOLE (ora Standby):**
   ```text
   DGMGRL> EDIT DATABASE 'SOLE' SET STATE='LOG-APPLY-OFF';
   ```
2. **Patching del Nodo 1 vecchio Primario (`racpri1`):**
   ```bash
   # Come root su racpri1
   $GRID_HOME/OPatch/opatchauto apply /path/to/patch_dir -binary
   ```
3. **Patching del Nodo 2 vecchio Primario (`racpri2`):**
   ```bash
   # Come root su racpri2
   $GRID_HOME/OPatch/opatchauto apply /path/to/patch_dir -binary
   ```

---

### 4. Esecuzione di Datapatch sul nuovo Primario Attivo (M24)

Una volta che tutti i nodi di entrambi i cluster (sito primario e sito standby) eseguono le stesse patch binarie (RU + OJVM), è possibile applicare le modifiche SQL a livello di dizionario.

1. **Esecuzione di Datapatch sul Primario Attivo (M24):**
   Collegarsi a un singolo nodo del **nuovo cluster Primario** (`M24`) ed eseguire `datapatch` come utente `oracle`:
   ```bash
   cd $ORACLE_HOME/OPatch
   ./datapatch -verbose
   ```
2. **Ricompilazione degli Oggetti Invalidi:**
   Esegui la ricompilazione sul database primario:
   ```sql
   sqlplus / as sysdba
   @?/rdbms/admin/utlrp.sql
   ```
3. **Verifica dei Log delle Patch SQL:**
   Interroga la vista del dizionario per verificare lo stato di successo:
   ```sql
   SET LINES 200 PAGES 100
   COL version FORMAT A12
   COL status FORMAT A15
   COL description FORMAT A60
   SELECT patch_id, patch_uid, version, status, description 
   FROM dba_registry_sqlpatch
   ORDER BY action_time DESC;
   ```
   *(Le modifiche apportate da datapatch verranno replicate automaticamente a `SOLE` tramite Redo Apply).*

---

### 5. Finalizzazione e Ripristino

1. **Riattivazione del Redo Apply su SOLE (Standby):**
   ```text
   DGMGRL> EDIT DATABASE 'SOLE' SET STATE='APPLY-ON';
   ```
2. **Switchback (Opzionale):**
   Se richiesto dal piano operativo, ripristina la configurazione originale riassegnando i ruoli iniziali:
   ```text
   DGMGRL> SWITCHOVER TO 'SOLE';
   ```
3. **Riattivazione FSFO:**
   Se precedentemente configurato, riabilita il Fast-Start Failover:
   ```text
   DGMGRL> ENABLE FAST_START FAILOVER;
   ```
   ```

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
