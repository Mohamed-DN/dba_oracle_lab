# Catalogo Script Studio AI - Raggruppamento e Top 20 per Categoria

Questo catalogo organizza gli script presenti in `studio_ai/` per categoria operativa, con una selezione "Top 20" dove possibile.

Data catalogazione: 13 marzo 2026  
Perimetro script conteggiati: `.sql`, `.sh`, `.pl`, `.py`, `.ksh`, `.ps1`

## 1) Sintesi volumi per categoria

| Categoria | Script totali | Nota |
|---|---:|---|
| `01_asm_storage` | 14 | Tutti elencati (meno di 20) |
| `02_dataguard` | 0 | Solo runbook `.md` |
| `03_monitoring_scripts` | 581 | Top 20 operativo estratto |
| `04_user_management` | 0 | Template `.txt` |
| `05_patching` | 0 | Runbook `.md` + template `.txt` |
| `06_backup_recovery` | 10 | Tutti elencati (meno di 20) |
| `07_performance_tuning` | 220 | Top 20 operativo estratto |
| `08_tde_security` | 8 | Tutti elencati (meno di 20) |
| `09_compression` | 1 | Tutto elencato |
| `10_partition_manager` | 2 | Tutto elencato |
| `11_sql_templates` | 17 | Tutti elencati (meno di 20) |
| `12_utilities` | 99 | Top 20 operativo estratto |

## 2) Criterio di selezione Top

Gli script in Top sono scelti con priorita su:

1. utilita quotidiana in troubleshooting/operations
2. copertura end-to-end dei casi principali della categoria
3. riuso nel lab RAC + Data Guard + GoldenGate
4. basso rischio di uso (query/report prima di script invasivi)

## 3) Raggruppamento e Top script per categoria

## 01_asm_storage (Top 14/20)

Raggruppamento operativo:
- inventario e stato ASM
- performance e hot spot
- extent/layout
- file e failgroup

| # | Script | Uso principale |
|---|---|---|
| 1 | [asm_diskgroups.sql](./01_asm_storage/community_scripts/asm_diskgroups.sql) | stato e spazio diskgroup |
| 2 | [asm_disks.sql](./01_asm_storage/community_scripts/asm_disks.sql) | inventario dischi ASM |
| 3 | [asm_diskgroup_attributes.sql](./01_asm_storage/community_scripts/asm_diskgroup_attributes.sql) | attributi DG (`au_size`, compatibilita) |
| 4 | [asm_diskgroup_templates.sql](./01_asm_storage/community_scripts/asm_diskgroup_templates.sql) | template ridondanza/striping |
| 5 | [asm_disk_stats.sql](./01_asm_storage/community_scripts/asm_disk_stats.sql) | metriche I/O per disco |
| 6 | [asm-diskgroup-stat.sql](./01_asm_storage/community_scripts/asm-diskgroup-stat.sql) | KPI sintetici diskgroup |
| 7 | [asm_disk_errors.sql](./01_asm_storage/community_scripts/asm_disk_errors.sql) | errori disco e stato |
| 8 | [asm_extent_distribution.sql](./01_asm_storage/community_scripts/asm_extent_distribution.sql) | distribuzione extent |
| 9 | [asm_extent_multi_au.sql](./01_asm_storage/community_scripts/asm_extent_multi_au.sql) | analisi extent multi-AU |
| 10 | [asm_failgroup_members.sql](./01_asm_storage/community_scripts/asm_failgroup_members.sql) | mapping failgroup |
| 11 | [asm_files.sql](./01_asm_storage/community_scripts/asm_files.sql) | elenco file ASM |
| 12 | [asm_files_path.sql](./01_asm_storage/community_scripts/asm_files_path.sql) | path/logical file map |
| 13 | [asm_partners.sql](./01_asm_storage/community_scripts/asm_partners.sql) | partner/failure alignment |
| 14 | [asm_copyblock.sql](./01_asm_storage/community_scripts/asm_copyblock.sql) | utility blocchi ASM |

## 02_dataguard (runbook)

Categoria documentale: non contiene script `.sql/.sh` pronti.

Top runbook:
1. [configurazione_dataguard.md](./02_dataguard/configurazione_dataguard.md)
2. [active_dataguard.md](./02_dataguard/active_dataguard.md)
3. [verifica_gap.md](./02_dataguard/verifica_gap.md)
4. [service_read_only.md](./02_dataguard/service_read_only.md)
5. [recovery_post_reboot.md](./02_dataguard/recovery_post_reboot.md)

## 03_monitoring_scripts (Top 20/20 su 581)

Raggruppamento operativo:
- sessioni e lock
- CPU/I-O/waits
- ASH real-time
- SQL tuning rapido

| # | Script | Uso principale |
|---|---|---|
| 1 | [ViewSession.sql](./03_monitoring_scripts/ViewSession.sql) | snapshot sessioni attive |
| 2 | [View_Blocking.sql](./03_monitoring_scripts/View_Blocking.sql) | blocking tree rapido |
| 3 | [locks.sql](./03_monitoring_scripts/locks.sql) | lock attivi |
| 4 | [locks_blocking.sql](./03_monitoring_scripts/locks_blocking.sql) | lock bloccanti |
| 5 | [locks_details.sql](./03_monitoring_scripts/locks_details.sql) | dettaglio lock e oggetti |
| 6 | [Check_Lock.sql](./03_monitoring_scripts/Check_Lock.sql) | controllo lock veloce |
| 7 | [View_Cpu_Consumer.sql](./03_monitoring_scripts/View_Cpu_Consumer.sql) | top CPU consumer |
| 8 | [View_Cpu_Hist.sql](./03_monitoring_scripts/View_Cpu_Hist.sql) | trend CPU |
| 9 | [View_IO_RealTime.sql](./03_monitoring_scripts/View_IO_RealTime.sql) | I/O realtime |
| 10 | [View_IO_Hist.sql](./03_monitoring_scripts/View_IO_Hist.sql) | storico I/O |
| 11 | [IO_WaitTimeDetails.sql](./03_monitoring_scripts/IO_WaitTimeDetails.sql) | wait I/O dettagliato |
| 12 | [Event_statistics.sql](./03_monitoring_scripts/Event_statistics.sql) | top wait/event |
| 13 | [ASH.sql](./03_monitoring_scripts/ASH.sql) | ASH base |
| 14 | [ActiveSessionHistoryQueries.sql](./03_monitoring_scripts/ActiveSessionHistoryQueries.sql) | query ASH avanzate |
| 15 | [AshTopSql.sql](./03_monitoring_scripts/AshTopSql.sql) | top SQL in ASH |
| 16 | [AshTopSession.sql](./03_monitoring_scripts/AshTopSession.sql) | top sessioni in ASH |
| 17 | [AshTopProcedure.sql](./03_monitoring_scripts/AshTopProcedure.sql) | top PL/SQL in ASH |
| 18 | [SQL Plan Change.sql](./03_monitoring_scripts/SQL Plan Change.sql) | cambi plan hash |
| 19 | [SQL Stats.sql](./03_monitoring_scripts/SQL Stats.sql) | statistiche SQL |
| 20 | [View_UnstablePlan.sql](./03_monitoring_scripts/View_UnstablePlan.sql) | rileva piani instabili |

Nota: la cartella include anche i pack `community_gwenshap` e `community_jkstill` con molte utility specialistiche.

## 04_user_management (template operativi)

Categoria template: non contiene script `.sql/.sh` pronti.

Top template:
1. [Prototipo_CreateUser_Nominale_v1.4.txt](./04_user_management/Prototipo_CreateUser_Nominale_v1.4.txt)
2. [Prototipo_CreateUser_DBA_OP_v1.3.txt](./04_user_management/Prototipo_CreateUser_DBA_OP_v1.3.txt)
3. [Prototipo_CreateUser_DB_APPLICATIVA_v1.3.txt](./04_user_management/Prototipo_CreateUser_DB_APPLICATIVA_v1.3.txt)
4. [Verify Function PWD.txt](./04_user_management/Verify%20Function%20PWD.txt)
5. [GeneraPass_Random_da_Bash.txt](./04_user_management/GeneraPass_Random_da_Bash.txt)

## 05_patching (runbook)

Categoria documentale: non contiene script `.sql/.sh` pronti.

Top runbook/template:
1. [golden_images_ohctl.md](./05_patching/golden_images_ohctl.md)
2. [golden_images_ohctl.txt](./05_patching/golden_images_ohctl.txt)
3. [patching_grid_12c.md](./05_patching/patching_grid_12c.md)
4. [setoh.txt](./05_patching/setoh.txt)
5. [support_notes.md](./05_patching/support_notes.md)

## 06_backup_recovery (Top 10/20)

Raggruppamento operativo:
- flashback e restore point
- stato backup RMAN
- recovery SCN e controllo data loss

| # | Script | Uso principale |
|---|---|---|
| 1 | [Flashback_restore_point.sql](./06_backup_recovery/Flashback_restore_point.sql) | gestione restore point |
| 2 | [FLASHBACK_RESTORPOINT.sql](./06_backup_recovery/FLASHBACK_RESTORPOINT.sql) | variante restore point |
| 3 | [fra_config.sql](./06_backup_recovery/community_scripts/fra_config.sql) | stato/config FRA |
| 4 | [incarnations.sql](./06_backup_recovery/community_scripts/incarnations.sql) | elenco incarnazioni DB |
| 5 | [rman-bkup-status.sql](./06_backup_recovery/community_scripts/rman-bkup-status.sql) | stato backup RMAN |
| 6 | [rman-bkup-details.sql](./06_backup_recovery/community_scripts/rman-bkup-details.sql) | dettaglio job RMAN |
| 7 | [rman-recovery-scn.sql](./06_backup_recovery/community_scripts/rman-recovery-scn.sql) | SCN recovery point |
| 8 | [rman-recovery-min-scn.sql](./06_backup_recovery/community_scripts/rman-recovery-min-scn.sql) | minimo SCN recuperabile |
| 9 | [unrecoverable-files.sql](./06_backup_recovery/community_scripts/unrecoverable-files.sql) | file non recoverable |
| 10 | [restore-sqlplus-settings.sql](./06_backup_recovery/community_scripts/restore-sqlplus-settings.sql) | reset ambiente SQL*Plus |

## 07_performance_tuning (Top 20/20 su 220)

Raggruppamento operativo:
- AAS/ASH/AWR (analisi carico)
- memory sizing
- SQL tuning

| # | Script | Uso principale |
|---|---|---|
| 1 | [aas.sql](./07_performance_tuning/community_scripts/ash_awr/aas.sql) | Average Active Sessions |
| 2 | [aas-ash-calc.sql](./07_performance_tuning/community_scripts/ash_awr/aas-ash-calc.sql) | AAS da ASH |
| 3 | [aas-awr-calc.sql](./07_performance_tuning/community_scripts/ash_awr/aas-awr-calc.sql) | AAS da AWR |
| 4 | [ash-current-waits.sql](./07_performance_tuning/community_scripts/ash_awr/ash-current-waits.sql) | wait attuali |
| 5 | [ash-current-waits-by-sql-event.sql](./07_performance_tuning/community_scripts/ash_awr/ash-current-waits-by-sql-event.sql) | wait per SQL/evento |
| 6 | [ash_top_sql.sql](./07_performance_tuning/community_scripts/ash_awr/ash_top_sql.sql) | top SQL ASH |
| 7 | [ash_top_session.sql](./07_performance_tuning/community_scripts/ash_awr/ash_top_session.sql) | top sessioni ASH |
| 8 | [ash_top_procedure.sql](./07_performance_tuning/community_scripts/ash_awr/ash_top_procedure.sql) | top procedure |
| 9 | [awr-top-events.sql](./07_performance_tuning/community_scripts/ash_awr/awr-top-events.sql) | top eventi AWR |
| 10 | [awr-top-10-daily.sql](./07_performance_tuning/community_scripts/ash_awr/awr-top-10-daily.sql) | trend giornaliero AWR |
| 11 | [top10-sql-awr.sql](./07_performance_tuning/community_scripts/ash_awr/top10-sql-awr.sql) | top SQL AWR |
| 12 | [top10-sql-ash.sql](./07_performance_tuning/community_scripts/ash_awr/top10-sql-ash.sql) | top SQL ASH |
| 13 | [pga_advice.sql](./07_performance_tuning/community_scripts/memory/pga_advice.sql) | sizing PGA advisor |
| 14 | [pga_workarea_active.sql](./07_performance_tuning/community_scripts/memory/pga_workarea_active.sql) | workarea attive |
| 15 | [shared_pool_advice.sql](./07_performance_tuning/community_scripts/memory/shared_pool_advice.sql) | sizing shared pool |
| 16 | [shared-pool-top-sql.sql](./07_performance_tuning/community_scripts/memory/shared-pool-top-sql.sql) | top SQL in shared pool |
| 17 | [showsga.sql](./07_performance_tuning/community_scripts/memory/showsga.sql) | riepilogo SGA |
| 18 | [find-expensive-sql.sql](./07_performance_tuning/community_scripts/tuning/find-expensive-sql.sql) | SQL costose |
| 19 | [dbms-sqltune-sqlid.sql](./07_performance_tuning/community_scripts/tuning/dbms-sqltune-sqlid.sql) | SQL Tuning Advisor |
| 20 | [sql-exe-times-awr.sql](./07_performance_tuning/community_scripts/tuning/sql-exe-times-awr.sql) | execution time da AWR |

## 08_tde_security (Top 8/20)

Raggruppamento operativo:
- audit trail e session audit
- controllo flag audit oggetti
- cleanup log audit

| # | Script | Uso principale |
|---|---|---|
| 1 | [audit-actions.sql](./08_tde_security/community_scripts/audit-actions.sql) | mapping azioni audit |
| 2 | [dba_audit_session.sql](./08_tde_security/community_scripts/dba_audit_session.sql) | session audit |
| 3 | [dba_audit_session_recent.sql](./08_tde_security/community_scripts/dba_audit_session_recent.sql) | sessioni recenti |
| 4 | [dba_audit_trail.sql](./08_tde_security/community_scripts/dba_audit_trail.sql) | audit trail completo |
| 5 | [dba_audit_trail_persons.sql](./08_tde_security/community_scripts/dba_audit_trail_persons.sql) | audit trail per utente |
| 6 | [dba_table_audit_flags.sql](./08_tde_security/community_scripts/dba_table_audit_flags.sql) | flag audit per tabella |
| 7 | [show_session_audit.sql](./08_tde_security/community_scripts/show_session_audit.sql) | report session audit |
| 8 | [ua-audit-log-cleanup-job.sql](./08_tde_security/community_scripts/ua-audit-log-cleanup-job.sql) | job cleanup unified audit |

## 09_compression (Top 1/20)

| # | Script | Uso principale |
|---|---|---|
| 1 | [Get_DDL_RENAME_OBJECT_v1.3.sql](./09_compression/Get_DDL_RENAME_OBJECT_v1.3.sql) | DDL support per operazioni di compressione/redefinition |

## 10_partition_manager (Top 2/20)

| # | Script | Uso principale |
|---|---|---|
| 1 | [Script_Creazione_Partition_Manager_v2_36.sql](./10_partition_manager/Script_Creazione_Partition_Manager_v2_36.sql) | installazione package partition manager |
| 2 | [dba_op_user_setup.sql](./10_partition_manager/dba_op_user_setup.sql) | setup utente/privilegi operativi |

## 11_sql_templates (Top 17/20)

Raggruppamento operativo:
- DDL
- DML
- PL/SQL
- grants

| # | Script | Uso principale |
|---|---|---|
| 1 | [00X_Form_create_table.sql](./11_sql_templates/00X_Form_create_table.sql) | template create table |
| 2 | [00X_Form_alter_table.sql](./11_sql_templates/00X_Form_alter_table.sql) | template alter table |
| 3 | [00X_Form_drop_table.sql](./11_sql_templates/00X_Form_drop_table.sql) | template drop table |
| 4 | [00X_Form_create_index.sql](./11_sql_templates/00X_Form_create_index.sql) | template create index |
| 5 | [00X_Form_alter_index.sql](./11_sql_templates/00X_Form_alter_index.sql) | template alter/rebuild index |
| 6 | [00X_Form_create_view.sql](./11_sql_templates/00X_Form_create_view.sql) | template create view |
| 7 | [00X_Form_primary_key.sql](./11_sql_templates/00X_Form_primary_key.sql) | template primary key |
| 8 | [00X_Form_foreign_key.sql](./11_sql_templates/00X_Form_foreign_key.sql) | template foreign key |
| 9 | [00X_Form_dml.sql](./11_sql_templates/00X_Form_dml.sql) | template DML con controlli |
| 10 | [00X_Form_loop_commit.sql](./11_sql_templates/00X_Form_loop_commit.sql) | batch commit controllato |
| 11 | [Form_loop_rowid.sql](./11_sql_templates/Form_loop_rowid.sql) | loop per rowid |
| 12 | [00X_Form_procedure.sql](./11_sql_templates/00X_Form_procedure.sql) | template procedure |
| 13 | [00X_Form_package.sql](./11_sql_templates/00X_Form_package.sql) | template package |
| 14 | [00X_Form_trigger.sql](./11_sql_templates/00X_Form_trigger.sql) | template trigger |
| 15 | [00X_Form_sequence.sql](./11_sql_templates/00X_Form_sequence.sql) | template sequence |
| 16 | [00X_Form_sinonimi.sql](./11_sql_templates/00X_Form_sinonimi.sql) | template sinonimi |
| 17 | [00X_Form_assign_grant.sql](./11_sql_templates/00X_Form_assign_grant.sql) | template grant |

## 12_utilities (Top 20/20 su 99)

Raggruppamento operativo:
- health check host/instance
- scheduler jobs
- storage/TEMP/UNDO
- diagnostica rapida

| # | Script | Uso principale |
|---|---|---|
| 1 | [TEMP_and_UNDO_monitor.sql](./12_utilities/TEMP_and_UNDO_monitor.sql) | monitor TEMP/UNDO |
| 2 | [Job monitoring TEMP e UNDO TABLESPACE.sql](./12_utilities/Job%20monitoring%20TEMP%20e%20UNDO%20TABLESPACE.sql) | job monitor tablespace |
| 3 | [Install_pkg_Dba_Utility_20220713_v1_9_PROD.sql](./12_utilities/Install_pkg_Dba_Utility_20220713_v1_9_PROD.sql) | install utility package |
| 4 | [get-alert-logs.sh](./12_utilities/community_scripts/get-alert-logs.sh) | raccolta alert log |
| 5 | [get-ohomes.sh](./12_utilities/community_scripts/get-ohomes.sh) | inventory Oracle Homes |
| 6 | [get-crsctl.sh](./12_utilities/community_scripts/get-crsctl.sh) | diagnosi Clusterware |
| 7 | [get-lgwr-trace.sh](./12_utilities/community_scripts/get-lgwr-trace.sh) | estrazione trace LGWR |
| 8 | [rman-chk-syntax.sh](./12_utilities/community_scripts/rman-chk-syntax.sh) | check sintassi RMAN |
| 9 | [asm-disk-chk.sh](./12_utilities/community_scripts/asm-disk-chk.sh) | check dischi ASM lato host |
| 10 | [memsz.sh](./12_utilities/community_scripts/memsz.sh) | riepilogo memoria processo |
| 11 | [memsz-all.sh](./12_utilities/community_scripts/memsz-all.sh) | memoria all-process |
| 12 | [oracle-connect-rate.sh](./12_utilities/community_scripts/oracle-connect-rate.sh) | test connect rate |
| 13 | [procmem.pl](./12_utilities/community_scripts/procmem.pl) | memoria processo (perl) |
| 14 | [sga-smallpage-detector.pl](./12_utilities/community_scripts/sga-smallpage-detector.pl) | verifica page allocation SGA |
| 15 | [show-sga-page-allocation.sh](./12_utilities/community_scripts/show-sga-page-allocation.sh) | SGA page map |
| 16 | [show_jobs.sql](./12_utilities/community_scripts/scheduler/show_jobs.sql) | job scheduler rapidi |
| 17 | [dba_jobs_running.sql](./12_utilities/community_scripts/scheduler/dba_jobs_running.sql) | job in esecuzione |
| 18 | [dba_sched_jobs.sql](./12_utilities/community_scripts/scheduler/dba_sched_jobs.sql) | catalogo scheduler jobs |
| 19 | [showspace.sql](./12_utilities/community_scripts/storage/showspace.sql) | analisi spazio oggetti |
| 20 | [show-pdbs.sql](./12_utilities/community_scripts/cdb_pdb/show-pdbs.sql) | elenco PDB operativo |

## 4) Uso pratico consigliato

Routine minima giornaliera (15-20 min):

1. `03_monitoring_scripts`: sessioni/lock + CPU/I-O
2. `07_performance_tuning`: top SQL ASH/AWR
3. `12_utilities`: job scheduler + TEMP/UNDO

Routine settimanale:

1. `06_backup_recovery`: stato RMAN/FRA
2. `08_tde_security`: audit session trail e cleanup
3. `01_asm_storage`: salute diskgroup/dischi

## 5) Nota di manutenzione catalogo

Se aggiungi nuovi script, aggiorna:

1. questo catalogo (`CATALOGO_SCRIPT_TOP20_PER_CATEGORIA.md`)
2. il README della categoria impattata
3. il README principale di `studio_ai` (se cambia la navigazione)

