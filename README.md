# 🏛️ Oracle RAC + Data Guard — Enterprise DBA Lab

[![Oracle 19c](https://img.shields.io/badge/Oracle-19c-red?logo=oracle&logoColor=white)](https://www.oracle.com/database/)
[![Ansible](https://img.shields.io/badge/Ansible-Automation-black?logo=ansible)](./automation/)
[![Scripts](https://img.shields.io/badge/Scripts-1000%2B-blue)](./docs/13_libreria_completa_script/)
[![MAA Gold](https://img.shields.io/badge/MAA_Gold-98%25-green)](./docs/10_esami_carriera/VALIDAZIONE_BEST_PRACTICES.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

> Guida pratica e operativa per costruire e gestire un laboratorio Oracle RAC + Data Guard.
> **Core del repository: Lab Fase 0→8.** Tutto il resto è estensione operativa/avanzata.

## 📑 Navigazione Rapida (ordine consigliato)

- 📚 **Fondamenti (leggi prima):** [Architettura Oracle](./docs/00_fondamenti/GUIDA_ARCHITETTURA_ORACLE.md) · [Glossario](./docs/00_fondamenti/GLOSSARIO_ORACLE.md) · [Comandi DBA](./docs/00_fondamenti/GUIDA_COMANDI_DBA.md)
- 🏛️ **Core Lab 0→8:** [Fasi 0→8](#-esegui-il-core-lab-fase-08) · [Checklist Core](./docs/01_lab_setup/OBIETTIVI_E_CHECKLIST_FASI_0_8.md) · [Vagrant Lab](./vagrant_rac_dataguard/README.md)
- 🛠️ **Operatività quotidiana DBA:** [Runbook](./docs/11_runbook_operativi/README.md) · [Script SQL pronti](./docs/12_scripts_sql_pronti/README.md) · [Top script DBA](./docs/05_performance/TOP_100_SCRIPT_DBA.md)
- 📖 **Approfondimenti:** [Indice docs per attività/argomento](./docs/README.md) · [High Availability](./docs/02_high_availability/) · [Backup & Recovery](./docs/03_backup_recovery/)
- 🤖 **Automazione/IaC (avanzato):** [Ansible](./automation/README.md) · [Track Proxmox](./docs/15_proxmox_track/README.md) · [Terraform Proxmox](./infrastructure/proxmox/terraform/README.md)

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

## 📚 Leggi prima del Lab

1. [GUIDA_ARCHITETTURA_ORACLE.md](./docs/00_fondamenti/GUIDA_ARCHITETTURA_ORACLE.md)
2. [GUIDA_COMANDI_DBA.md](./docs/00_fondamenti/GUIDA_COMANDI_DBA.md)
3. [GUIDA_REDO_UNDO_CRASH_RECOVERY.md](./docs/00_fondamenti/GUIDA_REDO_UNDO_CRASH_RECOVERY.md)
4. [GLOSSARIO_ORACLE.md](./docs/00_fondamenti/GLOSSARIO_ORACLE.md)

---

## 📖 Esegui il Core Lab (Fase 0→8)

> ✅ **Questo è il percorso principale del repository.**

| # | Fase | Guida | Output principale |
|---|---|---|---|
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

## 🛠️ Operatività quotidiana DBA (priorità alta)

- [Runbook operativi](./docs/11_runbook_operativi/README.md)
- [Script SQL pronti per scenario](./docs/12_scripts_sql_pronti/README.md)
- [Indice Centrale Runbook + Top20](./docs/11_runbook_operativi/INDICE_CENTRALE_RUNBOOK_TOP20.md)
- [Top 100 Script DBA](./docs/05_performance/TOP_100_SCRIPT_DBA.md)

### Cheat Sheet rapide (nuove)

- [Cheat Sheet RMAN](./docs/11_runbook_operativi/CHEAT_SHEET_RMAN.md)
- [Cheat Sheet DGMGRL](./docs/11_runbook_operativi/CHEAT_SHEET_DGMGRL.md)
- [Cheat Sheet GoldenGate](./docs/11_runbook_operativi/CHEAT_SHEET_GOLDENGATE.md)
- [GUIDA ADRCI + Diagnostica Oracle](./docs/05_performance/GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md)

---

## 🧭 Indice docs completo (per attività e per argomento)

Per navigazione globale ordinata usa: **[docs/README.md](./docs/README.md)**

- vista **per attività DBA** (giornaliero, incidente, manutenzione, progetto)
- vista **per argomento** (HA, backup, performance, sicurezza, replica, monitoring)

---

## 📝 Appunti e ripasso (snelli e utili)

- [GUIDA_RIPASSO_CONCETTI_DBA.md](./docs/10_esami_carriera/GUIDA_RIPASSO_CONCETTI_DBA.md) — ripasso strutturato con uso rapido
- [DIARIO_DI_BORDO.md](./docs/00_fondamenti/DIARIO_DI_BORDO.md) — changelog tecnico compatto
- Archivio storico: [docs/10_esami_carriera/archivio_extra](./docs/10_esami_carriera/archivio_extra/README.md)

---

## ⚡ Cosa trovi nel repository (sintesi)

| Area | Contenuto |
|---|---|
| Core Lab | Fasi 0→8 per costruire RAC + Data Guard + GoldenGate |
| Operatività | Runbook giornalieri + script SQL pronti + top script |
| Libreria estesa | ~1000 script in `docs/13_libreria_completa_script/` |
| Governance | standard qualità, reliability, security e release policy |

---

## 🤖 Automazione/IaC (estensione avanzata)

- [automation/README.md](./automation/README.md) — playbook e ruoli Ansible
- [docs/15_proxmox_track/README.md](./docs/15_proxmox_track/README.md) — track moderno Proxmox 1→5
- [infrastructure/proxmox/terraform/README.md](./infrastructure/proxmox/terraform/README.md) — baseline Terraform

---

## 🧭 Confronto percorsi (in fondo)

| Percorso | Quando usarlo | Link |
|---|---|---|
| **Vagrant storico (core attuale)** | Vuoi completare rapidamente il lab RAC + DG in locale | [vagrant_rac_dataguard/README.md](./vagrant_rac_dataguard/README.md) |
| **Proxmox moderno (avanzato)** | Vuoi evolvere verso IaC + control plane + K8s | [docs/15_proxmox_track/README.md](./docs/15_proxmox_track/README.md) |

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
