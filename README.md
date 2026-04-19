# Oracle RAC + Data Guard — Enterprise DBA Lab

> Repository completo per costruire, gestire e automatizzare un'architettura Oracle Enterprise:
> **RAC 19c + Data Guard + GoldenGate + Enterprise Manager + AutoUpgrade**.
>
> 📋 **13 Procedure Operative** pronte per il lavoro quotidiano • 🤖 **Ansible Automation** per upgrade • 📚 **40+ guide** tecniche

---

## 📁 Struttura del Repository

```
oracle_rac_project/
│
├── docs/                          ← 📚 Tutte le guide organizzate per dominio
│   ├── 00_fondamenti/             ← Teoria, architettura, glossario
│   ├── 01_lab_setup/              ← Fasi 0-2: VM, OS, Grid, RAC
│   ├── 02_high_availability/      ← Data Guard, Switchover, Failover, MAA
│   ├── 03_backup_recovery/        ← RMAN, Data Pump
│   ├── 04_administration/         ← CDB/PDB, Listener, ASM, Security, Scheduler
│   ├── 05_performance/            ← Troubleshooting, AWR/ASH, Top 100 script
│   ├── 06_patching_upgrade/       ← Patching, RU, AutoUpgrade 12c→19c, 19c→26c
│   ├── 07_replication/            ← GoldenGate, migrazioni Oracle→PostgreSQL
│   ├── 08_monitoring/             ← Enterprise Manager 13.5
│   ├── 09_cloud_oci/              ← GoldenGate verso OCI (opzionale)
│   └── 10_esami_carriera/         ← Preparazione esami, attività DBA
│
├── automation/                    ← 🤖 Ansible playbook per AutoUpgrade
│   ├── inventory.ini
│   └── playbooks/oracle_autoupgrade.yml
│
├── procedure_operative/           ← 📋 13 Runbook giornalieri (copia-incolla)
├── extra_dba/                     ← Domande colloquio, checklist, catalogo attività
├── scripts/                       ← Shell script (storage, grid install)
├── studio_ai/                     ← 500+ script SQL (12 categorie)
└── vagrant_rac_dataguard/         ← Automazione Vagrant "One-Click" (Fasi 0→4)
```

---

## ⚡ Quick Start

### Opzione 1: Lab Manuale (impara tutto da zero)

1. Leggi la teoria → [`docs/00_fondamenti/`](#-00-fondamenti--teoria)
2. Segui le Fasi 0→8 in ordine → [`docs/01_lab_setup/`](#-01-lab-setup--fasi-0-2)
3. Abilita Data Guard → [`docs/02_high_availability/`](#-02-high-availability)

### Opzione 2: Lab Automatizzato (Vagrant One-Click)

```bash
cd vagrant_rac_dataguard/
vagrant up    # Costruisce 5 nodi: DNS + 2 RAC Primary + 2 RAC Standby
```
→ Dettagli in [vagrant_rac_dataguard/README.md](./vagrant_rac_dataguard/README.md)

> ⚠️ **RAM Richiesta**: 32 GB per il lab completo (5 nodi) • 16 GB per il lab ridotto (2 nodi RAC senza Standby)

---

## 📚 Indice Guide per Dominio

### 📖 00 Fondamenti — Teoria

| Guida | Descrizione |
|---|---|
| [Architettura Oracle](./docs/00_fondamenti/GUIDA_ARCHITETTURA_ORACLE.md) | SGA, PGA, Redo, Undo, ASM, Cache Fusion — la bibbia |
| [Comandi DBA](./docs/00_fondamenti/GUIDA_COMANDI_DBA.md) | 100+ query SQL, health check, script Oracle Base |
| [Glossario](./docs/00_fondamenti/GLOSSARIO_ORACLE.md) | 100+ acronimi e termini Oracle spiegati |
| [Piano di Studio](./docs/00_fondamenti/PIANO_STUDIO_GIORNALIERO.md) | Roadmap 8 settimane (40 giorni × 3h/giorno) |

---

### 🖥️ 01 Lab Setup — Fasi 0-2

| Guida | Descrizione |
|---|---|
| [Fase 0: Setup Macchine](./docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md) | VM VirtualBox, DNS Dnsmasq, dischi ASM |
| [Fase 1: Preparazione OS](./docs/01_lab_setup/GUIDA_FASE1_PREPARAZIONE_OS.md) | Rete, DNS, utenti, SSH, kernel |
| [Fase 2: Grid + RAC](./docs/01_lab_setup/GUIDA_FASE2_GRID_E_RAC.md) | Grid Infrastructure, ASM, DB Software, crea RACDB |
| [SSH Keys RAC](./docs/01_lab_setup/GUIDA_SSH_KEYS_RAC.md) | Equivalenza SSH per grid/oracle/root |
| [Fase 8: Test Verifica](./docs/01_lab_setup/GUIDA_FASE8_TEST_VERIFICA.md) | Test end-to-end di tutto il lab |

---

### 🛡️ 02 High Availability

| Guida | Descrizione |
|---|---|
| [Fase 3: RAC Standby](./docs/02_high_availability/GUIDA_FASE3_RAC_STANDBY.md) | RMAN Duplicate, Listener statico, MRP |
| [Fase 4: Data Guard](./docs/02_high_availability/GUIDA_FASE4_DATAGUARD_DGMGRL.md) | DGMGRL, Protection Mode, MaxPerformance/MaxAvailability |
| [Switchover](./docs/02_high_availability/GUIDA_SWITCHOVER_COMPLETO.md) | Switchover + Switchback passo-passo |
| [Failover + Reinstate](./docs/02_high_availability/GUIDA_FAILOVER_E_REINSTATE.md) | Failover emergenza, reinstate, FSFO |
| [Flashback Database](./docs/02_high_availability/GUIDA_FLASHBACK_DATABASE.md) | Macchina del tempo Oracle |
| [MAA Best Practices](./docs/02_high_availability/GUIDA_MAA_BEST_PRACTICES.md) | Oracle Maximum Availability Architecture |

---

### 💾 03 Backup & Recovery

| Guida | Descrizione |
|---|---|
| [Fase 5: RMAN Backup](./docs/03_backup_recovery/GUIDA_FASE5_RMAN_BACKUP.md) | Strategia backup, script, cron, BCT, restore |
| [RMAN Completa 19c](./docs/03_backup_recovery/GUIDA_RMAN_COMPLETA_19C.md) | Runbook completo: config, validate, recovery, catalog |
| [Data Pump](./docs/03_backup_recovery/GUIDA_DATA_PUMP.md) | Export/Import con expdp/impdp |

---

### ⚙️ 04 Administration

| Guida | Descrizione |
|---|---|
| [CDB/PDB Utenti](./docs/04_administration/GUIDA_CDB_PDB_UTENTI.md) | Multitenant: CDB, PDB, utenti, service |
| [Listener & Services](./docs/04_administration/GUIDA_LISTENER_SERVICES_DBA.md) | Listener, services, TNS in dettaglio |
| [Servizi Applicativi RAC](./docs/04_administration/GUIDA_SERVIZI_APPLICATIVI_RAC.md) | TAF, FAN, CLB/RLB, Application Continuity |
| [Aggiunta Dischi ASM](./docs/04_administration/GUIDA_AGGIUNTA_DISCHI_ASM.md) | Aggiungere dischi ASM (ASMLib + AFD) |
| [Scheduler & Jobs](./docs/04_administration/GUIDA_SCHEDULER_JOBS.md) | DBMS_SCHEDULER, chain, auto-tasks, monitoring |
| [Security Hardening](./docs/04_administration/GUIDA_SECURITY_HARDENING.md) | TDE, Auditing, Encryption, Password Profiles |

---

### 📊 05 Performance & Diagnostica

| Guida | Descrizione |
|---|---|
| [**Troubleshooting Completo**](./docs/05_performance/GUIDA_TROUBLESHOOTING_COMPLETO.md) | **MEGA-GUIDA**: metodo top-down, wait events, scenari reali |
| [AWR / ASH / ADDM](./docs/05_performance/GUIDA_AWR_ASH_ADDM.md) | SQL Monitor, SPM, SQL Quarantine (19c) |
| [Top 100 Script DBA](./docs/05_performance/TOP_100_SCRIPT_DBA.md) | I 100 script più usati ogni giorno |

---

### 🔧 06 Patching & Upgrade

| Guida | Descrizione |
|---|---|
| [Patching RAC](./docs/06_patching_upgrade/GUIDA_PATCHING_RAC.md) | Combo Patch, OJVM, pulizia |
| [Upgrade RU](./docs/06_patching_upgrade/GUIDA_UPGRADE_RU_RAC.md) | Release Update in ambiente RAC |
| [**AutoUpgrade 12c → 19c**](./docs/06_patching_upgrade/GUIDA_AUTOUPGRADE_12C_TO_19C.md) | 🆕 Guida completa con config.cfg, analyze, deploy, rollback |
| [**AutoUpgrade 19c → 26c**](./docs/06_patching_upgrade/GUIDA_AUTOUPGRADE_19C_TO_26.md) | 🆕 Upgrade alla nuova Long-Term Release |

---

### 🔄 07 Replication & Migration

| Guida | Descrizione |
|---|---|
| [Fase 7: GoldenGate](./docs/07_replication/GUIDA_FASE7_GOLDENGATE.md) | GoldenGate locale (Oracle + PostgreSQL target) |
| [Migrazione con GG](./docs/07_replication/GUIDA_MIGRAZIONE_GOLDENGATE.md) | Zero-downtime migration con GoldenGate |
| [Oracle → PostgreSQL](./docs/07_replication/GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md) | Migrazione con ora2pg, ODBC |
| [Test Log GG Template](./docs/07_replication/TESTLOG_GOLDENGATE_TEMPLATE.md) | Template per tracciare PASS/FAIL |

---

### 📈 08 Monitoring

| Guida | Descrizione |
|---|---|
| [Enterprise Manager 13.5](./docs/08_monitoring/GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md) | OMS, Agent, alerting, EMCLI, Metric Extensions |

---

### ☁️ 09 Cloud OCI (Opzionale)

> Percorso alternativo avanzato: replicare verso Oracle Cloud (OCI ARM Free Tier).

| Guida | Descrizione |
|---|---|
| [Cloud GoldenGate](./docs/09_cloud_oci/GUIDA_CLOUD_GOLDENGATE.md) | Setup completo GG verso OCI ARM |
| [GG OCI ARM Target](./docs/09_cloud_oci/GUIDA_GOLDENGATE_OCI_ARM.md) | Scelta percorso Free vs Enterprise |
| [Rete Lab ↔ OCI](./docs/09_cloud_oci/GUIDA_RETE_LAB_OCI_GOLDENGATE.md) | VPN, SSH tunnel, IP pubblico |

---

### 🎓 10 Esami & Carriera

| Guida | Descrizione |
|---|---|
| [Ripasso Esame](./docs/10_esami_carriera/GUIDA_ESAME_REVIEW.md) | 1Z0-082 + 1Z0-083 completo |
| [Da Lab a Produzione](./docs/10_esami_carriera/GUIDA_DA_LAB_A_PRODUZIONE.md) | Sizing, HugePages, security, monitoring |
| [Attività DBA](./docs/10_esami_carriera/GUIDA_ATTIVITA_DBA.md) | Attività quotidiane del DBA |
| [Attività Lab RAC](./docs/10_esami_carriera/GUIDA_ATTIVITA_LAB_RAC.md) | 10 esercizi pratici |
| [Validazione Best Practices](./docs/10_esami_carriera/VALIDAZIONE_BEST_PRACTICES.md) | Audit 54 punti, scorecard 98% |

---

## 🤖 Automazione

### Ansible — AutoUpgrade

Playbook Ansible per automatizzare l'intero processo di upgrade (analyze + deploy + post-checks).

```bash
# Dry run (solo analisi, nessuna modifica)
ansible-playbook -i automation/inventory.ini automation/playbooks/oracle_autoupgrade.yml --tags analyze

# Upgrade reale
ansible-playbook -i automation/inventory.ini automation/playbooks/oracle_autoupgrade.yml --tags deploy
```

→ Dettagli e analisi Ansible vs Jenkins in [automation/README.md](./automation/README.md)

---

## 📋 Procedure Operative (Runbook)

**13 procedure pronte al copia-incolla** per il lavoro quotidiano → [procedure_operative/README.md](./procedure_operative/README.md)

| # | Procedura | Quando |
|---|---|---|
| 01 | [Morning Health Check](./procedure_operative/01_MORNING_HEALTH_CHECK.md) | Ogni mattina |
| 02 | [Verifica Backup](./procedure_operative/02_VERIFICA_BACKUP.md) | Ogni mattina |
| 03 | [Check Data Guard](./procedure_operative/03_CHECK_DATAGUARD.md) | Ogni mattina + incidenti |
| 04 | [Lock e Sessioni Bloccate](./procedure_operative/04_LOCK_SESSIONI_BLOCCATE.md) | "App bloccata!" |
| 05 | [Query Lenta](./procedure_operative/05_QUERY_LENTA.md) | "La query è lentissima!" |
| 06 | [Tablespace Pieno](./procedure_operative/06_TABLESPACE_PIENO.md) | Alert > 85% |
| 07 | [CPU Alta](./procedure_operative/07_CPU_ALTA.md) | Alert > 90% |
| 08 | [ORA-Errors Comuni](./procedure_operative/08_ORA_ERRORS.md) | Qualsiasi ORA- |
| 09 | [Gestione Utenti](./procedure_operative/09_GESTIONE_UTENTI.md) | Creazione/modifica utente |
| 10 | [Start/Stop RAC](./procedure_operative/10_START_STOP_RAC.md) | Manutenzione pianificata |
| 11 | [Review AWR](./procedure_operative/11_REVIEW_AWR.md) | Ogni venerdì |
| 12 | [Capacity Planning](./procedure_operative/12_CAPACITY_PLANNING_LIMITI.md) | Controllo mensile |
| 13 | [Refresh Schema Test](./procedure_operative/13_REFRESH_SCHEMA_TEST.md) | Richiesta Dev |

---

## 📚 Extra DBA & Script Library

| Risorsa | Descrizione |
|---|---|
| [extra_dba/](./extra_dba/README.md) | Domande colloquio, checklist, catalogo attività DBA |
| [studio_ai/](./studio_ai/README.md) | 500+ script SQL in 12 categorie (ASM, DG, monitoring, tuning...) |

---

## 🏗️ Architettura Lab

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                        VIRTUALBOX HOST (Il tuo PC)                          ║
║                                                                              ║
║  ┌──────────┐  ┌──────────┬──────────┐  ┌──────────┬──────────┐             ║
║  │ dnsnode  │  │  rac1    │  rac2    │  │ racstby1 │ racstby2 │             ║
║  │ .56.50   │  │ .56.101  │ .56.102  │  │ .56.111  │ .56.112  │             ║
║  │ 1GB/1CPU │  │ 8GB/4CPU │ 8GB/4CPU │  │ 8GB/4CPU │ 8GB/4CPU │             ║
║  └──────────┘  └────┬─────┴────┬─────┘  └────┬─────┴─────┬────┘             ║
║                     │          │              │           │                   ║
║                ┌────┴──────────┴───┐    ┌─────┴───────────┴──┐               ║
║                │ Interconnect      │    │ Interconnect       │               ║
║                │ 192.168.1.0/24    │    │ 192.168.2.0/24     │               ║
║                └───────────────────┘    └────────────────────┘               ║
║                                                                              ║
║  RAC PRIMARY (RACDB)  ──── Data Guard (LGWR ASYNC) ────►  RAC STANDBY       ║
║  ASM: +CRS +DATA +RECO                                    (RACDB_STBY)      ║
║       │                                                                      ║
║       └──── GoldenGate ────►  Target (Oracle / PostgreSQL)                   ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## 📦 Prerequisiti Software

| Software | Versione | Download |
|---|---|---|
| Oracle Linux | 7.9+ | [Oracle Linux ISOs](https://yum.oracle.com/oracle-linux-isos.html) |
| Grid Infrastructure | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle Database | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle GoldenGate | 19c / 21c | [eDelivery](https://edelivery.oracle.com) |
| Enterprise Manager | 13.5 | [eDelivery](https://edelivery.oracle.com) |
| VirtualBox | Ultimo | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) |

---

## 🌐 Piano IP

| Hostname | IP Pubblica | IP Privata | IP VIP |
|---|---|---|---|
| dnsnode | 192.168.56.50 | — | — |
| rac1 | 192.168.56.101 | 192.168.1.101 | 192.168.56.103 |
| rac2 | 192.168.56.102 | 192.168.1.102 | 192.168.56.104 |
| rac-scan | 192.168.56.105-107 | — | — |
| racstby1 | 192.168.56.111 | 192.168.2.111 | 192.168.56.113 |
| racstby2 | 192.168.56.112 | 192.168.2.112 | 192.168.56.114 |
| racstby-scan | 192.168.56.115-117 | — | — |

---

## Crediti

- [Oracle Base — RAC 19c on VirtualBox](https://oracle-base.com/articles/19c/oracle-db-19c-rac-installation-on-oracle-linux-7-using-virtualbox)
- [Oracle MAA Best Practices](https://www.oracle.com/database/technologies/high-availability/maa.html)
- [My Oracle Support](https://support.oracle.com) — Doc ID 2118136.2
