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
|---|---|---|
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
