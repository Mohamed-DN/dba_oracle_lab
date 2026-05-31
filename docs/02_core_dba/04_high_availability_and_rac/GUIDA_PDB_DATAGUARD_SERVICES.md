# Extra DBA - PDB, Data Guard, Services e Listener

## Obiettivo operativo

Gestire servizi PDB coerenti con i ruoli Data Guard e con il routing applicativo.

## Procedura operativa

Definisci service role-aware, prova apertura PDB e connessioni prima e dopo una role transition.

## Validazione finale

Conferma service placement, open mode PDB e login applicativo.

## Troubleshooting rapido

Per `ORA-12514`, verifica registrazione, service name e stato della PDB sul ruolo corrente.


> Guida operativa per testare la propagazione di un PDB dal primary al physical standby e per pubblicare servizi RAC corretti lato primary e, se vuoi Active Data Guard, lato standby.

## Quando farla

Esegui questa guida:

1. dopo (GUIDA_FASE4_DATAGUARD_DGMGRL.md), scenario consigliato;
2. oppure subito dopo la Fase 3 solo se Data Guard manuale e stabile.

Scenario raccomandato:

- primary `RACDB` aperto `READ WRITE`
- standby `RACDB_STBY` in `PHYSICAL STANDBY`
- `MRP0` attivo su `racstby1`
- `DEST_ID=2` valido sul primary
- Broker `SUCCESS`

## Obiettivo

Convalidare tre cose:

1. un PDB creato sul primary compare automaticamente sullo standby;
2. il servizio applicativo del PDB si pubblica correttamente sul listener RAC del primary;
3. opzionalmente, se abiliti Active Data Guard, puoi pubblicare un servizio read-only dedicato anche sullo standby.

## 1. Pre-check obbligatori

Sul primary:

```sql
sqlplus / as sysdba

SELECT name, open_mode, database_role, db_unique_name
FROM   v$database;

SELECT dest_id, status, error
FROM   v$archive_dest
WHERE  dest_id = 2;
```

Sul standby:

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
- standby `MOUNTED`, ruolo `PHYSICAL STANDBY`
- `MRP0` presente su `racstby1`
- `DEST_ID=2` `VALID` e senza errore

Nota:

- in RAC standby e' normale vedere `MRP0` su una sola istanza;
- non aspettarti `MRP0` su `racstby2` come requisito di successo.

## 2. Test base: verifica il PDB creato da DBCA

La baseline della Fase 2 crea già `RACDBPDB` con DBCA. Verifica prima che sia
presente e aperto su tutte le istanze:

```sql
sqlplus / as sysdba

SELECT name, open_mode
FROM   v$pdbs
WHERE  name = 'RACDBPDB';

ALTER PLUGGABLE DATABASE RACDBPDB OPEN INSTANCES=ALL;
ALTER PLUGGABLE DATABASE RACDBPDB SAVE STATE INSTANCES=ALL;
```

Solo su un ambiente costruito prima dell'allineamento DBCA, se `RACDBPDB` non
esiste, crealo dal seed con `STANDBYS=ALL`. Inserisci la password nel prompt
SQL*Plus e non salvarla nello script:

```sql
sqlplus / as sysdba

SHOW CON_NAME
ACCEPT pdb_admin_password CHAR PROMPT 'Password PDBADMIN: ' HIDE

CREATE PLUGGABLE DATABASE RACDBPDB
  ADMIN USER pdbadmin IDENTIFIED BY "&pdb_admin_password"
  STANDBYS=ALL;

ALTER PLUGGABLE DATABASE RACDBPDB OPEN INSTANCES=ALL;
ALTER PLUGGABLE DATABASE RACDBPDB SAVE STATE INSTANCES=ALL;
UNDEFINE pdb_admin_password

SELECT name, open_mode
FROM   v$pdbs
WHERE  name = 'RACDBPDB';
```

Perche' questo caso e' corretto nel tuo lab:

- il lab usa ASM/OMF;
- il primary e lo standby hanno `db_create_file_dest` e FRA in ASM;
- il redo apply puo' materializzare il nuovo PDB senza dover fare clone manuali sullo standby.

## 3. Forza il redo e aspetta la propagazione

Sul primary:

```sql
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM ARCHIVE LOG CURRENT;
```

Aspetta 20-60 secondi, poi controlla sullo standby:

```sql
sqlplus / as sysdba

SELECT process, status, thread#, sequence#
FROM   v$managed_standby
WHERE  process IN ('MRP0','RFS');

SELECT con_id, name, open_mode
FROM   v$pdbs
WHERE  name = 'RACDBPDB';
```

Atteso:

- `RACDBPDB` esiste sullo standby;
- lo standby resta `MOUNTED`;
- `MRP0` continua in `APPLYING_LOG` oppure `WAIT_FOR_LOG`.

Regola pratica:

- se il PDB non compare subito, guarda prima `MRP0`, `transport lag`, `apply lag`;
- non creare il PDB a mano sullo standby.

## 4. Test di propagazione oggetti dentro il PDB

Quando `RACDBPDB` esiste su entrambi i lati, testa una modifica reale.

Sul primary:

```sql
sqlplus / as sysdba

ALTER SESSION SET CONTAINER=RACDBPDB;

CREATE TABLESPACE racdbpdb_ts DATAFILE SIZE 100M AUTOEXTEND ON NEXT 50M;

ACCEPT app1_password CHAR PROMPT 'Password APP1: ' HIDE
CREATE USER app1 IDENTIFIED BY "&app1_password";
UNDEFINE app1_password
GRANT CONNECT, RESOURCE TO app1;

CREATE TABLE app1.t1 (id NUMBER PRIMARY KEY, note VARCHAR2(100));
INSERT INTO app1.t1 VALUES (1, 'DG_PDB_TEST');
COMMIT;

ALTER SYSTEM ARCHIVE LOG CURRENT;
```

Sullo standby:

```sql
sqlplus / as sysdba

SELECT process, status, thread#, sequence#
FROM   v$managed_standby
WHERE  process IN ('MRP0','RFS');
```

Se in futuro apri lo standby in `READ ONLY WITH APPLY`, potrai verificare direttamente anche il contenuto del PDB con query SQL.

## 5. Pubblicare un servizio RAC per il PDB sul primary

Per le applicazioni non usare il service di default del CDB. Crea un service dedicato al PDB.

Sul primary, come `oracle`:

```bash
. ~/.db_env

srvctl add service -d RACDB \
  -s racdbpdb_pry \
  -pdb RACDBPDB \
  -preferred RACDB1,RACDB2 \
  -role PRIMARY \
  -policy AUTOMATIC

srvctl start service -d RACDB -s racdbpdb_pry
srvctl status service -d RACDB -s racdbpdb_pry
srvctl config service -d RACDB -s racdbpdb_pry
```

Perche' cosi':

- `-pdb RACDBPDB` lega il service al PDB corretto;
- `-role PRIMARY` evita che il service si presenti sullo standby;
- `-preferred RACDB1,RACDB2` lo rende disponibile su entrambe le istanze RAC del primary.

## 6. Verifica listener e registrazione del service

Sul primary:

```bash
lsnrctl status
srvctl status service -d RACDB -s racdbpdb_pry
```

Se vuoi anche il test TNS, aggiungi nel `tnsnames.ora`:

```ini
RACDBPDB_PRY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = racdbpdb_pry)
    )
  )
```

Poi prova:

```bash
tnsping RACDBPDB_PRY
sqlplus pdbadmin@RACDBPDB_PRY
```

## 7. Servizio lato standby: farlo solo se usi Active Data Guard

Se lo standby e' ancora in `MOUNTED`, non creare ancora un servizio applicativo read-only per il PDB. Prima ti serve Active Data Guard.

Quando avrai lo standby in `READ ONLY WITH APPLY`, potrai creare un service dedicato:

```bash
srvctl add service -d RACDB_STBY \
  -s racdbpdb_ro \
  -pdb RACDBPDB \
  -preferred RACDB1,RACDB2 \
  -role PHYSICAL_STANDBY \
  -policy AUTOMATIC

srvctl start service -d RACDB_STBY -s racdbpdb_ro
srvctl status service -d RACDB_STBY -s racdbpdb_ro
```

Alias TNS di esempio:

```ini
RACDBPDB_RO =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = racstby-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = racdbpdb_ro)
    )
  )
```

## 8. Casi avanzati da testare dopo il caso base

Quando il test base funziona, prova in quest'ordine:

1. nuovo tablespace nel PDB;
2. nuovo utente/schema nel PDB;
3. service `PRIMARY` con stop/start e failover applicativo;
4. switchover Broker e verifica del comportamento dei service;
5. Active Data Guard con service `PHYSICAL_STANDBY`;
6. TDE nel PDB;
7. clone di PDB con requisiti Data Guard piu avanzati.

## 9. Troubleshooting mirato

### Il PDB non compare sullo standby

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
- PDB creato con opzioni non supportate dal tuo stato standby.

### Il service del PDB non si registra

Controlla:

```bash
srvctl config service -d RACDB -s racdbpdb_pry
srvctl status service -d RACDB -s racdbpdb_pry
lsnrctl status
```

Cause tipiche:

- PDB non aperto sul primary;
- service creato senza `-pdb`;
- service creato sul database sbagliato;
- ruolo non coerente (`PRIMARY` vs `PHYSICAL_STANDBY`);
- listener non aggiornato o service fermo.

### ORA-12514 sul service PDB

Cause tipiche:

- il service non e' partito;
- il listener SCAN non ha ancora registrato il service;
- stai usando un `SERVICE_NAME` diverso da quello creato con `srvctl`.

## 10. Criteri di successo

Considera il test riuscito se:

1. `RACDBPDB` esiste sul primary e sullo standby;
2. `MRP0` continua a lavorare su `racstby1`;
3. il service `racdbpdb_pry` risulta registrato e raggiungibile sul primary;
4. dopo log switch, il redo apply continua senza errori;
5. il listener mostra il service corretto.

## Riferimenti Oracle

- Oracle SQL Reference, `CREATE PLUGGABLE DATABASE` (`STANDBYS=ALL`)
- Oracle Data Guard Concepts and Administration, gestione PDB con Data Guard
- Oracle RAC Administration Guide, `srvctl add service -pdb`
