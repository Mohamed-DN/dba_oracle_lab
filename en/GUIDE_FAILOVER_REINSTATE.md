# Complete Guide: Data Guard Failover + Reinstate

> Failover is an **emergency** operation when the Primary is DOWN and cannot be recovered in time.

---

## Switchover vs Failover

| | Switchover | Failover |
|---|---|---|
| When? | Planned maintenance | Emergency — Primary dead! |
| Data loss? | ZERO (always) | Possible (MaxPerformance) |
| Primary alive? | Yes | NO — it crashed! |
| Reversible? | Switchback | Requires REINSTATE |

---

## Execute Failover

```bash
# 1. Verify Primary is truly dead
ssh root@rac1  # Timeout? → confirmed dead

# 2. Failover
dgmgrl sys/<password>@RACDB_STBY
FAILOVER TO RACDB_STBY;

# 3. Verify
SHOW CONFIGURATION;
# RACDB_STBY = Primary, RACDB = disabled
```

## Reinstate Old Primary

### Option A: Flashback (Fast — minutes)

```sql
-- On old primary (after restart)
STARTUP MOUNT;
FLASHBACK DATABASE TO SCN <failover_scn>;
ALTER DATABASE CONVERT TO PHYSICAL STANDBY;
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
```

```bash
dgmgrl> REINSTATE DATABASE RACDB;
```

### Option B: RMAN Duplicate (Slow — 30-60 min)

Rebuild from scratch using `RMAN DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE`.

## Fast-Start Failover (Automatic)

```bash
dgmgrl> ENABLE FAST_START FAILOVER;
dgmgrl> START OBSERVER;  # Run on 3rd machine (dbtarget)
```

If Primary doesn't respond for 30 seconds → **automatic failover**!

---

## Decision Tree

```
Primary down? → Can restart in < 5 min?
  YES → Restart, auto-recovery       NO → FAILOVER!
                                        → Old Primary back?
                                          YES + Flashback → REINSTATE
                                          YES no Flashback → RMAN DUPLICATE
                                          NO → Rebuild server + RMAN DUPLICATE
```
