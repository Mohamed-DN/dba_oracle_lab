# PHASE 5: Oracle GoldenGate to Target Local or OCI

> In this phase we configure GoldenGate in a manner consistent with the real lab. The basic and supported choice is this: `Integrated Extract sul primary RACDB`, Data Pump verso target, Replicat sul target. Data Guard resta la tua piattaforma di DR e HA, non il punto di capture predefinito per GoldenGate.

---

## 5.0 Architectural Decision Before You Go

Oracle documentation imposes a clear distinction.

### Percorso base del repo

- `source capture`: `RACDB` primary
- `capture mode`: `Integrated Extract`
- `transport`: Data Pump GoldenGate
- `target`: `dbtarget` locale oppure OCI compute target
- `Data Guard`: continues to protect the source, but is not the base capture point

### Because I corrected the flow

Nel draft precedente il lab assumeva `Integrated Extract` on Active Data Guard standby. This is not the base path supported by Oracle.

Key technical points:

- `Integrated Extract` does not capture from a physical standby;
- `GoldenGate Free`this is not the correct path for the RAC 19c + main DG lab;
- the OCI free target must be separated from the enterprise/licensed path.

Pragmatic conclusion:

- Phase 5 base = capture on primary;
- variants with offload from redo or standby = advanced section, not main stream.

Schema:

```text
PRIMARY RAC (RACDB)
     |
     | Integrated Extract
     v
  Local Trail
     |
     | Data Pump
     v
TARGET
  - dbtarget locale
  - OCI compute target

Data Guard continues in parallel as DR.
```

---

## 5.0A Entry from Phase 4 (mandatory check)

GoldenGate only makes sense if Phase 4 is stable.

```bash
dgmgrl sys/<password>@RACDB
SHOW CONFIGURATION;
SHOW DATABASE RACDB;
SHOW DATABASE RACDB_STBY;
```

```sql
sqlplus / as sysdba
SELECT name, open_mode, database_role, db_unique_name FROM v$database;
SELECT force_logging, supplemental_log_data_min FROM v$database;
```

Criteri minimi:

- Broker `SUCCESS` o warning gia compresi;
- primary `READ WRITE` e ruolo `PRIMARY`;
- healthy standby and active apply;
- stable source before touching GoldenGate.

If Phase 4 is not closed, return to [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](./GUIDE_PHASE4_DATAGUARD_DGMGRL.md).

---

## 5.0B Choose Target: Local or OCI

### Opzione 1 - `dbtarget` locale

Usala se vuoi:

- reduce network variables;
- learn GoldenGate before the cloud;
- avere debug piu semplice.

### Option 2 - target OCI compute

Usala se vuoi:

- learn a local -> cloud migration;
- train on listener, network, NSG and remote target.

Before using OCI read:

- [GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md](./GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md)
- [GUIDE_GOLDENGATE_OCI_ARM.md](./GUIDE_GOLDENGATE_OCI_ARM.md)

---

## 5.1 Network and Naming

Whatever target you choose, the source must resolve and reach the target.

### For the local target

Assumi `dbtarget.localdomain`reachable from`rac1`.

### Per il target OCI

Assumi `dbtarget.localdomain` o `dbtarget`pointed to the correct IP in the file`/etc/hosts`or in the DNS used by the lab.

Tests required by`rac1`:

```bash
ping dbtarget
nc -vz dbtarget 1521
# se target GG classic/core
nc -vz dbtarget 7809
# se target GG microservices
nc -vz dbtarget 9011
nc -vz dbtarget 9014
tnsping DBTARGET
```

Se questi test falliscono, non partire con GG.

---

## 5.2 Supported Lab Architecture

Flusso base:

```text
rac1/rac2 (PRIMARY RACDB)
   |
   | Integrated Extract on primary
   v
Local trail
   |
   | Pump
   v
Target DB
   |
   +--> locale
   +--> OCI compute
```

Why primary is the right default:

- is the most linear and supported Oracle path for`Integrated Extract`;
- riduce ambiguita con Active Data Guard;
- simplifies troubleshooting and initialization.

---

## 5.3 Prerequisiti Database sul Source

Sul primary `RACDB`:

```sql
sqlplus / as sysdba

ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH SID='*';
ALTER DATABASE FORCE LOGGING;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

SELECT force_logging,
supplemental_log_data_min,
supplemental_log_data_all
FROM   v$database;
```

Atteso:

- `FORCE_LOGGING = YES`
- `SUPPLEMENTAL_LOG_DATA_MIN = YES`
- `SUPPLEMENTAL_LOG_DATA_ALL = YES`

Nota:

- `FORCE LOGGING`and important for Data Guard and GoldenGate, to avoid unlogged redo holes.

---

## 5.4 Target prerequisites

Sul target Oracle:

```sql
sqlplus / as sysdba
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
```

If the target is multitenant:

- create or choose the target PDB;
- define a dedicated service;
- check listener e `tnsping`.

---

## 5.5 GoldenGate User Creation

### Sul source

```sql
sqlplus / as sysdba

CREATE USER ggadmin IDENTIFIED BY <password>
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION, RESOURCE, ALTER SESSION TO ggadmin;
GRANT SELECT ANY DICTIONARY TO ggadmin;
GRANT SELECT ANY TABLE TO ggadmin;
GRANT FLASHBACK ANY TABLE TO ggadmin;
GRANT EXECUTE ON DBMS_LOCK TO ggadmin;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');
```

### Sul target

```sql
sqlplus / as sysdba

CREATE USER ggadmin IDENTIFIED BY <password>
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION, RESOURCE, ALTER SESSION TO ggadmin;
GRANT SELECT ANY DICTIONARY TO ggadmin;
GRANT DBA TO ggadmin;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');
```

In the lab it's okay to be liberal with privileges. In production you narrow them down.

---

## 5.6 Installazione Software GoldenGate

### Sul source

Install GoldenGate on the node you will be running the Extract from, typically `rac1`.

Example path:

```bash
mkdir -p /u01/app/goldengate
chown oracle:oinstall /u01/app/goldengate
```

Then install the GoldenGate software consistent with the source database.

### Sul target

- if target local: install GoldenGate on the target server;
- se target OCI: segui [GUIDE_GOLDENGATE_OCI_ARM.md](./GUIDE_GOLDENGATE_OCI_ARM.md) to understand if you are using a target`free validation`or a target truly consistent with the main lab.

### Environment variables

```bash
cat >> /home/oracle/.bash_profile <<'EOF'
export OGG_HOME=/u01/app/goldengate/ogg
export PATH=$OGG_HOME:$PATH
export LD_LIBRARY_PATH=$OGG_HOME/lib:$ORACLE_HOME/lib:$LD_LIBRARY_PATH
EOF

source /home/oracle/.bash_profile
```

---

## 5.7 Manager Configuration

### Sul source

```bash
cd $OGG_HOME
./ggsci
```

```text
GGSCI> CREATE SUBDIRS
GGSCI> EDIT PARAMS MGR
```

Example parameters:

```text
PORT 7809
DYNAMICPORTLIST 7810-7820
AUTORESTART EXTRACT *, RETRIES 3, WAITMINUTES 5, RESETMINUTES 60
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPHOURS 24
```

```text
GGSCI> START MGR
GGSCI> INFO MGR
```

### Sul target

Manager analogo, adattando `AUTORESTART REPLICAT *`.

---

## 5.8 Extract configuration on the Primary

### 5.8.1 Login and registration

Su `rac1` as `oracle`:

```bash
cd $OGG_HOME
./ggsci
```

```text
GGSCI> DBLOGIN USERID ggadmin PASSWORD <password>
GGSCI> REGISTER EXTRACT ext_rac DATABASE
GGSCI> ADD EXTRACT ext_rac, INTEGRATED TRANLOG, BEGIN NOW
GGSCI> ADD EXTTRAIL ./dirdat/er, EXTRACT ext_rac, MEGABYTES 200
```

### 5.8.2 Parametri Extract

```text
GGSCI> EDIT PARAMS ext_rac
```

Basic example:

```text
EXTRACT ext_rac
USERID ggadmin, PASSWORD <password>
EXTTRAIL ./dirdat/er
LOGALLSUPCOLS
UPDATERECORDFORMAT COMPACT
DDL INCLUDE MAPPED
TRANLOGOPTIONS INTEGRATEDPARAMS (MAX_SGA_SIZE 256)

TABLE HR.*;
TABLE APP.*;
```

Practical note:

- in RAC the capture is logical on the database, but the instance from which you administer it is `rac1`;
- use correct services for Oracle login and replicated objects.

---

## 5.9 Data Pump configuration

```text
GGSCI> ADD EXTRACT pump_rac, EXTTRAILSOURCE ./dirdat/er
GGSCI> ADD RMTTRAIL ./dirdat/rt, EXTRACT pump_rac, MEGABYTES 200
GGSCI> EDIT PARAMS pump_rac
```

Example:

```text
EXTRACT pump_rac
USERID ggadmin, PASSWORD <password>
RMTHOST dbtarget, MGRPORT 7809
RMTTRAIL ./dirdat/rt
PASSTHRU

TABLE HR.*;
TABLE APP.*;
```

If you use microservices on the target, replace the template`RMTHOST/MGRPORT`with the Distribution/Receiver path consistent with the chosen deployment.

---

## 5.10 Initial Load (Instantiation)

GoldenGate does not replace the initial load. First you load the data, then you apply the delta.

### Step 1 - Prendi SCN consistente sul source

```sql
sqlplus / as sysdba
SELECT current_scn FROM v$database;
```

### Step 2 - Export consistente

```bash
expdp ggadmin/<password> \
  SCHEMAS=HR,APP \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=gg_init_%U.dmp \
  FILESIZE=2G \
  PARALLEL=4 \
  FLASHBACK_SCN=<SCN>
```

### Step 3 - Import sul target

```bash
impdp ggadmin/<password> \
  SCHEMAS=HR,APP \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=gg_init_%U.dmp \
  PARALLEL=4 \
  TABLE_EXISTS_ACTION=REPLACE
```

### Step 4 - Align Extract to the same SCN

```text
GGSCI> DELETE EXTRACT ext_rac
GGSCI> ADD EXTRACT ext_rac, INTEGRATED TRANLOG, SCN <SCN>
GGSCI> ADD EXTTRAIL ./dirdat/er, EXTRACT ext_rac, MEGABYTES 200
```

Then put the parameter file back`ext_rac`.

This is the correct logic to avoid holes or duplicates during bootstrapping.

---

## 5.11 Configuring Replicat on the Target

Sul target:

```bash
cd $OGG_HOME
./ggsci
```

```text
GGSCI> DBLOGIN USERID ggadmin PASSWORD <password>
GGSCI> ADD CHECKPOINTTABLE ggadmin.ggchkpt
GGSCI> ADD REPLICAT rep_rac, INTEGRATED, EXTTRAIL ./dirdat/rt
GGSCI> EDIT PARAMS rep_rac
```

Example:

```text
REPLICAT rep_rac
USERID ggadmin, PASSWORD <password>
ASSUMETARGETDEFS
DISCARDFILE ./dirrpt/rep_rac.dsc, APPEND, MEGABYTES 100
HANDLECOLLISIONS

MAP HR.*, TARGET HR.*;
MAP APP.*, TARGET APP.*;
```

Nota:

- `HANDLECOLLISIONS` it is only useful in the initial phase;
- after convergence, you remove it and restart Replicat.

---

## 5.12 Boot Order

Recommended order:

1. `START MGR` sul source
2. `START MGR` sul target
3. `START EXTRACT ext_rac`
4. `START EXTRACT pump_rac`
5. `START REPLICAT rep_rac`

Verify:

```text
GGSCI> INFO ALL
GGSCI> STATS EXTRACT ext_rac, TOTAL
GGSCI> STATS EXTRACT pump_rac, TOTAL
GGSCI> STATS REPLICAT rep_rac, TOTAL
GGSCI> LAG EXTRACT ext_rac
GGSCI> LAG REPLICAT rep_rac
```

---

## 5.13 Success Criteria Phase 5

The phase is considered closed if you have all these points:

- source primary stabile;
- target reachable via network and TNS;
- initial load completed;
- Extract `RUNNING`;
- Pump `RUNNING`;
- Replicat `RUNNING`;
- `lag`low and controlled;
- Test DML replicated correctly;
- Data Guard still healthy after enabling GG.

Check Data Guard post-GG:

```sql
SELECT dest_id, status, error FROM v$archive_dest WHERE dest_id = 2;
```

---

## 5.14 Test Minimi Obbligatori

### DML smoke test

```sql
INSERT INTO HR.REGIONS (REGION_ID, REGION_NAME) VALUES (500, 'GG_TEST');
COMMIT;
UPDATE HR.REGIONS SET REGION_NAME='GG_TEST_UPD' WHERE REGION_ID=500;
COMMIT;
DELETE FROM HR.REGIONS WHERE REGION_ID=500;
COMMIT;
```

### Bulk test

- massive insert in test table;
- mass update;
- mass delete;
- check lag and throughput.

### DDL policy test

If you have enabled DDL replication, try:

```sql
CREATE TABLE HR.GG_DDL_TEST (ID NUMBER, TXT VARCHAR2(30));
DROP TABLE HR.GG_DDL_TEST PURGE;
```

---

## 5.15 Advanced Variants and Limits

### Variant A - Offload from redo or standby

It is not the basic repo path.

Why:

- `Integrated Extract` does not capture directly from physical standby;
- `Classic Extract`on Active Data Guard and an advanced theme with important limitations;
- in multi-tenant or modern environments it is easy to end up in unclean combinations.

### Variante B - Downstream mining database

This is the cleanest variant if you want serious offloading from source:

- source continues to generate redo;
- redo is sent to a dedicated mining database;
- GoldenGate legge li.

It's an advanced case, not basic Phase 5.

### Variante C - GoldenGate Free

Use it only in a dedicated sub-lab`Free-to-Free`.

Do not use it as an implicit foundation of the main RAC 19c lab.

---

## 5.16 Troubleshooting Rapido

### `ORA-12514`

- service not registered;
- wrong TNS alias;
- target not in the right state.

### `ORA-01017`

- incorrect file/credential password;
- incorrect GG user.

### Extract `ABENDED`

- missing supplementary logging;
- `enable_goldengate_replication` missing;
- incomplete GG privileges;
- log mining issue.

### Replicat `ABENDED`

- object absent on the target;
- unmanaged collisions;
- incorrect datatype mapping;
- constraints or inconsistent keys.

### Lag alto

- slow network;
- target lento;
- trail saturi;
- high redo generation;
- insufficient parallelism or sizing.

---

## 5.17 Connection with Local Migration -> OCI

To use this phase as a real cloud migration:

1. build the OCI target with [GUIDE_GOLDENGATE_OCI_ARM.md](./GUIDE_GOLDENGATE_OCI_ARM.md)
2. clarify the network with [GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md](./GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md)
3. usa [GUIDE_GOLDENGATE_MIGRATION.md](./GUIDE_GOLDENGATE_MIGRATION.md) per il cutover

Correct sequence:

- initial load al target cloud;
- continuous delta with GG;
- validation of counts/checksums;
- application freeze;
- convergence at lag 0;
- cutover of the application service to the cloud.

---

## 5.18 Official Oracle Sources

- Integrated Extract cannot capture from standby: https://docs.oracle.com/en/middleware/goldengate/core/21.3/ggcab/overview-capture-active-data-guard-only-mode.html
- Active Data Guard only mode and classic capture notes: https://docs.oracle.com/en/middleware/goldengate/core/21.3/coredoc/extract-oracle-active-data-guard-only-mode.html
- Downstream capture overview: https://docs.oracle.com/en/middleware/goldengate/core/21.3/coredoc/extract-create-logmining-server-downstream-mining-database.html
- GoldenGate Free FAQ: https://docs.oracle.com/en/middleware/goldengate/free/23/overview/oracle-goldengate-free-faq.html

---

## 5.19 Operational Conclusion

Phase 5 of the repo now has a simple rule:

- Data Guard protects;
- GoldenGate migra e replica;
- the capture base starts from the primary;
- OCI locks in as a target only after networking and compatibility have been clarified.
