# Cheat Sheet LSNRCTL e Oracle Net

## Quando usarla

- Applicazione non si connette.
- `ORA-12514`, `ORA-12541`, `ORA-12154`, `ORA-12516`.
- Service non registrato.
- RMAN duplicate/Data Guard deve connettersi a istanza `NOMOUNT`.
- TCPS o wallet client/server.

## Comandi base

```bash
lsnrctl status
lsnrctl services
lsnrctl status LISTENER
lsnrctl services LISTENER
tnsping <TNS_ALIAS>
```

In RAC:

```bash
srvctl status listener
srvctl status scan_listener
srvctl status service -d <DB_UNIQUE_NAME>
```

## Lettura output `lsnrctl services`

Cerca:

- protocollo e porta: TCP/1521, TCPS/2484;
- `Service "<service>" has ... instance(s)`;
- stato handler: `READY`, `BLOCKED`, `UNKNOWN`;
- istanza corretta e ruolo corretto;
- static registration per Data Guard/RMAN.

## Parametri database

```sql
show parameter local_listener
show parameter remote_listener
show parameter service_names

select name, network_name, enabled
from dba_services
order by name;

select inst_id, name
from gv$active_services
order by name, inst_id;
```

Forzare registrazione dinamica:

```sql
alter system register;
```

## File Oracle Net

Path tipici:

```bash
echo $TNS_ADMIN
ls -l $ORACLE_HOME/network/admin
ls -l $GRID_HOME/network/admin
```

File:

- `listener.ora`: listener e static registration.
- `tnsnames.ora`: alias client.
- `sqlnet.ora`: naming, wallet, encryption, TCPS.

## Easy Connect

```bash
sqlplus app_user@//dbhost01:1521/APP_RW
sqlplus app_user@//scan-prod.example.com:1521/APP_RW
```

Con SYS:

```bash
sqlplus sys@//dbhost01:1521/SOLE_DGMGRL as sysdba
```

## ORA-12514

Sintomo: listener attivo, ma servizio non conosciuto.

Check:

```bash
lsnrctl services
srvctl status service -d <DB_UNIQUE_NAME>
```

Fix tipici:

```bash
srvctl start service -d <DB_UNIQUE_NAME> -s <SERVICE_NAME>
```

```sql
alter system register;
```

## ORA-12541

Sintomo: no listener.

Check:

```bash
ps -ef | grep tnslsnr
srvctl status listener
lsnrctl status
```

Fix:

```bash
srvctl start listener
srvctl start scan_listener
```

Single node non Grid:

```bash
lsnrctl start
```

## ORA-12154

Sintomo: alias non risolto.

Check:

```bash
echo $TNS_ADMIN
grep -n "<ALIAS>" $TNS_ADMIN/tnsnames.ora
tnsping <ALIAS>
```

Verifica anche `NAMES.DIRECTORY_PATH` in `sqlnet.ora`.

## Static registration Data Guard/RMAN

Serve per connettersi a istanze `NOMOUNT` o gestite dal broker.

Esempio:

```text
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = M24_DGMGRL.example.com)
      (ORACLE_HOME = /u01/app/oracle/product/19c/dbhome_1)
      (SID_NAME = M24)
    )
  )
```

Reload:

```bash
lsnrctl reload
lsnrctl services
```

## TCPS

```bash
grep -n "TCPS\\|WALLET\\|SSL" $TNS_ADMIN/listener.ora $TNS_ADMIN/sqlnet.ora $TNS_ADMIN/tnsnames.ora
orapki wallet display -wallet /path/to/wallet
tnsping APPDB_TCPS
```

Runbook dedicato: [34 TCPS Wallet e Certificati](../02_runbooks_incidenti/34_TCPS_WALLET_CERTIFICATI.md).

## Link collegati

- [26 Listener, SCAN e Services RAC](../02_runbooks_incidenti/26_LISTENER_SCAN_SERVICES_RAC.md)
- [GUIDA_LISTENER_SERVICES_DBA](../../02_core_dba/01_administration_and_security/GUIDA_LISTENER_SERVICES_DBA.md)
- [GUIDA_IDENTITA_ORACLE_E_SERVIZI](../../02_core_dba/01_administration_and_security/GUIDA_IDENTITA_ORACLE_E_SERVIZI.md)
