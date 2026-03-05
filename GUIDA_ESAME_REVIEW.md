# Ripasso Esami Oracle — Argomenti Completi

> **Esami coperti**: 1Z0-082 (DB Administration I + SQL), 1Z0-083 (DB Administration II / DBA Professional 2)
> **Dove praticare**: Ogni sezione ha un riferimento alla guida del lab dove puoi esercitarti.

---

## PARTE 1: Architettura Oracle Database

> 📖 Riferimento Lab: [GUIDA_ARCHITETTURA_ORACLE.md](./GUIDA_ARCHITETTURA_ORACLE.md)

### 1.1 Configurazioni dell'Istanza

| Tipo | Descrizione | Nel Nostro Lab |
|---|---|---|
| **Single Instance** | 1 DB, 1 istanza, 1 server | `dbtarget` (GoldenGate target) |
| **RAC** | 1 DB, N istanze, N server | `rac1`+`rac2` (RACDB1/RACDB2) |
| **RAC One Node** | 1 DB, 1 istanza attiva, failover automatico | Non configurato |
| **Data Guard** | Primary + Standby (fisico/logico) | `racstby1`+`racstby2` |

### 1.2 Strutture di Memoria

```
┌─────────────── ISTANZA ORACLE ───────────────┐
│                                               │
│  ┌──── SGA (System Global Area) ────┐        │
│  │ Shared Pool (SQL cache, dict.)   │        │
│  │ Database Buffer Cache            │        │
│  │ Redo Log Buffer                  │        │
│  │ Large Pool (RMAN, shared server) │        │
│  │ Java Pool                        │        │
│  │ Streams Pool                     │        │
│  └──────────────────────────────────┘        │
│                                               │
│  ┌──── PGA (per ogni sessione) ─────┐        │
│  │ Sort Area, Hash Area, Session    │        │
│  └──────────────────────────────────┘        │
└───────────────────────────────────────────────┘
```

**Comandi chiave**:
```sql
SHOW PARAMETER sga_target;
SHOW PARAMETER pga_aggregate_target;
SHOW PARAMETER memory_target;
SELECT * FROM v$sgainfo;
SELECT * FROM v$pgastat;
```

### 1.3 Processi in Background

| Processo | Funzione | Critico? |
|---|---|---|
| **PMON** | Cleanup processi falliti, registra col listener | Si |
| **SMON** | Instance recovery, coalescing free space | Si |
| **DBWn** | Scrive dirty buffers su disco | Si |
| **LGWR** | Scrive redo log buffer su redo log files | Si |
| **CKPT** | Segnala checkpoint a DBWn | Si |
| **ARCn** | Archivia redo log pieni (ARCHIVELOG mode) | Si per DG |
| **MMON** | AWR snapshots, metriche | No |
| **MMAN** | Automatic Memory Management | No |
| **RECO** | Distributed transaction recovery | No |

### 1.4 Strutture Logiche e Fisiche

```
LOGICHE                          FISICHE
────────                         ────────
Tablespace ──────────────────── Datafile(s)
  └── Segment                    Control File(s)
       └── Extent                Redo Log File(s)
            └── Data Block       Archive Log File(s)
                                 Parameter File (spfile)
                                 Password File
```

---

## PARTE 2: Gestione delle Istanze

> 📖 Riferimento Lab: [GUIDA_COMANDI_DBA.md](./GUIDA_COMANDI_DBA.md)

### 2.1 Startup e Shutdown

```sql
-- Fasi di Startup
STARTUP NOMOUNT;   -- Legge spfile, alloca SGA, avvia processi
ALTER DATABASE MOUNT;   -- Apre control file
ALTER DATABASE OPEN;    -- Apre datafile e redo log

-- Oppure tutto in un colpo
STARTUP;

-- Shutdown modes
SHUTDOWN IMMEDIATE;    -- Rollback transazioni attive, chiude pulito
SHUTDOWN TRANSACTIONAL; -- Aspetta fine transazioni, poi chiude
SHUTDOWN NORMAL;       -- Aspetta disconnessione di tutti
SHUTDOWN ABORT;        -- Crash! (richiede recovery al restart)
```

> **In RAC**: Usa `srvctl` invece di `SHUTDOWN`:
> ```bash
> srvctl stop instance -d RACDB -i RACDB1 -o immediate
> srvctl start instance -d RACDB -i RACDB1
> srvctl stop database -d RACDB -o immediate
> ```

### 2.2 Data Dictionary Views

| Vista | Contenuto |
|---|---|
| `DBA_USERS` | Tutti gli utenti |
| `DBA_TABLESPACES` | Tutti i tablespace |
| `DBA_DATA_FILES` | Tutti i datafile |
| `DBA_SEGMENTS` | Tutti i segmenti (tabelle, indici) |
| `DBA_OBJECTS` | Tutti gli oggetti del database |
| `DBA_TAB_COLUMNS` | Colonne di tutte le tabelle |
| `DBA_CONSTRAINTS` | Tutti i constraint |

### 2.3 Dynamic Performance Views (V$)

| Vista | A Cosa Serve |
|---|---|
| `V$INSTANCE` | Stato dell'istanza |
| `V$DATABASE` | Info sul database |
| `V$SESSION` | Sessioni attive |
| `V$PROCESS` | Processi del server |
| `V$SGA` | Dimensioni SGA |
| `V$PARAMETER` | Parametri di inizializzazione |
| `V$LOG` | Redo log groups |
| `V$ARCHIVED_LOG` | Archived redo logs |
| `V$ASM_DISKGROUP` | Disk group ASM |
| `GV$INSTANCE` | Come V$ ma per tutte le istanze RAC |

### 2.4 ADR (Automatic Diagnostic Repository)

```bash
# Struttura ADR
$ORACLE_BASE/diag/rdbms/<db_name>/<instance_name>/
├── alert/     # Alert log in XML
├── trace/     # Trace files
├── incident/  # Incidenti (crash, ORA-600)
└── cdump/     # Core dumps

# Usa ADRCI per navigare
adrci
> show homes
> set home diag/rdbms/racdb/racdb1
> show alert -tail 50
> show incident
```

### 2.5 Initialization Parameters

```sql
-- Visualizza tutti i parametri
SHOW PARAMETER;
SHOW PARAMETER db_name;

-- Modifica un parametro (spfile)
ALTER SYSTEM SET sga_target=2G SCOPE=BOTH;
-- SCOPE: MEMORY (solo sessione), SPFILE (solo spfile), BOTH

-- Crea pfile da spfile (backup)
CREATE PFILE='/tmp/init_backup.ora' FROM SPFILE;
```

---

## PARTE 3: Utenti, Ruoli e Privilegi

> 📖 Riferimento Lab: [GUIDA_CDB_PDB_UTENTI.md](./GUIDA_CDB_PDB_UTENTI.md)

### 3.1 Creazione Utenti e Quote

```sql
-- Crea utente con quota
CREATE USER app_user IDENTIFIED BY "SecurePass123!"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA 500M ON users
  QUOTA UNLIMITED ON app_data;

-- Assegna quota
ALTER USER app_user QUOTA 1G ON users;
```

### 3.2 Principio del Minimo Privilegio

```sql
-- NON fare mai questo in produzione:
GRANT DBA TO app_user;  -- ❌ MAI!

-- Fai questo:
GRANT CREATE SESSION TO app_user;           -- ✅ Login
GRANT SELECT ON hr.employees TO app_user;   -- ✅ Solo lettura
GRANT INSERT, UPDATE ON hr.departments TO app_user;  -- ✅ Solo scrittura specifica
```

### 3.3 Profili

```sql
-- Profilo per limitare risorse e password
CREATE PROFILE app_profile LIMIT
  SESSIONS_PER_USER          5
  CPU_PER_SESSION            UNLIMITED
  IDLE_TIME                  30
  CONNECT_TIME               480
  FAILED_LOGIN_ATTEMPTS      5
  PASSWORD_LOCK_TIME         1/24
  PASSWORD_LIFE_TIME         90
  PASSWORD_REUSE_TIME        365
  PASSWORD_REUSE_MAX         12
  PASSWORD_GRACE_TIME        7;

ALTER USER app_user PROFILE app_profile;
```

### 3.4 Ruoli

```sql
-- Crea ruolo personalizzato
CREATE ROLE app_readonly;
GRANT SELECT ANY TABLE TO app_readonly;
GRANT CREATE SESSION TO app_readonly;

-- Assegna ruolo
GRANT app_readonly TO app_user;

-- Ruoli predefiniti importanti
-- CONNECT, RESOURCE, DBA, SELECT_CATALOG_ROLE
```

---

## PARTE 4: Gestione Storage

> 📖 Riferimento Lab: [GUIDA_ATTIVITA_DBA.md](./GUIDA_ATTIVITA_DBA.md)

### 4.1 Resumable Space Allocation

```sql
-- Abilita operazioni resumable (si fermano invece di fallire se lo spazio finisce)
ALTER SESSION ENABLE RESUMABLE;
ALTER SYSTEM SET RESUMABLE_TIMEOUT = 3600;  -- 1 ora di attesa

-- Monitora
SELECT * FROM DBA_RESUMABLE;
```

### 4.2 Segment Shrink

```sql
-- Riduci spazio frammentato in una tabella
ALTER TABLE hr.employees ENABLE ROW MOVEMENT;
ALTER TABLE hr.employees SHRINK SPACE CASCADE;
-- CASCADE include anche gli indici
```

### 4.3 Deferred Segment Creation

```sql
-- La tabella non occupa spazio finche non inserisci dati
ALTER SYSTEM SET DEFERRED_SEGMENT_CREATION=TRUE;

-- Ora le tabelle vuote non hanno segmenti
CREATE TABLE test_deferred (id NUMBER, name VARCHAR2(100));
-- Nessun extent allocato fino al primo INSERT
```

### 4.4 Compressione Tabelle e Righe

```sql
-- Basic compression (solo direct-path insert)
CREATE TABLE sales_archive COMPRESS BASIC AS SELECT * FROM sales;

-- Advanced compression (OLTP — anche DML normali)
ALTER TABLE orders COMPRESS FOR OLTP;

-- HCC (Hybrid Columnar Compression — solo Exadata)
-- CREATE TABLE ... COMPRESS FOR QUERY HIGH;
```

### 4.5 Block Space Management

```sql
-- ASSM (Automatic Segment Space Management) — default e consigliato
CREATE TABLESPACE app_data
  DATAFILE '+DATA' SIZE 1G
  AUTOEXTEND ON NEXT 100M MAXSIZE 10G
  SEGMENT SPACE MANAGEMENT AUTO;   -- ASSM

-- MSSM (Manual) — legacy, NON usare
-- SEGMENT SPACE MANAGEMENT MANUAL;
```

---

## PARTE 5: Spostamento Dati

> 📖 Riferimento Lab: [GUIDA_ATTIVITA_DBA.md](./GUIDA_ATTIVITA_DBA.md)

### 5.1 External Tables

```sql
-- Legge un file CSV come se fosse una tabella SQL
CREATE DIRECTORY ext_dir AS '/tmp/data';

CREATE TABLE ext_employees (
  emp_id    NUMBER,
  emp_name  VARCHAR2(100),
  salary    NUMBER
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER
  DEFAULT DIRECTORY ext_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
    FIELDS TERMINATED BY ','
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('employees.csv')
);

SELECT * FROM ext_employees;  -- Legge direttamente il CSV!
```

### 5.2 Oracle Data Pump

```bash
# Export schema
expdp system/password SCHEMAS=hr DIRECTORY=dp_dir DUMPFILE=hr_export.dmp LOGFILE=hr_export.log

# Import schema
impdp system/password SCHEMAS=hr DIRECTORY=dp_dir DUMPFILE=hr_export.dmp LOGFILE=hr_import.log

# Export full database
expdp system/password FULL=y DIRECTORY=dp_dir DUMPFILE=full_%U.dmp PARALLEL=4

# Export solo metadati (senza dati)
expdp system/password SCHEMAS=hr CONTENT=METADATA_ONLY DIRECTORY=dp_dir DUMPFILE=hr_ddl.dmp
```

### 5.3 SQL*Loader

```bash
# Control file (loader.ctl)
cat > loader.ctl <<'EOF'
LOAD DATA
INFILE 'employees.csv'
INTO TABLE hr.employees
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
(employee_id, first_name, last_name, email, salary)
EOF

# Esegui il caricamento
sqlldr hr/password CONTROL=loader.ctl LOG=load.log BAD=load.bad DISCARD=load.dsc
```

---

## PARTE 6: Strumenti di Accesso

> 📖 Riferimento Lab: [GUIDA_COMANDI_DBA.md](./GUIDA_COMANDI_DBA.md)

| Strumento | Uso | Comando/URL |
|---|---|---|
| **SQL*Plus** | CLI classica, scripting | `sqlplus / as sysdba` |
| **SQL Developer** | GUI, sviluppo SQL | Download gratuito Oracle |
| **DBCA** | Crea/gestisce database | `dbca` (GUI) |
| **EM Express** | Web monitoring leggero | `https://rac1:5500/em` |
| **EM Cloud Control** | Enterprise monitoring | `https://oem:7803/em` |

---

## PARTE 7: Oracle Net Services

> 📖 Riferimento Lab: [GUIDA_LISTENER_SERVICES_DBA.md](./GUIDA_LISTENER_SERVICES_DBA.md)

### 7.1 Listener

```bash
# Stato listener
lsnrctl status

# In RAC, usa SCAN listener (gestito da Grid)
srvctl status scan_listener
srvctl config scan_listener

# Listener locale
srvctl status listener -l LISTENER
```

### 7.2 tnsnames.ora

```
RACDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = RACDB)
    )
  )
```

### 7.3 Dedicated vs Shared Server

| | Dedicated | Shared |
|---|---|---|
| **Processo** | 1 server process per sessione | Pool di shared server processes |
| **Memoria** | Più PGA per sessione | Meno PGA, usa Large Pool |
| **Uso** | Default, OLTP | Tante connessioni idle |
| **Config** | `SERVER=DEDICATED` | `SHARED_SERVERS=5` |

### 7.4 Naming Methods

| Metodo | File/Servizio | Uso |
|---|---|---|
| **Local Naming** | `tnsnames.ora` | Client → DB specifico |
| **Directory Naming** | LDAP/OID | Enterprise |
| **Easy Connect** | Nessun file | `sqlplus user/pass@host:port/service` |

---

## PARTE 8: Tablespace e Datafile

> 📖 Riferimento Lab: [GUIDA_ATTIVITA_DBA.md](./GUIDA_ATTIVITA_DBA.md)

```sql
-- Crea tablespace
CREATE TABLESPACE app_data
  DATAFILE '+DATA' SIZE 1G
  AUTOEXTEND ON NEXT 100M MAXSIZE 10G;

-- Aggiungi datafile
ALTER TABLESPACE app_data ADD DATAFILE '+DATA' SIZE 500M;

-- Ridimensiona datafile
ALTER DATABASE DATAFILE '+DATA/RACDB/datafile/app_data.dbf' RESIZE 2G;

-- Tablespace di sola lettura
ALTER TABLESPACE archive_data READ ONLY;

-- Drop tablespace
DROP TABLESPACE old_data INCLUDING CONTENTS AND DATAFILES;

-- Oracle Managed Files (OMF) — Oracle gestisce i nomi dei file
ALTER SYSTEM SET DB_CREATE_FILE_DEST='+DATA';
CREATE TABLESPACE omf_test;  -- Nessun DATAFILE specificato!

-- Move/Rename datafile online (12c+)
ALTER DATABASE MOVE DATAFILE '+DATA/old_path' TO '+DATA/new_path';

-- Visualizza info
SELECT tablespace_name, file_name, bytes/1024/1024 MB FROM dba_data_files;
SELECT tablespace_name, bytes/1024/1024 free_mb FROM dba_free_space;
```

---

## PARTE 9: Gestione Undo

```sql
-- Verifica undo tablespace attivo
SHOW PARAMETER undo_tablespace;
-- RACDB1: UNDOTBS1, RACDB2: UNDOTBS2

-- Undo retention (secondi)
SHOW PARAMETER undo_retention;
ALTER SYSTEM SET UNDO_RETENTION=1800;  -- 30 minuti

-- Monitora utilizzo undo
SELECT tablespace_name, status, COUNT(*) extents, SUM(bytes)/1024/1024 MB
FROM dba_undo_extents GROUP BY tablespace_name, status;
-- status: ACTIVE (in uso), UNEXPIRED (entro retention), EXPIRED (riciclabile)

-- Crea nuovo undo tablespace
CREATE UNDO TABLESPACE undotbs3 DATAFILE '+DATA' SIZE 500M AUTOEXTEND ON;

-- Temporary Undo (12c+) — undo per global temporary tables va in TEMP
ALTER SYSTEM SET TEMP_UNDO_ENABLED=TRUE;
```

> **Undo vs Redo**: L'**undo** serve per annullare (rollback) e leggere dati consistenti (read consistency). Il **redo** serve per ripetere (recovery) le modifiche dopo un crash. Sono complementari.

---

## PARTE 10: SQL Fundamentals

### 10.1 SELECT e Filtraggio

```sql
-- SELECT base
SELECT employee_id, first_name || ' ' || last_name AS full_name, salary
FROM hr.employees
WHERE department_id = 50
  AND salary > 5000
ORDER BY salary DESC;

-- DISTINCT
SELECT DISTINCT department_id FROM hr.employees;

-- Alias con spazi (doppi apici)
SELECT salary * 12 AS "Salario Annuale" FROM hr.employees;

-- Alternative quote operator (q'')
SELECT q'[L'apostrofo non e' un problema]' FROM dual;

-- DESCRIBE
DESC hr.employees;

-- Operatori di precedenza: (), *, /, +, -, ||
SELECT first_name, salary, salary + salary * 0.1 AS "Con Bonus" FROM hr.employees;

-- NULL: qualsiasi operazione con NULL = NULL
SELECT first_name, salary, salary + commission_pct FROM hr.employees;
-- Se commission_pct e NULL, il risultato e NULL!
```

### 10.2 Funzioni Single-Row

```sql
-- Stringhe
SELECT UPPER('hello'), LOWER('HELLO'), INITCAP('hello world') FROM dual;
SELECT SUBSTR('Oracle', 1, 3), LENGTH('Oracle'), INSTR('Oracle', 'a') FROM dual;
SELECT LPAD('42', 5, '0'), RPAD('Hi', 10, '.'), TRIM('  hello  ') FROM dual;
SELECT REPLACE('Hello World', 'World', 'Oracle') FROM dual;

-- Numeri
SELECT ROUND(45.926, 2), TRUNC(45.926, 2), MOD(1600, 300) FROM dual;
-- ROUND: 45.93, TRUNC: 45.92, MOD: 100

-- Date
SELECT SYSDATE, SYSDATE + 7, MONTHS_BETWEEN(SYSDATE, hire_date) FROM hr.employees;
SELECT ADD_MONTHS(SYSDATE, 6), NEXT_DAY(SYSDATE, 'MONDAY'), LAST_DAY(SYSDATE) FROM dual;
SELECT ROUND(SYSDATE, 'MONTH'), TRUNC(SYSDATE, 'YEAR') FROM dual;
```

### 10.3 Funzioni di Conversione

```sql
-- TO_CHAR (numero/data → stringa)
SELECT TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') FROM dual;
SELECT TO_CHAR(salary, '$99,999.00') FROM hr.employees;

-- TO_NUMBER (stringa → numero)
SELECT TO_NUMBER('1,234.56', '9,999.99') FROM dual;

-- TO_DATE (stringa → data)
SELECT TO_DATE('15-03-2025', 'DD-MM-YYYY') FROM dual;

-- NVL, NULLIF, COALESCE
SELECT NVL(commission_pct, 0) FROM hr.employees;                    -- Se NULL, ritorna 0
SELECT NULLIF(length(first_name), length(last_name)) FROM hr.employees;  -- NULL se uguali
SELECT COALESCE(commission_pct, salary * 0.01, 0) FROM hr.employees;     -- Primo non-NULL
```

### 10.4 JOIN

```sql
-- INNER JOIN
SELECT e.first_name, d.department_name
FROM hr.employees e JOIN hr.departments d ON e.department_id = d.department_id;

-- LEFT OUTER JOIN (tutti i dipendenti, anche senza dipartimento)
SELECT e.first_name, d.department_name
FROM hr.employees e LEFT JOIN hr.departments d ON e.department_id = d.department_id;

-- RIGHT OUTER JOIN
SELECT e.first_name, d.department_name
FROM hr.employees e RIGHT JOIN hr.departments d ON e.department_id = d.department_id;

-- FULL OUTER JOIN
SELECT e.first_name, d.department_name
FROM hr.employees e FULL OUTER JOIN hr.departments d ON e.department_id = d.department_id;

-- SELF JOIN (manager)
SELECT e.first_name AS "Dipendente", m.first_name AS "Manager"
FROM hr.employees e JOIN hr.employees m ON e.manager_id = m.employee_id;

-- Non equijoin
SELECT e.first_name, e.salary, g.grade_level
FROM hr.employees e JOIN hr.job_grades g ON e.salary BETWEEN g.lowest_sal AND g.highest_sal;
```

### 10.5 Group Functions e SET Operators

```sql
-- Group Functions
SELECT department_id, COUNT(*), AVG(salary), MIN(salary), MAX(salary), SUM(salary)
FROM hr.employees GROUP BY department_id HAVING COUNT(*) > 5;

-- SET Operators
SELECT employee_id FROM hr.employees WHERE department_id = 10
UNION          -- Unione senza duplicati
SELECT employee_id FROM hr.employees WHERE department_id = 20;

-- UNION ALL (con duplicati), INTERSECT, MINUS
SELECT department_id FROM hr.employees
MINUS
SELECT department_id FROM hr.departments WHERE location_id = 1700;
```

### 10.6 Subqueries

```sql
-- Single-row subquery
SELECT * FROM hr.employees
WHERE salary > (SELECT AVG(salary) FROM hr.employees);

-- Multi-row subquery (IN, ANY, ALL)
SELECT * FROM hr.employees
WHERE department_id IN (SELECT department_id FROM hr.departments WHERE location_id = 1700);

-- Correlated subquery
SELECT e.first_name, e.salary
FROM hr.employees e
WHERE e.salary > (SELECT AVG(salary) FROM hr.employees WHERE department_id = e.department_id);
```

### 10.7 DML, DDL, Transaction Control

```sql
-- DML
INSERT INTO hr.departments VALUES (300, 'AI Lab', NULL, 1700);
UPDATE hr.employees SET salary = salary * 1.10 WHERE department_id = 50;
DELETE FROM hr.departments WHERE department_id = 300;
MERGE INTO target t USING source s ON (t.id = s.id)
  WHEN MATCHED THEN UPDATE SET t.val = s.val
  WHEN NOT MATCHED THEN INSERT VALUES (s.id, s.val);

-- DDL
CREATE TABLE test (id NUMBER PRIMARY KEY, name VARCHAR2(100) NOT NULL);
ALTER TABLE test ADD (email VARCHAR2(200));
ALTER TABLE test MODIFY (name VARCHAR2(200));
DROP TABLE test PURGE;
TRUNCATE TABLE test;                    -- DDL! Non genera undo

-- Transaction Control
COMMIT;
ROLLBACK;
SAVEPOINT sp1;
ROLLBACK TO sp1;
```

### 10.8 Sequences, Synonyms, Indexes, Views

```sql
-- Sequences
CREATE SEQUENCE emp_seq START WITH 1000 INCREMENT BY 1 NOCACHE;
SELECT emp_seq.NEXTVAL FROM dual;

-- Synonyms
CREATE PUBLIC SYNONYM emp FOR hr.employees;

-- Indexes
CREATE INDEX idx_emp_name ON hr.employees(last_name);
CREATE UNIQUE INDEX idx_emp_email ON hr.employees(email);
CREATE BITMAP INDEX idx_emp_dept ON hr.employees(department_id);  -- Per low-cardinality

-- Views
CREATE OR REPLACE VIEW emp_summary AS
  SELECT department_id, COUNT(*) cnt, AVG(salary) avg_sal
  FROM hr.employees GROUP BY department_id;

-- Temporary tables
CREATE GLOBAL TEMPORARY TABLE temp_results (id NUMBER, result VARCHAR2(100))
  ON COMMIT DELETE ROWS;  -- o ON COMMIT PRESERVE ROWS

-- Constraints
ALTER TABLE hr.employees ADD CONSTRAINT chk_salary CHECK (salary > 0);
ALTER TABLE hr.employees MODIFY (email CONSTRAINT nn_email NOT NULL);
```

### 10.9 Time Zones

```sql
-- Current date/time functions
SELECT CURRENT_DATE, CURRENT_TIMESTAMP, LOCALTIMESTAMP FROM dual;
SELECT DBTIMEZONE, SESSIONTIMEZONE FROM dual;

-- INTERVAL types
SELECT SYSDATE + INTERVAL '30' DAY FROM dual;
SELECT SYSDATE + INTERVAL '3' MONTH FROM dual;
SELECT SYSDATE + INTERVAL '1-6' YEAR TO MONTH FROM dual;
SELECT TIMESTAMP '2025-01-01 00:00:00' + INTERVAL '10:30' HOUR TO MINUTE FROM dual;
```

---

## PARTE 11: DBA Professional 2 (1Z0-083)

> 📖 Riferimento Lab: Tutte le guide del lab coprono questi argomenti avanzati.

### 11.1 ASM (Automatic Storage Management)

```sql
-- Comandi ASM da SYSASM
sqlplus / as sysasm
SELECT name, state, type, total_mb, free_mb, usable_file_mb FROM v$asm_diskgroup;
SELECT name, path, mode_status, header_status FROM v$asm_disk;

-- Crea disk group
CREATE DISKGROUP DATA NORMAL REDUNDANCY
  FAILGROUP fg1 DISK '/dev/sdc1' NAME data_01
  FAILGROUP fg2 DISK '/dev/sdd1' NAME data_02
  FAILGROUP fg3 DISK '/dev/sde1' NAME data_03
  ATTRIBUTE 'compatible.asm'='19.0', 'compatible.rdbms'='19.0';

-- Aggiungi disco
ALTER DISKGROUP data ADD DISK '/dev/sdh1' NAME data_04 FAILGROUP fg1;

-- Rebalance
ALTER DISKGROUP data REBALANCE POWER 8;

-- Drop disk (rebalance automatico)
ALTER DISKGROUP data DROP DISK data_03;
```

> Nel nostro lab usiamo **ASMLib (`oracleasm`)** per la gestione dei dischi, vedi [Fase 0](./GUIDA_FASE0_SETUP_MACCHINE.md) e [Fase 2](./GUIDA_FASE2_GRID_E_RAC.md).

### 11.2 High Availability: RAC e Data Guard

> 📖 Riferimento Lab: [Fase 2](./GUIDA_FASE2_GRID_E_RAC.md), [Fase 3](./GUIDA_FASE3_RAC_STANDBY.md), [Fase 4](./GUIDA_FASE4_DATAGUARD_DGMGRL.md)

```bash
# RAC — comandi chiave
crsctl stat res -t                    # Stato risorse cluster
srvctl status database -d RACDB       # Stato database RAC
srvctl config database -d RACDB       # Configurazione
srvctl relocate service -d RACDB -s svc1 -i RACDB1 -t RACDB2  # Sposta servizio

# Data Guard — DGMGRL
dgmgrl sys/<password>
> show configuration;
> show database 'RACDB';
> switchover to 'RACDB_STBY';
> failover to 'RACDB_STBY';
```

**Protection Modes**:
| Mode | Redo Transport | Data Loss? |
|---|---|---|
| Maximum Performance | ASYNC | Possibile |
| Maximum Availability | SYNC + fallback ASYNC | No (normalmente) |
| Maximum Protection | SYNC (primary si ferma se stby non risponde) | Mai |

### 11.3 RMAN Avanzato

> 📖 Riferimento Lab: [GUIDA_FASE7_RMAN_BACKUP.md](./GUIDA_FASE7_RMAN_BACKUP.md)

```bash
# Backup incrementale Level 0 (full base)
RMAN> BACKUP INCREMENTAL LEVEL 0 DATABASE PLUS ARCHIVELOG;

# Backup incrementale Level 1 (solo cambiamenti)
RMAN> BACKUP INCREMENTAL LEVEL 1 DATABASE PLUS ARCHIVELOG;

# Block Change Tracking (velocizza Level 1)
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+RECO/bct.dbf';

# Compressione backup
RMAN> CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';
RMAN> BACKUP AS COMPRESSED BACKUPSET DATABASE;

# Encryption
RMAN> CONFIGURE ENCRYPTION FOR DATABASE ON;
RMAN> SET ENCRYPTION ON IDENTIFIED BY 'backup_password' ONLY;

# Multi-section backup (parallelo per file grandi)
RMAN> BACKUP SECTION SIZE 2G DATABASE;

# Flashback database
ALTER DATABASE FLASHBACK ON;
FLASHBACK DATABASE TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '1' HOUR);
ALTER DATABASE OPEN RESETLOGS;
```

### 11.4 CDB/PDB (Multitenant)

> 📖 Riferimento Lab: [GUIDA_CDB_PDB_UTENTI.md](./GUIDA_CDB_PDB_UTENTI.md)

```sql
-- Crea PDB
CREATE PLUGGABLE DATABASE pdb2 ADMIN USER pdb2admin IDENTIFIED BY "Pass123!"
  STORAGE (MAXSIZE 10G)
  FILE_NAME_CONVERT = ('+DATA/RACDB/pdbseed/', '+DATA/RACDB/pdb2/');

-- Apri e salva stato per auto-start
ALTER PLUGGABLE DATABASE pdb2 OPEN;
ALTER PLUGGABLE DATABASE pdb2 SAVE STATE;

-- Clona PDB
CREATE PLUGGABLE DATABASE pdb3 FROM pdb2;

-- Unplug/Plug
ALTER PLUGGABLE DATABASE pdb2 CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE pdb2 UNPLUG INTO '/tmp/pdb2.xml';
DROP PLUGGABLE DATABASE pdb2 KEEP DATAFILES;
CREATE PLUGGABLE DATABASE pdb2_new USING '/tmp/pdb2.xml' NOCOPY;
```

### 11.5 Performance Tuning (AWR/ADDM/ASH)

> 📖 Riferimento Lab: [GUIDA_ATTIVITA_DBA.md](./GUIDA_ATTIVITA_DBA.md)

```sql
-- Genera AWR Report
@$ORACLE_HOME/rdbms/admin/awrrpt.sql
-- Scegli HTML, snap_id inizio e fine

-- ADDM (Automatic Database Diagnostic Monitor)
@$ORACLE_HOME/rdbms/admin/addmrpt.sql

-- ASH Report (Active Session History)
@$ORACLE_HOME/rdbms/admin/ashrpt.sql

-- SQL Tuning Advisor
DECLARE
  l_task VARCHAR2(64);
BEGIN
  l_task := DBMS_SQLTUNE.CREATE_TUNING_TASK(sql_id => 'abc123xyz');
  DBMS_SQLTUNE.EXECUTE_TUNING_TASK(l_task);
END;
/
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('task_name') FROM dual;

-- Optimizer Statistics
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('HR');
EXEC DBMS_STATS.GATHER_TABLE_STATS('HR', 'EMPLOYEES');

-- Resource Manager
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();
  DBMS_RESOURCE_MANAGER.CREATE_PLAN(plan => 'DAY_PLAN', comment => 'Plan for daytime');
  DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP(consumer_group => 'OLTP_GROUP', comment => 'OLTP');
  DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();
END;
/
```

### 11.6 Security Avanzata

```sql
-- Unified Auditing (19c+)
CREATE AUDIT POLICY sensitive_ops
  ACTIONS DELETE ON hr.employees,
          ALTER TABLE,
          DROP TABLE;
AUDIT POLICY sensitive_ops;

-- TDE (Transparent Data Encryption)
-- 1. Configura wallet
ALTER SYSTEM SET WALLET_ROOT='/u01/app/oracle/admin/RACDB/wallet' SCOPE=SPFILE;
ALTER SYSTEM SET TDE_CONFIGURATION='KEYSTORE_CONFIGURATION=FILE' SCOPE=BOTH;
STARTUP FORCE;

-- 2. Crea keystore
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE '/u01/app/oracle/admin/RACDB/wallet' IDENTIFIED BY "<wallet_password>";
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "<wallet_password>";
ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY "<wallet_password>" WITH BACKUP;

-- 3. Cripta tablespace
ALTER TABLESPACE sensitive_data ENCRYPTION ONLINE ENCRYPT;

-- Network Encryption (sqlnet.ora)
-- SQLNET.ENCRYPTION_SERVER=REQUIRED
-- SQLNET.ENCRYPTION_TYPES_SERVER=(AES256)
```

### 11.7 Patching e Upgrades

> 📖 Riferimento Lab: [Fase 2 — sezione 2.8](./GUIDA_FASE2_GRID_E_RAC.md)

```bash
# Workflow patching RAC
# 1. Aggiorna OPatch
mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bkp
unzip -q p6880880_230000_Linux-x86-64.zip -d $ORACLE_HOME/

# 2. Applica RU alla Grid Home (come root)
$GRID_HOME/OPatch/opatchauto apply /tmp/patch/37957391 -oh $GRID_HOME

# 3. Applica RU alla DB Home (come root)
$ORACLE_HOME/OPatch/opatchauto apply /tmp/patch/37957391 -oh $ORACLE_HOME

# 4. Applica datapatch (come oracle)
$ORACLE_HOME/OPatch/datapatch -verbose

# 5. Verifica
$ORACLE_HOME/OPatch/opatch lspatches
SELECT patch_id, status FROM dba_registry_sqlpatch;
```

---

## ✅ Mappa Esame → Lab

| Argomento Esame | Dove lo Pratichi nel Lab |
|---|---|
| DB Architecture | [GUIDA_ARCHITETTURA_ORACLE.md](./GUIDA_ARCHITETTURA_ORACLE.md) |
| Instance Management | [GUIDA_COMANDI_DBA.md](./GUIDA_COMANDI_DBA.md) |
| Users/Roles/Privileges | [GUIDA_CDB_PDB_UTENTI.md](./GUIDA_CDB_PDB_UTENTI.md) |
| Storage Management | [GUIDA_ATTIVITA_DBA.md](./GUIDA_ATTIVITA_DBA.md) |
| Data Pump / SQL*Loader | [GUIDA_ATTIVITA_DBA.md](./GUIDA_ATTIVITA_DBA.md) |
| Net Services / Listener | [GUIDA_LISTENER_SERVICES_DBA.md](./GUIDA_LISTENER_SERVICES_DBA.md) |
| Tablespaces | [GUIDA_ATTIVITA_DBA.md](./GUIDA_ATTIVITA_DBA.md) |
| ASM | [Fase 0](./GUIDA_FASE0_SETUP_MACCHINE.md) + [Fase 2](./GUIDA_FASE2_GRID_E_RAC.md) |
| RAC | [Fase 2](./GUIDA_FASE2_GRID_E_RAC.md) |
| Data Guard | [Fase 3](./GUIDA_FASE3_RAC_STANDBY.md) + [Fase 4](./GUIDA_FASE4_DATAGUARD_DGMGRL.md) |
| RMAN | [GUIDA_FASE7_RMAN_BACKUP.md](./GUIDA_FASE7_RMAN_BACKUP.md) |
| CDB/PDB | [GUIDA_CDB_PDB_UTENTI.md](./GUIDA_CDB_PDB_UTENTI.md) |
| Performance Tuning | [GUIDA_ATTIVITA_DBA.md](./GUIDA_ATTIVITA_DBA.md) |
| GoldenGate | [Fase 5](./GUIDA_FASE5_GOLDENGATE.md) |
| Switchover/Failover | [GUIDA_SWITCHOVER_COMPLETO.md](./GUIDA_SWITCHOVER_COMPLETO.md) + [GUIDA_FAILOVER_E_REINSTATE.md](./GUIDA_FAILOVER_E_REINSTATE.md) |
| Security | [GUIDA_CDB_PDB_UTENTI.md](./GUIDA_CDB_PDB_UTENTI.md) |
| Patching | [Fase 2 — sez. 2.8](./GUIDA_FASE2_GRID_E_RAC.md) |
| Oracle→PostgreSQL | [GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md](./GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md) |

---

> → **Prossimo**: [GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md](./GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md) — Migrazione Oracle → PostgreSQL con GoldenGate
