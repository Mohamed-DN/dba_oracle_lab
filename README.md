# 🏛️ Oracle RAC + Data Guard — Enterprise DBA Lab

[![Oracle 19c](https://img.shields.io/badge/Oracle-19c-red?logo=oracle&logoColor=white)](https://www.oracle.com/database/)
[![Ansible](https://img.shields.io/badge/Ansible-Automation-black?logo=ansible)](./automation/)
[![Scripts](https://img.shields.io/badge/Scripts-1000%2B-blue)](./docs/13_libreria_completa_script/)
[![MAA Gold](https://img.shields.io/badge/MAA_Gold-98%25-green)](./docs/10_esami_carriera/VALIDAZIONE_BEST_PRACTICES.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

> Guida pratica e operativa per costruire e gestire un laboratorio Oracle RAC + Data Guard.
> **Core del repository: Lab Fase 0→8.** Tutto il resto è estensione operativa/avanzata.

## 📑 Navigazione Rapida (livello 1)

- 🟢 **Fondamenti:** [Indice area](./docs/00_fondamenti/README.md)
- 🏛️ **Core Lab 0→8:** [Indice area](./docs/01_lab_setup/README.md) · [Vagrant Lab](./vagrant_rac_dataguard/README.md)
- 🔵 **High Availability:** [Indice area](./docs/02_high_availability/README.md)
- 🟡 **Backup & Recovery:** [Indice area](./docs/03_backup_recovery/README.md)
- 🟠 **Amministrazione:** [Indice area](./docs/04_administration/README.md)
- 🔴 **Performance & Diagnostica:** [Indice area](./docs/05_performance/README.md)
- 🟣 **Patching & Upgrade:** [Indice area](./docs/06_patching_upgrade/README.md)
- 🔄 **Replica & Migrazione:** [Indice area](./docs/07_replication/README.md)
- 📊 **Monitoring:** [Indice area](./docs/08_monitoring/README.md)
- ☁️ **Cloud OCI (opzionale):** [Indice area](./docs/09_cloud_oci/README.md)
- 🎓 **Esami & Carriera:** [Indice area](./docs/10_esami_carriera/README.md)
- 🛠️ **Strumenti operativi:** [Runbook](./docs/11_runbook_operativi/README.md) · [Script SQL](./docs/12_scripts_sql_pronti/README.md) · [Libreria script](./docs/13_libreria_completa_script/README.md)
- 🤖 **Automazione/IaC:** [Ansible](./automation/README.md) · [Track Proxmox](./docs/15_proxmox_track/README.md) · [Terraform Proxmox](./infrastructure/proxmox/terraform/README.md)
- 🧭 **Indice totale unico:** [docs/README.md](./docs/README.md)

---

## 🧩 Indice esteso (interattivo)

<details>
  <summary>🟢 Fondamenti — leggi prima del lab</summary>

- [Architettura Oracle](./docs/00_fondamenti/GUIDA_ARCHITETTURA_ORACLE.md)
- [Ciclo di Vita di una Transazione](./docs/00_fondamenti/GUIDA_CICLO_DI_VITA_TRANSAZIONE.md)
- [Memory Architecture (SGA/PGA)](./docs/00_fondamenti/GUIDA_MEMORIA_ORACLE_SGA_PGA.md)
- [Redo/Undo & Crash Recovery](./docs/00_fondamenti/GUIDA_REDO_UNDO_CRASH_RECOVERY.md)
- [Locking, Concurrency & Wait Events](./docs/00_fondamenti/GUIDA_LOCKING_CONCURRENCY_WAIT_EVENTS.md)
- [Comandi DBA](./docs/00_fondamenti/GUIDA_COMANDI_DBA.md)
- [Glossario Oracle](./docs/00_fondamenti/GLOSSARIO_ORACLE.md)
- [Indice completo area](./docs/00_fondamenti/README.md)

</details>

<details>
  <summary>🔵 High Availability — Data Guard, Switchover, Failover</summary>

- [Switchover Completo](./docs/02_high_availability/GUIDA_SWITCHOVER_COMPLETO.md)
- [Failover + Reinstate](./docs/02_high_availability/GUIDA_FAILOVER_E_REINSTATE.md)
- [Flashback Database](./docs/02_high_availability/GUIDA_FLASHBACK_DATABASE.md)
- [MAA Best Practices](./docs/02_high_availability/GUIDA_MAA_BEST_PRACTICES.md)
- [Indice completo area](./docs/02_high_availability/README.md)

> ⚠️ FAILOVER è distruttivo: spegni tutte le VM e fai backup della cartella VirtualBox VMs prima del test.

</details>

<details>
  <summary>🛠️ Strumenti operativi (Runbook, Script SQL, Automation, Libreria)</summary>

- [Script SQL per Scenario — 10 script pronti](./docs/12_scripts_sql_pronti/README.md)
- [Runbook Operativi — indice completo](./docs/11_runbook_operativi/README.md)
- [Ansible Automation — 13 playbook](./automation/README.md)
- [Libreria Oracle script (~1000)](./docs/13_libreria_completa_script/README.md)
- [Catalogo completo libreria script](./docs/13_libreria_completa_script/CATALOGO_COMPLETO_SCRIPT.md)

</details>

<details>
  <summary>🎓 Roadmap, Esami, Piano IP e Risorse</summary>

- [Piano Laboratorio (8 settimane)](./docs/00_fondamenti/PIANO_LABORATORIO.md)
- [Preparazione Esami 1Z0-082 + 1Z0-083](./docs/10_esami_carriera/GUIDA_ESAME_REVIEW.md)
- [Ripasso Concetti DBA](./docs/10_esami_carriera/GUIDA_RIPASSO_CONCETTI_DBA.md)
- [Da Lab a Produzione](./docs/10_esami_carriera/GUIDA_DA_LAB_A_PRODUZIONE.md)
- [Piano IP e rete lab](./docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md)
- [Riferimenti Oracle ufficiali](#-riferimenti-ufficiali-oracle)

</details>

<details>
  <summary>🏛️ Core Lab 0→8 — Setup, Grid, RAC, Verifica</summary>

- [Fase 0: Setup Macchine](./docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md)
- [Fase 1: Preparazione OS](./docs/01_lab_setup/GUIDA_FASE1_PREPARAZIONE_OS.md)
- [Fase 2: Grid e RAC](./docs/01_lab_setup/GUIDA_FASE2_GRID_E_RAC.md)
- [Fase 8: Test e Verifica](./docs/01_lab_setup/GUIDA_FASE8_TEST_VERIFICA.md)
- [Percorso Lite Single Node](./docs/01_lab_setup/GUIDA_PERCORSO_LITE_SINGLE_NODE.md)
- [SSH Keys RAC](./docs/01_lab_setup/GUIDA_SSH_KEYS_RAC.md)
- [Obiettivi e Checklist Fasi 0→8](./docs/01_lab_setup/OBIETTIVI_E_CHECKLIST_FASI_0_8.md)
- [Indice completo area](./docs/01_lab_setup/README.md)

</details>

<details>
  <summary>🟡 Backup & Recovery — RMAN, Data Pump</summary>

- [Data Pump](./docs/03_backup_recovery/GUIDA_DATA_PUMP.md)
- [Fase 5: RMAN Backup](./docs/03_backup_recovery/GUIDA_FASE5_RMAN_BACKUP.md)
- [RMAN Completa 19c](./docs/03_backup_recovery/GUIDA_RMAN_COMPLETA_19C.md)
- [Indice completo area](./docs/03_backup_recovery/README.md)

</details>

<details>
  <summary>🟠 Amministrazione — Sicurezza, ASM, Scheduler, Servizi</summary>

- [Checklist Security Baseline](./docs/04_administration/CHECKLIST_SECURITY_BASELINE.md)
- [ACL Network Oracle](./docs/04_administration/GUIDA_ACL_NETWORK_ORACLE.md)
- [Aggiunta Dischi ASM](./docs/04_administration/GUIDA_AGGIUNTA_DISCHI_ASM.md)
- [Ansible Templates](./docs/04_administration/GUIDA_ANSIBLE_TEMPLATES.md)
- [CDB, PDB e Utenti](./docs/04_administration/GUIDA_CDB_PDB_UTENTI.md)
- [Identità Oracle e Servizi](./docs/04_administration/GUIDA_IDENTITA_ORACLE_E_SERVIZI.md)
- [Listener e Servizi DBA](./docs/04_administration/GUIDA_LISTENER_SERVICES_DBA.md)
- [Package Monitor DDL](./docs/04_administration/GUIDA_PACKAGE_MONITOR_DDL.md)
- [Scheduler Jobs](./docs/04_administration/GUIDA_SCHEDULER_JOBS.md)
- [Security Hardening](./docs/04_administration/GUIDA_SECURITY_HARDENING.md)
- [Servizi Applicativi RAC](./docs/04_administration/GUIDA_SERVIZI_APPLICATIVI_RAC.md)
- [Indice completo area](./docs/04_administration/README.md)

</details>

<details>
  <summary>🔴 Performance & Diagnostica — AWR, ASH, Troubleshooting</summary>

- [ADRCI Diagnostica Oracle](./docs/05_performance/GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md)
- [AWR, ASH e ADDM](./docs/05_performance/GUIDA_AWR_ASH_ADDM.md)
- [Troubleshooting Completo](./docs/05_performance/GUIDA_TROUBLESHOOTING_COMPLETO.md)
- [Top 100 Script DBA](./docs/05_performance/TOP_100_SCRIPT_DBA.md)
- [Indice completo area](./docs/05_performance/README.md)

</details>

<details>
  <summary>🟣 Patching & Upgrade — AutoUpgrade, RU, RAC</summary>

- [AutoUpgrade 12c → 19c](./docs/06_patching_upgrade/GUIDA_AUTOUPGRADE_12C_TO_19C.md)
- [AutoUpgrade 19c → 26](./docs/06_patching_upgrade/GUIDA_AUTOUPGRADE_19C_TO_26.md)
- [Patching RAC](./docs/06_patching_upgrade/GUIDA_PATCHING_RAC.md)
- [Upgrade RU RAC](./docs/06_patching_upgrade/GUIDA_UPGRADE_RU_RAC.md)
- [Indice completo area](./docs/06_patching_upgrade/README.md)

</details>

<details>
  <summary>🔄 Replica & Migrazione — GoldenGate, Oracle→Postgres</summary>

- [Fase 7: GoldenGate](./docs/07_replication/GUIDA_FASE7_GOLDENGATE.md)
- [Migrazione GoldenGate](./docs/07_replication/GUIDA_MIGRAZIONE_GOLDENGATE.md)
- [Migrazione Oracle → Postgres](./docs/07_replication/GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md)
- [Testlog GoldenGate Template](./docs/07_replication/TESTLOG_GOLDENGATE_TEMPLATE.md)
- [Indice completo area](./docs/07_replication/README.md)

</details>

<details>
  <summary>📊 Monitoring — Enterprise Manager, Open Source</summary>

- [Fase 6: Enterprise Manager 13c](./docs/08_monitoring/GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md)
- [Monitoring Open Source](./docs/08_monitoring/GUIDA_MONITORING_OPENSOURCE.md)
- [Indice completo area](./docs/08_monitoring/README.md)

</details>

<details>
  <summary>☁️ Cloud OCI — GoldenGate OCI, Rete Lab</summary>

- [Cloud GoldenGate](./docs/09_cloud_oci/GUIDA_CLOUD_GOLDENGATE.md)
- [GoldenGate OCI ARM](./docs/09_cloud_oci/GUIDA_GOLDENGATE_OCI_ARM.md)
- [Rete Lab OCI GoldenGate](./docs/09_cloud_oci/GUIDA_RETE_LAB_OCI_GOLDENGATE.md)
- [Indice completo area](./docs/09_cloud_oci/README.md)

</details>

<details>
  <summary>🏢 Enterprise Governance — Standard, KPI, Policy, Community</summary>

- [Compatibility Policy](./docs/14_enterprise_governance/COMPATIBILITY_POLICY.md)
- [Compatibility Matrix](./docs/14_enterprise_governance/COMPATIBILITY_MATRIX.md)
- [Compatibility by Area 19c/21c/23ai/26c](./docs/14_enterprise_governance/COMPATIBILITY_BY_AREA_19c_21c_23ai_26c.md)
- [Release Engineering Policy](./docs/14_enterprise_governance/RELEASE_ENGINEERING_POLICY.md)
- [Quickstart Enterprise 10 Minuti](./docs/14_enterprise_governance/QUICKSTART_10_MINUTI.md)
- [Troubleshooting Decision Tree](./docs/14_enterprise_governance/TROUBLESHOOTING_DECISION_TREE.md)
- [Reliability Framework (SLO/SLI/KPI)](./docs/14_enterprise_governance/RELIABILITY_FRAMEWORK.md)
- [MAA Scorecard](./docs/14_enterprise_governance/MAA_SCORECARD.md)
- [Production Profile](./docs/14_enterprise_governance/PRODUCTION_PROFILE.md)
- [Public KPI Scoreboard](./docs/14_enterprise_governance/PUBLIC_KPI_SCOREBOARD.md)
- [Go/No-Go Merge Policy](./docs/14_enterprise_governance/GO_NO_GO_MASTER_MERGE_POLICY.md)
- [Didactic Excellence Standard](./docs/14_enterprise_governance/DIDACTIC_EXCELLENCE_STANDARD.md)
- [Didactic Compliance Checklist](./docs/14_enterprise_governance/DIDACTIC_COMPLIANCE_CHECKLIST.md)
- [Community Roadmap](./docs/14_enterprise_governance/COMMUNITY_ROADMAP.md)
- [Community Onboarding Path](./docs/14_enterprise_governance/COMMUNITY_ONBOARDING_PATH.md)
- [Vulnerability Disclosure Policy](./docs/14_enterprise_governance/VULNERABILITY_DISCLOSURE_POLICY.md)
- [Indice completo area](./docs/14_enterprise_governance/README.md)

</details>

<details>
  <summary>🖥️ Track Proxmox Moderno — Infrastruttura moderna (Fasi 1→5)</summary>

- [Guida completa production-grade](./docs/15_proxmox_track/GUIDA_TRACK_PROXMOX_PRODUCTION_END_TO_END.md)
- [Fase 1: Proxmox Foundation](./docs/15_proxmox_track/PHASE_1_PROXMOX_FOUNDATION.md)
- [Fase 2: Terraform Proxmox](./infrastructure/proxmox/terraform/README.md)
- [Fase 3: Ansible + AWX](./docs/15_proxmox_track/PHASE_3_ANSIBLE_AWX.md)
- [Fase 4: Oracle Silent Automation](./docs/15_proxmox_track/PHASE_4_ORACLE_SILENT_AUTOMATION.md)
- [Fase 5: K3s/RKE2 Capstone](./docs/15_proxmox_track/PHASE_5_K8S_CAPSTONE.md)
- [Roadmap di adozione](./docs/15_proxmox_track/ADOPTION_ROADMAP.md)
- [Indice completo area](./docs/15_proxmox_track/README.md)

</details>

---

## 📏 Regole indice (limite di profondità)

- **Root README:** massimo 2 livelli (Area + link chiave)
- **README di area (`docs/*/README.md`):** fino a 3 livelli (Categoria + documento)
- **Oltre 12–15 voci in una sezione:** spezza in sotto-indice locale
- **Fonte unica indice totale:** [docs/README.md](./docs/README.md)

---

## 🚀 Quick Start (5 minuti)

```bash
# 1) Clona repo
git clone https://github.com/Mohamed-DN/dba_oracle_lab.git
cd dba_oracle_lab

# 2) Percorso lab principale (Vagrant one-click)
cd vagrant_rac_dataguard && vagrant up

# 3) Dopo il lab: operatività quotidiana
#    docs/11_runbook_operativi/
#    docs/12_scripts_sql_pronti/
```

> 💡 Se preferisci fare manualmente, inizia da `docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md`.

---

## 📖 Esegui il Core Lab (Fase 0→8)

> ✅ **Questo è il percorso principale del repository.**

| # | Fase | Guida | Output principale |
| --- | --- | --- | --- |
| 0 | Setup Macchine | [GUIDA_FASE0](./docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md) | VM + DNS + dischi ASM |
| 1 | Preparazione OS | [GUIDA_FASE1](./docs/01_lab_setup/GUIDA_FASE1_PREPARAZIONE_OS.md) | OS hardening base + rete |
| 2 | Grid + RAC | [GUIDA_FASE2](./docs/01_lab_setup/GUIDA_FASE2_GRID_E_RAC.md) | Cluster RAC operativo |
| 3 | RAC Standby | [GUIDA_FASE3](./docs/02_high_availability/GUIDA_FASE3_RAC_STANDBY.md) | Standby pronto |
| 4 | Data Guard Broker | [GUIDA_FASE4](./docs/02_high_availability/GUIDA_FASE4_DATAGUARD_DGMGRL.md) | Replica + switchover |
| 5 | RMAN Backup | [GUIDA_FASE5](./docs/03_backup_recovery/GUIDA_FASE5_RMAN_BACKUP.md) | Strategia backup/recovery |
| 6 | Enterprise Manager | [GUIDA_FASE6](./docs/08_monitoring/GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md) | Monitoring enterprise |
| 7 | GoldenGate | [GUIDA_FASE7](./docs/07_replication/GUIDA_FASE7_GOLDENGATE.md) | Replica logica |
| 8 | Test Verifica | [GUIDA_FASE8](./docs/01_lab_setup/GUIDA_FASE8_TEST_VERIFICA.md) | Validazione end-to-end |

---

## 📎 Riferimenti ufficiali Oracle

- Oracle Database 19c Documentation: <https://docs.oracle.com/en/database/oracle/oracle-database/19/>
- Oracle Database Backup and Recovery User's Guide (RMAN): <https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/>
- Oracle Data Guard Broker (DGMGRL): <https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/>
- Oracle GoldenGate Core Documentation: <https://docs.oracle.com/en/middleware/goldengate/core/21.3/>
- Oracle ADR Command Interpreter (ADRCI): <https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-adr-command-interpreter-adrci.html>
- Oracle MAA Best Practices: <https://www.oracle.com/database/technologies/high-availability/maa.html>

---

<p align="center">
  <sub>Built with ☕ and <code>ORA-00001</code> errors — <a href="./LICENSE">MIT License</a> — <a href="./CONTRIBUTING.md">Contributing</a></sub>
</p>
