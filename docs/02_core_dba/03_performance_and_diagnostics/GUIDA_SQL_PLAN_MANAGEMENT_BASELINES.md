# GUIDA: SQL Plan Management (SPM) & SQL Plan Baselines — Stabilità delle Query in Produzione

> [!NOTE]
> **DOCUMENTI DI PERFORMANCE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **SQL Plan Management & Baselines (questa guida)**: [GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md](./GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md) (SPM, stabilizzazione dei piani di query, evoluzione).
> - **SQL Tuning Set & Advisors**: [GUIDA_SQL_TUNING_SET_ADVISORS.md](./GUIDA_SQL_TUNING_SET_ADVISORS.md) (DBMS_SQLTUNE, SQL Tuning Advisor, profili).
> - **AWR, ASH & ADDM**: [GUIDA_AWR_ASH_ADDM.md](./GUIDA_AWR_ASH_ADDM.md) (diagnostica delle prestazioni del carico di lavoro).
> - **Troubleshooting Completo**: [GUIDA_TROUBLESHOOTING_COMPLETO.md](./GUIDA_TROUBLESHOOTING_COMPLETO.md) (metodo di analisi strutturata e wait events).

---

## 1. Perché serve SQL Plan Management (SPM)?

Uno dei rischi principali durante le manutenzioni dei database (applicazione di patch trimestrali Release Update, raccolta statistiche, aggiornamenti parametri) è che l'**Optimizer** di Oracle cambi all'improvviso il piano di esecuzione di una query critica per il business. 
Se una query OLTP che impiegava 0.05 secondi passa improvvisamente da un `INDEX UNIQUE SCAN` a un `FULL TABLE SCAN`, l'applicazione può bloccarsi per timeout.

**SQL Plan Management (SPM)** è una tecnologia proattiva che **garantisce la stabilità delle prestazioni delle query**. Fa in modo che il database utilizzi solo piani di esecuzione precedentemente validati ed **accettati**, ignorando i nuovi piani proposti dall'optimizer finché non viene dimostrato tecnicamente che sono migliori di quelli vecchi.

```
                   PIANO DI QUERY ESISTENTE (ACCETTATO)
                                  │
                                  ▼
Optimizer rileva variazione (statistiche, parametri, patch RU)
                                  │
                                  ▼
                     Genera NUOVO PIANO di query
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
        Migliore del precedente?      Peggiore del precedente?
                    │                           │
                    ▼                           ▼
         Viene ACCETTATO ed            Viene rifiutato/messo in coda
         utilizzato                    come NON ACCETTATO (SPM Baseline)
```

---

## 2. Come funziona SPM (Il Ciclo di Vita)

La stabilizzazione tramite SPM si basa su 3 fasi distinte:

1.  **Cattura (Capture)**: Il database registra la firma di ogni query SQL e ne memorizza i piani di esecuzione correnti all'interno del dizionario.
2.  **Selezione (Selection)**: Quando la query viene rieseguita, il database controlla se esiste una **SQL Plan Baseline** per quella query. Se esiste, forza l'optimizer a scegliere solo tra i piani marcati come **Accepted**.
3.  **Evoluzione (Evolve)**: I nuovi piani alternativi catturati nel tempo rimangono marcati come **Non-Accepted**. Il DBA (o un task automatico notturno) esegue un test prestazionale (Evolution) per confrontare il nuovo piano con quello vecchio. Se il nuovo piano è più veloce, viene promosso ad **Accepted**.

---

## 3. Abilitare la Cattura Automatica delle Baselines

Il metodo più semplice per proteggere il database è abilitare la cattura automatica a livello globale.

```sql
sqlplus / as sysdba

-- Abilita la cattura automatica dei piani per le query ripetitive (eseguite almeno 2 volte)
ALTER SYSTEM SET optimizer_capture_sql_plan_baselines = TRUE SCOPE=BOTH;

-- Abilita l'uso delle baselines da parte dell'optimizer (di default è già TRUE)
ALTER SYSTEM SET optimizer_use_sql_plan_baselines = TRUE SCOPE=BOTH;
```

> **Raccomandazione in Produzione**: Non lasciare `optimizer_capture_sql_plan_baselines` sempre a `TRUE` per mesi. Cattura i piani solo durante periodi di carico stabile, poi disabilita il parametro impostandolo a `FALSE` per congelare le baselines ed evitare overhead eccessivi sul dizionario.

---

## 4. Caricamento Manuale dei Piani (Il metodo più sicuro)

Invece di catturare tutto indistintamente, puoi creare baselines mirate per query specifiche caricandole direttamente dalla **Shared SQL Area (Cursor Cache)**.

### Scenario: Stabilizzare una query lenta
Identifica il `SQL_ID` e il `PLAN_HASH_VALUE` della query stabile cercandoli in memoria:

```sql
SELECT sql_id, plan_hash_value, sql_text 
FROM   v$sql 
WHERE  sql_text LIKE '%SELECT * FROM hr.employees WHERE%';
```

### Caricare il piano stabile nella Baseline
Associa il piano d'esecuzione desiderato a una SQL Plan Baseline:

```sql
DECLARE
  v_plans_loaded PLS_INTEGER;
BEGIN
  v_plans_loaded := DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(
    sql_id          => '8jg3s7k1ap9ws', -- SQL_ID della query
    plan_hash_value => 1294857392      -- Plan Hash del piano stabile
  );
  DBMS_OUTPUT.PUT_LINE('Piani stabili caricati: ' || v_plans_loaded);
END;
/
```

---

## 5. Gestione & Monitoraggio delle Baselines

Tutte le SQL Plan Baselines registrate possono essere analizzate tramite la vista di sistema `DBA_SQL_PLAN_BASELINES`.

```sql
-- Query per controllare lo stato delle baselines
SELECT sql_handle,
       plan_name,
       enabled,
       accepted,
       reproduced,
       autopurge,
       last_executed
FROM   dba_sql_plan_baselines
WHERE  creator = 'SYS';
```

*Significato dei flag:*
*   **ENABLED**: Se impostato a `YES`, la baseline è attiva ed è presa in considerazione.
*   **ACCEPTED**: Se impostato a `YES`, l'optimizer può utilizzare questo piano.
*   **REPRODUCED**: Se impostato a `YES`, il database è in grado di ricreare fisicamente il piano (es. gli indici necessari esistono ancora).

---

## 6. Evoluzione di un Piano (Evolve SQL Plan Baseline)

Quando l'optimizer scopre un piano alternativo potenzialmente migliore, lo inserisce nella baseline della query marcandolo come **NON ACCETTATO** (`accepted = NO`). Il DBA deve validarlo.

Il package `DBMS_SPM.EVOLVE_SQL_PLAN_BASELINE` esegue un test prestazionale (dry run) confrontando i tempi del piano non accettato con quello attivo. Se il nuovo piano ha prestazioni superiori, lo promuove ad `ACCEPTED`.

```sql
DECLARE
  v_report CLOB;
BEGIN
  -- Esegue l'evoluzione per una specifica query identificata dal suo SQL_HANDLE
  v_report := DBMS_SPM.EVOLVE_SQL_PLAN_BASELINE(
    sql_handle => 'SQL_0f37k89a19ws78',
    verify     => 'YES', -- Esegui il test prestazionale prima di accettare
    commit     => 'YES'  -- Se il piano è migliore, promuovilo automaticamente
  );
  
  -- Stampa il report dettagliato del confronto
  DBMS_OUTPUT.PUT_LINE(v_report);
END;
/
```

### Come leggere il report di evoluzione
Nel report stampato vedrai l'analisi dell'I/O e della CPU:
*   Se vedi `Plan was promoted because execution time improved by 4.2x`, il nuovo piano è stato accettato con successo.
*   Se vedi `Plan was not promoted because performance did not improve`, il piano è stato scartato e l'applicazione continuerà a usare il vecchio piano stabile in modo sicuro.

---

## 7. Esportare e Importare Baselines (Migrazione da Test a Prod)

Se hai ottimizzato una query in ambiente di test (lab) creando indici o inserendo hint, puoi esportare la SQL Plan Baseline risultante e caricarla direttamente nel database di produzione per garantire stabilità immediata.

### Step 1: Creare una Staging Table in Test
```sql
BEGIN
  DBMS_SPM.CREATE_STG_TAB_BASELINE(
    table_name      => 'SPM_STAGE_TABLE',
    table_owner     => 'SYSTEM',
    tablespace_name => 'USERS'
  );
END;
/
```

### Step 2: Confezionare le Baselines nella Staging Table
```sql
DECLARE
  v_packed PLS_INTEGER;
BEGIN
  v_packed := DBMS_SPM.PACK_STG_TAB_BASELINE(
    table_name  => 'SPM_STAGE_TABLE',
    table_owner => 'SYSTEM',
    sql_handle  => 'SQL_0f37k89a19ws78' -- Esporta solo questa specifica query
  );
END;
/
```

### Step 3: Esportare la Tabella via Data Pump ed Importarla in Produzione
```bash
# In Test: esporta la tabella di staging
expdp system/<password> tables=SYSTEM.SPM_STAGE_TABLE directory=DPUMP_DIR dumpfile=spm_stage.dmp

# In Produzione: importa la tabella
impdp system/<password> tables=SYSTEM.SPM_STAGE_TABLE directory=DPUMP_DIR dumpfile=spm_stage.dmp table_exists_action=REPLACE
```

### Step 4: Sballare (Unpack) le Baselines in Produzione
```sql
-- In Produzione:
DECLARE
  v_unpacked PLS_INTEGER;
BEGIN
  v_unpacked := DBMS_SPM.UNPACK_STG_TAB_BASELINE(
    table_name  => 'SPM_STAGE_TABLE',
    table_owner => 'SYSTEM',
    sql_handle  => 'SQL_0f37k89a19ws78'
  );
  DBMS_OUTPUT.PUT_LINE('SQL Baselines importate in Produzione: ' || v_unpacked);
END;
/
```
