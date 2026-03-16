# Network Guide: Local Lab, OCI and GoldenGate

> This guide explains how to consistently connect your VirtualBox local lab with an Oracle target on Oracle Cloud Infrastructure (OCI). The goal is to clarify what `stessa rete` really means, when the public IP is enough, when a VPN is needed and which ports must be opened.

---

## 1. Il Problema Reale

Nel tuo lab esistono tre mondi diversi:

1. private network VirtualBox `host-only` of the local lab;
2. VirtualBox NAT network used to go out to the Internet;
3. OCI network (`VCN`) where the target cloud lives.

These worlds are not automatically the same network.

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
|  dbtarget/compute instance/listener/GoldenGate               |
|                                                                    |
+--------------------------------------------------------------------+
```

Conclusione:

- Local `host-only` does not reach OCI on its own;
- OCI does not reach the `192.168.56.x` network on its own;
- an explicit connectivity model is needed.

---

## 2. What `Stessa Rete` Really Means

Ci sono tre significati diversi.

### 2.1 Same application logic network

Basta che le macchine si risolvano e si raggiungano sulle porte corrette.

Questo e sufficiente per GoldenGate nella maggior parte dei lab.

### 2.2 Same private network routed

Local and OCI machines are seen via private IPs, typically with:

- Site-to-Site VPN;
- FastConnect;
- overlay VPN.

Questo e il modello enterprise serio.

### 2.3 Same network only nominal via `/etc/hosts`

Non basta mappare un nome in `/etc/hosts` se non esiste connettivita reale.

`/etc/hosts` risolve un nome. Non crea il routing.

---

## 3. Modelli Supportati per il Lab

### 3.1 Model A - Simple lab with OCI public IP

Usi:

- i nodi locali escono via NAT;
- il target OCI ha un IP pubblico;
- open only minimal ports in OCI, limited to your home public IP.

Pro:

- semplice;
- rapido;
- nessun appliance VPN.

Contro:

- it is not a true shared private network;
- dipende dall'IP pubblico di casa;
- meno elegante del modello enterprise.

Quando usarlo:

- for the GoldenGate base lab towards the cloud.

### 3.2 Model B - Site-to-Site VPN with OCI

Usi:

- VCN OCI;
- Dynamic Routing Gateway;
- IPSec VPN tra casa/lab e OCI.

Pro:

- true private extension of the network;
- modello enterprise corretto;
- IP privati end-to-end.

Contro:

- piu complesso;
- richiede firewall/router o VM gateway.

Quando usarlo:

- if you really mean that the cloud target is `sulla stessa rete privata` of the lab.

### 3.3 Modello C - Overlay VPN opzionale

Usi una mesh VPN software tra lab locale e OCI.

Pro:

- facile da mettere su;
- evita aperture ampie su Internet.

Contro:

- non e il modello Oracle/enterprise di riferimento;
- it should be treated as a convenience option for the laboratory.

Quando usarlo:

- if you want a fast private network without building a full IPSec.

---

## 4. Modello Raccomandato nel Repo

Per il repo consiglio due livelli.

### Livello 1 - Percorso base documentato

- target OCI compute with public IP;
- NSG o Security List molto restrittive;
- listener and GoldenGate exposed only to your home public IP;
- traffico applicativo minimo e controllato.

### Livello 2 - Percorso avanzato

- Site-to-Site VPN OCI;
- IP privati tra lab e cloud;
- same internal naming for `dbtarget.localdomain`;
- no open DB listener in the world.

---

## 5. Porte da Conoscere

### 5.1 Oracle Net

- `1521/tcp`: Traditional DB listener.

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

- open only the doors that are really needed for the chosen model;
- do not open Web UI GoldenGate to the world without restrictions;
- per il lab pubblico usa sorgente limitata al tuo IP pubblico.

---

## 6. NSG e Security List in OCI

In OCI you can filter traffic with:

- `Security List` a livello subnet;
- `Network Security Group (NSG)` at VNIC/instance level.

Per il lab e meglio usare NSG dedicate al target.

Minimum example for Oracle + GoldenGate DB target:

- ingress `22/tcp` da `TUO_IP_PUBBLICO/32`
- ingress `1521/tcp` da `TUO_IP_PUBBLICO/32`
- ingress `7809/tcp` da `TUO_IP_PUBBLICO/32` se usi classic GG
- input `9011-9014/tcp` from `TUO_IP_PUBBLICO/32` only if you use microservices
- egress `all` oppure minima uscita necessaria

Nota importante:

- se il tuo IP pubblico cambia spesso, questo modello diventa scomodo;
- in quel caso VPN o Bastion sono piu puliti.

---

## 7. How to Make `dbtarget` Reachable

### 7.1 Naming lato locale

Su `rac1`, `rac2`, `racstby1`, `racstby2` you can use:

```text
130.x.x.x   dbtarget.localdomain   dbtarget
```

o l'IP privato VPN, se esiste.

### 7.2 TNS lato locale

Example:

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

If these tests fail, GoldenGate is not the problem. And the network.

---

## 8. Site-to-Site VPN: How to Really Connect the Lab and OCI

The correct Oracle model for `stessa rete privata` is:

1. `VCN` in OCI with target subnet;
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

With this template you can use:

- private IPs towards the target;
- listeners and GoldenGate not publicly exposed;
- naming interno coerente.

---

## 9. Bastion, VPN o IP Pubblico?

### Usa Bastion quando:

- you want to do administrative SSH without opening `22/tcp` to the world.

### Usa VPN quando:

- you want true private network between local and OCI;
- you want to make the `dentro` target look like your network perimeter.

### Usa IP pubblico limitato quando:

- you just want a quick, controlled lab;
- sai bene quali porte aprire;
- understand that it is not the same level as an enterprise environment.

---

## 10. GoldenGate: What network flow do you really need?

For local migration -> OCI with GoldenGate you need at least two paths.

### 10.1 Percorso source -> target Manager/Receiver

The source must achieve:

- `7809` se usi Manager classico;
- oppure `9014`/Distribution-Receiver se usi microservices.

### 10.2 Path source -> target DB listener

It is used for:

- `tnsping`;
- Replicat if it ran on target;
- test operativi e initial load.

### 10.3 Percorso SSH amministrativo

It is used for:

- installazione;
- troubleshooting;
- trasferimento file se non usi object storage.

---

## 11. Network Checklist Before Touching GoldenGate

Esegui questi check nell'ordine.

### On the OCI target

- VM `RUNNING`
- firewall OS coerente
- NSG/Security List coerenti
- active listener
- DB aperto
- GoldenGate Manager o microservices attivi se gia installati

### Dai nodi locali

- risoluzione nome `dbtarget`
- `ping` o almeno reachability IP
- `nc -vz dbtarget 1521`
- `nc -vz dbtarget 7809` oppure porte microservices
- `tnsping DBTARGET`

### On target

- `lsnrctl status`
- `ss -ltnp | grep -E '1521|7809|9011|9012|9013|9014|22'`

---

## 12. Errori Tipici da Evitare

1. pensare che `/etc/hosts` crei connettivita.
2. aprire la porta DB ma non la porta GoldenGate.
3. aprire la porta in OCI ma dimenticare il firewall Linux interno.
4. usare nomi TNS corretti ma porte sbagliate.
5. use a cloud target that responds to the browser but not to the DB listener.
6. confuse `host-only` VirtualBox with Internet-routable.
7. believe that `stessa rete` just means same DNS domain.

---

## 13. Fonti Oracle Ufficiali

- OCI Site-to-Site VPN: https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/managingIPsec.htm
- OCI Bastion: https://docs.oracle.com/en-us/iaas/Content/Bastion/Concepts/bastionoverview.htm
- OCI Network Security Groups: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/networksecuritygroups.htm
- OCI FastConnect overview: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/fastconnectoverview.htm
- Oracle Net Listener Admin: https://docs.oracle.com/en/database/oracle/oracle-database/19/netag/configuring-and-administering-oracle-net-listener.html

---

## 14. Decisione Pratica per il Tuo Lab

If you want to move without wasting time:

1. start with targeting OCI on public IP restricted to your home IP;
2. make DB listener and GoldenGate work end-to-end;
3. only then, if you want to do things like in the company, switch to Site-to-Site VPN.

Questa e la sequenza pragmatica corretta.
