# PHASE 3: RAC Standby Creation (RMAN Duplicate)

> This phase covers preparing standby nodes (`racstby1`, `racstby2`) and creating the physical standby database using RMAN Duplicate from Active Database.

### What Happens in This Phase

```
  BEFORE                                          AFTER
  ══════                                          ═════

┌─────────────┐                          ┌─────────────┐
│ RAC PRIMARY │                          │ RAC PRIMARY │
│   RACDB     │                          │   RACDB     │
│ ┌────┐┌────┐│                          │ ┌────┐┌────┐│
│ │DB1 ││DB2 ││                          │ │DB1 ││DB2 ││
│ └────┘└────┘│                          │ └────┘└────┘│
│ rac1  rac2  │                          │ rac1  rac2  │
└─────────────┘                          └──────┬──────┘
                                                │ Redo Shipping
                                                │ (LGWR ASYNC)
┌─────────────┐                                 ▼
│ RAC STANDBY │   RMAN Duplicate     ┌──────────────────┐
│  (empty)    │  ═══════════════►    │ RAC STANDBY      │
│ Grid + SW   │   Copies DB over     │ RACDB_STBY       │
│ NO database │   network in         │ ┌────┐ ┌────┐   │
│ racstby1/2  │   real-time!         │ │DB1 │ │DB2 │   │
└─────────────┘                      │ └────┘ └────┘   │
                                     │ MRP: Applies redo│
                                     │ in real-time     │
                                     └──────────────────┘
```

---

## Prerequisites

- ✅ Phase 1 complete on racstby1/racstby2
- ✅ Grid Infrastructure installed on standby
- ✅ DB Software installed (Software Only, NO database created)
- ✅ DATA and FRA disk groups exist on standby with same names as primary

---

## 3.2-3.3 Static Listener Configuration

Both primary and standby need static listener entries for Data Guard (dynamic PMON registration isn't enough when DB is in MOUNT state).

```
# Add to listener.ora (grid user) on primary (rac1):
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = RACDB_DGMGRL)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = RACDB1)))
```

> **Why Static Listener?** When the database is in MOUNT (not OPEN), PMON doesn't register with the listener dynamically. But Data Guard needs to connect to a database in MOUNT to apply redo.

---

## 3.4 TNS Names Configuration

`tnsnames.ora` must be identical on ALL nodes (primary and standby). Key entries: RACDB, RACDB_STBY, RACDB1, RACDB2, RACDB1_STBY, RACDB2_STBY.

---

## 3.5 Primary Data Guard Configuration

### How Redo Shipping Works

```
PRIMARY (RACDB)                              STANDBY (RACDB_STBY)
════════════════                              ═════════════════════

User does COMMIT
     │
     ▼
┌──────────┐                                  
│  LGWR    │──── Writes ───►┌──────────────┐  
│          │                │ Online Redo  │  
│          │                │ Log (local)  │  
│          │                └──────┬───────┘  
│          │                       │          
│          │── Ships ─────────────────────────►┌──────────────┐
│          │   (ASYNC over network)            │ Standby Redo │
└──────────┘                                   │ Log (SRL)    │
                                               └──────┬───────┘
                                                      │
                                                      ▼
                                               ┌──────────────┐
                                               │  MRP (Managed│
                                               │  Recovery    │
                                               │  Process)    │
                                               │              │
                                               │  Applies redo│
                                               │  to datafiles│
                                               └──────────────┘
```

Key parameters to set:
```sql
ALTER SYSTEM SET log_archive_config='DG_CONFIG=(RACDB,RACDB_STBY)' SCOPE=BOTH SID='*';
ALTER SYSTEM SET log_archive_dest_2='SERVICE=RACDB_STBY LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB_STBY' SCOPE=BOTH SID='*';
ALTER SYSTEM SET fal_server='RACDB_STBY' SCOPE=BOTH SID='*';
ALTER SYSTEM SET standby_file_management=AUTO SCOPE=BOTH SID='*';
```

---

## 3.10 RMAN Duplicate from Active Database

> 📸 **SNAPSHOT — "SNAP-11: Pre-Duplicate"** 🔴 CRITICAL — Take on ALL VMs!

```bash
rman TARGET sys/<password>@RACDB AUXILIARY sys/<password>@RACDB1_STBY
```

```rman
DUPLICATE TARGET DATABASE
  FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
    SET db_unique_name='RACDB_STBY'
    SET cluster_database='TRUE'
    SET remote_listener='racstby-scan.oracleland.local:1521'
    SET fal_server='RACDB'
  NOFILENAMECHECK;
```

> - `FOR STANDBY`: Creates a standby, not a clone
> - `FROM ACTIVE DATABASE`: Copies datafiles directly over network
> - `DORECOVER`: Automatically applies missing archivelogs
> - Operation takes 20-60 minutes

---

## 3.12 Start Redo Apply

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;
```

> `USING CURRENT LOGFILE` enables **Real-Time Apply**: standby applies redo as soon as it arrives, without waiting for archivelog completion.

> 📸 **SNAPSHOT — "SNAP-12: RMAN Duplicate Complete"** ⭐ MILESTONE

---

**→ Next: [PHASE 4: Data Guard Broker (DGMGRL)](./GUIDE_PHASE4_DATAGUARD_DGMGRL.md)**
