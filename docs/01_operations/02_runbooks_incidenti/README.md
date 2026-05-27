# Procedure Operative DBA Oracle 19c

Runbook pronti per uso quotidiano e incidenti. Ogni procedura deve essere letta con questo ordine: casi frequenti, prerequisiti, comandi, validazioni, rollback o piano di rientro.

- Navigazione avanzata: [Indice Centrale Runbook + Top20](./INDICE_CENTRALE_RUNBOOK_TOP20.md)
- Punto di ingresso incidenti: [00 Triage Incidenti Oracle](./00_TRIAGE_INCIDENTI_ORACLE.md)
- Decision tree generale: [Troubleshooting Decision Tree](../../04_governance_learning/02_enterprise_standards/TROUBLESHOOTING_DECISION_TREE.md)
- Gap analysis copertura DBA: [24 Gap Analysis Copertura Runbook](./24_GAP_ANALYSIS_COPERTURA_DBA.md)
- Script pronti per scenario: [03_scripts_pronti](../03_scripts_pronti/README.md)

## Priorita operativa: cosa aprire prima

1. [00 Triage Incidenti Oracle](./00_TRIAGE_INCIDENTI_ORACLE.md) - scegli il runbook corretto partendo dal sintomo.
2. [01 Morning Health Check](./01_MORNING_HEALTH_CHECK.md) - stato generale DB/RAC/DG/spazio/job.
3. [08 ORA-Errors Comuni](./08_ORA_ERRORS.md) - mappa rapida errore ORA -> causa -> runbook.
4. [06 Tablespace Pieno](./06_TABLESPACE_PIENO.md) - spazio permanente, TEMP, UNDO.
5. [04 Lock e Sessioni Bloccate](./04_LOCK_SESSIONI_BLOCCATE.md) - applicazione bloccata.
6. [05 Query Lenta](./05_QUERY_LENTA.md) - SQL_ID, piano, ASH/AWR.
7. [07 CPU Alta](./07_CPU_ALTA.md) - CPU host/DB, hard parse, parallelismo.
8. [02 Verifica Backup RMAN](./02_VERIFICA_BACKUP.md) - ultimo backup e restore evidence.
9. [03 Check Data Guard](./03_CHECK_DATAGUARD.md) - lag, gap, broker, role.
10. [22 RMAN + Data Guard Recovery/DR](./22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) - crash, drop, corruption, failover, PITR.
11. [23 SQL Tuning Enterprise](./23_SQL_TUNING_CASI_ENTERPRISE.md) - catalogo esteso di casi SQL tuning.

## Cheat Sheet specialistiche

- [RMAN Full Cheatsheet](../01_cheat_sheets/RMAN_FULL_CHEATSHEET.md)
- [RMAN Essentials](../01_cheat_sheets/CHEAT_SHEET_RMAN_ESSENZIALE.md)
- [DGMGRL](../01_cheat_sheets/CHEAT_SHEET_DGMGRL.md)
- [GoldenGate](../01_cheat_sheets/CHEAT_SHEET_GOLDENGATE.md)
- [ADRCI + Diagnostica Oracle](../../02_core_dba/03_performance_and_diagnostics/GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md)

## Indice procedure

### Giornaliere

| # | Procedura | Quando |
|---|---|---|
| 00 | [Triage Incidenti Oracle](./00_TRIAGE_INCIDENTI_ORACLE.md) | Prima di scegliere il runbook in caso di alert/ticket |
| 01 | [Morning Health Check](./01_MORNING_HEALTH_CHECK.md) | Ogni mattina |
| 02 | [Verifica Backup RMAN](./02_VERIFICA_BACKUP.md) | Ogni mattina dopo il backup |
| 03 | [Check Data Guard](./03_CHECK_DATAGUARD.md) | Ogni mattina e dopo incidenti |

### Su incidente o ticket

| # | Procedura | Quando |
|---|---|---|
| 04 | [Lock e Sessioni Bloccate](./04_LOCK_SESSIONI_BLOCCATE.md) | Applicazione bloccata |
| 05 | [Query Lenta](./05_QUERY_LENTA.md) | SQL lento o regressione |
| 06 | [Tablespace Pieno](./06_TABLESPACE_PIENO.md) | Tablespace oltre soglia |
| 07 | [CPU Alta](./07_CPU_ALTA.md) | CPU sopra soglia |
| 08 | [ORA-Errors Comuni](./08_ORA_ERRORS.md) | Errore ORA generico |
| 16 | [Resize TEMP](./16_RESIZE_TEMP.md) | TEMP piena o ORA-01652 |
| 17 | [Purge Log Oracle](./17_PURGE_LOG_ORACLE.md) | FRA/diag/audit/log pieni |
| 19 | [Diagnosi RMAN e DR](./19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) | Backup fallito o restore senza backup valido |
| 21 | [Gestione DB Link](./21_GESTIONE_DB_LINK.md) | DB link rotto/lento o post-clone |
| 22 | [Casi RMAN + Data Guard Recovery/DR](./22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) | Crash, perdita dati, corruzione, failover, switchover |
| 23 | [Casi SQL Tuning Enterprise](./23_SQL_TUNING_CASI_ENTERPRISE.md) | SQL tuning avanzato, AWR/ASH/SPM/optimizer |

### Manutenzione pianificata

| # | Procedura | Quando |
|---|---|---|
| 09 | [Gestione Utenti e Privilegi](./09_GESTIONE_UTENTI.md) | Creazione, modifica, revoca accessi |
| 10 | [Start/Stop Database RAC](./10_START_STOP_RAC.md) | Manutenzione DB/RAC |
| 13 | [Refresh Ambiente di Test](./13_REFRESH_SCHEMA_TEST.md) | Refresh schema test |
| 20 | [Export/Import Prod-Preprod](./20_EXPORT_IMPORT_PROD_PREPROD.md) | Refresh enterprise con Data Pump |
| 14 | [Chaos Network Partition Data Guard](./14_CHAOS_NETWORK_PARTITION_DATAGUARD.md) | Drill laboratorio resilienza |
| 15 | [Checkmk Agent TLS + SMART/RAID](./15_CHECKMK_AGENT_TLS_SMART_RAID_TROUBLESHOOTING.md) | Onboarding o troubleshooting monitoraggio |

### Review periodiche

| # | Procedura | Quando |
|---|---|---|
| 11 | [Review AWR Settimanale](./11_REVIEW_AWR.md) | Review settimanale performance |
| 12 | [Capacity Planning e Limiti](./12_CAPACITY_PLANNING_LIMITI.md) | Review mensile spazio/limiti |
| 18 | [Gestione Statistiche Optimizer](./18_GESTIONE_STATISTICHE_OPTIMIZER.md) | Review statistiche o regressioni |
| 24 | [Gap Analysis Copertura Runbook](./24_GAP_ANALYSIS_COPERTURA_DBA.md) | Pianificazione miglioramenti repository |

## Come usare i runbook

1. Parti da [00 Triage Incidenti Oracle](./00_TRIAGE_INCIDENTI_ORACLE.md) se non sai quale procedura aprire.
2. Nei file lunghi usa sempre l'indice operativo in alto.
3. Raccogli evidenze prima del fix.
4. Esegui validazione finale.
5. Documenta comandi, orari, esito e rischio residuo nel ticket.

Regola d'oro: in produzione non eseguire comandi distruttivi senza backup/evidenza, impatto dichiarato e approvazione.
