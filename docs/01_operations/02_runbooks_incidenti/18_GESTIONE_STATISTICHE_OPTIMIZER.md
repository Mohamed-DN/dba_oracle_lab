# 18 — Gestione Statistiche Optimizer (DBMS_STATS)

<!-- RUNBOOK_NAV_START -->
## Casi piu frequenti da aprire prima
- Query regredita dopo statistiche stale o mancanti.
- Tabella grande con modifiche massive.
- Istogrammi/extended stats da valutare.
- Import Data Pump con statistiche non affidabili.
- Serve gather mirato senza impattare produzione.

## Indice rapido
- [Casi piu frequenti da aprire prima](#casi-piu-frequenti-da-aprire-prima)
- [Obiettivi](#obiettivi)
- [Procedura Operativa](#procedura-operativa)
  - [Step 1: Verifica stato statistiche](#step-1-verifica-stato-statistiche)
  - [Step 2: Raccogli statistiche stale (raccomandato)](#step-2-raccogli-statistiche-stale-raccomandato)
  - [Step 3: Tabella critica (intervento puntuale)](#step-3-tabella-critica-intervento-puntuale)
- [Validazione Finale](#validazione-finale)
- [Troubleshooting](#troubleshooting)
<!-- RUNBOOK_NAV_END -->

> ⏱️ Tempo: 20-40 minuti | 📅 Frequenza: Settimanale o post-massive load | 👤 Chi: DBA
> **Scenario tipico**: regressione piani SQL, cardinalità errate, query improvvisamente lente.

---

## Obiettivi

Garantire che l'ottimizzatore Oracle disponga di statistiche accurate e aggiornate per la generazione di piani di esecuzione efficienti, minimizzando le regressioni prestazionali.

## Procedura Operativa

### Step 1: Verifica stato statistiche

```sql
sqlplus / as sysdba

SELECT owner, table_name,
       TO_CHAR(last_analyzed, 'YYYY-MM-DD HH24:MI') AS last_analyzed,
       stale_stats, num_rows
FROM dba_tab_statistics
WHERE owner NOT IN ('SYS','SYSTEM')
  AND temporary = 'N'
ORDER BY last_analyzed NULLS FIRST
FETCH FIRST 50 ROWS ONLY;
```

---

### Step 2: Raccogli statistiche stale (raccomandato)

```sql
BEGIN
  DBMS_STATS.GATHER_DATABASE_STATS(
    options          => 'GATHER STALE',
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
    cascade          => TRUE,
    degree           => DBMS_STATS.AUTO_DEGREE,
    no_invalidate    => DBMS_STATS.AUTO_INVALIDATE
  );
END;
/
```

---

### Step 3: Tabella critica (intervento puntuale)

```sql
EXEC DBMS_STATS.GATHER_TABLE_STATS(
  ownname          => '&OWNER',
  tabname          => '&TABLE_NAME',
  estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
  method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
  cascade          => TRUE,
  no_invalidate    => DBMS_STATS.AUTO_INVALIDATE
);
```

---

## Validazione Finale

```sql
SELECT sql_id, plan_hash_value, executions,
       ROUND(elapsed_time/1e6,2) AS elapsed_s
FROM v$sql
WHERE sql_id = '&SQL_ID';
```

```sql
SELECT owner, table_name, stale_stats, last_analyzed
FROM dba_tab_statistics
WHERE owner = '&OWNER' AND table_name = '&TABLE_NAME';
```

---

## Troubleshooting

- **Piano peggiora dopo gather**: valuta SQL Plan Baseline / statistiche storiche.
- **Statistiche non aggiornate**: verifica permessi e maintenance windows.
- **Tempo gather elevato**: limita scope per schema/tabella e usa parallelismo controllato.
