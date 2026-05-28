# 🏛️ Oracle RAC + Data Guard — Enterprise DBA Lab

[![Oracle 19c](https://img.shields.io/badge/Oracle-19c-red?logo=oracle&logoColor=white)](https://www.oracle.com/database/)
[![CI/CD](https://github.com/Mohamed-DN/dba_oracle_lab/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/Mohamed-DN/dba_oracle_lab/actions/workflows/ci.yml)
[![Security Gates](https://github.com/Mohamed-DN/dba_oracle_lab/actions/workflows/security-gates.yml/badge.svg?branch=master)](https://github.com/Mohamed-DN/dba_oracle_lab/actions/workflows/security-gates.yml)
[![Release Governance](https://github.com/Mohamed-DN/dba_oracle_lab/actions/workflows/release-governance.yml/badge.svg?branch=master)](https://github.com/Mohamed-DN/dba_oracle_lab/actions/workflows/release-governance.yml)
[![Ansible](https://img.shields.io/badge/Ansible-Automation-black?logo=ansible)](./automation/)
[![Scripts](https://img.shields.io/badge/Scripts-1000%2B-blue)](./docs/01_operations/04_libreria_script_completa/)
[![MAA Gold](https://img.shields.io/badge/MAA_Gold-98%25-green)](./docs/04_governance_learning/03_esami_e_carriera/VALIDAZIONE_BEST_PRACTICES.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

> Guida pratica e operativa per costruire e gestire un laboratorio Oracle RAC + Data Guard.
> **Core del repository: Lab Fase 0→8.** Tutto il resto è estensione operativa/avanzata.

## 📑 Navigazione Rapida (livello 1)

- 🧭 **Start Here:** [mappa operativa rapida](./START_HERE.md)
- 🟢 **Fondamenti:** [Indice area](./docs/04_governance_learning/01_fondamenti_teorici/README.md)
- 🏛️ **Core Lab 0→8:** [Indice area](./docs/03_infra_lab/02_oracle_installation_asm/README.md) · [Vagrant Lab](./vagrant_rac_dataguard/README.md)
- 🔵 **High Availability:** [Indice area](./docs/02_core_dba/04_high_availability_and_rac/README.md)
- 🟡 **Backup & Recovery:** [Indice area](./docs/02_core_dba/02_backup_and_recovery/README.md)
- 🟠 **Amministrazione:** [Indice area](./docs/02_core_dba/01_administration_and_security/README.md)
- 🔴 **Performance & Diagnostica:** [Indice area](./docs/02_core_dba/03_performance_and_diagnostics/README.md)
- 🟣 **Patching & Upgrade:** [Indice area](./docs/02_core_dba/05_patching_and_upgrades/README.md) · [Upgrade 19c → 26ai](./docs/02_core_dba/05_patching_and_upgrades/GUIDA_UPGRADE_19C_TO_26AI.md)
- 🔄 **Replica & Migrazione:** [Indice area](./docs/02_core_dba/07_replication_goldengate/README.md)
- 📊 **Monitoring:** [Indice area](./docs/02_core_dba/06_monitoring_systems/README.md)
- ☁️ **Cloud OCI & Terraform:** [Indice area](./docs/03_infra_lab/03_cloud_oci/README.md) · [Codice Terraform](./terraform/oci_base_infrastructure/README.md)
- 🐳 **Containerizzazione 26ai:** [Guida Podman/Docker](./docs/03_infra_lab/04_containerization/GUIDA_ORACLE_26AI_PODMAN_DOCKER.md)
- 🎓 **Esami & Carriera:** [Indice area](./docs/04_governance_learning/03_esami_e_carriera/README.md)
- 🛠️ **Strumenti operativi:** [Command Center](./docs/01_operations/01_cheat_sheets/CS_ORACLE_TOOLS_COMMAND_CENTER.md) · [Runbook](./docs/01_operations/02_runbooks_incidenti/README.md) · [Script SQL](./docs/01_operations/03_scripts_pronti/README.md) · [Libreria script](./docs/01_operations/04_libreria_script_completa/README.md)
- 🤖 **Automazione/IaC:** [Ansible](./automation/README.md)
- 🧭 **Indice totale unico:** [docs/README.md](./docs/README.md)

---

## 🗺️ Mappa del Repository (Ecosistema Enterprise)

```mermaid
mindmap
  root((Oracle DBA Lab))
    Operations
      Cheat Sheets
        Adrci
        Asmcmd
        Dgmgrl
        Goldengate
        Lsnrctl Net
        Master Dba
        Opatch Datapatch
        Oracle Tools Command Center
        Rman Rapido
        Sqlplus Sqlcl Dbca Netca
        Sql Assessment
        Srvctl Crsctl
      Runbooks Incidenti
        Triage Incidenti Oracle
        Morning Health Check
        Verifica Backup
        Check Dataguard
        Lock Sessioni Bloccate
        Query Lenta
        Tablespace Pieno
        Cpu Alta
        Ora Errors
        Gestione Utenti
        Start Stop Rac
        Review Awr
        Capacity Planning Limiti
        Refresh Schema Test
        Chaos Network Partition Dataguard
        Checkmk Agent Tls Smart Raid Tro...
        Resize Temp
        Purge Log Oracle
        Gestione Statistiche Optimizer
        Diagnosi Backup Rman Falliti E R...
        Export Import Prod Preprod
        Gestione Db Link
        Rman Dataguard Casi Recovery Dr
        Sql Tuning Casi Enterprise
        Gap Analysis Copertura Dba
        Asm Storage Incidenti Enterprise
        Listener Scan Services Rac
        Tde Wallet Keystore Runbook
        Scheduler Jobs Autotasks Runbook
        Patching Oracle Rac Dataguard
        Multitenant Pdb Operations
        Goldengate Incident Runbook
        Enterprise Manager Alert Runbook
        Audit Compliance Evidence
        Tcps Wallet Certificati
        Capacity Forecast Enterprise
        Migrazione Maa Best Practices
    Core Dba
      Administration And Security
        Checklist Security Baseline
        Acl Network Oracle
        Aggiunta Dischi Asm
        Ansible Templates
        Cdb Pdb Utenti
        Database Vault Enterprise
        Data Masking Redaction
        Identita Oracle E Servizi
        Listener Services Dba
        Package Monitor Ddl
        Password Rollout Enterprise
        Scheduler Jobs
        Security Hardening
        Servizi Applicativi Rac
        Setup Ldap Enterprise
        Storage Lun Lvm Udev Asm Asmlib Afd
        Tde In Profondita
        Unified Auditing Migrazione
      Backup And Recovery
        Data Pump
        Rman Backup
        Migrazione Xtts Rman
        Rman Comandi Enterprise
        Rman Completa 19c
        Tuning Data Pump Enterprise
      Performance And Diagnostics
        Adrci Diagnostica Oracle
        Adrci Trace Enterprise
        Awr Ash Addm
        Sql Plan Management Baselines
        Sql Tuning Set Advisors
        Troubleshooting Completo
        Top 100 Script Dba
      High Availability And Rac
        Application Continuity Taf
        Failover E Reinstate
        Far Sync Dataguard
        Rac Standby
        Dataguard Dgmgrl
        Flashback Database
        Maa Best Practices
        Pdb Dataguard Services
        Produzione Rac Dataguard Non Cdb
        Produzione Single Node Dataguard...
        Switchover Completo
      Patching And Upgrades
        Autoupgrade 12c To 19c
        Autoupgrade 19c To 26
        Patching Rac
        Upgrade 19c To 26ai
        Upgrade Ru Rac
      Monitoring Systems
        Enterprise Manager
        Monitoring Opensource
        Setup Checkmk Oracle Enterprise
      Replication Goldengate
        Cheat Sheet Goldengate 19c
        Goldengate
        Goldengate 19c Completa
        Goldengate 26ai Novita
        Goldengate Ambienti Critici Bancari
        Goldengate Classic Architecture 19c
        Goldengate Collegamento Source T...
        Goldengate Grants Privilegi 19c
        Goldengate Microservices Archite...
        Goldengate Oracle To Postgresql
        Goldengate Prerequisiti Db Archi...
        Goldengate Qa Professionale
        Goldengate Runbook End To End 19c
        Goldengate Upgrade 19c To 26ai
        Goldengate Use Cases Knowledge Hub
        Migrazione Goldengate
        Migrazione Oracle Postgres
        Testlog Goldengate Template
        Use Cases
          Uc01 No Downtime Migrations
          Uc02 High Availability
          Uc03 Analytical Data Ingest
          Uc04 Ai Ready Data
          Uc05 Multicloud Data Integration
          Uc06 Application Data Streams
          Uc07 Stream Processing Analytics
    Infra Lab
      Proxmox Hardware
        Track Proxmox Production End To End
      Oracle Installation Asm
        Setup Macchine
        Preparazione Os
        Grid E Rac
        Test Verifica
        Percorso Lite Single Node
        Ssh Keys Rac
        Obiettivi E Checklist Fasi 0 8
      Cloud Oci
        Cloud Goldengate
        Rete Lab Oci Goldengate
      Containerization
        Oracle 26ai Podman Docker
    Governance Learning
      Fondamenti Teorici
        Analisi Oraclebase Vagrant
        Diario Di Bordo
        Glossario Oracle
        Architettura Oracle
        Ciclo Di Vita Transazione
        Comandi Dba
        Locking Concurrency Wait Events
        Memoria Oracle Sga Pga
        Redo Undo Crash Recovery
        Learning Path Junior Mid Senior
        Piano Laboratorio
        Quiz Hands On Junior Mid Senior
        Template Guida Standard
      Enterprise Standards
        Community Onboarding Path
        Community Roadmap
        Compatibility By Area 19c 21c 23...
        Compatibility Matrix
        Compatibility Policy
        Didactic Compliance Checklist
        Didactic Excellence Standard
        Go No Go Master Merge Policy
        Maa Scorecard
        Production Profile
        Public Kpi Scoreboard
        Quickstart 10 Minuti
        Release Engineering Policy
        Reliability Framework
        Troubleshooting Decision Tree
        Vulnerability Disclosure Policy
      Esami E Carriera
        Attivita Lab Rac
        Catalogo Attivita Dba
        Checklist Attivita Dba
        Da Lab A Produzione
        Esame Review
        Ripasso Concetti Dba
        Validazione Best Practices
```

---

## 🏆 Le 10 Guide Monumentali (Livello Senior/Architect)
Abbiamo elevato le documentazioni chiave a veri e propri **Masterpiece Architetturali**. Queste guide contengono spiegazioni approfondite, diagrammi di flusso visivi, scenari di triage, comandi completi e best practices aziendali:

1. 🛡️ **[Database Vault Enterprise](./docs/02_core_dba/01_administration_and_security/GUIDA_DATABASE_VAULT_ENTERPRISE.md)**: Separation of Duties, Realms, e Command Rules.
2. 🛡️ **[Unified Auditing & Compliance](./docs/02_core_dba/01_administration_and_security/GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md)**: Pure Mode, AUDSYS purge, e offload su SIEM Syslog.
3. 🛡️ **[Data Masking & Redaction](./docs/02_core_dba/01_administration_and_security/GUIDA_DATA_MASKING_REDACTION.md)**: Dynamic redaction in-transit vs Static masking per UAT/DEV.
4. ⚡ **[SQL Plan Management (SPM)](./docs/02_core_dba/03_performance_and_diagnostics/GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md)**: Prevenzione regressioni query, Baseline evolution e Adaptive Cursor Sharing.
5. ⚡ **[AWR, ASH & ADDM](./docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md)**: Analisi profonda Wait Events, estrazione HTML batch e diagnostica AI.
6. 💾 **[Migrazione Cross-Platform XTTS](./docs/02_core_dba/02_backup_and_recovery/GUIDA_MIGRAZIONE_XTTS_RMAN.md)**: Zero-downtime da AIX a Linux tramite Cross-Platform Transportable Tablespaces.
7. 💾 **[Tuning Data Pump Enterprise](./docs/02_core_dba/02_backup_and_recovery/GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md)**: Parallelismo estremo e ottimizzazione per database multiterabyte.
8. 🔄 **[Application Continuity & TAF](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_APPLICATION_CONTINUITY_TAF.md)**: Failover client trasparente, FAN e configuration jdbc.
9. 🔄 **[Far Sync Data Guard](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_FAR_SYNC_DATAGUARD.md)**: Zero Data Loss geografico a lunghissima distanza senza penalità.
10. 🎯 **[Troubleshooting Completo](./docs/02_core_dba/03_performance_and_diagnostics/GUIDA_TROUBLESHOOTING_COMPLETO.md)**: La guida definitiva alla caccia al problema in ambienti Enterprise.

---

## Ordine Consigliato di Lettura / Esecuzione

Non leggere il repository in ordine alfabetico. Usa questo ordine, altrimenti rischi di entrare in GoldenGate, RMAN o troubleshooting senza avere prima rete, RAC, Data Guard e servizi stabili.

| Ordine | Modulo | Quando leggerlo/eseguirlo | Output atteso |
|---|---|---|---|
| 0 | [Fondamenti Oracle](./docs/04_governance_learning/01_fondamenti_teorici/README.md) | Prima di creare le VM | Capisci architettura Oracle, redo/undo, memoria, lock, wait event |
| 1 | [Lab Core Fase 0 -> 4](./docs/03_infra_lab/02_oracle_installation_asm/README.md) | Primo blocco pratico obbligatorio | VM, DNS, OS, Grid, RAC, standby, Data Guard Broker |
| 2 | [Backup & Monitoring Fase 5 -> 6](./docs/02_core_dba/02_backup_and_recovery/README.md) | Dopo Data Guard stabile | RMAN, restore, BCT, Enterprise Manager/monitoring |
| 3 | [GoldenGate prerequisiti e collegamento](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md) | Prima della Fase 7 | Logging, GGADMIN, FRA, TNS, credential store, source/target connectivity |
| 4 | [GoldenGate 19c operativo](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_19C_COMPLETA.md) | Prima o durante Fase 7 | Concetti Extract, trail, Replicat, checkpoint, lag, troubleshooting |
| 5 | [Fase 7 GoldenGate Microservices](./docs/02_core_dba/07_replication_goldengate/GUIDA_FASE7_GOLDENGATE.md) | Dopo prerequisiti GoldenGate | Replica lab source -> target con Microservices Architecture |
| 6 | [GoldenGate Classic + migrazioni](./docs/02_core_dba/07_replication_goldengate/README.md) | Dopo il lab Microservices | GGSCI, Classic, Oracle->Oracle, Oracle->PostgreSQL, cutover, scenari enterprise |
| 7 | [Patching, upgrade e 26ai](./docs/02_core_dba/05_patching_and_upgrades/README.md) | Solo dopo 19c stabile | Upgrade DB, upgrade GoldenGate 19c->26ai, rollback, compatibilita |
| 8 | [Runbook, script e automazione](./docs/01_operations/02_runbooks_incidenti/README.md) | Day-2 operations | Health check, incident response, script SQL, Ansible |

Regole pratiche:

- Se stai costruendo il lab: esegui **Fase 0 -> 8** in sequenza.
- Se stai studiando GoldenGate: segui l'ordine della sezione **Replica & Migrazione**, non partire direttamente dalla Fase 7.
- Non fare upgrade 19c -> 26ai prima di conoscere bene GoldenGate 19c Microservices e Classic.

---

## 📚 Guide per Area Tematica

### 🟢 Fondamenti — leggi prima del lab

| Guida | Cosa Impari |
|---|---|
| [Architettura Oracle](./docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md) | SGA, PGA, Redo Log, Undo, ASM, Cache Fusion |
| [**Ciclo di Vita di una Transazione**](./docs/04_governance_learning/01_fondamenti_teorici/GUIDA_CICLO_DI_VITA_TRANSAZIONE.md) | Anatomia di un UPDATE: Parsing, Cache, ITL, Redo, DBWR, LGWR |
| [Memory Architecture (SGA/PGA)](./docs/04_governance_learning/01_fondamenti_teorici/GUIDA_MEMORIA_ORACLE_SGA_PGA.md) | Deep Dive: Buffer Cache, Shared Pool, AMM vs ASMM, HugePages |
| [Redo/Undo & Crash Recovery](./docs/04_governance_learning/01_fondamenti_teorici/GUIDA_REDO_UNDO_CRASH_RECOVERY.md) | Deep Dive: Write-Ahead Logging, Checkpoint, Roll Forward/Back |
| [Locking, Concurrency & Wait Events](./docs/04_governance_learning/01_fondamenti_teorici/GUIDA_LOCKING_CONCURRENCY_WAIT_EVENTS.md) | Deep Dive: MVCC, ITL, Deadlocks, e Top 15 Wait Events |
| [Comandi DBA](./docs/04_governance_learning/01_fondamenti_teorici/GUIDA_COMANDI_DBA.md) | 100+ query SQL essenziali per il DBA |
| [**Analisi Base Vagrant**](./docs/04_governance_learning/01_fondamenti_teorici/ANALISI_ORACLEBASE_VAGRANT.md) | Studio approfondito della configurazione automatizzata |
| [Glossario](./docs/04_governance_learning/01_fondamenti_teorici/GLOSSARIO_ORACLE.md) | 100+ acronimi e termini Oracle spiegati |
| [Piano Laboratorio](./docs/04_governance_learning/01_fondamenti_teorici/PIANO_LABORATORIO.md) | 8 settimane × 3h/giorno, roadmap completa |
| [Diario di Bordo](./docs/04_governance_learning/01_fondamenti_teorici/DIARIO_DI_BORDO.md) | Note e avanzamento lavori del lab |

---

## 🏗️ Architettura del Lab

```mermaid
flowchart TD
    subgraph "Host (Il Tuo PC)"
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

## 📖 Esegui il Lab (Fase 0 → 8)

Segui le fasi **in ordine**. Ogni fase dipende dalla precedente.

> 📍 **[Indice centralizzato del percorso](./docs/04_governance_learning/03_esami_e_carriera/README.md)** — tabella completa, prerequisiti, roadmap e link a tutte le guide.

| # | Fase | Guida | Cosa Fai | Tempo |
|---|---|---|---|---|
| 0 | **Setup Macchine** | [GUIDA_FASE0](./docs/03_infra_lab/02_oracle_installation_asm/GUIDA_FASE0_SETUP_MACCHINE.md) | Crea VM VirtualBox, DNS, dischi ASM | 3-4h |
| 1 | **Preparazione OS** | [GUIDA_FASE1](./docs/03_infra_lab/02_oracle_installation_asm/GUIDA_FASE1_PREPARAZIONE_OS.md) | Rete, DNS, utenti, SSH, kernel | 2-3h |
| 2 | **Grid + RAC** | [GUIDA_FASE2](./docs/03_infra_lab/02_oracle_installation_asm/GUIDA_FASE2_GRID_E_RAC.md) | Grid Infrastructure, ASM, Database | 4-5h |
| 3 | **RAC Standby** | [GUIDA_FASE3](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_FASE3_RAC_STANDBY.md) | RMAN Duplicate, Listener statico, MRP | 3-4h |
| 4 | **Data Guard** | [GUIDA_FASE4](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md) | DGMGRL Broker, Protection Mode, FASTSYNC | 2-3h |
| 5 | **RMAN Backup** | [GUIDA_FASE5](./docs/02_core_dba/02_backup_and_recovery/GUIDA_FASE5_RMAN_BACKUP.md) | Strategia backup, cron, BCT, restore | 2h |
| 6 | **Enterprise Manager** | [GUIDA_FASE6](./docs/02_core_dba/06_monitoring_systems/GUIDA_FASE6_ENTERPRISE_MANAGER.md) | OEM Cloud Control 24ai + Agent | 4-5h |
| 7 | **GoldenGate** | [GUIDA_FASE7](./docs/02_core_dba/07_replication_goldengate/GUIDA_FASE7_GOLDENGATE.md) | Extract, Pump, Replicat (Oracle + PG) | 3-4h |
| 8 | **Test Verifica** | [GUIDA_FASE8](./docs/03_infra_lab/02_oracle_installation_asm/GUIDA_FASE8_TEST_VERIFICA.md) | Test end-to-end, stress, node crash | 2-3h |

> **Tempo totale stimato**: ~30 ore di lavoro pratico.

---

### 🔵 High Availability — Data Guard, Switchover, Failover

| Guida | Cosa Impari |
|---|---|
| [Switchover Completo](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_SWITCHOVER_COMPLETO.md) | Switchover + Switchback passo-passo |
| [Failover + Reinstate](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_FAILOVER_E_REINSTATE.md) | ⚠️ **NON obbligatorio nel lab** — vedi nota sotto |
| [Flashback Database](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_FLASHBACK_DATABASE.md) | "Macchina del tempo" Oracle |
| [MAA Best Practices](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_MAA_BEST_PRACTICES.md) | Oracle Maximum Availability Architecture |
| [Data Guard Far Sync](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_FAR_SYNC_DATAGUARD.md) | **Nuovo**: Zero Data Loss a distanza geografica con istanza Far Sync |
| [Application Continuity & TAF](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_APPLICATION_CONTINUITY_TAF.md) | **Nuovo**: Configurazione failover client trasparente lato DB e pool JDBC/UCP |

> ⚠️ **FAILOVER**: Operazione distruttiva. **Prima** di tentarla:
> 1. Spegni TUTTE le VM
> 2. **Copia/zippa l'intera cartella VirtualBox VMs** come backup
> 3. Poi prosegui — se si rompe tutto, ripristini dalla copia

---

### 🟡 Backup & Recovery

| Guida | Cosa Impari |
|---|---|
| [RMAN Completa 19c](./docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md) | Backup, restore, recovery, catalog, test pratici |
| [RMAN Comandi Enterprise](./docs/02_core_dba/02_backup_and_recovery/README.md) | Comandi RMAN, runbook e troubleshooting avanzato |
| [Data Pump](./docs/02_core_dba/02_backup_and_recovery/GUIDA_DATA_PUMP.md) | Export/Import con expdp/impdp |
| [Cross-Platform XTTS](./docs/02_core_dba/02_backup_and_recovery/GUIDA_MIGRAZIONE_XTTS_RMAN.md) | **Nuovo**: Migrazione cross-endian AIX/Solaris -> Linux con downtime minimo |
| [Tuning Data Pump Enterprise](./docs/02_core_dba/02_backup_and_recovery/GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md) | **Nuovo**: Ottimizzazione Data Pump per database di grandi dimensioni (>10 TB) |

---

### 🟠 Amministrazione

| Guida | Cosa Impari |
|---|---|
| [CDB/PDB/Utenti](./docs/02_core_dba/01_administration_and_security/GUIDA_CDB_PDB_UTENTI.md) | Multitenant, PDB create/clone/plug, ruoli |
| [Listener e Services](./docs/02_core_dba/01_administration_and_security/GUIDA_LISTENER_SERVICES_DBA.md) | Listener, TNS, services in dettaglio |
| [Servizi Applicativi RAC](./docs/02_core_dba/01_administration_and_security/GUIDA_SERVIZI_APPLICATIVI_RAC.md) | TAF, FAN, CLB/RLB, Application Continuity |
| [Ansible Response Templates](./docs/02_core_dba/01_administration_and_security/GUIDA_ANSIBLE_TEMPLATES.md) | **Nuovo**: Come fare *silent install* al 100% con Jinja2 |
| [Gestione Dischi ASM](./docs/02_core_dba/01_administration_and_security/GUIDA_AGGIUNTA_DISCHI_ASM.md) | Add/remove dischi ASM (ASMLib + AFD) |
| [Storage LUN/LVM/udev/ASM](./docs/02_core_dba/01_administration_and_security/GUIDA_STORAGE_LUN_LVM_UDEV_ASM_ASMLIB_AFD.md) | LUN, PV/VG/LV, multipath, udev, ASMLib, AFD deprecato, scelte storage |
| [Oracle Scheduler](./docs/02_core_dba/01_administration_and_security/GUIDA_SCHEDULER_JOBS.md) | Job, chain, auto-tasks, monitoring |
| [Security Hardening](./docs/02_core_dba/01_administration_and_security/GUIDA_SECURITY_HARDENING.md) | TDE, Auditing, Encryption, Password Profiles |
| [TDE in Profondità](./docs/02_core_dba/01_administration_and_security/GUIDA_TDE_IN_PROFONDITA.md) | Keystore, master key, colonna/tablespace encryption, backup e operatività RAC/DG |
| [**Identità Oracle e Servizi**](./docs/02_core_dba/01_administration_and_security/GUIDA_IDENTITA_ORACLE_E_SERVIZI.md) | **MEGA-GUIDA**: DB_NAME vs SID vs SERVICE_NAME, Listener, Role-Based Services, Switchover |
| [LDAP / EUS / CMU](./docs/02_core_dba/01_administration_and_security/GUIDA_SETUP_LDAP_ENTERPRISE.md) | Integrazione Active Directory, EUSM, Wallet Orapki, Kerberos SSO, Proxy Auth |
| [Password Rollout](./docs/02_core_dba/01_administration_and_security/GUIDA_PASSWORD_ROLLOUT_ENTERPRISE.md) | Rotazione Password Zero-Downtime, Integrazione PAM, Verify Functions |
| [Oracle Database Vault](./docs/02_core_dba/01_administration_and_security/GUIDA_DATABASE_VAULT_ENTERPRISE.md) | **Nuovo**: Setup Database Vault, realms, realms authorization, separation of duties |
| [Unified Auditing & Compliance](./docs/02_core_dba/01_administration_and_security/GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md) | **Nuovo**: Migrazione da traditional audit, custom policy, storage SYSAUX e purge automatico |
| [Data Masking & Redaction](./docs/02_core_dba/01_administration_and_security/GUIDA_DATA_MASKING_REDACTION.md) | **Nuovo**: Mascheramento dinamico con DBMS_REDACT e statico con Data Pump |

---

### 🔴 Performance & Diagnostica

| Guida | Cosa Impari |
|---|---|
| [Troubleshooting Completo](./docs/02_core_dba/03_performance_and_diagnostics/GUIDA_TROUBLESHOOTING_COMPLETO.md) | **MEGA-GUIDA**: metodo da zero, wait events, scenari reali |
| [AWR/ASH/ADDM](./docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md) | SQL Monitor, SPM, SQL Quarantine |
| [Top 100 Script DBA](./docs/02_core_dba/03_performance_and_diagnostics/TOP_100_SCRIPT_DBA.md) | I 100 script più utili ogni giorno |
| [ADRCI & Trace Enterprise](./docs/02_core_dba/03_performance_and_diagnostics/README.md) | ADR, alert log, trace file, incident package |
| [SQL Plan Management (SPM)](./docs/02_core_dba/03_performance_and_diagnostics/GUIDA_SQL_PLAN_MANAGEMENT_BASELINES.md) | **Nuovo**: Prevenzione delle regressioni delle query, baselines, evoluzione dei piani |
| [SQL Tuning Set & Advisors](./docs/02_core_dba/03_performance_and_diagnostics/GUIDA_SQL_TUNING_SET_ADVISORS.md) | **Nuovo**: DBMS_SQLTUNE, creazione STS, SQL Tuning Advisor, SQL Access Advisor |

---

### 🟣 Patching & Upgrade

| Guida | Cosa Impari |
|---|---|
| [Patching RAC](./docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md) | Combo Patch, OJVM, cleanup |
| [Upgrade RU RAC](./docs/02_core_dba/05_patching_and_upgrades/GUIDA_UPGRADE_RU_RAC.md) | Rolling upgrade, skip version, rollback |
| [AutoUpgrade 12c → 19c](./docs/02_core_dba/05_patching_and_upgrades/GUIDA_AUTOUPGRADE_12C_TO_19C.md) | AutoUpgrade completo con config.cfg |
| [AutoUpgrade 19c → 26c](./docs/02_core_dba/05_patching_and_upgrades/GUIDA_AUTOUPGRADE_19C_TO_26.md) | Nuova Long-Term Release |

---

### 🔄 Replica & Migrazione

> Ordine consigliato: prima prerequisiti, grant e collegamento, poi GoldenGate 19c, poi esecuzione Microservices, poi Classic/migrazioni, infine 26ai.

| Ordine | Guida | Cosa Impari |
|---|---|---|
| 1 | [Prerequisiti DB GoldenGate](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md) | Logging, supplemental logging, GGADMIN, FRA, trail retention |
| 2 | [Grant e Privilegi GoldenGate 19c](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md) | `DBMS_GOLDENGATE_AUTH`, CDB/PDB, target DML, PostgreSQL, no `GRANT DBA` |
| 3 | [Collegamento Source e Target](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md) | TNS, credential store, Distribution/Receiver, Classic Pump, PostgreSQL/ODBC, firewall |
| 4 | [GoldenGate in ambienti critici/bancari](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md) | Rete segregata, firewall, TLS/WSS/mTLS, target-initiated path, audit, governance |
| 5 | [GoldenGate 19c Completa](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_19C_COMPLETA.md) | Manuale enterprise: architettura, security, RAC/DG, troubleshooting |
| 6 | [Runbook End-to-End GoldenGate 19c](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_RUNBOOK_END_TO_END_19C.md) | Procedura da zero: assessment, grant, Extract, trail, Replicat, heartbeat, cutover |
| 7 | [Microservices Architecture 19c](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_MICROSERVICES_ARCHITECTURE_19C.md) | Service Manager, Admin Server, Distribution/Receiver, REST, Admin Client |
| 8 | [Fase 7 GoldenGate](./docs/02_core_dba/07_replication_goldengate/GUIDA_FASE7_GOLDENGATE.md) | Esecuzione pratica del lab Microservices |
| 9 | [Classic Architecture 19c](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_CLASSIC_ARCHITECTURE_19C.md) | GGSCI, Manager, Extract, Pump, Collector, Replicat |
| 10 | [Migrazione GoldenGate Oracle -> Oracle](./docs/02_core_dba/07_replication_goldengate/GUIDA_MIGRAZIONE_GOLDENGATE.md) | Zero-downtime migration Oracle -> Oracle |
| 11 | [Oracle -> PostgreSQL](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_ORACLE_TO_POSTGRESQL.md) | Replica eterogenea, datatype mapping, initial load e cutover |
| 12 | [Cheat Sheet GoldenGate 19c](./docs/02_core_dba/07_replication_goldengate/CHEAT_SHEET_GOLDENGATE_19C.md) | Comandi GGSCI, Admin Client, SQL e troubleshooting |
| 13 | [Q&A Tecnico GoldenGate](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_QA_PROFESSIONALE.md) | Domande/risposte professionali su GoldenGate |
| 14 | [Use Case e Knowledge Hub](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_USE_CASES_KNOWLEDGE_HUB.md) | Topologie, top 7 use case con link alle guide operative dedicate |
| 15 | [Novita GoldenGate 26ai](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_26AI_NOVITA.md) | Evoluzione 26ai, AI service, nuove compatibilita, Microservices-first |
| 16 | [Upgrade GoldenGate 19c -> 26ai](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_UPGRADE_19C_TO_26AI.md) | Upgrade MA, percorso Classic, backup, rollback e validazioni |

---

### 📊 Monitoring

| Guida | Cosa Impari |
|---|---|
| [Monitoring Enterprise](./docs/02_core_dba/06_monitoring_systems/GUIDA_SETUP_CHECKMK_ORACLE_ENTERPRISE.md) | Guida completa all'installazione, UI, Agent, regole Oracle, BI, Distributed Monitoring e Grafana. |
| [Monitoring Opensource](./docs/02_core_dba/06_monitoring_systems/GUIDA_MONITORING_OPENSOURCE.md) | **Checkmk vs Zabbix vs Prometheus+Grafana** — guida installazione completa |
| [Enterprise Manager 24ai](./docs/02_core_dba/06_monitoring_systems/GUIDA_FASE6_ENTERPRISE_MANAGER.md) | OEM Cloud Control 24ai: OMS, Agent, discovery |

---

### ☁️ Cloud OCI — Opzionale

> Percorso alternativo avanzato: replicare verso Oracle Cloud (OCI ARM Free Tier).

| Guida | Cosa Impari |
|---|---|
| [GoldenGate verso OCI](./docs/03_infra_lab/03_cloud_oci/GUIDA_CLOUD_GOLDENGATE.md) | Target su OCI, Free vs Enterprise |
| [Rete Lab ↔ OCI](./docs/03_infra_lab/03_cloud_oci/GUIDA_RETE_LAB_OCI_GOLDENGATE.md) | VPN, SSH tunnel, NSG |

---

### 🎓 Esami & Carriera

| Guida | Cosa Impari |
|---|---|
| [Ripasso Concetti DBA](./docs/04_governance_learning/03_esami_e_carriera/GUIDA_RIPASSO_CONCETTI_DBA.md) | 12 sezioni Q&A su architettura, RAC, DG, performance, scenari |
| [Preparazione Esami](./docs/04_governance_learning/03_esami_e_carriera/GUIDA_ESAME_REVIEW.md) | 1Z0-082 + 1Z0-083 completo |
| [Da Lab a Produzione](./docs/04_governance_learning/03_esami_e_carriera/GUIDA_DA_LAB_A_PRODUZIONE.md) | Sizing, HugePages, security |
| [Attività DBA](./docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_DBA.md) | Batch Jobs, AWR, Patching, DataPump |
| [Preparazione Attività DBA](./docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md) | Attività reali, responsabilità operative e mindset professionale |
| [Validazione Best Practices](./docs/04_governance_learning/03_esami_e_carriera/VALIDAZIONE_BEST_PRACTICES.md) | Audit 54 punti, scorecard 98% |

---

## 🛠️ Strumenti Operativi

### Script SQL per Scenario (`docs/01_operations/03_scripts_pronti/`)

> **15 script pronti al copia-incolla, inclusi controlli RAC con GV$** — [Indice completo](./docs/01_operations/03_scripts_pronti/README.md)

| Script | Scenario | Errori Coperti |
|---|---|---|
| [01 Tablespace/Datafile](./docs/01_operations/03_scripts_pronti/01_tablespace_datafile.sql) | Bigfile vs Smallfile, maxsize, resize | ORA-01654, ORA-01653 |
| [02 UNDO/TEMP](./docs/01_operations/03_scripts_pronti/02_undo_temp.sql) | Undo pieno, temp piena, retention | ORA-01555, ORA-30036 |
| [03 FRA/Archivelog](./docs/01_operations/03_scripts_pronti/03_fra_archivelog.sql) | FRA piena → DB SUSPEND! Data Pump impact | ORA-19815, ORA-00257 |
| [04 Data Pump](./docs/01_operations/03_scripts_pronti/04_datapump_operativo.sql) | Export/Import sicuri, pre-check FRA | Prevenzione |
| [05 ASM Storage](./docs/01_operations/03_scripts_pronti/05_asm_storage.sql) | Diskgroup, AU_SIZE, limiti | Capacity planning |
| [06 Sessioni/Lock](./docs/01_operations/03_scripts_pronti/06_sessioni_lock.sql) | Chi blocca chi, kill session | "App bloccata!" |
| [07 Performance](./docs/01_operations/03_scripts_pronti/07_performance_quick.sql) | Top SQL, wait events, hit ratio | "DB lento!" |
| [08 RMAN Backup](./docs/01_operations/03_scripts_pronti/08_rman_backup_status.sql) | Ultimo backup, fallimenti | Morning check |
| [09 Data Guard](./docs/01_operations/03_scripts_pronti/09_dataguard_status.sql) | Lag, GAP, MRP, switchover ready | Morning check |
| [10 Oggetti/Schema](./docs/01_operations/03_scripts_pronti/10_oggetti_schema.sql) | Invalidi, segmenti grandi, recyclebin | Post-upgrade |
| [11 TEMP Resize](./docs/01_operations/03_scripts_pronti/11_temp_resize.sql) | TEMP/tempfile, ORA-01652 | Capacity |
| [12 Log Purge/Audit](./docs/01_operations/03_scripts_pronti/12_log_purge_audit.sql) | FRA, audit cleanup | Manutenzione |
| [13 Monitor DDL](./docs/01_operations/03_scripts_pronti/13_monitor_ddl_package.sql) | Audit DDL con package/trigger | Governance |
| [14 Optimizer Stats](./docs/01_operations/03_scripts_pronti/14_optimizer_stats.sql) | Stale stats, gather mirato | Performance |
| [15 RAC Global Health](./docs/01_operations/03_scripts_pronti/15_rac_global_health.sql) | GV$, servizi, blocker cross-instance | RAC |

---

### Runbook Operativi (`docs/01_operations/02_runbooks_incidenti/`)

> **14 runbook giornalieri** — [Indice completo](./docs/01_operations/02_runbooks_incidenti/README.md)

| # | Procedura | Frequenza |
|---|---|---|
| 01 | [Morning Health Check](./docs/01_operations/02_runbooks_incidenti/01_MORNING_HEALTH_CHECK.md) | Ogni mattina |
| 02 | [Verifica Backup](./docs/01_operations/02_runbooks_incidenti/02_VERIFICA_BACKUP.md) | Ogni mattina |
| 03 | [Check Data Guard](./docs/01_operations/02_runbooks_incidenti/03_CHECK_DATAGUARD.md) | Ogni mattina |
| 04-08 | [Lock, Query Lenta, TBS Pieno, CPU, ORA-Errors](./docs/01_operations/02_runbooks_incidenti/README.md) | Su richiesta / alert |
| 09-11 | [Gestione Utenti, Start/Stop RAC, Review AWR](./docs/01_operations/02_runbooks_incidenti/README.md) | Settimanale |
| 12-13 | [Capacity Planning, Refresh Schema Test](./docs/01_operations/02_runbooks_incidenti/README.md) | Mensile |

---

### Ansible Automation (`automation/`)

> **14 playbook production-grade** + ruoli modulari — [Indice completo](./automation/README.md)

| Playbook | Cosa Fa |
|---|---|
| [01 Oracle Install](./automation/playbooks/oracle_install.yml) | Installazione 19c silent |
| [02 Oracle Patching](./automation/playbooks/oracle_patching.yml) | Rolling patch (zero downtime) |
| [03 AutoUpgrade](./automation/playbooks/oracle_autoupgrade.yml) | 3 fasi: pre_upgrade → upgrade → finalize |
| [04 Health Check](./automation/playbooks/daily_health_check.yml) | Morning check automatizzato |
| [05 RMAN Backup](./automation/playbooks/rman_backup.yml) | Backup + crosscheck + validate |
| [06 DG Switchover](./automation/playbooks/dataguard_switchover.yml) | Switchover Data Guard automatizzato |
| [07 Users & TBS](./automation/playbooks/create_users_tablespaces.yml) | Creazione BIGFILE Tablespace e Utenti |
| [08 Gather Stats](./automation/playbooks/gather_stats.yml) | DBMS_STATS automatizzato via Ansible |
| [09 DataPump Export](./automation/playbooks/datapump_export.yml) | Export parallelo di schemi applicativi |
| [10 RAC Services](./automation/playbooks/manage_services.yml) | Start/Stop srvctl dei servizi RAC |
| [11 CDB/PDB](./automation/playbooks/create_cdb_pdb.yml) | Creazione CDB/PDB idempotente |
| [12 DBA Maintenance](./automation/playbooks/dba_maintenance.yml) | Maintenance periodica DB |
| [13 MAA Guardrails](./automation/playbooks/maa_guardrails.yml) | Validazioni MAA e compliance DG |
| [14 Checkmk Bootstrap](./automation/playbooks/checkmk_oracle_checks_setup.yml) | Bootstrap Checkmk + check Oracle/SMART |

---

### Libreria Oracle (`docs/01_operations/04_libreria_script_completa/`)

> **~1000 script** dalla community Oracle — [Indice completo](./docs/01_operations/04_libreria_script_completa/README.md)

| Area | Script | Cosa Trovi |
|---|---|---|
| [Monitoring](./docs/01_operations/04_libreria_script_completa/monitoring_scripts/) | 586 | Sessioni, lock, CPU, I/O, ASH, rete |
| [Performance](./docs/01_operations/04_libreria_script_completa/performance_tuning/) | 225 | SPM, AWR, statistiche, SQL tuning |
| [Utilities](./docs/01_operations/04_libreria_script_completa/utilities/) | 103 | Scheduler, storage, CDB/PDB, profili |
| [Altro](./docs/01_operations/04_libreria_script_completa/README.md) | 86 | ASM, DG, utenti, patching, TDE, partizioni |

---

### Risorse Extra (Archivio)

| Documento | Descrizione |
|---|---|
| [Catalogo Attività DBA](./docs/04_governance_learning/03_esami_e_carriera/GUIDA_CATALOGO_ATTIVITA_DBA.md) | Panorama completo delle attività DBA reali |
| [Checklist Operativa](./docs/04_governance_learning/03_esami_e_carriera/GUIDA_CHECKLIST_ATTIVITA_DBA.md) | Runbook giornaliero/settimanale/mensile |
| [Domande Tecniche DBA](./docs/04_governance_learning/03_esami_e_carriera/GUIDA_RIPASSO_CONCETTI_DBA.md) | Domande e risposte per esami e certificazioni |

---

## 📅 Roadmap Lab (8 settimane, 3h/giorno)

| Settimana | Focus | Output |
|---|---|---|
| 1 | OS + Grid + ASM | Grid stabile, prerequisiti chiusi |
| 2 | RAC + standby | RAC operativo + standby pronto |
| 3 | Data Guard + RMAN + GG | Broker OK, backup validato, GG base |
| 4 | GG avanzato + HA test | 24+ test GoldenGate completati |
| 5 | EM + monitoring + cloud | OMS/Agent attivi, alerting funzionante |
| 6 | Migrazione Oracle → PG | Flusso end-to-end completato |
| 7 | Esame 1Z0-082 | 2 mock exam + revisione errori |
| 8 | Esame 1Z0-083 | 2 mock exam + runbook finali |

> Piano dettagliato giorno per giorno: [PIANO_LABORATORIO.md](./docs/04_governance_learning/01_fondamenti_teorici/PIANO_LABORATORIO.md)

---

## 🌐 Piano IP

| Hostname | IP Pubblica | IP Privata | IP VIP | Ruolo |
|---|---|---|---|---|
| dnsnode | 192.168.56.50 | — | — | DNS (Dnsmasq) |
| rac1 | 192.168.56.101 | 192.168.1.101 | .56.103 | RAC Primary N.1 |
| rac2 | 192.168.56.102 | 192.168.1.102 | .56.104 | RAC Primary N.2 |
| rac-scan | .56.105-107 | — | — | SCAN Primary |
| racstby1 | 192.168.56.111 | 192.168.2.111 | .56.113 | Standby N.1 |
| racstby2 | 192.168.56.112 | 192.168.2.112 | .56.114 | Standby N.2 |
| racstby-scan | .56.115-117 | — | — | SCAN Standby |

---

## 📦 Software Necessario

| Software | Versione | Download |
|---|---|---|
| Oracle Linux | 7.9 | [Oracle Linux ISOs](https://yum.oracle.com/oracle-linux-isos.html) |
| Grid Infrastructure | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle Database | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle GoldenGate | 19c core lab / 26ai upgrade awareness | [eDelivery](https://edelivery.oracle.com) |
| Enterprise Manager | 13.5 | [eDelivery](https://edelivery.oracle.com) |
| VirtualBox | 7.x | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) |

> 💡 Scarica TUTTO prima di iniziare! Lista completa in [Fase 0](./docs/03_infra_lab/02_oracle_installation_asm/GUIDA_FASE0_SETUP_MACCHINE.md).

---

## 📎 Riferimenti e Crediti

> Documentazione ufficiale Oracle, repository di ispirazione e tool di terze parti raccolti in un unico documento.

👉 **[REFERENCES.md](./REFERENCES.md)** — Oracle Docs · GoldenGate · OCI · Community repos (oraclebase, gwenshap, oravirt…) · Monitoring · IaC

---

<p align="center">
  <sub>Built with ☕ and <code>ORA-00001</code> errors — <a href="./LICENSE">MIT License</a> — <a href="./CONTRIBUTING.md">Contributing</a></sub>
</p>
