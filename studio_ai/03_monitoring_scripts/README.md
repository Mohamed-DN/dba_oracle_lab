# 03 — Script SQL di Monitoring (Uso Quotidiano)

> 48 script SQL per il monitoraggio quotidiano di database Oracle RAC.
> These are the scripts that an Enterprise DBA uses **every day** to diagnose problems.

---

## 📂 Organizzazione per Categoria

### 🔍 Sessioni e Lock

| Script | What He Does |
|---|---|
| `ViewSession.sql` | Show all active sessions with username, program, status |
| `View_Blocking.sql` | Identifica le sessioni bloccanti (chi blocca chi) |
| `locks.sql` | Active locks with details on type and object |
| `locks_blocking.sql` | Lock ascenders with waiting chain |
| `locks_details.sql` | Dettagli completi dei lock (DML, DDL, tipo) |
| `locks_10g.sql` | 10g compatible version |
| `Check_Lock.sql` | Check rapido dei lock |
| `Processsi.sql` | Processi OS collegati alle sessioni Oracle |

### 📊 Performance CPU e I/O

| Script | What He Does |
|---|---|
| `View_Cpu_Consumer.sql` | Top consumatori di CPU in tempo reale |
| `View_Cpu_Hist.sql` | Storico consumo CPU |
| `View_IO_Database.sql` | I/O complessivo del database |
| `View_IO_Hist.sql` | Storico I/O |
| `View_IO_RealTime.sql` | I/O in tempo reale per sessione |
| `IO_WaitTimeDetails.sql` | Dettaglio tempi di attesa I/O |
| `IO_stat_nel_tempo.sql` | Statistiche I/O nel tempo |
| `Event_statistics.sql` | Statistiche sugli eventi di attesa |

### 📈 ASH (Active Session History)

| Script | What He Does |
|---|---|
| `ASH.sql` | Report ASH base |
| `ActiveSessionHistoryQueries.sql` | Query ASH avanzate |
| `AshTopSession.sql` | Top sessions by activity |
| `AshTopSql.sql` | Top SQL per consumo risorse |
| `AshTopProcedure.sql` | Top procedure PL/SQL |

### 💾 ASM (Automatic Storage Management)

| Script | What He Does |
|---|---|
| `Asm_Diskgroups.sql` | Disk Group status and space |
| `Asm_Disks.sql` | Detail of ASM disks |
| `Asm_Disks_Perf.sql` | Performance I/O per disco ASM |
| `Asm_DiskGroupPerformance.sql` | Performance per Disk Group |
| `Asm_Files.sql` | File contenuti nei Disk Group |
| `Asm_Alias.sql` | Alias ASM |
| `Asm_Clients.sql` | Database connessi all'ASM |
| `Asm_Templates.sql` | Template di ridondanza |
| `Asm_Check.sql` | Health check ASM |
| `Asmdisk.sql` | Informazioni disco singolo |
| `Asm_drop_files.sql` | Identificazione file da eliminare |

### 🔧 SQL Tuning e SPM

| Script | What He Does |
|---|---|
| `SPM.sql` | SQL Plan Management (baselines) |
| `SPM_from_AWR_old_fashioned.sql` | SPM creation from AWR (classic method) |
| `SQL Area 1x.sql` | Analisi SQL Area |
| `SQL Bind.sql` | Variabili bind per SQL ID |
| `SQL Plan Change.sql` | Detection of plan changes |
| `SQL Stats.sql` | Statistiche SQL dettagliate |
| `SQL_Profile_Other_SqlID.sql` | Applicazione SQL Profile da un altro SQL ID |
| `View_UnstablePlan.sql` | Identificazione piani instabili |

### 📋 Altre Utility

| Script | What He Does |
|---|---|
| `___ Situation.sql` | Panorama generale: sessioni, PDB, job, PX, connessioni |
| `PGA.sql` | Analisi utilizzo PGA |
| `View_RedoGeneration.sql` | Generazione redo log per sessione |
| `BACKUP CHECKS.sql` | Check RMAN backup status |
| `MONITOR__RMAN_BACKUP.sql` | Monitoraggio backup RMAN in corso |
| `sysaux_fix.sql` | Fix per tablespace SYSAUX pieno |
| `Stats_workflow.sql` | Workflow for statistics management |
| `P3NPGP Queue*.sql` | Oracle queue management (Advanced Queuing) |
| `PerfTuningAnalisys.sql` | Complete Performance Tuning analysis |

---

## 🎯 How to Use Them

```bash
# Da SQL*Plus, connesso come DBA:
sqlplus / as sysdba

# Esecuzione di uno script
@/path/to/studio_ai/03_monitoring_scripts/ViewSession.sql
```

> [!TIP]
> The `___ Situation.sql` script is the "all-rounder": it gives a complete overview of the database situation in one fell swoop. Ideal as a first check-up.
