# CATRMAN: Recovery Catalog RMAN 19c

## Obiettivo operativo

Questa guida mette in piedi un recovery catalog RMAN centralizzato per il lab e
per le procedure SHAMS. Il nome operativo usato nella guida e' `CATRMAN`; il
net service usato dagli script e' `RMAN_CATALOG`.

Il catalogo serve a centralizzare i metadati RMAN di piu' database, primary e
standby inclusi. In un ambiente Data Guard e' particolarmente importante perche'
RMAN deve distinguere database che hanno lo stesso `DB_NAME` e lo stesso `DBID`,
ma `DB_UNIQUE_NAME` diversi.

Standard del lab:

| Oggetto | Valore guida | Note |
| --- | --- | --- |
| Database/PDB catalogo | `<CATRMAN_SERVICE>` | Esempio: `CATRMANPDB` o `CATRMAN` |
| TNS alias catalogo | `RMAN_CATALOG` | Alias usato da RMAN e dagli script |
| Schema owner | `RMAN_CATALOG` | Non usare `SYS` come owner catalogo |
| Tablespace | `RMAN_TS` | Default tablespace dello schema catalogo |
| Wallet/SEPS | `/opt/oracle/wallets/rman_catalog` | Esempio Linux, adattare al sito |
| TNS admin dedicato | `/opt/oracle/network/rman` | Evita dipendenze da home applicative |

Principi non negoziabili:

- il recovery catalog non deve stare dentro il target database che protegge;
- il database catalogo va protetto con backup indipendente;
- non mettere password in command line, crontab, script o file versionati;
- usare wallet/SEPS o prompt interattivo;
- per Data Guard configurare sempre i connect identifier per ogni
  `DB_UNIQUE_NAME`;
- non fare `UNREGISTER DATABASE` senza evidenza DBID, approval e backup del
  catalogo.

## Assessment

Prima di creare il catalogo verifica questi punti.

### 1. Dove vive CATRMAN

Produzione consigliata:

- database separato dal target, idealmente fuori dalla stessa failure domain;
- `ARCHIVELOG` attivo;
- backup RMAN dedicato del catalog database;
- Enterprise Edition per cataloghi 12.1.0.2+ come richiesto dalla
  documentazione Oracle;
- Oracle Partitioning disponibile se richiesto dalla versione/standard scelto
  per il catalog database.

Per il lab puoi usare un database/PDB dedicato, ma non metterlo dentro `RACDB`,
`M24SHAMSPEC`, `M24SHAMSSEC`, `M24SHAMSPEP`, `M24SHAMSSEP` o STG.

### 2. Alias Oracle Net necessari

Ogni nodo che esegue RMAN deve risolvere:

| Alias | Scopo |
| --- | --- |
| `RMAN_CATALOG` | Connessione al recovery catalog `CATRMAN` |
| `RACDB_DG` | Primary lab RACDB per RMAN/Data Guard |
| `RACDB_STBY_DG` | Standby lab RACDB per RMAN/Data Guard |
| `M24SHAMSPEC_DG` | Primary SHAMS collaudo |
| `M24SHAMSSEC_DG` | Standby SHAMS collaudo |
| `M24SHAMSPEP_DG` | Primary SHAMS produzione |
| `M24SHAMSSEP_DG` | Standby SHAMS produzione |
| `M24STGPEC_DG` | Primary STG |
| `M24STGSEC_DG` | Standby STG |

Gli alias `_DG` devono puntare a service raggiungibili da tutti i nodi coinvolti
nelle sessioni RMAN. Non usare alias generici se non sono garantiti su entrambi
i siti.

### 3. Scelta credenziali

Per il catalog owner usa uno schema dedicato:

- `RMAN_CATALOG` per il catalogo base del lab;
- eventuali Virtual Private Catalog solo se devi separare team o domini
  amministrativi.

Nel lab usiamo un solo base catalog. I VPC sono descritti solo come estensione,
non come default.

## Procedura operativa

### 1. Preparare il catalog database

Connettersi al database o alla PDB che ospitera' il catalogo.

```bash
sqlplus / as sysdba
```

Se il catalogo vive in una PDB, entra nella PDB corretta prima di creare user e
tablespace.

```sql
SHOW CON_NAME;
SHOW PDBS;

ALTER SESSION SET CONTAINER=<CATRMAN_PDB>;
SHOW CON_NAME;
```

Verifica archivelog e open mode.

```sql
SELECT name, open_mode, database_role, log_mode
FROM v$database;

SELECT instance_name, status
FROM v$instance;
```

Se il catalog database non e' in `ARCHIVELOG`, apri un change dedicato prima di
procedere. Non mischiare la creazione del catalogo con il cambio log mode.

### 2. Creare tablespace e schema owner

Esempio ASM:

```sql
CREATE TABLESPACE rman_ts
  DATAFILE '+DATA'
  SIZE 2G
  AUTOEXTEND ON NEXT 512M
  MAXSIZE 30G;

CREATE USER rman_catalog IDENTIFIED BY "<PASSWORD_RMAN_CATALOG>"
  DEFAULT TABLESPACE rman_ts
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON rman_ts;

GRANT CREATE SESSION TO rman_catalog;
GRANT RECOVERY_CATALOG_OWNER TO rman_catalog;
```

Esempio filesystem:

```sql
CREATE TABLESPACE rman_ts
  DATAFILE '/u02/oradata/<CATRMAN_DB>/rman_ts01.dbf'
  SIZE 2G
  AUTOEXTEND ON NEXT 512M
  MAXSIZE 30G;
```

Controllo:

```sql
SELECT username, account_status, default_tablespace
FROM dba_users
WHERE username = 'RMAN_CATALOG';

SELECT grantee, granted_role
FROM dba_role_privs
WHERE grantee = 'RMAN_CATALOG'
ORDER BY granted_role;
```

### 3. Configurare TNS dedicato

Sul client RMAN, creare una directory network dedicata.

```bash
sudo mkdir -p /opt/oracle/network/rman
sudo chown -R oracle:oinstall /opt/oracle/network/rman
sudo chmod 750 /opt/oracle/network/rman
```

`/opt/oracle/network/rman/tnsnames.ora`:

```ini
RMAN_CATALOG =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = <CATRMAN_HOST1>)(PORT = 1521))
      (ADDRESS = (PROTOCOL = TCP)(HOST = <CATRMAN_HOST2>)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = <CATRMAN_SERVICE>)
    )
  )
```

Se `CATRMAN` e' single instance, lascia un solo `ADDRESS`. Se e' RAC o usa SCAN,
usa gli endpoint approvati dal network team.

Test senza password:

```bash
export TNS_ADMIN=/opt/oracle/network/rman
tnsping RMAN_CATALOG
```

### 4. Configurare wallet/SEPS per il catalogo

Creare il wallet client.

```bash
export TNS_ADMIN=/opt/oracle/network/rman
export WALLET_DIR=/opt/oracle/wallets/rman_catalog

mkdir -p "$WALLET_DIR"
chmod 700 "$WALLET_DIR"

mkstore -wrl "$WALLET_DIR" -create
mkstore -wrl "$WALLET_DIR" -createCredential RMAN_CATALOG rman_catalog
mkstore -wrl "$WALLET_DIR" -listCredential
```

Il comando `-createCredential` chiede la password a prompt. Non scriverla nel
file, nella shell history o nel crontab.

`/opt/oracle/network/rman/sqlnet.ora`:

```ini
WALLET_LOCATION =
  (SOURCE =
    (METHOD = FILE)
    (METHOD_DATA =
      (DIRECTORY = /opt/oracle/wallets/rman_catalog)
    )
  )

SQLNET.WALLET_OVERRIDE = TRUE
```

Test:

```bash
export TNS_ADMIN=/opt/oracle/network/rman
sqlplus /@RMAN_CATALOG
```

La connessione deve entrare come `RMAN_CATALOG` senza password in command line.

Per procedure Data Guard non interattive, come `RESYNC CATALOG FROM
DB_UNIQUE_NAME ALL`, prepara anche le credential wallet per gli alias `_DG` dei
target, usando l'utente `SYS` e la password del password file. I comandi sotto
chiedono la password a prompt.

```bash
mkstore -wrl "$WALLET_DIR" -createCredential RACDB_DG sys
mkstore -wrl "$WALLET_DIR" -createCredential RACDB_STBY_DG sys
mkstore -wrl "$WALLET_DIR" -createCredential M24SHAMSPEC_DG sys
mkstore -wrl "$WALLET_DIR" -createCredential M24SHAMSSEC_DG sys
mkstore -wrl "$WALLET_DIR" -createCredential M24SHAMSPEP_DG sys
mkstore -wrl "$WALLET_DIR" -createCredential M24SHAMSSEP_DG sys
mkstore -wrl "$WALLET_DIR" -createCredential M24STGPEC_DG sys
mkstore -wrl "$WALLET_DIR" -createCredential M24STGSEC_DG sys
```

Se il sito non autorizza il wallet per `SYS`, usa connessione RMAN interattiva
con prompt password e non schedulare resync cross-site automatici.

### 5. Creare il catalogo RMAN

Usare l'Oracle Home della stessa major release del catalog database o comunque
una release RMAN compatibile con i target.

```bash
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH="$ORACLE_HOME/bin:$PATH"
export TNS_ADMIN=/opt/oracle/network/rman

rman catalog /@RMAN_CATALOG
```

Nel prompt RMAN:

```rman
CREATE CATALOG TABLESPACE rman_ts;
EXIT;
```

Validazione SQL lato catalogo:

```bash
sqlplus /@RMAN_CATALOG
```

```sql
SELECT COUNT(*) AS catalog_tables
FROM user_tables;

SELECT table_name
FROM user_tables
WHERE table_name LIKE 'RC_%'
ORDER BY table_name
FETCH FIRST 20 ROWS ONLY;
```

### 6. Registrare il primo target

Eseguire dal nodo del database target. Per il lab RACDB primary:

```bash
export TNS_ADMIN=/opt/oracle/network/rman
export ORACLE_SID=RACDB1

rman target / catalog /@RMAN_CATALOG
```

Nel prompt RMAN:

```rman
REGISTER DATABASE;
REPORT SCHEMA;
LIST INCARNATION;
LIST DB_UNIQUE_NAME OF DATABASE;
EXIT;
```

Se il database era gia' registrato, non forzare unregister. Usa:

```rman
RESYNC CATALOG;
LIST DB_UNIQUE_NAME OF DATABASE;
```

### 7. Configurare Data Guard nel catalogo

Per ogni coppia Data Guard, configurare il connect identifier dei
`DB_UNIQUE_NAME`. Il connect identifier non deve includere username o password.

Lab RACDB, con password file authentication tramite wallet alias `_DG`:

```bash
export TNS_ADMIN=/opt/oracle/network/rman
rman target /@RACDB_DG catalog /@RMAN_CATALOG
```

```rman
CONFIGURE DB_UNIQUE_NAME 'RACDB' CONNECT IDENTIFIER 'RACDB_DG';
CONFIGURE DB_UNIQUE_NAME 'RACDB_STBY' CONNECT IDENTIFIER 'RACDB_STBY_DG';

LIST DB_UNIQUE_NAME OF DATABASE;
RESYNC CATALOG FROM DB_UNIQUE_NAME ALL;
LIST DB_UNIQUE_NAME OF DATABASE;
EXIT;
```

SHAMS collaudo, eseguito dal primary:

```bash
rman target /@M24SHAMSPEC_DG catalog /@RMAN_CATALOG
```

```rman
CONFIGURE DB_UNIQUE_NAME 'M24SHAMSPEC' CONNECT IDENTIFIER 'M24SHAMSPEC_DG';
CONFIGURE DB_UNIQUE_NAME 'M24SHAMSSEC' CONNECT IDENTIFIER 'M24SHAMSSEC_DG';
RESYNC CATALOG FROM DB_UNIQUE_NAME ALL;
LIST DB_UNIQUE_NAME OF DATABASE;
```

SHAMS produzione MaxPerformance, eseguito dal primary:

```bash
rman target /@M24SHAMSPEP_DG catalog /@RMAN_CATALOG
```

```rman
CONFIGURE DB_UNIQUE_NAME 'M24SHAMSPEP' CONNECT IDENTIFIER 'M24SHAMSPEP_DG';
CONFIGURE DB_UNIQUE_NAME 'M24SHAMSSEP' CONNECT IDENTIFIER 'M24SHAMSSEP_DG';
RESYNC CATALOG FROM DB_UNIQUE_NAME ALL;
LIST DB_UNIQUE_NAME OF DATABASE;
```

SHAMS STG, eseguito dal primary:

```bash
rman target /@M24STGPEC_DG catalog /@RMAN_CATALOG
```

```rman
CONFIGURE DB_UNIQUE_NAME 'M24STGPEC' CONNECT IDENTIFIER 'M24STGPEC_DG';
CONFIGURE DB_UNIQUE_NAME 'M24STGSEC' CONNECT IDENTIFIER 'M24STGSEC_DG';
RESYNC CATALOG FROM DB_UNIQUE_NAME ALL;
LIST DB_UNIQUE_NAME OF DATABASE;
```

Se `RESYNC CATALOG FROM DB_UNIQUE_NAME ALL` non puo' autenticarsi verso un sito,
verifica password file, TNS, wallet e listener prima di riprovare.

### 8. Applicare la baseline RMAN per DB_UNIQUE_NAME

Connettersi al target e al catalogo:

```bash
export TNS_ADMIN=/opt/oracle/network/rman
rman target / catalog /@RMAN_CATALOG
```

Baseline generica:

```rman
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 35 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO BACKUPSET;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
SHOW ALL;
```

Per policy differenti primary/standby, usare i wrapper SHAMS e i file config
dedicati. Non duplicare logiche nei crontab.

### 9. Creare script globali opzionali

Gli stored script sono utili quando vuoi una baseline comune nel catalogo. Non
devono contenere password o path sensibili.

```bash
rman target / catalog /@RMAN_CATALOG
```

```rman
CREATE GLOBAL SCRIPT catrman_list_health
{
  LIST DB_UNIQUE_NAME OF DATABASE;
  LIST BACKUP SUMMARY;
  REPORT OBSOLETE;
}

LIST GLOBAL SCRIPT NAMES;
PRINT GLOBAL SCRIPT catrman_list_health;
```

Esecuzione:

```rman
RUN { EXECUTE GLOBAL SCRIPT catrman_list_health; }
```

### 10. Proteggere CATRMAN

Il catalogo protegge gli altri database, quindi deve avere backup propri. Esempio
minimo lato catalog database:

```bash
export ORACLE_SID=<CATRMAN_SID>
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH="$ORACLE_HOME/bin:$PATH"

rman target / <<'RMAN'
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG TAG 'CATRMAN_DAILY';
DELETE NOPROMPT OBSOLETE;
RMAN
```

Non salvare l'unica copia del backup catalogo nello stesso storage che ospita i
backup dei target.

### 11. Upgrade catalogo dopo patch o major upgrade

Quando il client RMAN richiede una versione catalogo piu' recente:

```bash
rman catalog /@RMAN_CATALOG
```

```rman
UPGRADE CATALOG;
UPGRADE CATALOG;
EXIT;
```

Per evitare il doppio prompt in automazione controllata:

```rman
UPGRADE CATALOG NOPROMPT;
```

Se usi Virtual Private Catalog, eseguire prima i controlli Oracle su
`dbmsrmansys.sql` e `dbmsrmanvpc.sql` con change dedicato.

## Validazione finale

### Check 1. Connessione sicura

```bash
export TNS_ADMIN=/opt/oracle/network/rman
tnsping RMAN_CATALOG
sqlplus /@RMAN_CATALOG
rman catalog /@RMAN_CATALOG
```

Esito atteso:

- nessuna password in command line;
- `sqlplus /@RMAN_CATALOG` entra nello schema `RMAN_CATALOG`;
- `rman catalog /@RMAN_CATALOG` apre la sessione catalogo.

### Check 2. Oggetti catalogo

```sql
SELECT COUNT(*) AS rc_objects
FROM user_objects
WHERE object_name LIKE 'RC_%';

SELECT db_key, dbid, name
FROM rc_database
ORDER BY name, dbid;
```

### Check 3. Target registrati

```bash
rman target / catalog /@RMAN_CATALOG
```

```rman
LIST DB_UNIQUE_NAME OF DATABASE;
LIST INCARNATION;
REPORT SCHEMA;
LIST BACKUP SUMMARY;
```

Per ogni coppia Data Guard devono comparire i `DB_UNIQUE_NAME` previsti:

| Coppia | Primary | Standby |
| --- | --- | --- |
| Lab RACDB | `RACDB` | `RACDB_STBY` |
| SHAMS collaudo | `M24SHAMSPEC` | `M24SHAMSSEC` |
| SHAMS produzione | `M24SHAMSPEP` | `M24SHAMSSEP` |
| SHAMS STG | `M24STGPEC` | `M24STGSEC` |

### Check 4. Resync Data Guard

```rman
RESYNC CATALOG FROM DB_UNIQUE_NAME ALL;
LIST DB_UNIQUE_NAME OF DATABASE;
```

Se il comando fallisce, il problema e' quasi sempre uno tra:

- TNS alias non risolvibile dal nodo RMAN;
- password file non allineato tra primary e standby;
- wallet credential `SYS` mancante per uno degli alias `_DG`;
- listener/service `_DG` non registrato;
- `CONFIGURE DB_UNIQUE_NAME ... CONNECT IDENTIFIER` assente o errato.

### Check 5. Nessun segreto nei file

Dal repository:

```bash
rg -n "password|identified by|catalog .*@|sys/" docs/02_core_dba/02_backup_and_recovery docs/02_core_dba/04_high_availability_and_rac
```

Sono ammessi solo placeholder come `<PASSWORD_RMAN_CATALOG>` e comandi che usano
wallet alias `/@RMAN_CATALOG` o `@RMAN_CATALOG` senza password.

## Troubleshooting rapido

| Errore | Causa probabile | Azione |
| --- | --- | --- |
| `RMAN-06445 cannot connect to recovery catalog after NOCATALOG has been used` | Sessione RMAN partita in `NOCATALOG` | Uscire e riaprire RMAN con `catalog /@RMAN_CATALOG` fin dall'inizio |
| `RMAN-20002 target database already registered` | Target gia' presente | Usare `RESYNC CATALOG`; non fare unregister |
| `RMAN-06613 connect identifier not configured` | Manca `CONFIGURE DB_UNIQUE_NAME ... CONNECT IDENTIFIER` | Configurare alias `_DG` del `DB_UNIQUE_NAME` coinvolto |
| `ORA-01017` su `/@RMAN_CATALOG` | Credenziale wallet errata | Ricreare credential con `mkstore -createCredential RMAN_CATALOG rman_catalog` |
| `ORA-12154` | Alias TNS non risolto | Verificare `TNS_ADMIN`, `tnsnames.ora`, permessi e nome alias |
| `LIST DB_UNIQUE_NAME` non mostra lo standby | Catalogo non resyncato o standby non visto | Verificare `DB_UNIQUE_NAME`, TNS `_DG`, poi `RESYNC CATALOG FROM DB_UNIQUE_NAME ALL` |
| `REGISTER DATABASE` fallisce per DBID duplicato | Clone creato copiando file invece di RMAN duplicate | Per clone indipendente usare RMAN `DUPLICATE`; se serve cambiare DBID usare DBNEWID/NID con change dedicato |
| Backup invisibile dopo switchover | Connect identifier o resync incompleto | Eseguire `LIST DB_UNIQUE_NAME`, `RESYNC CATALOG FROM DB_UNIQUE_NAME ALL`, poi `LIST BACKUP SUMMARY` |
| Catalogo perso | Backup catalogo assente o non recuperabile | Ripristinare catalog database dal suo backup; se impossibile, reregistrare target perdendo storico non presente nei controlfile |

## Rollback e operazioni pericolose

### Non usare unregister come cleanup ordinario

`UNREGISTER DATABASE` elimina metadati RMAN dal catalogo. Dopo la nuova
registrazione puoi perdere storico non piu' presente nel controlfile del target.

Usarlo solo se tutte queste condizioni sono vere:

- DBID e `DB_UNIQUE_NAME` sono stati identificati e salvati nel change;
- e' stato fatto backup del catalog database;
- non ci sono restore/recover pendenti che dipendono da quello storico;
- il change ha approvazione esplicita.

Esempio di raccolta evidenze:

```rman
LIST DB_UNIQUE_NAME OF DATABASE;
LIST INCARNATION;
LIST BACKUP SUMMARY;
```

### Cambio DB_UNIQUE_NAME

Se un database Data Guard cambia `DB_UNIQUE_NAME`, aggiornare il catalogo con:

```rman
LIST DB_UNIQUE_NAME OF DATABASE;
CHANGE DB_UNIQUE_NAME FROM <OLD_DB_UNIQUE_NAME> TO <NEW_DB_UNIQUE_NAME>;
LIST DB_UNIQUE_NAME OF DATABASE;
```

Poi riconfigurare il connect identifier:

```rman
CONFIGURE DB_UNIQUE_NAME '<NEW_DB_UNIQUE_NAME>' CONNECT IDENTIFIER '<NEW_DG_TNS_ALIAS>';
RESYNC CATALOG FROM DB_UNIQUE_NAME ALL;
```

## Integrazione con le guide del repo

Questa procedura e' il prerequisito comune per:

- `GUIDA_STANDARD_DIRECTORY_BACKUP_RMAN_19C.md`;
- `GUIDA_RMAN_COMPLETA_19C.md`;
- `GUIDA_RMAN_COMANDI_ENTERPRISE.md`;
- `SHAMS_RMAN/SHAMS_PROJECT/GUIDA_RMAN_BACKUP_SHAMS_PROJECT.md`;
- `SHAMS_RMAN/SHAMS_PROJECT/GUIDA_SHAMS_STANDBY_RMAN_SINGLE_NON_CDB.md`;
- `SHAMS_RMAN/SHAMS_PROJECT/GUIDA_SHAMS_PROD_MAXPERFORMANCE_WITH_RMAN.md`;
- `SHAMS_RMAN/SHAMS_PROJECT/GUIDA_SHAMS_MIGRATION_WITH_RMAN.md`;
- `04_high_availability_and_rac/GUIDA_FASE3_RAC_STANDBY.md`;
- `04_high_availability_and_rac/SHAMS_PROJECT/RUN_SHEET_01_M24SHAMS_SINGLE_NON_CDB.md`.

## Fonti Oracle

- Recovery catalog RMAN 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/managing-recovery-catalog.html
- `REGISTER DATABASE`:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/REGISTER-DATABASE.html
- `CONFIGURE DB_UNIQUE_NAME ... CONNECT IDENTIFIER`:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/CONFIGURE.html
- `CONNECT` RMAN e nota Data Guard/recovery catalog:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/CONNECT.html
- Standby database con RMAN:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/creating-data-guard-standby-database-using-RMAN.html
- `UPGRADE CATALOG`:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/UPGRADE-CATALOG.html
- Secure External Password Store:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-authentication.html
