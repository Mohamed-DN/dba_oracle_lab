# Procedure Operative DBA Oracle 19c

Runbook pronti per uso quotidiano e incidenti. Ogni procedura deve essere letta con questo ordine: casi frequenti, prerequisiti, comandi, validazioni, rollback o piano di rientro.

- Navigazione avanzata: [Indice Centrale Runbook + Top20](./INDICE_CENTRALE_RUNBOOK_TOP20.md)
- Punto di ingresso incidenti: [00 Triage Incidenti Oracle](./RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md)
- Decision tree generale: [Troubleshooting Decision Tree](../../04_governance_learning/02_enterprise_standards/TROUBLESHOOTING_DECISION_TREE.md)
- Gap analysis copertura DBA: [24 Gap Analysis Copertura Runbook](./RUNBOOK_24_GAP_ANALYSIS_COPERTURA_DBA.md)
- Script pronti per scenario: [03_scripts_pronti](../03_scripts_pronti/README.md)

## Priorita operativa: cosa aprire prima

1. [00 Triage Incidenti Oracle](./RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md) - scegli il runbook corretto partendo dal sintomo.
2. [01 Morning Health Check](./RUNBOOK_01_MORNING_HEALTH_CHECK.md) - stato generale DB/RAC/DG/spazio/job.
3. [08 ORA-Errors Comuni](./RUNBOOK_08_ORA_ERRORS.md) - mappa rapida errore ORA -> causa -> runbook.
4. [06 Tablespace Pieno](./RUNBOOK_06_TABLESPACE_PIENO.md) - spazio permanente, TEMP, UNDO.
5. [04 Lock e Sessioni Bloccate](./RUNBOOK_04_LOCK_SESSIONI_BLOCCATE.md) - applicazione bloccata.
6. [05 Query Lenta](./RUNBOOK_05_QUERY_LENTA.md) - SQL_ID, piano, ASH/AWR.
7. [07 CPU Alta](./RUNBOOK_07_CPU_ALTA.md) - CPU host/DB, hard parse, parallelismo.
8. [02 Verifica Backup RMAN](./RUNBOOK_02_VERIFICA_BACKUP.md) - ultimo backup e restore evidence.
9. [03 Check Data Guard](./RUNBOOK_03_CHECK_DATAGUARD.md) - lag, gap, broker, role.
10. [22 RMAN + Data Guard Recovery/DR](./RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) - crash, drop, corruption, failover, PITR.
11. [25 ASM Storage Incidenti](./RUNBOOK_25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md) - diskgroup, dischi, rebalance, ORA-150xx.
12. [26 Listener/SCAN/Services RAC](./RUNBOOK_26_LISTENER_SCAN_SERVICES_RAC.md) - ORA-125xx, servizi RAC, registrazione listener.
13. [23 SQL Tuning Enterprise](./RUNBOOK_23_SQL_TUNING_CASI_ENTERPRISE.md) - catalogo esteso di casi SQL tuning.

## Cheat Sheet specialistiche

- [RMAN Full Cheatsheet](../01_cheat_sheets/CS_RMAN_RAPIDO.md)
- [RMAN Essentials](../01_cheat_sheets/CS_RMAN_RAPIDO.md)
- [DGMGRL](../01_cheat_sheets/CS_DGMGRL.md)
- [GoldenGate](../01_cheat_sheets/CS_GOLDENGATE.md)
- [ADRCI + Diagnostica Oracle](../../02_core_dba/03_performance_and_diagnostics/GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md)

## Indice procedure

### Giornaliere

| # | Procedura | Quando |
|---|---|---|
| 00 | [Triage Incidenti Oracle](./RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md) | Prima di scegliere il runbook in caso di alert/ticket |
| 01 | [Morning Health Check](./RUNBOOK_01_MORNING_HEALTH_CHECK.md) | Ogni mattina |
| 02 | [Verifica Backup RMAN](./RUNBOOK_02_VERIFICA_BACKUP.md) | Ogni mattina dopo il backup |
| 03 | [Check Data Guard](./RUNBOOK_03_CHECK_DATAGUARD.md) | Ogni mattina e dopo incidenti |

### Su incidente o ticket

| # | Procedura | Quando |
|---|---|---|
| 04 | [Lock e Sessioni Bloccate](./RUNBOOK_04_LOCK_SESSIONI_BLOCCATE.md) | Applicazione bloccata |
| 05 | [Query Lenta](./RUNBOOK_05_QUERY_LENTA.md) | SQL lento o regressione |
| 06 | [Tablespace Pieno](./RUNBOOK_06_TABLESPACE_PIENO.md) | Tablespace oltre soglia |
| 07 | [CPU Alta](./RUNBOOK_07_CPU_ALTA.md) | CPU sopra soglia |
| 08 | [ORA-Errors Comuni](./RUNBOOK_08_ORA_ERRORS.md) | Errore ORA generico |
| 16 | [Resize TEMP](./RUNBOOK_16_RESIZE_TEMP.md) | TEMP piena o ORA-01652 |
| 17 | [Purge Log Oracle](./RUNBOOK_17_PURGE_LOG_ORACLE.md) | FRA/diag/audit/log pieni |
| 19 | [Diagnosi RMAN e DR](./RUNBOOK_19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) | Backup fallito o restore senza backup valido |
| 21 | [Gestione DB Link](./RUNBOOK_21_GESTIONE_DB_LINK.md) | DB link rotto/lento o post-clone |
| 22 | [Casi RMAN + Data Guard Recovery/DR](./RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) | Crash, perdita dati, corruzione, failover, switchover |
| 23 | [Casi SQL Tuning Enterprise](./RUNBOOK_23_SQL_TUNING_CASI_ENTERPRISE.md) | SQL tuning avanzato, AWR/ASH/SPM/optimizer |
| 25 | [ASM Storage Incidenti](./RUNBOOK_25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md) | Diskgroup pieno, dischi offline, rebalance, ORA-150xx |
| 26 | [Listener, SCAN e Services RAC](./RUNBOOK_26_LISTENER_SCAN_SERVICES_RAC.md) | ORA-12514/12541/12154, service non registrato, failover servizi |
| 27 | [TDE Wallet/Keystore](./RUNBOOK_27_TDE_WALLET_KEYSTORE_RUNBOOK.md) | Wallet chiuso, restore cifrato, backup keystore |
| 28 | [Scheduler Jobs e AutoTask](./RUNBOOK_28_SCHEDULER_JOBS_AUTOTASKS_RUNBOOK.md) | Job falliti, job bloccati, maintenance window, AutoTask |
| 31 | [GoldenGate Incident Runbook](./RUNBOOK_31_GOLDENGATE_INCIDENT_RUNBOOK.md) | Extract/Replicat abended, lag, trail pieno, archive mancanti |
| 32 | [Enterprise Manager Alert Handling](./RUNBOOK_32_ENTERPRISE_MANAGER_ALERT_RUNBOOK.md) | Alert OEM/EM da trasformare in runbook ed evidence |
| 34 | [TCPS Wallet e Certificati](./RUNBOOK_34_TCPS_WALLET_CERTIFICATI.md) | Connessioni TCPS, certificati, wallet client/server |

### Manutenzione pianificata

| # | Procedura | Quando |
|---|---|---|
| 09 | [Gestione Utenti e Privilegi](./RUNBOOK_09_GESTIONE_UTENTI.md) | Creazione, modifica, revoca accessi |
| 10 | [Start/Stop Database RAC](./RUNBOOK_10_START_STOP_RAC.md) | Manutenzione DB/RAC |
| 13 | [Refresh Ambiente di Test](./RUNBOOK_13_REFRESH_SCHEMA_TEST.md) | Refresh schema test |
| 20 | [Export/Import Prod-Preprod](./RUNBOOK_20_EXPORT_IMPORT_PROD_PREPROD.md) | Refresh enterprise con Data Pump |
| 29 | [Patching Oracle RAC/Data Guard](./RUNBOOK_29_PATCHING_ORACLE_RAC_DATAGUARD.md) | RU/RUR, OPatch, datapatch, rolling/non-rolling, DG |
| 30 | [Multitenant CDB/PDB Operations](./RUNBOOK_30_MULTITENANT_PDB_OPERATIONS.md) | Open/close PDB, clone, plug/unplug, restore PDB |
| 14 | [Chaos Network Partition Data Guard](./RUNBOOK_14_CHAOS_NETWORK_PARTITION_DATAGUARD.md) | Drill laboratorio resilienza |
| 15 | [Checkmk Agent TLS + SMART/RAID](./RUNBOOK_15_CHECKMK_AGENT_TLS_SMART_RAID_TROUBLESHOOTING.md) | Onboarding o troubleshooting monitoraggio |

### Review periodiche

| # | Procedura | Quando |
|---|---|---|
| 11 | [Review AWR Settimanale](./RUNBOOK_11_REVIEW_AWR.md) | Review settimanale performance |
| 12 | [Capacity Planning e Limiti](./RUNBOOK_12_CAPACITY_PLANNING_LIMITI.md) | Review mensile spazio/limiti |
| 18 | [Gestione Statistiche Optimizer](./RUNBOOK_18_GESTIONE_STATISTICHE_OPTIMIZER.md) | Review statistiche o regressioni |
| 24 | [Gap Analysis Copertura Runbook](./RUNBOOK_24_GAP_ANALYSIS_COPERTURA_DBA.md) | Pianificazione miglioramenti repository |
| 33 | [Audit, Compliance ed Evidence](./RUNBOOK_33_AUDIT_COMPLIANCE_EVIDENCE.md) | Evidence ticket, audit trail, controlli before/after |
| 35 | [Capacity Forecast Enterprise](./RUNBOOK_35_CAPACITY_FORECAST_ENTERPRISE.md) | Forecast spazio/FRA/ASM/SYSAUX/processi e change preventivi |

## Come usare i runbook

1. Parti da [00 Triage Incidenti Oracle](./RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md) se non sai quale procedura aprire.
2. Nei file lunghi usa sempre l'indice operativo in alto.
3. Raccogli evidenze prima del fix.
4. Esegui validazione finale.
5. Documenta comandi, orari, esito e rischio residuo nel ticket.

Regola d'oro: in produzione non eseguire comandi distruttivi senza backup/evidenza, impatto dichiarato e approvazione.
