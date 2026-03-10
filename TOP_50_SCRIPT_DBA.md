# 🏆 Top 50 Script DBA — I Più Usati Ogni Giorno

> Selezione curata dei **50 script più utili** tra le 3 raccolte del progetto (originali, jkstill, gwenshap).
> Ogni link punta direttamente allo script nella cartella `studio_ai/`.

---

## 🔴 EMERGENZA — Quando qualcosa non va (primi 5 minuti)

| # | Script | Cosa Fa | Fonte |
|---|---|---|---|
| 1 | [showlock2.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/showlock2.sql) | Chi blocca chi — lock con waiters e blockers (12c+) | jkstill |
| 2 | [locks.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/locks.sql) | Lock attivi con dettaglio completo | gwenshap |
| 3 | [active_status.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/active_status.sql) | Sessioni attive su CPU in questo momento | jkstill |
| 4 | [snapper.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/snapper.sql) | Sampling real-time sessioni (script leggendario di Tanel Poder) | jkstill |
| 5 | [check_and_kill.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/check_and_kill.sql) | Identifica e genera script per kill sessioni problematiche | gwenshap |

---

## 📊 PERFORMANCE — Diagnosi quotidiana

| # | Script | Cosa Fa | Fonte |
|---|---|---|---|
| 6 | [top-sql.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/top-sql.sql) | Top SQL per consumo risorse (semplice e veloce) | gwenshap |
| 7 | [top10-sql-ash.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/top10-sql-ash.sql) | Top 10 SQL da Active Session History | jkstill |
| 8 | [find-expensive-sql.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/find-expensive-sql.sql) | Trova SQL costosi (alto Logical I/O) da AWR | jkstill |
| 9 | [aas.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/aas.sql) | Average Active Sessions — il "battito cardiaco" del DB | jkstill |
| 10 | [ash-top-events.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ash-top-events.sql) | Top 10 eventi di attesa in ASH (per istanza e cluster) | jkstill |
| 11 | [ashtop.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ashtop.sql) | Top ASH events — script di Tanel Poder | jkstill |
| 12 | [cpu-busy.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/cpu-busy.sql) | Quali operazioni SQL stanno usando la CPU | jkstill |
| 13 | [sesswait.sql](./studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/sesswait.sql) | Waits correnti da v$session_wait | jkstill |

---

## 📈 AWR/ASH — Report e Analisi Storica

| # | Script | Cosa Fa | Fonte |
|---|---|---|---|
| 14 | [awr_defined.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr_defined.sql) | Report AWR **non-interattivo** (specificando snap_id) | jkstill |
| 15 | [awr_RAC_defined.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr_RAC_defined.sql) | Report AWR non-interattivo su **RAC** | jkstill |
| 16 | [awr-top-5-events.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-top-5-events.sql) | Top 5 eventi degli ultimi 7 giorni | jkstill |
| 17 | [awr-top-10-daily.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-top-10-daily.sql) | Top 10 eventi per giorno | jkstill |
| 18 | [awr-cpu-stats.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/awr-cpu-stats.sql) | Report CPU simile a `sar` da AWR | jkstill |
| 19 | [ash_blocking.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/ash_blocking.sql) | Storico blocchi: bloccanti e bloccati con SQL_ID | jkstill |
| 20 | [get-binds.sql](./studio_ai/07_performance_tuning/community_scripts/ash_awr/get-binds.sql) | Valori bind da dba_hist_sqlbind | jkstill |

---

## 🔧 SQL TUNING — Quando una query va piano

| # | Script | Cosa Fa | Fonte |
|---|---|---|---|
| 21 | [dbms-sqltune-sqlid.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/dbms-sqltune-sqlid.sql) | Crea ed esegui un SQL Tuning Task per un SQL_ID | jkstill |
| 22 | [profile_from_awr.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/profile_from_awr.sql) | Crea un SQL Profile da un piano AWR (forza il piano buono) | jkstill |
| 23 | [explain_plan.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/explain_plan.sql) | Explain plan formattato | gwenshap |
| 24 | [sql-exe-times-awr.sql](./studio_ai/07_performance_tuning/community_scripts/tuning/sql-exe-times-awr.sql) | Tempi esecuzione SQL negli ultimi 30 giorni | jkstill |
| 25 | [advisor_profile_recs.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/advisor_profile_recs.sql) | Raccomandazioni SQL Advisor e Profile | gwenshap |
| 26 | [index_efficiency.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/index_efficiency.sql) | Analisi efficienza indici (clustering factor) | gwenshap |
| 27 | [SPM.sql](./studio_ai/03_monitoring_scripts/SPM.sql) | Gestione SQL Plan Management (baselines) | originale |

---

## 💽 I/O e REDO — Diagnosi storage

| # | Script | Cosa Fa | Fonte |
|---|---|---|---|
| 28 | [lfsdiag.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/lfsdiag.sql) | Diagnosi **logfile sync** — fondamentale per commit lenti! | jkstill |
| 29 | [ioweight.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/ioweight.sql) | I/O per tablespace ordinato per peso | jkstill |
| 30 | [redo-rate.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/redo-rate.sql) | Redo generation rate in tempo reale | jkstill |
| 31 | [avg_disk_times.sql](./studio_ai/03_monitoring_scripts/community_jkstill/io_redo/avg_disk_times.sql) | Tempi medi lettura/scrittura disco | jkstill |

---

## 📀 ASM — Monitoraggio storage ASM

| # | Script | Cosa Fa | Fonte |
|---|---|---|---|
| 32 | [asm_diskgroups.sql](./studio_ai/01_asm_storage/community_scripts/asm_diskgroups.sql) | Stato e spazio dei Disk Group | jkstill |
| 33 | [asm_disks.sql](./studio_ai/01_asm_storage/community_scripts/asm_disks.sql) | Dettaglio dischi ASM | jkstill |
| 34 | [asm_disk_errors.sql](./studio_ai/01_asm_storage/community_scripts/asm_disk_errors.sql) | Errori disco ASM (check proattivo!) | jkstill |
| 35 | [asm_disk_stats.sql](./studio_ai/01_asm_storage/community_scripts/asm_disk_stats.sql) | Statistiche I/O per ogni disco | jkstill |
| 36 | [Asm_Diskgroups.sql](./studio_ai/03_monitoring_scripts/Asm_Diskgroups.sql) | Spazio disk group (versione nostra) | originale |

---

## 🗄️ TABLESPACE & STORAGE — Gestione spazio

| # | Script | Cosa Fa | Fonte |
|---|---|---|---|
| 37 | [tablespace.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/tablespace.sql) | Stato tablespace (semplice e chiaro) | gwenshap |
| 38 | [showtbs.sql](./studio_ai/12_utilities/community_scripts/storage/showtbs.sql) | Tutti i tablespace con info | jkstill |
| 39 | [showdf.sql](./studio_ai/12_utilities/community_scripts/storage/showdf.sql) | Tutti i datafile con informazioni | jkstill |
| 40 | [undo_stats.sql](./studio_ai/12_utilities/community_scripts/storage/undo_stats.sql) | Statistiche UNDO — rileva ORA-1555 | jkstill |
| 41 | [dfshrink-gen.sql](./studio_ai/12_utilities/community_scripts/storage/dfshrink-gen.sql) | Genera codice per shrink datafile (recupera spazio!) | jkstill |

---

## 📋 STATISTICHE — Optimizer e DBMS_STATS

| # | Script | Cosa Fa | Fonte |
|---|---|---|---|
| 42 | [controllo_statistiche.txt](./studio_ai/07_performance_tuning/controllo_statistiche.txt) | Procedura completa gestione statistiche | originale |
| 43 | [col_high_low_val.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/col_high_low_val.sql) | Valori high/low colonne per statistiche | gwenshap |

---

## 👤 SESSIONI — Chi è connesso

| # | Script | Cosa Fa | Fonte |
|---|---|---|---|
| 44 | [ViewSession.sql](./studio_ai/03_monitoring_scripts/ViewSession.sql) | Le nostre sessioni attive (versione originale) | originale |
| 45 | [ASH2.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/ASH2.sql) | Report ASH completo (sessioni, eventi, SQL) | gwenshap |
| 46 | [PGA_watch.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/PGA_watch.sql) | Monitoraggio PGA in tempo reale | gwenshap |

---

## 🔒 BACKUP & DATA GUARD — Verifiche

| # | Script | Cosa Fa | Fonte |
|---|---|---|---|
| 47 | [BACKUP CHECKS.sql](./studio_ai/03_monitoring_scripts/BACKUP%20CHECKS.sql) | Verifica stato backup RMAN | originale |
| 48 | [DataGuard.txt](./studio_ai/03_monitoring_scripts/community_gwenshap/DataGuard.txt) | Quick reference comandi Data Guard | gwenshap |
| 49 | [verifica_gap.md](./studio_ai/02_dataguard/verifica_gap.md) | Query per verificare GAP tra primary e standby | originale |

---

## 🛠️ UTILITY — Job e Scheduler

| # | Script | Cosa Fa | Fonte |
|---|---|---|---|
| 50 | [job_scheduling.sql](./studio_ai/03_monitoring_scripts/community_gwenshap/job_scheduling.sql) | Gestione job DBMS_SCHEDULER | gwenshap |

---

## ⚡ Come Usare Questa Lista

```bash
# Connettiti al database
sqlplus / as sysdba

# Esegui qualsiasi script dalla lista:
@studio_ai/03_monitoring_scripts/community_jkstill/sessions_locks/showlock2.sql

# Per gli script ASM, connettiti come SYSASM:
sqlplus / as sysasm
@studio_ai/01_asm_storage/community_scripts/asm_diskgroups.sql
```

> [!TIP]
> **Crea un alias!** Aggiungi al tuo `.bashrc`:
> ```bash
> export SCRIPTS=$ORACLE_HOME/studio_ai
> alias locks='sqlplus / as sysdba @$SCRIPTS/03_monitoring_scripts/community_jkstill/sessions_locks/showlock2.sql'
> alias topsql='sqlplus / as sysdba @$SCRIPTS/03_monitoring_scripts/community_gwenshap/top-sql.sql'
> alias space='sqlplus / as sysdba @$SCRIPTS/03_monitoring_scripts/community_gwenshap/tablespace.sql'
> ```

---

*📚 La raccolta completa è in [studio_ai/](./studio_ai/) — Vedi anche le [Attività Lab RAC](./GUIDA_ATTIVITA_LAB_RAC.md)*
