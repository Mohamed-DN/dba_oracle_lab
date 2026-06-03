# SHAMS Migration With RMAN: Produzione verso STG

## Obiettivo operativo

Creare un ambiente STG da produzione usando RMAN, con nome database distinto e
successivo physical standby STG. La procedura produce:

```text
Produzione: DB_NAME=M24SHAMS, DB_UNIQUE_NAME=M24SHAMSPEP/M24SHAMSSEP
STG primary: DB_NAME=M24STG, DB_UNIQUE_NAME=M24STGPEC
STG standby: DB_NAME=M24STG, DB_UNIQUE_NAME=M24STGSEC
```

`M24STG` e' corto, leggibile e compatibile con il limite storico di `DB_NAME`.

## Decisione tecnica

Per creare STG con DBID diverso, usare RMAN duplicate non-standby:

```rman
DUPLICATE TARGET DATABASE TO M24STG
```

Questo crea un database indipendente e lo apre con `RESETLOGS`. Non usare
`FOR STANDBY` per lo STG primary: quello mantiene DBID e ruolo standby del
source, quindi non e' un clone applicativo indipendente.

`nid` resta un fallback se parti da restore/copia che ha ancora lo stesso
`DB_NAME` o DBID del source. Non usare `nid` su un database standby.

## 0. Precheck source produzione

Sul source:

```sql
SELECT name, dbid, db_unique_name, database_role, open_mode, log_mode,
       force_logging
FROM v$database;

SELECT name, value
FROM v$parameter
WHERE name IN (
  'compatible',
  'db_block_size',
  'db_create_file_dest',
  'db_recovery_file_dest',
  'db_recovery_file_dest_size',
  'wallet_root',
  'tde_configuration'
)
ORDER BY name;

SELECT comp_id, version, status
FROM dba_registry
ORDER BY comp_id;

SELECT wrl_parameter, status, wallet_type
FROM v$encryption_wallet;
```

Sul target STG primary:

```bash
crsctl check has
srvctl status asm
asmcmd lsdg
df -h /backup/rman
lsnrctl status LISTENER_DG
```

Il target deve avere stessa major release e RU compatibile con il source.

## 1. Naming e rete STG

TNS su source e target:

```text
M24SHAMSPEP_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <PROD_PRIMARY_HOST>)(PORT = 1531))
    (CONNECT_DATA = (SERVER = DEDICATED)(SERVICE_NAME = M24SHAMSPEP_DG))
  )

M24STGPEC_AUX =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <STG_PRIMARY_HOST>)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = M24STGPEC_AUX)
      (UR = A)
    )
  )
```

Static listener su STG primary:

```text
SID_LIST_LISTENER_DG =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = M24STGPEC_AUX)
      (ORACLE_HOME = <ORACLE_HOME>)
      (SID_NAME = M24STGPEC)
    )
  )
```

Ricarica:

```bash
lsnrctl reload LISTENER_DG
tnsping M24SHAMSPEP_DG
tnsping M24STGPEC_AUX
```

## 2. Auxiliary STG primary

Sul target STG primary:

```bash
export ORACLE_HOME=<ORACLE_HOME>
export ORACLE_BASE=<ORACLE_BASE>
export ORACLE_SID=M24STGPEC
export ORACLE_UNQNAME=M24STGPEC
export PATH="$ORACLE_HOME/bin:$PATH"

mkdir -p "$ORACLE_BASE/admin/M24STGPEC/adump"
```

Pfile minimo:

```bash
cat > "$ORACLE_HOME/dbs/initM24STGPEC.ora" <<'EOF'
db_name='M24STG'
db_unique_name='M24STGPEC'
control_files='+M24STG_DATA','+M24STG_FRA'
db_create_file_dest='+M24STG_DATA'
db_recovery_file_dest='+M24STG_FRA'
db_recovery_file_dest_size='<FRA_BYTES>'
audit_file_dest='<ORACLE_BASE>/admin/M24STGPEC/adump'
EOF
```

Avvio:

```bash
sqlplus / as sysdba <<'EOF'
STARTUP NOMOUNT PFILE='<ORACLE_HOME>/dbs/initM24STGPEC.ora';
EXIT;
EOF
```

Se TDE e' attivo, copiare il keystore source nel path STG approvato prima del
duplicate e verificare `V$ENCRYPTION_WALLET`.

## 3. Duplicate produzione -> STG

Connettere RMAN senza password nella history:

```bash
rman target sys@M24SHAMSPEP_DG auxiliary sys@M24STGPEC_AUX
```

Script:

```rman
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c2 DEVICE TYPE DISK;
  ALLOCATE AUXILIARY CHANNEL a1 DEVICE TYPE DISK;
  ALLOCATE AUXILIARY CHANNEL a2 DEVICE TYPE DISK;

  DUPLICATE TARGET DATABASE TO M24STG
    FROM ACTIVE DATABASE
    SPFILE
      PARAMETER_VALUE_CONVERT
        'M24SHAMS','M24STG',
        'M24SHAMSPEP','M24STGPEC',
        'M24SHAMSSEP','M24STGSEC'
      SET db_name='M24STG'
      SET db_unique_name='M24STGPEC'
      SET control_files='+M24STG_DATA','+M24STG_FRA'
      SET db_create_file_dest='+M24STG_DATA'
      SET db_create_online_log_dest_1='+M24STG_DATA'
      SET db_create_online_log_dest_2='+M24STG_FRA'
      SET db_recovery_file_dest='+M24STG_FRA'
      SET db_recovery_file_dest_size='<FRA_BYTES>'
      SET log_archive_config=''
      SET log_archive_dest_2=''
      SET fal_server=''
      SET standby_file_management='MANUAL'
      SET dg_broker_start='FALSE'
      SET audit_file_dest='<ORACLE_BASE>/admin/M24STGPEC/adump'
    NOFILENAMECHECK;
}
```

`NOFILENAMECHECK` e' accettabile solo se i disk group STG sono separati da
produzione. Per stesso host o storage condiviso usare nomi OMF/disk group
distinti e validare con lo storage team.

## 4. Post-clone STG primary

RMAN duplicate non-standby apre il database con `RESETLOGS` e nuovo DBID.
Verificare:

```sql
SELECT name, dbid, db_unique_name, database_role, open_mode, resetlogs_time
FROM v$database;

SELECT global_name FROM global_name;

SELECT name, value
FROM v$parameter
WHERE name IN (
  'db_name',
  'db_unique_name',
  'control_files',
  'db_create_file_dest',
  'db_recovery_file_dest',
  'log_archive_config',
  'log_archive_dest_2',
  'fal_server',
  'dg_broker_start'
)
ORDER BY name;
```

Se `GLOBAL_NAME` non e' coerente:

```sql
ALTER DATABASE RENAME GLOBAL_NAME TO M24STG.<DB_DOMAIN>;
```

Rimuovere o rigenerare:

- database link verso produzione non autorizzati;
- job schedulati che chiamano endpoint produzione;
- servizi applicativi vecchi;
- directory object con path produzione;
- wallet/client credential non STG.

Query utili:

```sql
SELECT owner, db_link, host FROM dba_db_links ORDER BY owner, db_link;
SELECT owner, job_name, enabled FROM dba_scheduler_jobs ORDER BY owner, job_name;
SELECT directory_name, directory_path FROM dba_directories ORDER BY directory_name;
SELECT name, network_name, pdb FROM cdb_services ORDER BY name;
```

Registrare in Oracle Restart:

```bash
srvctl add database \
  -db M24STGPEC \
  -dbname M24STG \
  -oraclehome <ORACLE_HOME> \
  -spfile '+M24STG_DATA/M24STGPEC/PARAMETERFILE/<SPFILE_NAME>' \
  -role PRIMARY \
  -startoption OPEN \
  -stopoption IMMEDIATE \
  -diskgroup "M24STG_DATA,M24STG_FRA"

srvctl enable database -db M24STGPEC
srvctl start database -db M24STGPEC
srvctl status database -db M24STGPEC
```

## 5. Fallback NID

Usare solo se non hai creato STG con `DUPLICATE ... TO M24STG` e il clone ha
ancora il nome o DBID del source.

Condizioni:

- database non Data Guard;
- mounted exclusive;
- backup disponibile;
- change approvato.

```bash
sqlplus / as sysdba <<'EOF'
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
EXIT;
EOF

nid TARGET=/ DBNAME=M24STG SETNAME=NO

sqlplus / as sysdba <<'EOF'
STARTUP NOMOUNT;
ALTER SYSTEM SET db_name='M24STG' SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE OPEN RESETLOGS;
SELECT name, dbid, db_unique_name, open_mode FROM v$database;
EXIT;
EOF
```

Se serve cambiare solo nome e non DBID, valutare `SETNAME=YES`; comunque
validare sempre `GLOBAL_NAME`.

## 6. Backup STG

Dopo il clone:

```bash
mkdir -p /backup/rman/M24STGPEC
cp docs/02_core_dba/02_backup_and_recovery/RMAN/templates/rman_backup.conf.example \
  /opt/oracle/rman_scripts/cfg/rman_backup_M24STGPEC.conf
vi /opt/oracle/rman_scripts/cfg/rman_backup_M24STGPEC.conf
```

In RMAN:

```rman
REGISTER DATABASE;
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO
  '/backup/rman/M24STGPEC/pieces/controlfile/cf_M24STGPEC_%F';
CONFIGURE SNAPSHOT CONTROLFILE NAME TO
  '/backup/rman/M24STGPEC/metadata/snapcf_M24STGPEC.f';
BACKUP AS COMPRESSED BACKUPSET DATABASE TAG 'M24STG_BASELINE';
BACKUP ARCHIVELOG ALL NOT BACKED UP 1 TIMES TAG 'M24STG_ARCH_BASELINE';
RESTORE DATABASE VALIDATE;
```

## 7. Creazione standby STG

Usare la procedura standby SHAMS sostituendo:

| SHAMS | STG |
| --- | --- |
| `M24SHAMS` | `M24STG` |
| `M24SHAMSPEC` | `M24STGPEC` |
| `M24SHAMSSEC` | `M24STGSEC` |
| `+M24SHAMS_DATA` | `+M24STG_DATA` |
| `+M24SHAMS_FRA` | `+M24STG_FRA` |
| `DR_M24SHAMSC_CONF` | `DR_M24STGC_CONF` |

Creare standby con:

```rman
DUPLICATE TARGET DATABASE
  FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
```

Non usare `nid` sullo standby STG.

## 8. Validazione finale

Sul STG primary:

```sql
SELECT name, dbid, db_unique_name, database_role, open_mode
FROM v$database;

SELECT COUNT(*) FROM dba_db_links;
SELECT COUNT(*) FROM dba_scheduler_jobs WHERE enabled = 'TRUE';
```

Su STG standby:

```sql
SELECT name, db_unique_name, database_role, open_mode
FROM v$database;

SELECT process, status, sequence#
FROM v$managed_standby
WHERE process = 'MRP0';

SELECT * FROM v$archive_gap;
```

Broker:

```dgmgrl
SHOW CONFIGURATION;
VALIDATE DATABASE 'M24STGPEC';
VALIDATE DATABASE 'M24STGSEC';
```

RMAN:

```rman
LIST DB_UNIQUE_NAME OF DATABASE;
LIST BACKUP SUMMARY;
RESTORE DATABASE VALIDATE;
```

La migrazione e' completa solo quando STG primary e STG standby hanno nomi,
DBID, servizi, backup e Broker indipendenti dalla produzione.
