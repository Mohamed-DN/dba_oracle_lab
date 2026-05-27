# Runbook Enterprise: SQL Tuning Oracle 19c - Casi, Diagnostica e Spiegazioni

<!-- RUNBOOK_NAV_START -->
## Indice operativo rapido

### Casi piu frequenti da aprire prima
- [Top SQL da AWR con elapsed time alto](#sql-001---top-sql-da-awr-con-elapsed-time-alto)
- [Top SQL da AWR con CPU time alto](#sql-002---top-sql-da-awr-con-cpu-time-alto)
- [Top SQL da ASH durante picco applicativo](#sql-005---top-sql-da-ash-durante-picco-applicativo)
- [SQL_ID noto con piano cambiato](#sql-006---sql_id-noto-con-piano-cambiato)
- [Regressione dopo raccolta statistiche](#sql-008---regressione-dopo-raccolta-statistiche)
- [Query lenta solo in produzione](#sql-011---query-lenta-solo-in-produzione)
- [Bind peeking e adaptive cursor sharing](#sql-013---bind-peeking-e-adaptive-cursor-sharing)
- [Statistiche stale su tabella grande](#sql-015---statistiche-stale-su-tabella-grande)
- [Full table scan inatteso](#sql-021---full-table-scan-inatteso)
- [Partition pruning non avviene](#sql-033---partition-pruning-non-avviene)
- [Hash join consuma troppa PGA/TEMP](#sql-039---hash-join-consuma-troppa-pgatemp)
- [SQL Plan Management baseline](#sql-073---sql-plan-management-baseline)
- [Tuning in emergenza SEV1](#sql-154---tuning-in-emergenza-sev1)
- [Quando aprire SR Oracle](#sql-159---quando-aprire-sr-oracle)

### Macro-aree
- [Spiegazione didattica](#spiegazione-didattica-cosa-significa-fare-sql-tuning)
- [Concetti fondamentali](#concetti-fondamentali-da-saper-spiegare)
- [Matrice decisionale rapida](#matrice-decisionale-rapida)
- [Workflow standard production-grade](#workflow-standard-production-grade)
- [Regole bancarie per tuning in produzione](#regole-bancarie-per-tuning-in-produzione)
- [Blocco comune per tutti gli scenari SQL](#blocco-comune-per-tutti-gli-scenari-sql)
- [Parte 1 - Scenari SQL Tuning Enterprise](#parte-1---scenari-sql-tuning-enterprise)

### Come spiegare il documento
Non iniziare mai dal fix. Prima identifica sintomo, SQL_ID, baseline storica, piano attuale, piano precedente, cardinalita stimate vs reali e wait prevalente. Solo dopo scegli se intervenire su statistiche, indice, riscrittura SQL, SPM, SQL Profile o parametri di sessione controllati.
<!-- RUNBOOK_NAV_END -->

> Documento operativo per DBA Oracle 19c in ambienti critici. Copre diagnostica SQL, optimizer, statistiche, piani di esecuzione, AWR/ASH, SQL Monitor, indici, join, partizionamento, parallelismo, wait events, RAC, Exadata, SQL Plan Management e tuning sicuro in produzione.

---

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

# Parte 1 - Scenari SQL Tuning Enterprise

## SQL-001 - Top SQL da AWR con elapsed time alto

### Diagnostica mirata
- Usa [D01 - Top SQL AWR](#d01-top-sql-awr).

## SQL-002 - Top SQL da AWR con CPU time alto

### Diagnostica mirata
- Usa [D01 - Top SQL AWR](#d01-top-sql-awr).

## SQL-003 - Top SQL da AWR con buffer gets alto

### Diagnostica mirata
- Usa [D01 - Top SQL AWR](#d01-top-sql-awr).

## SQL-004 - Top SQL da AWR con physical reads alto

### Diagnostica mirata
- Usa [D01 - Top SQL AWR](#d01-top-sql-awr).

## SQL-005 - Top SQL da ASH durante picco applicativo

### Diagnostica mirata
- Usa [D01 - Top SQL AWR](#d01-top-sql-awr).

## SQL-006 - SQL_ID noto con piano cambiato

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-007 - Plan hash value diverso dopo deploy

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-008 - Regressione dopo raccolta statistiche

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-009 - Regressione dopo upgrade database

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-010 - Regressione dopo patch RU

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-011 - Query lenta solo in produzione

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-012 - Query lenta solo con bind specifico

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-013 - Bind peeking e adaptive cursor sharing

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-014 - Cardinalita stimata molto diversa da righe reali

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-015 - Statistiche stale su tabella grande

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-016 - Statistiche mancanti su colonne correlate

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-017 - Istogramma mancante su colonna skewed

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-018 - Istogramma dannoso su colonna non selettiva

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-019 - Extended statistics per colonne correlate

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-020 - Dynamic sampling troppo alto o insufficiente

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-021 - Full table scan inatteso

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-022 - Index range scan non usato

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-023 - Index skip scan indesiderato

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-024 - Index full scan vs fast full scan

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-025 - Bitmap index usato in OLTP

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-026 - Indice invisibile per test tuning

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-027 - Indice composito con ordine colonne sbagliato

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-028 - Indice funzione-based non usato

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-029 - Predicato non sargable con funzione su colonna

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-030 - LIKE con wildcard iniziale

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-031 - Conversione implicita tra VARCHAR2 e NUMBER

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-032 - Date filter non usa indice

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-033 - Partition pruning non avviene

### Diagnostica mirata
- Usa [D07 - Partizionamento](#d07-partizionamento).

## SQL-034 - Local index vs global index su partizioni

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-035 - Partizione stale stats

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-036 - Query su tabella partizionata con bind

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-037 - Join order errato

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-038 - Nested loop lento su grandi volumi

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-039 - Hash join consuma troppa PGA/TEMP

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-040 - Merge join inatteso

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-041 - Cartesian join accidentale

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-042 - Join su colonne con datatype diverso

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-043 - Subquery correlated lenta

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-044 - IN vs EXISTS

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-045 - NOT IN con NULL

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-046 - Anti-join inefficiente

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-047 - OR expansion e predicate transformation

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-048 - View merging non avviene

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-049 - Predicate pushdown non avviene

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-050 - WITH clause materializzata o inline

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-051 - Materialized view rewrite non avviene

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-052 - Result cache appropriata o dannosa

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-053 - Parallel query non parte

### Diagnostica mirata
- Usa [D08 - SQL Monitor](#d08-sql-monitor).

## SQL-054 - Parallel query parte troppo aggressiva

### Diagnostica mirata
- Usa [D08 - SQL Monitor](#d08-sql-monitor).

## SQL-055 - PX skew tra slave

### Diagnostica mirata
- Usa [D08 - SQL Monitor](#d08-sql-monitor).

## SQL-056 - DOP automatico non corretto

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-057 - PGA insufficiente e sort su TEMP

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-058 - TEMP piena per hash/sort

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-059 - Direct path read alto

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-060 - Db file sequential read alto

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-061 - Db file scattered read alto

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-062 - Read by other session alto

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-063 - Log file sync percepito come SQL lento

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-064 - Enqueue TX row lock contention

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-065 - Library cache lock/pin

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-066 - Mutex e cursor: pin S wait on X

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-067 - Hard parse elevato

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-068 - Soft parse ma molte versioni child cursor

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-069 - Cursor sharing force come workaround

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-070 - SQL con literal invece di bind

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-071 - Bind mismatch e child cursors

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-072 - Adaptive plans e statistics feedback

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-073 - SQL Plan Management baseline

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-074 - SQL Profile da SQL Tuning Advisor

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-075 - SQL Patch con hint correttivo

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-076 - Outline/hint temporaneo

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-077 - Hints ignorati o sbagliati

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-078 - Plan baseline non accettata

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-079 - Evolve SQL plan baseline

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-080 - SQL Monitor per query long-running

### Diagnostica mirata
- Usa [D08 - SQL Monitor](#d08-sql-monitor).

## SQL-081 - DBMS_XPLAN display_cursor con ALLSTATS LAST

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-082 - EXPLAIN PLAN fuorviante rispetto al piano reale

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-083 - AWR SQL report

### Diagnostica mirata
- Usa [D01 - Top SQL AWR](#d01-top-sql-awr).

## SQL-084 - ASH report per sessione bloccata

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-085 - SQL Tuning Advisor automatico

### Diagnostica mirata
- Usa [D09 - SQL Tuning Advisor](#d09-sql-tuning-advisor).

## SQL-086 - SQL Access Advisor per indici/MV

### Diagnostica mirata
- Usa [D09 - SQL Tuning Advisor](#d09-sql-tuning-advisor).

## SQL-087 - Statistiche di sistema mancanti

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-088 - Statistiche fixed objects mancanti

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-089 - Dictionary stats obsolete

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-090 - Gather stats con no_invalidate

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-091 - Incremental stats su partizioni

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-092 - Pending statistics test

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-093 - Locked statistics su tabella volatile

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-094 - Global temporary table stats

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-095 - Session private statistics GTT

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-096 - Cardinality hint come diagnostica

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-097 - OPT_PARAM come workaround controllato

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-098 - Optimizer feature enable dopo upgrade

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-099 - Query con ROWNUM/top-N inefficiente

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-100 - Pagination lenta OFFSET FETCH

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-101 - Analytic functions con sort enorme

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-102 - Group by pesante

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-103 - Distinct inutile

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-104 - UNION vs UNION ALL

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-105 - CTAS per materializzare risultato intermedio

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-106 - Delete massivo lento

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-107 - Update massivo lento

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-108 - Merge statement lento

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-109 - Insert append e nologging decisione

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-110 - DDL indice online lento

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-111 - Rebuild index inutile

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-112 - Coalesce index vs rebuild

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-113 - Segment high water mark e full scan

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-114 - Table compression impatto query

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-115 - Hybrid Columnar Compression in Exadata

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-116 - In-Memory column store query

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-117 - Bloom filter e star transformation

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-118 - Star schema bitmap indexes

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-119 - Exadata smart scan non attivo

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-120 - Storage index non usato

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-121 - Cell offload percentage basso

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-122 - RAC gc cr request alto

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-123 - RAC gc buffer busy acquire

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-124 - Service placement e SQL tuning in RAC

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-125 - Plan diverso tra nodi RAC

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-126 - Application module/action mancanti

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-127 - End-to-end tracing DBMS_MONITOR

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-128 - 10046 trace per SQL singolo

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-129 - 10053 trace optimizer ultima istanza

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-130 - TKPROF interpretazione

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-131 - SQL trace con bind e waits

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-132 - Optimizer trace troppo pesante in produzione

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).

## SQL-133 - Query su DB link lenta

### Diagnostica mirata
- Usa [D10 - DB link e fetch remoto](#d10-db-link-e-fetch-remoto).

## SQL-134 - DRIVING_SITE hint su DB link

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-135 - Fetch array size basso via DB link

### Diagnostica mirata
- Usa [D10 - DB link e fetch remoto](#d10-db-link-e-fetch-remoto).

## SQL-136 - Remote predicate pushdown

### Diagnostica mirata
- Usa [D10 - DB link e fetch remoto](#d10-db-link-e-fetch-remoto).

## SQL-137 - PLSQL function chiamata per ogni riga

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-138 - Context switch SQL PL/SQL elevato

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-139 - Bulk collect/forall mancante

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-140 - Pipelined function lenta

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-141 - JSON query senza indici appropriati

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-142 - XMLTABLE lento

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-143 - Spatial query lenta

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-144 - LOB read/write lento

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-145 - SecureFiles LOB tuning

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-146 - Audit/FGA impatta query critica

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-147 - VPD policy rallenta SQL

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-148 - Redaction impatta piano

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-149 - Masking/preprod stats diverse

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-150 - Query intermittente lenta per load concorrente

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-151 - Statistiche e bind dopo refresh preprod

### Diagnostica mirata
- Usa [D05 - Statistiche optimizer](#d05-statistiche-optimizer).

## SQL-152 - Baseline da produzione a preprod

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-153 - Comparare piano prod/preprod

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-154 - Tuning in emergenza SEV1

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-155 - Tuning strutturale post incidente

### Diagnostica mirata
- Usa [D04 - Diagnostica minima SQL_ID](#d04-diagnostica-minima-sql_id).

## SQL-156 - Quando non creare indice

### Diagnostica mirata
- Usa [D06 - Indici e colonne](#d06-indici-e-colonne).

## SQL-157 - Quando riscrivere SQL invece di hintare

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-158 - Quando usare SPM invece di SQL Profile

### Diagnostica mirata
- Usa [D02 - Piano reale e storico](#d02-piano-reale-e-storico).

## SQL-159 - Quando aprire SR Oracle

### Diagnostica mirata
- Usa [D03 - ASH e wait event](#d03-ash-e-wait-event).
