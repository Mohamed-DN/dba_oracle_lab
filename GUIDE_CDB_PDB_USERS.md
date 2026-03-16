# GUIDE: CDB/PDB, User Management and EM Express

> This guide covers 3 key areas for an Oracle 19c DBA that are often missing from RAC labs:
> Multitenant architecture (CDB/PDB), user/privilege management, and Enterprise Manager Express.
> **Fonti**: Oracle 19c Database Administration (Tanveer A.), Oracle DBA Administration (MSU).

---

## Reading Path

```
╔══════════════════════════════════════════════════════════════════════════╗
║ BEFORE this guide read: GUIDE_ORACLE_ARCHITECTURE.md              ║
║ AFTER this guide read:     GUIDE_DBA_ACTIVITIES.md                     ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

## PART 1: Multitenant Architecture (CDB/PDB)

### What is Multitenant and Why Does It Exist?

Before Oracle 12c, each database was independent: one instance, one database, one copy of the dictionary. If you had 10 applications, you needed 10 databases with 10 copies of the data dictionary (waste of memory and disk).

**Oracle 12c+ introduced Multitenant:**

```
╔═══════════════════════════════════════════════════════════════════╗
║ NON-CDB ARCHITECTURE (before 12c) ║
║                                                                    ║
║ Instance A Instance B Instance C Instance D ║
║   ┌───────┐     ┌───────┐     ┌───────┐     ┌───────┐             ║
║   │SGA    │     │SGA    │     │SGA    │     │SGA    │             ║
║   │1 GB   │     │1 GB   │     │1 GB   │     │1 GB   │   = 4 GB   ║
║   └───┬───┘     └───┬───┘     └───┬───┘     └───┬───┘   di RAM   ║
║       │             │             │             │                   ║
║   ┌───┴───┐     ┌───┴───┐     ┌───┴───┐     ┌───┴───┐             ║
║   │ DB_A  │     │ DB_B  │     │ DB_C  │     │ DB_D  │             ║
║   │Dict! │     │ Dict! │     │ Dict! │     │ Dict! │   4 copie   ║
║   └───────┘     └───────┘     └───────┘     └───────┘   del dict  ║
╚═══════════════════════════════════════════════════════════════════╝

╔═══════════════════════════════════════════════════════════════════╗
║ CDB/PDB ARCHITECTURE (12c and above) ║
║                                                                    ║
║ SINGLE Instance (CDB) ║
║               ┌──────────────────────────────────┐                 ║
║ │ SGA (2 GB = all shared!) │ ║
║               └──────────────┬───────────────────┘                 ║
║                              │                                     ║
║   ┌──────────────────────────┴───────────────────────────┐         ║
║   │                          CDB$ROOT                     │         ║
║ │ (Master Dictionary) │ ║
║   │  SYSTEM, SYSAUX, UNDO, TEMP ← Condivisi             │         ║
║   └──────┬──────────┬──────────┬─────────────────────────┘         ║
║          │          │          │                                    ║
║   ┌──────┴──┐ ┌─────┴───┐ ┌───┴─────┐                             ║
║   │PDB$SEED │ │  PDB_A  │ │  PDB_B│ ← Each PDB has its own ║
║ │(template│ │ App A │ │ App B │ datafile, but the dict ║
║ │ empty) │ │ data │ │ data │ is a "link" to the ROOT ║
║   └─────────┘ └─────────┘ └─────────┘                             ║
╚═══════════════════════════════════════════════════════════════════╝
```

### The Members of the CDB

|Component|Description| Visibility |
|---|---|---|
| **CDB$ROOT** |Master data dictionary, Oracle metadata| Solo DBA |
| **PDB$SEED** |Empty template to create new PDBs|Oracle only|
| **PDB (user)** |Application database, isolated|Application + DBA|
| **UNDO tablespace** | Shared by all PDBs (in CDB) | CDB |
| **TEMP tablespace** | Each PDB can have its own | Per PDB |

### Our Lab: CDB or Non-CDB?

> **In our lab we use a non-CDB database** (RACDB without containers). This is still supported in 19c but **desupported since Oracle 21c+**. If you prepare your CV for the future, you need to know both architectures.

### CDB/PDB Operations to Know

#### Creare un CDB con DBCA

```bash
#Using DBCA in GUI mode:
#When creating database, select "Create as Container Database"
#Specify the name of the PDB (example: PDB1)

#In silent mode:
dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -gdbname CDBRAC -sid CDBRAC \
  -createAsContainerDatabase true \
  -numberOfPDBs 1 \
  -pdbName PDB1 \
  -pdbAdminPassword Oracle_19c \
  -sysPassword Oracle_19c \
  -systemPassword Oracle_19c \
  -storageType ASM \
  -diskGroupName +DATA \
  -recoveryAreaDestination +FRA \
  -characterSet AL32UTF8 \
  -nodeinfo rac1,rac2
```

#### Navigare tra CDB e PDB

```sql
--See which container you are in
SHOW CON_NAME;
--Result: CDB$ROOT(if you are in root)

-- Vedere tutte le PDB
SHOW PDBS;
-- oppure:
SELECT con_id, name, open_mode FROM v$pdbs;

-- CON_ID  NAME        OPEN_MODE
-- ------  ----------  ----------
-- 2       PDB$SEED    READ ONLY
-- 3       PDB1        READ WRITE

--Navigate to a specific PDB
ALTER SESSION SET CONTAINER = PDB1;
SHOW CON_NAME;
--Result: PDB1

-- Tornare al root
ALTER SESSION SET CONTAINER = CDB$ROOT;
```

#### Creare/Eliminare una PDB

```sql
--Create a PDB from the SEED
CREATE PLUGGABLE DATABASE PDB2
  ADMIN USER pdb2admin IDENTIFIED BY Oracle_19c
  FILE_NAME_CONVERT = ('+DATA/CDBRAC/pdbseed/', '+DATA/CDBRAC/pdb2/');

-- Aprire la PDB
ALTER PLUGGABLE DATABASE PDB2 OPEN;

--Save the state (opens automatically upon restart)
ALTER PLUGGABLE DATABASE PDB2 SAVE STATE;

-- Eliminare una PDB
ALTER PLUGGABLE DATABASE PDB2 CLOSE IMMEDIATE;
DROP PLUGGABLE DATABASE PDB2 INCLUDING DATAFILES;

--Clone an existing PDB (hot clone in 19c!)
--The source PDB must be opened in READ ONLY or use snapshot
CREATE PLUGGABLE DATABASE PDB3 FROM PDB1
  FILE_NAME_CONVERT = ('+DATA/CDBRAC/pdb1/', '+DATA/CDBRAC/pdb3/');
```

#### Unplug/Plug (PDB Migration)

```sql
-- UNPLUG: sgancia una PDB e crea un XML manifest
ALTER PLUGGABLE DATABASE PDB2 CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE PDB2 
  UNPLUG INTO '/tmp/pdb2_manifest.xml';
DROP PLUGGABLE DATABASE PDB2 KEEP DATAFILES;

--PLUG: insert the PDB into another CDB
--First check compatibility
SET SERVEROUTPUT ON
DECLARE
  compatible BOOLEAN := FALSE;
BEGIN
  compatible := DBMS_PDB.CHECK_PLUG_COMPATIBILITY(
    pdb_descr_file => '/tmp/pdb2_manifest.xml');
  IF compatible THEN
    DBMS_OUTPUT.PUT_LINE('PDB is compatible!');
  ELSE
    DBMS_OUTPUT.PUT_LINE('PDB is NOT compatible!');
  END IF;
END;
/

--If compatible, create the PDB from the manifest
CREATE PLUGGABLE DATABASE PDB2 USING '/tmp/pdb2_manifest.xml'
  NOCOPY TEMPFILE REUSE;
ALTER PLUGGABLE DATABASE PDB2 OPEN;
```

> **Why is this important for CV?** In production we use Unplug/Plug to migrate applications between CDBs without Export/Import. It is the fastest way to move a database between servers.

---

## PART 2: Management of Users, Roles and Privileges

### Types of Oracle Users

```
╔═══════════════════════════════════════════════════════════════════╗
║ ORACLE USER HIERARCHY ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ┌─────────────────────────────────────────────────────────────┐  ║
║  │ SYS (SYSDBA)                                                │  ║
║ │ • DD owner (data dictionary) │ ║
║ │ • Can do EVERYTHING (startup, shutdown, recover) │ ║
║ │ • Never use directly for normal operations!            │ ║
║  └───────────────────────────┬─────────────────────────────────┘  ║
║                              │                                    ║
║  ┌───────────────────────────┴─────────────────────────────────┐  ║
║  │ SYSTEM                                                       │  ║
║ │ • Administrative DBA (not owner of the DD) │ ║
║ │ • For daily operations │ ║
║  └───────────────────────────┬─────────────────────────────────┘  ║
║                              │                                    ║
║  ┌───────────────────────────┴────────────┐  ┌────────────────┐  ║
║ │ Custom DBA Users │ │ App Users │ ║
║  │ • dba_admin, backup_admin              │  │ • app_user     │  ║
║ │ • Roles: DBA, SYSDBA (if needed) │ │ • app_readonly │ ║
║ │ • Use THESE for daily work │ │ • Custom roles │ ║
║  └────────────────────────────────────────┘  └────────────────┘  ║
╚═══════════════════════════════════════════════════════════════════╝
```

### Creating a Custom DBA User (Best Practice!)

```sql
--1. Create a dedicated tablespace for DBA users
CREATE TABLESPACE users_ts
  DATAFILE '+DATA' SIZE 500M
  AUTOEXTEND ON NEXT 100M MAXSIZE 2G;

--2. Create the DBA user
CREATE USER dba_admin IDENTIFIED BY "Str0ng_P@ssw0rd!"
  DEFAULT TABLESPACE users_ts
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON users_ts
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

--3. Assign the DBA role
GRANT DBA TO dba_admin;

--4. If you also need SYSDBA (startup/shutdown/recover):
GRANT SYSDBA TO dba_admin;

--5. Assign permission to create session
GRANT CREATE SESSION TO dba_admin;

--VERIFY:
SELECT username, account_status, default_tablespace, 
       profile, created
FROM dba_users 
WHERE username = 'DBA_ADMIN';
```

### Manage Application Users (Minimum Privilege!)

```sql
--Principle: An application user must NOT have DBA.
--Create a "role" with only the necessary privileges.

--1. Create the role
CREATE ROLE app_connect_role;
GRANT CREATE SESSION TO app_connect_role;
GRANT SELECT ANY TABLE TO app_connect_role;

CREATE ROLE app_readwrite_role;
GRANT app_connect_role TO app_readwrite_role;
GRANT INSERT ANY TABLE, UPDATE ANY TABLE, DELETE ANY TABLE TO app_readwrite_role;

--2. Create the user and assign the role
CREATE USER app_user IDENTIFIED BY "App_P@ss!"
  DEFAULT TABLESPACE users_ts
  TEMPORARY TABLESPACE TEMP
  QUOTA 500M ON users_ts;

GRANT app_readwrite_role TO app_user;

--3. Read-only user (for reporting)
CREATE USER app_readonly IDENTIFIED BY "Read_P@ss!"
  DEFAULT TABLESPACE users_ts
  TEMPORARY TABLESPACE TEMP
QUOTE 0 ON users_ts;  -- zero quota = cannot create objects

GRANT app_connect_role TO app_readonly;
```

### Password Profile (Enterprise Security)

```sql
--Create a profile with password policies
CREATE PROFILE secure_profile LIMIT
  PASSWORD_LIFE_TIME90 -- expires every 90 days
  PASSWORD_GRACE_TIME7 -- 7 days grace period after expiration
  PASSWORD_REUSE_TIME365 -- do not reuse for 1 year
  PASSWORD_REUSE_MAX12 -- at least 12 different passwords
  FAILED_LOGIN_ATTEMPTS5 -- blocks after 5 wrong attempts
  PASSWORD_LOCK_TIME1/24 -- block for 1 hour (1/24 of day)
  SESSIONS_PER_USER10 -- max 10 simultaneous sessions
  PASSWORD_VERIFY_FUNCTION ora12c_verify_function;

--Apply the profile to a user
ALTER USER dba_admin PROFILE secure_profile;

--Check profiles
SELECT username, profile, account_status 
FROM dba_users 
WHERE profile != 'DEFAULT'
ORDER BY profile;

--Unblock a blocked user
ALTER USER app_user ACCOUNT UNLOCK;

--Force password change at next login
ALTER USER app_user PASSWORD EXPIRE;
```

### CDB vs PDB Users (Multitenant)

```sql
--In a CDB, there are 2 types of users:

--COMMON USER: visible in the WHOLE CDB (name starts with C##)
CREATE USER C##DBA_ADMIN IDENTIFIED BY Oracle_19c CONTAINER=ALL;
GRANT DBA TO C##DBA_ADMIN CONTAINER=ALL;
--→ This user exists in the ROOT and ALL PDBs

--LOCAL USER: ONLY exists in a specific PDB
ALTER SESSION SET CONTAINER = PDB1;
CREATE USER app_user IDENTIFIED BY Oracle_19c;
GRANT CREATE SESSION, CREATE TABLE TO app_user;
--→ This user exists ONLY in PDB1
```

### View and Audit Users

```sql
--All users and their info
SELECT username, account_status, lock_date, expiry_date,
       default_tablespace, profile, authentication_type
FROM dba_users
ORDER BY username;

--Active sessions per user
SELECT username, sid, serial#, status, machine, program, 
logon_time
FROM v$session
WHERE type = 'USER'
ORDER BY username;

--A user's system privileges
SELECT privilege, admin_option
FROM dba_sys_privs
WHERE grantee = 'APP_USER';

--Roles assigned to a user
SELECT granted_role, admin_option, default_role
FROM dba_role_privs
WHERE grantee = 'APP_USER';

--Privileges on objects
SELECT owner, table_name, privilege, grantable
FROM dba_tab_privs
WHERE grantee = 'APP_USER';
```

---

## PARTE 3: Enterprise Manager Database Express (EM Express)

### What is EM Express?

**EM Express** is the web interface integrated into Oracle 19c that requires NO additional installations. It is a servlet inside Oracle XML DB that runs on HTTPS port 5500.

```
╔═══════════════════════════════════════════════════════════════════╗
║                    EM EXPRESS vs EM Cloud Control                  ║
╠══════════════════════════════╦════════════════════════════════════╣
║       EM Express             ║     EM Cloud Control (OMS)        ║
╠══════════════════════════════╬════════════════════════════════════╣
║ ✅ Integrated into the DB ║ ❌ Separate installation ║
║ ✅ Zero overhead             ║ ⚠️ Server dedicato (WebLogic)    ║
║ ✅ Gestisce 1 DB             ║ ✅ Gestisce 100+ DB             ║
║ ✅ Perfect for the lab ║ ✅ Perfect for production ║
║ ❌ No startup/shutdown ║ ✅ Complete operations ║
║ ❌ No job scheduling         ║ ✅ Job, patching, compliance     ║
╚══════════════════════════════╩════════════════════════════════════╝
```

### Configure EM Express in the Lab

```sql
--1. Check if EM Express is already configured
SELECT dbms_xdb_config.gethttpsport() FROM dual;
--If it returns 0, it is not configured

-- 2. Configura la porta HTTPS
EXEC DBMS_XDB_CONFIG.SETHTTPSPORT(5500);

--3. Check
SELECT dbms_xdb_config.gethttpsport() FROM dual;
-- Deve ritornare 5500

--4. Verify that the listener is active
--(EM Express registers on the listener automatically)
```

### Accedere a EM Express

```
In your host PC's browser:
https://rac1:5500/em/

Login:
  User: SYS (or SYSTEM or a user with DBA)
  Password: the DB password
  As: SYSDBA (se usi SYS)
```

> **⚠️ VirtualBox Note**: To access from the host machine, make sure the VM's port 5500 is reachable (Bridged networking automatically exposes it).

### What You Can Do with EM Express

| Section | What You See/Do |
|---|---|
| **Home** | Real-time performance, alerts, instance status |
| **Performance** | Active Session History (ASH), SQL Monitoring, Top SQL |
| **Storage** |Tablespace, datafile, disk usage|
| **Security** | Users, roles, privileges, audits |
|**Configuration**| Parametri init, memory advisor, feature usage |

### EM Express con RAC

```sql
--In a RAC, configure the port on EACH instance:

--On rac1 (connected to RACDB1):
EXEC DBMS_XDB_CONFIG.SETHTTPSPORT(5500);

--On rac2 (connected to RACDB2):
EXEC DBMS_XDB_CONFIG.SETHTTPSPORT(5500);

--Then access:
-- https://rac1:5500/em/  ← istanza RACDB1
-- https://rac2:5500/em/  ← istanza RACDB2
```

---

## PARTE 4: SQL Tuning Advisor e Performance

### SQL Tuning Advisor

```sql
--1. Create a tuning task for a specific SQL
DECLARE
  l_task_name VARCHAR2(100);
BEGIN
  l_task_name := DBMS_SQLTUNE.CREATE_TUNING_TASK(
sql_id => 'abc123def456', -- get from V$SQL
    scope       => DBMS_SQLTUNE.SCOPE_COMPREHENSIVE,
    time_limit  => 300,  -- 5 minuti max
    task_name   => 'tune_slow_query'
  );
  DBMS_OUTPUT.PUT_LINE('Task: ' || l_task_name);
END;
/

--2. Run the task
BEGIN
  DBMS_SQLTUNE.EXECUTE_TUNING_TASK(task_name => 'tune_slow_query');
END;
/

--3. Read the report
SET LONG 10000
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('tune_slow_query') AS report
FROM dual;

--The report tells you:
--• If statistics are missing
--• Whether an index would improve the query
--• Whether a SQL Profile can optimize the execution plan
--• If there is a better plan available
```

### Accept a SQL Profile

```sql
-- Se il Tuning Advisor raccomanda un SQL Profile:
BEGIN
  DBMS_SQLTUNE.ACCEPT_SQL_PROFILE(
    task_name    => 'tune_slow_query',
    name         => 'profile_slow_query',
    force_match  => TRUE  -- applica anche se il SQL ha bind diversi
  );
END;
/

--Check active profiles
SELECT name, sql_text, status, force_matching
FROM dba_sql_profiles
ORDER BY created DESC;

-- Eliminare un profilo
BEGIN
  DBMS_SQLTUNE.DROP_SQL_PROFILE('profile_slow_query');
END;
/
```

### SQL Plan Management (SPM) — Lock a Good Plan

```sql
--SPM allows you to "lock in" an execution plan that works well
--so Oracle can't change it for the worse after a collection of statistics.

--1. Load a plan from the cursor cache
DECLARE
  l_plans PLS_INTEGER;
BEGIN
  l_plans := DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(
    sql_id            => 'abc123def456',
plan_hash_value => 12345678, -- from the good plan
fixed => 'YES', -- block this plan
    enabled           => 'YES'
  );
  DBMS_OUTPUT.PUT_LINE('Plans loaded: ' || l_plans);
END;
/

-- 2. Verificare le SQL Plan Baselines
SELECT sql_handle, plan_name, enabled, accepted, fixed,
       optimizer_cost, executions
FROM dba_sql_plan_baselines
ORDER BY created DESC;
```

> **Why is SPM critical in production?** After a statistics update or upgrade, Oracle may "choose" a worse execution plan. SPM prevents **performance regressions** by blocking plans that work.

---

## PART 5: Advanced Concepts (from 19c)

### In-Memory Column Store (Cenni)

```sql
--Oracle In-Memory allows you to keep tables in columnar format in RAM
--for ultra-fast analytical queries. Requires parameterINMEMORY_SIZE > 0.

--Enable (instance level)
ALTER SYSTEM SET INMEMORY_SIZE = 512M SCOPE=SPFILE;
-- Richiede restart!

--Put a table in-memory
ALTER TABLE hr.employees INMEMORY PRIORITY HIGH;

--Check the status
SELECT segment_name, inmemory_size, bytes_not_populated
FROM v$im_segments;

--In production: Used for data warehousing and reporting.
--In the lab: Interesting to know, but requires extra RAM.
```

### Database Vault (Cenni)

```
Database Vault adds an additional layer of security:
even a user with DBA or SYSDBA can NOT access the data
of the application if it is not authorized by the DBV.

Real world example: In a bank, the DBA can manage the database
(startup, backup, patching) but can NOT read account balances
currents. Only the application can access that data.

-- This is an advanced concept. In the lab you just need to know it on a level
-- theoretical. In production it is required in regulated sectors
-- (banks, insurance, healthcare).
```

### Workload Capture e Replay (Real Application Testing)

```
Oracle Real Application Testing (RAT) permette di:
1. CAPTURE the workload from the production database
2. PLAY IT in a test environment

Practical use:
- Before applying a patch or upgrade
- To verify that performance does not worsen
- To test parameter changes

Comandi:
BEGIN
  DBMS_WORKLOAD_CAPTURE.START_CAPTURE(
    name     => 'pre_upgrade_capture',
    dir      => 'CAPTURE_DIR',
    duration => 3600  -- 1 ora
  );
END;
/

--After capturing, replay in test environment:
BEGIN
  DBMS_WORKLOAD_REPLAY.PROCESS_CAPTURE(
    capture_dir => 'CAPTURE_DIR'
  );
  DBMS_WORKLOAD_REPLAY.INITIALIZE_REPLAY(
    replay_name => 'pre_upgrade_replay',
    replay_dir  => 'CAPTURE_DIR'
  );
  DBMS_WORKLOAD_REPLAY.START_REPLAY;
END;
/

-- Richiede licenza Enterprise Edition + Diagnostics Pack + Tuning Pack
```

---

## Lab exercises

### Exercise 1: Create a Custom DBA User

```sql
--On your RACDB, create a user that you use for day-to-day work
--instead of SYS:
CREATE USER lab_dba IDENTIFIED BY "Lab_DBA_2024!"
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP;
GRANT DBA TO lab_dba;
GRANT SYSDBA TO lab_dba;

--Test: Connect with the new user
-- sqlplus lab_dba/"Lab_DBA_2024!"@rac-scan:1521/RACDB
```

### Exercise 2: Configure EM Express

```sql
--On RACDB, configure the port and access from the browser
EXEC DBMS_XDB_CONFIG.SETHTTPSPORT(5500);
-- Apri: https://192.168.56.101:5500/em/
-- Login: SYS / password / as SYSDBA
-- Esplora: Performance Hub, Storage, Security
```

### Exercise 3: SQL Tuning Advisor

```sql
--Find the slowest query and use the Tuning Advisor:
SELECT sql_id, elapsed_time/1000000 as secs, sql_text
FROM v$sql
ORDER BY elapsed_time DESC
FETCH FIRST 5 ROWS ONLY;

--Then run the Tuning Task on the worst sql_id (see section 4)
```

---

> **→ Prossimo: [GUIDE_DBA_ACTIVITIES.md](./GUIDE_DBA_ACTIVITIES.md)** for batch jobs, AWR/ADDM, patching, and advanced security.
