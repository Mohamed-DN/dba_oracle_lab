# UC04 - GoldenGate per AI Ready Data

> Obiettivo: rendere dati operativi freschi disponibili a pipeline AI, RAG, vector search e analytics avanzati, senza fare dump manuali non governati.

Guide correlate:

- [Novita GoldenGate 26ai](../GUIDA_GOLDENGATE_26AI_NOVITA.md)
- [Use Case e Knowledge Hub](../GUIDA_GOLDENGATE_USE_CASES_KNOWLEDGE_HUB.md)
- [Ambienti critici/bancari](../GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md)

Fonte Oracle utile:

- GoldenGate 23ai e AI/vector context: https://blogs.oracle.com/dataintegration/post/announcing-goldengate-23ai

---

## 1. Concetto

AI-ready non significa mandare tutto a un modello AI. Significa costruire una pipeline affidabile, sicura e aggiornata che trasforma dati operativi in dati consumabili da sistemi AI.

```text
OLTP / CRM / Core Banking
        |
        | CDC affidabile
        v
GoldenGate
        |
        +--> curated data store
        +--> event stream
        +--> embedding pipeline
        +--> vector DB / AI Vector Hub / RAG index
```

---

## 2. Quando GoldenGate serve davvero

Serve quando:

- devi aggiornare un indice RAG quasi in tempo reale;
- devi alimentare feature store o data product operativi;
- devi portare change event verso pipeline AI senza query pesanti sul source;
- devi avere audit trail dei cambiamenti;
- devi separare sistemi core da piattaforme AI.

Non serve se il requisito e' solo esportare un dataset statico una volta.

---

## 3. Requisiti bancari

| Tema | Regola |
|---|---|
| PII | classificare, minimizzare, mascherare o tokenizzare |
| Dati sensibili | vietato inviare fuori perimetro senza approvazione |
| Prompt/RAG | non indicizzare campi non autorizzati |
| Audit | tracciare chi consuma il dato e dove finisce |
| Cifratura | TLS in transito, encryption at rest per trail/stage |
| Retention | policy chiara per eventi e vettori |

---

## 4. Pattern operativo

```text
Oracle Source -> Extract -> Trail -> Replicat/Handler -> Landing curated -> AI pipeline
```

La generazione embedding non deve stare nel database core. Meglio separarla in una pipeline downstream controllata.

---

## 5. Controlli prima di partire

```text
[ ] Data owner approva i campi replicati.
[ ] Security approva target AI/vector.
[ ] DPO/privacy approva PII e retention.
[ ] GoldenGate trasporta solo tabelle/colonne necessarie.
[ ] Target ha cifratura e audit.
[ ] Esiste procedura di delete/right-to-be-forgotten se applicabile.
[ ] Esiste monitoraggio freshness del dato.
```

---

## 6. Domande tecniche

**GoldenGate crea embedding?**

GoldenGate trasporta cambiamenti. L'embedding di solito viene generato da pipeline downstream o servizi AI. GoldenGate rende la pipeline aggiornata e affidabile.

**Qual e' il rischio principale in banca?**

Mandare dati sensibili verso sistemi AI senza data governance. Il punto non e' solo tecnico, e' anche compliance.

**Perche' usare CDC per RAG?**

Per mantenere l'indice aggiornato senza rebuild massivi e senza query continue sui sistemi core.
