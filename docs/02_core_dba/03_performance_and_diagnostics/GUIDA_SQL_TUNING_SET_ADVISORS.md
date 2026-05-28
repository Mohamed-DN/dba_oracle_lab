# GUIDA COMPLETA: SQL Tuning Set (STS) & Advisors — Ottimizzazione Avanzata, SQL Profiles & Access Advisor

> [!NOTE]
> **DOCUMENTI DI PERFORMANCE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **SQL Tuning Set & Advisors (questa guida)**: [GUIDA_SQL_TUNING_SET_ADVISORS.md](./GUIDA_SQL_TUNING_SET_ADVISORS.md) (DBMS_SQLTUNE, SQL Tuning Advisor, SQL Profiles, Access Advisor).
> - **SQL Plan Management & Baselines**: [GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md](./GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md) (SPM, stabilizzazione dei piani di query, baselines, prevenzione regressioni).
> - **AWR, ASH & ADDM**: [GUIDA_AWR_ASH_ADDM.md](./GUIDA_AWR_ASH_ADDM.md) (diagnostica delle prestazioni del carico di lavoro e statistica).
> - **Troubleshooting Completo**: [GUIDA_TROUBLESHOOTING_COMPLETO.md](./GUIDA_TROUBLESHOOTING_COMPLETO.md) (metodo di analisi strutturata e wait events).

---

## 1. Architettura & Concetti: Cos'è un SQL Tuning Set (STS)?

Un **SQL Tuning Set (STS)** è un oggetto del database (memorizzato all'interno dello schema `SYS` nel tablespace `SYSAUX`) che funge da contenitore persistente per un gruppo di istruzioni SQL. A differenza della *Shared SQL Area* (Cursor Cache), che è volatile e viene svuotata ad ogni riavvio dell'istanza o a causa dell'invecchiamento dei cursori (age out), l'STS memorizza in modo permanente:

1.  **Testo della Query (SQL Text)**: L'istruzione SQL completa.
2.  **Variabili di Bind (Bind Variables)**: I valori effettivi passati durante l'esecuzione (fondamentali per riprodurre le performance e consentire all'advisor di analizzare i predicati).
3.  **Statistiche di Esecuzione**: Tempo di CPU, tempo trascorso (elapsed time), letture logiche (*buffer gets*), letture fisiche (*disk reads*), righe elaborate, numero di esecuzioni.
4.  **Contesto Operativo**: Schema di parsing, nome del modulo applicativo (`MODULE`), dell'azione (`ACTION`) ed eventuale identificativo client.
5.  **Piani d'Esecuzione**: Il piano d'esecuzione reale (con tanto di hash value) catturato al momento della memorizzazione.

```
 FONTI DI INPUT:
 +---------------------------+
 |  Cursor Cache (Memoria)  |--+
 +---------------------------+  |
 +---------------------------+  |   CATTURA (LOAD)
 |  Snapshot AWR (Storico)   |--+--&gt; [ SQL TUNING SET ]
 +---------------------------+  |    (Persistente in DB)
 +---------------------------+  |
 |  SQL Text / Script Manual |--+
 +---------------------------+
                                           |
       +-----------------------------------+-----------------------------------+
       v                                   v                                   v
 +--------------+                    +--------------+                    +--------------+
 |  SQL TUNING  |                    |  SQL ACCESS  |                    |     SQL      |
 |   ADVISOR    |                    |   ADVISOR    |                    | PERFORMANCE  |
 | (SQL Profile)|                    |(Indici/MView)|                    |ANALYZER (SPA)|
 +--------------+                    +--------------+                    +--------------+
```

### Le Viste del Dizionario Dati per STS:
*   `DBA_SQLSET`: Mostra l'elenco di tutti gli STS creati nel database.
*   `DBA_SQLSET_STATEMENTS`: Dettaglio di ogni istruzione SQL associata a un STS, comprese le statistiche aggregate di esecuzione.
*   `DBA_SQLSET_BINDS`: Elenco e valore delle variabili di bind associate a ciascuna query nell'STS.
*   `DBA_SQLSET_PLANS`: Piani di esecuzione reali catturati per le query contenute nell'STS.

---

## 2. Creazione & Popolamento Avanzato di un STS

Per gestire un STS si utilizza il package di sistema `DBMS_SQLTUNE`. Vediamo le tre metodologie principali di creazione e popolamento.

### 2.1 Setup di un STS Vuoto
```sql
sqlplus / as sysdba

BEGIN
  DBMS_SQLTUNE.CREATE_SQLSET(
    sqlset_name => 'STS_PROD_WORKLOAD_CRITICAL',
    description => 'Workload applicativo ad alta intensità di I/O e CPU'
  );
END;
/
```

### 2.2 Popolare l'STS dalla Cursor Cache (Filtri Avanzati)
Questo metodo cattura in tempo reale le query attualmente presenti in memoria nella SGA. Filtriamo le query eseguite dallo schema `APP_CRM` che hanno accumulato oltre 50.000 letture logiche o che hanno consumato più di 10 secondi di tempo CPU.

```sql
DECLARE
  v_cur DBMS_SQLTUNE.SQLSET_CURSOR;
BEGIN
  -- 1. Apri il cursore per catturare le query corrispondenti
  OPEN v_cur FOR
    SELECT VALUE(p)
    FROM   TABLE(
             DBMS_SQLTUNE.SELECT_CURSOR_CACHE(
               basic_filter   => 'parsing_schema_name = ''APP_CRM'' AND (buffer_gets > 50000 OR cpu_time > 10000000)',
               attribute_list => 'ALL'
             )
           );

  -- 2. Carica i dati nell'STS esistente
  DBMS_SQLTUNE.LOAD_SQLSET(
    sqlset_name     => 'STS_PROD_WORKLOAD_CRITICAL',
    populate_cursor => v_cur
  );

  CLOSE v_cur;
END;
/
```

### 2.3 Popolare l'STS dallo Storico AWR (Tuning Post-Mortem)
Se si desidera fare il tuning di un incidente avvenuto in passato (es. ieri notte durante il batch caricato tra lo snapshot 1540 e 1560), carichiamo le prime 50 query ordinate per tempo di esecuzione trascorso (*elapsed_time*) direttamente dal repository AWR.

```sql
DECLARE
  v_cur DBMS_SQLTUNE.SQLSET_CURSOR;
BEGIN
  -- 1. Apri il cursore estrattore da AWR ordinando per elapsed_time
  OPEN v_cur FOR
    SELECT VALUE(p)
    FROM   TABLE(
             DBMS_SQLTUNE.SELECT_WORKLOAD_REPOSITORY(
               begin_snap      => 1540,
               end_snap        => 1560,
               basic_filter    => 'parsing_schema_name = ''APP_CRM''',
               ranking_measure => 'elapsed_time',
               result_limit    => 50,
               attribute_list  => 'ALL'
             )
           );

  -- 2. Carica i dati
  DBMS_SQLTUNE.LOAD_SQLSET(
    sqlset_name     => 'STS_PROD_WORKLOAD_CRITICAL',
    populate_cursor => v_cur
  );

  CLOSE v_cur;
END;
/
```

### 2.4 Popolare l'STS da una Singola Query Specifica (Tramite SQL_ID)
Se si vuole isolare una singola query problematica di cui si conosce il `SQL_ID`:
```sql
DECLARE
  v_cur DBMS_SQLTUNE.SQLSET_CURSOR;
BEGIN
  OPEN v_cur FOR
    SELECT VALUE(p)
    FROM   TABLE(
             DBMS_SQLTUNE.SELECT_CURSOR_CACHE(
               basic_filter   => 'sql_id = ''9m7g5ts4b1w8r''',
               attribute_list => 'ALL'
             )
           );

  DBMS_SQLTUNE.LOAD_SQLSET(
    sqlset_name     => 'STS_PROD_WORKLOAD_CRITICAL',
    populate_cursor => v_cur
  );
  
  CLOSE v_cur;
END;
/
```

---

## 3. SQL Tuning Advisor (STA): Esecuzione Completa

Il **SQL Tuning Advisor** esamina le istruzioni SQL contenute in un STS o caricate direttamente, ed effettua un'analisi approfondita del piano d'esecuzione. Il motore esegue un'ottimizzazione globale valutando:
1.  Statistiche mancanti o obsolete.
2.  Profili SQL (SQL Profiles) per correggere la stima di cardinalità.
3.  Accesso strutturale (consigli su indici e partizionamento).
4.  Ristrutturazione SQL (modifiche della sintassi inefficiente).

### 3.1 Creazione ed Esecuzione del Tuning Task per un intero STS

```sql
DECLARE
  v_task_name VARCHAR2(100);
BEGIN
  -- 1. Crea il Task di tuning associato all'STS
  v_task_name := DBMS_SQLTUNE.CREATE_TUNING_TASK(
    sqlset_name => 'STS_PROD_WORKLOAD_CRITICAL',
    scope       => 'COMPREHENSIVE', -- Esegue analisi esaustiva
    time_limit  => 3600,             -- Tempo limite totale in secondi (1 ora)
    task_name   => 'TASK_TUNING_STS_CRM',
    description => 'Analisi approfondita del workload critico di CRM'
  );
  
  -- 2. Esegue il Task
  DBMS_SQLTUNE.EXECUTE_TUNING_TASK(task_name => 'TASK_TUNING_STS_CRM');
END;
/
```

### 3.2 Creazione ed Esecuzione per una Query con Bind Variables fornite manualmente
Se la query non è in cache e vogliamo passarla come testo puro configurando le variabili di bind:

```sql
DECLARE
  v_task_name VARCHAR2(100);
  v_sql       CLOB;
BEGIN
  v_sql := 'SELECT * FROM app_crm.orders WHERE status = :status AND total_amount > :amount';
  
  v_task_name := DBMS_SQLTUNE.CREATE_TUNING_TASK(
    sql_text    => v_sql,
    bind_list   => SQL_BINDS(
                     ANYDATA.ConvertVarchar2('COMPLETED'),
                     ANYDATA.ConvertNumber(5000)
                   ),
    scope       => 'COMPREHENSIVE',
    time_limit  => 300, -- 5 minuti
    task_name   => 'TASK_TUNING_MANUAL_SQL',
    description => 'Tuning manuale query ordini'
  );
  
  DBMS_SQLTUNE.EXECUTE_TUNING_TASK(task_name => 'TASK_TUNING_MANUAL_SQL');
END;
/
```

### 3.3 Monitoraggio e Controllo dello Stato dei Task
Per verificare l'avanzamento dell'elaborazione di tuning, utile per task lunghi:
```sql
SELECT task_name, status, execution_start, execution_end 
FROM   dba_advisor_tasks 
WHERE  task_name IN ('TASK_TUNING_STS_CRM', 'TASK_TUNING_MANUAL_SQL');
```

---

## 4. Deep Dive: Analisi e Interpretazione dei Report di STA

Una volta completata l'esecuzione del task di tuning, possiamo estrarre il report testuale generato dall'Advisor. Questo documento rappresenta la "Bibbia" delle performance per la query analizzata.

```sql
SET LONG 2000000;
SET PAGESIZE 50000;
SET LINESIZE 250;
COLUMN report FORMAT a220;

SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('TASK_TUNING_STS_CRM') AS report FROM dual;
```

### Anatomia dei Findings di un Report reale

Il report restituito si divide in sezioni strutturate per ogni query analizzata. Vediamo come interpretare le 5 macro-aree di raccomandazione:

#### 1. Statistics Finding (Statistiche obsolete/mancanti)
```
-------------------------------------------------------------------------------
1- Statistics Finding
-------------------------------------------------------------------------------
  The optimizer statistics for table "APP_CRM"."ORDERS" are stale.
  The optimizer statistics for table "APP_CRM"."ORDER_ITEMS" are missing.

  Recommendation:
  - Consider collecting optimizer statistics for these tables.
    execute dbms_stats.gather_table_stats(ownname => 'APP_CRM', tabname => 'ORDERS', estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE);
```
> 💡 **Azione del DBA**: L'optimizer sta prendendo decisioni basate su dati errati. Eseguire immediatamente il comando `DBMS_STATS` consigliato.

#### 2. SQL Profile Finding (Correzione delle cardinalità)
```
-------------------------------------------------------------------------------
2- SQL Profile Finding
-------------------------------------------------------------------------------
  A potentially better execution plan was found for this statement.
  The recommended plan avoids a full table scan on "ORDERS" and uses a selective index.

  Recommendation:
  - Consider accepting the recommended SQL Profile.
    execute dbms_sqltune.accept_sql_profile(task_name => 'TASK_TUNING_STS_CRM', task_depowner => 'SYS', object_id => 3, name => 'SYS_SQLPROF_01fc84768');
```
> 💡 **Azione del DBA**: Il motore ha rilevato una discrepanza sistematica tra le stime del parser e l'esecuzione reale (es. predice 1 riga ma ne restituisce 1.000.000). Accettando il profilo, si inseriscono nel database dei "coefficienti correttivi" che forzano l'optimizer a scegliere il piano corretto senza toccare il codice dell'applicazione.

#### 3. Index Finding (Miglioramento dell'Access Path)
```
-------------------------------------------------------------------------------
3- Index Finding
-------------------------------------------------------------------------------
  The execution plan for this statement can be improved by creating one or more indices.

  Recommendation:
  - Consider creating the recommended index:
    create index "APP_CRM"."ORDERS_IDX_STATUS_DATE" on "APP_CRM"."ORDERS"("STATUS","ORDER_DATE");
```
> 💡 **Azione del DBA**: La query effettua scan inefficienti. Creare l'indice consigliato in un ambiente di staging per verificarne l'impatto sugli inserimenti.

#### 4. Restructure SQL Finding (Sintassi inefficiente)
```
-------------------------------------------------------------------------------
4- Restructure SQL Finding
-------------------------------------------------------------------------------
  The query uses an inefficient "UNION" operator. "UNION ALL" should be used if the
  result sets are mutually exclusive.

  Recommendation:
  - Rewrite the query using "UNION ALL" instead of "UNION".
```
> 💡 **Azione del DBA**: Segnalare il problema al team di sviluppo applicativo per riscrivere il codice ed eliminare l'inutile overhead di ordinamento e deduplicazione richiesto dal `UNION` classico.

#### 5. Alternative Plan Finding (Piano Storico)
L'advisor analizza lo storico AWR e la cursor cache per vedere se in passato la stessa identica query ha girato con un piano d'esecuzione migliore. Se lo trova, propone di ripristinarlo associando una SQL Plan Baseline.

---

## 5. Gestione Completa dei SQL Profiles

Il **SQL Profile** rappresenta la soluzione ideale per query di terze parti (es. software ERP commerciali come SAP, Oracle EBS o pacchetti chiusi) in cui **è impossibile modificare il codice SQL**.

### 5.1 Accettazione e Abilitazione di un SQL Profile
Una volta identificata la raccomandazione dal report, si accetta il profilo associandolo alla query. L'impostazione `force_match => TRUE` è fondamentale in ambienti OLTP: dice ad Oracle di applicare il profilo anche se i valori letterali all'interno dei predicati cambiano ad ogni esecuzione (es. `WHERE id = 100` e `WHERE id = 101` useranno lo stesso profilo).

```sql
BEGIN
  DBMS_SQLTUNE.ACCEPT_SQL_PROFILE(
    task_name    => 'TASK_TUNING_STS_CRM',
    object_id    => 3,                         -- Recuperato dal report di tuning
    name         => 'SQLPROF_CRM_ORDERS_PERF', -- Nome mnemonico ed identificabile
    description  => 'Profilo di correzione stima cardinalità su tabella ORDERS',
    category     => 'DEFAULT',                 -- Categoria di attivazione
    force_match  => TRUE,                       -- Applica il matching anche con valori letterali differenti
    replace      => TRUE                        -- Sostituisce se già esistente
  );
END;
/
```

### 5.2 Monitorare e Verificare i SQL Profiles
```sql
COLUMN name FORMAT a30;
COLUMN sql_text FORMAT a80;
COLUMN category FORMAT a10;
COLUMN status FORMAT a10;

SELECT name, 
       category, 
       status, 
       force_matching, 
       created,
       last_modified
FROM   dba_sql_profiles
ORDER BY created DESC;
```

### 5.3 Abilitare/Disabilitare o Modificare un SQL Profile
Se si vuole disattivare temporaneamente un profilo senza eliminarlo:
```sql
-- Disabilitare
BEGIN
  DBMS_SQLTUNE.ALTER_SQL_PROFILE(
    name            => 'SQLPROF_CRM_ORDERS_PERF',
    attribute_name  => 'STATUS',
    value           => 'DISABLED'
  );
END;
/

-- Rimettere in ENABLED
BEGIN
  DBMS_SQLTUNE.ALTER_SQL_PROFILE(
    name            => 'SQLPROF_CRM_ORDERS_PERF',
    attribute_name  => 'STATUS',
    value           => 'ENABLED'
  );
END;
/
```

### 5.4 Eliminazione definitiva di un SQL Profile
```sql
BEGIN
  DBMS_SQLTUNE.DROP_SQL_PROFILE(name => 'SQLPROF_CRM_ORDERS_PERF', ignore => FALSE);
END;
/
```

---

## 6. Procedura Avanzata: Esportare e Importare SQL Profiles (Test ➔ Produzione)

In ambiente bancario o governativo è severamente proibito eseguire elaborazioni pesanti di Tuning Task direttamente sui nodi di produzione. 
**Best Practice**: Popolare un STS sul primario in Prod, esportarlo su un database di Lab/Test speculare, eseguire qui il Tuning Advisor, validare ed accettare il SQL Profile risultante, ed infine esportare/importare il solo SQL Profile finale nel database di produzione (con downtime zero e overhead nullo).

```
 +----------------------+                     +----------------------+
 | DATABASE DI SORGENTE |                     | DATABASE DI TARGET   |
 |        (TEST)        |                     |     (PRODUZIONE)     |
 +----------------------+                     +----------------------+
 |  SQL_PROFILE attivo  |                     |                      |
 |          |           |                     |          ^           |
 |  (PACK nel DB)       |                     |  (UNPACK nel DB)     |
 |          v           |                     |          |           |
 |   [ STAGING TABLE ]  |--&gt; Export/Import --&gt;|   [ STAGING TABLE ]  |
 +----------------------+      Data Pump      +----------------------+
```

### Step 1: Creazione della Staging Table in ambiente di Test (Sorgente)
Creiamo una tabella strutturata in grado di contenere i metadati del profilo.
```sql
-- Esegui in TEST
BEGIN
  DBMS_SQLTUNE.CREATE_STGTAB_SQLPROF(
    table_name  => 'STAGE_SQL_PROFILES',
    schema_name => 'SYSTEM'
  );
END;
/
```

### Step 2: Confezionamento (Pack) del Profilo SQL nella Staging Table
Copiamo i dati fisici dal dizionario di sistema nella nostra tabella di transito.
```sql
-- Esegui in TEST
BEGIN
  DBMS_SQLTUNE.PACK_STGTAB_SQLPROF(
    staging_table_name => 'STAGE_SQL_PROFILES',
    staging_schema_owner=> 'SYSTEM',
    profile_name       => 'SQLPROF_CRM_ORDERS_PERF' -- Esporta solo questo profilo specifico
  );
END;
/
```

### Step 3: Esportazione della Tabella via Data Pump
Esportiamo fisicamente la tabella in un file dump.
```bash
# Esegui sul server OS di TEST
expdp system/password TABLES=SYSTEM.STAGE_SQL_PROFILES DIRECTORY=DPUMP_DIR DUMPFILE=export_sql_profiles.dmp LOGFILE=exp_profiles.log
```

Trasferisci il file dump `export_sql_profiles.dmp` sul server di produzione.

### Step 4: Importazione della Tabella in Produzione (Target)
Importiamo la tabella di transito sul database di destinazione.
```bash
# Esegui sul server OS di PRODUZIONE
impdp system/password TABLES=SYSTEM.STAGE_SQL_PROFILES DIRECTORY=DPUMP_DIR DUMPFILE=export_sql_profiles.dmp LOGFILE=imp_profiles.log TABLE_EXISTS_ACTION=REPLACE
```

### Step 5: Sballamento (Unpack) e Attivazione dei SQL Profiles in Produzione
Eseguiamo l'unpack. I profili inseriti nella staging table verranno caricati immediatamente nel dizionario dati di produzione e risulteranno attivi ed operativi fin da subito.
```sql
-- Esegui in PRODUZIONE
BEGIN
  DBMS_SQLTUNE.UNPACK_STGTAB_SQLPROF(
    staging_table_name => 'STAGE_SQL_PROFILES',
    staging_schema_owner=> 'SYSTEM',
    replace            => TRUE -- Sostituisce se esistenti in produzione
  );
END;
/
```

---

## 7. SQL Access Advisor: Ottimizzazione Fisica Massiva

Mentre il SQL Tuning Advisor effettua il tuning a livello logico e puntuale di singole istruzioni, il **SQL Access Advisor** lavora sul carico di lavoro globale (*workload*) definendo una strategia fisica di database globale. Analizza le relazioni tra le query per raccomandare la creazione di:
1.  **Indici B-Tree ed indici Bitmap** complessi.
2.  **Materialized Views** e relativi log per la pre-aggregazione e il query rewrite automatico.
3.  Strategie ottimali di **Partizionamento** per tabelle massive.

### Workflow Completo PL/SQL per il Setup ed Esecuzione di SQL Access Advisor

```sql
DECLARE
  v_task_name VARCHAR2(100) := 'TASK_ACCESS_ADVISOR_GLOBAL';
BEGIN
  -- 1. Crea il Task di Access Advisor
  DBMS_ADVISOR.CREATE_TASK(
    advisor_name => 'SQL Access Advisor',
    task_name    => v_task_name
  );
  
  -- 2. Associa il Task al nostro SQL Tuning Set persistente (il workload reale)
  DBMS_ADVISOR.LINK_TEMPLATE(
    task_name => v_task_name,
    relations => 'STS_PROD_WORKLOAD_CRITICAL'
  );
  
  -- 3. Imposta i parametri dell'advisor
  -- ANALYSYS_SCOPE: può analizzare INDEX (indici), MVIEW (viste), PARTITION (partizionamento) o ALL (tutto)
  DBMS_ADVISOR.SET_TASK_PARAMETER(v_task_name, 'ANALYSIS_SCOPE', 'ALL');
  
  -- Definisce il criterio di ottimizzazione (es. massimizzare la velocità di query OLTP)
  DBMS_ADVISOR.SET_TASK_PARAMETER(v_task_name, 'WORKLOAD_SOURCE', 'SQLSET');
  DBMS_ADVISOR.SET_TASK_PARAMETER(v_task_name, 'TIME_LIMIT', 1800); -- 30 minuti max
  
  -- 4. Esegui il calcolo
  DBMS_ADVISOR.EXECUTE_TASK(v_task_name);
END;
/
```

### Estrarre e Leggere le Raccomandazioni Strutturali
Le raccomandazioni strutturali vengono salvate in viste di sistema. Possiamo visualizzare un riassunto dei benefici stimati e dei comandi DDL esatti generati dall'advisor:

```sql
-- Query per controllare le azioni consigliate
SELECT action_id,
       command,
       summary,
       ROUND(benefit_cost_ratio, 2) AS cost_benefit
FROM   dba_advisor_actions
WHERE  task_name = 'TASK_ACCESS_ADVISOR_GLOBAL'
ORDER BY benefit_cost_ratio DESC;
```

Se vogliamo estrarre l'intero script SQL con le DDL pronte all'uso:
```sql
DECLARE
  v_script CLOB;
BEGIN
  DBMS_ADVISOR.GET_TASK_SCRIPT(
    task_name => 'TASK_ACCESS_ADVISOR_GLOBAL',
    access_type=> 'ALL',
    script     => v_script
  );
  -- In un client SQL come SQL Developer o PL/SQL Developer, questo script può essere salvato in file.
END;
/
```

---

## 8. Panoramica: SQL Performance Analyzer (SPA)

Per completare il set di strumenti del Performance DBA, occorre citare il **SQL Performance Analyzer (SPA)**, componente chiave della suite *Real Application Testing (RAT)*.
Mentre il SQL Tuning Advisor serve per curare le performance di query lente, lo SPA serve per **prevenire ed analizzare l'effetto di un cambiamento sistemico** (es. aggiornamento dei parametri d'iniziazione del database, migrazione del server su nuovo hardware Exadata, applicazione di un Release Update RU, o aggiunta di 10 indici consigliati dall'Access Advisor).

### Come lavora lo SPA:
1.  **Cattura**: Si registra il carico di lavoro di produzione all'interno di un SQL Tuning Set (STS) prima del cambiamento.
2.  **Trial 1 (Baseline)**: Si esegue un test in ambiente isolato simulando o misurando le performance iniziali delle query contenute nell'STS.
3.  **Applica Cambiamento**: Si effettua la variazione (es. si cambia il parametro `optimizer_features_enable` da `19.1.0` a `21.1.0`).
4.  **Trial 2 (Post-Change)**: Si ri-eseguono le query dell'STS registrando le nuove prestazioni.
5.  **Confronto**: SPA genera un report analitico dettagliato mostrando quali query sono migliorate, quali sono rimaste stabili e quali hanno subito una **regressione**, consentendo al DBA di stabilizzarle tramite SQL Profiles o Baselines prima del Go-Live definitivo.

---

## 9. Risoluzione Problemi, Diagnostica & Licenze

### 9.1 Perché un SQL Profile non viene utilizzato?
Se hai creato un SQL Profile ma noti che la query continua ad andare lenta e a non usarlo:
1.  **Mismatch delle Variabili di Bind**: Se hai creato il profilo con `force_match => FALSE`, ma l'applicazione passa argomenti differenti ad ogni query, il profilo non farà match. Ricrealo abilitando `force_match => TRUE`.
2.  **Category non attiva**: Di default il profilo viene creato in categoria `DEFAULT`. Se il database è impostato su un'altra categoria applicativa (parametro `sqltune_category`), il profilo non verrà letto.
    ```sql
    -- Controlla il parametro di sessione/sistema
    SHOW PARAMETER sqltune_category;
    -- Se impostato a qualcosa diverso da DEFAULT, sposta la categoria del profilo:
    EXEC DBMS_SQLTUNE.ALTER_SQL_PROFILE(name => 'SQLPROF_CRM_ORDERS_PERF', attribute_name => 'CATEGORY', value => 'NEW_CATEGORY');
    ```
3.  **La firma (Signature) della query è differente**: Spazi bianchi extra, ritorni a capo o caratteri maiuscoli/minuscoli modificano la query. Il testo della query deve corrispondere esattamente (carattere per carattere) al profilo generato, a meno che non si utilizzi la firma normalizzata.

### 9.2 SQL Profiles vs SQL Plan Baselines (SPM)
È importante non confondere questi due eccellenti strumenti di stabilità:

| Caratteristica | SQL Profile (STA) | SQL Plan Baseline (SPM) |
|---|---|---|
| **Metodologia** | **Predittivo**: Fornisce all'optimizer statistiche ausiliarie per correggere stime errate di cardinalità. L'optimizer calcola comunque liberamente il piano. | **Prescrittivo**: Controlla e limita le scelte dell'optimizer a un set di piani predefiniti ed accettati. |
| **Flessibilità** | Alta: Se cambiano le condizioni fisiche (es. si aggiunge un indice eccellente), l'optimizer può calcolare un nuovo piano ancora migliore. | Bassa/Stabile: Impedisce qualsiasi piano alternativo a meno che non venga evoluto. |
| **Licensing** | Richiede **Oracle Tuning Pack** (licenziato a parte). | Incluso nella licenza **Enterprise Edition** standard. |
| **Uso ideale** | Query complesse con join multipli e sottoquery dove le stime di cardinalità falliscono sistematicamente. | Query OLTP stabili in produzione in cui si vuole bloccare al 100% il piano contro qualsiasi regressione causata da patching. |

---

## 10. Checklist Operativa di Tuning per il DBA

1.  **Morning Check**: Identificare le query che hanno causato wait event anomali o picchi di I/O nel report ADDM o AWR delle ultime 24 ore.
2.  **Isolamento**: Estrarre le query incriminate inserendole all'interno di un SQL Tuning Set dedicato (`CREATE_SQLSET` + `LOAD_SQLSET`).
3.  **Analisi**: Lanciare un tuning task completo in ambiente di Lab o Staging speculare per non intaccare la CPU del primario.
4.  **Triage**: Analizzare il report generato. Se consiglia indici, testarli accuratamente su tabelle di grandi dimensioni valutando i costi degli indici extra sulle operazioni di insert.
5.  **Stabilizzazione**: Se consiglia un SQL Profile, validarlo, accettarlo con `force_match => TRUE` in ambiente di staging, e migrarlo in produzione con la procedura di **Pack/Unpack** descritta al punto 6.
