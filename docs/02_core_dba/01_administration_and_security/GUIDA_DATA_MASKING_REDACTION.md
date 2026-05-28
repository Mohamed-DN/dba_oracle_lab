# GUIDA COMPLETA: Oracle Data Masking & Redaction ÔÇö Mascheramento Dinamico & Statico a Livello Enterprise

> [!NOTE]
> **DOCUMENTI DI SICUREZZA CORRELATI (SCEGLI QUELLO PI+Ö ADATTO):**
> - **Data Masking & Redaction (questa guida)**: [GUIDA_DATA_MASKING_REDACTION.md](./GUIDA_DATA_MASKING_REDACTION.md) (mascheramento dinamico in tempo reale e statico permanente).
> - **Setup Database Vault**: [GUIDA_DATABASE_VAULT_ENTERPRISE.md](./GUIDA_DATABASE_VAULT_ENTERPRISE.md) (Separation of duties, Realms CDB/PDB, protezione SYSDBA).
> - **Unified Auditing & Compliance**: [GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md](./GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md) (attivazione policy di audit, storage e purge automatico).
> - **Security Hardening Generale**: [GUIDA_SECURITY_HARDENING.md](./GUIDA_SECURITY_HARDENING.md) (TDE, Auditing base, Password Profiles).

---

## 1. Data Redaction (Dinamico) vs Data Masking (Statico)

La protezione e l'oscuramento delle informazioni personali identificabili (PII) o sensibili (carte di credito, dettagli finanziari, dati anagrafici) richiedono due metodologie profondamente diverse e complementari:

```
  DATO REALE IN PRODUZIONE (Tabella ORDERS)
  ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ
  Ôöé  NOME: Mario Rossi  |  CREDIT_CARD: 1234 5678 9012 3456 Ôöé
  ÔööÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÿ
                              Ôöé
       ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔö+ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ
       Ôû+                                             Ôû+
 [ ORACLE DATA REDACTION ]                    [ ORACLE DATA MASKING ]
      (Dinamico - SGA)                           (Statico - Disco)
       Ôöé                                             Ôöé
       Ôû+ (Esecuzione Query)                          Ôû+ (Export / Refresh Test)
  Il dato sul disco rimane reale.              Il dato sul disco viene riscritto.
  Viene oscurato in memoria SGA                I dati reali sono persi e sostituiti
  on-the-fly per utenti non abilitati.         da dati fittizi ma coerenti.
       Ôöé                                             Ôöé
       Ôû+ (Output per Client)                         Ôû+ (Output in Test / Dev)
  NOME: Mario Rossi                            NOME: Antonio Bianchi
  CC:   ************3456                       CC:   4000 9876 5432 1111
```

### Tabella Comparativa di Scelta Tecnologica:

| Caratteristica | Oracle Data Redaction (Dinamico) | Oracle Data Masking (Statico) |
|---|---|---|
| **Ambiente Target** | Produzione (Client/Operatori Call Center/DBA). | Test, Sviluppo, UAT, Lab. |
| **Persistenza** | Volatile in memoria (on-the-fly nella SGA). Il dato a disco rimane reale. | Fisico e permanente sul tablespace (irreversibile). |
| **Impatto Prestazionale** | Minimo overhead CPU durante la query del client. | Overhead iniziale pesante durante il processo di mascheramento statico dei dati. |
| **Reversibilit+á** | S+¼ (disabilitando la policy `DBMS_REDACT`). | NO (i dati reali sono persi per sempre). |
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
Vogliamo oscurare il nome utente degli indirizzi email lasciando visibile esclusivamente il dominio (es. `utente@dominio.com` Ô×ö `XXXX@dominio.com`).

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
+ê possibile richiamare funzioni esterne per logiche complesse (disponibile a partire da 19c):
```sql
-- Esempio teorico di firma del metodo:
-- Si utilizza la costante DBMS_REDACT.RANDOM o si associa una funzione personalizzata tramite DBMS_REDACT.ADD_POLICY
```

---

## 3. Data Masking Statico Avanzato in Data Pump (`REMAP_DATA`)

Se dobbiamo inviare un dump del database di produzione ad un fornitore di software esterno o al team di sviluppo in ambiente di test, dobbiamo **riscrivere fisicamente** i dati sensibili prima di esportare il file `.dmp`. 

Data Pump offre una funzionalit+á nativa chiamata **`REMAP_DATA`** che intercetta la colonna durante l'esportazione o l'importazione e la elabora tramite una funzione PL/SQL personalizzata, in grado di generare valori realistici ma fittizi.

```
  [ EXPORT IN PRODUZIONE ]
             Ôöé
   Estrazione delle righe da tabella CUSTOMERS
             Ôöé
   Intercettazione tramite REMAP_DATA:
   APP_CRM.CUSTOMERS.TAX_CODE ÔöÇÔöÇÔû| crm_masking.anonymize_tax_code(VALORE)
                                                Ôöé
                                                Ôû+ (Genera codice fittizio)
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
> **Gestione dei Vincoli e delle Chiavi Primarie**: Se applichi `REMAP_DATA` a una colonna soggetta a un vincolo di **Unique Key** o **Primary Key**, devi assicurarti che la funzione PL/SQL personalizzata generi valori **unici ed univoci**, altrimenti l'importazione (`impdp`) fallir+á sistematicamente a causa della violazione del vincolo di unicit+á.

---

## 4. Oracle Data Masking and Subsetting Pack (Enterprise Suite)

Per progetti di migrazione massiva su larga scala (es. core banking composto da migliaia di tabelle correlate), l'uso di script manuali `REMAP_DATA` diventa complesso da manutenere. 
Oracle fornisce lo strumento **Data Masking and Subsetting Pack** integrato in **Oracle Enterprise Manager (OEM) Cloud Control**, che permette di:

1.  **Application Data Model (ADM)**: Effettuare la discovery automatica delle relazioni di foreign key (anche non dichiarate a dizionario ma gestite a livello applicativo) e scoprire dove risiedono i dati PII (Sensitive Data Discovery).
2.  **Parent-Child Consistency**: Garantire la consistenza referenziale. Se il codice fiscale del cliente `'Mario Rossi'` viene mascherato in `'Antonio Bianchi'` nella tabella master, lo strumento provvede automaticamente a propagare lo stesso identico valore `'Antonio Bianchi'` in tutte le tabelle figlie collegate.
3.  **Subsetting**: Consente di estrarre solo una porzione percentuale coerente del database (es. solo il 10% dei clienti totali), riducendo drasticamente lo spazio necessario per gli ambienti di sviluppo e test.
4.  **Format Library**: Librerie di formati pre-configurate pronte all'uso per oscurare i dati conformemente ai requisiti di vari paesi (Codice Fiscale, IBAN, Social Security Number, numeri telefonici).


================================================================================

# [SEZIONE AGGIUNTIVA] APPROFONDIMENTO MONUMENTALE


## [ARCHITETTURA VISIVA] Dynamic Redaction vs Static Masking
```text

PRODUZIONE (Data Redaction):
[ Database ] ---> DBMS_REDACT ---> [ App (Dato Reale) / Consulente (XXX-XXX) ]

UAT / DEV (Static Masking):
[ Database ] ---> (PDB Clone & Masking) ---> [ Database Alterato ] ---> [ Sviluppatore ]
```

# GUIDA MONUMENTALE: Oracle Data Masking & Data Redaction

> [!NOTE]
> **DOCUMENTI DI SICUREZZA CORRELATI:**
> - **Unified Auditing**: [GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md](./GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md)
> - **Database Vault**: [GUIDA_DATABASE_VAULT_ENTERPRISE.md](./GUIDA_DATABASE_VAULT_ENTERPRISE.md)
> - **Transparent Data Encryption (TDE)**: [GUIDA_TDE_IN_PROFONDITA.md](./GUIDA_TDE_IN_PROFONDITA.md) (Per mascheramento at-rest al livello dei datafile).

In contesti Enterprise (Banche, Telco, Sanità), la gestione dei dati sensibili (PII - Personally Identifiable Information, PAN, SSN) è regolata da rigide normative (GDPR, PCI-DSS). Oracle offre due macro-architetture per nascondere queste informazioni: il **Mascheramento Dinamico (Data Redaction)** e il **Mascheramento Statico (Data Masking Pack / Data Pump Remap)**.

---

## 1. Oracle Data Redaction: Mascheramento Dinamico (In-Transit / Presentation)

**Oracle Data Redaction (Pacchetto Advanced Security)** agisce al momento della query (`SELECT`). I dati sui dischi (Datafiles) rimangono intatti e originali, ma quando un utente non autorizzato (es. uno sviluppatore, uno stagista o un consulente esterno) esegue la query, il kernel Oracle intercetta il Result Set e restituisce valori alterati prima che arrivino al client SQL.

```
       Dato Reale su Disco: 4532 1122 3344 5566 (Carta di Credito)
                                  |
                          [ DBMS_REDACT ] (Kernel)
                                  |
           +----------------------+----------------------+
           v                                             v
  [ Applicativo di Billing ]                  [ Consulente Esterno SQL ]
       Match condition:                           Match condition:
         Sys_context = 'BILLING'                     Sys_context != 'BILLING'
           |                                             |
           v                                             v
       Vede il dato reale                         Vede il dato offuscato
     4532 1122 3344 5566                        XXXX XXXX XXXX 5566
```

### 1.1 Tipologie di Redaction Policies

1.  **FULL**: Oscuramento totale. I numeri diventano `0`, le stringhe uno spazio vuoto `' '`, le date `01-JAN-2001`.
2.  **PARTIAL**: Oscuramento parziale basato su pattern fissi (es. nascondere tutto tranne le ultime 4 cifre della carta di credito).
3.  **REGULAR EXPRESSION**: Molto potente, consente di usare le Regex per cercare un pattern complesso all'interno di campi CLOB o lunghe stringhe (es. trovare ed offuscare indirizzi email o SSN all'interno di log testuali).
4.  **RANDOM**: Invece di restituire 'XXX', restituisce un valore apparentemente valido ma casuale ad ogni esecuzione della query, disorientando tentativi di inferenza statistica.
5.  **NONE**: Disabilita l'oscuramento (utile in fase di test della policy).

### 1.2 Implementazione Pratica: Protezione Carte di Credito e Saldi

Creiamo una policy sullo schema `FINANCE`, tabella `CUSTOMERS`.

```sql
sqlplus / as sysdba
GRANT EXECUTE ON DBMS_REDACT TO security_admin;
connect security_admin/StrongPwd123@PDB_PROD;

-- 1. Creiamo la policy principale sulla tabella per la colonna PAN (Carta di Credito)
BEGIN
  DBMS_REDACT.ADD_POLICY(
    object_schema       => 'FINANCE',
    object_name         => 'CUSTOMERS',
    column_name         => 'CREDIT_CARD_PAN',
    policy_name         => 'redact_customer_pii',
    function_type       => DBMS_REDACT.PARTIAL,
    function_parameters => 'VVVVFVVVVFVVVVFVVVV,VVVV-VVVV-VVVV-VVVV,*,1,12', -- Mostra solo ultime 4 cifre
    expression          => 'SYS_CONTEXT(''USERENV'', ''SESSION_USER'') != ''BILLING_APP''',
    enable              => TRUE
  );
END;
/

-- 2. Aggiungiamo alla STESSA policy un'altra colonna (es. ACCOUNT_BALANCE) con mascheramento Random
BEGIN
  DBMS_REDACT.ALTER_POLICY(
    object_schema       => 'FINANCE',
    object_name         => 'CUSTOMERS',
    policy_name         => 'redact_customer_pii',
    action              => DBMS_REDACT.ADD_COLUMN,
    column_name         => 'ACCOUNT_BALANCE',
    function_type       => DBMS_REDACT.RANDOM
  );
END;
/
```
> [!IMPORTANT]
> L'espressione `expression => '...'` è valutata a Runtime per ogni sessione. Nell'esempio, se si connette l'applicativo ufficiale (`BILLING_APP`), la policy non si attiva e il dato viene estratto in chiaro. Se si connette lo sviluppatore `DEV_USER`, la policy restituisce `XXX` per il PAN e un saldo fittizio.

### 1.3 Troubleshooting Data Redaction
- Viste di riferimento: `DBA_REDACTION_POLICIES`, `DBA_REDACTION_COLUMNS`.
- **Errore Comune:** Le prestazioni peggiorano. Questo accade se usi tipi di Redaction complessi (Regular Expressions pesanti) su result-set di milioni di righe. È consigliato limitarsi a Redaction di tipo FULL o PARTIAL fisso su tabelle OLTP ad alto volume.

---

## 2. Oracle Data Masking (Static Masking per UAT / DEV)

A differenza della Redaction, lo **Static Masking** altera definitivamente, irrimediabilmente e fisicamente il dato su disco. Non può e **NON DEVE MAI** essere eseguito nel database di Produzione. Viene utilizzato per clonare la Produzione verso gli ambienti di Test/Sviluppo (UAT/DEV) fornendo agli sviluppatori dataset "realistici" ma anonimizzati.

### Metodo A: Data Pump con `REMAP_DATA` (Free / Script-based)
Invece di esportare i dati sensibili, instruiamo il Data Pump (durante l'export dalla Prod o l'import verso Dev) a chiamare una funzione PL/SQL per sovrascrivere il flusso di byte on-the-fly.

#### Step 1: Creazione della Funzione di Mascheramento
```sql
-- Creata nello schema di utilità in Produzione o nell'ambiente di destinazione prima dell'import.
CREATE OR REPLACE FUNCTION mask_email (p_email IN VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    -- Se è NULL, ritorna NULL. Altrimenti crea un'email fake basata sull'hash
    IF p_email IS NULL THEN RETURN NULL; END IF;
    RETURN DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(p_email, 'AL32UTF8'), 2) || '@anon.local';
END;
/
```

#### Step 2: Utilizzo con Data Pump (`expdp` / `impdp`)
```bash
expdp system/password@PDB_PROD \
  DIRECTORY=PUMP_DIR \
  DUMPFILE=masked_export.dmp \
  SCHEMAS=FINANCE \
  REMAP_DATA=FINANCE.CUSTOMERS.EMAIL:mask_email
```
> [!WARNING]
> La funzione specificata in `REMAP_DATA` deve appartenere ad un utente con privilegi DBA/Execute e deve essere estremamente ottimizzata, in quanto verrà richiamata per **ogni singola riga** processata da Data Pump. Potrebbe incrementare enormemente i tempi di esportazione.

### Metodo B: Oracle Enterprise Manager Data Masking Pack (Licensed)

Per ambienti complessi, dove la consistenza referenziale è cruciale (es. l'ID Cliente deve essere cambiato identicamente nella tabella Anagrafica, Fatture e Ordini per non rompere le Foreign Key e l'applicativo), l'uso di Data Pump diventa insostenibile. Serve l'infrastruttura **Data Masking and Subsetting Pack** in OEM 13c.

#### Architettura del Processo OEM Masking:
1.  **Application Data Model (ADM)**: OEM analizza le Foreign Keys e i Dictionaries per mappare i legami tra tabelle. Se le FK non sono fisicamente dichiarate nel database (gestite a livello applicativo), il DBA deve dichiararle "virtualmente" nell'ADM per dire all'engine del masking di trattarle con coerenza (Deterministic Masking).
2.  **Masking Format Library**: Oracle fornisce formati preconfezionati per SSN, IBAN, Carte di Credito che rispettano i checksum logici (Luhn algorithm), in modo che i test applicativi su UAT passino le validazioni di form.
3.  **Data Masking Definition**: Il piano vero e proprio. Associa l'ADM e i formati alle specifiche colonne.
4.  **Generazione ed Esecuzione dello Script**: OEM genera uno script PL/SQL imponente che esegue `CTAS` (Create Table As Select) in parallelo, disabilita constraint, aggiorna i dati `NOLOGGING`, ricostruisce gli indici e riabilita i constraint.

#### Il Ciclo di Vita del Clone Sicuro (Integrazione Masking + Multitenant)
Il metodo più moderno ed efficiente non prevede Data Pump o lunghi update, ma lo sfruttamento dello storage Snapshot (o Thin Provisioning) unito alla flessibilità Multitenant (PDB).

1.  **Clone Rapido (Storage Snapshot / PDB Clone)**: Si crea un Clone PDB dalla Produzione in un'istanza "Staging" (isolata).
    ```sql
    CREATE PLUGGABLE DATABASE PDB_STG FROM PDB_PROD SNAPSHOT COPY;
    ```
2.  **Masking in Loco (In-Place)**: OEM o script proprietari eseguono il Masking statico **direttamente sul PDB_STG**, in un ambiente protetto e senza rete applicativa (per evitare leak). I dati reali vengono sostituiti da fake data.
3.  **Unplug & Plug in DEV**: Il PDB mascherato viene scollegato (Unplugged) e collegato all'istanza di Sviluppo accessibile dagli sviluppatori.
    ```sql
    -- Nel server di Staging:
    ALTER PLUGGABLE DATABASE PDB_STG UNPLUG INTO '/u01/app/oracle/pdb_stg.xml';
    
    -- Nel server di Sviluppo (UAT):
    CREATE PLUGGABLE DATABASE PDB_UAT USING '/u01/app/oracle/pdb_stg.xml' NOCOPY;
    ALTER PLUGGABLE DATABASE PDB_UAT OPEN;
    ```

Questo workflow abbatte i tempi di provisioning di enormi database (Terabyte) offrendo un mascheramento statico totalmente sicuro.
