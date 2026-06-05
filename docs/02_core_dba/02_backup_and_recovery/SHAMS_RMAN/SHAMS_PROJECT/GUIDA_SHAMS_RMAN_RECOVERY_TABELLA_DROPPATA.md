# SHAMS RMAN: Recovery Tabella Droppata

## Obiettivo operativo

Questa guida recupera una tabella droppata per errore su `M24SHAMS` scegliendo
il metodo meno invasivo:

1. `FLASHBACK TABLE ... TO BEFORE DROP` se la tabella e' ancora nel recycle bin;
2. RMAN `RECOVER TABLE` se il recycle bin non puo' aiutare;
3. clone auxiliary + Data Pump se `RECOVER TABLE` non e' supportato o il caso e'
   troppo rischioso per import diretto.

La priorita' e' non peggiorare l'incidente: prima si raccolgono SCN, timestamp,
dipendenze e oggetti correlati; poi si recupera con rename o schema temporaneo;
solo dopo validazione si rimpiazza l'oggetto applicativo.

## Assessment

### 1. Informazioni da bloccare subito

```sql
SET LINES 220 PAGES 200
SELECT current_scn,
       TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS') AS now_time
FROM v$database;

SELECT name, db_unique_name, database_role, open_mode
FROM v$database;

SHOW PARAMETER recyclebin;
```

Chiedere all'applicazione:

- owner tabella;
- nome tabella;
- ora approssimativa del drop;
- se e' stato usato `PURGE`;
- se ci sono batch che hanno ricreato una tabella con lo stesso nome;
- se servono grants, trigger, indici e constraints come prima.

### 2. Verificare recycle bin

```sql
SELECT owner,
       object_name AS recyclebin_name,
       original_name,
       type,
       droptime,
       can_undrop,
       can_purge,
       space
FROM dba_recyclebin
WHERE owner = UPPER('<OWNER>')
  AND original_name = UPPER('<TABLE_NAME>')
ORDER BY droptime DESC;
```

Se esistono piu' righe per la stessa tabella, recupera usando il nome
`BIN$...`, non solo `original_name`.

Controlla se il nome e' stato rioccupato:

```sql
SELECT owner, object_name, object_type, status, created, last_ddl_time
FROM dba_objects
WHERE owner = UPPER('<OWNER>')
  AND object_name = UPPER('<TABLE_NAME>')
ORDER BY object_type;
```

### 3. Verificare tablespace e dipendenze

```sql
SELECT owner, segment_name, segment_type, tablespace_name, bytes/1024/1024 size_mb
FROM dba_segments
WHERE owner = UPPER('<OWNER>')
  AND segment_name = UPPER('<TABLE_NAME>');

SELECT tablespace_name, contents, status, retention
FROM dba_tablespaces
ORDER BY tablespace_name;

SELECT index_owner, index_name, table_owner, table_name, uniqueness, status
FROM dba_indexes
WHERE table_owner = UPPER('<OWNER>')
  AND table_name = UPPER('<TABLE_NAME>')
ORDER BY index_name;

SELECT owner, constraint_name, constraint_type, table_name, status
FROM dba_constraints
WHERE owner = UPPER('<OWNER>')
  AND table_name = UPPER('<TABLE_NAME>')
ORDER BY constraint_type, constraint_name;

SELECT owner, trigger_name, status
FROM dba_triggers
WHERE table_owner = UPPER('<OWNER>')
  AND table_name = UPPER('<TABLE_NAME>')
ORDER BY trigger_name;

SELECT grantee, privilege, grantable
FROM dba_tab_privs
WHERE owner = UPPER('<OWNER>')
  AND table_name = UPPER('<TABLE_NAME>')
ORDER BY grantee, privilege;
```

## Procedura operativa

### 1. Caso semplice: recycle bin disponibile

Condizioni:

- `recyclebin=on`;
- tabella droppata senza `PURGE`;
- entry presente in `dba_recyclebin`;
- tablespace non ha purgato automaticamente l'oggetto.

Se il nome originale e' libero:

```sql
FLASHBACK TABLE <OWNER>.<TABLE_NAME> TO BEFORE DROP;
```

Se il nome originale e' gia' occupato, recupera con rename:

```sql
FLASHBACK TABLE <OWNER>."<RECYCLEBIN_NAME>" TO BEFORE DROP
  RENAME TO <TABLE_NAME>_RECOVERED;
```

Validazione:

```sql
SELECT COUNT(*) FROM <OWNER>.<TABLE_NAME>;

SELECT owner, object_name, object_type, status
FROM dba_objects
WHERE owner = UPPER('<OWNER>')
  AND object_name LIKE UPPER('<TABLE_NAME>%')
ORDER BY object_type, object_name;
```

Nota: gli indici tornano con nomi da recycle bin. Se l'applicazione richiede
nomi originali, rinominarli dopo verifica.

```sql
SELECT index_name, status
FROM dba_indexes
WHERE table_owner = UPPER('<OWNER>')
  AND table_name = UPPER('<TABLE_NAME>')
ORDER BY index_name;
```

### 2. Caso RMAN `RECOVER TABLE`

Usare quando:

- `DROP TABLE ... PURGE`;
- recycle bin disabilitato;
- entry purgata;
- vuoi recuperare la tabella a un timestamp preciso.

Gate:

- database primary aperto read write;
- backup level 0 disponibile;
- archivelog continui fino al timestamp scelto;
- spazio per auxiliary destination;
- tabella non in `SYS`, `SYSTEM` o `SYSAUX`;
- TDE wallet disponibile se tablespace cifrato.

Precheck RMAN:

```bash
export ORACLE_SID=M24SHAMSPEC
export AUX_DIR=/backup/rman/M24SHAMSPEC/tmp/recover_table_<TABLE_NAME>_$(date +%Y%m%d_%H%M%S)
mkdir -p "$AUX_DIR"
chmod 750 "$AUX_DIR"

rman target / catalog /@RMAN_CATALOG
```

```rman
LIST BACKUP OF DATABASE COMPLETED BEFORE "TO_DATE('<YYYY-MM-DD HH24:MI:SS>','YYYY-MM-DD HH24:MI:SS')";
LIST BACKUP OF ARCHIVELOG FROM TIME "TO_DATE('<YYYY-MM-DD HH24:MI:SS>','YYYY-MM-DD HH24:MI:SS') - 1";
RESTORE DATABASE PREVIEW SUMMARY;
```

Recovery con import diretto e rename sicuro:

```rman
RECOVER TABLE <OWNER>.<TABLE_NAME>
  UNTIL TIME "TO_DATE('<YYYY-MM-DD HH24:MI:SS>','YYYY-MM-DD HH24:MI:SS')"
  AUXILIARY DESTINATION '<AUX_DIR>'
  REMAP TABLE '<OWNER>'.'<TABLE_NAME>':'<TABLE_NAME>_RECOVERED';
```

Perche' usare `REMAP TABLE`: evita di sovrascrivere una tabella ricreata dopo
l'incidente. Prima si confrontano righe e struttura, poi si decide rename o
merge.

Validazione:

```sql
SELECT COUNT(*) AS recovered_rows
FROM <OWNER>.<TABLE_NAME>_RECOVERED;

SELECT column_id, column_name, data_type, data_length, nullable
FROM dba_tab_columns
WHERE owner = UPPER('<OWNER>')
  AND table_name IN (UPPER('<TABLE_NAME>'), UPPER('<TABLE_NAME>_RECOVERED'))
ORDER BY table_name, column_id;

SELECT owner, object_name, object_type, status
FROM dba_objects
WHERE owner = UPPER('<OWNER>')
  AND object_name = UPPER('<TABLE_NAME>_RECOVERED')
ORDER BY object_type;
```

Se la tabella originale non esiste piu' e la recovered e' approvata:

```sql
ALTER TABLE <OWNER>.<TABLE_NAME>_RECOVERED RENAME TO <TABLE_NAME>;
```

Se la tabella originale e' stata ricreata e contiene dati nuovi, non rinominare
alla cieca. Fare merge applicativo o export/import controllato.

### 3. Tablespace condiviso con altri oggetti

Se la tabella condivide il tablespace con molte altre tabelle, non fare
tablespace point-in-time recovery sul database di produzione: rischi di tornare
indietro anche oggetti sani.

Percorso sicuro:

1. creare auxiliary clone fino al timestamp precedente al drop;
2. esportare solo la tabella con Data Pump;
3. importare nel primary con nome temporaneo;
4. confrontare e fare rename/merge.

RMAN prepara auxiliary con `RECOVER TABLE` gia' automatizzato. Se non e'
supportato, usare la guida restore su nuova istanza e recuperare fino al
timestamp:

```rman
RUN {
  SET UNTIL TIME "TO_DATE('<YYYY-MM-DD HH24:MI:SS>','YYYY-MM-DD HH24:MI:SS')";
  RESTORE DATABASE;
  RECOVER DATABASE;
}
```

Aprire il clone:

```sql
ALTER DATABASE OPEN RESETLOGS;
```

Export della sola tabella dal clone:

```bash
expdp system@M24SHAMSREC \
  schemas=<OWNER> \
  tables=<OWNER>.<TABLE_NAME> \
  directory=DATA_PUMP_DIR \
  dumpfile=<TABLE_NAME>_recover_%U.dmp \
  logfile=<TABLE_NAME>_recover_expdp.log
```

Import sul primary con rename:

```bash
impdp system@M24SHAMSPEC \
  directory=DATA_PUMP_DIR \
  dumpfile=<TABLE_NAME>_recover_%U.dmp \
  logfile=<TABLE_NAME>_recover_impdp.log \
  remap_table=<OWNER>.<TABLE_NAME>:<TABLE_NAME>_RECOVERED
```

### 4. Grants, trigger, constraints e statistiche

Dopo recovery verificare oggetti dipendenti.

```sql
SELECT owner, object_name, object_type, status
FROM dba_objects
WHERE owner = UPPER('<OWNER>')
  AND status <> 'VALID'
ORDER BY object_type, object_name;

SELECT grantee, privilege, grantable
FROM dba_tab_privs
WHERE owner = UPPER('<OWNER>')
  AND table_name = UPPER('<TABLE_NAME>')
ORDER BY grantee, privilege;
```

Ricompilare se serve:

```sql
BEGIN
  DBMS_UTILITY.COMPILE_SCHEMA(schema => UPPER('<OWNER>'), compile_all => FALSE);
END;
/
```

Statistiche:

```sql
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => UPPER('<OWNER>'),
    tabname => UPPER('<TABLE_NAME>'),
    cascade => TRUE
  );
END;
/
```

## Validazione finale

Checklist SQL:

```sql
SELECT COUNT(*) FROM <OWNER>.<TABLE_NAME>;

SELECT owner, object_name, object_type, status
FROM dba_objects
WHERE owner = UPPER('<OWNER>')
  AND object_name LIKE UPPER('<TABLE_NAME>%')
ORDER BY object_type, object_name;

SELECT index_name, status
FROM dba_indexes
WHERE table_owner = UPPER('<OWNER>')
  AND table_name = UPPER('<TABLE_NAME>')
ORDER BY index_name;

SELECT constraint_name, constraint_type, status
FROM dba_constraints
WHERE owner = UPPER('<OWNER>')
  AND table_name = UPPER('<TABLE_NAME>')
ORDER BY constraint_type, constraint_name;

SELECT trigger_name, status
FROM dba_triggers
WHERE table_owner = UPPER('<OWNER>')
  AND table_name = UPPER('<TABLE_NAME>')
ORDER BY trigger_name;
```

Checklist RMAN:

```rman
LIST BACKUP SUMMARY;
REPORT NEED BACKUP;
```

Checklist applicativa:

- owner conferma row count o query funzionali;
- grants confermati;
- job applicativi riabilitati solo dopo test;
- export/evidence salvati.

## Pulizia finale

Rimuovere auxiliary destination solo se il recover/import e' chiuso.

```bash
echo "$AUX_DIR"
test -n "$AUX_DIR" &&
test -d "$AUX_DIR" &&
find "$AUX_DIR" -maxdepth 2 -type f -ls
```

Cancellazione controllata:

```bash
test "$AUX_DIR" != "/" &&
test -d "$AUX_DIR" &&
rm -rf -- "$AUX_DIR"
```

Se hai creato tabella temporanea:

```sql
DROP TABLE <OWNER>.<TABLE_NAME>_RECOVERED PURGE;
```

Farlo solo dopo conferma che la tabella finale e' corretta.

Purgare recycle bin solo se richiesto da spazio e dopo change:

```sql
PURGE DBA_RECYCLEBIN;
```

## Troubleshooting rapido

| Errore | Causa probabile | Azione |
| --- | --- | --- |
| `ORA-38305 object not in RECYCLE BIN` | Tabella purgata o recycle bin disabilitato | Passare a RMAN `RECOVER TABLE` |
| `ORA-00942` dopo flashback | Nome recuperato diverso o schema errato | Controllare `dba_recyclebin` e `dba_objects` |
| `RMAN-05026` durante `RECOVER TABLE` | Oggetto/tablespace non supportato | Usare clone auxiliary + Data Pump |
| `RMAN-06054` | Archivelog mancanti fino al timestamp | Scegliere timestamp piu' vecchio o recuperare archivelog |
| `ORA-28365 wallet is not open` | Tablespace cifrato | Aprire/copiare wallet prima di recovery |
| Import crea vincoli invalidi | Dipendenze mancanti o nome remap | Importare anche metadata necessario o ricreare constraint |
| Tabella ricreata dopo drop | Nome originale occupato | Recuperare con `_RECOVERED`, poi merge controllato |
| Tablespace condiviso | TSPITR rischioso su produzione | Non fare TSPITR diretto; usare clone/Data Pump |

## Fonti Oracle

- Flashback Table:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/FLASHBACK-TABLE.html
- Recycle bin e gestione tabelle:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-tables.html
- RMAN flashback e point-in-time recovery:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-performing-flashback-dbpitr.html
- RMAN complete recovery:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-complete-database-recovery.html
