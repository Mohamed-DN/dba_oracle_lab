# GUIDE: Complete Catalog of Oracle DBA Tasks 19c

> This guide collects the main activities that an Oracle DBA actually carries out in practice.
> It is designed for your Oracle 19c lab with RAC, Data Guard, GoldenGate and Enterprise Manager, but the structure is also valid as a production day-2 model.

## 1. How to use this guide

- Use this guide as a catalog of the DBA trade: it tells you what exists, why it's done, and where you can try it in the repo.
- Use [GUIDE_DBA_ACTIVITY_CHECKLIST.md](./GUIDE_DBA_ACTIVITY_CHECKLIST.md) when you need the operating sequence by frequency.
- Mantieni separati:
  - `lab base`: environment construction and setup runbook;
  - `extra_dba`: post-lab operational activities;
  - `studio_ai`: actual scripts and notes to reuse.

## 2. The macro-areas of DBA work

| Area | What the DBA does | Frequenza tipica | Where do you make it in the repo |
|---|---|---|---|
|**Availability and startup/shutdown**| Check instances, services, listeners, cluster resources, restarts checked |Daily / on change| [GUIDE_DBA_COMMANDS.md](../GUIDE_DBA_COMMANDS.md), [GUIDE_LISTENER_SERVICES_DBA.md](../GUIDE_LISTENER_SERVICES_DBA.md) |
|**Monitoring and alerting**|Reads alert logs, EM incidents, critical events, failed jobs, host and DB metrics|Daily| [GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md](../GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md), [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md) |
| **Backup e recovery** |Defines strategy, monitors backups, performs validation, restore tests, recovery runbooks|Daily / Weekly / Quarterly| [GUIDE_PHASE7_RMAN_BACKUP.md](../GUIDE_PHASE7_RMAN_BACKUP.md), [GUIDE_RMAN_COMPLETE_19C.md](../GUIDE_RMAN_COMPLETE_19C.md) |
| **Performance e tuning** | Analizza AWR/ADDM/ASH, top SQL, wait events, sessioni attive, statistiche |Daily / weekly / on accident| [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md), [GUIDE_DBA_COMMANDS.md](../GUIDE_DBA_COMMANDS.md) |
| **Storage, ASM e capacity** |Control tablespace, FRA, ASM disk group, data growth, autoextend, thresholds|Daily / Weekly / Monthly| [GUIDE_DBA_COMMANDS.md](../GUIDE_DBA_COMMANDS.md), [GUIDE_ADD_ASM_DISK.md](../GUIDE_ADD_ASM_DISK.md) |
| **Security e accessi** | Manages users, roles, privileges, auditing, wallet, TDE, hardening |Weekly / monthly / on request| [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md), [GUIDE_CDB_PDB_USERS.md](../GUIDE_CDB_PDB_USERS.md) |
| **Scheduler e batch** |Check jobs, windows, chains, failures, credentials and retries|Daily/weekly| [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md) |
| **HA e DR** | Gestisce RAC, Data Guard, switchover, failover, reinstate, lag, protection mode |Daily / monthly / drill| [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](../GUIDE_PHASE4_DATAGUARD_DGMGRL.md), [GUIDE_FULL_SWITCHOVER.md](../GUIDE_FULL_SWITCHOVER.md), [GUIDE_FAILOVER_AND_REINSTATE.md](../GUIDE_FAILOVER_AND_REINSTATE.md) |
| **Network, listeners and services** | Check SCAN, static/dynamic listeners, srvctl, TNS, service placement |Daily / on incident| [GUIDE_LISTENER_SERVICES_DBA.md](../GUIDE_LISTENER_SERVICES_DBA.md) |
| **Multitenant e lifecycle PDB** | Create, clone, open/close, plug/unplug, refresh, control PDB services |On request / monthly| [GUIDE_CDB_PDB_USERS.md](../GUIDE_CDB_PDB_USERS.md) |
| **Data movement e refresh** | Esegue export/import Data Pump, refresh ambienti, clone database/PDB |Upon request / project| [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md), [GUIDE_RMAN_COMPLETE_19C.md](../GUIDE_RMAN_COMPLETE_19C.md) |
| **Patching e lifecycle software** | Apply RU/OJVM, update OPatch, rollback plan, post-patch verification | Mensile / trimestrale / change | [GUIDE_RAC_PATCHING.md](../GUIDE_RAC_PATCHING.md), [GUIDE_RAC_RU_UPGRADE.md](../GUIDE_RAC_RU_UPGRADE.md) |
|**Documentation and change management**| Tiene runbook, backlog rischi, evidenze test, capacity trend, lesson learned |Continuous| [TESTLOG_GOLDENGATE_TEMPLATE.md](../TESTLOG_GOLDENGATE_TEMPLATE.md), [DAILY_STUDY_PLAN.md](../DAILY_STUDY_PLAN.md) |

## 3. Complete activities by operational domain

### 3.1 Availability and operational continuity

A DBA must always know:
- if the database is available;
- whether the services are online;
- if the cluster is healthy;
- if there are unexpected restarts or errors`ORA-` recenti.

Typical activities:
- check database and instance status;
- verify `srvctl status database`, `srvctl status service`, `crsctl stat res -t`;
- verify registered listeners and services;
- check alert log and `adrci`;
- controlled restart for maintenance or troubleshooting.

Output minimo da conservare:
- status `OPEN_MODE`, `DATABASE_ROLE`, online services;
- latest alert log errors;
- evidence that the restart did not leave resources in an intermediate state.

## 3.2 Monitoring, alerting and observability

This area covers the most frequent day-2 work:
- monitor incidents and events;
- immediately recognize CPU, memory, I/O, FRA, tablespace saturation;
- notice failed jobs, DG lag or target down.

Typical activities:
- review dashboard EM;
- review alert log and relevant traces;
- host and database metrics control;
- verifies that collection and monitoring jobs are healthy;
- tuning thresholds and notifications.

In your repo:
- [GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md](../GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md)
- [GUIDE_DBA_COMMANDS.md](../GUIDE_DBA_COMMANDS.md)

## 3.3 Backup, restore test e recovery readiness

This is a primary responsibility of the DBA. Oracle makes it clear: the backup administrator must define, implement and manage the backup and recovery strategy.

Typical activities:
- verify RMAN backup outcome;
- retention check, crosscheck, delete obsolete;
- `RESTORE VALIDATE`and recovery tests;
- backup control controlfile, spfile, archivelog;
- test restore on alternative host or controlled drill.

Signs of maturity:
- backup presenti non basta;
- periodic restore test is needed;
- RPO/RTO must be explained and verified.

In your repo:
- [GUIDE_PHASE7_RMAN_BACKUP.md](../GUIDE_PHASE7_RMAN_BACKUP.md)
- [GUIDE_RMAN_COMPLETE_19C.md](../GUIDE_RMAN_COMPLETE_19C.md)

## 3.4 Performance e tuning

The DBA doesn't "optimize everything all the time": he must first understand where the database wastes time.

Typical activities:
- review AWR;
- review ADDM;
- ASH analysis for short accidents;
- top SQL per elapsed time, CPU, I/O;
- wait events e sessioni attive;
- check statistics, SQL plans, post-change regressions.

In RAC you also need to look at:
- cross-instance sessions;
- load per instance;
- any imbalances in GCS/GES services or contention.

In your repo:
- [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md)
- [GUIDE_DBA_COMMANDS.md](../GUIDE_DBA_COMMANDS.md)
- [TOP_100_SCRIPT_DBA.md](../TOP_100_SCRIPT_DBA.md)

## 3.5 Storage, tablespace, ASM e capacity planning

A DBA must avoid two classic accidents:
- tablespace piena;
- FRA/ASM saturi.

Typical activities:
- monitor tablespace e autoextend;
- monitor FRA usage;
- monitor ASM disk group usage e rebalance;
- data growth forecast;
- adding datafiles or disks before the critical threshold is reached.

Output minimo:
- growth trend per week/month;
- top consumers;
- shared operating thresholds.

In your repo:
- [GUIDE_DBA_COMMANDS.md](../GUIDE_DBA_COMMANDS.md)
- [GUIDE_ADD_ASM_DISK.md](../GUIDE_ADD_ASM_DISK.md)

## 3.6 Security, account lifecycle e auditing

This area is not just about creating users.

Typical activities:
- create/edit users and roles;
- review excessive privileges and grants;
- control of expired, blocked and orphaned accounts;
- wallet/TDE management;
- review auditing and administrative access;
- applicare least privilege usando `SYSBACKUP`, `SYSDG`, `SYSKM`whenever possible instead of`SYSDBA`.

Key Controls:
- privilege `ANY` assigned only if justified;
- directory object and Data Pump roles under control;
- accessible audits and evidence.

In your repo:
- [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md)
- [GUIDE_CDB_PDB_USERS.md](../GUIDE_CDB_PDB_USERS.md)

## 3.7 Scheduler, batch and automatic maintenance

Many accidents come from jobs that stop spinning or spin too much.

Typical activities:
- review `DBA_SCHEDULER_JOBS`, `DBA_SCHEDULER_JOB_RUN_DETAILS`, job failures;
- check maintenance windows;
- review chains, programs, credentials;
- checking jobs that are stuck, looped or too slow;
- purging log scheduler when necessary.

In your repo:
- [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md)

## 3.8 HA/DR: RAC, Data Guard, switchover, failover

In environments like yours, the DBA needs to know:
- se RAC e sano;
- if Data Guard ships and applies gap-free redo;
- which protection mode is active;
- se switchover/failover sono pronti.

Typical activities:
- review `SHOW CONFIGURATION` in DGMGRL;
- monitor transport/apply lag;
- review `Protection Mode` e `LogXptMode`;
- test switchover pianificato;
- failover and reinstate drill in the lab;
- Verify that backup and monitoring continue after role transition.

In your repo:
- [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](../GUIDE_PHASE4_DATAGUARD_DGMGRL.md)
- [GUIDE_FULL_SWITCHOVER.md](../GUIDE_FULL_SWITCHOVER.md)
- [GUIDE_FAILOVER_AND_REINSTATE.md](../GUIDE_FAILOVER_AND_REINSTATE.md)

## 3.9 Listener, SCAN, services and connectivity

This area covers all problems such as:
- `ORA-12514`
- `TNS:no listener`
- unregistered services
- failover service placement incoerente

Typical activities:
- verify `lsnrctl status`;
- verify `srvctl config service` and `srvctl status service`;
- SCAN control and DNS resolution;
- static review listeners for Data Guard / RMAN;
- relocate services for maintenance or balancing.

In your repo:
- [GUIDE_LISTENER_SERVICES_DBA.md](../GUIDE_LISTENER_SERVICES_DBA.md)

## 3.10 Multitenant: CDB/PDB lifecycle

In 19c this area is an integral part of the DBA work.

Typical activities:
- aprire/chiudere PDB;
- creare o clonare PDB;
- plug/unplug;
- verify common and local users;
- manage PDB services;
- check status and monitoring for single PDB.

In your repo:
- [GUIDE_CDB_PDB_USERS.md](../GUIDE_CDB_PDB_USERS.md)

## 3.11 Data movement: Data Pump, clone, refresh

This area covers operational and project requests:
- refresh test environments;
- export schema o full;
- import with remap;
- clone with RMAN;
- duplicate for standby or clone.

Typical activities:
- `expdp` / `impdp`;
- selective exports per schema/table;
- import with `REMAP_SCHEMA`, `REMAP_TABLESPACE`;
- clone/duplicate for testing;
- version and privilege compatibility control.

In your repo:
- [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md)
- [GUIDE_RMAN_COMPLETE_19C.md](../GUIDE_RMAN_COMPLETE_19C.md)

## 3.12 Patching, upgrade e software lifecycle

This is one of the most sensitive areas of DBA work.

Typical activities:
- check patch inventory;
- OPatch update;
- pre-check e backup home;
- RU/OJVM application;
- review invalid objects and datapatches where applicable;
- rollback plan;
- verify services and performance post-change.

For RAC/Data Guard the DBA must also:
- keep order rolling whenever possible;
- align grid home, db home, standby and tooling;
- document baseline before and after.

In your repo:
- [GUIDE_RAC_PATCHING.md](../GUIDE_RAC_PATCHING.md)
- [GUIDE_RAC_RU_UPGRADE.md](../GUIDE_RAC_RU_UPGRADE.md)

## 3.13 Documentation, evidence and change management

This part is often overlooked, but it distinguishes a makeshift DBA from a reliable one.

Typical activities:
- keep runbooks updated;
- tenere evidenze di backup test, switchover test, patching, failover drill;
- note changed parameters;
- mantenere checklist pre/post change;
- registrare rischi, rollback plan, owner e finestra.

In the lab you can train it with:
- test log GoldenGate;
- checklist RMAN;
- role transition and patching notes.

## 4. Vista per frequenza

### Daily

- availability check database, listener, services, cluster
- alert log and EM incidents
- job batch e scheduler failures
- backup ultimo ciclo
- DG lag / status broker
- tablespace, FRA, ASM usage
- top wait o blocchi se ci sono ticket aperti

### Settimanale

- review AWR/ADDM
- `RESTORE VALIDATE`
- storage growth review
- user reviews and anomalous grants
- review scheduler jobs e log retention
- review GG lag / errori se in uso

### Mensile

- patch review e backlog RU
- capacity planning
- audit di sicurezza e account review
- operational testing of services / relocate / restart controlled
- review soglie EM e incident rules

### Trimestrale

- switchover drill
- restore drill or clone on alternative host
- failover/reinstate in lab
- complete runbook and documentation review

## 5. Quick Map: What You Can Really Do When This Guide is "Complete"

If you master this folder, you need to know how to do at least this:

1. understand in a few minutes whether your environment is healthy or not;
2. demonstrate that backups not only exist but are restoreable;
3. find the reason for lag, lock, top SQL and storage growth;
4. manage users, privileges and auditing without abusing `SYSDBA`;
5. perform controlled switchover/failover and understand the impact of protection mode;
6. manage TNS listeners, services, SCAN and troubleshoot;
7. do patching with pre-check, post-check and rollback plan;
8. gestire PDB, Data Pump e refresh ambienti.

## 6. Official Oracle sources consulted

- Oracle Database 19c Administration landing page:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/administration.html
- Oracle Database Administrator's Guide 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/admin.pdf
- Oracle Database Backup and Recovery User's Guide 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/
- Oracle Database Performance Tuning Guide 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/database-performance-tuning-guide.pdf
- Oracle Data Guard Concepts and Administration 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/data-guard-concepts-and-administration.pdf
- Oracle RAC Administration and Deployment Guide 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/
- Oracle Multitenant Administrator's Guide 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/managing-a-multitenant-environment.html
- Oracle Data Pump Export Utility 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-data-pump-export-utility.html
- Oracle Security Guide 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/keeping-your-oracle-database-secure.html
- Oracle Scheduler administration:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/administering-oracle-scheduler.html
- Oracle Enterprise Manager Cloud Control Administrator's Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/index.html
