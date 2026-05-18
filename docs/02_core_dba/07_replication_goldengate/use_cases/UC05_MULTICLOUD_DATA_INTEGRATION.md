# UC05 - GoldenGate per Multicloud Data Integration

> Obiettivo: sincronizzare dati tra on-premises, OCI, AWS, Azure, Google Cloud o SaaS/data platform, rispettando rete segregata e policy enterprise.

Guide correlate:

- [Ambienti critici/bancari](../GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md)
- [Collegamento Source e Target](../GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md)
- [Cloud GoldenGate](../../../03_infra_lab/03_cloud_oci/GUIDA_CLOUD_GOLDENGATE.md)
- [Rete Lab OCI GoldenGate](../../../03_infra_lab/03_cloud_oci/GUIDA_RETE_LAB_OCI_GOLDENGATE.md)

---

## 1. Architettura concettuale

```text
On-prem DC                         Cloud / altro DC
=========                          ================
Oracle RAC                         Target DB / Kafka / Lakehouse
OGG Extract                        OGG Receiver/Replicat
Private network / VPN / FastConnect / IPSec / approved public endpoint
```

---

## 2. Pattern di rete

| Pattern | Quando usarlo | Nota |
| --- | --- | --- |
| Source-initiated | source puo' aprire verso target | semplice ma spesso bloccato in banca |
| Target-initiated | target apre verso source/Distribution | utile quando inbound verso target non e' permesso |
| Hub GoldenGate | tante source/target e zone diverse | centralizza controllo ma diventa componente critico |
| Reverse proxy | esporre solo 443/HTTPS | consigliato per Microservices con TLS |
| Private connectivity | VPN/FastConnect/ExpressRoute/Interconnect | preferibile su dati critici |

---

## 3. Checklist multicloud

```text
[ ] Regione cloud approvata, per esempio Italia/Milano se richiesto.
[ ] Data residency verificata.
[ ] Cifratura in transito obbligatoria.
[ ] Cifratura at rest su trail/stage/target.
[ ] DNS risolvibile in entrambe le zone autorizzate.
[ ] Firewall aperto solo su porte richieste.
[ ] Nessuna password nei file parametro.
[ ] Monitoring centralizzato.
[ ] Runbook in caso link cloud down.
```

---

## 4. Sizing rete

Stima minima:

```text
redo medio giornaliero -> redo medio orario -> picco -> banda richiesta
```

Regola pratica:

- dimensionare per il picco, non solo per la media;
- considerare LOB e batch applicativi;
- considerare backlog se la rete cade;
- dimensionare trail retention per recovery window.

---

## 5. Errori comuni

- Aprire firewall troppo larghi per fare prima.
- Non testare failover DNS/VPN.
- Non considerare latenza tra regioni.
- Mettere Extract lontano dal source aumentando dipendenza rete.
- Non definire chi gestisce certificati e rinnovi.

---

## 6. Domande tecniche

**GoldenGate lavora bene tra cloud diversi?**

Si, se la certificazione source/target e la rete sono progettate correttamente. Il limite reale spesso non e' GoldenGate ma firewall, latency, bandwidth, DNS, TLS e governance.

**Quando uso target-initiated path?**

Quando il target puo' iniziare la connessione ma il source o una DMZ non puo' aprire connessioni inbound verso il target.

---

## Percorso operativo da zero

Prima di implementare questo use case in laboratorio o in UAT:

1. Leggi [Prerequisiti DB e Architettura](../GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md).
2. Applica [Grant e Privilegi 19c](../GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).
3. Configura [Collegamento Source e Target](../GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md).
4. Valida rete e sicurezza con [Ambienti critici/bancari](../GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md).
5. Esegui il [Runbook End-to-End 19c](../GUIDA_GOLDENGATE_RUNBOOK_END_TO_END_19C.md).
6. Usa [Cheat Sheet GoldenGate 19c](../CHEAT_SHEET_GOLDENGATE_19C.md) per i comandi rapidi.

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
## Approfondimento specifico UC05

In multicloud, il problema principale e' quasi sempre la rete:

```text
DNS -> routing -> firewall -> TLS -> proxy -> throughput -> osservabilita
```

Prima della configurazione GoldenGate chiedi sempre:

- chi apre la connessione, source o target;
- se serve target-initiated distribution path;
- se si usa VPN/FastConnect/ExpressRoute/Interconnect;
- dove sono terminati TLS e certificati;
- chi rinnova i certificati;
- se i dati possono uscire dalla regione o dal paese;
- cosa succede se il link cloud cade per 4/8/24 ore.

Il sizing trail deve coprire il peggiore outage di rete approvato.
