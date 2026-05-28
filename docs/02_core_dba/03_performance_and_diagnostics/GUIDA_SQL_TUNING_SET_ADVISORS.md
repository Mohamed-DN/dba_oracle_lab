# GUIDA: SQL Tuning Set (STS) & Advisors — Ottimizzazione Avanzata & SQL Profiles

> [!NOTE]
> **DOCUMENTI DI PERFORMANCE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **SQL Tuning Set & Advisors (questa guida)**: [GUIDA_SQL_TUNING_SET_ADVISORS.md](./GUIDA_SQL_TUNING_SET_ADVISORS.md) (DBMS_SQLTUNE, SQL Tuning Advisor, profili).
> - **SQL Plan Management & Baselines**: [GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md](./GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md) (SPM, stabilizzazione dei piani di query, baselines).
> - **AWR, ASH & ADDM**: [GUIDA_AWR_ASH_ADDM.md](./GUIDA_AWR_ASH_ADDM.md) (diagnostica delle prestazioni del carico di lavoro).
> - **Troubleshooting Completo**: [GUIDA_TROUBLESHOOTING_COMPLETO.md](./GUIDA_TROUBLESHOOTING_COMPLETO.md) (metodo di analisi strutturata e wait events).

---

## 1. Cos'è un SQL Tuning Set (STS)?

Un **SQL Tuning Set (STS)** è un oggetto di sistema (un contenitore) che raccoglie un gruppo di istruzioni SQL insieme al loro contesto di esecuzione (testo della query, variabili di bind, statistiche di esecuzione come tempo CPU, letture logiche/fisiche, righe elaborate e piani di esecuzione).

L'STS è lo strumento fondamentale per effettuare analisi di tuning massivo. Puoi popolare un STS in due modi:
1.  **Dalla Cursor Cache**: Catturando le query attualmente in esecuzione in memoria (ottimo per ottimizzazione estemporanea).
2.  **Dall'AWR**: Estraendo lo storico delle query più pesanti registrate negli snapshot AWR (ottimo per tuning post-mortem di incidenti passati).

---

## 2. Workflow Completo: Creare e Popolare un STS

### Step 1: Creazione dell'STS vuoto
Eseguiamo il setup del contenitore tramite `DBMS_SQLTUNE`:

```sql
sqlplus / as sysdba

BEGIN
  DBMS_SQLTUNE.CREATE_SQLSET(
    sqlset_name => 'STS_PRODUZIONE_CRITICO',
    description => 'Raccolta delle query più pesanti dell''applicazione'
  );
END;
/
```

### Step 2: Popolare l'STS dalla Shared SQL Area (Cursor Cache)
Vogliamo catturare tutte le query eseguite dall'utente applicativo `HR` che hanno richiesto più di 10.000 letture di buffer (buffer gets):

```sql
DECLARE
  v_cur DBMS_SQLTUNE.SQLSET_CURSOR;
BEGIN
  -- 1. Apri un cursore per selezionare le query che corrispondono al filtro
  OPEN v_cur FOR
    SELECT VALUE(p)
    FROM   TABLE(
             DBMS_SQLTUNE.SELECT_CURSOR_CACHE(
               basic_filter   => 'parsing_schema_name = ''HR'' AND buffer_gets > 10000',
               attribute_list => 'ALL'
             )
           );

  -- 2. Carica i dati nel nostro SQL Tuning Set
  DBMS_SQLTUNE.LOAD_SQLSET(
    sqlset_name => 'STS_PRODUZIONE_CRITICO',
    populate_cursor => v_cur
  );

  CLOSE v_cur;
END;
/
```

### Step 3: Popolare l'STS dallo storico AWR
Se vogliamo fare tuning sulle query della settimana scorsa catturandole dall'AWR:

```sql
DECLARE
  v_cur DBMS_SQLTUNE.SQLSET_CURSOR;
BEGIN
  OPEN v_cur FOR
    SELECT VALUE(p)
    FROM   TABLE(
             DBMS_SQLTUNE.SELECT_WORKLOAD_REPOSITORY(
               begin_snap     => 1204, -- Snap ID inizio
               end_snap       => 1220, -- Snap ID fine
               basic_filter   => 'parsing_schema_name = ''HR''',
               attribute_list => 'ALL'
             )
           );

  DBMS_SQLTUNE.LOAD_SQLSET(
    sqlset_name => 'STS_PRODUZIONE_CRITICO',
    populate_cursor => v_cur
  );

  CLOSE v_cur;
END;
/
```

---

## 3. Eseguire il SQL Tuning Advisor (STA)

Il **SQL Tuning Advisor (STA)** analizza le query all'interno dell'STS (o una singola query specifica) e propone raccomandazioni concrete:
*   Raccolta di statistiche mancanti o vecchie.
*   Creazione di indici per velocizzare i path di accesso.
*   Creazione di **SQL Profiles** (metadati che correggono le stime errate di cardinalità dell'optimizer).
*   Ristrutturazione del codice SQL (es. eliminazione di sottoquery non correlate inefficienti).

### Step 1: Creare il Tuning Task
Associamo l'advisor al nostro STS:

```sql
DECLARE
  v_task_name VARCHAR2(100);
BEGIN
  v_task_name := DBMS_SQLTUNE.CREATE_TUNING_TASK(
    sqlset_name => 'STS_PRODUZIONE_CRITICO',
    task_name   => 'TASK_TUNING_PROD'
  );
  DBMS_OUTPUT.PUT_LINE('Task creato: ' || v_task_name);
END;
/
```

### Step 2: Eseguire il Tuning Task
L'esecuzione può richiedere tempo a seconda del numero di query (puoi limitare il tempo massimo con `time_limit`):

```sql
BEGIN
  DBMS_SQLTUNE.EXECUTE_TUNING_TASK(
    task_name => 'TASK_TUNING_PROD'
  );
END;
/
```

### Step 3: Verificare lo stato del Task
```sql
SELECT status FROM dba_advisor_tasks WHERE task_name = 'TASK_TUNING_PROD';
-- Attendi che mostri status = COMPLETED
```

---

## 4. Analisi delle Raccomandazioni (Tuning Report)

Esegui la query per stampare il report completo generato dall'Advisor in formato testuale:

```sql
SET LONG 1000000;
SET PAGESIZE 50000;
SET LINESIZE 200;

SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('TASK_TUNING_PROD') FROM dual;
```

### Struttura del Report e Interpretazione:
Il report si divide in sezioni chiare per ogni query analizzata:
1.  **Finding: Statistics**: Oracle rileva che la tabella `ORDERS` ha statistiche vecchie del 20% e consiglia di eseguire `GATHER_TABLE_STATS`.
2.  **Finding: Index**: Oracle consiglia la creazione di un indice:
    `CREATE INDEX HR.ORDERS_IDX_CUST ON HR.ORDERS (CUSTOMER_ID);`
    Mostra anche il beneficio stimato (es. `98% improvement`).
3.  **Finding: SQL Profile**: Oracle ha scoperto che l'optimizer stima erroneamente 1.000 righe quando in realtà la query ne restituisce 500.000, e propone la creazione di un **SQL Profile**.

---

## 5. Implementare le Raccomandazioni: SQL Profiles

Un **SQL Profile** è una collezione di informazioni ausiliarie (statistiche aggiuntive sui predicati, cardinalità reali riscontrate durante il test) che viene associata alla query. **Non modifica il codice SQL della query**, ma costringe l'optimizer a fare stime realistiche generando il miglior piano possibile.

### Accettare e Abilitare un SQL Profile consigliato
Se il report STA consiglia un profilo, puoi accettarlo tramite la procedura:

```sql
BEGIN
  DBMS_SQLTUNE.ACCEPT_SQL_PROFILE(
    task_name   => 'TASK_TUNING_PROD',
    object_id   => 1, -- Recupera l'ID dell'oggetto dal report stampato
    name        => 'PROFILE_QUERY_CRITICA_HR',
    description => 'Profilo per la stabilizzazione della cardinalità della query HR',
    replace     => TRUE,
    force_match => TRUE -- Se impostato a TRUE, applica il profilo anche se cambiano i bind values della query
  );
END;
/
```

### Monitorare i SQL Profiles Attivi
```sql
SELECT name, category, signature, status, force_matching 
FROM   dba_sql_profiles;
```

---

## 6. SQL Access Advisor: Ottimizzazione Strutturale (Indici & Materialized Views)

Mentre il SQL Tuning Advisor si concentra sulla singola istruzione, il **SQL Access Advisor** analizza l'intero carico di lavoro (workload) per consigliare modifiche fisiche e strutturali ottimali: indici B-Tree, indici Bitmap, partizionamento di tabelle e **Materialized Views (Viste Materializzate)**.

### Esempio Rapido di Esecuzione:
```sql
DECLARE
  v_task_name VARCHAR2(100) := 'TASK_ACCESS_ADVISOR';
BEGIN
  -- 1. Crea il task
  DBMS_ADVISOR.CREATE_TASK(
    advisor_name => 'SQL Access Advisor',
    task_name    => v_task_name
  );
  
  -- 2. Collega il task al nostro SQL Tuning Set esistente
  DBMS_ADVISOR.LINK_TEMPLATE(
    task_name => v_task_name,
    relations => 'STS_PRODUZIONE_CRITICO'
  );
  
  -- 3. Imposta i parametri di focus (es. ottimizza per indici e viste)
  DBMS_ADVISOR.SET_TASK_PARAMETER(v_task_name, 'ANALYSIS_SCOPE', 'ALL');
  
  -- 4. Esegui l'analisi
  DBMS_ADVISOR.EXECUTE_TASK(v_task_name);
END;
/
```

### Visualizzazione dei risultati del SQL Access Advisor
```sql
SELECT rank, action_id, command, summary 
FROM   dba_advisor_actions 
WHERE  task_name = 'TASK_ACCESS_ADVISOR'
ORDER BY rank;
```
*Le azioni conterranno lo script DDL esatto (es. `CREATE MATERIALIZED VIEW ...`) da implementare per velocizzare l'intero carico di lavoro applicativo.*
