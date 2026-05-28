# GUIDA: Oracle Data Redaction & Masking — Mascheramento Dati in Tempo Reale & Anonymization

> [!NOTE]
> **DOCUMENTI DI SICUREZZA CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Data Masking & Redaction (questa guida)**: [GUIDA_DATA_MASKING_REDACTION.md](./GUIDA_DATA_MASKING_REDACTION.md) (mascheramento dinamico e statico di dati sensibili).
> - **Setup Database Vault**: [GUIDA_DATABASE_VAULT_ENTERPRISE.md](./GUIDA_DATABASE_VAULT_ENTERPRISE.md) (Separation of duties, Realms, protezione SYSDBA).
> - **Unified Auditing & Compliance**: [GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md](./GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md) (attivazione policy di audit e gestione storage).
> - **Security Hardening Generale**: [GUIDA_SECURITY_HARDENING.md](./GUIDA_SECURITY_HARDENING.md) (TDE, Auditing base, Password Profiles).

---

## 1. Data Redaction (Dinamico) vs Data Masking (Statico)

La protezione delle informazioni sensibili (es. carte di credito, codici fiscali, dati anagrafici) richiede due approcci diversi a seconda del contesto d'uso:

| Caratteristica | Oracle Data Redaction (Dinamico) | Oracle Data Masking (Statico) |
|---|---|---|
| **Meccanismo** | Il dato rimane inalterato sul disco. Viene mascherato **al volo (on-the-fly)** nella SGA prima di inviare i risultati al client. | Il dato originale viene **sovrascritto fisicamente** con dati fittizi ma realistici. |
| **Destinazione** | Ambiente di Produzione (es. per impedire agli operatori del call-center di leggere le carte di credito intere). | Ambiente di Sviluppo/Test/Lab (il database di produzione viene clonato/esportato e i dati sensibili resi anonimi). |
| **Impatto** | Minimo overhead CPU durante la query. | Elaborazione pesante iniziale (il mascheramento statico richiede una conversione fisica irreversibile). |
| **Reversibilità** | Sì (rimuovendo la policy, il dato originale torna visibile). | NO (il dato reale è perso per sempre e sostituito da dati fake). |

---

## 2. Implementazione di Oracle Data Redaction (Dinamico)

Oracle Data Redaction fa parte di Advanced Security ed è gestito tramite il package `DBMS_REDACT`. Puoi definire 4 tipi di mascheramento:
1.  **Full**: Il dato viene interamente sostituito da zeri (numeri) o spazi (stringhe).
2.  **Partial**: Viene mascherata solo una porzione del dato (es. solo le prime 12 cifre della carta di credito).
3.  **Regular Expression (RegEx)**: Mascheramento basato su pattern complessi (es. mascherare l'indirizzo email lasciando visibile solo il dominio).
4.  **Random**: Sostituisce il dato con valori casuali ad ogni esecuzione.

### Scenario: Proteggere lo Schema `HR` e la tabella `EMPLOYEES`
Vogliamo proteggere i dati sensibili dell'anagrafica dipendenti.

### 2.1 Esempio 1: Mascheramento Parziale (Carta di Credito / Codice Fiscale)
Vogliamo fare in modo che della colonna `CREDIT_CARD` vengano mostrate solo le ultime 4 cifre:

```sql
sqlplus / as sysdba

BEGIN
  dbms_redact.add_policy(
    object_schema       => 'HR',
    object_name         => 'EMPLOYEES',
    policy_name         => 'redact_credit_cards',
    column_name         => 'CREDIT_CARD',
    function_type       => dbms_redact.partial,
    function_parameters => 'VVVVVVVVVVVV1234,VVVVVVVVVVVVVVVV,*,1,12',
    -- Spiegazione parametri:
    -- VVVVVVVVVVVV1234: Formato di output (mostra solo ultimi 4 caratteri)
    -- *: Carattere da usare come maschera
    -- 1: Carattere da cui partire per il mascheramento
    -- 12: Quanti caratteri mascherare a partire dall'inizio
    expression          => 'SYS_CONTEXT(''USERENV'',''SESSION_USER'') != ''HR_APP'''
    -- Spiegazione espressione: il mascheramento si applica a TUTTI tranne che all'utente 'HR_APP'
  );
END;
/
```

### 2.2 Esempio 2: Mascheramento Totale (Stipendi)
Vogliamo mascherare interamente il salario (`SALARY`) sostituendolo con `0`:

```sql
BEGIN
  dbms_redact.add_policy(
    object_schema       => 'HR',
    object_name         => 'EMPLOYEES',
    policy_name         => 'redact_salaries',
    column_name         => 'SALARY',
    function_type       => dbms_redact.full,
    expression          => 'SYS_CONTEXT(''USERENV'',''SESSION_USER'') != ''HR_APP'''
  );
END;
/
```

### 2.3 Esempio 3: Mascheramento con Espressioni Regolari (Email)
Vogliamo mascherare la parte sinistra dell'indirizzo email prima del simbolo `@`:

```sql
BEGIN
  dbms_redact.add_policy(
    object_schema       => 'HR',
    object_name         => 'EMPLOYEES',
    policy_name         => 'redact_emails',
    column_name         => 'EMAIL',
    function_type       => dbms_redact.regexp,
    regexp_pattern      => '^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$',
    regexp_replace_string=> 'masked_user@\2.\3',
    expression          => 'SYS_CONTEXT(''USERENV'',''SESSION_USER'') != ''HR_APP'''
  );
END;
/
```

---

## 3. Verifica Dinamica: Cosa vede l'utente non autorizzato?

Eseguiamo una query con un utente amministrativo o un operatore generico:

```sql
-- Connettiti come utente di sola lettura generico
connect test_user/Password123#

SELECT first_name, last_name, email, salary, credit_card 
FROM   hr.employees 
WHERE  employee_id = 100;
```

### Output Risultante:
| FIRST_NAME | LAST_NAME | EMAIL | SALARY | CREDIT_CARD |
|---|---|---|---|---|
| Steven | King | `masked_user@oracle.com` | `0` | `************4432` |

*Nota: l'utente applicativo `HR_APP` eseguendo la stessa query vedrà i dati reali.*

---

## 4. Gestione delle Policy di Data Redaction

```sql
-- Mostra tutte le policy di Redaction attive nel database
SELECT policy_name, object_schema, object_name, column_name, enable
FROM   redaction_policies;

-- Disabilitare temporaneamente una policy
BEGIN
  dbms_redact.disable_policy(
    object_schema => 'HR',
    object_name   => 'EMPLOYEES',
    policy_name   => 'redact_salaries'
  );
END;
/

-- Rimuovere definitivamente una policy
BEGIN
  dbms_redact.drop_policy(
    object_schema => 'HR',
    object_name   => 'EMPLOYEES',
    policy_name   => 'redact_salaries'
  );
END;
/
```

---

## 5. Implementazione del Data Masking (Statico) in Data Pump

Se dobbiamo esportare i dati del database di produzione per inviarli all'ambiente di test (dove lavorano sviluppatori esterni), dobbiamo **anonimizzare fisicamente** i file dump prima dell'importazione.

Data Pump offre una funzionalità nativa chiamata `REMAP_DATA` che permette di mascherare i dati durante l'export o l'import richiamando un package PL/SQL personalizzato.

### Step 1: Creazione della Funzione di Mascheramento (Anonymization)
Creiamo un package di utilità che generi dati fittizi coerenti:

```sql
CREATE OR REPLACE PACKAGE hr_masking AS
  FUNCTION mask_credit_card(p_card VARCHAR2) RETURN VARCHAR2;
  FUNCTION mask_salary(p_salary NUMBER) RETURN NUMBER;
END hr_masking;
/

CREATE OR REPLACE PACKAGE BODY hr_masking AS
  -- Sostituisce la carta con un valore fisso mascherato
  FUNCTION mask_credit_card(p_card VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_card IS NULL THEN RETURN NULL; END IF;
    RETURN '400012345678' || SUBSTR(p_card, -4);
  END mask_credit_card;

  -- Applica una variazione casuale dello stipendio tra -20% e +20%
  FUNCTION mask_salary(p_salary NUMBER) RETURN NUMBER IS
  BEGIN
    IF p_salary IS NULL THEN RETURN NULL; END IF;
    RETURN ROUND(p_salary * DBMS_RANDOM.VALUE(0.8, 1.2));
  END mask_salary;
END hr_masking;
/
```

### Step 2: Esecuzione dell'Export Mascherato con `expdp`
Utilizziamo il parametro `remap_data` all'interno della riga di comando di Data Pump. Questo farà sì che il dump esportato contenga **solo i dati già anonimizzati**:

```bash
expdp system/<password> \
  schemas=HR \
  directory=DPUMP_DIR \
  dumpfile=hr_anonymized.dmp \
  logfile=hr_export_masked.log \
  remap_data=HR.EMPLOYEES.CREDIT_CARD:hr_masking.mask_credit_card \
  remap_data=HR.EMPLOYEES.SALARY:hr_masking.mask_salary
```

*Nota: nel file `hr_anonymized.dmp` i dati reali sono stati fisicamente sostituiti dai dati di output delle funzioni di mascheramento. Questo dump è ora sicuro da condividere con gli ambienti non di produzione.*
