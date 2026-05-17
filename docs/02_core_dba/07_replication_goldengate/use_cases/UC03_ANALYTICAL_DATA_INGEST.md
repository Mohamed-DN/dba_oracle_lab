# UC03 - GoldenGate per Analytical Data Ingest

> Obiettivo: alimentare data warehouse, lakehouse o piattaforme analytics con cambiamenti quasi real-time provenienti da database operativi.

Guide correlate:

- [Collegamento Source e Target](../GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md)
- [GoldenGate 19c Completa](../GUIDA_GOLDENGATE_19C_COMPLETA.md)
- [Use Case e Knowledge Hub](../GUIDA_GOLDENGATE_USE_CASES_KNOWLEDGE_HUB.md)

Fonti Oracle utili:

- GoldenGate Big Data 19c: https://docs.oracle.com/en/middleware/goldengate/big-data/19.1/gadbd/using-oracle-goldengate-big-data.pdf
- Snowflake handler 26ai: https://docs.oracle.com/en/database/goldengate/big-data/26/gadbd/snowflake.html

---

## 1. Architettura

```text
Oracle OLTP / RAC
      |
      | CDC
      v
GoldenGate Trail
      |
      +--> Kafka / object storage / Snowflake / Databricks / BigQuery / Redshift
      |
      +--> Bronze zone -> Silver -> Gold analytics
```

---

## 2. Perche' non usare solo batch notturno

GoldenGate serve quando:

- il business vuole dati aggiornati durante la giornata;
- i report operativi non possono aspettare la notte;
- il carico ETL batch sul source e' troppo alto;
- bisogna catturare ogni change event con ordine transazionale;
- si vuole disaccoppiare OLTP da analytics.

---

## 3. Decisioni architetturali

| Decisione | Opzioni | Nota |
|---|---|---|
| Target | warehouse, lakehouse, Kafka, object storage | dipende da consumo dati |
| Formato | JSON, Avro, delimited, Parquet tramite pipeline | Avro/JSON frequenti per event stream |
| Latenza | secondi, minuti, micro-batch | Snowflake stage/merge e' micro-batch; streaming e' piu real-time |
| Operazioni | insert/update/delete o insert-only | alcuni target analytics preferiscono append-only |
| Storia | current state o audit/event log | scegliere prima del design |

---

## 4. Pattern consigliato

```text
SOURCE OLTP -> Extract -> Trail -> Distribution/Pump -> Big Data Replicat/Handler -> Analytics Target
```

In produzione separa:

- capture vicino al source;
- delivery vicino al target;
- rete cifrata;
- storage trail dimensionato;
- monitoraggio lag end-to-end.

---

## 5. Controlli DBA

```sql
-- Volume redo giornaliero approssimativo
SELECT trunc(first_time) day, round(sum(blocks*block_size)/1024/1024/1024,2) gb
FROM   v$archived_log
WHERE  first_time > sysdate - 7
GROUP  BY trunc(first_time)
ORDER  BY day;

-- Tabelle candidate senza PK
SELECT owner, table_name
FROM   dba_tables t
WHERE  owner = 'APP'
AND    NOT EXISTS (
  SELECT 1 FROM dba_constraints c
  WHERE c.owner=t.owner AND c.table_name=t.table_name AND c.constraint_type IN ('P','U')
);
```

---

## 6. Rischi comuni

- Target analytics lento che fa crescere trail.
- Trasformazioni troppo complesse dentro Replicat.
- Update/delete non supportati o costosi sul target.
- PII inviata verso piattaforme analytics senza masking o policy.
- Mancata gestione DDL/schema evolution.

---

## 7. Domande tecniche

**GoldenGate e' ETL?**

Non nel senso classico. GoldenGate e' CDC e real-time integration. Puo' fare mapping e trasformazioni leggere, ma trasformazioni pesanti vanno su ETL/ELT/stream processing.

**Come gestisci update/delete verso lakehouse?**

Con formato/event model che conserva operation type, oppure con tabelle merge/upsert nel target, oppure con pattern append-only + compaction downstream.
