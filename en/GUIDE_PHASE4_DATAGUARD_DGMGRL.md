# PHASE 4: Data Guard Broker Configuration (DGMGRL)

> Data Guard Broker is the centralized "control panel" for managing Data Guard. Without Broker you could manage everything manually, but Broker greatly simplifies switchover, failover, and monitoring.

### Switchover vs Failover — The Crucial Difference

```
  SWITCHOVER (Planned, 0 data loss)             FAILOVER (Emergency!)
  ═════════════════════════════════             ═══════════════════════

  BEFORE:                                       BEFORE:
  ┌────────┐    redo    ┌────────┐              ┌────────┐    redo    ┌────────┐
  │PRIMARY │───────────►│STANDBY │              │PRIMARY │───────────►│STANDBY │
  │ RACDB  │            │RACDB_  │              │ RACDB  │     ✕      │RACDB_  │
  │  OPEN  │            │  STBY  │              │  💀    │   DEAD!    │  STBY  │
  └────────┘            └────────┘              └────────┘            └────────┘

  AFTER:                                        AFTER:
  ┌────────┐    redo    ┌────────┐              ┌────────┐             ┌────────┐
  │STANDBY │◄───────────│PRIMARY │              │  ???   │             │PRIMARY │
  │ RACDB  │            │RACDB_  │              │Requires│             │RACDB_  │
  │(ex-pri)│            │  STBY  │              │REINSTATE             │  STBY  │
  └────────┘            └────────┘              │or redo │             └────────┘
                                                │Phase 3 │
  ✅ Roles reversed     ✅ Zero data loss        └────────┘
  ✅ Reversible          ✅ ~30 seconds           ⚠️ Possible data loss
                                                 ⚠️ Old primary needs rebuild
```

---

## 4.1 Enable Data Guard Broker

```sql
-- On ALL nodes (primary AND standby)
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';
```

## 4.2 Create Broker Configuration

```bash
dgmgrl sys/<password>@RACDB
```
```
CREATE CONFIGURATION dg_config AS PRIMARY DATABASE IS RACDB CONNECT IDENTIFIER IS RACDB;
ADD DATABASE RACDB_STBY AS CONNECT IDENTIFIER IS RACDB_STBY MAINTAINED AS PHYSICAL;
ENABLE CONFIGURATION;
```

> 📸 **SNAPSHOT — "SNAP-13: Pre-DGMGRL"** — Before ENABLE CONFIGURATION

## 4.3 Verify

```
DGMGRL> SHOW CONFIGURATION;    -- Must show: SUCCESS
DGMGRL> SHOW DATABASE RACDB_STBY;
-- Transport Lag: 0 seconds | Apply Lag: 0 seconds | Status: SUCCESS
```

> 📸 **SNAPSHOT — "SNAP-14: DGMGRL SUCCESS"** ⭐

## 4.4 Protection Modes

```
╔═══════════════════╦══════════════════╦══════════════╦═══════════════════════╗
║ Mode              ║ Data Loss?       ║ Performance  ║ If standby dies?      ║
╠═══════════════════╬══════════════════╬══════════════╬═══════════════════════╣
║ Max Performance   ║ Possible         ║ ⚡ High      ║ Primary continues     ║
║ (ASYNC - default) ║ (few seconds)    ║              ║ without issues        ║
╠═══════════════════╬══════════════════╬══════════════╬═══════════════════════╣
║ Max Availability  ║ Zero (if standby ║ ⚡⚡ Medium  ║ Fallback to ASYNC,    ║
║ (SYNC + fallback) ║ reachable)       ║              ║ primary continues     ║
╠═══════════════════╬══════════════════╬══════════════╬═══════════════════════╣
║ Max Protection    ║ Zero (absolute!) ║ 🐢 Low      ║ ⛔ PRIMARY STOPS!!!   ║
║ (SYNC mandatory)  ║                  ║              ║                       ║
╚═══════════════════╩══════════════════╩══════════════╩═══════════════════════╝
```

## 4.5 Switchover Test

```
DGMGRL> VALIDATE DATABASE RACDB_STBY;  -- Must show "Ready for Switchover: Yes"
DGMGRL> SWITCHOVER TO RACDB_STBY;
DGMGRL> SHOW CONFIGURATION;            -- Roles are now reversed!
DGMGRL> SWITCHOVER TO RACDB;            -- Restore original roles
```

> 📸 **SNAPSHOT — "SNAP-15: Switchover OK"**

## 4.7 Active Data Guard

```sql
ALTER DATABASE OPEN READ ONLY;
SELECT open_mode FROM v$database;  -- READ ONLY WITH APPLY
```

---

**→ Next: [PHASE 5: GoldenGate](./GUIDE_PHASE5_GOLDENGATE.md)**
