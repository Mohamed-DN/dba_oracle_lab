# 30 - Multitenant CDB/PDB Operations

<!-- READY_SCRIPTS_START -->
## Script pronti collegati

- [utilities/cdb_pdb](../04_libreria_script_completa/utilities/cdb_pdb/) - query CDB/PDB, PDB violations, AWR PDB, parametri modificabili.
- [GUIDA_CDB_PDB_UTENTI](../../02_core_dba/01_administration_and_security/GUIDA_CDB_PDB_UTENTI.md) - teoria e amministrazione utenti in multitenant.
<!-- READY_SCRIPTS_END -->

## Casi frequenti

- PDB non aperta dopo restart.
- Applicazione punta al service del PDB ma riceve `ORA-12514` o `ORA-01033`.
- Clone PDB per test/preprod.
- Plug/unplug PDB durante migrazione.
- `PDB_PLUG_IN_VIOLATIONS` dopo clone, plug o upgrade.
- Parameter drift: capire se un parametro va cambiato in CDB root o nel PDB.
- AWR a livello PDB non disponibile.

## Regola di sicurezza

Non eseguire operazioni PDB se il database e non-CDB. Prima verifica sempre:

```sql
set lines 200
col name format a20
select name, cdb, open_mode, database_role from v$database;

show con_name
show pdbs
```

Se `CDB = NO`, usa i runbook non-CDB. Se `CDB = YES`, tutte le modifiche devono dichiarare il container corretto.

## Precheck minimo

```sql
set lines 220 pages 200
col name format a30
col open_mode format a20
col restricted format a10
select con_id, name, open_mode, restricted, open_time
from v$pdbs
order by con_id;

select con_id, name, total_size/1024/1024 total_mb
from v$containers
order by con_id;

select name, value, ispdb_modifiable, issys_modifiable
from v$system_parameter
where name in ('sga_target','pga_aggregate_target','optimizer_features_enable','open_cursors','sessions','processes')
order by name;
```

## Aprire o chiudere PDB

Aprire una PDB:

```sql
alter pluggable database APPPDB open read write;
alter pluggable database APPPDB save state;
```

Aprire tutte le PDB:

```sql
alter pluggable database all open;
alter pluggable database all save state;
```

Chiudere una PDB con drain applicativo:

```sql
alter pluggable database APPPDB close immediate;
```

Validazione:

```sql
select name, open_mode, restricted from v$pdbs where name = 'APPPDB';
select name, network_name, pdb from cdb_services where pdb = 'APPPDB';
```

## Service PDB

In RAC usa `srvctl`, non service creati a mano senza ownership Grid.

```bash
srvctl config service -db CDBPROD
srvctl status service -db CDBPROD

srvctl add service -db CDBPROD -service APP_RW -pdb APPPDB \
  -preferred CDBPROD1,CDBPROD2 -role PRIMARY -policy AUTOMATIC

srvctl start service -db CDBPROD -service APP_RW
srvctl status service -db CDBPROD -service APP_RW
```

Test:

```bash
tnsping APP_RW
sqlplus app_user@APP_RW
```

## Clone PDB locale

Precheck:

```sql
select name, open_mode from v$pdbs where name in ('SOURCEPDB','CLONEPDB');
select file_name from cdb_data_files where con_id = (select con_id from v$pdbs where name='SOURCEPDB');
```

Clone:

```sql
alter pluggable database SOURCEPDB close immediate;
alter pluggable database SOURCEPDB open read only;

create pluggable database CLONEPDB from SOURCEPDB
  file_name_convert = ('/oradata/CDBPROD/SOURCEPDB/', '/oradata/CDBPROD/CLONEPDB/');

alter pluggable database CLONEPDB open read write;
alter pluggable database SOURCEPDB close immediate;
alter pluggable database SOURCEPDB open read write;
```

Con ASM/OMF normalmente non usare `file_name_convert` se `db_create_file_dest` e gestito correttamente.

## Unplug / Plug PDB

Unplug:

```sql
alter pluggable database APPPDB close immediate;
alter pluggable database APPPDB unplug into '/backup/pdb/APPPDB.xml';
drop pluggable database APPPDB keep datafiles;
```

Plug con copy:

```sql
create pluggable database APPPDB using '/backup/pdb/APPPDB.xml'
  copy
  file_name_convert = ('/old_path/APPPDB/', '/new_path/APPPDB/');

alter pluggable database APPPDB open read write;
```

Controllo violazioni:

```sql
col message format a100
select name, cause, type, status, message
from pdb_plug_in_violations
where name = 'APPPDB'
order by time;
```

## Parametri: cosa si cambia dove

Regola pratica:

- `processes`, `sga_target`, `db_block_size`, `control_files`: livello istanza/CDB, non PDB.
- `open_cursors`, `optimizer_*`, `nls_*`: spesso modificabili a livello PDB, verificare `ISPDB_MODIFIABLE`.
- `local_listener`, `remote_listener`: livello istanza/RAC.
- Parametri statici richiedono restart; parametri dinamici possono essere applicati subito.

Query:

```sql
select name, value, ispdb_modifiable, issys_modifiable
from v$system_parameter
where lower(name) like lower('%&param%')
order by name;
```

Applicare a PDB:

```sql
alter session set container = APPPDB;
alter system set open_cursors = 1000 scope=both;
```

## AWR per PDB

Verifica:

```sql
alter session set container = APPPDB;
select snap_id, begin_interval_time, end_interval_time
from awr_pdb_snapshot
order by snap_id desc fetch first 10 rows only;
```

Abilitazione tipica:

```sql
alter session set container = APPPDB;
exec dbms_workload_repository.modify_snapshot_settings(interval => 60, retention => 10080);
```

Se non genera snapshot, tornare in root e verificare licenze, `AWR_PDB_AUTOFLUSH_ENABLED`, job MMON e policy aziendale.

## Restore e recovery PDB

Prima scelta: usare RMAN con backup validi e aprire change con impatto applicativo.

```rman
connect target /
list backup of pluggable database APPPDB;
restore pluggable database APPPDB validate;
```

Recovery con PDB chiusa:

```rman
sql "alter pluggable database APPPDB close immediate";
restore pluggable database APPPDB;
recover pluggable database APPPDB;
sql "alter pluggable database APPPDB open";
```

## Evidence ticket

```text
DB/CDB:
PDB:
Operazione:
Container usato:
Service coinvolti:
Precheck:
Comandi eseguiti:
Output show pdbs prima/dopo:
Violazioni PDB:
Validazione applicativa:
Rollback:
```
