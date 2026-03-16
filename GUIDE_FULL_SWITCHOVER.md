# Complete Guide: Switchover Data Guard (Step by Step)

> The switchover is a **scheduled** operation that reverses the roles between Primary and Standby with **zero data loss**. It is used for maintenance, patching, or DR testing.

---

## What Happens During a Switchover

```
BEFORE Switchover:
═══════════════════════
┌─────────────────┐      Redo Shipping      ┌─────────────────┐
│ RAC PRIMARY │ ───────────────────────→ │ RAC STANDBY │
│  RACDB          │                          │  RACDB_STBY     │
│  OPEN (R/W)     │                          │  MOUNT o ADG    │
│  ┌────┐ ┌────┐  │                          │  ┌────┐ ┌────┐  │
│  │DB1 │ │DB2 │  │                          │  │DB1 │ │DB2 │  │
│  └────┘ └────┘  │                          │  └────┘ └────┘  │
│  rac1    rac2   │                          │ stby1   stby2   │
└─────────────────┘                          └─────────────────┘
CLIENTS ──→ connect here


DURANTE lo Switchover (~30-60 secondi):
═══════════════════════════════════════
1. DGMGRL closes the Primary (final flush redo)
2. Primary becomes Standby
3. The Standby receives the latest redo and applies it
4. Standby becomes Primary
5. New roles open
⚠️ Clients are disconnected for ~30-60 seconds!


AFTER the Switchover:
═══════════════════
┌─────────────────┐      Redo Shipping      ┌─────────────────┐
│ RAC STANDBY │ ←─────────────────────── │ RAC PRIMARY │
│  RACDB          │                          │  RACDB_STBY     │
│ MOUNT (standby)│ │ OPEN (R/W) │
│  ┌────┐ ┌────┐  │                          │  ┌────┐ ┌────┐  │
│  │DB1 │ │DB2 │  │                          │  │DB1 │ │DB2 │  │
│  └────┘ └────┘  │                          │  └────┘ └────┘  │
│  rac1    rac2   │                          │ stby1   stby2   │
└─────────────────┘                          └─────────────────┘
CLIENTS ──→ connect HERE now
```

---

## Preparation (BEFORE starting)

### 1. Verify that Data Guard is healthy

```bash
dgmgrl sys/<password>@RACDB

SHOW CONFIGURATION;
# Configuration Status: SUCCESS  ← OBBLIGATORIO!
# If it shows WARNING or ERROR → DO NOT proceed, fix it first

SHOW DATABASE RACDB;
SHOW DATABASE RACDB_STBY;
# Entrambi: SUCCESS
```

### 2. Verify that the sync is complete

```sql
-- Sul Primario
SELECT thread#, MAX(sequence#) FROM v$archived_log WHERE applied='YES' 
GROUP BY thread# ORDER BY thread#;

-- Sullo Standby
SELECT thread#, MAX(sequence#) FROM v$archived_log WHERE applied='YES' 
GROUP BY thread# ORDER BY thread#;

--Sequence numbers must match!
```

### 3. Verify that switchover is possible

```
DGMGRL> VALIDATE DATABASE RACDB_STBY;
```

Output atteso:
```
  Ready for Switchover: Yes ← THIS IS OK!
  
  Verify Flashback:      On
  Verify Redo Apply:     Running
  Verify Media Recovery: On
```

> ⚠️ Se mostra "Ready for Switchover: No", controlla i "Warnings" nel report e risolvili.

### 4. Snapshot VirtualBox (CRITICO!)

```bash
# Su TUTTE le macchine
VBoxManage snapshot "rac1" take "PRE-SWITCHOVER"
VBoxManage snapshot "rac2" take "PRE-SWITCHOVER"
VBoxManage snapshot "racstby1" take "PRE-SWITCHOVER"
VBoxManage snapshot "racstby2" take "PRE-SWITCHOVER"
```

---

## Execution of the Switchover

### Step 1: Switchover with DGMGRL

```bash
dgmgrl sys/<password>@RACDB

# Single command — DGMGRL handles everything automatically
SWITCHOVER TO RACDB_STBY;
```

### What DGMGRL does internally:

```
1. Check that all redos have been sent
2. Chiude il database RACDB (Primary → Standby)
   → ALTER DATABASE COMMIT TO SWITCHOVER TO STANDBY WITH SESSION SHUTDOWN
3. Monta RACDB come physical standby
4. Apre RACDB_STBY come Primary
   → ALTER DATABASE COMMIT TO SWITCHOVER TO PRIMARY
5. Avvia redo apply sul nuovo standby (RACDB)
6. Reopens the database if configured for AUTO open
```

### Step 2: Check the new status

```
DGMGRL> SHOW CONFIGURATION;
```

Output atteso:
```
Configuration - dg_config
  Protection Mode: MaxPerformance
  Members:
  RACDB_STBY - Primary database ← ERA Standby, now it's Primary!
    RACDB - Physical standby ← ERA Primary, now it's Standby!

Fast-Start Failover: DISABLED
Configuration Status: SUCCESS
```

### Step 3: Check the instances

```bash
# Sul NUOVO Primary (racstby1)
srvctl status database -d RACDB_STBY
# Instance RACDB_STBY1 is running on node racstby1
# Instance RACDB_STBY2 is running on node racstby2

# Sul NUOVO Standby (rac1)
srvctl status database -d RACDB
# Instance RACDB1 is running on node rac1
# Instance RACDB2 is running on node rac2
```

### Step 4: Verify that redo shipping works in reverse

```sql
-- Sul NUOVO Primary (RACDB_STBY)
SELECT dest_id, status, error FROM v$archive_dest WHERE dest_id = 2;
--STATUS = VALID → redo is sent to the new standby

-- Sul NUOVO Standby (RACDB)
SELECT process, status FROM v$managed_standby WHERE process = 'MRP0';
-- STATUS = APPLYING_LOG→ redo is applied
```

### Step 5: DML test on the new Primary

```sql
sqlplus testdg/testdg123@RACDB_STBY

INSERT INTO test_replica VALUES (7777, 'Switchover completato!', SYSTIMESTAMP);
COMMIT;

--Check on the new standby
sqlplus / as sysdba @RACDB
SELECT * FROM testdg.test_replica WHERE id = 7777;
-- Deve esistere!
```

---

## Switchback (Return to the Original Configuration)

```bash
dgmgrl sys/<password>@RACDB_STBY

# Verify
VALIDATE DATABASE RACDB;
# Ready for Switchover: Yes

# Esegui
SWITCHOVER TO RACDB;

# Verify
SHOW CONFIGURATION;
# RACDB is Primary again
# RACDB_STBYis Standby again
```

---

## Troubleshooting Switchover

| Problema | Causa |Solution|
|---|---|---|
| "Ready for Switchover: No" | Apply lag, redo gap |Wait for lag to drop to 0, force log switch|
| ORA-16467: switchover target is not in sync |Redo not applied| `ALTER SYSTEM SWITCH LOGFILE;` on the primary, wait |
| Switchover stalled |Active sessions resist| Aggiungi `WITH SESSION SHUTDOWN` se manuale |
| New standby does not apply redo | Unreachable listeners | `lsnrctl status` on new standby, check tnsnames |
| ORA-01017 after switchover | File password not synced | Copy `orapw` from new primary to new standby |

---

## Quando Usare lo Switchover

|Scenario| Switchover? |
|---|---|
| Scheduled patching of the primary | ✅ Yes — switchover, patch, switchback |
|Annual DR test| ✅ Yes — check that everything works |
| Migration to new hardware | ✅ Yes — switchover to new HW |
| Primary hardware failure | ❌ No — use **Failover** (see dedicated guide) |
| Data corruption on the primary | ❌ No — usa **Flashback Database** o RMAN restore |
