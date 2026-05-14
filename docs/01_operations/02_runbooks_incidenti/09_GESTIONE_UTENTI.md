# 09 — Gestione Utenti e Privilegi

> ⏱️ Tempo: 5-15 minuti | 📅 Frequenza: Su richiesta | 👤 Chi: DBA
> **Scenario tipico**: "Crea un utente per la nuova applicazione", "Resetta la password", "Audit dei privilegi effettivi di un utente"

---

## 0. Verifiche preliminari (prima di creare/modificare)

```sql
-- Controlla se l'utente esiste già
SELECT username, account_status, created
FROM dba_users
WHERE username = UPPER('&username');

-- Controlla se il profilo esiste
SELECT profile, resource_name, limit
FROM dba_profiles
WHERE profile = UPPER('&profile_name')
  AND resource_type = 'PASSWORD';
```

---

## 1. Creare un Utente Applicativo

```sql
-- 1. Connettiti al PDB corretto (se in architettura Multitenant)
ALTER SESSION SET CONTAINER = &PDB_NAME;

-- 2. Crea l'utente (solo se non esiste già)
CREATE USER &username IDENTIFIED BY "&password"
    DEFAULT TABLESPACE &app_tablespace
    TEMPORARY TABLESPACE temp
    QUOTA 500M ON &app_tablespace
    PROFILE DEFAULT;

-- 3. Assegna privilegi base per la connessione
GRANT CONNECT, CREATE SESSION TO &username;

-- 4. Per utente applicativo (lettura/scrittura su tabelle proprie)
GRANT RESOURCE TO &username;
GRANT CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE TO &username;

-- 5. Per utente read-only (creazione ruolo dedicato)
-- CREATE ROLE app_readonly;
-- GRANT SELECT ON &owner.&table TO app_readonly;
-- GRANT app_readonly TO &username;
```

## 2. Reset Password e Sblocco

```sql
-- Cambia password utente
ALTER USER &username IDENTIFIED BY "&new_password";

-- Sblocca l'account
ALTER USER &username ACCOUNT UNLOCK;

-- Verifica stato account e scadenza
SELECT username, account_status, expiry_date, profile
FROM dba_users 
WHERE username = UPPER('&username');
```

## 3. Revocare Accessi

```sql
-- Revoca ruolo
REVOKE &role FROM &username;

-- Revoca privilegio specifico su oggetto
REVOKE &privilege ON &owner.&object FROM &username;

-- Locka l'account (previene nuovi login senza eliminare l'utente)
ALTER USER &username ACCOUNT LOCK;

-- Drop utente e di tutti i suoi oggetti (⚠️ Operazione distruttiva!)
-- DROP USER &username CASCADE;
```

---

## 4. 🔍 Audit Completo: Chi Ha Quali Privilegi? (Diretti e Indiretti)

*In Oracle, i privilegi possono essere assegnati direttamente all'utente o ereditati tramite ruoli (anche annidati). Le query seguenti esplodono l’intero albero delle concessioni.*

### 4.1. Tutti i Ruoli Assegnati (Inclusi i Ruoli Annidati)

```sql
-- Estrae tutti i ruoli ereditati dall'utente, esplodendo la gerarchia
SELECT DISTINCT granted_role AS role_name
FROM dba_role_privs
START WITH grantee = UPPER('&username')
CONNECT BY NOCYCLE PRIOR granted_role = grantee
ORDER BY 1;
```

### 4.2. Privilegi di Sistema (Diretti e tramite Ruoli)

```sql
-- Trova tutti i system privileges dell'utente e indica da dove derivano
WITH user_roles AS (
    SELECT granted_role
    FROM dba_role_privs
    START WITH grantee = UPPER('&username')
    CONNECT BY NOCYCLE PRIOR granted_role = grantee
)
-- Privilegi Diretti
SELECT privilege, 'DIRECT' AS grant_type, grantee AS granted_via
FROM dba_sys_privs
WHERE grantee = UPPER('&username')
UNION
-- Privilegi Indiretti (tramite ruolo)
SELECT rsp.privilege, 'INDIRECT' AS grant_type, rsp.role AS granted_via
FROM role_sys_privs rsp
JOIN user_roles ur ON rsp.role = ur.granted_role
ORDER BY grant_type, privilege;
```

### 4.3. Privilegi sugli Oggetti (Diretti e tramite Ruoli)

```sql
-- Trova chi ha accesso a quali tabelle/viste/procedure e come
WITH user_roles AS (
    SELECT granted_role
    FROM dba_role_privs
    START WITH grantee = UPPER('&username')
    CONNECT BY NOCYCLE PRIOR granted_role = grantee
)
-- Privilegi Diretti
SELECT owner, table_name, privilege, 'DIRECT' AS grant_type, grantee AS granted_via
FROM dba_tab_privs
WHERE grantee = UPPER('&username')
UNION
-- Privilegi Indiretti (tramite ruolo)
SELECT rtp.owner, rtp.table_name, rtp.privilege, 'INDIRECT' AS grant_type, rtp.role AS granted_via
FROM role_tab_privs rtp
JOIN user_roles ur ON rtp.role = ur.granted_role
ORDER BY owner, table_name, privilege;
```

---

## 5. Sicurezza e Utenti Problematici

```sql
-- 1. Utenti con privilegi di sistema pericolosi (ANY privileges o DBA)
SELECT grantee, privilege
FROM dba_sys_privs
WHERE (privilege LIKE '%ANY%' OR privilege = 'DBA')
  AND grantee NOT IN ('SYS','SYSTEM','DBA','IMP_FULL_DATABASE','EXP_FULL_DATABASE')
ORDER BY grantee, privilege;

-- 2. Utenti con accesso al file di password (SYSDBA, SYSOPER, SYSBACKUP, ecc.)
SELECT * FROM v$pwfile_users;

-- 3. Utenti bloccati o scaduti (escludendo quelli di sistema)
SELECT username, account_status, expiry_date, profile
FROM dba_users
WHERE account_status != 'OPEN'
  AND oracle_maintained = 'N'
ORDER BY account_status;

-- 4. Utenti inattivi: nessun login da oltre 90 giorni (richiede audit abilitato)
SELECT username, last_login,
       ROUND(SYSDATE - last_login) AS days_inactive
FROM dba_users
WHERE oracle_maintained = 'N'
  AND last_login < SYSDATE - 90
ORDER BY last_login NULLS FIRST;
```

## 6. Gestione Profili Password

```sql
-- Visualizza le regole del profilo assegnato a un utente
SELECT dp.profile, dp.resource_name, dp.limit
FROM dba_profiles dp
JOIN dba_users du ON dp.profile = du.profile
WHERE du.username = UPPER('&username')
  AND dp.resource_type = 'PASSWORD';

-- Crea profilo per applicazioni (no scadenza, no lock automatico)
-- (prima verifica se esiste già, altrimenti lo crea)
CREATE PROFILE app_profile LIMIT
    PASSWORD_LIFE_TIME UNLIMITED
    PASSWORD_REUSE_TIME UNLIMITED
    PASSWORD_REUSE_MAX UNLIMITED
    PASSWORD_GRACE_TIME UNLIMITED
    FAILED_LOGIN_ATTEMPTS UNLIMITED
    PASSWORD_LOCK_TIME UNLIMITED;

-- Crea profilo restrittivo per utenti fisici
CREATE PROFILE user_profile LIMIT
    PASSWORD_LIFE_TIME 90
    PASSWORD_GRACE_TIME 7
    PASSWORD_REUSE_TIME 365
    PASSWORD_REUSE_MAX 5
    FAILED_LOGIN_ATTEMPTS 5
    PASSWORD_LOCK_TIME 1/24;  -- lock per 1 ora

-- Assegna o modifica il profilo di un utente
ALTER USER &username PROFILE &profile_name;
```

---

## ✅ Check di Conferma

| Controllo | Atteso | Azione in caso di Failure |
| --- | --- | --- |
| **Stato Utente** | `account_status = OPEN` | Eseguire `ACCOUNT UNLOCK` o verificare `PASSWORD_LIFE_TIME` |
| **Privilegi** | Solo quelli strettamente necessari | Usare le CTE della sezione 4 per revoche puntuali |
| **Profilo** | Profilo non di `DEFAULT` per app/utenti | Assegnare `app_profile` o `user_profile` appropriato |
| **Connettività** | Login testato con successo | Verificare `CREATE SESSION` e configurazione TNS/Listener |
```

