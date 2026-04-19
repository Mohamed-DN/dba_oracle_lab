# Oracle Glossary — All Lab Acronyms

> Quick reference for all Oracle terms and acronyms used in this repository.

---

## Database Architecture

| Term | Definition |
|---------|------------|
| **CDB** | Container Database — the "container" database that hosts PDBs |
| **PDB** | Pluggable Database — a "pluggable" database inside a CDB |
| **SGA** | System Global Area — shared database memory (buffer cache, shared pool, etc.) |
| **PGA** | Program Global Area — private memory for each session/process |
| **DBID** | Database IDentifier — unique number identifying a database (used by RMAN) |
| **SCN** | System Change Number — database change counter (the "logical timestamp") |
| **REDO** | Transactional log file — records every change for recovery |
| **UNDO** | Rollback segment — stores "before" values for rollback and read consistency |
| **FRA** | Fast Recovery Area — disk area for backups, archivelogs, flashback logs |
| **BCT** | Block Change Tracking — file that tracks modified blocks to speed up incremental backups |
| **SPFILE** | Server Parameter File — binary file with database parameters |
| **PFILE** | Parameter File — text file with parameters (init.ora, used as fallback) |

## Processes

| Termine | Definizione |
|---------|------------|
| **LGWR** | Log Writer — writes the redo buffer to redo log files (COMMIT) |
| **DBWR/DBWn** | Database Writer — writes dirty blocks from the buffer cache to datafiles |
| **ARCH/ARCn** | Archiver — copies full redo logs into archivelogs (ARCHIVELOG mode) |
| **CKPT** | Checkpoint — updates datafile headers with the latest SCN |
| **SMON** | System Monitor — automatic recovery at startup, cleanup |
| **PMON** | Process Monitor — cleanup of dead sessions, release of orphaned locks |
| **MMON** | Manageability Monitor — collects AWR statistics, launches ADDM |
| **MRP0** | Managed Recovery Process — applies redo on the standby (Data Guard) |
| **RFS** | Remote File Server — receives redo from the primary (Data Guard) |
| **DMON** | Data Guard Monitor — the Broker process |
| **RVWR** | Recovery Writer — writes flashback logs |

## RAC (Real Application Clusters)

| Termine | Definizione |
|---------|------------|
| **RAC** | Real Application Clusters — multiple Oracle instances on different nodes, one shared database |
| **ASM** | Automatic Storage Management — Oracle volume manager for shared disks |
| **CRS** | Cluster Ready Services — Oracle's clustering framework |
| **OCR** | Oracle Cluster Registry — cluster configuration (which resources, where) |
| **OLR** | Oracle Local Registry — local copy of the OCR on each node |
| **VIP** | Virtual IP — virtual IP that migrates between nodes for HA |
| **SCAN** | Single Client Access Name — VIP + DNS round-robin for client connections |
| **Cache Fusion** | RAC mechanism for sharing blocks between instances via interconnect |
| **GES** | Global Enqueue Service — manages distributed locks between RAC nodes |
| **GCS** | Global Cache Service — manages block transfer between nodes |
| **HAIP** | High Availability IP — redundant IP for RAC interconnect |

## Data Guard

| Termine | Definizione |
|---------|------------|
| **DG** | Data Guard — Oracle technology for synchronous/asynchronous database replication |
| **DGMGRL** | Data Guard Manager (CLI) — the command-line client for managing the Broker |
| **Broker** | Data Guard Broker — automatic Data Guard management framework |
| **FAL** | Fetch Archive Log — mechanism for requesting missing archivelogs |
| **FSFO** | Fast-Start Failover — automatic failover with Observer |
| **Observer** | Process that monitors Primary/Standby and initiates FSFO |
| **MaxPerformance** | Protection mode: no impact on Primary (ASYNC) |
| **MaxAvailability** | Protection mode: synchronous but degrades to async if standby unreachable |
| **MaxProtection** | Protection mode: absolute synchronous, Primary stops if standby does not respond |
| **ADG** | Active Data Guard — standby open in READ ONLY with active apply |

## RMAN

| Termine | Definizione |
|---------|------------|
| **RMAN** | Recovery Manager — Oracle tool for backup and recovery |
| **Backupset** | Native RMAN format: contains only used blocks (compact) |
| **Image Copy** | 1:1 copy of datafiles (like `cp`, but managed by RMAN) |
| **Level 0** | Base incremental backup: copies all blocks |
| **Level 1** | Incremental backup: copies only blocks changed since Level 0 |
| **PITR** | Point-In-Time Recovery — restore to a specific point in time |
| **TSPITR** | Tablespace Point-In-Time Recovery |
| **DBPITR** | Database Point-In-Time Recovery |

## GoldenGate

| Termine | Definizione |
|---------|------------|
| **GG/OGG** | Oracle GoldenGate — real-time logical replication |
| **Extract** | GG process that captures changes from redo logs |
| **Pump** | Secondary GG process that transports trails over the network |
| **Replicat** | GG process that applies changes to the target database |
| **Trail** | GG binary file containing captured transactions |
| **GGSCI** | GoldenGate Software Command Interface — GoldenGate CLI |
| **MGR** | Manager — GoldenGate supervisor process |
| **DEFGEN** | Definition Generator — generates table definition files for heterogeneous targets |

## Performance

| Termine | Definizione |
|---------|------------|
| **AWR** | Automatic Workload Repository — persistent performance statistics |
| **ASH** | Active Session History — real-time sampling of active sessions |
| **ADDM** | Automatic Database Diagnostic Monitor — automatic AWR analysis |
| **SQL Profile** | Set of hints the optimizer uses for a specific query |
| **SQL Plan Baseline** | "Frozen" execution plan for a query |
| **Wait Event** | What a session is waiting for (I/O, lock, CPU, etc.) |
| **DB Time** | Total time spent by sessions in the database |

## High Availability

| Termine | Definizione |
|---------|------------|
| **HA** | High Availability |
| **MAA** | Maximum Availability Architecture — Oracle architecture for maximum HA |
| **TAF** | Transparent Application Failover — automatic client reconnect |
| **FCF** | Fast Connection Failover — rapid failover based on FAN events |
| **FAN** | Fast Application Notification — push events from cluster to clients |
| **CLB** | Connection Load Balancing — balancing connections between nodes |
| **RLB** | Runtime Load Balancing — dynamic balancing based on load |
| **RPO** | Recovery Point Objective — maximum data loss allowable ("how much data can I lose?") |
| **RTO** | Recovery Time Objective — maximum restore time ("how long am I down?") |

## Security

| Termine | Definizione |
|---------|------------|
| **TDE** | Transparent Data Encryption — encryption of datafiles at rest |
| **NNE** | Native Network Encryption — encryption of network connections |
| **Wallet** | Oracle keystore for encryption keys and certificates |

## Tools

| Termine | Definizione |
|---------|------------|
| **OEM/EM** | Oracle Enterprise Manager — centralized monitoring console |
| **OMS** | Oracle Management Service — central Enterprise Manager server |
| **OPatch** | Oracle tool for applying patches to binaries |
| **OUI** | Oracle Universal Installer |
| **sqlplus** | Oracle command-line SQL client |
| **adrci** | Automatic Diagnostic Repository Command Interpreter |
| **orachk** | Oracle tool for automated health check |
| **expdp/impdp** | Data Pump Export/Import |
