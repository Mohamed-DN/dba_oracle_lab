# SHAMS RMAN: Recovery Database Danneggiato

## Obiettivo operativo

Questa procedura recupera `M24SHAMS` quando il database e' danneggiato ma vuoi
ripristinare la stessa istanza, lo stesso `DB_NAME` e lo stesso `DBID`.

Usala per:

- datafile perso o corrotto;
- tablespace non leggibile;
- database che non apre per media recovery;
- perdita di SPFILE o controlfile;
- blocchi corrotti rilevati da RMAN;
- recovery completo oppure point-in-time recovery controllato.

Default SHAMS:

| Oggetto | Valore |
| --- | --- |
| Primary collaudo | `M24SHAMSPEC` |
| Standby collaudo | `M24SHAMSSEC` |
| DB_NAME | `M24SHAMS` |
| Catalogo RMAN | `/@RMAN_CATALOG` |
| Backup root | `/backup/rman/<DB_UNIQUE_NAME>` |
| Data ASM | `+M24SHAMS_DATA` |
| FRA ASM | `+M24SHAMS_FRA` |

Non eseguire comandi distruttivi prima di aver raccolto evidenze. Se esiste Data
Guard e lo standby e' sano, valuta switchover/failover prima di fermare il
primary.

## Assessment

### 1. Bloccare il contesto e raccogliere evidenza

Eseguire come `oracle` sul nodo interessato.

```bash
export ORACLE_SID=M24SHAMSPEC
export ORACLE_HOME=<ORACLE_HOME>
export PATH="$ORACLE_HOME/bin:$PATH"
export TNS_ADMIN=<TNS_ADMIN>
export EVIDENCE_DIR=/backup/rman/M24SHAMSPEC/evidence/recovery_$(date +%Y%m%d_%H%M%S)

mkdir -p "$EVIDENCE_DIR"
chmod 750 "$EVIDENCE_DIR"
```

Salva alert log, stato listener e stato file system/ASM.

```bash
adrci exec="show alert -tail 300" > "$EVIDENCE_DIR/alert_tail.txt" 2>&1
df -h > "$EVIDENCE_DIR/df_h.txt"
lsnrctl status > "$EVIDENCE_DIR/listener_status.txt" 2>&1
asmcmd lsdg > "$EVIDENCE_DIR/asm_lsdg.txt" 2>&1
```

Se il database e' ancora raggiungibile:

```bash
sqlplus -s / as sysdba <<'SQL' > "$EVIDENCE_DIR/db_state.sqlout"
SET LINES 220 PAGES 200
SELECT name, dbid, db_unique_name, database_role, open_mode, log_mode,
       flashback_on, controlfile_type
FROM v$database;

SELECT instance_name, host_name, status, database_status, startup_time
FROM v$instance;

SELECT file#, status, enabled, name
FROM v$datafile
ORDER BY file#;

SELECT file#, error, online_status, change#, time
FROM v$recover_file
ORDER BY file#;

SELECT file#, status, error, recover, tablespace_name, name
FROM v$datafile_header
WHERE recover = 'YES'
   OR error IS NOT NULL
ORDER BY file#;

SELECT dest_id, status, target, error
FROM v$archive_dest
WHERE dest_id IN (1,2)
ORDER BY dest_id;

SELECT name, space_limit/1024/1024/1024 limit_gb,
       space_used/1024/1024/1024 used_gb,
       space_reclaimable/1024/1024/1024 reclaimable_gb
FROM v$recovery_file_dest;
SQL
```

RMAN evidence:

```bash
rman target / catalog /@RMAN_CATALOG <<'RMAN' > "$EVIDENCE_DIR/rman_inventory.log"
SHOW ALL;
LIST DB_UNIQUE_NAME OF DATABASE;
LIST BACKUP SUMMARY;
LIST FAILURE;
REPORT SCHEMA;
REPORT NEED BACKUP;
RMAN
```

### 2. Decision tree

| Sintomo | Recupero preferito |
| --- | --- |
| Solo un datafile utente perso | Restore/recover del datafile, DB quasi sempre aperto |
| Tablespace applicativo corrotto | Offline tablespace, restore/recover tablespace, online |
| `SYSTEM`, `SYSAUX` o undo danneggiati | Database in `MOUNT`, restore/recover database o datafile critici |
| Controlfile perso ma almeno una copia valida esiste | Copiare la copia valida o correggere `CONTROL_FILES` |
| Tutti i controlfile persi | Restore controlfile da autobackup, recovery database, `OPEN RESETLOGS` |
| SPFILE perso | Restore SPFILE da autobackup o ricreazione da pfile |
| Archivelog mancanti | Recovery fino all'ultimo redo disponibile o failover se standby sano |
| Corruzione blocchi | `VALIDATE`, `BLOCKRECOVER` se backup/redo disponibili |
| Primary rotto e standby sano | Valutare switchover/failover prima del restore |

### 3. Gate Data Guard

Se `M24SHAMSSEC` e' sano, salva lo stato Broker.

```bash
dgmgrl / <<'DGM' > "$EVIDENCE_DIR/dgmgrl_before.log"
SHOW CONFIGURATION;
SHOW DATABASE 'M24SHAMSPEC';
SHOW DATABASE 'M24SHAMSSEC';
VALIDATE DATABASE 'M24SHAMSPEC';
VALIDATE DATABASE 'M24SHAMSSEC';
DGM
```

Se il primary e' irrecuperabile in tempi accettabili e lo standby ha apply lag
nullo o accettato dal change, usare la procedura failover/switchover. Questa
guida continua con il restore RMAN della stessa istanza.

## Procedura operativa

### 1. Validare backup prima del restore

Non saltare questo passo se il database resta almeno in `MOUNT`.

```bash
rman target / catalog /@RMAN_CATALOG
```

```rman
LIST BACKUP SUMMARY;
RESTORE DATABASE PREVIEW SUMMARY;
RESTORE DATABASE VALIDATE;
VALIDATE DATABASE;
LIST FAILURE;
```

Perche':

- `PREVIEW` mostra quali backup e archivelog RMAN usera';
- `VALIDATE` legge i backup e intercetta corruzione prima del restore reale;
- `LIST FAILURE` aiuta a distinguere file mancanti e blocchi corrotti.

### 2. Recuperare un singolo datafile

Usare quando un solo datafile e' perso o richiede media recovery.

Identifica file e tablespace:

```sql
SET LINES 220
SELECT r.file# AS file_id,
       d.name AS datafile_name,
       t.name AS tablespace_name,
       d.status,
       r.error,
       r.change#,
       r.time
FROM v$recover_file r
JOIN v$datafile d ON d.file# = r.file#
JOIN v$tablespace t ON t.ts# = d.ts#
ORDER BY r.file#;
```

Restore:

```bash
rman target / catalog /@RMAN_CATALOG
```

```rman
RUN {
  SQL "ALTER DATABASE DATAFILE <FILE_ID> OFFLINE";
  RESTORE DATAFILE <FILE_ID>;
  RECOVER DATAFILE <FILE_ID>;
  SQL "ALTER DATABASE DATAFILE <FILE_ID> ONLINE";
}
```

Validazione:

```sql
SELECT file#, status, error, recover, tablespace_name, name
FROM v$datafile_header
WHERE file# = <FILE_ID>;

SELECT file#, error, online_status
FROM v$recover_file
WHERE file# = <FILE_ID>;
```

Se `v$recover_file` non restituisce righe per quel file e la tabella applicativa
risponde, il recovery del datafile e' chiuso.

### 3. Recuperare un tablespace applicativo

Usare quando piu' datafile dello stesso tablespace sono danneggiati.

```sql
SELECT tablespace_name, status, contents
FROM dba_tablespaces
WHERE tablespace_name = '<TABLESPACE_NAME>';

SELECT file_id, file_name, online_status
FROM dba_data_files
WHERE tablespace_name = '<TABLESPACE_NAME>'
ORDER BY file_id;
```

```bash
rman target / catalog /@RMAN_CATALOG
```

```rman
RUN {
  SQL "ALTER TABLESPACE <TABLESPACE_NAME> OFFLINE IMMEDIATE";
  RESTORE TABLESPACE <TABLESPACE_NAME>;
  RECOVER TABLESPACE <TABLESPACE_NAME>;
  SQL "ALTER TABLESPACE <TABLESPACE_NAME> ONLINE";
}
```

Non usare questa procedura su `SYSTEM`, `SYSAUX` o undo mentre il database e'
aperto. Per tablespace critici passa al recovery in `MOUNT`.

### 4. Recuperare il database completo senza perdita dati

Usare quando il database non apre o sono coinvolti file critici, ma archivelog e
redo sono completi.

```bash
sqlplus / as sysdba
```

```sql
SHUTDOWN ABORT;
STARTUP MOUNT;
```

```bash
rman target / catalog /@RMAN_CATALOG
```

```rman
RUN {
  RESTORE DATABASE;
  RECOVER DATABASE;
}
```

Se il recovery termina senza richiesta di `RESETLOGS`:

```sql
ALTER DATABASE OPEN;
```

Se RMAN ha usato un backup controlfile o recovery incompleto, Oracle richiedera'
`RESETLOGS`:

```sql
ALTER DATABASE OPEN RESETLOGS;
```

Dopo `RESETLOGS` eseguire subito backup full baseline e resync catalogo.

```rman
RESYNC CATALOG;
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG TAG 'M24SHAMS_POST_RESETLOGS';
LIST INCARNATION;
```

### 5. Recuperare SPFILE perso

Se l'istanza non parte per SPFILE mancante, usa un pfile minimale temporaneo.

`<ORACLE_HOME>/dbs/initM24SHAMSPEC.ora`:

```ini
db_name='M24SHAMS'
db_unique_name='M24SHAMSPEC'
compatible='19.0.0'
control_files='+M24SHAMS_DATA/M24SHAMSPEC/CONTROLFILE/current.ctl'
diagnostic_dest='/u01/app/oracle'
```

Restore da autobackup:

```bash
rman target / catalog /@RMAN_CATALOG
```

```rman
SET DBID <DBID_M24SHAMS>;
STARTUP NOMOUNT PFILE='<ORACLE_HOME>/dbs/initM24SHAMSPEC.ora';
RESTORE SPFILE FROM AUTOBACKUP;
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
```

Se non usi catalogo, devi conoscere il DBID:

```rman
SET DBID <DBID_M24SHAMS>;
STARTUP NOMOUNT PFILE='<ORACLE_HOME>/dbs/initM24SHAMSPEC.ora';
RESTORE SPFILE FROM AUTOBACKUP;
```

### 6. Recuperare controlfile perso

Se una copia controlfile e' ancora valida, preferire copia ASM/OS verso la copia
mancante. Se tutti i controlfile sono persi:

```bash
rman target / catalog /@RMAN_CATALOG
```

```rman
SET DBID <DBID_M24SHAMS>;
STARTUP NOMOUNT;
RESTORE CONTROLFILE FROM AUTOBACKUP;
ALTER DATABASE MOUNT;
RESTORE DATABASE PREVIEW SUMMARY;
RESTORE DATABASE;
RECOVER DATABASE;
```

Aprire con resetlogs:

```sql
ALTER DATABASE OPEN RESETLOGS;
```

Poi:

```rman
RESYNC CATALOG;
LIST INCARNATION;
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG TAG 'M24SHAMS_AFTER_CONTROLFILE_RESTORE';
```

### 7. Recuperare blocchi corrotti

Identifica corruzioni:

```rman
VALIDATE DATABASE;
LIST FAILURE;
```

Query:

```sql
SELECT file#, block#, blocks, corruption_change#, corruption_type
FROM v$database_block_corruption
ORDER BY file#, block#;
```

Se RMAN ha backup e redo sufficienti:

```rman
BLOCKRECOVER CORRUPTION LIST;
```

Validazione:

```rman
VALIDATE DATABASE;
LIST FAILURE;
```

Se la corruzione riguarda blocchi non recuperabili o oggetti critici, aprire
incident con evidenze e valutare restore datafile/tablespace.

### 8. Recovery point-in-time del database

Usare solo se devi tornare prima di un errore logico globale. Questo perde le
transazioni successive al punto scelto e richiede `RESETLOGS`.

Raccogli SCN/time:

```sql
SELECT current_scn, TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS') now_time
FROM v$database;
```

Eseguire:

```sql
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
```

```rman
RUN {
  SET UNTIL TIME "TO_DATE('<YYYY-MM-DD HH24:MI:SS>','YYYY-MM-DD HH24:MI:SS')";
  RESTORE DATABASE;
  RECOVER DATABASE;
}
```

Aprire:

```sql
ALTER DATABASE OPEN RESETLOGS;
```

Data Guard dopo `RESETLOGS` va rivalutato: spesso lo standby deve essere
ricreato o flashbackato se Flashback Database era attivo e compatibile con lo
scenario.

## Validazione finale

SQL:

```sql
SELECT name, dbid, db_unique_name, database_role, open_mode, log_mode
FROM v$database;

SELECT instance_name, status, database_status
FROM v$instance;

SELECT file#, error, online_status
FROM v$recover_file
ORDER BY file#;

SELECT file#, status, error, recover, tablespace_name, name
FROM v$datafile_header
WHERE recover = 'YES'
   OR error IS NOT NULL
ORDER BY file#;

SELECT COUNT(*) AS corrupt_blocks
FROM v$database_block_corruption;
```

RMAN:

```rman
LIST BACKUP SUMMARY;
REPORT NEED BACKUP;
RESTORE DATABASE VALIDATE;
VALIDATE DATABASE;
```

Data Guard, se configurato:

```dgmgrl
SHOW CONFIGURATION;
VALIDATE DATABASE 'M24SHAMSPEC';
VALIDATE DATABASE 'M24SHAMSSEC';
```

Se hai fatto `RESETLOGS`, eseguire e registrare backup baseline:

```rman
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG TAG 'M24SHAMS_RECOVERY_BASELINE';
RESYNC CATALOG;
LIST INCARNATION;
```

## Pulizia finale

```bash
cp -p <RMAN_LOG_FILE> "$EVIDENCE_DIR/" 2>/dev/null || true
chmod -R go-rwx "$EVIDENCE_DIR"
```

Non cancellare backup piece manualmente. La retention resta governata dal
cleanup RMAN gated.

Se hai creato pfile temporanei, conservarli in evidence e rimuovere solo copie
senza segreti da `/tmp`.

```bash
find /tmp -maxdepth 1 -type f -name 'initM24SHAMS*.ora' -ls
```

## Troubleshooting rapido

| Errore | Causa probabile | Azione |
| --- | --- | --- |
| `RMAN-06023 no backup or copy of datafile found` | Backup mancante o catalogo non resyncato | `LIST BACKUP OF DATAFILE <n>`, `CROSSCHECK BACKUP`, verifica `/backup/rman` |
| `RMAN-06054 media recovery requesting unknown archived log` | Archivelog mancante | Cercare backup archivelog, valutare `UNTIL AVAILABLE REDO` o recovery incompleto |
| `ORA-01113 file needs media recovery` | File restored ma non recovered | `RECOVER DATAFILE <n>` o `RECOVER DATABASE` |
| `ORA-01110 data file ...` | Identifica il file coinvolto | Join `v$datafile`, `v$tablespace`, `v$recover_file` |
| `ORA-01547 warning RECOVER succeeded but OPEN RESETLOGS would get error` | Recovery incompleto/non consistente | Non aprire; controllare alert log e completare recovery |
| `ORA-28365 wallet is not open` | TDE attivo e keystore chiuso | Aprire/copiarlo prima del restore di tablespace cifrati |
| `ORA-19809 FRA full` | FRA piena durante recovery | Liberare spazio con RMAN, aumentare FRA o ripristinare archivelog altrove |
| Standby non valido dopo recovery | Incarnazione cambiata o gap | Valutare flashback standby, recreate standby o Broker reinstate |

## Fonti Oracle

- RMAN complete database recovery:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-complete-database-recovery.html
- RMAN `RESTORE`:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/RESTORE.html
- RMAN advanced recovery:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-recovery-advanced.html
