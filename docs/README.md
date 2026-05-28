# 🗄️ DBA Oracle Lab & Documentation Hub

> **Single Source of Truth** per le operazioni, il troubleshooting, la configurazione e gli standard architetturali del database Oracle. Ottimizzato per la rapida consultazione durante la giornata lavorativa e i ticket P1.

Questo repository contiene script, runbook e guide enterprise ad altissima densità per ambienti Oracle 19c/21c/23ai (RAC, Data Guard, ASM, OEM, CheckMK, TDE).

## Percorso Rapido

Se non sai da dove partire, apri prima la [mappa operativa START_HERE](../START_HERE.md).

---

## 🗺️ Struttura del Repository

Il repository è diviso in **4 Macro-Aree** pensate per l'operatività quotidiana del DBA:

### 🚨 1. OPERATIONS (Uso Quotidiano & Incidenti)
Le risorse di pronto intervento e uso giornaliero. Quello che ti serve "al volo" durante un ticket.

| Directory | Contenuto Principale |
|---|---|
| [`01_operations/01_cheat_sheets`](./01_operations/01_cheat_sheets/) | Cheat sheet a colpo d'occhio: RMAN, DGMGRL, GoldenGate. |
| [`01_operations/02_runbooks_incidenti`](./01_operations/02_runbooks_incidenti/) | **P1 Runbooks**: triage, backup/RMAN, Data Guard, performance, spazio, ASM, listener/services, TDE, scheduler, patching, GoldenGate, OEM, audit, TCPS e capacity forecast. |
| [`01_operations/03_scripts_pronti`](./01_operations/03_scripts_pronti/) | Script SQL isolati per estrazioni e check rapidi. |
| [`01_operations/04_libreria_script_completa`](./01_operations/04_libreria_script_completa/) | Libreria massiva di script DBA divisi per ambito (ASM, Performance, Patching, Utilities). |

### 📚 2. CORE DBA GUIDES (Guide Enterprise & Configurazione)
Le guide tecniche monumentali ("Enterprise Grade"). Procedure end-to-end, best practices e configurazioni avanzate.

| Directory | Contenuto Principale |
|---|---|
| [`02_core_dba/01_administration_and_security`](./02_core_dba/01_administration_and_security/) | Security hardening, TDE, LDAP/CMU, EUS, ACL, Auditing, Password Rollout, User Management. |
| [`02_core_dba/02_backup_and_recovery`](./02_core_dba/02_backup_and_recovery/) | Architettura RMAN, Catalog, Duplicate, Data Pump, strategie di restore. |
| [`02_core_dba/03_performance_and_diagnostics`](./02_core_dba/03_performance_and_diagnostics/) | AWR, ASH, ADDM, ADRCI, SQL Trace (10046), Hanganalyze, Optimizer. |
| [`02_core_dba/04_high_availability_and_rac`](./02_core_dba/04_high_availability_and_rac/) | Real Application Clusters (RAC), ASM, Data Guard, FSFO (Observer), Servizi. |
| [`02_core_dba/05_patching_and_upgrades`](./02_core_dba/05_patching_and_upgrades/) | OPatch, RU (Release Updates), OJVM, procedure Out-of-Place. |
| [`02_core_dba/06_monitoring_systems`](./02_core_dba/06_monitoring_systems/) | Oracle Enterprise Manager (OEM), CheckMK Agent, Alerting, Dashboard. |
| [`02_core_dba/07_replication_goldengate`](./02_core_dba/07_replication_goldengate/) | GoldenGate 19c completo: grant/privilegi least privilege, runbook end-to-end, ambienti critici, collegamento source/target, Microservices, Classic/GGSCI, Oracle->PostgreSQL, topologie, Knowledge Hub, 26ai e upgrade. |

### 🏗️ 3. INFRA LAB & SETUP (Infrastruttura di Base)
Guide per l'installazione e la creazione dell'infrastruttura di laboratorio o produzione.

| Directory | Contenuto Principale |
|---|---|
| [`03_infra_lab/01_proxmox_hardware`](./03_infra_lab/01_proxmox_hardware/) | Setup server bare-metal, Proxmox VE, storage condiviso (TrueNAS/iSCSI). |
| [`03_infra_lab/02_oracle_installation_asm`](./03_infra_lab/02_oracle_installation_asm/) | Installazione Oracle Linux, Grid Infrastructure, ASM, Database Binaries. |
| [`03_infra_lab/03_cloud_oci`](./03_infra_lab/03_cloud_oci/) | Setup lab su Oracle Cloud Infrastructure (OCI), GoldenGate on OCI. |

### 🧭 4. GOVERNANCE & LEARNING (Standard, Esami, Percorsi)
Materiale didattico, concetti teorici, roadmap professionali e standard aziendali.

| Directory | Contenuto Principale |
|---|---|
| [`04_governance_learning/01_fondamenti_teorici`](./04_governance_learning/01_fondamenti_teorici/) | Architettura Oracle (SGA/PGA, Redo/Undo, Lock, Transazioni), Glossario. |
| [`04_governance_learning/02_enterprise_standards`](./04_governance_learning/02_enterprise_standards/) | MAA Scorecard, Troubleshooting Decision Tree, Release Policy, Production Profile. |
| [`04_governance_learning/03_esami_e_carriera`](./04_governance_learning/03_esami_e_carriera/) | Checklist per attività DBA (Junior/Mid/Senior), guide per esami OCP, transizione da lab a produzione. |

---

## 🚀 Ricerca Rapida (Terminale)

Poiché il repository è progettato per i sistemisti, si consiglia l'uso di `grep` (o `ripgrep`) per trovare rapidamente codici e soluzioni:

```bash
# Cerca un comando RMAN specifico nei cheat sheet:
grep -ir "crosscheck" docs/01_operations/01_cheat_sheets/

# Cerca la soluzione a un errore ORA- nei runbooks:
grep -ir "ORA-01555" docs/01_operations/02_runbooks_incidenti/

# Cerca script per i tablespace:
grep -irl "dba_tablespaces" docs/01_operations/04_libreria_script_completa/
```

> **Nota:** Questo repository è mantenuto come *Living Document*. Ogni incidente risolto in produzione dovrebbe generare un aggiornamento nella sezione `runbooks_incidenti` o un nuovo script in `libreria_script_completa`.

---
*Ultimo aggiornamento della struttura: Maggio 2026*
