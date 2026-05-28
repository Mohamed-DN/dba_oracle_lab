# 26 - Listener, SCAN e Services RAC

## Casi piu frequenti

- Applicazione riceve `ORA-12514`, `ORA-12541`, `ORA-12154`, `ORA-12516`.
- Service non registrato sul listener.
- SCAN listener non raggiungibile.
- Connessioni vanno sul nodo sbagliato o non bilanciano.
- Dopo switchover il servizio applicativo resta sul vecchio primary.
- RMAN duplicate/Data Guard non raggiunge istanza in `NOMOUNT` o `MOUNT`.

## Regola operativa

Se il database e `OPEN` ma l'applicazione non entra, non e automaticamente un problema database. Verifica listener, service name, registrazione dinamica, SCAN, TNS e firewall.

## Triage rapido

Come `grid` o `oracle` secondo standard:

```bash
srvctl status listener
srvctl status scan
srvctl status scan_listener
srvctl status database -d <DB_UNIQUE_NAME> -v
srvctl status service -d <DB_UNIQUE_NAME>
lsnrctl status
lsnrctl services
tnsping <TNS_ALIAS>
```

Da SQL:

```sql
SELECT name, open_mode, database_role FROM v$database;

SELECT inst_id, instance_name, host_name, status
FROM gv$instance
ORDER BY inst_id;

SELECT name, network_name, enabled
FROM dba_services
ORDER BY name;

SHOW PARAMETER local_listener
SHOW PARAMETER remote_listener
SHOW PARAMETER service_names
```

## ORA-12514 - listener does not know service

Cause tipiche:

- service name errato nel TNS/JDBC;
- DB non aperto o istanza non registrata;
- `LOCAL_LISTENER`/`REMOTE_LISTENER` errati;
- service gestito da `srvctl` non avviato;
- standby in `MOUNT` senza static registration.

Fix:

```bash
srvctl status service -d <DB_UNIQUE_NAME>
srvctl start service -d <DB_UNIQUE_NAME> -s <SERVICE_NAME>
lsnrctl services
```

Forza registrazione dinamica:

```sql
ALTER SYSTEM REGISTER;
```

## ORA-12541 - no listener

Verifica:

```bash
ps -ef | grep tnslsnr
srvctl status listener
srvctl start listener
lsnrctl status
```

Se SCAN:

```bash
srvctl status scan_listener
srvctl start scan_listener
srvctl status scan
```

## ORA-12154 - could not resolve connect identifier

Verifica client/server:

```bash
echo $TNS_ADMIN
cat $ORACLE_HOME/network/admin/tnsnames.ora
tnsping <ALIAS>
```

Controlla differenza tra:

```text
SERVICE_NAME = servizio logico
SID          = istanza
HOST         = VIP/SCAN/hostname
PORT         = listener
```

## Service role-based per RAC/Data Guard

Esempio:

```bash
srvctl add service -d SOLE -s SOLE_RW \
  -preferred SOLE1,SOLE2 \
  -role PRIMARY \
  -policy AUTOMATIC

srvctl add service -d M24 -s M24_RO \
  -preferred M241,M242 \
  -role PHYSICAL_STANDBY \
  -policy AUTOMATIC
```

Controllo:

```bash
srvctl config service -d SOLE
srvctl status service -d SOLE
srvctl config service -d M24
srvctl status service -d M24
```

## Static registration per Data Guard/RMAN duplicate

Serve quando l'istanza e `NOMOUNT` o `MOUNT`.

Esempio `listener.ora`:

```text
SID_LIST_LISTENER_DG =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = M24_DG)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = M24)
    )
  )
```

Reload:

```bash
lsnrctl reload LISTENER_DG
lsnrctl services LISTENER_DG
```

## Validazione finale

```bash
tnsping <APP_ALIAS>
sqlplus app_user@<APP_ALIAS>
sqlplus sys@<DG_ALIAS> as sysdba
lsnrctl services
```

RAC:

```bash
srvctl status service -d <DB_UNIQUE_NAME>
crsctl stat res -t
```

## Cosa non fare

- Non modificare `listener.ora` gestito da Grid senza sapere cosa governa CRS.
- Non usare SID al posto di SERVICE_NAME per applicazioni moderne.
- Non lasciare servizi RW attivi sullo standby dopo switchover/failover.
- Non confondere porta applicativa e porta dedicata Data Guard.

## Evidence ticket

```text
Errore client:
Alias TNS/JDBC:
Host/porta:
Service richiesto:
Output lsnrctl services:
Output srvctl status service:
Fix applicato:
Smoke test:
```
