# GoldenGate - Indice Use Case Operativi

> Questa cartella trasforma i use case del GoldenGate Knowledge Hub in guide operative leggibili da un DBA enterprise. Ogni use case contiene architettura, prerequisiti, rete, sicurezza, procedura, controlli e domande tecniche.

---

## Regola di lettura

Prima di aprire un use case specifico, leggere sempre:

1. [Prerequisiti DB e Architettura](../GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md)
2. [Collegamento Source e Target](../GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md)
3. [Ambienti critici/bancari](../GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md)
4. [GoldenGate 19c Completa](../GUIDA_GOLDENGATE_19C_COMPLETA.md)

Motivo: in ambienti bancari non basta sapere configurare Extract e Replicat. Devi anche sapere giustificare firewall, TLS, credenziali, retention archive, monitoring, audit e rollback.

---

## Mappa use case

| # | Use case | Guida | Pattern principale |
| --- | --- | --- | --- |
| 1 | No Downtime Migrations | [UC01_NO_DOWNTIME_MIGRATIONS.md](./UC01_NO_DOWNTIME_MIGRATIONS.md) | Initial load + CDC + cutover |
| 2 | High Availability | [UC02_HIGH_AVAILABILITY.md](./UC02_HIGH_AVAILABILITY.md) | Live standby logico / active-active controllato |
| 3 | Analytical Data Ingest | [UC03_ANALYTICAL_DATA_INGEST.md](./UC03_ANALYTICAL_DATA_INGEST.md) | CDC verso warehouse/lakehouse |
| 4 | AI Ready Data | [UC04_AI_READY_DATA.md](./UC04_AI_READY_DATA.md) | CDC verso pipeline AI/RAG/vector |
| 5 | Multicloud Data Integration | [UC05_MULTICLOUD_DATA_INTEGRATION.md](./UC05_MULTICLOUD_DATA_INTEGRATION.md) | On-prem/cloud/cloud-to-cloud |
| 6 | Application Data Streams | [UC06_APPLICATION_DATA_STREAMS.md](./UC06_APPLICATION_DATA_STREAMS.md) | CDC verso eventi applicativi |
| 7 | Stream Processing and Analytics | [UC07_STREAM_PROCESSING_ANALYTICS.md](./UC07_STREAM_PROCESSING_ANALYTICS.md) | Kafka/stream analytics/lakehouse |

---

## Come scegliere il use case giusto

| Se il requisito e' | Parti da |
| --- | --- |
| Migrare Oracle senza fermo lungo | UC01 |
| Avere un secondo sito scrivibile o quasi pronto | UC02 |
| Alimentare DWH/lakehouse quasi real-time | UC03 |
| Aggiornare dati per AI, RAG o vector search | UC04 |
| Collegare data center e cloud diversi | UC05 |
| Pubblicare eventi dati verso microservizi | UC06 |
| Fare analytics su stream in tempo reale | UC07 |

---

## Nota production-grade

In produzione critica, ogni use case deve avere almeno:

- owner applicativo e owner DBA;
- matrice dati e classificazione PII;
- source, target, porte, protocolli, certificati e firewall approvati;
- piano initial load;
- piano CDC;
- piano cutover o enablement;
- piano rollback;
- monitoring lag/FRA/trail/checkpoint;
- test di riconciliazione dati;
- runbook incident;
- evidenza di change management.

---

## Standard minimo di completezza

Ogni guida use case deve rispondere a queste domande:

- Qual e' il problema business/tecnico?
- Qual e' la topologia GoldenGate corretta?
- Quali DB/source/target sono coinvolti?
- Quali grant servono su source e target?
- Quali porte/reti/certificati servono?
- Come si fa initial load o bootstrap?
- Come si abilita CDC?
- Come si misura il lag?
- Come si validano i dati?
- Come si fa rollback o re-sync?
- Quali rischi sono specifici per ambienti bancari?

Se una guida non entra nel dettaglio, deve puntare esplicitamente alla guida specialistica corretta.
