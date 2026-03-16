# OCI Guide: Target Database for GoldenGate and Migration from Local Lab

> This guide explains how to build an Oracle target on Oracle Cloud Infrastructure (OCI) in a manner consistent with your local lab. The focus is not just on creating a VM, but on choosing a target and a network model that are truly compatible with GoldenGate and your local RAC 19c.

---

## 1. Decisione Iniziale: Quale Target Cloud Vuoi Davvero

Before creating OCI resources, you need to choose the correct path.

### Path A - Free and lightweight validation

- OCI Always Free Compute
- Oracle AI Database Free sul target
- eventuale GoldenGate Free sul target

Quando usarlo:

- per imparare OCI;
- to test listener, TNS, network, initial load, schema replication in mini-lab;
- per un ambiente di prova separato e piccolo.

Limiti forti:

- GoldenGate Free e limitato a database Oracle <= 20 GB;
- interagisce solo con altre istanze GoldenGate Free;
- non include entitlement ADG o downstream capture.

Conclusione:

- questo percorso non e quello giusto per una replica formalmente supportata dal tuo RAC 19c + Data Guard locale verso cloud se sul source usi GoldenGate Core/licensed.

### Path B - Local migration -> OCI consistent with the enterprise lab

- OCI Compute targets Oracle
- DB target Oracle installato su compute
- GoldenGate Core/licensed o equivalente supportato su source e target

Quando usarlo:

- for the real migration from the local 19c lab to the cloud;
- per un flusso credibile da DBA enterprise.

Questo e il percorso che considero `corretto` per il tuo lab principale.

---

## 2. Status of Verified Offerings

Check done on `15 marzo 2026` su fonti Oracle ufficiali.

### Regione consigliata per questo repo

Per il lab fissiamo questa scelta:

- `Italy Northwest (Milan)`
- region identifier: `eu-milan-1`

Why I choose Milan:

- e una regione OCI italiana `live`;
- Oracle publishes it as `eu-milan-1`;
- gli `Always Free` si creano nella `home region` of the tenancy, therefore it is better to choose an Italian region that is already stable and mature for the lab;
- Torino (`eu-turin-1`) e stata annunciata piu di recente e non e la scelta base del repo.

Decisione pratica:

- if you create a new tenancy for this lab, use `Milan / eu-milan-1` as home region;
- if you already have a tenancy with a different home region, you can still use the repo, but the path `Always Free` follows the rules of your home region.

### OCI Always Free Compute

Oracle documenta per `VM.Standard.A1.Flex` Always Free:

- fino a `4 OCPU` Ampere A1;
- fino a `24 GB` RAM totale;
- fino a `200 GB` di block volume totale Always Free.

### Oracle AI Database Free

Oracle documenta che il pacchetto attuale disponibile e `Oracle AI Database Free 26ai`, installabile su Linux x86-64 e Arm.

Punti pratici:

- su ARM il database usa `SID FREE`;
- crea `FREE` e `FREEPDB1`;
- listener on `1521`;
- installazione RPM supportata.

### GoldenGate Free

Oracle documenta che GoldenGate Free:

- e pensato per database Oracle <= `20 GB`;
- can only interact with other GoldenGate Free instances;
- non include entitlement `Active Data Guard`;
- non supporta downstream capture.

Questo punto da solo impone disciplina architetturale.

---

## 3. Architettura Raccomandata per il Repo

Per il tuo repo consiglio di separare nettamente due casi.

### Caso 1 - Lab principale

- `source`: RAC 19c locale
- `Data Guard`: DR locale
- `GoldenGate capture`: on primary, not standby
- `target`: OCI Compute Oracle DB
- `rete`: pubblico ristretto o VPN

### Caso 2 - Lab free-only separato

- `source`: Oracle AI Database Free locale o piccolo single instance
- `target`: Oracle AI Database Free su OCI
- `GoldenGate Free`: su entrambi i lati

This second case is useful for learning the UX of GoldenGate Free, but should not be confused with the main RAC 19c lab.

---

## 4. Network: Decide on the Model First

Follow first [GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md](./GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md).

For the OCI target you can choose:

1. `IP pubblico ristretto` al tuo IP di casa: piu rapido.
2. `Site-to-Site VPN`: piu corretto e piu vicino a un ambiente reale.
3. `Overlay VPN`: opzionale da laboratorio.

If you haven't decided on your network model yet, don't go any further with GoldenGate.

---

## 5. Build del Target OCI Compute

### 5.1 Instance creation

Nel portale OCI:

1. `Compute` -> `Instances` -> `Create instance`
2. check that you are in the region `Italy Northwest (Milan) / eu-milan-1`
3. `Shape`: `VM.Standard.A1.Flex`
4. imposta, se disponibile in quota Always Free:
   - `4 OCPU`
   - `24 GB RAM`
5. immagine consigliata:
   - `Oracle Linux 8` se vuoi il percorso piu lineare con Database Free RPM su Arm
6. assegna public IP solo se usi il modello pubblico ristretto
7. put the instance in a subnet with dedicated NSG

### 5.2 Porte minime

Apri solo quelle coerenti col modello scelto:

- `22/tcp` SSH
- `1521/tcp` DB listener
- `7809/tcp` se usi GG classic/core manager
- `9011-9014/tcp` solo se usi microservices

Sorgente raccomandata:

- il tuo `IP pubblico /32`
- oppure la subnet privata locale via VPN

---

## 6. Operating System Bootstrap

Initial example how `root`:

```bash
sudo -s

dnf -y update
hostnamectl set-hostname dbtarget

dnf -y install oraclelinux-developer-release-el8
firewall-cmd --reload
```

Swap raccomandato se fai lab su VM free piccola:

```bash
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
```

---

## 7. Installazione Database Target: Due Opzioni

### 7.1 Opzione pratica Always Free: Oracle AI Database Free 26ai

Questa opzione e la piu semplice da costruire su ARM.

Sequenza documentata da Oracle:

```bash
sudo -s

dnf -y install oracle-ai-database-preinstall-26ai
# scarica l'RPM corretto aarch64 dal sito Oracle
# poi installa l'RPM locale
# esempio nome file ufficiale documentato:
# oracle-database-free-26ai-23.26.0-1.el8.aarch64.rpm

dnf -y install ./oracle-database-free-26ai-23.26.0-1.el8.aarch64.rpm
/etc/init.d/oracle-free-26ai configure
```

What it creates:

- `ORACLE_HOME` sotto `/opt/oracle/product/26ai/dbhomeFree`
- `FREE`
- `FREEPDB1`
- listener `1521`

Nota importante:

- questo target e ottimo per lab, ma non va automaticamente confuso con un target supportato per il lab RAC 19c + GG principale.

### 7.2 Option consistent with enterprise migration

If you want a truly consistent migration with the RAC 19c source, use on the OCI target:

- un Oracle Database versione certificata per il tuo percorso GG;
- GoldenGate Core/licensed o servizio OCI GoldenGate, non GoldenGate Free.

Questa opzione richiede media/licensing o un percorso di evaluation non sempre disponibile nel Free Tier.

---

## 8. Basic Configuration of the Target Database

### 8.1 Variabili ambiente oracle

```bash
su - oracle
cat >> ~/.bash_profile <<'EOF'
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/26ai/dbhomeFree
export ORACLE_SID=FREE
export PATH=$PATH:$ORACLE_HOME/bin
EOF
source ~/.bash_profile
```

### 8.2 Test listeners and databases

```bash
lsnrctl status
sqlplus / as sysdba
show pdbs;
```

### 8.3 Creation of target user for lab

```sql
sqlplus / as sysdba
ALTER SESSION SET CONTAINER=FREEPDB1;

CREATE USER ggadmin IDENTIFIED BY <password>
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION, RESOURCE TO ggadmin;
GRANT SELECT ANY DICTIONARY TO ggadmin;
```

Se il target fara il ruolo di Replicat Oracle:

```sql
GRANT DBA TO ggadmin;
```

Nel lab va bene. In ambienti seri si riducono i privilegi.

---

## 9. GoldenGate sul Target: Regola di Compatibilita

### Se usi GoldenGate Core/licensed nel lab principale

The OCI target must use a compatible and supported GoldenGate deployment.

### Se usi GoldenGate Free

Ricorda i limiti Oracle ufficiali:

- solo con altri GoldenGate Free;
- no ADG entitlement;
- no downstream capture;
- workload piccolo.

Conclusione pratica:

- to migrate from your local RAC 19c to OCI with GoldenGate in the main lab, do not rely on GoldenGate Free as the path `ufficiale` of the basic guide.

---

## 10. Network Test Before GoldenGate

Dai nodi locali:

```bash
ping dbtarget
nc -vz dbtarget 1521
# se usi GG classic/core
nc -vz dbtarget 7809
# se usi microservices
nc -vz dbtarget 9011
nc -vz dbtarget 9014
tnsping DBTARGET
```

Se uno di questi test fallisce, fermati li.

---

## 11. Quale Percorso Useremo nel Repo

Nel repo fisso questa regola:

1. Basic Phase 5: GoldenGate supported with capture on local primary.
2. Target: locale o OCI Compute.
3. OCI Free: ottimo per target DB e networking lab.
4. GoldenGate Free: Treated as a separate variant and not as a prerequisite to the main RAC 19c lab.

---

## 12. What You Must Have Before Automating OCI

Per creare davvero il DB nel tuo tenancy OCI servono:

- accesso al tuo account OCI;
- quota disponibile nel compartment corretto;
- scelta reale di regione/shape/subnet;
- SSH keys or `oci cli` configurati se vuoi automatizzare.

Without these prerequisites, the repo can explain the correct path but cannot replace real provisioning in your tenancy.

---

## 13. Fonti Oracle Ufficiali

- OCI Always Free resources: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- Oracle AI Database Free install guide: https://docs.oracle.com/en/database/oracle/oracle-database-free/get-started/installing-oracle-database-free.html
- GoldenGate Free overview and limitations: https://docs.oracle.com/en/middleware/goldengate/free/23/overview/index.html
- GoldenGate Free FAQ and limits: https://docs.oracle.com/en/middleware/goldengate/free/23/overview/oracle-goldengate-free-faq.html
- OCI network security groups: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/networksecuritygroups.htm

---

## 14. Correct Next Step

The correct step after this guide is:

1. complete Phase 4 Broker well;
2. set the network model with [GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md](./GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md);
3. scegliere se il target cloud e solo `free validation` o `migration target` vero;
4. then follow Phase 5 for GoldenGate with capture on the primary.
