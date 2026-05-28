# UC07 - GoldenGate per Stream Processing and Analytics

> Obiettivo: usare GoldenGate come sorgente CDC affidabile per stream processing, real-time dashboard, anomaly detection e pipeline analytics continue.

Guide correlate:

- [Analytical Data Ingest](./GUIDA_UC03_ANALYTICAL_DATA_INGEST.md)
- [Application Data Streams](./GUIDA_UC06_APPLICATION_DATA_STREAMS.md)
- [Use Case e Knowledge Hub](../GUIDA_GOLDENGATE_USE_CASES_KNOWLEDGE_HUB.md)

Fonti Oracle utili:

- OCI GoldenGate Stream Analytics: https://docs.oracle.com/en-us/iaas/goldengate/doc/stream-analytics.html
- GoldenGate Big Data 19c: https://docs.oracle.com/en/middleware/goldengate/big-data/19.1/gadbd/using-oracle-goldengate-big-data.pdf

---

## 1. Architettura

```text
Oracle Source
   |
   v
GoldenGate Extract -> Trail -> Big Data/Streaming handler
   |
   v
Kafka / OCI Streaming / Event Hub
   |
   v
Stream processing: windows, joins, filters, enrichment
   |
   +--> dashboards
   +--> alerts
   +--> lakehouse
   +--> ML/anomaly detection
```

---

## 2. Differenza tra ingest e stream processing

| Tema | Analytical ingest | Stream processing |
| --- | --- | --- |
| Focus | portare dati al target | calcolare mentre i dati passano |
| Output | tabelle/lakehouse | eventi arricchiti, alert, metriche |
| Latenza | secondi/minuti | secondi/sub-secondi secondo piattaforma |
| Logica | merge/upsert | window, join, aggregation |

---

## 3. Casi pratici

- dashboard frodi quasi real-time;
- monitoraggio transazioni anomale;
- feed operativi per risk engine;
- alert su cambiamenti critici;
- arricchimento stream con dati master;
- bronze/silver/gold lakehouse continuo.

---

## 4. Requisiti enterprise

```text
[ ] Definire ordering per chiave business.
[ ] Definire ritardo massimo tollerabile.
[ ] Definire gestione late events.
[ ] Definire deduplica/idempotenza.
[ ] Definire retention topic/stream.
[ ] Definire replay strategy.
[ ] Definire sicurezza PII nei topic.
[ ] Definire monitoraggio end-to-end.
```

---

## 5. Ruolo di GoldenGate

GoldenGate non sostituisce Kafka/Flink/Spark/Stream Analytics. GoldenGate fornisce change events affidabili e consistenti dal database. La logica di stream processing resta nella piattaforma downstream.

---

## 6. Errori comuni

- Mettere troppa logica di business nei parameter file GoldenGate.
- Non prevedere replay dei messaggi.
- Non gestire schema evolution.
- Usare un topic unico gigante senza partizionamento ragionato.
- Non proteggere dati sensibili nei payload.

---

## 7. Domande tecniche

**GoldenGate e Kafka fanno la stessa cosa?**

No. GoldenGate cattura cambiamenti transazionali dal database e li consegna. Kafka e' una piattaforma di streaming/event log. Insieme formano una pipeline CDC/event-driven.

**Dove metto aggregazioni e finestre temporali?**

In una piattaforma di stream processing, non in Extract/Replicat se la logica e' complessa.

---

## Percorso operativo da zero

Prima di implementare questo use case in laboratorio o in UAT:

1. Leggi [Prerequisiti DB e Architettura](../GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md).
2. Applica [Grant e Privilegi 19c](../GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).
3. Configura [Collegamento Source e Target](../GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md).
4. Valida rete e sicurezza con [Ambienti critici/bancari](../GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md).
5. Esegui il [Runbook End-to-End 19c](../GUIDA_GOLDENGATE_RUNBOOK_END_TO_END_19C.md).
6. Usa [Cheat Sheet GoldenGate 19c](../GUIDA_GOLDENGATE_19C_CHEAT_SHEET.md) per i comandi rapidi.

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
## Approfondimento specifico UC07

Per stream analytics, definisci prima la semantica temporale:

- event time: quando la transazione e' stata committata;
- processing time: quando la piattaforma stream la elabora;
- window: intervallo di aggregazione;
- late event: evento arrivato in ritardo;
- replay: rielaborazione da offset/checkpoint.

GoldenGate fornisce eventi ordinati secondo transazioni e trail/checkpoint; la piattaforma stream deve gestire windowing, join, deduplica e late events.
