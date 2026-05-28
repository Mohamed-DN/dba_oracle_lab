# Script pronti DBA Oracle 19c

Raccolta di script SQL pronti per diagnosi rapida. Gli script non sostituiscono i runbook: servono come acceleratore operativo dopo aver scelto lo scenario corretto.

Molti script sono RAC-aware: quando vedi `INST_ID`, non ragionare piu' solo su `SID/SERIAL#`. Per kill session, longops, Data Pump, RMAN e lock cross-instance usa sempre anche l'istanza corretta.

## Ordine consigliato

1. Parti dal [Triage Incidenti Oracle](../02_runbooks_incidenti/00_TRIAGE_INCIDENTI_ORACLE.md).
2. Apri il runbook dello scenario.
3. Usa lo script pronto collegato per raccogliere evidenze.
4. Se l'incidente e complesso, passa alla [libreria completa script](../04_libreria_script_completa/README.md) o al [Top 100 Script DBA](../../02_core_dba/03_performance_and_diagnostics/TOP_100_SCRIPT_DBA.md).

## Regole di sicurezza

- Non eseguire sezioni correttive senza leggere i commenti e verificare ambiente, ruolo database e impatto.
- Non incollare password nei comandi: usare wallet, OS authentication, prompt interattivo o credenziali gestite.
- Prima di delete, purge, kill session, resize o change strutturale, allegare evidenza al ticket.
- In Data Guard/RMAN verificare sempre archivelog, standby apply e backup prima di cancellare file.

## Indice script -> runbook

| # | Script | Quando usarlo | Runbook collegati |
|---|---|---|---|
| 01 | [Tablespace e datafile](./01_tablespace_datafile.sql) | diagnosi tablespace pieni, datafile, autoextend, maxsize, bigfile/smallfile | [06_TABLESPACE_PIENO](../02_runbooks_incidenti/06_TABLESPACE_PIENO.md), [12_CAPACITY_PLANNING_LIMITI](../02_runbooks_incidenti/12_CAPACITY_PLANNING_LIMITI.md), [08_ORA_ERRORS](../02_runbooks_incidenti/08_ORA_ERRORS.md) |
| 02 | [UNDO e TEMP](./02_undo_temp.sql) | diagnosi ORA-01555, ORA-30036, ORA-01652, consumo TEMP/UNDO | [06_TABLESPACE_PIENO](../02_runbooks_incidenti/06_TABLESPACE_PIENO.md), [16_RESIZE_TEMP](../02_runbooks_incidenti/16_RESIZE_TEMP.md), [23_SQL_TUNING_CASI_ENTERPRISE](../02_runbooks_incidenti/23_SQL_TUNING_CASI_ENTERPRISE.md) |
| 03 | [FRA e archivelog](./03_fra_archivelog.sql) | diagnosi FRA piena, archivelog, ORA-19809, ORA-00257 | [17_PURGE_LOG_ORACLE](../02_runbooks_incidenti/17_PURGE_LOG_ORACLE.md), [19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP](../02_runbooks_incidenti/19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md), [22_RMAN_DATAGUARD_CASI_RECOVERY_DR](../02_runbooks_incidenti/22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) |
| 04 | [Data Pump operativo](./04_datapump_operativo.sql) | precheck, monitoraggio e template expdp/impdp senza password in chiaro | [20_EXPORT_IMPORT_PROD_PREPROD](../02_runbooks_incidenti/20_EXPORT_IMPORT_PROD_PREPROD.md), [13_REFRESH_SCHEMA_TEST](../02_runbooks_incidenti/13_REFRESH_SCHEMA_TEST.md) |
| 05 | [ASM storage](./05_asm_storage.sql) | diskgroup, dischi ASM, AU size, capacity e limiti fisici | [12_CAPACITY_PLANNING_LIMITI](../02_runbooks_incidenti/12_CAPACITY_PLANNING_LIMITI.md), [24_GAP_ANALYSIS_COPERTURA_DBA](../02_runbooks_incidenti/24_GAP_ANALYSIS_COPERTURA_DBA.md) |
| 06 | [Sessioni e lock](./06_sessioni_lock.sql) | sessioni attive, blocker/waiter, DDL lock, kill command generator | [04_LOCK_SESSIONI_BLOCCATE](../02_runbooks_incidenti/04_LOCK_SESSIONI_BLOCCATE.md), [07_CPU_ALTA](../02_runbooks_incidenti/07_CPU_ALTA.md), [08_ORA_ERRORS](../02_runbooks_incidenti/08_ORA_ERRORS.md) |
| 07 | [Performance quick](./07_performance_quick.sql) | top SQL, wait event, ASH real-time, piani SQL | [05_QUERY_LENTA](../02_runbooks_incidenti/05_QUERY_LENTA.md), [07_CPU_ALTA](../02_runbooks_incidenti/07_CPU_ALTA.md), [11_REVIEW_AWR](../02_runbooks_incidenti/11_REVIEW_AWR.md) |
| 08 | [RMAN backup status](./08_rman_backup_status.sql) | ultimo backup, backup falliti, config RMAN, archivelog non backuppati | [02_VERIFICA_BACKUP](../02_runbooks_incidenti/02_VERIFICA_BACKUP.md), [19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP](../02_runbooks_incidenti/19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md), [22_RMAN_DATAGUARD_CASI_RECOVERY_DR](../02_runbooks_incidenti/22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) |
| 09 | [Data Guard status](./09_dataguard_status.sql) | ruolo DB, transport/apply lag, gap, MRP, switchover readiness | [03_CHECK_DATAGUARD](../02_runbooks_incidenti/03_CHECK_DATAGUARD.md), [14_CHAOS_NETWORK_PARTITION_DATAGUARD](../02_runbooks_incidenti/14_CHAOS_NETWORK_PARTITION_DATAGUARD.md), [22_RMAN_DATAGUARD_CASI_RECOVERY_DR](../02_runbooks_incidenti/22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) |
| 10 | [Oggetti e schema](./10_oggetti_schema.sql) | invalidi, segmenti grandi, indici, recyclebin, oggetti schema | [09_GESTIONE_UTENTI](../02_runbooks_incidenti/09_GESTIONE_UTENTI.md), [13_REFRESH_SCHEMA_TEST](../02_runbooks_incidenti/13_REFRESH_SCHEMA_TEST.md), [20_EXPORT_IMPORT_PROD_PREPROD](../02_runbooks_incidenti/20_EXPORT_IMPORT_PROD_PREPROD.md) |
| 11 | [TEMP resize e capacity](./11_temp_resize.sql) | diagnosi TEMP e tempfile per ORA-01652 | [16_RESIZE_TEMP](../02_runbooks_incidenti/16_RESIZE_TEMP.md), [06_TABLESPACE_PIENO](../02_runbooks_incidenti/06_TABLESPACE_PIENO.md) |
| 12 | [Log purge e audit](./12_log_purge_audit.sql) | FRA, unified audit cleanup, audit recenti | [17_PURGE_LOG_ORACLE](../02_runbooks_incidenti/17_PURGE_LOG_ORACLE.md) |
| 13 | [Monitor DDL package](./13_monitor_ddl_package.sql) | audit operativo DDL con tabella, package e trigger | [09_GESTIONE_UTENTI](../02_runbooks_incidenti/09_GESTIONE_UTENTI.md), [24_GAP_ANALYSIS_COPERTURA_DBA](../02_runbooks_incidenti/24_GAP_ANALYSIS_COPERTURA_DBA.md) |
| 14 | [Optimizer stats operations](./14_optimizer_stats.sql) | stale stats, gather database/table mirato | [18_GESTIONE_STATISTICHE_OPTIMIZER](../02_runbooks_incidenti/18_GESTIONE_STATISTICHE_OPTIMIZER.md), [05_QUERY_LENTA](../02_runbooks_incidenti/05_QUERY_LENTA.md), [23_SQL_TUNING_CASI_ENTERPRISE](../02_runbooks_incidenti/23_SQL_TUNING_CASI_ENTERPRISE.md) |
| 15 | [RAC global health](./15_rac_global_health.sql) | istanze, servizi, sessioni per istanza, blocker cross-instance, top SQL GV$, gc/ges wait, longops | [00_TRIAGE_INCIDENTI_ORACLE](../02_runbooks_incidenti/00_TRIAGE_INCIDENTI_ORACLE.md), [10_START_STOP_RAC](../02_runbooks_incidenti/10_START_STOP_RAC.md), [26_LISTENER_SCAN_SERVICES_RAC](../02_runbooks_incidenti/26_LISTENER_SCAN_SERVICES_RAC.md) |

## Esecuzione standard

```bash
cd docs/01_operations/03_scripts_pronti
sqlplus / as sysdba @07_performance_quick.sql
```

Per spool evidence:

```sql
SPOOL evidence_&&_CONNECT_IDENTIFIER._diagnosi.log
@07_performance_quick.sql
SPOOL OFF
```

## Escalation

- Script rapidi: questa cartella.
- Diagnosi enterprise: [libreria completa script](../04_libreria_script_completa/README.md).
- ADR e alert log: [Guida ADRCI](../../02_core_dba/03_performance_and_diagnostics/GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md).
- Recovery/DR: [RMAN + Data Guard casi enterprise](../02_runbooks_incidenti/22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md).
- SQL tuning: [SQL Tuning casi enterprise](../02_runbooks_incidenti/23_SQL_TUNING_CASI_ENTERPRISE.md).
- Storage LUN/ASM/udev/ASMLib/AFD: [Guida storage enterprise](../../02_core_dba/01_administration_and_security/GUIDA_STORAGE_LUN_LVM_UDEV_ASM_ASMLIB_AFD.md).
