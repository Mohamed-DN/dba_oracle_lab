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
