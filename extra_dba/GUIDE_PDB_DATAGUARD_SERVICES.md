# Extra DBA - PDB, Data Guard, Services and Listener

> Operational guide to test the propagation of a PDB from primary to physical standby and to publish correct RAC services on the primary side and, if you want Active Data Guard, on the standby side.

## Quando farla

Run this guide:

1. after [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](../GUIDE_PHASE4_DATAGUARD_DGMGRL.md), recommended scenario;
2. or immediately after Phase 3 only if Data Guard is manual and stable.

Scenario raccomandato:

- primary `RACDB` aperto `READ WRITE`
- standby `RACDB_STBY` to `PHYSICAL STANDBY`
- `MRP0` attivo su `racstby1`
- `DEST_ID=2` valid on primary
- Broker `SUCCESS`

## Obiettivo

Convalidare tre cose:

1. a PDB created on the primary automatically appears on the standby;
2. the PDB application service is published correctly on the primary's RAC listener;
3. optionally, if you enable Active Data Guard, you can publish a dedicated read-only service on standby as well.

## 1. Pre-check obbligatori

On primary:

```sql
sqlplus / as sysdba

SELECT name, open_mode, database_role, db_unique_name
FROM   v$database;

SELECT dest_id, status, error
FROM   v$archive_dest
WHERE  dest_id = 2;
```

On standby:

```sql
sqlplus / as sysdba

SELECT name, open_mode, database_role, db_unique_name
FROM   v$database;

SELECT process, status, thread#, sequence#
FROM   v$managed_standby
WHERE  process IN ('MRP0','RFS');

SELECT name, value, unit
FROM   v$dataguard_stats
WHERE  name IN ('transport lag','apply lag','apply finish time');
```

Criteri minimi:

- primary `READ WRITE`, ruolo `PRIMARY`
- standby `MOUNTED`, role `PHYSICAL STANDBY`
- `MRP0` presente su `racstby1`
- `DEST_ID=2` `VALID` and without error

Nota:

- in RAC standby it is normal to see `MRP0` on only one instance;
- don't expect `MRP0` over `racstby2` as a success requirement.

## 2. Basic test: Create a PDB from the seed with replication on the standby

Per il primo test usa il caso piu semplice:

- `CREATE PLUGGABLE DATABASE ... FROM PDB$SEED`
- `STANDBYS=ALL`

Don't use yet:

- clone da altro PDB
- XML unplug/plug
- clone remoto
- TDE

On the primary, from `CDB$ROOT`:

```sql
sqlplus / as sysdba

SHOW CON_NAME;

CREATE PLUGGABLE DATABASE LABPDB1
  ADMIN USER pdbadmin IDENTIFIED BY "LabPdb_1234"
  STANDBYS=ALL;

ALTER PLUGGABLE DATABASE LABPDB1 OPEN INSTANCES=ALL;
ALTER PLUGGABLE DATABASE LABPDB1 SAVE STATE INSTANCES=ALL;

SELECT name, open_mode
FROM   v$pdbs
WHERE  name = 'LABPDB1';
```

Why this case is correct in your lab:

- il lab usa ASM/OMF;
- the primary and standby have `db_create_file_dest` and FRA in ASM;
- redo apply can materialize the new PDB without having to do manual clones on standby.

## 3. Forza il redo e aspetta la propagazione

On primary:

```sql
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM ARCHIVE LOG CURRENT;
```

Wait 20-60 seconds, then check on standby:

```sql
sqlplus / as sysdba

SELECT process, status, thread#, sequence#
FROM   v$managed_standby
WHERE  process IN ('MRP0','RFS');

SELECT con_id, name, open_mode
FROM   v$pdbs
WHERE  name = 'LABPDB1';
```

Atteso:

- `LABPDB1` exists on standby;
- standby remains `MOUNTED`;
- `MRP0` continua in `APPLYING_LOG` oppure `WAIT_FOR_LOG`.

Regola pratica:

- if the PDB does not appear immediately, first look at `MRP0`, `transport lag`, `apply lag`;
- do not create the PDB by hand on standby.

## 4. Test di propagazione oggetti dentro il PDB

Quando `LABPDB1` esiste su entrambi i lati, testa una modifica reale.

On primary:

```sql
sqlplus / as sysdba

ALTER SESSION SET CONTAINER=LABPDB1;

CREATE TABLESPACE labpdb1_ts DATAFILE SIZE 100M AUTOEXTEND ON NEXT 50M;

CREATE USER app1 IDENTIFIED BY "App1_1234";
GRANT CONNECT, RESOURCE TO app1;

CREATE TABLE app1.t1 (id NUMBER PRIMARY KEY, note VARCHAR2(100));
INSERT INTO app1.t1 VALUES (1, 'DG_PDB_TEST');
COMMIT;

ALTER SYSTEM ARCHIVE LOG CURRENT;
```

On standby:

```sql
sqlplus / as sysdba

SELECT process, status, thread#, sequence#
FROM   v$managed_standby
WHERE  process IN ('MRP0','RFS');
```

If you open the standby in `READ ONLY WITH APPLY` in the future, you will also be able to directly check the contents of the PDB with SQL queries.

## 5. Publish a RAC service for the PDB on the primary

Per le applicazioni non usare il service di default del CDB. Crea un service dedicato al PDB.

On the primary, like `oracle`:

```bash
. ~/.db_env

srvctl add service -d RACDB \
  -s labpdb1_rw \
  -pdb LABPDB1 \
  -preferred RACDB1,RACDB2 \
  -role PRIMARY \
  -policy AUTOMATIC

srvctl start service -d RACDB -s labpdb1_rw
srvctl status service -d RACDB -s labpdb1_rw
srvctl config service -d RACDB -s labpdb1_rw
```

Why like this:

- `-pdb LABPDB1` lega il service al PDB corretto;
- `-role PRIMARY` prevents the service from appearing on standby;
- `-preferred RACDB1,RACDB2` lo rende disponibile su entrambe le istanze RAC del primary.

## 6. Verify listener and service registration

On primary:

```bash
lsnrctl status
srvctl status service -d RACDB -s labpdb1_rw
```

If you also want the TNS test, add in `tnsnames.ora`:

```ini
LABPDB1_RW =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = labpdb1_rw)
    )
  )
```

Poi prova:

```bash
tnsping LABPDB1_RW
sqlplus pdbadmin/LabPdb_1234@LABPDB1_RW
```

## 7. Standby side service: Do this only if you use Active Data Guard

If the standby is still in `MOUNTED`, do not create a read-only application service for the PDB yet. First you need Active Data Guard.

When you have standby in `READ ONLY WITH APPLY`, you can create a dedicated service:

```bash
srvctl add service -d RACDB_STBY \
  -s labpdb1_ro \
  -pdb LABPDB1 \
  -preferred RACDB1,RACDB2 \
  -role PHYSICAL_STANDBY \
  -policy AUTOMATIC

srvctl start service -d RACDB_STBY -s labpdb1_ro
srvctl status service -d RACDB_STBY -s labpdb1_ro
```

Example TNS alias:

```ini
LABPDB1_RO =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = racstby-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = labpdb1_ro)
    )
  )
```

## 8. Advanced cases to be tested after the base case

Quando il test base funziona, prova in quest'ordine:

1. new tablespace in PDB;
2. new user/schema in PDB;
3. service `PRIMARY` with stop/start and application failover;
4. Broker switchover and verification of service behavior;
5. Active Data Guard with service `PHYSICAL_STANDBY`;
6. TDE nel PDB;
7. PDB clone with more advanced Data Guard requirements.

## 9. Troubleshooting mirato

### The PDB does not appear on standby

Controlla:

```sql
SELECT process, status, thread#, sequence#
FROM   v$managed_standby
WHERE  process IN ('MRP0','RFS');

SELECT name, value, unit
FROM   v$dataguard_stats
WHERE  name IN ('transport lag','apply lag','apply finish time');
```

Cause tipiche:

- `MRP0` fermo;
- errore su `DEST_ID=2` lato primary;
- file create problem in ASM;
- PDB created with options not supported by your standby state.

### Il service del PDB non si registra

Controlla:

```bash
srvctl config service -d RACDB -s labpdb1_rw
srvctl status service -d RACDB -s labpdb1_rw
lsnrctl status
```

Cause tipiche:

- PDB not open on primary;
- service created without `-pdb`;
- service created on wrong database;
- ruolo non coerente (`PRIMARY` vs `PHYSICAL_STANDBY`);
- listener not updated or service stopped.

### ORA-12514 on the service PDB

Cause tipiche:

- il service non e' partito;
- the SCAN listener has not yet registered the service;
- you are using a different `SERVICE_NAME` than the one created with `srvctl`.

## 10. Criteri di successo

Considera il test riuscito se:

1. `LABPDB1` exists on primary and standby;
2. `MRP0` continua a lavorare su `racstby1`;
3. the `labpdb1_rw` service is registered and reachable on the primary;
4. after log switch, redo apply continues without errors;
5. the listener shows the correct service.

## Riferimenti Oracle

- Oracle SQL Reference, `CREATE PLUGGABLE DATABASE` (`STANDBYS=ALL`)
- Oracle Data Guard Concepts and Administration, PDB management with Data Guard
- Oracle RAC Administration Guide, `srvctl add service -pdb`
