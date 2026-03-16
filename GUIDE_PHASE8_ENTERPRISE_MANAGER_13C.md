# PHASE 8: Oracle Enterprise Manager Cloud Control 13.5 (Single OMS Lab)

Updated: March 13, 2026
Target lab: Oracle Linux 7.9/8.x, Oracle DB 19c, RAC + Data Guard + GoldenGate gia operativi.

This phase adds a centralized console to monitor and govern the entire laboratory:

- host e metriche OS
- single instance database and RAC
- ASM, listener, Data Guard
- alerting, incident management, notification, jobs, blackout
- RMAN backup monitoring

## 8.0A Input from Phase 7 (preflight)

Before installing EM, verify that the Oracle lab is stable:

```bash
dgmgrl sys/<password>@RACDB "show configuration;"
```

```sql
--On the main DB that you will use as EM repository
sqlplus / as sysdba
SELECT name, open_mode, log_mode FROM v$database;
SELECT value FROM v$parameter WHERE name='compatible';
```

```bash
#From node emcc1: DNS resolution and reachability target
getent hosts rac1 rac2 racstby1 racstby2 dbtarget
```

Minimum gate:

- Data Guard in `SUCCESS`
- DB repository reachable from`emcc1`
- adequate disk space and RAM`emcc1`

## 8.0B If OMS is already installed

If you already have a working OMS (previous tests), do not reinstall:

```bash
$OMS_HOME/bin/emctl status oms -details
$AGENT_HOME/bin/emctl status agent
```

Se `OMS Up` e `Agent Up`, go directly to`8.7` (deploy agent target) oppure `8.8` (onboarding target).

## 8.1 Operational objective

At the end of the phase you must have:

- 1 VM dedicata `emcc1` con OMS + local Agent
- repository database 19c per EM
- registered targets (host + DB + ASM + listener)
- rule set incidents and email notifications
- daily operational dashboards
- runbook test alert validato

##8.2 Recommended architecture in your lab

Locked choice: Single OMS on dedicated VM.

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

Practical note:

- In lab you can put DB repository on `dbtarget` per risparmiare RAM.
- In production, dedicated OMS vs repository separation is preferred.

## 8.3 Minimum prerequisites

## 8.3.1 Hardware VM `emcc1`

Minimo lab:

- vCPU: 4
- RAM: 12 GB (16 GB recommended)
- Disk: 120 GB

With 8 GB RAM OMS tends to become saturated during console discovery and patching.

## 8.3.2 Software

- Oracle Linux 7.9 o 8.x
- JDK supported by EM 13.5 release
- OS packages required by the installer
- install media EM 13.5 + possible RU

## 8.3.3 Network and ports

Open at least:

- 7802/7803 (upload/communication, depends on configuration)
- 3872 (agent)
- 4903, 4904 (OMS internal)
- 1521 (repository DB)
- 7803 (default OMS HTTPS console, or custom port chosen during installation)

Use resolvable DNS for:

- `emcc1`
- RAC and standby nodes
- host repository DB

## 8.3.4 Recommended users and paths

- OMS software user: `oracle` (lab) o `omsuser` (enterprise)
- base directory: `/u01/app/oracle`
- middleware home OMS: `/u01/app/oracle/middleware`
- software media: `/u01/software/em13c`

## 8.4 Preparing the emcc1 VM

```bash
# hostname and resolution
hostnamectl set-hostname emcc1

# swap recommended for OMS in lab
free -h
swapon --show

#kernel/network controls (example)
ulimit -n
sysctl -a | egrep "fs.file-max|net.core.somaxconn" 
```

Check NTP/chrony on all VMs, otherwise you will have false alerts and inconsistent metrics.

## 8.5 Repository DB 19c per Enterprise Manager

You can use:

- option A: repository in the database`dbtarget`
- option B: local repository on`emcc1`

For lab, option A is sufficient.

Checklist repository DB:

- ARCHIVELOG ON
- character set supportato
- adequate tablespace space for SYSMAN/MGMT_TABLESPACE
- listeners and services reachable from `emcc1`

Quick Controls:

```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT value FROM v$parameter WHERE name='compatible';
```

## 8.6 Installing OMS 13.5 from scratch

## 8.6.1 Graphic installation (recommended in lab)

1. Copia software EM su `emcc1`.
2. Extract/run installer.
3. Seleziona "Install a new Enterprise Manager System".
4. Enter DB repository connection.
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

# Console URL
/u01/app/oracle/middleware/bin/emctl status oms -details | egrep "Console URL|Upload URL"
```

Console Login:

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

Minimum console checks:

- target status: Up
- error-free metric collection
- consistent availability timeline

## 8.9 Daily operational setup

## 8.9.1 Dashboard e homepage

Crea homepage operative:

- Infrastructure Overview
- Database Group (RAC primary)
- Database Group (standby + target)
- Critical Incidents

## 8.9.2 Metric thresholds

Define realistic thresholds for labs:

- CPU host > 85% per 15 min
- Filesystem usage > 85%
- Tablespace usage > 85%
- Failed login attempts
- Data Guard transport/apply lag

## 8.9.3 Incident Rules

Create at least two rule sets:

- `LAB_CRITICAL_DB`
- `LAB_WARNING_INFRA`

Example routing:

- Critical -> immediate email
- Warning -> digest ogni 30 minuti

## 8.9.4 Notifications (SMTP)

Configure:

- SMTP server
- sender address
- recipient groups (DBA team)

Test with sending test notification and with real simulated accident.

## 8.9.5 Jobs e library

Crea job standard:

- Daily SQL health check
- check FRA usage
- check Data Guard lag
- RMAN backup status

Save job template to library for reuse.

## 8.9.6 Blackout

Use maintenance blackout:

- patching Grid/DB
- reboot host
- test failover/switchover

Rule: No scheduled activities without open blackout.

## 8.10 RMAN specific monitoring

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
2. waits for the threshold to be exceeded
3. incident verification and email notification

Expected outcome:

- incidente warning/critical creato
- email ricevuta

## Test 2 - Tablespace alert

1. fill test tablespace beyond threshold
2. verify event in EM
3. reduce tablespace usage and close incident

Expected outcome:

- auto-clear accident after threshold reentry

## Test 3 - Listener down

1. stop listener on target host
2. check target unavailable
3. restart listener

Expected outcome:

- target status returns Up and incident closed

## Test 4 - Data Guard lag

1. simulate backlog apply (lab controlled)
2. check lag and crash metrics
3. reset apply realtime

Expected outcome:

- DG alert visible in the dashboard

## Test 5 - Job fail/success

1. Create SQL jobs with intentional error
2. failure verification and notification
3. fix job and rerun

Expected outcome:

- job history shows fail then success

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

- lagging metrics
- pending uploads alto

Azioni:

- check OMS resources (CPU/RAM/disk)
- controlla repository DB load
- OMS controlled restart in maintenance window

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

- OMS Up and accessible console
- agent deployed on all target nodes
- RAC + standby + dbtarget visible and monitored
- incident rule set active
- notifiche email testate
- at least 5 runbook tests performed with recorded results

## 8.15 Integration with the rest of the lab

After this phase you can:

- usare EM per seguire switchover/failover in tempo reale
- correlare alert DG con backup RMAN
- schedule periodic DBA checks
- have operational evidence for review/CV

##8.16 Official Oracle References (13.5)

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
