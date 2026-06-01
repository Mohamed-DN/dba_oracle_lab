# SOP Enterprise M24SHAMS: Staging Single Instance Data Guard 19c Non-CDB

## Obiettivo operativo

Creare e portare in esercizio il database Oracle `M24SHAMS` per l'ambiente di
collaudo/staging `C`, con primary single instance nel sito PE e physical standby
nel sito SE. Entrambi i server usano Oracle Restart/HAS, ASM e Oracle Managed
Files (OMF).

La configurazione target include Data Guard Broker e backup RMAN eseguito
sullo standby con recovery catalog. Active Data Guard e il servizio `_RO` sono
opzionali e richiedono il gate licenza. Fast-Start Failover (FSFO) non fa parte
di questo change: viene attivato successivamente seguendo
[Observer FSFO PEYTECH](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md).

Questa SOP e' specifica per `M24SHAMS`. Per il modello riutilizzabile consulta
[Produzione Single Instance Data Guard Non-CDB](../GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md).

## Principi e fonti

Ordine di precedenza usato nel documento:

1. documentazione ufficiale Oracle Database 19c;
2. standard PEYTECH `PEYTECH_Database_Install_Configure_BestPractice_0.5`;
3. convenzioni operative approvate nel change;
4. esempi della chat di raccolta requisiti, usati solo come materiale di lavoro.

Fonti Oracle:

- [Creazione database con DBCA](https://docs.oracle.com/en/database/oracle/oracle-database/19/admqs/installing-oracle-database-creating-database.html)
- [Creazione standby fisico con RMAN](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/creating-data-guard-standby-database-using-RMAN.html)
- [Redo Transport Services](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-transport-services.html)
- [Protection Modes](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-protection-modes.html)
- [RMAN in configurazioni Data Guard](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/using-RMAN-in-oracle-data-guard-configurations.html)
- [TDE con Data Guard](https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/using-transparent-data-encryption-with-other-oracle-features.html)
- [Deprecazioni Oracle Database 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/upgrd/oracle-database-changes-deprecations-desupports.html)

> [!IMPORTANT]
> Oracle Database 19c supporta ancora i database non-CDB, ma l'architettura e'
> deprecata. La scelta non-CDB deve essere registrata nel change e accompagnata
> da una roadmap futura verso CDB/PDB.

## Architettura target

```text
                           Applicazione staging
                                   |
                         service M24SHAMSC_PRY
                                   |
                  +----------------+----------------+
                  |                                 |
        PE - PRIMARY                       SE - PHYSICAL STANDBY
        DB_NAME=M24SHAMS                   DB_NAME=M24SHAMS
        DB_UNIQUE_NAME=M24SHAMSPEC         DB_UNIQUE_NAME=M24SHAMSSEC
        Oracle Restart / ASM               Oracle Restart / ASM
        +M24SHAMS_DATA / +M24SHAMS_FRA     +M24SHAMS_DATA / +M24SHAMS_FRA
                  |                                 |
                  +------ SYNC gate / redo ---------+
                                                    |
                                           service M24SHAMSC_RO
                                           Active Data Guard opzionale
                                           RMAN backup offload
```

| Parametro | Valore approvato |
| --- | --- |
| Release | Oracle Database e Grid Infrastructure `19c` |
| RU | Stessa RU approvata in PE e SE, da compilare nel change |
| Architettura | Single instance non-CDB, Oracle Restart/HAS, ASM OMF |
| `DB_NAME` | `M24SHAMS` |
| Primary PE | `M24SHAMSPEC` |
| Standby SE | `M24SHAMSSEC` |
| Servizio primary | `M24SHAMSC_PRY` |
| Servizio standby ADG | `M24SHAMSC_RO` |
| ASM | `+M24SHAMS_DATA`, `+M24SHAMS_FRA` |
| Listener Data Guard | Porta `1531` |
| Broker | Obbligatorio |
| Protection mode | `MaxAvailability` dopo gate di latenza |
| FSFO | Change separato |

### Scheda sostituzioni per riuso

Questa SOP usa `M24SHAMS` come esempio leggibile. Prima di adattarla a un
altro database compila la matrice e applica le sostituzioni in modo coerente:

| Oggetto | Esempio collaudo | Valore approvato |
| --- | --- | --- |
| `DB_NAME` | `M24SHAMS` | `<DB_NAME>` |
| Ambiente | `C` | `<ENV>` |
| Primary / standby `DB_UNIQUE_NAME` | `M24SHAMSPEC` / `M24SHAMSSEC` | `<PRIMARY_UNIQUE_NAME>` / `<STANDBY_UNIQUE_NAME>` |
| Broker configuration | `DR_M24SHAMSC_CONF` | `DR_<DB_NAME><ENV>_CONF` |
| Servizi | `M24SHAMSC_PRY` / `M24SHAMSC_RO` | `<PRIMARY_SERVICE>` / `<STANDBY_RO_SERVICE>` |
| ASM | `+M24SHAMS_DATA` / `+M24SHAMS_FRA` | `<ASM_DATA>` / `<ASM_FRA>` |

## Ruoli e prerequisiti

Prima dell'esecuzione assegna un owner per ciascuna area:

| Area | Owner | Evidenza richiesta |
| --- | --- | --- |
| Change manager | `<NOME>` | Change approvato e finestra |
| DBA Oracle | `<NOME>` | Output assessment e verbale Go/No-Go |
| Sistemista Linux | `<NOME>` | Verifica host, mount, multipath e spazio |
| Storage | `<NOME>` | LUN, ridondanza e crescita FRA |
| Networking | `<NOME>` | DNS, porte e latenza PE-SE |
| Security | `<NOME>` | Gate Active Data Guard e decisione TDE |
| Backup | `<NOME>` | Recovery catalog, destinazione e restore test |

La preparazione host e software e' descritta in
[Allegato Host Oracle Restart ASM 19c](./GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md).

## Scheda inventario preflight

Non eseguire i comandi con placeholder irrisolti.

| Campo | Primary PE | Standby SE |
| --- | --- | --- |
| Hostname FQDN | `<PRIMARY_FQDN>` | `<STANDBY_FQDN>` |
| IP public | `<PRIMARY_PUBLIC_IP>` | `<STANDBY_PUBLIC_IP>` |
| IP rete Data Guard | `<PRIMARY_DG_IP>` | `<STANDBY_DG_IP>` |
| Oracle Base | `<ORACLE_BASE>` | `<ORACLE_BASE>` |
| Oracle Home 19c | `<ORACLE_HOME>` | `<ORACLE_HOME>` |
| Grid Home 19c | `<GRID_HOME>` | `<GRID_HOME>` |
| RU Grid / DB | `<RU_APPROVATA>` | `<RU_APPROVATA>` |
| Listener DG | `<PRIMARY_DG_IP>:1531` | `<STANDBY_DG_IP>:1531` |
| Diskgroup DATA | `+M24SHAMS_DATA` | `+M24SHAMS_DATA` |
| Diskgroup FRA | `+M24SHAMS_FRA` | `+M24SHAMS_FRA` |
| FRA bytes | `<FRA_BYTES>` | `<FRA_BYTES>` |
| Directory audit | `<AUDIT_DIR>` | `<AUDIT_DIR>` |
| Keystore TDE | `<KEYSTORE_DIR oppure N/A>` | `<KEYSTORE_DIR oppure N/A>` |
| Recovery catalog | `<RMAN_CATALOG_TNS>` | `<RMAN_CATALOG_TNS>` |
| Destinazione backup | `/backup/rman/M24SHAMSPEC` | `/backup/rman/M24SHAMSSEC` |

Registra anche:

| Gate | Valore |
| --- | --- |
| RPO richiesto | `<RPO>` |
| RTO richiesto | `<RTO>` |
| Latenza PE-SE misurata | `<LATENZA_MS>` |
| Redo medio e picco | `<MB_SEC>` |
| Active Data Guard | `<PRODUZIONE_CON_EVIDENZA/LAB_PERSONALE/NO>` |
| TDE richiesto | `<SI/NO - riferimento approvazione>` |
| Percorso creazione primary | `<DBCA_SCRIPT_REVIEW/GOLDEN_RMAN>` |
| Trasporto scelto | `<SYNC_AFFIRM/FASTSYNC_NOAFFIRM>` |

## Procedura operativa

### 0. Prepara host e software

Completa l'[allegato Host Oracle Restart ASM 19c](./GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md)
su PE e SE. Registra DNS, NTP, rete DG, multipath, ASM, RU Grid/DB,
`ORACLE_HOME`, `GRID_HOME`, keystore e recovery catalog. Non creare il
database se host, storage o RU non sono allineati.

### 1. Assessment iniziale

Esegui sul server di riferimento e sul nuovo primary, se gia' esistente. Salva
gli output nell'evidence pack del change.

```sql
SET LINES 240 PAGES 500 TRIMSPOOL ON
SPOOL m24shams_assessment.log

SELECT name, dbid, db_unique_name, open_mode, database_role,
       log_mode, force_logging, flashback_on, protection_mode
FROM v$database;

SELECT instance_name, host_name, version, status, database_status
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

SELECT name, value, isdefault, ismodified
FROM v$parameter
WHERE name IN (
  'compatible',
  'db_block_size',
  'processes',
  'sessions',
  'open_cursors',
  'sga_target',
  'pga_aggregate_target',
  'db_create_file_dest',
  'db_recovery_file_dest',
  'db_recovery_file_dest_size',
  'control_files',
  'log_archive_config',
  'log_archive_dest_1',
  'log_archive_dest_2',
  'standby_file_management',
  'fal_server',
  'dg_broker_start',
  'wallet_root',
  'tde_configuration'
)
ORDER BY name;

SELECT group#, thread#, bytes / 1024 / 1024 AS mb, members, status
FROM v$log
ORDER BY thread#, group#;

SELECT group#, thread#, bytes / 1024 / 1024 AS mb, status
FROM v$standby_log
ORDER BY thread#, group#;

SELECT name, value, unit
FROM v$pgastat
WHERE name IN ('aggregate PGA target parameter', 'maximum PGA allocated');

SELECT dest_id, status, target, destination, db_unique_name, error
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;

SELECT wrl_type, wrl_parameter, status, wallet_type
FROM v$encryption_wallet;

SPOOL OFF
```

Sul sistema operativo:

```bash
hostname -f
uname -r
id oracle
df -hT
df -ih
lsblk
timedatectl
opatch lsinventory
srvctl config asm
srvctl status asm
asmcmd lsdg
```

La query `V$ENCRYPTION_WALLET` puo' generare un warning in alert log anche se
TDE non e' configurato. Registralo come esito dell'assessment, non come errore
automatico.

### 2. Decisione sul metodo di creazione

Il change deve scegliere uno dei due percorsi. Entrambi producono un primary
nuovo e pulito.

| Percorso | Quando usarlo | Vincolo |
| --- | --- | --- |
| DBCA script review | Nessun golden template approvato o requisiti specifici applicativi | DBCA genera gli script; il DBA li revisiona prima dell'esecuzione |
| Golden RMAN vuoto | Esiste un template standard, vuoto, aggiornato e formalmente approvato | Verificare provenienza, patch level, componenti e assenza dati applicativi |

Non clonare implicitamente un database con dati applicativi. Un physical
standby non viene creato con DBCA: deve mantenere lo stesso DBID del primary e
si crea con `RMAN DUPLICATE ... FOR STANDBY`.

### 3A. Creazione primary con DBCA script review

Accedi al DB Home, non al Grid Home:

```bash
export ORACLE_BASE=<ORACLE_BASE>
export ORACLE_HOME=<ORACLE_HOME>
export PATH="$ORACLE_HOME/bin:$PATH"
dbca
```

In DBCA seleziona:

1. `Create a database`;
2. `Advanced configuration`;
3. `Custom Database`;
4. single instance;
5. Global Database Name `M24SHAMSPEC` oppure
   `M24SHAMSPEC.<DB_DOMAIN>` se il dominio aziendale e' previsto;
6. SID `M24SHAMSPEC`;
7. in `All Initialization Parameters` verifica o imposta
   `DB_NAME=M24SHAMS` e `DB_UNIQUE_NAME=M24SHAMSPEC`, includendoli nello
   SPFILE;
8. non selezionare `Create as Container database`;
9. storage ASM e OMF su `+M24SHAMS_DATA`;
10. FRA su `+M24SHAMS_FRA` con dimensione approvata;
11. `ARCHIVELOG`;
12. charset `AL32UTF8`, national charset `AL16UTF16`;
13. solo i componenti richiesti dall'applicazione;
14. `Generate Database Creation Scripts`.

`M24SHAMS` e' il nome base condiviso dalla coppia Data Guard.
`M24SHAMSPEC` identifica invece primary, datacenter `PE` e collaudo `C`.
Lo standby non viene creato con un secondo wizard DBCA: usa
`DB_UNIQUE_NAME=M24SHAMSSEC` e SID locale auxiliary `M24SHAMSSEC` durante il
duplicate RMAN.

Per verificare ogni scelta GUI usa la
[matrice campi DBCA](./GUIDA_08_DBCA_GUI_FIELD_MATRIX_PEYTECH_19C.md).

Revisiona gli script generati. Verifica almeno:

- assenza di path filesystem non approvati;
- assenza di componenti non richiesti, incluso OJVM se non necessario;
- `DB_NAME=M24SHAMS`;
- `DB_UNIQUE_NAME=M24SHAMSPEC`;
- SID primary `M24SHAMSPEC`;
- storage ASM/OMF;
- control file ridondati tra DATA e FRA;
- nessuna password lasciata in file leggibili da altri utenti;
- profili locali non-CDB, senza prefisso comune `C##`.

Esegui solo gli script approvati e conserva la versione firmata nell'evidence
pack.

### 3B. Creazione primary con golden template RMAN vuoto

Usa questo percorso solo se l'inventario contiene l'identificativo del golden
template e l'approvazione.

```text
GOLDEN_TEMPLATE_ID=<ID>
GOLDEN_PATCH_LEVEL=<RU>
GOLDEN_BACKUP_LOCATION=<PATH>
GOLDEN_APPROVAL=<RIFERIMENTO>
```

Il restore deve creare un database indipendente con DBID nuovo. Non usare
`FOR STANDBY` per il primary. Prima del rilascio verifica:

- assenza di schemi applicativi non autorizzati;
- patch level e `DBA_REGISTRY_SQLPATCH`;
- componenti registrati;
- nome, servizi, directory e job;
- password rotation e password file;
- nuovo backup baseline.

### 4. Hardening del primary prima di Data Guard

Connetti localmente con autenticazione OS:

```bash
sqlplus / as sysdba
```

Non inserire password negli argomenti shell, nei file di script o nei comandi
eseguiti in background.

Imposta i prerequisiti:

```sql
ALTER DATABASE FORCE LOGGING;

ALTER SYSTEM SET db_unique_name='M24SHAMSPEC' SCOPE=SPFILE;
ALTER SYSTEM SET db_create_file_dest='+M24SHAMS_DATA' SCOPE=BOTH;
ALTER SYSTEM SET db_recovery_file_dest='+M24SHAMS_FRA' SCOPE=BOTH;
ALTER SYSTEM SET db_recovery_file_dest_size=<FRA_BYTES> SCOPE=BOTH;
ALTER SYSTEM SET standby_file_management='AUTO' SCOPE=BOTH;
ALTER SYSTEM SET log_archive_config=
  'DG_CONFIG=(M24SHAMSPEC,M24SHAMSSEC)' SCOPE=BOTH;
```

Se `ARCHIVELOG` non e' attivo:

```sql
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
```

Configura l'archiviazione locale:

```sql
ALTER SYSTEM SET log_archive_dest_1=
  'LOCATION=USE_DB_RECOVERY_FILE_DEST
   VALID_FOR=(ALL_LOGFILES,ALL_ROLES)
   DB_UNIQUE_NAME=M24SHAMSPEC' SCOPE=BOTH;
```

Non impostare ancora il trasporto remoto finche' listener, standby e SRL non
sono pronti.

### 5. Online redo log e standby redo log

Lo standard PEYTECH di partenza e' quattro online redo log group da `4G` per
thread. Conferma la scelta con il carico misurato: la frequenza di log switch
non deve essere governata da una copia cieca dello standard.

```sql
SELECT group#, thread#, bytes / 1024 / 1024 AS mb, members, status
FROM v$log
ORDER BY thread#, group#;

SELECT group#, thread#, bytes / 1024 / 1024 AS mb, status
FROM v$standby_log
ORDER BY thread#, group#;
```

Per single instance esiste solo `THREAD 1`. Gli SRL devono essere creati sia
sul primary sia sullo standby, con dimensione almeno pari al redo online piu'
grande. Usare almeno online redo group + 1: con quattro gruppi online creare
cinque SRL.

Esempio OMF da adattare ai group number liberi:

```sql
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 11 SIZE 4G;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 12 SIZE 4G;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 13 SIZE 4G;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 14 SIZE 4G;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 15 SIZE 4G;
```

Non eliminare redo log `CURRENT` o `ACTIVE`. Ogni variazione dei redo online
richiede query di stato, log switch controllati e validazione separata.

Se il database esistente usa gruppi piu' piccoli, non modificare i file in
place. Esegui una migrazione controllata:

1. salva inventario e frequenza di log switch;
2. aggiungi quattro nuovi online redo log group OMF da `4G`;
3. forza log switch controllati finche' i gruppi precedenti risultano
   `INACTIVE`;
4. elimina solo i vecchi gruppi `INACTIVE`, mai `CURRENT` o `ACTIVE`;
5. crea o riallinea almeno cinque SRL da `4G` su primary e standby;
6. prova switchover e switchback prima del Go-Live.

### 6. Oracle Net e listener Data Guard

Usa un listener dedicato su porta `1531`. Integra i file aziendali tramite
`IFILE` se la convenzione locale lo prevede.

Esempio `tnsnames.ora`:

```text
M24SHAMSPEC_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <PRIMARY_DG_FQDN>)(PORT = 1531))
    (CONNECT_DATA = (SERVER = DEDICATED)(SERVICE_NAME = M24SHAMSPEC_DG))
  )

M24SHAMSSEC_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <STANDBY_DG_FQDN>)(PORT = 1531))
    (CONNECT_DATA = (SERVER = DEDICATED)(SERVICE_NAME = M24SHAMSSEC_DG))
  )

M24SHAMSSEC_AUX =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <STANDBY_DG_FQDN>)(PORT = 1531))
    (CONNECT_DATA = (SERVER = DEDICATED)(SERVICE_NAME = M24SHAMSSEC_AUX))
  )
```

Gli alias `_DG` sono il canale durevole per redo, FAL e
`DGConnectIdentifier`. La registrazione statica `_AUX` serve invece soltanto
durante il duplicate in `NOMOUNT`; `_DGMGRL` serve al restart Broker quando
richiesto.

Esempio statico temporaneo da adattare in `listener.ora` sullo standby:

```text
SID_LIST_LISTENER_DG =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = M24SHAMSSEC_AUX)
      (ORACLE_HOME = <ORACLE_HOME>)
      (SID_NAME = M24SHAMSSEC)
    )
  )
```

Configura separatamente `_DGMGRL` su entrambi i siti se la gestione restart
lo richiede. Rimuovi `_AUX` dopo il duplicate se non serve piu'.

Test:

```bash
lsnrctl status LISTENER_DG
tnsping M24SHAMSPEC_DG
tnsping M24SHAMSSEC_DG
tnsping M24SHAMSSEC_AUX
```

### 7. Password file e autenticazione

Primary e standby devono avere password file coerenti per le connessioni
amministrative Data Guard. Crea o aggiorna il file sul primary secondo la
procedura aziendale, quindi trasferiscilo con canale sicuro allo standby e
limita i permessi.

```bash
scp <PRIMARY_PASSWORD_FILE> oracle@<STANDBY_FQDN>:<STANDBY_PASSWORD_FILE>
ssh oracle@<STANDBY_FQDN> chmod 600 <STANDBY_PASSWORD_FILE>
```

Non mostrare password in chiaro. Per le connessioni remote usa prompt
interattivo o wallet SEPS approvato.

### 8. Gate TDE

TDE non viene attivato automaticamente. Registra la decisione Security.

Assessment:

```sql
SHOW PARAMETER wallet_root
SHOW PARAMETER tde_configuration

SELECT wrl_type, wrl_parameter, status, wallet_type
FROM v$encryption_wallet;

SELECT owner, table_name, column_name, encryption_alg
FROM dba_encrypted_columns
ORDER BY owner, table_name, column_name;

SELECT tablespace_name, encrypted
FROM dba_tablespaces
ORDER BY tablespace_name;
```

Se TDE e' richiesto:

1. usa il runbook aziendale per creare o aprire il keystore;
2. effettua un backup del keystore;
3. distribuisci il keystore sullo standby con canale sicuro prima del duplicate;
4. imposta permessi minimi;
5. valida apertura e recovery;
6. ripeti distribuzione e validazione dopo ogni rekey.

Il runbook operativo di riferimento e'
[TDE Wallet/Keystore](../../../01_operations/02_runbooks_incidenti/RUNBOOK_27_TDE_WALLET_KEYSTORE_RUNBOOK.md).

### 9. Avvio auxiliary e RMAN duplicate dello standby

Sul server standby prepara un pfile minimo:

```text
db_name='M24SHAMS'
db_unique_name='M24SHAMSSEC'
db_create_file_dest='+M24SHAMS_DATA'
db_recovery_file_dest='+M24SHAMS_FRA'
db_recovery_file_dest_size=<FRA_BYTES>
audit_file_dest='<AUDIT_DIR>'
```

Avvia l'auxiliary:

```bash
export ORACLE_SID=M24SHAMSSEC
sqlplus / as sysdba
```

```sql
STARTUP NOMOUNT PFILE='<PFILE_PATH>';
```

Da una shell amministrativa avvia RMAN. Il comando richiede le password con
prompt interattivo: non aggiungerle alla command line.

```bash
rman target sys@M24SHAMSPEC_DG auxiliary sys@M24SHAMSSEC_AUX
```

```rman
RUN {
  DUPLICATE TARGET DATABASE
    FOR STANDBY
    FROM ACTIVE DATABASE
    DORECOVER
    SPFILE
      SET db_unique_name='M24SHAMSSEC'
      SET db_create_file_dest='+M24SHAMS_DATA'
      SET db_recovery_file_dest='+M24SHAMS_FRA'
      SET db_recovery_file_dest_size='<FRA_BYTES>'
      SET log_archive_config='DG_CONFIG=(M24SHAMSPEC,M24SHAMSSEC)'
      SET fal_server='M24SHAMSPEC_DG'
      SET standby_file_management='AUTO'
    NOFILENAMECHECK;
}
```

`NOFILENAMECHECK` e' ammesso solo dopo aver confermato che primary e standby
sono su host e storage distinti. Se la rete non regge l'active duplicate, usa
il percorso backup-based documentato nella guida generica.

Prima del riavvio persistente crea lo SPFILE in ASM, lascia nel DB Home il
pointer file e verifica successivamente con `srvctl stop database` /
`srvctl start database`. Non considerare sufficiente uno startup SQL*Plus
riuscito con il solo PFILE locale.

### 10. Parametri redo transport simmetrici

Sul primary:

```sql
ALTER SYSTEM SET log_archive_dest_2=
  'SERVICE=M24SHAMSSEC_DG
   SYNC AFFIRM
   VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE)
   DB_UNIQUE_NAME=M24SHAMSSEC' SCOPE=BOTH;
ALTER SYSTEM SET fal_server='M24SHAMSSEC_DG' SCOPE=BOTH;
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH;
```

Sullo standby:

```sql
ALTER SYSTEM SET log_archive_dest_1=
  'LOCATION=USE_DB_RECOVERY_FILE_DEST
   VALID_FOR=(ALL_LOGFILES,ALL_ROLES)
   DB_UNIQUE_NAME=M24SHAMSSEC' SCOPE=BOTH;
ALTER SYSTEM SET log_archive_dest_2=
  'SERVICE=M24SHAMSPEC_DG
   SYNC AFFIRM
   VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE)
   DB_UNIQUE_NAME=M24SHAMSPEC' SCOPE=BOTH;
ALTER SYSTEM SET fal_server='M24SHAMSPEC_DG' SCOPE=BOTH;
ALTER SYSTEM SET standby_file_management='AUTO' SCOPE=BOTH;
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH;
```

Verifica che lo standby abbia cinque SRL da `4G`, oppure il numero e la
dimensione approvati dal gate redo.

### 11. Apply e Active Data Guard

Avvia prima il Redo Apply base con standby montato. Questa e' la baseline Data
Guard e non richiede Active Data Guard:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

Valida MRP, SRL, lag e gap. Solo dopo, se esiste evidenza licenza Active Data
Guard, puoi aprire lo standby in lettura:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
ALTER DATABASE OPEN READ ONLY;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

Controlla:

```sql
SELECT open_mode, database_role FROM v$database;

SELECT process, status, thread#, sequence#
FROM v$managed_standby
ORDER BY process;

SELECT name, value, unit
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');
```

L'esito base atteso e' `MOUNTED` con ruolo `PHYSICAL STANDBY`. Se ADG e'
autorizzato, l'open mode diventa `READ ONLY WITH APPLY`.

### 12. Registrazione Oracle Restart e servizi

Verifica la sintassi disponibile nella RU installata:

```bash
srvctl add database -help
srvctl add service -help
```

Registra su ciascun host la risorsa locale con DB Home, spfile ASM, ruolo e
diskgroup corretti. Non usare `srvctl add instance`: e' un comando RAC e non
serve in questa architettura.

Esempio da adattare sul primary:

```bash
srvctl add database \
  -db M24SHAMSPEC \
  -oraclehome <ORACLE_HOME> \
  -spfile <ASM_SPFILE_PATH> \
  -role PRIMARY \
  -startoption OPEN \
  -stopoption IMMEDIATE \
  -diskgroup "M24SHAMS_DATA,M24SHAMS_FRA"
```

Esempio sullo standby:

```bash
srvctl add database \
  -db M24SHAMSSEC \
  -oraclehome <ORACLE_HOME> \
  -spfile <ASM_SPFILE_PATH> \
  -role PHYSICAL_STANDBY \
  -startoption MOUNT \
  -stopoption IMMEDIATE \
  -diskgroup "M24SHAMS_DATA,M24SHAMS_FRA"
```

Configura i servizi role-based su entrambi i siti secondo la sintassi della RU:

```text
M24SHAMSC_PRY -> PRIMARY
M24SHAMSC_RO  -> PHYSICAL_STANDBY
```

Verifica:

```bash
srvctl config database -db M24SHAMSPEC
srvctl config database -db M24SHAMSSEC
srvctl status database -db M24SHAMSPEC
srvctl status database -db M24SHAMSSEC
```

### 13. Data Guard Broker

Da un host con Oracle Client e `dgmgrl`:

```bash
dgmgrl
```

Prima di creare la configurazione:

1. salva `LOG_ARCHIVE_DEST_n`, `LOG_ARCHIVE_CONFIG` e `FAL_SERVER`;
2. prepara rollback SQL;
3. rimuovi sul primary la destinazione remota manuale incompatibile prima di
   `CREATE CONFIGURATION`;
4. rimuovi sullo standby la destinazione remota manuale prima di
   `ADD DATABASE`;
5. non resettare parametri di rete o destinazioni locali FRA.

Connettiti con prompt interattivo o wallet approvato, quindi:

```text
CREATE CONFIGURATION 'DR_M24SHAMSC_CONF' AS
  PRIMARY DATABASE IS M24SHAMSPEC
  CONNECT IDENTIFIER IS M24SHAMSPEC_DG;

ADD DATABASE M24SHAMSSEC AS
  CONNECT IDENTIFIER IS M24SHAMSSEC_DG
  MAINTAINED AS PHYSICAL;

ENABLE CONFIGURATION;
SHOW CONFIGURATION;
VALIDATE DATABASE M24SHAMSPEC;
VALIDATE DATABASE M24SHAMSSEC;
VALIDATE DATABASE M24SHAMSPEC SPFILE;
VALIDATE DATABASE M24SHAMSSEC SPFILE;
VALIDATE NETWORK CONFIGURATION FOR ALL;
VALIDATE STATIC CONNECT IDENTIFIER FOR ALL;
```

`DR_M24SHAMSC_CONF` deriva dal `DB_NAME=M24SHAMS` e dall'ambiente `C`.
Non contiene `PE` o `SE`, quindi resta stabile dopo switchover.

### 14. Gate MaxAvailability

Il change parte con test controllati. Misura latenza commit applicativa,
transport lag, apply lag e stabilita' rete.

Profilo preferito quando la latenza e' accettabile:

```text
EDIT DATABASE 'M24SHAMSSEC' SET PROPERTY 'LogXptMode'='SYNC';
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
```

Se il business approva un rischio residuo diverso per ridurre la latenza:

```text
EDIT DATABASE 'M24SHAMSSEC' SET PROPERTY 'LogXptMode'='FASTSYNC';
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
```

`FASTSYNC` equivale a `SYNC NOAFFIRM`: riduce il tempo di commit, ma non attende
la persistenza del redo sul disco remoto. La scelta deve apparire nel verbale
Go/No-Go.

Rollback del protection mode se la latenza o la rete non sono accettabili:

```text
EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
EDIT DATABASE 'M24SHAMSSEC' SET PROPERTY 'LogXptMode'='ASYNC';
SHOW CONFIGURATION;
```

### 15. RMAN offload sullo standby

Il recovery catalog e' obbligatorio per rendere coerenti le operazioni RMAN tra
i siti. Non registrare lo standby come database indipendente: primary e
standby hanno lo stesso DBID e vengono distinti da `DB_UNIQUE_NAME`.

Avvia RMAN sullo standby con prompt interattivo:

```bash
rman target sys@M24SHAMSSEC_DG catalog <CATALOG_USER>@<RMAN_CATALOG_TNS>
```

Configura:

```rman
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY
  BACKED UP 1 TIMES TO DEVICE TYPE DISK;

CONFIGURE DB_UNIQUE_NAME M24SHAMSPEC
  CONNECT IDENTIFIER 'M24SHAMSPEC_DG';
CONFIGURE DB_UNIQUE_NAME M24SHAMSSEC
  CONNECT IDENTIFIER 'M24SHAMSSEC_DG';

LIST DB_UNIQUE_NAME OF DATABASE;
SHOW ALL;
```

Backup baseline sullo standby:

```rman
RUN {
  BACKUP AS COMPRESSED BACKUPSET DATABASE
    FORMAT '/backup/rman/M24SHAMSSEC/pieces/database/db_%d_%T_%U.bkp'
    TAG 'M24SHAMS_STBY_BASELINE';
  BACKUP ARCHIVELOG ALL NOT BACKED UP 1 TIMES
    FORMAT '/backup/rman/M24SHAMSSEC/pieces/archivelog/arch_%d_%T_%U.bkp'
    TAG 'M24SHAMS_STBY_ARCH';
  BACKUP CURRENT CONTROLFILE
    FORMAT '/backup/rman/M24SHAMSSEC/pieces/controlfile/cf_%d_%T_%U.bkp';
  BACKUP SPFILE
    FORMAT '/backup/rman/M24SHAMSSEC/pieces/spfile/spfile_%d_%T_%U.bkp';
}
```

Esegui un backup SPFILE locale su entrambi i siti: il backup SPFILE deve essere
disponibile per il database da cui verra' ripristinato.

Non cancellare archivelog per eta' ignorando Data Guard. Prima di ogni purge
controlla deletion policy, backup, sequence shipped e sequence applied.

### 16. Drill switchover controllato

Prima del drill:

```text
SHOW CONFIGURATION;
VALIDATE DATABASE M24SHAMSPEC;
VALIDATE DATABASE M24SHAMSSEC;
```

Con applicazione fermata o correttamente drenata:

```text
SWITCHOVER TO M24SHAMSSEC;
SHOW CONFIGURATION;
```

Verifica servizi, ruolo, apply e accesso applicativo. Esegui switchback:

```text
SWITCHOVER TO M24SHAMSPEC;
SHOW CONFIGURATION;
```

Non abilitare FSFO durante questo change. Dopo un periodo di stabilita', usa la
[Observer FSFO PEYTECH](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md).

## Validazione finale

### Checklist tecnica

| Controllo | Comando o evidenza | Esito |
| --- | --- | --- |
| Identita' primary | `SELECT name, db_unique_name, database_role FROM v$database;` | `<OK/KO>` |
| Identita' standby | stessa query su SE | `<OK/KO>` |
| RU allineata | `opatch lsinventory` PE e SE | `<OK/KO>` |
| ASM | `asmcmd lsdg` | `<OK/KO>` |
| Archivelog e force logging | `SELECT log_mode, force_logging FROM v$database;` | `<OK/KO>` |
| SRL | `SELECT group#, thread#, bytes, status FROM v$standby_log;` | `<OK/KO>` |
| Listener DG | `lsnrctl status LISTENER_DG` | `<OK/KO>` |
| TNS | `tnsping M24SHAMSPEC_DG`, `tnsping M24SHAMSSEC_DG` | `<OK/KO>` |
| Apply | `V$DATAGUARD_STATS`, `V$MANAGED_STANDBY` | `<OK/KO>` |
| Active Data Guard | `READ ONLY WITH APPLY` | `<OK/KO>` |
| Broker | `SHOW CONFIGURATION`, `VALIDATE DATABASE` | `<OK/KO>` |
| Protection gate | verbale `SYNC` o `FASTSYNC` | `<OK/KO>` |
| RMAN catalog | `LIST DB_UNIQUE_NAME OF DATABASE` | `<OK/KO>` |
| Backup standby | `LIST BACKUP SUMMARY` | `<OK/KO>` |
| Restore test | verbale restore validato | `<OK/KO>` |
| Switchover e switchback | evidenza DGMGRL e test servizi | `<OK/KO>` |

Query di chiusura sul primary:

```sql
SELECT name, db_unique_name, database_role, open_mode, log_mode,
       force_logging, protection_mode, protection_level
FROM v$database;

SELECT dest_id, status, target, destination, db_unique_name, error
FROM v$archive_dest_status
WHERE status <> 'INACTIVE'
ORDER BY dest_id;
```

Query di chiusura sullo standby:

```sql
SELECT name, db_unique_name, database_role, open_mode
FROM v$database;

SELECT name, value, unit
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');

SELECT process, status, thread#, sequence#
FROM v$managed_standby
ORDER BY process;
```

## Rollback

Rollback minimo se il trasporto sincrono causa latenza:

```text
EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
EDIT DATABASE 'M24SHAMSSEC' SET PROPERTY 'LogXptMode'='ASYNC';
SHOW CONFIGURATION;
```

Se Broker introduce un blocco operativo:

1. salva `SHOW CONFIGURATION VERBOSE`;
2. disabilita solo la parte necessaria;
3. mantieni redo transport e apply manuali;
4. apri incidente e non improvvisare un failover.

Se lo standby deve essere ricostruito:

1. mantieni il primary in servizio;
2. proteggi gli archivelog necessari;
3. rimuovi solo la risorsa standby difettosa;
4. ripeti duplicate e validazione;
5. non cancellare dati primary o backup validi.

## Troubleshooting rapido

| Sintomo | Prima diagnosi | Azione controllata |
| --- | --- | --- |
| `ORA-12514` su auxiliary | Static listener o alias errato | Controlla `listener.ora`, `lsnrctl status`, `tnsping` |
| Duplicate RMAN fallisce | Password file, NOMOUNT, rete o ASM | Verifica alert log, listener, permessi e `asmcmd lsdg` |
| `ORA-28365` | Keystore TDE chiuso o assente | Distribuisci e apri il keystore approvato, poi riavvia apply |
| SRL non usati | Numero, dimensione o thread errati | Confronta `V$LOG` e `V$STANDBY_LOG` |
| Apply lag cresce | Gap, rete, I/O standby o MRP | Controlla `V$DATAGUARD_STATS`, `V$MANAGED_STANDBY`, alert log |
| Commit rallentano | `SYNC` incompatibile con latenza | Applica rollback documentato a `MaxPerformance ASYNC` |
| Backup standby invisibile dal primary | Recovery catalog o connect identifier errato | Verifica catalogo e `LIST DB_UNIQUE_NAME OF DATABASE` |
| FRA piena con standby in lag | Purge cieco pericoloso | Usa [DG-061](../../../01_operations/02_runbooks_incidenti/RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md#dg-061---primary-fra-piena-per-standby-lag) |

## Adattamenti rispetto allo standard PEYTECH 0.5

| Tema | Decisione M24SHAMS |
| --- | --- |
| Versioni miste 12.2/18c/19c | Baseline unica Oracle 19c con RU allineata |
| RAC | Fuori ambito: nessun thread 2, interconnect o `srvctl add instance` |
| HAS | Oracle Restart standalone confermato |
| Profili `C##...` | Non usare come default: il database e' non-CDB |
| OJVM e componenti DBCA | Installare solo se richiesti |
| Redo | Baseline PEYTECH quattro gruppi da `4G`, con gate sul carico reale |
| SRL | Su entrambi i ruoli, online group + 1 |
| Active Data Guard | Obbligatorio nel target, previa evidenza licenza |
| TDE | Assessment obbligatorio; attivazione solo approvata |
| Archivelog purge | Solo Data Guard-aware e conforme alla deletion policy |
| FSFO | Change separato dopo stabilizzazione |
