# Complete Guide: Failover Data Guard + Reinstate of the Old Primary

> Failover is the **emergency** operation when the Primary is DEAD and cannot be recovered in time. Unlike switchover, failover can cause **data loss** (depends on protection mode).

---

## ⚠️ AVVERTENZA LAB: Snapshot VirtualBox e Test di Failover

> **FREQUENTLY ASKED QUESTION**: *"Since I'm on VirtualBox, can I take a snapshot of all 4 machines, test failover, and then put the snapshots back to quickly go back?"*
> 
> 🛑 **RISPOSTA: ASSOLUTAMENTE NO! Corromperai tutto il cluster.**
> 
> **Why?** In VirtualBox, disks configured as **"Shareable"** (like ours `asm_crs`, `asm_data`, etc.) are intentionally **EXCLUDED** from VM snapshots. 
> If you do a failover (writing and modifying shared ASM disks) and then restore the VMs to a previous snapshot, the machines' OS disks will roll back in time, but the ASM disks will remain in the post-failover future state. This will cause a fatal misalignment between the operating system/Clusterware and the data on disk (Split Brain or OCR corruption).
> 
> ✅ **HOW TO TEST SAFELY (Physical Cold Backup):**
> If you want to "save" the state of the entire scenario so you can go back without going crazy with the REINSTATE command, you need to make a **cold physical backup**:
> 1. Do it as you would use a USB stick: **Completely shut down** the 4 VMs (rac1, rac2, racstby1, racstby2).
> 2. Go to the Windows folder where you keep the virtual machines and the virtual disks folder (`.vdi`).
> 3. Right click and **zip/copy-paste** the entire VM folder and the entire folder with all ASM disks into a backup directory (e.g. `Backup_RAC_PreFailover`).
> 4. Accendi le VM, devasta tutto col failover, fai i tuoi test.
> 5. When you're done, shut down the VMs, **delete** the current files, and unzip your physical backup in their place. You'll magically go back to 10 minutes earlier.

---

## Switchover vs Failover — La Differenza Cruciale

```
╔═══════════════════════╦════════════════════════════╦════════════════════════════╗
║                       ║     SWITCHOVER             ║     FAILOVER               ║
╠═══════════════════════╬════════════════════════════╬════════════════════════════╣
║ Quando si usa?        ║ Manutenzione pianificata   ║ EMERGENZA — Primary morto! ║
║ Data loss?            ║ ZERO (sempre)              ║ Possibile (MaxPerformance) ║
║                       ║                            ║ Zero (MaxAvailability)     ║
║ Is Primary active?     ║ Yes ║ NO — it crashed!           ║
║ Reversible?          ║ Yes (switchback) ║ Requires REINSTATE or ║
║ ║ ║ complete reconstruction ║
║ Tempo di downtime     ║ ~30-60 secondi             ║ ~1-5 minuti                ║
║ Comando               ║ SWITCHOVER TO ...          ║ FAILOVER TO ...            ║
╚═══════════════════════╩════════════════════════════╩════════════════════════════╝
```

---

## Scenario: The Primary is Dead

```
┌─────────────────┐                          ┌─────────────────┐
│ RAC PRIMARY │ │ RAC STANDBY │
│  RACDB          │                          │  RACDB_STBY     │
│ │ ✕ DEAD! ✕ │ All redos │
│  💀 💀 💀      │      Nessun redo         │  applicati fino │
│ Server broken │ is shipped!      │ to the last │
│  Disco corrotto │                          │  ricevuto       │
│  Datacenter KO  │                          │                 │
└─────────────────┘                          └─────────────────┘
                                                     │
                    The DBA must decide: │
                    FAILOVER → promuovo lo           │
                    standby to Primary ▼
                                             ┌─────────────────┐
                                             │ NEW PRIMARY │
                                             │  RACDB_STBY     │
                                             │  OPEN (R/W)     │
                                             │  I client si    │
                                             │  connettono QUI │
                                             └─────────────────┘
```

---

## Step 1: Verify that the Primary Is Really Dead

> **Do NOT failover if the Primary is still alive!** If both are open in R/W, you get a **split brain** with irreversible data corruption.

```bash
# Prova a connetterti al Primary
sqlplus sys/<password>@RACDB as sysdba
# Se timeout → il Primary è probabilmente morto

# Prova SSH
ssh root@rac1
ssh root@rac2
# Se entrambi non rispondono → conferma che il Primary è down

# Controlla il DGMGRL
dgmgrl sys/<password>@RACDB_STBY
SHOW CONFIGURATION;
# Se RACDB mostra "Error" → conferma
```

---

## Phase 2: Performing Failover

### With DGMGRL (recommended)

```bash
dgmgrl sys/<password>@RACDB_STBY

# Verifica quanti dati si perderebbero
SHOW DATABASE RACDB_STBY;
# Apply Lag: mostra quanto redo NON è stato ancora applicato

# Failover!
FAILOVER TO RACDB_STBY;
```

### What DGMGRL does internally:

```
1. Stop redo apply on standby
2. Apply all redos received but not yet applied (reduces data loss)
3. Opens standby as Primary
   → ALTER DATABASE ACTIVATE STANDBY DATABASE;
   → oppure FAILOVER TO usando End-Of-Redo (se i redo finali sono disponibili)
4. Change the database_role from PHYSICAL STANDBY to PRIMARY
5. Attiva il redo logging
```

### Check after Failover

```
DGMGRL> SHOW CONFIGURATION;
```

```
Configuration - dg_config
  Protection Mode: MaxPerformance
  Members:
  RACDB_STBY - Primary database ← NOW IT'S THE PRIMARY!
    RACDB - Physical standby (disabled) ← DISABLED!
                                               It's no longer in sync
Configuration Status: SUCCESS
```

```sql
-- Verifica sul nuovo Primary
sqlplus / as sysdba
SELECT name, database_role, open_mode FROM v$database;
-- RACDB_STBY | PRIMARY | READ WRITE

-- Testa il DML
INSERT INTO testdg.test_replica VALUES (8888, 'Post-Failover!', SYSTIMESTAMP);
COMMIT;
-- Se funziona → failover riuscito!
```

---

## Phase 3: Reinstate the Old Primary (FUNDAMENTAL!)

> After a failover, the old Primary (RACDB) is in a "divergent" state — its redos no longer match those of the new Primary. You need to bring it back online as standby.

### Opzione A: Reinstate con Flashback Database (VELOCE — pochi minuti)

> **Prerequisite**: Flashback Database must have been enabled BEFORE the crash!

```sql
-- Verifica sul vecchio Primary (se è ripartito)
sqlplus / as sysdba
SELECT flashback_on FROM v$database;
-- Se YES → puoi usare questa opzione!
```

```bash
# 1. Spegni il vecchio Primary
srvctl stop database -d RACDB

# 2. Avvia in MOUNT
sqlplus / as sysdba
STARTUP MOUNT;

# 3. Flashback al punto PRIMA del failover
# Il SCN di failover si trova nel nuovo Primary:
# SELECT to_char(standby_became_primary_scn) FROM v$database; (sul nuovo primary)
FLASHBACK DATABASE TO SCN <failover_scn>;

# 4. Converti in Standby
ALTER DATABASE CONVERT TO PHYSICAL STANDBY;

# 5. Riavvia
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
```

```bash
# 6. Reinstate con DGMGRL
dgmgrl sys/<password>@RACDB_STBY

REINSTATE DATABASE RACDB;

# 7. Verifica
SHOW CONFIGURATION;
# RACDB_STBY - Primary database
# RACDB      - Physical standby      ← Tornato come standby!
# Configuration Status: SUCCESS
```

### Option B: Complete Reconstruction with RMAN Duplicate (SLOW — 30-60 min)

> If Flashback was not enabled or the old Primary is too divergent.

```bash
# 1. Cancella il vecchio database
sqlplus / as sysdba
STARTUP MOUNT RESTRICT;
DROP DATABASE;

# 2. Rifai l'RMAN Duplicate (come nella Fase 3)
rman TARGET sys/<password>@RACDB_STBY AUXILIARY sys/<password>@RACDB1

DUPLICATE TARGET DATABASE
  FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
    SET db_unique_name='RACDB'
    SET cluster_database='TRUE'
    SET fal_server='RACDB_STBY'
  NOFILENAMECHECK;
```

```bash
# 3. Registra nel DGMGRL
dgmgrl sys/<password>@RACDB_STBY

ENABLE DATABASE RACDB;

SHOW CONFIGURATION;
# SUCCESS → Reinstate completato!
```

---

## Opzione Avanzata: Fast-Start Failover (FSFO) — Failover AUTOMATICO

```
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│ RAC PRIMARY │ │ RAC STANDBY │ │ OBSERVER │
│  RACDB          │        │  RACDB_STBY     │        │  (su dbtarget)  │
│                 │        │                 │        │                 │
│                 │◄══════►│                 │◄══════►│  Monitora lo    │
│ │ DG │ │ │ state of │
│                 │  Redo  │                 │        │  entrambi i DB  │
└─────────────────┘        └─────────────────┘        │                 │
                                                      │  Se Primary     │
                                                      │  muore →        │
                                                      │  FAILOVER       │
                                                      │  AUTOMATICO!    │
                                                      └─────────────────┘
```

```bash
dgmgrl sys/<password>@RACDB

# Configura FSFO
ENABLE FAST_START FAILOVER;

# Avvia l'Observer (su una terza macchina, es. dbtarget)
dgmgrl sys/<password>@RACDB
START OBSERVER;
# L'observer gira in foreground — mettilo in un screen/tmux!
```

> **FSFO**: Se il Primary non risponde per `FastStartFailoverThreshold` seconds (default 30), the Observer automatically orders failover to standby. **Zero human intervention!**

---

## Diagramma Decisionale

```
Is Primary down?
        │
        ├── NO ────→ Is this scheduled maintenance?
        │                    │
        │ ├── YES → SWITCHOVER (→ see switchover guide)
        │                    │
        │                    └── NO → Non fare niente
        │
        └── YES ────→ Can you restart it in < 5 minutes?
                         │
                         ├── YES → Reboot and wait for automatic recovery
                         │
                         └── NO → FAILOVER!
                                    │
                                    └── After → Has Old Primary started again?
                                                  │
                                                  ├── YES → Flashback active?
                                                  │            │
                                                  │ ├── YES → REINSTATE
                                                  │            │
                                                  │            └── NO → RMAN DUPLICATE
                                                  │
                                                  └── NO → Ricostruisci il server,
                                                            poi RMAN DUPLICATE
```
