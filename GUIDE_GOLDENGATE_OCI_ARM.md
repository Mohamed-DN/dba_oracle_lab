# OCI Guide: Target Database for GoldenGate and Migration from Local Lab

> This guide explains how to build an Oracle target on Oracle Cloud Infrastructure (OCI) in a manner consistent with your local lab. The focus is not just on creating a VM, but on choosing a target and a network model that are truly compatible with GoldenGate and your local RAC 19c.

---

## 1. Initial Decision: Which Target Cloud Do You Really Want

Before creating OCI resources, you need to choose the correct path.

### Path A - Free and lightweight validation

- OCI Always Free Compute
- Oracle AI Database Free sul target
- eventuale GoldenGate Free sul target

Quando usarlo:

- per imparare OCI;
- to test listener, TNS, network, initial load, schema replication in mini-lab;
- for a separate and small test environment.

Limiti forti:

- GoldenGate Free and limited to Oracle databases <= 20 GB;
- interacts only with other GoldenGate Free instances;
- non include entitlement ADG o downstream capture.

Conclusion:

- this path is not the right one for a replication formally supported by your local RAC 19c + Data Guard to the cloud if you use GoldenGate Core/licensed on the source.

### Path B - Local migration -> OCI consistent with the enterprise lab

- OCI Compute targets Oracle
- Oracle target DB installed on compute
- GoldenGate Core/licensed or equivalent supported on source and target

Quando usarlo:

- for the real migration from the local 19c lab to the cloud;
- for a credible flow from enterprise DBA.

This is the path I consider`corretto`for your main lab.

---

## 2. Status of Verified Offerings

Check done on `15 marzo 2026`on official Oracle sources.

### Recommended region for this repo

For the lab we set this choice:

- `Italy Northwest (Milan)`
- region identifier:`eu-milan-1`

Why I choose Milan:

- and an Italian OCI region`live`;
- Oracle publishes it as `eu-milan-1`;
- gli `Always Free` si creano nella `home region` of the tenancy, therefore it is better to choose an Italian region that is already stable and mature for the lab;
- Torino (`eu-turin-1`) was announced more recently and is not the default repo choice.

Practical decision:

- if you create a new tenancy for this lab, use `Milan / eu-milan-1` as home region;
- if you already have a tenancy with a different home region, you can still use the repo, but the path `Always Free` follows the rules of your home region.

### OCI Always Free Compute

Oracle documenta per `VM.Standard.A1.Flex` Always Free:

- fino a `4 OCPU` Ampere A1;
- fino a `24 GB`total RAM;
- fino a `200 GB`total block volume Always Free.

### Oracle AI Database Free

Oracle documents that the current package available e`Oracle AI Database Free 26ai`, installabile su Linux x86-64 e Arm.

Practical points:

- su ARM il database usa `SID FREE`;
- crea `FREE` e `FREEPDB1`;
- listener on `1521`;
- RPM installation supported.

### GoldenGate Free

Oracle documenta che GoldenGate Free:

- and designed for Oracle databases <=`20 GB`;
- can only interact with other GoldenGate Free instances;
- non include entitlement `Active Data Guard`;
- non supporta downstream capture.

This point alone imposes architectural discipline.

---

##3. Recommended Repo Architecture

For your repo I recommend clearly separating two cases.

### Case 1 - Main Lab

- `source`: local RAC 19c
- `Data Guard`: local DR
- `GoldenGate capture`: on primary, not standby
- `target`: OCI Compute Oracle DB
- `network`: restricted public IP or VPN

### Case 2 - Separate free-only lab

- `source`: local Oracle AI Database Free or a small single instance
- `target`: Oracle AI Database Free su OCI
- `GoldenGate Free`: su entrambi i lati

This second case is useful for learning the UX of GoldenGate Free, but should not be confused with the main RAC 19c lab.

---

## 4. Network: Decide on the Model First

Follow first [GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md](./GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md).

For the OCI target you can choose:

1. `IP pubblico ristretto`to your home IP: faster.
2. `Site-to-Site VPN`: more correct and closer to a real environment.
3. `Overlay VPN`: optional for laboratory.

If you haven't decided on your network model yet, don't go any further with GoldenGate.

---

## 5. Build del Target OCI Compute

### 5.1 Instance creation

In the OCI portal:

1. `Compute` -> `Instances` -> `Create instance`
2. check that you are in the region `Italy Northwest (Milan) / eu-milan-1`
3. `Shape`: `VM.Standard.A1.Flex`
4. set, if available in Always Free quota:
   - `4 OCPU`
   - `24 GB RAM`
5. Recommended image:
   - `Oracle Linux 8`if you want the most linear path with Database Free RPM on Arm
6. assign public IP only if you use the restricted public model
7. put the instance in a subnet with dedicated NSG

### 5.2 Porte minime

Open only those consistent with the chosen model:

- `22/tcp` SSH
- `1521/tcp` DB listener
- `7809/tcp`if you use GG classic/core manager
- `9011-9014/tcp`only if you use microservices

Recommended source:

- il tuo `IP pubblico /32`
- or the local private subnet via VPN

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

Recommended swap if you do lab on small free VM:

```bash
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
```

---

## 7. Target Database Installation: Two Options

### 7.1 Opzione pratica Always Free: Oracle AI Database Free 26ai

This option is the simplest to build on ARM.

Sequence documented by Oracle:

```bash
sudo -s

dnf -y install oracle-ai-database-preinstall-26ai
#download the correct aarch64 RPM from the Oracle site
# then install the local RPM
#example documented official file name:
# oracle-database-free-26ai-23.26.0-1.el8.aarch64.rpm

dnf -y install ./oracle-database-free-26ai-23.26.0-1.el8.aarch64.rpm
/etc/init.d/oracle-free-26ai configure
```

What it creates:

- `ORACLE_HOME` sotto `/opt/oracle/product/26ai/dbhomeFree`
- `FREE`
- `FREEPDB1`
- listener `1521`

Important note:

- this target is great for labs, but should not be automatically confused with a target supported for the main RAC 19c + GG lab.

### 7.2 Option consistent with enterprise migration

If you want a truly consistent migration with the RAC 19c source, use on the OCI target:

- an Oracle Database certified version for your GG path;
- GoldenGate Core/licensed o servizio OCI GoldenGate, non GoldenGate Free.

This option requires media/licensing or an evaluation path not always available in the Free Tier.

---

## 8. Basic Configuration of the Target Database

### 8.1 Oracle environment variables

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

If the target will play the role of Replicat Oracle:

```sql
GRANT DBA TO ggadmin;
```

In the lab it's fine. In serious environments, privileges are reduced.

---

## 9. GoldenGate on Target: Compatibility Rule

### If you use GoldenGate Core/licensed in the main lab

The OCI target must use a compatible and supported GoldenGate deployment.

### Se usi GoldenGate Free

Remember the official Oracle limits:

- only with other GoldenGate Free;
- no ADG entitlement;
- no downstream capture;
- workload piccolo.

Practical conclusion:

- to migrate from your local RAC 19c to OCI with GoldenGate in the main lab, do not rely on GoldenGate Free as the path `ufficiale` of the basic guide.

---

## 10. Network Test Before GoldenGate

From local nodes:

```bash
ping dbtarget
nc -vz dbtarget 1521
# if you use GG classic/core
nc -vz dbtarget 7809
# if you use microservices
nc -vz dbtarget 9011
nc -vz dbtarget 9014
tnsping DBTARGET
```

If any of these tests fail, stop there.

---

## 11. Which Path We Will Use in the Repo

In the repo I set this rule:

1. Basic Phase 5: GoldenGate supported with capture on local primary.
2. Target: locale o OCI Compute.
3. OCI Free: ottimo per target DB e networking lab.
4. GoldenGate Free: Treated as a separate variant and not as a prerequisite to the main RAC 19c lab.

---

## 12. What You Must Have Before Automating OCI

To actually create the DB in your OCI tenancy you need:

- access to your OCI account;
- quota available in the correct compartment;
- real choice of region/shape/subnet;
- SSH keys or `oci cli`configured if you want to automate.

Without these prerequisites, the repo can explain the correct path but cannot replace real provisioning in your tenancy.

---

##13. Official Oracle Sources

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
3. choose if the target cloud is only`free validation` o `migration target` vero;
4. then follow Phase 5 for GoldenGate with capture on the primary.
