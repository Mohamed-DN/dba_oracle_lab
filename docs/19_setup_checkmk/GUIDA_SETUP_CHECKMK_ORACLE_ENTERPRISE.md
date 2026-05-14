# Guida Setup CheckMK per Oracle Database — Enterprise

> Guida completa per configurare il monitoring Oracle Database con CheckMK.
> Copre installazione agent, plugin mk_oracle, configurazione Single Instance,
> RAC, Data Guard, ASM, Tablespace, RMAN, Performance, Alerting.
>
> **Target audience**: DBA Oracle e team Monitoring/Infrastructure.

---

## PARTE I — ARCHITETTURA E PREREQUISITI

---

## 1. Architettura del Monitoring

```
┌──────────────────┐       ┌──────────────────┐
│  CheckMK Server  │◄─────►│  CheckMK Agent   │
│  (Central Site)  │ TCP   │  + mk_oracle     │
│                  │ 6556  │  plugin           │
│  ┌────────────┐  │       │                   │
│  │ Web UI     │  │       │  ┌─────────────┐  │
│  │ WATO       │  │       │  │ Oracle DB   │  │
│  │ Dashboards │  │       │  │ (sqlplus)   │  │
│  │ Alerting   │  │       │  └─────────────┘  │
│  └────────────┘  │       │                   │
└──────────────────┘       └──────────────────┘
```

### 1.1 Componenti

| Componente | Funzione |
|---|---|
| **CheckMK Server** | Riceve dati, genera alert, web UI |
| **CheckMK Agent** | Daemon sull'host Oracle (porta 6556) |
| **mk_oracle** | Plugin specifico per Oracle (bash script su Linux) |
| **Oracle Instant Client** | Necessario per `sqlplus` / `tnsping` |
| **Monitoring User** | Utente DB read-only per le query monitoring |

### 1.2 Cosa Viene Monitorato

| Check | Descrizione | Criticita |
|---|---|---|
| **Instance Status** | UP/DOWN/RESTRICTED | CRIT se down |
| **Tablespace Usage** | % utilizzo per tablespace | WARN > 85%, CRIT > 95% |
| **Datafile Status** | ONLINE/OFFLINE/RECOVER | CRIT se non ONLINE |
| **ASM Diskgroup** | Spazio libero per diskgroup | WARN < 15%, CRIT < 5% |
| **RMAN Backup Age** | Eta dell'ultimo backup valido | WARN > 24h, CRIT > 48h |
| **Archivelog Usage** | Archivelog non backuppati | WARN > 50, CRIT > 100 |
| **Recovery Area** | FRA % utilizzo | WARN > 80%, CRIT > 90% |
| **Data Guard Lag** | Apply/Transport lag | WARN > 30min, CRIT > 1h |
| **Sessions** | Sessioni attive vs max | WARN > 80%, CRIT > 95% |
| **Long Running Queries** | Query > soglia tempo | WARN > 30min, CRIT > 2h |
| **Locks** | Sessioni bloccanti | WARN > 5min, CRIT > 30min |
| **Performance** | Buffer cache hit, library cache | WARN < 95%, CRIT < 90% |
| **Job Status** | DBMS_SCHEDULER jobs falliti | CRIT se FAILED |
| **Process Count** | Processi Oracle attivi | WARN > 80%, CRIT > 95% |

---

## PARTE II — INSTALLAZIONE E CONFIGURAZIONE

---

## 2. Prerequisiti sull'Host Oracle

### 2.1 Oracle Instant Client

```bash
# Se Oracle DB e gia installato, usa $ORACLE_HOME
# Altrimenti installa Instant Client

# RPM (Oracle Linux / RHEL / CentOS)
yum install oracle-instantclient19.22-basic-19.22.0.0.0-1.x86_64.rpm
yum install oracle-instantclient19.22-sqlplus-19.22.0.0.0-1.x86_64.rpm

# Librerie
yum install libaio

# Verifica
sqlplus -version
tnsping PROD
```

### 2.2 Creare l'Utente Monitoring nel Database

```sql
-- ============================================
-- UTENTE MONITORING PER CHECKMK
-- ============================================

-- Crea utente dedicato (NEVER expire password, read-only)
CREATE USER checkmk_monitor IDENTIFIED BY "StrongP@ss2026!"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

-- Password non scade mai
ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;
-- Oppure crea un profilo dedicato:
-- CREATE PROFILE monitoring_profile LIMIT
--   PASSWORD_LIFE_TIME UNLIMITED
--   FAILED_LOGIN_ATTEMPTS UNLIMITED;
-- ALTER USER checkmk_monitor PROFILE monitoring_profile;

-- Grant minimi (SOLO lettura)
GRANT CREATE SESSION TO checkmk_monitor;
GRANT SELECT_CATALOG_ROLE TO checkmk_monitor;

-- Grant specifici per i check
GRANT SELECT ON sys.v_$database TO checkmk_monitor;
GRANT SELECT ON sys.v_$instance TO checkmk_monitor;
GRANT SELECT ON sys.v_$session TO checkmk_monitor;
GRANT SELECT ON sys.v_$process TO checkmk_monitor;
GRANT SELECT ON sys.v_$sysstat TO checkmk_monitor;
GRANT SELECT ON sys.v_$system_event TO checkmk_monitor;
GRANT SELECT ON sys.v_$log TO checkmk_monitor;
GRANT SELECT ON sys.v_$archive_dest TO checkmk_monitor;
GRANT SELECT ON sys.v_$archived_log TO checkmk_monitor;
GRANT SELECT ON sys.v_$recovery_file_dest TO checkmk_monitor;
GRANT SELECT ON sys.v_$rman_backup_job_details TO checkmk_monitor;
GRANT SELECT ON sys.v_$dataguard_stats TO checkmk_monitor;
GRANT SELECT ON sys.v_$managed_standby TO checkmk_monitor;
GRANT SELECT ON sys.v_$database_block_corruption TO checkmk_monitor;
GRANT SELECT ON sys.v_$asm_diskgroup TO checkmk_monitor;
GRANT SELECT ON sys.v_$asm_disk TO checkmk_monitor;
GRANT SELECT ON sys.v_$flash_recovery_area_usage TO checkmk_monitor;
GRANT SELECT ON sys.v_$session_longops TO checkmk_monitor;
GRANT SELECT ON sys.v_$resource_limit TO checkmk_monitor;
GRANT SELECT ON sys.v_$sgastat TO checkmk_monitor;
GRANT SELECT ON sys.v_$pgastat TO checkmk_monitor;
GRANT SELECT ON sys.dba_tablespaces TO checkmk_monitor;
GRANT SELECT ON sys.dba_data_files TO checkmk_monitor;
GRANT SELECT ON sys.dba_free_space TO checkmk_monitor;
GRANT SELECT ON sys.dba_temp_files TO checkmk_monitor;
GRANT SELECT ON sys.dba_scheduler_jobs TO checkmk_monitor;
GRANT SELECT ON sys.dba_scheduler_job_run_details TO checkmk_monitor;

-- Per Multitenant (CDB): grant su tutti i container
-- ALTER USER checkmk_monitor SET CONTAINER_DATA=ALL CONTAINER=CURRENT;
```

### 2.3 Verifica Connessione

```bash
# Test connessione
sqlplus checkmk_monitor/StrongP@ss2026!@PROD

# Test query base
SELECT instance_name, status, database_status FROM v$instance;
SELECT name, db_unique_name, database_role, open_mode FROM v$database;
```

---

## 3. Installazione CheckMK Agent

### 3.1 Download e Installazione Agent

```bash
# Dal CheckMK Server, scarica il pacchetto agent
wget "https://checkmk-server:443/mysite/check_mk/agents/check-mk-agent-2.3.0-1.noarch.rpm"

# Installa
rpm -ivh check-mk-agent-2.3.0-1.noarch.rpm

# Verifica
check_mk_agent | head -20

# Registra l'agent con il server (CheckMK 2.2+)
cmk-agent-ctl register --hostname oracledb01 \
  --server checkmk-server:443 \
  --site mysite \
  --user cmkadmin --password "pwd"
```

### 3.2 Configurazione Firewall

```bash
# Porta agent CheckMK
firewall-cmd --permanent --add-port=6556/tcp
firewall-cmd --reload

# Verifica
firewall-cmd --list-ports
```

### 3.3 Agent con TLS (CheckMK 2.1+)

```bash
# Registra con TLS
cmk-agent-ctl register --hostname oracledb01 \
  --server checkmk-server --site mysite \
  --user cmkadmin --password "pwd" \
  --trust-cert
```

---

## 4. Plugin mk_oracle

### 4.1 Installazione Plugin (Enterprise Edition — Agent Bakery)

```
1. CheckMK Web UI → Setup → Agents → Agent rules
2. Cerca "Oracle databases"
3. Add rule:
   - Login: checkmk_monitor / password
   - Instances: PROD (hostname:1521)
   - Sections: Instance, Tablespaces, Dataguard, ASM, Recovery Area, 
               RMAN, Jobs, Locks, Long Active Sessions, Performance
4. Bake agents
5. Deploy su host Oracle
```

### 4.2 Installazione Plugin (Raw Edition — Manuale)

```bash
# 1. Copia il plugin dal server CheckMK
scp checkmk-server:/opt/omd/sites/mysite/share/check_mk/agents/plugins/mk_oracle \
    root@oracledb01:/usr/lib/check_mk_agent/plugins/300/

# NOTA: la directory 300/ indica esecuzione asincrona ogni 300 secondi (5 min)
# Per 60 secondi: /usr/lib/check_mk_agent/plugins/60/mk_oracle

# 2. Permessi
chmod 755 /usr/lib/check_mk_agent/plugins/300/mk_oracle

# 3. Crea configurazione
cat > /etc/check_mk/mk_oracle.cfg <<'EOF'
# ============================================
# mk_oracle.cfg — Configurazione Plugin Oracle
# ============================================

# Credenziali
DBUSER="checkmk_monitor:StrongP@ss2026!::oracledb01:1521:PROD"

# Oppure con wallet (piu sicuro):
# DBUSER="/:@PROD"
# In questo caso configura il wallet TNS:
# mkstore -wrl /etc/check_mk/oracle_wallet -create
# mkstore -wrl /etc/check_mk/oracle_wallet -createCredential PROD checkmk_monitor "StrongP@ss2026!"

# ORACLE_HOME (se non e gia impostato)
ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1

# Sezioni da abilitare
# Uncomment per disabilitare sezioni non necessarie:
# EXCLUDE_SECTIONS="instance tablespaces dataguard asm rman recovery_area"

# Per RAC: definisci tutte le istanze
# DBUSER_PROD1="checkmk_monitor:pwd::node1:1521:PROD1"
# DBUSER_PROD2="checkmk_monitor:pwd::node2:1521:PROD2"

# Per ASM
# ASMUSER="asmsnmp:pwd::+ASM"
EOF
```

### 4.3 Verifica Plugin

```bash
# Esegui manualmente il plugin
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
/usr/lib/check_mk_agent/plugins/300/mk_oracle

# Output atteso:
# <<<oracle_instance>>>
# PROD|STARTED|OPEN|READ WRITE|...
# <<<oracle_tablespaces>>>
# PROD|SYSTEM|ONLINE|...
# <<<oracle_dataguard_stats>>>
# ...
```

### 4.4 Troubleshooting Plugin

```bash
# Debug mode
MK_ORACLE_DEBUG=1 /usr/lib/check_mk_agent/plugins/300/mk_oracle 2>&1 | head -100

# Check log
cat /var/log/mk_oracle.log

# Check permessi
ls -la /usr/lib/check_mk_agent/plugins/300/mk_oracle
ls -la /etc/check_mk/mk_oracle.cfg

# Line endings (se copiato da Windows)
file /usr/lib/check_mk_agent/plugins/300/mk_oracle
# Deve dire: "Bourne-Again shell script, ASCII text executable"
# Se dice "with CRLF line terminators": dos2unix mk_oracle

# Test sqlplus con l'utente monitoring
su - oracle -c "sqlplus checkmk_monitor/pwd@PROD"
```

---

## PARTE III — CONFIGURAZIONE SOGLIE E ALERTING

---

## 5. Configurazione Soglie

### 5.1 Tablespace

```
Setup → Services → Service monitoring rules → Oracle Tablespaces
- Warning: 85%
- Critical: 95%
- Eccezioni per tablespace grandi: 90% / 98%
```

### 5.2 RMAN Backup Age

```
Setup → Services → Service monitoring rules → Oracle RMAN Backup
- Warning: 26 hours  (tollera 2h di ritardo)
- Critical: 50 hours (backup completamente mancato)
```

### 5.3 Data Guard Lag

```
Setup → Services → Service monitoring rules → Oracle Dataguard Stats
- Transport Lag Warning: 30 minutes
- Transport Lag Critical: 60 minutes
- Apply Lag Warning: 60 minutes
- Apply Lag Critical: 120 minutes
```

### 5.4 Recovery Area (FRA)

```
Setup → Services → Service monitoring rules → Oracle Recovery Area
- Warning: 80%
- Critical: 90%
```

### 5.5 Session Count

```
Setup → Services → Service monitoring rules → Oracle Sessions
- Warning: 80% of max sessions
- Critical: 95% of max sessions
```

---

## 6. Notifiche e Escalation

### 6.1 Configurare Notifiche Email

```
Setup → Events → Notification rules → Add rule
- Condition: Service label = oracle
- Contact: dba-team@company.com
- Method: HTML Email
- Timing: Immediate for CRIT, 15 min delay for WARN
```

### 6.2 Configurare Escalation

```
Setup → Events → Notification rules → Add rule (escalation)
- Condition: Service in CRIT for > 30 minutes
- Contact: dba-manager@company.com, oncall-dba@company.com
- Method: Email + SMS (via plugin)
```

### 6.3 Business Intelligence (BI Aggregation)

```
Setup → Business Intelligence → BI Packs
- Crea aggregazione "Oracle Production Database"
  - Includes: Instance, Tablespaces, RMAN, DataGuard
  - Worst state aggregation
  - Dashboard: Business > BI > Oracle Production
```

---

## PARTE IV — CONFIGURAZIONI AVANZATE

---

## 7. RAC Monitoring

```bash
# mk_oracle.cfg per RAC
# Definisci un DBUSER per ogni istanza
DBUSER_PROD1="checkmk_monitor:pwd::racnode1:1521:PROD1"
DBUSER_PROD2="checkmk_monitor:pwd::racnode2:1521:PROD2"

# Se usi SCAN listener:
DBUSER_PROD="checkmk_monitor:pwd::scan-listener:1521:PROD"
```

In CheckMK, crea un host per ogni nodo RAC + un host "cluster" per la vista aggregata.

## 8. Data Guard Monitoring

Il plugin `mk_oracle` rileva automaticamente Data Guard se connesso a primary o standby.

```sql
-- Verifica che l'utente possa leggere i dati DG
SELECT name, value FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
```

## 9. ASM Monitoring

```bash
# mk_oracle.cfg — sezione ASM
ASMUSER="asmsnmp:AsmPwd::+ASM:1521"

# Se l'ASM e su un ORACLE_HOME diverso
ASM_ORACLE_HOME=/u01/app/19.0.0/grid
```

## 10. Monitoring Remoto (Piggyback)

Se non puoi installare l'agent sull'host Oracle (es. Cloud, RDS):

```bash
# Installa il plugin su un host "proxy"
# mk_oracle.cfg sull'host proxy:
DBUSER="checkmk_monitor:pwd::remote-oracle-host:1521:PROD"
REMOTE_ORACLE_HOST="remote-oracle-host"

# In CheckMK, crea l'host "remote-oracle-host" e il proxy host.
# I dati verranno piggybackati.
```

---

## 11. Custom Checks (SQL Queries Personalizzate)

```sql
-- Crea una view per un check custom
CREATE OR REPLACE VIEW checkmk_monitor.v_custom_check AS
SELECT 
  CASE 
    WHEN COUNT(*) > 100 THEN 2  -- CRITICAL
    WHEN COUNT(*) > 50 THEN 1   -- WARNING
    ELSE 0                       -- OK
  END AS status,
  'Pending transactions: ' || COUNT(*) AS detail
FROM dba_2pc_pending;
```

```bash
# Aggiungi a mk_oracle.cfg
CUSTOM_SQLS_PROD="/etc/check_mk/oracle_custom_sqls/"

# Crea il file SQL
cat > /etc/check_mk/oracle_custom_sqls/pending_tx.sql <<'EOF'
-- custom check: pending transactions
SELECT status, detail FROM checkmk_monitor.v_custom_check;
EOF
```

---

## 12. Troubleshooting CheckMK + Oracle

| Problema | Causa | Risoluzione |
|---|---|---|
| No Oracle services in discovery | Plugin non eseguito | Verifica path, permessi, ORACLE_HOME |
| "Cannot find sqlplus" | ORACLE_HOME non impostato | Imposta in mk_oracle.cfg |
| Permission denied | File non eseguibile | `chmod 755 mk_oracle` |
| CRLF line endings | File editato su Windows | `dos2unix mk_oracle` |
| Timeout | Query lente o network | Aumenta timeout in plugin config |
| "ORA-01017 invalid credentials" | Password errata | Verifica DBUSER in mk_oracle.cfg |
| Stale data | Plugin eseguito troppo raramente | Riduci intervallo (es. da 300/ a 60/) |
| Agent non raggiungibile | Firewall | Apri porta 6556 |
| TLS registration failed | Certificato non trusted | Usa --trust-cert |
| ASM not detected | ASMUSER non configurato | Aggiungi ASMUSER in mk_oracle.cfg |

---

## 13. Best Practice

```
[x] Utente monitoring con password non-expiring e profilo dedicato
[x] Oracle Wallet per credenziali (no password in chiaro nel config)
[x] Plugin in modalita asincrona (300/ o 60/) per non impattare agent
[x] Soglie calibrate sull'ambiente (no default ciechi)
[x] Notifiche separate per WARN e CRIT con escalation
[x] Dashboard dedicato "Oracle Production" con BI aggregation
[x] Custom checks per metriche applicative specifiche
[x] Test mensile delle notifiche (CRIT simulato)
[x] Documentare tutte le soglie personalizzate
[x] Monitorare anche il plugin stesso (check_mk_agent status)
```

---



---

## PARTE V — CONFIGURAZIONE AVANZATA E DETTAGLI PLUGIN

---

## 15. mk_oracle.cfg — Riferimento Completo Parametri

### 15.1 Formato DBUSER

```bash
# Formato completo:
# DBUSER[_<SID>]="username:password:syspriv:host:port:SID"
#
# Campi:
#   username  - utente monitoring Oracle
#   password  - password (o vuoto se wallet)
#   syspriv   - vuoto, SYSDBA, SYSASM, SYSOPER
#   host      - hostname/IP del DB (vuoto = localhost)
#   port      - porta listener (vuoto = 1521)
#   SID       - nome istanza

# Esempio: utente locale, porta default
DBUSER="checkmk_monitor:StrongP@ss::"

# Esempio: utente con connessione remota
DBUSER="checkmk_monitor:StrongP@ss::dbserver01:1521:PROD"

# Esempio: istanza specifica
DBUSER_PROD="checkmk_monitor:StrongP@ss::dbserver01:1521:PROD"
DBUSER_TEST="checkmk_monitor:TestPwd::dbserver01:1521:TEST"

# Esempio: con SYSDBA (se necessario)
DBUSER_PROD="checkmk_monitor:StrongP@ss:SYSDBA:dbserver01:1521:PROD"

# Esempio: con wallet (no password nel config!)
DBUSER="/::"
# Richiede: wallet configurato in sqlnet.ora + tnsnames.ora
```

### 15.2 ASM User

```bash
# Per monitorare ASM diskgroups
ASMUSER="asmsnmp:AsmP@ss:SYSASM:localhost:1521:+ASM"

# Se ASM ha un ORACLE_HOME diverso
ASM_ORACLE_HOME=/u01/app/19.0.0/grid

# ASM con wallet
ASMUSER="/::SYSASM:localhost:1521:+ASM"
```

### 15.3 Sezioni Disponibili

```bash
# Sezioni SYNC (eseguite ad ogni check, veloci)
SYNC_SECTIONS="instance sessions processes"

# Sezioni ASYNC (eseguite periodicamente, cache)
ASYNC_SECTIONS="tablespaces dataguard_stats rman recovery_area \
                jobs ts_quotas resumable undostat recovery_status \
                longactivesessions asm_diskgroup performance locks"

# Sezioni ASM specifiche
SYNC_ASM_SECTIONS="instance processes"
ASYNC_ASM_SECTIONS="asm_diskgroup"

# Cache timeout (secondi, default 600)
CACHE_MAXAGE=600

# Per ESCLUDERE sezioni (alternativa)
EXCLUDE_SECTIONS="jobs resumable"

# Per ESCLUDERE SID (se ci sono istanze che non vuoi monitorare)
EXCLUDE_SID="dbtest1 dbdev2"
```

### 15.4 Remote Instances (Piggyback)

```bash
# Monitorare database remoti da un host proxy
# Formato: REMOTE_INSTANCE_<N>="user:pwd:syspriv:host:port:piggyback_host:SID:version"

REMOTE_INSTANCE_1="checkmk_monitor:pwd::remote-db01:1521:remote-db01:PROD:19.0"
REMOTE_INSTANCE_2="checkmk_monitor:pwd::remote-db02:1521:remote-db02:TEST:19.0"
REMOTE_INSTANCE_3="checkmk_monitor:pwd::cloud-rds:1521:cloud-rds:RDS01:19.0"

# piggyback_host = hostname come appare in CheckMK
# version = versione Oracle (opzionale, aiuta il plugin)
```

### 15.5 Custom SQL Queries

```bash
# Directory per SQL personalizzati
CUSTOM_SQLS_PROD="/etc/check_mk/oracle_custom/"

# Struttura file SQL:
# -- Ogni file .sql nella directory viene eseguito
# -- L'output deve seguire il formato CheckMK:
# -- campo1|campo2|campo3
```

Esempio file SQL custom:

```sql
-- /etc/check_mk/oracle_custom/pending_tx.sql
-- CheckMK custom check: pending distributed transactions
SELECT
  'pending_tx' AS check_name,
  CASE WHEN COUNT(*) > 100 THEN 2
       WHEN COUNT(*) > 10 THEN 1
       ELSE 0 END AS state,
  COUNT(*) AS count,
  'Pending 2PC transactions: ' || COUNT(*) AS detail
FROM dba_2pc_pending;
```

```sql
-- /etc/check_mk/oracle_custom/invalid_objects.sql
SELECT
  'invalid_objects' AS check_name,
  CASE WHEN COUNT(*) > 50 THEN 2
       WHEN COUNT(*) > 10 THEN 1
       ELSE 0 END AS state,
  COUNT(*) AS count,
  'Invalid objects: ' || COUNT(*) AS detail
FROM dba_objects
WHERE status = 'INVALID';
```

---

## 16. Installazione CheckMK Agent su Windows (Oracle su Windows)

### 16.1 Agent Windows

```powershell
# 1. Download agent MSI dal server CheckMK
# https://checkmk-server/mysite/check_mk/agents/windows/check_mk_agent.msi

# 2. Installa
msiexec /i check_mk_agent.msi /qn

# 3. Plugin mk_oracle per Windows
# Copia mk_oracle.ps1 in:
# C:\ProgramData\checkmk\agent\plugins\

# 4. Configurazione
# C:\ProgramData\checkmk\agent\config\mk_oracle.cfg
# Stesso formato del Linux (DBUSER, ASMUSER, etc.)

# 5. Registra con TLS
& "C:\Program Files (x86)\checkmk\service\cmk-agent-ctl.exe" register `
  --hostname oracledb-win `
  --server checkmk-server --site mysite `
  --user cmkadmin --password "pwd" --trust-cert
```

---

## 17. Dashboard e Visualizzazione

### 17.1 Creare Dashboard Oracle Dedicato

```
1. CheckMK Web UI -> Customize -> Dashboards -> New Dashboard
2. Nome: "Oracle Production Overview"
3. Aggiungi dashlet:
   a. Service state summary (filter: service label = oracle)
   b. Host matrix (filter: host label = oracle_db)
   c. Single metric graph: Tablespace usage top 10
   d. Single metric graph: RMAN backup age
   e. Single metric graph: DataGuard lag
   f. Alert timeline (filter: oracle services)
```

### 17.2 Graph Collections

```
Setup -> General -> Graph Collections -> New
- Nome: "Oracle DB Performance"
- Graphs:
  - oracle_sessions: current/max
  - oracle_tablespace_*: percentage used
  - oracle_rman: backup age per type
  - oracle_dataguard_stats: transport/apply lag
```

---

## 18. Integrazione con OEM (Enterprise Manager)

Se usi sia CheckMK che OEM, ecco come evitare conflitti:

| Metrica | CheckMK | OEM | Note |
|---|---|---|---|
| Instance UP/DOWN | mk_oracle | EM Agent | Entrambi, per ridondanza |
| Tablespace | mk_oracle | EM Metric | Soglie allineate |
| RMAN Backup Age | mk_oracle | EM Job Status | CheckMK come primary |
| Data Guard Lag | mk_oracle | DG Broker | CheckMK come primary |
| Performance (AWR) | Custom SQL | EM Performance Page | OEM preferito per dettaglio |
| OS Metrics | CheckMK Agent | EM Agent | CheckMK per OS, OEM per DB |

---

## 19. Sicurezza del Plugin

### 19.1 Oracle Wallet (Evitare Password in Chiaro)

```bash
# 1. Crea wallet per monitoring
mkstore -wrl /etc/check_mk/oracle_wallet -create

# 2. Aggiungi credenziali
mkstore -wrl /etc/check_mk/oracle_wallet \
  -createCredential PROD checkmk_monitor "StrongP@ss"

# 3. Configura sqlnet.ora per il plugin
cat > /etc/check_mk/sqlnet.ora <<'EOF'
WALLET_LOCATION =
  (SOURCE = (METHOD = FILE)
    (METHOD_DATA = (DIRECTORY = /etc/check_mk/oracle_wallet)))
SQLNET.WALLET_OVERRIDE = TRUE
EOF

# 4. Configura tnsnames.ora
cat > /etc/check_mk/tnsnames.ora <<'EOF'
PROD =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = dbserver01)(PORT = 1521))
    (CONNECT_DATA = (SERVICE_NAME = PROD)))
EOF

# 5. In mk_oracle.cfg: usa wallet
DBUSER="/::"
TNS_ADMIN=/etc/check_mk
```

### 19.2 Permessi File

```bash
# Il plugin deve essere leggibile solo da root/agent
chmod 700 /usr/lib/check_mk_agent/plugins/300/mk_oracle
chmod 600 /etc/check_mk/mk_oracle.cfg
chmod 700 /etc/check_mk/oracle_wallet/
chown root:root /etc/check_mk/mk_oracle.cfg

# Se il plugin esegue come utente check_mk_agent:
# chown check_mk_agent:check_mk_agent /etc/check_mk/mk_oracle.cfg
```

---

## 20. Troubleshooting Completo

| # | Problema | Causa | Diagnostica | Risoluzione |
|---|---|---|---|---|
| 1 | No Oracle services | Plugin non eseguito | `ls -la plugins/300/mk_oracle` | Fix path, chmod 755 |
| 2 | Cannot find sqlplus | ORACLE_HOME mancante | `echo $ORACLE_HOME` | Set in mk_oracle.cfg |
| 3 | Permission denied | File non eseguibile | `file mk_oracle` | `chmod 755`, check owner |
| 4 | CRLF line endings | File editato su Windows | `file mk_oracle` | `dos2unix mk_oracle` |
| 5 | ORA-01017 | Password errata | Test manuale sqlplus | Aggiorna DBUSER |
| 6 | ORA-12154 | TNS not found | `tnsping PROD` | Fix tnsnames.ora |
| 7 | ORA-12541 | Listener down | `lsnrctl status` | Start listener |
| 8 | Stale data | Intervallo troppo alto | Check directory 300/ vs 60/ | Move to 60/ |
| 9 | Agent unreachable | Firewall | `telnet host 6556` | Open port 6556 |
| 10 | TLS registration fail | Cert non trusted | Agent log | `--trust-cert` |
| 11 | ASM not detected | ASMUSER mancante | Check mk_oracle.cfg | Add ASMUSER |
| 12 | Binary permission check | CheckMK 2.2+ security | Agent log | Fix binary perms o disable check |
| 13 | Timeout plugin | Query lente | `time mk_oracle` | Increase CACHE_MAXAGE |
| 14 | Wrong instance data | SID detection fail | `ps -ef \| grep pmon` | Set explicit DBUSER_SID |
| 15 | Tablespace UNKNOWN | Missing privileges | `GRANT SELECT ON dba_data_files` | Add grants |
| 16 | RMAN check empty | No backup metadata | `LIST BACKUP SUMMARY` in RMAN | Ensure backups exist |
| 17 | DG stats missing | Not Enterprise Edition | `SELECT * FROM v$version` | Requires EE license |

---

## 21. Checklist Post-Installazione

```
[ ] Agent installato e registrato con TLS
[ ] Plugin mk_oracle in directory asincrona (60/ o 300/)
[ ] DBUSER configurato con wallet (no password in chiaro)
[ ] Utente monitoring creato con grant minimi
[ ] Connessione testata: sqlplus checkmk_monitor/pwd@SID
[ ] Plugin testato: /usr/lib/check_mk_agent/plugins/300/mk_oracle
[ ] Service Discovery eseguita in CheckMK
[ ] Soglie personalizzate per tablespace, RMAN, DG
[ ] Notifiche configurate per WARN e CRIT
[ ] Dashboard Oracle creato
[ ] Firewall: porta 6556 aperta
[ ] Permessi file: mk_oracle.cfg protetto (600)
[ ] Documentate tutte le soglie personalizzate
[ ] Test notifiche eseguito (simulato CRIT)
```

---

## 22. Riferimenti Completi

- CheckMK Official: Monitoring Oracle Databases
  https://docs.checkmk.com/latest/en/monitoring_oracle.html
- CheckMK Official: Agent Plugin mk_oracle
  https://docs.checkmk.com/latest/en/agent_oracle.html
- CheckMK Official: Linux Agent Installation
  https://docs.checkmk.com/latest/en/agent_linux.html
- CheckMK Official: Agent Bakery
  https://docs.checkmk.com/latest/en/wato_monitoringagents.html
- CheckMK Official: Notification Configuration
  https://docs.checkmk.com/latest/en/notifications.html
- CheckMK Official: Business Intelligence
  https://docs.checkmk.com/latest/en/bi.html
- CheckMK Forum: Oracle Plugin Issues
  https://forum.checkmk.com/c/oracle/
- MOS: Oracle Database Monitoring Best Practices (Doc ID 466173.1)

---

**Documento confidenziale ad uso interno DBA. Ultima revisione: Maggio 2026.**
