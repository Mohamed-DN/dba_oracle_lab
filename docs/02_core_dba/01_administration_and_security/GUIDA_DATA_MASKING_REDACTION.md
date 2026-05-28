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
                                  │
                          [ DBMS_REDACT ] (Kernel)
                                  │
           ┌──────────────────────┴──────────────────────┐
           ▼                                             ▼
  [ Applicativo di Billing ]                  [ Consulente Esterno SQL ]
       Match condition:                           Match condition:
         Sys_context = 'BILLING'                     Sys_context != 'BILLING'
           │                                             │
           ▼                                             ▼
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
