# GUIDE: Oracle MAA Best Practices — Lab Validation

> **Goal**: Verify that our lab is aligned with **Oracle Maximum Availability Architecture (MAA)** best practices. MAA is Oracle's official framework for high availability and disaster recovery.

---

## 1. What is MAA?

```
╔══════════════════════════════════════════════════════════════════╗
║          ORACLE MAA — Livelli di Protezione                      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ 🥉 BRONZE — High Local Availability ║
║ ├── Single Instance with RMAN Backup ║
║  ├── Flashback Database abilitato                                ║
║  ├── Block Checking e Checksums                                  ║
║  └── RPO: minuti / RTO: ore                                     ║
║                                                                  ║
║  🥈 SILVER — Disaster Recovery                                   ║
║  ├── Tutto Bronze +                                              ║
║ ├── Oracle Data Guard (Physical Standby) ║
║ ├── Standby Redo Logs (real-time apply) ║
║  ├── DGMGRL (Data Guard Broker)                                  ║
║  └── RPO: secondi / RTO: minuti                                 ║
║                                                                  ║
║  🥇 GOLD — Zero Data Loss, Minimal Downtime       ← IL NOSTRO!  ║
║  ├── Tutto Silver +                                              ║
║ ├── Oracle RAC (multi-node) ║
║ ├── Active Data Guard (standby read-only) ║
║  ├── Fast-Start Failover (FSFO)                                  ║
║  ├── Application Continuity (FAN)                                ║
║  └── RPO: 0 (zero data loss) / RTO: secondi                     ║
║                                                                  ║
║  💎 PLATINUM — Mission Critical (Exadata + GDS)                  ║
║  ├── Tutto Gold + Global Data Services                           ║
║  ├── Multi-site Active-Active                                    ║
║  └── RPO: 0 / RTO: 0 (always available)                         ║
╚══════════════════════════════════════════════════════════════════╝
```

> **Our lab is MAA GOLD**: RAC Primary + RAC Standby + Active Data Guard + GoldenGate. Only some fine-tuning parameters are missing.

---

## 2. Validation Checklist — Our Lab vs MAA

### 2.1 Data Protection

| # | Requisito MAA | Il Nostro Lab | Status | How to Fix |
|---|---|---|---|---|
| 1 | `ARCHIVELOG` mode ON | ✅ Configured in Phase 2 | ✅ | — |
| 2 | `FORCE LOGGING` ON | ✅ Configured in Phase 2 | ✅ | — |
| 3 | `DB_BLOCK_CHECKING = MEDIUM` | ❌ Non configurato | ⚠️ | Vedi 3.1 |
| 4 | `DB_BLOCK_CHECKSUM = TYPICAL` | ❌ Non configurato | ⚠️ | Vedi 3.1 |
| 5 | `DB_LOST_WRITE_PROTECT = TYPICAL` | ❌ Non configurato | ⚠️ | Vedi 3.1 |
| 6 | Flashback Database ON | ❌ Non configurato | ⚠️ | Vedi 3.2 |
| 7 | Redo Log multiplexato | ⚠️ Dipende da ASM redundancy | ⚠️ | Vedi 3.3 |

### 2.2 Data Guard

| # | Requisito MAA | Il Nostro Lab | Status | How to Fix |
|---|---|---|---|---|
| 8 | Standby Redo Logs | ✅ Configured in Phase 3 | ✅ | — |
| 9 | Real-Time Apply | ✅ MRP with USING CURRENT LOGFILE | ✅ | — |
| 10 | DG Broker (DGMGRL) | ✅ Configured in Phase 4 | ✅ | — |
| 11 | Active Data Guard | ✅ Read-Only with Apply | ✅ | — |
| 12 | FSFO (automatic failover) | ⚠️ Descritto ma non configurato | ⚠️ | Vedi 3.4 |
| 13 | `LOG_ARCHIVE_DEST_2` ASYNC o SYNC | ✅ Configurato | ✅ | — |
| 14 | FAL_SERVER configurato | ✅ Configured in Phase 3 | ✅ | — |

### 2.3 RAC

| # | Requisito MAA | Il Nostro Lab | Status | How to Fix |
|---|---|---|---|---|
| 15 | 2+ nodi RAC | ✅ 2 primary nodes + 2 standby | ✅ | — |
| 16 | SCAN configurato | ✅ 3 SCAN IP | ✅ | — |
| 17 | Services definiti | ⚠️ Described in the Listener guide | ⚠️ | See exercises |
| 18 | FAN abilitato | ❓ Non verificato | ⚠️ | Vedi 3.5 |
| 19 | ONS (Oracle Notification Service) | ❓ Auto-configurato da CRS | ✅ | Verify |

### 2.4 Backup e Recovery

| # | Requisito MAA | Il Nostro Lab | Status | How to Fix |
|---|---|---|---|---|
| 20 | RMAN Backup regolare | ✅ Phase 7 complete | ✅ | — |
| 21 | BCT (Block Change Tracking) | ✅ Configured in Phase 7 | ✅ | — |
| 22 | Backup VALIDATE regolare | ✅ Described in Phase 7 | ✅ | — |
| 23 | Controlfile autobackup | ✅ Configurato | ✅ | — |

### 2.5 Riepilogo

```
╔══════════════════════════════════════════════════╗
║  SCORECARD MAA — Il Nostro Lab                    ║
╠══════════════════════════════════════════════════╣
║                                                   ║
║  ✅ Compliant:      16 / 23 (70%)                ║
║  ⚠️ Da migliorare:   7 / 23 (30%)                ║
║  ❌ Non presente:     0                           ║
║                                                   ║
║  LIVELLO MAA RAGGIUNTO: 🥈 SILVER → 🥇 GOLD     ║
║ (with the fixes below, we reach full GOLD) ║
╚══════════════════════════════════════════════════╝
```

---

## 3. Fix per Raggiungere MAA GOLD

### 3.1 Abilitare Data Protection Parameters

```sql
-- Sul PRIMARY (propagato allo standby da DG)
sqlplus / as sysdba

-- Block Checking: rileva corruzione dei blocchi in memoria
-- MEDIUM è il miglior compromesso (impatto ~1-3% CPU)
ALTER SYSTEM SET db_block_checking = MEDIUM SCOPE=BOTH SID='*';

-- Block Checksum: verifica integrità dei blocchi
-- TYPICAL è consigliato (impatto ~1% I/O)
ALTER SYSTEM SET db_block_checksum = TYPICAL SCOPE=BOTH SID='*';

-- Lost Write Protection: rileva scritture perse
-- TYPICAL abilita il shadow tablespace (richiede le standby redo log)
ALTER SYSTEM SET db_lost_write_protect = TYPICAL SCOPE=BOTH SID='*';
```

```
╔══════════════════════════════════════════════════════════════════╗
║ WHY THESE PARAMETERS?                                        ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  DB_BLOCK_CHECKING:                                              ║
║  Controlla la coerenza interna dei blocchi quando vengono        ║
║  modificati in memoria. Previene la propagazione di corruzione.  ║
║ └── MEDIUM: check all blocks except INDEX blocks ║
║              (gli indici si possono ricostruire)                 ║
║                                                                  ║
║  DB_BLOCK_CHECKSUM:                                              ║
║  Aggiunge un checksum a ogni blocco scritto su disco.            ║
║ When the block is read back, the checksum is verified.   ║
║  └── Se non corrisponde → ORA-01578 (block corrupt detected)    ║
║                                                                  ║
║  DB_LOST_WRITE_PROTECT:                                          ║
║  Protegge da "lost writes" — quando l'I/O subsystem conferma    ║
║  una scrittura ma non la esegue realmente. Rarissimo ma          ║
║ devastating. The standby detects the mismatch.                      ║
╚══════════════════════════════════════════════════════════════════╝
```

### 3.2 Abilitare Flashback Database

```sql
-- Sul PRIMARY
sqlplus / as sysdba

-- Verifica FRA configurata
SHOW PARAMETER db_recovery_file_dest;
-- Deve mostrare +FRA e la dimensione

-- Abilita Flashback (richiede FRA con spazio sufficiente)
ALTER DATABASE FLASHBACK ON;

-- Verifica
SELECT flashback_on FROM v$database;
-- YES

-- Configura retention (default 1440 minuti = 24 ore)
ALTER SYSTEM SET db_flashback_retention_target = 2880 SCOPE=BOTH;
-- 2880 min = 48 ore di finestra di flashback
```

> **Flashback Database** allows you to "rewind" the entire database to a point in time in the past. It is essential for **reinstate** after a failover (instead of rebuilding standby with RMAN).

### 3.3 Redo Log Sizing

Oracle MAA raccomanda:

```sql
-- Regola: I redo log dovrebbero essere abbastanza grandi da
-- durare almeno 15-20 minuti prima di un log switch.

-- Verifica frequenza switch
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS hour,
       COUNT(*) AS switches
FROM   v$log_history
WHERE  first_time > SYSDATE - 1
GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY hour;

-- Se hai > 4 switch per ora → i redo log sono troppo piccoli!

-- Sizing consigliato:
-- Lab:        200 MB (sufficiente per il workload del lab)
-- Produzione: 1-4 GB (dipende dal workload)
-- Big OLTP:   4-8 GB

-- Ridimensionare (se necessario):
-- 1. Aggiungi nuovi gruppi più grandi
ALTER DATABASE ADD LOGFILE THREAD 1 GROUP 11 ('+DATA') SIZE 1G;
ALTER DATABASE ADD LOGFILE THREAD 1 GROUP 12 ('+DATA') SIZE 1G;
-- 2. Switch ai nuovi
ALTER SYSTEM SWITCH LOGFILE;  -- ripeti N volte
-- 3. Quando i vecchi sono INACTIVE, droppali
ALTER DATABASE DROP LOGFILE GROUP <old_group_number>;
```

### 3.4 Fast-Start Failover (FSFO)

```
╔══════════════════════════════════════════════════════════════════╗
║               FSFO — FAILOVER AUTOMATICO                         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║   ┌──────────┐      ┌──────────┐      ┌──────────┐              ║
║ │ PRIMARY │◄────►│ STANDBY │◄────►│ OBSERVER │ ║
║   │ (RACDB)  │      │ (STBY)   │      │ (3° host)│              ║
║   └──────────┘      └──────────┘      └──────────┘              ║
║                                                                  ║
║ Observer continuously monitors Primary and Standby.             ║
║ If the Primary is unreachable for FastStartFailoverThreshold ║
║ seconds (default 30), the Observer orders Standby to ║
║   diventare Primary AUTOMATICAMENTE.                             ║
║                                                                  ║
║   REQUISITI:                                                     ║
║   ✓ DG Broker configurato                                       ║
║   ✓ Flashback Database ON su entrambi                            ║
║ ✓ Standby Redo Logs configured ║
║ ✓ A third host for the Observer (can be dbtarget) ║
╚══════════════════════════════════════════════════════════════════╝
```

```bash
# Configurare FSFO
dgmgrl sys/<password>@RACDB

# 1. Abilita Flashback su entrambi
DGMGRL> EDIT DATABASE 'RACDB' SET PROPERTY FlashbackOn = 'YES';
DGMGRL> EDIT DATABASE 'RACDB_STBY' SET PROPERTY FlashbackOn = 'YES';

# 2. Configura FSFO
DGMGRL> ENABLE FAST_START FAILOVER;
DGMGRL> EDIT CONFIGURATION SET PROPERTY FastStartFailoverThreshold = 30;

# 3. Avvia l'Observer (su dbtarget o altro host)
# Da un terzo host:
dgmgrl sys/<password>@RACDB
DGMGRL> START OBSERVER;
# L'Observer rimane attivo in foreground — usa nohup o screen

# 4. Verifica
DGMGRL> SHOW FAST_START FAILOVER;
# Fast-Start Failover: Enabled
# Threshold:           30 seconds
# Observer:            oci-dbcloud (o dbtarget)
```

### 3.5 Verificare FAN

```sql
-- FAN è auto-configurato in RAC 19c
-- Verifica che ONS sia attivo
```

```bash
# Come grid
srvctl status ons
# ONS daemon is running on node rac1
# ONS daemon is running on node rac2

# Test ONS
onsctl ping
# ons is running ...

# Se non funziona:
srvctl start ons
```

---

## 4. Connection String MAA Best Practice

```
# ═══════════════════════════════════════════════════════
# CONNECTION STRING OTTIMIZZATA (per applicazioni)
# ═══════════════════════════════════════════════════════

ORCL_HA =
  (DESCRIPTION =
    (CONNECT_TIMEOUT = 15)
    (TRANSPORT_CONNECT_TIMEOUT = 3)
    (RETRY_COUNT = 3)
    (RETRY_DELAY = 3)
    (FAILOVER = ON)
    (ADDRESS_LIST =
      (LOAD_BALANCE = ON)
      (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan)(PORT = 1521))
    )
    (ADDRESS_LIST =
      (LOAD_BALANCE = ON)
      (ADDRESS = (PROTOCOL = TCP)(HOST = racstby-scan)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ORCL_OLTP)
    )
  )
```

> **Explanation**: This connection string tests the primary cluster first (rac-scan), then the standby (racstby-scan). With `RETRY_COUNT=3` and `RETRY_DELAY=3`, the application waits up to 9 seconds before failing — long enough for an automatic switchover.

---

## 5. Azioni Consigliate per il Lab

| # | Azione | Priority | Tempo | Guide |
|---|---|---|---|---|
| 1 | `DB_BLOCK_CHECKING = MEDIUM` | Alta | 1 min | Sez. 3.1 |
| 2 | `DB_BLOCK_CHECKSUM = TYPICAL` | Alta | 1 min | Sez. 3.1 |
| 3 | `DB_LOST_WRITE_PROTECT = TYPICAL` | Alta | 1 min | Sez. 3.1 |
| 4 | Flashback Database ON | Alta | 5 min | Sez. 3.2 |
| 5 | Verificare Redo Log sizing | Media | 10 min | Sez. 3.3 |
| 6 | FSFO with Observer on dbtarget | Bassa | 15 min | Sez. 3.4 |
| 7 | Verificare FAN/ONS | Bassa | 2 min | Sez. 3.5 |
| 8 | Connection string HA | Media | 5 min | Sez. 4 |

> After applying all the fixes: **the lab will be MAA GOLD compliant** 🥇

---

> **Next**: Return to [README.md](./README.md) for the complete index of all guides.
