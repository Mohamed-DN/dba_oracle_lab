# UC06 - GoldenGate per Application Data Streams

> Obiettivo: trasformare cambiamenti transazionali del database in eventi consumabili da applicazioni, microservizi o piattaforme event-driven.

Guide correlate:

- [GoldenGate 19c Completa](../GUIDA_GOLDENGATE_19C_COMPLETA.md)
- [Collegamento Source e Target](../GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md)
- [Ambienti critici/bancari](../GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md)

Fonte Oracle utile:

- GoldenGate Big Data 19c: https://docs.oracle.com/en/middleware/goldengate/big-data/19.1/gadbd/using-oracle-goldengate-big-data.pdf

---

## 1. Concetto

```text
Oracle / OLTP table change
        |
        v
GoldenGate CDC
        |
        v
Kafka / JMS / OCI Streaming / Event Hub / application topic
        |
        v
Microservices / cache / search / notification / integration layer
```

GoldenGate permette di pubblicare eventi derivati da commit reali del database, senza modificare subito l'applicazione legacy.

---

## 2. Quando usarlo

- modernizzazione applicativa graduale;
- integrazione legacy -> microservizi;
- aggiornamento cache/search index;
- notifica eventi di business;
- feed verso sistemi downstream senza query polling.

---

## 3. Disegno eventi

| Tema | Decisione |
| --- | --- |
| Topic | per tabella, dominio o aggregate business |
| Payload | before/after image, operation type, timestamp, transaction id |
| Ordering | per key/partition, non globale se non necessario |
| Idempotenza | consumer deve tollerare retry o duplicati |
| Schema | schema registry o contratto payload versionato |
| Sicurezza | niente PII non autorizzata nel messaggio |

---

## 4. Parametri concettuali utili

GoldenGate Big Data/handler puo' esporre metadata come:

```text
operation type: INSERT / UPDATE / DELETE
commit timestamp
source table
transaction id
before/after columns se configurato
```

Il punto chiave e' disegnare il payload come contratto applicativo, non semplicemente scaricare righe grezze.

---

## 5. Pattern outbox vs CDC

| Pattern | Pro | Contro |
| --- | --- | --- |
| Outbox applicativa | evento business esplicito | richiede modifica applicazione |
| GoldenGate CDC | nessuna modifica app legacy iniziale | evento tecnico da trasformare in evento business |

In banca spesso si parte con CDC per disaccoppiare, poi si evolve verso eventi business governati.

---

## 6. Domande tecniche

**GoldenGate garantisce exactly-once?**

GoldenGate garantisce checkpoint e delivery affidabile, ma lato sistemi di streaming/consumer devi progettare idempotenza e gestione duplicati.

**Posso pubblicare ogni tabella come topic?**

Tecnicamente si, ma non e' sempre buona architettura. Meglio ragionare per dominio dati, sicurezza e consumer reali.

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
## Approfondimento specifico UC06

Per application streams, non pubblicare eventi senza contratto.

Contratto minimo evento:

```text
schema_version
source_system
source_table o business_domain
primary_key
operation_type
commit_timestamp
transaction_id
payload before/after secondo policy
classification: public/internal/confidential/restricted
```

Il consumer deve essere idempotente: GoldenGate e la piattaforma streaming possono ritentare delivery; il consumer non deve corrompere lo stato se riceve lo stesso evento due volte.
