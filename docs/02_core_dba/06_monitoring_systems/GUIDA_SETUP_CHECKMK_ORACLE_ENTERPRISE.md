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
| **Database Vault** | Violazioni policy (ORA-47400) | CRIT se violazione |
| **SQL Plan Management** | Baselines non accettate/evolute | WARN se regressione |
| **App Continuity** | Draining timeouts e failover client | WARN se drain lento |
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


### 2.X Configurazione Check Custom per Funzionalità Avanzate

Per monitorare funzionalità Enterprise (Database Vault, SPM, AC), è necessario creare script custom da inserire nella cartella locale dell'agent (`/usr/lib/check_mk_agent/local/`).

#### A) Monitoring Database Vault (Violazioni DVSYS)
Verifica i tentativi di accesso non autorizzati ai Realm protetti:
```bash
#!/bin/bash
# check_oracle_vault_violations.sh
VIOLATIONS=$(sqlplus -s checkmk_monitor/StrongP@ss2026!@PROD <<EOF
set heading off feedback off pagesize 0
SELECT count(*) FROM DVSYS.AUDIT_TRAIL$ WHERE ACTION_NAME='VIOLATION' AND TIMESTAMP > SYSDATE-1/24;
EOF
)
if [ "$VIOLATIONS" -gt 0 ]; then
    echo "2 Oracle_Vault_Violations count=$VIOLATIONS CRITICAL - Rilevate $VIOLATIONS violazioni Database Vault nell'ultima ora!"
else
    echo "0 Oracle_Vault_Violations count=0 OK - Nessuna violazione Database Vault"
fi
```

#### B) Monitoring SQL Plan Management (SPM)
Verifica che i profili e le baseline vengano utilizzati e non ci siano regressioni attive in auto-capture:
```bash
#!/bin/bash
# check_oracle_spm.sh
UNACCEPTED=$(sqlplus -s checkmk_monitor/StrongP@ss2026!@PROD <<EOF
set heading off feedback off pagesize 0
SELECT count(*) FROM dba_sql_plan_baselines WHERE accepted='NO';
EOF
)
if [ "$UNACCEPTED" -gt 10 ]; then
    echo "1 Oracle_SPM_Baselines unaccepted=$UNACCEPTED WARN - $UNACCEPTED SQL Plan Baselines in attesa di evoluzione/accettazione."
else
    echo "0 Oracle_SPM_Baselines unaccepted=$UNACCEPTED OK - SPM Baseline stabili"
fi
```

#### C) Monitoring Application Continuity (AC) e Draining
Monitora lo stato di draining dei servizi per patch zero-downtime:
```bash
#!/bin/bash
# check_oracle_ac_draining.sh
DRAINING=$(srvctl status service -d PROD | grep "draining" | wc -l)
if [ "$DRAINING" -gt 0 ]; then
    echo "1 Oracle_AC_Draining services_draining=$DRAINING WARN - Ci sono $DRAINING servizi attualmente in draining (Possibile rallentamento client)"
else
    echo "0 Oracle_AC_Draining services_draining=0 OK - Nessun servizio in draining"
fi
```

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



---

## PARTE VI — INSTALLAZIONE SERVER CHECKMK

---

## 23. Installazione CheckMK Server

### 23.1 Scelta Edizione

| Edizione | Costo | Caratteristiche |
|---|---|---|
| **Raw (CE)** | Gratuita, open source | Agent, tutti i check, no Agent Bakery |
| **Enterprise (CEE)** | Licenza commerciale | Agent Bakery, Alert Handler, Reporting |
| **Cloud (CCE)** | Licenza cloud | AWS/Azure/GCP native, auto-scaling |
| **Managed (CME)** | MSP license | Multi-tenant, white-label |

Per Oracle DBA: **Enterprise** se possibile (Agent Bakery semplifica enormemente).
Altrimenti **Raw** e gestisci il plugin manualmente.

### 23.2 Installazione su Rocky Linux / RHEL / Oracle Linux

```bash
# 1. Prerequisiti
sudo dnf update -y
sudo dnf install -y epel-release wget

# 2. Download pacchetto (sostituisci con la versione corrente)
wget https://download.checkmk.com/checkmk/2.3.0p16/check-mk-raw-2.3.0p16-el9-38.x86_64.rpm

# 3. Installazione
sudo dnf install -y ./check-mk-raw-2.3.0p16-el9-38.x86_64.rpm

# 4. Se mancano dipendenze
sudo dnf install -y --fix-broken

# 5. Verifica
omd version
```

### 23.3 Installazione su Ubuntu / Debian

```bash
# 1. Prerequisiti
sudo apt update && sudo apt upgrade -y

# 2. Download
wget https://download.checkmk.com/checkmk/2.3.0p16/check-mk-raw-2.3.0p16_0.jammy_amd64.deb

# 3. Installazione
sudo apt install -y ./check-mk-raw-2.3.0p16_0.jammy_amd64.deb

# 4. Verifica
omd version
```

### 23.4 Installazione con Docker

```bash
# Quick start (testing/lab)
docker run -d --name checkmk \
  -p 8080:5000 \
  -v checkmk-data:/omd/sites \
  --tmpfs /opt/omd/sites/cmk/tmp:uid=1000,gid=1000 \
  checkmk/check-mk-raw:2.3.0-latest

# Recupera password admin
docker logs checkmk 2>&1 | grep "password"

# Production con docker-compose
cat > docker-compose.yml <<'COMPOSE'
version: '3.8'
services:
  checkmk:
    image: checkmk/check-mk-raw:2.3.0-latest
    container_name: checkmk
    ports:
      - "8080:5000"
      - "8000:8000"
    volumes:
      - checkmk-data:/omd/sites
    tmpfs:
      - /opt/omd/sites/cmk/tmp:uid=1000,gid=1000
    restart: unless-stopped
    environment:
      - CMK_SITE_ID=mysite
volumes:
  checkmk-data:
COMPOSE

docker-compose up -d
```

### 23.5 Creazione Site OMD

```bash
# Crea un sito di monitoring
sudo omd create mysite

# Output:
# Created new site mysite with version 2.3.0.cre.
# The site can be started with omd start mysite.
# The default web UI is available at http://<hostname>/mysite/
# The admin user for the web login is cmkadmin with password: <auto-generated>

# Imposta password admin
sudo omd su mysite
cmk-passwd cmkadmin
# Inserisci la nuova password

# Avvia il sito
sudo omd start mysite

# Verifica
sudo omd status mysite
```

### 23.6 Firewall

```bash
# Porta web UI
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
# Porta agent
sudo firewall-cmd --permanent --add-port=6556/tcp
# LiveStatus (opzionale, per integrazioni)
sudo firewall-cmd --permanent --add-port=6557/tcp
sudo firewall-cmd --reload
```

---

## PARTE VII — INTERFACCIA WEB: GUIDA PASSO-PASSO

---

## 24. Navigazione Web UI

### 24.1 Login e Dashboard Iniziale

```
URL: http://<checkmk-server>/mysite/
User: cmkadmin
Password: (quella impostata)

Dopo il login:
- Dashboard principale: overview di tutti gli host e servizi
- Barra superiore: Monitor | Customize | Setup | Help
- Sidebar sinistra: Quick search, Views, Dashboards
```

### 24.2 Struttura Menu Principale

| Menu | Contenuto |
|---|---|
| **Monitor** | Vista in tempo reale: hosts, services, events, problems |
| **Customize** | Personalizzazione: dashboards, views, bookmarks |
| **Setup** | Configurazione: hosts, agents, rules, notifications |
| **Help** | Documentazione, info versione |

---

## 25. Aggiungere un Host Oracle — Passo per Passo

### 25.1 Step 1: Crea una Cartella per gli Host Oracle

```
Setup -> Hosts -> Hosts
- Clicca "Add folder"
- Nome: "Oracle Databases"
- Attributi della cartella:
  - Labels: oracle_db:yes
  - Criticality: Production system
- Salva
```

### 25.2 Step 2: Aggiungi il Primo Host

```
All'interno della cartella "Oracle Databases":
- Clicca "Add host"
- Hostname: oracledb01  (deve risolvere via DNS o /etc/hosts)
- Se non hai DNS:
  - IPv4 address: seleziona "Explicit" e inserisci l'IP (es. 192.168.1.100)
- Monitoring agents:
  - Checkmk agent / API integrations: seleziona "Configured API integrations and target host agent"
- Labels: aggiungi "oracle_db:yes" e "environment:production"
- Clicca "Save & run service discovery"
```

### 25.3 Step 3: Service Discovery

```
Dopo il salvataggio, CheckMK contatta l'agent e mostra i servizi scoperti.

Vedrai servizi come:
  - CPU load, Memory, Disk I/O (servizi OS base)
  - Oracle Instance PROD (se mk_oracle funziona)
  - Oracle Tablespace SYSTEM
  - Oracle Tablespace USERS
  - Oracle Tablespace TEMP
  - Oracle RMAN PROD
  - Oracle Recovery Area PROD
  - Oracle Dataguard Stats PROD (se DG attivo)
  - Oracle ASM Diskgroup DATA (se ASM)
  - Oracle Sessions PROD
  - Oracle Locks PROD

Clicca "Accept all" per monitorare tutto.
Oppure seleziona solo quelli che vuoi e clicca "+"
```

### 25.4 Step 4: Attiva le Modifiche

```
IMPORTANTE: Nessuna modifica e attiva finche non la attivi!

- In alto a destra vedrai un'icona gialla con "!"
- Cliccala
- Pagina "Activate changes"
- Clicca "Activate on selected sites"
- Attendi il completamento (pochi secondi)
- Ora l'host e monitorato!
```

### 25.5 Step 5: Verifica nel Monitor

```
Monitor -> Overview -> All hosts
- Cerca "oracledb01"
- Clicca sul nome dell'host
- Vedrai tutti i servizi con stato OK/WARN/CRIT/UNKNOWN
- Clicca su un servizio per vedere dettagli e grafici
```

---

## 26. Configurare le Regole Oracle

### 26.1 Rule: Oracle Plugin Configuration

```
Setup -> Agents -> Agent rules
Cerca: "Oracle databases"
Clicca "Add rule"

Configurazione:
  Login:
    - Username: checkmk_monitor
    - Password: StrongP@ss
    - (oppure: Use credential store)
  
  Instance:
    - SID: PROD
    - Host: localhost (se agent e sull'host Oracle)
    - Port: 1521
  
  Sections:
    [x] Instance
    [x] Sessions
    [x] Tablespaces
    [x] Dataguard Stats
    [x] ASM Diskgroups
    [x] Recovery Area
    [x] RMAN
    [x] Performance
    [x] Jobs
    [x] Locks
    [x] Long Active Sessions
  
  Conditions:
    - Explicit hosts: oracledb01
    (oppure: Folder: Oracle Databases)

Salva e ATTIVA le modifiche.
```

### 26.2 Rule: Tablespace Thresholds

```
Setup -> Services -> Service monitoring rules
Cerca: "Oracle Tablespaces"
Clicca "Add rule"

Parametri:
  - Warning at: 85.0% used
  - Critical at: 95.0% used
  - Magic factor: 0.8 (scala i limiti per tablespace grandi)
  
Conditions:
  - Folder: Oracle Databases
  (si applica a tutti gli host nella cartella)

Salva e attiva.
```

### 26.3 Rule: RMAN Backup Age

```
Setup -> Services -> Service monitoring rules
Cerca: "Oracle RMAN"
Clicca "Add rule"

Parametri:
  - Warning: backup older than 26 hours
  - Critical: backup older than 50 hours
  
Conditions:
  - Folder: Oracle Databases

Salva e attiva.
```

### 26.4 Rule: Data Guard Lag

```
Setup -> Services -> Service monitoring rules
Cerca: "Oracle Dataguard Stats"
Clicca "Add rule"

Parametri:
  - Apply lag Warning: 1800 seconds (30 min)
  - Apply lag Critical: 3600 seconds (1 ora)
  - Transport lag Warning: 900 seconds (15 min)
  - Transport lag Critical: 1800 seconds (30 min)
  
Conditions:
  - Folder: Oracle Databases

Salva e attiva.
```

---

## 27. Notifiche — Setup Completo

### 27.1 Step 1: Crea Contact Groups

```
Setup -> Users -> Contact groups
- Clicca "Add group"
- Name: dba_team
- Alias: DBA Oracle Team
- Salva

Poi assegna i membri:
Setup -> Users -> Users
- Seleziona un utente
- Contact groups: aggiungi "dba_team"
- Email: dba@company.com
- Salva
```

### 27.2 Step 2: Assegna Contact Group agli Host

```
Setup -> Hosts -> Hosts -> cartella "Oracle Databases"
- Proprieta della cartella
- Permissions: Contact groups -> dba_team
- Salva e attiva
```

### 27.3 Step 3: Crea Regola di Notifica Email

```
Setup -> Events -> Notifications
Clicca "Add rule"

Parametri:
  - Description: "Oracle DB Alerts - Email"
  - Notification method: HTML Email
  - Contact selection: All contacts of the object
  - Conditions:
    - Match host folder: Oracle Databases
    - Match service state: CRITICAL, WARNING
    - Time period: 24x7
  
Salva e attiva.
```

### 27.4 Step 4: Regola di Escalation (SMS/PagerDuty)

```
Setup -> Events -> Notifications
Clicca "Add rule"

Parametri:
  - Description: "Oracle DB Escalation - after 30 min"
  - Notification method: PagerDuty (o SMS via gateway)
  - Contact selection: Specific users -> dba_oncall
  - Conditions:
    - Match host folder: Oracle Databases
    - Match service state: CRITICAL only
    - Restrict to notification number: 3 to 999999
      (questo significa: dopo 3 notifiche = ~30 minuti con 10 min interval)
  
Salva e attiva.
```

### 27.5 Step 5: Test Notifiche

```
Setup -> Events -> Test notifications
- Select host: oracledb01
- Select service: Oracle Tablespace USERS
- Simulate state: CRITICAL
- Clicca "Test"
- Verifica che l'email arrivi al team DBA
```

---

## 28. Agent Bakery (Enterprise Edition)

### 28.1 Cos'e l'Agent Bakery

L'Agent Bakery genera pacchetti agent personalizzati (RPM/DEB/MSI)
che includono AUTOMATICAMENTE i plugin configurati (es. mk_oracle)
e le configurazioni (mk_oracle.cfg) basate sulle regole definite.

### 28.2 Processo

```
1. Setup -> Agents -> Agent rules
   - Configura regole per Oracle, Linux, etc.

2. Setup -> Agents -> Windows, Linux, Solaris, AIX
   - Clicca "Bake agents"
   - Attendi il completamento

3. Download il pacchetto per il tuo OS:
   - .rpm per RHEL/Oracle Linux
   - .deb per Ubuntu/Debian
   - .msi per Windows

4. Installa sull'host Oracle:
   sudo rpm -Uvh check-mk-agent-2.3.0-1.x86_64.rpm

5. L'agent include gia:
   - mk_oracle plugin nella directory corretta
   - mk_oracle.cfg con le credenziali configurate
   - Intervallo asincrono configurato
```

### 28.3 Auto-Update Agent (CEE 2.1+)

```
Setup -> Agents -> Agent auto-update
- Abilita auto-update
- Gli agent si aggiornano automaticamente quando fai "Bake agents"
- Nessun intervento manuale sugli host!
```


---

## 29. Riferimenti Completi

- CheckMK Official: Getting Started Guide
  https://docs.checkmk.com/latest/en/intro_setup.html
- CheckMK Official: Monitoring Oracle Databases
  https://docs.checkmk.com/latest/en/monitoring_oracle.html
- CheckMK Official: Agent Plugin mk_oracle
  https://docs.checkmk.com/latest/en/agent_oracle.html
- CheckMK Official: Linux Agent Installation
  https://docs.checkmk.com/latest/en/agent_linux.html
- CheckMK Official: Windows Agent Installation
  https://docs.checkmk.com/latest/en/agent_windows.html
- CheckMK Official: Agent Bakery
  https://docs.checkmk.com/latest/en/wato_monitoringagents.html
- CheckMK Official: Notification Configuration
  https://docs.checkmk.com/latest/en/notifications.html
- CheckMK Official: Business Intelligence
  https://docs.checkmk.com/latest/en/bi.html
- CheckMK Official: Docker Installation
  https://docs.checkmk.com/latest/en/introduction_docker.html
- CheckMK Official: Host Management
  https://docs.checkmk.com/latest/en/hosts_setup.html
- CheckMK Official: Service Discovery
  https://docs.checkmk.com/latest/en/wato_services.html
- CheckMK Forum: Oracle Plugin Issues
  https://forum.checkmk.com/c/oracle/
- MOS: Oracle Database Monitoring Best Practices (Doc ID 466173.1)

---

**Documento confidenziale ad uso interno DBA. Ultima revisione: Maggio 2026.**


---

## 11. 📈 CheckMK Business Intelligence (BI) per Oracle

Il modulo **Business Intelligence (BI)** di CheckMK permette di aggregare lo stato di decine di servizi database (Tablespace, Alert Log, Processi) in un unico **Stato di Servizio Business** (es. "ERP Database Health"). Questo è cruciale in ambienti Enterprise per non sommergere i manager di alert tecnici, ma mostrare solo il "semaforo" del servizio finale.

### Fase 1: Creazione BI Rules (Regole Logiche)
Le regole definiscono *come* i servizi tecnici influenzano il servizio Business.

1. Vai in `Setup` -> `Business Intelligence` -> `Rules`.
2. Crea una regola **"Oracle Core Health"**.
3. Aggiungi i seguenti **Nodi Figli (Child nodes)**:
   * **Stato Istanza:** `Service: Oracle Instance .*`
   * **Stato Listener:** `Service: Listener .*`
   * **Spazio Tablespace:** `Service: ORA .* Tablespace .*` (Imposta come "Worst state" - se un TBS è critico, tutto è critico).
   * **Errori Alert Log:** `Service: ORA .* Alert Log`

### Fase 2: Creazione BI Aggregation
1. Vai in `Setup` -> `Business Intelligence` -> `Aggregations`.
2. Crea una nuova Aggregazione e chiamala **"Produzione ERP Database"**.
3. Associala alla regola "Oracle Core Health" creata prima.
4. Ora nella dashboard principale di CheckMK avrai un **Macro-Semaforo** che raggruppa tutti gli allarmi tecnici sotto un'unica voce, filtrando il rumore.

---

## 12. 🛠️ Custom Local Checks per Oracle (Bash & Python)

Se il plugin ufficiale `mk_oracle` non copre un tuo script SQL proprietario o un'esigenza di business molto specifica (es. "Ci sono ordini bloccati in tabella XYZ?"), puoi scrivere un **Local Check**.

Un Local Check è uno script eseguibile che l'Agent CheckMK lancia sul server Oracle e il cui output viene processato automaticamente senza bisogno di scrivere plugin complessi in Python lato server.

### Sintassi di Output CheckMK
Lo script deve stampare a terminale una riga in questo formato esatto:
`Stato "Nome Servizio" Metriche Testo Descrittivo`
* **Stato:** `0` (OK), `1` (WARNING), `2` (CRITICAL), `3` (UNKNOWN).

### Esempio: Check Bash per Errori Custom
Crea il file `/usr/lib/check_mk_agent/local/oracle_custom_check.sh`:

```bash
#!/bin/bash
# Local check per contare righe in una tabella di LOG applicativo Oracle

export ORACLE_HOME=/u01/app/oracle/product/19.3.0/dbhome_1
export ORACLE_SID=PRODDB

COUNT=$(su - oracle -c "$ORACLE_HOME/bin/sqlplus -S / as sysdba <<EOF
SET PAGESIZE 0 FEEDBACK OFF
SELECT COUNT(*) FROM applicativo.tabella_errori WHERE row_date >= SYSDATE - 1;
EOF" | xargs)

if [ "$COUNT" -ge 100 ]; then
    echo "2 \"App Errors\" count=$COUNT Oltre 100 errori ($COUNT) registrati nelle ultime 24h!"
elif [ "$COUNT" -ge 50 ]; then
    echo "1 \"App Errors\" count=$COUNT Attenzione: $COUNT errori nelle ultime 24h."
else
    echo "0 \"App Errors\" count=$COUNT OK: Nessun errore anomalo ($COUNT)."
fi
```

### Esecuzione Asincrona (Efficienza)
Le query SQL pesanti non devono girare ogni minuto (il default di CheckMK).
Per far girare questo local check solo **ogni 5 minuti (300 secondi)**:
1. Crea la cartella: `mkdir -p /usr/lib/check_mk_agent/local/300/`
2. Sposta lo script lì dentro: `mv oracle_custom_check.sh /usr/lib/check_mk_agent/local/300/`
3. Dai permessi di esecuzione: `chmod +x /usr/lib/check_mk_agent/local/300/oracle_custom_check.sh`

Al prossimo discovery, CheckMK rileverà automaticamente il nuovo servizio chiamato **App Errors**!

---

## 13. 🌍 Distributed Monitoring (Multi-Datacenter RAC)
Se hai un Database RAC steso su due Data Center (es. Primary a Milano, Standby a Roma) o se usi il Cloud OCI:
1. Installa un **CheckMK Central Server** (Milano).
2. Installa un **CheckMK Remote Site** (Roma / OCI).
3. Collega il Remote Site al Central Site via Livestatus TCP (porta 6557 criptata con TLS).
4. Assegna gli host di Roma al server di polling di Roma.
*Vantaggio:* Se cade la VPN tra Milano e Roma, il server di Roma continua a monitorare il DB Standby e trattiene gli alert. Quando la VPN torna su, invia lo storico al server centrale senza alcun "buco" nei grafici.


---

## 14. 🎨 Integrazione CheckMK + Grafana (Dashboarding Avanzato)

Se hai l'esigenza di creare dashboard visivamente più accattivanti e correlare le metriche Oracle estratte da CheckMK con dati provenienti da altre fonti, puoi **integrare nativamente CheckMK con Grafana** utilizzando il plugin ufficiale.

L'integrazione è bidirezionale a livello di interrogazione (Grafana usa le REST API di CheckMK per estrarre storici, grafici e stati).

### Fase 1: Preparazione Utente CheckMK (Automation User)
Per ragioni di sicurezza, Grafana **NON** deve usare l'account `cmkadmin`.
1. Accedi a CheckMK e vai in `Setup` -> `Users`.
2. Crea un nuovo utente chiamato `grafana_api`.
3. Invece di una password normale, genera un **Automation Secret** per questo utente.
4. **Ruolo:** Clona il ruolo `Guest` e aggiungi il permesso speciale `"User management" (allow read access to user information)` necessario per l'API. Assegna questo ruolo all'utente.

### Fase 2: Installazione Plugin su Grafana
Sul tuo server Grafana, esegui l'installazione del plugin ufficale CheckMK Cloud Datasource da riga di comando:

```bash
grafana-cli plugins install checkmk-cloud-datasource
systemctl restart grafana-server
```

*(Se usi Grafana UI, vai su `Connections` -> `Add new connection` -> Cerca "Checkmk" e clicca Install).*

### Fase 3: Configurazione del Data Source
1. Accedi all'interfaccia web di Grafana come admin.
2. Vai su **Data Sources** -> **Add Data Source** -> Cerca e seleziona **Checkmk**.
3. Compila i campi:
   * **URL:** L'URL completo del tuo sito CheckMK (es. `https://192.168.1.100/mysite/`)
   * **Authentication:** Seleziona "Basic Auth" e inserisci `grafana_api` come utente e l'**Automation Secret** come password.
   * **Edition:** Scegli l'edizione di CheckMK che stai usando (Raw, Enterprise, o Cloud).
4. Clicca su **Save & Test**. Se vedi il bollino verde, i due sistemi comunicano.

### Fase 4: Creazione Dashboard Oracle
Ora puoi creare Dashboard in Grafana!
Quando aggiungi un nuovo "Panel", scegli **Checkmk** come data source. Avrai un'interfaccia a tendina (Query Builder) per selezionare:
* **Site:** Il sito CheckMK.
* **Host:** Il server Oracle (es. `rac1.localdomain`).
* **Service:** La metrica estratta dall'Agent (es. `ORA PRODDB Tablespace USERS`, `CPU load`, o il custom check scritto prima).
* **Aggregation:** Grafana traccerà i trend in base ai parametri di retention storicizzati nativamente in CheckMK.

---

## PARTE VI — MONITORAGGIO AVANZATO 26AI E AUTOMAZIONE

---

## 22. Monitoraggio Oracle 23ai / 26ai (AI & Vector Search)

Con l'avvento dell'AI generativa integrata nel database, il monitoring deve evolversi per tracciare la salute dei vettori e della True Cache.

### 22.1 Monitoraggio Vector Search (AI Vector Search)
Gli indici vettoriali possono essere pesanti per la memoria (SGA).
```sql
-- Custom SQL per CheckMK: Salute degli indici vettoriali
CREATE OR REPLACE VIEW checkmk_monitor.v_vector_health AS
SELECT 
  'vector_indexes' AS check_name,
  CASE WHEN sum(bytes)/1024/1024 > 5000 THEN 1 ELSE 0 END AS state, -- Warn se > 5GB
  'Vector Index Size: ' || round(sum(bytes)/1024/1024, 2) || ' MB' AS detail
FROM dba_segments 
WHERE segment_type = 'VECTOR INDEX';
```

### 22.2 Monitoraggio True Cache
True Cache è una feature di 23ai che scarica le letture su una cache distribuita.
```sql
-- Verifica hit-rate della True Cache
SELECT 
  inst_id, 
  name, 
  value 
FROM gv$true_cache_statistics 
WHERE name = 'true cache hit ratio';
```

---

## 23. Automazione con Ansible (Enterprise Deployment)

In un ambiente Enterprise con 50+ database, non puoi installare l'agente a mano. Usa Ansible.

### 23.1 Playbook: Deploy CheckMK Agent & mk_oracle
```yaml
---
- name: Deploy Oracle Monitoring (CheckMK)
  hosts: oracle_servers
  become: yes
  vars:
    cmk_server: "checkmk-server"
    cmk_site: "mysite"
    cmk_user: "cmkadmin"
    cmk_pwd: "StrongPassword"
    oracle_home: "/u01/app/oracle/product/19.0.0/dbhome_1"

  tasks:
    - name: Install CheckMK Agent RPM
      dnf:
        name: "https://{{ cmk_server }}/{{ cmk_site }}/check_mk/agents/check-mk-agent-2.3.0-1.noarch.rpm"
        state: present
        disable_gpg_check: yes

    - name: Register Agent with TLS
      command: >
        cmk-agent-ctl register --hostname {{ inventory_hostname }}
        --server {{ cmk_server }} --site {{ cmk_site }}
        --user {{ cmk_user }} --password {{ cmk_pwd }} --trust-cert
      args:
        creates: /var/lib/cmk-agent/registered

    - name: Deploy mk_oracle plugin
      get_url:
        url: "https://{{ cmk_server }}/{{ cmk_site }}/check_mk/agents/plugins/mk_oracle"
        dest: /usr/lib/check_mk_agent/plugins/60/mk_oracle
        mode: '0755'

    - name: Configure mk_oracle.cfg
      template:
        src: templates/mk_oracle.cfg.j2
        dest: /etc/check_mk/mk_oracle.cfg
        mode: '0600'
```

---

## 24. Grafana Integration (Executive Dashboards)

CheckMK è ottimo per gli alert, ma Grafana è lo standard per i cockpit di controllo.

### 24.1 Installazione del DataSource CheckMK
1. Su Grafana: `Configuration -> Plugins -> CheckMK`.
2. Aggiungi DataSource: `https://checkmk-server/mysite/check_mk/webapi.py`.
3. Crea Dashboard:
   - **Panel 1**: SGA vs PGA Usage (Graph).
   - **Panel 2**: Transactions Per Second (TPS) across all instances.
   - **Panel 3**: Data Guard Lag (Heatmap).

---

## 25. Matrice di Alerting Enterprise (SLA Protection)

| Metrica | Soglia Warning | Soglia Critical | Azione SRE |
|---|---|---|---|
| **Tablespace** | 85% | 95% | Auto-extend o aggiunta Datafile |
| **Active Sessions** | 70% di CPU cores | 100% di CPU cores | Kill sessioni non critiche / Scaling |
| **Redo Log Switches** | > 10 / ora | > 30 / ora | Ridimensionamento Redo Log Groups |
| **Failed Logins** | 5 / min | 20 / min | Blocco IP a livello Firewall / Brute-force alert |
| **Backup Age** | 26 ore | 48 ore | Restart immediato job RMAN d'emergenza |

---
**Documento di Monitoring certificato per Oracle 26ai.**
