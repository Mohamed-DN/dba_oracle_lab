# Oracle → PostgreSQL migration with GoldenGate

> **Goal**: Migrate an Oracle database (from our RAC lab) to PostgreSQL 16 using Oracle GoldenGate for real-time replication with zero-downtime.
> **Estimated duration**: 5 days (Week 6 of the study plan)

---

## Migration Architecture

![Oracle-PostgreSQL Migration Architecture](./images/oracle_to_postgres_flow.png)

```
┌──────────────────────┐                    ┌──────────────────────┐
│   ORACLE RAC (Source) │                    │  POSTGRESQL (Target)  │
│                       │                    │                       │
│  ┌─────────────────┐  │    Trail Files     │  ┌─────────────────┐  │
│  │  RACDB (CDB)    │  │   ════════════►    │  │  app_db (PG 16) │  │
│  │  ├─ PDB1        │  │                    │  │                  │  │
│  │  │  ├─ HR       │  │  ┌───────────┐     │  │  ├─ hr (schema) │  │
│  │  │  └─ APP      │  │  │ GoldenGate│     │  │  └─ app (schema)│  │
│  │  └─ PDB2        │  │  │  Extract  │     │  │                  │  │
│  └─────────────────┘  │  │  Data Pump│     │  └─────────────────┘  │
│                       │  │  Replicat │     │                       │
│  GoldenGate for       │  └───────────┘     │  GoldenGate for       │
│  Oracle (Extract)     │                    │  PostgreSQL (Replicat)│
└──────────────────────┘                    └──────────────────────┘
```

---

## Prerequisiti

| Requisito | Oracle (Source) | PostgreSQL (Target) |
|---|---|---|
| **Versione** | 19c (nostro lab) | 16.x |
| **Archivelog** | Already active (Phase 2) | N/A |
|**Supplemental Logging**|To be enabled| N/A |
| **GoldenGate** | GG for Oracle 19c/21c | GG for PostgreSQL 21c |
| **ODBC** | N/A | PostgreSQL ODBC driver |
| **Tool DDL** | N/A | `ora2pg`for schema conversion|

---

## STEP 1: Oracle Preparation (Source)

### 1.1 Enable Supplemental Logging

GoldenGate requires additional logging to capture all changed columns:

```sql
--As SYSDBA on Oracle database (on rac1)
sqlplus / as sysdba

--Enable supplemental logging at the database level
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

--Enable for all columns on the tables to be migrated
ALTER TABLE hr.employees ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE hr.departments ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE hr.jobs ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

--Verify
SELECT SUPPLEMENTAL_LOG_DATA_MIN, SUPPLEMENTAL_LOG_DATA_ALL FROM v$database;
-- Deve mostrare YES
```

> **Why supplemental logging?** Oracle normally records only changed columns in the redo log. GoldenGate needs ALL columns (including the primary key) in order to construct the correct UPDATE/DELETE statements on the PostgreSQL target.

### 1.2 Create GoldenGate Oracle User

```sql
--Dedicated user for GoldenGate
CREATE USER ggadmin IDENTIFIED BY "GGadmin123!"
  DEFAULT TABLESPACE users TEMPORARY TABLESPACE temp;

GRANT DBA TO ggadmin;
GRANT SELECT ANY DICTIONARY TO ggadmin;
GRANT FLASHBACK ANY TABLE TO ggadmin;
GRANT SELECT ANY TABLE TO ggadmin;
GRANT EXECUTE ON DBMS_FLASHBACK TO ggadmin;
```

---

## STEP 2: PostgreSQL Installation (Target)

### 2.1 Install PostgreSQL 16

```bash
# On a separate VM or on the dbtarget VM (192.168.56.150)
# Per Oracle Linux 7/8:
yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum install -y postgresql16-server postgresql16-contrib

# Initialize and boot
/usr/pgsql-16/bin/postgresql-16-setup initdb
systemctl enable postgresql-16
systemctl start postgresql-16
```

### 2.2 Configura PostgreSQL per GoldenGate

```bash
# Edit postgresql.conf
vim /var/lib/pgsql/16/data/postgresql.conf

# Add/edit:
wal_level = logical              # CRITICO per GoldenGate
max_replication_slots = 4
max_wal_senders = 4
track_commit_timestamp = on # For lag tracking
listen_addresses = '*' # Accept remote connections

# Edit pg_hba.conf for remote access
echo "host all ggadmin 192.168.56.0/24 md5" >> /var/lib/pgsql/16/data/pg_hba.conf

# Riavvia
systemctl restart postgresql-16
```

### 2.3 Create Database and Target User

```bash
sudo -u postgres psql

--Create GoldenGate user
CREATE USER ggadmin WITH PASSWORD 'GGadmin123!' REPLICATION;
ALTER USER ggadmin WITH SUPERUSER;

-- Crea database target
CREATE DATABASE app_db OWNER ggadmin;
\c app_db

-- Crea schema target
CREATE SCHEMA hr;
GRANT ALL ON SCHEMA hr TO ggadmin;
```

### 2.4 Convert Schema with ora2pg

```bash
# Install now2pg
yum install -y perl-DBI perl-DBD-Pg
#Download now2pg fromhttps://github.com/darold/ora2pg
tar xzf ora2pg-*.tar.gz && cd ora2pg-*
perl Makefile.PL && make && make install

# Configure ora2pg.conf
cat > /etc/ora2pg/ora2pg.conf <<'EOF'
ORACLE_DSN    dbi:Oracle:host=192.168.56.101;sid=RACDB;port=1521
ORACLE_USER   ggadmin
ORACLE_PWD    GGadmin123!
SCHEMA        HR
TYPE          TABLE
OUTPUT        /tmp/pg_schema.sql
PG_DSN        dbi:Pg:dbname=app_db;host=localhost;port=5432
PG_USER       ggadmin
PG_PWD        GGadmin123!
EOF

# Genera DDL PostgreSQL
ora2pg -c /etc/ora2pg/ora2pg.conf -t TABLE -o /tmp/tables.sql
ora2pg -c /etc/ora2pg/ora2pg.conf -t SEQUENCE -o /tmp/sequences.sql
ora2pg -c /etc/ora2pg/ora2pg.conf -t INDEX -o /tmp/indexes.sql
ora2pg -c /etc/ora2pg/ora2pg.conf -t CONSTRAINT -o /tmp/constraints.sql

# Apply DDL to PostgreSQL database
psql -U ggadmin -d app_db -f /tmp/tables.sql
psql -U ggadmin -d app_db -f /tmp/sequences.sql
```

> **Why ora2pg?** Oracle data types (NUMBER, VARCHAR2, DATE) are different from PostgreSQL (INTEGER, VARCHAR, TIMESTAMP). ora2pg does the automatic conversion and generates PostgreSQL compatible DDL.

### 2.5 Configure REPLICA IDENTITY

```sql
--For each table in the PostgreSQL target
ALTER TABLE hr.employees REPLICA IDENTITY FULL;
ALTER TABLE hr.departments REPLICA IDENTITY FULL;
ALTER TABLE hr.jobs REPLICA IDENTITY FULL;
```

---

## STEP 3: GoldenGate Installation

### 3.1 GoldenGate per Oracle (Source — rac1)

```bash
#Already installed in Phase 5 of the lab!
#Verify
cd $OGG_HOME
./ggsci
> INFO ALL
```

### 3.2 GoldenGate per PostgreSQL (Target — dbtarget)

```bash
#Download "Oracle GoldenGate for PostgreSQL" from Oracle eDelivery
# WARNING: this is a DIFFERENT package from GoldenGate for Oracle!

mkdir -p /u01/app/ogg_pg
cd /u01/app/ogg_pg
unzip /tmp/V983xxx_01of01.zip

# Configura environment
export OGG_HOME=/u01/app/ogg_pg
export LD_LIBRARY_PATH=$OGG_HOME/lib:$LD_LIBRARY_PATH
export PATH=$OGG_HOME:$PATH

# Crea sottodirectory
cd $OGG_HOME
./ggsci
> CREATE SUBDIRS
> EXIT
```

### 3.3 Configura ODBC per PostgreSQL

```bash
# Configure odbc.ini
cat > $OGG_HOME/odbc.ini <<'EOF'
[ODBC Data Sources]
PG_APP = PostgreSQL

[PG_APP]
Driver = /usr/pgsql-16/lib/psqlodbc.so
Description = PostgreSQL target
Servername = localhost
Port = 5432
Database = app_db
Username = ggadmin
Password = GGadmin123!
EOF

export ODBCINI=$OGG_HOME/odbc.ini
```

---

## PHASE 4: GoldenGate Process Configuration

### 4.1 Manager (su entrambi i lati)

```bash
# Su Oracle (rac1)
cd $OGG_HOME && ./ggsci
> EDIT PARAM MGR
PORT 7809
AUTORESTART EXTRACT *, RETRIES 5, WAITMINUTES 3
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPDAYS 3
> START MGR

# Su PostgreSQL (dbtarget)
cd $OGG_HOME && ./ggsci
> EDIT PARAM MGR
PORT 7810
AUTORESTART REPLICAT *, RETRIES 5, WAITMINUTES 3
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPDAYS 3
> START MGR
```

### 4.2 Extract (Oracle Source)

```bash
# Configura Extract
./ggsci
> DBLOGIN USERID ggadmin, PASSWORD GGadmin123!

> EDIT PARAM EXT_PG
EXTRACT EXT_PG
USERID ggadmin, PASSWORD GGadmin123!
EXTTRAIL ./dirdat/pg
TABLE hr.employees;
TABLE hr.departments;
TABLE hr.jobs;

> ADD EXTRACT EXT_PG, TRANLOG, BEGIN NOW
> ADD EXTTRAIL ./dirdat/pg, EXTRACT EXT_PG
```

### 4.3 Data Pump (Oracle Source → trail remoto)

```bash
> EDIT PARAM PMP_PG
EXTRACT PMP_PG
RMTHOST 192.168.56.150, MGRPORT 7810
RMTTRAIL ./dirdat/rp
TABLE hr.employees;
TABLE hr.departments;
TABLE hr.jobs;

> ADD EXTRACT PMP_PG, EXTTRAILSOURCE ./dirdat/pg
> ADD RMTTRAIL ./dirdat/rp, EXTRACT PMP_PG
```

### 4.4 Replicat (PostgreSQL Target)

```bash
# Sul server PostgreSQL
cd $OGG_HOME && ./ggsci

> EDIT PARAM REP_PG
REPLICAT REP_PG
TARGETDB PG_APP, USERID ggadmin, PASSWORD GGadmin123!
DISCARDFILE ./dirrpt/rep_pg.dsc, PURGE
MAP hr.employees, TARGET hr.employees;
MAP hr.departments, TARGET hr.departments;
MAP hr.jobs, TARGET hr.jobs;

> ADD REPLICAT REP_PG, EXTTRAIL ./dirdat/rp
```

---

## STEP 5: Initial Load

### 5.1 Initial Loading with Data Pump

```bash
# Su Oracle — esporta i dati
expdp ggadmin/GGadmin123! SCHEMAS=hr DIRECTORY=dp_dir \
  DUMPFILE=hr_initial.dmp LOGFILE=hr_initial.log

# Convert and upload to PostgreSQL with ora2pg
ora2pg -c /etc/ora2pg/ora2pg.conf -t INSERT -o /tmp/data.sql
psql -U ggadmin -d app_db -f /tmp/data.sql
```

### 5.2 Avvia la Replica CDC

```bash
# Su Oracle
./ggsci
> START EXTRACT EXT_PG
> START EXTRACT PMP_PG

# Su PostgreSQL
./ggsci
> START REPLICAT REP_PG
```

### 5.3 Verification

```bash
# Su Oracle
./ggsci
> INFO ALL
> STATS EXT_PG, TOTAL

# Su PostgreSQL
./ggsci
> INFO ALL
> STATS REP_PG, TOTAL
> LAG REPLICAT REP_PG
```

---

## PHASE 6: Cutover (Zero-Downtime Switch)

### 6.1 Pre-Cutover Verification

```bash
#Check that the lag is zero
./ggsci
> LAG REPLICAT REP_PG
# Lag at Checkpoint: 00:00:00

# Count rows on both sides
# Oracle
sqlplus ggadmin/GGadmin123!
SELECT COUNT(*) FROM hr.employees;

# PostgreSQL
psql -U ggadmin -d app_db -c "SELECT COUNT(*) FROM hr.employees;"
```

### 6.2 Cutover procedure

```
1. Put the application in READ-ONLY or maintenance mode
2. Wait for the GoldenGate lag to drop to 0
3. Ferma l'Extract su Oracle
4. Check final counts (Oracle vs PostgreSQL)
5. Change the application connection string:
   - DA: jdbc:oracle:thin:@rac-scan:1521/RACDB
   - A:  jdbc:postgresql://192.168.56.150:5432/app_db
6. Remove the application from maintenance mode
7. Test with verification query
```

### 6.3 Rollback Plan

```
If something goes wrong:
1. Cambia la connection string INDIETRO a Oracle
2. Riavvia l'Extract su Oracle
3. Data written to PostgreSQL during testing is ignored
4. Analyze the problem, fix it, try again
```

---

## PHASE 7: Post-Migration Validation

```sql
--On PostgreSQL — check integrity
SELECT schemaname, tablename, n_live_tup
FROM pg_stat_all_tables
WHERE schemaname = 'hr'
ORDER BY tablename;

--Compare with Oracle
-- Su Oracle
SELECT table_name, num_rows FROM dba_tables WHERE owner = 'HR';
```

### Validation Checklist

| # | Check | Comando |
|---|---|---|
| 1 |Equal row count| COUNT(*) on each table |
| 2 | Checksum dati |Hash comparison on key columns|
| 3 | Constraint attivi | `\d+ tablename` in psql |
| 4 |Indexes created| `\di` in psql |
| 5 |Updated sequences| `SELECT last_value FROM seq_name` |
| 6 |Working app| Test login + CRUD |
| 7 |Acceptable performance| EXPLAIN ANALYZE su query critiche |

---

## Data Type Mapping (Oracle → PostgreSQL)

| Oracle | PostgreSQL | Note |
|---|---|---|
| `NUMBER(p)` | `INTEGER` / `BIGINT` | p<=9 → INT, p<=18 → BIGINT |
| `NUMBER(p,s)` | `NUMERIC(p,s)` |Direct mapping|
| `NUMBER` | `NUMERIC` | Without precision |
| `VARCHAR2(n)` | `VARCHAR(n)` |Identical|
| `CHAR(n)` | `CHAR(n)` |Identical|
| `CLOB` | `TEXT` | PostgreSQL non ha limiti |
| `BLOB` | `BYTEA` | Binary data |
| `DATE` | `TIMESTAMP` | Oracle DATE include ore! |
| `TIMESTAMP` | `TIMESTAMP` |Identical|
| `RAW(n)` | `BYTEA` | Binary data |
| `ROWID` | Nessuno | Non esiste in PG |
| `SYSDATE` | `NOW()` |Different function|
| `NVL()` | `COALESCE()` |Standard SQL equivalent|
| `DECODE()` | `CASE WHEN` | Standard SQL |

---

## Troubleshooting Comuni

| Problema |Solution|
|---|---|
| Extract non parte |Verify additional logging:`SELECT SUPPLEMENTAL_LOG_DATA_MIN FROM v$database` |
| ODBC connection refused | Check `pg_hba.conf` and `listen_addresses` |
| Data type mismatch | Usa `COLMAP`in the Replicat for explicit mapping|
| Performance lenta | Aumenta `GROUPTRANSOPS` nel Replicat (default 1000) |
|Sequences not synchronized| After initial load: `SELECT setval('seq_name', max_val)` |

---

> → **Previous**: [GUIDE_EXAM_REVIEW.md](./GUIDE_EXAM_REVIEW.md) — Oracle Exam Review
> → **Study Plan**: [DAILY_STUDY_PLAN.md](./DAILY_STUDY_PLAN.md) — See Week 6
