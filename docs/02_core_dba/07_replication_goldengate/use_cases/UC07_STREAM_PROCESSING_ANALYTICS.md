# UC07 - GoldenGate per Stream Processing and Analytics

> Obiettivo: usare GoldenGate come sorgente CDC affidabile per stream processing, real-time dashboard, anomaly detection e pipeline analytics continue.

Guide correlate:

- [Analytical Data Ingest](./UC03_ANALYTICAL_DATA_INGEST.md)
- [Application Data Streams](./UC06_APPLICATION_DATA_STREAMS.md)
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
|---|---|---|
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
