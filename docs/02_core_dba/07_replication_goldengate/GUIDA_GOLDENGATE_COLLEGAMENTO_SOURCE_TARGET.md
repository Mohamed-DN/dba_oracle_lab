# GoldenGate 19c - Collegamento Source e Target

> Punto fondamentale: in GoldenGate **non e' il database source che si collega direttamente al database target** per replicare. Sono i processi GoldenGate che si collegano ai rispettivi database e si parlano tra loro via trail file e rete. Per ambienti bancari o regolati leggi anche [GoldenGate in Ambienti Critici Bancari](./GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md).

---

## 1. Modello mentale corretto

```text
SBAGLIATO come modello principale:

Oracle Source DB  ----------------------->  Target DB
                 DB link diretto CDC

CORRETTO in GoldenGate:

Oracle Source DB        GoldenGate Source Host          GoldenGate Target Host        Target DB
===============        ======================          ======================        =========
Redo / Archive   -->   Extract -> Local Trail   -->    Remote Trail -> Replicat -->  Tabelle
                            |                                  |
                            |                                  |
                            +-- connessione DB source          +-- connessione DB target
                            +-- Distribution/Pump ------------> Receiver/Manager
```

Il collegamento e' composto da tre livelli:

| Livello | Cosa collega | Serve per |
| --- | --- | --- |
| DB source connection | Extract/Admin Server -> Oracle source | leggere metadata, registrare Extract, capture |
| GoldenGate transport | Pump/Distribution -> Manager/Receiver target | spedire trail file |
| DB target connection | Replicat/Admin Server -> DB target | applicare DML/DDL sul target |

Un database link Oracle puo' servire per initial load via Data Pump `NETWORK_LINK` o controlli, ma **non e' il meccanismo normale della replica CDC GoldenGate**.

---

## 2. Architettura Microservices 19c

```text
SOURCE SIDE                                                       TARGET SIDE
===========================================================       =============================================

Oracle RACDB listener/SCAN :1521                                  Target DB listener :1521 / PostgreSQL :5432
        ^                                                                       ^
        |                                                                       |
        | DB credential ggsrc                                                   | DB credential ggtgt / ggpg
        |                                                                       |
+-----------------------+        HTTPS/WSS/WS        +-----------------------+  |
| Administration Server |                            | Administration Server |  |
| Extract EXT_RAC       |                            | Replicat REP_TGT      |--+
+-----------+-----------+                            +-----------+-----------+
            |                                                    ^
            v                                                    |
+-----------------------+      trail network path      +-----------------------+
| Distribution Server   | ---------------------------> | Receiver Server       |
| legge local trail ea  |                              | scrive remote trail rt|
+-----------------------+                              +-----------------------+
```

Connessioni minime:

| Da | A | Porta | Protocollo | Perche' |
| --- | --- | --- | --- | --- |
| Source OGG host | Source DB SCAN/listener | 1521 | TCP Oracle Net | Extract metadata/capture |
| Source Distribution Server | Target Receiver Server | 9014 | WS/WSS/HTTP(S) | invio trail |
| Target OGG host | Target Oracle listener | 1521 | TCP Oracle Net | Replicat apply Oracle |
| Target OGG host | PostgreSQL target | 5432 | TCP/libpq/ODBC | Replicat apply PostgreSQL |
| Admin client/browser | Admin Server | 9012 | HTTP(S) | amministrazione |
| Browser | Service Manager | 9011 | HTTP(S) | lifecycle deployment |

---

## 3. Architettura Classic 19c

```text
SOURCE HOST                                               TARGET HOST
====================================================      ======================================

Oracle RACDB :1521                                        Target DB :1521 / 5432
      ^                                                             ^
      |                                                             |
      | DBLOGIN ggsrc                                               | DBLOGIN ggtgt
      |                                                             |
+-------------+       +-------------+      TCP 7809       +-------------+       +-------------+
| Extract     | ----> | Local Trail | ---- Pump --------> | RemoteTrail | ----> | Replicat    |
| EXT_RAC     |       | ./dirdat/ea |                     | ./dirdat/rt |       | REP_TGT     |
+-------------+       +-------------+                     +-------------+       +-------------+
                              |                                  ^
                              |                                  |
                         Manager source                    Manager target / Collector
```

Connessioni Classic:

| Da | A | Porta | Parametro |
| --- | --- | --- | --- |
| Extract | Source Oracle DB | 1521 | `USERIDALIAS ggsrc` |
| Pump | Target Manager | 7809 | `RMTHOST target, MGRPORT 7809` |
| Target Manager/Collector | Remote trail filesystem | locale | `RMTTRAIL ./dirdat/rt` |
| Replicat | Target DB | 1521/5432 | `USERIDALIAS ggtgt` / `TARGETDB` |

---

## 4. TNS per Oracle source e target

### 4.1 Source RACDB via SCAN

Nel `$ORACLE_HOME/network/admin/tnsnames.ora` usato dall'utente GoldenGate/Oracle:

```text
RACDB_GG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = RACDB)
    )
  )
```

### 4.2 Target Oracle

```text
DBTARGET_GG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = dbtarget.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = DBTARGET)
    )
  )
```

### 4.3 Test connessione Oracle

Dal source GoldenGate host:

```bash
tnsping RACDB_GG
sqlplus c##ggadmin/<PASSWORD_SICURA>@RACDB_GG
```

Dal target GoldenGate host:

```bash
tnsping DBTARGET_GG
sqlplus ggadmin/<PASSWORD_SICURA>@DBTARGET_GG
```

Per evitare password in shell history, usa login interattivo o wallet/credential store.

---

## 5. Credential store Microservices

Source deployment:

```text
Admin Client> CONNECT http://rac1:9012 DEPLOYMENT SourceDeploy AS oggadmin PASSWORD <PASSWORD_DEPLOYMENT>
Admin Client> ADD CREDENTIALSTORE
Admin Client> ALTER CREDENTIALSTORE ADD USER c##ggadmin@RACDB_GG PASSWORD <PASSWORD_DB> ALIAS ggsrc DOMAIN OracleGoldenGate
Admin Client> INFO CREDENTIALSTORE
```

Target deployment Oracle:

```text
Admin Client> CONNECT http://dbtarget:9012 DEPLOYMENT TargetDeploy AS oggadmin PASSWORD <PASSWORD_DEPLOYMENT>
Admin Client> ADD CREDENTIALSTORE
Admin Client> ALTER CREDENTIALSTORE ADD USER ggadmin@DBTARGET_GG PASSWORD <PASSWORD_DB> ALIAS ggtgt DOMAIN OracleGoldenGate
Admin Client> INFO CREDENTIALSTORE
```

Uso nei parameter file:

```text
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
USERIDALIAS ggtgt DOMAIN OracleGoldenGate
```

---

## 6. Collegamento Distribution Server -> Receiver Server

In Microservices, il collegamento tra source e target e' il **Distribution Path**.

Parametri concettuali:

| Campo | Esempio |
| --- | --- |
| Path name | `RAC_TO_TGT` |
| Source trail | `ea` |
| Target host | `dbtarget.localdomain` |
| Target receiver port | `9014` |
| Target trail | `rt` |
| Protocollo | `ws` in lab, `wss` in produzione |

Test rete:

```bash
# Dal source OGG host verso target Receiver
nc -vz dbtarget.localdomain 9014
curl -k https://dbtarget.localdomain:9014/services/v2/status
```

Se usi HTTP lab:

```bash
curl http://dbtarget.localdomain:9014/services/v2/status
```

Problemi tipici:

| Sintomo | Causa |
| --- | --- |
| Path non parte | Receiver giu, porta chiusa, protocollo sbagliato |
| Path running ma zero bytes | trail source errato o Extract fermo |
| Errori TLS | certificati/wallet non coerenti |
| Trail cresce sul source | target non riceve o rete bloccata |

---

## 7. Collegamento Classic Pump -> Manager target

Parameter file Pump:

```text
EXTRACT pump_rac
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
RMTHOST dbtarget.localdomain, MGRPORT 7809
RMTTRAIL ./dirdat/rt
PASSTHRU
TABLE HR.*;
```

Test rete:

```bash
nc -vz dbtarget.localdomain 7809
```

Sul target:

```text
GGSCI> INFO MANAGER
GGSCI> SEND MANAGER STATUS
```

Se usi `DYNAMICPORTLIST`, apri anche il range configurato:

```text
PORT 7809
DYNAMICPORTLIST 7810-7820
```

---

## 8. Collegamento Oracle -> PostgreSQL

Qui Extract si collega a Oracle, Replicat si collega a PostgreSQL.

```text
Oracle Source :1521 -> Extract -> Trail -> Replicat -> PostgreSQL :5432
```

### 8.1 Test PostgreSQL

Dal target OGG host:

```bash
psql -h pg-target.localdomain -p 5432 -U ggadmin -d appdb
```

### 8.2 DSN ODBC concettuale

`odbc.ini`:

```ini
[PG_APP]
Driver=PostgreSQL Unicode
Servername=pg-target.localdomain
Port=5432
Database=appdb
Username=ggadmin
Password=<PASSWORD_SICURA>
```

`odbcinst.ini`:

```ini
[PostgreSQL Unicode]
Driver=/usr/lib64/psqlodbcw.so
Setup=/usr/lib64/libodbcpsqlS.so
```

Test:

```bash
isql -v PG_APP ggadmin <PASSWORD_SICURA>
```

In produzione evita password in file leggibili: usa meccanismi supportati dal prodotto/versione e permessi OS stretti.

---

## 9. DB link: quando serve davvero

DB link Oracle non e' richiesto per la replica CDC GoldenGate.

Serve eventualmente per:

- Data Pump `NETWORK_LINK` durante initial load Oracle->Oracle;
- query di confronto source/target;
- validazioni manuali.

Esempio initial load:

```sql
CREATE DATABASE LINK source_racdb_link
CONNECT TO ggadmin IDENTIFIED BY "<PASSWORD_SICURA>"
USING 'RACDB_GG';

SELECT current_scn FROM v$database@source_racdb_link;
```

Non usarlo per sostituire Extract/Replicat.

---

## 10. Matrix firewall del lab

| Flusso | Porta | Necessario per |
| --- | --- | --- |
| OGG source -> Oracle source SCAN | 1521 | Extract |
| OGG target -> Oracle target | 1521 | Replicat Oracle |
| OGG target -> PostgreSQL target | 5432 | Replicat PostgreSQL |
| OGG source -> OGG target Receiver | 9014 | MA Distribution Path |
| Admin/browser -> Service Manager | 9011 | gestione MA |
| Admin/browser -> Admin Server | 9012 | Extract/Replicat MA |
| Admin/browser -> Distribution Server | 9013 | path MA |
| Pump Classic -> Manager target | 7809 | Classic trail shipping |
| Pump Classic -> dynamic collector | 7810-7820 | Classic dynamic ports |

Regola produzione: aprire solo direzioni e porte necessarie, preferire TLS, documentare firewall e DNS.

---

## 11. Checklist end-to-end

- [ ] DNS risolve source e target.
- [ ] `tnsping RACDB_GG` OK.
- [ ] `sqlplus ggadmin@RACDB_GG` OK.
- [ ] `tnsping DBTARGET_GG` o `psql` target OK.
- [ ] Credential store contiene alias source/target.
- [ ] Extract fa DBLOGIN con `USERIDALIAS`.
- [ ] Distribution Path o Pump raggiunge target.
- [ ] Remote trail viene creato sul target.
- [ ] Replicat fa login al target.
- [ ] Test DML source arriva al target.
- [ ] Lag e stats sono visibili.

---

## 12. Fonti ufficiali

- GoldenGate Microservices components: https://docs.oracle.com/en/middleware/goldengate/core/19.1/coredoc/overview-components-oracle-goldengate-microservices-architecture.html
- GoldenGate access points: https://docs.oracle.com/en/middleware/goldengate/core/19.1/coredoc/overview-access-points-oracle-goldengate-microservices.html
- GoldenGate Classic/GGSCI commands: https://docs.oracle.com/en/middleware/goldengate/core/18.1/reference/oracle-goldengate-ggsci-commands.html