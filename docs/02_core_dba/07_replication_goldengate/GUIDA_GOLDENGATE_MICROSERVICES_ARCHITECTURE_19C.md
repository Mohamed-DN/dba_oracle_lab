# Oracle GoldenGate 19c - Microservices Architecture

> Guida operativa per Oracle GoldenGate 19c Microservices Architecture (MA). Questo e' il percorso consigliato per nuove implementazioni: gestione via Web UI, Admin Client e REST API, con deployment separati e servizi dedicati.

---

## 1. Perche' Microservices

GoldenGate Microservices Architecture sostituisce l'approccio monolitico Classic con servizi indipendenti e API-first.

Vantaggi:

- gestione via browser;
- automazione via REST API;
- separazione ruoli e utenti;
- deployment multipli sulla stessa macchina;
- migliore integrazione con monitoring moderno;
- percorso naturale verso GoldenGate 26ai.

Classic non sparisce dagli ambienti reali, ma per nuovi setup conviene saper usare MA.

---

## 2. Componenti MA

```text
HOST SOURCE                                             HOST TARGET
====================================================    ================================================

+----------------------+                                +----------------------+
| Service Manager      |                                | Service Manager      |
| porta 9011           |                                | porta 9011           |
+----------+-----------+                                +----------+-----------+
           |                                                       |
           v                                                       v
+----------------------+                                +----------------------+
| Administration Server|                                | Administration Server|
| porta 9012           |                                | porta 9012           |
| gestisce Extract     |                                | gestisce Replicat    |
+----------+-----------+                                +----------+-----------+
           |                                                       ^
           v                                                       |
+----------------------+     WebSocket/HTTP(S)          +----------------------+
| Distribution Server  | ============================> | Receiver Server      |
| porta 9013           |                                | porta 9014           |
| invia trail          |                                | riceve trail         |
+----------------------+                                +----------------------+
```

| Servizio | Cosa fa |
| --- | --- |
| Service Manager | Gestisce deployment locali, inventory, lifecycle dei servizi. |
| Administration Server | Crea, modifica, start/stop Extract e Replicat. |
| Distribution Server | Spedisce trail file verso target tramite path. |
| Receiver Server | Riceve trail file remoti. |
| Performance Metrics Server | Espone metriche e statistiche. |
| Admin Client | CLI moderna simile a `ggsci`, ma connessa al deployment MA. |
| REST API | Automazione HTTP/JSON per processi, configurazioni e path. |

---

## 3. Directory e variabili

Layout raccomandato:

```bash
/u01/app/oracle/product/ogg19c_ma     # OGG_HOME software read-mostly
/u01/app/oracle/ogg_deployments       # deployment home
/u01/app/oracle/ogg_var               # var/log/trail/config runtime
/u01/app/oracle/ogg_stage             # staging patch/backup
```

Variabili utili:

```bash
export OGG_HOME=/u01/app/oracle/product/ogg19c_ma
export OGG_VAR_HOME=/u01/app/oracle/ogg_var/SourceDeploy
export OGG_ETC_HOME=/u01/app/oracle/ogg_var/SourceDeploy/etc
export PATH=$OGG_HOME/bin:$PATH
```

Best practice:

- non mischiare Oracle DB home e OGG home;
- tenere deployment e software separati;
- backup di deployment prima di patch/upgrade;
- usare filesystem con spazio e monitoring per trail/log.

---

## 4. Installazione software 19c MA

Esempio silent generico:

```bash
cd /stage/ogg19c
unzip V*.zip -d /stage/ogg19c
cd /stage/ogg19c/fbo_ggs_Linux_x64_services_shiphome/Disk1

./runInstaller -silent \
  -responseFile response/oggcore.rsp \
  INSTALL_OPTION=ORA19c \
  SOFTWARE_LOCATION=/u01/app/oracle/product/ogg19c_ma \
  UNIX_GROUP_NAME=oinstall \
  INVENTORY_LOCATION=/u01/app/oraInventory
```

Verifica:

```bash
/u01/app/oracle/product/ogg19c_ma/bin/adminclient -version
```

---

## 5. Creazione deployment

Con `oggca.sh` puoi creare deployment source e target.

Source:

```bash
export OGG_HOME=/u01/app/oracle/product/ogg19c_ma
$OGG_HOME/bin/oggca.sh
```

Parametri concettuali:

| Campo | Source example |
| --- | --- |
| Deployment name | `SourceDeploy` |
| Service Manager | `9011` |
| Administration Server | `9012` |
| Distribution Server | `9013` |
| Receiver Server | `9014` |
| Deployment home | `/u01/app/oracle/ogg_deployments/SourceDeploy` |
| Security | TLS in produzione, HTTP solo lab |

Target:

| Campo | Target example |
| --- | --- |
| Deployment name | `TargetDeploy` |
| Service Manager | `9011` |
| Administration Server | `9012` |
| Receiver Server | `9014` |
| Deployment home | `/u01/app/oracle/ogg_deployments/TargetDeploy` |

---

## 6. Credential store

In MA le credenziali DB si configurano da Web UI o Admin Client. Non scrivere password nei parameter file.

Admin Client:

```text
$OGG_HOME/bin/adminclient
CONNECT http://rac1:9012 DEPLOYMENT SourceDeploy AS oggadmin PASSWORD <PASSWORD_DEPLOYMENT>

ADD CREDENTIALSTORE
ALTER CREDENTIALSTORE ADD USER c##ggadmin@RACDB PASSWORD <PASSWORD_DB> ALIAS ggsrc DOMAIN OracleGoldenGate
INFO CREDENTIALSTORE
```

Target:

```text
CONNECT http://dbtarget:9012 DEPLOYMENT TargetDeploy AS oggadmin PASSWORD <PASSWORD_DEPLOYMENT>
ADD CREDENTIALSTORE
ALTER CREDENTIALSTORE ADD USER ggadmin@DBTARGET PASSWORD <PASSWORD_DB> ALIAS ggtgt DOMAIN OracleGoldenGate
INFO CREDENTIALSTORE
```

---

## 7. Integrated Extract

### 7.1 Register Extract

```text
CONNECT http://rac1:9012 DEPLOYMENT SourceDeploy AS oggadmin PASSWORD <PASSWORD_DEPLOYMENT>
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
REGISTER EXTRACT ext_rac DATABASE
```

### 7.2 Create Extract

```text
ADD EXTRACT ext_rac, INTEGRATED TRANLOG, BEGIN NOW
ADD EXTTRAIL ea, EXTRACT ext_rac, MEGABYTES 200
```

Parameter file:

```text
EXTRACT ext_rac
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
EXTTRAIL ea
LOGALLSUPCOLS
UPDATERECORDFORMAT COMPACT
REPORTCOUNT EVERY 5 MINUTES, RATE
WARNLONGTRANS 1H, CHECKINTERVAL 10M
TABLE HR.*;
TABLE APP.*;
```

Avvio:

```text
START EXTRACT ext_rac
INFO EXTRACT ext_rac, DETAIL
LAG EXTRACT ext_rac
```

---

## 8. Distribution Path

Il Distribution Server sostituisce il Data Pump Classic.

Da Web UI:

1. Source Distribution Server.
2. Add Path.
3. Source trail: `ea`.
4. Target host: `dbtarget`.
5. Target Receiver Server port: `9014`.
6. Target trail: `rt`.
7. Start path.

Da REST/API il concetto e' lo stesso: creare un path che legge local trail e scrive remote trail.

Verifica:

```text
INFO DISTPATH *
```

Se il path resta fermo:

- controlla firewall porta Receiver;
- controlla TLS/certificati se HTTPS;
- controlla spazio target;
- controlla credenziali deployment.

---

## 9. Receiver Server

Il Receiver salva i remote trail.

Controlli:

```bash
ls -lh /u01/app/oracle/ogg_deployments/TargetDeploy/var/lib/data
```

In UI verifica:

- path connected;
- bytes received;
- remote trail sequence;
- error log Receiver.

---

## 10. Integrated Replicat

Prima di creare Replicat, verifica che l'utente target abbia i privilegi `APPLY` tramite `DBMS_GOLDENGATE_AUTH` e i grant DML sulle tabelle target. Dettaglio completo: [GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).

### 10.1 Checkpoint table

```text
CONNECT http://dbtarget:9012 DEPLOYMENT TargetDeploy AS oggadmin PASSWORD <PASSWORD_DEPLOYMENT>
DBLOGIN USERIDALIAS ggtgt DOMAIN OracleGoldenGate
ADD CHECKPOINTTABLE GGADMIN.GG_CHECKPOINT
```

### 10.2 Create Replicat

```text
ADD REPLICAT rep_tgt, INTEGRATED, EXTTRAIL rt, CHECKPOINTTABLE GGADMIN.GG_CHECKPOINT
```

Parameter file:

```text
REPLICAT rep_tgt
USERIDALIAS ggtgt DOMAIN OracleGoldenGate
ASSUMETARGETDEFS
DISCARDFILE ./dirrpt/rep_tgt.dsc, APPEND, MEGABYTES 500
REPORTCOUNT EVERY 5 MINUTES, RATE
BATCHSQL
MAP HR.*, TARGET HR.*;
MAP APP.*, TARGET APP.*;
```

Start:

```text
START REPLICAT rep_tgt
INFO REPLICAT rep_tgt, DETAIL
LAG REPLICAT rep_tgt
STATS REPLICAT rep_tgt, TOTAL
```

---

## 11. Initial load e start point

Il target deve essere instanziato a uno SCN coerente.

Pattern sicuro:

1. Avvia Extract o registra start SCN.
2. Esegui Data Pump con `FLASHBACK_SCN` o `FLASHBACK_TIME`.
3. Importa target.
4. Avvia Replicat da CSN/SCN corretto.

Esempio:

```sql
SELECT current_scn FROM v$database;
```

```bash
expdp system schemas=HR directory=DATA_PUMP_DIR dumpfile=hr_%U.dmp logfile=hr_exp.log flashback_scn=123456789 parallel=4
impdp system schemas=HR directory=DATA_PUMP_DIR dumpfile=hr_%U.dmp logfile=hr_imp.log parallel=4
```

Start Replicat:

```text
START REPLICAT rep_tgt, AFTERCSN 123456789
```

---

## 12. Operazioni giornaliere MA

Morning check:

```text
INFO EXTRACT *
INFO REPLICAT *
LAG EXTRACT ext_rac
LAG REPLICAT rep_tgt
STATS EXTRACT ext_rac, TOTAL
STATS REPLICAT rep_tgt, TOTAL
```

Controlli OS:

```bash
df -h /u01/app/oracle/ogg_deployments
find /u01/app/oracle/ogg_deployments -name "*.rpt" -mtime -1 -ls
find /u01/app/oracle/ogg_deployments -name "ggserr.log" -exec tail -100 {} \;
```

Controlli DB:

```sql
SELECT name, open_mode, database_role FROM v$database;
SELECT force_logging, supplemental_log_data_min FROM v$database;
SELECT file_type, percent_space_used FROM v$flash_recovery_area_usage;
```

---

## 13. Troubleshooting MA

| Sintomo | Causa probabile | Verifica |
| --- | --- | --- |
| Admin Server non accessibile | servizio fermo/firewall | Service Manager UI, porta 9012 |
| Path fermo | Receiver non raggiungibile | log Distribution/Receiver |
| Extract ABENDED | archivelog mancante, privilegi, supplement logging | report Extract, alert DB |
| Replicat ABENDED | constraint, mapping, dati mancanti | discard file, report Replicat |
| Lag alto | throughput, I/O, target lento | stats, AWR, OS metrics |
| Login DB fallisce | credential alias errato | `INFO CREDENTIALSTORE` |

---

## 14. Sicurezza MA

Produzione:

- TLS abilitato;
- utenti deployment nominali;
- password in wallet/credential store;
- niente password nei param file;
- firewall solo porte necessarie;
- audit accessi UI/API;
- backup wallet e deployment.

Lab:

- HTTP puo' essere accettabile per imparare, ma documenta che non e' produzione.

---

## 15. Fonti ufficiali

- Componenti MA: https://docs.oracle.com/en/middleware/goldengate/core/19.1/coredoc/overview-components-oracle-goldengate-microservices-architecture.html
- Access points MA: https://docs.oracle.com/en/middleware/goldengate/core/19.1/coredoc/overview-access-points-oracle-goldengate-microservices.html
- REST API 19c: https://docs.oracle.com/en/middleware/goldengate/core/19.1/oggra/QuickStart.html

## Obiettivo
Descrivere l’adozione dell’architettura Microservices 19c con focus su Service Manager e servizi Admin/Distribution/Receiver.

## Procedura operativa
Configurare deployment Microservices, utenti e wallet, endpoint REST, distribuzione trail e gestione processi via console/API.

## Validazione finale
Verificare stato servizi, reachability endpoint, health deployment e corretto flusso dati tra Distribution e Receiver.

## Troubleshooting rapido
Se un servizio risulta degraded, controllare log Service Manager, porte API, certificati e binding dei deployment.
