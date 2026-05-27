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
# Parte 1 - Scenari SQL Tuning Enterprise

## SQL-001 - Top SQL da AWR con elapsed time alto

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-002 - Top SQL da AWR con CPU time alto

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-003 - Top SQL da AWR con buffer gets alto

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-004 - Top SQL da AWR con physical reads alto

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-005 - Top SQL da ASH durante picco applicativo

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-006 - SQL_ID noto con piano cambiato

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-007 - Plan hash value diverso dopo deploy

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-008 - Regressione dopo raccolta statistiche

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-009 - Regressione dopo upgrade database

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-010 - Regressione dopo patch RU

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-011 - Query lenta solo in produzione

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-012 - Query lenta solo con bind specifico

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-013 - Bind peeking e adaptive cursor sharing

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-014 - Cardinalita stimata molto diversa da righe reali

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-015 - Statistiche stale su tabella grande

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-016 - Statistiche mancanti su colonne correlate

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-017 - Istogramma mancante su colonna skewed

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-018 - Istogramma dannoso su colonna non selettiva

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-019 - Extended statistics per colonne correlate

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-020 - Dynamic sampling troppo alto o insufficiente

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-021 - Full table scan inatteso

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-022 - Index range scan non usato

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-023 - Index skip scan indesiderato

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-024 - Index full scan vs fast full scan

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-025 - Bitmap index usato in OLTP

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-026 - Indice invisibile per test tuning

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-027 - Indice composito con ordine colonne sbagliato

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-028 - Indice funzione-based non usato

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-029 - Predicato non sargable con funzione su colonna

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-030 - LIKE con wildcard iniziale

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-031 - Conversione implicita tra VARCHAR2 e NUMBER

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-032 - Date filter non usa indice

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-033 - Partition pruning non avviene

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
SELECT table_name, partitioning_type, partition_count
FROM   dba_part_tables
WHERE  owner='APP';

SELECT table_name, partition_name, high_value, num_rows, last_analyzed
FROM   dba_tab_partitions
WHERE  table_owner='APP' AND table_name='ORDERS'
ORDER  BY partition_position;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-034 - Local index vs global index su partizioni

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-035 - Partizione stale stats

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-036 - Query su tabella partizionata con bind

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-037 - Join order errato

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-038 - Nested loop lento su grandi volumi

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-039 - Hash join consuma troppa PGA/TEMP

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-040 - Merge join inatteso

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-041 - Cartesian join accidentale

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-042 - Join su colonne con datatype diverso

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-043 - Subquery correlated lenta

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-044 - IN vs EXISTS

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-045 - NOT IN con NULL

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-046 - Anti-join inefficiente

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-047 - OR expansion e predicate transformation

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-048 - View merging non avviene

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-049 - Predicate pushdown non avviene

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-050 - WITH clause materializzata o inline

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-051 - Materialized view rewrite non avviene

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-052 - Result cache appropriata o dannosa

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-053 - Parallel query non parte

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
SELECT dbms_sqltune.report_sql_monitor(
         sql_id => '<SQL_ID>',
         type => 'TEXT',
         report_level => 'ALL') AS report
FROM dual;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-054 - Parallel query parte troppo aggressiva

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
SELECT dbms_sqltune.report_sql_monitor(
         sql_id => '<SQL_ID>',
         type => 'TEXT',
         report_level => 'ALL') AS report
FROM dual;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-055 - PX skew tra slave

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
SELECT dbms_sqltune.report_sql_monitor(
         sql_id => '<SQL_ID>',
         type => 'TEXT',
         report_level => 'ALL') AS report
FROM dual;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-056 - DOP automatico non corretto

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-057 - PGA insufficiente e sort su TEMP

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-058 - TEMP piena per hash/sort

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-059 - Direct path read alto

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-060 - Db file sequential read alto

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-061 - Db file scattered read alto

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-062 - Read by other session alto

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-063 - Log file sync percepito come SQL lento

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-064 - Enqueue TX row lock contention

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-065 - Library cache lock/pin

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-066 - Mutex e cursor: pin S wait on X

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-067 - Hard parse elevato

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-068 - Soft parse ma molte versioni child cursor

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-069 - Cursor sharing force come workaround

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-070 - SQL con literal invece di bind

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-071 - Bind mismatch e child cursors

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-072 - Adaptive plans e statistics feedback

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-073 - SQL Plan Management baseline

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-074 - SQL Profile da SQL Tuning Advisor

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-075 - SQL Patch con hint correttivo

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-076 - Outline/hint temporaneo

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-077 - Hints ignorati o sbagliati

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-078 - Plan baseline non accettata

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-079 - Evolve SQL plan baseline

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-080 - SQL Monitor per query long-running

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
SELECT dbms_sqltune.report_sql_monitor(
         sql_id => '<SQL_ID>',
         type => 'TEXT',
         report_level => 'ALL') AS report
FROM dual;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-081 - DBMS_XPLAN display_cursor con ALLSTATS LAST

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-082 - EXPLAIN PLAN fuorviante rispetto al piano reale

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-083 - AWR SQL report

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-084 - ASH report per sessione bloccata

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-085 - SQL Tuning Advisor automatico

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-086 - SQL Access Advisor per indici/MV

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-087 - Statistiche di sistema mancanti

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-088 - Statistiche fixed objects mancanti

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-089 - Dictionary stats obsolete

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-090 - Gather stats con no_invalidate

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-091 - Incremental stats su partizioni

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-092 - Pending statistics test

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-093 - Locked statistics su tabella volatile

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-094 - Global temporary table stats

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-095 - Session private statistics GTT

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-096 - Cardinality hint come diagnostica

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-097 - OPT_PARAM come workaround controllato

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-098 - Optimizer feature enable dopo upgrade

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-099 - Query con ROWNUM/top-N inefficiente

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-100 - Pagination lenta OFFSET FETCH

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-101 - Analytic functions con sort enorme

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-102 - Group by pesante

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-103 - Distinct inutile

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-104 - UNION vs UNION ALL

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-105 - CTAS per materializzare risultato intermedio

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-106 - Delete massivo lento

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-107 - Update massivo lento

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-108 - Merge statement lento

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-109 - Insert append e nologging decisione

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-110 - DDL indice online lento

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-111 - Rebuild index inutile

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-112 - Coalesce index vs rebuild

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-113 - Segment high water mark e full scan

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-114 - Table compression impatto query

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-115 - Hybrid Columnar Compression in Exadata

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-116 - In-Memory column store query

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-117 - Bloom filter e star transformation

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-118 - Star schema bitmap indexes

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-119 - Exadata smart scan non attivo

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-120 - Storage index non usato

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-121 - Cell offload percentage basso

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-122 - RAC gc cr request alto

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-123 - RAC gc buffer busy acquire

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-124 - Service placement e SQL tuning in RAC

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-125 - Plan diverso tra nodi RAC

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-126 - Application module/action mancanti

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-127 - End-to-end tracing DBMS_MONITOR

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-128 - 10046 trace per SQL singolo

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-129 - 10053 trace optimizer ultima istanza

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-130 - TKPROF interpretazione

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-131 - SQL trace con bind e waits

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-132 - Optimizer trace troppo pesante in produzione

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-133 - Query su DB link lenta

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
SELECT /*+ DRIVING_SITE(r) */ COUNT(*)
FROM   local_table l
JOIN   remote_table@LINK r ON r.id = l.id
WHERE  l.status = 'ACTIVE';

SET ARRAYSIZE 5000
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-134 - DRIVING_SITE hint su DB link

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-135 - Fetch array size basso via DB link

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
SELECT /*+ DRIVING_SITE(r) */ COUNT(*)
FROM   local_table l
JOIN   remote_table@LINK r ON r.id = l.id
WHERE  l.status = 'ACTIVE';

SET ARRAYSIZE 5000
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-136 - Remote predicate pushdown

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
SELECT /*+ DRIVING_SITE(r) */ COUNT(*)
FROM   local_table l
JOIN   remote_table@LINK r ON r.id = l.id
WHERE  l.status = 'ACTIVE';

SET ARRAYSIZE 5000
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-137 - PLSQL function chiamata per ogni riga

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-138 - Context switch SQL PL/SQL elevato

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-139 - Bulk collect/forall mancante

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-140 - Pipelined function lenta

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-141 - JSON query senza indici appropriati

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-142 - XMLTABLE lento

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-143 - Spatial query lenta

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-144 - LOB read/write lento

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-145 - SecureFiles LOB tuning

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-146 - Audit/FGA impatta query critica

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-147 - VPD policy rallenta SQL

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-148 - Redaction impatta piano

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-149 - Masking/preprod stats diverse

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-150 - Query intermittente lenta per load concorrente

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-151 - Statistiche e bind dopo refresh preprod

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-152 - Baseline da produzione a preprod

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-153 - Comparare piano prod/preprod

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-154 - Tuning in emergenza SEV1

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-155 - Tuning strutturale post incidente

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-156 - Quando non creare indice

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
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

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-157 - Quando riscrivere SQL invece di hintare

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-158 - Quando usare SPM invece di SQL Profile

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- Piano reale
SELECT *
FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ALIAS'));

-- Piano storico AWR
SELECT *
FROM table(dbms_xplan.display_awr('<SQL_ID>', NULL, NULL, 'ADVANCED'));
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

## SQL-159 - Quando aprire SR Oracle

Dominio: SQL tuning / optimizer / performance diagnostics
Severita tipica: SEV1 se impatta servizio core, SEV2/SEV3 negli altri casi.

### Come spiegarlo
- Un SQL lento va spiegato separando sintomo, piano, cardinalita, wait event e fix.
- Il piano di esecuzione e una ipotesi dell optimizer; il piano reale con `ALLSTATS LAST` mostra cosa e successo davvero.
- La metrica piu utile dipende dal caso: elapsed time, CPU, buffer gets, physical reads, rows, temp, waits, parse time.
- In produzione prima si stabilizza il servizio, poi si fa tuning strutturale.

### Sintomi tipici
- Utenti segnalano lentezza o timeout.
- AWR mostra SQL tra i top per elapsed/CPU/gets/reads.
- Piano cambiato rispetto al baseline noto.
- ASH mostra wait specifici collegati al SQL o alla sessione.
- SQL Monitor mostra step con righe reali molto diverse dalle stime.

### Diagnostica base
```sql
-- ASH: dove passa tempo il SQL o il sistema
SELECT sql_id, session_state, event, wait_class, COUNT(*) samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP  BY sql_id, session_state, event, wait_class
ORDER  BY samples DESC;
```

### Decisione operativa
- Se la causa e piano cambiato, valutare SPM baseline o SQL Patch come workaround reversibile.
- Se la causa e statistiche errate, correggere statistiche e verificare invalidazione cursor.
- Se la causa e modello dati/access path, valutare indice, partizionamento, rewrite o materialized view.
- Se la causa e concorrenza o lock, non correggere con indice: risolvere transazioni/sessioni.

### Fix possibili
- Raccolta statistiche mirata con `DBMS_STATS`.
- Creazione indice invisibile per test e poi visibile se validato.
- SQL Plan Baseline per stabilizzare piano buono.
- SQL Profile se il problema e stima cardinalita.
- SQL Patch/hint temporaneo se non puoi modificare codice.
- Rewrite SQL se il problema e logico o sintattico.

### Validazione before/after
```sql
SELECT * FROM table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'));
SELECT sql_id, plan_hash_value, executions, elapsed_time/1e6 elapsed_s, cpu_time/1e6 cpu_s, buffer_gets, disk_reads FROM v$sql WHERE sql_id='<SQL_ID>';
```

### Rischi enterprise
- Un indice accelera SELECT ma rallenta INSERT/UPDATE/DELETE e aumenta storage/redo/backup.
- Un hint puo bloccare un piano oggi e diventare dannoso dopo crescita dati.
- Cambiare parametri optimizer globali per un singolo SQL e rischioso.
- Un fix testato in PREPROD puo non comportarsi uguale se statistiche o bind differiscono.

### Criterio PASS
- Elapsed time ridotto o tornato sotto SLA.
- Buffer gets/reads/TEMP coerenti con il nuovo piano.
- Piano stabile su bind rappresentativi.
- Nessuna regressione su SQL correlati.
- Rollback plan documentato.

---

# Appendice finale - Checklist unica SQL tuning

```text
[ ] SQL_ID identificato.
[ ] Piano reale acquisito con DBMS_XPLAN ALLSTATS LAST.
[ ] SQL Monitor salvato se SQL long-running.
[ ] AWR/ASH prima e dopo allegati.
[ ] Bind rappresentativi verificati.
[ ] Statistiche controllate e documentate.
[ ] Fix scelto: stats, indice, rewrite, SPM, profile, patch o parametro locale.
[ ] Test regressione su SQL correlati.
[ ] Rollback plan pronto.
[ ] Evidenza allegata al ticket.
```

## Fonti Oracle ufficiali

- SQL Tuning Guide 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/
- Performance Tuning Guide 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/
- DBMS_XPLAN: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_XPLAN.html
- DBMS_SQLTUNE: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_SQLTUNE.html
- DBMS_SPM: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_SPM.html
- DBMS_STATS: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_STATS.html
- SQL Plan Management: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/managing-sql-plan-baselines.html
- Optimizer Statistics Concepts: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/optimizer-statistics-concepts.html
- Monitoring Database Operations / SQL Monitor: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/monitoring-database-operations.html
