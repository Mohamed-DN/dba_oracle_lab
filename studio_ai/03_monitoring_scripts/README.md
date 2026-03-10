# 03 — Script SQL di Monitoring (Uso Quotidiano)

> 48 script SQL per il monitoraggio quotidiano di database Oracle RAC.
> Questi sono gli script che un DBA Enterprise usa **ogni giorno** per diagnosticare problemi.

---

## 📂 Organizzazione per Categoria

### 🔍 Sessioni e Lock

| Script | Cosa Fa |
|---|---|
| `ViewSession.sql` | Mostra tutte le sessioni attive con username, programma, stato |
| `View_Blocking.sql` | Identifica le sessioni bloccanti (chi blocca chi) |
| `locks.sql` | Lock attivi con dettagli su tipo e oggetto |
| `locks_blocking.sql` | Lock bloccanti con catena di attesa |
| `locks_details.sql` | Dettagli completi dei lock (DML, DDL, tipo) |
| `locks_10g.sql` | Versione compatibile con 10g |
| `Check_Lock.sql` | Check rapido dei lock |
| `Processsi.sql` | Processi OS collegati alle sessioni Oracle |

### 📊 Performance CPU e I/O

| Script | Cosa Fa |
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

| Script | Cosa Fa |
|---|---|
| `ASH.sql` | Report ASH base |
| `ActiveSessionHistoryQueries.sql` | Query ASH avanzate |
| `AshTopSession.sql` | Top sessioni per attività |
| `AshTopSql.sql` | Top SQL per consumo risorse |
| `AshTopProcedure.sql` | Top procedure PL/SQL |

### 💾 ASM (Automatic Storage Management)

| Script | Cosa Fa |
|---|---|
| `Asm_Diskgroups.sql` | Stato e spazio dei Disk Group |
| `Asm_Disks.sql` | Dettaglio dei dischi ASM |
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

| Script | Cosa Fa |
|---|---|
| `SPM.sql` | Gestione SQL Plan Management (baselines) |
| `SPM_from_AWR_old_fashioned.sql` | Creazione SPM da AWR (metodo classico) |
| `SQL Area 1x.sql` | Analisi SQL Area |
| `SQL Bind.sql` | Variabili bind per SQL ID |
| `SQL Plan Change.sql` | Rilevamento cambi di piano |
| `SQL Stats.sql` | Statistiche SQL dettagliate |
| `SQL_Profile_Other_SqlID.sql` | Applicazione SQL Profile da un altro SQL ID |
| `View_UnstablePlan.sql` | Identificazione piani instabili |

### 📋 Altre Utility

| Script | Cosa Fa |
|---|---|
| `___ Situation.sql` | Panorama generale: sessioni, PDB, job, PX, connessioni |
| `PGA.sql` | Analisi utilizzo PGA |
| `View_RedoGeneration.sql` | Generazione redo log per sessione |
| `BACKUP CHECKS.sql` | Verifica stato backup RMAN |
| `MONITOR__RMAN_BACKUP.sql` | Monitoraggio backup RMAN in corso |
| `sysaux_fix.sql` | Fix per tablespace SYSAUX pieno |
| `Stats_workflow.sql` | Workflow per gestione statistiche |
| `P3NPGP Queue*.sql` | Gestione code Oracle (Advanced Queuing) |
| `PerfTuningAnalisys.sql` | Analisi completa Performance Tuning |

---

## 🎯 Come Usarli

```bash
# Da SQL*Plus, connesso come DBA:
sqlplus / as sysdba

# Esecuzione di uno script
@/path/to/studio_ai/03_monitoring_scripts/ViewSession.sql
```

> [!TIP]
> Lo script `___ Situation.sql` è il "tuttfare": dà una panoramica completa della situazione del database in un colpo solo. Ideale come primo controllo.
