# GUIDA COMPLETA: SQL Plan Management (SPM) ÔÇö Stabilit├á & Controllo dei Piani d'Esecuzione

> [!NOTE]
> **DOCUMENTI DI PERFORMANCE CORRELATI (SCEGLI QUELLO PI├Ö ADATTO):**
> - **SQL Plan Management & Baselines (questa guida)**: [GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md](./GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md) (SPM, stabilizzazione dei piani di query, baselines, prevenzione regressioni).
> - **SQL Tuning Set & Advisors**: [GUIDA_SQL_TUNING_SET_ADVISORS.md](./GUIDA_SQL_TUNING_SET_ADVISORS.md) (DBMS_SQLTUNE, SQL Tuning Advisor, SQL Profiles, Access Advisor).
> - **AWR, ASH & ADDM**: [GUIDA_AWR_ASH_ADDM.md](./GUIDA_AWR_ASH_ADDM.md) (diagnostica delle prestazioni del carico di lavoro e statistica).
> - **Troubleshooting Completo**: [GUIDA_TROUBLESHOOTING_COMPLETO.md](./GUIDA_TROUBLESHOOTING_COMPLETO.md) (metodo di analisi strutturata e wait events).

---

## 1. Perch├® serve SQL Plan Management (SPM)?

Nelle basi dati di livello Enterprise, un cambio repentino del piano d'esecuzione di una query critica per il business rappresenta uno dei rischi pi├╣ elevati per la continuit├á operativa. Durante le manutenzioni ordinarie (raccolta statistiche di sistema, aggiornamenti parametri di inizializzazione, ricompilazione indici, migrazioni di versione, installazione di RU Patch trimestrali), l'**Optimizer** di Oracle pu├▓ stimare che un nuovo percorso di accesso ai dati sia ottimale, quando in realt├á causa regressioni disastrose.

**SQL Plan Management (SPM)** ├¿ un meccanismo integrato nel kernel di Oracle che **garantisce la stabilit├á delle prestazioni del database**. Impedisce all'optimizer di utilizzare un nuovo piano d'esecuzione non testato prima che il DBA (o un meccanismo automatico) lo abbia esaminato ed **accettato** verificando che non provochi regressioni.

```
                    [ RICHIESTA ESECUZIONE QUERY SQL ]
                                    Ôöé
                                    Ôû╝
                     L'Optimizer genera un NUOVO PIANO
                                    Ôöé
                                    Ôû╝
                 Esiste una SQL Plan Baseline per la query?
                                    Ôöé
                    ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔö┤ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ
                    Ôû╝ (SI)                          Ôû╝ (NO)
         Cerca i piani ACCETTATI              Esegui il piano
            nella Baseline                    generato normalmente
                    Ôöé
       ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔö┤ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ
       Ôû╝                         Ôû╝
Il nuovo piano ├¿      Il nuovo piano NON ├¿
   accettato?                accettato
       Ôöé                         Ôöé
       Ôû╝                         Ôû╝
Usa il nuovo piano!    Usa il vecchio piano stabile!
                       Salva il nuovo piano come
                       NON ACCETTATO per l'evoluzione.
```

---

## 2. Architettura & Ciclo di Vita delle Baselines

Il funzionamento di SPM si basa sulla persistenza all'interno del dizionario dati (tablespace `SYSAUX`) dei piani d'esecuzione validi per una query, identificata tramite una firma digitale unica (**SQL Signature**).

### Il Ciclo di Vita in 3 Fasi:

1.  **Cattura (Capture)**: Registrazione della firma della query SQL e memorizzazione del suo piano d'esecuzione corrente come baseline iniziale.
2.  **Selezione (Selection)**: Ad ogni riesecuzione della query, l'optimizer ├¿ obbligato a selezionare esclusivamente i piani all'interno della baseline che sono marcati come **Accepted**.
3.  **Evoluzione (Evolve)**: I nuovi piani alternativi calcolati dall'optimizer nel tempo vengono registrati all'interno della baseline ma marcati come **Non-Accepted** (`ACCEPTED = NO`). Il DBA esegue un test prestazionale dry-run (Evoluzione) per misurare l'I/O ed il tempo CPU del nuovo piano rispetto a quello vecchio. Se le prestazioni migliorano, il nuovo piano viene promosso ad **Accepted**.

---

## 3. Configurazione Parametriche e Strategie di Cattura

Il comportamento di SPM ├¿ controllato principalmente da due parametri di inizializzazione del database:

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
| **Conservazione e Uso** | `FALSE` | `TRUE` | **Standard di Produzione**: Congela le baselines esistenti ed utilizza solo i piani precedentemente validati ed accettati. I nuovi piani non vengono pi├╣ catturati automaticamente. |

```sql
-- Configurazione Standard di Produzione (Congelamento ed Uso)
ALTER SYSTEM SET optimizer_capture_sql_plan_baselines = FALSE SCOPE=BOTH SID='*';
ALTER SYSTEM SET optimizer_use_sql_plan_baselines = TRUE SCOPE=BOTH SID='*';
```

---

## 4. Workflow Avanzato: Caricamento Manuale delle Baselines

La strategia pi├╣ sicura per stabilizzare query specifiche consiste nel caricare i piani desiderati manualmente dalla **Shared SQL Area (Cursor Cache)** o da un **SQL Tuning Set (STS)**.

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

I nuovi piani proposti dall'optimizer rimangono nello stato di `accepted = NO` finch├® non vengono evoluti. 

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
    commit     => 'YES'  -- Se il nuovo piano ├¿ prestazionalmente migliore del 1.5x, promuovilo ad ACCEPTED
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

## 6. Procedura di Esportazione e Importazione (TEST Ô×ö PRODUZIONE)

Se hai testato e stabilizzato le prestazioni delle query in un ambiente di laboratorio (UAT/TEST) ricreando baselines perfette, puoi esportarle e caricarle in Produzione per garantire la stabilit├á immediata prima del Go-Live.

```
 ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ                     ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ
 Ôöé DATABASE DI SORGENTE Ôöé                     Ôöé DATABASE DI TARGET   Ôöé
 Ôöé        (TEST)        Ôöé                     Ôöé     (PRODUZIONE)     Ôöé
 Ôö£ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöñ                     Ôö£ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöñ
 Ôöé SPM Baseline attiva  Ôöé                     Ôöé                      Ôöé
 Ôöé          Ôöé           Ôöé                     Ôöé          Ôû▓           Ôöé
 Ôöé  (PACK nel DB)       Ôöé                     Ôöé  (UNPACK nel DB)     Ôöé
 Ôöé          Ôû╝           Ôöé                     Ôöé          Ôöé           Ôöé
 Ôöé   [ STAGING TABLE ]  ÔöéÔöÇÔöÇÔû║ Export/Import ÔöÇÔöÇÔû║Ôöé   [ STAGING TABLE ]  Ôöé
 ÔööÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÿ      Data Pump      ÔööÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÿ
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

### 7.1 Perch├® l'optimizer non riproduce la Baseline? (`reproduced = NO`)
Se noti che la query continua ad usare un piano d'esecuzione pessimo ignorando la baseline attiva:
1.  **Indice Eliminato**: Il piano salvato nella baseline faceva affidamento su un indice che ├¿ stato accidentalmente eliminato dal database (`DROP INDEX`). In questo caso, il flag `reproduced` passa a `NO`. Il DBA deve ricreare l'indice mancante.
2.  **Cambiamento delle Partizioni**: La struttura fisica della tabella partizionata ├¿ cambiata radicalmente.
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


================================================================================

# [SEZIONE AGGIUNTIVA] APPROFONDIMENTO MONUMENTALE


## [ARCHITETTURA VISIVA] Optimizer e SPM
```text

[ Nuova Query ] ---> (Hard Parse) ---> [ Miglior Piano Teorico ]
                                               |
                                               v
                          Esiste una Baseline ACCEPTED in SPM?
                                  /                                                 SI                   NO
                               /                            Piano calcolato e' tra quelli ACCEPTED?     Salva il piano e usalo
               /                \                 (Diventa 1a Baseline)
             SI                  NO
            /                         Usa il piano calcolato    Salva come UNACCEPTED
                             Usa miglior piano ACCEPTED
```

# GUIDA MONUMENTALE: SQL Plan Management (SPM) & Baselines in Oracle (19c/21c/23ai)

> [!NOTE]
> **DOCUMENTI DI PERFORMANCE CORRELATI:**
> - **AWR, ASH e ADDM**: [GUIDA_AWR_ASH_ADDM.md](./GUIDA_AWR_ASH_ADDM.md)
> - **SQL Tuning Advisor & SQL Tuning Sets**: [GUIDA_SQL_TUNING_SET_ADVISORS.md](./GUIDA_SQL_TUNING_SET_ADVISORS.md)
> - **Troubleshooting Generale**: [GUIDA_TROUBLESHOOTING_COMPLETO.md](./GUIDA_TROUBLESHOOTING_COMPLETO.md)

In ambienti di produzione mission-critical, un improvviso degrado delle performance è spesso causato da un "Plan Regression": l'Optimizer di Oracle decide di cambiare il piano di esecuzione di una query (magari dopo la raccolta delle statistiche, o dopo un upgrade di versione), passando da un piano ottimale a uno disastroso (es. da Index Scan a Full Table Scan su tabelle da miliardi di righe).

**SQL Plan Management (SPM)** è la funzionalità Enterprise progettata per garantire la stabilità delle performance. Permette di:
1.  Memorizzare i piani "noti e buoni" all'interno di un repository (SQL Management Base - SMB).
2.  Costringere l'Optimizer a utilizzare solo i piani approvati (Accepted Baselines).
3.  Catturare nuovi piani in background, valutarne le performance e promuoverli automaticamente se sono più veloci dei vecchi.

---

## 1. Architettura di SQL Plan Management

Il repository di SPM risiede nel tablespace `SYSAUX`. È composto da due elementi chiave:
*   **Statement Log**: Traccia le firme (SQL Signatures) delle query eseguite più di una volta.
*   **Plan History**: Salva i piani di esecuzione per le query catturate.

Ogni piano di esecuzione all'interno della Plan History può avere i seguenti stati (`DBA_SQL_PLAN_BASELINES`):
*   **ENABLED (YES/NO)**: Il piano è attivo e considerabile dall'optimizer.
*   **ACCEPTED (YES/NO)**: Il piano è stato verificato ed approvato. L'optimizer lo userà. Se un piano è `ENABLED=YES` ma `ACCEPTED=NO`, è un piano appena scoperto (unverified) che non verrà usato finché non sarà evoluto.
*   **FIXED (YES/NO)**: Priorità massima. Se un piano è Fixed, l'optimizer preferirà SEMPRE questo piano, anche se esistono altri piani Accepted con un costo teorico inferiore.

### Flusso Logico dell'Optimizer con SPM
1.  Arriva una Query. Viene generata l'hash signature.
2.  L'Optimizer esegue l'Hard Parse e calcola il "Miglior Piano Teorico" secondo le statistiche attuali.
3.  L'Optimizer cerca nella SQL Management Base se esistono Baseline per questa query.
4.  **Se Esistono Piani ACCEPTED**: L'Optimizer confronta il piano appena calcolato con quelli accepted.
    *   Se il piano calcolato *è tra* quelli Accepted, lo usa.
    *   Se il piano calcolato *NON è tra* quelli Accepted, l'Optimizer usa il piano Accepted con il costo più basso. Il nuovo piano calcolato viene inserito nella Baseline come `ACCEPTED=NO` (in attesa di evoluzione/verifica).
5.  **Se Esistono Piani FIXED**: Usa solo i piani Fixed. Ignora eventuali altri piani Accepted, a meno che i piani Fixed non siano falliti (es. indici droppati).

---

## 2. Metodi di Cattura delle Baseline

Esistono tre metodi per popolare la SQL Management Base.

### Metodo 1: Cattura Automatica a Livello di Sistema (Automatic Capture)
Impostando `OPTIMIZER_CAPTURE_SQL_PLAN_BASELINES = TRUE`, Oracle traccia tutte le query ripetibili. Il primo piano visto diventa `ACCEPTED=YES`. I successivi diventano `ACCEPTED=NO`.
> [!WARNING]
> In ambienti OLTP con SQL non bindati (literal values), attivare la cattura automatica a livello globale può far esplodere lo spazio `SYSAUX` ed intasare l'infrastruttura. Usalo solo in concomitanza con `CURSOR_SHARING=FORCE` o in finestre di tempo limitate.

```sql
-- Attivazione Globale
ALTER SYSTEM SET OPTIMIZER_CAPTURE_SQL_PLAN_BASELINES = TRUE SCOPE=BOTH;

-- Disattivazione
ALTER SYSTEM SET OPTIMIZER_CAPTURE_SQL_PLAN_BASELINES = FALSE SCOPE=BOTH;
```

### Metodo 2: Cattura Manuale dalla Shared Pool (Cursor Cache)
Il metodo più sicuro ed utilizzato dai DBA. Quando una query è in esecuzione con un piano buono, la "congeliamo" estraendola dalla memoria.

**Esempio: La query con `sql_id = '7v4km0b9m083y'` sta andando bene, blocchiamo il suo piano.**

```sql
sqlplus / as sysdba
DECLARE
  l_plans_loaded PLS_INTEGER;
BEGIN
  l_plans_loaded := DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(
    sql_id => '7v4km0b9m083y',
    plan_hash_value => 3811195655 -- Opzionale: specifica l'hash del piano buono
  );
  DBMS_OUTPUT.PUT_LINE('Piani caricati: ' || l_plans_loaded);
END;
/
```
Questo crea automaticamente una baseline `ENABLED=YES`, `ACCEPTED=YES`.

### Metodo 3: Cattura da un SQL Tuning Set (STS) o AWR
Utile durante le migrazioni. Estrai i piani buoni dal DB di produzione 12c in un STS, lo esporti, lo importi nel DB 19c e crei le baselines dal STS.

```sql
DECLARE
  l_plans_loaded PLS_INTEGER;
BEGIN
  l_plans_loaded := DBMS_SPM.LOAD_PLANS_FROM_SQLSET(
    sqlset_name => 'MY_GOOD_PLANS_STS',
    sqlset_owner => 'DBA_USER'
  );
END;
/
```

---

## 3. Gestione ed Evoluzione delle Baseline

### 3.1 Identificare le Baselines
Come troviamo le baselines associate a una specifica query?

```sql
SELECT sql_handle, plan_name, enabled, accepted, fixed, origin, optimizer_cost
FROM   dba_sql_plan_baselines
WHERE  sql_text LIKE '%SELECT * FROM EMPLOYEES WHERE%';
```
*`sql_handle`* è l'ID logico della query all'interno di SPM (es. `SQL_3f92b7c1a2d3e4f5`).
*`plan_name`* è l'ID univoco di uno specifico piano esecutivo.

### 3.2 Modificare lo Stato di un Piano (FIX / DISABLE / DROP)

**Forzare (Fix) un piano in modo definitivo:**
Se l'applicazione non cambierà e vuoi che Oracle smetta di cercare piani migliori per questa query:
```sql
DECLARE
  l_changed PLS_INTEGER;
BEGIN
  l_changed := DBMS_SPM.ALTER_SQL_PLAN_BASELINE(
    sql_handle      => 'SQL_3f92b7c1a2d3e4f5',
    plan_name       => 'SQL_PLAN_3z4p7w1b2d3e4f5g',
    attribute_name  => 'FIXED',
    attribute_value => 'YES'
  );
END;
/
```

**Disabilitare temporaneamente un piano problematico:**
```sql
BEGIN
  l_changed := DBMS_SPM.ALTER_SQL_PLAN_BASELINE(
    sql_handle      => 'SQL_3f92b7c1a2d3e4f5',
    plan_name       => 'SQL_PLAN_BAD123',
    attribute_name  => 'ENABLED',
    attribute_value => 'NO'
  );
END;
/
```

**Rimuovere fisicamente la Baseline:**
```sql
DECLARE
  l_dropped PLS_INTEGER;
BEGIN
  l_dropped := DBMS_SPM.DROP_SQL_PLAN_BASELINE(
    sql_handle => 'SQL_3f92b7c1a2d3e4f5',
    plan_name  => NULL -- Se NULL, droppa TUTTI i piani per questa query
  );
END;
/
```

### 3.3 Evoluzione Manuale (Plan Evolution)
Se l'Optimizer scopre un nuovo piano che ha un costo inferiore, lo inserirà come `ACCEPTED=NO`. L'AWR o un DBA deve "evolverlo" (verificarlo empiricamente).

L'evoluzione esegue testualmente la query con il vecchio piano e con il nuovo piano, ne confronta i tempi CPU/Elapsed, e se il nuovo è davvero migliore, lo marca come `ACCEPTED=YES`.

```sql
-- 1. Avvia l'evoluzione del piano non accettato
SET LONG 100000
DECLARE
  l_report CLOB;
BEGIN
  l_report := DBMS_SPM.EVOLVE_SQL_PLAN_BASELINE(
    sql_handle => 'SQL_3f92b7c1a2d3e4f5',
    plan_name  => 'SQL_PLAN_UNVERIFIED_999',
    verify     => 'YES', -- Esegui realmente le query per testare i tempi
    commit     => 'YES'  -- Se il test è positivo, imposta ACCEPTED=YES in automatico
  );
  DBMS_OUTPUT.PUT_LINE(l_report);
END;
/
```
L'output di `EVOLVE_SQL_PLAN_BASELINE` è un report in testo chiaro (HTML/TEXT) che documenta il miglioramento prestazionale.

---

## 4. SPM e il Problema dei Bind Variables (Adaptive Cursor Sharing)

Una delle sfide più ardue per SPM è la coesistenza con l'**Adaptive Cursor Sharing (ACS)**.
Se l'applicazione fa largo uso di Bind Variables, e i dati sono asimmetrici (data skew), la stessa query con valori di bind diversi potrebbe necessitare di piani completamente opposti:
*   `status = 'ACTIVE'` (99% dei dati) -> Full Table Scan.
*   `status = 'PENDING'` (1% dei dati) -> Index Range Scan.

**Come si comporta SPM in questo caso?**
SPM *supporta* piani esecutivi multipli. Se un SQL Statement ha più di un piano con `ACCEPTED=YES`, l'Optimizer sceglierà tra di essi in base all'estimazione dei costi per il bind variable corrente (eseguendo il peek).
*L'errore fatale del DBA* è usare l'attributo `FIXED=YES` su query soggette a data skew. Se forzi (FIX) l'Index Scan, quando arriverà la query con status ACTIVE richiederà mesi per finire.

> [!TIP]
> Su tabelle asimmetriche, lascia che SPM mantenga 2 o 3 piani `ACCEPTED=YES` (senza flag FIXED) e permetti ad ACS di switchare tra i cursori in autonomia, ma protetto dalla "gabbia" dei piani certificati da SPM.

---

## 5. Migrazione e Trasporto delle Baselines tra Database

Per garantire il "Performance Assurance" durante un upgrade di versione (es. da 12c a 19c) o una migrazione su Exadata (o OCI), il flusso obbligatorio è:

1.  **Su DB Origine (12c)**: Cattura i workload critici in un SQL Tuning Set.
2.  **Su DB Origine (12c)**: Usa `DBMS_SPM.PACK_STGTAB_BASELINE` per pacchettizzare le baselines in una tabella di staging regolare (es. `STG_SPM_TAB`).
3.  **Data Pump**: Esporta la tabella `STG_SPM_TAB` e importala nel DB Destinazione.
4.  **Su DB Destinazione (19c)**: Usa `DBMS_SPM.UNPACK_STGTAB_BASELINE` per installare le baselines nel nuovo dizionario `SYSAUX`.

### Esempio Pratico di Trasporto
**Sorgente (Prod):**
```sql
-- Crea tabella di staging
EXEC DBMS_SPM.CREATE_STGTAB_BASELINE(table_name => 'SPM_STG_TAB', table_owner => 'DBA_USER');

-- Impacchetta tutte le baselines ACCEPTED
DECLARE
  l_cnt NUMBER;
BEGIN
  l_cnt := DBMS_SPM.PACK_STGTAB_BASELINE(
    table_name => 'SPM_STG_TAB',
    table_owner => 'DBA_USER',
    accepted => 'YES'
  );
END;
/
```
*(Esegui Export/Import Data Pump della tabella `DBA_USER.SPM_STG_TAB` sul nuovo ambiente)*

**Destinazione (Nuovo DB):**
```sql
-- Spacchetta e installa le baselines
DECLARE
  l_cnt NUMBER;
BEGIN
  l_cnt := DBMS_SPM.UNPACK_STGTAB_BASELINE(
    table_name => 'SPM_STG_TAB',
    table_owner => 'DBA_USER'
  );
END;
/
```

In questo modo, al primo avvio su 19c, l'Optimizer userà gli stessi esatti piani di accesso (es. Hash Join) della 12c, azzerando il rischio di regressioni dovute ai cambiamenti del kernel dell'optimizer. Successivamente, in background, l'Evolve Task valuterà se i nuovi feature della 19c offrono piani ancora migliori.
