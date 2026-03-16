# Oracle RAC + Data Guard + GoldenGate + Cloud - Ultimate Guide

> Complete step-by-step guide to building an Oracle Enterprise architecture in the lab.
> **98% validated** against official Oracle MAA Gold best practices.

---

> ⚠️ **CRITICAL HARDWARE REQUIREMENTS**: To run the entire environment (4 RAC Nodes + 1 DNS Node) **at least 32GB of physical RAM** is required on your PC. If you have 16GB, you can only do half the lab (e.g. 2 RAC nodes without Standby).

> 🤖 **AUTOMATION AVAILABLE**: Want to skip the boring steps? In the `scripts/` folder you will find ready-to-use bash scripts to autoconfigure the storage (`configure_storage.sh`) and install the Grid (`install_grid.sh`). The guides show you the manual way (to learn), but the scripts are at your disposal!

---

## Lab Architecture (Graphical View)

```text
╔════════════════════════════════════════════════════════════════════════════════════╗
║                           IL TUO PC (HOST VIRTUALBOX)                             ║
║                                                                                    ║
║  ┌──────────────────────────────────────────────────────────────────────────────┐  ║
║ │ Host-Only Network #1 (192.168.56.0/24) │ ║
║ │ "Publish" for cluster, DNS and management │ ║
║  └──┬──────────┬──────────┬────────────┬────────────┬─────────────┬────────────┘  ║
║     │          │          │            │            │             │               ║
║  ┌──┴──────┐ ┌─┴───────┐ ┌┴─────────┐ ┌┴──────────┐ ┌┴──────────┐ ┌┴───────────┐  ║
║  │ dnsnode │ │  rac1   │ │  rac2    │ │ racstby1  │ │ racstby2  │ │   emcc1    │  ║
║  │ .56.50  │ │ .56.101 │ │ .56.102  │ │ .56.111   │ │ .56.112   │ │ EM 13.5    │  ║
║  │ 1GB/1CPU│ │ 8GB/4CPU│ │ 8GB/4CPU │ │ 8GB/4CPU  │ │ 8GB/4CPU  │ │ OMS+Agent  │  ║
║  └─────────┘ └───┬─────┘ └────┬─────┘ └────┬──────┘ └────┬──────┘ └────────────┘  ║
║                  │            │            │             │                           ║
║             ┌────┴────────────┴───┐   ┌────┴─────────────┴───┐                       ║
║             │ Host-Only #2         │   │ Host-Only #3         │                       ║
║             │ 192.168.1.0/24       │   │ 192.168.2.0/24       │                       ║
║ │ Interconnect PRIMARY │ │ Interconnect STANDBY │ ║
║             └──────────────────────┘   └──────────────────────┘                       ║
║                                                                                    ║
║ Logical flows: ║
║  - Cache Fusion: rac1 <-> rac2  |  racstby1 <-> racstby2                           ║
║  - Data Guard: RACDB (primary) -> RACDB_STBY (LGWR ASYNC)                          ║
║ - GoldenGate: Extract/Pump on primary -> Replicat on dbtarget/OCI ║
║ - Enterprise Manager (emcc1): monitor all nodes + targets ║
║                                                                                    ║
║ Shared Disks (Shareable VDI): ║
║  ┌──────────────────────────────┐     ┌──────────────────────────────┐              ║
║  │ rac1 + rac2 (PRIMARY)        │     │ racstby1 + racstby2 (STBY)   │              ║
║  │ asm-crs-disk1    2GB         │     │ asm-stby-crs-1      2GB      │              ║
║  │ asm-crs-disk2    2GB         │     │ asm-stby-crs-2      2GB      │              ║
║  │ asm-crs-disk3    2GB         │     │ asm-stby-crs-3      2GB      │              ║
║  │ asm-data-disk1  20GB         │     │ asm-stby-data      20GB      │              ║
║  │ asm-reco-disk1  15GB         │     │ asm-stby-reco      15GB      │              ║
║  └──────────────────────────────┘     └──────────────────────────────┘              ║
║                                                                                    ║
║ External target: dbtarget (OCI/Cloud) for Oracle or PostgreSQL replication ║
╚════════════════════════════════════════════════════════════════════════════════════╝
```

> Below you will also find the **Overall Architecture** section in ASCII format with network/disk details.

---

## Where to Start (Recommended Route)

### 1) Initial theory (2 hours)

1. [GUIDE_ORACLE_ARCHITECTURE.md](./GUIDE_ORACLE_ARCHITECTURE.md)
2. [GUIDE_DBA_COMMANDS.md](./GUIDE_DBA_COMMANDS.md)
3. [DAILY_STUDY_PLAN.md](./DAILY_STUDY_PLAN.md)

### 2) Perform the basic lab in order (Steps 0 -> 8)

1. [GUIDE_PHASE0_MACHINE_SETUP.md](./GUIDE_PHASE0_MACHINE_SETUP.md)
2. [GUIDE_PHASE1_OS_PREPARATION.md](./GUIDE_PHASE1_OS_PREPARATION.md)
3. [GUIDE_PHASE2_GRID_AND_RAC.md](./GUIDE_PHASE2_GRID_AND_RAC.md)
4. [GUIDE_PHASE3_RAC_STANDBY.md](./GUIDE_PHASE3_RAC_STANDBY.md)
5. [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](./GUIDE_PHASE4_DATAGUARD_DGMGRL.md) - also includes `Protection Mode`, `MaxPerformance`, `MaxAvailability`, `MaxProtection`, `FASTSYNC`
6. [GUIDE_PHASE5_GOLDENGATE.md](./GUIDE_PHASE5_GOLDENGATE.md)
7. [GUIDE_PHASE6_TEST_VERIFY.md](./GUIDE_PHASE6_TEST_VERIFY.md)
8. [GUIDE_PHASE7_RMAN_BACKUP.md](./GUIDE_PHASE7_RMAN_BACKUP.md)
9. [GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md](./GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md)

### 3) Sprint GoldenGate esteso (40 test)

- Main Guide: [GUIDE_PHASE5_GOLDENGATE.md](./GUIDE_PHASE5_GOLDENGATE.md)
- Template log test: [TESTLOG_GOLDENGATE_TEMPLATE.md](./TESTLOG_GOLDENGATE_TEMPLATE.md)
- Daily Schedule: [DAILY_STUDY_PLAN.md](./DAILY_STUDY_PLAN.md) (GoldenGate Operational Addendum)

### 4) Advanced operations + Cloud + exams

1. Protection Mode / switch modalita: [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](./GUIDE_PHASE4_DATAGUARD_DGMGRL.md)
2. Switchover / Failover / Migration: [GUIDE_FULL_SWITCHOVER.md](./GUIDE_FULL_SWITCHOVER.md), [GUIDE_FAILOVER_AND_REINSTATE.md](./GUIDE_FAILOVER_AND_REINSTATE.md), [GUIDE_GOLDENGATE_MIGRATION.md](./GUIDE_GOLDENGATE_MIGRATION.md)
3. PDB propagation + services: [extra_dba/GUIDE_PDB_DATAGUARD_SERVICES.md](./extra_dba/GUIDE_PDB_DATAGUARD_SERVICES.md)
4. Oracle DBA Questions: [extra_dba/GUIDE_ORACLE_DBA_QUESTIONS.md](./extra_dba/GUIDE_ORACLE_DBA_QUESTIONS.md)
5. Extra DBA index: [extra_dba/README.md](./extra_dba/README.md)
6. Cloud, Network and MAA: [GUIDE_GOLDENGATE_OCI_ARM.md](Z./GUIDE_GOLDENGATE_OCI_ARM.md), [GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md](./GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md), [GUIDE_MAA_BEST_PRACTICES.md](Z./GUIDE_MAA_BEST_PRACTICES.md)
7. Exams and PostgreSQL: [GUIDE_EXAM_REVIEW.md](./GUIDE_EXAM_REVIEW.md), [GUIDE_ORACLE_TO_POSTGRES_MIGRATION.md](./GUIDE_ORACLE_TO_POSTGRES_MIGRATION.md)

> **Tip**: The complete and updated plan is at [DAILY_STUDY_PLAN.md](Z./DAILY_STUDY_PLAN.md), 8 weeks (40 days) at 3 hours/day.

---

## Rebalanced Studio Roadmap (8 weeks, 3h/day)

This condensed roadmap aligns the README with the plan updated in [DAILY_STUDY_PLAN.md](./DAILY_STUDY_PLAN.md).

### Recommended weekly pattern

| Day |Intensity| Focus |
|---|---|---|
| 1 | HIGH | New theme + new lab |
| 2 | HIGH | Continuazione + troubleshooting |
| 3 | MEDIUM | Consolidamento + test guidati |
| 4 | HIGH | New technical block |
| 5 | LIGHT | Active review + backlog fix + documentation |
|6 (optional)| BUFFER | Recupero task o test extra |
| 7 | OFF |Technical rest (max 30 min light reading)|

### Load per phase (quick view)

| Week | Focus |Minimum output|
|---|---|---|
| 1 | OS + Grid + ASM |Stable grid + closed prerequisites|
| 2 | RAC + standby prep | RAC operational + standby ready |
| 3 | Data Guard + RMAN + GG base | broker ok + backup validato + GG base |
| 4 |Advanced GG + HA test|at least 24 GG tests closed|
| 5 | Enterprise Manager + monitoring + cloud | OMS/Agents active + basic alerting working |
| 6 |Oracle -> PostgreSQL migration| flusso end-to-end completato |
| 7 |Preparation 1Z0-082| 2 mock exam + revisione errori |
| 8 |Preparation 1Z0-083| 2 mock exam + runbook finali |

### Mock exam Oracle (allineamento pratico)

Exam reference in English (Oracle University, verified March 14, 2026):

- `1Z0-082` (Oracle Database Administration I)
- `1Z0-083` (Oracle Database Administration II)
- pagina esame EN 1Z0-082: https://education.oracle.com/oracle-database-administration-i/pexam_1Z0-082
- pagina esame EN 1Z0-083: https://education.oracle.com/oracle-database-administration-ii/pexam_1Z0-083

Note: number of questions and passing score may change per language/track; Always check the Oracle portal before booking.

Recommended calendar:

- week 7: 2 simulations of 120 minutes
- week 8: 2 simulations of 120 minutes
- after each mock: 40-60 minutes of error review per category

### Sprint GoldenGate (40 tests) without overload

- week 3: `GG-01..GG-16`
- week 4: `GG-17..GG-32`
- buffer week 4/5: `GG-33..GG-40` + retest fail

Operational materials:

- guide: [GUIDE_PHASE5_GOLDENGATE.md](./GUIDE_PHASE5_GOLDENGATE.md)
- template testlog: [TESTLOG_GOLDENGATE_TEMPLATE.md](./TESTLOG_GOLDENGATE_TEMPLATE.md)

---

## Full Index

### Theory (Read BEFORE building)

| # | Documento | File | What You Learn |
|---|---|---|---|
| 1 | **Oracle Architecture** | [GUIDA_ARCHITETTURA](./GUIDE_ORACLE_ARCHITECTURE.md) | SGA, PGA, Redo Log, Undo, Temp, ASM, Cache Fusion |
| 2 | **DBA Commands** | [GUIDA_COMANDI_DBA](./GUIDE_DBA_COMMANDS.md) | 100+ query SQL, script Oracle Base, health check |
| 3 | **CDB/PDB, Users, EM Express** | [GUIDA_CDB_PDB_UTENTI](./GUIDE_CDB_PDB_USERS.md) | Multitenant, PDB create/clone/plug, users, roles, SQL Tuning |
| 4 | **Study Plan** | [PIANO_STUDIO](./DAILY_STUDY_PLAN.md) | 8 weeks (40 days) x 3h/day, roadmap and milestones |
| 5 | **Top 100 Script DBA** | [TOP_100_SCRIPT](./TOP_100_SCRIPT_DBA.md) | The 100 most useful scripts every day - lock, AWR, tuning, ASM, I/O |
| 6 | **RAC Lab Activities** | [ATTIVITA_LAB](./GUIDE_RAC_LAB_ACTIVITIES.md) | 10 practical exercises: health check, AWR, switchover, GG test |

---

### Construction Lab (Follow in order!)

| # | Phase | File | What are you doing |
|---|---|---|---|
| 7 | **Phase 0** | [SETUP MACCHINE](./GUIDE_PHASE0_MACHINE_SETUP.md) | Create VirtualBox VM, Dnsmasq DNS, oracleasm ASM disks, install OL 7.9 |
| 8 | **Phase 1** | [PREPARAZIONE OS](./GUIDE_PHASE1_OS_PREPARATION.md) | Configure network, DNS, users, SSH, kernel |
| 9 | **Phase 2** | [GRID + RAC](./GUIDE_PHASE2_GRID_AND_RAC.md) | Installa Grid, ASM, DB Software, crea RACDB |
| 10 | **Phase 3** | [RAC STANDBY](./GUIDE_PHASE3_RAC_STANDBY.md) | RMAN Duplicate, Static Listener, MRP |
| 11 | **Phase 4** | [DATA GUARD](./GUIDE_PHASE4_DATAGUARD_DGMGRL.md) | DGMGRL Broker, Active Data Guard, Protection Mode (`MaxPerformance`, `MaxAvailability`, `MaxProtection`, `FASTSYNC`) |
| 12 | **Phase 5** | [GOLDENGATE](./GUIDE_PHASE5_GOLDENGATE.md) | Integrated extract on primary, Pump, Replicat target local/OCI + advanced variants documented |
| 13 | **Phase 6** | [VERIFICATION TEST](./GUIDE_PHASE6_TEST_VERIFY.md) | Test DG + GG + stress + node crash |
| 14 | **Phase 7** | [RMAN BACKUP](./GUIDE_PHASE7_RMAN_BACKUP.md) | Strategia backup, script, cron, BCT, restore |
| 15 | **Phase 8** | [ENTERPRISE MANAGER](./GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md) | Setup Cloud Control 13.5: OMS, Agent, target discovery, alerting, jobs |
| 16 | **RMAN Complete** | [GUIDA_RMAN_19C](./GUIDE_RMAN_COMPLETE_19C.md) | Complete RMAN runbook + test lab: config, backup, validate, recovery, catalog |

---

### Advanced Operations (After the basic lab)

| # | Documento | File | What You Learn |
|---|---|---|---|
| 17 | **Protection Mode** | [GUIDA_FASE4_DG](./GUIDE_PHASE4_DATAGUARD_DGMGRL.md) | Cambio modalita Data Guard: `MaxPerformance`, `MaxAvailability`, `MaxProtection`, `FASTSYNC` |
| 18 | **Switchover** | [GUIDA_SWITCHOVER](./GUIDE_FULL_SWITCHOVER.md) | Step-by-step Switchover + Switchback |
| 19 | **Failover + Reinstate** | [GUIDA_FAILOVER](./GUIDE_FAILOVER_AND_REINSTATE.md) | Failover emergenza, reinstate, FSFO |
| 20 | **Migration GG** | [GUIDA_MIGRAZIONE](./GUIDE_GOLDENGATE_MIGRATION.md) | Zero-downtime migration with GoldenGate |
| 21 | **Patching & RU** | [GUIDA_PATCHING](./GUIDE_RAC_PATCHING.md) | Combo Patch, OJVM, e pulizia filesystem |
| 22 | **Upgrade RU** | [GUIDA_UPGRADE_RU](./GUIDE_RAC_RU_UPGRADE.md) | Skip version, rollback auto, upgrade workflow |
| 23 | **PDB + Services + DG** | [GUIDA_PDB_DG](./extra_dba/GUIDE_PDB_DATAGUARD_SERVICES.md) | PDB creation on primary, propagation on standby, RAC and listener services |
| 24 | **RAC Lab Activities** | [GUIDA_ATTIVITA_LAB](./GUIDE_RAC_LAB_ACTIVITIES.md) | 10 practical lab exercises: health check, AWR, lock, switchover, GG test |

### Extra DBA (Post-lab)

| Documento | File |Description|
|---|---|---|
| **Indice Extra DBA** | [EXTRA_DBA](./extra_dba/README.md) | Extra laboratory activities already present in the repo: advanced Data Guard, RAC operations, backup/recovery, monitoring and day-2 |
| **DBA Business Catalog** | [CATALOGO_DBA](./extra_dba/GUIDE_DBA_ACTIVITY_CATALOG.md) | Comprehensive overview of real Oracle DBA activities: availability, backup, performance, security, TDE, HA/DR, multitenant, patching |
| **DBA Operational Checklist** | [CHECKLIST_DBA](./extra_dba/GUIDE_DBA_ACTIVITY_CHECKLIST.md) | Daily, weekly, monthly, quarterly, pre-change and post-incident runbook |
| **Oracle DBA Question Guide** | [DOMANDE_DBA](./extra_dba/GUIDE_ORACLE_DBA_QUESTIONS.md) | Technical questions, clear answers, follow-ups and realistic scenarios on Oracle DBA |

> `extra_dba` and `studio_ai` remain separate: `extra_dba` is an index of advanced lab paths, `studio_ai` remains the operational library of scripts and real notes.

---

### Cloud and Professional DBA (Week 5)

| # | Documento | File | What You Learn |
|---|---|---|---|
| 23 | **Cloud GoldenGate** | [GUIDA_CLOUD_GG](./GUIDE_GOLDENGATE_OCI_ARM.md) |OCI compute target, choice between free validation and consistent migration target|
| 24 | **Lab network + OCI** | [GUIDA_RETE_OCI](./GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md) | Host-only, NAT, public IP, VPN, NSG, listeners and GoldenGate ports |
| 25 | **DBA Activities** | [GUIDA_ATTIVITA_DBA](./GUIDE_DBA_ACTIVITIES.md) | Batch Jobs, AWR/ADDM/ASH, Patching, DataPump, Security |
| 26 | **MAA Best Practices** | [GUIDA_MAA](./GUIDE_MAA_BEST_PRACTICES.md) | Lab validation vs Oracle MAA Gold |

---

### Exam + PostgreSQL Migration (Weeks 6-8)

| # | Documento | File | What You Learn |
|---|---|---|---|
| 26 | **Exam Review** | [GUIDA_ESAME_REVIEW](./GUIDE_EXAM_REVIEW.md) | All topics 1Z0-082 + 1Z0-083 (Admin + SQL + DBA Pro 2) |
| 27 | **Oracle -> PostgreSQL** | [GUIDA_MIGRAZIONE_PG](./GUIDE_ORACLE_TO_POSTGRES_MIGRATION.md) | Oracle->PostgreSQL migration with GoldenGate, ora2pg, ODBC |

---

### Reference and Further Information

| Documento | File |Description|
|---|---|---|
| **From Lab to Production** | [GUIDA_PRODUZIONE](./GUIDE_FROM_LAB_TO_PRODUCTION.md) | Sizing, HugePages, security, monitoring |
|**Oracle BP Validation**| [VALIDAZIONE_BP](./BEST_PRACTICES_VALIDATION.md) | Audit 54 punti, scorecard 98%, GUI vs CLI |
|**Basic Oracle Analysis**| [ANALISI_ORACLEBASE](./ORACLEBASE_VAGRANT_ANALYSIS.md) | Comparison with Oracle Base Vagrant |
| **ASM Disk Management** | [GUIDA_ASM_DISK](./GUIDE_ADD_ASM_DISK.md) | Add/Create ASM Disks (ASMLib + AFD) |
| **Complete RMAN Guide 19c** | [GUIDA_RMAN_19C](./GUIDE_RMAN_COMPLETE_19C.md) | Backup, restore, recovery, Data Guard and practical tests with official Oracle sources |
| **SSH Keys RAC Guide** | [GUIDA_SSH_KEYS](./GUIDE_RAC_SSH_KEYS.md) | User equivalence per `grid`/`oracle`/`root`, reset rapido e troubleshooting `PRVG-2019` |
| **Enterprise Manager Phase 8 Guide** | [GUIDA_EM13C](./GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md) | Complete OEM Cloud Control 13.5 setup, operational monitoring and runbook testing |
| **Template Test GoldenGate** | [TESTLOG_GG_TEMPLATE](./TESTLOG_GOLDENGATE_TEMPLATE.md) |Template ready to track PASS/FAIL, lag, evidence and fixes|

---

### 📚 Enterprise DBA Toolkit (AI Studio)

> Collection of real scripts and operational procedures from production Enterprise environments.
> Extracted and organized from the `studio/` folder with operational notes.

| # | Area | Description |
|---|---|---|
| 01 |[ASM & Storage](./studio_ai/01_asm_storage/)| Add/Remove ASM Disks, LUN Migration (ASMLib + AFD) |
| 02 |[Data Guard](./studio_ai/02_dataguard/)| DG configuration, Active DG, GAP verification, DR recovery |
| 03 | [Script Monitoring](./studio_ai/03_monitoring_scripts/) |48 SQL scripts: sessions, locks, CPU, I/O, ASH, ASM|
| 04 | [User Management](./studio_ai/04_user_management/) | User creation template, password policy, Vault |
| 05 | [Patching](./studio_ai/05_patching/) | Patching Oracle, Golden Images (OHCTL) |
| 06 | [Backup & Recovery](./studio_ai/06_backup_recovery/) | Flashback, Restore Point, verifiche RMAN |
| 07 | [Performance & Tuning](./studio_ai/07_performance_tuning/) | SPM, AWR analysis, statistics management |
| 08 | [TDE & Sicurezza](./studio_ai/08_tde_security/) | Transparent Data Encryption, Oracle Vault |
| 09 |[Compression](./studio_ai/09_compression/)| DBMS_REDEFINITION online, near-zero downtime |
| 10 |[Partition Manager](./studio_ai/10_partition_manager/)| Automatic partition management package |
| 11 |[SQL Template](./studio_ai/11_sql_templates/)| Standard DDL/DML template with error handling |
| 12 | [Utility](./studio_ai/12_utilities/) | Monitor TEMP/UNDO, MView refresh, DBA utility package |

---

## Overall Architecture

```
+===========================================================================+
|VIRTUALBOX HOST (Your PC)|
|                                                                           |
|  Host-Only #1: 192.168.56.0/24 (Public) |
|  Host-Only #2: 192.168.1.0/24 (Primary Interconnect)                   |
|  Host-Only #3: 192.168.2.0/24 (Interconnect Standby)                    |
|                                                                           |
|  +----------+   +----------+----------+   +----------+----------+        |
|  | dnsnode  |   | rac1     | rac2     |   | racstby1 | racstby2 |        |
|  | .56.50   |   | .56.101  | .56.102  |   | .56.111  | .56.112  |        |
|  | Dnsmasq  |   | VIP .103 | VIP .104 |   | VIP .113 | VIP .114 |        |
|  | 1GB/1CPU |   | 8GB/4CPU | 8GB/4CPU |   | 8GB/4CPU | 8GB/4CPU |        |
|  +----------+   +-----+----+----+-----+   +-----+----+----+-----+        |
|                       |         |               |         |               |
|                  +----+---------+----+     +----+---------+----+          |
|                  | Interconnect     |     | Interconnect     |           |
|                  | 192.168.1.101-102|     | 192.168.2.111-112|           |
|                  | (Cache Fusion)   |     | (Cache Fusion)   |           |
|                  +------------------+     +------------------+           |
|                                                                           |
|  SCAN Primary: rac-scan       --> 192.168.56.105, .106, .107             |
|  SCAN Standby: racstby-scan --> 192.168.56.115, .116, .117             |
|                                                                           |
|  +-------------------------------+   +-------------------------------+   |
|  | RAC PRIMARY (RACDB)           |   | RAC STANDBY (RACDB_STBY)     |   |
|  | Grid 19c + RU                 |   | Active Data Guard            |   |
|  | ASM: +CRS(2GBx3) +DATA(20GB) |   | READ ONLY WITH APPLY         |   |
|  |      +RECO(15GB)              |   | GG Extract + Data Pump       |   |
|  +---------------+---------------+   +-------------------------------+   |
|                  |                                                        |
|                  | Data Guard: Redo Shipping (LGWR ASYNC)                 |
|                  v                                                        |
|  +---------------------------------------------------------------+        |
|  | TARGET ENVIRONMENT (dbtarget / Cloud OCI / Altra VM)          |        |
|  | - Oracle Database Target (Replica Oracle-Oracle)              |        |
|  | - PostgreSQL 16 Target (Oracle-PostgreSQL Migration)       |        |
|  |--> Receives data via GoldenGate Replicat|        |
|  +---------------------------------------------------------------+        |
+===========================================================================+
```

---

## Prerequisiti Software

| Software | Versione | Download |
|---|---|---|
| Oracle Linux | 7.9 (VM) | [Oracle Linux ISOs](https://yum.oracle.com/oracle-linux-isos.html) |
| Oracle Grid Infrastructure | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle Database | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle GoldenGate | 19c o 21c | [eDelivery](https://edelivery.oracle.com) |
| Oracle Enterprise Manager | 13.5 | [Oracle Software Delivery Cloud](https://edelivery.oracle.com) |
| VirtualBox | Ultimo | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) |

> Download EVERYTHING before you start! See the full list in [PHASE 0](./GUIDE_PHASE0_MACHINE_SETUP.md).

---

## IP plan

| Hostname | Public IP | Private IP | VIP IP | Notes |
|---|---|---|---|---|
| dnsnode | 192.168.56.50 | -- | -- | Dnsmasq DNS |
| rac1 | 192.168.56.101 | 192.168.1.101 | 192.168.56.103 | RAC Primary N.1 |
| rac2 | 192.168.56.102 | 192.168.1.102 | 192.168.56.104 | RAC Primary N.2 |
| rac-scan | 192.168.56.105-107 | -- | -- | SCAN (3 IP) |
| racstby1 | 192.168.56.111 | 192.168.2.111 | 192.168.56.113 | Standby No.1 |
| racstby2 | 192.168.56.112 | 192.168.2.112 | 192.168.56.114 | Standby No.2 |
| racstby-scan | 192.168.56.115-117 | -- | -- | SCAN Standby (3 IP) |
| dbtarget | Cloud OCI | -- | -- | GoldenGate Replicat |

---

## Credits and References

- [Oracle Base - RAC 19c on VirtualBox](https://oracle-base.com/articles/19c/oracle-db-19c-rac-installation-on-oracle-linux-7-using-virtualbox)
- [Oracle MAA Best Practices](https://www.oracle.com/database/technologies/high-availability/maa.html)
- [My Oracle Support](https://support.oracle.com) - Doc ID 2118136.2 per le Release Update


