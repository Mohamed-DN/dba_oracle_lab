# START HERE - Mappa Operativa del Repository

> Punto di ingresso rapido. Usa questa pagina quando non sai quale guida aprire o quando devi lavorare sotto pressione.

## Se Hai Un Incidente

Apri in questo ordine:

1. [Triage Incidenti Oracle](./docs/01_operations/02_runbooks_incidenti/00_TRIAGE_INCIDENTI_ORACLE.md)
2. [Indice Centrale Runbook Top20](./docs/01_operations/02_runbooks_incidenti/INDICE_CENTRALE_RUNBOOK_TOP20.md)
3. [Script pronti per scenario](./docs/01_operations/03_scripts_pronti/README.md)
4. [Troubleshooting Decision Tree](./docs/04_governance_learning/02_enterprise_standards/TROUBLESHOOTING_DECISION_TREE.md)

Regola:

```text
Sintomo -> impatto -> evidenze -> diagnosi -> fix -> validazione -> prevenzione
```

## Se Devi Costruire Il Lab

Percorso principale:

1. [Fondamenti teorici](./docs/04_governance_learning/01_fondamenti_teorici/README.md)
2. [Core Lab 0-8](./docs/03_infra_lab/02_oracle_installation_asm/README.md)
3. [Vagrant RAC + Data Guard](./vagrant_rac_dataguard/README.md)
4. [Backup & Recovery](./docs/02_core_dba/02_backup_and_recovery/README.md)
5. [High Availability](./docs/02_core_dba/04_high_availability_and_rac/README.md)
6. [Monitoring](./docs/02_core_dba/06_monitoring_systems/README.md)

Non partire da GoldenGate, upgrade o patching se non hai prima RAC/Data Guard stabile.

## Se Devi Fare Data Guard In Produzione

Scegli il caso:

| Caso | Guida |
| --- | --- |
| Single instance primary + standby non-CDB | [Produzione Single Instance Data Guard Non-CDB](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md) |
| RAC primary + RAC standby non-CDB | [Produzione RAC Data Guard Non-CDB](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md) |
| Lab RAC standby | [Fase 3 RAC Standby](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_FASE3_RAC_STANDBY.md) |
| Broker DGMGRL | [Fase 4 Data Guard Broker](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md) |
| Switchover | [Switchover Completo](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_SWITCHOVER_COMPLETO.md) |
| Failover e reinstate | [Failover + Reinstate](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_FAILOVER_E_REINSTATE.md) |
| Flashback database | [Flashback Database](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_FLASHBACK_DATABASE.md) |

## Se Devi Fare Backup, Restore O Clone

Apri:

- [RMAN completa 19c](./docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md)
- [RMAN Full Cheatsheet](./docs/01_operations/01_cheat_sheets/RMAN_FULL_CHEATSHEET.md)
- [Verifica Backup RMAN](./docs/01_operations/02_runbooks_incidenti/02_VERIFICA_BACKUP.md)
- [Diagnosi RMAN e DR](./docs/01_operations/02_runbooks_incidenti/19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md)
- [RMAN + Data Guard Recovery/DR](./docs/01_operations/02_runbooks_incidenti/22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md)

## Se Devi Gestire Operativita Enterprise

Apri:

- [ASM Storage Incidenti](./docs/01_operations/02_runbooks_incidenti/25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md)
- [Listener, SCAN e Services RAC](./docs/01_operations/02_runbooks_incidenti/26_LISTENER_SCAN_SERVICES_RAC.md)
- [TDE Wallet/Keystore](./docs/01_operations/02_runbooks_incidenti/27_TDE_WALLET_KEYSTORE_RUNBOOK.md)
- [Scheduler Jobs e AutoTask](./docs/01_operations/02_runbooks_incidenti/28_SCHEDULER_JOBS_AUTOTASKS_RUNBOOK.md)
- [Patching Oracle RAC/Data Guard](./docs/01_operations/02_runbooks_incidenti/29_PATCHING_ORACLE_RAC_DATAGUARD.md)
- [Audit, Compliance ed Evidence](./docs/01_operations/02_runbooks_incidenti/33_AUDIT_COMPLIANCE_EVIDENCE.md)
- [Capacity Forecast Enterprise](./docs/01_operations/02_runbooks_incidenti/35_CAPACITY_FORECAST_ENTERPRISE.md)

## Se Devi Fare Performance/Tuning

Apri:

- [Query Lenta](./docs/01_operations/02_runbooks_incidenti/05_QUERY_LENTA.md)
- [CPU Alta](./docs/01_operations/02_runbooks_incidenti/07_CPU_ALTA.md)
- [SQL Tuning Enterprise](./docs/01_operations/02_runbooks_incidenti/23_SQL_TUNING_CASI_ENTERPRISE.md)
- [AWR/ASH/ADDM](./docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md)
- [Top 100 Script DBA](./docs/02_core_dba/03_performance_and_diagnostics/TOP_100_SCRIPT_DBA.md)

## Se Devi Fare Migrazione O Replica

| Obiettivo | Apri |
| --- | --- |
| Export/import prod-preprod | [Export/Import Prod-Preprod](./docs/01_operations/02_runbooks_incidenti/20_EXPORT_IMPORT_PROD_PREPROD.md) |
| Refresh schema test | [Refresh Schema Test](./docs/01_operations/02_runbooks_incidenti/13_REFRESH_SCHEMA_TEST.md) |
| GoldenGate prerequisiti | [Prerequisiti DB GoldenGate](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md) |
| GoldenGate end-to-end | [Runbook GoldenGate 19c](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_RUNBOOK_END_TO_END_19C.md) |
| Oracle -> PostgreSQL | [GoldenGate Oracle to PostgreSQL](./docs/02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_ORACLE_TO_POSTGRESQL.md) |

## Matrice Decisionale Rapida

| Sintomo / Obiettivo | Primo documento |
| --- | --- |
| Non sai da dove iniziare | [Triage Incidenti Oracle](./docs/01_operations/02_runbooks_incidenti/00_TRIAGE_INCIDENTI_ORACLE.md) |
| DB non parte | [Morning Health Check](./docs/01_operations/02_runbooks_incidenti/01_MORNING_HEALTH_CHECK.md) |
| Backup fallito | [Verifica Backup RMAN](./docs/01_operations/02_runbooks_incidenti/02_VERIFICA_BACKUP.md) |
| Standby in lag | [Check Data Guard](./docs/01_operations/02_runbooks_incidenti/03_CHECK_DATAGUARD.md) |
| Applicazione bloccata | [Lock Sessioni Bloccate](./docs/01_operations/02_runbooks_incidenti/04_LOCK_SESSIONI_BLOCCATE.md) |
| SQL lento | [Query Lenta](./docs/01_operations/02_runbooks_incidenti/05_QUERY_LENTA.md) |
| Spazio pieno | [Tablespace Pieno](./docs/01_operations/02_runbooks_incidenti/06_TABLESPACE_PIENO.md) |
| FRA piena | [Purge Log Oracle](./docs/01_operations/02_runbooks_incidenti/17_PURGE_LOG_ORACLE.md) |
| ASM diskgroup pieno o dischi offline | [ASM Storage Incidenti](./docs/01_operations/02_runbooks_incidenti/25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md) |
| ORA-12514/12541 o service non registrato | [Listener/SCAN/Services RAC](./docs/01_operations/02_runbooks_incidenti/26_LISTENER_SCAN_SERVICES_RAC.md) |
| Wallet TDE chiuso o restore cifrato | [TDE Wallet/Keystore](./docs/01_operations/02_runbooks_incidenti/27_TDE_WALLET_KEYSTORE_RUNBOOK.md) |
| Job scheduler fallito | [Scheduler Jobs e AutoTask](./docs/01_operations/02_runbooks_incidenti/28_SCHEDULER_JOBS_AUTOTASKS_RUNBOOK.md) |
| Alert OEM/EM | [Enterprise Manager Alert Handling](./docs/01_operations/02_runbooks_incidenti/32_ENTERPRISE_MANAGER_ALERT_RUNBOOK.md) |
| Connessione TCPS/certificato | [TCPS Wallet e Certificati](./docs/01_operations/02_runbooks_incidenti/34_TCPS_WALLET_CERTIFICATI.md) |
| Creare standby fisico | [Produzione Single Instance DG](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md) |
| Creare standby RAC | [Produzione RAC DG](./docs/02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md) |

## Ricerca Rapida

Da shell:

```bash
rg -n "ORA-01555|ORA-01652|ORA-19809" docs
rg -n "DUPLICATE TARGET DATABASE" docs
rg -n "SHOW CONFIGURATION|VALIDATE DATABASE" docs
rg -n "DBMS_XPLAN|SQL_ID|PLAN_HASH_VALUE" docs
rg -n "ORA-12514|ORA-12541|LOCAL_LISTENER|REMOTE_LISTENER" docs
rg -n "ORA-28365|v\\$encryption_wallet|ADMINISTER KEY MANAGEMENT" docs
rg -n "OGG-|INFO ALL|lag replicat|lag extract" docs
```

Da PowerShell:

```powershell
rg -n "ORA-01555|ORA-01652|ORA-19809" docs
rg -n "DUPLICATE TARGET DATABASE" docs
rg -n "SHOW CONFIGURATION|VALIDATE DATABASE" docs
rg -n "DBMS_XPLAN|SQL_ID|PLAN_HASH_VALUE" docs
rg -n "ORA-12514|ORA-12541|LOCAL_LISTENER|REMOTE_LISTENER" docs
rg -n "ORA-28365|v\\$encryption_wallet|ADMINISTER KEY MANAGEMENT" docs
rg -n "OGG-|INFO ALL|lag replicat|lag extract" docs
```

## Regole Di Uso Del Repo

- Per incidenti: parti sempre da `01_operations`.
- Per architettura o implementazioni: parti da `02_core_dba`.
- Per installare lab/infrastruttura: parti da `03_infra_lab`.
- Per teoria, standard e decision tree: parti da `04_governance_learning`.
- Non usare script della libreria massiva direttamente in produzione senza leggerli e testarli.
- Ogni procedura in produzione deve finire con evidenze before/after e rischio residuo.
