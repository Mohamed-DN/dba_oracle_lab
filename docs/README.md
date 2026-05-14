# 📚 Indice Documentazione DBA Oracle Lab

> Indice unificato per navigare il repository in modalità **operativa**.
> Ogni sezione è numerata progressivamente e copre un'area specifica dell'attività DBA.

---

## 1) Indice per attività DBA

### 🟢 Giornaliero

- [01_MORNING_HEALTH_CHECK](./11_runbook_operativi/01_MORNING_HEALTH_CHECK.md)
- [02_VERIFICA_BACKUP](./11_runbook_operativi/02_VERIFICA_BACKUP.md)
- [03_CHECK_DATAGUARD](./11_runbook_operativi/03_CHECK_DATAGUARD.md)
- [Script SQL pronti](./12_scripts_sql_pronti/README.md)

### 🔴 Incidente / Ticket

- [04_LOCK_SESSIONI_BLOCCATE](./11_runbook_operativi/04_LOCK_SESSIONI_BLOCCATE.md)
- [05_QUERY_LENTA](./11_runbook_operativi/05_QUERY_LENTA.md)
- [08_ORA_ERRORS](./11_runbook_operativi/08_ORA_ERRORS.md)
- [19_DIAGNOSI_BACKUP_RMAN_FALLITI](./11_runbook_operativi/19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) ⬅️ **Root Cause Analysis backup**
- [GUIDA_TROUBLESHOOTING_COMPLETO](./05_performance/GUIDA_TROUBLESHOOTING_COMPLETO.md)
- [ADRCI & Trace Enterprise](./17_adrci_trace/GUIDA_ADRCI_TRACE_ENTERPRISE.md)

### 🟡 Manutenzione

- [10_START_STOP_RAC](./11_runbook_operativi/10_START_STOP_RAC.md)
- [11_REVIEW_AWR](./11_runbook_operativi/11_REVIEW_AWR.md)
- [17_PURGE_LOG_ORACLE](./11_runbook_operativi/17_PURGE_LOG_ORACLE.md)
- [18_GESTIONE_STATISTICHE_OPTIMIZER](./11_runbook_operativi/18_GESTIONE_STATISTICHE_OPTIMIZER.md)
- [GUIDA_PATCHING_RAC](./06_patching_upgrade/GUIDA_PATCHING_RAC.md)
- [GUIDA_UPGRADE_RU_RAC](./06_patching_upgrade/GUIDA_UPGRADE_RU_RAC.md)

### 🔵 Progetto / Evoluzione

- [Core Lab Fase 0→8](./01_lab_setup/OBIETTIVI_E_CHECKLIST_FASI_0_8.md)
- [GUIDA_FASE7_GOLDENGATE](./07_replication/GUIDA_FASE7_GOLDENGATE.md)

---

## 2) Indice per argomento (Directory Map)

| # | Argomento | Link |
| :---: | :--- | :--- |
| 🗂️ | **Cheat Sheet Centralizzati** | [00_cheat_sheet/](./00_cheat_sheet/README.md) |
| 00 | Fondamenti Oracle | [00_fondamenti/](./00_fondamenti/README.md) |
| 00 | Percorso Lab | [00_lab_percorso/](./00_lab_percorso/README.md) |
| 01 | Core Lab Setup (Grid, ASM, RAC) | [01_lab_setup/](./01_lab_setup/README.md) |
| 02 | High Availability / Data Guard | [02_high_availability/](./02_high_availability/README.md) |
| 03 | Backup & Recovery (RMAN base) | [03_backup_recovery/](./03_backup_recovery/README.md) |
| 04 | Administration (Users, TBS, CDB/PDB) | [04_administration/](./04_administration/README.md) |
| 05 | Performance & Diagnostica (AWR/ASH) | [05_performance/](./05_performance/README.md) |
| 06 | Patching & Upgrade | [06_patching_upgrade/](./06_patching_upgrade/README.md) |
| 07 | Replica / GoldenGate | [07_replication/](./07_replication/README.md) |
| 08 | Monitoring (OEM, CheckMK) | [08_monitoring/](./08_monitoring/README.md) |
| 09 | Cloud OCI (opzionale) | [09_cloud_oci/](./09_cloud_oci/README.md) |
| 10 | Esami & Carriera | [10_esami_carriera/](./10_esami_carriera/README.md) |
| 11 | Runbook Operativi (Top 20) | [11_runbook_operativi/](./11_runbook_operativi/README.md) |
| 12 | Script SQL Pronti | [12_scripts_sql_pronti/](./12_scripts_sql_pronti/README.md) |
| 13 | Libreria Completa Script | [13_libreria_completa_script/](./13_libreria_completa_script/README.md) |
| 14 | Enterprise Governance | [14_enterprise_governance/](./14_enterprise_governance/README.md) |
| 15 | **RMAN Enterprise (Comandi & TDE)** | [15_rman_comandi/](./15_rman_comandi/README.md) |
| 16 | Proxmox Track (Infra Lab) | [16_proxmox_track/](./16_proxmox_track/GUIDA_TRACK_PROXMOX_PRODUCTION_END_TO_END.md) |
| 17 | **ADRCI & Trace Enterprise** | [17_adrci_trace/](./17_adrci_trace/README.md) |
| 18 | **Setup LDAP (EUS/CMU/AD)** | [18_setup_ldap/](./18_setup_ldap/GUIDA_SETUP_LDAP_ENTERPRISE.md) |
| 19 | **Setup CheckMK Oracle** | [19_setup_checkmk/](./19_setup_checkmk/GUIDA_SETUP_CHECKMK_ORACLE_ENTERPRISE.md) |

---

## 3) Materiali operativi ad alta priorità

1. [Runbook Operativi](./11_runbook_operativi/README.md)
2. [Script SQL per Scenario](./12_scripts_sql_pronti/README.md)
3. [Indice Centrale Runbook + Top20](./11_runbook_operativi/INDICE_CENTRALE_RUNBOOK_TOP20.md)
4. [Top 100 Script DBA](./05_performance/TOP_100_SCRIPT_DBA.md)
5. Cheat Sheet: [RMAN](./00_cheat_sheet/CHEAT_SHEET_RMAN.md) · [DGMGRL](./00_cheat_sheet/CHEAT_SHEET_DGMGRL.md) · [GoldenGate](./00_cheat_sheet/CHEAT_SHEET_GOLDENGATE.md)

---

## 4) Appunti e archivio

- Uso frequente: [GUIDA_RIPASSO_CONCETTI_DBA](./10_esami_carriera/GUIDA_RIPASSO_CONCETTI_DBA.md)
- Storico tecnico: [DIARIO_DI_BORDO](./00_fondamenti/DIARIO_DI_BORDO.md)
- Archivio secondario: [10_esami_carriera/archivio_extra](./10_esami_carriera/archivio_extra/README.md)
