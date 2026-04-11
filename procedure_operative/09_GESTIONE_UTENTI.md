# 09 — Gestione Utenti e Privilegi

> ⏱️ Tempo: 5-15 minuti | 📅 Frequenza: Su richiesta | 👤 Chi: DBA
> **Scenario tipico**: "Crea un utente per la nuova applicazione" / "Resetta la password"

---

## 1. Creare un Utente Applicativo

```sql
-- Template standard per utente applicativo su CDB/PDB

-- 1. Connettiti al PDB corretto
ALTER SESSION SET CONTAINER = &PDB_NAME;

-- 2. Crea l'utente
CREATE USER &username IDENTIFIED BY "&password"
    DEFAULT TABLESPACE &app_tablespace
    TEMPORARY TABLESPACE TEMP
    QUOTA 500M ON &app_tablespace
    PROFILE DEFAULT;

-- 3. Assegna privilegi base
GRANT CONNECT TO &username;
GRANT CREATE SESSION TO &username;

-- 4. Per utente applicativo (lettura/scrittura su tabelle proprie)
GRANT RESOURCE TO &username;
GRANT CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE TO &username;

-- 5. Per utente read-only (solo lettura su schema altrui)
-- GRANT SELECT ON &owner.&table TO &username;
-- oppure crea un ruolo:
-- CREATE ROLE app_readonly;
-- GRANT SELECT ANY TABLE TO app_readonly;
-- GRANT app_readonly TO &username;
```

## 2. Reset Password

```sql
-- Cambia password utente
ALTER USER &username IDENTIFIED BY "&new_password";

-- Se l'account è bloccato
ALTER USER &username ACCOUNT UNLOCK;

-- Se la password è scaduta (verificare prima)
SELECT username, account_status, expiry_date
FROM dba_users WHERE username = UPPER('&username');
```

## 3. Revocare Accesso

```sql
-- Revoca ruolo
REVOKE &role FROM &username;

-- Revoca privilegio specifico
REVOKE &privilege ON &owner.&object FROM &username;

-- Locka l'account (senza eliminarlo)
ALTER USER &username ACCOUNT LOCK;

-- Drop utente (⚠️ operazione distruttiva!)
-- DROP USER &username CASCADE;
```

## 4. Audit: Chi Ha Quali Privilegi?

```sql
-- System privileges dell'utente
SELECT privilege, admin_option
FROM dba_sys_privs
WHERE grantee = UPPER('&username')
ORDER BY privilege;

-- Ruoli assegnati
SELECT granted_role, admin_option, default_role
FROM dba_role_privs
WHERE grantee = UPPER('&username');

-- Object privileges
SELECT owner, table_name, privilege, grantable
FROM dba_tab_privs
WHERE grantee = UPPER('&username')
ORDER BY owner, table_name;
```

## 5. Utenti Problematici

```sql
-- Utenti con privilegi pericolosi (audit di sicurezza)
SELECT grantee, privilege
FROM dba_sys_privs
WHERE privilege LIKE '%ANY%'
  AND grantee NOT IN ('SYS','SYSTEM','DBA','IMP_FULL_DATABASE','EXP_FULL_DATABASE')
ORDER BY grantee, privilege;

-- Utenti scaduti o bloccati
SELECT username, account_status, expiry_date, profile
FROM dba_users
WHERE account_status != 'OPEN'
  AND oracle_maintained = 'N'
ORDER BY account_status;

-- Utenti senza login da oltre 90 giorni
SELECT username, last_login,
       ROUND(SYSDATE - last_login) AS days_inactive
FROM dba_users
WHERE oracle_maintained = 'N'
  AND last_login < SYSDATE - 90
ORDER BY last_login;
```

## 6. Profili Password

```sql
-- Profili esistenti
SELECT profile, resource_name, limit
FROM dba_profiles
WHERE resource_type = 'PASSWORD'
ORDER BY profile, resource_name;

-- Crea profilo per applicazioni (no scadenza)
CREATE PROFILE app_profile LIMIT
    PASSWORD_LIFE_TIME UNLIMITED
    PASSWORD_REUSE_TIME UNLIMITED
    PASSWORD_REUSE_MAX UNLIMITED
    PASSWORD_GRACE_TIME UNLIMITED
    FAILED_LOGIN_ATTEMPTS 10
    PASSWORD_LOCK_TIME 1/24;  -- lock per 1 ora

-- Crea profilo per utenti umani (con scadenza)
CREATE PROFILE user_profile LIMIT
    PASSWORD_LIFE_TIME 90
    PASSWORD_GRACE_TIME 7
    PASSWORD_REUSE_TIME 365
    PASSWORD_REUSE_MAX 12
    FAILED_LOGIN_ATTEMPTS 5
    PASSWORD_LOCK_TIME 1/24;

-- Assegna profilo
ALTER USER &username PROFILE &profile_name;
```

---

## ✅ Check di Conferma

| Controllo | Atteso |
|---|---|
| Utente creato | Account status = OPEN |
| Privilegi | Solo quelli necessari (least privilege) |
| Profilo | Assegnato correttamente |
| Connessione | Test login riuscito |
