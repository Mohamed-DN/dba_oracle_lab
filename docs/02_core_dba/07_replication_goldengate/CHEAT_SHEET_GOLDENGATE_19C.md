# Cheat Sheet Oracle GoldenGate 19c

> [!NOTE]
> **DOCUMENTI GOLDENGATE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Cheat Sheet Operativo (Veloce)**: [CHEAT_SHEET_GOLDENGATE.md](../../01_operations/01_cheat_sheets/CHEAT_SHEET_GOLDENGATE.md) (Lag, checkpoint, stop/start rapido).
> - **Guida di Laboratorio Core**: [GUIDA_FASE7_GOLDENGATE.md](./GUIDA_FASE7_GOLDENGATE.md) (fondamenti di installazione e setup).
> - **Guida di Riferimento 19c Core**: [GUIDA_GOLDENGATE_19C_COMPLETA.md](./GUIDA_GOLDENGATE_19C_COMPLETA.md) (manuale completo dei comandi e parametri).

> Comandi rapidi per Classic `ggsci`, Microservices `adminclient`, SQL Oracle e troubleshooting. Usare placeholder per password: non salvare segreti nei file.

---

## 1. Ambiente

```bash
export OGG_HOME=/u01/app/oracle/product/ogg19c
export PATH=$OGG_HOME:$PATH
cd $OGG_HOME
```

Classic:

```bash
./ggsci
```

Microservices:

```bash
$OGG_HOME/bin/adminclient
```

---

## 2. GGSCI - Manager

```text
CREATE SUBDIRS
EDIT PARAMS mgr
START MANAGER
STOP MANAGER
INFO MANAGER
SEND MANAGER STATUS
VIEW GGSEVT
```

`mgr.prm` base:

```text
PORT 7809
DYNAMICPORTLIST 7810-7820
AUTOSTART ER *
AUTORESTART ER *, RETRIES 5, WAITMINUTES 2, RESETMINUTES 60
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPDAYS 3
```

---

## 3. Credential Store

```text
ADD CREDENTIALSTORE
ALTER CREDENTIALSTORE ADD USER c##ggadmin@RACDB PASSWORD <PASSWORD_DB> ALIAS ggsrc DOMAIN OracleGoldenGate
ALTER CREDENTIALSTORE ADD USER ggadmin@DBTARGET PASSWORD <PASSWORD_DB> ALIAS ggtgt DOMAIN OracleGoldenGate
INFO CREDENTIALSTORE
DELETE CREDENTIALSTORE
```

Login DB:

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
```

---

## 4. Supplemental Logging

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
ADD SCHEMATRANDATA HR
INFO SCHEMATRANDATA HR
DELETE SCHEMATRANDATA HR

ADD TRANDATA HR.EMPLOYEES
ADD TRANDATA HR.EMPLOYEES ALLCOLS
INFO TRANDATA HR.EMPLOYEES
DELETE TRANDATA HR.EMPLOYEES
```

SQL verifica:

```sql
SELECT force_logging, supplemental_log_data_min, supplemental_log_data_pk, supplemental_log_data_ui
FROM   v$database;

SELECT owner, table_name, log_group_name, log_group_type
FROM   dba_log_groups
WHERE  owner = 'HR';
```

---

## 5. Extract Classic

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
REGISTER EXTRACT ext_rac DATABASE
ADD EXTRACT ext_rac, INTEGRATED TRANLOG, BEGIN NOW
ADD EXTTRAIL ./dirdat/ea, EXTRACT ext_rac, MEGABYTES 200
EDIT PARAMS ext_rac
START EXTRACT ext_rac
STOP EXTRACT ext_rac
INFO EXTRACT ext_rac, DETAIL
LAG EXTRACT ext_rac
SEND EXTRACT ext_rac, STATUS
STATS EXTRACT ext_rac, TOTAL
VIEW REPORT ext_rac
```

Param file:

```text
EXTRACT ext_rac
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
EXTTRAIL ./dirdat/ea
LOGALLSUPCOLS
UPDATERECORDFORMAT COMPACT
TABLE HR.*;
```

---

## 6. Pump Classic

```text
ADD EXTRACT pump_rac, EXTTRAILSOURCE ./dirdat/ea
ADD RMTTRAIL ./dirdat/rt, EXTRACT pump_rac, MEGABYTES 200
EDIT PARAMS pump_rac
START EXTRACT pump_rac
INFO EXTRACT pump_rac, DETAIL
LAG EXTRACT pump_rac
VIEW REPORT pump_rac
```

Param file:

```text
EXTRACT pump_rac
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
RMTHOST dbtarget.localdomain, MGRPORT 7809
RMTTRAIL ./dirdat/rt
PASSTHRU
TABLE HR.*;
```

---

## 7. Replicat Classic

```text
DBLOGIN USERIDALIAS ggtgt DOMAIN OracleGoldenGate
ADD CHECKPOINTTABLE GGADMIN.GG_CHECKPOINT
ADD REPLICAT rep_tgt, INTEGRATED, EXTTRAIL ./dirdat/rt, CHECKPOINTTABLE GGADMIN.GG_CHECKPOINT
EDIT PARAMS rep_tgt
START REPLICAT rep_tgt
STOP REPLICAT rep_tgt
INFO REPLICAT rep_tgt, DETAIL
LAG REPLICAT rep_tgt
SEND REPLICAT rep_tgt, STATUS
STATS REPLICAT rep_tgt, TOTAL
VIEW REPORT rep_tgt
```

Param file:

```text
REPLICAT rep_tgt
USERIDALIAS ggtgt DOMAIN OracleGoldenGate
ASSUMETARGETDEFS
DISCARDFILE ./dirrpt/rep_tgt.dsc, APPEND, MEGABYTES 500
BATCHSQL
MAP HR.*, TARGET HR.*;
```

---

## 8. Admin Client Microservices

Connessione:

```text
CONNECT http://rac1:9012 DEPLOYMENT SourceDeploy AS oggadmin PASSWORD <PASSWORD_DEPLOYMENT>
CONNECT https://rac1:9012 DEPLOYMENT SourceDeploy AS oggadmin PASSWORD <PASSWORD_DEPLOYMENT>
```

Processi:

```text
INFO EXTRACT *
INFO REPLICAT *
INFO DISTPATH *
START EXTRACT ext_rac
STOP EXTRACT ext_rac
START REPLICAT rep_tgt
STOP REPLICAT rep_tgt
LAG EXTRACT ext_rac
LAG REPLICAT rep_tgt
STATS EXTRACT ext_rac, TOTAL
STATS REPLICAT rep_tgt, TOTAL
```

Distribution path:

```text
INFO DISTPATH *
START DISTPATH path_rac_tgt
STOP DISTPATH path_rac_tgt
```

---

## 9. Reposition

Extract:

```text
ALTER EXTRACT ext_rac, SCN 123456789
ALTER EXTRACT ext_rac, BEGIN NOW
```

Replicat:

```text
START REPLICAT rep_tgt, AFTERCSN 123456789
ALTER REPLICAT rep_tgt, EXTSEQNO 10, EXTRBA 12345
```

Usare solo dopo analisi: puo' causare perdita o duplicazione logica.

---

## 10. Trail e LogDump

```bash
$OGG_HOME/logdump
```

```text
Logdump> OPEN ./dirdat/ea000000001
Logdump> GHDR ON
Logdump> DETAIL ON
Logdump> NEXT
Logdump> COUNT
Logdump> POS 0
```

---

## 11. SQL Oracle per GoldenGate

Parametri:

```sql
SELECT inst_id, name, value
FROM   gv$parameter
WHERE  name = 'enable_goldengate_replication';

SELECT force_logging, supplemental_log_data_min
FROM   v$database;
```

Redo rate:

```sql
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS ora,
       ROUND(SUM(blocks * block_size)/1024/1024/1024,2) redo_gb
FROM   v$archived_log
WHERE  first_time > SYSDATE - 1
GROUP  BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER  BY ora;
```

FRA:

```sql
SELECT name, space_limit/1024/1024/1024 limit_gb,
       space_used/1024/1024/1024 used_gb,
       ROUND(space_used*100/space_limit,2) pct_used
FROM   v$recovery_file_dest;
```

Privilegi:

```sql
SELECT * FROM dba_goldengate_privileges;
```

Service/PDB lookup:

```sql
SELECT pdb AS pluggable_database,
       name AS service_name,
       network_name
FROM   cdb_services
WHERE  UPPER(name) LIKE UPPER('%&SERVICE_NAME%');
```

Dimensione database:

```sql
SELECT
    ROUND((SELECT SUM(bytes)/1024/1024/1024 FROM dba_data_files), 2) AS datafiles_gb,
    ROUND((SELECT SUM(bytes)/1024/1024/1024 FROM dba_temp_files), 2) AS tempfiles_gb,
    ROUND((SELECT SUM(bytes)/1024/1024/1024 FROM v$log), 2) AS redo_logs_gb
FROM dual;
```

---

## 12. Grant e privilegi rapidi

Guida completa: [GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).

Oracle CDB common user:

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

Oracle target DML per Replicat:

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.CUSTOMERS TO ggadmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.ORDERS TO ggadmin;
```

Genera grant per schema:

```sql
SELECT 'GRANT SELECT, INSERT, UPDATE, DELETE ON ' || owner || '.' || table_name || ' TO GGADMIN;'
FROM   dba_tables
WHERE  owner = 'APP'
ORDER  BY table_name;
```

PostgreSQL target:

```sql
CREATE USER ggadmin WITH PASSWORD '<PASSWORD_SICURA>';
GRANT CONNECT ON DATABASE appdb TO ggadmin;
GRANT USAGE ON SCHEMA app TO ggadmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO ggadmin;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ggadmin;
```

PostgreSQL source:

```sql
ALTER USER ggadmin WITH REPLICATION;
-- Se richiesto solo per configurazione TRANDATA:
ALTER USER ggadmin WITH SUPERUSER;
ALTER USER ggadmin WITH NOSUPERUSER;
```

Verifica Oracle:

```sql
SELECT username, privilege_type
FROM   dba_goldengate_privileges
WHERE  username IN ('GGADMIN','C##GGADMIN');
```

---

## 13. Heartbeat e lag end-to-end

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
ADD HEARTBEATTABLE
INFO HEARTBEATTABLE
```

Lag e stato:

```text
LAG EXTRACT ext_rac
LAG REPLICAT rep_tgt
SEND EXTRACT ext_rac, STATUS
SEND REPLICAT rep_tgt, STATUS
STATS EXTRACT ext_rac, TOTAL
STATS REPLICAT rep_tgt, TOTAL
```

---

## 14. REST API Microservices

Status:

```bash
curl -k -u oggadmin:<PASSWORD_DEPLOYMENT> https://rac1:9012/services/v2/status
```

Esecuzione comando via REST:

```bash
curl -k -u oggadmin:<PASSWORD_DEPLOYMENT> \
  -H "Content-Type: application/json" \
  -X POST https://rac1:9012/services/v2/commands/execute \
  -d '{"name":"info","processName":"ext_rac","processType":"extract"}'
```

---

## 15. Active-active / CDR skeleton

Solo dopo design conflitti approvato. Validare sintassi e regole in UAT.

```text
MAP APP.CUSTOMERS, TARGET APP.CUSTOMERS,
  COMPARECOLS (ON UPDATE ALL, ON DELETE ALL),
  RESOLVECONFLICT (UPDATEROWEXISTS, (DEFAULT, OVERWRITE)),
  RESOLVECONFLICT (INSERTROWEXISTS, (DEFAULT, DISCARD));
```

---

## 16. Big Data / Kafka skeleton

```text
REPLICAT rkafka
TARGETDB LIBFILE libggjava.so SET property=dirprm/kafka.props
REPORTCOUNT EVERY 5 MINUTES, RATE
MAP APP.*, TARGET APP.*;
```

`kafka.props` concettuale:

```text
gg.handlerlist=kafkahandler
gg.handler.kafkahandler.type=kafka
gg.handler.kafkahandler.KafkaProducerConfigFile=custom_kafka_producer.properties
gg.handler.kafkahandler.topicMappingTemplate=${fullyQualifiedTableName}
gg.handler.kafkahandler.format=json
```

---

## 17. Diagnostica errori comuni

```text
INFO ALL
VIEW REPORT <process>
VIEW GGSEVT
SEND <process> STATUS
LAG <process>
STATS <process>, TOTAL
```

File da controllare:

```bash
ls -ltr dirrpt
ls -ltr dirdat
tail -200 ggserr.log
df -h
```

---

## 18. Errori tipici

| Errore | Azione rapida |
| --- | --- |
| `ORA-01031` | controlla `DBMS_GOLDENGATE_AUTH` |
| `ORA-01017` | credential store/password/alias |
| `ORA-01291` | archive log mancante |
| `ORA-00001` | duplicato, verifica SCN initial load |
| `ORA-02291` | FK violata, ordine dati/mapping |
| `OGG-00446` | leggi report, root cause specifica |
| `OGG-01028` | trail/checkpoint problem |

---

## 19. Runbook stop/start sicuro

Stop:

```text
STOP EXTRACT pump_rac
STOP EXTRACT ext_rac
STOP REPLICAT rep_tgt
INFO ALL
```

Start:

```text
START EXTRACT ext_rac
START EXTRACT pump_rac
START REPLICAT rep_tgt
INFO ALL
LAG EXTRACT ext_rac
LAG REPLICAT rep_tgt
```

---

## 20. Cutover migrazione

```text
1. stop applicazione source
2. verifica zero nuove transazioni
3. attendi lag Extract/Replicat = 0
4. confronta conteggi source/target
5. stop GoldenGate
6. cambia connection string applicativa
7. start applicazione target
8. monitor intensivo
```

---

## 21. Fonti ufficiali

- GGSCI Commands: https://docs.oracle.com/en/middleware/goldengate/core/18.1/reference/oracle-goldengate-ggsci-commands.html
- Microservices Access Points: https://docs.oracle.com/en/middleware/goldengate/core/19.1/coredoc/overview-access-points-oracle-goldengate-microservices.html
- REST API: https://docs.oracle.com/en/middleware/goldengate/core/19.1/oggra/QuickStart.html
- DBMS_GOLDENGATE_AUTH: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_GOLDENGATE_AUTH.html
- Monitoring/Heartbeat: https://docs.oracle.com/en/middleware/goldengate/core/19.1/admin/monitoring-oracle-goldengate-processing.html
- Active-active/CDR: https://docs.oracle.com/en/middleware/goldengate/core/19.1/admin/configuring-oracle-goldengate-active-active-high-availability.html
- GoldenGate for Big Data 19.1: https://docs.oracle.com/en/middleware/goldengate/big-data/19.1/index.html
