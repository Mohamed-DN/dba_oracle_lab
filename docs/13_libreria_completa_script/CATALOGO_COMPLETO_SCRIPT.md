# Catalogo completo script Oracle (analisi 1:1)

Catalogo generato automaticamente leggendo tutti i file script della libreria e assegnando descrizione sintetica, rischio e coerenza cartella.

- Script analizzati: **965**
- Script con cartella coerente: **965**
- Script candidati a riclassificazione: **0**

## Sintesi per categoria

| Categoria | Totale script |
|---|---:|
| `01_asm_storage` (ASM & Storage) | 26 |
| `02_dataguard` (Data Guard) | 0 |
| `03_monitoring_scripts` (Monitoring) | 560 |
| `04_user_management` (User Management) | 5 |
| `05_patching` (Patching) | 2 |
| `06_backup_recovery` (Backup & Recovery) | 12 |
| `07_performance_tuning` (Performance Tuning) | 230 |
| `08_tde_security` (TDE & Security) | 8 |
| `09_compression` (Compression) | 1 |
| `10_partition_manager` (Partition Manager) | 2 |
| `11_sql_templates` (SQL Templates) | 17 |
| `12_utilities` (Utilities) | 102 |

## Dettaglio script per script

### `01_asm_storage` — ASM & Storage (26 script)

| Script | Sottocartella | Rischio | Stato cartella | Spiegazione |
|---|---|---|---|---|
| [`asm_limits_ausize.sql`](./01_asm_storage/asm_limits_ausize.sql) | `-` | BASSO | OK | Analisi Limiti Fisici ASM basati su AU_SIZE, Compatibilità e Ridondanza |
| [`asm-diskgroup-stat.sql`](./01_asm_storage/community_scripts/asm-diskgroup-stat.sql) | `community_scripts` | BASSO | OK | asm-diskgroup-stat.sql |
| [`Asm_Alias.sql`](./01_asm_storage/community_scripts/Asm_Alias.sql) | `community_scripts` | BASSO | OK | | FILE : asm_alias.sql | |
| [`Asm_Check.sql`](./01_asm_storage/community_scripts/Asm_Check.sql) | `community_scripts` | BASSO | OK | Find largest amount of space allocated to a cell |
| [`Asm_Clients.sql`](./01_asm_storage/community_scripts/Asm_Clients.sql) | `community_scripts` | BASSO | OK | | DATABASE : Oracle | |
| [`asm_copyblock.sql`](./01_asm_storage/community_scripts/asm_copyblock.sql) | `community_scripts` | BASSO | OK | asm_copyblock.sql |
| [`asm_disk_errors.sql`](./01_asm_storage/community_scripts/asm_disk_errors.sql) | `community_scripts` | BASSO | OK | asm_disk_errors.sql |
| [`asm_disk_stats.sql`](./01_asm_storage/community_scripts/asm_disk_stats.sql) | `community_scripts` | BASSO | OK | asm_disk_stats.sql |
| [`asm_diskgroup_attributes.sql`](./01_asm_storage/community_scripts/asm_diskgroup_attributes.sql) | `community_scripts` | BASSO | OK | asm_diskgroup_attributes.sql |
| [`asm_diskgroup_templates.sql`](./01_asm_storage/community_scripts/asm_diskgroup_templates.sql) | `community_scripts` | BASSO | OK | asm_diskgroup_templates.sql |
| [`Asm_DiskGroupPerformance.sql`](./01_asm_storage/community_scripts/Asm_DiskGroupPerformance.sql) | `community_scripts` | BASSO | OK | Controllo operativo backup/recovery RMAN e stato protezione dati. |
| [`Asm_Diskgroups.sql`](./01_asm_storage/community_scripts/Asm_Diskgroups.sql) | `community_scripts` | BASSO | OK | | DATABASE : Oracle | |
| [`asm_diskgroups.sql`](./01_asm_storage/community_scripts/asm_diskgroups.sql) | `community_scripts` | BASSO | OK | Verifica storage ASM: stato dischi, performance e configurazione. |
| [`Asm_Disks.sql`](./01_asm_storage/community_scripts/Asm_Disks.sql) | `community_scripts` | BASSO | OK | | DATABASE : Oracle | |
| [`asm_disks.sql`](./01_asm_storage/community_scripts/asm_disks.sql) | `community_scripts` | BASSO | OK | Verifica storage ASM: stato dischi, performance e configurazione. |
| [`Asm_Disks_Perf.sql`](./01_asm_storage/community_scripts/Asm_Disks_Perf.sql) | `community_scripts` | BASSO | OK | | DATABASE : Oracle | |
| [`Asm_drop_files.sql`](./01_asm_storage/community_scripts/Asm_drop_files.sql) | `community_scripts` | ALTO | OK | | DATABASE : Oracle | |
| [`asm_extent_distribution.sql`](./01_asm_storage/community_scripts/asm_extent_distribution.sql) | `community_scripts` | BASSO | OK | asm_extent_distribution.sql |
| [`asm_extent_multi_au.sql`](./01_asm_storage/community_scripts/asm_extent_multi_au.sql) | `community_scripts` | BASSO | OK | asm_extent_multi_au |
| [`asm_failgroup_members.sql`](./01_asm_storage/community_scripts/asm_failgroup_members.sql) | `community_scripts` | BASSO | OK | asm_failgroup_members.sql |
| [`Asm_Files.sql`](./01_asm_storage/community_scripts/Asm_Files.sql) | `community_scripts` | BASSO | OK | | DATABASE : Oracle | |
| [`asm_files.sql`](./01_asm_storage/community_scripts/asm_files.sql) | `community_scripts` | BASSO | OK | asm_files.sql |
| [`asm_files_path.sql`](./01_asm_storage/community_scripts/asm_files_path.sql) | `community_scripts` | MEDIO | OK | asm_files_path.sql |
| [`asm_partners.sql`](./01_asm_storage/community_scripts/asm_partners.sql) | `community_scripts` | BASSO | OK | asm-partners.sql |
| [`Asm_Templates.sql`](./01_asm_storage/community_scripts/Asm_Templates.sql) | `community_scripts` | BASSO | OK | | DATABASE : Oracle | |
| [`Asmdisk.sql`](./01_asm_storage/community_scripts/Asmdisk.sql) | `community_scripts` | BASSO | OK | Mostra i dischi ASM |

### `02_dataguard` — Data Guard (0 script)

_Nessuno script operativo in questa categoria (solo documentazione)._

### `03_monitoring_scripts` — Monitoring (560 script)

| Script | Sottocartella | Rischio | Stato cartella | Spiegazione |
|---|---|---|---|---|
| [` Gestione code oracle per NIX.sql`](./03_monitoring_scripts/%20Gestione%20code%20oracle%20per%20NIX.sql) | `-` | MEDIO | OK | grant da dare anche all'utente OWNER delle queue tables per corretto funzionamento |
| [`___ Situation.sql`](./03_monitoring_scripts/___%20Situation.sql) | `-` | ALTO | OK | ACTIVE SESSIONS |
| [`ActiveSessionHistoryQueries.sql`](./03_monitoring_scripts/ActiveSessionHistoryQueries.sql) | `-` | BASSO | OK | Script operativo Oracle per: ActiveSessionHistoryQueries. |
| [`ASH.sql`](./03_monitoring_scripts/ASH.sql) | `-` | MEDIO | OK | https://blogs.oracle.com/oraclemagazine/beginning-performance-tuning-active-session-history |
| [`AshTopProcedure.sql`](./03_monitoring_scripts/AshTopProcedure.sql) | `-` | BASSO | OK | Analisi Active Session History (ASH) per colli di bottiglia e top consumer. |
| [`AshTopSession.sql`](./03_monitoring_scripts/AshTopSession.sql) | `-` | BASSO | OK | Analisi Active Session History (ASH) per colli di bottiglia e top consumer. |
| [`AshTopSql.sql`](./03_monitoring_scripts/AshTopSql.sql) | `-` | BASSO | OK | and ash.sample_time > sysdate - minutes /( 60*24) |
| [`Check_Lock.sql`](./03_monitoring_scripts/Check_Lock.sql) | `-` | MEDIO | OK | Diagnosi lock/sessioni bloccanti e catene di attesa. |
| [`advisor_profile_recs.sql`](./03_monitoring_scripts/community_gwenshap/advisor_profile_recs.sql) | `community_gwenshap` | BASSO | OK | Retrieve SQL tuning advisor findings. You can only run the most recent run if you like, but it will only contain new recommendations. This s |
| [`ASH2.sql`](./03_monitoring_scripts/community_gwenshap/ASH2.sql) | `community_gwenshap` | BASSO | OK | how much history do we have |
| [`check_and_kill.sql`](./03_monitoring_scripts/community_gwenshap/check_and_kill.sql) | `community_gwenshap` | ALTO | OK | Check what the sessions in our instance are waiting for |
| [`col_high_low_val.sql`](./03_monitoring_scripts/community_gwenshap/col_high_low_val.sql) | `community_gwenshap` | BASSO | OK | Martin Widlake mdw 21/03/2003 |
| [`DataGuard.txt`](./03_monitoring_scripts/community_gwenshap/DataGuard.txt) | `community_gwenshap` | ALTO | OK | Find which logs were applied in the last day |
| [`double_tablespace.sql`](./03_monitoring_scripts/community_gwenshap/double_tablespace.sql) | `community_gwenshap` | ALTO | OK | Script written for a case where data was loaded rapidly and without prior notice |
| [`explain_plan.sql`](./03_monitoring_scripts/community_gwenshap/explain_plan.sql) | `community_gwenshap` | BASSO | OK | dbms_xplan works in 9i and up |
| [`external_table_load_example.sql`](./03_monitoring_scripts/community_gwenshap/external_table_load_example.sql) | `community_gwenshap` | ALTO | OK | select * from db.bm_tmp where rownum<=5 |
| [`find_sql.sql`](./03_monitoring_scripts/community_gwenshap/find_sql.sql) | `community_gwenshap` | BASSO | OK | Script operativo Oracle per: find sql. |
| [`fsx.sql`](./03_monitoring_scripts/community_gwenshap/fsx.sql) | `community_gwenshap` | BASSO | OK | File name: fsx.sql |
| [`index_efficiency.sql`](./03_monitoring_scripts/community_gwenshap/index_efficiency.sql) | `community_gwenshap` | BASSO | OK | t1 sample block (100) |
| [`job_scheduling.sql`](./03_monitoring_scripts/community_gwenshap/job_scheduling.sql) | `community_gwenshap` | ALTO | OK | Decent reference for new scheduler |
| [`locks.sql`](./03_monitoring_scripts/community_gwenshap/locks.sql) | `community_gwenshap` | BASSO | OK | Find all blocked sessions and who is blocking them |
| [`login.sql`](./03_monitoring_scripts/community_gwenshap/login.sql) | `community_gwenshap` | BASSO | OK | Script operativo Oracle per: login. |
| [`my_sqlmon.sql`](./03_monitoring_scripts/community_gwenshap/my_sqlmon.sql) | `community_gwenshap` | BASSO | OK | Script operativo Oracle per: my sqlmon. |
| [`PGA_watch.sql`](./03_monitoring_scripts/community_gwenshap/PGA_watch.sql) | `community_gwenshap` | BASSO | OK | order by inst_id,server |
| [`sql_monitor_offload.sql`](./03_monitoring_scripts/community_gwenshap/sql_monitor_offload.sql) | `community_gwenshap` | BASSO | OK | Script operativo Oracle per: sql monitor offload. |
| [`SSD.sql`](./03_monitoring_scripts/community_gwenshap/SSD.sql) | `community_gwenshap` | BASSO | OK | Find segments with most read operations, and hopefully relatively few writes |
| [`tablespace.sql`](./03_monitoring_scripts/community_gwenshap/tablespace.sql) | `community_gwenshap` | ALTO | OK | Tablespaces, ordered by percentage of space used |
| [`tfsclock.sql`](./03_monitoring_scripts/community_gwenshap/tfsclock.sql) | `community_gwenshap` | ALTO | OK | Diagnosi lock/sessioni bloccanti e catene di attesa. |
| [`top-sql.sql`](./03_monitoring_scripts/community_gwenshap/top-sql.sql) | `community_gwenshap` | BASSO | OK | by Jeremy Schneider, Pythian |
| [`top_excel.sql`](./03_monitoring_scripts/community_gwenshap/top_excel.sql) | `community_gwenshap` | BASSO | OK | Script operativo Oracle per: top excel. |
| [`top_queries.sql`](./03_monitoring_scripts/community_gwenshap/top_queries.sql) | `community_gwenshap` | BASSO | OK | ,executions_delta |
| [`undo_space.sql`](./03_monitoring_scripts/community_gwenshap/undo_space.sql) | `community_gwenshap` | BASSO | OK | undo generated in last day |
| [`date_math.sql`](./03_monitoring_scripts/community_jkstill/dates/date_math.sql) | `community_jkstill/dates` | ALTO | OK | date_math.sql |
| [`date_math_2.sql`](./03_monitoring_scripts/community_jkstill/dates/date_math_2.sql) | `community_jkstill/dates` | ALTO | OK | date_math_2.sql |
| [`date_math_3.sql`](./03_monitoring_scripts/community_jkstill/dates/date_math_3.sql) | `community_jkstill/dates` | MEDIO | OK | date_math_3.sql |
| [`date_math_4.sql`](./03_monitoring_scripts/community_jkstill/dates/date_math_4.sql) | `community_jkstill/dates` | ALTO | OK | date_math_4.sql |
| [`date_math_epoch.sql`](./03_monitoring_scripts/community_jkstill/dates/date_math_epoch.sql) | `community_jkstill/dates` | BASSO | OK | date_math_epoch.sql |
| [`datemath-pkg.sql`](./03_monitoring_scripts/community_jkstill/dates/datemath-pkg.sql) | `community_jkstill/dates` | MEDIO | OK | works with systimestamp, which is of type timestamp with time zone |
| [`datemath-test.sql`](./03_monitoring_scripts/community_jkstill/dates/datemath-test.sql) | `community_jkstill/dates` | MEDIO | OK | datemath-test.sql |
| [`timestamp-day-boundaries.sql`](./03_monitoring_scripts/community_jkstill/dates/timestamp-day-boundaries.sql) | `community_jkstill/dates` | BASSO | OK | timestamp-day-boundaries.sql |
| [`timestamp-diff-inline-function.sql`](./03_monitoring_scripts/community_jkstill/dates/timestamp-diff-inline-function.sql) | `community_jkstill/dates` | BASSO | OK | timestamp-diff-seconds-inline-function.sql |
| [`timestamp-diff-seconds-2.sql`](./03_monitoring_scripts/community_jkstill/dates/timestamp-diff-seconds-2.sql) | `community_jkstill/dates` | BASSO | OK | timestamp-diff-seconds-2.sql |
| [`timestamp-diff-seconds.sql`](./03_monitoring_scripts/community_jkstill/dates/timestamp-diff-seconds.sql) | `community_jkstill/dates` | BASSO | OK | timestamp-diff-seconds.sql |
| [`timestamp-trunc.sql`](./03_monitoring_scripts/community_jkstill/dates/timestamp-trunc.sql) | `community_jkstill/dates` | ALTO | OK | timestamp-trunc.sql |
| [`timestamp-types.sql`](./03_monitoring_scripts/community_jkstill/dates/timestamp-types.sql) | `community_jkstill/dates` | ALTO | OK | timestamp-types.sql |
| [`timestamp_to_millisecond.sql`](./03_monitoring_scripts/community_jkstill/dates/timestamp_to_millisecond.sql) | `community_jkstill/dates` | BASSO | OK | Script operativo Oracle per: timestamp to millisecond. |
| [`timezone-abbrev.sql`](./03_monitoring_scripts/community_jkstill/dates/timezone-abbrev.sql) | `community_jkstill/dates` | BASSO | OK | timezone-names.sql |
| [`timezone-names.sql`](./03_monitoring_scripts/community_jkstill/dates/timezone-names.sql) | `community_jkstill/dates` | BASSO | OK | timezone-names.sql |
| [`drcp_connection_monitor.sql`](./03_monitoring_scripts/community_jkstill/drcp/drcp_connection_monitor.sql) | `community_jkstill/drcp` | BASSO | OK | drcp_connection_monitor.sql |
| [`drcp_connection_status.sql`](./03_monitoring_scripts/community_jkstill/drcp/drcp_connection_status.sql) | `community_jkstill/drcp` | BASSO | OK | Script operativo Oracle per: drcp connection status. |
| [`drcp_pool_cc_stats.sql`](./03_monitoring_scripts/community_jkstill/drcp/drcp_pool_cc_stats.sql) | `community_jkstill/drcp` | BASSO | OK | , wait_time -- reserved for future use |
| [`drcp_pool_ratio.sql`](./03_monitoring_scripts/community_jkstill/drcp/drcp_pool_ratio.sql) | `community_jkstill/drcp` | BASSO | OK | Script operativo Oracle per: drcp pool ratio. |
| [`drcp_pool_stats.sql`](./03_monitoring_scripts/community_jkstill/drcp/drcp_pool_stats.sql) | `community_jkstill/drcp` | BASSO | OK | drcp_pool_stats.sql |
| [`drcp_set_connections_per_broker.sql`](./03_monitoring_scripts/community_jkstill/drcp/drcp_set_connections_per_broker.sql) | `community_jkstill/drcp` | BASSO | OK | minimum allowed is 3 |
| [`drcp_set_num_brokers.sql`](./03_monitoring_scripts/community_jkstill/drcp/drcp_set_num_brokers.sql) | `community_jkstill/drcp` | BASSO | OK | Script operativo Oracle per: drcp set num brokers. |
| [`drcp_show_config.sql`](./03_monitoring_scripts/community_jkstill/drcp/drcp_show_config.sql) | `community_jkstill/drcp` | BASSO | OK | drcp_show_config.sql |
| [`drcp_start.sql`](./03_monitoring_scripts/community_jkstill/drcp/drcp_start.sql) | `community_jkstill/drcp` | BASSO | OK | Script operativo Oracle per: drcp start. |
| [`drcp_stop.sql`](./03_monitoring_scripts/community_jkstill/drcp/drcp_stop.sql) | `community_jkstill/drcp` | BASSO | OK | Script operativo Oracle per: drcp stop. |
| [`event-names.sql`](./03_monitoring_scripts/community_jkstill/events/event-names.sql) | `community_jkstill/events` | BASSO | OK | event-names.sql |
| [`10046.sql`](./03_monitoring_scripts/community_jkstill/general/10046.sql) | `community_jkstill/general` | MEDIO | OK | level 4 is bind values |
| [`10046_off.sql`](./03_monitoring_scripts/community_jkstill/general/10046_off.sql) | `community_jkstill/general` | MEDIO | OK | Script operativo Oracle per: 10046 off. |
| [`all-ini-trans.sql`](./03_monitoring_scripts/community_jkstill/general/all-ini-trans.sql) | `community_jkstill/general` | BASSO | OK | all-init-trans.sql |
| [`apex-version.sql`](./03_monitoring_scripts/community_jkstill/general/apex-version.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: apex version. |
| [`ascii.sql`](./03_monitoring_scripts/community_jkstill/general/ascii.sql) | `community_jkstill/general` | BASSO | OK | generate a simple ascii table |
| [`average_active_sessions.sql`](./03_monitoring_scripts/community_jkstill/general/average_active_sessions.sql) | `community_jkstill/general` | BASSO | OK | average_active_sessions_2.sql |
| [`bad-date.sql`](./03_monitoring_scripts/community_jkstill/general/bad-date.sql) | `community_jkstill/general` | MEDIO | OK | bad-date.sql |
| [`bct_bufsz.sql`](./03_monitoring_scripts/community_jkstill/general/bct_bufsz.sql) | `community_jkstill/general` | BASSO | OK | get size of buffers currently allocated for BCT change tracking |
| [`between-trunc-demo.sql`](./03_monitoring_scripts/community_jkstill/general/between-trunc-demo.sql) | `community_jkstill/general` | MEDIO | OK | between-trunc-demo.sql |
| [`bitwalk.sql`](./03_monitoring_scripts/community_jkstill/general/bitwalk.sql) | `community_jkstill/general` | BASSO | OK | Jared Still 2021 |
| [`block_decode.sql`](./03_monitoring_scripts/community_jkstill/general/block_decode.sql) | `community_jkstill/general` | BASSO | OK | block_decode.sql |
| [`blocker-tree.sql`](./03_monitoring_scripts/community_jkstill/general/blocker-tree.sql) | `community_jkstill/general` | BASSO | OK | blocker-tree.sql |
| [`blog-prompt.sql`](./03_monitoring_scripts/community_jkstill/general/blog-prompt.sql) | `community_jkstill/general` | BASSO | OK | simplified prompt for copy and paste to blog and articles |
| [`bootstrap_objects.sql`](./03_monitoring_scripts/community_jkstill/general/bootstrap_objects.sql) | `community_jkstill/general` | MEDIO | OK | bootstrap_objects.sql |
| [`build-record.sql`](./03_monitoring_scripts/community_jkstill/general/build-record.sql) | `community_jkstill/general` | MEDIO | OK | build-record.sql |
| [`bulk-collect-1.sql`](./03_monitoring_scripts/community_jkstill/general/bulk-collect-1.sql) | `community_jkstill/general` | MEDIO | OK | bulk-collect-1.sql |
| [`cf-size.sql`](./03_monitoring_scripts/community_jkstill/general/cf-size.sql) | `community_jkstill/general` | BASSO | OK | cf-size.sql - Display the size of the control file in MB |
| [`character-sets.sql`](./03_monitoring_scripts/community_jkstill/general/character-sets.sql) | `community_jkstill/general` | BASSO | OK | character-sets.sql |
| [`check_events.sql`](./03_monitoring_scripts/community_jkstill/general/check_events.sql) | `community_jkstill/general` | MEDIO | OK | check_events.sql |
| [`chk4incremental.sql`](./03_monitoring_scripts/community_jkstill/general/chk4incremental.sql) | `community_jkstill/general` | BASSO | OK | chk4incremental.sql |
| [`clear_for_spool.sql`](./03_monitoring_scripts/community_jkstill/general/clear_for_spool.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: clear for spool. |
| [`clears.sql`](./03_monitoring_scripts/community_jkstill/general/clears.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: clears. |
| [`cluster-factor.sql`](./03_monitoring_scripts/community_jkstill/general/cluster-factor.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: cluster factor. |
| [`code-inventory.sql`](./03_monitoring_scripts/community_jkstill/general/code-inventory.sql) | `community_jkstill/general` | MEDIO | OK | code-inventory.sql |
| [`colcomm.sql`](./03_monitoring_scripts/community_jkstill/general/colcomm.sql) | `community_jkstill/general` | BASSO | OK | find common columns between a set of tables |
| [`colors.sql`](./03_monitoring_scripts/community_jkstill/general/colors.sql) | `community_jkstill/general` | BASSO | OK | _C_RESET can be simply =[m |
| [`columns.sql`](./03_monitoring_scripts/community_jkstill/general/columns.sql) | `community_jkstill/general` | BASSO | OK | show paramater/spparameter settings |
| [`cores.sql`](./03_monitoring_scripts/community_jkstill/general/cores.sql) | `community_jkstill/general` | BASSO | OK | report the number of cores |
| [`csv-split-2.sql`](./03_monitoring_scripts/community_jkstill/general/csv-split-2.sql) | `community_jkstill/general` | BASSO | OK | csv-split-2.sql |
| [`csv-split-bind.sql`](./03_monitoring_scripts/community_jkstill/general/csv-split-bind.sql) | `community_jkstill/general` | BASSO | OK | csv-split-bind.sql |
| [`csv-split.sql`](./03_monitoring_scripts/community_jkstill/general/csv-split.sql) | `community_jkstill/general` | BASSO | OK | csv-split.sql |
| [`cursor-check.sql`](./03_monitoring_scripts/community_jkstill/general/cursor-check.sql) | `community_jkstill/general` | BASSO | OK | from gv$session ses, gv$sesstat ss, gv$statname sn, gv$parameter p |
| [`cursor-counts.sql`](./03_monitoring_scripts/community_jkstill/general/cursor-counts.sql) | `community_jkstill/general` | BASSO | OK | cursor-counts.sql |
| [`data-growth-db-predict-regr.sql`](./03_monitoring_scripts/community_jkstill/general/data-growth-db-predict-regr.sql) | `community_jkstill/general` | BASSO | OK | data-growth-db-predict-regr.sql |
| [`data-growth-db.sql`](./03_monitoring_scripts/community_jkstill/general/data-growth-db.sql) | `community_jkstill/general` | BASSO | OK | date is text and stored in this format: 'MM/DD/YYYY HH24:MI:SS' |
| [`data-growth-tbs-predict-regr.sql`](./03_monitoring_scripts/community_jkstill/general/data-growth-tbs-predict-regr.sql) | `community_jkstill/general` | BASSO | OK | data-growth-tbs-predict-regr.sql |
| [`data-growth-tbs.sql`](./03_monitoring_scripts/community_jkstill/general/data-growth-tbs.sql) | `community_jkstill/general` | BASSO | OK | date is text and stored in this format: 'MM/DD/YYYY HH24:MI:SS' |
| [`database_properties.sql`](./03_monitoring_scripts/community_jkstill/general/database_properties.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: database properties. |
| [`db_cache_advice.sql`](./03_monitoring_scripts/community_jkstill/general/db_cache_advice.sql) | `community_jkstill/general` | BASSO | OK | db_cache_advice.sql |
| [`db_corrupt.sql`](./03_monitoring_scripts/community_jkstill/general/db_corrupt.sql) | `community_jkstill/general` | BASSO | OK | db_corrupt.sql |
| [`dba-registry-history.sql`](./03_monitoring_scripts/community_jkstill/general/dba-registry-history.sql) | `community_jkstill/general` | BASSO | OK | dba-registry-history.sql |
| [`dba-registry.sql`](./03_monitoring_scripts/community_jkstill/general/dba-registry.sql) | `community_jkstill/general` | BASSO | OK | dba-registry.sql |
| [`dbms_application.sql`](./03_monitoring_scripts/community_jkstill/general/dbms_application.sql) | `community_jkstill/general` | BASSO | OK | v$session.client_info |
| [`dbms_log.sql`](./03_monitoring_scripts/community_jkstill/general/dbms_log.sql) | `community_jkstill/general` | MEDIO | OK | dbms_log.sql |
| [`dbms_output-abstracted.sql`](./03_monitoring_scripts/community_jkstill/general/dbms_output-abstracted.sql) | `community_jkstill/general` | MEDIO | OK | dbms_output-abstracted.sql |
| [`dbms_output-allow-blank-lines.sql`](./03_monitoring_scripts/community_jkstill/general/dbms_output-allow-blank-lines.sql) | `community_jkstill/general` | BASSO | OK | default is word_wrapped |
| [`dbms_system_undoc_calls.sql`](./03_monitoring_scripts/community_jkstill/general/dbms_system_undoc_calls.sql) | `community_jkstill/general` | MEDIO | OK | dbms_system_undoc_calls.sql |
| [`default_tablespace.sql`](./03_monitoring_scripts/community_jkstill/general/default_tablespace.sql) | `community_jkstill/general` | BASSO | OK | Monitoraggio capacità tablespace/TEMP/UNDO e prevenzione saturazione. |
| [`defaults-demo.sql`](./03_monitoring_scripts/community_jkstill/general/defaults-demo.sql) | `community_jkstill/general` | BASSO | OK | defaults-demo.sql |
| [`defaults.sql`](./03_monitoring_scripts/community_jkstill/general/defaults.sql) | `community_jkstill/general` | BASSO | OK | defaults.sql |
| [`dice-roll.sql`](./03_monitoring_scripts/community_jkstill/general/dice-roll.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: dice roll. |
| [`dirs.sql`](./03_monitoring_scripts/community_jkstill/general/dirs.sql) | `community_jkstill/general` | BASSO | OK | Jared Still - 2022 |
| [`dml-log-errors-test.sql`](./03_monitoring_scripts/community_jkstill/general/dml-log-errors-test.sql) | `community_jkstill/general` | ALTO | OK | dml-log-errors-test.sql |
| [`dp-filter-types.sql`](./03_monitoring_scripts/community_jkstill/general/dp-filter-types.sql) | `community_jkstill/general` | BASSO | OK | dp-filter-types.sh |
| [`dual_data_gen-low-mem.sql`](./03_monitoring_scripts/community_jkstill/general/dual_data_gen-low-mem.sql) | `community_jkstill/general` | BASSO | OK | dual_date_gen-low-mem.sql |
| [`dual_data_gen.sql`](./03_monitoring_scripts/community_jkstill/general/dual_data_gen.sql) | `community_jkstill/general` | BASSO | OK | dual_data_gen.sql |
| [`dump.sql`](./03_monitoring_scripts/community_jkstill/general/dump.sql) | `community_jkstill/general` | BASSO | OK | dump.sql - jared still |
| [`dumptrace_off.sql`](./03_monitoring_scripts/community_jkstill/general/dumptrace_off.sql) | `community_jkstill/general` | BASSO | OK | dumptrace_off.sql |
| [`dumptrace_on.sql`](./03_monitoring_scripts/community_jkstill/general/dumptrace_on.sql) | `community_jkstill/general` | BASSO | OK | dumptrace.sql |
| [`dumptracem_off.sql`](./03_monitoring_scripts/community_jkstill/general/dumptracem_off.sql) | `community_jkstill/general` | ALTO | OK | dumptracem_off.sql |
| [`dumptracem_on.sql`](./03_monitoring_scripts/community_jkstill/general/dumptracem_on.sql) | `community_jkstill/general` | ALTO | OK | dumptracem_on.sql |
| [`dup-user-profile.sql`](./03_monitoring_scripts/community_jkstill/general/dup-user-profile.sql) | `community_jkstill/general` | MEDIO | OK | Script operativo Oracle per: dup user profile. |
| [`dup_role.sql`](./03_monitoring_scripts/community_jkstill/general/dup_role.sql) | `community_jkstill/general` | MEDIO | OK | duplicate a role |
| [`dup_role_users.sql`](./03_monitoring_scripts/community_jkstill/general/dup_role_users.sql) | `community_jkstill/general` | MEDIO | OK | dup_role_users.sql |
| [`dup_user.sql`](./03_monitoring_scripts/community_jkstill/general/dup_user.sql) | `community_jkstill/general` | ALTO | OK | dup_user.sql |
| [`dynamic_plan_table.sql`](./03_monitoring_scripts/community_jkstill/general/dynamic_plan_table.sql) | `community_jkstill/general` | MEDIO | OK | dynamic_plan_table.sql |
| [`e2ts-hires.sql`](./03_monitoring_scripts/community_jkstill/general/e2ts-hires.sql) | `community_jkstill/general` | BASSO | OK | e2ts-hires.sql |
| [`e2ts.sql`](./03_monitoring_scripts/community_jkstill/general/e2ts.sql) | `community_jkstill/general` | BASSO | OK | convert a lowres (msec) epoch value to a timestamp |
| [`enqueue-bitand.sql`](./03_monitoring_scripts/community_jkstill/general/enqueue-bitand.sql) | `community_jkstill/general` | BASSO | OK | enqueue-bitand.sql |
| [`explain_plan_columns.sql`](./03_monitoring_scripts/community_jkstill/general/explain_plan_columns.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: explain plan columns. |
| [`find-index-sql.sql`](./03_monitoring_scripts/community_jkstill/general/find-index-sql.sql) | `community_jkstill/general` | BASSO | OK | find-index-sql.sql |
| [`findcol.sql`](./03_monitoring_scripts/community_jkstill/general/findcol.sql) | `community_jkstill/general` | BASSO | OK | findcol.sql - jared still |
| [`findobj.sql`](./03_monitoring_scripts/community_jkstill/general/findobj.sql) | `community_jkstill/general` | BASSO | OK | 08/07/2000 - jks - join on v$fixed_table |
| [`fk-circular-ref.sql`](./03_monitoring_scripts/community_jkstill/general/fk-circular-ref.sql) | `community_jkstill/general` | BASSO | OK | fk-circular-ref.sql |
| [`fk_hierarchy.sql`](./03_monitoring_scripts/community_jkstill/general/fk_hierarchy.sql) | `community_jkstill/general` | BASSO | OK | fk_hierarchy.sql |
| [`fktree-rcte.sql`](./03_monitoring_scripts/community_jkstill/general/fktree-rcte.sql) | `community_jkstill/general` | MEDIO | OK | fktree-rcte.sql |
| [`fktree.sql`](./03_monitoring_scripts/community_jkstill/general/fktree.sql) | `community_jkstill/general` | BASSO | OK | prototype SQL |
| [`full_sql_text.sql`](./03_monitoring_scripts/community_jkstill/general/full_sql_text.sql) | `community_jkstill/general` | MEDIO | OK | full_sql_text.sql |
| [`gen-post.sql`](./03_monitoring_scripts/community_jkstill/general/gen-post.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: gen post. |
| [`gen-pre.sql`](./03_monitoring_scripts/community_jkstill/general/gen-pre.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: gen pre. |
| [`gen_bind_vars.sql`](./03_monitoring_scripts/community_jkstill/general/gen_bind_vars.sql) | `community_jkstill/general` | MEDIO | OK | gen_bind_vars.sql |
| [`gen_bind_vars_awr-loop.sql`](./03_monitoring_scripts/community_jkstill/general/gen_bind_vars_awr-loop.sql) | `community_jkstill/general` | MEDIO | OK | gen_bind_vars_awr-loop.sql |
| [`gen_bind_vars_awr.sql`](./03_monitoring_scripts/community_jkstill/general/gen_bind_vars_awr.sql) | `community_jkstill/general` | MEDIO | OK | gen_bind_vars_awr.sql |
| [`gen_data_with_recursion.sql`](./03_monitoring_scripts/community_jkstill/general/gen_data_with_recursion.sql) | `community_jkstill/general` | BASSO | OK | gen_data_with_recursion.sql |
| [`gen_fk_from-11.1.sql`](./03_monitoring_scripts/community_jkstill/general/gen_fk_from-11.1.sql) | `community_jkstill/general` | MEDIO | OK | gen_fk_from-11.1.sql |
| [`gen_fk_from-11.2.sql`](./03_monitoring_scripts/community_jkstill/general/gen_fk_from-11.2.sql) | `community_jkstill/general` | MEDIO | OK | gen_fk_from-11.2.sql |
| [`gen_fk_to-11.1.sql`](./03_monitoring_scripts/community_jkstill/general/gen_fk_to-11.1.sql) | `community_jkstill/general` | MEDIO | OK | gen_fk_to-11.1.sql |
| [`gen_fk_to-11.2.sql`](./03_monitoring_scripts/community_jkstill/general/gen_fk_to-11.2.sql) | `community_jkstill/general` | MEDIO | OK | gen_fk_to-11.2.sql |
| [`gen_list_data_with_dual.sql`](./03_monitoring_scripts/community_jkstill/general/gen_list_data_with_dual.sql) | `community_jkstill/general` | BASSO | OK | gen_list_data_without_dual.sql |
| [`gen_list_data_without_dual.sql`](./03_monitoring_scripts/community_jkstill/general/gen_list_data_without_dual.sql) | `community_jkstill/general` | BASSO | OK | gen_list_data_without_dual.sql |
| [`generate-sql.sql`](./03_monitoring_scripts/community_jkstill/general/generate-sql.sql) | `community_jkstill/general` | BASSO | OK | generate-sql.sql |
| [`get-alert-log-location.sql`](./03_monitoring_scripts/community_jkstill/general/get-alert-log-location.sql) | `community_jkstill/general` | BASSO | OK | get-alert-log-location.sql |
| [`get-code-error-context.sql`](./03_monitoring_scripts/community_jkstill/general/get-code-error-context.sql) | `community_jkstill/general` | BASSO | OK | get-code-error-context.sql |
| [`get-curr-ospid.sql`](./03_monitoring_scripts/community_jkstill/general/get-curr-ospid.sql) | `community_jkstill/general` | BASSO | OK | get-curr-ospid.sql |
| [`get-missing-tablenames.sql`](./03_monitoring_scripts/community_jkstill/general/get-missing-tablenames.sql) | `community_jkstill/general` | BASSO | OK | get-missing-tablenames.sql |
| [`get-schema-name.sql`](./03_monitoring_scripts/community_jkstill/general/get-schema-name.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: get schema name. |
| [`get-schema-size.sql`](./03_monitoring_scripts/community_jkstill/general/get-schema-size.sql) | `community_jkstill/general` | BASSO | OK | get-schema-size.sql |
| [`get-sql-for-table.sql`](./03_monitoring_scripts/community_jkstill/general/get-sql-for-table.sql) | `community_jkstill/general` | BASSO | OK | get-sql-for-table.sql |
| [`get-table-name.sql`](./03_monitoring_scripts/community_jkstill/general/get-table-name.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: get table name. |
| [`get_awr_bind_values.sql`](./03_monitoring_scripts/community_jkstill/general/get_awr_bind_values.sql) | `community_jkstill/general` | BASSO | OK | get_awr_bind_values.sql |
| [`get_bind_values.sql`](./03_monitoring_scripts/community_jkstill/general/get_bind_values.sql) | `community_jkstill/general` | BASSO | OK | get_bind_values.sql |
| [`get_date_range.sql`](./03_monitoring_scripts/community_jkstill/general/get_date_range.sql) | `community_jkstill/general` | BASSO | OK | get_date_range.sql |
| [`get_prefs.sql`](./03_monitoring_scripts/community_jkstill/general/get_prefs.sql) | `community_jkstill/general` | MEDIO | OK | Script operativo Oracle per: get prefs. |
| [`get_sched_tz.sql`](./03_monitoring_scripts/community_jkstill/general/get_sched_tz.sql) | `community_jkstill/general` | MEDIO | OK | Diagnostica e controllo job Oracle Scheduler. |
| [`get_table_lock.sql`](./03_monitoring_scripts/community_jkstill/general/get_table_lock.sql) | `community_jkstill/general` | BASSO | OK | get_table_lock.sql |
| [`getallparm-12c.sql`](./03_monitoring_scripts/community_jkstill/general/getallparm-12c.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: getallparm 12c. |
| [`getallparm.sql`](./03_monitoring_scripts/community_jkstill/general/getallparm.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: getallparm. |
| [`getaud.sql`](./03_monitoring_scripts/community_jkstill/general/getaud.sql) | `community_jkstill/general` | ALTO | OK | SCRIPT: Generate AUDIT and NOAUDIT Statements for Current Audit Settings [ID 287436.1] |
| [`gethostname.sql`](./03_monitoring_scripts/community_jkstill/general/gethostname.sql) | `community_jkstill/general` | BASSO | OK | set term and feed off then back on when calling |
| [`getinstance.sql`](./03_monitoring_scripts/community_jkstill/general/getinstance.sql) | `community_jkstill/general` | BASSO | OK | set term and feed off then back on when calling |
| [`getinstanceowner.sql`](./03_monitoring_scripts/community_jkstill/general/getinstanceowner.sql) | `community_jkstill/general` | BASSO | OK | set term and feed off then back on when calling |
| [`getparm.sql`](./03_monitoring_scripts/community_jkstill/general/getparm.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: getparm. |
| [`getpid.sql`](./03_monitoring_scripts/community_jkstill/general/getpid.sql) | `community_jkstill/general` | BASSO | OK | set term and feed off then back on when calling |
| [`getsid.sql`](./03_monitoring_scripts/community_jkstill/general/getsid.sql) | `community_jkstill/general` | BASSO | OK | get sid for current session |
| [`getsql.sql`](./03_monitoring_scripts/community_jkstill/general/getsql.sql) | `community_jkstill/general` | BASSO | OK | which ever is an empty string indicates the mode used |
| [`gettracefile.sql`](./03_monitoring_scripts/community_jkstill/general/gettracefile.sql) | `community_jkstill/general` | BASSO | OK | copy the current sessions tracefile from the server |
| [`gettrcname.sql`](./03_monitoring_scripts/community_jkstill/general/gettrcname.sql) | `community_jkstill/general` | BASSO | OK | set term and feed off then back on when calling |
| [`global-prefs.sql`](./03_monitoring_scripts/community_jkstill/general/global-prefs.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: global prefs. |
| [`hash-function.sql`](./03_monitoring_scripts/community_jkstill/general/hash-function.sql) | `community_jkstill/general` | MEDIO | OK | error code here if desired |
| [`histo_dist.sql`](./03_monitoring_scripts/community_jkstill/general/histo_dist.sql) | `community_jkstill/general` | BASSO | OK | histo_dist.sql |
| [`histo_hist.sql`](./03_monitoring_scripts/community_jkstill/general/histo_hist.sql) | `community_jkstill/general` | BASSO | OK | histo_hist.sql |
| [`histo_hist_dist.sql`](./03_monitoring_scripts/community_jkstill/general/histo_hist_dist.sql) | `community_jkstill/general` | BASSO | OK | histo_hist_dist.sql |
| [`histo_types.sql`](./03_monitoring_scripts/community_jkstill/general/histo_types.sql) | `community_jkstill/general` | BASSO | OK | , abs(num_distinct - num_buckets) diff |
| [`host-cpu-metric-names.sql`](./03_monitoring_scripts/community_jkstill/general/host-cpu-metric-names.sql) | `community_jkstill/general` | MEDIO | OK | host-cpu-metric-names.sql |
| [`host-cpu.sql`](./03_monitoring_scripts/community_jkstill/general/host-cpu.sql) | `community_jkstill/general` | MEDIO | OK | host-cpu.sql |
| [`hwm-df.sql`](./03_monitoring_scripts/community_jkstill/general/hwm-df.sql) | `community_jkstill/general` | BASSO | OK | based on script from Connor McDonald |
| [`idle-events.sql`](./03_monitoring_scripts/community_jkstill/general/idle-events.sql) | `community_jkstill/general` | BASSO | OK | idle-events.sql |
| [`index-col-use-ratios.sql`](./03_monitoring_scripts/community_jkstill/general/index-col-use-ratios.sql) | `community_jkstill/general` | BASSO | OK | index-col-use-ratios.sql |
| [`index-correlate.sql`](./03_monitoring_scripts/community_jkstill/general/index-correlate.sql) | `community_jkstill/general` | BASSO | OK | index-correlate.sql |
| [`index-usage-awr.sql`](./03_monitoring_scripts/community_jkstill/general/index-usage-awr.sql) | `community_jkstill/general` | BASSO | OK | index-usage-awr.sql |
| [`index_by_table_demo.sql`](./03_monitoring_scripts/community_jkstill/general/index_by_table_demo.sql) | `community_jkstill/general` | BASSO | OK | since I can never seem to remember this simple syntax |
| [`iot_segments.sql`](./03_monitoring_scripts/community_jkstill/general/iot_segments.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: iot segments. |
| [`kglh-growth-awr.sql`](./03_monitoring_scripts/community_jkstill/general/kglh-growth-awr.sql) | `community_jkstill/general` | BASSO | OK | kglh-growth-awr.sql |
| [`kglh-growth.sql`](./03_monitoring_scripts/community_jkstill/general/kglh-growth.sql) | `community_jkstill/general` | BASSO | OK | kglh-growth.sql |
| [`latency_eventmetric.sql`](./03_monitoring_scripts/community_jkstill/general/latency_eventmetric.sql) | `community_jkstill/general` | BASSO | OK | wait event latency last minute |
| [`latency_system_event.sql`](./03_monitoring_scripts/community_jkstill/general/latency_system_event.sql) | `community_jkstill/general` | BASSO | OK | wait event latency averaged over each hour |
| [`latency_waitclassmetric.sql`](./03_monitoring_scripts/community_jkstill/general/latency_waitclassmetric.sql) | `community_jkstill/general` | BASSO | OK | wait event latency last minute |
| [`legacy-exclude.sql`](./03_monitoring_scripts/community_jkstill/general/legacy-exclude.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: legacy exclude. |
| [`liveplan-9i-hash.sql`](./03_monitoring_scripts/community_jkstill/general/liveplan-9i-hash.sql) | `community_jkstill/general` | BASSO | OK | liveplan-9i-hash.sql |
| [`liveplan-9i.sql`](./03_monitoring_scripts/community_jkstill/general/liveplan-9i.sql) | `community_jkstill/general` | BASSO | OK | liveplan-9i.sql |
| [`liveplan-hash.sql`](./03_monitoring_scripts/community_jkstill/general/liveplan-hash.sql) | `community_jkstill/general` | BASSO | OK | liveplan-hash.sql |
| [`liveplan-sqlid.sql`](./03_monitoring_scripts/community_jkstill/general/liveplan-sqlid.sql) | `community_jkstill/general` | BASSO | OK | liveplan-sqlid.sql |
| [`loghist-csv.sql`](./03_monitoring_scripts/community_jkstill/general/loghist-csv.sql) | `community_jkstill/general` | BASSO | OK | loghist-csv.sql |
| [`loghistory_8.sql`](./03_monitoring_scripts/community_jkstill/general/loghistory_8.sql) | `community_jkstill/general` | MEDIO | OK | loghistory_8.sql |
| [`logsetup.sql`](./03_monitoring_scripts/community_jkstill/general/logsetup.sql) | `community_jkstill/general` | BASSO | OK | logsetup.sql |
| [`mem-leak-detect.sql`](./03_monitoring_scripts/community_jkstill/general/mem-leak-detect.sql) | `community_jkstill/general` | BASSO | OK | mem-leak-detect.sql |
| [`mem-subpool-mgt.sql`](./03_monitoring_scripts/community_jkstill/general/mem-subpool-mgt.sql) | `community_jkstill/general` | ALTO | OK | mem-subpool-mgt.sql |
| [`my-events.sql`](./03_monitoring_scripts/community_jkstill/general/my-events.sql) | `community_jkstill/general` | BASSO | OK | and lower(event) like '%net%' |
| [`my-redo.sql`](./03_monitoring_scripts/community_jkstill/general/my-redo.sql) | `community_jkstill/general` | BASSO | OK | Jared Still 2023 |
| [`na-std-timezones.sql`](./03_monitoring_scripts/community_jkstill/general/na-std-timezones.sql) | `community_jkstill/general` | BASSO | OK | na-std-timezones.sql |
| [`numeric-timezone-abbrev.sql`](./03_monitoring_scripts/community_jkstill/general/numeric-timezone-abbrev.sql) | `community_jkstill/general` | BASSO | OK | numeric-timezone-abbreviations.sql |
| [`object-times.sql`](./03_monitoring_scripts/community_jkstill/general/object-times.sql) | `community_jkstill/general` | BASSO | OK | object-times.sql |
| [`object-types.sql`](./03_monitoring_scripts/community_jkstill/general/object-types.sql) | `community_jkstill/general` | BASSO | OK | object-types.sql |
| [`opcodes.sql`](./03_monitoring_scripts/community_jkstill/general/opcodes.sql) | `community_jkstill/general` | MEDIO | OK | do NOT add blank lines |
| [`opthist.sql`](./03_monitoring_scripts/community_jkstill/general/opthist.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: opthist. |
| [`oracle-data-types.sql`](./03_monitoring_scripts/community_jkstill/general/oracle-data-types.sql) | `community_jkstill/general` | BASSO | OK | oracle-data-types.sql |
| [`oracle-exclude-demo.sql`](./03_monitoring_scripts/community_jkstill/general/oracle-exclude-demo.sql) | `community_jkstill/general` | BASSO | OK | oracle-exclude-demo.sql |
| [`oracle-exclude-inline.sql`](./03_monitoring_scripts/community_jkstill/general/oracle-exclude-inline.sql) | `community_jkstill/general` | BASSO | OK | oracle-exclude-inline.sql |
| [`oracle-exclude-schema.sql`](./03_monitoring_scripts/community_jkstill/general/oracle-exclude-schema.sql) | `community_jkstill/general` | BASSO | OK | oracle-exclude-schema.sql |
| [`oracle-naming-inconsistencies.sql`](./03_monitoring_scripts/community_jkstill/general/oracle-naming-inconsistencies.sql) | `community_jkstill/general` | BASSO | OK | oracle-naming-inconsistencies.sql |
| [`oradebug_doc.sql`](./03_monitoring_scripts/community_jkstill/general/oradebug_doc.sql) | `community_jkstill/general` | BASSO | OK | oradebug_doc.sql |
| [`orapwdhash.sql`](./03_monitoring_scripts/community_jkstill/general/orapwdhash.sql) | `community_jkstill/general` | BASSO | OK | orapwdhash.sql |
| [`os-load.sql`](./03_monitoring_scripts/community_jkstill/general/os-load.sql) | `community_jkstill/general` | BASSO | OK | System load for the previous hour as reported by Oracle |
| [`oversion_major.sql`](./03_monitoring_scripts/community_jkstill/general/oversion_major.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: oversion major. |
| [`oversion_minor.sql`](./03_monitoring_scripts/community_jkstill/general/oversion_minor.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: oversion minor. |
| [`parameter-compare.sql`](./03_monitoring_scripts/community_jkstill/general/parameter-compare.sql) | `community_jkstill/general` | MEDIO | OK | parameter-compare.sql |
| [`parm-hist-diff.sql`](./03_monitoring_scripts/community_jkstill/general/parm-hist-diff.sql) | `community_jkstill/general` | BASSO | OK | and s.con_dbid = p.con_dbid |
| [`parms-diff.sql`](./03_monitoring_scripts/community_jkstill/general/parms-diff.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: parms diff. |
| [`parms-version-diff.sql`](./03_monitoring_scripts/community_jkstill/general/parms-version-diff.sql) | `community_jkstill/general` | BASSO | OK | parms-version-diff.sql |
| [`parms_dump_12c_csv.sql`](./03_monitoring_scripts/community_jkstill/general/parms_dump_12c_csv.sql) | `community_jkstill/general` | BASSO | OK | parms_dump_12c_csv.sql |
| [`parms_dump_csv.sql`](./03_monitoring_scripts/community_jkstill/general/parms_dump_csv.sql) | `community_jkstill/general` | BASSO | OK | parms_dump_csv.sql |
| [`pg.sql`](./03_monitoring_scripts/community_jkstill/general/pg.sql) | `community_jkstill/general` | BASSO | OK | setup pagesize and linesize |
| [`pivot.sql`](./03_monitoring_scripts/community_jkstill/general/pivot.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: pivot. |
| [`pq-ash-all.sql`](./03_monitoring_scripts/community_jkstill/general/pq-ash-all.sql) | `community_jkstill/general` | BASSO | OK | pq-ash-all.sql |
| [`pq-ash-sqlid.sql`](./03_monitoring_scripts/community_jkstill/general/pq-ash-sqlid.sql) | `community_jkstill/general` | BASSO | OK | pq-ash-sqlid.sql |
| [`pq-awr-all.sql`](./03_monitoring_scripts/community_jkstill/general/pq-awr-all.sql) | `community_jkstill/general` | BASSO | OK | pq-awr-all.sql |
| [`pq-awr-sqlid.sql`](./03_monitoring_scripts/community_jkstill/general/pq-awr-sqlid.sql) | `community_jkstill/general` | BASSO | OK | pq-awr-sqlid.sql |
| [`print_table_2.sql`](./03_monitoring_scripts/community_jkstill/general/print_table_2.sql) | `community_jkstill/general` | MEDIO | OK | print_table_2.sql |
| [`privileged-accounts.sql`](./03_monitoring_scripts/community_jkstill/general/privileged-accounts.sql) | `community_jkstill/general` | BASSO | OK | privileged-accounts.sql |
| [`privmaps.sql`](./03_monitoring_scripts/community_jkstill/general/privmaps.sql) | `community_jkstill/general` | BASSO | OK | privmaps.sql |
| [`purge_cursors.sql`](./03_monitoring_scripts/community_jkstill/general/purge_cursors.sql) | `community_jkstill/general` | BASSO | OK | purge_cursors.sql |
| [`q_quote.sql`](./03_monitoring_scripts/community_jkstill/general/q_quote.sql) | `community_jkstill/general` | BASSO | OK | example of the q quoting mechanism for string literals |
| [`raise_error.sql`](./03_monitoring_scripts/community_jkstill/general/raise_error.sql) | `community_jkstill/general` | BASSO | OK | raise_error.sql |
| [`rbs_shrink.sql`](./03_monitoring_scripts/community_jkstill/general/rbs_shrink.sql) | `community_jkstill/general` | MEDIO | OK | rbs_shrink.sql |
| [`redo-log-mirrors.sql`](./03_monitoring_scripts/community_jkstill/general/redo-log-mirrors.sql) | `community_jkstill/general` | BASSO | OK | redo-log-mirrors.sql |
| [`redo-per-hour.sql`](./03_monitoring_scripts/community_jkstill/general/redo-per-hour.sql) | `community_jkstill/general` | BASSO | OK | redo-per-hour.sql |
| [`remove-sqlplus-settings.sql`](./03_monitoring_scripts/community_jkstill/general/remove-sqlplus-settings.sql) | `community_jkstill/general` | BASSO | OK | bind var is :v_sqltempfile |
| [`reserved-words.sql`](./03_monitoring_scripts/community_jkstill/general/reserved-words.sql) | `community_jkstill/general` | BASSO | OK | where keyword like '%YOUR_WORD_HERE%' |
| [`resmgr-columns.sql`](./03_monitoring_scripts/community_jkstill/general/resmgr-columns.sql) | `community_jkstill/general` | BASSO | OK | resmgr-columns.sql |
| [`resmgr-consumer-groups.sql`](./03_monitoring_scripts/community_jkstill/general/resmgr-consumer-groups.sql) | `community_jkstill/general` | BASSO | OK | resmgr-consumer-groups.sql |
| [`resmgr-group-privs.sql`](./03_monitoring_scripts/community_jkstill/general/resmgr-group-privs.sql) | `community_jkstill/general` | BASSO | OK | resmgr-group-privs.sql |
| [`resmgr-plan-directives.sql`](./03_monitoring_scripts/community_jkstill/general/resmgr-plan-directives.sql) | `community_jkstill/general` | BASSO | OK | resmgr-plan-directives.sql |
| [`resmgr-setup.sql`](./03_monitoring_scripts/community_jkstill/general/resmgr-setup.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: resmgr setup. |
| [`resmgr-user-consumer-groups.sql`](./03_monitoring_scripts/community_jkstill/general/resmgr-user-consumer-groups.sql) | `community_jkstill/general` | BASSO | OK | resmgr-user-consumer-groups.sql |
| [`resmgr-waits.sql`](./03_monitoring_scripts/community_jkstill/general/resmgr-waits.sql) | `community_jkstill/general` | BASSO | OK | resmgr-waits.sql |
| [`resmgr-who.sql`](./03_monitoring_scripts/community_jkstill/general/resmgr-who.sql) | `community_jkstill/general` | BASSO | OK | resmgr-who.sql |
| [`restricted_session_disable.sql`](./03_monitoring_scripts/community_jkstill/general/restricted_session_disable.sql) | `community_jkstill/general` | ALTO | OK | Script operativo Oracle per: restricted session disable. |
| [`restricted_session_enable.sql`](./03_monitoring_scripts/community_jkstill/general/restricted_session_enable.sql) | `community_jkstill/general` | ALTO | OK | Script operativo Oracle per: restricted session enable. |
| [`reverse_role_lookup.sql`](./03_monitoring_scripts/community_jkstill/general/reverse_role_lookup.sql) | `community_jkstill/general` | BASSO | OK | reverse_role_lookup.sql |
| [`run-advice-scripts.sql`](./03_monitoring_scripts/community_jkstill/general/run-advice-scripts.sql) | `community_jkstill/general` | BASSO | OK | run all advice scripts |
| [`sampled_size.sql`](./03_monitoring_scripts/community_jkstill/general/sampled_size.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: sampled size. |
| [`sampled_size_details.sql`](./03_monitoring_scripts/community_jkstill/general/sampled_size_details.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: sampled size details. |
| [`save-sqlplus-settings.sql`](./03_monitoring_scripts/community_jkstill/general/save-sqlplus-settings.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: save sqlplus settings. |
| [`schedcols.sql`](./03_monitoring_scripts/community_jkstill/general/schedcols.sql) | `community_jkstill/general` | BASSO | OK | Diagnostica e controllo job Oracle Scheduler. |
| [`scott.sql`](./03_monitoring_scripts/community_jkstill/general/scott.sql) | `community_jkstill/general` | ALTO | OK | Copyright (c) Oracle Corporation 1988, 2000. All Rights Reserved |
| [`sess-event-summary.sql`](./03_monitoring_scripts/community_jkstill/general/sess-event-summary.sql) | `community_jkstill/general` | BASSO | OK | sess-event-summary.sql |
| [`sess_longops.sql`](./03_monitoring_scripts/community_jkstill/general/sess_longops.sql) | `community_jkstill/general` | BASSO | OK | sess_longops.sql |
| [`sessevent.sql`](./03_monitoring_scripts/community_jkstill/general/sessevent.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: sessevent. |
| [`sessevent2.sql`](./03_monitoring_scripts/community_jkstill/general/sessevent2.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: sessevent2. |
| [`session-cursor-metrics.sql`](./03_monitoring_scripts/community_jkstill/general/session-cursor-metrics.sql) | `community_jkstill/general` | BASSO | OK | session-cursor-metrics.sql |
| [`session-parm-diff.sql`](./03_monitoring_scripts/community_jkstill/general/session-parm-diff.sql) | `community_jkstill/general` | BASSO | OK | session-parm-diff.sql |
| [`session_fix.sql`](./03_monitoring_scripts/community_jkstill/general/session_fix.sql) | `community_jkstill/general` | BASSO | OK | File Name : http://www.oracle-base.com/dba/11g/session_fix.sql |
| [`set-default-profile-unlimited.sql`](./03_monitoring_scripts/community_jkstill/general/set-default-profile-unlimited.sql) | `community_jkstill/general` | MEDIO | OK | set-default-profile-unlimited.sql |
| [`set-tracefile-id-external.sql`](./03_monitoring_scripts/community_jkstill/general/set-tracefile-id-external.sql) | `community_jkstill/general` | BASSO | OK | set-tracefile-id-external.sql |
| [`set_date_format.sql`](./03_monitoring_scripts/community_jkstill/general/set_date_format.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: set date format. |
| [`set_dbid.sql`](./03_monitoring_scripts/community_jkstill/general/set_dbid.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: set dbid. |
| [`set_events.sql`](./03_monitoring_scripts/community_jkstill/general/set_events.sql) | `community_jkstill/general` | ALTO | OK | see http://blog.tanelpoder.com/2009/03/03/the-full-power-of-oracles-diagnostic-events-part-1-syntax-for-ksd-debug-event-handling |
| [`set_sess_tz.sql`](./03_monitoring_scripts/community_jkstill/general/set_sess_tz.sql) | `community_jkstill/general` | MEDIO | OK | Script operativo Oracle per: set sess tz. |
| [`set_table_prefs.sql`](./03_monitoring_scripts/community_jkstill/general/set_table_prefs.sql) | `community_jkstill/general` | MEDIO | OK | Script operativo Oracle per: set table prefs. |
| [`setc.sql`](./03_monitoring_scripts/community_jkstill/general/setc.sql) | `community_jkstill/general` | MEDIO | OK | set container |
| [`setup.sql`](./03_monitoring_scripts/community_jkstill/general/setup.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: setup. |
| [`show-fk.sql`](./03_monitoring_scripts/community_jkstill/general/show-fk.sql) | `community_jkstill/general` | BASSO | OK | show-fk.sql - report foreign key constraints |
| [`show-pk-with-idx.sql`](./03_monitoring_scripts/community_jkstill/general/show-pk-with-idx.sql) | `community_jkstill/general` | BASSO | OK | showpk.sql - show primary key constraints |
| [`show-pk.sql`](./03_monitoring_scripts/community_jkstill/general/show-pk.sql) | `community_jkstill/general` | BASSO | OK | show-pk.sql - show primary key constraints |
| [`show-uk.sql`](./03_monitoring_scripts/community_jkstill/general/show-uk.sql) | `community_jkstill/general` | BASSO | OK | show-uk.sql - show unique key constraints |
| [`show-x-dollar-tables.sql`](./03_monitoring_scripts/community_jkstill/general/show-x-dollar-tables.sql) | `community_jkstill/general` | BASSO | OK | show-x-dollar-tables.sql |
| [`show_active_log_dest.sql`](./03_monitoring_scripts/community_jkstill/general/show_active_log_dest.sql) | `community_jkstill/general` | BASSO | OK | show_active_log_test.sql |
| [`show_check_cons.sql`](./03_monitoring_scripts/community_jkstill/general/show_check_cons.sql) | `community_jkstill/general` | BASSO | OK | show_check_cons.sql |
| [`show_data_types.sql`](./03_monitoring_scripts/community_jkstill/general/show_data_types.sql) | `community_jkstill/general` | BASSO | OK | show_data_type.sql |
| [`show_event_messages.sql`](./03_monitoring_scripts/community_jkstill/general/show_event_messages.sql) | `community_jkstill/general` | BASSO | OK | show server event messages |
| [`show_logon_triggers.sql`](./03_monitoring_scripts/community_jkstill/general/show_logon_triggers.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: show logon triggers. |
| [`show_supp_logs.sql`](./03_monitoring_scripts/community_jkstill/general/show_supp_logs.sql) | `community_jkstill/general` | BASSO | OK | contents of gg_env.sql |
| [`showallparm.sql`](./03_monitoring_scripts/community_jkstill/general/showallparm.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: showallparm. |
| [`showallparm12c-drvr.sql`](./03_monitoring_scripts/community_jkstill/general/showallparm12c-drvr.sql) | `community_jkstill/general` | BASSO | OK | show all available init.ora parameters |
| [`showallparm73drvr.sql`](./03_monitoring_scripts/community_jkstill/general/showallparm73drvr.sql) | `community_jkstill/general` | BASSO | OK | show all available init.ora parameters |
| [`showcol.sql`](./03_monitoring_scripts/community_jkstill/general/showcol.sql) | `community_jkstill/general` | BASSO | OK | show column details and comments for a table |
| [`showdb.sql`](./03_monitoring_scripts/community_jkstill/general/showdb.sql) | `community_jkstill/general` | ALTO | OK | select * from v$database |
| [`showdblink.sql`](./03_monitoring_scripts/community_jkstill/general/showdblink.sql) | `community_jkstill/general` | MEDIO | OK | Script operativo Oracle per: showdblink. |
| [`showdis.sql`](./03_monitoring_scripts/community_jkstill/general/showdis.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: showdis. |
| [`showdiscon.sql`](./03_monitoring_scripts/community_jkstill/general/showdiscon.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: showdiscon. |
| [`showdistrg.sql`](./03_monitoring_scripts/community_jkstill/general/showdistrg.sql) | `community_jkstill/general` | BASSO | OK | showdistrg.sql |
| [`showindex.sql`](./03_monitoring_scripts/community_jkstill/general/showindex.sql) | `community_jkstill/general` | BASSO | OK | showindex.sql |
| [`showinv.sql`](./03_monitoring_scripts/community_jkstill/general/showinv.sql) | `community_jkstill/general` | BASSO | OK | jkstill - 11/30/2006 |
| [`showkey.sql`](./03_monitoring_scripts/community_jkstill/general/showkey.sql) | `community_jkstill/general` | BASSO | OK | find primary and unique keys, |
| [`showlog.sql`](./03_monitoring_scripts/community_jkstill/general/showlog.sql) | `community_jkstill/general` | BASSO | OK | and l.inst_id = f.inst_id |
| [`showmem.sql`](./03_monitoring_scripts/community_jkstill/general/showmem.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: showmem. |
| [`shownls.sql`](./03_monitoring_scripts/community_jkstill/general/shownls.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: shownls. |
| [`showparm.sql`](./03_monitoring_scripts/community_jkstill/general/showparm.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: showparm. |
| [`showparmchanges.sql`](./03_monitoring_scripts/community_jkstill/general/showparmchanges.sql) | `community_jkstill/general` | BASSO | OK | showparmchanges.sql |
| [`showparmdrvr.sql`](./03_monitoring_scripts/community_jkstill/general/showparmdrvr.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: showparmdrvr. |
| [`showpin.sql`](./03_monitoring_scripts/community_jkstill/general/showpin.sql) | `community_jkstill/general` | BASSO | OK | show objects that are pinned in the shared pool |
| [`showpipes.sql`](./03_monitoring_scripts/community_jkstill/general/showpipes.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: showpipes. |
| [`showplan-all.sql`](./03_monitoring_scripts/community_jkstill/general/showplan-all.sql) | `community_jkstill/general` | BASSO | OK | showplan_all.sql |
| [`showplan-awr.sql`](./03_monitoring_scripts/community_jkstill/general/showplan-awr.sql) | `community_jkstill/general` | BASSO | OK | showplan_awr.sql |
| [`showplan-last.sql`](./03_monitoring_scripts/community_jkstill/general/showplan-last.sql) | `community_jkstill/general` | BASSO | OK | showplan_last.sql |
| [`showplan72.sql`](./03_monitoring_scripts/community_jkstill/general/showplan72.sql) | `community_jkstill/general` | BASSO | OK | showplan72.sql |
| [`showplan73.sql`](./03_monitoring_scripts/community_jkstill/general/showplan73.sql) | `community_jkstill/general` | BASSO | OK | showplan73.sql |
| [`showplan9i.sql`](./03_monitoring_scripts/community_jkstill/general/showplan9i.sql) | `community_jkstill/general` | BASSO | OK | showplan9i.sql |
| [`showpriv.sql`](./03_monitoring_scripts/community_jkstill/general/showpriv.sql) | `community_jkstill/general` | BASSO | OK | showpriv.sql |
| [`showprofile.sql`](./03_monitoring_scripts/community_jkstill/general/showprofile.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: showprofile. |
| [`showrbs.sql`](./03_monitoring_scripts/community_jkstill/general/showrbs.sql) | `community_jkstill/general` | BASSO | OK | spool rbs.lis |
| [`showrbslock.sql`](./03_monitoring_scripts/community_jkstill/general/showrbslock.sql) | `community_jkstill/general` | BASSO | OK | from Tim Sawmiller |
| [`showrole.sql`](./03_monitoring_scripts/community_jkstill/general/showrole.sql) | `community_jkstill/general` | BASSO | OK | showrole.sql |
| [`showroles.sql`](./03_monitoring_scripts/community_jkstill/general/showroles.sql) | `community_jkstill/general` | BASSO | OK | showpriv.sql |
| [`showsrc.sql`](./03_monitoring_scripts/community_jkstill/general/showsrc.sql) | `community_jkstill/general` | BASSO | OK | ed src-&uowner..txt |
| [`showtab.sql`](./03_monitoring_scripts/community_jkstill/general/showtab.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: showtab. |
| [`showview.sql`](./03_monitoring_scripts/community_jkstill/general/showview.sql) | `community_jkstill/general` | BASSO | OK | select view_name, view_definition |
| [`snap_ids.sql`](./03_monitoring_scripts/community_jkstill/general/snap_ids.sql) | `community_jkstill/general` | BASSO | OK | Set up the binds for dbid and instance_number |
| [`snapNmin.sql`](./03_monitoring_scripts/community_jkstill/general/snapNmin.sql) | `community_jkstill/general` | BASSO | OK | take a two minute snapshot at level 7 |
| [`sp_current.sql`](./03_monitoring_scripts/community_jkstill/general/sp_current.sql) | `community_jkstill/general` | BASSO | OK | sp_current.sql |
| [`sp_get_date_range.sql`](./03_monitoring_scripts/community_jkstill/general/sp_get_date_range.sql) | `community_jkstill/general` | BASSO | OK | sp_get_date_range.sql |
| [`sp_getsql.sql`](./03_monitoring_scripts/community_jkstill/general/sp_getsql.sql) | `community_jkstill/general` | BASSO | OK | sp_getsql.sql |
| [`sp_lvl_0.sql`](./03_monitoring_scripts/community_jkstill/general/sp_lvl_0.sql) | `community_jkstill/general` | BASSO | OK | change statspack to level 0 |
| [`sp_lvl_5.sql`](./03_monitoring_scripts/community_jkstill/general/sp_lvl_5.sql) | `community_jkstill/general` | BASSO | OK | change statspack to level 0 |
| [`sp_lvl_6.sql`](./03_monitoring_scripts/community_jkstill/general/sp_lvl_6.sql) | `community_jkstill/general` | BASSO | OK | change statspack to level 6 |
| [`sp_lvl_7.sql`](./03_monitoring_scripts/community_jkstill/general/sp_lvl_7.sql) | `community_jkstill/general` | BASSO | OK | change statspack to level 6 |
| [`sp_lvl_current.sql`](./03_monitoring_scripts/community_jkstill/general/sp_lvl_current.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: sp lvl current. |
| [`sp_lvl_sql.sql`](./03_monitoring_scripts/community_jkstill/general/sp_lvl_sql.sql) | `community_jkstill/general` | BASSO | OK | change statspack SQL collection levels |
| [`sp_plan.sql`](./03_monitoring_scripts/community_jkstill/general/sp_plan.sql) | `community_jkstill/general` | BASSO | OK | display historic execution plans |
| [`sp_plan_hash.sql`](./03_monitoring_scripts/community_jkstill/general/sp_plan_hash.sql) | `community_jkstill/general` | BASSO | OK | sp_plan_hash.sql |
| [`sp_plan_table.sql`](./03_monitoring_scripts/community_jkstill/general/sp_plan_table.sql) | `community_jkstill/general` | MEDIO | OK | sp_plan_table.sql |
| [`sp_recent.sql`](./03_monitoring_scripts/community_jkstill/general/sp_recent.sql) | `community_jkstill/general` | BASSO | OK | sp_recent.sql |
| [`sp_snap.sql`](./03_monitoring_scripts/community_jkstill/general/sp_snap.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: sp snap. |
| [`sp_snap_6.sql`](./03_monitoring_scripts/community_jkstill/general/sp_snap_6.sql) | `community_jkstill/general` | BASSO | OK | sp_snap_6.sql |
| [`sp_snap_id.sql`](./03_monitoring_scripts/community_jkstill/general/sp_snap_id.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: sp snap id. |
| [`spacemap.sql`](./03_monitoring_scripts/community_jkstill/general/spacemap.sql) | `community_jkstill/general` | ALTO | OK | spacemap.sql |
| [`spacemap_rpt.sql`](./03_monitoring_scripts/community_jkstill/general/spacemap_rpt.sql) | `community_jkstill/general` | BASSO | OK | spacemap_rpt.sql |
| [`spacemap_sum.sql`](./03_monitoring_scripts/community_jkstill/general/spacemap_sum.sql) | `community_jkstill/general` | ALTO | OK | spacemap_sum.sql |
| [`spacemap_sum_rpt.sql`](./03_monitoring_scripts/community_jkstill/general/spacemap_sum_rpt.sql) | `community_jkstill/general` | BASSO | OK | spacemap_sum_rpt.sql |
| [`spool-example-2.sql`](./03_monitoring_scripts/community_jkstill/general/spool-example-2.sql) | `community_jkstill/general` | BASSO | OK | template for spooling a logfile with timestamp |
| [`spool_example.sql`](./03_monitoring_scripts/community_jkstill/general/spool_example.sql) | `community_jkstill/general` | MEDIO | OK | trimspool for older versions - <= 9i I think |
| [`spreport.sql`](./03_monitoring_scripts/community_jkstill/general/spreport.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: spreport. |
| [`sql-command-types.sql`](./03_monitoring_scripts/community_jkstill/general/sql-command-types.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: sql command types. |
| [`sql-patch-report.sql`](./03_monitoring_scripts/community_jkstill/general/sql-patch-report.sql) | `community_jkstill/general` | BASSO | OK | sql-patch-report.sql |
| [`sql-read-write-size-sql.sql`](./03_monitoring_scripts/community_jkstill/general/sql-read-write-size-sql.sql) | `community_jkstill/general` | BASSO | OK | sql-read-write-size-sql.sql |
| [`sql-read-write-size.sql`](./03_monitoring_scripts/community_jkstill/general/sql-read-write-size.sql) | `community_jkstill/general` | BASSO | OK | sql-read-write-size.sql |
| [`sql-version-counts.sql`](./03_monitoring_scripts/community_jkstill/general/sql-version-counts.sql) | `community_jkstill/general` | BASSO | OK | sql-version-counts |
| [`sql_current_plan.sql`](./03_monitoring_scripts/community_jkstill/general/sql_current_plan.sql) | `community_jkstill/general` | BASSO | OK | sql_current_plan.sql |
| [`sql_spawned_reasons.sql`](./03_monitoring_scripts/community_jkstill/general/sql_spawned_reasons.sql) | `community_jkstill/general` | BASSO | OK | sql_spawned_reasons.sql |
| [`sql_trick_1.sql`](./03_monitoring_scripts/community_jkstill/general/sql_trick_1.sql) | `community_jkstill/general` | BASSO | OK | sql_trick_1.sql |
| [`sqlid-trace.sql`](./03_monitoring_scripts/community_jkstill/general/sqlid-trace.sql) | `community_jkstill/general` | ALTO | OK | trace a particular sqlid regardless of session |
| [`sqlplus_return_code.sql`](./03_monitoring_scripts/community_jkstill/general/sqlplus_return_code.sql) | `community_jkstill/general` | ALTO | OK | run some PL/SQL |
| [`sqlplus_return_code_2.sql`](./03_monitoring_scripts/community_jkstill/general/sqlplus_return_code_2.sql) | `community_jkstill/general` | MEDIO | OK | sqlplus_return_code_2.sql |
| [`supp-col-info.sql`](./03_monitoring_scripts/community_jkstill/general/supp-col-info.sql) | `community_jkstill/general` | BASSO | OK | supp-col-info.sql |
| [`supp-db-info.sql`](./03_monitoring_scripts/community_jkstill/general/supp-db-info.sql) | `community_jkstill/general` | BASSO | OK | supp-db-info.sql |
| [`supp-tab-info.sql`](./03_monitoring_scripts/community_jkstill/general/supp-tab-info.sql) | `community_jkstill/general` | BASSO | OK | supp-tab-info.sql |
| [`sys-context-all.sql`](./03_monitoring_scripts/community_jkstill/general/sys-context-all.sql) | `community_jkstill/general` | BASSO | OK | sys-context-all.sql |
| [`sys_context.sql`](./03_monitoring_scripts/community_jkstill/general/sys_context.sql) | `community_jkstill/general` | BASSO | OK | sys_context.sql |
| [`sysaux_free.sql`](./03_monitoring_scripts/community_jkstill/general/sysaux_free.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: sysaux free. |
| [`sysevent-top-10.sql`](./03_monitoring_scripts/community_jkstill/general/sysevent-top-10.sql) | `community_jkstill/general` | BASSO | OK | sysevent-top-10.sql |
| [`sysevent_begin.sql`](./03_monitoring_scripts/community_jkstill/general/sysevent_begin.sql) | `community_jkstill/general` | ALTO | OK | time_waited/100 time_waited, |
| [`sysevent_end.sql`](./03_monitoring_scripts/community_jkstill/general/sysevent_end.sql) | `community_jkstill/general` | ALTO | OK | time_waited/100 time_waited, |
| [`sysevent_rpt.sql`](./03_monitoring_scripts/community_jkstill/general/sysevent_rpt.sql) | `community_jkstill/general` | BASSO | OK | set the start_time |
| [`system_fix.sql`](./03_monitoring_scripts/community_jkstill/general/system_fix.sql) | `community_jkstill/general` | BASSO | OK | File Name : http://www.oracle-base.com/dba/11g/system_fix.sql |
| [`system_fix_all.sql`](./03_monitoring_scripts/community_jkstill/general/system_fix_all.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: system fix all. |
| [`tabcols.sql`](./03_monitoring_scripts/community_jkstill/general/tabcols.sql) | `community_jkstill/general` | BASSO | OK | show columns in alpha order for owner and table |
| [`tabidx.sql`](./03_monitoring_scripts/community_jkstill/general/tabidx.sql) | `community_jkstill/general` | BASSO | OK | show indexes per table |
| [`table-annotations.sql`](./03_monitoring_scripts/community_jkstill/general/table-annotations.sql) | `community_jkstill/general` | BASSO | OK | table-annotations.sql |
| [`table_ddl.sql`](./03_monitoring_scripts/community_jkstill/general/table_ddl.sql) | `community_jkstill/general` | BASSO | OK | table_ddl.sql |
| [`table_list.sql`](./03_monitoring_scripts/community_jkstill/general/table_list.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: table list. |
| [`test_calendar_string-examples.sql`](./03_monitoring_scripts/community_jkstill/general/test_calendar_string-examples.sql) | `community_jkstill/general` | BASSO | OK | between 07:00 and 23:59 repeat every 15 minutes on the 15 minute mark |
| [`test_calendar_string.sql`](./03_monitoring_scripts/community_jkstill/general/test_calendar_string.sql) | `community_jkstill/general` | MEDIO | OK | File Name : https://oracle-base.com/dba/10g/test_calendar_string.sql |
| [`title.sql`](./03_monitoring_scripts/community_jkstill/general/title.sql) | `community_jkstill/general` | BASSO | OK | title.sql - copied from title80.sql |
| [`title132.sql`](./03_monitoring_scripts/community_jkstill/general/title132.sql) | `community_jkstill/general` | BASSO | OK | DATABASE||' Database' DATABASE, |
| [`title80.sql`](./03_monitoring_scripts/community_jkstill/general/title80.sql) | `community_jkstill/general` | BASSO | OK | DATABASE||' Database' DATABASE, |
| [`tracefile-dump.sql`](./03_monitoring_scripts/community_jkstill/general/tracefile-dump.sql) | `community_jkstill/general` | BASSO | OK | tracefile-dump.sql |
| [`tracefile.sql`](./03_monitoring_scripts/community_jkstill/general/tracefile.sql) | `community_jkstill/general` | BASSO | OK | tracefile.sql |
| [`troff.sql`](./03_monitoring_scripts/community_jkstill/general/troff.sql) | `community_jkstill/general` | BASSO | OK | turn off tracing for all current sessions of a user |
| [`tron.sql`](./03_monitoring_scripts/community_jkstill/general/tron.sql) | `community_jkstill/general` | BASSO | OK | turn on tracing for all current sessions of a user |
| [`ts2e-hires.sql`](./03_monitoring_scripts/community_jkstill/general/ts2e-hires.sql) | `community_jkstill/general` | BASSO | OK | ts2e-hires.sql |
| [`ts2e.sql`](./03_monitoring_scripts/community_jkstill/general/ts2e.sql) | `community_jkstill/general` | BASSO | OK | convert a timestamp to highres (usec) epoch value |
| [`ttitle.sql`](./03_monitoring_scripts/community_jkstill/general/ttitle.sql) | `community_jkstill/general` | BASSO | OK | set the current time |
| [`tz_set.sql`](./03_monitoring_scripts/community_jkstill/general/tz_set.sql) | `community_jkstill/general` | MEDIO | OK | Script operativo Oracle per: tz set. |
| [`ua-actions.sql`](./03_monitoring_scripts/community_jkstill/general/ua-actions.sql) | `community_jkstill/general` | BASSO | OK | ua-actions.sql |
| [`ua-policies.sql`](./03_monitoring_scripts/community_jkstill/general/ua-policies.sql) | `community_jkstill/general` | BASSO | OK | where policy_name = 'ORA_ACCOUNT_MGMT' |
| [`ua-sessions.sql`](./03_monitoring_scripts/community_jkstill/general/ua-sessions.sql) | `community_jkstill/general` | MEDIO | OK | ua-session.sql |
| [`uifk.sql`](./03_monitoring_scripts/community_jkstill/general/uifk.sql) | `community_jkstill/general` | BASSO | OK | format data from user_uifk |
| [`uifk_gen.sql`](./03_monitoring_scripts/community_jkstill/general/uifk_gen.sql) | `community_jkstill/general` | MEDIO | OK | gen_uifk.sql |
| [`uifk_v.sql`](./03_monitoring_scripts/community_jkstill/general/uifk_v.sql) | `community_jkstill/general` | MEDIO | OK | adapted from a script by Tom Kyte that is used to |
| [`undo-active-12c.sql`](./03_monitoring_scripts/community_jkstill/general/undo-active-12c.sql) | `community_jkstill/general` | BASSO | OK | undo-active-12c.sql |
| [`undo-active.sql`](./03_monitoring_scripts/community_jkstill/general/undo-active.sql) | `community_jkstill/general` | BASSO | OK | undo-active.sql |
| [`undo-mon-fast.sql`](./03_monitoring_scripts/community_jkstill/general/undo-mon-fast.sql) | `community_jkstill/general` | BASSO | OK | undo-mon-fast.sql |
| [`undo-mon-trans.sql`](./03_monitoring_scripts/community_jkstill/general/undo-mon-trans.sql) | `community_jkstill/general` | BASSO | OK | undo-mon-trans.sql |
| [`uptime.sql`](./03_monitoring_scripts/community_jkstill/general/uptime.sql) | `community_jkstill/general` | BASSO | OK | uptime.sql - show db uptime |
| [`user-modifiable-all-parms.sql`](./03_monitoring_scripts/community_jkstill/general/user-modifiable-all-parms.sql) | `community_jkstill/general` | BASSO | OK | a.KSPPITY TYPE |
| [`user-modifiable-parms.sql`](./03_monitoring_scripts/community_jkstill/general/user-modifiable-parms.sql) | `community_jkstill/general` | BASSO | OK | user-modifiable-parms.sql |
| [`user_ddl.sql`](./03_monitoring_scripts/community_jkstill/general/user_ddl.sql) | `community_jkstill/general` | BASSO | OK | user_ddl.sql |
| [`user_exit.sql`](./03_monitoring_scripts/community_jkstill/general/user_exit.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: user exit. |
| [`utl_file-test.sql`](./03_monitoring_scripts/community_jkstill/general/utl_file-test.sql) | `community_jkstill/general` | MEDIO | OK | utl_file-test.sql |
| [`wait_chains.sql`](./03_monitoring_scripts/community_jkstill/general/wait_chains.sql) | `community_jkstill/general` | BASSO | OK | Oracle Support Note |
| [`wc-legend.sql`](./03_monitoring_scripts/community_jkstill/general/wc-legend.sql) | `community_jkstill/general` | BASSO | OK | the alternative list with punctuation looks more interesting |
| [`xb.sql`](./03_monitoring_scripts/community_jkstill/general/xb.sql) | `community_jkstill/general` | MEDIO | OK | Copyright 2018 Tanel Poder. All rights reserved. More info at http://tanelpoder.com |
| [`xbi.sql`](./03_monitoring_scripts/community_jkstill/general/xbi.sql) | `community_jkstill/general` | MEDIO | OK | Copyright 2018 Tanel Poder. All rights reserved. More info at http://tanelpoder.com |
| [`xdesc-all.sql`](./03_monitoring_scripts/community_jkstill/general/xdesc-all.sql) | `community_jkstill/general` | BASSO | OK | 30 char for colname |
| [`xdesc.sql`](./03_monitoring_scripts/community_jkstill/general/xdesc.sql) | `community_jkstill/general` | BASSO | OK | DBMS_SQL ref, including the record types |
| [`xdllr-abstract-list.sql`](./03_monitoring_scripts/community_jkstill/general/xdllr-abstract-list.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: xdllr abstract list. |
| [`xdllr-comments.sql`](./03_monitoring_scripts/community_jkstill/general/xdllr-comments.sql) | `community_jkstill/general` | MEDIO | OK | Script operativo Oracle per: xdllr comments. |
| [`xdllr-info.sql`](./03_monitoring_scripts/community_jkstill/general/xdllr-info.sql) | `community_jkstill/general` | BASSO | OK | scan must be off as there may be a number of ampersand characters in the comments |
| [`xdllr-tablist.sql`](./03_monitoring_scripts/community_jkstill/general/xdllr-tablist.sql) | `community_jkstill/general` | BASSO | OK | Script operativo Oracle per: xdllr tablist. |
| [`archived_log_dest.sql`](./03_monitoring_scripts/community_jkstill/instance_db/archived_log_dest.sql) | `community_jkstill/instance_db` | BASSO | OK | Script operativo Oracle per: archived log dest. |
| [`archived_log_hist_matrix.sql`](./03_monitoring_scripts/community_jkstill/instance_db/archived_log_hist_matrix.sql) | `community_jkstill/instance_db` | BASSO | OK | archived_log_hist_matrix.sql |
| [`archived_log_sums.sql`](./03_monitoring_scripts/community_jkstill/instance_db/archived_log_sums.sql) | `community_jkstill/instance_db` | BASSO | OK | archived_log_sums.sql |
| [`feature-usage.sql`](./03_monitoring_scripts/community_jkstill/instance_db/feature-usage.sql) | `community_jkstill/instance_db` | BASSO | OK | where detected_usages != 0 |
| [`incarnations.sql`](./03_monitoring_scripts/community_jkstill/instance_db/incarnations.sql) | `community_jkstill/instance_db` | BASSO | OK | incarnations.sql |
| [`nls_date_format.sql`](./03_monitoring_scripts/community_jkstill/instance_db/nls_date_format.sql) | `community_jkstill/instance_db` | MEDIO | OK | nls_date_format.sql |
| [`nls_time_format.sql`](./03_monitoring_scripts/community_jkstill/instance_db/nls_time_format.sql) | `community_jkstill/instance_db` | MEDIO | OK | Script operativo Oracle per: nls time format. |
| [`options.sql`](./03_monitoring_scripts/community_jkstill/instance_db/options.sql) | `community_jkstill/instance_db` | BASSO | OK | Script operativo Oracle per: options. |
| [`showobjprivs.sql`](./03_monitoring_scripts/community_jkstill/instance_db/showobjprivs.sql) | `community_jkstill/instance_db` | BASSO | OK | grantor.name grantor, |
| [`showsga.sql`](./03_monitoring_scripts/community_jkstill/instance_db/showsga.sql) | `community_jkstill/instance_db` | BASSO | OK | col name format |
| [`avg_disk_times.sql`](./03_monitoring_scripts/community_jkstill/io_redo/avg_disk_times.sql) | `community_jkstill/io_redo` | BASSO | OK | Verifica storage ASM: stato dischi, performance e configurazione. |
| [`io_begin.sql`](./03_monitoring_scripts/community_jkstill/io_redo/io_begin.sql) | `community_jkstill/io_redo` | ALTO | OK | must truncate GTT before dropping |
| [`io_end.sql`](./03_monitoring_scripts/community_jkstill/io_redo/io_end.sql) | `community_jkstill/io_redo` | ALTO | OK | must truncate GTT before dropping |
| [`io_order.sql`](./03_monitoring_scripts/community_jkstill/io_redo/io_order.sql) | `community_jkstill/io_redo` | BASSO | OK | io_order.sql |
| [`io_stat.sql`](./03_monitoring_scripts/community_jkstill/io_redo/io_stat.sql) | `community_jkstill/io_redo` | BASSO | OK | first run 'io_begin.sql' |
| [`io_stat2.sql`](./03_monitoring_scripts/community_jkstill/io_redo/io_stat2.sql) | `community_jkstill/io_redo` | BASSO | OK | first run 'io_begin.sql' |
| [`io_stat3.sql`](./03_monitoring_scripts/community_jkstill/io_redo/io_stat3.sql) | `community_jkstill/io_redo` | BASSO | OK | first run 'io_begin.sql' |
| [`io_tbs.sql`](./03_monitoring_scripts/community_jkstill/io_redo/io_tbs.sql) | `community_jkstill/io_redo` | BASSO | OK | spool io_tbs.txt |
| [`ioweight.sql`](./03_monitoring_scripts/community_jkstill/io_redo/ioweight.sql) | `community_jkstill/io_redo` | BASSO | OK | spool err.txt |
| [`lfsdiag.sql`](./03_monitoring_scripts/community_jkstill/io_redo/lfsdiag.sql) | `community_jkstill/io_redo` | MEDIO | OK | NAME: LFSDIAG.SQL |
| [`redo-per-second.sql`](./03_monitoring_scripts/community_jkstill/io_redo/redo-per-second.sql) | `community_jkstill/io_redo` | BASSO | OK | redo-per-second.sql |
| [`redo-rate.sql`](./03_monitoring_scripts/community_jkstill/io_redo/redo-rate.sql) | `community_jkstill/io_redo` | BASSO | OK | redo-rate.sql |
| [`showtrans.sql`](./03_monitoring_scripts/community_jkstill/io_redo/showtrans.sql) | `community_jkstill/io_redo` | BASSO | OK | spool showtrans.txt |
| [`trans_per_hour.sql`](./03_monitoring_scripts/community_jkstill/io_redo/trans_per_hour.sql) | `community_jkstill/io_redo` | ALTO | OK | trans_per_hour.sql |
| [`who5.sql`](./03_monitoring_scripts/community_jkstill/io_redo/who5.sql) | `community_jkstill/io_redo` | BASSO | OK | taken from OraMag Code Depot ( and slightly modified ) |
| [`metric-names.sql`](./03_monitoring_scripts/community_jkstill/metrics/metric-names.sql) | `community_jkstill/metrics` | BASSO | OK | metric-names.sql |
| [`metrics-available-ash.sql`](./03_monitoring_scripts/community_jkstill/metrics/metrics-available-ash.sql) | `community_jkstill/metrics` | BASSO | OK | metrics-available-ash.sql |
| [`metrics-available-awr.sql`](./03_monitoring_scripts/community_jkstill/metrics/metrics-available-awr.sql) | `community_jkstill/metrics` | BASSO | OK | metrics-available-awr.sql |
| [`metrics-available.sql`](./03_monitoring_scripts/community_jkstill/metrics/metrics-available.sql) | `community_jkstill/metrics` | BASSO | OK | metrics-available.sql |
| [`metrics-not-saved-in-awr.sql`](./03_monitoring_scripts/community_jkstill/metrics/metrics-not-saved-in-awr.sql) | `community_jkstill/metrics` | BASSO | OK | metrics-not-saved-in-awr.sql |
| [`sysmetric-cpu-seconds-summary.sql`](./03_monitoring_scripts/community_jkstill/metrics/sysmetric-cpu-seconds-summary.sql) | `community_jkstill/metrics` | BASSO | OK | sysmetric-cpu-seconds-summary.sql |
| [`ash-snapshot-define-begin-end.sql`](./03_monitoring_scripts/community_jkstill/mviews/ash-snapshot-define-begin-end.sql) | `community_jkstill/mviews` | BASSO | OK | ash-snapshot-define-begin-end.sql |
| [`awr_create_snapshot.sql`](./03_monitoring_scripts/community_jkstill/mviews/awr_create_snapshot.sql) | `community_jkstill/mviews` | BASSO | OK | Analisi AWR per trend prestazionali e identificazione root cause. |
| [`awr_get_snapshots.sql`](./03_monitoring_scripts/community_jkstill/mviews/awr_get_snapshots.sql) | `community_jkstill/mviews` | BASSO | OK | awr_get_snapshots.sql |
| [`deregister_snapshots.sql`](./03_monitoring_scripts/community_jkstill/mviews/deregister_snapshots.sql) | `community_jkstill/mviews` | BASSO | OK | deregister_snapshots.sql |
| [`show_mview_status.sql`](./03_monitoring_scripts/community_jkstill/mviews/show_mview_status.sql) | `community_jkstill/mviews` | BASSO | OK | Script operativo Oracle per: show mview status. |
| [`showregistered_snapshots.sql`](./03_monitoring_scripts/community_jkstill/mviews/showregistered_snapshots.sql) | `community_jkstill/mviews` | BASSO | OK | show all registered snapshots at master site |
| [`showsnapshot_logs.sql`](./03_monitoring_scripts/community_jkstill/mviews/showsnapshot_logs.sql) | `community_jkstill/mviews` | BASSO | OK | ,log_trigger |
| [`showsnapshot_sites.sql`](./03_monitoring_scripts/community_jkstill/mviews/showsnapshot_sites.sql) | `community_jkstill/mviews` | BASSO | OK | showsnapshot_sites.sql |
| [`showsnapshots.sql`](./03_monitoring_scripts/community_jkstill/mviews/showsnapshots.sql) | `community_jkstill/mviews` | BASSO | OK | , decode(r.rname, null, '-NO REFRESH-',rname, decode(s.refresh_mode,'COMMIT','NA'), 'UNKNOWN') |
| [`cursor-invalidation-reasons.sql`](./03_monitoring_scripts/community_jkstill/plsql/cursor-invalidation-reasons.sql) | `community_jkstill/plsql` | BASSO | OK | cursor-invalidation-reasons.sql |
| [`invalid.sql`](./03_monitoring_scripts/community_jkstill/plsql/invalid.sql) | `community_jkstill/plsql` | BASSO | OK | jkstill - 11/30/2006 |
| [`plsql-error.sql`](./03_monitoring_scripts/community_jkstill/plsql/plsql-error.sql) | `community_jkstill/plsql` | BASSO | OK | plsql-error.sql |
| [`plsql-init.sql`](./03_monitoring_scripts/community_jkstill/plsql/plsql-init.sql) | `community_jkstill/plsql` | MEDIO | OK | setup plscope |
| [`plsql-return-bool-from-sql.sql`](./03_monitoring_scripts/community_jkstill/plsql/plsql-return-bool-from-sql.sql) | `community_jkstill/plsql` | BASSO | OK | plsql-return-bool-from-sql.sql |
| [`plsql_called_objects.sql`](./03_monitoring_scripts/community_jkstill/plsql/plsql_called_objects.sql) | `community_jkstill/plsql` | BASSO | OK | plsql_called_objects.sql |
| [`recompile.sql`](./03_monitoring_scripts/community_jkstill/plsql/recompile.sql) | `community_jkstill/plsql` | MEDIO | OK | recompile.sql |
| [`col-diff.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/col-diff.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | col-diff.sql |
| [`dba_audit_session.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_audit_session.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | and rownum < 100 |
| [`dba_audit_session_recent.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_audit_session_recent.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | dba_audit_session_recent.sql |
| [`dba_audit_trail.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_audit_trail.sql) | `community_jkstill/rdbms_utilities` | MEDIO | OK | dba_audit_trail.sql |
| [`dba_audit_trail_persons.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_audit_trail_persons.sql) | `community_jkstill/rdbms_utilities` | MEDIO | OK | dba_audit_trail_persons.sql |
| [`dba_dependencies.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_dependencies.sql) | `community_jkstill/rdbms_utilities` | MEDIO | OK | obj-dependencies.sql |
| [`dba_deps_selective.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_deps_selective.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | anchor member |
| [`dba_feature_usage.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_feature_usage.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | dba_feature_usage.sql |
| [`dba_hist_sys_time_model.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_hist_sys_time_model.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | Script operativo Oracle per: dba hist sys time model. |
| [`dba_jobs.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_jobs.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | Diagnostica e controllo job Oracle Scheduler. |
| [`dba_jobs_running.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_jobs_running.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | Diagnostica e controllo job Oracle Scheduler. |
| [`dba_kgllock.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_kgllock.sql) | `community_jkstill/rdbms_utilities` | MEDIO | OK | dba_kgllock.sql |
| [`dba_recyclebin_purge_gen.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_recyclebin_purge_gen.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | dba_recyclebin_purge_gen.sql |
| [`dba_sched_jobs.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_sched_jobs.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | dba_scheduler_jobs.sql |
| [`dba_sched_jobs_hist.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_sched_jobs_hist.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | jkstill@gmail.com |
| [`dba_table_audit_flags.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/dba_table_audit_flags.sql) | `community_jkstill/rdbms_utilities` | ALTO | OK | dba_table_audit_flags.sql |
| [`gen-tbs-ddl.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/gen-tbs-ddl.sql) | `community_jkstill/rdbms_utilities` | MEDIO | OK | gen-tbs-ddl.sql |
| [`obj-privs.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/obj-privs.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | Jared Still 2022 |
| [`tab-info.sql`](./03_monitoring_scripts/community_jkstill/rdbms_utilities/tab-info.sql) | `community_jkstill/rdbms_utilities` | BASSO | OK | tab-info.sql |
| [`autotask_resources.sql`](./03_monitoring_scripts/community_jkstill/resource_manager/autotask_resources.sql) | `community_jkstill/resource_manager` | BASSO | OK | Script operativo Oracle per: autotask resources. |
| [`awr-resource-limit.sql`](./03_monitoring_scripts/community_jkstill/resource_manager/awr-resource-limit.sql) | `community_jkstill/resource_manager` | BASSO | OK | awr-resource-limit.sql |
| [`disable-autotasks-resource-mgr.sql`](./03_monitoring_scripts/community_jkstill/resource_manager/disable-autotasks-resource-mgr.sql) | `community_jkstill/resource_manager` | ALTO | OK | Oracle sometimes enforces Resource Manager for background processes |
| [`disable_resource_manager.sql`](./03_monitoring_scripts/community_jkstill/resource_manager/disable_resource_manager.sql) | `community_jkstill/resource_manager` | ALTO | OK | disable the resource manager |
| [`resmgr-resource-plans.sql`](./03_monitoring_scripts/community_jkstill/resource_manager/resmgr-resource-plans.sql) | `community_jkstill/resource_manager` | BASSO | OK | resmgr-resource-plans.sql |
| [`sp_resource_limit.sql`](./03_monitoring_scripts/community_jkstill/resource_manager/sp_resource_limit.sql) | `community_jkstill/resource_manager` | MEDIO | OK | sp_resource_limit.sql |
| [`active_status.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/active_status.sql) | `community_jkstill/sessions_locks` | BASSO | OK | active_status.sql |
| [`cf-waits.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/cf-waits.sql) | `community_jkstill/sessions_locks` | BASSO | OK | cf-waits.sql - Control File Waits |
| [`concurrency-waits-sqlid.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/concurrency-waits-sqlid.sql) | `community_jkstill/sessions_locks` | BASSO | OK | concurrency-waits-sqlid.sql |
| [`cpu-killer.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/cpu-killer.sql) | `community_jkstill/sessions_locks` | BASSO | OK | Script operativo Oracle per: cpu killer. |
| [`cpu-stalled-ratio.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/cpu-stalled-ratio.sql) | `community_jkstill/sessions_locks` | BASSO | OK | cpu-stalled-ratio.sql |
| [`dba_kgllock.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/dba_kgllock.sql) | `community_jkstill/sessions_locks` | MEDIO | OK | dba_kgllock.sql |
| [`extproc-sessions.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/extproc-sessions.sql) | `community_jkstill/sessions_locks` | BASSO | OK | extproc-sessions.sql |
| [`getstat.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/getstat.sql) | `community_jkstill/sessions_locks` | BASSO | OK | Script operativo Oracle per: getstat. |
| [`getstats.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/getstats.sql) | `community_jkstill/sessions_locks` | BASSO | OK | Script operativo Oracle per: getstats. |
| [`getstatu2.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/getstatu2.sql) | `community_jkstill/sessions_locks` | BASSO | OK | break on username |
| [`itl_waits.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/itl_waits.sql) | `community_jkstill/sessions_locks` | BASSO | OK | Script operativo Oracle per: itl waits. |
| [`itl_waits_hist.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/itl_waits_hist.sql) | `community_jkstill/sessions_locks` | BASSO | OK | , d.instance_number |
| [`latch_statsa.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/latch_statsa.sql) | `community_jkstill/sessions_locks` | ALTO | OK | Script operativo Oracle per: latch statsa. |
| [`latch_statss.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/latch_statss.sql) | `community_jkstill/sessions_locks` | ALTO | OK | Script operativo Oracle per: latch statss. |
| [`libcachepin_waits.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/libcachepin_waits.sql) | `community_jkstill/sessions_locks` | BASSO | OK | libcachepin_waits.sql |
| [`mystat.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/mystat.sql) | `community_jkstill/sessions_locks` | BASSO | OK | Script operativo Oracle per: mystat. |
| [`segment-space-statistics-hist.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/segment-space-statistics-hist.sql) | `community_jkstill/sessions_locks` | MEDIO | OK | segment-space-statistics-hist.sql |
| [`segment-space-statistics.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/segment-space-statistics.sql) | `community_jkstill/sessions_locks` | MEDIO | OK | segment-space-statistics.sql |
| [`segment-statistics.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/segment-statistics.sql) | `community_jkstill/sessions_locks` | BASSO | OK | may be interesting results |
| [`sesswait.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/sesswait.sql) | `community_jkstill/sessions_locks` | BASSO | OK | Script operativo Oracle per: sesswait. |
| [`sesswaitp.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/sesswaitp.sql) | `community_jkstill/sessions_locks` | BASSO | OK | sesswaitp.sql |
| [`sesswaitu.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/sesswaitu.sql) | `community_jkstill/sessions_locks` | BASSO | OK | sesswaitu.sql |
| [`sesswaitu10g.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/sesswaitu10g.sql) | `community_jkstill/sessions_locks` | BASSO | OK | sesswaitu.sql |
| [`sesswaitu72.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/sesswaitu72.sql) | `community_jkstill/sessions_locks` | BASSO | OK | sesswaitu.sql |
| [`sesswaitu73.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/sesswaitu73.sql) | `community_jkstill/sessions_locks` | BASSO | OK | sesswaitu.sql |
| [`sesswaitu_112.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/sesswaitu_112.sql) | `community_jkstill/sessions_locks` | BASSO | OK | sesswaitu.sql |
| [`sesswaitug.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/sesswaitug.sql) | `community_jkstill/sessions_locks` | BASSO | OK | case wait_time |
| [`showlatch.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/showlatch.sql) | `community_jkstill/sessions_locks` | BASSO | OK | Script operativo Oracle per: showlatch. |
| [`showlock.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/showlock.sql) | `community_jkstill/sessions_locks` | MEDIO | OK | showlock.sql - show all user locks |
| [`showlock2.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/showlock2.sql) | `community_jkstill/sessions_locks` | BASSO | OK | showlock2.sql |
| [`snapper.sql`](./03_monitoring_scripts/community_jkstill/sessions_locks/snapper.sql) | `community_jkstill/sessions_locks` | BASSO | OK | File name: snapper.sql (Oracle Session Snapper v4) |
| [`asm_diskgroup_templates.sql`](./03_monitoring_scripts/community_jkstill/temp_sorts/asm_diskgroup_templates.sql) | `community_jkstill/temp_sorts` | BASSO | OK | asm_diskgroup_templates.sql |
| [`my-pga-temp.sql`](./03_monitoring_scripts/community_jkstill/temp_sorts/my-pga-temp.sql) | `community_jkstill/temp_sorts` | BASSO | OK | my-pga-temp.sql |
| [`showsort.sql`](./03_monitoring_scripts/community_jkstill/temp_sorts/showsort.sql) | `community_jkstill/temp_sorts` | BASSO | OK | showsort.sql |
| [`showtemp.sql`](./03_monitoring_scripts/community_jkstill/temp_sorts/showtemp.sql) | `community_jkstill/temp_sorts` | BASSO | OK | , tu.session_addr |
| [`showuser.sql`](./03_monitoring_scripts/community_jkstill/users_logged/showuser.sql) | `community_jkstill/users_logged` | MEDIO | OK | &use_12c_feature , oracle_maintained |
| [`who.sql`](./03_monitoring_scripts/community_jkstill/users_logged/who.sql) | `community_jkstill/users_logged` | BASSO | OK | Script operativo Oracle per: who. |
| [`who2.sql`](./03_monitoring_scripts/community_jkstill/users_logged/who2.sql) | `community_jkstill/users_logged` | BASSO | OK | jkstill@gmail.com |
| [`who2g.sql`](./03_monitoring_scripts/community_jkstill/users_logged/who2g.sql) | `community_jkstill/users_logged` | BASSO | OK | jkstill@gmail.com |
| [`who2s.sql`](./03_monitoring_scripts/community_jkstill/users_logged/who2s.sql) | `community_jkstill/users_logged` | BASSO | OK | less detail than who2.sql |
| [`who5.sql`](./03_monitoring_scripts/community_jkstill/users_logged/who5.sql) | `community_jkstill/users_logged` | BASSO | OK | taken from OraMag Code Depot ( and slightly modified ) |
| [`who6.sql`](./03_monitoring_scripts/community_jkstill/users_logged/who6.sql) | `community_jkstill/users_logged` | BASSO | OK | jkstill@gmail.com |
| [`who7.sql`](./03_monitoring_scripts/community_jkstill/users_logged/who7.sql) | `community_jkstill/users_logged` | BASSO | OK | who with avg transaction size |
| [`who8.sql`](./03_monitoring_scripts/community_jkstill/users_logged/who8.sql) | `community_jkstill/users_logged` | BASSO | OK | jkstill@gmail.com |
| [`who9.sql`](./03_monitoring_scripts/community_jkstill/users_logged/who9.sql) | `community_jkstill/users_logged` | BASSO | OK | jkstill@gmail.com |
| [`who_dba_jobs.sql`](./03_monitoring_scripts/community_jkstill/users_logged/who_dba_jobs.sql) | `community_jkstill/users_logged` | BASSO | OK | jkstill@gmail.com |
| [`who_dblink.sql`](./03_monitoring_scripts/community_jkstill/users_logged/who_dblink.sql) | `community_jkstill/users_logged` | BASSO | OK | who_dblink.sql |
| [`who_protocol.sql`](./03_monitoring_scripts/community_jkstill/users_logged/who_protocol.sql) | `community_jkstill/users_logged` | BASSO | OK | who_protocol.sql |
| [`whocp.sql`](./03_monitoring_scripts/community_jkstill/users_logged/whocp.sql) | `community_jkstill/users_logged` | BASSO | OK | who with DRCP (database resident connection pool) info |
| [`whog.sql`](./03_monitoring_scripts/community_jkstill/users_logged/whog.sql) | `community_jkstill/users_logged` | BASSO | OK | jkstill@gmail.com |
| [`whotmp8i.sql`](./03_monitoring_scripts/community_jkstill/users_logged/whotmp8i.sql) | `community_jkstill/users_logged` | BASSO | OK | whotmp8i.sql |
| [`Event_statistics.sql`](./03_monitoring_scripts/Event_statistics.sql) | `-` | MEDIO | OK | EVENT HISTOGRAMS |
| [`IO_stat_nel_tempo.sql`](./03_monitoring_scripts/IO_stat_nel_tempo.sql) | `-` | BASSO | OK | via SQL (per day) |
| [`IO_WaitTimeDetails.sql`](./03_monitoring_scripts/IO_WaitTimeDetails.sql) | `-` | BASSO | OK | wait_time_detail_10g.sql |
| [`locks.sql`](./03_monitoring_scripts/locks.sql) | `-` | BASSO | OK | locks.sql locks and enqueue blocks for 11g |
| [`locks_10g.sql`](./03_monitoring_scripts/locks_10g.sql) | `-` | BASSO | OK | in 11g can use select .. from v$wait_chains |
| [`locks_blocking.sql`](./03_monitoring_scripts/locks_blocking.sql) | `-` | BASSO | OK | | Jeffrey M. Hunter | |
| [`locks_details.sql`](./03_monitoring_scripts/locks_details.sql) | `-` | BASSO | OK | locks.sql locks and enqueue blocks for 11g |
| [`PGA.sql`](./03_monitoring_scripts/PGA.sql) | `-` | BASSO | OK | Limiting process size with database parameter PGA_AGGREGATE_LIMIT (Doc ID 1520324.1) |
| [`Processi.sql`](./03_monitoring_scripts/Processi.sql) | `-` | MEDIO | OK | OSPID FROM SID |
| [`Stats_workflow.sql`](./03_monitoring_scripts/Stats_workflow.sql) | `-` | MEDIO | OK | Check Autotask job history |
| [`sysaux_fix.sql`](./03_monitoring_scripts/sysaux_fix.sql) | `-` | ALTO | OK | WRI$_OPTSTAT_HISTGRM_HISTORY non può essere shrinkata... dovrebbe contenere 1 mese di dati |
| [`View_Blocking.sql`](./03_monitoring_scripts/View_Blocking.sql) | `-` | BASSO | OK | Mostra le sessioni bloccanti |
| [`View_Cpu_Consumer.sql`](./03_monitoring_scripts/View_Cpu_Consumer.sql) | `-` | ALTO | OK | Script operativo Oracle per: View Cpu Consumer. |
| [`View_Cpu_Hist.sql`](./03_monitoring_scripts/View_Cpu_Hist.sql) | `-` | MEDIO | OK | round((round((nw.value - ol.value) / 100)) / ((cast(nw.end_interval_time as date) - cast(ol.end_interval_time as date)) * 24 *60 * 60),2) us |
| [`View_IO_Database.sql`](./03_monitoring_scripts/View_IO_Database.sql) | `-` | BASSO | OK | Total|Small|IOPS" questa colonna quella da considerare per calcolare il numero di I/O al secondo fatti dal database |
| [`View_IO_Hist.sql`](./03_monitoring_scripts/View_IO_Hist.sql) | `-` | BASSO | OK | 'control file parallel write', |
| [`View_IO_RealTime.sql`](./03_monitoring_scripts/View_IO_RealTime.sql) | `-` | BASSO | OK | 'control file parallel write' |
| [`View_RedoGeneration.sql`](./03_monitoring_scripts/View_RedoGeneration.sql) | `-` | ALTO | OK | Shows current redo logs generation info (RAC-non RAC environment) |
| [`ViewSession.sql`](./03_monitoring_scripts/ViewSession.sql) | `-` | MEDIO | OK | wait.p1text||' = '||wait.p1 p1, |

### `04_user_management` — User Management (5 script)

| Script | Sottocartella | Rischio | Stato cartella | Spiegazione |
|---|---|---|---|---|
| [`GeneraPass_Random_da_Bash.txt`](./04_user_management/GeneraPass_Random_da_Bash.txt) | `-` | BASSO | OK | Solo caratteri -- Esempio: TPBahbBuHLqL |
| [`Prototipo_CreateUser_DB_APPLICATIVA_v1.3.txt`](./04_user_management/Prototipo_CreateUser_DB_APPLICATIVA_v1.3.txt) | `-` | MEDIO | OK | Fare la replace di xxx con UTENTE per generare uno script secondo standard |
| [`Prototipo_CreateUser_DBA_OP_v1.3.txt`](./04_user_management/Prototipo_CreateUser_DBA_OP_v1.3.txt) | `-` | MEDIO | OK | CREAZIONE UTENTE DBA_OP nel caso in cui non esista |
| [`Prototipo_CreateUser_Nominale_v1.4.txt`](./04_user_management/Prototipo_CreateUser_Nominale_v1.4.txt) | `-` | MEDIO | OK | Le utenze nominali hanno il formato COxxxx per esterni e D0xxxx per gli interni e vengono comunicati da Security Governance |
| [`Verify Function PWD.txt`](./04_user_management/Verify%20Function%20PWD.txt) | `-` | MEDIO | OK | Check if the password is same as the username |

### `05_patching` — Patching (2 script)

| Script | Sottocartella | Rischio | Stato cartella | Spiegazione |
|---|---|---|---|---|
| [`golden_images_ohctl.txt`](./05_patching/golden_images_ohctl.txt) | `-` | MEDIO | OK | define colors for bash candiness |
| [`setoh.txt`](./05_patching/setoh.txt) | `-` | BASSO | OK | ic is a shortcut for the Instant Client |

### `06_backup_recovery` — Backup & Recovery (12 script)

| Script | Sottocartella | Rischio | Stato cartella | Spiegazione |
|---|---|---|---|---|
| [`BACKUP CHECKS.sql`](./06_backup_recovery/community_scripts/BACKUP%20CHECKS.sql) | `community_scripts` | MEDIO | OK | NB: Le query sono applicabili solo per target database dalla 10g in poi |
| [`fra_config.sql`](./06_backup_recovery/community_scripts/fra_config.sql) | `community_scripts` | BASSO | OK | fra_config.sql |
| [`incarnations.sql`](./06_backup_recovery/community_scripts/incarnations.sql) | `community_scripts` | BASSO | OK | incarnations.sql |
| [`MONITOR__RMAN_BACKUP.sql`](./06_backup_recovery/community_scripts/MONITOR__RMAN_BACKUP.sql) | `community_scripts` | BASSO | OK | Backup completati |
| [`restore-sqlplus-settings.sql`](./06_backup_recovery/community_scripts/restore-sqlplus-settings.sql) | `community_scripts` | BASSO | OK | bind var is :v_sqltempfile |
| [`rman-bkup-details.sql`](./06_backup_recovery/community_scripts/rman-bkup-details.sql) | `community_scripts` | BASSO | OK | rman-bkup-details.sql |
| [`rman-bkup-status.sql`](./06_backup_recovery/community_scripts/rman-bkup-status.sql) | `community_scripts` | BASSO | OK | rman-bkup-status.sql |
| [`rman-recovery-min-scn.sql`](./06_backup_recovery/community_scripts/rman-recovery-min-scn.sql) | `community_scripts` | BASSO | OK | rman-recovery-scn.sql |
| [`rman-recovery-scn.sql`](./06_backup_recovery/community_scripts/rman-recovery-scn.sql) | `community_scripts` | BASSO | OK | rman-recovery-scn.sql |
| [`unrecoverable-files.sql`](./06_backup_recovery/community_scripts/unrecoverable-files.sql) | `community_scripts` | MEDIO | OK | unrecoverable.sql |
| [`Flashback_restore_point.sql`](./06_backup_recovery/Flashback_restore_point.sql) | `-` | ALTO | OK | ATTIVAZIONE RESTORE POINT |
| [`FLASHBACK_RESTORPOINT.sql`](./06_backup_recovery/FLASHBACK_RESTORPOINT.sql) | `-` | MEDIO | OK | In Caso il rilascio fallisce come eseguire il flashback |

### `07_performance_tuning` — Performance Tuning (230 script)

| Script | Sottocartella | Rischio | Stato cartella | Spiegazione |
|---|---|---|---|---|
| [`aas-ash-calc.sql`](./07_performance_tuning/community_scripts/ash_awr/aas-ash-calc.sql) | `community_scripts/ash_awr` | BASSO | OK | aas-ash-calc.sql |
| [`aas-awr-calc.sql`](./07_performance_tuning/community_scripts/ash_awr/aas-awr-calc.sql) | `community_scripts/ash_awr` | BASSO | OK | aas-calc.sql |
| [`aas-awr-pdb-calc.sql`](./07_performance_tuning/community_scripts/ash_awr/aas-awr-pdb-calc.sql) | `community_scripts/ash_awr` | BASSO | OK | aas-awr-pdb-calc.sql |
| [`aas-std.sql`](./07_performance_tuning/community_scripts/ash_awr/aas-std.sql) | `community_scripts/ash_awr` | BASSO | OK | gather AAS metrics from AWR |
| [`aas.sql`](./07_performance_tuning/community_scripts/ash_awr/aas.sql) | `community_scripts/ash_awr` | BASSO | OK | Jared Still jkstill@gmail.com |
| [`aas_hist_metrics.sql`](./07_performance_tuning/community_scripts/ash_awr/aas_hist_metrics.sql) | `community_scripts/ash_awr` | BASSO | OK | aas_hist_metrics.sql |
| [`aas_history.sql`](./07_performance_tuning/community_scripts/ash_awr/aas_history.sql) | `community_scripts/ash_awr` | BASSO | OK | change value below to '--' for regular report, '' for CSV |
| [`ash-all-events-5-pct.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-all-events-5-pct.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-all-events-5-pct.sql |
| [`ash-blocker-waits.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-blocker-waits.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-blocker-waits.sql |
| [`ash-current-waits-by-sql-event.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-current-waits-by-sql-event.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-current-waits-by-sql-event.sql |
| [`ash-current-waits-by-sql.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-current-waits-by-sql.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-current-waits-by-sql.sql |
| [`ash-current-waits.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-current-waits.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-current-waits.sql |
| [`ash-enq-obj.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-enq-obj.sql) | `community_scripts/ash_awr` | ALTO | OK | ash-enq-obj.sql |
| [`ash-events.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-events.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-events.sql |
| [`ash-itl-waits.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-itl-waits.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-itl-waits.sql |
| [`ash-sessions.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-sessions.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-sessions.sql |
| [`ash-snapshot-define-begin-end.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-snapshot-define-begin-end.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-snapshot-define-begin-end.sql |
| [`ash-sql-ops.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-sql-ops.sql) | `community_scripts/ash_awr` | MEDIO | OK | ash-sql-ops.sql |
| [`ash-sqlid-event-window.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-sqlid-event-window.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-sqlid-event-window.sql |
| [`ash-top-events.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-top-events.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-top-events.sql |
| [`ash-waits-user.sql`](./07_performance_tuning/community_scripts/ash_awr/ash-waits-user.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-waits-user.sql |
| [`ash_bbw.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_bbw.sql) | `community_scripts/ash_awr` | BASSO | OK | and w.class# > 18 |
| [`ash_blockers.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_blockers.sql) | `community_scripts/ash_awr` | BASSO | OK | awr_blockers.sql |
| [`ash_blockers_10g.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_blockers_10g.sql) | `community_scripts/ash_awr` | BASSO | OK | awr_blockers.sql |
| [`ash_blocking.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_blocking.sql) | `community_scripts/ash_awr` | BASSO | OK | ash_blocking.sql |
| [`ash_cpu_hist.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_cpu_hist.sql) | `community_scripts/ash_awr` | BASSO | OK | ash-cpu-hist.sql |
| [`ash_enq.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_enq.sql) | `community_scripts/ash_awr` | BASSO | OK | Analisi Active Session History (ASH) per colli di bottiglia e top consumer. |
| [`ash_graph.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_graph.sql) | `community_scripts/ash_awr` | BASSO | OK | ashmasters - https://github.com/khailey/ashmasters |
| [`ash_graph_histash_by_dbid.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_graph_histash_by_dbid.sql) | `community_scripts/ash_awr` | BASSO | OK | ashmasters - https://github.com/khailey/ashmasters |
| [`ash_graph_histash_by_dbid_program.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_graph_histash_by_dbid_program.sql) | `community_scripts/ash_awr` | BASSO | OK | ashmasters - https://github.com/khailey/ashmasters |
| [`ash_graph_histash_by_dbid_sqlid.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_graph_histash_by_dbid_sqlid.sql) | `community_scripts/ash_awr` | BASSO | OK | ashmasters - https://github.com/khailey/ashmasters |
| [`ash_graph_waits.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_graph_waits.sql) | `community_scripts/ash_awr` | BASSO | OK | ashmasters - https://github.com/khailey/ashmasters |
| [`ash_graph_waits_histash.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_graph_waits_histash.sql) | `community_scripts/ash_awr` | BASSO | OK | ashmasters - https://github.com/khailey/ashmasters |
| [`ash_io_sizes.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_io_sizes.sql) | `community_scripts/ash_awr` | BASSO | OK | from v$active_session_history |
| [`ash_log_sync.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_log_sync.sql) | `community_scripts/ash_awr` | BASSO | OK | , time_waited / power(10,6) time_waited |
| [`ash_sql_elapsed.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_sql_elapsed.sql) | `community_scripts/ash_awr` | BASSO | OK | ash masters - Kyle Hailey |
| [`ash_sql_elapsed_hist.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_sql_elapsed_hist.sql) | `community_scripts/ash_awr` | BASSO | OK | ash masters - Kyle Hailey |
| [`ash_sql_elapsed_hist_longestid.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_sql_elapsed_hist_longestid.sql) | `community_scripts/ash_awr` | BASSO | OK | ash masters - Kyle Hailey |
| [`ash_top_procedure.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_top_procedure.sql) | `community_scripts/ash_awr` | BASSO | OK | Analisi Active Session History (ASH) per colli di bottiglia e top consumer. |
| [`ash_top_session.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_top_session.sql) | `community_scripts/ash_awr` | BASSO | OK | outer join to v$session because the session might be disconnected |
| [`ash_top_sql.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_top_sql.sql) | `community_scripts/ash_awr` | BASSO | OK | ash_top_sql.sql |
| [`ash_top_sql_w_top_obj.sql`](./07_performance_tuning/community_scripts/ash_awr/ash_top_sql_w_top_obj.sql) | `community_scripts/ash_awr` | BASSO | OK | from master,audit_actions aud , dba_objects o |
| [`ashdump-summary.sql`](./07_performance_tuning/community_scripts/ash_awr/ashdump-summary.sql) | `community_scripts/ash_awr` | BASSO | OK | ashdump-summary.sql |
| [`ashdump.sql`](./07_performance_tuning/community_scripts/ash_awr/ashdump.sql) | `community_scripts/ash_awr` | BASSO | OK | jkstill@gmail.com |
| [`ashtop.sql`](./07_performance_tuning/community_scripts/ash_awr/ashtop.sql) | `community_scripts/ash_awr` | BASSO | OK | Copyright 2018 Tanel Poder. All rights reserved. More info at http://tanelpoder.com |
| [`awr-blocker-waits.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-blocker-waits.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-blocker-waits.sql |
| [`awr-cpu-stats.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-cpu-stats.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-cpu-stats.sql |
| [`awr-enq-hot-blocks.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-enq-hot-blocks.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-enq-hot-blocks.sql |
| [`awr-enq-obj.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-enq-obj.sql) | `community_scripts/ash_awr` | ALTO | OK | awr-enq-obj.sql |
| [`awr-event-histogram.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-event-histogram.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-event-histogram.sql |
| [`awr-export.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-export.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-export.sql |
| [`awr-get-retention.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-get-retention.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-get-retention.sql |
| [`awr-hist-model-top10.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-hist-model-top10.sql) | `community_scripts/ash_awr` | BASSO | OK | hist-model-top10.sql |
| [`awr-itl-wait-details.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-itl-wait-details.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-itl-waits.sql |
| [`awr-itl-waits.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-itl-waits.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-itl-waits.sql |
| [`awr-resource-limit.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-resource-limit.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-resource-limit.sql |
| [`awr-set-retention.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-set-retention.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-set-retention.sql |
| [`awr-top-10-daily.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-top-10-daily.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-top-10-daily.sql |
| [`awr-top-5-events.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-top-5-events.sql) | `community_scripts/ash_awr` | MEDIO | OK | awr-top-5-events.sql |
| [`awr-top-events.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-top-events.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-top-events.sql |
| [`awr-top-sqlid-events.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-top-sqlid-events.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-top-sqlid-events.sql |
| [`awr-trans-counts.sql`](./07_performance_tuning/community_scripts/ash_awr/awr-trans-counts.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-trans-counts.sql |
| [`awr_blockers.sql`](./07_performance_tuning/community_scripts/ash_awr/awr_blockers.sql) | `community_scripts/ash_awr` | BASSO | OK | awr_blockers.sql |
| [`awr_bracket_baseline.sql`](./07_performance_tuning/community_scripts/ash_awr/awr_bracket_baseline.sql) | `community_scripts/ash_awr` | MEDIO | OK | create awr baseline that brackets a time |
| [`awr_bracket_snaps.sql`](./07_performance_tuning/community_scripts/ash_awr/awr_bracket_snaps.sql) | `community_scripts/ash_awr` | BASSO | OK | awr_bracket_snaps.sql |
| [`awr_create_snapshot.sql`](./07_performance_tuning/community_scripts/ash_awr/awr_create_snapshot.sql) | `community_scripts/ash_awr` | BASSO | OK | Analisi AWR per trend prestazionali e identificazione root cause. |
| [`awr_defined.sql`](./07_performance_tuning/community_scripts/ash_awr/awr_defined.sql) | `community_scripts/ash_awr` | BASSO | OK | awr_defined.sql |
| [`awr_display_baselines.sql`](./07_performance_tuning/community_scripts/ash_awr/awr_display_baselines.sql) | `community_scripts/ash_awr` | BASSO | OK | awr_display_baselines.sql |
| [`awr_drop_baseline.sql`](./07_performance_tuning/community_scripts/ash_awr/awr_drop_baseline.sql) | `community_scripts/ash_awr` | ALTO | OK | awr_drop_baseline.sql |
| [`awr_file_io_times.sql`](./07_performance_tuning/community_scripts/ash_awr/awr_file_io_times.sql) | `community_scripts/ash_awr` | BASSO | OK | and tbs.con_id = f.con_id |
| [`awr_get_snapshots.sql`](./07_performance_tuning/community_scripts/ash_awr/awr_get_snapshots.sql) | `community_scripts/ash_awr` | BASSO | OK | awr_get_snapshots.sql |
| [`awr_itl_waits_10g.sql`](./07_performance_tuning/community_scripts/ash_awr/awr_itl_waits_10g.sql) | `community_scripts/ash_awr` | BASSO | OK | awr_itl_waits_10g.sql.sql |
| [`awr_RAC_defined.sql`](./07_performance_tuning/community_scripts/ash_awr/awr_RAC_defined.sql) | `community_scripts/ash_awr` | BASSO | OK | awr_RAC_defined.sql |
| [`awr_settings.sql`](./07_performance_tuning/community_scripts/ash_awr/awr_settings.sql) | `community_scripts/ash_awr` | BASSO | OK | Analisi AWR per trend prestazionali e identificazione root cause. |
| [`concurrency-waits-sqlid-ash.sql`](./07_performance_tuning/community_scripts/ash_awr/concurrency-waits-sqlid-ash.sql) | `community_scripts/ash_awr` | BASSO | OK | concurrency-waits-sqlid-ash.sql |
| [`concurrency-waits-sqlid.sql`](./07_performance_tuning/community_scripts/ash_awr/concurrency-waits-sqlid.sql) | `community_scripts/ash_awr` | BASSO | OK | concurrency-waits-sqlid.sql |
| [`cpu-busy.sql`](./07_performance_tuning/community_scripts/ash_awr/cpu-busy.sql) | `community_scripts/ash_awr` | BASSO | OK | cpu-busy.sql - what is keeping CPU busy? |
| [`dba_hist_sys_time_model.sql`](./07_performance_tuning/community_scripts/ash_awr/dba_hist_sys_time_model.sql) | `community_scripts/ash_awr` | BASSO | OK | Script operativo Oracle per: dba hist sys time model. |
| [`dbw-hist.sql`](./07_performance_tuning/community_scripts/ash_awr/dbw-hist.sql) | `community_scripts/ash_awr` | BASSO | OK | dbw-hist.sql |
| [`flash-hist-stats.sql`](./07_performance_tuning/community_scripts/ash_awr/flash-hist-stats.sql) | `community_scripts/ash_awr` | BASSO | OK | Analisi Active Session History (ASH) per colli di bottiglia e top consumer. |
| [`get-binds.sql`](./07_performance_tuning/community_scripts/ash_awr/get-binds.sql) | `community_scripts/ash_awr` | BASSO | OK | get_bind_values.sql |
| [`getsql-awr.sql`](./07_performance_tuning/community_scripts/ash_awr/getsql-awr.sql) | `community_scripts/ash_awr` | BASSO | OK | Analisi AWR per trend prestazionali e identificazione root cause. |
| [`osstat-cpu-10g.sql`](./07_performance_tuning/community_scripts/ash_awr/osstat-cpu-10g.sql) | `community_scripts/ash_awr` | BASSO | OK | osstat-cpu-10g.sql |
| [`osstat-cpu-rpt.sql`](./07_performance_tuning/community_scripts/ash_awr/osstat-cpu-rpt.sql) | `community_scripts/ash_awr` | BASSO | OK | osstat-cpu-rpt.sql |
| [`osstat-cpu.sql`](./07_performance_tuning/community_scripts/ash_awr/osstat-cpu.sql) | `community_scripts/ash_awr` | BASSO | OK | osstat-cpu.sql |
| [`plan-counts-force.sql`](./07_performance_tuning/community_scripts/ash_awr/plan-counts-force.sql) | `community_scripts/ash_awr` | BASSO | OK | plan-counts-force.sql |
| [`plan-stats.sql`](./07_performance_tuning/community_scripts/ash_awr/plan-stats.sql) | `community_scripts/ash_awr` | BASSO | OK | plan-stats.sql |
| [`resize-ops-metric-awr.sql`](./07_performance_tuning/community_scripts/ash_awr/resize-ops-metric-awr.sql) | `community_scripts/ash_awr` | BASSO | OK | resize-ops-metric.sql |
| [`resize-ops-metric.sql`](./07_performance_tuning/community_scripts/ash_awr/resize-ops-metric.sql) | `community_scripts/ash_awr` | BASSO | OK | resize-ops-metric.sql |
| [`rowlock-hist.sql`](./07_performance_tuning/community_scripts/ash_awr/rowlock-hist.sql) | `community_scripts/ash_awr` | BASSO | OK | rowlock-hist.sql |
| [`rowlock-mode-decode.sql`](./07_performance_tuning/community_scripts/ash_awr/rowlock-mode-decode.sql) | `community_scripts/ash_awr` | BASSO | OK | awr-top-events.sql |
| [`rowlock-sqlid-counts.sql`](./07_performance_tuning/community_scripts/ash_awr/rowlock-sqlid-counts.sql) | `community_scripts/ash_awr` | BASSO | OK | rowlock-sqlid-counts.sql |
| [`rowlock-sqlid-hist.sql`](./07_performance_tuning/community_scripts/ash_awr/rowlock-sqlid-hist.sql) | `community_scripts/ash_awr` | BASSO | OK | rowlock-sqlid-hist.sql |
| [`session-history.sql`](./07_performance_tuning/community_scripts/ash_awr/session-history.sql) | `community_scripts/ash_awr` | BASSO | OK | session-history.sql |
| [`sql-cache-mem-user.sql`](./07_performance_tuning/community_scripts/ash_awr/sql-cache-mem-user.sql) | `community_scripts/ash_awr` | BASSO | OK | sql-workarea-memory-user.sql |
| [`sql-cache-mem.sql`](./07_performance_tuning/community_scripts/ash_awr/sql-cache-mem.sql) | `community_scripts/ash_awr` | BASSO | OK | sql-workarea-memory.sql |
| [`sql-cache-projections.sql`](./07_performance_tuning/community_scripts/ash_awr/sql-cache-projections.sql) | `community_scripts/ash_awr` | BASSO | OK | based on max memory |
| [`sql-count-ash.sql`](./07_performance_tuning/community_scripts/ash_awr/sql-count-ash.sql) | `community_scripts/ash_awr` | BASSO | OK | Analisi Active Session History (ASH) per colli di bottiglia e top consumer. |
| [`sql-counts-fms.sql`](./07_performance_tuning/community_scripts/ash_awr/sql-counts-fms.sql) | `community_scripts/ash_awr` | BASSO | OK | sql-counts-fms.sql |
| [`sql-counts.sql`](./07_performance_tuning/community_scripts/ash_awr/sql-counts.sql) | `community_scripts/ash_awr` | BASSO | OK | sql-counts.sql |
| [`sql-plans.sql`](./07_performance_tuning/community_scripts/ash_awr/sql-plans.sql) | `community_scripts/ash_awr` | BASSO | OK | sa.sql - sql activity |
| [`sysmetric-cpu-seconds-hist.sql`](./07_performance_tuning/community_scripts/ash_awr/sysmetric-cpu-seconds-hist.sql) | `community_scripts/ash_awr` | BASSO | OK | sysmetric-cpu-seconds-hist.sql |
| [`sysmetric-cpu-seconds-summary.sql`](./07_performance_tuning/community_scripts/ash_awr/sysmetric-cpu-seconds-summary.sql) | `community_scripts/ash_awr` | BASSO | OK | sysmetric-cpu-seconds-summary.sql |
| [`sysmetric-hist-matrix.sql`](./07_performance_tuning/community_scripts/ash_awr/sysmetric-hist-matrix.sql) | `community_scripts/ash_awr` | BASSO | OK | sysmetric-hist-matrix.sql |
| [`sysmetric-history.sql`](./07_performance_tuning/community_scripts/ash_awr/sysmetric-history.sql) | `community_scripts/ash_awr` | BASSO | OK | sysmetric-history.sql |
| [`top10-sql-ash.sql`](./07_performance_tuning/community_scripts/ash_awr/top10-sql-ash.sql) | `community_scripts/ash_awr` | BASSO | OK | top10-sql-ash.sql |
| [`top10-sql-awr.sql`](./07_performance_tuning/community_scripts/ash_awr/top10-sql-awr.sql) | `community_scripts/ash_awr` | BASSO | OK | top10-sql-awr.sql |
| [`wsqlmon.sql`](./07_performance_tuning/community_scripts/ash_awr/wsqlmon.sql) | `community_scripts/ash_awr` | BASSO | OK | File name: wsqlmon.sql (based on asqlmon.sql v1.1) |
| [`my-pga-temp.sql`](./07_performance_tuning/community_scripts/memory/my-pga-temp.sql) | `community_scripts/memory` | BASSO | OK | my-pga-temp.sql |
| [`ora-4031-info-shared-pool.sql`](./07_performance_tuning/community_scripts/memory/ora-4031-info-shared-pool.sql) | `community_scripts/memory` | MEDIO | OK | CONNECT / AS SYSDBA |
| [`pga_advice.sql`](./07_performance_tuning/community_scripts/memory/pga_advice.sql) | `community_scripts/memory` | BASSO | OK | pga_advice.sql |
| [`pga_advice_hist.sql`](./07_performance_tuning/community_scripts/memory/pga_advice_hist.sql) | `community_scripts/memory` | BASSO | OK | pga_advice_hist.sql |
| [`pga_advice_selective.sql`](./07_performance_tuning/community_scripts/memory/pga_advice_selective.sql) | `community_scripts/memory` | BASSO | OK | pga_advice_selective.sql |
| [`pga_history_sum.sql`](./07_performance_tuning/community_scripts/memory/pga_history_sum.sql) | `community_scripts/memory` | BASSO | OK | pga_history_sum.sql |
| [`pga_history_week.sql`](./07_performance_tuning/community_scripts/memory/pga_history_week.sql) | `community_scripts/memory` | BASSO | OK | pga_history_week.sql |
| [`pga_workarea_active.sql`](./07_performance_tuning/community_scripts/memory/pga_workarea_active.sql) | `community_scripts/memory` | BASSO | OK | from performance tuning manual chapter 14 |
| [`pga_workarea_hist.sql`](./07_performance_tuning/community_scripts/memory/pga_workarea_hist.sql) | `community_scripts/memory` | BASSO | OK | Script operativo Oracle per: pga workarea hist. |
| [`pgacols.sql`](./07_performance_tuning/community_scripts/memory/pgacols.sql) | `community_scripts/memory` | BASSO | OK | Script operativo Oracle per: pgacols. |
| [`pgastat.sql`](./07_performance_tuning/community_scripts/memory/pgastat.sql) | `community_scripts/memory` | BASSO | OK | Script operativo Oracle per: pgastat. |
| [`pgastat_hist.sql`](./07_performance_tuning/community_scripts/memory/pgastat_hist.sql) | `community_scripts/memory` | BASSO | OK | Script operativo Oracle per: pgastat hist. |
| [`process-memory.sql`](./07_performance_tuning/community_scripts/memory/process-memory.sql) | `community_scripts/memory` | MEDIO | OK | process-memory.sql |
| [`sga_advice_selective.sql`](./07_performance_tuning/community_scripts/memory/sga_advice_selective.sql) | `community_scripts/memory` | BASSO | OK | gv$sga_target_advice |
| [`shared-pool-top-sql.sql`](./07_performance_tuning/community_scripts/memory/shared-pool-top-sql.sql) | `community_scripts/memory` | BASSO | OK | , s.sql_fulltext |
| [`shared-pool-top-users.sql`](./07_performance_tuning/community_scripts/memory/shared-pool-top-users.sql) | `community_scripts/memory` | BASSO | OK | Script operativo Oracle per: shared pool top users. |
| [`shared_pool_advice.sql`](./07_performance_tuning/community_scripts/memory/shared_pool_advice.sql) | `community_scripts/memory` | BASSO | OK | shared_pool_advice.sql |
| [`shared_pool_advice_selective.sql`](./07_performance_tuning/community_scripts/memory/shared_pool_advice_selective.sql) | `community_scripts/memory` | BASSO | OK | sp_advice_selective.sql |
| [`showsga.sql`](./07_performance_tuning/community_scripts/memory/showsga.sql) | `community_scripts/memory` | BASSO | OK | col name format |
| [`get-sql-exe-times.sh`](./07_performance_tuning/community_scripts/sql_performance/get-sql-exe-times.sh) | `community_scripts/sql_performance` | BASSO | OK | !/usr/bin/env bash |
| [`sql-buffer-ratios-awr.sql`](./07_performance_tuning/community_scripts/sql_performance/sql-buffer-ratios-awr.sql) | `community_scripts/sql_performance` | BASSO | OK | sql-buffer-ratios-awr.sql |
| [`sql-buffer-ratios.sql`](./07_performance_tuning/community_scripts/sql_performance/sql-buffer-ratios.sql) | `community_scripts/sql_performance` | BASSO | OK | where buffer_gets > 0 |
| [`sql-exe-times-awr-rpt.pl`](./07_performance_tuning/community_scripts/sql_performance/sql-exe-times-awr-rpt.pl) | `community_scripts/sql_performance` | BASSO | OK | !/opt/oracle/product/23c/dbhomeFree//perl/bin/perl |
| [`sqlid-elapsed.sql`](./07_performance_tuning/community_scripts/sql_performance/sqlid-elapsed.sql) | `community_scripts/sql_performance` | BASSO | OK | sqlid-elapsed.sql |
| [`active_status.sql`](./07_performance_tuning/community_scripts/stats_optimizer/active_status.sql) | `community_scripts/stats_optimizer` | BASSO | OK | active_status.sql |
| [`asm-diskgroup-stat.sql`](./07_performance_tuning/community_scripts/stats_optimizer/asm-diskgroup-stat.sql) | `community_scripts/stats_optimizer` | BASSO | OK | asm-diskgroup-stat.sql |
| [`asm_disk_stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/asm_disk_stats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | asm_disk_stats.sql |
| [`autotask_auto_stats_disable.sql`](./07_performance_tuning/community_scripts/stats_optimizer/autotask_auto_stats_disable.sql) | `community_scripts/stats_optimizer` | BASSO | OK | disable automatics tasks |
| [`autotask_auto_stats_enable.sql`](./07_performance_tuning/community_scripts/stats_optimizer/autotask_auto_stats_enable.sql) | `community_scripts/stats_optimizer` | BASSO | OK | enable automatics stats |
| [`awr-cpu-stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/awr-cpu-stats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | awr-cpu-stats.sql |
| [`awr-event-histogram.sql`](./07_performance_tuning/community_scripts/stats_optimizer/awr-event-histogram.sql) | `community_scripts/stats_optimizer` | BASSO | OK | awr-event-histogram.sql |
| [`bct_status.sql`](./07_performance_tuning/community_scripts/stats_optimizer/bct_status.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Script operativo Oracle per: bct status. |
| [`cpu-bucket-histogram.sql`](./07_performance_tuning/community_scripts/stats_optimizer/cpu-bucket-histogram.sql) | `community_scripts/stats_optimizer` | BASSO | OK | this section may be an approximation |
| [`cpu-minute-histogram.sql`](./07_performance_tuning/community_scripts/stats_optimizer/cpu-minute-histogram.sql) | `community_scripts/stats_optimizer` | BASSO | OK | this section may be an approximation |
| [`crc-stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/crc-stats.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | crc-stats.sql |
| [`dbms_stats_get_prefs.sql`](./07_performance_tuning/community_scripts/stats_optimizer/dbms_stats_get_prefs.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | dbms_stats_get_prefs.sql |
| [`dbms_stats_report.sql`](./07_performance_tuning/community_scripts/stats_optimizer/dbms_stats_report.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | dbms_stats_report.sql |
| [`drcp_connection_status.sql`](./07_performance_tuning/community_scripts/stats_optimizer/drcp_connection_status.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Script operativo Oracle per: drcp connection status. |
| [`drcp_pool_cc_stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/drcp_pool_cc_stats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | , wait_time -- reserved for future use |
| [`drcp_pool_stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/drcp_pool_stats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | drcp_pool_stats.sql |
| [`dup-system-stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/dup-system-stats.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | dup-system-stats.sql |
| [`flash-hist-stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/flash-hist-stats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Analisi Active Session History (ASH) per colli di bottiglia e top consumer. |
| [`gather_system_stats_iteratively.sql`](./07_performance_tuning/community_scripts/stats_optimizer/gather_system_stats_iteratively.sql) | `community_scripts/stats_optimizer` | BASSO | OK | gather_system_stats_iteratively.sh |
| [`gather_table_stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/gather_table_stats.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | Script operativo Oracle per: gather table stats. |
| [`get_stats_job.sql`](./07_performance_tuning/community_scripts/stats_optimizer/get_stats_job.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Diagnostica e controllo job Oracle Scheduler. |
| [`get_stats_task.sql`](./07_performance_tuning/community_scripts/stats_optimizer/get_stats_task.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Script operativo Oracle per: get stats task. |
| [`get_system_stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/get_system_stats.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | see sys.aux_stats$ |
| [`getobj_stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/getobj_stats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | subpartitions |
| [`getstat.sql`](./07_performance_tuning/community_scripts/stats_optimizer/getstat.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Script operativo Oracle per: getstat. |
| [`getstats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/getstats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Script operativo Oracle per: getstats. |
| [`getstatu2.sql`](./07_performance_tuning/community_scripts/stats_optimizer/getstatu2.sql) | `community_scripts/stats_optimizer` | BASSO | OK | break on username |
| [`histogram_values.sql`](./07_performance_tuning/community_scripts/stats_optimizer/histogram_values.sql) | `community_scripts/stats_optimizer` | BASSO | OK | thanks to Jonathan Lewis for the base query |
| [`idle-sessions-histogram.sql`](./07_performance_tuning/community_scripts/stats_optimizer/idle-sessions-histogram.sql) | `community_scripts/stats_optimizer` | BASSO | OK | idle-sessions-histogram.sql |
| [`io_stat.sql`](./07_performance_tuning/community_scripts/stats_optimizer/io_stat.sql) | `community_scripts/stats_optimizer` | BASSO | OK | first run 'io_begin.sql' |
| [`io_stat2.sql`](./07_performance_tuning/community_scripts/stats_optimizer/io_stat2.sql) | `community_scripts/stats_optimizer` | BASSO | OK | first run 'io_begin.sql' |
| [`io_stat3.sql`](./07_performance_tuning/community_scripts/stats_optimizer/io_stat3.sql) | `community_scripts/stats_optimizer` | BASSO | OK | first run 'io_begin.sql' |
| [`latch_statsa.sql`](./07_performance_tuning/community_scripts/stats_optimizer/latch_statsa.sql) | `community_scripts/stats_optimizer` | ALTO | OK | Script operativo Oracle per: latch statsa. |
| [`latch_statss.sql`](./07_performance_tuning/community_scripts/stats_optimizer/latch_statss.sql) | `community_scripts/stats_optimizer` | ALTO | OK | Script operativo Oracle per: latch statss. |
| [`locked_stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/locked_stats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | locked_stats.sql |
| [`log-switch-histogram.sql`](./07_performance_tuning/community_scripts/stats_optimizer/log-switch-histogram.sql) | `community_scripts/stats_optimizer` | BASSO | OK | log-switch-histogram.sql |
| [`log_histogram.sql`](./07_performance_tuning/community_scripts/stats_optimizer/log_histogram.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Script operativo Oracle per: log histogram. |
| [`mystat.sql`](./07_performance_tuning/community_scripts/stats_optimizer/mystat.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Script operativo Oracle per: mystat. |
| [`os-stats-avgs.sql`](./07_performance_tuning/community_scripts/stats_optimizer/os-stats-avgs.sql) | `community_scripts/stats_optimizer` | BASSO | OK | os-stats-avg.sql |
| [`osstat-cpu-10g.sql`](./07_performance_tuning/community_scripts/stats_optimizer/osstat-cpu-10g.sql) | `community_scripts/stats_optimizer` | BASSO | OK | osstat-cpu-10g.sql |
| [`osstat-cpu-rpt.sql`](./07_performance_tuning/community_scripts/stats_optimizer/osstat-cpu-rpt.sql) | `community_scripts/stats_optimizer` | BASSO | OK | osstat-cpu-rpt.sql |
| [`osstat-cpu.sql`](./07_performance_tuning/community_scripts/stats_optimizer/osstat-cpu.sql) | `community_scripts/stats_optimizer` | BASSO | OK | osstat-cpu.sql |
| [`partstats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/partstats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | partstats.sql |
| [`partstats_sum.sql`](./07_performance_tuning/community_scripts/stats_optimizer/partstats_sum.sql) | `community_scripts/stats_optimizer` | BASSO | OK | partstats_sum.sql |
| [`pgastat.sql`](./07_performance_tuning/community_scripts/stats_optimizer/pgastat.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Script operativo Oracle per: pgastat. |
| [`pgastat_hist.sql`](./07_performance_tuning/community_scripts/stats_optimizer/pgastat_hist.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Script operativo Oracle per: pgastat hist. |
| [`plan-stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/plan-stats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | plan-stats.sql |
| [`rbs_no_optimal.sql`](./07_performance_tuning/community_scripts/stats_optimizer/rbs_no_optimal.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | rbs_optimal.sql |
| [`rbs_optimal.sql`](./07_performance_tuning/community_scripts/stats_optimizer/rbs_optimal.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | rbs_optimal.sql |
| [`rman-bkup-status.sql`](./07_performance_tuning/community_scripts/stats_optimizer/rman-bkup-status.sql) | `community_scripts/stats_optimizer` | BASSO | OK | rman-bkup-status.sql |
| [`segment-space-statistics-hist.sql`](./07_performance_tuning/community_scripts/stats_optimizer/segment-space-statistics-hist.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | segment-space-statistics-hist.sql |
| [`segment-space-statistics.sql`](./07_performance_tuning/community_scripts/stats_optimizer/segment-space-statistics.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | segment-space-statistics.sql |
| [`segment-statistics.sql`](./07_performance_tuning/community_scripts/stats_optimizer/segment-statistics.sql) | `community_scripts/stats_optimizer` | BASSO | OK | may be interesting results |
| [`sess-optimizer-env.sql`](./07_performance_tuning/community_scripts/stats_optimizer/sess-optimizer-env.sql) | `community_scripts/stats_optimizer` | BASSO | OK | sess-optimizer-env.sql |
| [`set_avg_stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/set_avg_stats.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | get avg rows for parts |
| [`show_mview_status.sql`](./07_performance_tuning/community_scripts/stats_optimizer/show_mview_status.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Script operativo Oracle per: show mview status. |
| [`show_os_stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/show_os_stats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | show_os_stats.sql |
| [`show_os_stats_hist.sql`](./07_performance_tuning/community_scripts/stats_optimizer/show_os_stats_hist.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Script operativo Oracle per: show os stats hist. |
| [`sp_io_stat_drive.sql`](./07_performance_tuning/community_scripts/stats_optimizer/sp_io_stat_drive.sql) | `community_scripts/stats_optimizer` | BASSO | OK | sp_io_stat_drive.sql |
| [`sp_io_stat_sys.sql`](./07_performance_tuning/community_scripts/stats_optimizer/sp_io_stat_sys.sql) | `community_scripts/stats_optimizer` | BASSO | OK | sp_io_stat_sys.sql |
| [`sql-exe-times-ash-histogram.sql`](./07_performance_tuning/community_scripts/stats_optimizer/sql-exe-times-ash-histogram.sql) | `community_scripts/stats_optimizer` | BASSO | OK | sql-exe-times-ash.sql |
| [`sql-exe-times-awr-histogram.sql`](./07_performance_tuning/community_scripts/stats_optimizer/sql-exe-times-awr-histogram.sql) | `community_scripts/stats_optimizer` | BASSO | OK | sql-exe-times-awr.sql |
| [`stale-stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/stale-stats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | stale-stats.sql |
| [`stat-classes.sql`](./07_performance_tuning/community_scripts/stats_optimizer/stat-classes.sql) | `community_scripts/stats_optimizer` | BASSO | OK | stat-classes |
| [`stat-names.sql`](./07_performance_tuning/community_scripts/stats_optimizer/stat-names.sql) | `community_scripts/stats_optimizer` | BASSO | OK | stat-names.sql |
| [`stat.sql`](./07_performance_tuning/community_scripts/stats_optimizer/stat.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Timur Akhmadeev - akhmadeev@.com |
| [`stats-sqlid.sql`](./07_performance_tuning/community_scripts/stats_optimizer/stats-sqlid.sql) | `community_scripts/stats_optimizer` | BASSO | OK | stats-sqlid.sql |
| [`stats_config.sql`](./07_performance_tuning/community_scripts/stats_optimizer/stats_config.sql) | `community_scripts/stats_optimizer` | BASSO | OK | Script operativo Oracle per: stats config. |
| [`stats_mod.sql`](./07_performance_tuning/community_scripts/stats_optimizer/stats_mod.sql) | `community_scripts/stats_optimizer` | BASSO | OK | jkstill@gmail.com |
| [`stats_prefs.sql`](./07_performance_tuning/community_scripts/stats_optimizer/stats_prefs.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | Script operativo Oracle per: stats prefs. |
| [`stats_trace.sql`](./07_performance_tuning/community_scripts/stats_optimizer/stats_trace.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | Script operativo Oracle per: stats trace. |
| [`stats_trace_test.sql`](./07_performance_tuning/community_scripts/stats_optimizer/stats_trace_test.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | stats_trace_test.sql |
| [`stats_wait.sql`](./07_performance_tuning/community_scripts/stats_optimizer/stats_wait.sql) | `community_scripts/stats_optimizer` | BASSO | OK | if state is 'WAITING' then wait_time is time in current wait |
| [`undo_stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/undo_stats.sql) | `community_scripts/stats_optimizer` | BASSO | OK | undo_stats.sql |
| [`unlock_stats.sql`](./07_performance_tuning/community_scripts/stats_optimizer/unlock_stats.sql) | `community_scripts/stats_optimizer` | MEDIO | OK | Diagnosi lock/sessioni bloccanti e catene di attesa. |
| [`xmldb-status.sql`](./07_performance_tuning/community_scripts/stats_optimizer/xmldb-status.sql) | `community_scripts/stats_optimizer` | BASSO | OK | xmldb-status.sql |
| [`sp_top_sql_io.sql`](./07_performance_tuning/community_scripts/statspack/sp_top_sql_io.sql) | `community_scripts/statspack` | BASSO | OK | sp_top_sql_io.sql |
| [`dbms-sqltune-sqlid.sql`](./07_performance_tuning/community_scripts/tuning/dbms-sqltune-sqlid.sql) | `community_scripts/tuning` | ALTO | OK | dbms-sqltune-sqlid.sql |
| [`find-expensive-sql.sql`](./07_performance_tuning/community_scripts/tuning/find-expensive-sql.sql) | `community_scripts/tuning` | BASSO | OK | find-expensive-sql.sql |
| [`get-expensive-sqlid-sts.sql`](./07_performance_tuning/community_scripts/tuning/get-expensive-sqlid-sts.sql) | `community_scripts/tuning` | MEDIO | OK | get-expensive-sqlid-sts.sql |
| [`PerfTuningAnalisys.sql`](./07_performance_tuning/community_scripts/tuning/PerfTuningAnalisys.sql) | `community_scripts/tuning` | MEDIO | OK | vedere in generale quale servizio bombarda di piu' e capire perche non viene utilizzato un ConnPOol o perche si ritrova a aprire e chiudere  |
| [`profile_from_awr.sql`](./07_performance_tuning/community_scripts/tuning/profile_from_awr.sql) | `community_scripts/tuning` | BASSO | OK | File name: create_sql_profile_awr.sql |
| [`SPM.sql`](./07_performance_tuning/community_scripts/tuning/SPM.sql) | `community_scripts/tuning` | ALTO | OK | Per fissare un piano in SPM bisogna prima verificare se il piano corretto è ancora presente nella GV$SQL, o se ad esempio è presente sull'al |
| [`SPM_from_AWR_old_fashioned.sql`](./07_performance_tuning/community_scripts/tuning/SPM_from_AWR_old_fashioned.sql) | `community_scripts/tuning` | BASSO | OK | HOW TO LOAD SQL PLANS INTO SPM FROM AWR (Doc ID 789888.1) |
| [`SQL Area 1x.sql`](./07_performance_tuning/community_scripts/tuning/SQL%20Area%201x.sql) | `community_scripts/tuning` | MEDIO | OK | and s.sql_id in (select sp.sql_id from v$sql_plan sp where sp.object_name='TABELLA') |
| [`SQL Bind.sql`](./07_performance_tuning/community_scripts/tuning/SQL%20Bind.sql) | `community_scripts/tuning` | BASSO | OK | Matching Signatures |
| [`SQL Plan Change.sql`](./07_performance_tuning/community_scripts/tuning/SQL%20Plan%20Change.sql) | `community_scripts/tuning` | BASSO | OK | File name: unstable_plans.sql |
| [`SQL Stats.sql`](./07_performance_tuning/community_scripts/tuning/SQL%20Stats.sql) | `community_scripts/tuning` | BASSO | OK | HISTORICAL SQL STATISTICS |
| [`sql-exe-events-ash.sql`](./07_performance_tuning/community_scripts/tuning/sql-exe-events-ash.sql) | `community_scripts/tuning` | BASSO | OK | sql-exe-events-ash.sql |
| [`sql-exe-events-awr.sql`](./07_performance_tuning/community_scripts/tuning/sql-exe-events-awr.sql) | `community_scripts/tuning` | BASSO | OK | sql-exe-events-awr.sql |
| [`sql-exe-times-ash-rpt.sql`](./07_performance_tuning/community_scripts/tuning/sql-exe-times-ash-rpt.sql) | `community_scripts/tuning` | BASSO | OK | sql-exe-times-ash-rpt.sql |
| [`sql-exe-times-ash.sql`](./07_performance_tuning/community_scripts/tuning/sql-exe-times-ash.sql) | `community_scripts/tuning` | BASSO | OK | sql-exe-times-ash.sql |
| [`sql-exe-times-awr-histogram.sql`](./07_performance_tuning/community_scripts/tuning/sql-exe-times-awr-histogram.sql) | `community_scripts/tuning` | BASSO | OK | sql-exe-times-awr.sql |
| [`sql-exe-times-awr-rpt.sql`](./07_performance_tuning/community_scripts/tuning/sql-exe-times-awr-rpt.sql) | `community_scripts/tuning` | BASSO | OK | sql-exe-times-awr-rpt.sql |
| [`sql-exe-times-awr.sql`](./07_performance_tuning/community_scripts/tuning/sql-exe-times-awr.sql) | `community_scripts/tuning` | BASSO | OK | sql-exe-times-awr.sql |
| [`SQL_Profile_Other_SqlID.sql`](./07_performance_tuning/community_scripts/tuning/SQL_Profile_Other_SqlID.sql) | `community_scripts/tuning` | BASSO | OK | Supporto SQL tuning: piano esecuzione, SPM e stabilità optimizer. |
| [`View_UnstablePlan.sql`](./07_performance_tuning/community_scripts/tuning/View_UnstablePlan.sql) | `community_scripts/tuning` | MEDIO | OK | (buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta)) avg_lio |
| [`controllo_statistiche.txt`](./07_performance_tuning/controllo_statistiche.txt) | `-` | MEDIO | OK | Interpretazione |

### `08_tde_security` — TDE & Security (8 script)

| Script | Sottocartella | Rischio | Stato cartella | Spiegazione |
|---|---|---|---|---|
| [`audit-actions.sql`](./08_tde_security/community_scripts/audit-actions.sql) | `community_scripts` | BASSO | OK | , aud.ses_actions |
| [`dba_audit_session.sql`](./08_tde_security/community_scripts/dba_audit_session.sql) | `community_scripts` | BASSO | OK | and rownum < 100 |
| [`dba_audit_session_recent.sql`](./08_tde_security/community_scripts/dba_audit_session_recent.sql) | `community_scripts` | BASSO | OK | dba_audit_session_recent.sql |
| [`dba_audit_trail.sql`](./08_tde_security/community_scripts/dba_audit_trail.sql) | `community_scripts` | MEDIO | OK | dba_audit_trail.sql |
| [`dba_audit_trail_persons.sql`](./08_tde_security/community_scripts/dba_audit_trail_persons.sql) | `community_scripts` | MEDIO | OK | dba_audit_trail_persons.sql |
| [`dba_table_audit_flags.sql`](./08_tde_security/community_scripts/dba_table_audit_flags.sql) | `community_scripts` | ALTO | OK | dba_table_audit_flags.sql |
| [`show_session_audit.sql`](./08_tde_security/community_scripts/show_session_audit.sql) | `community_scripts` | BASSO | OK | Controllo sicurezza Oracle (audit/TDE/compliance operativa). |
| [`ua-audit-log-cleanup-job.sql`](./08_tde_security/community_scripts/ua-audit-log-cleanup-job.sql) | `community_scripts` | MEDIO | OK | ua-audit-log-cleanup-job.sql |

### `09_compression` — Compression (1 script)

| Script | Sottocartella | Rischio | Stato cartella | Spiegazione |
|---|---|---|---|---|
| [`Get_DDL_RENAME_OBJECT_v1.3.sql`](./09_compression/Get_DDL_RENAME_OBJECT_v1.3.sql) | `-` | ALTO | OK | Dare i privilegi allo schema proprietario della funzione |

### `10_partition_manager` — Partition Manager (2 script)

| Script | Sottocartella | Rischio | Stato cartella | Spiegazione |
|---|---|---|---|---|
| [`dba_op_user_setup.sql`](./10_partition_manager/dba_op_user_setup.sql) | `-` | ALTO | OK | default tablespace for DBA_OP |
| [`Script_Creazione_Partition_Manager_v2_36.sql`](./10_partition_manager/Script_Creazione_Partition_Manager_v2_36.sql) | `-` | ALTO | OK | Script per Creazione Package Svecchiamento Tabelle |

### `11_sql_templates` — SQL Templates (17 script)

| Script | Sottocartella | Rischio | Stato cartella | Spiegazione |
|---|---|---|---|---|
| [`00X_Form_alter_index.sql`](./11_sql_templates/00X_Form_alter_index.sql) | `-` | MEDIO | OK | Script operativo Oracle per: 00X Form alter index. |
| [`00X_Form_alter_table.sql`](./11_sql_templates/00X_Form_alter_table.sql) | `-` | MEDIO | OK | Script operativo Oracle per: 00X Form alter table. |
| [`00X_Form_assign_grant.sql`](./11_sql_templates/00X_Form_assign_grant.sql) | `-` | MEDIO | OK | Script operativo Oracle per: 00X Form assign grant. |
| [`00X_Form_create_index.sql`](./11_sql_templates/00X_Form_create_index.sql) | `-` | MEDIO | OK | CREATE INDEX |
| [`00X_Form_create_table.sql`](./11_sql_templates/00X_Form_create_table.sql) | `-` | MEDIO | OK | CREATE TABLE |
| [`00X_Form_create_view.sql`](./11_sql_templates/00X_Form_create_view.sql) | `-` | MEDIO | OK | Script operativo Oracle per: 00X Form create view. |
| [`00X_Form_dml.sql`](./11_sql_templates/00X_Form_dml.sql) | `-` | ALTO | OK | Script operativo Oracle per: 00X Form dml. |
| [`00X_Form_drop_table.sql`](./11_sql_templates/00X_Form_drop_table.sql) | `-` | ALTO | OK | Script operativo Oracle per: 00X Form drop table. |
| [`00X_Form_foreign_key.sql`](./11_sql_templates/00X_Form_foreign_key.sql) | `-` | MEDIO | OK | CREATE FOREIGN KEY |
| [`00X_Form_loop_commit.sql`](./11_sql_templates/00X_Form_loop_commit.sql) | `-` | BASSO | OK | PL/SQL WITH PARTIAL COMMIT |
| [`00X_Form_package.sql`](./11_sql_templates/00X_Form_package.sql) | `-` | MEDIO | OK | CREATE PACKAGE |
| [`00X_Form_primary_key.sql`](./11_sql_templates/00X_Form_primary_key.sql) | `-` | MEDIO | OK | CREATE PRIMARY KEY |
| [`00X_Form_procedure.sql`](./11_sql_templates/00X_Form_procedure.sql) | `-` | MEDIO | OK | CREATE PROCEDURE |
| [`00X_Form_sequence.sql`](./11_sql_templates/00X_Form_sequence.sql) | `-` | MEDIO | OK | CREATE SEQUENCE |
| [`00X_Form_sinonimi.sql`](./11_sql_templates/00X_Form_sinonimi.sql) | `-` | MEDIO | OK | CREATE SYNONYM |
| [`00X_Form_trigger.sql`](./11_sql_templates/00X_Form_trigger.sql) | `-` | MEDIO | OK | CREATE TRIGGER |
| [`Form_loop_rowid.sql`](./11_sql_templates/Form_loop_rowid.sql) | `-` | ALTO | OK | creazione tabella rowid |

### `12_utilities` — Utilities (102 script)

| Script | Sottocartella | Rischio | Stato cartella | Spiegazione |
|---|---|---|---|---|
| [`all-parms.sh`](./12_utilities/community_scripts/all-parms.sh) | `community_scripts` | BASSO | OK | !/usr/bin/env bash |
| [`asm-disk-chk.pl`](./12_utilities/community_scripts/asm-disk-chk.pl) | `community_scripts` | BASSO | OK | !/usr/bin/env perl |
| [`asm-disk-chk.sh`](./12_utilities/community_scripts/asm-disk-chk.sh) | `community_scripts` | BASSO | OK | on a virtual box server using iSCSI for RAC storage |
| [`all-parms.sh`](./12_utilities/community_scripts/bin/all-parms.sh) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env bash |
| [`asm-disk-chk.pl`](./12_utilities/community_scripts/bin/asm-disk-chk.pl) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env perl |
| [`asm-disk-chk.sh`](./12_utilities/community_scripts/bin/asm-disk-chk.sh) | `community_scripts/bin` | BASSO | OK | on a virtual box server using iSCSI for RAC storage |
| [`functions.sh`](./12_utilities/community_scripts/bin/functions.sh) | `community_scripts/bin` | ALTO | OK | use to get RAC instances from db name |
| [`get-alert-logs.sh`](./12_utilities/community_scripts/bin/get-alert-logs.sh) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env bash |
| [`get-bind-info.pl`](./12_utilities/community_scripts/bin/get-bind-info.pl) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env perl |
| [`get-crsctl.sh`](./12_utilities/community_scripts/bin/get-crsctl.sh) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env bash |
| [`get-lgwr-trace.sh`](./12_utilities/community_scripts/bin/get-lgwr-trace.sh) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env bash |
| [`get-ohomes.sh`](./12_utilities/community_scripts/bin/get-ohomes.sh) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env bash |
| [`memsz-all.sh`](./12_utilities/community_scripts/bin/memsz-all.sh) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env bash |
| [`memsz.sh`](./12_utilities/community_scripts/bin/memsz.sh) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env bash |
| [`oracle-connect-rate.sh`](./12_utilities/community_scripts/bin/oracle-connect-rate.sh) | `community_scripts/bin` | BASSO | OK | get connection rate from oracle listener log |
| [`procmem.pl`](./12_utilities/community_scripts/bin/procmem.pl) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env perl |
| [`rman-chk-syntax.sh`](./12_utilities/community_scripts/bin/rman-chk-syntax.sh) | `community_scripts/bin` | BASSO | OK | Determine if STDIN is from pipe or terminal |
| [`sga-smallpage-detector.pl`](./12_utilities/community_scripts/bin/sga-smallpage-detector.pl) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env perl |
| [`show-sga-page-allocation.sh`](./12_utilities/community_scripts/bin/show-sga-page-allocation.sh) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env bash |
| [`sql-driver.sh`](./12_utilities/community_scripts/bin/sql-driver.sh) | `community_scripts/bin` | BASSO | OK | !/usr/bin/env bash |
| [`sqlnet-io-rates.pl`](./12_utilities/community_scripts/bin/sqlnet-io-rates.pl) | `community_scripts/bin` | MEDIO | OK | !/usr/bin/env perl |
| [`sqlnet-io.sql`](./12_utilities/community_scripts/bin/sqlnet-io.sql) | `community_scripts/bin` | BASSO | OK | and sess.sid = 34 --and sess.serial# = 18799 |
| [`aas-awr-pdb-calc.sql`](./12_utilities/community_scripts/cdb_pdb/aas-awr-pdb-calc.sql) | `community_scripts/cdb_pdb` | BASSO | OK | aas-awr-pdb-calc.sql |
| [`cdb-containers-query.sql`](./12_utilities/community_scripts/cdb_pdb/cdb-containers-query.sql) | `community_scripts/cdb_pdb` | BASSO | OK | cdb-containers-query.sql |
| [`cdb_sched_jobs.sql`](./12_utilities/community_scripts/cdb_pdb/cdb_sched_jobs.sql) | `community_scripts/cdb_pdb` | BASSO | OK | dba_scheduler_jobs.sql |
| [`pdb-awr-enable.sql`](./12_utilities/community_scripts/cdb_pdb/pdb-awr-enable.sql) | `community_scripts/cdb_pdb` | ALTO | OK | pdb-awr-enable.sql |
| [`pdb-modifiable-params-dump.sql`](./12_utilities/community_scripts/cdb_pdb/pdb-modifiable-params-dump.sql) | `community_scripts/cdb_pdb` | BASSO | OK | pdb-modifiable-params-dump.sql |
| [`pdb-violations.sql`](./12_utilities/community_scripts/cdb_pdb/pdb-violations.sql) | `community_scripts/cdb_pdb` | BASSO | OK | pdb-violations.sql |
| [`resmgr-waits-pdb.sql`](./12_utilities/community_scripts/cdb_pdb/resmgr-waits-pdb.sql) | `community_scripts/cdb_pdb` | BASSO | OK | resmgr-waits-pdb.sql |
| [`show-pdbs.sql`](./12_utilities/community_scripts/cdb_pdb/show-pdbs.sql) | `community_scripts/cdb_pdb` | BASSO | OK | Gestione multitenant Oracle (CDB/PDB) e verifiche operative. |
| [`show_container.sql`](./12_utilities/community_scripts/cdb_pdb/show_container.sql) | `community_scripts/cdb_pdb` | BASSO | OK | show_container.sql |
| [`functions.sh`](./12_utilities/community_scripts/functions.sh) | `community_scripts` | ALTO | OK | use to get RAC instances from db name |
| [`get-alert-logs.sh`](./12_utilities/community_scripts/get-alert-logs.sh) | `community_scripts` | BASSO | OK | !/usr/bin/env bash |
| [`get-bind-info.pl`](./12_utilities/community_scripts/get-bind-info.pl) | `community_scripts` | BASSO | OK | !/usr/bin/env perl |
| [`get-crsctl.sh`](./12_utilities/community_scripts/get-crsctl.sh) | `community_scripts` | BASSO | OK | !/usr/bin/env bash |
| [`get-lgwr-trace.sh`](./12_utilities/community_scripts/get-lgwr-trace.sh) | `community_scripts` | BASSO | OK | !/usr/bin/env bash |
| [`get-ohomes.sh`](./12_utilities/community_scripts/get-ohomes.sh) | `community_scripts` | BASSO | OK | !/usr/bin/env bash |
| [`memsz-all.sh`](./12_utilities/community_scripts/memsz-all.sh) | `community_scripts` | BASSO | OK | !/usr/bin/env bash |
| [`memsz.sh`](./12_utilities/community_scripts/memsz.sh) | `community_scripts` | BASSO | OK | !/usr/bin/env bash |
| [`oracle-connect-rate.sh`](./12_utilities/community_scripts/oracle-connect-rate.sh) | `community_scripts` | BASSO | OK | get connection rate from oracle listener log |
| [`procmem.pl`](./12_utilities/community_scripts/procmem.pl) | `community_scripts` | BASSO | OK | !/usr/bin/env perl |
| [`rman-chk-syntax.sh`](./12_utilities/community_scripts/rman-chk-syntax.sh) | `community_scripts` | BASSO | OK | Determine if STDIN is from pipe or terminal |
| [`all_jobs.sql`](./12_utilities/community_scripts/scheduler/all_jobs.sql) | `community_scripts/scheduler` | BASSO | OK | Diagnostica e controllo job Oracle Scheduler. |
| [`all_sched_jobs.sql`](./12_utilities/community_scripts/scheduler/all_sched_jobs.sql) | `community_scripts/scheduler` | BASSO | OK | all_scheduler_jobs.sql |
| [`ash-sqlid-event-window.sql`](./12_utilities/community_scripts/scheduler/ash-sqlid-event-window.sql) | `community_scripts/scheduler` | BASSO | OK | ash-sqlid-event-window.sql |
| [`autotask_auto_stats_disable.sql`](./12_utilities/community_scripts/scheduler/autotask_auto_stats_disable.sql) | `community_scripts/scheduler` | BASSO | OK | disable automatics tasks |
| [`autotask_auto_stats_enable.sql`](./12_utilities/community_scripts/scheduler/autotask_auto_stats_enable.sql) | `community_scripts/scheduler` | BASSO | OK | enable automatics stats |
| [`autotask_auto_tasks_disable.sql`](./12_utilities/community_scripts/scheduler/autotask_auto_tasks_disable.sql) | `community_scripts/scheduler` | BASSO | OK | disable automatics tasks |
| [`autotask_auto_tasks_enable.sql`](./12_utilities/community_scripts/scheduler/autotask_auto_tasks_enable.sql) | `community_scripts/scheduler` | BASSO | OK | enable automatics stats |
| [`autotask_client_attributes.sql`](./12_utilities/community_scripts/scheduler/autotask_client_attributes.sql) | `community_scripts/scheduler` | BASSO | OK | Script operativo Oracle per: autotask client attributes. |
| [`autotask_client_history.sql`](./12_utilities/community_scripts/scheduler/autotask_client_history.sql) | `community_scripts/scheduler` | BASSO | OK | WHERE client_name like '%stats%' |
| [`autotask_client_job.sql`](./12_utilities/community_scripts/scheduler/autotask_client_job.sql) | `community_scripts/scheduler` | BASSO | OK | where client_name='auto optimizer stats collection' |
| [`autotask_clients.sql`](./12_utilities/community_scripts/scheduler/autotask_clients.sql) | `community_scripts/scheduler` | BASSO | OK | Script operativo Oracle per: autotask clients. |
| [`autotask_job_history.sql`](./12_utilities/community_scripts/scheduler/autotask_job_history.sql) | `community_scripts/scheduler` | BASSO | OK | where client_name like '%optimizer stats%' |
| [`autotask_operation.sql`](./12_utilities/community_scripts/scheduler/autotask_operation.sql) | `community_scripts/scheduler` | BASSO | OK | Script operativo Oracle per: autotask operation. |
| [`autotask_resources.sql`](./12_utilities/community_scripts/scheduler/autotask_resources.sql) | `community_scripts/scheduler` | BASSO | OK | Script operativo Oracle per: autotask resources. |
| [`autotask_sched.sql`](./12_utilities/community_scripts/scheduler/autotask_sched.sql) | `community_scripts/scheduler` | BASSO | OK | , start_time |
| [`autotask_sql_setup.sql`](./12_utilities/community_scripts/scheduler/autotask_sql_setup.sql) | `community_scripts/scheduler` | BASSO | OK | set nls_timezone_tz_format to 'yyyy-mm-dd hh24:mi:ss tzh:tzm' |
| [`autotask_task.sql`](./12_utilities/community_scripts/scheduler/autotask_task.sql) | `community_scripts/scheduler` | BASSO | OK | Script operativo Oracle per: autotask task. |
| [`autotask_window_clients.sql`](./12_utilities/community_scripts/scheduler/autotask_window_clients.sql) | `community_scripts/scheduler` | BASSO | OK | , health_monitor |
| [`autotask_window_hist.sql`](./12_utilities/community_scripts/scheduler/autotask_window_hist.sql) | `community_scripts/scheduler` | BASSO | OK | Script operativo Oracle per: autotask window hist. |
| [`cdb_sched_jobs.sql`](./12_utilities/community_scripts/scheduler/cdb_sched_jobs.sql) | `community_scripts/scheduler` | BASSO | OK | dba_scheduler_jobs.sql |
| [`dba_jobs.sql`](./12_utilities/community_scripts/scheduler/dba_jobs.sql) | `community_scripts/scheduler` | BASSO | OK | Diagnostica e controllo job Oracle Scheduler. |
| [`dba_jobs_running.sql`](./12_utilities/community_scripts/scheduler/dba_jobs_running.sql) | `community_scripts/scheduler` | BASSO | OK | Diagnostica e controllo job Oracle Scheduler. |
| [`dba_sched_jobs.sql`](./12_utilities/community_scripts/scheduler/dba_sched_jobs.sql) | `community_scripts/scheduler` | BASSO | OK | dba_scheduler_jobs.sql |
| [`dba_sched_jobs_hist.sql`](./12_utilities/community_scripts/scheduler/dba_sched_jobs_hist.sql) | `community_scripts/scheduler` | BASSO | OK | jkstill@gmail.com |
| [`disable-autotasks-resource-mgr.sql`](./12_utilities/community_scripts/scheduler/disable-autotasks-resource-mgr.sql) | `community_scripts/scheduler` | ALTO | OK | Oracle sometimes enforces Resource Manager for background processes |
| [`get_stats_job.sql`](./12_utilities/community_scripts/scheduler/get_stats_job.sql) | `community_scripts/scheduler` | BASSO | OK | Diagnostica e controllo job Oracle Scheduler. |
| [`job_submit.sql`](./12_utilities/community_scripts/scheduler/job_submit.sql) | `community_scripts/scheduler` | BASSO | OK | job_submit.sql |
| [`scheduler_programs.sql`](./12_utilities/community_scripts/scheduler/scheduler_programs.sql) | `community_scripts/scheduler` | BASSO | OK | Diagnostica e controllo job Oracle Scheduler. |
| [`scheduler_windows.sql`](./12_utilities/community_scripts/scheduler/scheduler_windows.sql) | `community_scripts/scheduler` | BASSO | OK | , next_start_date |
| [`show_jobs.sql`](./12_utilities/community_scripts/scheduler/show_jobs.sql) | `community_scripts/scheduler` | BASSO | OK | current_session_label, |
| [`sp_job_submit.sql`](./12_utilities/community_scripts/scheduler/sp_job_submit.sql) | `community_scripts/scheduler` | BASSO | OK | job_submit.sql |
| [`ua-audit-log-cleanup-job.sql`](./12_utilities/community_scripts/scheduler/ua-audit-log-cleanup-job.sql) | `community_scripts/scheduler` | MEDIO | OK | ua-audit-log-cleanup-job.sql |
| [`who_dba_jobs.sql`](./12_utilities/community_scripts/scheduler/who_dba_jobs.sql) | `community_scripts/scheduler` | BASSO | OK | jkstill@gmail.com |
| [`sga-smallpage-detector.pl`](./12_utilities/community_scripts/sga-smallpage-detector.pl) | `community_scripts` | BASSO | OK | !/usr/bin/env perl |
| [`show-sga-page-allocation.sh`](./12_utilities/community_scripts/show-sga-page-allocation.sh) | `community_scripts` | BASSO | OK | !/usr/bin/env bash |
| [`sql-driver.sh`](./12_utilities/community_scripts/sql-driver.sh) | `community_scripts` | BASSO | OK | !/usr/bin/env bash |
| [`sqlnet-io-rates.pl`](./12_utilities/community_scripts/sqlnet-io-rates.pl) | `community_scripts` | MEDIO | OK | !/usr/bin/env perl |
| [`sqlnet-io.sql`](./12_utilities/community_scripts/sqlnet-io.sql) | `community_scripts` | BASSO | OK | and sess.sid = 34 --and sess.serial# = 18799 |
| [`block-summary.sql`](./12_utilities/community_scripts/storage/block-summary.sql) | `community_scripts/storage` | BASSO | OK | block-summary.sql |
| [`dbms_space_asa_rpt.sql`](./12_utilities/community_scripts/storage/dbms_space_asa_rpt.sql) | `community_scripts/storage` | BASSO | OK | dbms_space_asa_rpt.sql |
| [`dfshrink-gen-9i.sql`](./12_utilities/community_scripts/storage/dfshrink-gen-9i.sql) | `community_scripts/storage` | ALTO | OK | dfshrink-gen-9i.sql |
| [`dfshrink-gen.sql`](./12_utilities/community_scripts/storage/dfshrink-gen.sql) | `community_scripts/storage` | ALTO | OK | dfshrink-gen.sql |
| [`gen_bigfile_autoextend.sql`](./12_utilities/community_scripts/storage/gen_bigfile_autoextend.sql) | `community_scripts/storage` | MEDIO | OK | Generatore di comandi per estendere MAXSIZE sui BIGFILE Tablespaces |
| [`maxext3.sql`](./12_utilities/community_scripts/storage/maxext3.sql) | `community_scripts/storage` | BASSO | OK | find tables/indexes with only 1 or 2 extents to go before |
| [`showdf.sql`](./12_utilities/community_scripts/storage/showdf.sql) | `community_scripts/storage` | BASSO | OK | get from dba_data_files and dba_temp_files rather that v$ views |
| [`showdf7.sql`](./12_utilities/community_scripts/storage/showdf7.sql) | `community_scripts/storage` | BASSO | OK | Script operativo Oracle per: showdf7. |
| [`showdf8i.sql`](./12_utilities/community_scripts/storage/showdf8i.sql) | `community_scripts/storage` | BASSO | OK | showdf8i.sql |
| [`showfree.sql`](./12_utilities/community_scripts/storage/showfree.sql) | `community_scripts/storage` | BASSO | OK | showfree.sql |
| [`showfreemax.sql`](./12_utilities/community_scripts/storage/showfreemax.sql) | `community_scripts/storage` | BASSO | OK | showmaxfree.sql |
| [`showfreesum.sql`](./12_utilities/community_scripts/storage/showfreesum.sql) | `community_scripts/storage` | BASSO | OK | showfreesum.sql |
| [`showspace.sql`](./12_utilities/community_scripts/storage/showspace.sql) | `community_scripts/storage` | BASSO | OK | showspace.sql |
| [`showtbs.sql`](./12_utilities/community_scripts/storage/showtbs.sql) | `community_scripts/storage` | BASSO | OK | spool tbs.lis |
| [`tbs_maxsize_limits.sql`](./12_utilities/community_scripts/storage/tbs_maxsize_limits.sql) | `community_scripts/storage` | BASSO | OK | MAXSIZE vs ACTUAL SIZE (Non-CDB/CDB Tablespaces) |
| [`undo_blocks_required.sql`](./12_utilities/community_scripts/storage/undo_blocks_required.sql) | `community_scripts/storage` | BASSO | OK | undo_blocks_required.sql |
| [`undo_retention_available.sql`](./12_utilities/community_scripts/storage/undo_retention_available.sql) | `community_scripts/storage` | BASSO | OK | undo_retention_available.sql |
| [`undo_stats.sql`](./12_utilities/community_scripts/storage/undo_stats.sql) | `community_scripts/storage` | BASSO | OK | undo_stats.sql |
| [`Install_pkg_Dba_Utility_20220713_v1_9_PROD.sql`](./12_utilities/Install_pkg_Dba_Utility_20220713_v1_9_PROD.sql) | `-` | ALTO | OK | Il JOB della PURGE_AM_TABLES NON viene creato in automatico dalo script |
| [`Job monitoring TEMP e UNDO TABLESPACE.sql`](./12_utilities/Job%20monitoring%20TEMP%20e%20UNDO%20TABLESPACE.sql) | `-` | ALTO | OK | Connettersi con utenza DBA_OP |
| [`mview_refresh_procedure.txt`](./12_utilities/mview_refresh_procedure.txt) | `-` | ALTO | OK | inserimento tabelle di configurazione |
| [`TEMP_and_UNDO_monitor.sql`](./12_utilities/TEMP_and_UNDO_monitor.sql) | `-` | ALTO | OK | Monitoraggio capacità tablespace/TEMP/UNDO e prevenzione saturazione. |

