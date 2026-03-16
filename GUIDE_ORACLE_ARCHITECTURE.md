# Oracle Architecture: Complete Guide to Fundamental Concepts

> This guide explains the architectural concepts that an Oracle DBA must truly master. The goal is not to memorize isolated definitions, but to understand how Oracle reads, writes, retrieves, scales and protects data.

---

## 1. Basic Mental Model

An Oracle database is composed of two distinct parts:

1. the Oracle instance;
2. the physical database on disk.

```text
+---------------------------------------------------------------+
|                        ORACLE INSTANCE                         |
|                                                               |
|SGA (shared memory)|
|  - Database Buffer Cache                                      |
|  - Shared Pool                                                |
|  - Redo Log Buffer                                            |
|  - Large Pool / Java Pool / Streams Pool                      |
|                                                               |
|PGA (Per-Process Private Memory)|
|                                                               |
|Processes|
|  - Server processes                                           |
|  - Background processes                                       |
+-------------------------------+-------------------------------+
                                |
| reads/writes
                                v
+---------------------------------------------------------------+
|                        DATABASE FILES                          |
|                                                               |
|  Datafiles                                                    |
|  Tempfiles                                                    |
|Control files|
|  Online redo logs                                             |
|  Archived redo logs                                           |
|  SPFILE / PFILE                                               |
|  Password file                                                |
|  FRA                                                          |
+---------------------------------------------------------------+
```

Correct definitions:

- `istanza`= memory + processes;
- `database`= set of persistent files;
- quando fai `shutdown immediate`, stop the instance, do not delete the database;
- quando fai `startup`, the instance returns to managing database files.

Key concept:

- the instance is volatile;
- the database is persistent.

Visual block:

```text
           STARTUP
              |
              v
   +-----------------------+
   | NOMOUNT               |
   |SGA + active processes|
   |no control file|
   +-----------------------+
              |
              v
   +-----------------------+
   | MOUNT                 |
   |control file open|
   |known structure|
   +-----------------------+
              |
              v
   +-----------------------+
   | OPEN                  |
   |open datafile and redo|
   | utenti ammessi        |
   +-----------------------+
```

---

## 2. Database Lifecycle: NOMOUNT, MOUNT, OPEN

Oracle does not always start directly in`OPEN`. There are three distinct phases.

### 2.1 NOMOUNT

In `NOMOUNT`, Oracle reads the parameter file and starts the instance.

Available:

- SGA;
- background processes;
- parameter file.

Not available yet:

- control open file;
- mounted datafiles;
- redo logs open for normal use.

Typical use:

- database creation;
- RMAN duplicate;
- recovery of SPFILE;
- bootstrap standby.

### 2.2 MOUNT

In `MOUNT`, Oracle opens the control file and knows the database structure.

Available:

- control file;
- elenco datafile e redo log;
- montage metadata.

Not available yet:

- normal access to data by users.

Typical use:

- media recovery;
- standby databases;
- rename file;
- enable/disable archivelog;
- Data Guard operations.

### 2.3 OPEN

In `OPEN`, Oracle opens datafiles and redo logs and the database becomes usable.

Common variants:

- `OPEN READ WRITE`;
- `OPEN READ ONLY`;
- `MOUNTED` for physical standby;
- `READ ONLY WITH APPLY` per Active Data Guard.

### 2.4 Shutdown Modes

The main ones are:

- `SHUTDOWN NORMAL`: wait for all users to log out;
- `SHUTDOWN IMMEDIATE`: rollback of uncommitted transactions and clean closure;
- `SHUTDOWN ABORT`: brutal stop, recovery at next startup;
- `SHUTDOWN TRANSACTIONAL`: wait for active transactions to end.

In the lab, the most used is`IMMEDIATE`.

---

## 3. Memory Architecture

Oracle uses two large memory areas:

1. `SGA`shared;
2. `PGA` privata.

Quick diagram:

```text
+-------------------------------------------------------------------+
|                           ORACLE INSTANCE                          |
|                                                                   |
|  +--------------------------- SGA -------------------------------+ |
|  | Buffer Cache | Shared Pool | Redo Buffer | Large/Java/Streams| |
|  +---------------------------------------------------------------+ |
|                                                                   |
|  +--------------------------- PGA -------------------------------+ |
|  |private memory of the single process: sort, hash, stack| |
|  +---------------------------------------------------------------+ |
+-------------------------------------------------------------------+
```

### 3.1 SGA: Instance shared memory

All server and background processes read or write the SGA.

Main components.

#### Database Buffer Cache

Contains blocks of data read from datafiles.

Function:

- reduce physical I/O;
- keep the most used blocks in RAM;
- host blocks that have been modified but not yet written to disk.

Logical states of the blocks:

- `clean`: block equal to disk copy;
- `dirty`: modified in memory, not yet written by DBWn.

Important concept:

- the commit does not wait for the dirty block to be written to the datafile;
- commit waits for redo to disk.

#### Shared Pool

Contains shared structures necessary for SQL execution.

Key Subcomponents:

- `Library Cache`: SQL parsato, PL/SQL, execution plans;
- `Data Dictionary Cache`: metadata of tables, users, objects, privileges.

If the Shared Pool is small or fragmented you can see:

- excessive hard parses;
- invalidations;
- errori `ORA-04031`.

#### Redo Log Buffer

Circular buffer in RAM where Oracle accumulates redo records before LGWR writes them to the online redo logs.

Contains:

- description of the changes;
- not whole blocks, but change vectors.

#### Large Pool

Optional area used by:

- RMAN;
- parallel execution;
- shared server;
- some I/O and messaging operations.

It serves to avoid unnecessary pressure on the Shared Pool.

#### Java Pool

Used if the database runs internal Java components.

#### Streams Pool

Used by streaming and replication features in some scenarios.

### 3.2 PGA: Private Memory

Each Oracle process has its own PGA.

Typically contains:

- sort area;
- hash area;
- stack;
- session or process information;
- cursor state on the process side.

Characteristics:

- it is not shared;
- grows per session or process;
- e' critica per sort, hash join, bitmap merge, parallel execution.

### 3.3 UGA

La `UGA` it is the memory associated with the user session.

It depends on the connection model:

- con `dedicated server`, the UGA is in the PGA of the server process;
- con `shared server`, UGA is in SGA.

### 3.4 Automatic memory management

Main models.

#### ASMM

Automatic Shared Memory Management.

Typical parameters:

- `SGA_TARGET`;
- `SGA_MAX_SIZE`;
- `PGA_AGGREGATE_TARGET`.

It is the most common model in the classic Oracle lab.

#### AMM

Automatic Memory Management.

Typical parameters:

- `MEMORY_TARGET`;
- `MEMORY_MAX_TARGET`.

It can handle SGA and PGA together, but in many real world environments ASMM or explicit tuning is preferred.

---

## 4. Process Architecture

Oracle usa:

1. client processes;
2. listener;
3. server processes;
4. background processes.

### 4.1 Client process

It is the application process or tool that connects to Oracle:

- SQL*Plus;
- JDBC;
- Python;
- web application.

### 4.2 Listeners

The listener receives the network connection and forwards it to the correct service.

Non esegue SQL.

Acts as initial dispatcher:

- listen at the door;
- knows the registered services;
- passes the session to the server process.

### 4.3 Server process

It is the process that actually does the work of the session.

Compiti:

- parse;
- execute;
- fetch;
- access to blocks;
- cursor management;
- interaction with PGA and SGA.

Modelli:

- `dedicated server`: one server process per session;
- `shared server`: Multiple sessions share server resources.

In your lab you almost always use`dedicated server`.

### 4.4 Background processes fondamentali

|Process|Practical role|
|---|---|
| `DBWn` |writes dirty buffers from Buffer Cache to datafiles|
| `LGWR` |writes redo from the Redo Log Buffer to online redo logs|
| `CKPT` |reports checkpoints and updates header/control file|
| `SMON` | instance recovery e housekeeping |
| `PMON` |cleanup of failed processes/sessions|
| `ARCn` |Archive full redo logs in archived redo logs|
| `RECO` |recovering distributed transactions in doubt|
| `MMON` |manageability/AWR statistics collection|
| `MMNL` |MMON support|
| `LREG` | Dynamically registers services and instances to listeners |
| `CJQ0` | coordina job scheduler |
| `RVWR` | scrive flashback logs se Flashback e' attivo |
| `FBDA` | Flashback Data Archive |
| `DMON` | Data Guard Broker |
| `VKTM` |manages internal virtual time|

### 4.5 RAC-specific processes

Cluster-specific processes also appear in RAC, for example:

- `LMON`;
- `LMD`;
- `LMS`;
- `LCK`.

Servono a:

- cache fusion;
- global enqueue service;
- coordination of blocks between instances.

---

## 5. How Oracle Executes a Query

Simplified flow.

```text
1. Client sends SQL
2. Listener forwards to the correct service
3. Server process riceve SQL
4. Parse
5. Bind
6. Execute
7. Reading blocks or accessing indexes
8. Fetch righe al client
```

Mental drawing:

```text
Client
  |
  v
Listener -> Service -> Instance
  |
  v
Server Process
  |
  +--> Parse
  +--> Bind
  +--> Execute
  +--> Fetch
```

### 5.1 Parse

Parse is not just syntactic analysis.

Include:

- syntax check;
- verify objects and privileges;
- optimization;
- scelta execution plan;
- lookup o reuse in Library Cache.

Tipi di parse:

- `hard parse`: need new complete parse;
- `soft parse`: Oracle reuses an existing plan.

DBA Objective:

- ridurre hard parse inutili;
- usare bind variables quando ha senso.

### 5.2 Execute

Durante l'execute Oracle:

- acquisisce lock o enqueue necessari;
- reads requested blocks;
- modify blocks in memory if the SQL changes data;
- genera redo e undo.

### 5.3 Fetch

The rows are returned to the client in subsequent fetches.

Importante:

- a query can be executed once and then fetched many times;
- most of the application time can be spent in fetches, not parse.

---

## 6. Transactions, SCN, Redo, Undo and Consistency

Commit scheme:

```text
Session
  |
  | UPDATE
  v
Server process
  |
+--> change block to Buffer Cache
  +--> genera UNDO
  +--> genera REDO
               |
               v
        Redo Log Buffer
               |
               v
             LGWR
               |
               v
Online Redo Log to disk
               |
               v
           COMMIT OK

DBWn writes the datafiles afterwards.
```

This is the part that separates those who use Oracle from those who understand it.

### 6.1 SCN

Lo `SCN` e' il System Change Number.

It is Oracle's internal time or logical reference.

It is used for:

- order changes;
- guarantee reading consistency;
- recovery;
- flashback;
- Data Guard;
- backup consistency.

### 6.2 Undo

Undo preserves the information needed to:

- rollback uncommitted transactions;
- rebuild previous versions of blocks for consistent queries.

Key concept:

- quando fai `UPDATE`, Oracle doesn't just overwrite the data;
- first record the logical image needed in undo.

### 6.3 Redo

The redo describes all the changes necessary for recovery.

It is used for:

- redo changes after crash;
- alimentare archived redo;
- power Data Guard;
- allow media recovery.

### 6.4 Commit

Un `COMMIT`it does not mean that the datafile is already written.

It means:

- the redo of that transaction has been made durable on the online redo logs;
- from that moment the transaction is committed.

This is why the commit is fast:

- LGWR does sequential writing;
- DBWn writes the datafiles later, with lazy logic.

### 6.5 Read consistency

Oracle ensures that a query sees a consistent snapshot of the data at a logical SCN.

If another session modifies a row while a long query is reading it, Oracle can:

- use the current block if compatible;
- or rebuild the previous version via undo.

This avoids dirty readings.

### 6.6 Checkpoint

The checkpoint does not mean stop.

It means that Oracle:

- update checkpoint information in control file and datafile header;
- reduces the amount of redo to be reread in instance recovery.

### 6.7 Instance recovery vs media recovery

#### Instance recovery

Serves after instance crash but without file loss.

Oracle usa:

- redo online;
- undo.

#### Media recovery

It is useful when you lose or restore physical files.

Oracle usa:

- backup;
- archived redo logs;
- eventuali incremental backup;
- control file or catalog RMAN.

---

## 7. Logical Storage Structures

Oracle separates logical and physical architecture.

Correct logical order:

```text
Database
  -> Tablespace
     -> Segment
        -> Extent
           -> Block
```

### 7.1 Data block

The block is the minimum logical unit of database I/O.

Key Parameters:

- `DB_BLOCK_SIZE`;
- typically 8 KB in the lab.

### 7.2 Extent

An extent is a set of contiguous blocks allocated to a segment.

### 7.3 Segment

A segment is the set of extents belonging to an object.

Common types:

- table segment;
- index segment;
- undo segment;
- temporary segment;
- LOB segment.

### 7.4 Tablespace

A tablespace is the logical container of segments.

Comuni in Oracle:

- `SYSTEM`;
- `SYSAUX`;
- `UNDO`;
- `TEMP`;
- tablespace applicativi.

Important types:

- permanent;
- temporary;
- undo;
- bigfile;
- smallfile.

### 7.5 Bigfile vs smallfile

#### Smallfile tablespace

- multiple datafiles in the same tablespace;
- most common historical model.

#### Bigfile tablespace

- a single very large datafile;
- useful in ASM and automated environments.

---

## 8. Strutture Fisiche di Storage

### 8.1 Datafiles

They contain the permanent and undo tablespace blocks.

They do not contain:

- redo log;
- controlfile.

### 8.2 Tempfiles

Usati per:

- sort;
- hash;
- temporary segments.

Practical Difference:

- they are not recovered like normal datafiles;
- can be recreated.

### 8.3 Control files

They are the minimum physical catalog of the database.

They contain information on:

- nome DB e DBID;
- datafiles and redo logs;
- checkpoint;
- archived log history;
- RMAN metadata minima.

If you lose all control files, the database will not mount.

### 8.4 Online redo logs

I am the active journal of the database.

Organized in:

- gruppi;
- membri.

Concepts:

- a group is used as `CURRENT`;
- at log switch Oracle moves to the next group;
- ARCn archives full groups if the DB is in`ARCHIVELOG`.

### 8.5 Archived redo logs

They are historical copies of the full online redo logs.

They are used for:

- backup e recovery;
- point-in-time recovery;
- standby Data Guard.

### 8.6 SPFILE e PFILE

#### PFILE

- file testuale;
- readable and editable by hand;
- useful for bootstrap and recovery.

#### SPFILE

- file binario server parameter file;
- normally used in production;
- consente `ALTER SYSTEM SET ... SCOPE=SPFILE|BOTH`.

### 8.7 File passwords

Used for remote administrative authentication:

- `SYSDBA`;
- `SYSDG`;
- `SYSBACKUP`;
- `SYSASM`;
- `SYSKM`.

It is critical in:

- RAC;
- Data Guard;
- RMAN duplicate;
- Broker.

### 8.8 FRA

La `Fast Recovery Area`It is an area managed by Oracle for recovery files.

Typically contains:

- archived logs;
- flashback logs;
- backup pieces;
- copies;
- control file autobackups.

If it fills:

- backup and archiving may stop;
- Data Guard can degrade;
- recovery space errors appear.

---

## 9. Writing Flow: UPDATE -> COMMIT

This is the flow you need to know by heart.

```text
1. Session executes UPDATE
2. Oracle reads the block into Buffer Cache if necessary
3. Oracle genera undo
4. Oracle genera redo
5. Oracle changes the block to Buffer Cache
6. The block becomes dirty
7. COMMIT
8. LGWR writes redo to online redo log
9. COMMIT returns OK
10. DBWn will write the dirty block to the datafile later
```

Vista step-by-step:

```text
UPDATE
  |
+--> block read or already in cache
  +--> undo generato
+--> generated redo
+--> block becomes dirty

COMMIT
  |
+--> LGWR forces redo to disk
+--> Oracle confirms the commit

POST-COMMIT
  |
+--> CKPT updates checkpoint info
+--> DBWn downloads the dirty block later
```

Golden rule:

- redo before datafiles;
- questa e' la base del write-ahead logging Oracle.

---

## 10. Oracle Net, Listeners, Services and Dynamic Recording

Visual block:

```text
Application / sqlplus
        |
        v
     Listeners
        |
        | usa SERVICE_NAME
        v
   Service registration
        |
        +--> instance 1
        +--> instance 2
        +--> role-based service Data Guard
```

### 10.1 Listeners

The listener listens for connection requests and forwards them to the correct service.

Typical files:

- `listener.ora`;
- `tnsnames.ora`;
- `sqlnet.ora`.

### 10.2 Service vs SID

`SID`:

- identifies a specific instance.

`SERVICE_NAME`:

- identifies the logical service used by applications.

Best practice:

- applications must use services, not SIDs;
- in RAC and Data Guard, service is the correct concept of access.

### 10.3 Dynamic recording

Il processo `LREG` registers services to the listener.

Parameters involved:

- `LOCAL_LISTENER`;
- `REMOTE_LISTENER`.

In RAC:

- `REMOTE_LISTENER`typically points to SCAN;
- services can do load balancing and failover.

Useful command:

```sql
ALTER SYSTEM REGISTER;
```

It is used to force immediate registration after start listener or service changes.

---

## 11. Multitenant Architecture: CDB and PDB

From the 19c perspective, multitenant architecture is central.

Schema CDB/PDB:

```text
+---------------------------------------------------------------+
|                           CDB ROOT                            |
|processes, memory, redo, undo, common dictionary|
|                                                               |
|  +----------------+  +----------------+  +----------------+   |
|  | PDB$SEED       |  | APP_PDB1       |  | APP_PDB2       |   |
|  | template       |  |app data 1|  |app data 2|   |
|  | read only      |  | local users  |  | local users  |   |
|  +----------------+  +----------------+  +----------------+   |
+---------------------------------------------------------------+
```

### 11.1 Components

Each CDB includes:

- `CDB$ROOT`;
- `PDB$SEED`;
- zero or more user PDBs.

### 11.2 Root

`CDB$ROOT`contains:

- common Oracle metadata;
- common users;
- shared facilities.

This is not the right place for normal application data.

### 11.3 Seed

`PDB$SEED` e' il template read only usato per creare nuovi PDB.

### 11.4 PDB

A PDB appears to the application as a quasi-independent database, but shares with the CDB:

- instance;
- SGA;
- background processes;
- redo logs;
- controlfile.

This is fundamental:

- a CDB with 10 PDBs does not have 10 separate instances;
- has a single instance that manages multiple containers.

### 11.5 Common users e local users

- common user: visible in all containers;
- local user: exists only in the PDB.

### 11.6 Services and PDB

Best practice:

- each application uses a service associated with the PDB;
- in RAC you create the service with`srvctl add service -pdb ...`.

---

## 12. ASM: Automatic Storage Management

ASM is Oracle's storage layer optimized for database files.

Fa da:

- volume manager;
- Oracle specialized file system.

Basic concepts:

- ASM instance;
- disk groups;
- failure groups;
- allocation units;
- template, striping e mirroring.

In your lab you use typical disk groups:

- `+DATA`;
- `+RECO`;
- `+CRS`.

Why ASM is important:

- semplifica naming e placement file;
- supports OMF;
- integrates well with RAC, RMAN, Data Guard.

Visual block:

```text
Database / Grid
      |
      v
   ASM instance
      |
   +--+----------------------+
   |                         |
   v                         v
+DATA                     +RECO
datafile archivelog
controlfile               backup pieces
online redo               flashback logs
spfile/password file copies
```

---

## 13. RAC: Architettura Cluster

RAC means multiple instances opening the same shared database.

Schema RAC:

```text
             +---------------- Shared Storage ----------------+
             | Datafiles / Controlfiles / Redo / SPFILE / ASM |
             +-------------------+-----------------------------+
                                 ^
                                 |
        +------------------------+------------------------+
        |                                                 |
        v                                                 v
+---------------------+                         +---------------------+
| Instance RACDB1     |<-- Cache Fusion / GCS ->| Instance RACDB2     |
| Node rac1           |                         | Node rac2           |
| SGA + PGA + proc    |                         | SGA + PGA + proc    |
+---------------------+                         +---------------------+
```

### 13.1 What the RAC instances share

Condividono:

- datafiles;
- control files;
- online redo logs per thread;
- Shared SPFILE;
- ASM storage.

They don't share:

- PGA;
- buffer cache locale;
- server processes locali.

Each instance has:

- own EMS;
- own processes;
- proprio redo thread;
- proprio undo tablespace.

### 13.2 Cache Fusion

It is the mechanism by which a RAC instance can receive blocks in memory from another instance without going through disk.

It's the key to RAC.

### 13.3 SCAN

Lo `SCAN`it is the virtual name of access to the cluster.

It is used for:

- simplify client connections;
- load balancing;
- failover.

### 13.4 Services in RAC

The services allow you to decide:

- where the workload should run;
- failover;
- applicative role;
- pinning a PDB.

---

## 14. Data Guard: Protection Architecture

Data Guard protects the database with one or more standbys.

Schema redo transport:

```text
PRIMARY (RACDB) STANDBY (RACDB_STBY)

User COMMIT
     |
     v
   LGWR  -------------------- redo transport -------------------->
     |                                                           |
     v                                                           v
Online Redo Log Standby Redo Log
                                                                |
                                                                v
                                                        MRP0 / Redo Apply
                                                                |
                                                                v
                                                          Standby datafile
```

### 14.1 Conceptual components

- primary database;
- standby databases;
- redo transport services;
- apply services;
- Broker opzionale.

### 14.2 Main types of standby

- physical standby;
- logical standby;
- standby snapshot.

In your lab you use physical standby.

### 14.3 Flusso base

```text
Primary generates redo
-> redo transport sends redo
-> standby receives redo (RFS / SRL)
-> apply services apply redo (MRP)
```

### 14.4 Roles and methods

Ruoli:

- `PRIMARY`;
- `PHYSICAL STANDBY`.

Operations:

- switchover;
- failover;
- reinstate.

Protection modes:

- `MaxPerformance`;
- `MaxAvailability`;
- `MaxProtection`.

### 14.5 Broker

The Broker centralizes management with:

- `DGMGRL`;
- Enterprise Manager.

Key Process:

- `DMON`.

---

## 15. Diagnostics: ADR, Alert Log, Trace, AWR, ASH

### 15.1 ADR

The ADR is the Automatic Diagnostic Repository.

Contains:

- alert log;
- trace files;
- accidents;
- homes diagnostics database, listener and ASM.

Main tool:

- `adrci`.

### 15.2 Alert log

It is the operational diary of the database.

Check for:

- ORA errors;
- archiver issues;
- crash recovery;
- Data Guard apply;
- parameter changes;
- startup e shutdown.

### 15.3 Trace files

They contain technical detail for specific processes or errors.

### 15.4 AWR, ASH, ADDM

They are performance and diagnostic tools.

Conceptual use:

- `AWR`: snapshot storici;
- `ASH`: sampling of active sessions;
- `ADDM`: automatic analysis.

Practical note:

- Full AWR, ASH and ADDM require appropriate licenses or packs in production.

---

## 16. Data Dictionary and Dynamic Performance Views

Two fundamental families.

### 16.1 DBA_, ALL_, USER_

Persistent metadata:

- oggetti;
- users;
- tablespace;
- quote;
- segments.

### 16.2 V$ e GV$

Dynamic runtime view.

- `V$`: local instance;
- `GV$`: cluster-wide in RAC.

Viste da conoscere.

| Vista | Because it's important |
|---|---|
| `v$instance` | status of the instance |
| `v$database` | ruolo, open mode, DBID, log mode |
| `v$parameter` |actual parameters|
| `v$spparameter` |parameters in the SPFILE|
| `v$bgprocess` | background processes |
| `v$session` |active sessions|
| `v$process` |OS and Oracle processes|
| `v$datafile` |datafiles|
| `v$log` | redo log groups |
| `v$logfile` | redo log members |
| `v$archived_log` | archived redo history |
| `v$managed_standby` | standby and apply processes |
| `v$dataguard_stats` | transport e apply lag |
| `v$asm_diskgroup` | ASM status |
| `gv$instance` |all RAC instances|
| `gv$services` | services cluster-wide |

---

## 17. Map of the most important parameters

| Parametro |Architectural significance|
|---|---|
| `DB_NAME` |logical name of the database|
| `DB_UNIQUE_NAME` |unique site name, crucial for Data Guard|
| `INSTANCE_NAME` | name of the single instance |
| `SERVICE_NAMES` | database services, today often managed via srvctl |
| `SGA_TARGET` | automatic EMS management |
| `PGA_AGGREGATE_TARGET` | target PGA |
| `DB_BLOCK_SIZE` |database block size|
| `CONTROL_FILES` |control active files|
| `DB_CREATE_FILE_DEST` |OMF primary destination|
| `DB_RECOVERY_FILE_DEST` | FRA |
| `DB_RECOVERY_FILE_DEST_SIZE` |FRA dimension|
| `REMOTE_LOGIN_PASSWORDFILE` | use of the password file |
| `LOCAL_LISTENER` | local listener |
| `REMOTE_LISTENER` | remote listener or SCAN |
| `CLUSTER_DATABASE` |enable RAC behavior|
| `LOG_ARCHIVE_CONFIG` |Data Guard perimeter|
| `LOG_ARCHIVE_DEST_n` |redo transport or local archive destinations|
| `STANDBY_FILE_MANAGEMENT` | standby file self-management |
| `DG_BROKER_START` | Broker startup |

---

## 18. Common Conceptual Errors

1. think that`COMMIT`means datafile already written;
2. confuse`service` con `SID`;
3. confuse`istanza` con `database`;
4. believe that each PDB has its own separate instance;
5. pensare che `MRP0` must be on all RAC standby instances;
6. ignore the difference between`SPFILE` locale e `SPFILE`shared in ASM;
7. believe that the listener contains the database;
8. confondere redo e undo;
9. believe that ASM is just a special directory;
10. usare solo `v$archived_log` to measure Data Guard status.

---

## 19. How to Connect Theory to Your Lab

In your laboratory these concepts become concrete like this.

### Phase 2

- `RACDB`= a shared database;
- `rac1` e `rac2` = due istanze;
- `+DATA`, `+RECO`, `+CRS` = disk group ASM;
- `SCAN`, VIP, services = successful client access.

### Phase 3

- `RACDB_STBY` = primary physical standby;
- `MRP0`, `RFS`, SRL = apply e transport redo;
- SPFILE in ASM = standby RAC corrected attitude;
- OCR registration = complete clusterware management.

### Phase 4

- Broker = Data Guard orchestration layer;
- `DMON`= key process;
- `DGConnectIdentifier`, protection mode, switchover, failover = true HA and DR management.

### Extra DBA

- PDB propagation primary -> standby;
- services PDB `PRIMARY` vs `PHYSICAL_STANDBY`;
- EM, RMAN, TDE, troubleshooting listener and alert log.

---

## 20. Minimum Queries to Know by Heart

```sql
SELECT instance_name, status FROM v$instance;
SELECT name, open_mode, database_role FROM v$database;
SELECT name, value FROM v$parameter;
SELECT name, value FROM v$spparameter WHERE value IS NOT NULL;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest;
SELECT group#, thread#, status FROM v$log;
SELECT member FROM v$logfile;
SELECT con_id, name, open_mode FROM v$pdbs;
SELECT inst_id, instance_name, host_name FROM gv$instance;
```

---

## 21. Official Oracle References

- Oracle Database 19c Concepts - Memory Architecture
- Oracle Database 19c Concepts - Process Architecture
- Oracle Database 19c Concepts - Logical Storage Structures
- Oracle Database 19c Concepts - Physical Storage Structures
- Oracle Database 19c Concepts - Application and Networking Architecture
- Oracle Database 19c Multitenant - Overview of the Multitenant Architecture
- Oracle RAC Administration and Deployment Guide - Overview of Oracle RAC Architecture
- Oracle Data Guard Concepts and Administration - Redo Transport and Apply Services
- Oracle ASM Administrator's Guide - ASM Overview

Official links:

- https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/memory-architecture.html
- https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/process-architecture.html
- https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/logical-storage-structures.html
- https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/physical-storage-structures.html
- https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/application-and-networking-architecture.html
- https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/overview-of-the-multitenant-architecture.html
- https://docs.oracle.com/en/database/oracle/oracle-database/19/rilin/oracle-net-services-configuration-for-oracle-rac-databases.html
- https://docs.oracle.com/en/database/oracle/oracle-database/19/riwin/service-registration-for-an-oracle-rac-database.html
- https://docs.oracle.com/en/database/oracle/oracle-database/19/ostmg/automatic-storage-management-administrators-guide.pdf
- https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/data-guard-concepts-and-administration.pdf
- https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-apply-services.html
- https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/real-application-clusters-administration-and-deployment-guide.pdf

---

## 22. Final Summary

If you only need to remember 10 ideas, remember these:

1. instance and database are not the same thing;
2. SGA is shared, PGA is private;
3. commit expects redo, not datafile;
4. redo and undo are both essential but do different things;
5. Oracle garantisce read consistency tramite SCN + undo;
6. listener forwards connections, does not execute SQL;
7. service beats SID for applications, RAC and Data Guard;
8. a CDB has only one instance for its PDBs, not one for each PDB;
9. RAC = multiple instances on the same shared database;
10. Data Guard = redo transport + redo apply, does not copy \"magic\" files.
