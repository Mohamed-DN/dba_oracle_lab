# SHAMS Produzione: Data Guard MaxPerformance con RMAN

## Obiettivo operativo

Creare la coppia di produzione SHAMS in modalita' Data Guard
`MAXPERFORMANCE`, usando RMAN active duplicate, Oracle Restart, Broker e
recovery catalog.

Naming di riferimento:

```text
DB_NAME             = M24SHAMS
Primary produzione = M24SHAMSPEP
Standby produzione = M24SHAMSSEP
Broker config      = DR_M24SHAMSP_CONF
Protection mode    = MAXPERFORMANCE
Redo transport     = ASYNC
```

Questa guida e' la versione production-ready della procedura single non-CDB.
Usa comandi reali Oracle 19c con placeholder, ma non contiene password, host
reali o path aziendali originali.

## Principi tecnici

- `M24SHAMSPEP` e `M24SHAMSSEP` condividono `DB_NAME=M24SHAMS` e hanno
  `DB_UNIQUE_NAME` diversi.
- Lo standby si crea con `DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE
  DATABASE DORECOVER`.
- Il listener Data Guard su porta dedicata serve per redo, FAL, Broker e
  duplicate.
- L'alias `_AUX` serve solo mentre l'istanza standby e' in `NOMOUNT`; dopo il
  duplicate va rimosso.
- Il recovery catalog registra entrambi i siti con `CONFIGURE DB_UNIQUE_NAME`.
- In `MAXPERFORMANCE`, il Broker deve usare `LogXptMode=ASYNC`.
- Le password non vanno in command line, crontab o file versionati: usare
  wallet/SEPS o prompt.

## Procedura operativa

Eseguire i passi da 0 a 13 nell'ordine indicato. Fermarsi se un gate non torna:
non correggere parametri Data Guard "alla cieca" senza inventory e rollback.

## 0. Precheck produzione

Sul primary:

```sql
SELECT name, dbid, db_unique_name, database_role, open_mode, log_mode,
       force_logging, flashback_on
FROM v$database;

SELECT name, value
FROM v$parameter
WHERE name IN (
  'db_name',
  'db_unique_name',
  'compatible',
  'db_create_file_dest',
  'db_recovery_file_dest',
  'db_recovery_file_dest_size',
  'log_archive_config',
  'log_archive_dest_1',
  'log_archive_dest_2',
  'standby_file_management',
  'dg_broker_start',
  'wallet_root',
  'tde_configuration'
)
ORDER BY name;

SELECT group#, bytes/1024/1024 AS mb, status FROM v$log ORDER BY group#;
SELECT group#, bytes/1024/1024 AS mb, status FROM v$standby_log ORDER BY group#;
```

Gate minimi:

- database in `ARCHIVELOG`;
- `FORCE LOGGING` attivo;
- FRA dimensionata e monitorata;
- standby redo log presenti o pianificati con stessa size degli online redo;
- password file e, se presente TDE, keystore disponibili per il sito standby;
- listener DG raggiungibile tra primary e standby;
- spazio in ASM e `/backup/rman` validato.

## 1. TNS e listener Data Guard

Esempio `tnsnames.ora` su primary, standby e server che esegue RMAN:

```text
M24SHAMSPEP_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <PROD_PRIMARY_HOST>)(PORT = 1531))
    (CONNECT_DATA = (SERVER = DEDICATED)(SERVICE_NAME = M24SHAMSPEP_DG))
  )

M24SHAMSSEP_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <PROD_STANDBY_HOST>)(PORT = 1531))
    (CONNECT_DATA = (SERVER = DEDICATED)(SERVICE_NAME = M24SHAMSSEP_DG))
  )

M24SHAMSSEP_AUX =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <PROD_STANDBY_HOST>)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = M24SHAMSSEP_AUX)
      (UR = A)
    )
  )
```

Static listener DG temporaneo sullo standby:

```text
SID_LIST_LISTENER_DG =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = M24SHAMSSEP_AUX)
      (ORACLE_HOME = <ORACLE_HOME>)
      (SID_NAME = M24SHAMSSEP)
    )
  )
```

Ricarica e test:

```bash
lsnrctl reload LISTENER_DG
tnsping M24SHAMSPEP_DG
tnsping M24SHAMSSEP_DG
tnsping M24SHAMSSEP_AUX
```

## 2. Servizio locale per backup

Se i backup usano un alias locale sul listener applicativo, il servizio standby
deve registrarsi anche sulla porta standard. Salvare prima l'inventory:

```sql
SELECT name, value
FROM v$parameter
WHERE name IN ('local_listener','remote_listener','service_names');
```

Se `lsnrctl services LISTENER` non mostra il servizio standby, impostare:

```sql
ALTER SYSTEM SET local_listener=
  '(ADDRESS=(PROTOCOL=TCP)(HOST=<PROD_STANDBY_HOST>)(PORT=1521))'
  SCOPE=BOTH;
ALTER SYSTEM REGISTER;
```

Non usare `M24SHAMSSEP_AUX` per i backup. L'alias `_AUX` e' temporaneo e verra'
rimosso dopo la creazione.

## 3. Primary pronto per Data Guard

Sul primary:

```sql
ALTER DATABASE FORCE LOGGING;

ALTER SYSTEM SET log_archive_config='DG_CONFIG=(M24SHAMSPEP,M24SHAMSSEP)' SCOPE=BOTH;
ALTER SYSTEM SET log_archive_dest_1=
  'LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=M24SHAMSPEP'
  SCOPE=BOTH;
ALTER SYSTEM SET log_archive_dest_2=
  'SERVICE=M24SHAMSSEP_DG ASYNC REOPEN=15 VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=M24SHAMSSEP'
  SCOPE=BOTH;
ALTER SYSTEM SET fal_server='M24SHAMSSEP_DG' SCOPE=BOTH;
ALTER SYSTEM SET standby_file_management='AUTO' SCOPE=BOTH;
ALTER SYSTEM SET dg_broker_start='FALSE' SCOPE=BOTH;
```

Se `log_archive_dest_2` contiene un valore vecchio, salvarlo prima di
sostituirlo:

```sql
SELECT dest_id, destination, target, status, error
FROM v$archive_dest
WHERE dest_id IN (1,2);
```

Non svuotare `log_archive_dest_2` senza piano di rollback.

## 4. Password file e TDE

Copiare il password file dal primary allo standby con canale sicuro e permessi
ristretti:

```bash
scp <PRIMARY_HOST>:$ORACLE_HOME/dbs/orapwM24SHAMSPEP /tmp/orapwM24SHAMSSEP
mv /tmp/orapwM24SHAMSSEP "$ORACLE_HOME/dbs/orapwM24SHAMSSEP"
chown oracle:oinstall "$ORACLE_HOME/dbs/orapwM24SHAMSSEP"
chmod 600 "$ORACLE_HOME/dbs/orapwM24SHAMSSEP"
```

Se TDE e' attivo, copiare il keystore/wallet nel path approvato del sito
standby, senza versionarlo e senza inserirne password negli script. Verificare:

```sql
SELECT wrl_parameter, status, wallet_type
FROM v$encryption_wallet;
```

Con Oracle 19c preferire `WALLET_ROOT` e `TDE_CONFIGURATION` nel file parametri:

```text
wallet_root='<STANDBY_WALLET_ROOT>'
tde_configuration='KEYSTORE_CONFIGURATION=FILE'
```

## 5. Auxiliary standby in NOMOUNT

Sul nodo standby:

```bash
export ORACLE_HOME=<ORACLE_HOME>
export ORACLE_BASE=<ORACLE_BASE>
export ORACLE_SID=M24SHAMSSEP
export ORACLE_UNQNAME=M24SHAMSSEP
export PATH="$ORACLE_HOME/bin:$PATH"

mkdir -p "$ORACLE_BASE/admin/M24SHAMSSEP/adump"
```

Pfile minimo:

```bash
vi "$ORACLE_HOME/dbs/initM24SHAMSSEP.ora"
```

Contenuto:

```text
db_name='M24SHAMS'
db_unique_name='M24SHAMSSEP'
control_files='+M24SHAMS_DATA','+M24SHAMS_FRA'
db_create_file_dest='+M24SHAMS_DATA'
db_recovery_file_dest='+M24SHAMS_FRA'
db_recovery_file_dest_size='<FRA_BYTES>'
audit_file_dest='<ORACLE_BASE>/admin/M24SHAMSSEP/adump'
```

Avvio:

```bash
sqlplus / as sysdba <<'EOF'
STARTUP NOMOUNT PFILE='<ORACLE_HOME>/dbs/initM24SHAMSSEP.ora';
EXIT;
EOF
```

Test connessioni RMAN:

```bash
rman target sys@M24SHAMSPEP_DG auxiliary sys@M24SHAMSSEP_AUX
```

## 6. Duplicate RMAN standby

Eseguire senza password nella history:

```rman
CONNECT TARGET sys@M24SHAMSPEP_DG
CONNECT AUXILIARY sys@M24SHAMSSEP_AUX

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
      SET db_name='M24SHAMS'
      SET db_unique_name='M24SHAMSSEP'
      SET control_files='+M24SHAMS_DATA','+M24SHAMS_FRA'
      SET db_create_file_dest='+M24SHAMS_DATA'
      SET db_create_online_log_dest_1='+M24SHAMS_DATA'
      SET db_create_online_log_dest_2='+M24SHAMS_FRA'
      SET db_recovery_file_dest='+M24SHAMS_FRA'
      SET db_recovery_file_dest_size='<FRA_BYTES>'
      SET log_archive_config='DG_CONFIG=(M24SHAMSPEP,M24SHAMSSEP)'
      SET log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=M24SHAMSSEP'
      SET log_archive_dest_2='SERVICE=M24SHAMSPEP_DG ASYNC REOPEN=15 VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=M24SHAMSPEP'
      SET fal_server='M24SHAMSPEP_DG'
      SET standby_file_management='AUTO'
      SET audit_file_dest='<ORACLE_BASE>/admin/M24SHAMSSEP/adump'
      SET dg_broker_start='FALSE'
    NOFILENAMECHECK;
}
```

`NOFILENAMECHECK` e' ammesso solo con storage separato e disk group coerenti.
Se primary e standby condividono host o storage visibile, usare OMF/disk group
diversi e validare prima i path.

## 7. SPFILE in ASM e Oracle Restart

Verificare dove RMAN ha scritto lo SPFILE:

```sql
SHOW PARAMETER spfile;
SELECT name, value FROM v$parameter WHERE name = 'spfile';
```

Se serve creare o normalizzare lo SPFILE in ASM:

```sql
CREATE SPFILE='+M24SHAMS_DATA/M24SHAMSSEP/PARAMETERFILE/spfileM24SHAMSSEP.ora'
FROM MEMORY;
```

Pointer file locale:

```bash
cat > "$ORACLE_HOME/dbs/initM24SHAMSSEP.ora" <<'EOF'
SPFILE='+M24SHAMS_DATA/M24SHAMSSEP/PARAMETERFILE/spfileM24SHAMSSEP.ora'
EOF
```

Registrare Oracle Restart:

```bash
srvctl add database \
  -db M24SHAMSSEP \
  -dbname M24SHAMS \
  -oraclehome <ORACLE_HOME> \
  -spfile '+M24SHAMS_DATA/M24SHAMSSEP/PARAMETERFILE/spfileM24SHAMSSEP.ora' \
  -role PHYSICAL_STANDBY \
  -startoption MOUNT \
  -stopoption IMMEDIATE \
  -diskgroup "M24SHAMS_DATA,M24SHAMS_FRA"

srvctl enable database -db M24SHAMSSEP
srvctl start database -db M24SHAMSSEP
srvctl status database -db M24SHAMSSEP
```

## 8. Apply MRP

Sul standby:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

SELECT process, status, sequence#
FROM v$managed_standby
WHERE process IN ('MRP0','RFS','ARCH');

SELECT * FROM v$archive_gap;
```

## 9. Broker MAXPERFORMANCE

Abilitare Broker:

```sql
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH;
```

Creare la configurazione:

```dgmgrl
CONNECT /
CREATE CONFIGURATION 'DR_M24SHAMSP_CONF' AS
  PRIMARY DATABASE IS 'M24SHAMSPEP'
  CONNECT IDENTIFIER IS 'M24SHAMSPEP_DG';

ADD DATABASE 'M24SHAMSSEP'
  AS CONNECT IDENTIFIER IS 'M24SHAMSSEP_DG'
  MAINTAINED AS PHYSICAL;

EDIT DATABASE 'M24SHAMSPEP' SET PROPERTY LogXptMode='ASYNC';
EDIT DATABASE 'M24SHAMSSEP' SET PROPERTY LogXptMode='ASYNC';
EDIT DATABASE 'M24SHAMSPEP' SET PROPERTY StandbyFileManagement='AUTO';
EDIT DATABASE 'M24SHAMSSEP' SET PROPERTY StandbyFileManagement='AUTO';

ENABLE CONFIGURATION;
EDIT CONFIGURATION SET PROTECTION MODE AS MaxPerformance;
SHOW CONFIGURATION;
VALIDATE DATABASE 'M24SHAMSPEP';
VALIDATE DATABASE 'M24SHAMSSEP';
```

## 10. Recovery catalog

Connettersi senza password in command line:

```bash
rman target / catalog /@RMAN_CATALOG
```

Sul primary:

```rman
REGISTER DATABASE;
RESYNC CATALOG;
LIST DB_UNIQUE_NAME OF DATABASE;

CONFIGURE DB_UNIQUE_NAME 'M24SHAMSPEP' CONNECT IDENTIFIER 'M24SHAMSPEP_DG';
CONFIGURE DB_UNIQUE_NAME 'M24SHAMSSEP' CONNECT IDENTIFIER 'M24SHAMSSEP_DG';

CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 30 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE RMAN OUTPUT TO KEEP FOR 21 DAYS;
SHOW ALL;
```

Se il database e' gia' registrato, non ripetere `REGISTER DATABASE`: usare
`RESYNC CATALOG`.

## 11. Backup policy produzione

Usare `/backup/rman/<DB_UNIQUE_NAME>` e script in `/opt/oracle/rman_scripts`.

Policy A, backup datafile sul primary:

```text
M24SHAMSPEP: EXEC_DATAFILE_BACKUP_WHEN=PRIMARY
M24SHAMSSEP: EXEC_DATAFILE_BACKUP_WHEN=NEVER
```

Questa policy mantiene full/incremental sul primary e usa lo standby per
trasporto/apply e verifiche. E' coerente quando la produzione preferisce non
offloadare il backup dei datafile sullo standby.

Policy B, offload datafile sullo standby:

```text
M24SHAMSPEP: EXEC_DATAFILE_BACKUP_WHEN=NEVER
M24SHAMSSEP: EXEC_DATAFILE_BACKUP_WHEN=STANDBY
```

Questa e' la policy standard del bundle SHAMS collaudo. In entrambi i casi
eseguire backup archivelog secondo piano e verificare che la deletion policy
non rimuova redo non applicati.

Crontab esempio production:

```cron
00 21 * * 0 /opt/oracle/rman_scripts/rman_backup.sh M24SHAMSPEP full >/dev/null 2>&1
10 21 * * 3 /opt/oracle/rman_scripts/rman_backup.sh M24SHAMSPEP cumulative >/dev/null 2>&1
10 21 * * 1,2,4,5 /opt/oracle/rman_scripts/rman_backup.sh M24SHAMSPEP differential >/dev/null 2>&1
49 * * * * /opt/oracle/rman_scripts/rman_backup.sh M24SHAMSPEP archive >/dev/null 2>&1
49 */4 * * * /opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEP archive >/dev/null 2>&1
```

## 12. Pulizia AUX

Conservare:

- alias `M24SHAMSPEP_DG` e `M24SHAMSSEP_DG`;
- password file, wallet/keystore, adump, SPFILE in ASM;
- log RMAN duplicate in evidence.

Rimuovere:

- alias `M24SHAMSSEP_AUX`;
- blocco statico listener con `GLOBAL_DBNAME=M24SHAMSSEP_AUX`;
- pfile temporaneo non usato;
- cmdfile/log temporanei in `/tmp` dopo salvataggio evidenze.

Esempio:

```bash
export ORACLE_HOME=<ORACLE_HOME>
export GRID_HOME=<GRID_HOME>
export EVIDENCE_DIR=/backup/rman/M24SHAMSSEP/evidence/duplicate_setup
mkdir -p "$EVIDENCE_DIR"

cp -p "$ORACLE_HOME/network/admin/tnsnames.ora" \
  "$EVIDENCE_DIR/tnsnames.ora.pre_aux_cleanup.$(date +%Y%m%d_%H%M%S)"
cp -p "$GRID_HOME/network/admin/listener.ora" \
  "$EVIDENCE_DIR/listener.ora.pre_aux_cleanup.$(date +%Y%m%d_%H%M%S)"

vi "$ORACLE_HOME/network/admin/tnsnames.ora"
vi "$GRID_HOME/network/admin/listener.ora"
lsnrctl reload LISTENER_DG

if grep -n "M24SHAMSSEP_AUX" "$ORACLE_HOME/network/admin/tnsnames.ora"; then
  echo "ERRORE: entry TNS AUX ancora presente"
  exit 1
fi
if grep -n "M24SHAMSSEP_AUX" "$GRID_HOME/network/admin/listener.ora"; then
  echo "ERRORE: static listener AUX ancora presente"
  exit 1
fi
```

## 13. Rollback controllato

Se il duplicate fallisce prima della registrazione Broker:

```sql
SHUTDOWN ABORT;
STARTUP NOMOUNT;
```

Correggere TNS/listener/password file/ASM e ripetere solo dopo aver salvato il
log RMAN. Non cancellare file ASM a mano senza inventory.

Se Broker e' gia' stato creato ma non stabile:

```dgmgrl
DISABLE CONFIGURATION;
REMOVE DATABASE 'M24SHAMSSEP';
```

Poi rimuovere la configurazione solo se il primary e' sano e il change approva:

```dgmgrl
REMOVE CONFIGURATION;
```

## Validazione finale

Primary e standby:

```sql
SELECT name, db_unique_name, database_role, open_mode, switchover_status
FROM v$database;

SELECT dest_id, status, target, error
FROM v$archive_dest_status
WHERE dest_id IN (1,2);
```

Standby:

```sql
SELECT process, status, sequence#
FROM v$managed_standby
WHERE process IN ('MRP0','RFS','ARCH');

SELECT * FROM v$archive_gap;
```

Broker:

```dgmgrl
SHOW CONFIGURATION;
SHOW DATABASE 'M24SHAMSPEP';
SHOW DATABASE 'M24SHAMSSEP';
VALIDATE DATABASE 'M24SHAMSPEP';
VALIDATE DATABASE 'M24SHAMSSEP';
```

RMAN catalog:

```rman
LIST DB_UNIQUE_NAME OF DATABASE;
LIST BACKUP SUMMARY;
REPORT NEED BACKUP;
RESTORE DATABASE VALIDATE;
```

Filesystem e rete:

```bash
lsnrctl services LISTENER_DG
grep -n "M24SHAMSSEP_AUX" "$ORACLE_HOME/network/admin/tnsnames.ora" "$GRID_HOME/network/admin/listener.ora"
crontab -l
```

La procedura e' chiusa solo quando Broker e' `SUCCESS`, MRP applica, il catalogo
vede entrambi i `DB_UNIQUE_NAME`, i backup producono evidenze, e non resta
alcuna entry `_AUX` nei file operativi.

## Troubleshooting rapido

| Sintomo | Controllo | Azione |
| --- | --- | --- |
| RMAN non si collega all'auxiliary | `tnsping M24SHAMSSEP_AUX`, `lsnrctl services LISTENER_DG` | correggere static listener, `SID_NAME`, porta e password file |
| Broker non valida ASYNC | `SHOW DATABASE VERBOSE` | impostare `LogXptMode='ASYNC'` e protection mode `MAXPERFORMANCE` |
| Standby non applica | `V$MANAGED_STANDBY`, `V$ARCHIVE_GAP` | verificare FAL, TNS, password file e `log_archive_dest_2` |
| Catalogo non vede standby | `LIST DB_UNIQUE_NAME OF DATABASE` | eseguire `RESYNC CATALOG` e configurare connect identifier |
| Backup datafile saltato | log wrapper e `EXEC_DATAFILE_BACKUP_WHEN` | scegliere esplicitamente policy A primary o policy B standby |
| Rimane `_AUX` nei file | `grep M24SHAMSSEP_AUX tnsnames.ora listener.ora` | rimuovere solo entry temporanee e ricaricare listener |
