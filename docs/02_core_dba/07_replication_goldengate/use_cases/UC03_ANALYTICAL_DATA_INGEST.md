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
| --- | --- | --- |
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

---

## Percorso operativo da zero

Prima di implementare questo use case in laboratorio o in UAT:

1. Leggi [Prerequisiti DB e Architettura](../GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md).
2. Applica [Grant e Privilegi 19c](../GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).
3. Configura [Collegamento Source e Target](../GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md).
4. Valida rete e sicurezza con [Ambienti critici/bancari](../GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md).
5. Usa [Cheat Sheet GoldenGate 19c](../CHEAT_SHEET_GOLDENGATE_19C.md) per i comandi rapidi.

Grant minimi da non saltare:

```text
Oracle source: CREATE SESSION + DBMS_GOLDENGATE_AUTH privilege_type CAPTURE o *
Oracle target: DBMS_GOLDENGATE_AUTH privilege_type APPLY o * + grant DML sulle tabelle target
PostgreSQL target: CONNECT + USAGE schema + SELECT/INSERT/UPDATE/DELETE sulle tabelle
PostgreSQL source: CONNECT + WITH REPLICATION + eventuale admin temporaneo per TRANDATA
```

Criterio di avanzamento:

```text
[ ] DBLOGIN funziona con USERIDALIAS.
[ ] Supplemental logging e' attivo sugli oggetti replicati.
[ ] Extract/Replicat partono senza ORA-01031.
[ ] Lag e checkpoint sono monitorati.
[ ] Esiste rollback o re-sync plan.
[ ] I dati sensibili sono autorizzati e protetti.
```
## Approfondimento specifico UC03

Per analytics ingest separa sempre tre livelli:

```text
Raw/Bronze: eventi CDC quasi grezzi
Silver: dati puliti, normalizzati, deduplicati
Gold: aggregati o data product usati dal business
```

Non forzare GoldenGate a fare tutta la trasformazione. GoldenGate deve consegnare change event affidabili; trasformazioni pesanti, aggregazioni e data quality stanno nel target analytics o nella piattaforma stream/ELT.

Controlli extra:

- il target supporta update/delete o richiede append-only;
- il payload include operation type;
- il lag e' misurato source-to-target, non solo Extract;
- PII e dati soggetti a retention sono classificati prima della replica.
