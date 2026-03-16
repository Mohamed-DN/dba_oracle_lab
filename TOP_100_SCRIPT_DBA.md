# 🏆 Top 100 DBA Scripts — Most Used Every Day

> Curated selection of the **100 most useful scripts** among the 914 available in the project.
> Each link points directly to the verified script in the folder`studio_ai/`.
> 🔴 = Emergenza |📊 = Daily use| 🔧 = Tuning | 📎 = Utility

---

## 🔴 1-10: EMERGENZA — Lock, Blocchi, Kill

| # | Script | What He Does | Quando |
|---|---|---|---|
| 1 | [showlock2.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/showlock2.sql) | Lock with waiters and blockers (12c+) | Blocked users |
| 2 | [locks.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/locks.sql) | Active locks with complete detail | Blocked users |
| 3 | [locks_blocking.sql](./studio_ai/03_monitoring_scripts/locks_blocking.sql) |Who blocks whom (our version)| Blocked users |
| 4 | [snapper.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/snapper.sql) |Sampling real-time sessions (Tanel Poder)|Live diagnosis|
| 5 | [active_status.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/active_status.sql) |Active sessions on CPU now| CPU alta |
| 6 | [check_and_kill.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/check_and_kill.sql) |Generate session kill scripts| Kill sessione |
| 7 | [View_Blocking.sql](./studio_ai/03_monitoring_scripts/View_Blocking.sql) |Blocks in progress (our version)| Lock analysis |
| 8 | [Check_Lock.sql](./studio_ai/03_monitoring_scripts/Check_Lock.sql) | Check locks on objects | Lock on table |
| 9 | [concurrency-waits-sqlid.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/concurrency-waits-sqlid.sql) | Concurrency waits per SQL_ID |High contention|
| 10 | [itl_waits.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/itl_waits.sql) | ITL waits → you have to do ALTER TABLE INITRANS |"enq: TX - allocate ITL"|

---

## 📊 11-25: SESSIONI E MONITORING ATTIVO

| # | Script | What He Does | Quando |
|---|---|---|---|
| 11 | [ViewSession.sql](./studio_ai/03_monitoring_scripts/ViewSession.sql) |Active sessions (our version)| Everyday |
| 12 | [top-sql.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/top-sql.sql) |Top SQL for Resources (Simple)| Everyday |
| 13 | [top_queries.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/top_queries.sql) | Top active queries with details | Everyday |
| 14 | [View_Cpu_Consumer.sql](./studio_ai/03_monitoring_scripts/View_Cpu_Consumer.sql) | Chi sta consumando CPU | CPU alta |
| 15 | [View_Cpu_Hist.sql](./studio_ai/03_monitoring_scripts/View_Cpu_Hist.sql) | Storico consumo CPU |Trend analysis|
| 16 | [ASH2.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/ASH2.sql) | Full ASH report | Analisi sessioni |
| 17 | [ASH.sql](./studio_ai/03_monitoring_scripts/ASH.sql) | ASH queries (versione nostra) | Analisi sessioni |
| 18 | [AshTopSql.sql](./studio_ai/03_monitoring_scripts/AshTopSql.sql) |Top SQL from ASH (our version)| Top consumers |
| 19 | [AshTopSession.sql](./studio_ai/03_monitoring_scripts/AshTopSession.sql) |Top sessions from ASH| Top sessions |
| 20 | [sesswait.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/sesswait.sql) | Waits correnti per sessione |Waiting event|
| 21 | [who2.sql](./studio_ai/03_monitoring_scripts/community_jkstill/users_logged/who2.sql) | Who is connected with details | Everyday |
| 22 | [PGA_watch.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/PGA_watch.sql) |Real-time PGA monitoring| Memory alta |
| 23 | [PGA.sql](./studio_ai/03_monitoring_scripts/PGA.sql) |PGA analysis (our version)| Memory |
| 24 | [Processi.sql](./studio_ai/03_monitoring_scripts/Processi.sql) | Active processes with details | Everyday |
| 25 | [Event_statistics.sql](./studio_ai/03_monitoring_scripts/Event_statistics.sql) |Waiting event statistics|Diagnosis|

---

## 📈 26-45: AWR, ASH E ANALISI STORICA

| # | Script | What He Does | Quando |
|---|---|---|---|
| 26 | [aas.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/aas.sql) |Average Active Sessions — your heart rate| Everyday |
| 27 | [awr_defined.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr_defined.sql) |AWR Report **non-interactive**| Report automatico |
| 28 | [awr_RAC_defined.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr_RAC_defined.sql) |Non-interactive AWR report on **RAC**| Report RAC |
| 29 | [ash-top-events.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ash-top-events.sql) | Top 10 eventi in ASH |Diagnosis|
| 30 | [ashtop.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ashtop.sql) | Top ASH events (Tanel Poder) | Diagnosi rapida |
| 31 | [top10-sql-ash.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/top10-sql-ash.sql) | Top 10 SQL da ASH | Everyday |
| 32 | [top10-sql-awr.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/top10-sql-awr.sql) | Top 10 SQL from AWR (30 days) |Trend analysis|
| 33 | [awr-top-5-events.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-top-5-events.sql) | Top 5 events last 7 days | Weekly report |
| 34 | [awr-top-10-daily.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-top-10-daily.sql) | Top 10 events per day | Daily trend |
| 35 | [awr-cpu-stats.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-cpu-stats.sql) | CPU stats tipo `sar` da AWR | Capacity planning |
| 36 | [ash_blocking.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ash_blocking.sql) | Block history with SQL_ID |Contention analysis|
| 37 | [ash-blocker-waits.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ash-blocker-waits.sql) | Top blockers in ASH |Lock diagnosis|
| 38 | [ash-current-waits.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ash-current-waits.sql) | Waits correnti per SQL |Live diagnosis|
| 39 | [cpu-busy.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/cpu-busy.sql) | SQL Operations su CPU | CPU analysis |
| 40 | [get-binds.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/get-binds.sql) | Bind values da AWR | Debug SQL |
| 41 | [getsql-awr.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/getsql-awr.sql) | Testo SQL da AWR | Trova SQL |
| 42 | [awr-export.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-export.sql) | Export AWR (pre-migration!) |Pre-migration|
| 43 | [awr-get-retention.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-get-retention.sql) |Shows AWR retention and interval|Configuration|
| 44 | [awr-set-retention.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-set-retention.sql) |Set AWR retention|Configuration|
| 45 | [ash_cpu_hist.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ash_cpu_hist.sql) |CPU history from sysmetric (12c+)| Trend CPU |

---

## 🔧 46-65: SQL TUNING E PIANI DI ESECUZIONE

| # | Script | What He Does | Quando |
|---|---|---|---|
| 46 | [dbms-sqltune-sqlid.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/dbms-sqltune-sqlid.sql) | Crea tuning task per SQL_ID |Slow SQL|
| 47 | [find-expensive-sql.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/find-expensive-sql.sql) |Find expensive SQL (high LIO)| Top consumers |
| 48 | [profile_from_awr.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/profile_from_awr.sql) | Create SQL Profile from AWR plan | Come on good plan |
| 49 | [sql-exe-times-awr.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/sql-exe-times-awr.sql) |Execution times from AWR (30 days)|Trend analysis|
| 50 | [sql-exe-times-ash.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/sql-exe-times-ash.sql) |Execution times from ASH|Live diagnosis|
| 51 | [sql-exe-events-ash.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/sql-exe-events-ash.sql) |Events for SQL execution| Where he wastes time |
| 52 | [sql-exe-events-awr.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/sql-exe-events-awr.sql) |Events per execution (history)|Historical analysis|
| 53 | [explain_plan.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/explain_plan.sql) | Explain plan formattato | Everyday |
| 54 | [advisor_profile_recs.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/advisor_profile_recs.sql) |SQL Advisor recommendations|Slow SQL|
| 55 | [index_efficiency.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/index_efficiency.sql) | Efficienza indici (clustering factor) | Indice inutile? |
| 56 | [SPM.sql](./studio_ai/03_monitoring_scripts/SPM.sql) | SQL Plan Management baselines | Unstable floor |
| 57 | [SPM_from_AWR_old_fashioned.sql](./studio_ai/03_monitoring_scripts/SPM_from_AWR_old_fashioned.sql) | Create baseline from AWR | Come on slow old man |
| 58 | [SQL_Profile_Other_SqlID.sql](./studio_ai/03_monitoring_scripts/SQL_Profile_Other_SqlID.sql) | Apply a SQL_ID profile to another SQL_ID | Advanced trick |
| 59 | [View_UnstablePlan.sql](./studio_ai/03_monitoring_scripts/View_UnstablePlan.sql) | Plans unstable over time | Flip-flop plan |
| 60 | [PerfTuningAnalisys.sql](./studio_ai/03_monitoring_scripts/PerfTuningAnalisys.sql) | Complete performance analysis | Report tuning |
| 61 | [SQL Plan Change.sql](./studio_ai/03_monitoring_scripts/SQL%20Plan%20Change.sql) | Detect execution plan changes | Plan changed |
| 62 | [SQL Stats.sql](./studio_ai/03_monitoring_scripts/SQL%20Stats.sql) | Detailed SQL statistics | SQL analysis |
| 63 | [SQL Bind.sql](./studio_ai/03_monitoring_scripts/SQL%20Bind.sql) | Bind variable peeking | Bind sensitivity |
| 64 | [find_sql.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/find_sql.sql) | Trova SQL per SQL_ID | Cercare SQL |
| 65 | [my_sqlmon.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/my_sqlmon.sql) | SQL Monitor report |Real-time SQL|

---

## 💽 66-75: I/O, REDO E DISCO

| # | Script | What He Does | Quando |
|---|---|---|---|
| 66 | [lfsdiag.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/lfsdiag.sql) |Diagnosis **logfile sync**| Commit lenti! |
| 67 | [ioweight.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/ioweight.sql) | I/O per tablespace per peso | Hotspot I/O |
| 68 | [redo-rate.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/redo-rate.sql) |Redo rate in real time|Dimension online redo|
| 69 | [avg_disk_times.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/avg_disk_times.sql) | Tempi medi read/write | Storage lento |
| 70 | [View_IO_RealTime.sql](./studio_ai/03_monitoring_scripts/View_IO_RealTime.sql) |Real-time I/O (ours)| Everyday |
| 71 | [View_IO_Database.sql](./studio_ai/03_monitoring_scripts/View_IO_Database.sql) | I/O per database | Report |
| 72 | [View_IO_Hist.sql](./studio_ai/03_monitoring_scripts/View_IO_Hist.sql) |I/O history|Trend analysis|
| 73 | [IO_stat_nel_tempo.sql](./studio_ai/03_monitoring_scripts/IO_stat_nel_tempo.sql) |I/O statistics over time| Trend |
| 74 | [View_RedoGeneration.sql](./studio_ai/03_monitoring_scripts/View_RedoGeneration.sql) |Redo generation per instance| Sizing redo |
| 75 | [trans_per_hour.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/trans_per_hour.sql) |Transactions for now| Capacity |

---

## 📀 76-82: ASM

| # | Script | What He Does | Quando |
|---|---|---|---|
| 76 | [Asm_Diskgroups.sql](./studio_ai/03_monitoring_scripts/Asm_Diskgroups.sql) | Spazio disk group (nostro) | Space control |
| 77 | [asm_diskgroups.sql](./studio_ai/01_asm_storage/community_scripts/asm_diskgroups.sql) |Detailed diskgroups|ASM control|
| 78 | [asm_disks.sql](./studio_ai/01_asm_storage/community_scripts/asm_disks.sql) | ASM disks detail | Check disks |
| 79 | [asm_disk_errors.sql](./studio_ai/01_asm_storage/community_scripts/asm_disk_errors.sql) |ASM disk errors| Check proattivo! |
| 80 | [asm_disk_stats.sql](./studio_ai/01_asm_storage/community_scripts/asm_disk_stats.sql) | I/O per disco ASM | Performance ASM |
| 81 | [asm_failgroup_members.sql](./studio_ai/01_asm_storage/community_scripts/asm_failgroup_members.sql) | Membri per failgroup | Check redundancy |
| 82 | [asm_files_path.sql](./studio_ai/01_asm_storage/community_scripts/asm_files_path.sql) | ASM file with full path | Trova file |

---

## 🗄️ 83-92: TABLESPACE, UNDO E STORAGE

| # | Script | What He Does | Quando |
|---|---|---|---|
| 83 | [tablespace.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/tablespace.sql) | Tablespace state (simple) |Space alert|
| 84 | [showtbs.sql](./studio_ai/12_utilities/community_scripts/storage/showtbs.sql) | All tablespaces | Full report |
| 85 | [showdf.sql](./studio_ai/12_utilities/community_scripts/storage/showdf.sql) |All datafiles| Check files |
| 86 | [showfree.sql](./studio_ai/12_utilities/community_scripts/storage/showfree.sql) |Free space for tablespace| Space control |
| 87 | [dfshrink-gen.sql](./studio_ai/12_utilities/community_scripts/storage/dfshrink-gen.sql) | Genera shrink datafile |Reclaim space|
| 88 | [double_tablespace.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/double_tablespace.sql) | Script per raddoppiare tablespace |Space emergency|
| 89 | [undo_stats.sql](./studio_ai/12_utilities/community_scripts/storage/undo_stats.sql) |UNDO statistics (detects ORA-1555)| ORA-1555 |
| 90 | [undo_space.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/undo_space.sql) |UNDO space analysis| UNDO pieno |
| 91 | [TEMP_and_UNDO_monitor.sql](./studio_ai/12_utilities/TEMP_and_UNDO_monitor.sql) | Monitor TEMP e UNDO (nostro) | TEMP pieno |
| 92 | [showspace.sql](./studio_ai/12_utilities/community_scripts/storage/showspace.sql) | Object space with DBMS_SPACE |Segment analysis|

---

## � 93-97: STATISTICHE E OPTIMIZER

| # | Script | What He Does | Quando |
|---|---|---|---|
| 93 | [stale-stats.sql](./studio_ai/07_performance_tuning/community_scripts/stats_optimizer/stale-stats.sql) | Tables with outdated statistics | Statistiche vecchie |
| 94 | [stats_prefs.sql](./studio_ai/07_performance_tuning/community_scripts/stats_optimizer/stats_prefs.sql) | Preferenze DBMS_STATS |Configuration|
| 95 | [Stats_workflow.sql](./studio_ai/03_monitoring_scripts/Stats_workflow.sql) | Stats management workflow (ours) | Stats procedure |
| 96 | [col_high_low_val.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/col_high_low_val.sql) | Valori high/low colonne | Skew detection |
| 97 | [locked_stats.sql](./studio_ai/07_performance_tuning/community_scripts/stats_optimizer/locked_stats.sql) | Statistiche bloccate |Stats not updated|

---

## 🔒 98-100: BACKUP, DATA GUARD E SECURITY

| # | Script | What He Does | Quando |
|---|---|---|---|
| 98 | [BACKUP CHECKS.sql](./studio_ai/03_monitoring_scripts/BACKUP%20CHECKS.sql) | Check RMAN backup status |Every morning|
| 99 | [MONITOR__RMAN_BACKUP.sql](./studio_ai/03_monitoring_scripts/MONITOR__RMAN_BACKUP.sql) |RMAN monitoring in progress| Backup running |
| 100 | [rman-bkup-status.sql](./studio_ai/06_backup_recovery/community_scripts/rman-bkup-status.sql) | RMAN backup status (community) | Check backup |

---

## ⚡ How to Use

```bash
# Connect and run any script:
sqlplus / as sysdba
@studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/showlock2.sql

# Per ASM:
sqlplus / as sysasm
@studio_ai/01_asm_storage/community_scripts/asm_diskgroups.sql
```

> [!TIP]
> **The 5 scripts a DBA should run EVERY MORNING:**
> 1. `aas.sql`— is the database working too hard?
> 2. `tablespace.sql` — is there room?
> 3. `asm_disk_errors.sql`— disk errors?
> 4. `BACKUP CHECKS.sql` — backup OK stanotte?
> 5. `showlock2.sql` — anyone blocked?

---

*📚 All 554 scripts are in [studio_ai/](./studio_ai/) — [RAC Lab Activity](./GUIDE_RAC_LAB_ACTIVITIES.md)*
