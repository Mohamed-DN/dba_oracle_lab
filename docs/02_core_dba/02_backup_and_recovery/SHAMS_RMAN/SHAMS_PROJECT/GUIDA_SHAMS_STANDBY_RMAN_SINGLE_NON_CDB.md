# SHAMS: Creazione Physical Standby con RMAN Active Duplicate

## Obiettivo operativo

Creare il physical standby single instance non-CDB `M24SHAMSSEC` da primary
`M24SHAMSPEC`, usando Oracle Restart, ASM OMF, listener Data Guard dedicato e
RMAN `DUPLICATE ... FOR STANDBY FROM ACTIVE DATABASE`.

Questa procedura deriva dalla runbook operativa passata nei file TXT, ma usa
placeholder e rimuove segreti, host reali e valori non riusabili.

## Naming e placeholder

| Oggetto | Valore SHAMS |
| --- | --- |
| `DB_NAME` comune | `M24SHAMS` |
| Primary PE `DB_UNIQUE_NAME` e SID | `M24SHAMSPEC` |
| Standby SE `DB_UNIQUE_NAME` e SID | `M24SHAMSSEC` |
| TNS primary DG | `M24SHAMSPEC_DG` |
| TNS standby DG | `M24SHAMSSEC_DG` |
| TNS auxiliary temporaneo | `M24SHAMSSEC_AUX` |
| Broker config | `DR_M24SHAMSC_CONF` |
| ASM DATA / FRA | `+M24SHAMS_DATA` / `+M24SHAMS_FRA` |
| Listener DG port | `1531` |

Compilare prima di eseguire:

```text
<PRIMARY_HOST>
<STANDBY_HOST>
<PRIMARY_DG_IP>
<STANDBY_DG_IP>
<ORACLE_HOME>
<GRID_HOME>
<ORACLE_BASE>
<FRA_BYTES>
<SYS_PASSWORD oppure wallet alias>
<KEYSTORE_DIR oppure N/A>
```

## Procedura operativa

Eseguire i passi da 0 a 11 senza saltare controlli intermedi. Il duplicate deve
partire solo quando listener, TNS, password file, parametri Data Guard e
auxiliary `NOMOUNT` sono gia' coerenti su primary e standby.

## 0. Precheck obbligatori

Eseguire su primary e standby come `oracle` o `grid` dove indicato.

```bash
export ORACLE_HOME=<ORACLE_HOME>
export GRID_HOME=<GRID_HOME>
export ORACLE_BASE=<ORACLE_BASE>
export PATH="$ORACLE_HOME/bin:$GRID_HOME/bin:$PATH"

hostname -f
crsctl check has
srvctl status asm
asmcmd lsdg
lsnrctl status LISTENER_DG
```

Sul primary:

```bash
sqlplus / as sysdba @docs/02_core_dba/02_backup_and_recovery/SHAMS_RMAN/templates/sql/shams_precheck_dataguard.sql
```

Condizioni minime:

- `LOG_MODE=ARCHIVELOG`;
- `FORCE_LOGGING=YES`;
- `DB_UNIQUE_NAME=M24SHAMSPEC`;
- `DB_CREATE_FILE_DEST=+M24SHAMS_DATA`;
- `DB_RECOVERY_FILE_DEST=+M24SHAMS_FRA`;
- RU Oracle Home uguale su PE e SE;
- rete `1531/TCP` aperta tra PE e SE;
- se TDE e' attivo, keystore copiato su SE prima del duplicate.

## 1. TNS e listener dedicati

Mettere le entry in `$ORACLE_HOME/network/admin/tnsnames.ora` su entrambi i
server.

```text
M24SHAMSPEC_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <PRIMARY_HOST>)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = M24SHAMSPEC_DG)
    )
  )

M24SHAMSSEC_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <STANDBY_HOST>)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = M24SHAMSSEC_DG)
    )
  )

M24SHAMSSEC_AUX =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <STANDBY_HOST>)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = M24SHAMSSEC_AUX)
      (UR = A)
    )
  )
```

Nel listener della Grid Home sullo standby aggiungere l'auxiliary statico.

```text
SID_LIST_LISTENER_DG =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = M24SHAMSSEC_AUX)
      (ORACLE_HOME = <ORACLE_HOME>)
      (SID_NAME = M24SHAMSSEC)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = M24SHAMSSEC_DGMGRL)
      (ORACLE_HOME = <ORACLE_HOME>)
      (SID_NAME = M24SHAMSSEC)
    )
  )
```

Sul primary configurare almeno il servizio statico Broker:

```text
SID_LIST_LISTENER_DG =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = M24SHAMSPEC_DGMGRL)
      (ORACLE_HOME = <ORACLE_HOME>)
      (SID_NAME = M24SHAMSPEC)
    )
  )
```

Ricaricare e testare:

```bash
lsnrctl reload LISTENER_DG
tnsping M24SHAMSPEC_DG
tnsping M24SHAMSSEC_DG
tnsping M24SHAMSSEC_AUX
```

### 1.1 Registrazione servizio locale per backup

Il listener Data Guard su `1531` serve a redo transport, FAL, Broker e
duplicate. Se lo standard backup usa anche un alias locale senza suffisso `_DG`
su `1521`, lo standby deve registrare il servizio locale sul listener
applicativo. Questo evita il problema operativo visto nella procedura sorgente:
database montato o aperto, ma servizio non visibile dal listener usato dagli
script.

Sullo standby salvare prima lo stato:

```sql
SET LINES 200
COL name FORMAT A30
COL value FORMAT A120

SELECT name, value
FROM v$parameter
WHERE name IN ('local_listener','remote_listener','service_names');
```

Se `lsnrctl services LISTENER` non mostra `M24SHAMSSEC`, impostare
`LOCAL_LISTENER` in modo esplicito:

```sql
ALTER SYSTEM SET local_listener=
  '(ADDRESS=(PROTOCOL=TCP)(HOST=<STANDBY_HOST>)(PORT=1521))'
  SCOPE=BOTH;

ALTER SYSTEM REGISTER;
```

Verifica:

```bash
lsnrctl services LISTENER | grep M24SHAMSSEC
tnsping M24SHAMSSEC
```

Non usare `M24SHAMSSEC_AUX` per i backup. `_AUX` e' temporaneo per RMAN
duplicate in `NOMOUNT` e viene rimosso nella pulizia finale.

## 2. Redo log e standby redo log

Il modello passato nei TXT usa gruppi online da `4G` e SRL da `4G`. Non copiare
il sizing senza misurare redo rate e log switch; il pattern corretto e':
stessa dimensione online redo e SRL, con almeno un gruppo SRL in piu' rispetto
agli online redo per thread.

Esempio single instance con gruppi liberi:

```sql
ALTER DATABASE ADD LOGFILE GROUP 4 SIZE 4096M;
ALTER DATABASE ADD LOGFILE GROUP 5 SIZE 4096M;
ALTER DATABASE ADD LOGFILE GROUP 6 SIZE 4096M;
ALTER DATABASE ADD LOGFILE GROUP 7 SIZE 4096M;

ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;

SELECT group#, bytes / 1024 / 1024 AS mb, status
FROM v$log
ORDER BY group#;
```

Rimuovere vecchi gruppi solo se `INACTIVE`.

```sql
ALTER DATABASE DROP LOGFILE GROUP <OLD_GROUP_INACTIVE>;
```

Creare SRL sul primary prima del duplicate:

```sql
ALTER DATABASE ADD STANDBY LOGFILE GROUP 11 SIZE 4096M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 12 SIZE 4096M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 13 SIZE 4096M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 14 SIZE 4096M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 15 SIZE 4096M;

SELECT group#, thread#, bytes / 1024 / 1024 AS mb, status
FROM v$standby_log
ORDER BY group#;
```

## 3. Parametri primary per Data Guard

Sul primary:

```sql
ALTER DATABASE FORCE LOGGING;

ALTER SYSTEM SET log_archive_config=
  'DG_CONFIG=(M24SHAMSPEC,M24SHAMSSEC)' SCOPE=BOTH;

ALTER SYSTEM SET log_archive_dest_1=
  'LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=M24SHAMSPEC'
  SCOPE=BOTH;

ALTER SYSTEM SET log_archive_dest_2=
  'SERVICE=M24SHAMSSEC_DG ASYNC REOPEN=15 VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=M24SHAMSSEC'
  SCOPE=BOTH;

ALTER SYSTEM SET fal_server='M24SHAMSSEC_DG' SCOPE=BOTH;
ALTER SYSTEM SET standby_file_management='AUTO' SCOPE=BOTH;
```

Se il Broker viene creato subito dopo il duplicate, conservare questi valori in
un rollback SQL e lasciare che il Broker gestisca le destinazioni remote dopo
`ENABLE CONFIGURATION`.

## 4. Password file e TDE

Usare un canale sicuro approvato. Non mettere password nel repository o nella
history shell.

Se il password file primary e' in filesystem:

```bash
scp "$ORACLE_HOME/dbs/orapwM24SHAMSPEC" \
  oracle@<STANDBY_HOST>:"$ORACLE_HOME/dbs/orapwM24SHAMSSEC"
ssh oracle@<STANDBY_HOST> "chmod 640 $ORACLE_HOME/dbs/orapwM24SHAMSSEC"
```

Se e' in ASM, estrarlo temporaneamente come `grid` e poi copiarlo:

```bash
asmcmd pwcopy +M24SHAMS_DATA/M24SHAMSPEC/PASSWORD/<PASSWORD_FILE> /tmp/orapwM24SHAMSPEC
scp /tmp/orapwM24SHAMSPEC oracle@<STANDBY_HOST>:<ORACLE_HOME>/dbs/orapwM24SHAMSSEC
rm -f /tmp/orapwM24SHAMSPEC
```

Per TDE:

```bash
mkdir -p <KEYSTORE_DIR>
chmod 700 <KEYSTORE_DIR>
rsync -av --chmod=F600,D700 <PRIMARY_KEYSTORE_DIR>/ oracle@<STANDBY_HOST>:<KEYSTORE_DIR>/
```

Verifica SQL:

```sql
SELECT wrl_parameter, status, wallet_type
FROM v$encryption_wallet;
```

## 5. Auxiliary standby in NOMOUNT

Sullo standby:

```bash
export ORACLE_HOME=<ORACLE_HOME>
export ORACLE_BASE=<ORACLE_BASE>
export ORACLE_SID=M24SHAMSSEC
export ORACLE_UNQNAME=M24SHAMSSEC
export PATH="$ORACLE_HOME/bin:$PATH"

mkdir -p "$ORACLE_BASE/admin/M24SHAMSSEC/adump"
```

Creare pfile minimo:

```bash
cat > "$ORACLE_HOME/dbs/initM24SHAMSSEC.ora" <<'EOF'
db_name='M24SHAMS'
db_unique_name='M24SHAMSSEC'
audit_file_dest='<ORACLE_BASE>/admin/M24SHAMSSEC/adump'
control_files='+M24SHAMS_DATA','+M24SHAMS_FRA'
db_create_file_dest='+M24SHAMS_DATA'
db_recovery_file_dest='+M24SHAMS_FRA'
db_recovery_file_dest_size='<FRA_BYTES>'
EOF
```

Avviare solo NOMOUNT:

```bash
sqlplus / as sysdba <<'EOF'
STARTUP NOMOUNT PFILE='<ORACLE_HOME>/dbs/initM24SHAMSSEC.ora';
EXIT;
EOF
```

Test connessioni:

```bash
rman target sys@M24SHAMSPEC_DG auxiliary sys@M24SHAMSSEC_AUX
```

Uscire se RMAN non connette target e auxiliary.

## 6. RMAN duplicate

Usare il template:

```bash
cp docs/02_core_dba/02_backup_and_recovery/SHAMS_RMAN/templates/rman/duplicate_standby_from_active.rcv /tmp/duplicate_m24shamssec.rcv
vi /tmp/duplicate_m24shamssec.rcv
```

Eseguire:

```bash
nohup rman cmdfile=/tmp/duplicate_m24shamssec.rcv log=/tmp/duplicate_m24shamssec.log &
tail -f /tmp/duplicate_m24shamssec.log
```

Comando centrale:

```rman
DUPLICATE TARGET DATABASE
  FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
    SET db_name='M24SHAMS'
    SET db_unique_name='M24SHAMSSEC'
    SET control_files='+M24SHAMS_DATA','+M24SHAMS_FRA'
    SET db_create_file_dest='+M24SHAMS_DATA'
    SET db_create_online_log_dest_1='+M24SHAMS_DATA'
    SET db_create_online_log_dest_2='+M24SHAMS_FRA'
    SET db_recovery_file_dest='+M24SHAMS_FRA'
    SET db_recovery_file_dest_size='<FRA_BYTES>'
    SET log_archive_config='DG_CONFIG=(M24SHAMSPEC,M24SHAMSSEC)'
    SET log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=M24SHAMSSEC'
    SET log_archive_dest_2='SERVICE=M24SHAMSPEC_DG ASYNC REOPEN=15 VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=M24SHAMSPEC'
    SET fal_server='M24SHAMSPEC_DG'
    SET standby_file_management='AUTO'
    SET dg_broker_start='FALSE'
  NOFILENAMECHECK;
```

`NOFILENAMECHECK` e' ammesso solo per storage realmente separato. Non usarlo se
primary e standby puntano agli stessi dischi o directory fisiche.

## 7. Registrazione Oracle Restart

Sullo standby:

```bash
sqlplus / as sysdba <<'EOF'
SHOW PARAMETER spfile
EXIT;
EOF
```

Usare esattamente il path ASM mostrato:

```bash
srvctl add database \
  -db M24SHAMSSEC \
  -dbname M24SHAMS \
  -oraclehome <ORACLE_HOME> \
  -spfile '+M24SHAMS_DATA/M24SHAMSSEC/PARAMETERFILE/<SPFILE_NAME>' \
  -role PHYSICAL_STANDBY \
  -startoption MOUNT \
  -stopoption IMMEDIATE \
  -diskgroup "M24SHAMS_DATA,M24SHAMS_FRA"

srvctl enable database -db M24SHAMSSEC
srvctl start database -db M24SHAMSSEC
srvctl status database -db M24SHAMSSEC
```

## 8. Avvio apply

Sullo standby:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

SELECT process, status, sequence#
FROM v$managed_standby
WHERE process = 'MRP0';
```

Eseguire i post-check:

```bash
sqlplus / as sysdba @docs/02_core_dba/02_backup_and_recovery/SHAMS_RMAN/templates/sql/shams_post_duplicate_checks.sql
```

Atteso:

- `DATABASE_ROLE=PHYSICAL STANDBY`;
- `OPEN_MODE=MOUNTED`, oppure `READ ONLY WITH APPLY` se ADG e' autorizzato;
- `MRP0` presente;
- nessuna riga in `V$ARCHIVE_GAP`;
- `last_received` e `last_applied` allineati o con gap temporaneo spiegabile.

## 9. Broker

Su primary e standby:

```sql
ALTER SYSTEM SET dg_broker_config_file1='+M24SHAMS_DATA/M24SHAMSPEC/DATAGUARDCONFIG/dr1.dat' SCOPE=BOTH;
ALTER SYSTEM SET dg_broker_config_file2='+M24SHAMS_FRA/M24SHAMSPEC/DATAGUARDCONFIG/dr2.dat' SCOPE=BOTH;
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH;
```

Sul standby usare path con `M24SHAMSSEC`.

Connettersi senza password in command line:

```bash
dgmgrl sys@M24SHAMSPEC_DG
```

```dgmgrl
CREATE CONFIGURATION 'DR_M24SHAMSC_CONF' AS
  PRIMARY DATABASE IS 'M24SHAMSPEC'
  CONNECT IDENTIFIER IS 'M24SHAMSPEC_DG';

ADD DATABASE 'M24SHAMSSEC' AS
  CONNECT IDENTIFIER IS 'M24SHAMSSEC_DG'
  MAINTAINED AS PHYSICAL;

ENABLE CONFIGURATION;
SHOW CONFIGURATION;
VALIDATE DATABASE 'M24SHAMSPEC';
VALIDATE DATABASE 'M24SHAMSSEC';
VALIDATE DATABASE 'M24SHAMSPEC' SPFILE;
VALIDATE DATABASE 'M24SHAMSSEC' SPFILE;
VALIDATE NETWORK CONFIGURATION FOR ALL;
VALIDATE STATIC CONNECT IDENTIFIER FOR ALL;
```

## 10. Catalogo RMAN e backup baseline

Prima della pulizia degli artefatti temporanei, registrare e validare la coppia
nel recovery catalog. Il catalogo deve conoscere entrambi i `DB_UNIQUE_NAME`,
altrimenti backup, restore e switchover non sono governabili in modo ordinato.

Dal primary:

```bash
rman target / catalog /@RMAN_CATALOG
```

```rman
REGISTER DATABASE;
LIST DB_UNIQUE_NAME OF DATABASE;
CONFIGURE DB_UNIQUE_NAME 'M24SHAMSPEC' CONNECT IDENTIFIER 'M24SHAMSPEC_DG';
CONFIGURE DB_UNIQUE_NAME 'M24SHAMSSEC' CONNECT IDENTIFIER 'M24SHAMSSEC_DG';
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 30 DAYS;
CONFIGURE RMAN OUTPUT TO KEEP FOR 21 DAYS;
SHOW ALL;
```

Se il database era gia' registrato, proseguire con `RESYNC CATALOG` e
`LIST DB_UNIQUE_NAME OF DATABASE`.

Dal nodo standby:

```bash
rman target / catalog /@RMAN_CATALOG
```

```rman
RESYNC CATALOG;
LIST DB_UNIQUE_NAME OF DATABASE;
LIST BACKUP SUMMARY;
```

Eseguire una baseline minima prima della pulizia:

```bash
/opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC full
/opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC archive
```

Validare:

```rman
LIST BACKUP OF DATABASE COMPLETED AFTER 'SYSDATE-1';
LIST BACKUP OF ARCHIVELOG FROM TIME 'SYSDATE-1';
RESTORE DATABASE VALIDATE;
```

Non mettere credenziali catalogo in command line. Usare wallet alias
`/@RMAN_CATALOG` o prompt interattivo.

## 11. Pulizia post-duplicate

Dopo duplicate, apply, Broker e backup baseline, togliere gli artefatti usati
solo per la fase `NOMOUNT`. Non fare questa pulizia prima che `SHOW
CONFIGURATION`, `VALIDATE DATABASE`, `LIST DB_UNIQUE_NAME OF DATABASE` e
`RESTORE DATABASE VALIDATE` siano verdi.

Conservare:

- `M24SHAMSPEC_DG` e `M24SHAMSSEC_DG`, usati da redo transport, FAL, RMAN e
  Broker;
- `M24SHAMSPEC_DGMGRL` e `M24SHAMSSEC_DGMGRL`, se usati dal Broker per restart
  statico;
- password file, wallet/keystore, adump, SPFILE ASM e pointer file locale.

Rimuovere o archiviare:

- alias TNS temporaneo `M24SHAMSSEC_AUX`;
- blocco statico listener con `GLOBAL_DBNAME=M24SHAMSSEC_AUX`;
- `/tmp/duplicate_m24shamssec.rcv` dopo aver verificato che non contenga
  segreti;
- `/tmp/duplicate_m24shamssec.log` solo dopo copia in evidence;
- pfile temporanei usati per `STARTUP NOMOUNT`, lasciando solo il pointer file
  verso lo SPFILE ASM.

Esempio operativo sullo standby:

```bash
export ORACLE_HOME=<ORACLE_HOME>
export GRID_HOME=<GRID_HOME>
export EVIDENCE_DIR=/backup/rman/M24SHAMSSEC/evidence/dataguard_setup
mkdir -p "$EVIDENCE_DIR"

cp -p "$ORACLE_HOME/network/admin/tnsnames.ora" \
  "$EVIDENCE_DIR/tnsnames.ora.pre_aux_cleanup.$(date +%Y%m%d_%H%M%S)"
cp -p "$GRID_HOME/network/admin/listener.ora" \
  "$EVIDENCE_DIR/listener.ora.pre_aux_cleanup.$(date +%Y%m%d_%H%M%S)"

cp -p /tmp/duplicate_m24shamssec.log \
  "$EVIDENCE_DIR/duplicate_m24shamssec.$(date +%Y%m%d_%H%M%S).log"
```

Editare i file, non usare sostituzioni cieche:

```bash
vi "$ORACLE_HOME/network/admin/tnsnames.ora"
vi "$GRID_HOME/network/admin/listener.ora"
```

Nel `tnsnames.ora` togliere solo il blocco `M24SHAMSSEC_AUX`. Nel
`listener.ora` togliere solo il `SID_DESC` con
`GLOBAL_DBNAME=M24SHAMSSEC_AUX`. Lasciare intatti `_DG` e `_DGMGRL`.

Ricaricare e validare:

```bash
lsnrctl reload LISTENER_DG
lsnrctl status LISTENER_DG
tnsping M24SHAMSPEC_DG
tnsping M24SHAMSSEC_DG

if grep -n "M24SHAMSSEC_AUX" "$ORACLE_HOME/network/admin/tnsnames.ora"; then
  echo "ERRORE: entry TNS AUX ancora presente"
  exit 1
fi
if grep -n "M24SHAMSSEC_AUX" "$GRID_HOME/network/admin/listener.ora"; then
  echo "ERRORE: static listener AUX ancora presente"
  exit 1
fi
```

Se lo SPFILE e' in ASM, il file locale deve essere solo un pointer file:

```bash
sqlplus / as sysdba <<'EOF'
SHOW PARAMETER spfile
EXIT;
EOF

cat > "$ORACLE_HOME/dbs/initM24SHAMSSEC.ora" <<'EOF'
SPFILE='+M24SHAMS_DATA/M24SHAMSSEC/PARAMETERFILE/<SPFILE_NAME>'
EOF
chmod 640 "$ORACLE_HOME/dbs/initM24SHAMSSEC.ora"
rm -f /tmp/duplicate_m24shamssec.rcv /tmp/duplicate_m24shamssec.log
```

Validare di nuovo Broker e apply:

```dgmgrl
SHOW CONFIGURATION;
VALIDATE DATABASE 'M24SHAMSPEC';
VALIDATE DATABASE 'M24SHAMSSEC';
VALIDATE STATIC CONNECT IDENTIFIER FOR ALL;
```

```sql
SELECT process, status, sequence#
FROM v$managed_standby
WHERE process = 'MRP0';

SELECT * FROM v$archive_gap;
```

## Validazione finale

| Check | Query/comando | Atteso |
| --- | --- | --- |
| Ruolo standby | `SELECT database_role FROM v$database;` | `PHYSICAL STANDBY` |
| Apply | `V$MANAGED_STANDBY` | `MRP0` attivo |
| Gap | `SELECT * FROM v$archive_gap;` | nessuna riga |
| Broker | `SHOW CONFIGURATION` | `SUCCESS` |
| Restart | `srvctl status database -db M24SHAMSSEC` | database gestito da HAS |
| Backup | `LIST BACKUP SUMMARY` | baseline presente nel catalogo |
| Pulizia AUX | `grep M24SHAMSSEC_AUX tnsnames.ora listener.ora` | nessun match |

Non procedere a switchover o FSFO se questa checklist non e' pulita.

## Troubleshooting rapido

| Sintomo | Controllo | Azione |
| --- | --- | --- |
| `RMAN-06217` o connessione auxiliary KO | `tnsping M24SHAMSSEC_AUX` e listener statico | correggere `SID_DESC`, porta `1531` e servizio statico |
| `ORA-01031` durante duplicate | password file e `REMOTE_LOGIN_PASSWORDFILE` | ricopiare password file con permessi corretti e stessa password SYS |
| File creati fuori ASM atteso | `SHOW PARAMETER db_create_file_dest` | correggere `DB_CREATE_FILE_DEST` e rifare duplicate se necessario |
| MRP non parte | `V$MANAGED_STANDBY`, alert log | risolvere gap, standby redo log o parametri `LOG_ARCHIVE_CONFIG` |
| Broker non valida static connect | `VALIDATE STATIC CONNECT IDENTIFIER FOR ALL` | allineare listener statico e `StaticConnectIdentifier` |
