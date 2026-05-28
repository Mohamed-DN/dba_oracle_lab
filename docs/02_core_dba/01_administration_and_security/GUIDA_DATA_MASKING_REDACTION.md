# GUIDA COMPLETA: Oracle Data Masking & Redaction — Mascheramento Dinamico & Statico a Livello Enterprise

> [!NOTE]
> **DOCUMENTI DI SICUREZZA CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Data Masking & Redaction (questa guida)**: [GUIDA_DATA_MASKING_REDACTION.md](./GUIDA_DATA_MASKING_REDACTION.md) (mascheramento dinamico in tempo reale e statico permanente).
> - **Setup Database Vault**: [GUIDA_DATABASE_VAULT_ENTERPRISE.md](./GUIDA_DATABASE_VAULT_ENTERPRISE.md) (Separation of duties, Realms CDB/PDB, protezione SYSDBA).
> - **Unified Auditing & Compliance**: [GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md](./GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md) (attivazione policy di audit, storage e purge automatico).
> - **Security Hardening Generale**: [GUIDA_SECURITY_HARDENING.md](./GUIDA_SECURITY_HARDENING.md) (TDE, Auditing base, Password Profiles).

---

## 1. Data Redaction (Dinamico) vs Data Masking (Statico)

La protezione e l'oscuramento delle informazioni personali identificabili (PII) o sensibili (carte di credito, dettagli finanziari, dati anagrafici) richiedono due metodologie profondamente diverse e complementari:

```
  DATO REALE IN PRODUZIONE (Tabella ORDERS)
  ┌────────────────────────────────────────────────────────┐
  │  NOME: Mario Rossi  |  CREDIT_CARD: 1234 5678 9012 3456 │
  └────────────────────────────────────────────────────────┘
                              │
       ┌──────────────────────┴──────────────────────┐
       ▼                                             ▼
 [ ORACLE DATA REDACTION ]                    [ ORACLE DATA MASKING ]
      (Dinamico - SGA)                           (Statico - Disco)
       │                                             │
       ▼ (Esecuzione Query)                          ▼ (Export / Refresh Test)
  Il dato sul disco rimane reale.              Il dato sul disco viene riscritto.
  Viene oscurato in memoria SGA                I dati reali sono persi e sostituiti
  on-the-fly per utenti non abilitati.         da dati fittizi ma coerenti.
       │                                             │
       ▼ (Output per Client)                         ▼ (Output in Test / Dev)
  NOME: Mario Rossi                            NOME: Antonio Bianchi
  CC:   ************3456                       CC:   4000 9876 5432 1111
```

### Tabella Comparativa di Scelta Tecnologica:

| Caratteristica | Oracle Data Redaction (Dinamico) | Oracle Data Masking (Statico) |
|---|---|---|
| **Ambiente Target** | Produzione (Client/Operatori Call Center/DBA). | Test, Sviluppo, UAT, Lab. |
| **Persistenza** | Volatile in memoria (on-the-fly nella SGA). Il dato a disco rimane reale. | Fisico e permanente sul tablespace (irreversibile). |
| **Impatto Prestazionale** | Minimo overhead CPU durante la query del client. | Overhead iniziale pesante durante il processo di mascheramento statico dei dati. |
| **Reversibilità** | Sì (disabilitando la policy `DBMS_REDACT`). | NO (i dati reali sono persi per sempre). |
| **Licensing** | Opzione **Oracle Advanced Security** (licenziato). | Opzione **Oracle Data Masking and Subsetting Pack** (licenziato). |

---

## 2. Implementazione Dettagliata di Oracle Data Redaction

Oracle Data Redaction intercetta le query dell'utente prima che il database restituisca i blocchi di dati. Si gestisce tramite il package `DBMS_REDACT`.

### 2.1 Esempio 1: Mascheramento Parziale (Partial Redaction per Carte di Credito)
Vogliamo oscurare le prime 12 cifre del codice di carta di credito mostrando solo le ultime 4, applicando la regola a chiunque tranne all'utenza applicativa `CRM_APP`.

```sql
sqlplus / as sysdba

BEGIN
  DBMS_REDACT.ADD_POLICY(
    object_schema       => 'APP_CRM',
    object_name         => 'CUSTOMERS',
    policy_name         => 'redact_customer_cc',
    column_name         => 'CREDIT_CARD',
    function_type       => DBMS_REDACT.PARTIAL,
    -- Spiegazione stringa parametri:
    -- VVVVVVVVVVVV1234: Specifica che l'output deve mostrare solo gli ultimi 4 caratteri numerici
    -- *: Carattere da usare come maschera di sostituzione
    -- 1: Punto di partenza del mascheramento (carattere 1)
    -- 12: Quanti caratteri mascherare a partire dallo start
    function_parameters => 'VVVVVVVVVVVV1234,VVVVVVVVVVVVVVVV,*,1,12',
    expression          => 'SYS_CONTEXT(''USERENV'',''SESSION_USER'') != ''CRM_APP''',
    policy_description  => 'Oscuramento parziale carte di credito per utenti non applicativi'
  );
END;
/
```

### 2.2 Esempio 2: Mascheramento basato su RegEx (RegEx Redaction per Indirizzi Email)
Vogliamo oscurare il nome utente degli indirizzi email lasciando visibile esclusivamente il dominio (es. `utente@dominio.com` ➔ `XXXX@dominio.com`).

```sql
BEGIN
  DBMS_REDACT.ADD_POLICY(
    object_schema       => 'APP_CRM',
    object_name         => 'CUSTOMERS',
    policy_name         => 'redact_customer_email',
    column_name         => 'EMAIL',
    function_type       => DBMS_REDACT.REGEXP,
    regexp_pattern      => '^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$',
    regexp_replace_string=> 'XXXX@\2.\3',
    expression          => 'SYS_CONTEXT(''USERENV'',''SESSION_USER'') != ''CRM_APP'''
  );
END;
/
```

### 2.3 Esempio 3: Mascheramento Totale di Numeri (Full Redaction per Saldi Conti)
Sostituisce qualsiasi valore numerico della colonna con `0`:
```sql
BEGIN
  DBMS_REDACT.ADD_POLICY(
    object_schema       => 'APP_CRM',
    object_name         => 'ACCOUNTS',
    policy_name         => 'redact_bank_balance',
    column_name         => 'BALANCE',
    function_type       => DBMS_REDACT.FULL,
    expression          => 'SYS_CONTEXT(''USERENV'',''SESSION_USER'') != ''CRM_APP'''
  );
END;
/
```

### 2.4 Esempio 4: Mascheramento tramite Funzione Personalizzata (Custom Redaction)
È possibile richiamare funzioni esterne per logiche complesse (disponibile a partire da 19c):
```sql
-- Esempio teorico di firma del metodo:
-- Si utilizza la costante DBMS_REDACT.RANDOM o si associa una funzione personalizzata tramite DBMS_REDACT.ADD_POLICY
```

---

## 3. Data Masking Statico Avanzato in Data Pump (`REMAP_DATA`)

Se dobbiamo inviare un dump del database di produzione ad un fornitore di software esterno o al team di sviluppo in ambiente di test, dobbiamo **riscrivere fisicamente** i dati sensibili prima di esportare il file `.dmp`. 

Data Pump offre una funzionalità nativa chiamata **`REMAP_DATA`** che intercetta la colonna durante l'esportazione o l'importazione e la elabora tramite una funzione PL/SQL personalizzata, in grado di generare valori realistici ma fittizi.

```
  [ EXPORT IN PRODUZIONE ]
             │
   Estrazione delle righe da tabella CUSTOMERS
             │
   Intercettazione tramite REMAP_DATA:
   APP_CRM.CUSTOMERS.TAX_CODE ──► crm_masking.anonymize_tax_code(VALORE)
                                                │
                                                ▼ (Genera codice fittizio)
   Scrittura del valore modificato fisicamente sul file dump:
   [ export_masked_test.dmp ]
```

### Step 1: Creazione del Package PL/SQL di Anonymization
Creiamo un package che converta i dati reali (es. Codici Fiscali o Nomi) in valori anonimi e fittizi coerenti.

```sql
sqlplus / as sysdba

CREATE OR REPLACE PACKAGE crm_masking AS
  FUNCTION anonymize_tax_code(p_input VARCHAR2) RETURN VARCHAR2;
  FUNCTION anonymize_credit_card(p_input VARCHAR2) RETURN VARCHAR2;
END crm_masking;
/

CREATE OR REPLACE PACKAGE BODY crm_masking AS
  -- Genera un codice fiscale fittizio ma formalmente valido (16 caratteri)
  FUNCTION anonymize_tax_code(p_input VARCHAR2) RETURN VARCHAR2 IS
    v_out VARCHAR2(16);
  BEGIN
    IF p_input IS NULL THEN RETURN NULL; END IF;
    -- Ritorna una stringa di prova formattata come codice fiscale basata su randomizer
    v_out := 'MXXRXX' || TO_CHAR(DBMS_RANDOM.VALUE(10, 99), 'FM99') || 'A' || TO_CHAR(DBMS_RANDOM.VALUE(10, 99), 'FM99') || 'F205' || 'X';
    RETURN v_out;
  END anonymize_tax_code;

  -- Anonimizza la carta di credito
  FUNCTION anonymize_credit_card(p_input VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_input IS NULL THEN RETURN NULL; END IF;
    -- Mantiene l'issuer (es. 4000 / Visa) e maschera il resto
    RETURN SUBSTR(p_input, 1, 4) || '-XXXX-XXXX-' || SUBSTR(p_input, -4);
  END anonymize_credit_card;
END crm_masking;
/

-- Concedi i privilegi di esecuzione a SYSTEM per Data Pump
GRANT EXECUTE ON crm_masking TO SYSTEM;
```

### Step 2: Esecuzione dell'Export Mascherato con `expdp`
Utilizziamo il parametro `REMAP_DATA` per indicare a Data Pump di elaborare le colonne durante l'estrazione.

```bash
expdp system/SecurePwd123#@PROD_DB \
  schemas=APP_CRM \
  directory=DPUMP_DIR \
  dumpfile=crm_masked_production.dmp \
  logfile=expdp_masked_crm.log \
  remap_data=APP_CRM.CUSTOMERS.TAX_CODE:SYS.crm_masking.anonymize_tax_code \
  remap_data=APP_CRM.CUSTOMERS.CREDIT_CARD:SYS.crm_masking.anonymize_credit_card
```

> [!CAUTION]
> **Gestione dei Vincoli e delle Chiavi Primarie**: Se applichi `REMAP_DATA` a una colonna soggetta a un vincolo di **Unique Key** o **Primary Key**, devi assicurarti che la funzione PL/SQL personalizzata generi valori **unici ed univoci**, altrimenti l'importazione (`impdp`) fallirà sistematicamente a causa della violazione del vincolo di unicità.

---

## 4. Oracle Data Masking and Subsetting Pack (Enterprise Suite)

Per progetti di migrazione massiva su larga scala (es. core banking composto da migliaia di tabelle correlate), l'uso di script manuali `REMAP_DATA` diventa complesso da manutenere. 
Oracle fornisce lo strumento **Data Masking and Subsetting Pack** integrato in **Oracle Enterprise Manager (OEM) Cloud Control**, che permette di:

1.  **Application Data Model (ADM)**: Effettuare la discovery automatica delle relazioni di foreign key (anche non dichiarate a dizionario ma gestite a livello applicativo) e scoprire dove risiedono i dati PII (Sensitive Data Discovery).
2.  **Parent-Child Consistency**: Garantire la consistenza referenziale. Se il codice fiscale del cliente `'Mario Rossi'` viene mascherato in `'Antonio Bianchi'` nella tabella master, lo strumento provvede automaticamente a propagare lo stesso identico valore `'Antonio Bianchi'` in tutte le tabelle figlie collegate.
3.  **Subsetting**: Consente di estrarre solo una porzione percentuale coerente del database (es. solo il 10% dei clienti totali), riducendo drasticamente lo spazio necessario per gli ambienti di sviluppo e test.
4.  **Format Library**: Librerie di formati pre-configurate pronte all'uso per oscurare i dati conformemente ai requisiti di vari paesi (Codice Fiscale, IBAN, Social Security Number, numeri telefonici).
