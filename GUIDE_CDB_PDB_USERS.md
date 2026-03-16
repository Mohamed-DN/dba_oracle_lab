# GUIDE: CDB/PDB, User Management and EM Express

> This guide covers 3 key areas for an Oracle 19c DBA that are often missing from RAC labs:
> Multitenant architecture (CDB/PDB), user/privilege management, and Enterprise Manager Express.
> **Fonti**: Oracle 19c Database Administration (Tanveer A.), Oracle DBA Administration (MSU).

---

## Percorso di Lettura

```
╔══════════════════════════════════════════════════════════════════════════╗
║ BEFORE this guide read: GUIDE_ORACLE_ARCHITECTURE.md              ║
║ AFTER this guide read:     GUIDE_DBA_ACTIVITIES.md                     ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

## PARTE 1: Architettura Multitenant (CDB/PDB)

### What is Multitenant and Why Does It Exist?

Before Oracle 12c, each database was independent: one instance, one database, one copy of the dictionary. If you had 10 applications, you needed 10 databases with 10 copies of the data dictionary (waste of memory and disk).

**Oracle 12c+ ha introdotto il Multitenant:**

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
║                ARCHITETTURA CDB/PDB (12c e oltre)                 ║
║                                                                    ║
║ SINGLE Instance (CDB) ║
║               ┌──────────────────────────────────┐                 ║
║               │  SGA (2 GB = tutto condiviso!)    │                 ║
║               └──────────────┬───────────────────┘                 ║
║                              │                                     ║
║   ┌──────────────────────────┴───────────────────────────┐         ║
║   │                          CDB$ROOT                     │         ║
║   │                    (Dizionario Master)                 │         ║
║   │  SYSTEM, SYSAUX, UNDO, TEMP ← Condivisi             │         ║
║   └──────┬──────────┬──────────┬─────────────────────────┘         ║
║          │          │          │                                    ║
║   ┌──────┴──┐ ┌─────┴───┐ ┌───┴─────┐                             ║
║   │PDB$SEED │ │  PDB_A  │ │  PDB_B  │     ← Ogni PDB ha i suoi   ║
║   │(template│ │  App A  │ │  App B  │        datafile, ma il dict ║
║ │ empty) │ │ data │ │ data │ is a "link" to the ROOT ║
║   └─────────┘ └─────────┘ └─────────┘                             ║
╚═══════════════════════════════════════════════════════════════════╝
```

### I Componenti del CDB

| Componente | Descrizione | Visibility |
|---|---|---|
| **CDB$ROOT** | Dizionario dati master, metadata Oracle | Solo DBA |
| **PDB$SEED** | Template vuoto per creare nuove PDB | Solo Oracle |
| **PDB (user)** | Database dell'applicazione, isolato | Applicazione + DBA |
| **UNDO tablespace** | Shared by all PDBs (in CDB) | CDB |
| **TEMP tablespace** | Each PDB can have its own | Per PDB |

### Il Nostro Lab: CDB o Non-CDB?

> **In our lab we use a non-CDB database** (RACDB without containers). This is still supported in 19c but **desupported since Oracle 21c+**. If you prepare your CV for the future, you need to know both architectures.

### Operazioni CDB/PDB da Conoscere

#### Creare un CDB con DBCA

```bash
# Usando DBCA in modalità GUI:
# Durante la creazione database, seleziona "Create as Container Database"
# Specifica il nome del PDB (esempio: PDB1)

# In modalità silent:
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
-- Vedere in quale container sei
SHOW CON_NAME;
-- Risultato: CDB$ROOT (se sei nel root)

-- Vedere tutte le PDB
SHOW PDBS;
-- oppure:
SELECT con_id, name, open_mode FROM v$pdbs;

-- CON_ID  NAME        OPEN_MODE
-- ------  ----------  ----------
-- 2       PDB$SEED    READ ONLY
-- 3       PDB1        READ WRITE

-- Spostarsi in una PDB specifica
ALTER SESSION SET CONTAINER = PDB1;
SHOW CON_NAME;
-- Risultato: PDB1

-- Tornare al root
ALTER SESSION SET CONTAINER = CDB$ROOT;
```

#### Creare/Eliminare una PDB

```sql
-- Creare una PDB dal SEED
CREATE PLUGGABLE DATABASE PDB2
  ADMIN USER pdb2admin IDENTIFIED BY Oracle_19c
  FILE_NAME_CONVERT = ('+DATA/CDBRAC/pdbseed/', '+DATA/CDBRAC/pdb2/');

-- Aprire la PDB
ALTER PLUGGABLE DATABASE PDB2 OPEN;

-- Salvare lo stato (si apre automaticamente al restart)
ALTER PLUGGABLE DATABASE PDB2 SAVE STATE;

-- Eliminare una PDB
ALTER PLUGGABLE DATABASE PDB2 CLOSE IMMEDIATE;
DROP PLUGGABLE DATABASE PDB2 INCLUDING DATAFILES;

-- Clonare una PDB esistente (hot clone in 19c!)
-- La PDB sorgente deve essere aperta in READ ONLY o usa snapshot
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

-- PLUG: inserisci la PDB in un altro CDB
-- Prima verifica compatibilità
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

-- Se compatibile, crea la PDB dal manifest
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
║  │ • Proprietario del DD (data dictionary)                     │  ║
║ │ • Can do EVERYTHING (startup, shutdown, recover) │ ║
║  │ • Mai usare direttamente per operazioni normali!            │  ║
║  └───────────────────────────┬─────────────────────────────────┘  ║
║                              │                                    ║
║  ┌───────────────────────────┴─────────────────────────────────┐  ║
║  │ SYSTEM                                                       │  ║
║  │ • DBA amministrativo (non proprietario del DD)              │  ║
║  │ • Per operazioni giornaliere                                │  ║
║  └───────────────────────────┬─────────────────────────────────┘  ║
║                              │                                    ║
║  ┌───────────────────────────┴────────────┐  ┌────────────────┐  ║
║ │ Custom DBA Users │ │ App Users │ ║
║  │ • dba_admin, backup_admin              │  │ • app_user     │  ║
║  │ • Ruoli: DBA, SYSDBA (se servono)      │  │ • app_readonly │  ║
║  │ • Usa QUESTI per il lavoro quotidiano  │  │ • Ruoli custom │  ║
║  └────────────────────────────────────────┘  └────────────────┘  ║
╚═══════════════════════════════════════════════════════════════════╝
```

### Creating a Custom DBA User (Best Practice!)

```sql
-- 1. Crea un tablespace dedicato per gli utenti DBA
CREATE TABLESPACE users_ts
  DATAFILE '+DATA' SIZE 500M
  AUTOEXTEND ON NEXT 100M MAXSIZE 2G;

-- 2. Crea l'utente DBA
CREATE USER dba_admin IDENTIFIED BY "Str0ng_P@ssw0rd!"
  DEFAULT TABLESPACE users_ts
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON users_ts
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

-- 3. Assegna il ruolo DBA
GRANT DBA TO dba_admin;

-- 4. Se serve anche SYSDBA (startup/shutdown/recover):
GRANT SYSDBA TO dba_admin;

-- 5. Assegna il permesso di creare sessione
GRANT CREATE SESSION TO dba_admin;

-- VERIFICA:
SELECT username, account_status, default_tablespace, 
       profile, created
FROM dba_users 
WHERE username = 'DBA_ADMIN';
```

### Manage Application Users (Minimum Privilege!)

```sql
-- Principio: un utente applicativo NON deve avere DBA.
-- Crea un "ruolo" con solo i privilegi necessari.

-- 1. Crea il ruolo
CREATE ROLE app_connect_role;
GRANT CREATE SESSION TO app_connect_role;
GRANT SELECT ANY TABLE TO app_connect_role;

CREATE ROLE app_readwrite_role;
GRANT app_connect_role TO app_readwrite_role;
GRANT INSERT ANY TABLE, UPDATE ANY TABLE, DELETE ANY TABLE TO app_readwrite_role;

-- 2. Crea l'utente e assegna il ruolo
CREATE USER app_user IDENTIFIED BY "App_P@ss!"
  DEFAULT TABLESPACE users_ts
  TEMPORARY TABLESPACE TEMP
  QUOTA 500M ON users_ts;

GRANT app_readwrite_role TO app_user;

-- 3. Utente di sola lettura (per reporting)
CREATE USER app_readonly IDENTIFIED BY "Read_P@ss!"
  DEFAULT TABLESPACE users_ts
  TEMPORARY TABLESPACE TEMP
  QUOTA 0 ON users_ts;  -- zero quota = non può creare oggetti

GRANT app_connect_role TO app_readonly;
```

### Password Profile (Enterprise Security)

```sql
-- Crea un profilo con politiche password
CREATE PROFILE secure_profile LIMIT
  PASSWORD_LIFE_TIME 90           -- scade ogni 90 giorni
  PASSWORD_GRACE_TIME 7           -- 7 giorni di grazia dopo scadenza
  PASSWORD_REUSE_TIME 365         -- non riusare per 1 anno
  PASSWORD_REUSE_MAX 12           -- almeno 12 password diverse
  FAILED_LOGIN_ATTEMPTS 5         -- blocca dopo 5 tentativi sbagliati
  PASSWORD_LOCK_TIME 1/24         -- blocco per 1 ora (1/24 di giorno)
  SESSIONS_PER_USER 10            -- max 10 sessioni contemporanee
  PASSWORD_VERIFY_FUNCTION ora12c_verify_function;

-- Applica il profilo a un utente
ALTER USER dba_admin PROFILE secure_profile;

-- Verifica profili
SELECT username, profile, account_status 
FROM dba_users 
WHERE profile != 'DEFAULT'
ORDER BY profile;

-- Sbloccare un utente bloccato
ALTER USER app_user ACCOUNT UNLOCK;

-- Forzare il cambio password al prossimo login
ALTER USER app_user PASSWORD EXPIRE;
```

### CDB vs PDB Users (Multitenant)

```sql
-- In un CDB, esistono 2 tipi di utenti:

-- COMMON USER: visibile in TUTTO il CDB (nome inizia con C##)
CREATE USER C##DBA_ADMIN IDENTIFIED BY Oracle_19c CONTAINER=ALL;
GRANT DBA TO C##DBA_ADMIN CONTAINER=ALL;
-- → Questo utente esiste nel ROOT e in TUTTE le PDB

-- LOCAL USER: esiste SOLO in una PDB specifica
ALTER SESSION SET CONTAINER = PDB1;
CREATE USER app_user IDENTIFIED BY Oracle_19c;
GRANT CREATE SESSION, CREATE TABLE TO app_user;
-- → Questo utente esiste SOLO in PDB1
```

### View and Audit Users

```sql
-- Tutti gli utenti e le loro info
SELECT username, account_status, lock_date, expiry_date,
       default_tablespace, profile, authentication_type
FROM dba_users
ORDER BY username;

-- Sessioni attive per utente
SELECT username, sid, serial#, status, machine, program, 
       logon_time
FROM v$session
WHERE type = 'USER'
ORDER BY username;

-- Privilegi di sistema di un utente
SELECT privilege, admin_option
FROM dba_sys_privs
WHERE grantee = 'APP_USER';

-- Ruoli assegnati a un utente  
SELECT granted_role, admin_option, default_role
FROM dba_role_privs
WHERE grantee = 'APP_USER';

-- Privilegi su oggetti
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
║ ✅ Integrato nel DB          ║ ❌ Installazione separata        ║
║ ✅ Zero overhead             ║ ⚠️ Server dedicato (WebLogic)    ║
║ ✅ Gestisce 1 DB             ║ ✅ Gestisce 100+ DB             ║
║ ✅ Perfect for the lab ║ ✅ Perfect for production ║
║ ❌ No startup/shutdown       ║ ✅ Operazioni complete           ║
║ ❌ No job scheduling         ║ ✅ Job, patching, compliance     ║
╚══════════════════════════════╩════════════════════════════════════╝
```

### Configurare EM Express nel Lab

```sql
-- 1. Verifica se EM Express è già configurato
SELECT dbms_xdb_config.gethttpsport() FROM dual;
-- Se ritorna 0, non è configurato

-- 2. Configura la porta HTTPS
EXEC DBMS_XDB_CONFIG.SETHTTPSPORT(5500);

-- 3. Verifica
SELECT dbms_xdb_config.gethttpsport() FROM dual;
-- Deve ritornare 5500

-- 4. Verifica che il listener sia attivo
-- (EM Express si registra sul listener automaticamente)
```

### Accedere a EM Express

```
Nel browser del tuo PC host:
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
| **Storage** | Tablespace, datafile, utilizzo disco |
| **Security** | Users, roles, privileges, audits |
| **Configuration** | Parametri init, memory advisor, feature usage |

### EM Express con RAC

```sql
-- In un RAC, configura la porta su OGNI istanza:

-- Su rac1 (connesso a RACDB1):
EXEC DBMS_XDB_CONFIG.SETHTTPSPORT(5500);

-- Su rac2 (connesso a RACDB2):
EXEC DBMS_XDB_CONFIG.SETHTTPSPORT(5500);

-- Accedi poi a:
-- https://rac1:5500/em/  ← istanza RACDB1
-- https://rac2:5500/em/  ← istanza RACDB2
```

---

## PARTE 4: SQL Tuning Advisor e Performance

### SQL Tuning Advisor

```sql
-- 1. Crea un tuning task per un SQL specifico
DECLARE
  l_task_name VARCHAR2(100);
BEGIN
  l_task_name := DBMS_SQLTUNE.CREATE_TUNING_TASK(
    sql_id      => 'abc123def456',  -- prendi da V$SQL
    scope       => DBMS_SQLTUNE.SCOPE_COMPREHENSIVE,
    time_limit  => 300,  -- 5 minuti max
    task_name   => 'tune_slow_query'
  );
  DBMS_OUTPUT.PUT_LINE('Task: ' || l_task_name);
END;
/

-- 2. Esegui il task
BEGIN
  DBMS_SQLTUNE.EXECUTE_TUNING_TASK(task_name => 'tune_slow_query');
END;
/

-- 3. Leggi il report
SET LONG 10000
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('tune_slow_query') AS report
FROM dual;

-- Il report ti dice:
-- • Se mancano statistiche
-- • Se un indice migliorerebbe la query
-- • Se un SQL Profile può ottimizzare il piano di esecuzione
-- • Se c'è un piano migliore disponibile
```

### Accettare un SQL Profile

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

-- Verificare i profili attivi
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
-- SPM permette di "bloccare" un piano di esecuzione che funziona bene
-- così Oracle non può cambiarlo in peggio dopo una raccolta di statistiche.

-- 1. Carica un piano dalla cursor cache
DECLARE
  l_plans PLS_INTEGER;
BEGIN
  l_plans := DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(
    sql_id            => 'abc123def456',
    plan_hash_value   => 12345678,  -- dal piano buono
    fixed             => 'YES',     -- blocca questo piano
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

## PARTE 5: Concetti Avanzati (da 19c)

### In-Memory Column Store (Cenni)

```sql
-- Oracle In-Memory permette di tenere tabelle in formato colonnare in RAM
-- per query analitiche ultra-veloci. Richiede il parametro INMEMORY_SIZE > 0.

-- Abilitare (a livello istanza)
ALTER SYSTEM SET INMEMORY_SIZE = 512M SCOPE=SPFILE;
-- Richiede restart!

-- Mettere una tabella in-memory
ALTER TABLE hr.employees INMEMORY PRIORITY HIGH;

-- Verificare lo stato
SELECT segment_name, inmemory_size, bytes_not_populated
FROM v$im_segments;

-- In produzione: usato per data warehousing e reporting.
-- Nel lab: interessante da sapere, ma richiede RAM extra.
```

### Database Vault (Cenni)

```
Database Vault aggiunge un ulteriore livello di sicurezza:
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
1. CATTURARE il carico di lavoro dal database di produzione
2. RIPRODURLO in un ambiente di test

Uso pratico:
- Prima di applicare un patch o upgrade
- Per verificare che le performance non peggiorino
- Per testare cambio di parametri

Comandi:
BEGIN
  DBMS_WORKLOAD_CAPTURE.START_CAPTURE(
    name     => 'pre_upgrade_capture',
    dir      => 'CAPTURE_DIR',
    duration => 3600  -- 1 ora
  );
END;
/

-- Dopo aver catturato, replay in ambiente test:
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
-- Sul tuo RACDB, crea un utente che usi per il lavoro quotidiano
-- invece di SYS:
CREATE USER lab_dba IDENTIFIED BY "Lab_DBA_2024!"
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP;
GRANT DBA TO lab_dba;
GRANT SYSDBA TO lab_dba;

-- Test: connettiti con il nuovo utente
-- sqlplus lab_dba/"Lab_DBA_2024!"@rac-scan:1521/RACDB
```

### Esercizio 2: Configura EM Express

```sql
-- Su RACDB, configura la porta ed accedi dal browser
EXEC DBMS_XDB_CONFIG.SETHTTPSPORT(5500);
-- Apri: https://192.168.56.101:5500/em/
-- Login: SYS / password / as SYSDBA
-- Esplora: Performance Hub, Storage, Security
```

### Esercizio 3: SQL Tuning Advisor

```sql
-- Trova la query più lenta e usa il Tuning Advisor:
SELECT sql_id, elapsed_time/1000000 as secs, sql_text
FROM v$sql
ORDER BY elapsed_time DESC
FETCH FIRST 5 ROWS ONLY;

-- Poi lancia il Tuning Task sul sql_id peggiore (vedi sezione 4)
```

---

> **→ Prossimo: [GUIDE_DBA_ACTIVITIES.md](./GUIDE_DBA_ACTIVITIES.md)** per batch jobs, AWR/ADDM, patching, e sicurezza avanzata.
