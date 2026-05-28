# Indice Centrale: Runbook Operativi + Top 20 Script

## Prima scelta in caso di incidente

1. [00 Triage Incidenti Oracle](./00_TRIAGE_INCIDENTI_ORACLE.md) - decision tree alert -> runbook.
2. [01 Morning Health Check](./01_MORNING_HEALTH_CHECK.md) - stato generale.
3. [08 ORA-Errors Comuni](./08_ORA_ERRORS.md) - errore ORA -> causa -> fix.
4. [22 RMAN + Data Guard Recovery/DR](./22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) - recovery, DR, failover, PITR.
5. [25 ASM Storage Incidenti](./25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md) - ASM, diskgroup, dischi, rebalance.
6. [26 Listener/SCAN/Services RAC](./26_LISTENER_SCAN_SERVICES_RAC.md) - connettivita applicativa, servizi, ORA-125xx.
7. [23 SQL Tuning Enterprise](./23_SQL_TUNING_CASI_ENTERPRISE.md) - SQL tuning avanzato.

## Runbook operativi

- [README Runbook](./README.md)
- [Troubleshooting Decision Tree](../../04_governance_learning/02_enterprise_standards/TROUBLESHOOTING_DECISION_TREE.md)
- [00 Triage Incidenti Oracle](./00_TRIAGE_INCIDENTI_ORACLE.md)
- [01 Morning Health Check](./01_MORNING_HEALTH_CHECK.md)
- [02 Verifica Backup RMAN](./02_VERIFICA_BACKUP.md)
- [03 Check Data Guard](./03_CHECK_DATAGUARD.md)
- [04 Lock Sessioni Bloccate](./04_LOCK_SESSIONI_BLOCCATE.md)
- [05 Query Lenta](./05_QUERY_LENTA.md)
- [06 Tablespace Pieno](./06_TABLESPACE_PIENO.md)
- [07 CPU Alta](./07_CPU_ALTA.md)
- [08 ORA-Errors Comuni](./08_ORA_ERRORS.md)
- [09 Gestione Utenti](./09_GESTIONE_UTENTI.md)
- [10 Start/Stop Database RAC](./10_START_STOP_RAC.md)
- [11 Review AWR Settimanale](./11_REVIEW_AWR.md)
- [12 Capacity Planning e Limiti](./12_CAPACITY_PLANNING_LIMITI.md)
- [13 Refresh Schema Test](./13_REFRESH_SCHEMA_TEST.md)
- [14 Chaos Network Partition](./14_CHAOS_NETWORK_PARTITION_DATAGUARD.md)
- [15 Checkmk Troubleshooting](./15_CHECKMK_AGENT_TLS_SMART_RAID_TROUBLESHOOTING.md)
- [16 Resize TEMP](./16_RESIZE_TEMP.md)
- [17 Purge Log Oracle](./17_PURGE_LOG_ORACLE.md)
- [18 Gestione Statistiche Optimizer](./18_GESTIONE_STATISTICHE_OPTIMIZER.md)
- [19 Diagnosi RMAN e DR](./19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md)
- [20 Export/Import Prod-Preprod](./20_EXPORT_IMPORT_PROD_PREPROD.md) - Data Pump enterprise, masking, checksum, FRA, manuali Oracle.
- [21 Gestione DB Link](./21_GESTIONE_DB_LINK.md) - sicurezza DB link, SQLNet encryption, 2PC, hardening post-refresh.
- [22 Casi RMAN + Data Guard Recovery/DR](./22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) - scenari operativi per crash DB, errori umani, PITR, standby, gap, failover e switchover.
- [23 Casi SQL Tuning Enterprise](./23_SQL_TUNING_CASI_ENTERPRISE.md) - scenari optimizer, AWR/ASH, SQL Monitor, piani, statistiche, indici, SPM e tuning sicuro.
- [24 Gap Analysis Copertura DBA](./24_GAP_ANALYSIS_COPERTURA_DBA.md) - cosa manca ancora per copertura enterprise.
- [25 ASM Storage Incidenti Enterprise](./25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md) - diskgroup full, dischi offline, ORA-150xx, rebalance, evidence storage.
- [26 Listener, SCAN e Services RAC](./26_LISTENER_SCAN_SERVICES_RAC.md) - listener/SCAN, service role-based, PMON/LREG, ORA-12514/12541/12154.
- [27 TDE Wallet/Keystore](./27_TDE_WALLET_KEYSTORE_RUNBOOK.md) - wallet open/closed, backup keystore, restore cifrati, Data Guard/TDE.
- [28 Scheduler Jobs e AutoTask](./28_SCHEDULER_JOBS_AUTOTASKS_RUNBOOK.md) - job failure, stop/disable sicuro, AutoTask, maintenance windows.
- [29 Patching Oracle RAC/Data Guard](./29_PATCHING_ORACLE_RAC_DATAGUARD.md) - OPatch, datapatch, rolling patch, Data Guard strategy, rollback.
- [30 Multitenant CDB/PDB Operations](./30_MULTITENANT_PDB_OPERATIONS.md) - open/close PDB, clone, plug/unplug, service PDB, PDB recovery.
- [31 GoldenGate Incident Runbook](./31_GOLDENGATE_INCIDENT_RUNBOOK.md) - ABEND, lag, trail, archive mancanti, Replicat error.
- [32 Enterprise Manager Alert Handling](./32_ENTERPRISE_MANAGER_ALERT_RUNBOOK.md) - triage alert OEM/EM, blackout, evidence, chiusura corretta.
- [33 Audit, Compliance ed Evidence](./33_AUDIT_COMPLIANCE_EVIDENCE.md) - audit trail, unified audit, before/after, evidence ticket.
- [34 TCPS Wallet e Certificati](./34_TCPS_WALLET_CERTIFICATI.md) - TCPS, wallet Oracle Net, certificati, DN match, rotazione.
- [35 Capacity Forecast Enterprise](./35_CAPACITY_FORECAST_ENTERPRISE.md) - forecast tablespace/FRA/ASM/SYSAUX/processi.
- [Guida Migrazione MAA](./GUIDA_MIGRAZIONE_MAA_BEST_PRACTICES.md)

## Cheat sheet

- [RMAN Full Cheatsheet](../01_cheat_sheets/RMAN_FULL_CHEATSHEET.md) - catalog, RAC/DG, CDB/PDB, validate restore, TSPITR, manuali RMAN.
- [RMAN Essentials](../01_cheat_sheets/CHEAT_SHEET_RMAN_ESSENZIALE.md)
- [DGMGRL](../01_cheat_sheets/CHEAT_SHEET_DGMGRL.md)
- [GoldenGate](../01_cheat_sheets/CHEAT_SHEET_GOLDENGATE.md)

## Catalogo script enterprise

- [Script pronti per scenario](../03_scripts_pronti/README.md)
- [Top 100 Script DBA](../../02_core_dba/03_performance_and_diagnostics/TOP_100_SCRIPT_DBA.md)
- [Libreria completa script](../04_libreria_script_completa/README.md)
- [ADRCI + Diagnostica Oracle](../../02_core_dba/03_performance_and_diagnostics/GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md)

## Uso consigliato

1. Parti dal triage centrale se il sintomo non e chiaro.
2. Apri il runbook specifico e usa l'indice rapido in alto.
3. Per casi complessi passa al documento enterprise esteso.
4. Alla fine aggiorna il ticket con evidenze, validazione e rischio residuo.
