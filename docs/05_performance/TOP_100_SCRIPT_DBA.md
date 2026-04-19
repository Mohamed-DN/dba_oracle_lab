# 🏆 Top 100 Script DBA — I Più Usati Ogni Giorno

> Selezione curata dei **100 script più utili** tra i 914 disponibili nel progetto.
> Ogni link punta direttamente allo script verificato nella cartella `studio_ai/`.
> 🔴 = Emergenza | 📊 = Uso quotidiano | 🔧 = Tuning | 📎 = Utility

---

## 🔴 1-10: EMERGENZA — Lock, Blocchi, Kill

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 1 | [showlock2.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/showlock2.sql) | Lock con waiters e blockers (12c+) | Utenti bloccati |
| 2 | [locks.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/locks.sql) | Lock attivi con dettaglio completo | Utenti bloccati |
| 3 | [locks_blocking.sql](./studio_ai/03_monitoring_scripts/locks_blocking.sql) | Chi blocca chi (versione nostra) | Utenti bloccati |
| 4 | [snapper.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/snapper.sql) | Sampling real-time sessioni (Tanel Poder) | Diagnosi live |
| 5 | [active_status.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/active_status.sql) | Sessioni attive su CPU adesso | CPU alta |
| 6 | [check_and_kill.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/check_and_kill.sql) | Genera script per kill sessioni | Kill sessione |
| 7 | [View_Blocking.sql](./studio_ai/03_monitoring_scripts/View_Blocking.sql) | Blocchi in corso (versione nostra) | Lock analysis |
| 8 | [Check_Lock.sql](./studio_ai/03_monitoring_scripts/Check_Lock.sql) | Verifica lock su oggetti | Lock su tabella |
| 9 | [concurrency-waits-sqlid.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/concurrency-waits-sqlid.sql) | Concurrency waits per SQL_ID | Contesa alta |
| 10 | [itl_waits.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/itl_waits.sql) | ITL waits → devi fare ALTER TABLE INITRANS | "enq: TX - allocate ITL" |

---

## 📊 11-25: SESSIONI E MONITORING ATTIVO

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 11 | [ViewSession.sql](./studio_ai/03_monitoring_scripts/ViewSession.sql) | Sessioni attive (versione nostra) | Ogni giorno |
| 12 | [top-sql.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/top-sql.sql) | Top SQL per risorse (semplice) | Ogni giorno |
| 13 | [top_queries.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/top_queries.sql) | Top query attive con dettagli | Ogni giorno |
| 14 | [View_Cpu_Consumer.sql](./studio_ai/03_monitoring_scripts/View_Cpu_Consumer.sql) | Chi sta consumando CPU | CPU alta |
| 15 | [View_Cpu_Hist.sql](./studio_ai/03_monitoring_scripts/View_Cpu_Hist.sql) | Storico consumo CPU | Analisi trend |
| 16 | [ASH2.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/ASH2.sql) | Report ASH completo | Analisi sessioni |
| 17 | [ASH.sql](./studio_ai/03_monitoring_scripts/ASH.sql) | ASH queries (versione nostra) | Analisi sessioni |
| 18 | [AshTopSql.sql](./studio_ai/03_monitoring_scripts/AshTopSql.sql) | Top SQL da ASH (versione nostra) | Top consumers |
| 19 | [AshTopSession.sql](./studio_ai/03_monitoring_scripts/AshTopSession.sql) | Top sessioni da ASH | Top sessions |
| 20 | [sesswait.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/sesswait.sql) | Waits correnti per sessione | Evento di attesa |
| 21 | [who2.sql](./studio_ai/03_monitoring_scripts/community_jkstill/users_logged/who2.sql) | Chi è connesso con dettagli | Ogni giorno |
| 22 | [PGA_watch.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/PGA_watch.sql) | Monitoraggio PGA real-time | Memory alta |
| 23 | [PGA.sql](./studio_ai/03_monitoring_scripts/PGA.sql) | Analisi PGA (versione nostra) | Memory |
| 24 | [Processi.sql](./studio_ai/03_monitoring_scripts/Processi.sql) | Processi attivi con dettagli | Ogni giorno |
| 25 | [Event_statistics.sql](./studio_ai/03_monitoring_scripts/Event_statistics.sql) | Statistiche eventi di attesa | Diagnosi |

---

## 📈 26-45: AWR, ASH E ANALISI STORICA

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 26 | [aas.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/aas.sql) | Average Active Sessions — il battito cardiaco | Ogni giorno |
| 27 | [awr_defined.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr_defined.sql) | Report AWR **non-interattivo** | Report automatico |
| 28 | [awr_RAC_defined.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr_RAC_defined.sql) | Report AWR non-interattivo su **RAC** | Report RAC |
| 29 | [ash-top-events.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ash-top-events.sql) | Top 10 eventi in ASH | Diagnosi |
| 30 | [ashtop.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ashtop.sql) | Top ASH events (Tanel Poder) | Diagnosi rapida |
| 31 | [top10-sql-ash.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/top10-sql-ash.sql) | Top 10 SQL da ASH | Ogni giorno |
| 32 | [top10-sql-awr.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/top10-sql-awr.sql) | Top 10 SQL da AWR (30 giorni) | Analisi trend |
| 33 | [awr-top-5-events.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-top-5-events.sql) | Top 5 eventi ultimi 7 giorni | Report settimanale |
| 34 | [awr-top-10-daily.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-top-10-daily.sql) | Top 10 eventi per giorno | Trend giornaliero |
| 35 | [awr-cpu-stats.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-cpu-stats.sql) | CPU stats tipo `sar` da AWR | Capacity planning |
| 36 | [ash_blocking.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ash_blocking.sql) | Storico blocchi con SQL_ID | Analisi contesa |
| 37 | [ash-blocker-waits.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ash-blocker-waits.sql) | Top blockers in ASH | Diagnosi lock |
| 38 | [ash-current-waits.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ash-current-waits.sql) | Waits correnti per SQL | Diagnosi live |
| 39 | [cpu-busy.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/cpu-busy.sql) | SQL Operations su CPU | CPU analysis |
| 40 | [get-binds.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/get-binds.sql) | Bind values da AWR | Debug SQL |
| 41 | [getsql-awr.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/getsql-awr.sql) | Testo SQL da AWR | Trova SQL |
| 42 | [awr-export.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-export.sql) | Esporta AWR (pre-migrazione!) | Pre-migrazione |
| 43 | [awr-get-retention.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-get-retention.sql) | Mostra AWR retention e interval | Configurazione |
| 44 | [awr-set-retention.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-set-retention.sql) | Imposta AWR retention | Configurazione |
| 45 | [ash_cpu_hist.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ash_cpu_hist.sql) | Storico CPU da sysmetric (12c+) | Trend CPU |

---

## 🔧 46-65: SQL TUNING E PIANI DI ESECUZIONE

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 46 | [dbms-sqltune-sqlid.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/dbms-sqltune-sqlid.sql) | Crea tuning task per SQL_ID | SQL lento |
| 47 | [find-expensive-sql.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/find-expensive-sql.sql) | Trova SQL costosi (alto LIO) | Top consumers |
| 48 | [profile_from_awr.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/profile_from_awr.sql) | Crea SQL Profile da piano AWR | Forza piano buono |
| 49 | [sql-exe-times-awr.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/sql-exe-times-awr.sql) | Tempi esecuzione da AWR (30gg) | Analisi trend |
| 50 | [sql-exe-times-ash.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/sql-exe-times-ash.sql) | Tempi esecuzione da ASH | Diagnosi live |
| 51 | [sql-exe-events-ash.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/sql-exe-events-ash.sql) | Eventi per esecuzione SQL | Dove perde tempo |
| 52 | [sql-exe-events-awr.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/sql-exe-events-awr.sql) | Eventi per esecuzione (storico) | Analisi storica |
| 53 | [explain_plan.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/explain_plan.sql) | Explain plan formattato | Ogni giorno |
| 54 | [advisor_profile_recs.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/advisor_profile_recs.sql) | Raccomandazioni SQL Advisor | SQL lento |
| 55 | [index_efficiency.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/index_efficiency.sql) | Efficienza indici (clustering factor) | Indice inutile? |
| 56 | [SPM.sql](./studio_ai/03_monitoring_scripts/SPM.sql) | SQL Plan Management baselines | Piano instabile |
| 57 | [SPM_from_AWR_old_fashioned.sql](./studio_ai/03_monitoring_scripts/SPM_from_AWR_old_fashioned.sql) | Crea baseline da AWR | Forza piano vecchio |
| 58 | [SQL_Profile_Other_SqlID.sql](./studio_ai/03_monitoring_scripts/SQL_Profile_Other_SqlID.sql) | Applica profilo di un SQL_ID ad un altro | Trick avanzato |
| 59 | [View_UnstablePlan.sql](./studio_ai/03_monitoring_scripts/View_UnstablePlan.sql) | Piani instabili nel tempo | Piano flip-flop |
| 60 | [PerfTuningAnalisys.sql](./studio_ai/03_monitoring_scripts/PerfTuningAnalisys.sql) | Analisi performance completa | Report tuning |
| 61 | [SQL Plan Change.sql](./studio_ai/03_monitoring_scripts/SQL%20Plan%20Change.sql) | Detect cambio piano esecuzione | Piano cambiato |
| 62 | [SQL Stats.sql](./studio_ai/03_monitoring_scripts/SQL%20Stats.sql) | Statistiche SQL dettagliate | SQL analysis |
| 63 | [SQL Bind.sql](./studio_ai/03_monitoring_scripts/SQL%20Bind.sql) | Bind variable peeking | Bind sensitivity |
| 64 | [find_sql.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/find_sql.sql) | Trova SQL per SQL_ID | Cercare SQL |
| 65 | [my_sqlmon.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/my_sqlmon.sql) | SQL Monitor report | Real-time SQL |

---

## 💽 66-75: I/O, REDO E DISCO

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 66 | [lfsdiag.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/lfsdiag.sql) | Diagnosi **logfile sync** | Commit lenti! |
| 67 | [ioweight.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/ioweight.sql) | I/O per tablespace per peso | Hotspot I/O |
| 68 | [redo-rate.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/redo-rate.sql) | Redo rate in tempo reale | Dimensiona online redo |
| 69 | [avg_disk_times.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/avg_disk_times.sql) | Tempi medi read/write | Storage lento |
| 70 | [View_IO_RealTime.sql](./studio_ai/03_monitoring_scripts/View_IO_RealTime.sql) | I/O in tempo reale (nostro) | Ogni giorno |
| 71 | [View_IO_Database.sql](./studio_ai/03_monitoring_scripts/View_IO_Database.sql) | I/O per database | Report |
| 72 | [View_IO_Hist.sql](./studio_ai/03_monitoring_scripts/View_IO_Hist.sql) | Storico I/O | Analisi trend |
| 73 | [IO_stat_nel_tempo.sql](./studio_ai/03_monitoring_scripts/IO_stat_nel_tempo.sql) | Statistiche I/O nel tempo | Trend |
| 74 | [View_RedoGeneration.sql](./studio_ai/03_monitoring_scripts/View_RedoGeneration.sql) | Redo generation per istanza | Sizing redo |
| 75 | [trans_per_hour.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/trans_per_hour.sql) | Transazioni per ora | Capacity |

---

## 📀 76-82: ASM

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 76 | [Asm_Diskgroups.sql](./studio_ai/03_monitoring_scripts/Asm_Diskgroups.sql) | Spazio disk group (nostro) | Controllo spazio |
| 77 | [asm_diskgroups.sql](./studio_ai/01_asm_storage/community_scripts/asm_diskgroups.sql) | Diskgroups dettagliato | Controllo ASM |
| 78 | [asm_disks.sql](./studio_ai/01_asm_storage/community_scripts/asm_disks.sql) | Dettaglio dischi ASM | Verifica dischi |
| 79 | [asm_disk_errors.sql](./studio_ai/01_asm_storage/community_scripts/asm_disk_errors.sql) | Errori disco ASM | Check proattivo! |
| 80 | [asm_disk_stats.sql](./studio_ai/01_asm_storage/community_scripts/asm_disk_stats.sql) | I/O per disco ASM | Performance ASM |
| 81 | [asm_failgroup_members.sql](./studio_ai/01_asm_storage/community_scripts/asm_failgroup_members.sql) | Membri per failgroup | Verifica ridondanza |
| 82 | [asm_files_path.sql](./studio_ai/01_asm_storage/community_scripts/asm_files_path.sql) | File ASM con path completo | Trova file |

---

## 🗄️ 83-92: TABLESPACE, UNDO E STORAGE

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 83 | [tablespace.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/tablespace.sql) | Stato tablespace (semplice) | Alert spazio |
| 84 | [showtbs.sql](./studio_ai/12_utilities/community_scripts/storage/showtbs.sql) | Tutti i tablespace | Report completo |
| 85 | [showdf.sql](./studio_ai/12_utilities/community_scripts/storage/showdf.sql) | Tutti i datafile | Verifica file |
| 86 | [showfree.sql](./studio_ai/12_utilities/community_scripts/storage/showfree.sql) | Spazio libero per tablespace | Controllo spazio |
| 87 | [dfshrink-gen.sql](./studio_ai/12_utilities/community_scripts/storage/dfshrink-gen.sql) | Genera shrink datafile | Recupera spazio |
| 88 | [double_tablespace.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/double_tablespace.sql) | Script per raddoppiare tablespace | Emergenza spazio |
| 89 | [undo_stats.sql](./studio_ai/12_utilities/community_scripts/storage/undo_stats.sql) | Statistiche UNDO (rileva ORA-1555) | ORA-1555 |
| 90 | [undo_space.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/undo_space.sql) | Analisi spazio UNDO | UNDO pieno |
| 91 | [TEMP_and_UNDO_monitor.sql](./studio_ai/12_utilities/TEMP_and_UNDO_monitor.sql) | Monitor TEMP e UNDO (nostro) | TEMP pieno |
| 92 | [showspace.sql](./studio_ai/12_utilities/community_scripts/storage/showspace.sql) | Spazio oggetto con DBMS_SPACE | Analisi segmenti |

---

## � 93-97: STATISTICHE E OPTIMIZER

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 93 | [stale-stats.sql](./studio_ai/07_performance_tuning/community_scripts/stats_optimizer/stale-stats.sql) | Tabelle con statistiche obsolete | Statistiche vecchie |
| 94 | [stats_prefs.sql](./studio_ai/07_performance_tuning/community_scripts/stats_optimizer/stats_prefs.sql) | Preferenze DBMS_STATS | Configurazione |
| 95 | [Stats_workflow.sql](./studio_ai/03_monitoring_scripts/Stats_workflow.sql) | Workflow gestione stats (nostro) | Procedura stats |
| 96 | [col_high_low_val.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/col_high_low_val.sql) | Valori high/low colonne | Skew detection |
| 97 | [locked_stats.sql](./studio_ai/07_performance_tuning/community_scripts/stats_optimizer/locked_stats.sql) | Statistiche bloccate | Stats non aggiornate |

---

## 🔒 98-100: BACKUP, DATA GUARD E SECURITY

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 98 | [BACKUP CHECKS.sql](./studio_ai/03_monitoring_scripts/BACKUP%20CHECKS.sql) | Verifica stato backup RMAN | Ogni mattina |
| 99 | [MONITOR__RMAN_BACKUP.sql](./studio_ai/03_monitoring_scripts/MONITOR__RMAN_BACKUP.sql) | Monitoraggio RMAN in corso | Backup running |
| 100 | [rman-bkup-status.sql](./studio_ai/06_backup_recovery/community_scripts/rman-bkup-status.sql) | Stato backup RMAN (community) | Verifica backup |

---

## ⚡ Come Usare

```bash
# Connettiti e lancia qualsiasi script:
sqlplus / as sysdba
@studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/showlock2.sql

# Per ASM:
sqlplus / as sysasm
@studio_ai/01_asm_storage/community_scripts/asm_diskgroups.sql
```

> [!TIP]
> **I 5 script che un DBA dovrebbe lanciare OGNI MATTINA:**
> 1. `aas.sql` — il database sta lavorando troppo?
> 2. `tablespace.sql` — c'è spazio?
> 3. `asm_disk_errors.sql` — errori disco?
> 4. `BACKUP CHECKS.sql` — backup OK stanotte?
> 5. `showlock2.sql` — qualcuno è bloccato?

---

*📚 Tutti i 554 script sono in [studio_ai/](./studio_ai/) — [Attività Lab RAC](./GUIDA_ATTIVITA_LAB_RAC.md)*
