# Oracle Database Architecture — Concepts Explained

> Understanding the internal mechanics of Oracle before you start building.

## Oracle Instance vs Database

```
                    ┌───────────────────────────────────────────┐
                    │            ORACLE INSTANCE                │
                    │         (Lives in MEMORY)                 │
                    │                                           │
                    │  ┌─────────────────────────────────────┐  │
                    │  │           SGA (System Global Area)  │  │
                    │  │  ┌───────────┐  ┌────────────────┐  │  │
                    │  │  │ DB Buffer │  │ Shared Pool    │  │  │
                    │  │  │ Cache     │  │ (SQL cache,    │  │  │
                    │  │  │ (data     │  │  dictionary    │  │  │
                    │  │  │  blocks)  │  │  cache)        │  │  │
                    │  │  └───────────┘  └────────────────┘  │  │
                    │  │  ┌───────────┐  ┌────────────────┐  │  │
                    │  │  │ Redo Log  │  │ Large Pool     │  │  │
                    │  │  │ Buffer    │  │ (RMAN, shared  │  │  │
                    │  │  │           │  │  servers)      │  │  │
                    │  │  └───────────┘  └────────────────┘  │  │
                    │  └─────────────────────────────────────┘  │
                    │                                           │
                    │  ┌─────────────────────────────────────┐  │
                    │  │ Background Processes                │  │
                    │  │ DBWR  LGWR  CKPT  SMON  PMON  ARCn │  │
                    │  └─────────────────────────────────────┘  │
                    │                                           │
                    │  ┌─────────────────────────────────────┐  │
                    │  │ PGA (Private per session)           │  │
                    │  │ Sort area, hash area, session data  │  │
                    │  └─────────────────────────────────────┘  │
                    └──────────────────┬────────────────────────┘
                                       │
                                       │ Reads/Writes
                                       ▼
                    ┌───────────────────────────────────────────┐
                    │            ORACLE DATABASE                │
                    │          (Lives on DISK)                  │
                    │                                           │
                    │  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
                    │  │ Datafiles│ │ Redo Logs│ │ Control  │ │
                    │  │ (.dbf)   │ │ (.log)   │ │ File     │ │
                    │  │ Your     │ │ Change   │ │ DB map   │ │
                    │  │ actual   │ │ journal  │ │ metadata │ │
                    │  │ data     │ │          │ │          │ │
                    │  └──────────┘ └──────────┘ └──────────┘ │
                    │  ┌──────────┐ ┌──────────┐              │
                    │  │ Temp     │ │ Archive  │              │
                    │  │ Files    │ │ Logs     │              │
                    │  │ (sorts)  │ │ (history)│              │
                    │  └──────────┘ └──────────┘              │
                    └───────────────────────────────────────────┘
```

## Key Concepts

### Redo Logs — The "Black Box" of Oracle
Every change (INSERT, UPDATE, DELETE) is FIRST written to the Redo Log Buffer, then flushed to Online Redo Log files by LGWR. This guarantees crash recovery: even if the server loses power mid-transaction, Oracle replays the redo logs on restart.

### Undo — Time Travel for Data
Before Oracle modifies a row, it saves the old version in the Undo tablespace. This enables: read consistency (other sessions see old data during your transaction), rollback (ROLLBACK undoes your changes), and Flashback Query.

### ASM (Automatic Storage Management)
ASM is Oracle's own volume manager + filesystem. It stripes data across disks automatically, provides mirroring (Normal/High redundancy), and is required for RAC shared storage.

### Cache Fusion (RAC specific)
When rac1 needs a data block that's in rac2's buffer cache, Cache Fusion transfers it directly over the interconnect (memory-to-memory). No disk I/O needed. This is why the private interconnect must be fast and dedicated.

```
  rac1: "I need block #42"
    │
    │   GCS (Global Cache Service)
    ├──────────────────────────────────►  rac2: "I have it in my cache"
    │                                         │
    │   Block #42 transferred via              │
    │◄─────────────────────────────────────────┘
    │   interconnect (RAM to RAM)
    │
    ▼
  rac1 now has block #42
  (no disk read needed!)
```

### Logical vs Physical Structure

```
LOGICAL (How YOU see it)              PHYSICAL (How ORACLE stores it)
════════════════════                  ══════════════════════════════

Database                              Datafiles (.dbf)
  └── Tablespace (USERS)              ├── users01.dbf
       └── Segment (TABLE)            ├── system01.dbf
            └── Extent (group of      ├── sysaux01.dbf
                 blocks)              ├── undotbs01.dbf
                 └── Block (8KB       └── temp01.dbf
                      smallest        
                      unit)           Redo Log Files (.log)
                                      ├── redo01.log
                                      ├── redo02.log
                                      └── redo03.log

                                      Control Files (.ctl)
                                      └── control01.ctl
```
