# Guida Password Rollout Oracle Database — Enterprise

> Guida operativa completa per la gestione, rotazione e rollout delle password
> in ambienti Oracle Database 19c/21c/23ai. Copre: profili, verify function,
> gradual rollover (zero-downtime), password file, wallet, Data Guard, RAC,
> integrazione con CyberArk/HashiCorp Vault, audit e compliance.
>
> **Target audience**: DBA Oracle e Security team.

---

## PARTE I — ARCHITETTURA E CONCETTI

---

## 1. Componenti della Gestione Password Oracle

| Componente | Dove | Funzione |
|---|---|---|
| **Profile** | Data Dictionary | Policy: scadenza, complessita, lockout |
| **Password Verify Function** | PL/SQL nel DB | Validazione complessita (lunghezza, charset) |
| **Password File** | `$ORACLE_HOME/dbs/orapwSID` | Auth remota SYSDBA/SYSOPER |
| **Oracle Wallet** | Filesystem/ASM | Storage sicuro credenziali (no password in chiaro) |
| **Gradual Rollover** | Profile (19.12+) | Dual-password per zero-downtime rotation |
| **Unified Audit** | Data Dictionary | Log di tutti i cambi password |

### 1.1 Flusso di Autenticazione

```
Client -> Listener -> Server Process -> Authentication Check
                                          |
                                          +-- Password Hash in SYS.USER$ (utenti normali)
                                          +-- Password File (SYSDBA/SYSOPER remoto)
                                          +-- LDAP/AD (EUS/CMU)
                                          +-- Kerberos (ticket)
```

---

## PARTE II — PROFILI E PASSWORD POLICY

---

## 2. Profili Password

### 2.1 Visualizzare Profili Esistenti

```sql
-- Lista tutti i profili e i loro limiti password
SELECT profile, resource_name, limit
FROM dba_profiles
WHERE resource_type = 'PASSWORD'
ORDER BY profile, resource_name;

-- Utenti per profilo
SELECT username, profile, account_status,
       lock_date, expiry_date, password_change_date
FROM dba_users
WHERE oracle_maintained = 'N'
ORDER BY profile, username;

-- Utenti con password in scadenza nei prossimi 30 giorni
SELECT username, profile, expiry_date,
       ROUND(expiry_date - SYSDATE) AS days_remaining
FROM dba_users
WHERE expiry_date BETWEEN SYSDATE AND SYSDATE + 30
  AND account_status = 'OPEN'
ORDER BY expiry_date;
```

### 2.2 Parametri Password del Profile

| Parametro | Descrizione | Default | Raccomandato |
|---|---|---|---|
| `PASSWORD_LIFE_TIME` | Giorni validita password | 180 | 90 (compliance) |
| `PASSWORD_GRACE_TIME` | Giorni extra dopo scadenza | 7 | 7-14 |
| `PASSWORD_REUSE_TIME` | Giorni prima di riuso | UNLIMITED | 365 |
| `PASSWORD_REUSE_MAX` | N. cambi prima di riuso | UNLIMITED | 12 |
| `FAILED_LOGIN_ATTEMPTS` | Tentativi prima del lock | 10 | 5 |
| `PASSWORD_LOCK_TIME` | Giorni di lock | 1 | 1/1440 (1 minuto) |
| `PASSWORD_VERIFY_FUNCTION` | Funzione di validazione | NULL | `ora12c_verify_function` |
| `PASSWORD_ROLLOVER_TIME` | Finestra dual-password (19.12+) | NULL | 3-7 giorni |
| `INACTIVE_ACCOUNT_TIME` | Giorni inattivita prima lock (19c+) | UNLIMITED | 90 |

### 2.3 Creare Profili Enterprise

```sql
-- ============================================
-- PROFILO: Utenti applicativi (service account)
-- ============================================
CREATE PROFILE app_service_profile LIMIT
  PASSWORD_LIFE_TIME 90
  PASSWORD_GRACE_TIME 14
  PASSWORD_REUSE_TIME 365
  PASSWORD_REUSE_MAX 12
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LOCK_TIME 1/1440        -- 1 minuto di lock
  PASSWORD_VERIFY_FUNCTION ora12c_verify_function
  PASSWORD_ROLLOVER_TIME 7         -- 7 giorni dual-password (19.12+)
  INACTIVE_ACCOUNT_TIME UNLIMITED; -- service account mai inattivo

-- ============================================
-- PROFILO: Utenti interattivi (persone)
-- ============================================
CREATE PROFILE interactive_user_profile LIMIT
  PASSWORD_LIFE_TIME 90
  PASSWORD_GRACE_TIME 7
  PASSWORD_REUSE_TIME 365
  PASSWORD_REUSE_MAX 12
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LOCK_TIME 1/1440
  PASSWORD_VERIFY_FUNCTION ora12c_verify_function
  PASSWORD_ROLLOVER_TIME 3
  INACTIVE_ACCOUNT_TIME 90;

-- ============================================
-- PROFILO: DBA (piu restrittivo)
-- ============================================
CREATE PROFILE dba_admin_profile LIMIT
  PASSWORD_LIFE_TIME 60
  PASSWORD_GRACE_TIME 7
  PASSWORD_REUSE_TIME 365
  PASSWORD_REUSE_MAX 24
  FAILED_LOGIN_ATTEMPTS 3
  PASSWORD_LOCK_TIME 1/1440
  PASSWORD_VERIFY_FUNCTION custom_strong_verify
  PASSWORD_ROLLOVER_TIME 3
  INACTIVE_ACCOUNT_TIME 30;

-- ============================================
-- PROFILO: Monitoring (password non scade)
-- ============================================
CREATE PROFILE monitoring_profile LIMIT
  PASSWORD_LIFE_TIME UNLIMITED
  FAILED_LOGIN_ATTEMPTS 10
  PASSWORD_LOCK_TIME 1
  PASSWORD_VERIFY_FUNCTION ora12c_verify_function;

-- Assegna profili
ALTER USER app_user PROFILE app_service_profile;
ALTER USER dba_admin PROFILE dba_admin_profile;
ALTER USER checkmk_monitor PROFILE monitoring_profile;
```

---

## 3. Password Verify Function

### 3.1 Funzioni Built-in Oracle

```sql
-- Installa le funzioni built-in (se non gia presenti)
@?/rdbms/admin/utlpwdmg.sql

-- Funzioni disponibili dopo l'esecuzione:
-- ora12c_verify_function     (raccomandato per 12c+)
-- ora12c_strong_verify_function  (piu restrittiva)
-- verify_function_11G        (legacy)
```

### 3.2 Regole di ora12c_verify_function

| Regola | Requisito |
|---|---|
| Lunghezza minima | 8 caratteri |
| Almeno 1 lettera | Obbligatorio |
| Almeno 1 cifra | Obbligatorio |
| Diversa dal username | Obbligatorio |
| Diversa dalla precedente | Almeno 3 caratteri diversi |
| Non parola comune | Check dizionario base |

### 3.3 Funzione Custom (Enterprise)

```sql
CREATE OR REPLACE FUNCTION custom_strong_verify (
  username     VARCHAR2,
  password     VARCHAR2,
  old_password VARCHAR2
) RETURN BOOLEAN IS
  n_len     INTEGER;
  n_upper   INTEGER := 0;
  n_lower   INTEGER := 0;
  n_digit   INTEGER := 0;
  n_special INTEGER := 0;
  v_char    VARCHAR2(1);
  differ    INTEGER := 0;
BEGIN
  n_len := LENGTH(password);

  -- Lunghezza minima 12 caratteri
  IF n_len < 12 THEN
    raise_application_error(-20001, 'Password must be at least 12 characters');
  END IF;

  -- Diversa dal username (case insensitive)
  IF UPPER(password) = UPPER(username) THEN
    raise_application_error(-20002, 'Password cannot be the same as the username');
  END IF;

  -- Non contiene il username
  IF INSTR(UPPER(password), UPPER(username)) > 0 THEN
    raise_application_error(-20003, 'Password cannot contain the username');
  END IF;

  -- Conta complessita
  FOR i IN 1..n_len LOOP
    v_char := SUBSTR(password, i, 1);
    IF v_char BETWEEN 'A' AND 'Z' THEN n_upper := n_upper + 1;
    ELSIF v_char BETWEEN 'a' AND 'z' THEN n_lower := n_lower + 1;
    ELSIF v_char BETWEEN '0' AND '9' THEN n_digit := n_digit + 1;
    ELSE n_special := n_special + 1;
    END IF;
  END LOOP;

  IF n_upper < 1 THEN
    raise_application_error(-20004, 'Password must contain at least 1 uppercase letter');
  END IF;
  IF n_lower < 1 THEN
    raise_application_error(-20005, 'Password must contain at least 1 lowercase letter');
  END IF;
  IF n_digit < 1 THEN
    raise_application_error(-20006, 'Password must contain at least 1 digit');
  END IF;
  IF n_special < 1 THEN
    raise_application_error(-20007, 'Password must contain at least 1 special character');
  END IF;

  -- Almeno 4 caratteri diversi dalla vecchia password
  IF old_password IS NOT NULL THEN
    FOR i IN 1..LEAST(n_len, LENGTH(old_password)) LOOP
      IF SUBSTR(password, i, 1) != SUBSTR(old_password, i, 1) THEN
        differ := differ + 1;
      END IF;
    END LOOP;
    IF differ < 4 THEN
      raise_application_error(-20008, 'New password must differ from old by at least 4 characters');
    END IF;
  END IF;

  RETURN TRUE;
END;
/
```

---

## PARTE III — GRADUAL PASSWORD ROLLOVER (ZERO-DOWNTIME)

---

## 4. Gradual Rollover (Oracle 19.12+)

### 4.1 Concetto

```
PRIMA (senza rollover):
  1. Cambia password  --> App si rompe IMMEDIATAMENTE
  2. Aggiorna config app --> Tempo di downtime
  3. Riavvia app

DOPO (con rollover):
  1. Configura PASSWORD_ROLLOVER_TIME = 7 giorni
  2. Cambia password --> ENTRAMBE le password funzionano per 7 giorni
  3. Aggiorna config app con calma (zero downtime)
  4. Dopo 7 giorni, la vecchia password scade automaticamente
```

### 4.2 Implementazione

```sql
-- 1. Verifica la versione (deve essere 19.12+)
SELECT version_full FROM v$instance;

-- 2. Configura il profilo con rollover
ALTER PROFILE app_service_profile LIMIT
  PASSWORD_ROLLOVER_TIME 7;  -- finestra di 7 giorni

-- 3. Assegna il profilo all'utente
ALTER USER app_user PROFILE app_service_profile;

-- 4. Cambia la password (inizia il rollover)
ALTER USER app_user IDENTIFIED BY "NewP@ssword2026!";

-- 5. Verifica lo stato
SELECT username, account_status, password_change_date
FROM dba_users WHERE username = 'APP_USER';
-- account_status sara 'OPEN' con entrambe le password valide

-- 6. Aggiorna le configurazioni applicative (senza fretta)
-- Hai 7 giorni per aggiornare tutto

-- 7. (Opzionale) Forza la fine del rollover prima del tempo
ALTER USER app_user EXPIRE PASSWORD ROLLOVER PERIOD;
```

### 4.3 Verifica dello Stato Rollover

```sql
-- Utenti in stato di rollover
SELECT username, account_status, profile,
       password_change_date,
       expiry_date
FROM dba_users
WHERE account_status LIKE '%ROLLOVER%'
ORDER BY password_change_date;

-- Dettaglio dal profilo
SELECT u.username, p.limit AS rollover_days
FROM dba_users u
JOIN dba_profiles p ON u.profile = p.profile
WHERE p.resource_name = 'PASSWORD_ROLLOVER_TIME'
  AND p.limit != 'DEFAULT' AND p.limit != 'UNLIMITED';
```

---

## PARTE IV — PASSWORD FILE E SYSDBA

---

## 5. Gestione Password File

### 5.1 Verifica Password File

```sql
-- Utenti nel password file
SELECT username, sysdba, sysoper, sysasm, sysbackup, sysdg, syskm
FROM v$pwfile_users;

-- Parametro configurazione
SHOW PARAMETER remote_login_passwordfile;
-- Deve essere EXCLUSIVE per gestione completa
```

### 5.2 Creare/Ricreare Password File

```bash
# Crea nuovo password file
orapwd file=$ORACLE_HOME/dbs/orapwPROD \
  password=NewSysP@ss \
  entries=30 \
  force=y \
  format=12.2

# Per ASM (password file in ASM)
orapwd file='+DATA/PROD/orapwprod' \
  password=NewSysP@ss \
  entries=30 \
  force=y \
  format=12.2 \
  asm_diskstring='+DATA'

# Per RAC: il password file deve essere in ASM
# e condiviso tra tutti i nodi
srvctl modify database -d PROD -pwfile '+DATA/PROD/orapwprod'
```

### 5.3 Rotazione Password SYS

```sql
-- Cambia password SYS (aggiorna automaticamente il password file)
ALTER USER SYS IDENTIFIED BY "NewSysP@ss2026!";

-- Verifica
SELECT username, password_change_date FROM dba_users WHERE username = 'SYS';

-- ATTENZIONE PER DATA GUARD:
-- Dopo aver cambiato SYS sul primary, copia il password file sulla standby
-- Oppure in 19c+ con redo_transport_user dedicato, non serve
```

### 5.4 Rotazione SYS su Data Guard

```bash
# Metodo 1: Copia manuale del password file (tradizionale)
# Sul PRIMARY:
scp $ORACLE_HOME/dbs/orapwPROD standby_host:$ORACLE_HOME/dbs/orapwPROD

# Metodo 2: Se password file in ASM, viene propagato automaticamente
# (richiede redo_transport_user configurato)

# Metodo 3: Usa un utente dedicato per il redo transport (raccomandato)
# Sul PRIMARY:
ALTER SYSTEM SET redo_transport_user = 'REDO_ADMIN' SCOPE=BOTH;
# Sulla STANDBY:
ALTER SYSTEM SET redo_transport_user = 'REDO_ADMIN' SCOPE=BOTH;
# Cosi la password di SYS puo essere cambiata indipendentemente
```

---

## PARTE V — ORACLE WALLET (PASSWORD-LESS)

---

## 6. Oracle Wallet per Connessioni Senza Password

### 6.1 Creare un Wallet con Credenziali

```bash
# 1. Crea la directory wallet
mkdir -p /u01/app/oracle/admin/PROD/wallet

# 2. Crea il wallet
mkstore -wrl /u01/app/oracle/admin/PROD/wallet -create <<EOF
WalletPassword123
WalletPassword123
EOF

# 3. Aggiungi credenziali per un TNS alias
mkstore -wrl /u01/app/oracle/admin/PROD/wallet \
  -createCredential PROD app_user "AppP@ssword2026!"

# Per piu database:
mkstore -wrl /u01/app/oracle/admin/PROD/wallet \
  -createCredential TEST app_user "TestP@ss!"
mkstore -wrl /u01/app/oracle/admin/PROD/wallet \
  -createCredential DEV app_user "DevP@ss!"

# 4. Crea auto-login wallet (non richiede password per aprirlo)
orapki wallet create -wallet /u01/app/oracle/admin/PROD/wallet \
  -auto_login -pwd WalletPassword123

# 5. Verifica
mkstore -wrl /u01/app/oracle/admin/PROD/wallet -listCredential
```

### 6.2 Configurare sqlnet.ora

```
WALLET_LOCATION =
  (SOURCE = (METHOD = FILE)
    (METHOD_DATA = (DIRECTORY = /u01/app/oracle/admin/PROD/wallet)))

SQLNET.WALLET_OVERRIDE = TRUE
```

### 6.3 Connessione Senza Password

```bash
# Connessione senza specificare user/password
sqlplus /@PROD

# Funziona anche per RMAN
rman target /@PROD

# E per Data Pump
expdp /@PROD directory=dpump_dir dumpfile=full.dmp full=y
```

### 6.4 Rotazione Password nel Wallet

```bash
# Quando cambi la password nel DB, aggiorna il wallet:
mkstore -wrl /u01/app/oracle/admin/PROD/wallet \
  -modifyCredential PROD app_user "NuovaPassword2026!"
# Il wallet viene aggiornato senza restart dell'applicazione
```

---

## PARTE VI — PROCEDURE OPERATIVE DI ROLLOUT

---

## 7. Procedura: Rollout Password Singolo Utente

```
Pre-requisiti:
  [ ] Profile con PASSWORD_ROLLOVER_TIME configurato
  [ ] Lista applicazioni che usano l'utente
  [ ] Nuova password generata e conforme alla policy
  [ ] Comunicazione al team applicativo

Procedura:
  1. [ ] Verifica stato attuale:
         SELECT username, account_status, expiry_date FROM dba_users WHERE username='APP_USER';
  2. [ ] Cambia password:
         ALTER USER app_user IDENTIFIED BY "NuovaP@ss2026!";
  3. [ ] Verifica rollover attivo:
         SELECT username, account_status FROM dba_users WHERE username='APP_USER';
  4. [ ] Comunica nuova password al team applicativo (via vault/canale sicuro)
  5. [ ] Team applicativo aggiorna config e riavvia (entro finestra rollover)
  6. [ ] Verifica connessione con nuova password:
         sqlplus app_user/"NuovaP@ss2026!"@PROD
  7. [ ] (Opzionale) Forza fine rollover:
         ALTER USER app_user EXPIRE PASSWORD ROLLOVER PERIOD;
  8. [ ] Aggiorna wallet (se usato):
         mkstore -wrl /wallet_path -modifyCredential PROD app_user "NuovaP@ss2026!"
  9. [ ] Documenta nel change management
```

---

## 8. Procedura: Rollout Massivo (Tutti gli Utenti)

### 8.1 Script PL/SQL per Rotazione Massiva

```sql
-- GENERA gli script di ALTER USER (non esegue direttamente)
SET SERVEROUTPUT ON
DECLARE
  v_new_pwd VARCHAR2(30);
BEGIN
  FOR r IN (
    SELECT username FROM dba_users
    WHERE oracle_maintained = 'N'
      AND account_status = 'OPEN'
      AND profile IN ('APP_SERVICE_PROFILE','INTERACTIVE_USER_PROFILE')
    ORDER BY username
  ) LOOP
    -- Genera password random (12 char, alfanumerica + speciale)
    v_new_pwd := DBMS_RANDOM.STRING('x', 8) ||
                 CHR(TRUNC(DBMS_RANDOM.VALUE(33,47))) ||
                 TRUNC(DBMS_RANDOM.VALUE(1000,9999));
    DBMS_OUTPUT.PUT_LINE('ALTER USER ' || r.username ||
      ' IDENTIFIED BY "' || v_new_pwd || '";');
    DBMS_OUTPUT.PUT_LINE('-- Store in vault: ' || r.username || ' = ' || v_new_pwd);
  END LOOP;
END;
/
-- REVISIONA l'output, poi esegui gli ALTER USER
```

### 8.2 Report Pre-Rollout

```sql
-- Report: stato password di tutti gli utenti
SELECT username, profile, account_status,
       password_change_date,
       expiry_date,
       CASE WHEN expiry_date < SYSDATE THEN 'EXPIRED'
            WHEN expiry_date < SYSDATE + 30 THEN 'EXPIRING SOON'
            ELSE 'OK' END AS pwd_status,
       ROUND(SYSDATE - password_change_date) AS days_since_change
FROM dba_users
WHERE oracle_maintained = 'N'
ORDER BY expiry_date NULLS LAST;
```

---

## PARTE VII — INTEGRAZIONE PAM (CYBERARK / HASHICORP VAULT)

---

## 9. CyberArk Integration

### 9.1 Architettura

```
CyberArk Vault (password store)
  |
  v
CyberArk Central Policy Manager (CPM)
  |--- ODBC ---> Oracle Database (cambia password)
  |
  v
CyberArk Privileged Session Manager (PSM)
  |--- Proxy ---> DBA si connette tramite PSM
```

### 9.2 Configurazione CPM per Oracle

```
1. Installa Oracle Instant Client sul server CPM
2. Configura la piattaforma "Oracle Database" in CyberArk
3. Parametri connessione:
   - ConnectionCommand: Provider=OraOLEDB.Oracle;Data Source=PROD;
   - Port: 1521
   - ChangeCommand: ALTER USER {username} IDENTIFIED BY "{newpassword}"
   - VerifyCommand: SELECT 1 FROM dual
4. Configura la rotazione automatica (es. ogni 90 giorni)
```

### 9.3 Flusso Operativo

```
1. CyberArk CPM genera nuova password conforme alla policy
2. CPM si connette al DB con le credenziali correnti
3. CPM esegue ALTER USER ... IDENTIFIED BY "nuova_password"
4. CPM salva la nuova password nel Vault
5. Le applicazioni recuperano la password dal Vault via API
6. Nessun umano vede mai la password
```

---

## 10. HashiCorp Vault Integration

### 10.1 Database Secrets Engine

```bash
# 1. Abilita il secrets engine per database
vault secrets enable database

# 2. Configura la connessione Oracle
vault write database/config/oracle-prod \
  plugin_name=oracle-database-plugin \
  connection_url="{{username}}/{{password}}@PROD" \
  allowed_roles="app-role,readonly-role" \
  username="vault_admin" \
  password="VaultAdminPwd"

# 3. Crea un ruolo per credenziali dinamiche
vault write database/roles/app-role \
  db_name=oracle-prod \
  creation_statements="CREATE USER {{name}} IDENTIFIED BY \"{{password}}\"; \
    GRANT CONNECT, RESOURCE TO {{name}};" \
  revocation_statements="DROP USER {{name}} CASCADE;" \
  default_ttl="1h" \
  max_ttl="24h"

# 4. Richiedi credenziali dinamiche (dall'applicazione)
vault read database/creds/app-role
# Output:
# username: v-app-role-xxxx
# password: A1B2C3D4-random
# ttl: 1h
```

### 10.2 Static Role (Rotazione Automatica)

```bash
# Per utenti fissi (service account) con rotazione automatica
vault write database/static-roles/app-user \
  db_name=oracle-prod \
  username="APP_USER" \
  rotation_period=86400  # 24 ore

# Vault ruota automaticamente la password ogni 24 ore
# L'app legge la password corrente via API:
vault read database/static-creds/app-user
```

---

## PARTE VIII — AUDIT, MONITORING, TROUBLESHOOTING

---

## 11. Audit Password Changes

```sql
-- Unified Audit: cattura tutti i cambi password
CREATE AUDIT POLICY password_change_audit
  ACTIONS ALTER USER;
AUDIT POLICY password_change_audit;

-- Query: chi ha cambiato password e quando
SELECT event_timestamp, dbusername, 
       sql_text, return_code,
       os_username, userhost
FROM unified_audit_trail
WHERE action_name = 'ALTER USER'
  AND sql_text LIKE '%IDENTIFIED%'
ORDER BY event_timestamp DESC;

-- Report: ultimo cambio password per utente
SELECT username, password_change_date,
       ROUND(SYSDATE - password_change_date) AS days_ago
FROM dba_users
WHERE oracle_maintained = 'N'
ORDER BY password_change_date;
```

---

## 12. Monitoring Proattivo

```sql
-- Alert: utenti con password in scadenza nei prossimi 14 giorni
SELECT 'WARNING: Password expiring in ' || ROUND(expiry_date - SYSDATE) ||
       ' days for ' || username AS alert_msg
FROM dba_users
WHERE expiry_date BETWEEN SYSDATE AND SYSDATE + 14
  AND account_status = 'OPEN'
  AND oracle_maintained = 'N';

-- Alert: account locked
SELECT 'CRITICAL: Account LOCKED - ' || username AS alert_msg
FROM dba_users
WHERE account_status LIKE '%LOCKED%'
  AND oracle_maintained = 'N';

-- Alert: password non cambiata da > 180 giorni
SELECT 'WARNING: Password unchanged for ' || ROUND(SYSDATE - password_change_date) ||
       ' days - ' || username AS alert_msg
FROM dba_users
WHERE password_change_date < SYSDATE - 180
  AND account_status = 'OPEN'
  AND oracle_maintained = 'N';
```

---

## 13. Troubleshooting

| Problema | Causa | Risoluzione |
|---|---|---|
| ORA-28001: password expired | PASSWORD_LIFE_TIME superato | `ALTER USER x IDENTIFIED BY "new";` |
| ORA-28000: account locked | FAILED_LOGIN_ATTEMPTS superato | `ALTER USER x ACCOUNT UNLOCK;` |
| ORA-28003: verify function fail | Password non conforme | Usa password piu complessa |
| ORA-28007: password cannot reused | PASSWORD_REUSE_TIME/MAX | Usa password mai usata prima |
| ORA-28011: account will expire | In grace period | Cambia password prima della scadenza |
| ORA-01017: invalid user/pwd | Password errata o case-sensitive | Check SEC_CASE_SENSITIVE_LOGON |
| Login fallisce dopo rollout | App usa vecchia password | Verifica finestra rollover attiva |
| Wallet non aggiornato | mkstore non eseguito | `mkstore -modifyCredential` |
| Data Guard: login SYS fallisce | Password file non sincronizzato | Copia password file sulla standby |
| CyberArk: rotation fail | CPM non raggiunge il DB | Check network, ODBC, listener |

---

## 14. Best Practice Riepilogative

```
[x] Profili dedicati per tipo utente (app, interactive, DBA, monitoring)
[x] PASSWORD_VERIFY_FUNCTION sempre configurata (mai NULL)
[x] PASSWORD_ROLLOVER_TIME per service account (zero-downtime)
[x] Oracle Wallet per connessioni automatiche (no password in script)
[x] MAI usare SYS per connessioni applicative
[x] redo_transport_user dedicato per Data Guard (indipendenza da SYS)
[x] Unified Audit per tracciare ogni cambio password
[x] Monitoring proattivo: alert su scadenze imminenti
[x] Integrazione PAM (CyberArk/Vault) per rotazione automatica
[x] Test di login dopo ogni cambio password
[x] Documentare ogni rotazione nel change management
[x] Password file in ASM per RAC (condiviso tra nodi)
[x] Backup del wallet separato e sicuro
```

---

## 15. Riferimenti

- Oracle Database Security Guide 19c: Password Management
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-authentication.html
- Oracle Gradual Password Rollover (19.12+)
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-authentication.html#GUID-D4C5E498-B56A-4CD0-8775-D2E6D8B19849
- Oracle Password File Administration
  https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/getting-started-with-database-administration.html
- Oracle Wallet Manager
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-secure-sockets-layer-authentication.html
- HashiCorp Vault Oracle Plugin
  https://developer.hashicorp.com/vault/docs/secrets/databases/oracle
- MOS: Password Management Best Practices (Doc ID 2167986.1)
- MOS: Gradual Password Rollover (Doc ID 2861984.1)
- MOS: ORA-28001 Troubleshooting (Doc ID 1554575.1)

---

**Documento confidenziale ad uso interno DBA. Ultima revisione: Maggio 2026.**
