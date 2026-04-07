# FASE 6: Oracle Enterprise Manager Cloud Control 13.5 (Single OMS Lab)

Aggiornata: 13 marzo 2026
Target lab: Oracle Linux 7.9/8.x, Oracle DB 19c, RAC + Data Guard + GoldenGate gia operativi.

Questa fase aggiunge una console centralizzata per monitorare e governare tutto il laboratorio:

- host e metriche OS
- database single instance e RAC
- ASM, listener, Data Guard
- alerting, incident management, notification, jobs, blackout
- monitoraggio backup RMAN

## 6.0A Ingresso da Fase 5 (preflight)

Prima di installare EM, verifica che il lab Oracle sia stabile:

```bash
dgmgrl sys/<password>@RACDB "show configuration;"
```

```sql
-- Sul DB principale che userai come repository EM
sqlplus / as sysdba
SELECT name, open_mode, log_mode FROM v$database;
SELECT value FROM v$parameter WHERE name='compatible';
```

```bash
# Dal nodo emcc1: risoluzione DNS e reachability target
getent hosts rac1 rac2 racstby1 racstby2 dbtarget
```

Gate minimo:

- Data Guard in `SUCCESS`
- repository DB raggiungibile da `emcc1`
- spazio disco e RAM adeguati su `emcc1`

## 6.0B Se OMS e gia installato

Se hai gia un OMS funzionante (test precedenti), non reinstallare:

```bash
$OMS_HOME/bin/emctl status oms -details
$AGENT_HOME/bin/emctl status agent
```

Se `OMS Up` e `Agent Up`, vai direttamente a `6.7` (deploy agent target) oppure `6.8` (onboarding target).

## 6.1 Obiettivo operativo

A fine fase devi avere:

- 1 VM dedicata `emcc1` con OMS + local Agent
- repository database 19c per EM
- target registrati (host + DB + ASM + listener)
- rule set incidenti e notifiche email
- dashboard operative giornaliere
- runbook test alert validato

## 6.2 Architettura consigliata nel tuo lab

Scelta bloccata: Single OMS su VM dedicata.

```text
+------------------------+            +---------------------------+
| emcc1                  |            | dbtarget (o emcc1 local) |
| OMS + Agent + Console  |----------->| Repository DB 19c         |
| Porta console HTTPS    |            | SYSMAN schema             |
+------------+-----------+            +-------------+-------------+
             |
             | Agent uploads / discovery
             v
+----------------+  +----------------+  +----------------+
| RAC primary    |  | RAC standby    |  | dbtarget       |
| host/db/asm    |  | host/db/asm    |  | host/db/listnr |
+----------------+  +----------------+  +----------------+
```

Nota pratica:

- In lab puoi mettere repository DB su `dbtarget` per risparmiare RAM.
- In produzione si preferisce separazione dedicata OMS vs repository.

## 6.3 Prerequisiti minimi

## 6.3.1 Hardware VM `emcc1`

Minimo lab:

- vCPU: 4
- RAM: 12 GB (16 GB consigliati)
- Disk: 120 GB

Con 8 GB RAM OMS tende a saturarsi durante discovery e patching console.

## 6.3.2 Software

- Oracle Linux 7.9 o 8.x
- JDK supportato dalla release EM 13.5
- pacchetti OS richiesti dall installer
- install media EM 13.5 + eventuale RU

## 6.3.3 Rete e porte

Apri almeno:

- 7802/7803 (upload/communication, dipende da configurazione)
- 3872 (agent)
- 4903, 4904 (OMS internal)
- 1521 (repository DB)
- 7803 (console HTTPS OMS default, oppure porta custom scelta in installazione)

Usa DNS risolvibile per:

- `emcc1`
- nodi RAC e standby
- host repository DB

## 6.3.4 Utenti e path consigliati

- utente software OMS: `oracle` (lab) o `omsuser` (enterprise)
- base directory: `/u01/app/oracle`
- middleware home OMS: `/u01/app/oracle/middleware`
- software media: `/u01/software/em13c`

## 6.4 Preparazione VM emcc1

```bash
# hostname e risoluzione
hostnamectl set-hostname emcc1

# swap consigliata per OMS in lab
free -h
swapon --show

# controlli kernel/network (esempio)
ulimit -n
sysctl -a | egrep "fs.file-max|net.core.somaxconn" 
```

Verifica NTP/chrony su tutte le VM, altrimenti avrai falsi alert e metriche incoerenti.

## 6.5 Repository DB 19c per Enterprise Manager

Puoi usare:

- opzione A: repository nel database `dbtarget`
- opzione B: repository locale su `emcc1`

Per lab e sufficiente opzione A.

Checklist repository DB:

- ARCHIVELOG ON
- character set supportato
- spazio tablespace adeguato per SYSMAN/MGMT_TABLESPACE
- listener e service raggiungibili da `emcc1`

Controlli rapidi:

```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT value FROM v$parameter WHERE name='compatible';
```

## 6.6 Installazione OMS 13.5 da zero

## 6.6.1 Installazione grafica (consigliata in lab)

1. Copia software EM su `emcc1`.
2. Estrai/esegui installer.
3. Seleziona "Install a new Enterprise Manager System".
4. Inserisci connessione repository DB.
5. Definisci password SYSMAN e porta console.
6. Completa prereq check e install.

Esempio avvio installer:

```bash
cd /u01/software/em13c
chmod +x em13500_linux64.bin
./em13500_linux64.bin
```

## 6.6.2 Comandi post-install obbligatori

```bash
# OMS status
/u01/app/oracle/middleware/bin/emctl status oms -details

# Agent locale status
/u01/app/oracle/agent/agent_inst/bin/emctl status agent

# URL console
/u01/app/oracle/middleware/bin/emctl status oms -details | egrep "Console URL|Upload URL"
```

Login console:

- URL: `https://emcc1:<porta_oms>/em`
- user: `SYSMAN`

## 6.7 Deploy agent sui target host

Per ogni host target (rac1, rac2, racstby1, racstby2, dbtarget):

1. Deploy Agent da console (Add Host Targets).
2. Configura named credentials SSH + sudo.
3. Verifica upload heartbeat agent.

Comandi diagnostici su host target:

```bash
$AGENT_HOME/bin/emctl status agent
$AGENT_HOME/bin/emctl upload agent
$AGENT_HOME/bin/emctl clearstate agent
```

## 6.8 Onboarding target Oracle

Ordine consigliato:

1. Host target
2. Listener
3. Database instances
4. ASM instance + diskgroups
5. RAC database target
6. Data Guard association

Verifiche minime in console:

- target status: Up
- metric collection senza errori
- availability timeline coerente

## 6.9 Setup operativo giornaliero

## 6.9.1 Dashboard e homepage

Crea homepage operative:

- Infrastructure Overview
- Database Group (RAC primary)
- Database Group (standby + target)
- Critical Incidents

## 6.9.2 Metric thresholds

Definisci soglie realistiche per lab:

- CPU host > 85% per 15 min
- Filesystem usage > 85%
- Tablespace usage > 85%
- Failed login attempts
- Data Guard transport/apply lag

## 6.9.3 Incident Rules

Crea almeno due rule set:

- `LAB_CRITICAL_DB`
- `LAB_WARNING_INFRA`

Routing esempio:

- Critical -> email immediata
- Warning -> digest ogni 30 minuti

## 6.9.4 Notifications (SMTP)

Configura:

- SMTP server
- sender address
- recipient groups (DBA team)

Testa con invio notifica di prova e con incidente reale simulato.

## 6.9.5 Jobs e library

Crea job standard:

- SQL health check giornaliero
- check FRA usage
- verifica Data Guard lag
- stato backup RMAN

Salva job template nella library per riuso.

## 6.9.6 Blackout

Usa blackout per manutenzione:

- patching Grid/DB
- reboot host
- test failover/switchover

Regola: nessuna attivita pianificata senza blackout aperto.

## 6.10 Monitoraggio specifico RMAN

In EM crea viste/favorite su:

- ultimo backup job
- backup failed negli ultimi 7 giorni
- recovery area usage
- missing archived logs

Cross-check SQL utile:

```sql
SELECT session_key, input_type, status, start_time, end_time
FROM v$rman_backup_job_details
ORDER BY session_key DESC;
```

Collega questa fase alla tua guida:

- `GUIDA_FASE5_RMAN_BACKUP.md`

## 6.11 Runbook test pratici (lab)

Ogni test deve registrare: data, obiettivo, tempo rilevazione alert, esito.

## Test 1 - Alert CPU host

1. genera carico CPU su `dbtarget`
2. attende superamento soglia
3. verifica incidente e notifica email

Esito atteso:

- incidente warning/critical creato
- email ricevuta

## Test 2 - Tablespace alert

1. riempi tablespace test oltre soglia
2. verifica evento in EM
3. riduci uso tablespace e chiudi incidente

Esito atteso:

- incidente auto-clear dopo rientro soglia

## Test 3 - Listener down

1. stop listener su host target
2. verifica target unavailable
3. restart listener

Esito atteso:

- stato target torna Up e incidente chiuso

## Test 4 - Data Guard lag

1. simula backlog apply (lab controllato)
2. verifica metrica lag e incidente
3. ripristina apply realtime

Esito atteso:

- alert DG visibile nella dashboard

## Test 5 - Job fail/success

1. crea job SQL con errore intenzionale
2. verifica fallimento e notifica
3. correggi job e riesegui

Esito atteso:

- storico job mostra fail poi success

## 6.12 Troubleshooting piu comune

## Agent down

Sintomi:

- host target Down
- last upload timestamp vecchio

Azioni:

```bash
$AGENT_HOME/bin/emctl status agent
$AGENT_HOME/bin/emctl start agent
$AGENT_HOME/bin/emctl upload agent
```

## Upload backlog OMS

Sintomi:

- metriche in ritardo
- pending uploads alto

Azioni:

- verifica risorse OMS (CPU/RAM/disk)
- controlla repository DB load
- riavvio controllato OMS in finestra manutenzione

```bash
$OMS_HOME/bin/emctl status oms -details
$OMS_HOME/bin/emctl stop oms -all
$OMS_HOME/bin/emctl start oms
```

## Target unavailable ma host raggiungibile

Azioni:

- valida credentials target
- forzare rediscovery
- controlla listener/service

## Metric collection error

Azioni:

- review metric extension e collection schedule
- verifica privilegio DB user monitor
- controlla clock drift host/OMS

## 6.13 Hardening minimo consigliato in lab

- password policy forte per SYSMAN e named credentials
- backup periodico repository DB
- snapshot VM pre-change
- audit delle modifiche di soglie/rules/job

## 6.14 Checklist di completamento fase 6

- OMS Up e console accessibile
- agent deployato su tutti i nodi target
- RAC + standby + dbtarget visibili e monitorati
- rule set incidenti attivo
- notifiche email testate
- almeno 5 test runbook eseguiti con esito registrato

## 6.15 Integrazione con il resto del lab

Dopo questa fase puoi:

- usare EM per seguire switchover/failover in tempo reale
- correlare alert DG con backup RMAN
- schedulare controlli DBA periodici
- avere evidenze operative per review/cv

## 6.16 Installazione Silente OMS (Response File)

Per automazione e ripetibilità, usa il response file:

```bash
# Genera response file template
./em13500_linux64.bin -getResponseFileTemplates -outputLoc /tmp/em_templates

# Compila il response file (esempio chiave)
cat > /tmp/em_install.rsp <<'EOF'
RESPONSEFILE_VERSION=2.2.1.0.0
INSTALL_TYPE="TYPICAL"

# Percorsi
ORACLE_MIDDLEWARE_HOME_LOCATION="/u01/app/oracle/middleware"
ORACLE_HOSTNAME=emcc1
AGENT_BASE_DIR="/u01/app/oracle/agent"

# Repository DB
DATABASE_HOSTNAME=dbtarget
LISTENER_PORT=1521
SERVICENAME_OR_SID=EMREP
SYS_PASSWORD=<sys_password>
SYSMAN_PASSWORD=<sysman_password>

# Console
MANAGEMENT_TABLESPACE_LOCATION=+DATA/{DB_UNIQUE_NAME}/datafile/mgmt.dbf
CONFIGURATION_DATA_TABLESPACE_LOCATION=+DATA/{DB_UNIQUE_NAME}/datafile/mgmt_ecm_depot.dbf
JVM_DIAGNOSTICS_TABLESPACE_LOCATION=+DATA/{DB_UNIQUE_NAME}/datafile/mgmt_deepdive.dbf

# Plugin
PLUGIN_SELECTION="{\"oracle.sysman.db\":\"13.5.0.0.0\",\"oracle.sysman.emas\":\"13.5.0.0.0\"}"

# Security
WLS_ADMIN_SERVER_USERNAME=weblogic
WLS_ADMIN_SERVER_PASSWORD=<wls_password>
WLS_ADMIN_SERVER_CONFIRM_PASSWORD=<wls_password>

# Porte (default o custom)
EM_UPLOAD_PORT=4903
EM_CENTRAL_CONSOLE_PORT=7803
EOF
```

```bash
# Installazione silente
./em13500_linux64.bin -silent -responseFile /tmp/em_install.rsp \
  -invPtrLoc /etc/oraInst.loc \
  -J-Djava.io.tmpdir=/tmp

# Post-install root scripts
sudo /u01/app/oracle/middleware/allroot.sh
```

> **Best Practice**: In produzione, salva il response file (senza password) nel repository per riproducibilità. Le password vanno gestite via vault o variabili d'ambiente.

---

## 6.17 EMCLI — Command Line Interface

`emcli` è il tool da riga di comando per automatizzare EM. Essenziale per DBA che vogliono scriptare le operazioni.

### Setup Iniziale

```bash
# Configura emcli
$OMS_HOME/bin/emcli setup \
  -url=https://emcc1:7803/em \
  -username=SYSMAN \
  -password=<password> \
  -trustall

# Login (sessione)
$OMS_HOME/bin/emcli login -username=SYSMAN -password=<password>
```

### Comandi Essenziali

```bash
# Lista target
emcli get_targets -targets="oracle_database"
emcli get_targets -targets="host"
emcli get_targets -targets="osm_instance"    # ASM

# Status target specifico
emcli get_targets -targets="RACDB:rac_database" -format="name:csv"

# Lista incidenti aperti
emcli get_open_incidents

# Crea blackout
emcli create_blackout \
  -name="PATCHING_RAC_$(date +%Y%m%d)" \
  -add_targets="RACDB:rac_database" \
  -schedule="duration::02:00" \
  -reason="RU Patching"

# Rimuovi blackout
emcli stop_blackout -name="PATCHING_RAC_20260407"

# Job submission
emcli submit_job \
  -name="RMAN_HEALTH_CHECK" \
  -type="SQLScript" \
  -targets="RACDB:rac_database" \
  -input="sql_script:SELECT status FROM v$instance;"
```

### Script di Health Check via EMCLI

```bash
#!/bin/bash
# /home/oracle/scripts/em_health_check.sh
# Verifica rapida via EMCLI

$OMS_HOME/bin/emcli login -username=SYSMAN -password=$(cat /home/oracle/.em_pwd)

echo "=== TARGET STATUS ==="
$OMS_HOME/bin/emcli get_targets -targets="oracle_database" -format="name:pretty" \
  | grep -E "Status|RACDB"

echo ""
echo "=== INCIDENTI APERTI ==="
$OMS_HOME/bin/emcli get_open_incidents | head -20

echo ""
echo "=== BLACKOUT ATTIVI ==="
$OMS_HOME/bin/emcli get_blackouts -format="name:pretty" | grep "ACTIVE"
```

---

## 6.18 Metric Extensions — Metriche Custom

Le Metric Extensions permettono di creare metriche personalizzate per monitorare ciò che EM non copre di default.

### Esempio 1: Monitorare Tabelle con Troppi Extent

```sql
-- Query per la Metric Extension
SELECT owner, segment_name, extents, bytes/1024/1024 AS mb
FROM dba_segments
WHERE extents > 500
ORDER BY extents DESC;
```

**Setup nella Console EM:**
1. Enterprise → Monitoring → Metric Extensions → Create
2. Target Type: `Database Instance`
3. Collection Type: `SQL`
4. Incolla la query sopra
5. Definisci colonne: Owner, Segment, Extents (metrica), Size_MB (metrica)
6. Alert: Warning se extents > 500, Critical se > 1000
7. Deploy sul target group RAC

### Esempio 2: Monitorare FRA Usage (più granulare)

```sql
SELECT
    name,
    ROUND(space_limit/1024/1024/1024, 1) AS limit_gb,
    ROUND(space_used/1024/1024/1024, 1) AS used_gb,
    ROUND(space_used/space_limit * 100, 1) AS pct_used
FROM v$recovery_file_dest;
```

### Esempio 3: Data Guard Lag Alert Custom

```sql
SELECT
    name AS metric_name,
    TO_NUMBER(REGEXP_SUBSTR(value, '\d+')) AS lag_seconds
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');
```

> **Importante**: Le Metric Extensions devono essere testate su un target singolo prima del deploy massivo. Usa la Console EM per il test prima di gestirle via EMCLI.

---

## 6.19 Riferimenti ufficiali Oracle (13.5)

- Oracle Enterprise Manager Cloud Control Basic Installation Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/embsc/index.html
- Oracle Enterprise Manager Cloud Control Advanced Installation and Configuration Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadv/index.html
- Oracle Enterprise Manager Cloud Control Administrator's Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/index.html
- Oracle Enterprise Manager Cloud Control Monitoring Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emmon/index.html
- EMCLI Reference:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emcli/index.html
- Metric Extensions:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/creating-metric-extensions.html
- Incidents and Problems in EM 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/managing-incidents.html
- Management Agent administration in EM 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/management-agent.html
- Blackouts in EM 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/administering-blackouts.html
- Jobs and Automation in EM 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/administering-jobs.html
- Notifications in EM 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/managing-notifications.html

---

**→ Prossimo: [FASE 7: Configurazione GoldenGate Locale e Cloud](./GUIDA_FASE7_GOLDENGATE.md)**
