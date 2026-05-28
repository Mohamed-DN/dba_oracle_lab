# GUIDA: Oracle Database Vault — Separation of Duties & Protezione Dati Amministrativi

> [!NOTE]
> **DOCUMENTI DI SICUREZZA CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Setup Database Vault (questa guida)**: [GUIDA_DATABASE_VAULT_ENTERPRISE.md](./GUIDA_DATABASE_VAULT_ENTERPRISE.md) (Separation of duties, Realms, protezione SYSDBA).
> - **Unified Auditing & Compliance**: [GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md](./GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md) (attivazione policy di audit e gestione storage).
> - **Data Masking & Redaction**: [GUIDA_DATA_MASKING_REDACTION.md](./GUIDA_DATA_MASKING_REDACTION.md) (mascheramento dinamico e statico di dati sensibili).
> - **Security Hardening Generale**: [GUIDA_SECURITY_HARDENING.md](./GUIDA_SECURITY_HARDENING.md) (TDE, Auditing base, Password Profiles).
> - **TDE in Profondità**: [GUIDA_TDE_IN_PROFONDITA.md](./GUIDA_TDE_IN_PROFONDITA.md) (Keystore, Master Key, colonna/tablespace encryption).

---

## 1. Cos'è Oracle Database Vault?

Oracle Database Vault (DV) è un'opzione di sicurezza avanzata che implementa la **Separation of Duties (Separazione dei Doveri)** all'interno del database. Risolve il problema del "super-utente" (`SYS` / `SYSDBA`), impedendo agli amministratori del database o a utenti compromessi con privilegi amministrativi di accedere e visualizzare i dati applicativi di business (es. carte di credito, stipendi, anagrafiche clienti).

Il DBA mantiene tutte le sue facoltà operative (backup, restore, patching, tuning, manutenzione storage), ma **non può eseguire SELECT o DML** sugli schemi applicativi protetti da un **Realm**.

```
   SENZA DATABASE VAULT:                             CON DATABASE VAULT:
 ┌──────────────────────┐                         ┌───────────────────────┐
 │        SYSDBA        │                         │  SYSDBA / DBA ROLE    │
 └──────────┬───────────┘                         └───────────┬───────────┘
            │                                                 │
            │ SELECT *                                        │ SELECT *
            ▼                                                 ▼ (BLOCCATO!)
 ┌──────────────────────┐                         ┌───────────────────────┐
 │   DATI DI BUSINESS   │                         │  REALM: DATI PROTETTI │
 │  (Anagrafiche, CC)   │                         │  (Anagrafiche, CC)    │
 └──────────────────────┘                         └───────────────────────┘
                                                              ▲
                                                    Accesso   │ (AUTORIZZATO)
                                                    Solo a    │
                                                  ┌───────────┴───────────┐
                                                  │   APPLICATION USER    │
                                                  └───────────────────────┘
```

---

## 2. Architettura & Ruoli Chiave

Quando abiliti Database Vault, vengono creati due ruoli amministrativi separati e indipendenti dal tradizionale DBA:

| Ruolo | Nome Utente Suggerito | Descrizione |
|---|---|---|
| **Database Vault Owner** | `dbvowner` | Gestisce le policy di sicurezza di DV: crea i Realms, definisce chi può accedere alle tabelle protette e configura le Command Rules. Non può creare utenti o fare manutenzione DB. |
| **Database Vault Account Manager** | `dbvacctmgr` | Gestisce gli account utente e i profili all'interno del database (`CREATE USER`, `ALTER USER`, `DROP USER`, `GRANT`). Impedisce che il DV Owner o il DBA creino utenti non autorizzati per bypassare i controlli. |

---

## 3. Prerequisiti & Setup Iniziale (Lab / Produzione)

### 3.1 Pre-check e Registrazione Ruoli
Prima di abilitare il servizio, verifica che Database Vault sia installato ma non ancora abilitato nel database:

```sql
sqlplus / as sysdba

SELECT parameter, value FROM v$option WHERE parameter = 'Oracle Database Vault';
-- Output atteso: Oracle Database Vault | TRUE (indica che il software è presente nel binario)

SELECT status FROM dba_dv_status;
-- Output atteso: status = DISABLED
```

### 3.2 Creazione degli Utenti Amministrativi (Separazione dei Doveri)
Database Vault richiede la creazione di due utenti dedicati per gestire la configurazione e gli account. Esegui come `SYSDBA`:

```sql
-- 1. Creazione del Database Vault Owner
CREATE USER dbvowner IDENTIFIED BY "SecurePasswordOwner123#" DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT connect, resource TO dbvowner;

-- 2. Creazione del Database Vault Account Manager
CREATE USER dbvacctmgr IDENTIFIED BY "SecurePasswordAcctMgr123#" DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT connect, resource TO dbvacctmgr;
```

---

## 4. Abilitazione di Database Vault

L'abilitazione richiede una sequenza coordinata che culmina nel riavvio dell'istanza (in RAC va eseguita in modalità non-rolling).

### 4.1 Registrazione degli Utenti nel Keystore di DV
Sempre connesso come `SYSDBA`, configura ed esegui la registrazione delle utenze operative:

```sql
BEGIN
  dbms_dnfs.enable_dv; -- Registrazione interna se applicabile (opzionale)
END;
/

-- Registrazione delle utenze DV
EXEC xs_dv.configure_dv('dbvowner', 'dbvacctmgr');
```
*Nota: se l'eseguibile richiede un riallineamento delle librerie OS (Oracle 19c richiede solo il comando SQL sopra).*

### 4.2 Abilitazione Finale
Esegui la chiamata per attivare il software:

```sql
-- Connettiti come dbvowner per abilitare Database Vault
connect dbvowner/SecurePasswordOwner123#

EXEC dbms_macadm.enable_dv;
```

### 4.3 Riavvio del Database
Per rendere attive le modifiche, riavvia completamente il database (se in RAC, ferma tutte le istanze tramite `srvctl`):

```bash
# RAC Stop & Start
srvctl stop database -d RACDB
srvctl start database -d RACDB
```

### 4.4 Verifica dell'Attivazione
Accedi come `SYSDBA` e verifica lo stato:

```sql
sqlplus / as sysdba

SELECT status FROM dba_dv_status;
-- Output atteso: status = ENABLED

-- Verifica le limitazioni: prova a creare un utente come SYSDBA (dovrebbe fallire!)
CREATE USER test_fail IDENTIFIED BY "Password123#";
-- Output atteso: ORA-01031: insufficient privileges
-- (Ora solo dbvacctmgr può creare utenti!)
```

---

## 5. Configurazione Pratica: Creare un Realm

Un **Realm** è una zona protetta all'interno del database che racchiude schemi, tabelle o ruoli. Nessun utente (incluso `SYS` o `SYSTEM`) può accedere agli oggetti all'interno del Realm a meno che non sia stato esplicitamente autorizzato dal **Database Vault Owner** (`dbvowner`).

### Scenario: Proteggere lo Schema Applicativo `HR`
Vogliamo fare in modo che lo schema `HR` sia completamente invisibile e protetto dai DBA amministrativi.

### Step 1: Connessione come DV Owner e Creazione del Realm
```sql
connect dbvowner/SecurePasswordOwner123#

-- Creazione del Realm
BEGIN
  dbms_macadm.create_realm(
    realm_name    => 'Realm Dati Sensibili HR',
    description   => 'Realm per la protezione delle anagrafiche e stipendi HR',
    enabled       => dbms_macutl.g_yes,
    audit_options => dbms_macutl.g_audit_on_failure
  );
END;
/
```

### Step 2: Associare lo Schema HR al Realm
```sql
BEGIN
  dbms_macadm.add_object_to_realm(
    realm_name  => 'Realm Dati Sensibili HR',
    object_owner=> 'HR',
    object_name => '%', -- Protegge TUTTE le tabelle, viste e package dello schema
    object_type => '%'
  );
END;
/
```

### Step 3: Autorizzare l'Utente Applicativo (es. `hr_app`)
Solo il server applicativo o l'owner dello schema deve poter accedere ai dati. Autorizziamo l'utente `HR` (e opzionalmente un utente applicativo `hr_app` creato da `dbvacctmgr`):

```sql
BEGIN
  dbms_macadm.add_auth_to_realm(
    realm_name  => 'Realm Dati Sensibili HR',
    grantee     => 'HR', -- Owner dello schema
    rule_set_name=> NULL,
    auth_options=> dbms_macutl.g_realm_auth_owner
  );
END;
/
```

---

## 6. Verifica & Triage: Cosa vede il DBA?

Ora testiamo l'efficacia del Realm accedendo come `SYSDBA` o amministratore generico:

```sql
sqlplus / as sysdba

-- Il DBA prova a leggere la tabella degli stipendi
SELECT employees_id, salary FROM hr.employees;
-- Output atteso: ORA-47400: Command Rule violation for SELECT on HR.EMPLOYEES

-- Il DBA prova a fare un grant o a modificare la tabella
ALTER TABLE hr.employees ADD (credit_card VARCHAR2(20));
-- Output atteso: ORA-47401: Realm violation for ALTER TABLE on HR.EMPLOYEES
```

*Il DBA mantiene però tutte le funzioni operative:*
```sql
-- Il DBA può ancora fare backup, raccogliere statistiche o ottimizzare lo storage:
ALTER INDEX hr.emp_emp_id_pk REBUILD;
-- Output: Index altered. (Le operazioni strutturali sono consentite se non toccano i dati!)
```

---

## 7. Command Rules: Limitare comandi specifici
Oltre ai Realms, puoi bloccare comandi DDL o di sessione (es. impedire `TRUNCATE TABLE` o `DROP TABLE` in orari di produzione o se non si proviene da una determinata rete).

### Esempio: Impedire DDL (`ALTER SYSTEM`) al di fuori della rete aziendale
```sql
connect dbvowner/SecurePasswordOwner123#

-- Creazione di una Command Rule per il comando ALTER SYSTEM
BEGIN
  dbms_macadm.create_command_rule(
    command         => 'ALTER SYSTEM',
    rule_set_name   => 'Limit_IP_Address', -- Richiede la creazione preventiva di un Rule Set basato su SYS_CONTEXT('USERENV', 'IP_ADDRESS')
    enabled         => dbms_macutl.g_yes,
    scope           => dbms_macutl.g_scope_local
  );
END;
/
```

---

## 8. Rollback: Disabilitare Database Vault

In caso di emergenza o manutenzione straordinaria che richiede l'accesso completo di `SYS`, Database Vault può essere disabilitato:

```sql
-- Connettiti come dbvowner
connect dbvowner/SecurePasswordOwner123#

EXEC dbms_macadm.disable_dv;

-- Riavvia il database (necessario per scaricare i filtri di sicurezza in memoria)
connect / as sysdba
shutdown immediate
startup
```
