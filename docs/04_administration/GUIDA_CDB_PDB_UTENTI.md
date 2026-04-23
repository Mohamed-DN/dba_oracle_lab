# GUIDA: CDB/PDB, Gestione Utenti e EM Express

> Questa guida copre 3 aree fondamentali per un DBA Oracle 19c che spesso mancano nei lab RAC:
> l'architettura Multitenant (CDB/PDB), la gestione utenti/privilegi, e Enterprise Manager Express.
> **Fonti**: Oracle 19c Database Administration (Tanveer A.), Oracle DBA Administration (MSU).

---

## Percorso di Lettura

```
╔══════════════════════════════════════════════════════════════════════════╗
║  PRIMA di questa guida leggi: GUIDA_ARCHITETTURA_ORACLE.md              ║
║  DOPO questa guida leggi:     GUIDA_ATTIVITA_DBA.md                     ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

## Obiettivo

Fornire una guida pratica per amministrare CDB/PDB in Oracle 19c, includendo anche la
gestione di scenari con **Transparent Data Encryption (TDE)** già attiva o da attivare.

## Procedura operativa

Questa guida segue il flusso:

1. Fondamenti CDB/PDB e operazioni core (create/clone/unplug/plug)
2. Gestione utenti, ruoli e profili in contesto enterprise
3. Sezione dedicata: creazione e gestione PDB in presenza di TDE

## Validazione finale

A fine guida verifica sempre:

- stato PDB (`SHOW PDBS`, `V$PDBS`);
- stato utenti/ruoli/profili (`DBA_USERS`, `DBA_ROLE_PRIVS`);
- se TDE è coinvolta: stato keystore e chiavi (`V$ENCRYPTION_WALLET`, `V$ENCRYPTION_KEYS`).

## Troubleshooting rapido

- PDB non apre dopo clone/plug: controlla compatibilità, path file e stato servizi.
- Errori privilege su utenti: verifica `GRANT` effettivi e container corrente.
- Errori TDE/keystore: apri wallet corretto e verifica modalità united/isolated.

---

## PARTE 1: Architettura Multitenant (CDB/PDB)

### Cos'è il Multitenant e Perché Esiste?

Prima di Oracle 12c, ogni database era indipendente: un'istanza, un database, una copia del dizionario. Se avevi 10 applicazioni, servivano 10 database con 10 copie del data dictionary (spreco di memoria e disco).

**Oracle 12c+ ha introdotto il Multitenant:**

```
╔═══════════════════════════════════════════════════════════════════╗
║                ARCHITETTURA NON-CDB (prima di 12c)                ║
║                                                                    ║
║   Istanza A     Istanza B     Istanza C     Istanza D              ║
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
║               UNA SOLA Istanza (CDB)                               ║
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
║   │ vuoto)  │ │  dati   │ │  dati   │        è un "link" al ROOT  ║
║   └─────────┘ └─────────┘ └─────────┘                             ║
╚═══════════════════════════════════════════════════════════════════╝
```

### I Componenti del CDB

| Componente | Descrizione | Visibilità |
|---|---|---|
| **CDB$ROOT** | Dizionario dati master, metadata Oracle | Solo DBA |
| **PDB$SEED** | Template vuoto per creare nuove PDB | Solo Oracle |
| **PDB (utente)** | Database dell'applicazione, isolato | Applicazione + DBA |
| **UNDO tablespace** | Condiviso da tutte le PDB (in CDB) | CDB |
| **TEMP tablespace** | Ogni PDB può averne uno proprio | Per PDB |

### Il Nostro Lab: CDB o Non-CDB?

> **Nel nostro lab usiamo un database non-CDB** (RACDB senza container). Questo è ancora supportato in 19c ma **desupportato da Oracle 21c+**. Se prepari il CV per il futuro, devi conoscere entrambe le architetture.

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

#### Unplug/Plug (Migrazione PDB)

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

> **Perché è importante per il CV?** In produzione si usa Unplug/Plug per migrare applicazioni tra CDB senza Export/Import. È il modo più veloce per muovere un database tra server.

---

## PARTE 1B: Creazione PDB quando è presente TDE

### Quando serve questa procedura

Usa questa sezione quando:

- il CDB usa TDE (keystore già configurato),
- cloni/sposti PDB con dati cifrati,
- prepari ambienti con policy security enterprise.

### Procedura consigliata (United Mode)

```sql
-- 1) Dal ROOT: verifica stato wallet/keystore
ALTER SESSION SET CONTAINER = CDB$ROOT;
SELECT status, wallet_type, keystore_mode
FROM   v$encryption_wallet;

-- 2) Se CLOSED, apri il keystore
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "Wallet#Pass123" CONTAINER=ALL;

-- 3) Verifica presenza chiave master
SELECT con_id, key_id, creation_time
FROM   v$encryption_keys
ORDER  BY creation_time DESC;
```

Creazione PDB da seed con TDE già operativo nel CDB:

```sql
CREATE PLUGGABLE DATABASE PDB_SEC
  ADMIN USER pdbsec_admin IDENTIFIED BY "StrongPdb#2026"
  FILE_NAME_CONVERT = ('+DATA/CDBRAC/pdbseed/', '+DATA/CDBRAC/pdb_sec/');

ALTER PLUGGABLE DATABASE PDB_SEC OPEN;
ALTER PLUGGABLE DATABASE PDB_SEC SAVE STATE;
```

Clone/spostamento PDB cifrata (quando richiesto dal caso operativo):

```sql
CREATE PLUGGABLE DATABASE PDB_SEC_CLONE FROM PDB_SEC
  FILE_NAME_CONVERT = ('+DATA/CDBRAC/pdb_sec/', '+DATA/CDBRAC/pdb_sec_clone/')
  KEYSTORE IDENTIFIED BY "Wallet#Pass123";
```

### Validazione specifica TDE su PDB

```sql
ALTER SESSION SET CONTAINER = PDB_SEC;

-- Stato wallet visibile dalla PDB
SELECT status, wallet_type, keystore_mode
FROM   v$encryption_wallet;

-- Tablespace cifrati nella PDB
SELECT tablespace_name, encrypted
FROM   dba_tablespaces
ORDER  BY tablespace_name;
```

### Note operative importanti

- In RAC, keystore e configurazione TDE devono essere coerenti su tutti i nodi.
- Prima di switchover/failover Data Guard, verifica sincronizzazione chiavi/keystore.
- Prima di clone/migrazione PDB cifrata, pianifica backup keystore e rollback.

---

## PARTE 2: Gestione Utenti, Ruoli e Privilegi

### Tipi di Utenti Oracle

```
╔═══════════════════════════════════════════════════════════════════╗
║                    GERARCHIA UTENTI ORACLE                        ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ┌─────────────────────────────────────────────────────────────┐  ║
║  │ SYS (SYSDBA)                                                │  ║
║  │ • Proprietario del DD (data dictionary)                     │  ║
║  │ • Può fare TUTTO (startup, shutdown, recover)               │  ║
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
║  │ Utenti DBA personalizzati              │  │ Utenti App     │  ║
║  │ • dba_admin, backup_admin              │  │ • app_user     │  ║
║  │ • Ruoli: DBA, SYSDBA (se servono)      │  │ • app_readonly │  ║
║  │ • Usa QUESTI per il lavoro quotidiano  │  │ • Ruoli custom │  ║
║  └────────────────────────────────────────┘  └────────────────┘  ║
╚═══════════════════════════════════════════════════════════════════╝
```

### Creare un Utente DBA Personalizzato (Best Practice!)

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

### Gestire Utenti Applicazione (Minimo Privilegio!)

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

### Password Profile (Sicurezza Enterprise)

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

### Utenti CDB vs PDB (Multitenant)

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

### Visualizzare e Auditare gli Utenti

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

### Cos'è EM Express?

**EM Express** è l'interfaccia web integrata in Oracle 19c che NON richiede installazioni aggiuntive. È un servlet dentro Oracle XML DB che gira sulla porta HTTPS 5500.

```
╔═══════════════════════════════════════════════════════════════════╗
║                    EM EXPRESS vs EM Cloud Control                  ║
╠══════════════════════════════╦════════════════════════════════════╣
║       EM Express             ║     EM Cloud Control (OMS)        ║
╠══════════════════════════════╬════════════════════════════════════╣
║ ✅ Integrato nel DB          ║ ❌ Installazione separata        ║
║ ✅ Zero overhead             ║ ⚠️ Server dedicato (WebLogic)    ║
║ ✅ Gestisce 1 DB             ║ ✅ Gestisce 100+ DB             ║
║ ✅ Perfetto per il lab       ║ ✅ Perfetto per produzione       ║
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
  User: SYS (o SYSTEM o un utente con DBA)
  Password: la password del DB
  As: SYSDBA (se usi SYS)
```

> **⚠️ Nota VirtualBox**: Per accedere dalla macchina host, assicurati che la porta 5500 della VM sia raggiungibile (la rete Bridged la espone automaticamente).

### Cosa Puoi Fare con EM Express

| Sezione | Cosa Vedi/Fai |
|---|---|
| **Home** | Performance in tempo reale, alert, stato istanza |
| **Performance** | Active Session History (ASH), SQL Monitoring, Top SQL |
| **Storage** | Tablespace, datafile, utilizzo disco |
| **Security** | Utenti, ruoli, privilegi, audit |
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

### SQL Plan Management (SPM) — Bloccare un Piano Buono

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

> **Perché SPM è fondamentale in produzione?** Dopo un aggiornamento di statistiche o un upgrade, Oracle potrebbe "scegliere" un piano di esecuzione peggiore. SPM previene le **regressioni di performance** bloccando i piani che funzionano.

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
anche un utente con DBA o SYSDBA NON può accedere ai dati
dell'applicazione se non è autorizzato dal DBV.

Esempio reale: in una banca, il DBA può gestire il database
(startup, backup, patching) ma NON può leggere i saldi dei conti
correnti. Solo l'applicazione può accedere a quei dati.

-- Questo è un concetto avanzato. Nel lab basta conoscerlo a livello
-- teorico. In produzione è richiesto in settori regolamentati
-- (banche, assicurazioni, sanità).
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

## Esercizi Lab

### Esercizio 1: Crea un Utente DBA Personalizzato

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

> **→ Prossimo: [GUIDA_ATTIVITA_DBA.md](../10_esami_carriera/GUIDA_ATTIVITA_DBA.md)** per batch jobs, AWR/ADDM, patching, e sicurezza avanzata.
