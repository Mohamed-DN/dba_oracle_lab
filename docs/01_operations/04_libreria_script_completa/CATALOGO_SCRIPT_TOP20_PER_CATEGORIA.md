# Catalogo Script Studio AI - Raggruppamento e Top 20 per Categoria

Questo catalogo organizza gli script presenti in `libreria_oracle/` per categoria operativa, con una selezione "Top 20" dove possibile.

Data catalogazione: 13 marzo 2026  
Perimetro script conteggiati: `.sql`, `.sh`, `.pl`, `.py`, `.ksh`, `.ps1`

## 1) Sintesi volumi per categoria

| Categoria | Script totali | Nota |
|---|---:|---|
| `asm_storage` | 14 | Tutti elencati (meno di 20) |
| `dataguard` | 0 | Solo runbook `.md` |
| `monitoring_scripts` | 581 | Top 20 operativo estratto |
| `user_management` | 0 | Template `.txt` |
| `patching` | 0 | Runbook `.md` + template `.txt` |
| `backup_recovery` | 10 | Tutti elencati (meno di 20) |
| `performance_tuning` | 220 | Top 20 operativo estratto |
| `tde_security` | 8 | Tutti elencati (meno di 20) |
| `compression` | 1 | Tutto elencato |
| `partition_manager` | 2 | Tutto elencato |
| `sql_templates` | 17 | Tutti elencati (meno di 20) |
| `utilities` | 99 | Top 20 operativo estratto |

## 2) Criterio di selezione Top

Gli script in Top sono scelti con priorita su:

1. utilita quotidiana in troubleshooting/operations
2. copertura end-to-end dei casi principali della categoria
3. riuso nel lab RAC + Data Guard + GoldenGate
4. basso rischio di uso (query/report prima di script invasivi)

## 3) Raggruppamento e Top script per categoria

## asm_storage (Top 14/20)

Raggruppamento operativo:
- inventario e stato ASM
- performance e hot spot
- extent/layout
- file e failgroup

| # | Script | Uso principale |
|---|---|---|
| 1 | [asm_diskgroups.sql](./asm_storage/community_scripts/asm_diskgroups.sql) | stato e spazio diskgroup |
| 2 | [asm_disks.sql](./asm_storage/community_scripts/asm_disks.sql) | inventario dischi ASM |
| 3 | [asm_diskgroup_attributes.sql](./asm_storage/community_scripts/asm_diskgroup_attributes.sql) | attributi DG (`au_size`, compatibilita) |
| 4 | [asm_diskgroup_templates.sql](./asm_storage/community_scripts/asm_diskgroup_templates.sql) | template ridondanza/striping |
| 5 | [asm_disk_stats.sql](./asm_storage/community_scripts/asm_disk_stats.sql) | metriche I/O per disco |
| 6 | [asm-diskgroup-stat.sql](./asm_storage/community_scripts/asm-diskgroup-stat.sql) | KPI sintetici diskgroup |
| 7 | [asm_disk_errors.sql](./asm_storage/community_scripts/asm_disk_errors.sql) | errori disco e stato |
| 8 | [asm_extent_distribution.sql](./asm_storage/community_scripts/asm_extent_distribution.sql) | distribuzione extent |
| 9 | [asm_extent_multi_au.sql](./asm_storage/community_scripts/asm_extent_multi_au.sql) | analisi extent multi-AU |
| 10 | [asm_failgroup_members.sql](./asm_storage/community_scripts/asm_failgroup_members.sql) | mapping failgroup |
| 11 | [asm_files.sql](./asm_storage/community_scripts/asm_files.sql) | elenco file ASM |
| 12 | [asm_files_path.sql](./asm_storage/community_scripts/asm_files_path.sql) | path/logical file map |
| 13 | [asm_partners.sql](./asm_storage/community_scripts/asm_partners.sql) | partner/failure alignment |
| 14 | [asm_copyblock.sql](./asm_storage/community_scripts/asm_copyblock.sql) | utility blocchi ASM |

## dataguard (runbook)

Categoria documentale: non contiene script `.sql/.sh` pronti.

Top runbook:
1. [configurazione_dataguard.md](./dataguard/configurazione_dataguard.md)
2. [active_dataguard.md](./dataguard/active_dataguard.md)
3. [verifica_gap.md](./dataguard/verifica_gap.md)
4. [service_read_only.md](./dataguard/service_read_only.md)
5. [recovery_post_reboot.md](./dataguard/recovery_post_reboot.md)

## monitoring_scripts (Top 20/20 su 581)

Raggruppamento operativo:
- sessioni e lock
- CPU/I-O/waits
- ASH real-time
- SQL tuning rapido

| # | Script | Uso principale |
|---|---|---|
| 1 | [ViewSession.sql](./monitoring_scripts/ViewSession.sql) | snapshot sessioni attive |
| 2 | [View_Blocking.sql](./monitoring_scripts/View_Blocking.sql) | blocking tree rapido |
| 3 | [locks.sql](./monitoring_scripts/locks.sql) | lock attivi |
| 4 | [locks_blocking.sql](./monitoring_scripts/locks_blocking.sql) | lock bloccanti |
| 5 | [locks_details.sql](./monitoring_scripts/locks_details.sql) | dettaglio lock e oggetti |
| 6 | [Check_Lock.sql](./monitoring_scripts/Check_Lock.sql) | controllo lock veloce |
| 7 | [View_Cpu_Consumer.sql](./monitoring_scripts/View_Cpu_Consumer.sql) | top CPU consumer |
| 8 | [View_Cpu_Hist.sql](./monitoring_scripts/View_Cpu_Hist.sql) | trend CPU |
| 9 | [View_IO_RealTime.sql](./monitoring_scripts/View_IO_RealTime.sql) | I/O realtime |
| 10 | [View_IO_Hist.sql](./monitoring_scripts/View_IO_Hist.sql) | storico I/O |
| 11 | [IO_WaitTimeDetails.sql](./monitoring_scripts/IO_WaitTimeDetails.sql) | wait I/O dettagliato |
| 12 | [Event_statistics.sql](./monitoring_scripts/Event_statistics.sql) | top wait/event |
| 13 | [ASH.sql](./monitoring_scripts/ASH.sql) | ASH base |
| 14 | [ActiveSessionHistoryQueries.sql](./monitoring_scripts/ActiveSessionHistoryQueries.sql) | query ASH avanzate |
| 15 | [AshTopSql.sql](./monitoring_scripts/AshTopSql.sql) | top SQL in ASH |
| 16 | [AshTopSession.sql](./monitoring_scripts/AshTopSession.sql) | top sessioni in ASH |
| 17 | [AshTopProcedure.sql](./monitoring_scripts/AshTopProcedure.sql) | top PL/SQL in ASH |
| 18 | [SQL Plan Change.sql](./monitoring_scripts/SQL Plan Change.sql) | cambi plan hash |
| 19 | [SQL Stats.sql](./monitoring_scripts/SQL Stats.sql) | statistiche SQL |
| 20 | [View_UnstablePlan.sql](./performance_tuning/community_scripts/tuning/View_UnstablePlan.sql) | rileva piani instabili |

Nota: la cartella include anche i pack `community_gwenshap` e `community_jkstill` con molte utility specialistiche.

## user_management (template operativi)

Categoria template: non contiene script `.sql/.sh` pronti.

Top template:
1. [Prototipo_CreateUser_Nominale_v1.4.txt](./user_management/Prototipo_CreateUser_Nominale_v1.4.txt)
2. [Prototipo_CreateUser_DBA_OP_v1.3.txt](./user_management/Prototipo_CreateUser_DBA_OP_v1.3.txt)
3. [Prototipo_CreateUser_DB_APPLICATIVA_v1.3.txt](./user_management/Prototipo_CreateUser_DB_APPLICATIVA_v1.3.txt)
4. [Verify Function PWD.txt](./user_management/Verify%20Function%20PWD.txt)
5. [GeneraPass_Random_da_Bash.txt](./user_management/GeneraPass_Random_da_Bash.txt)

## patching (runbook)

Categoria documentale: non contiene script `.sql/.sh` pronti.

Top runbook/template:
1. [golden_images_ohctl.md](./patching/golden_images_ohctl.md)
2. [golden_images_ohctl.txt](./patching/golden_images_ohctl.txt)
3. [patching_grid_12c.md](./patching/patching_grid_12c.md)
4. [setoh.txt](./patching/setoh.txt)
5. [support_notes.md](./patching/support_notes.md)

## backup_recovery (Top 10/20)

Raggruppamento operativo:
- flashback e restore point
- stato backup RMAN
- recovery SCN e controllo data loss

| # | Script | Uso principale |
|---|---|---|
| 1 | [Flashback_restore_point.sql](./backup_recovery/Flashback_restore_point.sql) | gestione restore point |
| 2 | [FLASHBACK_RESTORPOINT.sql](./backup_recovery/FLASHBACK_RESTORPOINT.sql) | variante restore point |
| 3 | [fra_config.sql](./backup_recovery/community_scripts/fra_config.sql) | stato/config FRA |
| 4 | [incarnations.sql](./backup_recovery/community_scripts/incarnations.sql) | elenco incarnazioni DB |
| 5 | [rman-bkup-status.sql](./backup_recovery/community_scripts/rman-bkup-status.sql) | stato backup RMAN |
| 6 | [rman-bkup-details.sql](./backup_recovery/community_scripts/rman-bkup-details.sql) | dettaglio job RMAN |
| 7 | [rman-recovery-scn.sql](./backup_recovery/community_scripts/rman-recovery-scn.sql) | SCN recovery point |
| 8 | [rman-recovery-min-scn.sql](./backup_recovery/community_scripts/rman-recovery-min-scn.sql) | minimo SCN recuperabile |
| 9 | [unrecoverable-files.sql](./backup_recovery/community_scripts/unrecoverable-files.sql) | file non recoverable |
| 10 | [restore-sqlplus-settings.sql](./backup_recovery/community_scripts/restore-sqlplus-settings.sql) | reset ambiente SQL*Plus |

## performance_tuning (Top 20/20 su 220)

Raggruppamento operativo:
- AAS/ASH/AWR (analisi carico)
- memory sizing
- SQL tuning

| # | Script | Uso principale |
|---|---|---|
| 1 | [aas.sql](./performance_tuning/community_scripts/ash_awr/aas.sql) | Average Active Sessions |
| 2 | [aas-ash-calc.sql](./performance_tuning/community_scripts/ash_awr/aas-ash-calc.sql) | AAS da ASH |
| 3 | [aas-awr-calc.sql](./performance_tuning/community_scripts/ash_awr/aas-awr-calc.sql) | AAS da AWR |
| 4 | [ash-current-waits.sql](./performance_tuning/community_scripts/ash_awr/ash-current-waits.sql) | wait attuali |
| 5 | [ash-current-waits-by-sql-event.sql](./performance_tuning/community_scripts/ash_awr/ash-current-waits-by-sql-event.sql) | wait per SQL/evento |
| 6 | [ash_top_sql.sql](./performance_tuning/community_scripts/ash_awr/ash_top_sql.sql) | top SQL ASH |
| 7 | [ash_top_session.sql](./performance_tuning/community_scripts/ash_awr/ash_top_session.sql) | top sessioni ASH |
| 8 | [ash_top_procedure.sql](./performance_tuning/community_scripts/ash_awr/ash_top_procedure.sql) | top procedure |
| 9 | [awr-top-events.sql](./performance_tuning/community_scripts/ash_awr/awr-top-events.sql) | top eventi AWR |
| 10 | [awr-top-10-daily.sql](./performance_tuning/community_scripts/ash_awr/awr-top-10-daily.sql) | trend giornaliero AWR |
| 11 | [top10-sql-awr.sql](./performance_tuning/community_scripts/ash_awr/top10-sql-awr.sql) | top SQL AWR |
| 12 | [top10-sql-ash.sql](./performance_tuning/community_scripts/ash_awr/top10-sql-ash.sql) | top SQL ASH |
| 13 | [pga_advice.sql](./performance_tuning/community_scripts/memory/pga_advice.sql) | sizing PGA advisor |
| 14 | [pga_workarea_active.sql](./performance_tuning/community_scripts/memory/pga_workarea_active.sql) | workarea attive |
| 15 | [shared_pool_advice.sql](./performance_tuning/community_scripts/memory/shared_pool_advice.sql) | sizing shared pool |
| 16 | [shared-pool-top-sql.sql](./performance_tuning/community_scripts/memory/shared-pool-top-sql.sql) | top SQL in shared pool |
| 17 | [showsga.sql](./performance_tuning/community_scripts/memory/showsga.sql) | riepilogo SGA |
| 18 | [find-expensive-sql.sql](./performance_tuning/community_scripts/tuning/find-expensive-sql.sql) | SQL costose |
| 19 | [dbms-sqltune-sqlid.sql](./performance_tuning/community_scripts/tuning/dbms-sqltune-sqlid.sql) | SQL Tuning Advisor |
| 20 | [sql-exe-times-awr.sql](./performance_tuning/community_scripts/tuning/sql-exe-times-awr.sql) | execution time da AWR |

## tde_security (Top 8/20)

Raggruppamento operativo:
- audit trail e session audit
- controllo flag audit oggetti
- cleanup log audit

| # | Script | Uso principale |
|---|---|---|
| 1 | [audit-actions.sql](./tde_security/community_scripts/audit-actions.sql) | mapping azioni audit |
| 2 | [dba_audit_session.sql](./tde_security/community_scripts/dba_audit_session.sql) | session audit |
| 3 | [dba_audit_session_recent.sql](./tde_security/community_scripts/dba_audit_session_recent.sql) | sessioni recenti |
| 4 | [dba_audit_trail.sql](./tde_security/community_scripts/dba_audit_trail.sql) | audit trail completo |
| 5 | [dba_audit_trail_persons.sql](./tde_security/community_scripts/dba_audit_trail_persons.sql) | audit trail per utente |
| 6 | [dba_table_audit_flags.sql](./tde_security/community_scripts/dba_table_audit_flags.sql) | flag audit per tabella |
| 7 | [show_session_audit.sql](./tde_security/community_scripts/show_session_audit.sql) | report session audit |
| 8 | [ua-audit-log-cleanup-job.sql](./tde_security/community_scripts/ua-audit-log-cleanup-job.sql) | job cleanup unified audit |

## compression (Top 1/20)

| # | Script | Uso principale |
|---|---|---|
| 1 | [Get_DDL_RENAME_OBJECT_v1.3.sql](./compression/Get_DDL_RENAME_OBJECT_v1.3.sql) | DDL support per operazioni di compressione/redefinition |

## partition_manager (Top 2/20)

| # | Script | Uso principale |
|---|---|---|
| 1 | [Script_Creazione_Partition_Manager_v2_36.sql](./partition_manager/Script_Creazione_Partition_Manager_v2_36.sql) | installazione package partition manager |
| 2 | [dba_op_user_setup.sql](./partition_manager/dba_op_user_setup.sql) | setup utente/privilegi operativi |

## sql_templates (Top 17/20)

Raggruppamento operativo:
- DDL
- DML
- PL/SQL
- grants

| # | Script | Uso principale |
|---|---|---|
| 1 | [00X_Form_create_table.sql](./sql_templates/00X_Form_create_table.sql) | template create table |
| 2 | [00X_Form_alter_table.sql](./sql_templates/00X_Form_alter_table.sql) | template alter table |
| 3 | [00X_Form_drop_table.sql](./sql_templates/00X_Form_drop_table.sql) | template drop table |
| 4 | [00X_Form_create_index.sql](./sql_templates/00X_Form_create_index.sql) | template create index |
| 5 | [00X_Form_alter_index.sql](./sql_templates/00X_Form_alter_index.sql) | template alter/rebuild index |
| 6 | [00X_Form_create_view.sql](./sql_templates/00X_Form_create_view.sql) | template create view |
| 7 | [00X_Form_primary_key.sql](./sql_templates/00X_Form_primary_key.sql) | template primary key |
| 8 | [00X_Form_foreign_key.sql](./sql_templates/00X_Form_foreign_key.sql) | template foreign key |
| 9 | [00X_Form_dml.sql](./sql_templates/00X_Form_dml.sql) | template DML con controlli |
| 10 | [00X_Form_loop_commit.sql](./sql_templates/00X_Form_loop_commit.sql) | batch commit controllato |
| 11 | [Form_loop_rowid.sql](./sql_templates/Form_loop_rowid.sql) | loop per rowid |
| 12 | [00X_Form_procedure.sql](./sql_templates/00X_Form_procedure.sql) | template procedure |
| 13 | [00X_Form_package.sql](./sql_templates/00X_Form_package.sql) | template package |
| 14 | [00X_Form_trigger.sql](./sql_templates/00X_Form_trigger.sql) | template trigger |
| 15 | [00X_Form_sequence.sql](./sql_templates/00X_Form_sequence.sql) | template sequence |
| 16 | [00X_Form_sinonimi.sql](./sql_templates/00X_Form_sinonimi.sql) | template sinonimi |
| 17 | [00X_Form_assign_grant.sql](./sql_templates/00X_Form_assign_grant.sql) | template grant |

## utilities (Top 20/20 su 99)

Raggruppamento operativo:
- health check host/instance
- scheduler jobs
- storage/TEMP/UNDO
- diagnostica rapida

| # | Script | Uso principale |
|---|---|---|
| 1 | [TEMP_and_UNDO_monitor.sql](./utilities/TEMP_and_UNDO_monitor.sql) | monitor TEMP/UNDO |
| 2 | [Job monitoring TEMP e UNDO TABLESPACE.sql](./utilities/Job%20monitoring%20TEMP%20e%20UNDO%20TABLESPACE.sql) | job monitor tablespace |
| 3 | [Install_pkg_Dba_Utility_20220713_v1_9_PROD.sql](./utilities/Install_pkg_Dba_Utility_20220713_v1_9_PROD.sql) | install utility package |
| 4 | [get-alert-logs.sh](./utilities/community_scripts/get-alert-logs.sh) | raccolta alert log |
| 5 | [get-ohomes.sh](./utilities/community_scripts/get-ohomes.sh) | inventory Oracle Homes |
| 6 | [get-crsctl.sh](./utilities/community_scripts/get-crsctl.sh) | diagnosi Clusterware |
| 7 | [get-lgwr-trace.sh](./utilities/community_scripts/get-lgwr-trace.sh) | estrazione trace LGWR |
| 8 | [rman-chk-syntax.sh](./utilities/community_scripts/rman-chk-syntax.sh) | check sintassi RMAN |
| 9 | [asm-disk-chk.sh](./utilities/community_scripts/asm-disk-chk.sh) | check dischi ASM lato host |
| 10 | [memsz.sh](./utilities/community_scripts/memsz.sh) | riepilogo memoria processo |
| 11 | [memsz-all.sh](./utilities/community_scripts/memsz-all.sh) | memoria all-process |
| 12 | [oracle-connect-rate.sh](./utilities/community_scripts/oracle-connect-rate.sh) | test connect rate |
| 13 | [procmem.pl](./utilities/community_scripts/procmem.pl) | memoria processo (perl) |
| 14 | [sga-smallpage-detector.pl](./utilities/community_scripts/sga-smallpage-detector.pl) | verifica page allocation SGA |
| 15 | [show-sga-page-allocation.sh](./utilities/community_scripts/show-sga-page-allocation.sh) | SGA page map |
| 16 | [show_jobs.sql](./utilities/scheduler/show_jobs.sql) | job scheduler rapidi |
| 17 | [dba_jobs_running.sql](./utilities/scheduler/dba_jobs_running.sql) | job in esecuzione |
| 18 | [dba_sched_jobs.sql](./utilities/scheduler/dba_sched_jobs.sql) | catalogo scheduler jobs |
| 19 | [showspace.sql](./utilities/storage/showspace.sql) | analisi spazio oggetti |
| 20 | [show-pdbs.sql](./utilities/cdb_pdb/show-pdbs.sql) | elenco PDB operativo |

## 4) Uso pratico consigliato

Routine minima giornaliera (15-20 min):

1. `monitoring_scripts`: sessioni/lock + CPU/I-O
2. `performance_tuning`: top SQL ASH/AWR
3. `utilities`: job scheduler + TEMP/UNDO

Routine settimanale:

1. `backup_recovery`: stato RMAN/FRA
2. `tde_security`: audit session trail e cleanup
3. `asm_storage`: salute diskgroup/dischi

## 5) Nota di manutenzione catalogo

Se aggiungi nuovi script, aggiorna:

1. questo catalogo (`CATALOGO_SCRIPT_TOP20_PER_CATEGORIA.md`)
2. il README della categoria impattata
3. il README principale di `libreria_oracle` (se cambia la navigazione)

