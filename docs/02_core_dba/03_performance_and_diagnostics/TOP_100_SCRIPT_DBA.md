# ?? Top 100 Script DBA � I Pi� Usati Ogni Giorno

> Selezione curata dei **100 script pi� utili** tra i 914 disponibili nel progetto.
> Ogni link punta direttamente allo script verificato nella cartella `01_operations/04_libreria_script_completa/`.
> ?? = Emergenza | ?? = Uso quotidiano | ?? = Tuning | ?? = Utility

---

## ?? 1-10: EMERGENZA � Lock, Blocchi, Kill

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 1 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/sessions_locks/showlock2.sql) | Lock con waiters e blockers (12c+) | Utenti bloccati |
| 2 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/locks.sql) | Lock attivi con dettaglio completo | Utenti bloccati |
| 3 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/locks_blocking.sql) | Chi blocca chi (versione nostra) | Utenti bloccati |
| 4 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/sessions_locks/snapper.sql) | Sampling real-time sessioni (Tanel Poder) | Diagnosi live |
| 5 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/sessions_locks/active_status.sql) | Sessioni attive su CPU adesso | CPU alta |
| 6 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/check_and_kill.sql) | Genera script per kill sessioni | Kill sessione |
| 7 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/View_Blocking.sql) | Blocchi in corso (versione nostra) | Lock analysis |
| 8 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/Check_Lock.sql) | Verifica lock su oggetti | Lock su tabella |
| 9 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/sessions_locks/concurrency-waits-sqlid.sql) | Concurrency waits per SQL_ID | Contesa alta |
| 10 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/sessions_locks/itl_waits.sql) | ITL waits ? devi fare ALTER TABLE INITRANS | "enq: TX - allocate ITL" |

---

## ?? 11-25: SESSIONI E MONITORING ATTIVO

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 11 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/ViewSession.sql) | Sessioni attive (versione nostra) | Ogni giorno |
| 12 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/top-sql.sql) | Top SQL per risorse (semplice) | Ogni giorno |
| 13 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/top_queries.sql) | Top query attive con dettagli | Ogni giorno |
| 14 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/View_Cpu_Consumer.sql) | Chi sta consumando CPU | CPU alta |
| 15 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/View_Cpu_Hist.sql) | Storico consumo CPU | Analisi trend |
| 16 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/ASH2.sql) | Report ASH completo | Analisi sessioni |
| 17 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/ASH.sql) | ASH queries (versione nostra) | Analisi sessioni |
| 18 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/AshTopSql.sql) | Top SQL da ASH (versione nostra) | Top consumers |
| 19 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/AshTopSession.sql) | Top sessioni da ASH | Top sessions |
| 20 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/sessions_locks/sesswait.sql) | Waits correnti per sessione | Evento di attesa |
| 21 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/users_logged/who2.sql) | Chi � connesso con dettagli | Ogni giorno |
| 22 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/PGA_watch.sql) | Monitoraggio PGA real-time | Memory alta |
| 23 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/PGA.sql) | Analisi PGA (versione nostra) | Memory |
| 24 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/Processi.sql) | Processi attivi con dettagli | Ogni giorno |
| 25 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/Event_statistics.sql) | Statistiche eventi di attesa | Diagnosi |

---

## ?? 26-45: AWR, ASH E ANALISI STORICA

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 26 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/aas.sql) | Average Active Sessions � il battito cardiaco | Ogni giorno |
| 27 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr_defined.sql) | Report AWR **non-interattivo** | Report automatico |
| 28 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr_RAC_defined.sql) | Report AWR non-interattivo su **RAC** | Report RAC |
| 29 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/ash-top-events.sql) | Top 10 eventi in ASH | Diagnosi |
| 30 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/ashtop.sql) | Top ASH events (Tanel Poder) | Diagnosi rapida |
| 31 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/top10-sql-ash.sql) | Top 10 SQL da ASH | Ogni giorno |
| 32 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/top10-sql-awr.sql) | Top 10 SQL da AWR (30 giorni) | Analisi trend |
| 33 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr-top-5-events.sql) | Top 5 eventi ultimi 7 giorni | Report settimanale |
| 34 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr-top-10-daily.sql) | Top 10 eventi per giorno | Trend giornaliero |
| 35 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr-cpu-stats.sql) | CPU stats tipo `sar` da AWR | Capacity planning |
| 36 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/ash_blocking.sql) | Storico blocchi con SQL_ID | Analisi contesa |
| 37 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/ash-blocker-waits.sql) | Top blockers in ASH | Diagnosi lock |
| 38 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/ash-current-waits.sql) | Waits correnti per SQL | Diagnosi live |
| 39 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/cpu-busy.sql) | SQL Operations su CPU | CPU analysis |
| 40 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/get-binds.sql) | Bind values da AWR | Debug SQL |
| 41 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/getsql-awr.sql) | Testo SQL da AWR | Trova SQL |
| 42 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr-export.sql) | Esporta AWR (pre-migrazione!) | Pre-migrazione |
| 43 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr-get-retention.sql) | Mostra AWR retention e interval | Configurazione |
| 44 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr-set-retention.sql) | Imposta AWR retention | Configurazione |
| 45 | (../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/ash_cpu_hist.sql) | Storico CPU da sysmetric (12c+) | Trend CPU |

---

## ?? 46-65: SQL TUNING E PIANI DI ESECUZIONE

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 46 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/dbms-sqltune-sqlid.sql) | Crea tuning task per SQL_ID | SQL lento |
| 47 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/find-expensive-sql.sql) | Trova SQL costosi (alto LIO) | Top consumers |
| 48 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/profile_from_awr.sql) | Crea SQL Profile da piano AWR | Forza piano buono |
| 49 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/sql-exe-times-awr.sql) | Tempi esecuzione da AWR (30gg) | Analisi trend |
| 50 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/sql-exe-times-ash.sql) | Tempi esecuzione da ASH | Diagnosi live |
| 51 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/sql-exe-events-ash.sql) | Eventi per esecuzione SQL | Dove perde tempo |
| 52 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/sql-exe-events-awr.sql) | Eventi per esecuzione (storico) | Analisi storica |
| 53 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/explain_plan.sql) | Explain plan formattato | Ogni giorno |
| 54 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/advisor_profile_recs.sql) | Raccomandazioni SQL Advisor | SQL lento |
| 55 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/index_efficiency.sql) | Efficienza indici (clustering factor) | Indice inutile? |
| 56 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/SPM.sql) | SQL Plan Management baselines | Piano instabile |
| 57 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/SPM_from_AWR_old_fashioned.sql) | Crea baseline da AWR | Forza piano vecchio |
| 58 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/SQL_Profile_Other_SqlID.sql) | Applica profilo di un SQL_ID ad un altro | Trick avanzato |
| 59 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/View_UnstablePlan.sql) | Piani instabili nel tempo | Piano flip-flop |
| 60 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/PerfTuningAnalisys.sql) | Analisi performance completa | Report tuning |
| 61 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/SQL%20Plan%20Change.sql) | Detect cambio piano esecuzione | Piano cambiato |
| 62 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/SQL%20Stats.sql) | Statistiche SQL dettagliate | SQL analysis |
| 63 | (../../01_operations/04_libreria_script_completa/performance_tuning/tuning/SQL%20Bind.sql) | Bind variable peeking | Bind sensitivity |
| 64 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/find_sql.sql) | Trova SQL per SQL_ID | Cercare SQL |
| 65 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/my_sqlmon.sql) | SQL Monitor report | Real-time SQL |

---

## ?? 66-75: I/O, REDO E DISCO

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 66 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/io_redo/lfsdiag.sql) | Diagnosi **logfile sync** | Commit lenti! |
| 67 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/io_redo/ioweight.sql) | I/O per tablespace per peso | Hotspot I/O |
| 68 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/io_redo/redo-rate.sql) | Redo rate in tempo reale | Dimensiona online redo |
| 69 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/io_redo/avg_disk_times.sql) | Tempi medi read/write | Storage lento |
| 70 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/View_IO_RealTime.sql) | I/O in tempo reale (nostro) | Ogni giorno |
| 71 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/View_IO_Database.sql) | I/O per database | Report |
| 72 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/View_IO_Hist.sql) | Storico I/O | Analisi trend |
| 73 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/IO_stat_nel_tempo.sql) | Statistiche I/O nel tempo | Trend |
| 74 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/View_RedoGeneration.sql) | Redo generation per istanza | Sizing redo |
| 75 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/io_redo/trans_per_hour.sql) | Transazioni per ora | Capacity |

---

## ?? 76-82: ASM

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 76 | (../../01_operations/04_libreria_script_completa/asm_storage/asm_diskgroups.sql) | Spazio disk group (nostro) | Controllo spazio |
| 77 | (../../01_operations/04_libreria_script_completa/asm_storage/asm_diskgroups.sql) | Diskgroups dettagliato | Controllo ASM |
| 78 | (../../01_operations/04_libreria_script_completa/asm_storage/asm_disks.sql) | Dettaglio dischi ASM | Verifica dischi |
| 79 | (../../01_operations/04_libreria_script_completa/asm_storage/asm_disk_errors.sql) | Errori disco ASM | Check proattivo! |
| 80 | (../../01_operations/04_libreria_script_completa/asm_storage/asm_disk_stats.sql) | I/O per disco ASM | Performance ASM |
| 81 | (../../01_operations/04_libreria_script_completa/asm_storage/asm_failgroup_members.sql) | Membri per failgroup | Verifica ridondanza |
| 82 | (../../01_operations/04_libreria_script_completa/asm_storage/asm_files_path.sql) | File ASM con path completo | Trova file |

---

## ??? 83-92: TABLESPACE, UNDO E STORAGE

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 83 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/tablespace.sql) | Stato tablespace (semplice) | Alert spazio |
| 84 | (../../01_operations/04_libreria_script_completa/utilities/storage/showtbs.sql) | Tutti i tablespace | Report completo |
| 85 | (../../01_operations/04_libreria_script_completa/utilities/storage/showdf.sql) | Tutti i datafile | Verifica file |
| 86 | (../../01_operations/04_libreria_script_completa/utilities/storage/showfree.sql) | Spazio libero per tablespace | Controllo spazio |
| 87 | (../../01_operations/04_libreria_script_completa/utilities/storage/dfshrink-gen.sql) | Genera shrink datafile | Recupera spazio |
| 88 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/double_tablespace.sql) | Script per raddoppiare tablespace | Emergenza spazio |
| 89 | (../../01_operations/04_libreria_script_completa/performance_tuning/stats_optimizer/undo_stats.sql) | Statistiche UNDO (rileva ORA-1555) | ORA-1555 |
| 90 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/undo_space.sql) | Analisi spazio UNDO | UNDO pieno |
| 91 | (../../01_operations/04_libreria_script_completa/utilities/TEMP_and_UNDO_monitor.sql) | Monitor TEMP e UNDO (nostro) | TEMP pieno |
| 92 | (../../01_operations/04_libreria_script_completa/utilities/storage/showspace.sql) | Spazio oggetto con DBMS_SPACE | Analisi segmenti |

---

## ? 93-97: STATISTICHE E OPTIMIZER

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 93 | (../../01_operations/04_libreria_script_completa/performance_tuning/stats_optimizer/stale-stats.sql) | Tabelle con statistiche obsolete | Statistiche vecchie |
| 94 | (../../01_operations/04_libreria_script_completa/performance_tuning/stats_optimizer/stats_prefs.sql) | Preferenze DBMS_STATS | Configurazione |
| 95 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/Stats_workflow.sql) | Workflow gestione stats (nostro) | Procedura stats |
| 96 | (../../01_operations/04_libreria_script_completa/monitoring_scripts/col_high_low_val.sql) | Valori high/low colonne | Skew detection |
| 97 | (../../01_operations/04_libreria_script_completa/performance_tuning/stats_optimizer/locked_stats.sql) | Statistiche bloccate | Stats non aggiornate |

---

## ?? 98-100: BACKUP, DATA GUARD E SECURITY

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 98 | (../../01_operations/04_libreria_script_completa/backup_recovery/BACKUP%20CHECKS.sql) | Verifica stato backup RMAN | Ogni mattina |
| 99 | (../../01_operations/04_libreria_script_completa/backup_recovery/MONITOR__RMAN_BACKUP.sql) | Monitoraggio RMAN in corso | Backup running |
| 100 | (../../01_operations/04_libreria_script_completa/backup_recovery/rman-bkup-status.sql) | Stato backup RMAN (community) | Verifica backup |

---

## ? Come Usare

```bash
# Connettiti e lancia qualsiasi script:
sqlplus / as sysdba
@../../01_operations/04_libreria_script_completa/03_monitoring_scripts/community_jkstill/sessions_locks/showlock2.sql

# Per ASM:
sqlplus / as sysasm
@../../01_operations/04_libreria_script_completa/01_asm_storage/community_scripts/asm_diskgroups.sql
```

> [!TIP]
> **I 5 script che un DBA dovrebbe lanciare OGNI MATTINA:**
> 1. `aas.sql` � il database sta lavorando troppo?
> 2. `tablespace.sql` � c'� spazio?
> 3. `asm_disk_errors.sql` � errori disco?
> 4. `BACKUP CHECKS.sql` � backup OK stanotte?
> 5. `showlock2.sql` � qualcuno � bloccato?

---

*?? Tutti i 554 script sono in [01_operations/04_libreria_script_completa/](../../01_operations/04_libreria_script_completa/) � [Attivit� Lab RAC](../../04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md)*
