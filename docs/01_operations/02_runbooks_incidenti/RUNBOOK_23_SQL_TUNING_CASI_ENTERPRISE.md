# Runbook Enterprise: SQL Tuning Oracle 19c - Casi, Diagnostica e Spiegazioni

<!-- RUNBOOK_NAV_START -->
## Indice operativo rapido

### Playbook principali
- [Triage SQL e baseline](#sql-p01---triage-sql-e-baseline)
- [Regressione del piano](#sql-p02---regressione-del-piano)
- [CPU o IO elevati](#sql-p03---cpu-o-io-elevati)
- [Bind e cardinalita](#sql-p04---bind-e-cardinalita)
- [Statistiche optimizer](#sql-p05---statistiche-optimizer)
- [TEMP e PGA](#sql-p06---temp-e-pga)
- [Lock e concorrenza](#sql-p07---lock-e-concorrenza)
- [RAC gc waits](#sql-p08---rac-gc-waits)
- [DB link lento](#sql-p09---db-link-lento)
- [Fix reversibili](#sql-p10---fix-reversibili-e-validazione)

### Come usare il documento
Parti dal sintomo business, identifica `SQL_ID`, confronta baseline e piano reale,
poi scegli il playbook. La matrice finale instrada i casi secondari senza
replicare lo stesso paragrafo decine di volte.
<!-- RUNBOOK_NAV_END -->

<!-- READY_SCRIPTS_START -->
## Script pronti collegati

Usali per raccogliere evidenze rapide dopo aver letto lo scenario del runbook.

- [07_performance_quick.sql](../03_scripts_pronti/07_performance_quick.sql) - top SQL, wait event, ASH real-time, piani SQL.
- [14_optimizer_stats.sql](../03_scripts_pronti/14_optimizer_stats.sql) - stale stats, gather database/table mirato.
- [10_oggetti_schema.sql](../03_scripts_pronti/10_oggetti_schema.sql) - invalidi, segmenti grandi, indici, recyclebin, oggetti schema.
- [02_undo_temp.sql](../03_scripts_pronti/02_undo_temp.sql) - diagnosi ORA-01555, ORA-30036, ORA-01652, consumo TEMP/UNDO.
<!-- READY_SCRIPTS_END -->
> Documento operativo per DBA Oracle 19c in ambienti critici. Copre diagnostica SQL, optimizer, statistiche, piani di esecuzione, AWR/ASH, SQL Monitor, indici, join, partizionamento, parallelismo, wait events, RAC, Exadata, SQL Plan Management e tuning sicuro in produzione.

---

## Obiettivi

- Diagnosticare SQL lenti con evidenze misurabili.
- Separare sintomo, causa e workaround reversibile.
- Chiudere ogni intervento con confronto before/after e rollback.

## Procedura operativa

Apri il playbook coerente con il sintomo, usa il toolbox D01-D10 e applica una
sola modifica misurabile per volta. In produzione privilegia mitigazioni
reversibili prima dei cambi strutturali.

## Validazione finale

Conserva SQL_ID, piano reale, statistiche, wait event, tempi, buffer gets,
physical reads, righe elaborate e risultato dello smoke test applicativo.

## Troubleshooting rapido

Se non hai una baseline, raccogli prima il comportamento attuale. Non creare un
indice o cambiare parametri globali soltanto perche' una query e' lenta.

## Come usare questo documento

- Se hai un SQL_ID: parti da SQL Monitor, DBMS_XPLAN e AWR SQL report.
- Se hai solo un sintomo applicativo: parti da ASH/AWR e wait events.
- Se il piano e' cambiato: confronta plan hash, statistiche e bind.
- Se l'incidente e' SEV1: usa workaround reversibili come SPM, SQL Patch o hint controllati prima di cambiare schema.
- Se devi spiegare il tuning: usa le sezioni didattiche prima dei casi.

---

## Spiegazione didattica: cosa significa fare SQL tuning

SQL tuning non significa "creare un indice". Significa ridurre il costo reale di una query mantenendo correttezza funzionale, stabilita del piano, sicurezza operativa e prevedibilita dopo change, deploy, upgrade o refresh statistiche.

```text
Sintomo -> SQL_ID -> piano reale -> cardinalita -> wait/eventi -> causa -> fix controllato -> validazione -> rollback plan
```

---

## Concetti fondamentali da saper spiegare

| Concetto | Spiegazione semplice |
|---|---|
| SQL_ID | identificatore del testo SQL normalizzato |
| PLAN_HASH_VALUE | fingerprint del piano, utile per vedere cambi piano |
| Optimizer | componente che sceglie il piano in base a statistiche e costo |
| Cardinality | stima righe prodotte da ogni step |
| E-Rows vs A-Rows | stima optimizer vs righe reali nel piano eseguito |
| Selectivity | quanto un predicato filtra i dati |
| Access path | full scan, index scan, partition scan, smart scan |
| Join method | nested loop, hash join, merge join |
| Join order | ordine in cui Oracle combina le tabelle |
| Predicate pushdown | spingere filtri il piu vicino possibile ai dati |
| Bind peeking | optimizer guarda il primo valore bind per stimare il piano |
| Adaptive cursor sharing | piu child cursor per bind con selettivita diversa |
| SQL Profile | correzione statistiche/cardinalita prodotta da SQL Tuning Advisor |
| SQL Plan Baseline | vincolo controllato sui piani accettati |
| SQL Patch | patch mirata con hint senza modificare codice applicativo |
| AWR | storico performance aggregato |
| ASH | campionamento sessioni attive, utile per picchi |
| SQL Monitor | osservabilita dettagliata di SQL long-running o parallel |

---

## Matrice decisionale rapida

| Sintomo | Prima diagnosi | Fix tipico |
|---|---|---|
| CPU alta | SQL ordered by CPU / ASH | piano migliore, indici, rewrite SQL |
| I/O alto | SQL ordered by Reads | pruning, indice, segment design, Exadata offload |
| Query lenta intermittente | ASH + bind + plan hash | bind-aware, baseline, stats |
| Piano cambiato | DBMS_XPLAN + AWR history | SPM baseline, stats rollback, profile |
| TEMP piena | SQL Monitor + workarea | hash/sort tuning, PGA, rewrite |
| Hard parse alto | AWR parse stats | bind variables, cursor sharing, shared pool review |
| RAC gc waits | ASH per instance | service placement, hot block, plan access path |
| DB link lento | SQL Monitor + remote plan | DRIVING_SITE, fetch array, pushdown |
| DML massivo lento | SQL Monitor + locks + redo | batch, parallel DML, index strategy |

---

## Workflow standard production-grade

```sql
-- 1. Identifica SQL e piano reale
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s,
       cpu_time/1e6 cpu_s, buffer_gets, disk_reads, rows_processed
FROM   v$sql
WHERE  sql_text LIKE '%<pezzo_sql>%'
ORDER  BY elapsed_time DESC;

-- 2. Piano reale con righe effettive, se presente in cursor cache
SELECT *
FROM   table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- 3. SQL Monitor per long-running
SELECT dbms_sqltune.report_sql_monitor(sql_id => '<SQL_ID>', type => 'TEXT', report_level => 'ALL')
FROM dual;

-- 4. Storico AWR piano/prestazioni
SELECT *
FROM   table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

---

## Regole bancarie per tuning in produzione

- Non creare indici in produzione senza stima DML/storage/redo/backup.
- Non cambiare parametri optimizer globali per correggere un singolo SQL.
- Non usare hint permanenti senza owner applicativo e test regressione.
- Preferire fix reversibili in emergenza: SQL Patch, SQL Plan Baseline, profilo controllato.
- Salvare sempre before/after: piano, AWR/ASH, SQL Monitor, tempi, buffer gets, rows.
- Ogni tuning deve avere rollback plan.

---

## Fonti Oracle principali

- SQL Tuning Guide 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/
- Performance Tuning Guide 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/
- DBMS_XPLAN: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_XPLAN.html
- DBMS_SQLTUNE: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_SQLTUNE.html
- DBMS_SPM: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_SPM.html
- DBMS_STATS: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_STATS.html
- SQL Plan Management: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/managing-sql-plan-baselines.html
- Optimizer Statistics: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/optimizer-statistics-concepts.html
- SQL Monitoring: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/monitoring-database-operations.html

---

## Comandi man utili

```bash
man sqlplus
man awk
man grep
man sort
man uniq
man top
man vmstat
man iostat
man sar
man perf
```

---

## Blocco comune per tutti gli scenari SQL

Questa sezione sostituisce i blocchi ripetuti dentro ogni caso. I singoli scenari sotto devono essere letti come una mappa rapida: titolo del problema, diagnostica mirata e scelta del fix usando le regole comuni qui sotto.

### Come spiegare un problema SQL
- Parti dal sintomo business: timeout, batch lento, CPU alta, TEMP piena, report non completato.
- Identifica il `SQL_ID` e separa sempre tempo totale, CPU, I/O, TEMP, wait event, righe processate e numero esecuzioni.
- Confronta piano attuale, piano storico e cardinalita stimata vs reale; non fidarti solo del costo optimizer.
- Prima stabilizzi il servizio con un fix reversibile, poi fai tuning strutturale con test e change.

### Sintomi comuni
- AWR mostra il SQL tra i top per elapsed, CPU, buffer gets, physical reads o parse time.
- ASH mostra un wait prevalente coerente con il problema: CPU, I/O, row lock, gc waits, direct path, temp.
- Il `PLAN_HASH_VALUE` e cambiato rispetto al periodo sano.
- SQL Monitor mostra uno step con A-Rows molto diverso da E-Rows.
- Il problema e legato a bind specifici, statistiche appena raccolte, deploy, patch o refresh dati.

### Decisione operativa comune
- Piano cambiato: valuta SQL Plan Baseline o SQL Patch come workaround reversibile.
- Statistiche errate: correggi con `DBMS_STATS` mirato, preferendo `AUTO_SAMPLE_SIZE` e `AUTO_INVALIDATE`.
- Access path errato: testa indice invisibile, extended statistics, rewrite SQL o partizionamento.
- Cardinalita errata persistente: valuta SQL Profile da SQL Tuning Advisor.
- Concorrenza o lock: non risolvere con indice; risolvi sessioni, transazioni o design applicativo.

### Toolbox fix
- `DBMS_STATS`: statistiche tabella, partizione, indice, istogrammi, extended stats.
- Indice invisibile: test controllato senza impatto immediato su tutto il workload.
- SQL Plan Baseline: stabilizza un piano noto buono senza cambiare SQL applicativo.
- SQL Profile: corregge stime/cardinalita quando il piano dipende da stime sbagliate.
- SQL Patch: workaround temporaneo con hint quando non puoi modificare codice.
- Rewrite SQL: soluzione migliore quando il problema e logico, non solo optimizer.

### Validazione before/after unica
```sql
SELECT *
FROM   table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

SELECT sql_id, plan_hash_value, executions,
       elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s,
       buffer_gets, disk_reads, rows_processed
FROM   v$sql
WHERE  sql_id = '<SQL_ID>';
```

### Criterio PASS unico
- Elapsed time o tempo batch tornato sotto SLA.
- Buffer gets, physical reads, TEMP e CPU coerenti con il nuovo piano.
- Piano stabile sui bind rappresentativi, non solo sul bind usato nel test.
- Nessuna regressione su SQL correlati o workload DML.
- Rollback plan documentato: drop indice, disable baseline, drop SQL patch/profile o restore stats.

### Rischi enterprise comuni
- Un indice accelera alcune SELECT ma puo rallentare DML, aumentare redo, backup e storage.
- Un hint puo salvare oggi e diventare dannoso dopo crescita dati o patch optimizer.
- Parametri optimizer globali per un singolo SQL sono quasi sempre una cattiva pratica.
- PREPROD puo mentire se statistiche, bind, volumi o concorrenza non rappresentano produzione.

### Libreria diagnostica comune

#### D01 - Top SQL AWR

```sql
-- Top SQL da AWR per elapsed time
SELECT * FROM (
  SELECT s.sql_id, s.plan_hash_value,
         SUM(s.elapsed_time_delta)/1e6 elapsed_s,
         SUM(s.cpu_time_delta)/1e6 cpu_s,
         SUM(s.buffer_gets_delta) buffer_gets,
         SUM(s.disk_reads_delta) disk_reads,
         SUM(s.executions_delta) execs
  FROM   dba_hist_sqlstat s
  JOIN   dba_hist_snapshot sn ON sn.snap_id=s.snap_id AND sn.instance_number=s.instance_number
  WHERE  sn.begin_interval_time > SYSDATE-1
  GROUP  BY s.sql_id, s.plan_hash_value
  ORDER  BY elapsed_s DESC
) WHERE ROWNUM <= 20;
```

#### D02 - Piano reale e storico

```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

#### D03 - ASH e wait event

```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

#### D04 - Diagnostica minima SQL_ID

```sql
-- Diagnostica minima SQL tuning
SELECT sql_id, plan_hash_value, executions,
       elapsed_time/1e6 elapsed_s,
       cpu_time/1e6 cpu_s,
       buffer_gets, disk_reads, rows_processed
FROM   v$sql
WHERE  sql_id = '<SQL_ID>';

SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
```

#### D05 - Statistiche optimizer

```sql
-- Stato statistiche
SELECT owner, table_name, stale_stats, last_analyzed, num_rows
FROM   dba_tab_statistics
WHERE  owner='APP'
ORDER  BY stale_stats DESC, last_analyzed;

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'APP', tabname => 'ORDERS',
    method_opt => 'FOR ALL COLUMNS SIZE AUTO',
    cascade => TRUE, no_invalidate => DBMS_STATS.AUTO_INVALIDATE);
END;
/
```

#### D06 - Indici e colonne

```sql
-- Indici e colonne
SELECT index_name, uniqueness, status, visibility
FROM   dba_indexes
WHERE  owner='APP' AND table_name='ORDERS';

SELECT index_name, column_name, column_position
FROM   dba_ind_columns
WHERE  table_owner='APP' AND table_name='ORDERS'
ORDER  BY index_name, column_position;
```

#### D07 - Partizionamento

```sql
SELECT table_name, partitioning_type, partition_count
FROM   dba_part_tables
WHERE  owner='APP';

SELECT table_name, partition_name, high_value, num_rows, last_analyzed
FROM   dba_tab_partitions
WHERE  table_owner='APP' AND table_name='ORDERS'
ORDER  BY partition_position;
```

#### D08 - SQL Monitor

```sql
SELECT dbms_sqltune.report_sql_monitor(
         sql_id => '<SQL_ID>',
         type => 'TEXT',
         report_level => 'ALL') AS report
FROM dual;
```

#### D09 - SQL Tuning Advisor

```sql
DECLARE
  t VARCHAR2(30);
BEGIN
  t := DBMS_SQLTUNE.CREATE_TUNING_TASK(sql_id => '<SQL_ID>', time_limit => 600);
  DBMS_SQLTUNE.EXECUTE_TUNING_TASK(t);
END;
/
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('<TASK_NAME>') FROM dual;
```

#### D10 - DB link e fetch remoto

```sql
SELECT /*+ DRIVING_SITE(r) */ COUNT(*)
FROM   local_table l
JOIN   remote_table@LINK r ON r.id = l.id
WHERE  l.status = 'ACTIVE';

SET ARRAYSIZE 5000
```

# Parte 1 - Playbook SQL Tuning Enterprise

## SQL-P01 - Triage SQL e baseline

### Decisione

Prima del fix raccogli finestra temporale, impatto business, SQL_ID, piano reale
e metriche. Un singolo snapshot non dimostra una causa.

### Procedura

1. Cerca il SQL in `v$sql` o nello storico AWR se licenziato.
2. Usa D01 per ordinare il carico e D04 per il SQL_ID specifico.
3. Confronta executions, elapsed, CPU, buffer gets, physical reads e righe.
4. Salva il piano corrente con D02 e la finestra ASH con D03.

### Validazione

Hai una baseline riproducibile e sai distinguere regressione singola da carico
cumulativo.

## SQL-P02 - Regressione del piano

### Sintomo

Una query prima veloce rallenta dopo deploy, patch, upgrade o refresh
statistiche; il `PLAN_HASH_VALUE` cambia.

### Procedura

1. Confronta piano corrente e storico con D02.
2. Verifica statistiche, bind e outline.
3. Se il servizio e' degradato, stabilizza con baseline o SQL Patch testata.
4. Correggi la root cause in test: statistiche, indice, SQL o cardinalita.

### Guardrail

Non cambiare parametri optimizer globali per correggere un singolo SQL.

## SQL-P03 - CPU o IO elevati

### Decisione

Separa CPU, logical I/O e physical I/O. Un SQL eseguito milioni di volte puo'
pesare piu' di una singola esecuzione lenta.

### Procedura

- Usa D01 e D03 per ordinare i consumatori nella finestra corretta.
- Mappa sessioni e processi OS.
- Controlla access path, righe elaborate ed executions.
- Valuta rewrite, indice, pruning o riduzione chiamate applicative.

### Validazione

Confronta elapsed, CPU, gets, reads e throughput prima e dopo il fix.

## SQL-P04 - Bind e cardinalita

### Sintomo

Il SQL e' veloce per alcuni valori e lento per altri oppure E-Rows e A-Rows
divergono fortemente.

### Procedura

1. Usa D02 e D04 per child cursor, peeked bind e piano reale.
2. Controlla distribuzione dati e istogrammi con D05.
3. Verifica adaptive cursor sharing.
4. Valuta extended statistics, SQL Profile o riscrittura del predicato.

### Guardrail

Non forzare un piano unico se workload diversi richiedono access path diversi.

## SQL-P05 - Statistiche optimizer

### Sintomo

Regressione dopo refresh dati, statistiche stale, colonne correlate o
partizioni con distribuzione diversa.

### Procedura

- Usa D05 per stato e storico.
- Raccogli statistiche in modo mirato, non sull'intero database in emergenza.
- Preferisci `AUTO_SAMPLE_SIZE`, `AUTO_INVALIDATE` e test rappresentativi.
- Verifica istogrammi, extended statistics e statistiche incrementali su
  partizioni.

### Validazione

Controlla piano, cardinalita e workload DML dopo la raccolta.

## SQL-P06 - TEMP e PGA

### Sintomo

TEMP cresce rapidamente, hash join o sort riversano su disco, ETL impatta altri
utenti.

### Procedura

1. Identifica sessione, SQL_ID, workarea e parallelismo.
2. Usa D03 e D08 per trovare lo step costoso.
3. Aggiungi tempfile solo come mitigazione con storage disponibile.
4. Correggi piano, join order, filtro, PGA o grado parallelo.

### Validazione

Misura TEMP, elapsed e concorrenza nel batch successivo.

## SQL-P07 - Lock e concorrenza

### Decisione

Un lock non si risolve creando un indice alla cieca. Trova blocker, waiter,
transazione e oggetto prima di killare sessioni.

### Procedura

- Usa D03 e i runbook lock collegati.
- Salva SQL, modulo, utente, durata e catena dei blocker.
- Concorda kill o rollback con owner applicativo.
- Correggi ordine transazioni, commit scope o hot row.

## SQL-P08 - RAC gc waits

### Decisione

I wait `gc` non significano automaticamente rete lenta. Correlali con SQL,
oggetto, istanza e service placement.

### Procedura

1. Usa D03 per SQL_ID e istanza.
2. Verifica hot block, access path e distribuzione workload.
3. Controlla interconnect soltanto dopo aver identificato il pattern DB.
4. Valuta service affinity, partizionamento o riduzione accessi concorrenti.

## SQL-P09 - DB link lento

### Decisione

Misura cosa viene eseguito localmente e cosa da remoto. Evita trasferimenti
massivi quando il filtro puo' essere applicato sul sito remoto.

### Procedura

- Usa D10 e piano remoto.
- Controlla latenza rete, cardinalita e fetch array size.
- Valuta predicate pushdown e `DRIVING_SITE` solo con test.
- Verifica timeout e transazioni distribuite.

## SQL-P10 - Fix reversibili e validazione

### Toolbox

| Fix | Quando usarlo | Rollback |
| --- | --- | --- |
| SQL Plan Baseline | Piano noto buono dopo regressione | Disabilita o rimuovi baseline |
| SQL Patch | Workaround mirato con hint | Rimuovi patch |
| SQL Profile | Stime optimizer errate | Disabilita profile |
| Indice invisibile | Test access path | Rendi invisibile o elimina |
| Statistiche mirate | Stale o distribuzione cambiata | Ripristina statistiche precedenti |

### Chiusura

Conserva piano, metriche before/after, smoke test, rischio residuo e intervento
strutturale successivo.

## Matrice dei casi secondari

| Sintomo | Playbook | Toolbox iniziale |
| --- | --- | --- |
| Top SQL elapsed, CPU, gets o reads | SQL-P01, SQL-P03 | D01, D03 |
| Piano cambiato dopo deploy o patch | SQL-P02 | D02, D04 |
| Query lenta solo con alcuni bind | SQL-P04 | D02, D04, D05 |
| Statistiche stale o istogramma errato | SQL-P05 | D05 |
| Full scan o indice non usato | SQL-P03, SQL-P05 | D02, D06 |
| Partition pruning assente | SQL-P03 | D02, D07 |
| Hash join, sort o TEMP piena | SQL-P06 | D03, D08 |
| Sessioni bloccate o deadlock | SQL-P07 | D03 |
| RAC gc waits | SQL-P08 | D03 |
| Query remota lenta | SQL-P09 | D10 |
| SQL long-running o parallelo | SQL-P03, SQL-P06 | D08 |
| Fix emergenziale reversibile | SQL-P10 | D02, D09 |

## Validazione finale

- SQL_ID e finestra temporale registrati.
- Piano reale e storico confrontati.
- Metriche before/after conservate.
- Workaround reversibile e rollback documentati.
- Smoke test applicativo completato.

## Troubleshooting rapido

Se non trovi il SQL in cursor cache, usa storico AWR se licenziato oppure trace
mirato. Se il problema non e' riproducibile, non applicare fix permanenti senza
una baseline osservabile.
