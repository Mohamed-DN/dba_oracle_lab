# GUIDA COMPLETA: SQL Plan Management (SPM) — Stabilità & Controllo dei Piani d'Esecuzione

> [!NOTE]
> **DOCUMENTI DI PERFORMANCE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **SQL Plan Management & Baselines (questa guida)**: [GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md](./GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md) (SPM, stabilizzazione dei piani di query, baselines, prevenzione regressioni).
> - **SQL Tuning Set & Advisors**: [GUIDA_SQL_TUNING_SET_ADVISORS.md](./GUIDA_SQL_TUNING_SET_ADVISORS.md) (DBMS_SQLTUNE, SQL Tuning Advisor, SQL Profiles, Access Advisor).
> - **AWR, ASH & ADDM**: [GUIDA_AWR_ASH_ADDM.md](./GUIDA_AWR_ASH_ADDM.md) (diagnostica delle prestazioni del carico di lavoro e statistica).
> - **Troubleshooting Completo**: [GUIDA_TROUBLESHOOTING_COMPLETO.md](./GUIDA_TROUBLESHOOTING_COMPLETO.md) (metodo di analisi strutturata e wait events).

---

## 1. Perché serve SQL Plan Management (SPM)?

Nelle basi dati di livello Enterprise, un cambio repentino del piano d'esecuzione di una query critica per il business rappresenta uno dei rischi più elevati per la continuità operativa. Durante le manutenzioni ordinarie (raccolta statistiche di sistema, aggiornamenti parametri di inizializzazione, ricompilazione indici, migrazioni di versione, installazione di RU Patch trimestrali), l'**Optimizer** di Oracle può stimare che un nuovo percorso di accesso ai dati sia ottimale, quando in realtà causa regressioni disastrose.

**SQL Plan Management (SPM)** è un meccanismo integrato nel kernel di Oracle che **garantisce la stabilità delle prestazioni del database**. Impedisce all'optimizer di utilizzare un nuovo piano d'esecuzione non testato prima che il DBA (o un meccanismo automatico) lo abbia esaminato ed **accettato** verificando che non provochi regressioni.

```
                    [ RICHIESTA ESECUZIONE QUERY SQL ]
                                    │
                                    ▼
                     L'Optimizer genera un NUOVO PIANO
                                    │
                                    ▼
                 Esiste una SQL Plan Baseline per la query?
                                    │
                    ┌───────────────┴───────────────┐
                    ▼ (SI)                          ▼ (NO)
         Cerca i piani ACCETTATI              Esegui il piano
            nella Baseline                    generato normalmente
                    │
       ┌────────────┴────────────┐
       ▼                         ▼
Il nuovo piano è      Il nuovo piano NON è
   accettato?                accettato
       │                         │
       ▼                         ▼
Usa il nuovo piano!    Usa il vecchio piano stabile!
                       Salva il nuovo piano come
                       NON ACCETTATO per l'evoluzione.
```

---

## 2. Architettura & Ciclo di Vita delle Baselines

Il funzionamento di SPM si basa sulla persistenza all'interno del dizionario dati (tablespace `SYSAUX`) dei piani d'esecuzione validi per una query, identificata tramite una firma digitale unica (**SQL Signature**).

### Il Ciclo di Vita in 3 Fasi:

1.  **Cattura (Capture)**: Registrazione della firma della query SQL e memorizzazione del suo piano d'esecuzione corrente come baseline iniziale.
2.  **Selezione (Selection)**: Ad ogni riesecuzione della query, l'optimizer è obbligato a selezionare esclusivamente i piani all'interno della baseline che sono marcati come **Accepted**.
3.  **Evoluzione (Evolve)**: I nuovi piani alternativi calcolati dall'optimizer nel tempo vengono registrati all'interno della baseline ma marcati come **Non-Accepted** (`ACCEPTED = NO`). Il DBA esegue un test prestazionale dry-run (Evoluzione) per misurare l'I/O ed il tempo CPU del nuovo piano rispetto a quello vecchio. Se le prestazioni migliorano, il nuovo piano viene promosso ad **Accepted**.

---

## 3. Configurazione Parametriche e Strategie di Cattura

Il comportamento di SPM è controllato principalmente da due parametri di inizializzazione del database:

```sql
sqlplus / as sysdba

-- 1. Controlla lo stato dei parametri attuali
SHOW PARAMETER optimizer_capture_sql_plan_baselines;
SHOW PARAMETER optimizer_use_sql_plan_baselines;
```

### Strategie di Setup in Produzione:

| Criterio | Parametro `optimizer_capture_sql_plan_baselines` | Parametro `optimizer_use_sql_plan_baselines` | Descrizione |
|---|---|---|---|
| **Cattura Automatica** | `TRUE` | `TRUE` | **Consigliata in fase iniziale**: Il database registra automaticamente i piani per tutte le query eseguite almeno due volte. Da non tenere attivo per lunghi periodi in ambienti con milioni di query dinamiche per non saturare il tablespace `SYSAUX`. |
| **Conservazione e Uso** | `FALSE` | `TRUE` | **Standard di Produzione**: Congela le baselines esistenti ed utilizza solo i piani precedentemente validati ed accettati. I nuovi piani non vengono più catturati automaticamente. |

```sql
-- Configurazione Standard di Produzione (Congelamento ed Uso)
ALTER SYSTEM SET optimizer_capture_sql_plan_baselines = FALSE SCOPE=BOTH SID='*';
ALTER SYSTEM SET optimizer_use_sql_plan_baselines = TRUE SCOPE=BOTH SID='*';
```

---

## 4. Workflow Avanzato: Caricamento Manuale delle Baselines

La strategia più sicura per stabilizzare query specifiche consiste nel caricare i piani desiderati manualmente dalla **Shared SQL Area (Cursor Cache)** o da un **SQL Tuning Set (STS)**.

### Scenario: Stabilizzare una query critica
Identifichiamo il `SQL_ID` e il piano stabile desiderato (`PLAN_HASH_VALUE`) tramite query in memoria:

```sql
SELECT sql_id, plan_hash_value, executions, elapsed_time/executions AS avg_time, sql_text
FROM   v$sql
WHERE  sql_text LIKE '%SELECT /*+ CRM_CRITICAL_QUERY */%';
-- Ipotizziamo: SQL_ID = 'b73s8df9ap3ws', PLAN_HASH_VALUE = 203847592
```

### Metodo 1: Caricamento Singolo dalla Cursor Cache
Assegniamo il piano corretto al database forzandolo come baseline accettata:

```sql
DECLARE
  v_plans_loaded PLS_INTEGER;
BEGIN
  v_plans_loaded := DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(
    sql_id          => 'b73s8df9ap3ws',
    plan_hash_value => 203847592,
    enabled         => 'YES',
    accepted        => 'YES' -- Forza l'accettazione immediata del piano!
  );
  DBMS_OUTPUT.PUT_LINE('Piani caricati con successo: ' || v_plans_loaded);
END;
/
```

### Metodo 2: Caricamento Massivo da un SQL Tuning Set (STS)
Se abbiamo ottimizzato un intero parco query in un STS, possiamo migrare tutti i piani stabili nelle baselines di SPM:

```sql
DECLARE
  v_plans_loaded PLS_INTEGER;
BEGIN
  v_plans_loaded := DBMS_SPM.LOAD_PLANS_FROM_SQLSET(
    sqlset_name  => 'STS_PROD_WORKLOAD_CRITICAL',
    sqlset_owner => 'SYS',
    basic_filter => 'parsing_schema_name = ''APP_CRM'''
  );
  DBMS_OUTPUT.PUT_LINE('Piani totali caricati da STS a SPM: ' || v_plans_loaded);
END;
/
```

---

## 5. Gestione & Evoluzione delle Baselines

I nuovi piani proposti dall'optimizer rimangono nello stato di `accepted = NO` finché non vengono evoluti. 

### 5.1 Monitorare lo stato delle Baselines attive
```sql
SELECT sql_handle,
       plan_name,
       enabled,
       accepted,
       reproduced,
       autopurge,
       last_executed
FROM   dba_sql_plan_baselines
WHERE  parsing_schema_name = 'APP_CRM';
```

### 5.2 Evoluzione Manuale di una singola Baseline (Dry-Run Prestazionale)
Il DBA esegue l'evoluzione confrontando le metriche prestazionali (tempo CPU, buffer gets) del vecchio piano con quello nuovo.

```sql
DECLARE
  v_report CLOB;
BEGIN
  v_report := DBMS_SPM.EVOLVE_SQL_PLAN_BASELINE(
    sql_handle => 'SQL_0b73s8df9ap3ws',
    verify     => 'YES', -- Esegue il test reale prima di decidere
    commit     => 'YES'  -- Se il nuovo piano è prestazionalmente migliore del 1.5x, promuovilo ad ACCEPTED
  );
  DBMS_OUTPUT.PUT_LINE(v_report);
END;
/
```

### 5.3 Il Task di Evoluzione Automatica di Oracle (`SYS_AUTO_SPM_EVOLVE_TASK`)
A partire da Oracle 12c/19c, il database dispone di un task automatico notturno (`SYS_AUTO_SPM_EVOLVE_TASK`) che gira all'interno della finestra di manutenzione ordinaria e provvede ad evolvere le baselines orfane senza intervento umano. 

Per impostare i parametri di questo task, come la soglia di miglioramento necessaria per promuovere un piano:

```sql
-- Configura il task automatico per promuovere i piani solo se migliorano di almeno 2 volte le performance (200%)
BEGIN
  DBMS_SPM.SET_EVOLVE_TASK_PARAMETER(
    task_name => 'SYS_AUTO_SPM_EVOLVE_TASK',
    parameter => 'ALTERNATE_PLAN_LIMIT',
    value     => 10
  );
  DBMS_SPM.SET_EVOLVE_TASK_PARAMETER(
    task_name => 'SYS_AUTO_SPM_EVOLVE_TASK',
    parameter => 'COMPASSIONATE_PLAN_LIMIT', -- Valore teorico di esempio
    value     => 5
  );
END;
/
```

---

## 6. Procedura di Esportazione e Importazione (TEST ➔ PRODUZIONE)

Se hai testato e stabilizzato le prestazioni delle query in un ambiente di laboratorio (UAT/TEST) ricreando baselines perfette, puoi esportarle e caricarle in Produzione per garantire la stabilità immediata prima del Go-Live.

```
 ┌──────────────────────┐                     ┌──────────────────────┐
 │ DATABASE DI SORGENTE │                     │ DATABASE DI TARGET   │
 │        (TEST)        │                     │     (PRODUZIONE)     │
 ├──────────────────────┤                     ├──────────────────────┤
 │ SPM Baseline attiva  │                     │                      │
 │          │           │                     │          ▲           │
 │  (PACK nel DB)       │                     │  (UNPACK nel DB)     │
 │          ▼           │                     │          │           │
 │   [ STAGING TABLE ]  │──► Export/Import ──►│   [ STAGING TABLE ]  │
 └──────────────────────┘      Data Pump      └──────────────────────┘
```

### Step 1: Creazione della Staging Table in Test (Sorgente)
```sql
-- Esegui in TEST
BEGIN
  DBMS_SPM.CREATE_STG_TAB_BASELINE(
    table_name      => 'SPM_STAGE_TEST_PROD',
    table_owner     => 'SYSTEM',
    tablespace_name => 'USERS'
  );
END;
/
```

### Step 2: Confezionamento (Pack) delle Baselines nella Staging Table
```sql
-- Esegui in TEST
DECLARE
  v_packed PLS_INTEGER;
BEGIN
  v_packed := DBMS_SPM.PACK_STG_TAB_BASELINE(
    table_name  => 'SPM_STAGE_TEST_PROD',
    table_owner => 'SYSTEM',
    sql_handle  => 'SQL_0b73s8df9ap3ws' -- Esporta solo questa baseline
  );
  DBMS_OUTPUT.PUT_LINE('Baselines impacchettate: ' || v_packed);
END;
/
```

### Step 3: Esportazione ed Importazione via Data Pump
```bash
# OS SORGENTE (TEST): esporta
expdp system/password TABLES=SYSTEM.SPM_STAGE_TEST_PROD DIRECTORY=DPUMP_DIR DUMPFILE=spm_stage_transfer.dmp

# OS TARGET (PRODUZIONE): importa
impdp system/password TABLES=SYSTEM.SPM_STAGE_TEST_PROD DIRECTORY=DPUMP_DIR DUMPFILE=spm_stage_transfer.dmp TABLE_EXISTS_ACTION=REPLACE
```

### Step 4: Sballamento (Unpack) in Produzione (Target)
```sql
-- Esegui in PRODUZIONE
DECLARE
  v_unpacked PLS_INTEGER;
BEGIN
  v_unpacked := DBMS_SPM.UNPACK_STG_TAB_BASELINE(
    table_name  => 'SPM_STAGE_TEST_PROD',
    table_owner => 'SYSTEM',
    sql_handle  => 'SQL_0b73s8df9ap3ws'
  );
  DBMS_OUTPUT.PUT_LINE('Baselines attivate in Produzione: ' || v_unpacked);
END;
/
```

---

## 7. Risoluzione Problemi & Best Practices

### 7.1 Perché l'optimizer non riproduce la Baseline? (`reproduced = NO`)
Se noti che la query continua ad usare un piano d'esecuzione pessimo ignorando la baseline attiva:
1.  **Indice Eliminato**: Il piano salvato nella baseline faceva affidamento su un indice che è stato accidentalmente eliminato dal database (`DROP INDEX`). In questo caso, il flag `reproduced` passa a `NO`. Il DBA deve ricreare l'indice mancante.
2.  **Cambiamento delle Partizioni**: La struttura fisica della tabella partizionata è cambiata radicalmente.
3.  **Ottimizzazione Riorientata**: Parametri dell'ottimizzatore a livello di sessione forzano piani differenti non riproducibili.

### 7.2 Rimozione manuale di Baselines obsolete o difettose
Se hai inserito accidentalmente un piano inefficiente nella baseline, puoi eliminarlo indicando la query ed il piano specifico:

```sql
DECLARE
  v_dropped PLS_INTEGER;
BEGIN
  v_dropped := DBMS_SPM.DROP_EVOLVE_TASK(task_name => '...'); -- Se associato a task
  
  -- Eliminazione diretta dal dizionario
  v_dropped := DBMS_SPM.DROP_SQL_PLAN_BASELINE(
    sql_handle => 'SQL_0b73s8df9ap3ws',
    plan_name  => 'SQL_PLAN_b73s8df9ap3ws0fc48'
  );
  DBMS_OUTPUT.PUT_LINE('Baseline rimossa: ' || v_dropped);
END;
/
```
