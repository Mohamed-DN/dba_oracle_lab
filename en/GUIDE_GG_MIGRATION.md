# Guide: Zero-Downtime Database Migration with GoldenGate

> Migrate a database from one system to another with **near-zero downtime** (~5 minutes).

---

## Migration Architecture

```
PHASE 1: Initial Load (Data Pump export/import)
  SOURCE ══expdp/impdp══► TARGET

PHASE 2: CDC Sync (GoldenGate captures changes since export SCN)
  SOURCE ══GG Extract══► TARGET (GG Replicat)

PHASE 3: Cutover (~5 min downtime)
  SOURCE ⛔ STOP → TARGET ✅ ACTIVE
```

## Steps

### 1. Enable Prerequisites

```sql
-- On SOURCE
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
```

### 2. Initial Load

```bash
expdp SCHEMAS=HR,FINANCE FLASHBACK_TIME=SYSTIMESTAMP DUMPFILE=migration.dmp
# Note the SCN from the log file!
impdp SCHEMAS=HR,FINANCE DUMPFILE=migration.dmp  # On TARGET
```

### 3. Configure GG Extract from Export SCN

```
ADD EXTRACT ext_migr, INTEGRATED TRANLOG, SCN 12345678
ADD EXTTRAIL ./dirdat/em, EXTRACT ext_migr
```

### 4. Configure Pump + Replicat

Standard GG pump (source→target) + Integrated Replicat with `HANDLECOLLISIONS`.

### 5. Wait for Sync (Lag = 0)

### 6. Cutover

```
1. Stop application
2. Verify lag = 0
3. Verify COUNT(*) source == target
4. Stop GG processes
5. Reconfigure app connection → TARGET
6. Restart app → Done! 🎉
```

## Rollback Strategy

Configure **bidirectional GG** (target→source) before cutover for safety.

---

**Total downtime: ~5 minutes**
