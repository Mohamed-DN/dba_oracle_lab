# Top 100 Script DBA - I Piu' Usati Ogni Giorno

## Obiettivo operativo

Scegliere rapidamente lo script diagnostico corretto senza eseguire modifiche durante il triage.

## Procedura operativa

Parti dal sintomo, apri lo script indicato, leggi header e prerequisiti, poi eseguilo con un utente
di sola lettura quando possibile.

## Validazione finale

Registra query, timestamp, database e output utile nel ticket.

## Troubleshooting rapido

Se uno script fallisce, verifica container, privilegi e versione Oracle prima di adattarlo.

> Selezione curata dei **100 script piu' utili** tra i 914 disponibili nel progetto.
> Ogni link punta direttamente allo script verificato nella cartella `01_operations/04_libreria_script_completa/`.
> Legenda: emergenza | uso quotidiano | tuning | utility

---

## 1-10: EMERGENZA - Lock, Blocchi, Kill

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 1 | [showlock2.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/sessions_locks/showlock2.sql) | Lock con waiters e blockers (12c+) | Utenti bloccati |
| 2 | [locks.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/locks.sql) | Lock attivi con dettaglio completo | Utenti bloccati |
| 3 | [locks_blocking.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/locks_blocking.sql) | Chi blocca chi (versione nostra) | Utenti bloccati |
| 4 | [snapper.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/sessions_locks/snapper.sql) | Sampling real-time sessioni (Tanel Poder) | Diagnosi live |
| 5 | [active_status.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/sessions_locks/active_status.sql) | Sessioni attive su CPU adesso | CPU alta |
| 6 | [check_and_kill.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/check_and_kill.sql) | Genera script per kill sessioni | Kill sessione |
| 7 | [View_Blocking.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/View_Blocking.sql) | Blocchi in corso (versione nostra) | Lock analysis |
| 8 | [Check_Lock.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/Check_Lock.sql) | Verifica lock su oggetti | Lock su tabella |
| 9 | [concurrency-waits-sqlid.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/sessions_locks/concurrency-waits-sqlid.sql) | Concurrency waits per SQL_ID | Contesa alta |
| 10 | [itl_waits.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/sessions_locks/itl_waits.sql) | ITL waits ? devi fare ALTER TABLE INITRANS | "enq: TX - allocate ITL" |

---

## 11-25: SESSIONI E MONITORING ATTIVO

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 11 | [ViewSession.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/ViewSession.sql) | Sessioni attive (versione nostra) | Ogni giorno |
| 12 | [top-sql.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/top-sql.sql) | Top SQL per risorse (semplice) | Ogni giorno |
| 13 | [top_queries.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/top_queries.sql) | Top query attive con dettagli | Ogni giorno |
| 14 | [View_Cpu_Consumer.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/View_Cpu_Consumer.sql) | Chi sta consumando CPU | CPU alta |
| 15 | [View_Cpu_Hist.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/View_Cpu_Hist.sql) | Storico consumo CPU | Analisi trend |
| 16 | [ASH2.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/ASH2.sql) | Report ASH completo | Analisi sessioni |
| 17 | [ASH.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/ASH.sql) | ASH queries (versione nostra) | Analisi sessioni |
| 18 | [AshTopSql.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/AshTopSql.sql) | Top SQL da ASH (versione nostra) | Top consumers |
| 19 | [AshTopSession.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/AshTopSession.sql) | Top sessioni da ASH | Top sessions |
| 20 | [sesswait.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/sessions_locks/sesswait.sql) | Waits correnti per sessione | Evento di attesa |
| 21 | [who2.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/users_logged/who2.sql) | Chi e' connesso con dettagli | Ogni giorno |
| 22 | [PGA_watch.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/PGA_watch.sql) | Monitoraggio PGA real-time | Memory alta |
| 23 | [PGA.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/PGA.sql) | Analisi PGA (versione nostra) | Memory |
| 24 | [Processi.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/Processi.sql) | Processi attivi con dettagli | Ogni giorno |
| 25 | [Event_statistics.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/Event_statistics.sql) | Statistiche eventi di attesa | Diagnosi |

---

## 26-45: AWR, ASH E ANALISI STORICA

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 26 | [aas.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/aas.sql) | Average Active Sessions - il battito cardiaco | Ogni giorno |
| 27 | [awr_defined.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr_defined.sql) | Report AWR **non-interattivo** | Report automatico |
| 28 | [awr_RAC_defined.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr_RAC_defined.sql) | Report AWR non-interattivo su **RAC** | Report RAC |
| 29 | [ash-top-events.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/ash-top-events.sql) | Top 10 eventi in ASH | Diagnosi |
| 30 | [ashtop.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/ashtop.sql) | Top ASH events (Tanel Poder) | Diagnosi rapida |
| 31 | [top10-sql-ash.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/top10-sql-ash.sql) | Top 10 SQL da ASH | Ogni giorno |
| 32 | [top10-sql-awr.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/top10-sql-awr.sql) | Top 10 SQL da AWR (30 giorni) | Analisi trend |
| 33 | [awr-top-5-events.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr-top-5-events.sql) | Top 5 eventi ultimi 7 giorni | Report settimanale |
| 34 | [awr-top-10-daily.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr-top-10-daily.sql) | Top 10 eventi per giorno | Trend giornaliero |
| 35 | [awr-cpu-stats.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr-cpu-stats.sql) | CPU stats tipo `sar` da AWR | Capacity planning |
| 36 | [ash_blocking.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/ash_blocking.sql) | Storico blocchi con SQL_ID | Analisi contesa |
| 37 | [ash-blocker-waits.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/ash-blocker-waits.sql) | Top blockers in ASH | Diagnosi lock |
| 38 | [ash-current-waits.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/ash-current-waits.sql) | Waits correnti per SQL | Diagnosi live |
| 39 | [cpu-busy.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/cpu-busy.sql) | SQL Operations su CPU | CPU analysis |
| 40 | [get-binds.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/get-binds.sql) | Bind values da AWR | Debug SQL |
| 41 | [getsql-awr.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/getsql-awr.sql) | Testo SQL da AWR | Trova SQL |
| 42 | [awr-export.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr-export.sql) | Esporta AWR (pre-migrazione!) | Pre-migrazione |
| 43 | [awr-get-retention.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr-get-retention.sql) | Mostra AWR retention e interval | Configurazione |
| 44 | [awr-set-retention.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/awr-set-retention.sql) | Imposta AWR retention | Configurazione |
| 45 | [ash_cpu_hist.sql](../../01_operations/04_libreria_script_completa/performance_tuning/ash_awr/ash_cpu_hist.sql) | Storico CPU da sysmetric (12c+) | Trend CPU |

---

## 46-65: SQL TUNING E PIANI DI ESECUZIONE

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 46 | [dbms-sqltune-sqlid.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/dbms-sqltune-sqlid.sql) | Crea tuning task per SQL_ID | SQL lento |
| 47 | [find-expensive-sql.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/find-expensive-sql.sql) | Trova SQL costosi (alto LIO) | Top consumers |
| 48 | [profile_from_awr.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/profile_from_awr.sql) | Crea SQL Profile da piano AWR | Forza piano buono |
| 49 | [sql-exe-times-awr.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/sql-exe-times-awr.sql) | Tempi esecuzione da AWR (30gg) | Analisi trend |
| 50 | [sql-exe-times-ash.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/sql-exe-times-ash.sql) | Tempi esecuzione da ASH | Diagnosi live |
| 51 | [sql-exe-events-ash.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/sql-exe-events-ash.sql) | Eventi per esecuzione SQL | Dove perde tempo |
| 52 | [sql-exe-events-awr.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/sql-exe-events-awr.sql) | Eventi per esecuzione (storico) | Analisi storica |
| 53 | [explain_plan.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/explain_plan.sql) | Explain plan formattato | Ogni giorno |
| 54 | [advisor_profile_recs.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/advisor_profile_recs.sql) | Raccomandazioni SQL Advisor | SQL lento |
| 55 | [index_efficiency.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/index_efficiency.sql) | Efficienza indici (clustering factor) | Indice inutile? |
| 56 | [SPM.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/SPM.sql) | SQL Plan Management baselines | Piano instabile |
| 57 | [SPM_from_AWR_old_fashioned.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/SPM_from_AWR_old_fashioned.sql) | Crea baseline da AWR | Forza piano vecchio |
| 58 | [SQL_Profile_Other_SqlID.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/SQL_Profile_Other_SqlID.sql) | Applica profilo di un SQL_ID ad un altro | Trick avanzato |
| 59 | [View_UnstablePlan.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/View_UnstablePlan.sql) | Piani instabili nel tempo | Piano flip-flop |
| 60 | [PerfTuningAnalisys.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/PerfTuningAnalisys.sql) | Analisi performance completa | Report tuning |
| 61 | [SQL Plan Change.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/SQL%20Plan%20Change.sql) | Detect cambio piano esecuzione | Piano cambiato |
| 62 | [SQL Stats.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/SQL%20Stats.sql) | Statistiche SQL dettagliate | SQL analysis |
| 63 | [SQL Bind.sql](../../01_operations/04_libreria_script_completa/performance_tuning/tuning/SQL%20Bind.sql) | Bind variable peeking | Bind sensitivity |
| 64 | [find_sql.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/find_sql.sql) | Trova SQL per SQL_ID | Cercare SQL |
| 65 | [my_sqlmon.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/my_sqlmon.sql) | SQL Monitor report | Real-time SQL |

---

## 66-75: I/O, REDO E DISCO

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 66 | [lfsdiag.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/io_redo/lfsdiag.sql) | Diagnosi **logfile sync** | Commit lenti! |
| 67 | [ioweight.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/io_redo/ioweight.sql) | I/O per tablespace per peso | Hotspot I/O |
| 68 | [redo-rate.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/io_redo/redo-rate.sql) | Redo rate in tempo reale | Dimensiona online redo |
| 69 | [avg_disk_times.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/io_redo/avg_disk_times.sql) | Tempi medi read/write | Storage lento |
| 70 | [View_IO_RealTime.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/View_IO_RealTime.sql) | I/O in tempo reale (nostro) | Ogni giorno |
| 71 | [View_IO_Database.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/View_IO_Database.sql) | I/O per database | Report |
| 72 | [View_IO_Hist.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/View_IO_Hist.sql) | Storico I/O | Analisi trend |
| 73 | [IO_stat_nel_tempo.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/IO_stat_nel_tempo.sql) | Statistiche I/O nel tempo | Trend |
| 74 | [View_RedoGeneration.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/View_RedoGeneration.sql) | Redo generation per istanza | Sizing redo |
| 75 | [trans_per_hour.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/io_redo/trans_per_hour.sql) | Transazioni per ora | Capacity |

---

## 76-82: ASM

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 76 | [asm_diskgroups.sql](../../01_operations/04_libreria_script_completa/asm_storage/asm_diskgroups.sql) | Spazio disk group (nostro) | Controllo spazio |
| 77 | [asm_diskgroups.sql](../../01_operations/04_libreria_script_completa/asm_storage/asm_diskgroups.sql) | Diskgroups dettagliato | Controllo ASM |
| 78 | [asm_disks.sql](../../01_operations/04_libreria_script_completa/asm_storage/asm_disks.sql) | Dettaglio dischi ASM | Verifica dischi |
| 79 | [asm_disk_errors.sql](../../01_operations/04_libreria_script_completa/asm_storage/asm_disk_errors.sql) | Errori disco ASM | Check proattivo! |
| 80 | [asm_disk_stats.sql](../../01_operations/04_libreria_script_completa/asm_storage/asm_disk_stats.sql) | I/O per disco ASM | Performance ASM |
| 81 | [asm_failgroup_members.sql](../../01_operations/04_libreria_script_completa/asm_storage/asm_failgroup_members.sql) | Membri per failgroup | Verifica ridondanza |
| 82 | [asm_files_path.sql](../../01_operations/04_libreria_script_completa/asm_storage/asm_files_path.sql) | File ASM con path completo | Trova file |

---

## 83-92: TABLESPACE, UNDO E STORAGE

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 83 | [tablespace.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/tablespace.sql) | Stato tablespace (semplice) | Alert spazio |
| 84 | [showtbs.sql](../../01_operations/04_libreria_script_completa/utilities/storage/showtbs.sql) | Tutti i tablespace | Report completo |
| 85 | [showdf.sql](../../01_operations/04_libreria_script_completa/utilities/storage/showdf.sql) | Tutti i datafile | Verifica file |
| 86 | [showfree.sql](../../01_operations/04_libreria_script_completa/utilities/storage/showfree.sql) | Spazio libero per tablespace | Controllo spazio |
| 87 | [dfshrink-gen.sql](../../01_operations/04_libreria_script_completa/utilities/storage/dfshrink-gen.sql) | Genera shrink datafile | Recupera spazio |
| 88 | [double_tablespace.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/double_tablespace.sql) | Script per raddoppiare tablespace | Emergenza spazio |
| 89 | [undo_stats.sql](../../01_operations/04_libreria_script_completa/performance_tuning/stats_optimizer/undo_stats.sql) | Statistiche UNDO (rileva ORA-1555) | ORA-1555 |
| 90 | [undo_space.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/undo_space.sql) | Analisi spazio UNDO | UNDO pieno |
| 91 | [TEMP_and_UNDO_monitor.sql](../../01_operations/04_libreria_script_completa/utilities/TEMP_and_UNDO_monitor.sql) | Monitor TEMP e UNDO (nostro) | TEMP pieno |
| 92 | [showspace.sql](../../01_operations/04_libreria_script_completa/utilities/storage/showspace.sql) | Spazio oggetto con DBMS_SPACE | Analisi segmenti |

---

## 93-97: STATISTICHE E OPTIMIZER

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 93 | [stale-stats.sql](../../01_operations/04_libreria_script_completa/performance_tuning/stats_optimizer/stale-stats.sql) | Tabelle con statistiche obsolete | Statistiche vecchie |
| 94 | [stats_prefs.sql](../../01_operations/04_libreria_script_completa/performance_tuning/stats_optimizer/stats_prefs.sql) | Preferenze DBMS_STATS | Configurazione |
| 95 | [Stats_workflow.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/Stats_workflow.sql) | Workflow gestione stats (nostro) | Procedura stats |
| 96 | [col_high_low_val.sql](../../01_operations/04_libreria_script_completa/monitoring_scripts/col_high_low_val.sql) | Valori high/low colonne | Skew detection |
| 97 | [locked_stats.sql](../../01_operations/04_libreria_script_completa/performance_tuning/stats_optimizer/locked_stats.sql) | Statistiche bloccate | Stats non aggiornate |

---

## 98-100: BACKUP, DATA GUARD E SECURITY

| # | Script | Cosa Fa | Quando |
|---|---|---|---|
| 98 | [BACKUP CHECKS.sql](../../01_operations/04_libreria_script_completa/backup_recovery/BACKUP%20CHECKS.sql) | Verifica stato backup RMAN | Ogni mattina |
| 99 | [MONITOR__RMAN_BACKUP.sql](../../01_operations/04_libreria_script_completa/backup_recovery/MONITOR__RMAN_BACKUP.sql) | Monitoraggio RMAN in corso | Backup running |
| 100 | [rman-bkup-status.sql](../../01_operations/04_libreria_script_completa/backup_recovery/rman-bkup-status.sql) | Stato backup RMAN (community) | Verifica backup |

---

## Come usare il catalogo

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
> 1. `aas.sql` - il database sta lavorando troppo?
> 2. `tablespace.sql` - c'e' spazio?
> 3. `asm_disk_errors.sql` - errori disco?
> 4. `BACKUP CHECKS.sql` - backup OK stanotte?
> 5. `showlock2.sql` - qualcuno e' bloccato?

---

*Tutti i 554 script sono in [01_operations/04_libreria_script_completa/](../../01_operations/04_libreria_script_completa/) - [Attivita Lab RAC](../../04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md)*
