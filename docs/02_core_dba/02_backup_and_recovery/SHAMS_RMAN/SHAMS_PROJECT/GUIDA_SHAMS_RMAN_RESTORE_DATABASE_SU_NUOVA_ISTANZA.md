# SHAMS RMAN: Restore Database su Nuova Istanza

## Obiettivo operativo

Questa guida ricostruisce `M24SHAMS` su un nuovo host o una nuova istanza usando
backup RMAN. Serve per disaster recovery, laboratorio di restore o ricostruzione
controllata quando il server originale non e' piu' disponibile.

Questa procedura non crea uno standby. Crea un database ripristinato. Se il
database deve diventare un clone indipendente con nuovo nome o DBID, usare `nid`
solo dopo il restore e con change dedicato.

Scenari coperti:

| Scenario | Disponibile | Metodo |
| --- | --- | --- |
| A | Backup RMAN + recovery catalog `RMAN_CATALOG` | Restore piu' semplice, metadata nel catalogo |
| B | Solo backup pieces + controlfile autobackup | `SET DBID`, restore controlfile, `CATALOG START WITH` |
| C | Backup + password file + pfile/spfile + wallet | Restore completo con meno ricostruzione manuale |

Default usati:

| Oggetto | Valore |
| --- | --- |
| SID nuova istanza | `M24SHAMSREC` |
| DB_NAME originale | `M24SHAMS` |
| DB_UNIQUE_NAME restore | `M24SHAMSREC` |
| Backup staging | `/backup/rman/M24SHAMSPEC` |
| Restore data ASM | `+M24SHAMS_DATA` |
| Restore FRA ASM | `+M24SHAMS_FRA` |
| Catalogo | `/@RMAN_CATALOG` |

## Assessment

### 1. Inventario minimo richiesto

Prima di iniziare devi avere almeno:

- backupset database;
- backup archivelog fino al punto di recovery desiderato;
- controlfile autobackup oppure recovery catalog;
- DBID del database sorgente;
- stessa major release Oracle o release compatibile;
- password file se servono connessioni remote SYS;
- wallet/keystore se il database usa TDE.

Raccogli evidenze dal catalogo, se disponibile:

```bash
export ORACLE_SID=M24SHAMSREC
export ORACLE_HOME=<ORACLE_HOME>
export PATH="$ORACLE_HOME/bin:$PATH"
export TNS_ADMIN=<TNS_ADMIN>
export EVIDENCE_DIR=/backup/rman/M24SHAMSREC/evidence/restore_new_host_$(date +%Y%m%d_%H%M%S)

mkdir -p "$EVIDENCE_DIR"
chmod 750 "$EVIDENCE_DIR"

rman target /@M24SHAMSPEC_DG catalog /@RMAN_CATALOG <<'RMAN' > "$EVIDENCE_DIR/source_rman_inventory.log"
LIST DB_UNIQUE_NAME OF DATABASE;
LIST INCARNATION;
LIST BACKUP SUMMARY;
REPORT SCHEMA;
RMAN
```

Se il source non esiste piu', usa solo catalogo:

```bash
rman catalog /@RMAN_CATALOG <<'RMAN' > "$EVIDENCE_DIR/catalog_inventory.log"
LIST DB_UNIQUE_NAME OF DATABASE;
LIST INCARNATION OF DATABASE M24SHAMS;
RMAN
```

### 2. Preparare nuovo host

Verifica software, ASM e spazio.

```bash
id oracle
echo "$ORACLE_HOME"
$ORACLE_HOME/bin/sqlplus -v
asmcmd lsdg
df -h /backup/rman
```

Creare directory standard.

```bash
mkdir -p /backup/rman/M24SHAMSREC/{pieces,metadata,logs,reports,evidence,tmp}
chmod -R 750 /backup/rman/M24SHAMSREC
```

Se usi filesystem invece di ASM, creare anche:

```bash
mkdir -p /u02/oradata/M24SHAMSREC /u03/fra/M24SHAMSREC
chmod 750 /u02/oradata/M24SHAMSREC /u03/fra/M24SHAMSREC
```

### 3. Password file, network e TDE

Password file:

```bash
orapwd file="$ORACLE_HOME/dbs/orapwM24SHAMSREC" \
  dbuniquename=M24SHAMSREC \
  force=y \
  format=12
```

Il comando chiede la password a prompt. Preferire prompt o copia sicura del
password file approvato; non scrivere la password nella command line.

Pfile minimale:

```ini
db_name='M24SHAMS'
db_unique_name='M24SHAMSREC'
compatible='19.0.0'
diagnostic_dest='/u01/app/oracle'
control_files='+M24SHAMS_DATA/M24SHAMSREC/CONTROLFILE/current01.ctl','+M24SHAMS_FRA/M24SHAMSREC/CONTROLFILE/current02.ctl'
db_create_file_dest='+M24SHAMS_DATA'
db_recovery_file_dest='+M24SHAMS_FRA'
db_recovery_file_dest_size=<FRA_BYTES>
audit_file_dest='/u01/app/oracle/admin/M24SHAMSREC/adump'
remote_login_passwordfile='EXCLUSIVE'
```

Salvare come:

```bash
mkdir -p /u01/app/oracle/admin/M24SHAMSREC/adump
vi "$ORACLE_HOME/dbs/initM24SHAMSREC.ora"
```

Se TDE e' attivo, copiare wallet/keystore prima di `RESTORE DATABASE`.

```sql
SELECT wrl_type, wrl_parameter, status, wallet_type
FROM v$encryption_wallet;

SELECT tablespace_name, encrypted
FROM dba_tablespaces
ORDER BY tablespace_name;
```

Senza wallet aperto, i datafile cifrati non sono recuperabili.

## Procedura operativa

### 1. Scenario A: restore con recovery catalog

Avvia in `NOMOUNT`.

```bash
export ORACLE_SID=M24SHAMSREC
sqlplus / as sysdba
```

```sql
STARTUP NOMOUNT PFILE='<ORACLE_HOME>/dbs/initM24SHAMSREC.ora';
```

Connetti RMAN:

```bash
rman target / catalog /@RMAN_CATALOG
```

Imposta sempre il DBID quando il controlfile non e' ancora montato. Il catalogo
contiene i metadati, ma il target in `NOMOUNT` non identifica ancora quale DBID
deve essere ripristinato.

```rman
SET DBID <DBID_M24SHAMS>;
```

Se vuoi ripristinare lo SPFILE dal backup:

```rman
RESTORE SPFILE TO PFILE '<ORACLE_HOME>/dbs/initM24SHAMSREC_restored.ora' FROM AUTOBACKUP;
```

Revisiona il pfile ripristinato prima di usarlo: devono cambiare path,
`db_unique_name`, audit, FRA e controlfile. Non avviare con parametri del vecchio
host senza review.

Restore controlfile:

```rman
RESTORE CONTROLFILE FROM AUTOBACKUP;
ALTER DATABASE MOUNT;
```

Se i backup sono in path non registrati o copiati manualmente:

```rman
CATALOG START WITH '/backup/rman/M24SHAMSPEC/';
CROSSCHECK BACKUP;
LIST BACKUP SUMMARY;
```

Restore completo:

```rman
RUN {
  SET NEWNAME FOR DATABASE TO '+M24SHAMS_DATA';
  RESTORE DATABASE;
  SWITCH DATAFILE ALL;
  SWITCH TEMPFILE ALL;
  RECOVER DATABASE;
}
```

Apri:

```sql
ALTER DATABASE OPEN RESETLOGS;
```

`RESETLOGS` e' atteso quando ripristini con backup controlfile o fai DR su nuova
istanza.

### 2. Scenario B: restore senza catalogo

Serve conoscere il DBID.

```bash
rman target /
```

```rman
SET DBID <DBID_M24SHAMS>;
STARTUP NOMOUNT PFILE='<ORACLE_HOME>/dbs/initM24SHAMSREC.ora';
SET CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/backup/rman/M24SHAMSPEC/pieces/controlfile/%F';
RESTORE CONTROLFILE FROM AUTOBACKUP;
ALTER DATABASE MOUNT;
CATALOG START WITH '/backup/rman/M24SHAMSPEC/';
CROSSCHECK BACKUP;
LIST BACKUP SUMMARY;
RESTORE DATABASE PREVIEW SUMMARY;
```

Restore:

```rman
RUN {
  SET NEWNAME FOR DATABASE TO '+M24SHAMS_DATA';
  RESTORE DATABASE;
  SWITCH DATAFILE ALL;
  SWITCH TEMPFILE ALL;
  RECOVER DATABASE;
}
```

Se mancano archivelog continui ma vuoi recuperare fino all'ultimo redo
disponibile:

```rman
RUN {
  SET NEWNAME FOR DATABASE TO '+M24SHAMS_DATA';
  RESTORE DATABASE;
  SWITCH DATAFILE ALL;
  SWITCH TEMPFILE ALL;
  RECOVER DATABASE UNTIL AVAILABLE REDO;
}
```

Apri:

```sql
ALTER DATABASE OPEN RESETLOGS;
```

### 3. Scenario C: hai pfile/spfile, password file e wallet

Questo e' lo scenario migliore. Copia prima tutto in modo tracciato:

```bash
cp -p <SOURCE_PFILE> "$EVIDENCE_DIR/source_init.ora"
cp -p <SOURCE_PASSWORD_FILE> "$EVIDENCE_DIR/source_orapw"
tar -C <SOURCE_WALLET_PARENT> -cf "$EVIDENCE_DIR/source_wallet.tar" <WALLET_DIR_NAME>
```

Poi installa i file nella nuova istanza:

```bash
cp -p <APPROVED_PFILE> "$ORACLE_HOME/dbs/initM24SHAMSREC.ora"
cp -p <APPROVED_PASSWORD_FILE> "$ORACLE_HOME/dbs/orapwM24SHAMSREC"
chmod 600 "$ORACLE_HOME/dbs/orapwM24SHAMSREC"
```

Aggiorna nel pfile:

- `db_unique_name='M24SHAMSREC'`;
- `control_files` verso nuovo ASM/FRA;
- `db_create_file_dest`;
- `db_recovery_file_dest`;
- `audit_file_dest`;
- eventuali `local_listener`, `remote_listener`, `service_names`.

Procedere poi con Scenario A o B.

### 4. Rinominare solo se clone indipendente

Se il restore serve come clone permanente e non come DR dello stesso database,
valutare DBNEWID dopo apertura `RESETLOGS`.

Gate:

```sql
SELECT name, dbid, db_unique_name, open_mode
FROM v$database;
```

Esecuzione solo su clone isolato:

```bash
sqlplus / as sysdba <<'SQL'
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
SQL

nid TARGET=/ DBNAME=M24SHAMSREC SETNAME=YES
```

Poi aggiornare pfile/spfile e aprire con `RESETLOGS` se richiesto da `nid`.
Non usare `nid` se il database deve rientrare nella stessa configurazione Data
Guard originale.

## Validazione finale

SQL:

```sql
SELECT name, dbid, db_unique_name, database_role, open_mode, resetlogs_time
FROM v$database;

SELECT instance_name, host_name, status
FROM v$instance;

SELECT file#, name, status
FROM v$datafile
ORDER BY file#;

SELECT file#, error, online_status
FROM v$recover_file
ORDER BY file#;

SELECT COUNT(*) AS invalid_objects
FROM dba_objects
WHERE status <> 'VALID';
```

RMAN:

```rman
LIST INCARNATION;
REPORT SCHEMA;
LIST BACKUP SUMMARY;
RESTORE DATABASE VALIDATE;
VALIDATE DATABASE;
```

Se registri il restore nel catalogo:

```rman
REGISTER DATABASE;
RESYNC CATALOG;
LIST DB_UNIQUE_NAME OF DATABASE;
```

Eseguire backup baseline sul nuovo host:

```rman
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG TAG 'M24SHAMSREC_BASELINE';
```

## Pulizia finale

Conservare evidence:

```bash
cp -p "$ORACLE_HOME/dbs/initM24SHAMSREC.ora" "$EVIDENCE_DIR/"
chmod -R go-rwx "$EVIDENCE_DIR"
```

Non rimuovere backup RMAN con `rm`. Se hai copiato backup temporanei fuori da
`/backup/rman`, cancellarli solo dopo:

- restore validate verde;
- baseline backup completato;
- approvazione del change.

Esempio sicuro per directory temporanea dedicata:

```bash
RESTORE_STAGING=/restore_staging/M24SHAMSREC
test "$RESTORE_STAGING" = "/restore_staging/M24SHAMSREC" &&
test -d "$RESTORE_STAGING" &&
find "$RESTORE_STAGING" -maxdepth 1 -type f -ls
```

La cancellazione effettiva richiede conferma operativa separata.

## Troubleshooting rapido

| Errore | Causa probabile | Azione |
| --- | --- | --- |
| `RMAN-06172 no AUTOBACKUP found` | Format o DBID errato | Verifica DBID e `SET CONTROLFILE AUTOBACKUP FORMAT` |
| `RMAN-06026 some targets not found` | Backup pieces non catalogati | `CATALOG START WITH '/backup/rman/M24SHAMSPEC/'` |
| `ORA-01103 database name ... in control file is not ...` | `db_name` nel pfile errato | Deve restare `M24SHAMS` fino a eventuale `nid` |
| `ORA-19870/ORA-19505` | Piece non leggibile o path sbagliato | Verifica permessi, mount, `CROSSCHECK BACKUP` |
| `ORA-28365 wallet is not open` | TDE wallet mancante/chiuso | Copiare keystore e aprirlo prima del restore |
| `RMAN-06054` | Archivelog mancante | Cercare backup archivelog o usare `UNTIL AVAILABLE REDO` accettando perdita dati |
| `ORA-01589 must use RESETLOGS or NORESETLOGS` | Recovery con backup controlfile | Aprire con `ALTER DATABASE OPEN RESETLOGS` |
| DBID uguale al source ma doveva essere clone | `nid` non eseguito | Isolare clone, eseguire DBNEWID con change dedicato |

## Fonti Oracle

- RMAN disaster recovery e restore su nuovo host:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-recovery-advanced.html
- RMAN complete database recovery:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-complete-database-recovery.html
- RMAN `RESTORE`:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/RESTORE.html
- DBNEWID/NID:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-dbnewid-utility.html
