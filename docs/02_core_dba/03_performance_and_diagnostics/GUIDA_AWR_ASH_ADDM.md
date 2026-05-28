# GUIDA MONUMENTALE: AWR, ASH e ADDM per Performance Tuning Avanzato (19c/21c/23ai)

> [!NOTE]
> **DOCUMENTI DI PERFORMANCE CORRELATI:**
> - **SQL Tuning Advisor & STS**: [GUIDA_SQL_TUNING_SET_ADVISORS.md](./GUIDA_SQL_TUNING_SET_ADVISORS.md)
> - **SQL Plan Management**: [GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md](./GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md)
> - **Troubleshooting Wait Events**: [GUIDA_TROUBLESHOOTING_COMPLETO.md](./GUIDA_TROUBLESHOOTING_COMPLETO.md)

L'ecosistema diagnostico di Oracle (Automatic Workload Repository, Active Session History e Automatic Database Diagnostic Monitor) costituisce il "Flight Recorder" (scatola nera) del database. Padroneggiare questi tre strumenti è il requisito fondamentale per passare da DBA Operativo a **Performance Tuning Expert**. 

Questa guida fornisce l'arsenale per analizzare colli di bottiglia complessi, sia reattivamente (incidente in corso) che proattivamente (analisi di un rallentamento di ieri notte).

---

## 1. Automatic Workload Repository (AWR)

L'AWR è il repository persistente delle statistiche di sistema. Ogni ora (di default), Oracle scatta uno "Snapshot" (fotografia) di migliaia di contatori (metriche in memoria V$) e li salva su disco all'interno dello schema `SYS` (tablespace `SYSAUX`), nelle viste del dizionario `DBA_HIST_%`.

Un "AWR Report" è semplicemente un'analisi differenziale (Delta) tra due Snapshot (es. lo Snapshot delle 10:00 e quello delle 11:00). Oracle ti dice quanto tempo è stato speso e quante I/O sono state fatte *in quell'intervallo*.

### 1.1 Configurazione della Retention e dell'Intervallo
Nelle istanze di produzione critiche, l'intervallo di 60 minuti potrebbe essere troppo ampio per catturare un picco transitorio di 5 minuti ("micro-burst"). E la retention di default di 8 giorni è troppo breve per fare paragoni di fine mese (es. "Perché le chiusure contabili di questo mese sono più lente del mese scorso?").

**Modifica dei Parametri AWR (Best Practice Enterprise):**
```sql
sqlplus / as sysdba

-- Controlla le impostazioni attuali
SELECT extract(day from snap_interval) *24*60+extract(hour from snap_interval) *60+extract(minute from snap_interval) as Snapshot_Min,
       extract(day from retention) as Retention_Days
FROM dba_hist_wr_control;

-- Imposta l'intervallo a 15 o 30 minuti, e la retention a 45 giorni
BEGIN
  DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(
    retention => 45 * 24 * 60, -- 45 Giorni (in minuti)
    interval  => 30            -- Snapshot ogni 30 minuti
  );
END;
/
```
> [!WARNING]
> Aumentare la frequenza e la retention aumenterà drasticamente l'occupazione del tablespace `SYSAUX`. Monitorare costantemente con `@?/rdbms/admin/awrinfo.sql`.

### 1.2 Generazione dei Report AWR

Esistono numerosi script forniti da Oracle all'interno di `$ORACLE_HOME/rdbms/admin`:

*   `awrrpt.sql`: Report AWR standard per una singola istanza.
*   `awrrpti.sql`: Report AWR per un'istanza diversa (su RAC).
*   `awrsqrpt.sql`: AWR Report focalizzato esclusivamente su uno specifico `SQL_ID`. Fondamentale per vedere come è cambiato il piano o i costi di I/O nel tempo.
*   `awrddrpt.sql`: AWR Compare Period Report. Compara due AWR di giorni/settimane diversi (es. "Ieri vs Oggi"). Ottimo per isolare regressioni post-rilascio.
*   `awrgdrpt.sql`: Global AWR (tutti i nodi RAC sommati).

**Come estrarre un AWR in modo testuale (non interattivo) per invio mail:**
Se hai decine di database, generare AWR interattivi è lento. Usa l'API PL/SQL.
```sql
SET HEADING OFF PAGESIZE 0 TERMOUT OFF ECHO OFF
SPOOL awr_report_123_124.html
SELECT output FROM TABLE(
  DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(
    l_dbid     => 123456789, -- Ottieni da v$database
    l_inst_num => 1,         -- Istanza
    l_bid      => 123,       -- Snapshot ID inizio
    l_eid      => 124        -- Snapshot ID fine
  )
);
SPOOL OFF
```

---

## 2. Analisi Pratica di un Report AWR

Quando apri un report AWR, troverai centinaia di sezioni. Ecco la mappa per i Tuning Expert. Non leggere dall'inizio alla fine, salta alle sezioni critiche:

1.  **Top 10 Foreground Events**: È il riassunto dell'incidente. In quale Wait Class il database ha speso il maggior tempo?
    *   *User I/O (db file sequential read)*: Problemi sui dischi, indici mancanti (Full table scan nascosti).
    *   *Concurrency (library cache lock, enq: TX)*: Lock applicativi, row-level locking, problemi di parsing duro.
    *   *Network (SQL*Net message from client)*: Il DB è veloce, ma l'applicazione è lenta a processare i dati o la rete è satura. Spesso è un falso allarme o un problema architetturale.
    *   *Cluster (gc buffer busy)*: Esclusivo RAC. I blocchi viaggiano troppo spesso sull'interconnessione privata. Cattivo partizionamento o applicazioni non affini per nodo.
2.  **Load Profile**: Controlla `Logical reads (blocks)` vs `Physical reads (blocks)`. Se i logical reads esplodono all'improvviso, un piano di esecuzione è degradato.
3.  **SQL ordered by Elapsed Time / CPU Time / Gets**:
    Qui trovi il colpevole. L'SQL che ha consumato più risorse nel periodo dello snapshot. Copia il `SQL_ID` e passa all'analisi ASH o STS.

---

## 3. Active Session History (ASH)

L'AWR è "macroscopico". Ti dice che dalle 10 alle 11 c'è stato un problema di I/O, e ti elenca le top query.
Ma se l'incidente è durato solo 40 secondi, alle 10:15, l'AWR lo nasconderà in una media oraria perfetta (diluizione statistica).

**ASH (Active Session History)** risolve questo problema. Ogni 1 secondo in memoria (`V$ACTIVE_SESSION_HISTORY`), e ogni 10 secondi su disco (`DBA_HIST_ACTIVE_SESS_HISTORY`), Oracle fa un campionamento (sampling) di cosa stiano facendo ESATTAMENTE tutte le sessioni attive (non idle).

### 3.1 Estrazione del Report ASH
```sql
@?/rdbms/admin/ashrpt.sql
-- Ti chiederà data di inizio (es. -15 per iniziare 15 minuti fa) e durata in minuti.
```

### 3.2 ASH Analytics: Query PL/SQL Avanzate
I DBA Senior interrogano direttamente le viste ASH invece di usare il report precompilato.

**Scenario 1: Chi (Username/Machine) stava bloccando la CPU o facendo I/O ieri alle 14:15?**
```sql
SELECT session_state, event, module, machine, user_id, count(*) as campionamenti
FROM   dba_hist_active_sess_history
WHERE  sample_time BETWEEN TO_TIMESTAMP('2023-10-15 14:15:00', 'YYYY-MM-DD HH24:MI:SS') 
                       AND TO_TIMESTAMP('2023-10-15 14:20:00', 'YYYY-MM-DD HH24:MI:SS')
GROUP BY session_state, event, module, machine, user_id
ORDER BY campionamenti DESC;
```
*(Nota: moltiplicando `campionamenti` * 10, ottieni un'approssimazione dei secondi effettivi spesi nella wait).*

**Scenario 2: Analisi dei Lock a Livello di Riga (Blocking Tree)**
Quale sessione ha scatenato la reazione a catena (Deadlock o Blocking Lock)?
ASH traccia sia il SID bloccato, sia il `BLOCKING_SESSION`.
```sql
SELECT sample_time, session_id, blocking_session, event, sql_id, current_obj#
FROM   v$active_session_history
WHERE  event = 'enq: TX - row lock contention'
ORDER BY sample_time DESC;
```
L'`obj#` ti permette di fare la join con `DBA_OBJECTS` per capire esattamente su quale tabella e blocco è avvenuto lo stallo.

---

## 4. Automatic Database Diagnostic Monitor (ADDM)

ADDM è l'Intelligenza Artificiale integrata (Rule Engine) di Oracle. Mentre un DBA "umano" apre un AWR report e cerca di dedurre i problemi analizzando i numeri, l'ADDM analizza automaticamente i due snapshot AWR appena generati e produce un report diagnostico in lingua naturale, con tanto di "Impact %" e "Recommendations" (soluzioni proposte).

ADDM è eccezionale per due motivi:
1.  **Approccio Top-Down (DB Time)**: Ignora i falsi positivi (es. processi in attesa della rete senza impatto sul business). Analizza solo i colli di bottiglia che consumano gran parte del DB Time.
2.  **Sintesi**: In pochi secondi ti dà un quadro chiaro e un albero diagnostico.

### 4.1 Generazione ed Esecuzione ADDM
L'ADDM gira automaticamente in background dopo ogni snapshot AWR, popolando viste come `DBA_ADVISOR_FINDINGS`.
Puoi generare il report testo per un intervallo a tuo piacimento:

```sql
@?/rdbms/admin/addmrpt.sql
-- Ti chiederà i due Snapshot ID di inizio e fine.
```

### 4.2 ADDM Findings e Recommendation Types
Il report generato ti fornirà raccomandazioni categorizzate in:
*   **Hardware Changes**: Es. "La CPU è satura al 99%, aumentare le risorse o spostare i batch".
*   **Database Configuration**: Es. "La Shared Pool è troppo piccola (Shared Pool Thrashing). Aumenta SGA_TARGET".
*   **Schema Design**: Es. "Aggiungere l'indice X alla tabella Y per ridurre il buffer get della query Z". (Questa recommendation richiama indirettamente il SQL Tuning Advisor).
*   **Application Design**: Es. "Trovati 1500 SQL ID identici ma senza bind variables. Problema di Hard Parsing. Cambiare l'applicazione o impostare CURSOR_SHARING=FORCE".

### 4.3 ADDM su Eventi Puntuali e RAC
In un ambiente RAC, l'AWR normale (singolo nodo) e l'ADDM normale ignorano le dinamiche globali. Oracle espone:
*   `@?/rdbms/admin/addmrpti.sql`: ADDM Report mirato su un nodo specifico (Instance-level).
*   **ADDM in Real-Time (Solo via Enterprise Manager)**: Una funzionalità esclusiva che permette ad ADDM di analizzare un'istanza freezata (hung system) collegandosi in Diagnostic Mode (senza impattare la SGA principale), estraendo dati dalla PGA e da un piccolo dump file OS, fondamentale per risolvere blocchi totali ("L'istanza non risponde a SQL*Plus").
