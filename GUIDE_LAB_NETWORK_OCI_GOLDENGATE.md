# Network Guide: Local Lab, OCI and GoldenGate

> This guide explains how to consistently connect your VirtualBox local lab with an Oracle target on Oracle Cloud Infrastructure (OCI). The goal is to clarify what `same network` really means, when the public IP is enough, when a VPN is needed, and which ports must be opened.

---

## 1. The Real Problem

In your lab there are three different worlds:

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
|  Private or public subnet |
|  dbtarget/compute instance/listener/GoldenGate               |
|                                                                    |
+--------------------------------------------------------------------+
```

Conclusion:

- Local `host-only` does not reach OCI on its own;
- OCI does not reach the `192.168.56.x` network on its own;
- an explicit connectivity model is needed.

---

## 2. What `Stessa Rete` Really Means

There are three different meanings.

### 2.1 Same application logic network

Just let the cars resolve and reach the correct doors.

This is sufficient for GoldenGate in most labs.

### 2.2 Same private network routed

Local and OCI machines are seen via private IPs, typically with:

- Site-to-Site VPN;
- FastConnect;
- overlay VPN.

This is the serious enterprise model.

### 2.3 Same network only nominal via `/etc/hosts`

It's not enough to map a name to`/etc/hosts`if there is no real connectivity.

`/etc/hosts` risolve un nome. Non crea il routing.

---

## 3. Supported Lab Templates

### 3.1 Model A - Simple lab with OCI public IP

Usi:

- local nodes exit via NAT;
- the OCI target has a public IP;
- open only minimal ports in OCI, limited to your home public IP.

Pro:

- simple;
- rapido;
- no VPN appliances.

Contro:

- it is not a true shared private network;
- depends on your home public IP;
- less elegant than the enterprise model.

Quando usarlo:

- for the GoldenGate base lab towards the cloud.

### 3.2 Model B - Site-to-Site VPN with OCI

Usi:

- VCN OCI;
- Dynamic Routing Gateway;
- IPSec VPN tra casa/lab e OCI.

Pro:

- true private extension of the network;
- correct enterprise model;
- End-to-end private IPs.

Contro:

- piu complesso;
- richiede firewall/router o VM gateway.

Quando usarlo:

- if you really mean that the cloud target is `on the same private network` as the lab.

### 3.3 Model C - Optional overlay VPN

You use a software VPN mesh between local lab and OCI.

Pro:

- easy to put on;
- evita aperture ampie su Internet.

Contro:

- it is not the Oracle/enterprise model of reference;
- it should be treated as a convenience option for the laboratory.

Quando usarlo:

- if you want a fast private network without building a full IPSec.

---

## 4. Model Recommended in the Repo

For the repo I recommend two levels.

### Level 1 - Documented basic path

- target OCI compute with public IP;
- NSG o Security List molto restrittive;
- listener and GoldenGate exposed only to your home public IP;
- minimal and controlled application traffic.

### Level 2 - Advanced path

- Site-to-Site VPN OCI;
- private IPs between lab and cloud;
- same internal naming for `dbtarget.localdomain`;
- no open DB listener in the world.

---

## 5. Porte da Conoscere

### 5.1 Oracle Net

- `1521/tcp`: Traditional DB listener.

### 5.2 GoldenGate Classic/Core

- `7809/tcp`: Manager classico.
- trail/process ports: typically a typical range`7810-7820/tcp`.

### 5.3 GoldenGate Microservices

Typical doors:

- `9011/tcp`: Service Manager
- `9012/tcp`: Administration Server
- `9013/tcp`: Distribution Server
- `9014/tcp`: Receiver Server

### 5.4 SSH

- `22/tcp`: host administration.

Rule of thumb:

- open only the doors that are really needed for the chosen model;
- do not open Web UI GoldenGate to the world without restrictions;
- for the public lab use source limited to your public IP.

---

## 6. NSG e Security List in OCI

In OCI you can filter traffic with:

- `Security List` a livello subnet;
- `Network Security Group (NSG)` at VNIC/instance level.

For the lab it is better to use NSG dedicated to the target.

Minimum example for Oracle + GoldenGate DB target:

- ingress `22/tcp` da `TUO_IP_PUBBLICO/32`
- ingress `1521/tcp` da `TUO_IP_PUBBLICO/32`
- ingress `7809/tcp` da `TUO_IP_PUBBLICO/32` se usi classic GG
- input `9011-9014/tcp` from `TUO_IP_PUBBLICO/32` only if you use microservices
- egress `all`or minimum output necessary

Important note:

- if your public IP changes often, this model becomes inconvenient;
- in that case VPN or Bastion are cleaner.

---

## 7. How to Make `dbtarget` Reachable

### 7.1 Local side naming

Su `rac1`, `rac2`, `racstby1`, `racstby2` you can use:

```text
130.x.x.x   dbtarget.localdomain   dbtarget
```

or the VPN private IP, if it exists.

### 7.2 TNS local side

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

The correct Oracle model for `same private network` is:

1. `VCN` in OCI with target subnet;
2. `DRG` associated with the VCN;
3. `Customer Premises Equipment (CPE)` representing your local side;
4. `IPSec Connection` tra OCI e il tuo router/firewall o VM gateway locale;
5. route rules on both sides.

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
- consistent internal naming.

---

## 9. Bastion, VPN or Public IP?

### Use Bastion when:

- you want to do administrative SSH without opening `22/tcp` to the world.

### Usa VPN quando:

- you want true private network between local and OCI;
- you want to make the `dentro` target look like your network perimeter.

### Use restricted public IP when:

- you just want a quick, controlled lab;
- you know well which doors to open;
- understand that it is not the same level as an enterprise environment.

---

## 10. GoldenGate: What network flow do you really need?

For local migration -> OCI with GoldenGate you need at least two paths.

### 10.1 Percorso source -> target Manager/Receiver

The source must achieve:

- `7809`if you use Classic Manager;
- oppure `9014`/Distribution-Receiver se usi microservices.

### 10.2 Path source -> target DB listener

It is used for:

- `tnsping`;
- Replicat if it ran on target;
- operational tests and initial load.

### 10.3 Administrative SSH path

It is used for:

- installation;
- troubleshooting;
- file transfer if you don't use object storage.

---

## 11. Network Checklist Before Touching GoldenGate

Perform these checks in order.

### On the OCI target

- VM `RUNNING`
- firewall OS coerente
- NSG/Security List coerenti
- active listener
- DB open
- GoldenGate Manager or microservices active if already installed

### From local nodes

- name resolution`dbtarget`
- `ping` o almeno reachability IP
- `nc -vz dbtarget 1521`
- `nc -vz dbtarget 7809` oppure porte microservices
- `tnsping DBTARGET`

### On target

- `lsnrctl status`
- `ss -ltnp | grep -E '1521|7809|9011|9012|9013|9014|22'`

---

## 12. Typical Mistakes to Avoid

1. think that`/etc/hosts`you create connectivity.
2. aprire la porta DB ma non la porta GoldenGate.
3. open the port in OCI but forget the internal Linux firewall.
4. use correct TNS names but the wrong ports.
5. use a cloud target that responds to the browser but not to the DB listener.
6. confuse `host-only` VirtualBox with Internet-routable.
7. believe that `same network` just means the same DNS domain.

---

## 13. Official Oracle Sources

- OCI Site-to-Site VPN: https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/managingIPsec.htm
- OCI Bastion: https://docs.oracle.com/en-us/iaas/Content/Bastion/Concepts/bastionoverview.htm
- OCI Network Security Groups: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/networksecuritygroups.htm
- OCI FastConnect overview: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/fastconnectoverview.htm
- Oracle Net Listener Admin: https://docs.oracle.com/en/database/oracle/oracle-database/19/netag/configuring-and-administering-oracle-net-listener.html

---

## 14. Practical Decision for Your Lab

If you want to move without wasting time:

1. start with targeting OCI on public IP restricted to your home IP;
2. make DB listener and GoldenGate work end-to-end;
3. only then, if you want to do things like in the company, switch to Site-to-Site VPN.

This is the correct pragmatic sequence.
