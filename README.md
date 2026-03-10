# Oracle RAC + Data Guard + GoldenGate + Cloud - Ultimate Guide

> Comprehensive step-by-step guide to building an Enterprise Oracle architecture in a home lab.
> **98% Validated** against official Oracle MAA Gold best practices.

---

> ⚠️ **CRITICAL HARDWARE REQUIREMENTS**: To run the entire environment (4 RAC Nodes + 1 DNS Node + 1 PostgreSQL Target Node + OS Host), **you need at least 32GB of physical RAM** on your PC. If you have 16GB, you can only do half of the lab (e.g., 2 RAC nodes without Standby).

> 🤖 **AUTOMATION AVAILABLE**: Want to skip the boring parts? In the `scripts/` folder, you will find ready-to-use bash scripts to auto-configure storage (`configure_storage.sh`) and install Grid (`install_grid.sh`). The guides show you the manual path (for learning), but the scripts are at your disposal!

---

## 🚀 CHANGELOG: Autonomous DBA Optimization

*This section tracks the architectural and educational optimizations applied completely autonomously to bring the repository to optimal Enterprise standards.*

| Date | Modified File | Optimization Applied (DBA Explanation) |
|---|---|---|
| In progress... | `...` | *Audit started...* |

---

## WHERE TO START

**STUDY PATH**

```
STEP 0: READ THEORY FIRST (2 hours)
  |
  |  1. GUIDE_ORACLE_ARCHITECTURE.md   <-- SGA, PGA, Redo, Undo, Temp, ASM
  |  2. GUIDE_DBA_COMMANDS.md          <-- Essential SQL queries, DBA scripts
  |  3. DAILY_STUDY_PLAN.md            <-- YOUR plan: 40 days x 3h
  |
  v
STEP 1-7: BUILD THE LAB (Weeks 1-4)
  |
  |  4. PHASE 0 --> VirtualBox Machines Setup (DNS, RAC, Storage)
  |  5. PHASE 1 --> OS Preparation (network, DNS, users, SSH)
  |  6. PHASE 2 --> Grid Infrastructure + RAC Database
  |  7. PHASE 3 --> RAC Standby (RMAN Duplicate)
  |  8. PHASE 4 --> Data Guard (DGMGRL, ADG)
  |  9. PHASE 5 --> GoldenGate (Extract, Pump, Replicat)
  | 10. PHASE 6 --> End-to-end Testing and Verification
  | 11. PHASE 7 --> RMAN Backup Strategy
  |
  v
STEP 8-11: ADVANCED OPERATIONS (Week 4)
  |
  | 12. Data Guard Switchover
  | 13. Failover + Reinstate
  | 14. Zero-downtime migration with GoldenGate
  | 15. Listener, Services, DBA Toolkit
  |
  v
STEP 12-14: CLOUD + DBA PRO (Week 5)
  |
  | 16. Cloud GoldenGate on OCI ARM Free Tier
  | 17. DBA Activities (Batch, AWR, Patching, DataPump, Security)
  | 18. MAA Best Practices + Validation
  |
  v
STEP 15-17: POSTGRES + EXAMS (Weeks 6-8)
  |
  | 19. Oracle -> PostgreSQL Migration with GoldenGate
  | 20. Review for 1Z0-082 Exam (Admin I + SQL)
  | 21. Review for 1Z0-083 Exam (DBA Professional 2)
  |
  v
COMPLETED! --> Read GUIDE_FROM_LAB_TO_PRODUCTION.md for real-world sizing
```

> **Tip**: Follow the [Daily Study Plan](./DAILY_STUDY_PLAN.md) -- it tells you exactly what to do every day in 3 hours.

---

## Full Index - All Guides

### Theory (Read BEFORE building)

| # | Document | File | What you learn |
|---|---|---|---|
| 1 | **Oracle Architecture** | [GUIDE_ARCHITECTURE](./GUIDE_ORACLE_ARCHITECTURE.md) | SGA, PGA, Redo Log, Undo, Temp, ASM, Cache Fusion |
| 2 | **DBA Commands** | [GUIDE_DBA_COMMANDS](./GUIDE_DBA_COMMANDS.md) | 100+ SQL queries, Oracle Base scripts, health check |
| 3 | **CDB/PDB, Users, EM Express** | [GUIDE_CDB_PDB_USERS](./GUIDE_CDB_PDB_USERS.md) | Multitenant, PDB create/clone/plug, users, roles, SQL Tuning |
| 4 | **Study Plan** | [STUDY_PLAN](./DAILY_STUDY_PLAN.md) | 25 days x 3h/day (5 weeks), CV tips |

---

### Lab Construction (Follow in order!)

| # | Phase | File | What you do |
|---|---|---|---|
| 4 | **Phase 0** | [MACHINE SETUP](./GUIDE_PHASE0_MACHINE_SETUP.md) | Create VM VirtualBox, Dnsmasq DNS, oracleasm disks, install OL 7.9 |
| 5 | **Phase 1** | [OS PREPARATION](./GUIDE_PHASE1_OS_PREPARATION.md) | Setup network, DNS, users, SSH, kernel |
| 6 | **Phase 2** | [GRID + RAC](./GUIDE_PHASE2_GRID_AND_RAC.md) | Install Grid, ASM, DB Software, create RACDB |
| 7 | **Phase 3** | [RAC STANDBY](./GUIDE_PHASE3_RAC_STANDBY.md) | RMAN Duplicate, Static listener, MRP |
| 8 | **Phase 4** | [DATA GUARD](./GUIDE_PHASE4_DATAGUARD_DGMGRL.md) | DGMGRL Broker, Active Data Guard |
| 9 | **Phase 5** | [GOLDENGATE](./GUIDE_PHASE5_GOLDENGATE.md) | Extract on Standby, Pump, Replicat Target |
| 10 | **Phase 6** | [TEST & VERIFY](./GUIDE_PHASE6_TEST_VERIFY.md) | Test DG + GG + stress + node crash |
| 11 | **Phase 7** | [RMAN BACKUP](./GUIDE_PHASE7_RMAN_BACKUP.md) | Backup strategy, scripts, cron, BCT, restore |

---

### Advanced Operations (After base lab)

| # | Document | File | What you learn |
|---|---|---|---|
| 12 | **Switchover** | [GUIDE_SWITCHOVER](./GUIDE_FULL_SWITCHOVER.md) | Step-by-step Switchover + Switchback |
| 13 | **Failover + Reinstate** | [GUIDE_FAILOVER](./GUIDE_FAILOVER_AND_REINSTATE.md) | Emergency failover, reinstate, FSFO |
| 14 | **GG Migration** | [GUIDE_MIGRATION](./GUIDE_GOLDENGATE_MIGRATION.md) | Zero-downtime migration with GoldenGate |
| 15 | **Listener + Services** | [GUIDE_LISTENER_DBA](./GUIDE_LISTENER_SERVICES_DBA.md) | RAC Listener, SCAN, Services, DBA Toolkit |

---

### Cloud and Professional DBA (Week 5)

| # | Document | File | What you learn |
|---|---|---|---|
| 16 | **Cloud GoldenGate** | [GUIDE_CLOUD_GG](./GUIDE_GOLDENGATE_OCI_ARM.md) | OCI Free Tier ARM, hybrid 23ai Free setup, SSH tunnel |
| 17 | **DBA Activities** | [GUIDE_DBA_ACTIVITIES](./GUIDE_DBA_ACTIVITIES.md) | Batch Jobs, AWR/ADDM/ASH, Patching, DataPump, Security |
| 18 | **MAA Best Practices** | [GUIDE_MAA](./GUIDE_MAA_BEST_PRACTICES.md) | Validate lab vs Oracle MAA Gold |

---

### Exam + PostgreSQL Migration (Week 6)

| # | Document | File | What you learn |
|---|---|---|---|
| 19 | **Exam Review** | [GUIDE_EXAM_REVIEW](./GUIDE_EXAM_REVIEW.md) | All topics 1Z0-082 + 1Z0-083 (Admin + SQL + DBA Pro 2) |
| 20 | **Oracle → PostgreSQL** | [GUIDE_MIGRATION_PG](./GUIDE_ORACLE_POSTGRES_MIGRATION.md) | Oracle→PostgreSQL migration with GoldenGate, ora2pg, ODBC |

---

### Reference and Deep Dive

| Document | File | Description |
|---|---|---|
| **From Lab to Production** | [GUIDE_PRODUCTION](./GUIDE_FROM_LAB_TO_PRODUCTION.md) | Sizing, HugePages, security, monitoring |
| **Oracle BP Validation** | [VALIDATION_BP](./BEST_PRACTICES_VALIDATION.md) | 54-point audit, 98% scorecard, GUI vs CLI |
| **Oracle Base Analysis** | [ORACLEBASE_ANALYSIS](./ORACLEBASE_VAGRANT_ANALYSIS.md) | Comparison with Oracle Base Vagrant |

---

## Overall Architecture

```
+===========================================================================+
|                      VIRTUALBOX HOST (Your PC)                            |
|                                                                           |
|  Host-Only #1: 192.168.56.0/24 (Public)                                  |
|  Host-Only #2: 192.168.1.0/24  (Primary Interconnect)                    |
|  Host-Only #3: 192.168.2.0/24  (Standby Interconnect)                    |
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
|  SCAN Standby: racstby-scan   --> 192.168.56.115, .116, .117             |
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
|  | TARGET ENVIRONMENT (dbtarget / Cloud OCI / Other VM)          |        |
|  | - Oracle Database Target (Oracle-Oracle Replication)          |        |
|  | - PostgreSQL 16 Target   (Oracle-PostgreSQL Migration)        |        |
|  |   --> Receives data via GoldenGate Replicat                   |        |
|  +---------------------------------------------------------------+        |
+===========================================================================+
```

---

## Software Prerequisites

| Software | Version | Download |
|---|---|---|
| Oracle Linux | 7.9 (VM) | [Oracle Linux ISOs](https://yum.oracle.com/oracle-linux-isos.html) |
| Oracle Grid Infrastructure | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle Database | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle GoldenGate | 19c or 21c | [eDelivery](https://edelivery.oracle.com) |
| VirtualBox | Latest | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) |

> Download EVERYTHING before you start! See the complete list in [PHASE 0](./GUIDE_PHASE0_MACHINE_SETUP.md).

---

## IP Plan

| Hostname | Public IP | Private IP | VIP IP | Notes |
|---|---|---|---|---|
| dnsnode | 192.168.56.50 | -- | -- | Dnsmasq DNS |
| rac1 | 192.168.56.101 | 192.168.1.101 | 192.168.56.103 | RAC Primary Node 1 |
| rac2 | 192.168.56.102 | 192.168.1.102 | 192.168.56.104 | RAC Primary Node 2 |
| rac-scan | 192.168.56.105-107 | -- | -- | SCAN (3 IPs) |
| racstby1 | 192.168.56.111 | 192.168.2.111 | 192.168.56.113 | RAC Standby Node 1 |
| racstby2 | 192.168.56.112 | 192.168.2.112 | 192.168.56.114 | RAC Standby Node 2 |
| racstby-scan | 192.168.56.115-117 | -- | -- | Standby SCAN (3 IPs) |
| dbtarget | Cloud OCI | -- | -- | GoldenGate Replicat |

---

## Credits and References

- [Oracle Base - RAC 19c on VirtualBox](https://oracle-base.com/articles/19c/oracle-db-19c-rac-installation-on-oracle-linux-7-using-virtualbox)
- [Oracle MAA Best Practices](https://www.oracle.com/database/technologies/high-availability/maa.html)
- [My Oracle Support](https://support.oracle.com) - Doc ID 2118136.2 for Release Updates
