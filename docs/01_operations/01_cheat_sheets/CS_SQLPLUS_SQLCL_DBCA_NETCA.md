# Cheat Sheet SQLPlus, SQLcl, DBCA e NETCA

## SQLPlus: connessione

Locale OS authentication:

```bash
sqlplus / as sysdba
sqlplus / as sysasm
```

Remota:

```bash
sqlplus system@//host:1521/service
sqlplus sys@//host:1521/service as sysdba
```

Prompt utile:

```sql
set sqlprompt "_user'@'_connect_identifier> "
```

## SQLPlus: set standard DBA

```sql
set lines 220 pages 200 trimspool on tab off
set long 100000 longchunksize 100000
column name format a30
column value format a80
set timing on
set serveroutput on
```

Spool:

```sql
spool /tmp/evidence_&&_connect_identifier..log
select systimestamp from dual;
spool off
```

Error handling per script:

```sql
whenever sqlerror exit sql.sqlcode
whenever oserror exit failure
```

## SQLPlus: startup/shutdown

```sql
startup
startup mount
startup nomount
shutdown immediate
shutdown transactional
shutdown abort
```

Regola:

- `immediate`: standard manutenzione.
- `transactional`: aspetta fine transazioni, se possibile.
- `abort`: solo emergenza, poi serve crash recovery allo startup.

## SQLPlus: diagnosi rapida

```sql
select name, open_mode, database_role from v$database;
select inst_id, instance_name, status, host_name from gv$instance order by inst_id;
show parameter spfile
show parameter control_files
show parameter service_names
```

PDB:

```sql
show con_name
show pdbs
alter session set container = <PDB_NAME>;
```

## SQLcl

SQLcl e piu comodo per output moderno, history e scripting.

```bash
sql / as sysdba
sql system@//host:1521/service
```

Comandi utili:

```sql
info <object>
ddl <object>
set sqlformat ansiconsole
set sqlformat csv
history
```

## DBCA: uso grafico e silent

GUI:

```bash
dbca
```

Lista template:

```bash
dbca -silent -listTemplates
```

Creazione database non-CDB esempio:

```bash
dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -gdbname SOLE \
  -sid SOLE \
  -createAsContainerDatabase false \
  -characterSet AL32UTF8 \
  -nationalCharacterSet AL16UTF16 \
  -memoryMgmtType auto_sga \
  -totalMemory 8192 \
  -emConfiguration NONE \
  -datafileDestination +DATA \
  -recoveryAreaDestination +FRA \
  -recoveryAreaSize 102400 \
  -responseFile /secure/dbca-secrets.rsp
```

Il response file contiene i secret richiesti da DBCA: crealo fuori dal repository,
proteggilo con `chmod 600` e rimuovilo al termine.

Eliminazione database, alto impatto:

```bash
dbca -deleteDatabase -sourceDB SOLE
```

Senza `-silent`, DBCA chiede interattivamente le credenziali necessarie.

## DBCA: cosa verificare prima

```bash
echo $ORACLE_HOME
echo $ORACLE_BASE
which dbca
lsnrctl status
srvctl status listener
```

SQL su DB sorgente se stai clonando:

```sql
select name, cdb, db_unique_name, platform_name from v$database;
select name, value, isdefault, issys_modifiable from v$parameter order by name;
select comp_id, comp_name, status from dba_registry order by comp_id;
select property_name, property_value from database_properties order by property_name;
```

## NETCA

GUI:

```bash
netca
```

Silent listener:

```bash
netca -silent -responsefile $ORACLE_HOME/assistants/netca/netca.rsp
```

Verifica:

```bash
lsnrctl status
lsnrctl services
```

## File di log

DBCA:

```bash
ls -ltr $ORACLE_BASE/cfgtoollogs/dbca
```

NETCA:

```bash
ls -ltr $ORACLE_BASE/cfgtoollogs/netca
```

SQLPlus script:

```bash
echo $?
```

## Tool collegati

- [LSNRCTL e Oracle Net](./CS_LSNRCTL_NET.md)
- [SRVCTL/CRSCTL](./CS_SRVCTL_CRSCTL.md)
- [Produzione Single Node Data Guard Non-CDB](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md)
- [Produzione RAC Data Guard Non-CDB](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md)
