# PHASE 8: Oracle Enterprise Manager Cloud Control 13.5 (Single OMS Lab)

Aggiornata: 13 marzo 2026
Target lab: Oracle Linux 7.9/8.x, Oracle DB 19c, RAC + Data Guard + GoldenGate gia operativi.

This phase adds a centralized console to monitor and govern the entire laboratory:

- host e metriche OS
- database single instance e RAC
- ASM, listener, Data Guard
- alerting, incident management, notification, jobs, blackout
- monitoraggio backup RMAN

## 8.0A Input from Phase 7 (preflight)

Before installing EM, verify that the Oracle lab is stable:

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

## 8.0B Se OMS e gia installato

Se hai gia un OMS funzionante (test precedenti), non reinstallare:

```bash
$OMS_HOME/bin/emctl status oms -details
$AGENT_HOME/bin/emctl status agent
```

Se `OMS Up` e `Agent Up`, vai direttamente a `8.7` (deploy agent target) oppure `8.8` (onboarding target).

## 8.1 Operational objective

At the end of the phase you must have:

- 1 VM dedicata `emcc1` con OMS + local Agent
- repository database 19c per EM
- registered targets (host + DB + ASM + listener)
- rule set incidenti e notifiche email
- dashboard operative giornaliere
- runbook test alert validato

## 8.2 Architettura consigliata nel tuo lab

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

- In lab you can put DB repository on `dbtarget` per risparmiare RAM.
- In production, dedicated OMS vs repository separation is preferred.

## 8.3 Prerequisiti minimi

## 8.3.1 Hardware VM `emcc1`

Minimo lab:

- vCPU: 4
- RAM: 12 GB (16 GB consigliati)
- Disk: 120 GB

Con 8 GB RAM OMS tende a saturarsi durante discovery e patching console.

## 8.3.2 Software

- Oracle Linux 7.9 o 8.x
- JDK supportato dalla release EM 13.5
- pacchetti OS richiesti dall installer
- install media EM 13.5 + eventuale RU

## 8.3.3 Network and ports

Apri almeno:

- 7802/7803 (upload/communication, depends on configuration)
- 3872 (agent)
- 4903, 4904 (OMS internal)
- 1521 (repository DB)
- 7803 (console HTTPS OMS default, oppure porta custom scelta in installazione)

Usa DNS risolvibile per:

- `emcc1`
- RAC and standby nodes
- host repository DB

## 8.3.4 Recommended users and paths

- OMS software user: `oracle` (lab) o `omsuser` (enterprise)
- base directory: `/u01/app/oracle`
- middleware home OMS: `/u01/app/oracle/middleware`
- software media: `/u01/software/em13c`

## 8.4 Preparazione VM emcc1

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

Check NTP/chrony on all VMs, otherwise you will have false alerts and inconsistent metrics.

## 8.5 Repository DB 19c per Enterprise Manager

You can use:

- opzione A: repository nel database `dbtarget`
- opzione B: repository locale su `emcc1`

Per lab e sufficiente opzione A.

Checklist repository DB:

- ARCHIVELOG ON
- character set supportato
- spazio tablespace adeguato per SYSMAN/MGMT_TABLESPACE
- listeners and services reachable from `emcc1`

Controlli rapidi:

```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT value FROM v$parameter WHERE name='compatible';
```

## 8.6 Installazione OMS 13.5 da zero

## 8.6.1 Installazione grafica (consigliata in lab)

1. Copia software EM su `emcc1`.
2. Estrai/esegui installer.
3. Seleziona "Install a new Enterprise Manager System".
4. Inserisci connessione repository DB.
5. Define SYSMAN password and console port.
6. Complete prereq check and install.

Installer startup example:

```bash
cd /u01/software/em13c
chmod +x em13500_linux64.bin
./em13500_linux64.bin
```

## 8.6.2 Mandatory post-install commands

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

## 8.7 Deploy agent sui target host

Per ogni host target (rac1, rac2, racstby1, racstby2, dbtarget):

1. Deploy Agent da console (Add Host Targets).
2. Configura named credentials SSH + sudo.
3. Check upload heartbeat agent.

Diagnostic commands on target host:

```bash
$AGENT_HOME/bin/emctl status agent
$AGENT_HOME/bin/emctl upload agent
$AGENT_HOME/bin/emctl clearstate agent
```

## 8.8 Onboarding target Oracle

Recommended order:

1. Host target
2. Listeners
3. Database instances
4. ASM instance + diskgroups
5. RAC database target
6. Data Guard association

Verifiche minime in console:

- target status: Up
- metric collection senza errori
- availability timeline coerente

## 8.9 Daily operational setup

## 8.9.1 Dashboard e homepage

Crea homepage operative:

- Infrastructure Overview
- Database Group (RAC primary)
- Database Group (standby + target)
- Critical Incidents

## 8.9.2 Metric thresholds

Definisci soglie realistiche per lab:

- CPU host > 85% per 15 min
- Filesystem usage > 85%
- Tablespace usage > 85%
- Failed login attempts
- Data Guard transport/apply lag

## 8.9.3 Incident Rules

Crea almeno due rule set:

- `LAB_CRITICAL_DB`
- `LAB_WARNING_INFRA`

Example routing:

- Critical -> email immediata
- Warning -> digest ogni 30 minuti

## 8.9.4 Notifications (SMTP)

Configura:

- SMTP server
- sender address
- recipient groups (DBA team)

Testa con invio notifica di prova e con incidente reale simulato.

## 8.9.5 Jobs e library

Crea job standard:

- Daily SQL health check
- check FRA usage
- check Data Guard lag
- RMAN backup status

Save job template to library for reuse.

## 8.9.6 Blackout

Usa blackout per manutenzione:

- patching Grid/DB
- reboot host
- test failover/switchover

Rule: No scheduled activities without open blackout.

## 8.10 Monitoraggio specifico RMAN

In EM crea viste/favorite su:

- ultimo backup job
- backup failed in the last 7 days
- recovery area usage
- missing archived logs

Useful SQL cross-check:

```sql
SELECT session_key, input_type, status, start_time, end_time
FROM v$rman_backup_job_details
ORDER BY session_key DESC;
```

Link this step to your guide:

- `GUIDE_RMAN_COMPLETE_19C.md`

## 8.11 Runbook test pratici (lab)

Each test must record: date, objective, alert detection time, outcome.

## Test 1 - Alert CPU host

1. generates CPU load on `dbtarget`
2. attende superamento soglia
3. incident verification and email notification

Esito atteso:

- incidente warning/critical creato
- email ricevuta

## Test 2 - Tablespace alert

1. riempi tablespace test oltre soglia
2. verify event in EM
3. riduci uso tablespace e chiudi incidente

Esito atteso:

- auto-clear accident after threshold reentry

## Test 3 - Listener down

1. stop listener on target host
2. check target unavailable
3. restart listener

Esito atteso:

- target status returns Up and incident closed

## Test 4 - Data Guard lag

1. simula backlog apply (lab controllato)
2. check lag and crash metrics
3. ripristina apply realtime

Esito atteso:

- alert DG visibile nella dashboard

## Test 5 - Job fail/success

1. crea job SQL con errore intenzionale
2. failure verification and notification
3. correggi job e riesegui

Esito atteso:

- storico job mostra fail poi success

## 8.12 Troubleshooting piu comune

## Agent down

Sintomi:

- host target Down
- last upload timestamp old

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

- check OMS resources (CPU/RAM/disk)
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
- check listener/service

## Metric collection error

Azioni:

- review metric extension e collection schedule
- check DB user monitor privilege
- controlla clock drift host/OMS

## 8.13 Minimum hardening recommended in lab

- Strong password policy for SYSMAN and named credentials
- backup periodico repository DB
- snapshot VM pre-change
- audit of thresholds/rules/job changes

## 8.14 Phase 8 completion checklist

- OMS Up e console accessibile
- agent deployed on all target nodes
- RAC + standby + dbtarget visible and monitored
- rule set incidenti attivo
- notifiche email testate
- almeno 5 test runbook eseguiti con esito registrato

## 8.15 Integrazione con il resto del lab

After this phase you can:

- usare EM per seguire switchover/failover in tempo reale
- correlare alert DG con backup RMAN
- schedulare controlli DBA periodici
- avere evidenze operative per review/cv

## 8.16 Riferimenti ufficiali Oracle (13.5)

- Oracle Enterprise Manager Cloud Control Basic Installation Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/embsc/index.html
- Oracle Enterprise Manager Cloud Control Advanced Installation and Configuration Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadv/index.html
- Oracle Enterprise Manager Cloud Control Administrator's Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/index.html
- Oracle Enterprise Manager Cloud Control Monitoring Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emmon/index.html
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

Note:

- This guide covers setup and daily operation in a lab environment.
- HA/multi-OMS setups require a separate design with dedicated capacity planning.
