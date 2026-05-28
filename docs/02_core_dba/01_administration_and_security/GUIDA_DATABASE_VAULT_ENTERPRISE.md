# GUIDA COMPLETA: Oracle Database Vault ÔÇö Separation of Duties & Protezione Multitenant

> [!NOTE]
> **DOCUMENTI DI SICUREZZA CORRELATI (SCEGLI QUELLO PI├Ö ADATTO):**
> - **Setup Database Vault (questa guida)**: [GUIDA_DATABASE_VAULT_ENTERPRISE.md](./GUIDA_DATABASE_VAULT_ENTERPRISE.md) (Separation of duties, Realms CDB/PDB, protezione SYSDBA).
> - **Unified Auditing & Compliance**: [GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md](./GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md) (attivazione policy di audit, storage e purge automatico).
> - **Data Masking & Redaction**: [GUIDA_DATA_MASKING_REDACTION.md](./GUIDA_DATA_MASKING_REDACTION.md) (mascheramento dinamico con DBMS_REDACT e statico con Data Pump).
> - **Security Hardening Generale**: [GUIDA_SECURITY_HARDENING.md](./GUIDA_SECURITY_HARDENING.md) (TDE, Auditing base, Password Profiles).
> - **TDE in Profondit├á**: [GUIDA_TDE_IN_PROFONDITA.md](./GUIDA_TDE_IN_PROFONDITA.md) (Keystore, Master Key, colonna/tablespace encryption).

---

## 1. Architettura & Separation of Duties (SoD)

Nelle architetture tradizionali di database, l'utente con privilegio `SYSDBA` (es. `SYS`) possiede poteri illimitati: pu├▓ leggere qualsiasi dato applicativo di business, creare e alterare account, disabilitare gli audit log ed estrarre record sensibili (es. carte di credito, dati sanitari, conti correnti). Questo scenario viola i principali standard internazionali di compliance (**PCI-DSS**, **GDPR**, **SOX**), che richiedono esplicitamente la **Separazione dei Doveri (Separation of Duties - SoD)**.

**Oracle Database Vault (DV)** risponde a questa esigenza imponendo un controllo di sicurezza preventivo ed invalicabile all'interno del kernel del database. Isola l'amministratore del database (DBA) dalle anagrafiche applicative. 

```
                       [ RICHIESTA DI ACCESSO SQL ]
                                    Ôöé
                                    Ôû╝
                ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ
                Ôöé       FILTRO DATABASE VAULT          Ôöé
                ÔööÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÿ
                                    Ôöé
                  Se tocca un Realm o Command Rule
                                    Ôöé
                                    Ôû╝
               Ispeziona i privilegi ed il contesto
               (Client IP, Programma, Session User)
                                    Ôöé
                    ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔö┤ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ
                    Ôû╝                               Ôû╝
               [ PASS ]                         [ BLOCK ]
         La richiesta ├¿ ammessa.          Genera ORA-47400
       (L'applicazione legge i dati)     (Il DBA riceve errore)
```

### La Separazione dei Tre Ruoli Fondamentali:
1.  **System/Infrastructure DBA (`SYSDBA` / `DBA`)**: Mantiene tutte le facolt├á operative. Esegue backup, restore, tuning fisico, manutenzione storage (ASM), patching, riavvio dell'istanza. **Non pu├▓** visualizzare i dati all'interno dei Realms protetti.
2.  **Database Vault Owner (`DV_OWNER`)**: Il responsabile della sicurezza e della compliance. Definisce le regole di accesso, crea i Realms, autorizza i ruoli applicativi e configura le Command Rules. **Non ha** poteri di amministrazione fisica sul DB.
3.  **Database Vault Account Manager (`DV_ACCTMGR`)**: Il gestore delle identit├á. Esegue `CREATE USER`, `ALTER USER`, `GRANT` e gestisce le password. Impedisce che il DBA crei account "fantasma" per bypassare i Realms o che il DV Owner si auto-crei privilegi operativi.

---

## 2. Database Vault in Ambienti Multitenant (CDB vs PDB)

In Oracle 19c/21c/23ai (Multitenant Architecture), l'abilitazione di Database Vault segue una gerarchia rigida per garantire la sicurezza del consolidamento dei dati.

> [!IMPORTANT]
> Non ├¿ possibile abilitare Database Vault all'interno di un singolo Pluggable Database (PDB) se questo non ├¿ stato prima **configurato ed abilitato nel container root (`CDB$ROOT`)**. L'omissione di questo ordine provoca l'errore `ORA-47503: Database Vault is not enabled on CDB$ROOT`.

### Architettura CDB/PDB in Database Vault:
*   **Common Database Vault Manager**: Configurato nel `CDB$ROOT`, utilizza utenti comuni (es. `C##DV_OWNER_COMMON`) per controllare la sicurezza a livello globale.
*   **Local Database Vault Manager**: Configurato all'interno del singolo PDB, consente di delegare la gestione della sicurezza a responsabili locali dei dati applicativi tramite utenti locali del PDB.
*   **Operations Control (Novit├á 19c)**: Consente all'amministratore della sicurezza del CDB di impedire ai DBA comuni (che hanno accesso al `CDB$ROOT`) di connettersi ai PDB ed ispezionare dati sensibili locali, anche se DV non ├¿ abilitato nei singoli PDB.

---

## 3. Workflow Completo di Abilitazione (RAC e Multitenant)

### Step 1: Creazione delle Utenze Comuni nel `CDB$ROOT`
Connettiti all'istanza primaria in `CDB$ROOT` come `SYSDBA` e crea gli utenti comuni che gestiranno il servizio.

```sql
sqlplus / as sysdba

-- Verifica che il DB sia in modalit├á multitenant
SELECT cdb FROM v$database; -- Deve restituire YES

-- 1. Creazione del Common Database Vault Owner
CREATE USER C##DV_OWNER IDENTIFIED BY "SecurePwdCommonOwner123#$" CONTAINER=ALL;
GRANT CONNECT, RESOURCE TO C##DV_OWNER CONTAINER=ALL;
GRANT AUDIT SYSTEM TO C##DV_OWNER CONTAINER=ALL;

-- 2. Creazione del Common Database Vault Account Manager
CREATE USER C##DV_ACCTMGR IDENTIFIED BY "SecurePwdCommonAcct123#$" CONTAINER=ALL;
GRANT CONNECT, RESOURCE TO C##DV_ACCTMGR CONTAINER=ALL;
```

### Step 2: Registrazione e Abilitazione in `CDB$ROOT`
La registrazione associa i ruoli di sicurezza interni di Oracle agli utenti appena creati.

```sql
-- 1. Esegui la registrazione da SYSDBA
BEGIN
  CONFIGURE_DV(
    dvowner_uname   => 'C##DV_OWNER',
    dvacctmgr_uname => 'C##DV_ACCTMGR'
  );
END;
/

-- 2. Connettiti come C##DV_OWNER comune per abilitare il servizio nel root container
connect C##DV_OWNER/SecurePwdCommonOwner123#$

BEGIN
  DBMS_MACADM.ENABLE_DV;
END;
/
```

### Step 3: Riavvio Non-Rolling del Cluster (RAC)
L'attivazione di Database Vault richiede il riavvio completo del database. In ambienti RAC, per motivi di sicurezza legati al caricamento del driver di controllo in SGA, deve essere eseguito un riavvio coordinato.

```bash
# Esegui sul server OS come utente oracle
# Arresta il database su tutti i nodi
srvctl stop database -d RACDB

# Avvia il database
srvctl start database -d RACDB
```

### Step 4: Abilitazione Localizzata all'interno dei Pluggable Database (PDB)
Una volta attivo sul `CDB$ROOT`, abilitiamo Database Vault nel nostro database applicativo `PDB_PROD`.

```sql
sqlplus / as sysdba

-- Sposta la sessione nel PDB applicativo
ALTER SESSION SET CONTAINER = PDB_PROD;

-- Crea le utenze locali specifiche del PDB per la separation of duties localizzata
CREATE USER dbvowner_local IDENTIFIED BY "SecureLocalOwner123#";
GRANT CONNECT, RESOURCE TO dbvowner_local;

CREATE USER dbvacctmgr_local IDENTIFIED BY "SecureLocalAcct123#";
GRANT CONNECT, RESOURCE TO dbvacctmgr_local;

-- Registra gli utenti locali
BEGIN
  CONFIGURE_DV(
    dvowner_uname   => 'dbvowner_local',
    dvacctmgr_uname => 'dbvacctmgr_local'
  );
END;
/

-- Connettiti come utente di sicurezza locale del PDB
connect dbvowner_local/SecureLocalOwner123#@PDB_PROD

-- Abilita localmente
BEGIN
  DBMS_MACADM.ENABLE_DV;
END;
/

-- Riavvia il PDB per applicare la configurazione
connect / as sysdba
ALTER SESSION SET CONTAINER = PDB_PROD;
ALTER PLUGGABLE DATABASE PDB_PROD CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE PDB_PROD OPEN;
```

---

## 4. Configurazione Pratica: Realms & Protezione Dati

Un **Realm** ├¿ un perimetro logico di sicurezza a cui ├¿ associato un insieme di oggetti (schemi, tabelle, viste, ruoli). Una volta che un oggetto fa parte di un Realm, l'accesso ├¿ **bloccato a tutti**, compresi gli amministratori `SYS`, `SYSTEM` e gli utenti con ruoli `DBA`, a meno che non siano stati autorizzati esplicitamente dal `dbvowner`.

### Scenario: Proteggere i dati dello schema `PAYROLL`
Vogliamo fare in modo che solo l'utente applicativo `PAYROLL_APP` possa accedere alla tabella `SALARIES` dello schema `PAYROLL`. I DBA devono poter fare la manutenzione fisica ma non leggere i dati dei dipendenti.

```
                  ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ
                  Ôöé    REALM: Protezione Dati Payroll      Ôöé
                  Ôöé  - Oggetto protetto: PAYROLL.SALARIES   Ôöé
                  ÔööÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÿ
                                      Ôöé
                                      Ôû╝
             Controlla l'utente che effettua la query:
                                      Ôöé
             ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔö┤ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ
             Ôû╝                                                 Ôû╝
     [ PAYROLL_APP ]                                    [ SYS / SYSTEM / DBA ]
   Utente autorizzato                                   Utente NON autorizzato
             Ôöé                                                 Ôöé
             Ôû╝                                                 Ôû╝
         Consenti                                       Blocca (Genera ORA-47400)
```

### Step 1: Creazione del Realm
Connettiti come `dbvowner_local` al PDB applicativo:

```sql
connect dbvowner_local/SecureLocalOwner123#@PDB_PROD

BEGIN
  DBMS_MACADM.CREATE_REALM(
    realm_name    => 'Realm Protezione Payroll',
    description   => 'Protezione dei dati contrattuali e stipendi dipendenti',
    enabled       => DBMS_MACUTL.G_YES,
    audit_options => DBMS_MACUTL.G_AUDIT_ON_FAILURE
  );
END;
/
```

### Step 2: Aggiunta dell'oggetto sensibile al Realm
```sql
BEGIN
  DBMS_MACADM.ADD_OBJECT_TO_REALM(
    realm_name  => 'Realm Protezione Payroll',
    object_owner=> 'PAYROLL',
    object_name => 'SALARIES',
    object_type => 'TABLE'
  );
END;
/
```

### Step 3: Autorizzazione dell'utente applicativo
Concediamo l'accesso solo al server applicativo `PAYROLL_APP`:
```sql
BEGIN
  DBMS_MACADM.ADD_AUTH_TO_REALM(
    realm_name    => 'Realm Protezione Payroll',
    grantee       => 'PAYROLL_APP',
    rule_set_name => NULL,
    auth_options  => DBMS_MACUTL.G_REALM_AUTH_OWNER -- Definisce l'utente come proprietario funzionale del dato
  );
END;
/
```

---

## 5. Command Rules: Controllare i comandi DDL/DCL

Mentre i Realms proteggono i dati (`SELECT`, `INSERT`, `UPDATE`, `DELETE`), le **Command Rules** intercettano ed analizzano l'esecuzione dei comandi SQL operativi (es. `DROP TABLE`, `ALTER SYSTEM`, `CREATE USER`, `TRUNCATE`).

### Esempio Reale: Impedire `ALTER SYSTEM` tranne che in determinate ore e da determinati IP
Vogliamo evitare che un malintenzionato possa alterare parametri strutturali del database al di fuori della finestra di manutenzione ordinaria (dalle 22:00 alle 02:00) o se non si connette dal server di amministrazione (`192.168.56.50`).

```sql
connect dbvowner_local/SecureLocalOwner123#@PDB_PROD

-- 1. Creazione della Regola basata su IP ed Ora
BEGIN
  DBMS_MACADM.CREATE_RULE(
    rule_name => 'Check_Maintenance_Window_And_IP',
    expression=> 'SYS_CONTEXT(''USERENV'', ''IP_ADDRESS'') = ''192.168.56.50'' AND TO_NUMBER(TO_CHAR(SYSDATE, ''HH24'')) IN (22, 23, 00, 01)'
  );
END;
/

-- 2. Creazione del Rule Set (Insieme di Regole)
BEGIN
  DBMS_MACADM.CREATE_RULE_SET(
    rule_set_name => 'RuleSet_Maint_Only',
    description   => 'Consente DDL critiche solo nella finestra notturna da IP sicuro',
    enabled       => DBMS_MACUTL.G_YES,
    eval_options  => DBMS_MACUTL.G_EVAL_ALL,
    audit_options => DBMS_MACUTL.G_AUDIT_ON_FAILURE
  );
END;
/

-- 3. Associazione della Regola al Rule Set
BEGIN
  DBMS_MACADM.ADD_RULE_TO_RULE_SET(
    rule_set_name => 'RuleSet_Maint_Only',
    rule_name     => 'Check_Maintenance_Window_And_IP'
  );
END;
/

-- 4. Creazione della Command Rule per il comando ALTER SYSTEM
BEGIN
  DBMS_MACADM.CREATE_COMMAND_RULE(
    command        => 'ALTER SYSTEM',
    rule_set_name  => 'RuleSet_Maint_Only',
    enabled        => DBMS_MACUTL.G_YES,
    scope          => DBMS_MACUTL.G_SCOPE_LOCAL
  );
END;
/
```

---

## 6. Diagnostica & Triage: Risoluzione Errori Comuni

Quando Database Vault ├¿ attivo, le tradizionali operazioni del DBA cambiano drasticamente. Ecco una guida ai problemi tipici di produzione.

### 6.1 Errore ORA-47400 / ORA-47401 (Realm/Command Violation)
*   **Problema**: Un batch applicativo o un DBA riceve `ORA-47400: Command Rule violation for SELECT on PAYROLL.SALARIES`.
*   **Causa**: La tabella ├¿ protetta da un Realm e l'utente che sta tentando l'operazione non ├¿ stato autorizzato dal `dbvowner`.
*   **Risoluzione (Esegui come `dbvowner`)**:
    1.  Verificare quale Realm protegge l'oggetto:
        ```sql
        SELECT realm_name, object_owner, object_name 
        FROM   dba_dv_realm_object 
        WHERE  object_name = 'SALARIES';
        ```
    2.  Verificare gli utenti abilitati per quel Realm:
        ```sql
        SELECT grantee, auth_options 
        FROM   dba_dv_realm_auth 
        WHERE  realm_name = 'Realm Protezione Payroll';
        ```
    3.  Se l'applicazione ├¿ legittima, concedere l'autorizzazione:
        ```sql
        EXEC DBMS_MACADM.ADD_AUTH_TO_REALM('Realm Protezione Payroll', 'NOME_UTENTE_APPLICATIVO');
        ```

### 6.2 Il DBA non pu├▓ creare Utenti o assegnare Privilegi (`ORA-01031`)
*   **Causa**: Con Database Vault abilitato, l'utente `SYS` o `SYSTEM` o chiunque abbia il ruolo `DBA` **perde** il privilegio di eseguire `CREATE USER`, `DROP USER`, `GRANT` e `REVOKE`.
*   **Risoluzione**: Queste operazioni devono essere eseguite connettendosi con l'account `dbvacctmgr` dedicato (o `C##DV_ACCTMGR` per il CDB).
    ```sql
    -- Connettiti come Account Manager
    connect dbvacctmgr_local/SecureLocalAcct123#@PDB_PROD
    
    -- Esegui l'operazione di gestione utenze
    CREATE USER app_developer IDENTIFIED BY "DevPassword123#";
    GRANT CREATE SESSION TO app_developer;
    ```

---

## 7. Disabilitazione di Database Vault (Emergency Rollback)

In caso di incidenti catastrofici in produzione o necessit├á di manutenzioni strutturali di terze parti non compatibili con i filtri di Database Vault, ├¿ possibile disattivare temporaneamente l'opzione.

```sql
-- 1. Connettiti come Database Vault Owner locale o comune
connect dbvowner_local/SecureLocalOwner123#@PDB_PROD

-- 2. Disabilita Database Vault
EXEC DBMS_MACADM.DISABLE_DV;

-- 3. Riavvia il PDB o l'istanza per scaricare la configurazione dalla memoria
connect / as sysdba
ALTER SESSION SET CONTAINER = PDB_PROD;
ALTER PLUGGABLE DATABASE PDB_PROD CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE PDB_PROD OPEN;

-- 4. Verifica lo stato (deve mostrare status = DISABLED)
SELECT status FROM dba_dv_status;
```


================================================================================

# [SEZIONE AGGIUNTIVA] APPROFONDIMENTO MONUMENTALE


## [ARCHITETTURA VISIVA] Database Vault Flow
\\mermaid
sequenceDiagram
    participant App as Applicazione
    participant DBA as SYSDBA / SYSTEM
    participant DV as Database Vault Kernel
    participant Data as Dati Sensibili (Realms)

    App->>DV: Richiesta SQL (SELECT su dati Payroll)
    DV->>DV: Verifica Contesto (App è autorizzata)
    DV-->>App: Permesso Accordato
    App->>Data: Lettura Dati

    DBA->>DV: Richiesta SQL (SELECT su dati Payroll)
    DV->>DV: Verifica Contesto (SYSDBA non autorizzato nel Realm)
    DV-->>DBA: ORA-47400: Access Denied
\

# GUIDA MONUMENTALE: Oracle Database Vault — Separation of Duties & Protezione Multitenant

> [!NOTE]
> **DOCUMENTI DI SICUREZZA CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Setup Database Vault (questa guida)**: [GUIDA_DATABASE_VAULT_ENTERPRISE.md](./GUIDA_DATABASE_VAULT_ENTERPRISE.md) (Separation of duties, Realms CDB/PDB, protezione SYSDBA).
> - **Unified Auditing & Compliance**: [GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md](./GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md) (attivazione policy di audit, storage e purge automatico).
> - **Data Masking & Redaction**: [GUIDA_DATA_MASKING_REDACTION.md](./GUIDA_DATA_MASKING_REDACTION.md) (mascheramento dinamico con DBMS_REDACT e statico con Data Pump).
> - **Security Hardening Generale**: [GUIDA_SECURITY_HARDENING.md](./GUIDA_SECURITY_HARDENING.md) (TDE, Auditing base, Password Profiles).
> - **TDE in Profondità**: [GUIDA_TDE_IN_PROFONDITA.md](./GUIDA_TDE_IN_PROFONDITA.md) (Keystore, Master Key, colonna/tablespace encryption).

---

## 1. Architettura & Separation of Duties (SoD)

Nelle architetture tradizionali di database, l'utente con privilegio `SYSDBA` (es. `SYS`) possiede poteri illimitati: può leggere qualsiasi dato applicativo di business, creare e alterare account, disabilitare gli audit log ed estrarre record sensibili (es. carte di credito, dati sanitari, conti correnti). Questo scenario viola i principali standard internazionali di compliance (**PCI-DSS**, **GDPR**, **SOX**), che richiedono esplicitamente la **Separazione dei Doveri (Separation of Duties - SoD)**.

**Oracle Database Vault (DV)** risponde a questa esigenza imponendo un controllo di sicurezza preventivo ed invalicabile all'interno del kernel del database. Isola l'amministratore del database (DBA) dalle anagrafiche applicative. 

```
                       [ RICHIESTA DI ACCESSO SQL ]
                                    │
                                    ▼
                ┌──────────────────────────────────────┐
                │       FILTRO DATABASE VAULT          │
                └──────────────────────────────────────┘
                                    │
                  Se tocca un Realm o Command Rule
                                    │
                                    ▼
               Ispeziona i privilegi ed il contesto
               (Client IP, Programma, Session User)
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
               [ PASS ]                         [ BLOCK ]
         La richiesta è ammessa.          Genera ORA-47400
       (L'applicazione legge i dati)     (Il DBA riceve errore)
```

### La Separazione dei Tre Ruoli Fondamentali:
1.  **System/Infrastructure DBA (`SYSDBA` / `DBA`)**: Mantiene tutte le facoltà operative. Esegue backup, restore, tuning fisico, manutenzione storage (ASM), patching, riavvio dell'istanza. **Non può** visualizzare i dati all'interno dei Realms protetti.
2.  **Database Vault Owner (`DV_OWNER`)**: Il responsabile della sicurezza e della compliance. Definisce le regole di accesso, crea i Realms, autorizza i ruoli applicativi e configura le Command Rules. **Non ha** poteri di amministrazione fisica sul DB.
3.  **Database Vault Account Manager (`DV_ACCTMGR`)**: Il gestore delle identità. Esegue `CREATE USER`, `ALTER USER`, `GRANT` e gestisce le password. Impedisce che il DBA crei account "fantasma" per bypassare i Realms o che il DV Owner si auto-crei privilegi operativi.

---

## 2. Database Vault in Ambienti Multitenant (CDB vs PDB)

In Oracle 19c/21c/23ai (Multitenant Architecture), l'abilitazione di Database Vault segue una gerarchia rigida per garantire la sicurezza del consolidamento dei dati.

> [!IMPORTANT]
> Non è possibile abilitare Database Vault all'interno di un singolo Pluggable Database (PDB) se questo non è stato prima **configurato ed abilitato nel container root (`CDB$ROOT`)**. L'omissione di questo ordine provoca l'errore `ORA-47503: Database Vault is not enabled on CDB$ROOT`.

### Architettura CDB/PDB in Database Vault:
*   **Common Database Vault Manager**: Configurato nel `CDB$ROOT`, utilizza utenti comuni (es. `C##DV_OWNER_COMMON`) per controllare la sicurezza a livello globale.
*   **Local Database Vault Manager**: Configurato all'interno del singolo PDB, consente di delegare la gestione della sicurezza a responsabili locali dei dati applicativi tramite utenti locali del PDB.
*   **Operations Control (Novità 19c)**: Consente all'amministratore della sicurezza del CDB di impedire ai DBA comuni (che hanno accesso al `CDB$ROOT`) di connettersi ai PDB ed ispezionare dati sensibili locali, anche se DV non è abilitato nei singoli PDB.

---

## 3. Workflow Completo di Abilitazione (RAC e Multitenant)

### Step 1: Creazione delle Utenze Comuni nel `CDB$ROOT`
Connettiti all'istanza primaria in `CDB$ROOT` come `SYSDBA` e crea gli utenti comuni che gestiranno il servizio.

```sql
sqlplus / as sysdba

-- Verifica che il DB sia in modalità multitenant
SELECT cdb FROM v$database; -- Deve restituire YES

-- 1. Creazione del Common Database Vault Owner
CREATE USER C##DV_OWNER IDENTIFIED BY "SecurePwdCommonOwner123#$" CONTAINER=ALL;
GRANT CONNECT, RESOURCE TO C##DV_OWNER CONTAINER=ALL;
GRANT AUDIT SYSTEM TO C##DV_OWNER CONTAINER=ALL;

-- 2. Creazione del Common Database Vault Account Manager
CREATE USER C##DV_ACCTMGR IDENTIFIED BY "SecurePwdCommonAcct123#$" CONTAINER=ALL;
GRANT CONNECT, RESOURCE TO C##DV_ACCTMGR CONTAINER=ALL;
```

### Step 2: Registrazione e Abilitazione in `CDB$ROOT`
La registrazione associa i ruoli di sicurezza interni di Oracle agli utenti appena creati.

```sql
-- 1. Esegui la registrazione da SYSDBA
BEGIN
  CONFIGURE_DV(
    dvowner_uname   => 'C##DV_OWNER',
    dvacctmgr_uname => 'C##DV_ACCTMGR'
  );
END;
/

-- 2. Connettiti come C##DV_OWNER comune per abilitare il servizio nel root container
connect C##DV_OWNER/SecurePwdCommonOwner123#$

BEGIN
  DBMS_MACADM.ENABLE_DV;
END;
/
```

### Step 3: Riavvio Non-Rolling del Cluster (RAC)
L'attivazione di Database Vault richiede il riavvio completo del database. In ambienti RAC, per motivi di sicurezza legati al caricamento del driver di controllo in SGA, deve essere eseguito un riavvio coordinato.

```bash
# Esegui sul server OS come utente oracle
# Arresta il database su tutti i nodi
srvctl stop database -d RACDB

# Avvia il database
srvctl start database -d RACDB
```

### Step 4: Abilitazione Localizzata all'interno dei Pluggable Database (PDB)
Una volta attivo sul `CDB$ROOT`, abilitiamo Database Vault nel nostro database applicativo `PDB_PROD`.

```sql
sqlplus / as sysdba

-- Sposta la sessione nel PDB applicativo
ALTER SESSION SET CONTAINER = PDB_PROD;

-- Crea le utenze locali specifiche del PDB per la separation of duties localizzata
CREATE USER dbvowner_local IDENTIFIED BY "SecureLocalOwner123#";
GRANT CONNECT, RESOURCE TO dbvowner_local;

CREATE USER dbvacctmgr_local IDENTIFIED BY "SecureLocalAcct123#";
GRANT CONNECT, RESOURCE TO dbvacctmgr_local;

-- Registra gli utenti locali
BEGIN
  CONFIGURE_DV(
    dvowner_uname   => 'dbvowner_local',
    dvacctmgr_uname => 'dbvacctmgr_local'
  );
END;
/

-- Connettiti come utente di sicurezza locale del PDB
connect dbvowner_local/SecureLocalOwner123#@PDB_PROD

-- Abilita localmente
BEGIN
  DBMS_MACADM.ENABLE_DV;
END;
/

-- Riavvia il PDB per applicare la configurazione
connect / as sysdba
ALTER SESSION SET CONTAINER = PDB_PROD;
ALTER PLUGGABLE DATABASE PDB_PROD CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE PDB_PROD OPEN;
```

---

## 4. Configurazione Pratica: Realms & Protezione Dati

Un **Realm** è un perimetro logico di sicurezza a cui è associato un insieme di oggetti (schemi, tabelle, viste, ruoli). Una volta che un oggetto fa parte di un Realm, l'accesso è **bloccato a tutti**, compresi gli amministratori `SYS`, `SYSTEM` e gli utenti con ruoli `DBA`, a meno che non siano stati autorizzati esplicitamente dal `dbvowner`.

Esistono due tipologie di Realms:
1.  **Regular Realm**: Consente ai proprietari degli schemi (es. lo schema `PAYROLL` che possiede la tabella) di accedere liberamente ai propri dati senza essere esplicitamente autorizzati nel realm.
2.  **Mandatory Realm**: Estremamente restrittivo. Anche il proprietario stesso dello schema viene bloccato a meno che non gli venga concessa un'autorizzazione formale all'interno del realm. Ottimo per proteggere tabelle da application owner compromessi.

### Scenario: Proteggere i dati dello schema `PAYROLL`
Vogliamo fare in modo che solo l'utente applicativo `PAYROLL_APP` possa accedere alla tabella `SALARIES` dello schema `PAYROLL`. I DBA devono poter fare la manutenzione fisica ma non leggere i dati dei dipendenti.

```
                  ┌────────────────────────────────────────┐
                  │    REALM: Protezione Dati Payroll      │
                  │  - Oggetto protetto: PAYROLL.SALARIES   │
                  └────────────────────────────────────────┘
                                      │
                                      ▼
             Controlla l'utente che effettua la query:
                                      │
             ┌────────────────────────┴────────────────────────┐
             ▼                                                 ▼
     [ PAYROLL_APP ]                                    [ SYS / SYSTEM / DBA ]
   Utente autorizzato                                   Utente NON autorizzato
             │                                                 │
             ▼                                                 ▼
         Consenti                                       Blocca (Genera ORA-47400)
```

### Step 1: Creazione del Realm
Connettiti come `dbvowner_local` al PDB applicativo:

```sql
connect dbvowner_local/SecureLocalOwner123#@PDB_PROD

BEGIN
  DBMS_MACADM.CREATE_REALM(
    realm_name    => 'Realm Protezione Payroll',
    description   => 'Protezione dei dati contrattuali e stipendi dipendenti',
    enabled       => DBMS_MACUTL.G_YES,
    audit_options => DBMS_MACUTL.G_AUDIT_ON_FAILURE,
    realm_type    => 1 -- 0 per Regular, 1 per Mandatory
  );
END;
/
```

### Step 2: Aggiunta dell'oggetto sensibile al Realm
```sql
BEGIN
  DBMS_MACADM.ADD_OBJECT_TO_REALM(
    realm_name  => 'Realm Protezione Payroll',
    object_owner=> 'PAYROLL',
    object_name => 'SALARIES',
    object_type => 'TABLE'
  );
END;
/
```

### Step 3: Autorizzazione dell'utente applicativo
Concediamo l'accesso solo al server applicativo `PAYROLL_APP`:
```sql
BEGIN
  DBMS_MACADM.ADD_AUTH_TO_REALM(
    realm_name    => 'Realm Protezione Payroll',
    grantee       => 'PAYROLL_APP',
    rule_set_name => NULL,
    auth_options  => DBMS_MACUTL.G_REALM_AUTH_OWNER -- Definisce l'utente come proprietario funzionale del dato
  );
END;
/
```

---

## 5. Command Rules: Controllare i comandi DDL/DCL

Mentre i Realms proteggono i dati (`SELECT`, `INSERT`, `UPDATE`, `DELETE`), le **Command Rules** intercettano ed analizzano l'esecuzione dei comandi SQL operativi (es. `DROP TABLE`, `ALTER SYSTEM`, `CREATE USER`, `TRUNCATE`).

### Esempio Reale: Impedire `ALTER SYSTEM` tranne che in determinate ore e da determinati IP
Vogliamo evitare che un malintenzionato possa alterare parametri strutturali del database al di fuori della finestra di manutenzione ordinaria (dalle 22:00 alle 02:00) o se non si connette dal server di amministrazione (`192.168.56.50`).

```sql
connect dbvowner_local/SecureLocalOwner123#@PDB_PROD

-- 1. Creazione della Regola basata su IP ed Ora
BEGIN
  DBMS_MACADM.CREATE_RULE(
    rule_name => 'Check_Maintenance_Window_And_IP',
    expression=> 'SYS_CONTEXT(''USERENV'', ''IP_ADDRESS'') = ''192.168.56.50'' AND TO_NUMBER(TO_CHAR(SYSDATE, ''HH24'')) IN (22, 23, 00, 01)'
  );
END;
/

-- 2. Creazione del Rule Set (Insieme di Regole)
-- Un Rule Set può contenere più Rules e definirne il criterio di valutazione (TUTTE o ALMENO UNA)
BEGIN
  DBMS_MACADM.CREATE_RULE_SET(
    rule_set_name => 'RuleSet_Maint_Only',
    description   => 'Consente DDL critiche solo nella finestra notturna da IP sicuro',
    enabled       => DBMS_MACUTL.G_YES,
    eval_options  => DBMS_MACUTL.G_EVAL_ALL, -- Tutte le regole interne devono restituire TRUE
    audit_options => DBMS_MACUTL.G_AUDIT_ON_FAILURE
  );
END;
/

-- 3. Associazione della Regola al Rule Set
BEGIN
  DBMS_MACADM.ADD_RULE_TO_RULE_SET(
    rule_set_name => 'RuleSet_Maint_Only',
    rule_name     => 'Check_Maintenance_Window_And_IP'
  );
END;
/

-- 4. Creazione della Command Rule per il comando ALTER SYSTEM
BEGIN
  DBMS_MACADM.CREATE_COMMAND_RULE(
    command        => 'ALTER SYSTEM',
    rule_set_name  => 'RuleSet_Maint_Only',
    enabled        => DBMS_MACUTL.G_YES,
    scope          => DBMS_MACUTL.G_SCOPE_LOCAL
  );
END;
/
```

---

## 6. Diagnostica & Triage: Risoluzione Errori Comuni

Quando Database Vault è attivo, le tradizionali operazioni del DBA cambiano drasticamente. Ecco una guida ai problemi tipici di produzione.

### 6.1 Viste di Sistema per Database Vault
*   `DBA_DV_REALM`: Elenco dei realm attivi e configurati.
*   `DBA_DV_REALM_OBJECT`: Oggetti protetti da un realm.
*   `DBA_DV_REALM_AUTH`: Autorizzazioni esplicite concesse all'interno di un realm.
*   `DBA_DV_COMMAND_RULE`: Elenco delle command rules create.
*   `DBA_DV_STATUS`: Stato generale di abilitazione del servizio DV.

### 6.2 Errore ORA-47400 / ORA-47401 (Realm/Command Violation)
*   **Problema**: Un batch applicativo o un DBA riceve `ORA-47400: Command Rule violation for SELECT on PAYROLL.SALARIES`.
*   **Causa**: La tabella è protetta da un Realm e l'utente che sta tentando l'operazione non è stato autorizzato dal `dbvowner`.
*   **Risoluzione (Esegui come `dbvowner`)**:
    1.  Verificare quale Realm protegge l'oggetto:
        ```sql
        SELECT realm_name, object_owner, object_name 
        FROM   dba_dv_realm_object 
        WHERE  object_name = 'SALARIES';
        ```
    2.  Verificare gli utenti abilitati per quel Realm:
        ```sql
        SELECT grantee, auth_options 
        FROM   dba_dv_realm_auth 
        WHERE  realm_name = 'Realm Protezione Payroll';
        ```
    3.  Se l'applicazione è legittima, concedere l'autorizzazione:
        ```sql
        EXEC DBMS_MACADM.ADD_AUTH_TO_REALM('Realm Protezione Payroll', 'NOME_UTENTE_APPLICATIVO');
        ```

### 6.3 Il DBA non può creare Utenti o assegnare Privilegi (`ORA-01031`)
*   **Causa**: Con Database Vault abilitato, l'utente `SYS` o `SYSTEM` o chiunque abbia il ruolo `DBA` **perde** il privilegio di eseguire `CREATE USER`, `DROP USER`, `GRANT` e `REVOKE`.
*   **Risoluzione**: Queste operazioni devono essere eseguite connettendosi con l'account `dbvacctmgr` dedicato (o `C##DV_ACCTMGR` per il CDB).
    ```sql
    -- Connettiti come Account Manager
    connect dbvacctmgr_local/SecureLocalAcct123#@PDB_PROD
    
    -- Esegui l'operazione di gestione utenze
    CREATE USER app_developer IDENTIFIED BY "DevPassword123#";
    GRANT CREATE SESSION TO app_developer;
    ```

---

## 7. Disabilitazione di Database Vault (Emergency Rollback)

In caso di incidenti catastrofici in produzione o necessità di manutenzioni strutturali di terze parti non compatibili con i filtri di Database Vault, è possibile disattivare temporaneamente l'opzione.

### 7.1 Disabilitazione Standard via Software
```sql
-- 1. Connettiti come Database Vault Owner locale o comune
connect dbvowner_local/SecureLocalOwner123#@PDB_PROD

-- 2. Disabilita Database Vault
EXEC DBMS_MACADM.DISABLE_DV;

-- 3. Riavvia il PDB o l'istanza per scaricare la configurazione dalla memoria
connect / as sysdba
ALTER SESSION SET CONTAINER = PDB_PROD;
ALTER PLUGGABLE DATABASE PDB_PROD CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE PDB_PROD OPEN;

-- 4. Verifica lo stato (deve mostrare status = DISABLED)
SELECT status FROM dba_dv_status;
```

### 7.2 Disabilitazione Fisica a livello Kernel (Estrema Emergenza)
Se hai perso le password degli account `DV_OWNER` o se il database non si avvia a causa di configurazioni errate di DV, puoi disabilitare il servizio ricompilando i binari a livello di OS Unix.

```bash
# Esegui come utente oracle a livello OS
srvctl stop database -d RACDB

cd $ORACLE_HOME/rdbms/lib
make -f ins_rdbms.mk dv_off ioracle

srvctl start database -d RACDB
```
