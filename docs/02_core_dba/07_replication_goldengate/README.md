# Replica & Migrazione - GoldenGate 19c / 26ai

> Area dedicata a Oracle GoldenGate. Il percorso principale e' **GoldenGate 19c**, perche' e' la versione piu comune negli ambienti enterprise esistenti. Le guide 26ai servono per capire evoluzione, novita e upgrade.

## Percorso consigliato

| Ordine | Guida | Cosa impari |
| --- | --- | --- |
| 1 | [Prerequisiti DB e Architettura](./GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md) | Logging, supplemental logging, GGADMIN, FRA, trail, gate pre-configurazione |
| 2 | [Grant e Privilegi 19c](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md) | `DBMS_GOLDENGATE_AUTH`, CDB/PDB, target DML, PostgreSQL, no `GRANT DBA` |
| 3 | [GoldenGate 19c Completa](./GUIDA_GOLDENGATE_19C_COMPLETA.md) | Concetti enterprise: Extract, Replicat, trail, checkpoint, RAC/DG, troubleshooting |
| 4 | [Collegamento Source e Target](./GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md) | TNS, credential store, Distribution/Receiver, Classic Pump, PostgreSQL/ODBC, firewall |
| 5 | [Ambienti critici/bancari](./GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md) | Rete segregata, TLS/WSS/mTLS, target-initiated path, reverse proxy, audit e governance |
| 6 | [Microservices Architecture 19c](./GUIDA_GOLDENGATE_MICROSERVICES_ARCHITECTURE_19C.md) | Service Manager, Admin Server, Distribution Server, Receiver Server, Admin Client, REST |
| 7 | [Classic Architecture 19c](./GUIDA_GOLDENGATE_CLASSIC_ARCHITECTURE_19C.md) | Manager, GGSCI, Extract, Pump, Collector, Replicat, parameter file |
| 8 | [Oracle -> PostgreSQL](./GUIDA_GOLDENGATE_ORACLE_TO_POSTGRESQL.md) | Replica eterogenea, datatype mapping, initial load, cutover |
| 9 | [Cheat Sheet GoldenGate 19c](./CHEAT_SHEET_GOLDENGATE_19C.md) | Comandi rapidi GGSCI, Admin Client, SQL, troubleshooting |
| 10 | [Q&A Tecnico Professionale](./GUIDA_GOLDENGATE_QA_PROFESSIONALE.md) | Domande/risposte su architettura, errori, scenari e upgrade |
| 11 | [Use Case, Topologie e Knowledge Hub](./GUIDA_GOLDENGATE_USE_CASES_KNOWLEDGE_HUB.md) | Data fabric, topologie, top 7 use case con guide operative dedicate |
| 12 | [Novita GoldenGate 26ai](./GUIDA_GOLDENGATE_26AI_NOVITA.md) | Cosa cambia in 26ai e quando valutarlo |
| 13 | [Upgrade 19c -> 26ai](./GUIDA_GOLDENGATE_UPGRADE_19C_TO_26AI.md) | Upgrade Microservices, percorso Classic, backup, rollback, validazioni |

## Guide pratiche del lab

| Guida | Cosa impari |
| --- | --- |
| [Fase 7: GoldenGate](./GUIDA_FASE7_GOLDENGATE.md) | Lab pratico con Microservices Architecture |
| [Migrazione GoldenGate](./GUIDA_MIGRAZIONE_GOLDENGATE.md) | Zero-downtime migration Oracle -> Oracle |
| [Oracle -> PostgreSQL legacy](./GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md) | Pattern esistente di migrazione eterogenea |
| [Use Case operativi](./use_cases/README.md) | Runbook dedicati per migrazioni, HA, analytics, AI-ready data, multicloud, application streams e stream analytics |

## Template utili

- [Testlog GoldenGate Template](./TESTLOG_GOLDENGATE_TEMPLATE.md)

## Fonti principali

- Oracle GoldenGate 19c Microservices: https://docs.oracle.com/en/middleware/goldengate/core/19.1/coredoc/overview-components-oracle-goldengate-microservices-architecture.html
- Oracle GoldenGate Classic/GGSCI: https://docs.oracle.com/en/middleware/goldengate/core/18.1/reference/oracle-goldengate-ggsci-commands.html
- Oracle GoldenGate Knowledge Hub: https://www.oracle.com/integration/goldengate/knowledge-hub/
- Oracle GoldenGate 26ai: https://docs.oracle.com/en/database/goldengate/core/26/index.html
- Oracle GoldenGate Certifications: https://www.oracle.com/integration/goldengate/certifications/

---

Indice area core DBA: [../README.md](../README.md)
