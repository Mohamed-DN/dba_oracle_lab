# Guida Security Hardening — Oracle 19c RAC

> In lab abbiamo semplificato la sicurezza per concentrarci sull'architettura. In produzione, la sicurezza è il primo requisito. Questa guida copre tutti gli aspetti.

---

## 1. TDE — Transparent Data Encryption

### 1.1 Cos'è TDE

```
SENZA TDE:
  I datafile su disco sono in chiaro.
  Chiunque abbia accesso al filesystem può leggere i dati:
  strings +DATA/RACDB/DATAFILE/users01.dbf | grep "SALARIO"
  → Mostra tutti i salari in chiaro! 😱

CON TDE:
  I blocchi dei datafile sono crittografati AES-256.
  strings +DATA/RACDB/DATAFILE/users01.dbf | grep "SALARIO"
  → Solo caratteri illeggibili 🔒
  Ma le query SQL funzionano normalmente (la decifrazione è trasparente).
```

### 1.2 Configurazione TDE

```sql
sqlplus / as sysdba

-- 1. Configura la Wallet (Keystore) location
-- In sqlnet.ora su TUTTI i nodi RAC:
-- ENCRYPTION_WALLET_LOCATION = (SOURCE = (METHOD = FILE)(METHOD_DATA = (DIRECTORY = /u01/app/oracle/admin/RACDB/wallet)))

-- 2. Crea la Keystore
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE '/u01/app/oracle/admin/RACDB/wallet' IDENTIFIED BY <wallet_password>;

-- 3. Apri la Keystore
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY <wallet_password>;

-- 4. Crea la Master Encryption Key
ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY <wallet_password> WITH BACKUP;

-- 5. Configura Auto-Login (per non dover aprire a mano dopo ogni restart)
ADMINISTER KEY MANAGEMENT CREATE AUTO_LOGIN KEYSTORE FROM KEYSTORE '/u01/app/oracle/admin/RACDB/wallet' IDENTIFIED BY <wallet_password>;

-- 6. Encrypta un tablespace (ONLINE, nessun downtime!)
ALTER TABLESPACE USERS ENCRYPTION ONLINE USING 'AES256' ENCRYPT;

-- 7. Verifica
SELECT tablespace_name, encrypted FROM dba_tablespaces;
```

---

## 2. Unified Auditing

### 2.1 Attivazione

```sql
-- Verifica se Unified Auditing è attivo
SELECT value FROM v$option WHERE parameter = 'Unified Auditing';
-- Se FALSE, devi ricompilare con:
-- cd $ORACLE_HOME/rdbms/lib && make -f ins_rdbms.mk uniaud_on ioracle

-- Crea una policy di audit
CREATE AUDIT POLICY ADMIN_OPERATIONS
  ACTIONS
    ALTER SYSTEM,
    CREATE USER,
    ALTER USER,
    DROP USER,
    GRANT,
    REVOKE,
    ALTER DATABASE;

-- Abilita la policy per TUTTI gli utenti
AUDIT POLICY ADMIN_OPERATIONS;

-- Policy per login falliti
CREATE AUDIT POLICY FAILED_LOGINS
  ACTIONS LOGON
  WHEN 'SYS_CONTEXT(''USERENV'', ''AUTHENTICATION_TYPE'') != ''OS'''
  EVALUATE PER SESSION;
AUDIT POLICY FAILED_LOGINS WHENEVER NOT SUCCESSFUL;
```

### 2.2 Query di Audit

```sql
-- Ultimi 50 eventi audit
SELECT event_timestamp, dbusername, action_name, object_name, return_code
FROM unified_audit_trail
ORDER BY event_timestamp DESC
FETCH FIRST 50 ROWS ONLY;

-- Login falliti
SELECT event_timestamp, dbusername, os_username, userhost, return_code
FROM unified_audit_trail
WHERE action_name = 'LOGON' AND return_code != 0
ORDER BY event_timestamp DESC;

-- Pulizia periodica (i log crescono!)
EXEC DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(
    audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    use_last_arch_timestamp => FALSE
);
```

---

## 3. Network Encryption

```sql
-- In sqlnet.ora su TUTTI i nodi:

-- Server (su tutti i nodi RAC)
SQLNET.ENCRYPTION_SERVER = REQUIRED
SQLNET.ENCRYPTION_TYPES_SERVER = (AES256)
SQLNET.CRYPTO_CHECKSUM_SERVER = REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER = (SHA256)

-- Client (per connessioni da applicazioni)
SQLNET.ENCRYPTION_CLIENT = REQUIRED
SQLNET.ENCRYPTION_TYPES_CLIENT = (AES256)
SQLNET.CRYPTO_CHECKSUM_CLIENT = REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_CLIENT = (SHA256)

-- Verifica che la connessione sia cifrata
SELECT network_service_banner FROM v$session_connect_info
WHERE sid = SYS_CONTEXT('USERENV', 'SID');
-- Deve mostrare: "AES256 Encryption service adapter"
```

---

## 4. Password Profiles

```sql
-- Crea un profilo password restrittivo
CREATE PROFILE SECURE_PROFILE LIMIT
    FAILED_LOGIN_ATTEMPTS 5        -- blocca dopo 5 tentativi falliti
    PASSWORD_LIFE_TIME 90          -- password scade ogni 90 giorni
    PASSWORD_REUSE_TIME 365        -- non riusi la stessa password per 1 anno
    PASSWORD_REUSE_MAX 12          -- almeno 12 password diverse prima di riusare
    PASSWORD_LOCK_TIME 1/24        -- blocco per 1 ora dopo i 5 tentativi
    PASSWORD_GRACE_TIME 7          -- 7 giorni di grazia dopo scadenza
    PASSWORD_VERIFY_FUNCTION ora12c_verify_function;
-- ^^^ ora12c_verify_function: verifica complessità (lunghezza, maiuscole, numeri, speciali)

-- Assegna il profilo
ALTER USER ggadmin PROFILE SECURE_PROFILE;

-- Lista utenti con password scadute o bloccate
SELECT username, account_status, lock_date, expiry_date, profile
FROM dba_users
WHERE account_status != 'OPEN'
ORDER BY expiry_date;
```

---

## 5. Principio del Minimo Privilegio

```sql
-- ❌ MAI fare in produzione:
GRANT DBA TO app_user;

-- ✅ Fai così:
-- 1. Crea un ruolo applicativo
CREATE ROLE APP_READONLY;
GRANT SELECT ON HR.EMPLOYEES TO APP_READONLY;
GRANT SELECT ON HR.DEPARTMENTS TO APP_READONLY;

CREATE ROLE APP_READWRITE;
GRANT APP_READONLY TO APP_READWRITE;
GRANT INSERT, UPDATE, DELETE ON HR.EMPLOYEES TO APP_READWRITE;

-- 2. Assegna il ruolo all'utente
GRANT APP_READWRITE TO app_user;

-- 3. Verifica i privilegi effettivi di un utente
SELECT * FROM dba_role_privs WHERE grantee = 'APP_USER';
SELECT * FROM dba_sys_privs WHERE grantee = 'APP_USER';
SELECT * FROM dba_tab_privs WHERE grantee = 'APP_USER';
```

---

## 6. Checklist Sicurezza Produzione

| Area | Lab | Produzione |
|------|-----|------------|
| Firewall | ❌ Disabilitato | ✅ Abilitato con porte specifiche |
| SELinux | ❌ Disabled | ✅ Permissive o Enforcing |
| TDE | ❌ No | ✅ AES-256 su tablespace dati |
| Network Encryption | ❌ No | ✅ AES256 + SHA256 |
| Audit | ❌ Minimo | ✅ Unified Auditing |
| Password | ❌ Semplici | ✅ Profilo SECURE_PROFILE |
| SSH | ❌ Password | ✅ Chiavi SSH only |
| Privilege | ❌ DBA a tutti | ✅ Ruoli granulari |
| Patch | ❌ Quando capita | ✅ Trimestrali (CPU/RU) |

---

## 7. Fonti Oracle Ufficiali

- TDE: https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/introduction-to-transparent-data-encryption.html
- Unified Auditing: https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-audit-policies.html
- Network Encryption: https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-network-data-encryption-and-integrity.html
