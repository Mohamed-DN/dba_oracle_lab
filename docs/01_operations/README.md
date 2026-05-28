# 01. Operations
Questa directory rappresenta il **cuore operativo** del repository, progettata per essere la prima area da consultare in caso di incidenti (Priority 1) o per l'operatività quotidiana del DBA Oracle.

## Struttura
- **`01_cheat_sheets/`**: Comandi rapidi di emergenza e assessment da copiare/incollare a terminale.
- **`02_runbooks_incidenti/`**: Procedure operative passo-passo per la risoluzione di disservizi o per attività di manutenzione ordinaria (Runbook).
- **`03_scripts_pronti/`**: Top 10 script SQL per l'identificazione immediata di problemi (Lock, Performance, Spazio).
- **`04_libreria_script_completa/`**: Una monumentale raccolta (oltre 1000 file) categorizzata di script SQL e Bash provenienti dalla community (Tim Hall, Gwen Shapira, ecc.) e adattati per questo Lab.

> [!TIP]
> Durante una severity 1, parti da [`02_runbooks_incidenti/00_TRIAGE_INCIDENTI_ORACLE.md`](./02_runbooks_incidenti/00_TRIAGE_INCIDENTI_ORACLE.md), usa gli script di `03_scripts_pronti` per raccogliere evidenze, poi rientra nel runbook specifico.

## Shortcut operativi

- [Indice Centrale Runbook Top20](./02_runbooks_incidenti/INDICE_CENTRALE_RUNBOOK_TOP20.md)
- [Oracle Tools Command Center](./01_cheat_sheets/CHEAT_SHEET_ORACLE_TOOLS_COMMAND_CENTER.md)
- [Morning Health Check](./02_runbooks_incidenti/01_MORNING_HEALTH_CHECK.md)
- [RMAN + Data Guard Recovery/DR](./02_runbooks_incidenti/22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md)
- [ASM Storage Incidenti](./02_runbooks_incidenti/25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md)
- [Listener, SCAN e Services RAC](./02_runbooks_incidenti/26_LISTENER_SCAN_SERVICES_RAC.md)
- [Patching Oracle RAC/Data Guard](./02_runbooks_incidenti/29_PATCHING_ORACLE_RAC_DATAGUARD.md)
- [Audit, Compliance ed Evidence](./02_runbooks_incidenti/33_AUDIT_COMPLIANCE_EVIDENCE.md)
- [Capacity Forecast Enterprise](./02_runbooks_incidenti/35_CAPACITY_FORECAST_ENTERPRISE.md)
