#03 — Monitoring SQL Script (Daily Use)

> 48 SQL scripts for daily monitoring of Oracle RAC databases.
> These are the scripts that an Enterprise DBA uses **every day** to diagnose problems.

---

## 📂 Organization by Category

### 🔍 Sessions and Lock

| Script | What He Does |
|---|---|
| `ViewSession.sql` | Show all active sessions with username, program, status |
| `View_Blocking.sql` |Identify blocking sessions (who is blocking whom)|
| `locks.sql` | Active locks with details on type and object |
| `locks_blocking.sql` | Lock ascenders with waiting chain |
| `locks_details.sql` |Full lock details (DML, DDL, type)|
| `locks_10g.sql` | 10g compatible version |
| `Check_Lock.sql` | Check rapido dei lock |
| `Processsi.sql` |OS processes linked to Oracle sessions|

### 📊 Performance CPU e I/O

| Script | What He Does |
|---|---|
| `View_Cpu_Consumer.sql` |Top real-time CPU consumers|
| `View_Cpu_Hist.sql` | Storico consumo CPU |
| `View_IO_Database.sql` |Overall database I/O|
| `View_IO_Hist.sql` |I/O history|
| `View_IO_RealTime.sql` |Real-time I/O per session|
| `IO_WaitTimeDetails.sql` |Detail of I/O waiting times|
| `IO_stat_nel_tempo.sql` |I/O statistics over time|
| `Event_statistics.sql` |Wait event statistics|

### 📈 ASH (Active Session History)

| Script | What He Does |
|---|---|
| `ASH.sql` | Report ASH base |
| `ActiveSessionHistoryQueries.sql` |Advanced ASH queries|
| `AshTopSession.sql` | Top sessions by activity |
| `AshTopSql.sql` |Top SQL for resource consumption|
| `AshTopProcedure.sql` | Top procedure PL/SQL |

### 💾 ASM (Automatic Storage Management)

| Script | What He Does |
|---|---|
| `Asm_Diskgroups.sql` | Disk Group status and space |
| `Asm_Disks.sql` | Detail of ASM disks |
| `Asm_Disks_Perf.sql` | Performance I/O per disco ASM |
| `Asm_DiskGroupPerformance.sql` | Performance per Disk Group |
| `Asm_Files.sql` |Files contained in Disk Groups|
| `Asm_Alias.sql` | Alias ASM |
| `Asm_Clients.sql` |Databases connected to the ASM|
| `Asm_Templates.sql` |Redundancy template|
| `Asm_Check.sql` | Health check ASM |
| `Asmdisk.sql` |Single disc information|
| `Asm_drop_files.sql` |Identifying files to delete|

### 🔧 SQL Tuning e SPM

| Script | What He Does |
|---|---|
| `SPM.sql` | SQL Plan Management (baselines) |
| `SPM_from_AWR_old_fashioned.sql` | SPM creation from AWR (classic method) |
| `SQL Area 1x.sql` | Analisi SQL Area |
| `SQL Bind.sql` |Bind variables for SQL ID|
| `SQL Plan Change.sql` | Detection of plan changes |
| `SQL Stats.sql` |Detailed SQL statistics|
| `SQL_Profile_Other_SqlID.sql` |SQL Profile application from another SQL ID|
| `View_UnstablePlan.sql` |Identification of unstable floors|

### 📋 Other Utilities

| Script | What He Does |
|---|---|
| `___ Situation.sql` |General overview: sessions, PDB, jobs, PX, connections|
| `PGA.sql` |PGA usage analysis|
| `View_RedoGeneration.sql` |Redo log generation per session|
| `BACKUP CHECKS.sql` | Check RMAN backup status |
| `MONITOR__RMAN_BACKUP.sql` |Monitoring RMAN backup in progress|
| `sysaux_fix.sql` | Fix per tablespace SYSAUX pieno |
| `Stats_workflow.sql` | Workflow for statistics management |
| `P3NPGP Queue*.sql` | Oracle queue management (Advanced Queuing) |
| `PerfTuningAnalisys.sql` | Complete Performance Tuning analysis |

---

## 🎯 How to Use Them

```bash
# Da SQL*Plus, connesso come DBA:
sqlplus / as sysdba

# Running a script
@/path/to/studio_ai/03_monitoring_scripts/ViewSession.sql
```

> [!TIP]
> The `___ Situation.sql` script is the "all-rounder": it gives a complete overview of the database situation in one fell swoop. Ideal as a first check-up.
