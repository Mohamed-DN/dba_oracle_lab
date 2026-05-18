# GoldenGate 19c - Runbook End-to-End per Implementazione Use Case

> Runbook unico da usare come procedura operativa per costruire un flusso GoldenGate 19c da zero. Le guide use case spiegano il perche' e il disegno; questa guida spiega il come operativo: assessment, grant, collegamento, Extract, Distribution/Pump, Replicat, heartbeat, validazione, cutover e troubleshooting.

---

## 0. Quando usare questo runbook

Usalo per questi use case:

- [UC01 - No Downtime Migrations](./use_cases/UC01_NO_DOWNTIME_MIGRATIONS.md)
- [UC02 - High Availability](./use_cases/UC02_HIGH_AVAILABILITY.md)
- [UC03 - Analytical Data Ingest](./use_cases/UC03_ANALYTICAL_DATA_INGEST.md)
- [UC04 - AI Ready Data](./use_cases/UC04_AI_READY_DATA.md)
- [UC05 - Multicloud Data Integration](./use_cases/UC05_MULTICLOUD_DATA_INTEGRATION.md)
- [UC06 - Application Data Streams](./use_cases/UC06_APPLICATION_DATA_STREAMS.md)
- [UC07 - Stream Processing and Analytics](./use_cases/UC07_STREAM_PROCESSING_ANALYTICS.md)

L'ordine consigliato e':

1. [Prerequisiti DB e Architettura](./GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md)
2. [Grant e Privilegi](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md)
3. [Collegamento Source e Target](./GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md)
4. [Ambienti critici/bancari](./GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md)
5. questa guida runbook

---

## 1. Disegno architetturale minimo

```text
SOURCE DB Oracle 19c/RAC
  |
  | redo / archive log
  v
Extract integrato
  |
  v
Local trail
  |
  +-- Microservices Distribution Path --> Receiver --> Remote trail --> Replicat --> Target
  |
  +-- Classic Pump --------------------> Manager/Collector --> Remote trail --> Replicat --> Target
```

Regola importante: GoldenGate non usa una connessione DB-to-DB diretta per spostare i dati. Extract legge redo sul source, scrive trail; Distribution/Pump trasporta trail; Replicat applica sul target.

---

## 2. Assessment tecnico iniziale

### 2.1 Identificare service e PDB

Se hai un `SERVICE_NAME` e devi capire a quale PDB punta:

```sql
SELECT pdb AS pluggable_database,
       name AS service_name,
       network_name
FROM   cdb_services
WHERE  UPPER(name) LIKE UPPER('%&SERVICE_NAME%');
```

Per tutte le PDB e servizi:

```sql
SELECT p.name AS pdb_name,
       s.name AS service_name,
       s.network_name
FROM   v$pdbs p
LEFT JOIN cdb_services s ON s.pdb = p.name
ORDER  BY p.name, s.name;
```

### 2.2 Dimensione database

```sql
SELECT
    ROUND((SELECT SUM(bytes)/1024/1024/1024 FROM dba_data_files), 2) AS datafiles_gb,
    ROUND((SELECT SUM(bytes)/1024/1024/1024 FROM dba_temp_files), 2) AS tempfiles_gb,
    ROUND((SELECT SUM(bytes)/1024/1024/1024 FROM v$log), 2) AS redo_logs_gb,
    ROUND(
        (SELECT SUM(bytes)/1024/1024/1024 FROM dba_data_files) +
        (SELECT SUM(bytes)/1024/1024/1024 FROM dba_temp_files) +
        (SELECT SUM(bytes)/1024/1024/1024 FROM v$log)
    , 2) AS total_allocated_gb
FROM dual;
```

### 2.3 Trend crescita tablespace da AWR

```sql
WITH snap_sizes AS (
    SELECT
        s.snap_id,
        TO_CHAR(s.begin_interval_time, 'YYYY-MM') AS mese,
        SUM(h.tablespace_size * t.block_size) AS allocato_bytes,
        SUM(h.tablespace_usedsize * t.block_size) AS usato_bytes
    FROM dba_hist_tbspc_space_usage h
    JOIN dba_hist_snapshot s ON h.snap_id = s.snap_id
    JOIN v$tablespace vt ON h.tablespace_id = vt.ts#
    JOIN dba_tablespaces t ON vt.name = t.tablespace_name
    WHERE s.begin_interval_time >= ADD_MONTHS(SYSDATE, -12)
    GROUP BY s.snap_id, TO_CHAR(s.begin_interval_time, 'YYYY-MM')
)
SELECT
    mese,
    ROUND(MAX(allocato_bytes) / 1024/1024/1024, 2) AS max_allocato_gb,
    ROUND(MAX(usato_bytes) / 1024/1024/1024, 2) AS max_usato_gb,
    ROUND(
      ROUND(MAX(usato_bytes) / 1024/1024/1024, 2) -
      LAG(ROUND(MAX(usato_bytes) / 1024/1024/1024, 2)) OVER (ORDER BY mese)
    , 2) AS delta_usato_vs_mese_prec_gb
FROM snap_sizes
GROUP BY mese
ORDER BY mese;
```

### 2.4 Redo generation per sizing FRA/trail

```sql
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS ora,
       ROUND(SUM(blocks * block_size)/1024/1024/1024,2) redo_gb
FROM   v$archived_log
WHERE  first_time > SYSDATE - 7
GROUP  BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER  BY ora;
```

Formula pratica:

```text
spazio_minimo_archive_per_extract = redo_picco_ora * ore_outage_extract * 1.5
spazio_minimo_trail = volume_cambiamenti_attesi * ore_outage_target * 1.5
```

---

## 3. Preparazione Oracle source

```sql
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH SID='*';
ALTER DATABASE FORCE LOGGING;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
```

Verifica:

```sql
SELECT force_logging,
       supplemental_log_data_min,
       supplemental_log_data_pk,
       supplemental_log_data_ui
FROM   v$database;

SELECT inst_id, value
FROM   gv$parameter
WHERE  name = 'enable_goldengate_replication';
```

---

## 4. Grant GoldenGate

Non usare il ruolo `DBA` come soluzione permanente. Usa la guida dedicata:

- [GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md)

Schema minimo CDB:

```sql
CREATE USER c##ggadmin IDENTIFIED BY "<PASSWORD_SICURA>" CONTAINER=ALL;
GRANT CREATE SESSION TO c##ggadmin CONTAINER=ALL;
GRANT CREATE VIEW TO c##ggadmin CONTAINER=ALL;
GRANT ALTER SYSTEM TO c##ggadmin CONTAINER=ALL;
GRANT ALTER USER TO c##ggadmin CONTAINER=ALL;
ALTER USER c##ggadmin QUOTA UNLIMITED ON USERS CONTAINER=ALL;
ALTER USER c##ggadmin SET CONTAINER_DATA=ALL CONTAINER=CURRENT;

BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'C##GGADMIN',
    privilege_type          => '*',
    grant_select_privileges => TRUE,
    do_grants               => TRUE,
    container               => 'ALL');
END;
/
```

Target DML:

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.CUSTOMERS TO ggadmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.ORDERS TO ggadmin;
```

---

## 5. Credential store

```text
ADD CREDENTIALSTORE
ALTER CREDENTIALSTORE ADD USER c##ggadmin@RACDB PASSWORD <PASSWORD_DB> ALIAS ggsrc DOMAIN OracleGoldenGate
ALTER CREDENTIALSTORE ADD USER ggadmin@DBTARGET PASSWORD <PASSWORD_DB> ALIAS ggtgt DOMAIN OracleGoldenGate
INFO CREDENTIALSTORE
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
```

Nei parametri usare sempre:

```text
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
```

Non usare password in chiaro.

---

## 6. Supplemental logging oggetti

Schema intero:

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
ADD SCHEMATRANDATA APP
INFO SCHEMATRANDATA APP
```

Tabella singola:

```text
ADD TRANDATA APP.CUSTOMERS
INFO TRANDATA APP.CUSTOMERS
```

Active-active o CDR:

```text
ADD TRANDATA APP.CUSTOMERS ALLCOLS
```

Nota: `ALLCOLS` aumenta redo. Usarlo solo dove serve davvero.

---

## 7. Initial load

Scelta consigliata per Oracle -> Oracle:

```bash
expdp ggadmin/<password> schemas=APP directory=DATA_PUMP_DIR dumpfile=app_%U.dmp logfile=app_export.log parallel=4 flashback_time=systimestamp
impdp ggadmin/<password> schemas=APP directory=DATA_PUMP_DIR dumpfile=app_%U.dmp logfile=app_import.log parallel=4
```

Per migrazione con SCN esplicito:

```sql
SELECT current_scn FROM v$database;
```

Poi usare `FLASHBACK_SCN=<SCN>` in Data Pump e avviare Extract coerentemente con quel punto.

---

## 8. Integrated Extract 19c

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
REGISTER EXTRACT ext_app DATABASE
ADD EXTRACT ext_app, INTEGRATED TRANLOG, BEGIN NOW
ADD EXTTRAIL ./dirdat/ea, EXTRACT ext_app, MEGABYTES 200
EDIT PARAMS ext_app
```

Parametro base:

```text
EXTRACT ext_app
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
EXTTRAIL ./dirdat/ea
LOGALLSUPCOLS
UPDATERECORDFORMAT COMPACT
TABLE APP.*;
```

Start e controllo:

```text
START EXTRACT ext_app
INFO EXTRACT ext_app, DETAIL
LAG EXTRACT ext_app
STATS EXTRACT ext_app, TOTAL
VIEW REPORT ext_app
```

---

## 9. Trasporto trail

### 9.1 Microservices Distribution Path

```text
CONNECT https://source-ogg:9012 DEPLOYMENT SourceDeploy AS oggadmin PASSWORD <PASSWORD_DEPLOYMENT>
INFO DISTPATH *
START DISTPATH path_app_tgt
INFO DISTPATH path_app_tgt
```

Verifica Receiver:

```text
CONNECT https://target-ogg:9012 DEPLOYMENT TargetDeploy AS oggadmin PASSWORD <PASSWORD_DEPLOYMENT>
INFO RECVPATH *
```

REST quick check:

```bash
curl -k -u oggadmin:<PASSWORD_DEPLOYMENT> https://source-ogg:9012/services/v2/status
curl -k -u oggadmin:<PASSWORD_DEPLOYMENT> https://target-ogg:9012/services/v2/status
```

### 9.2 Classic Pump

```text
ADD EXTRACT pump_app, EXTTRAILSOURCE ./dirdat/ea
ADD RMTTRAIL ./dirdat/rt, EXTRACT pump_app, MEGABYTES 200
EDIT PARAMS pump_app
```

Parametro:

```text
EXTRACT pump_app
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
RMTHOST target-ogg.localdomain, MGRPORT 7809
RMTTRAIL ./dirdat/rt
PASSTHRU
TABLE APP.*;
```

---

## 10. Replicat target

```text
DBLOGIN USERIDALIAS ggtgt DOMAIN OracleGoldenGate
ADD CHECKPOINTTABLE GGADMIN.GG_CHECKPOINT
ADD REPLICAT rep_app, INTEGRATED, EXTTRAIL ./dirdat/rt, CHECKPOINTTABLE GGADMIN.GG_CHECKPOINT
EDIT PARAMS rep_app
```

Parametro:

```text
REPLICAT rep_app
USERIDALIAS ggtgt DOMAIN OracleGoldenGate
ASSUMETARGETDEFS
DISCARDFILE ./dirrpt/rep_app.dsc, APPEND, MEGABYTES 500
REPORTCOUNT EVERY 5 MINUTES, RATE
BATCHSQL
MAP APP.*, TARGET APP.*;
```

Start e controllo:

```text
START REPLICAT rep_app
INFO REPLICAT rep_app, DETAIL
LAG REPLICAT rep_app
STATS REPLICAT rep_app, TOTAL
VIEW REPORT rep_app
```

---

## 11. Heartbeat e lag end-to-end

Oracle GoldenGate 19c supporta heartbeat automatico per misurare lag end-to-end.

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
ADD HEARTBEATTABLE
INFO HEARTBEATTABLE
```

Controlli operativi:

```text
LAG EXTRACT ext_app
LAG REPLICAT rep_app
SEND EXTRACT ext_app, STATUS
SEND REPLICAT rep_app, STATUS
STATS EXTRACT ext_app, TOTAL
STATS REPLICAT rep_app, TOTAL
```

In produzione devi monitorare:

- lag Extract;
- lag Distribution/Pump;
- lag Replicat;
- crescita trail;
- FRA/archive log;
- abend processi;
- errori discard;
- heartbeat end-to-end.

---

## 12. Validazione dati

Conteggi base:

```sql
SELECT COUNT(*) FROM app.customers;
SELECT COUNT(*) FROM app.orders;
```

Checksum semplice per tabella piccola/media:

```sql
SELECT COUNT(*) AS rows_count,
       SUM(ORA_HASH(customer_id || ':' || status || ':' || last_update_date)) AS hash_sum
FROM   app.customers;
```

Test DML minimo:

```sql
INSERT INTO app.gg_test(id, descr, last_update_ts) VALUES (1, 'insert test', SYSTIMESTAMP);
COMMIT;

UPDATE app.gg_test SET descr='update test', last_update_ts=SYSTIMESTAMP WHERE id=1;
COMMIT;

DELETE FROM app.gg_test WHERE id=1;
COMMIT;
```

Verifica sul target dopo ogni step.

---

## 13. Cutover per migrazione

```text
1. Notifica finestra change.
2. Stop applicazione o modalita read-only.
3. Forza log switch sul source.
4. Attendi lag Extract/Replicat = 0.
5. Verifica report senza errori.
6. Esegui query di riconciliazione.
7. Stop GoldenGate o mantieni reverse/fallback secondo piano.
8. Cambia connection string applicativa.
9. Avvia applicazione su target.
10. Monitora per finestra intensiva.
```

---

## 14. Active-active e CDR

Prima di active-active devi leggere [UC02 - High Availability](./use_cases/UC02_HIGH_AVAILABILITY.md).

Concetto base:

```text
COMPARECOLS serve a confrontare before image e valori target.
RESOLVECONFLICT decide cosa fare in caso di conflitto.
```

Scheletro concettuale da adattare e validare in UAT:

```text
MAP APP.CUSTOMERS, TARGET APP.CUSTOMERS,
  COMPARECOLS (ON UPDATE ALL, ON DELETE ALL),
  RESOLVECONFLICT (UPDATEROWEXISTS, (DEFAULT, OVERWRITE)),
  RESOLVECONFLICT (INSERTROWEXISTS, (DEFAULT, DISCARD));
```

Non usare active-active senza:

- chiavi robuste;
- gestione sequence/identity;
- regole conflitto approvate dal business;
- test update/update, insert collision, delete/update;
- prevenzione loop replication.

---

## 15. Kafka / Big Data / Stream use case

Per UC06/UC07, il pattern cambia nella parte target:

```text
Oracle Extract -> Trail -> GoldenGate for Big Data Replicat/Handler -> Kafka topic
```

Skeleton concettuale:

```text
REPLICAT rkafka
TARGETDB LIBFILE libggjava.so SET property=dirprm/kafka.props
REPORTCOUNT EVERY 5 MINUTES, RATE
MAP APP.*, TARGET APP.*;
```

Esempio `kafka.props` concettuale:

```text
gg.handlerlist=kafkahandler
gg.handler.kafkahandler.type=kafka
gg.handler.kafkahandler.KafkaProducerConfigFile=custom_kafka_producer.properties
gg.handler.kafkahandler.topicMappingTemplate=${fullyQualifiedTableName}
gg.handler.kafkahandler.format=json
```

Validare sempre con la documentazione GoldenGate for Big Data della versione installata.

---

## 16. Troubleshooting rapido

| Sintomo | Primo controllo | Azione |
|---|---|---|
| `ORA-01031` | grant/container | guida grant, `DBA_GOLDENGATE_PRIVILEGES`, grant DML target |
| `ORA-01017` | credential store | alias, password, service name, account lock |
| Extract abended | report + archive | archive presenti, FRA, checkpoint |
| Replicat abended | discard/report | PK, FK, datatype, grant DML |
| Lag alto Extract | redo/archive/I/O | AWR, archive log, CPU, disk |
| Lag alto Replicat | target lento | indici, constraint, batchsql, parallelism |
| Trail cresce | target down/slow | spazio filesystem, purge, restart target |
| Distribuzione non va | rete/TLS/path | firewall, cert, Receiver/Manager, target-initiated path |

---

## 17. Fonti Oracle ufficiali

- DBMS_GOLDENGATE_AUTH: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_GOLDENGATE_AUTH.html
- GoldenGate credentials 19c: https://docs.oracle.com/en/middleware/goldengate/core/19.1/oracle-db/establishing-oracle-goldengate-credentials.html
- GoldenGate monitoring and heartbeat: https://docs.oracle.com/en/middleware/goldengate/core/19.1/admin/monitoring-oracle-goldengate-processing.html
- GoldenGate Microservices REST API: https://docs.oracle.com/en/middleware/goldengate/core/19.1/oggra/QuickStart.html
- GoldenGate Microservices access points: https://docs.oracle.com/en/middleware/goldengate/core/19.1/coredoc/overview-access-points-oracle-goldengate-microservices.html
- GoldenGate active-active configuration: https://docs.oracle.com/en/middleware/goldengate/core/19.1/admin/configuring-oracle-goldengate-active-active-high-availability.html
- GoldenGate for Big Data 19.1: https://docs.oracle.com/en/middleware/goldengate/big-data/19.1/index.html
