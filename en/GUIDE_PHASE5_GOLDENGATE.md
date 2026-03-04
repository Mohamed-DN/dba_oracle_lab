# PHASE 5: GoldenGate Configuration (Standby Extract → Target Replicat)

> Configure Oracle GoldenGate to capture changes from the standby database (Active Data Guard) and replicate them to an independent target database (`dbtarget`).

### Architecture: Downstream Integrated Extract

```
┌────────────────┐      Redo Shipping       ┌──────────────────┐
│  RAC PRIMARY   │ ─────────────────────────→│  RAC STANDBY     │
│  (RACDB)       │                           │  (RACDB_STBY)    │
│                │                           │  Active DG       │
└────────────────┘                           │                  │
                                             │  ┌────────────┐  │
                                             │  │ GG Extract │  │     Trails
                                             │  │ (Integrated│──│──────────→ ┌──────────────┐
                                             │  │  Capture)  │  │            │  dbtarget    │
                                             │  └────────────┘  │            │  ┌─────────┐ │
                                             └──────────────────┘            │  │GG Repli-│ │
                                                                             │  │cat      │ │
                                                                             │  └─────────┘ │
                                                                             └──────────────┘
```

> **Why extract from standby, not primary?** 1) Zero impact on primary. 2) If primary dies, Extract continues on standby. 3) Oracle best practice.

---

## Setup Summary

1. **Enable GG**: `ALTER SYSTEM SET enable_goldengate_replication=TRUE` on all 3 databases
2. **Supplemental Logging**: `ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS` on primary
3. **Create GG user**: `ggadmin` with DBA + GoldenGate privileges on primary + target
4. **Install GG** on standby (`racstby1`) and target (`dbtarget`)

> 📸 **SNAPSHOT — "SNAP-16: Pre-GoldenGate"** 🔴

5. **Configure Manager** on both (port 7809)
6. **Configure Extract** (Integrated) on standby
7. **Configure Data Pump** on standby → ships trails to target
8. **Configure Replicat** (Integrated) on target
9. **Initial Load** via Data Pump export/import
10. **Start processes** in order: Extract → Pump → Replicat

### Verification
```
GGSCI> INFO ALL
-- All processes RUNNING with lag < 10 seconds
```

> 📸 **SNAPSHOT — "SNAP-17: GoldenGate Running"** ⭐ FINAL MILESTONE

---

**→ Next: [PHASE 6: Testing](./GUIDE_PHASE6_TESTING.md)**
