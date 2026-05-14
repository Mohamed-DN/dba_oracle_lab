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

## 4. 🔍 Audit Completo (sola lettura, nessuna modifica)

*Tutti i controlli sono in **sola lettura**. Puoi esaminare i privilegi effettivi di un utente passo‑passo o con una query unica.*

### 4.1 – Ruoli dell’utente (compresi quelli annidati)

```sql
-- Elenco di tutti i ruoli ereditati, anche se assegnati ad altri ruoli
SELECT DISTINCT granted_role AS ruolo
FROM dba_role_privs
START WITH grantee = UPPER('&username')
CONNECT BY NOCYCLE PRIOR granted_role = grantee
ORDER BY 1;
```

### 4.2 – Privilegi di sistema (diretti e via ruoli)

```sql
-- Mostra se il privilegio è DIRETTO o ereditato da un RUOLO
WITH user_roles AS (
    SELECT granted_role
    FROM dba_role_privs
    START WITH grantee = UPPER('&username')
    CONNECT BY NOCYCLE PRIOR granted_role = grantee
)
SELECT privilege, 'DIRECT' AS tipo, grantee AS provenienza
FROM dba_sys_privs
WHERE grantee = UPPER('&username')
UNION
SELECT rsp.privilege, 'INDIRECT', rsp.role
FROM role_sys_privs rsp
JOIN user_roles ur ON rsp.role = ur.granted_role
ORDER BY tipo, privilege;
```

### 4.3 – Privilegi su oggetti (tabelle, viste, procedure, …)

> **Importante**: `dba_tab_privs` contiene i privilegi per **tutti** i tipi di oggetto: tabelle, viste, sequenze, sinonimi, procedure, funzioni, package, tipi, ecc.  
> Puoi filtrare per un nome oggetto (es. `DB_CRUSCO_DISPO`) oppure **premere semplicemente Invio** (o inserire `%`) per ottenere l’elenco completo di tutti gli oggetti a cui l’utente ha accesso.

```sql
-- Imposta il nome utente (obbligatorio)
DEFINE audit_user = '&username'

-- Filtro oggetto: scrivi il nome esatto o lascia vuoto (o '%') per vedere tutto
-- Se lasci vuoto verrà usato '%' automaticamente
ACCEPT obj_filter CHAR DEFAULT '%' PROMPT 'Nome oggetto (vuoto = tutti): '

-- Query che unisce privilegi DIRETTI e INDIRETTI (via ruoli annidati)
SELECT grantee AS utente,
       NULL AS ruolo_intermedio,          -- NULL = concessione diretta
       privilege AS permesso,
       owner AS proprietario,
       table_name AS oggetto
FROM dba_tab_privs
WHERE grantee = UPPER('&audit_user')
  AND table_name LIKE UPPER('&obj_filter')

UNION ALL

SELECT rp.grantee AS utente,
       rtp.role AS ruolo_intermedio,
       rtp.privilege AS permesso,
       rtp.owner AS proprietario,
       rtp.table_name AS oggetto
FROM role_tab_privs rtp
JOIN (
    -- Esplode i ruoli annidati
    SELECT DISTINCT grantee, granted_role
    FROM dba_role_privs
    START WITH grantee = UPPER('&audit_user')
    CONNECT BY NOCYCLE PRIOR granted_role = grantee
) rp ON rtp.role = rp.granted_role
WHERE rtp.table_name LIKE UPPER('&obj_filter')

ORDER BY utente, proprietario, oggetto, ruolo_intermedio;
```

**Esempio di esecuzione:**

```
SQL> @audit_obj
Enter value for username: IBK_EXCHANGE_SV
Nome oggetto (vuoto = tutti):
... premieresti Invio ...
-- restituisce tutte le righe come:
UTENTE           RUOLO_INTERMEDIO PERMESSO PROPRIETARIO OGGETTO
---------------- ---------------- -------- ------------ ----------------
IBK_EXCHANGE_SV                    SELECT  IBK          DB_CRUSCO_DISPO
IBK_EXCHANGE_SV  IBK_RO           SELECT  IBK          DB_CRUSCO_INFO
```

### 4.4 – Tutto in un colpo solo (ruoli, system, oggetti)

```sql
-- Blocco unico che esegue tutti e tre gli audit per l'utente indicato
-- Sostituisci &username con il nome utente (o usa DEFINE)

-- Ruoli
SELECT DISTINCT granted_role AS ruolo
FROM dba_role_privs
START WITH grantee = UPPER('&username')
CONNECT BY NOCYCLE PRIOR granted_role = grantee
ORDER BY 1;

-- System privileges
WITH user_roles AS (
    SELECT granted_role
    FROM dba_role_privs
    START WITH grantee = UPPER('&username')
    CONNECT BY NOCYCLE PRIOR granted_role = grantee
)
SELECT privilege, 'DIRECT' AS tipo, grantee AS da
FROM dba_sys_privs
WHERE grantee = UPPER('&username')
UNION
SELECT rsp.privilege, 'INDIRECT', rsp.role
FROM role_sys_privs rsp
JOIN user_roles ur ON rsp.role = ur.granted_role
ORDER BY tipo, privilege;

-- Oggetti (tutte le viste, tabelle, procedure...)
ACCEPT obj_filter CHAR DEFAULT '%' PROMPT 'Nome oggetto (vuoto = tutti): '

SELECT grantee AS utente,
       NULL AS ruolo_intermedio,
       privilege AS permesso,
       owner AS proprietario,
       table_name AS oggetto
FROM dba_tab_privs
WHERE grantee = UPPER('&username')
  AND table_name LIKE UPPER('&obj_filter')
UNION ALL
SELECT rp.grantee,
       rtp.role,
       rtp.privilege,
       rtp.owner,
       rtp.table_name
FROM role_tab_privs rtp
JOIN (
    SELECT DISTINCT grantee, granted_role
    FROM dba_role_privs
    START WITH grantee = UPPER('&username')
    CONNECT BY NOCYCLE PRIOR granted_role = grantee
) rp ON rtp.role = rp.granted_role
WHERE rtp.table_name LIKE UPPER('&obj_filter')
ORDER BY utente, proprietario, oggetto, ruolo_intermedio;
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
| **Privilegi** | Solo quelli strettamente necessari | Utilizzare le query di audit per revoche puntuali |
| **Profilo** | Profilo non di `DEFAULT` per app/utenti | Assegnare `app_profile` o `user_profile` appropriato |
| **Connettività** | Login testato con successo | Verificare `CREATE SESSION` e configurazione TNS/Listener |
```
