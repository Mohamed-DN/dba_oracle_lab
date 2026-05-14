# Guida Rete: Lab Locale, OCI e GoldenGate

> Questa guida spiega come collegare in modo coerente il lab locale VirtualBox con un target Oracle su Oracle Cloud Infrastructure (OCI). L'obiettivo e chiarire cosa significa davvero `stessa rete`, quando basta l'IP pubblico, quando serve una VPN e quali porte devono essere aperte.

---

## 1. Il Problema Reale

Nel tuo lab esistono tre mondi diversi:

1. rete privata VirtualBox `host-only` del lab locale;
2. rete NAT di VirtualBox usata per uscire su Internet;
3. rete OCI (`VCN`) dove vive il target cloud.

Questi mondi non sono automaticamente la stessa rete.

Schema minimo:

```text
+----------------------- PC HOST / VIRTUALBOX ------------------------+
|                                                                     |
|  Host-only 192.168.56.0/24         NAT 10.0.2.0/24                  |
|  rac1 rac2 racstby1 racstby2  ----> uscita Internet                 |
|                                                                     |
+-------------------------------+-------------------------------------+
                                |
                                | Internet / WAN
                                v
+-------------------------- OCI / VCN -------------------------------+
|                                                                    |
|  Subnet privata o pubblica                                         |
|  dbtarget / compute instance / listener / GoldenGate               |
|                                                                    |
+--------------------------------------------------------------------+
```

Conclusione:

- `host-only` locale non raggiunge da solo OCI;
- OCI non raggiunge da sola la rete `192.168.56.x`;
- serve un modello di connettivita esplicito.

---

## 2. Cosa Vuol Dire Davvero `Stessa Rete`

Ci sono tre significati diversi.

### 2.1 Stessa rete logica applicativa

Basta che le macchine si risolvano e si raggiungano sulle porte corrette.

Questo e sufficiente per GoldenGate nella maggior parte dei lab.

### 2.2 Stessa rete privata instradata

Le macchine locali e OCI si vedono via IP privati, tipicamente con:

- Site-to-Site VPN;
- FastConnect;
- overlay VPN.

Questo e il modello enterprise serio.

### 2.3 Stessa rete solo nominale via `/etc/hosts`

Non basta mappare un nome in `/etc/hosts` se non esiste connettivita reale.

`/etc/hosts` risolve un nome. Non crea il routing.

---

## 3. Modelli Supportati per il Lab

### 3.1 Modello A - Lab semplice con IP pubblico OCI

Usi:

- i nodi locali escono via NAT;
- il target OCI ha un IP pubblico;
- apri in OCI solo le porte minime, limitate al tuo IP pubblico di casa.

Pro:

- semplice;
- rapido;
- nessun appliance VPN.

Contro:

- non e una vera rete privata condivisa;
- dipende dall'IP pubblico di casa;
- meno elegante del modello enterprise.

Quando usarlo:

- per il lab base GoldenGate verso cloud.

### 3.2 Modello B - Site-to-Site VPN con OCI

Usi:

- VCN OCI;
- Dynamic Routing Gateway;
- IPSec VPN tra casa/lab e OCI.

Pro:

- vera estensione privata della rete;
- modello enterprise corretto;
- IP privati end-to-end.

Contro:

- piu complesso;
- richiede firewall/router o VM gateway.

Quando usarlo:

- se vuoi davvero dire che il target cloud e `sulla stessa rete privata` del lab.

### 3.3 Modello C - Overlay VPN opzionale

Usi una mesh VPN software tra lab locale e OCI.

Pro:

- facile da mettere su;
- evita aperture ampie su Internet.

Contro:

- non e il modello Oracle/enterprise di riferimento;
- va trattato come opzione di comodita per laboratorio.

Quando usarlo:

- se vuoi una rete privata rapida senza costruire una IPSec completa.

---

## 4. Modello Raccomandato nel Repo

Per il repo consiglio due livelli.

### Livello 1 - Percorso base documentato

- target OCI compute con IP pubblico;
- NSG o Security List molto restrittive;
- listener e GoldenGate esposti solo verso il tuo IP pubblico di casa;
- traffico applicativo minimo e controllato.

### Livello 2 - Percorso avanzato

- Site-to-Site VPN OCI;
- IP privati tra lab e cloud;
- stesso naming interno per `dbtarget.localdomain`;
- nessun listener DB aperto al mondo.

---

## 5. Porte da Conoscere

### 5.1 Oracle Net

- `1521/tcp`: listener DB tradizionale.

### 5.2 GoldenGate Classic/Core

- `7809/tcp`: Manager classico.
- porte trail/processi: tipicamente un range tipo `7810-7820/tcp`.

### 5.3 GoldenGate Microservices

Porte tipiche:

- `9011/tcp`: Service Manager
- `9012/tcp`: Administration Server
- `9013/tcp`: Distribution Server
- `9014/tcp`: Receiver Server

### 5.4 SSH

- `22/tcp`: amministrazione host.

Regola pratica:

- apri solo le porte che servono davvero al modello scelto;
- non aprire Web UI GoldenGate al mondo senza restrizioni;
- per il lab pubblico usa sorgente limitata al tuo IP pubblico.

---

## 6. NSG e Security List in OCI

In OCI puoi filtrare traffico con:

- `Security List` a livello subnet;
- `Network Security Group (NSG)` a livello VNIC/istanza.

Per il lab e meglio usare NSG dedicate al target.

Esempio minimo per target DB Oracle + GoldenGate:

- ingress `22/tcp` da `TUO_IP_PUBBLICO/32`
- ingress `1521/tcp` da `TUO_IP_PUBBLICO/32`
- ingress `7809/tcp` da `TUO_IP_PUBBLICO/32` se usi classic GG
- ingress `9011-9014/tcp` da `TUO_IP_PUBBLICO/32` solo se usi microservices
- egress `all` oppure minima uscita necessaria

Nota importante:

- se il tuo IP pubblico cambia spesso, questo modello diventa scomodo;
- in quel caso VPN o Bastion sono piu puliti.

---

## 7. Come Rendere Raggiungibile `dbtarget`

### 7.1 Naming lato locale

Su `rac1`, `rac2`, `racstby1`, `racstby2` puoi usare:

```text
130.x.x.x   dbtarget.localdomain   dbtarget
```

o l'IP privato VPN, se esiste.

### 7.2 TNS lato locale

Esempio:

```text
DBTARGET =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = dbtarget.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = DBTARGET)
    )
  )
```

### 7.3 Test obbligatori

```bash
ping dbtarget
nc -vz dbtarget 1521
nc -vz dbtarget 7809
tnsping DBTARGET
```

Se questi test non passano, GoldenGate non e il problema. E la rete.

---

## 8. Site-to-Site VPN: Come Collegare Davvero il Lab e OCI

Il modello Oracle corretto per `stessa rete privata` e:

1. `VCN` in OCI con subnet target;
2. `DRG` associato alla VCN;
3. `Customer Premises Equipment (CPE)` che rappresenta il tuo lato locale;
4. `IPSec Connection` tra OCI e il tuo router/firewall o VM gateway locale;
5. route rules da entrambi i lati.

Schema:

```text
Lab locale 192.168.56.0/24
        |
        | router/firewall o VM gateway
        |
   IPSec tunnel
        |
        v
OCI DRG -> VCN -> subnet -> dbtarget
```

Con questo modello puoi usare:

- IP privati verso il target;
- listener e GoldenGate non esposti pubblicamente;
- naming interno coerente.

---

## 9. Bastion, VPN o IP Pubblico?

### Usa Bastion quando:

- vuoi fare SSH amministrativo senza aprire `22/tcp` al mondo.

### Usa VPN quando:

- vuoi rete privata vera tra locale e OCI;
- vuoi far sembrare il target `dentro` il tuo perimetro di rete.

### Usa IP pubblico limitato quando:

- vuoi solo un lab rapido e controllato;
- sai bene quali porte aprire;
- capisci che non e lo stesso livello di un ambiente enterprise.

---

## 10. GoldenGate: Quale flusso di rete serve davvero?

Per migrazione locale -> OCI con GoldenGate servono almeno due percorsi.

### 10.1 Percorso source -> target Manager/Receiver

Il source deve raggiungere:

- `7809` se usi Manager classico;
- oppure `9014`/Distribution-Receiver se usi microservices.

### 10.2 Percorso source -> target DB listener

Serve per:

- `tnsping`;
- Replicat se girasse sul target;
- test operativi e initial load.

### 10.3 Percorso SSH amministrativo

Serve per:

- installazione;
- troubleshooting;
- trasferimento file se non usi object storage.

---

## 11. Checklist Rete Prima di Toccare GoldenGate

Esegui questi check nell'ordine.

### Sul target OCI

- VM `RUNNING`
- firewall OS coerente
- NSG/Security List coerenti
- listener attivo
- DB aperto
- GoldenGate Manager o microservices attivi se gia installati

### Dai nodi locali

- risoluzione nome `dbtarget`
- `ping` o almeno reachability IP
- `nc -vz dbtarget 1521`
- `nc -vz dbtarget 7809` oppure porte microservices
- `tnsping DBTARGET`

### Sul target

- `lsnrctl status`
- `ss -ltnp | grep -E '1521|7809|9011|9012|9013|9014|22'`

---

## 12. Errori Tipici da Evitare

1. pensare che `/etc/hosts` crei connettivita.
2. aprire la porta DB ma non la porta GoldenGate.
3. aprire la porta in OCI ma dimenticare il firewall Linux interno.
4. usare nomi TNS corretti ma porte sbagliate.
5. usare un target cloud che risponde in browser ma non al listener DB.
6. confondere `host-only` VirtualBox con Internet-routable.
7. credere che `stessa rete` significhi solo stesso dominio DNS.

---

## 13. Fonti Oracle Ufficiali

- OCI Site-to-Site VPN: https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/managingIPsec.htm
- OCI Bastion: https://docs.oracle.com/en-us/iaas/Content/Bastion/Concepts/bastionoverview.htm
- OCI Network Security Groups: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/networksecuritygroups.htm
- OCI FastConnect overview: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/fastconnectoverview.htm
- Oracle Net Listener Admin: https://docs.oracle.com/en/database/oracle/oracle-database/19/netag/configuring-and-administering-oracle-net-listener.html

---

## 14. Decisione Pratica per il Tuo Lab

Se vuoi muoverti senza perdere tempo:

1. inizia con target OCI su IP pubblico ristretto al tuo IP di casa;
2. fai funzionare DB listener e GoldenGate end-to-end;
3. solo dopo, se vuoi fare le cose come in azienda, passa a Site-to-Site VPN.

Questa e la sequenza pragmatica corretta.
