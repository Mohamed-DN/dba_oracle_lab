# 🏛️ Oracle RAC + Data Guard — Enterprise DBA Lab

[![Oracle 19c](https://img.shields.io/badge/Oracle-19c-red?logo=oracle&logoColor=white)](https://www.oracle.com/database/)
[![Ansible](https://img.shields.io/badge/Ansible-Automation-black?logo=ansible)](./automation/)
[![Scripts](https://img.shields.io/badge/Scripts-1000%2B-blue)](./docs/13_libreria_completa_script/)
[![MAA Gold](https://img.shields.io/badge/MAA_Gold-98%25-green)](./docs/10_esami_carriera/VALIDAZIONE_BEST_PRACTICES.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

> Guida completa passo-passo per costruire un'architettura Oracle Enterprise in laboratorio.
> **Validata al 98%** contro le best practice ufficiali Oracle MAA Gold.

## 📑 Navigazione Rapida

### Inizia da qui
- [🚀 Quick Start](#-quick-start-5-minuti)
- [🧭 Percorsi supportati](#-percorsi-supportati-vagrant-storico-vs-proxmox-moderno)
- [⚠️ Prima di iniziare](#️-prima-di-iniziare)
- [📖 Lab Fasi 0→8](#-esegui-il-lab-fase-0--8)

### Percorsi e guide chiave
- [🪶 Percorso Lite](./docs/01_lab_setup/GUIDA_PERCORSO_LITE_SINGLE_NODE.md)
- [🧱 Track Proxmox 1→5](./docs/15_proxmox_track/README.md)
- [📚 Guide tematiche](#-guide-per-area-tematica)
- [🛠️ Strumenti operativi](#️-strumenti-operativi)

### Governance e risorse
- [⚡ Cosa contiene il repository](#-cosa-trovi-in-questo-repository)
- [🏛️ Governance Enterprise](./docs/14_enterprise_governance/README.md)
- [🌐 Piano IP](#-piano-ip)
- [🎯 Learning Path](./docs/00_fondamenti/LEARNING_PATH_JUNIOR_MID_SENIOR.md)
- [✅ Obiettivi Fasi](./docs/01_lab_setup/OBIETTIVI_E_CHECKLIST_FASI_0_8.md)
- [🧪 Quiz Hands-on](./docs/00_fondamenti/QUIZ_HANDS_ON_JUNIOR_MID_SENIOR.md)
- [🧱 Standard Guide](./docs/00_fondamenti/TEMPLATE_GUIDA_STANDARD.md)
- [🔐 Security Baseline](./docs/04_administration/CHECKLIST_SECURITY_BASELINE.md)
- [🧭 Indice Runbook + Top20](./docs/11_runbook_operativi/INDICE_CENTRALE_RUNBOOK_TOP20.md)

---

## 🚀 Quick Start (5 minuti)

```bash
# 1. Clona il repo
git clone https://github.com/Mohamed-DN/dba_oracle_lab.git
cd dba_oracle_lab

# 2A. Percorso manuale (consigliato per imparare)
#     docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md

# 2B. Percorso automatico Vagrant (1-click, ~33GB RAM)
cd vagrant_rac_dataguard && vagrant up

# 3. Dopo il lab, usa gli script operativi ogni giorno
#    → docs/12_scripts_sql_pronti/  (10 script SQL per emergenze)
#    → docs/11_runbook_operativi/   (14 runbook DBA)
```

> 💡 **Primo giorno?** Leggi prima [Architettura Oracle](./docs/00_fondamenti/GUIDA_ARCHITETTURA_ORACLE.md) e [Glossario](./docs/00_fondamenti/GLOSSARIO_ORACLE.md).

---

## 🧭 Percorsi supportati: Vagrant storico vs Proxmox moderno

| Percorso | Quando usarlo | Stack principale | Link |
|---|---|---|---|
| **Vagrant storico (attuale)** | Vuoi riprodurre rapidamente il lab RAC/Data Guard classico in locale | VirtualBox + Vagrant + Oracle RAC/DG | [vagrant_rac_dataguard/README.md](./vagrant_rac_dataguard/README.md) |
| **Proxmox moderno (nuovo track)** | Vuoi evolvere verso IaC + control plane + Kubernetes | Proxmox + Terraform + Ansible/AWX + K3s/RKE2 | [docs/15_proxmox_track/README.md](./docs/15_proxmox_track/README.md) |

> Il percorso Vagrant resta pienamente supportato; il track Proxmox introduce una roadmap moderna in 5 fasi.

---

## ⚡ Cosa Trovi in Questo Repository

| Sezione | Contenuto | Quantità |
|---|---|---|
| 📖 [Guide Lab (Fasi 0→8)](#-esegui-il-lab-fase-0--8) | Costruisci da zero un RAC + Data Guard + GoldenGate | 9 guide |
| 📚 [Documentazione](./docs/) | Guide tematiche per ogni area DBA | 40+ guide |
| 🛠️ [Script Operativi](./docs/12_scripts_sql_pronti/) | SQL pronti al copia-incolla per scenari reali | 10 script |
| 📂 [Libreria Oracle](./docs/13_libreria_completa_script/) | Raccolta Enterprise di script e procedure | **~1000 script** |
| 📋 [Runbook Operativi](./docs/11_runbook_operativi/) | Runbook giornalieri per attività DBA | 14 runbook |
| 🤖 [Automazione Ansible](./automation/) | Playbook production-grade + ruoli library-grade | 13 playbook |
| 🖥️ [Vagrant One-Click](./vagrant_rac_dataguard/) | Ambiente completo automatizzato (Fasi 0→4) | 1-click setup |
| 🧱 [Track Proxmox 1→5](./docs/15_proxmox_track/README.md) | Foundation Proxmox, IaC Terraform, AWX, Oracle silent, K8s | percorso guidato |
| 🌍 [Terraform Proxmox](./infrastructure/proxmox/terraform/README.md) | Provisioning 3 VM con output metadati per Ansible/AWX | baseline IaC |

---

## ⚠️ Prima di Iniziare

| Requisito | Dettaglio |
|---|---|
| **RAM minima** | **32GB** per lab full (4 nodi + DNS). **12-16GB** per percorso Lite single-node |
| **Disco** | ~150GB liberi (VM + ASM disks + software Oracle) |
| **CPU** | 4+ core consigliati (VirtualBox con VT-x/AMD-V abilitato) |
| **OS Host** | Windows, Linux, o macOS con VirtualBox 7+ |

> 💡 **Non vuoi fare tutto a mano?**
> - **Parziale**: La cartella `scripts/` ha bash script per storage e Grid.
> - **Completa**: [`vagrant_rac_dataguard/`](vagrant_rac_dataguard/README.md) automatizza le **Fasi 0→4** in un click (33GB RAM).

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

| # | Fase | Guida | Cosa Fai | Tempo |
|---|---|---|---|---|
| 0 | **Setup Macchine** | [GUIDA_FASE0](./docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md) | Crea VM VirtualBox, DNS, dischi ASM | 3-4h |
| 1 | **Preparazione OS** | [GUIDA_FASE1](./docs/01_lab_setup/GUIDA_FASE1_PREPARAZIONE_OS.md) | Rete, DNS, utenti, SSH, kernel | 2-3h |
| 2 | **Grid + RAC** | [GUIDA_FASE2](./docs/01_lab_setup/GUIDA_FASE2_GRID_E_RAC.md) | Grid Infrastructure, ASM, Database | 4-5h |
| 3 | **RAC Standby** | [GUIDA_FASE3](./docs/02_high_availability/GUIDA_FASE3_RAC_STANDBY.md) | RMAN Duplicate, Listener statico, MRP | 3-4h |
| 4 | **Data Guard** | [GUIDA_FASE4](./docs/02_high_availability/GUIDA_FASE4_DATAGUARD_DGMGRL.md) | DGMGRL Broker, Protection Mode, FASTSYNC | 2-3h |
| 5 | **RMAN Backup** | [GUIDA_FASE5](./docs/03_backup_recovery/GUIDA_FASE5_RMAN_BACKUP.md) | Strategia backup, cron, BCT, restore | 2h |
| 6 | **Enterprise Manager** | [GUIDA_FASE6](./docs/08_monitoring/GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md) | OEM Cloud Control 13.5 + Agent | 4-5h |
| 7 | **GoldenGate** | [GUIDA_FASE7](./docs/07_replication/GUIDA_FASE7_GOLDENGATE.md) | Extract, Pump, Replicat (Oracle + PG) | 3-4h |
| 8 | **Test Verifica** | [GUIDA_FASE8](./docs/01_lab_setup/GUIDA_FASE8_TEST_VERIFICA.md) | Test end-to-end, stress, node crash | 2-3h |

> **Tempo totale stimato**: ~30 ore di lavoro pratico.

---

## 📚 Guide per Area Tematica

### 🟢 Fondamenti — leggi prima del lab

| Guida | Cosa Impari |
|---|---|
| [Architettura Oracle](./docs/00_fondamenti/GUIDA_ARCHITETTURA_ORACLE.md) | SGA, PGA, Redo Log, Undo, ASM, Cache Fusion |
| [**Ciclo di Vita di una Transazione**](./docs/00_fondamenti/GUIDA_CICLO_DI_VITA_TRANSAZIONE.md) | Anatomia di un UPDATE: Parsing, Cache, ITL, Redo, DBWR, LGWR |
| [Memory Architecture (SGA/PGA)](./docs/00_fondamenti/GUIDA_MEMORIA_ORACLE_SGA_PGA.md) | Deep Dive: Buffer Cache, Shared Pool, AMM vs ASMM, HugePages |
| [Redo/Undo & Crash Recovery](./docs/00_fondamenti/GUIDA_REDO_UNDO_CRASH_RECOVERY.md) | Deep Dive: Write-Ahead Logging, Checkpoint, Roll Forward/Back |
| [Locking, Concurrency & Wait Events](./docs/00_fondamenti/GUIDA_LOCKING_CONCURRENCY_WAIT_EVENTS.md) | Deep Dive: MVCC, ITL, Deadlocks, e Top 15 Wait Events |
| [Comandi DBA](./docs/00_fondamenti/GUIDA_COMANDI_DBA.md) | 100+ query SQL essenziali per il DBA |
| [**Analisi Base Vagrant**](./docs/00_fondamenti/ANALISI_ORACLEBASE_VAGRANT.md) | Studio approfondito della configurazione automatizzata |
| [Glossario](./docs/00_fondamenti/GLOSSARIO_ORACLE.md) | 100+ acronimi e termini Oracle spiegati |
| [Piano Laboratorio](./docs/00_fondamenti/PIANO_LABORATORIO.md) | 8 settimane × 3h/giorno, roadmap completa |
| [Diario di Bordo](./docs/00_fondamenti/DIARIO_DI_BORDO.md) | Note e avanzamento lavori del lab |

---

### 🔵 High Availability — Data Guard, Switchover, Failover

| Guida | Cosa Impari |
|---|---|
| [Switchover Completo](./docs/02_high_availability/GUIDA_SWITCHOVER_COMPLETO.md) | Switchover + Switchback passo-passo |
| [Failover + Reinstate](./docs/02_high_availability/GUIDA_FAILOVER_E_REINSTATE.md) | ⚠️ **NON obbligatorio nel lab** — vedi nota sotto |
| [Flashback Database](./docs/02_high_availability/GUIDA_FLASHBACK_DATABASE.md) | "Macchina del tempo" Oracle |
| [MAA Best Practices](./docs/02_high_availability/GUIDA_MAA_BEST_PRACTICES.md) | Oracle Maximum Availability Architecture |

> ⚠️ **FAILOVER**: Operazione distruttiva. **Prima** di tentarla:
> 1. Spegni TUTTE le VM
> 2. **Copia/zippa l'intera cartella VirtualBox VMs** come backup
> 3. Poi prosegui — se si rompe tutto, ripristini dalla copia

---

### 🟡 Backup & Recovery

| Guida | Cosa Impari |
|---|---|
| [RMAN Completa 19c](./docs/03_backup_recovery/GUIDA_RMAN_COMPLETA_19C.md) | Backup, restore, recovery, catalog, test pratici |
| [Data Pump](./docs/03_backup_recovery/GUIDA_DATA_PUMP.md) | Export/Import con expdp/impdp |

---

### 🟠 Amministrazione

| Guida | Cosa Impari |
|---|---|
| [CDB/PDB/Utenti](./docs/04_administration/GUIDA_CDB_PDB_UTENTI.md) | Multitenant, PDB create/clone/plug, ruoli |
| [Listener e Services](./docs/04_administration/GUIDA_LISTENER_SERVICES_DBA.md) | Listener, TNS, services in dettaglio |
| [Servizi Applicativi RAC](./docs/04_administration/GUIDA_SERVIZI_APPLICATIVI_RAC.md) | TAF, FAN, CLB/RLB, Application Continuity |
| [Ansible Response Templates](./docs/04_administration/GUIDA_ANSIBLE_TEMPLATES.md) | **Nuovo**: Come fare *silent install* al 100% con Jinja2 |
| [Gestione Dischi ASM](./docs/04_administration/GUIDA_AGGIUNTA_DISCHI_ASM.md) | Add/remove dischi ASM (ASMLib + AFD) |
| [Oracle Scheduler](./docs/04_administration/GUIDA_SCHEDULER_JOBS.md) | Job, chain, auto-tasks, monitoring |
| [Security Hardening](./docs/04_administration/GUIDA_SECURITY_HARDENING.md) | TDE, Auditing, Encryption, Password Profiles |
| [**Identità Oracle e Servizi**](./docs/04_administration/GUIDA_IDENTITA_ORACLE_E_SERVIZI.md) | **MEGA-GUIDA**: DB_NAME vs SID vs SERVICE_NAME, Listener, Role-Based Services, Switchover |

---

### 🔴 Performance & Diagnostica

| Guida | Cosa Impari |
|---|---|
| [Troubleshooting Completo](./docs/05_performance/GUIDA_TROUBLESHOOTING_COMPLETO.md) | **MEGA-GUIDA**: metodo da zero, wait events, scenari reali |
| [AWR/ASH/ADDM](./docs/05_performance/GUIDA_AWR_ASH_ADDM.md) | SQL Monitor, SPM, SQL Quarantine |
| [Top 100 Script DBA](./docs/05_performance/TOP_100_SCRIPT_DBA.md) | I 100 script più utili ogni giorno |

---

### 🟣 Patching & Upgrade

| Guida | Cosa Impari |
|---|---|
| [Patching RAC](./docs/06_patching_upgrade/GUIDA_PATCHING_RAC.md) | Combo Patch, OJVM, cleanup |
| [Upgrade RU RAC](./docs/06_patching_upgrade/GUIDA_UPGRADE_RU_RAC.md) | Rolling upgrade, skip version, rollback |
| [AutoUpgrade 12c → 19c](./docs/06_patching_upgrade/GUIDA_AUTOUPGRADE_12C_TO_19C.md) | AutoUpgrade completo con config.cfg |
| [AutoUpgrade 19c → 26c](./docs/06_patching_upgrade/GUIDA_AUTOUPGRADE_19C_TO_26.md) | Nuova Long-Term Release |

---

### 🔄 Replica & Migrazione

| Guida | Cosa Impari |
|---|---|
| [Migrazione GoldenGate](./docs/07_replication/GUIDA_MIGRAZIONE_GOLDENGATE.md) | Zero-downtime migration |
| [Oracle → PostgreSQL](./docs/07_replication/GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md) | Migrazione con GG, ora2pg, ODBC |

---

### 📊 Monitoring

| Guida | Cosa Impari |
|---|---|
| [Monitoring Opensource](./docs/08_monitoring/GUIDA_MONITORING_OPENSOURCE.md) | **Checkmk vs Zabbix vs Prometheus+Grafana** — guida installazione completa |
| [Enterprise Manager 13c](./docs/08_monitoring/GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md) | OEM Cloud Control: OMS, Agent, discovery |

---

### ☁️ Cloud OCI — Opzionale

> Percorso alternativo avanzato: replicare verso Oracle Cloud (OCI ARM Free Tier).

| Guida | Cosa Impari |
|---|---|
| [GoldenGate verso OCI](./docs/09_cloud_oci/GUIDA_GOLDENGATE_OCI_ARM.md) | Target su OCI, Free vs Enterprise |
| [Rete Lab ↔ OCI](./docs/09_cloud_oci/GUIDA_RETE_LAB_OCI_GOLDENGATE.md) | VPN, SSH tunnel, NSG |

---

### 🎓 Esami & Carriera

| Guida | Cosa Impari |
|---|---|
| [Ripasso Concetti DBA](./docs/10_esami_carriera/GUIDA_RIPASSO_CONCETTI_DBA.md) | 12 sezioni Q&A su architettura, RAC, DG, performance, scenari |
| [Preparazione Esami](./docs/10_esami_carriera/GUIDA_ESAME_REVIEW.md) | 1Z0-082 + 1Z0-083 completo |
| [Da Lab a Produzione](./docs/10_esami_carriera/GUIDA_DA_LAB_A_PRODUZIONE.md) | Sizing, HugePages, security |
| [Attività DBA](./docs/10_esami_carriera/GUIDA_ATTIVITA_DBA.md) | Batch Jobs, AWR, Patching, DataPump |
| [Preparazione Attività DBA](./docs/10_esami_carriera/GUIDA_ATTIVITA_DBA.md) | Attività reali, responsabilità operative e mindset professionale |
| [Validazione Best Practices](./docs/10_esami_carriera/VALIDAZIONE_BEST_PRACTICES.md) | Audit 54 punti, scorecard 98% |

---

## 🛠️ Strumenti Operativi

### Script SQL per Scenario (`docs/12_scripts_sql_pronti/`)

> **10 script pronti al copia-incolla** — [Indice completo](./docs/12_scripts_sql_pronti/README.md)

| Script | Scenario | Errori Coperti |
|---|---|---|
| [01 Tablespace/Datafile](./docs/12_scripts_sql_pronti/01_tablespace_datafile.sql) | Bigfile vs Smallfile, maxsize, resize | ORA-01654, ORA-01653 |
| [02 UNDO/TEMP](./docs/12_scripts_sql_pronti/02_undo_temp.sql) | Undo pieno, temp piena, retention | ORA-01555, ORA-30036 |
| [03 FRA/Archivelog](./docs/12_scripts_sql_pronti/03_fra_archivelog.sql) | FRA piena → DB SUSPEND! Data Pump impact | ORA-19815, ORA-00257 |
| [04 Data Pump](./docs/12_scripts_sql_pronti/04_datapump_operativo.sql) | Export/Import sicuri, pre-check FRA | Prevenzione |
| [05 ASM Storage](./docs/12_scripts_sql_pronti/05_asm_storage.sql) | Diskgroup, AU_SIZE, limiti | Capacity planning |
| [06 Sessioni/Lock](./docs/12_scripts_sql_pronti/06_sessioni_lock.sql) | Chi blocca chi, kill session | "App bloccata!" |
| [07 Performance](./docs/12_scripts_sql_pronti/07_performance_quick.sql) | Top SQL, wait events, hit ratio | "DB lento!" |
| [08 RMAN Backup](./docs/12_scripts_sql_pronti/08_rman_backup_status.sql) | Ultimo backup, fallimenti | Morning check |
| [09 Data Guard](./docs/12_scripts_sql_pronti/09_dataguard_status.sql) | Lag, GAP, MRP, switchover ready | Morning check |
| [10 Oggetti/Schema](./docs/12_scripts_sql_pronti/10_oggetti_schema.sql) | Invalidi, segmenti grandi, recyclebin | Post-upgrade |

---

### Runbook Operativi (`docs/11_runbook_operativi/`)

> **14 runbook giornalieri** — [Indice completo](./docs/11_runbook_operativi/README.md)

| # | Procedura | Frequenza |
|---|---|---|
| 01 | [Morning Health Check](./docs/11_runbook_operativi/01_MORNING_HEALTH_CHECK.md) | Ogni mattina |
| 02 | [Verifica Backup](./docs/11_runbook_operativi/02_VERIFICA_BACKUP.md) | Ogni mattina |
| 03 | [Check Data Guard](./docs/11_runbook_operativi/03_CHECK_DATAGUARD.md) | Ogni mattina |
| 04-08 | Lock, Query Lenta, TBS Pieno, CPU, ORA-Errors | Su richiesta / alert |
| 09-11 | Gestione Utenti, Start/Stop RAC, Review AWR | Settimanale |
| 12-13 | Capacity Planning, Refresh Schema Test | Mensile |

---

### Ansible Automation (`automation/`)

> **13 playbook production-grade** + ruoli modulari — [Indice completo](./automation/README.md)

| Playbook | Cosa Fa |
|---|---|
| [01 Oracle Install](./automation/playbooks/01_oracle_install.yml) | Installazione 19c silent |
| [02 Oracle Patching](./automation/playbooks/02_oracle_patching.yml) | Rolling patch (zero downtime) |
| [03 AutoUpgrade](./automation/playbooks/03_oracle_autoupgrade.yml) | 3 fasi: pre_upgrade → upgrade → finalize |
| [04 Health Check](./automation/playbooks/04_daily_health_check.yml) | Morning check automatizzato |
| [05 RMAN Backup](./automation/playbooks/05_rman_backup.yml) | Backup + crosscheck + validate |
| [06 DG Switchover](./automation/playbooks/06_dataguard_switchover.yml) | Switchover Data Guard automatizzato |
| [07 Users & TBS](./automation/playbooks/07_create_users_tablespaces.yml) | Creazione BIGFILE Tablespace e Utenti |
| [08 Gather Stats](./automation/playbooks/08_gather_stats.yml) | DBMS_STATS automatizzato via Ansible |
| [09 DataPump Export](./automation/playbooks/09_datapump_export.yml) | Export parallelo di schemi applicativi |
| [10 RAC Services](./automation/playbooks/10_manage_services.yml) | Start/Stop srvctl dei servizi RAC |
| [11 CDB/PDB](./automation/playbooks/11_create_cdb_pdb.yml) | Creazione CDB/PDB idempotente |
| [12 DBA Maintenance](./automation/playbooks/12_dba_maintenance.yml) | Maintenance periodica DB |
| [13 MAA Guardrails](./automation/playbooks/13_maa_guardrails.yml) | Validazioni MAA e compliance DG |

---

### Libreria Oracle (`docs/13_libreria_completa_script/`)

> **~1000 script** dalla community Oracle — [Indice completo](./docs/13_libreria_completa_script/README.md)

| Area | Script | Cosa Trovi |
|---|---|---|
| [Monitoring](./docs/13_libreria_completa_script/03_monitoring_scripts/) | 586 | Sessioni, lock, CPU, I/O, ASH, rete |
| [Performance](./docs/13_libreria_completa_script/07_performance_tuning/) | 225 | SPM, AWR, statistiche, SQL tuning |
| [Utilities](./docs/13_libreria_completa_script/12_utilities/) | 103 | Scheduler, storage, CDB/PDB, profili |
| [Altro](./docs/13_libreria_completa_script/README.md) | 86 | ASM, DG, utenti, patching, TDE, partizioni |

---

### Risorse Extra (Archivio)

| Documento | Descrizione |
|---|---|
| [Catalogo Attività DBA](./docs/10_esami_carriera/archivio_extra/GUIDA_CATALOGO_ATTIVITA_DBA.md) | Panorama completo delle attività DBA reali |
| [Checklist Operativa](./docs/10_esami_carriera/archivio_extra/GUIDA_CHECKLIST_ATTIVITA_DBA.md) | Runbook giornaliero/settimanale/mensile |
| [Domande Tecniche DBA](./docs/10_esami_carriera/archivio_extra/GUIDA_DOMANDE_DBA_ORACLE.md) | Domande e risposte per esami e certificazioni |

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

> Piano dettagliato giorno per giorno: [PIANO_LABORATORIO.md](./docs/00_fondamenti/PIANO_LABORATORIO.md)

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
| Oracle GoldenGate | 19c / 21c | [eDelivery](https://edelivery.oracle.com) |
| Enterprise Manager | 13.5 | [eDelivery](https://edelivery.oracle.com) |
| VirtualBox | 7.x | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) |

> 💡 Scarica TUTTO prima di iniziare! Lista completa in [Fase 0](./docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md).

---

## 📎 Riferimenti

| Risorsa | Link |
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
