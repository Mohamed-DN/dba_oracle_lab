# 🏛️ Oracle RAC + Data Guard — Enterprise DBA Lab

[![Oracle 19c](https://img.shields.io/badge/Oracle-19c-red?logo=oracle&logoColor=white)](https://www.oracle.com/database/)
[![Ansible](https://img.shields.io/badge/Ansible-Automation-black?logo=ansible)](./automation/)
[![Scripts](https://img.shields.io/badge/Scripts-1000%2B-blue)](./docs/13_libreria_completa_script/)
[![MAA Gold](https://img.shields.io/badge/MAA_Gold-98%25-green)](./docs/10_esami_carriera/VALIDAZIONE_BEST_PRACTICES.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

> Complete step-by-step guide to building an Oracle Enterprise architecture in a lab environment.
> **98% Validated** against the official Oracle MAA Gold best practices.

### 📑 Quick Navigation

[⚡ What's Inside](#-whats-in-this-repository) · [🚀 Quick Start](#-quick-start-5-minutes) · [📖 Lab Phases 0→8](#-run-the-lab-phase-0--8) · [📚 Thematic Guides](#-guides-by-topic) · [🛠️ Tools](#️-operational-tools) · [📅 Roadmap](#-lab-roadmap-8-weeks-3hday) · [🌐 IP Plan](#-ip-plan)

---

## 🚀 Quick Start (5 minutes)

```bash
# 1. Clone the repo
git clone https://github.com/Mohamed-DN/dba_oracle_lab.git
cd dba_oracle_lab

# 2A. MANUAL PATH (learn more, ~30 hours)
#     Follow the 9 guides in order → docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md

# 2B. AUTOMATED PATH (1-click, requires 33GB RAM)
cd vagrant_rac_dataguard
vagrant up    # → creates DNS + 2 RAC Primary nodes + 2 Standby nodes + Data Guard

# 3. After the lab, use the operational scripts every day
#    → docs/12_scripts_sql_pronti/  (10 SQL scripts for emergencies)
#    → docs/11_runbook_operativi/   (13 DBA runbooks)
```

> 💡 **First day?** Read [Oracle Architecture](./docs/00_fondamenti/GUIDA_ARCHITETTURA_ORACLE.md) and [Glossary](./docs/00_fondamenti/GLOSSARIO_ORACLE.md) first.

---

## ⚡ What's in This Repository

| Section | Content | Quantity |
|---|---|---|
| 📖 [Lab Guides (Phases 0→8)](#-run-the-lab-phase-0--8) | Build a RAC + Data Guard + GoldenGate from scratch | 9 guides |
| 📚 [Documentation](./docs/) | Thematic guides for every DBA area | 40+ guides |
| 🛠️ [Operational Scripts](./docs/12_scripts_sql_pronti/) | Copy-paste-ready SQL for real-world scenarios | 10 scripts |
| 📂 [Oracle Library](./docs/13_libreria_completa_script/) | Enterprise collection of scripts and procedures | **~1000 scripts** |
| 📋 [Operational Runbooks](./docs/11_runbook_operativi/) | Daily runbooks for DBA activities | 13 runbooks |
| 🤖 [Ansible Automation](./automation/) | Production-grade playbooks | 10 playbooks |
| 🖥️ [Vagrant One-Click](./vagrant_rac_dataguard/) | Fully automated environment (Phases 0→4) | 1-click setup |

---

## ⚠️ Before You Start

| Requirement | Detail |
|---|---|
| **Minimum RAM** | **32GB** for the full environment (4 RAC nodes + DNS). With 16GB: only 2 nodes, no Standby |
| **Disk** | ~150GB free (VMs + ASM disks + Oracle software) |
| **CPU** | 4+ cores recommended (VirtualBox with VT-x/AMD-V enabled) |
| **Host OS** | Windows, Linux, or macOS with VirtualBox 7+ |

> 💡 **Don't want to do everything manually?**
> - **Partial**: The `scripts/` folder has bash scripts for storage and Grid.
> - **Full**: [`vagrant_rac_dataguard/`](vagrant_rac_dataguard/README.md) automates **Phases 0→4** in one click (33GB RAM).

---

## 🏗️ Lab Architecture

```mermaid
flowchart TD
    subgraph "Host (Your PC)"
        dns("DNS Node\n192.168.56.50")
        
        subgraph "Primary DataCenter"
            rac1[("rac1\n192.168.56.101\n8G/4CPU")]
            rac2[("rac2\n192.168.56.102\n8G/4CPU")]
            
            rac1 <== "Private Network 1 & 2\n(Cache Fusion)\n192.168.1.0/24, 192.168.2.0/24" ==> rac2
            db1>"RAC PRIMARY (RACDB)\nASM: +CRS, +DATA, +RECO"]
            rac1 --- db1
            rac2 --- db1
        end
        
        subgraph "Standby DataCenter"
            racstby1[("racstby1\n192.168.56.111\n8G/4CPU")]
            racstby2[("racstby2\n192.168.56.112\n8G/4CPU")]
            
            racstby1 <== "Private Network 1 & 2\n(Cache Fusion)\n192.168.1.0/24, 192.168.2.0/24" ==> racstby2
            db2>"RAC STANDBY (RACDB_DG)\nASM: +CRS, +DATA, +RECO"]
            racstby1 --- db2
            racstby2 --- db2
        end
        
        dns -.-> rac1
        dns -.-> rac2
        dns -.-> racstby1
        dns -.-> racstby2
        
        db1 == "Data Guard (LGWR ASYNC)" ==> db2
        db1 -. "GoldenGate Extract" .-> gg("Target (Locale / OCI)")
        
    end
```

---

## 📖 Run the Lab (Phase 0 → 8)

Follow the phases **in order**. Each phase depends on the previous one.

| # | Phase | Guide | What You Do | Time |
|---|---|---|---|---|
| 0 | **Machine Setup** | [GUIDA_FASE0](./docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md) | Create VirtualBox VMs, DNS, ASM disks | 3-4h |
| 1 | **OS Preparation** | [GUIDA_FASE1](./docs/01_lab_setup/GUIDA_FASE1_PREPARAZIONE_OS.md) | Network, DNS, users, SSH, kernel | 2-3h |
| 2 | **Grid + RAC** | [GUIDA_FASE2](./docs/01_lab_setup/GUIDA_FASE2_GRID_E_RAC.md) | Grid Infrastructure, ASM, Database | 4-5h |
| 3 | **RAC Standby** | [GUIDA_FASE3](./docs/02_high_availability/GUIDA_FASE3_RAC_STANDBY.md) | RMAN Duplicate, static Listener, MRP | 3-4h |
| 4 | **Data Guard** | [GUIDA_FASE4](./docs/02_high_availability/GUIDA_FASE4_DATAGUARD_DGMGRL.md) | DGMGRL Broker, Protection Mode, FASTSYNC | 2-3h |
| 5 | **RMAN Backup** | [GUIDA_FASE5](./docs/03_backup_recovery/GUIDA_FASE5_RMAN_BACKUP.md) | Strategia backup, cron, BCT, restore | 2h |
| 6 | **Enterprise Manager** | [GUIDA_FASE6](./docs/08_monitoring/GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md) | OEM Cloud Control 13.5 + Agent | 4-5h |
| 7 | **GoldenGate** | [GUIDA_FASE7](./docs/07_replication/GUIDA_FASE7_GOLDENGATE.md) | Extract, Pump, Replicat (Oracle + PG) | 3-4h |
| 8 | **Verification Tests** | [GUIDA_FASE8](./docs/01_lab_setup/GUIDA_FASE8_TEST_VERIFICA.md) | End-to-end tests, stress, node crash | 2-3h |

> **Estimated total time**: ~30 hours of hands-on work.

---

## 📚 Guides by Topic

### 🟢 Fundamentals — read before the lab

| Guide | What You Learn |
|---|---|
| [Oracle Architecture](./docs/00_fondamenti/GUIDA_ARCHITETTURA_ORACLE.md) | SGA, PGA, Redo Log, Undo, ASM, Cache Fusion |
| [**Transaction Lifecycle**](./docs/00_fondamenti/GUIDA_CICLO_DI_VITA_TRANSAZIONE.md) | Anatomy of an UPDATE: Parsing, Cache, ITL, Redo, DBWR, LGWR |
| [Memory Architecture (SGA/PGA)](./docs/00_fondamenti/GUIDA_MEMORIA_ORACLE_SGA_PGA.md) | Deep Dive: Buffer Cache, Shared Pool, AMM vs ASMM, HugePages |
| [Redo/Undo & Crash Recovery](./docs/00_fondamenti/GUIDA_REDO_UNDO_CRASH_RECOVERY.md) | Deep Dive: Write-Ahead Logging, Checkpoint, Roll Forward/Back |
| [Locking, Concurrency & Wait Events](./docs/00_fondamenti/GUIDA_LOCKING_CONCURRENCY_WAIT_EVENTS.md) | Deep Dive: MVCC, ITL, Deadlocks, e Top 15 Wait Events |
| [DBA Commands](./docs/00_fondamenti/GUIDA_COMANDI_DBA.md) | 100+ essential SQL queries for the DBA |
| [**Vagrant Base Analysis**](./docs/00_fondamenti/ANALISI_ORACLEBASE_VAGRANT.md) | In-depth study of the automated configuration |
| [Glossary](./docs/00_fondamenti/GLOSSARIO_ORACLE.md) | 100+ Oracle acronyms and terms explained |
| [Lab Plan](./docs/00_fondamenti/PIANO_LABORATORIO.md) | 8 weeks × 3h/day, complete roadmap |
| [Lab Journal](./docs/00_fondamenti/DIARIO_DI_BORDO.md) | Notes and lab progress log |

---

### 🔵 High Availability — Data Guard, Switchover, Failover

| Guida | Cosa Impari |
|---|---|
| [Complete Switchover](./docs/02_high_availability/GUIDA_SWITCHOVER_COMPLETO.md) | Switchover + Switchback step-by-step |
| [Failover + Reinstate](./docs/02_high_availability/GUIDA_FAILOVER_E_REINSTATE.md) | ⚠️ **NOT mandatory in the lab** — see note below |
| [Flashback Database](./docs/02_high_availability/GUIDA_FLASHBACK_DATABASE.md) | Oracle "time machine" |
| [MAA Best Practices](./docs/02_high_availability/GUIDA_MAA_BEST_PRACTICES.md) | Oracle Maximum Availability Architecture |

> ⚠️ **FAILOVER**: Destructive operation. **Before** attempting it:
> 1. Shut down ALL VMs
> 2. **Copy/zip the entire VirtualBox VMs folder** as a backup
> 3. Then proceed — if everything breaks, restore from the copy

---

### 🟡 Backup & Recovery

| Guida | Cosa Impari |
|---|---|
| [Complete RMAN 19c](./docs/03_backup_recovery/GUIDA_RMAN_COMPLETA_19C.md) | Backup, restore, recovery, catalog, practical tests |
| [Data Pump](./docs/03_backup_recovery/GUIDA_DATA_PUMP.md) | Export/Import con expdp/impdp |

---

### 🟠 Administration

| Guida | Cosa Impari |
|---|---|
| [CDB/PDB/Users](./docs/04_administration/GUIDA_CDB_PDB_UTENTI.md) | Multitenant, PDB create/clone/plug, roles |
| [Listener and Services](./docs/04_administration/GUIDA_LISTENER_SERVICES_DBA.md) | Listener, TNS, services in detail |
| [RAC Application Services](./docs/04_administration/GUIDA_SERVIZI_APPLICATIVI_RAC.md) | TAF, FAN, CLB/RLB, Application Continuity |
| [Ansible Response Templates](./docs/04_administration/GUIDA_ANSIBLE_TEMPLATES.md) | **New**: How to do 100% *silent install* with Jinja2 |
| [ASM Disk Management](./docs/04_administration/GUIDA_AGGIUNTA_DISCHI_ASM.md) | Add/remove ASM disks (ASMLib + AFD) |
| [Oracle Scheduler](./docs/04_administration/GUIDA_SCHEDULER_JOBS.md) | Jobs, chains, auto-tasks, monitoring |
| [Security Hardening](./docs/04_administration/GUIDA_SECURITY_HARDENING.md) | TDE, Auditing, Encryption, Password Profiles |
| [**Oracle Identity and Services**](./docs/04_administration/GUIDA_IDENTITA_ORACLE_E_SERVIZI.md) | **MEGA-GUIDE**: DB_NAME vs SID vs SERVICE_NAME, Listener, Role-Based Services, Switchover |

---

### 🔴 Performance & Diagnostics

| Guida | Cosa Impari |
|---|---|
| [Complete Troubleshooting](./docs/05_performance/GUIDA_TROUBLESHOOTING_COMPLETO.md) | **MEGA-GUIDE**: from-scratch method, wait events, real-world scenarios |
| [AWR/ASH/ADDM](./docs/05_performance/GUIDA_AWR_ASH_ADDM.md) | SQL Monitor, SPM, SQL Quarantine |
| [Top 100 DBA Scripts](./docs/05_performance/TOP_100_SCRIPT_DBA.md) | The 100 most useful daily scripts |

---

### 🟣 Patching & Upgrade

| Guida | Cosa Impari |
|---|---|
| [RAC Patching](./docs/06_patching_upgrade/GUIDA_PATCHING_RAC.md) | Combo Patch, OJVM, cleanup |
| [RU Upgrade RAC](./docs/06_patching_upgrade/GUIDA_UPGRADE_RU_RAC.md) | Rolling upgrade, skip version, rollback |
| [AutoUpgrade 12c → 19c](./docs/06_patching_upgrade/GUIDA_AUTOUPGRADE_12C_TO_19C.md) | AutoUpgrade completo con config.cfg |
| [AutoUpgrade 19c → 26c](./docs/06_patching_upgrade/GUIDA_AUTOUPGRADE_19C_TO_26.md) | New Long-Term Release |

---

### 🔄 Replication & Migration

| Guida | Cosa Impari |
|---|---|
| [GoldenGate Migration](./docs/07_replication/GUIDA_MIGRAZIONE_GOLDENGATE.md) | Zero-downtime migration |
| [Oracle → PostgreSQL](./docs/07_replication/GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md) | Migration with GG, ora2pg, ODBC |

---

### 📊 Monitoring

| Guida | Cosa Impari |
|---|---|
| [Open Source Monitoring](./docs/08_monitoring/GUIDA_MONITORING_OPENSOURCE.md) | **Checkmk vs Zabbix vs Prometheus+Grafana** — complete installation guide |
| [Enterprise Manager 13c](./docs/08_monitoring/GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md) | OEM Cloud Control: OMS, Agent, discovery |

---

### ☁️ Cloud OCI — Optional

> Advanced alternative path: replicate to Oracle Cloud (OCI ARM Free Tier).

| Guida | Cosa Impari |
|---|---|
| [GoldenGate to OCI](./docs/09_cloud_oci/GUIDA_GOLDENGATE_OCI_ARM.md) | OCI target, Free vs Enterprise |
| [Lab ↔ OCI Network](./docs/09_cloud_oci/GUIDA_RETE_LAB_OCI_GOLDENGATE.md) | VPN, SSH tunnel, NSG |

---

### 🎓 Exams & Career

| Guida | Cosa Impari |
|---|---|
| [DBA Concepts Review](./docs/10_esami_carriera/GUIDA_RIPASSO_CONCETTI_DBA.md) | 12 Q&A sections on architecture, RAC, DG, performance, scenarios |
| [Exam Preparation](./docs/10_esami_carriera/GUIDA_ESAME_REVIEW.md) | Complete 1Z0-082 + 1Z0-083 |
| [From Lab to Production](./docs/10_esami_carriera/GUIDA_DA_LAB_A_PRODUZIONE.md) | Sizing, HugePages, security |
| [DBA Activities](./docs/10_esami_carriera/GUIDA_ATTIVITA_DBA.md) | Batch Jobs, AWR, Patching, DataPump |
| [**Interview Preparation**](./docs/10_esami_carriera/GUIDA_PREPARAZIONE_COLLOQUIO_TECNICO.md) | **MEGA-GUIDE**: mindset, STAR method and 18 advanced questions |
| [Best Practices Validation](./docs/10_esami_carriera/VALIDAZIONE_BEST_PRACTICES.md) | 54-point audit, 98% scorecard |

---

## 🛠️ Operational Tools

### SQL Scripts by Scenario (`docs/12_scripts_sql_pronti/`)

> **10 copy-paste-ready scripts** — [Full index](./docs/12_scripts_sql_pronti/README.md)

| Script | Scenario | Errors Covered |
|---|---|---|
| [01 Tablespace/Datafile](./docs/12_scripts_sql_pronti/01_tablespace_datafile.sql) | Bigfile vs Smallfile, maxsize, resize | ORA-01654, ORA-01653 |
| [02 UNDO/TEMP](./docs/12_scripts_sql_pronti/02_undo_temp.sql) | Full undo, full temp, retention | ORA-01555, ORA-30036 |
| [03 FRA/Archivelog](./docs/12_scripts_sql_pronti/03_fra_archivelog.sql) | Full FRA → DB SUSPEND! Data Pump impact | ORA-19815, ORA-00257 |
| [04 Data Pump](./docs/12_scripts_sql_pronti/04_datapump_operativo.sql) | Safe Export/Import, pre-check FRA | Prevention |
| [05 ASM Storage](./docs/12_scripts_sql_pronti/05_asm_storage.sql) | Diskgroup, AU_SIZE, limits | Capacity planning |
| [06 Sessions/Lock](./docs/12_scripts_sql_pronti/06_sessioni_lock.sql) | Who is blocking whom, kill session | "App stuck!" |
| [07 Performance](./docs/12_scripts_sql_pronti/07_performance_quick.sql) | Top SQL, wait events, hit ratio | "DB slow!" |
| [08 RMAN Backup](./docs/12_scripts_sql_pronti/08_rman_backup_status.sql) | Last backup, failures | Morning check |
| [09 Data Guard](./docs/12_scripts_sql_pronti/09_dataguard_status.sql) | Lag, GAP, MRP, switchover ready | Morning check |
| [10 Objects/Schema](./docs/12_scripts_sql_pronti/10_oggetti_schema.sql) | Invalid objects, large segments, recyclebin | Post-upgrade |

---

### Operational Runbooks (`docs/11_runbook_operativi/`)

> **13 daily runbooks** — [Full index](./docs/11_runbook_operativi/README.md)

| # | Procedure | Frequency |
|---|---|---|
| 01 | [Morning Health Check](./docs/11_runbook_operativi/01_MORNING_HEALTH_CHECK.md) | Every morning |
| 02 | [Backup Verification](./docs/11_runbook_operativi/02_VERIFICA_BACKUP.md) | Every morning |
| 03 | [Data Guard Check](./docs/11_runbook_operativi/03_CHECK_DATAGUARD.md) | Every morning |
| 04-08 | Lock, Slow Query, Full TBS, CPU, ORA-Errors | On demand / alert |
| 09-11 | User Management, Start/Stop RAC, AWR Review | Weekly |
| 12-13 | Capacity Planning, Test Schema Refresh | Monthly |

---

### Ansible Automation (`automation/`)

> **10 production-grade playbooks** — [Full index](./automation/README.md)

| Playbook | What It Does |
|---|---|
| [01 Oracle Install](./automation/playbooks/01_oracle_install.yml) | Silent 19c installation |
| [02 Oracle Patching](./automation/playbooks/02_oracle_patching.yml) | Rolling patch (zero downtime) |
| [03 AutoUpgrade](./automation/playbooks/03_oracle_autoupgrade.yml) | 3 fasi: pre_upgrade → upgrade → finalize |
| [04 Health Check](./automation/playbooks/04_daily_health_check.yml) | Automated morning check |
| [05 RMAN Backup](./automation/playbooks/05_rman_backup.yml) | Backup + crosscheck + validate |
| [06 DG Switchover](./automation/playbooks/06_dataguard_switchover.yml) | Automated Data Guard Switchover |
| [07 Users & TBS](./automation/playbooks/07_create_users_tablespaces.yml) | BIGFILE Tablespace and User creation |
| [08 Gather Stats](./automation/playbooks/08_gather_stats.yml) | Automated DBMS_STATS via Ansible |
| [09 DataPump Export](./automation/playbooks/09_datapump_export.yml) | Parallel export of application schemas |
| [10 RAC Services](./automation/playbooks/10_manage_services.yml) | Start/Stop srvctl for RAC services |

---

### Oracle Library (`docs/13_libreria_completa_script/`)

> **~1000 scripts** from the Oracle community — [Full index](./docs/13_libreria_completa_script/README.md)

| Area | Scripts | What You Find |
|---|---|---|
| [Monitoring](./docs/13_libreria_completa_script/03_monitoring_scripts/) | 586 | Sessions, lock, CPU, I/O, ASH, network |
| [Performance](./docs/13_libreria_completa_script/07_performance_tuning/) | 225 | SPM, AWR, statistiche, SQL tuning |
| [Utilities](./docs/13_libreria_completa_script/12_utilities/) | 103 | Scheduler, storage, CDB/PDB, profiles |
| [Other](./docs/13_libreria_completa_script/README.md) | 86 | ASM, DG, users, patching, TDE, partitions |

---

### Extra Resources (Archive)

| Document | Description |
|---|---|
| [DBA Activity Catalog](./docs/10_esami_carriera/archivio_extra/GUIDA_CATALOGO_ATTIVITA_DBA.md) | Complete overview of real DBA activities |
| [Operational Checklist](./docs/10_esami_carriera/archivio_extra/GUIDA_CHECKLIST_ATTIVITA_DBA.md) | Daily/weekly/monthly runbook |
| [DBA Technical Questions](./docs/10_esami_carriera/archivio_extra/GUIDA_DOMANDE_DBA_ORACLE.md) | Questions and answers for exams and certifications |

---

## 📅 Lab Roadmap (8 weeks, 3h/day)

| Week | Focus | Output |
|---|---|---|
| 1 | OS + Grid + ASM | Stable Grid, prerequisites complete |
| 2 | RAC + standby | Operational RAC + standby ready |
| 3 | Data Guard + RMAN + GG | Broker OK, backup validated, GG basics |
| 4 | Advanced GG + HA tests | 24+ GoldenGate tests completed |
| 5 | EM + monitoring + cloud | OMS/Agent active, alerting functional |
| 6 | Oracle → PG migration | End-to-end flow completed |
| 7 | Exam 1Z0-082 | 2 mock exams + error review |
| 8 | Exam 1Z0-083 | 2 mock exams + final runbooks |

> Detailed day-by-day plan: [PIANO_LABORATORIO.md](./docs/00_fondamenti/PIANO_LABORATORIO.md)

---

## 🌐 IP Plan

| Hostname | Public IP | Private IP | VIP | Role |
|---|---|---|---|---|
| dnsnode | 192.168.56.50 | — | — | DNS (Dnsmasq) |
| rac1 | 192.168.56.101 | 192.168.1.101 | .56.103 | RAC Primary N.1 |
| rac2 | 192.168.56.102 | 192.168.1.102 | .56.104 | RAC Primary N.2 |
| rac-scan | .56.105-107 | — | — | SCAN Primary |
| racstby1 | 192.168.56.111 | 192.168.2.111 | .56.113 | Standby N.1 |
| racstby2 | 192.168.56.112 | 192.168.2.112 | .56.114 | Standby N.2 |
| racstby-scan | .56.115-117 | — | — | SCAN Standby |

---

## 📦 Required Software

| Software | Version | Download |
|---|---|---|
| Oracle Linux | 7.9 | [Oracle Linux ISOs](https://yum.oracle.com/oracle-linux-isos.html) |
| Grid Infrastructure | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle Database | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle GoldenGate | 19c / 21c | [eDelivery](https://edelivery.oracle.com) |
| Enterprise Manager | 13.5 | [eDelivery](https://edelivery.oracle.com) |
| VirtualBox | 7.x | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) |

> 💡 Download EVERYTHING before starting! Full list in [Phase 0](./docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md).

---

## 📎 References

| Resource | Link |
|---|---|
| Oracle Base — RAC 19c on VirtualBox | [oracle-base.com](https://oracle-base.com/articles/19c/oracle-db-19c-rac-installation-on-oracle-linux-7-using-virtualbox) |
| Oracle MAA Best Practices | [oracle.com/maa](https://www.oracle.com/database/technologies/high-availability/maa.html) |
| My Oracle Support | [support.oracle.com](https://support.oracle.com) — Doc ID 2118136.2 |
| Ansible Oracle Collection | [oravirt/ansible-oracle](https://github.com/oravirt/ansible-oracle) |
| Ansible DB Upgrade | [CruGlobal/ansible-oracle-db-upgrade](https://github.com/CruGlobal/ansible-oracle-db-upgrade) |
| Oracle DB 19c Docs | [docs.oracle.com](https://docs.oracle.com/en/database/oracle/oracle-database/19/) |

---

<p align="center">
  <sub>Built with ☕ and <code>ORA-00001</code> errors — <a href="./LICENSE">MIT License</a> — <a href="./CONTRIBUTING.md">Contributing</a></sub>
</p>
