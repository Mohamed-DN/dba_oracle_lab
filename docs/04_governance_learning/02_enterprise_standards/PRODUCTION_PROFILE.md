# RUNBOOK ENTERPRISE: DATABASE HARDENING & COMPLIANCE BASELINE

> **Document Classification:** STRICTLY CONFIDENTIAL / SECURITY BASELINE  
> **Last Updated:** Maggio 2026  
> **Target Audience:** DBA, Security Officers, IT Auditors  
> **Purpose:** Stabilire lo standard di configurazione inviolabile (ISO 27001 / PCI-DSS compliant) per qualsiasi database Oracle promosso nell'ambiente di Produzione.

## SOMMARIO ELETTRONICO
1. [Init.ora: Baseline Configuration](#1-initora-baseline-configuration)
2. [Network Hardening (sqlnet.ora & listener.ora)](#2-network-hardening-sqlnetora--listenerora)
3. [Gestione Password e Profili Utente](#3-gestione-password-e-profili-utente)
4. [TDE (Transparent Data Encryption) e Wallets](#4-tde-transparent-data-encryption-e-wallets)
5. [Unified Auditing Policies](#5-unified-auditing-policies)
6. [Gestione dei Privilegi (Least Privilege Principle)](#6-gestione-dei-privilegi-least-privilege-principle)

---

## 1. Init.ora: Baseline Configuration

Prima del Go-Live, l'SPFILE deve rispettare questa lista di parametri. Qualsiasi deviazione richiede un'esenzione scritta dal Security Officer.

### 1.1. Parametri di Sicurezza
```sql
-- Forza il controllo case-sensitive delle password
ALTER SYSTEM SET sec_case_sensitive_logon = TRUE SCOPE=BOTH;

-- Disabilita la vecchia versione non sicura del protocollo TNS (solo SHA-256 e AES supportati)
ALTER SYSTEM SET sec_protocol_error_further_action = DROP,10 SCOPE=BOTH;
ALTER SYSTEM SET sec_max_failed_login_attempts = 3 SCOPE=BOTH;

-- Disabilita utente O7_DICTIONARY_ACCESSIBILITY (Previene privilege escalation)
ALTER SYSTEM SET o7_dictionary_accessibility = FALSE SCOPE=SPFILE;

-- Nasconde la versione esatta nei banner di login (anti-reconnaissance)
ALTER SYSTEM SET sec_return_server_release_banner = FALSE SCOPE=BOTH;

-- Forza l'uso dell'Unified Audit Trail
ALTER SYSTEM SET audit_trail = NONE SCOPE=SPFILE; -- Il vecchio mixed-mode è deprecato in 19c+
```

### 1.2. Parametri di Stabilità e Performance
```sql
-- Evita crash per processi zombie
ALTER SYSTEM SET processes = 2000 SCOPE=SPFILE;
ALTER SYSTEM SET sessions = 3000 SCOPE=SPFILE;

-- Previene esaurimento cursori per applicazioni scritte male (leak)
ALTER SYSTEM SET open_cursors = 1000 SCOPE=BOTH;

-- Ottimizzatore CBO: Assicura stabilità
ALTER SYSTEM SET optimizer_adaptive_plans = TRUE SCOPE=BOTH;
ALTER SYSTEM SET optimizer_adaptive_statistics = FALSE SCOPE=BOTH; -- (FALSE raccomandato da Oracle come default stabile)
```

---

## 2. Network Hardening (sqlnet.ora & listener.ora)

La rete Oracle Net non cifrata viaggia in chiaro. Su 19c e 26ai, si deve forzare la Native Network Encryption (NNE).

### 2.1. File `sqlnet.ora` (Database Server)
Posizione: `$ORACLE_HOME/network/admin/sqlnet.ora`
```text
# Forza cifratura AES256 per tutto il traffico (non serve Advanced Security Option per questo)
SQLNET.ENCRYPTION_SERVER = REQUIRED
SQLNET.ENCRYPTION_TYPES_SERVER = (AES256)
SQLNET.CRYPTO_CHECKSUM_SERVER = REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER = (SHA256)

# Disabilita vecchi protocolli obsoleti e insicuri
SQLNET.ALLOWED_LOGON_VERSION_SERVER = 12a
SQLNET.ALLOWED_LOGON_VERSION_CLIENT = 12a

# IP Whitelisting (Solo queste subnet possono parlare con la porta 1521)
TCP.VALIDNODE_CHECKING = YES
TCP.INVITED_NODES = (10.0.1.0/24, 192.168.100.50, localhost)
```

### 2.2. File `listener.ora`
Il demone listener è spesso il target di DoS.
```text
# Limite di sicurezza contro DoS/Brute Force
INBOUND_CONNECT_TIMEOUT_LISTENER = 10

# Disabilita il remote administration (comandi LSNRCTL da altri IP)
ADMIN_RESTRICTIONS_LISTENER = ON
```

---

## 3. Gestione Password e Profili Utente

Il profilo `DEFAULT` di Oracle non è sufficientemente sicuro per gli utenti applicativi o umani. Creare e assegnare profili dedicati.

### 3.1. Profilo Utenti Umani (DBA, Sviluppatori)
```sql
CREATE PROFILE prof_human LIMIT
  PASSWORD_LIFE_TIME 90
  PASSWORD_GRACE_TIME 7
  PASSWORD_REUSE_TIME 365
  PASSWORD_REUSE_MAX UNLIMITED
  FAILED_LOGIN_ATTEMPTS 3
  PASSWORD_LOCK_TIME 1/24 -- (Lock per 1 ora)
  IDLE_TIME 30; -- (Disconnette se AFK per 30 min)

-- Esempio di Assegnazione
ALTER USER m.rossi PROFILE prof_human;
```

### 3.2. Profilo Utenti Applicativi (Service Accounts)
Gli account usati dai pooler (es. HikariCP, Tomcat) non devono avere password in scadenza (causerebbero incidenti gravi), ma devono essere strettamente controllati.
```sql
CREATE PROFILE prof_app LIMIT
  PASSWORD_LIFE_TIME UNLIMITED
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LOCK_TIME UNLIMITED; -- (Se l'app impazzisce e sbaglia pwd, resta locked finché un DBA non interviene)

-- Esempio
ALTER USER core_app PROFILE prof_app;
```

---

## 4. TDE (Transparent Data Encryption) e Wallets

Il GDPR e la PCI-DSS richiedono la cifratura del Data-At-Rest. Qualsiasi database di produzione deve avere il TDE abilitato (richiede Advanced Security Option su Enterprise Edition, incluso in OCI Base DB).

### 4.1. Configurazione Keystore
Creare la directory protetta:
```bash
mkdir -p /u01/app/oracle/admin/wallet/PRDDB
chmod 700 /u01/app/oracle/admin/wallet/PRDDB
```

Aggiungere al `sqlnet.ora`:
```text
ENCRYPTION_WALLET_LOCATION =
  (SOURCE =
    (METHOD = FILE)
    (METHOD_DATA =
      (DIRECTORY = /u01/app/oracle/admin/wallet/PRDDB)
    )
  )
```

### 4.2. Inizializzazione
```sql
-- Crea il Wallet e setta la Master Key
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE '/u01/app/oracle/admin/wallet/PRDDB' IDENTIFIED BY "<WALLET_PASSWORD>";
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "<WALLET_PASSWORD>";
ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY "<WALLET_PASSWORD>" WITH BACKUP;

-- Creare l'Auto-Login Wallet (fondamentale affinché il DB possa aprirsi automaticamente ai riavvii)
ADMINISTER KEY MANAGEMENT CREATE AUTO_LOGIN KEYSTORE FROM KEYSTORE '/u01/app/oracle/admin/wallet/PRDDB' IDENTIFIED BY "<WALLET_PASSWORD>";
```

### 4.3. Cifratura Tablespace
I nuovi tablespace devono essere creati con l'opzione di cifratura AES256.
```sql
CREATE TABLESPACE users_enc
    DATAFILE '+DATA' SIZE 1G
    ENCRYPTION USING 'AES256' ENCRYPT;
```

---

## 5. Unified Auditing Policies

L'auditing tradizionale genera overhead. Unified Auditing scrive in un binary trail altamente performante ed è obbligatorio.

### 5.1. Abilitare l'Auditing delle Azioni Critiche
Tracciare chiunque modifichi lo schema o la sicurezza:
```sql
CREATE AUDIT POLICY pol_sec_admin
  PRIVILEGES CREATE USER, ALTER USER, DROP USER, GRANT ANY PRIVILEGE, CREATE PROFILE;

AUDIT POLICY pol_sec_admin;
```

Tracciare gli accessi falliti (brute force detection):
```sql
CREATE AUDIT POLICY pol_failed_logon
  ACTIONS LOGON;

AUDIT POLICY pol_failed_logon WHENEVER NOT SUCCESSFUL;
```

### 5.2. Lettura dell'Audit Trail (per il SOC)
```sql
SELECT event_timestamp, dbusername, action_name, return_code, sql_text
FROM unified_audit_trail
WHERE event_timestamp > SYSDATE - 1
AND return_code != 0
ORDER BY event_timestamp DESC;
```

---

## 6. Gestione dei Privilegi (Least Privilege Principle)

Non assegnare MAI i ruoli `DBA` o `SYSDBA` ad account applicativi o sviluppatori.

### 6.1. Revoca dei Diritti di Default
Alcuni permessi pubblici sono pericolosi:
```sql
-- Impedisce agli utenti non previlegiati di listare i file OS e leggere pacchetti kernel
REVOKE EXECUTE ON UTL_FILE FROM PUBLIC;
REVOKE EXECUTE ON DBMS_OBFUSCATION_TOOLKIT FROM PUBLIC;
REVOKE EXECUTE ON UTL_TCP FROM PUBLIC;
```

### 6.2. Creazione del Ruolo Applicativo Standard
```sql
CREATE ROLE role_app_developer;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE TO role_app_developer;
-- Nessun diritto di DROP ANY TABLE o SELECT ANY TABLE.
```
