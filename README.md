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
