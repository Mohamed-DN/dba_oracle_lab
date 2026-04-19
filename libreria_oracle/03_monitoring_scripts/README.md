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

## 🎯 Come Usare Questo Toolkit in Emergenza

Un DBA professionista non lancia script a caso. L'approccio deve essere metodico. Ecco come combinare questi script in uno scenario di crisi (es. "Il DB è piantato, il cliente è al telefono"):

### Fase 1: Il "Triage" (Rilevamento Globale)
Inizia sempre dallo script `___ Situation.sql`.
* **Cosa fa**: Ti restituisce in un solo colpo lo stato dell'istanza, l'uptime, l'utilizzo dei processi (rispetto al limite `processes`), le sessioni bloccate e i principali wait event del sistema.
* **Perché usarlo**: Ti evita di navigare ciecamente. Capisci sùbito se il problema è CPU, I/O o concorrenza (Lock).

### Fase 2: Approfondimento per Categoria
In base al risultato del Triage:
* **Se ci sono Lock**: Esegui sùbito `View_Blocking.sql`. Trova il **root blocker** (la sessione in cima all'albero che blocca tutte le altre). Usa `Processsi.sql` per capire quale server applicativo sta tenendo aperta la transazione.
* **Se ci sono attese di I/O**: Usa `View_IO_RealTime.sql` per capire quale datafile o disco ASM è sotto stress. Spesso è un *Full Table Scan* causato da un indice mancante (in tal caso, passa ad ASH).
* **Se la CPU è al 100%**: Usa `View_Cpu_Consumer.sql`. L'Output ti darà il `SQL_ID` colpevole.

### Fase 3: SQL Tuning (Root Cause)
Una volta trovato il **SQL_ID** problematico (grazie ad `AshTopSql.sql` o all'analisi CPU):
1. Usa `SQL Stats.sql` (inserisci l'ID) per vedere quante esecuzioni fa e quante righe legge a esecuzione.
2. Controlla se il piano è instabile con `View_UnstablePlan.sql`.
3. Se l'optimizer è impazzito di colpo (a causa di gather stats sbagliato), puoi usare la suite `SPM` per bloccare o ripristinare il vecchio piano (es. usando `SQL_Profile_Other_SqlID.sql`).

```bash
# Esecuzione rapida da terminale
sqlplus / as sysdba @/path/to/libreria_oracle/03_monitoring_scripts/___ Situation.sql
```

> [!TIP]
> **Consiglio per il colloquio (Intervista)**: Quando ti chiedono "Come monitori il database?", non rispondere "Guardo Enterprise Manager". Rispondi: "Uso script SQL customizzati interrogando le viste dinamiche (`v$session`, `v$sql`, `v$active_session_history`) perché permettono un'indagine millimetrica sui lock e sui wait events prima ancora di aprire grafici."
