content = r"""# Oracle Architecture: Complete Guide to Fundamental Concepts

> This guide explains the architectural concepts that an Oracle DBA must truly master. The goal is not to memorize isolated definitions, but to understand how Oracle reads, writes, recovers, scales, and protects data.

---

## 0. Quick Glossary for Beginners

> If you are new to the database world, these terms are the fundamental "building blocks" of the Oracle ecosystem.

- **Instance**: The running processes and memory (RAM) allocated on the server. It only exists when the server is on. If you restart the machine, it "disappears" and then recreates itself.
- **Database**: The actual files saved on the hard disk. These do not disappear when you shut down the machine. They contain both your data and log files for security.
- **SGA (System Global Area)**: The large "shared memory" (RAM pool) that all Oracle instance processes use together to work quickly without always accessing the disk.
- **PGA (Program Global Area)**: The "private memory" assigned to each individual connection or process. For example, if you do an `ORDER BY`, Oracle performs the calculation here in private.
- **Tablespace**: A logical container. It is like a Windows folder: you save your data in a "Tablespace", and Oracle takes care of spreading them across the actual physical files on disk (Datafiles).
- **Redo Log**: The logbook in which Oracle writes *any modification* you make before even physically saving it in the Datafiles. Used for recovery in case of a crash.
- **Undo**: The temporary data used to "go back" (Rollback) or to allow other users to read the old data while you are modifying it (Read Consistency).
- **Data Guard**: The primary security system for having a "Copy Database" (Standby) constantly aligned with the main one (Primary) for Disaster Recovery.
- **Oracle RAC (Real Application Clusters)**: A technology that allows you to have *multiple instances* (on multiple compute servers) operating simultaneously on the *same* physical database. Ideal for High Availability and Scalability (Load Balancing).
- **GoldenGate**: The tool that allows you to "replicate" and synchronize data between Oracle and other databases (or between different versions of Oracle, even in the Cloud) in real time.
- **Enterprise Manager**: The web control panel (a large unified dashboard) that a DBA uses to understand the health status and manage all databases from a single web page.
- **ASM (Automatic Storage Management)**: A special kind of file system created by Oracle to autonomously manage the storage of DB files distributed across multiple disks.

---

## 1. Basic Mental Model

An Oracle database consists of two distinct parts:

1. the Oracle instance;
2. the physical database on disk.

```mermaid
graph TD
    subgraph ORACLE_INSTANCE["ORACLE INSTANCE (Memory & Processes)"]
        subgraph SGA["SGA (Shared Memory)"]
            BC[Database Buffer Cache]
            SP[Shared Pool]
            RLB[Redo Log Buffer]
            LP["Large/Java/Streams Pool"]
        end
        PGA["PGA (Private Memory)"]
        PROC["Processes (Server & Background)"]
    end

    subgraph DATABASE_FILES["DATABASE FILES (Physical Disk)"]
        DF[Datafiles]
        TF[Tempfiles]
        CF[Control files]
        ORL[Online redo logs]
        ARL[Archived redo logs]
        PF["SPFILE / Password file"]
    end

    ORACLE_INSTANCE -- "Reads / Writes" --> DATABASE_FILES
```

> **Architectural Explanation of the Diagram (Instance and Database):**
> The diagram shows the clear and inviolable separation between the volatile "compute engine" and the permanent "storage". At the top is the **Oracle Instance** (which lives only in the server's RAM and CPU cycles), composed of the large public SGA memory, the small private PGA memories, and dozens of background processes that work ceaselessly. At the bottom is the true **Physical Database**, meaning files permanently residing on disks or SAN. The Instance is the sole intermediary that "Reads and Writes" to these files. If the server catches fire, the Instance evaporates instantly (losing the RAM), but as long as the Database Files (at the bottom) are intact on the external disks, you have not lost a single committed transaction.

Correct definitions:

- `instance` = memory + processes;
- `database` = set of persistent files;
- when you do `shutdown immediate`, you stop the instance, you do not delete the database;
- when you do `startup`, the instance resumes managing the database files.

Key concept:

- the instance is volatile;
- the database is persistent.

Visual block:

```mermaid
graph TD
    A([STARTUP]) --> B
    B["NOMOUNT<br>(SGA + active processes)<br>(no control file)"] --> C
    C["MOUNT<br>(control file open)<br>(structure known)"] --> D
    D["OPEN<br>(datafiles and redo open)<br>(users admitted)"]
```

> **Explanation of the Startup Flow:**
> The journey from darkness to an operational database follows mandatory security stages. At the launch of the `STARTUP` command (A), Oracle wakes the instance entering **NOMOUNT** (B); here the RAM (SGA) and Processes are born "blind", consulting only the Parameter File, without knowing where the actual data resides. In the next step **MOUNT** (C), the instance retrieves the `Control File` (the structural catalog), finally discovering the location and full name of all Datafiles and Redo logs scattered on the disks, but keeping them locked for administrative operations. Only in the last jump to **OPEN** (D), Oracle physically unlocks the valves: it mathematically verifies the complete integrity between file headers and the control file (SCN), repairs in background any residual corruption from an old crash (Instance Recovery) and finally allows applications in to run queries.

---

## 2. Database Lifecycle: NOMOUNT, MOUNT, OPEN

Oracle does not always start directly in `OPEN`. There are three distinct phases.

### 2.1 NOMOUNT

In `NOMOUNT`, the compute instance (Memory and Processes) is "guided" and set in motion, but the physical database for now is as if it does not exist. Oracle does not yet know where the files are or what the database is called.
What happens exactly under the hood:

1. **Reading the Parameter File (PFILE/SPFILE)**: The instance looks for a specific configuration file on the operating system to know how to size itself (it will typically search in sequence: `spfile<SID>.ora`, then `spfile.ora`, then the text file `init<SID>.ora`).
2. **SGA Allocation**: The large amount of RAM memory required to operate is physically allocated (the Shared Pool, Buffer Cache etc. as requested in the Parameter file).
3. **Background Processes Startup**: Vital processes such as PMON, SMON, CKPT, DBWn, LGWR are "switched on" and positioned ready in RAM.
4. **Trace file writing**: Oracle opens the famous `alert.log` file for the instance and records all startup information (and any critical errors from this point on).

Available:
- Database creation (`CREATE DATABASE` command).
- RMAN cloning (`DUPLICATE` command).
- Emergency restore of the Parameter File.
- Initial setup (Bootstrap) of the standby database in Data Guard.

### 2.2 MOUNT

In `MOUNT`, the started instance finally shakes hands with the physical database (the files), placing it under administrative lock. It is the "closed doors" phase.

What happens exactly:
1. **Opening the Control File**: The instance reads from the Parameter File the path of the *Control File* (the disk catalog/brain) and opens it in memory.
2. **Physical Metadata Scan**: By reading the Control File, Oracle extracts the "treasure map": the names and directories of all Datafiles and Online Redo Log files of the database.
3. **Verification (without revealing the data)**: The instance verifies at a low level that those physical files exist where the Control File says they should be (e.g., checking inside ASM disks `+DATA`), but deliberately **does not open the database files to clients**.

Available to the DBA *but not to App Users*:
- Full Media Recovery (restore and apply old backups).
- Receive mode setup for Standby databases.
- Massive `RENAME` operations on datafiles, enabling or disabling the precious `ARCHIVELOG` mode.

### 2.3 OPEN

In `OPEN`, the final move takes place. The database flings open its doors, allowing business and applications to pour in to read and modify data.

What happens, very delicately:
1. **Opening Datafiles and Online Redo Logs**: Oracle connects directly into them and is able to trace or recover specific application data.
2. **Full Consistency Verification (The SCN Cross-check)**: Oracle precisely compares the *System Change Number (SCN)* (the internal clock of the database) safely stored in the Control File with the SCNs stamped in the header of all Datafiles. Everything **must** match to ensure the files are perfectly in sync.
3. **Possible Auto-Magic Instance Recovery (SMON)**: If there was an abnormal shutdown in the past (for example, pulling the plug on the server, using *SHUTDOWN ABORT*, and interrupting the SCN check), Oracle detects this here! The *SMON* process takes over forcefully, consults the raw data in the *Online Redo Logs*, calculates, cleans buffers and performs *Instance Recovery* instantly, recovering committed transactions that were lost and rolling back dirty ones, guaranteeing a consistent and bootable database before logins.
4. **Opening Data Access**: Normal tablespaces become editable and normal users gain querying/update privileges on the data.

Common variants for advanced phases:
- `OPEN READ WRITE`: Regular production use.
- `OPEN READ ONLY`: Absolute read-only protection (useful in Data Warehouse/Static Reporting contexts).
- `READ ONLY WITH APPLY`: For active Data Guard (the famous Active Data Guard feature, where you can read the replicated data on a standby while the server invisibly updates it in the background).

### 2.4 Shutdown Modes

The main ones are:

- `SHUTDOWN NORMAL`: waits for all users to exit;
- `SHUTDOWN IMMEDIATE`: rollback of uncommitted transactions and clean shutdown;
- `SHUTDOWN ABORT`: brutal stop, recovery at next startup;
- `SHUTDOWN TRANSACTIONAL`: waits for active transactions to finish.

In the lab, the most commonly used is `IMMEDIATE`.

---

## 3. Memory Architecture

Oracle uses two large memory areas:

1. shared `SGA`;
2. private `PGA`.

Quick schema:

```mermaid
graph TB
    subgraph ORACLE_INSTANCE["ORACLE INSTANCE"]
        subgraph SGA["SGA (System Global Area) - Shared"]
            BC[Buffer Cache]
            SP[Shared Pool]
            RB[Redo Buffer]
            LP["Large/Java/Streams"]
        end
        subgraph PGA["PGA (Program Global Area) - Private"]
            MEM["Single session memory: Sort, Hash, Stack"]
        end
    end
```

> **Explanation of the Memory Model (SGA vs PGA):**
> The RAM topology in Oracle is similar to a large office. The upper box **SGA (System Global Area)** represents the "shared common area": there is the **Buffer Cache** (the huge work table where raw data extracted from the disks is deposited so everyone can read it at RAM speed), the **Shared Pool** (the enormous filing cabinet of already-analyzed queries and execution plans) and the **Redo Buffer** (the tray where change records frantically accumulate before being "flushed" to the hard disk).
> The lower box **PGA (Program Global Area)** represents instead the "absolutely isolated private desk" of each employee (the Server Process). If you as a user asked to sort one million records alphabetically (`ORDER BY`), this "mental sorting (Sort/Hash)" is done in complete secrecy and shielded from prying eyes in your *private PGA*, thus not disturbing the public SGA memory.

### 3.1 SGA: shared instance memory

All server and background processes read or write the SGA.

Main components.

#### Database Buffer Cache

Contains data blocks read from datafiles.

Function:

- reduce physical I/O;
- keep the most used blocks in RAM;
- hold modified blocks not yet written to disk.

Logical block states (Buffer States):

- `clean`: block identical to the copy on disk. If the DB needs space, it can overwrite it instantly (after "aging" it out via LRU). If Database Smart Flash Cache is enabled, DBWn can write the clean buffer body to the flash cache for future quick reuse, keeping its header in memory.
- `dirty`: modified in memory, not yet written by DBWn.
- `pinned`: block currently in use or modified in an active transaction, untouchable for other operations at that millisecond.

**Buffer Touch Counts and LRU (Least Recently Used)**:
Oracle uses an LRU list to decide which blocks to keep in RAM. It does not physically move data in memory, but moves "pointers". It uses a "touch count" mechanism: when a buffer is "pinned", if the counter was incremented more than three seconds ago, it is increased. The three-second rule prevents a burst of operations from counting as multiple reads (e.g., an insert of many rows counts as 1 touch). Blocks with high touch counts go towards the "hot" part of the LRU list, unused ones "age out" and leave.

**Multiple Buffer Pools**:
By default only the *Default pool* exists. But to optimize, you can divide the Buffer Cache into:
- `Keep pool`: for frequently read blocks (e.g., lookup tables) that you want to always stay in RAM.
- `Recycle pool`: for rarely read blocks (e.g., data warehouse scans) that must leave the cache immediately to avoid polluting the Default pool LRU.
- `Big table cache`: for managing massive table scans using temperature-based algorithms.

Important concept:

- commit does not wait for the dirty block to be written to the datafile;
- commit waits for the redo to be written to disk.

#### Shared Pool

Contains shared structures necessary for SQL execution.

Key sub-components:

- `Library Cache`: Contains parsed SQL, PL/SQL blocks, execution plans. This is where "Allocation and Reuse" occurs: when a new SQL is parsed (if it is not DDL), space is allocated. The item stays in memory via LRU algorithm. If multiple sessions use it, it remains even if the creating process terminates. The statement `ALTER SYSTEM FLUSH SHARED_POOL` (or changing the global database name) clears this cache.
- `Data Dictionary Cache` (or *Row Cache*): Oracle accesses the data dictionary very frequently for parsing (privileges, objects, column types). This cache is the only one that stores data as *rows* (not as *buffers* (entire blocks)).

If the Shared Pool is small or fragmented you may see:

- excessive hard parsing;
- invalidations;
- `ORA-04031` errors.

#### Redo Log Buffer

Circular buffer in RAM where Oracle accumulates redo records before LGWR writes them to the online redo logs.

Contains:

- description of changes;
- not entire blocks, but change vectors.

#### Large Pool

Optional area used by:

- RMAN;
- parallel execution;
- shared server;
- some I/O and messaging operations.

Used to avoid unnecessary pressure on the Shared Pool.

#### Java Pool

Used if the database runs internal Java components.

#### Streams Pool

Used by streaming and replication functionality in certain scenarios.

### 3.2 PGA: private memory (Program Global Area)

Unlike the SGA (which is a huge public square where all processes read and write), the **PGA** is strictly private. Each individual server process or background process owns its own PGA allocated by the operating system at the moment of its startup. No other process can peek at the data in your PGA.

What happens here:
- **Sort Area**: If you write a query with `ORDER BY`, `GROUP BY` or a `ROLLUP`, Oracle uses this RAM computation space to sort the data. If the Sort Area is too small, Oracle "spills" the data to temporary files on disk (TEMP Tablespace), crashing overall performance.
- **Hash Area**: Used mathematically to perform *Hash Joins* between huge tables.
- **Session Information & Cursor State**: Contains the current state of the connection (who you are, what privileges you have active) and the row-by-row execution state of a SQL cursor.
- **Stack Space**: Local variables and arrays passed to the session or to PL/SQL programs.

PGA control is governed by parameters such as `PGA_AGGREGATE_TARGET` (where you impose a soft total limit for all combined PGAs) and, from Oracle 12c, `PGA_AGGREGATE_LIMIT` (a hard limit to prevent the DB from consuming all server RAM and exploding with OOM - Out of Memory errors).

### 3.3 UGA: User Memory (User Global Area)

The `UGA` is a logical subset of memory strictly associated with the user *session* (not the operating process itself). Where Oracle physically places the UGA depends critically on the chosen network architecture:

- **Dedicated Server Model**: There is a 1:1 relationship between the session and the OS process. Since the process serves only one client, **the UGA is entirely contained within the PGA** of the server process. This guarantees maximum performance and total isolation.
- **Shared Server Model**: Thousands of sessions "jump" from time to time onto a small pool of shared processes. Consequently, server process A cannot hold the private data of user X in its own PGA, because user X ten seconds later might be handed to server process B. Therefore, **Oracle moves the UGA inside the SGA** (specifically in the Large Pool or Shared Pool) making the user state visible to all server processes in the pool.

### 3.4 Automatic Memory Management

Manually configuring how much RAM to give to the Shared Pool, Buffer Cache or Java Pool is complex. Oracle over time has invented algorithms to auto-balance these areas by "borrowing" RAM from each other based on actual needs (workload-driven tuning).

#### ASMM (Automatic Shared Memory Management)
The model most widely used today (especially in large labs and enterprises). You set the *total* SGA quota, and the MMAN (Memory Manager) background processes dynamically and continuously size the internal Pools.
Control parameters:
- `SGA_TARGET`: How much dynamic allocation to allow.
- `SGA_MAX_SIZE`: The maximum structural limit beyond which ASMM cannot physically push without a true instance restart.
- `PGA_AGGREGATE_TARGET`: The automatic management of private PGAs, treated independently and in parallel.

#### AMM (Automatic Memory Management)
The extreme evolution, somewhat less popular for large Linux systems with HugePages.
Parameters:
- `MEMORY_TARGET` and `MEMORY_MAX_TARGET`.
By giving Oracle a single total RAM pool for everything (SGA + PGA), the instance is able to expand the SGA by stealing space from the PGA when processes are not doing computations, and vice versa. It tends to be excellent for smaller servers, but in giant Data Warehouse systems it can lead to potential instability or continuous frantic resizing.

---

## 4. Process Architecture

Oracle uses:

1. client processes;
2. listener;
3. server processes;
4. background processes.

### 4.1 Client process

It is the application process or tool that connects to Oracle:

- SQL*Plus;
- JDBC / OCI Client;
- Python / Web Application.

It is fundamental to understand the difference from a server process:
- The client process **cannot directly access the SGA** (shared ram) of the database.
- This is the reason why the application and the database can reside on physically different servers or networks.
- The connection (network session) is established to a listener which in turn creates a dedicated (or assigned) **Server Process** to communicate with the SGA and files.

### 4.2 Listener

The listener receives the network connection and forwards it to the correct service.

It does not execute SQL.

It acts as the initial dispatcher:

- listens on the port;
- knows the registered services;
- hands the session to the server process.

### 4.3 Server process

It is the process that actually does the work of the session.

Tasks:

- parse;
- execute;
- fetch;
- block access;
- cursor management;
- interaction with PGA and SGA.

Connection models:

- `dedicated server`: for each connected user (Client process), Oracle starts a dedicated process (Server process) on the DB server. That Server process keeps the UGA (User Global Area) inside its private PGA. This is the standard and safest model in terms of isolation. (In your lab you almost always use `dedicated server`).
- `shared server`: if you have thousands of users, duplicating thousands of server processes would exhaust the RAM (PGA). With this model, clients talk to a `Dispatcher`, which puts the requests in a queue. A smaller pool of `Shared Server Processes` picks the requests from the queue. Here the UGA moves inside the SGA (Large Pool) so that any server process can read it.

### 4.4 Fundamental background processes

| Process | Practical role |
|---|---|
| Process | Practical role and Technical Detail|
|---|---|
| `DBWn` (Database Writer) | Performs "lazy" writes of buffers that have become *dirty* (modified in RAM) transferring them to the physical datafiles. Also intervenes in response to CKPT (Checkpoint). Can have multiple threads (DBW0, DBW1, etc.). |
| `LGWR` (Log Writer) | Super critical process: writes REDO entries from the Redo Log Buffer in RAM to the Online Redo Logs on disk in sequential fashion. Always writes synchronously at the time of a COMMIT. |
| `CKPT` (Checkpoint) | Monitors the "success point" up to which data is safe. Updates the header of control files and the header of each datafile recording up to which SCN number the data is healthy, signaling to DBWn to flush dirty buffers. |
| `SMON` (System Monitor) | Handles Instance Recovery. In case of server crash (and shutdown abort), at the next startup `SMON` "rewinds" and "reapplies" the actual redo and undo to bring the db back to consistency. It also cleans up temporary segments. |
| `PMON` (Process Monitor) | The watchdog. If a user process crashes/dies suddenly, PMON intervenes: releases the table-locks held, empties the PGA used by the dead process. In Oracle RAC, it performs cleanup at the cluster level. |
| `ARCn` (Archiver) | When an Online Redo Log is full, and before LGWR can recycle it (overwrite it), ARCn copies it to the physical backup files "Archived Redo Log". Optional (requires configuring ARCHIVELOG mode) but mandatory in production. |
| `RECO` | Recovery of suspended distributed transactions. |
| `MMON` | manageability/AWR statistics collection |
| `MMNL` | MMON support |
| `LREG` | dynamically registers services and instances to listeners |
| `CJQ0` | coordinates job scheduler |
| `RVWR` | writes flashback logs if Flashback is active |
| `FBDA` | Flashback Data Archive |
| `DMON` | Data Guard Broker |
| `VKTM` | manages internal virtual time |

### 4.5 RAC-specific processes

In RAC, cluster-specific processes also appear, for example:

- `LMON`;
- `LMD`;
- `LMS`;
- `LCK`.

They serve:

- cache fusion;
- global enqueue service;
- block coordination between instances.

---

## 5. How Oracle Executes a Query

Simplified flow.

```mermaid
flowchart TD
    Client[Client App] --> Listener[Listener]
    Listener -- "Forwards (Service)" --> Instance[Oracle Instance]
    Instance --> ServerProcess[Server Process]
    ServerProcess --> Parse["1. Parse"]
    Parse --> Bind["2. Bind"]
    Bind --> Execute["3. Execute"]
    Execute --> Fetch["4. Fetch"]
```

> **Explanation of the Query Execution Flow (Lifecycle):**
> The complete path to run a simple `SELECT *` is incredibly elaborate.
> Everything starts from the **Client App** (which could be your Python script or DBeaver), which contacts the directional antenna called the **Listener**. The Listener bounces it into the **Instance** by assigning or creating on the fly a "private butler" (the **Server Process**).
> At this point the "4 Sacred Steps" of SQL begin:
> 1) The **Parse**: The server checks grammar, permissions and decides the fastest "GPS navigation route" (Execution Plan via the CBO).
> 2) The **Bind**: Translates and pastes the secret dynamic variables passed by the user (e.g.: `WHERE ID = :1`) in place of the placeholders.
> 3) The **Execute**: The pulsing action! Locks are acquired, physical blocks are loaded from Datafiles to the Buffer Cache memory (if not already there) and any modifications are applied (logical Undo and Redo).
> 4) The **Fetch**: Happens only for reads or returns. The server packages the found rows and sends them back via TCP network to the Client "X rows at a time" (Array Fetching) to avoid congesting the infrastructure.

### 5.1 Parse (Syntactic analysis and optimization)

The *parse* is the most expensive brain operation (and often feared for performance) in which Oracle analyzes the SQL text entered by the user and produces the execution plan to quickly retrieve the data. It is not just about checking parentheses and punctuation.

1. **Syntax Check**: Checks grammar correctness.
2. **Semantic Check and Privileges**: Oracle frantically scans the *Data Dictionary Cache* to make sure the table called "EMPLOYEES" really exists, and that your user has the GRANT permission to read it.
3. **CBO Optimization (Cost-Based Optimizer)**: Oracle considers the intelligence of statistics. Will it use indexes or partitions? Will it do a sequential Table Scan? The *CBO* generates dozens of invisible possible Execution Plans and assigns a "logical cost" (based on I/O or CPU estimate) to each. It will choose the path with the lowest mathematical cost.

Critical parse types:
- **Hard Parse**: This is the first time this exact specific query has been seen by the server. Oracle follows all 3 steps (extremely expensive for CPU and in-memory spinlocks). Afterwards, it stores the abstract "execution plan" in the *Library Cache* of the Shared Pool.
- **Soft Parse**: An identical query is received (literally character by character, including spaces). Oracle checks permissions but then *skips the CBO optimization*, instantly fetching and recycling the Execution Plan saved in the Library Cache.

> **Sacred Goal of a DBA / Dev**: Massively encourage *Soft Parse* by always using **Bind Variables** (`SELECT * FROM employees WHERE id = :code`). If you concatenate strings explicitly (`... WHERE id = 12` and then `... WHERE id = 13`), Oracle will see them as different queries and hammer the CPU with continuous exhausting *Hard Parses*.

### 5.2 Execute (Executing the manipulation/query)

Armed with its Execution Plan, the server process gets serious. If it is a DDL or DML command (INSERT, UPDATE, DELETE):
1. **Buffer Cache Check**: Checks if it already has the table rows in RAM. Otherwise, it triggers I/O descending to the Datafiles and copying the block into memory.
2. **Locking**: If it is DML, it places exclusive `Enqueue` (Lock) to protect the modified rows from concurrent modifications by other sessions.
3. **HISTORY and LOG Generation**: Writes the temporal countermeasure to *Undo Segments* (to allow rollback if you change your mind) and then saves the change stream to the sequential RAM logs (the *Redo Log Buffer* destined for LGWR).
4. **RAM Mutation**: Materially changes the row value in the *Database Buffer Cache*, flagging the logical block as **Dirty**. No datafile is touched on disk at the time of Execute!

### 5.3 Fetch (Data retrieval or return)

This phase applies if it was a `SELECT` or returns from PL/SQL cursors:
- The server process neatly packages the retrieved rows and sends them via TCP/IP network to the terminal or application (SQL*Plus, Java, .NET, browser).
- If there are many rows (e.g., 1 million), it does not send them all at once, causing crashes. It forwards them in "batches" (e.g., 100 rows at a time per fetch) managing network buffer windows. Many application bottlenecks reside in poorly written Fetch loops at the application level (called Row-by-Row or "Slow-by-Slow"), while in Oracle massive fetch (Array Fetch) is always best practice.

---

## 6. Transactions, SCN, Redo, Undo and Consistency

Commit schema:

```mermaid
sequenceDiagram
    participant S as Session
    participant SP as Server Process
    participant DBWn as DBWn (Data Writer)
    participant RLB as Redo Log Buffer
    participant LGWR as LGWR (Log Writer)
    participant ORL as Online Redo Log
    participant DF as Datafiles
    
    S->>SP: UPDATE
    SP->>SP: 1. Modify block in Buffer Cache
    SP->>SP: 2. Generate UNDO in memory
    SP->>RLB: 3. Generate REDO and save it in RAM
    S->>SP: COMMIT
    SP->>LGWR: 4. Request redo write
    LGWR->>ORL: 5. Write from Redo Log Buffer to disk
    ORL-->>LGWR: 
    LGWR-->>SP: 
    SP-->>S: COMMIT COMPLETED (Fast)
    Note over DBWn,DF: Later (Lazy mode) DBWn\nwrites the modified block.
    DBWn->>DF: 6. Write "Dirty" block to Datafile
```

This is the part that separates those who use Oracle from those who understand it.

### 6.1 SCN (System Change Number)

The `SCN` is the true temporal heartbeat of Oracle. It does not rely on the operating system clock (which could skip due to an NTP server), but on an internal incremental counter (a logical and exact clock) that never goes back.

It is of galactic importance for the entire engine because:
- **Orders changes**: Every time a COMMIT succeeds, the SCN advances, placing a unique "stamp" on the transactions.
- **Guarantees Read Consistency**: Oracle uses the SCN to understand if the data you are reading right now was already modified and committed *before* your long query started.
- **Orchestrates Data Guard and Recovery**: Allows perfectly aligning Data Guard databases and performing *Point-In-Time Recovery* by telling RMAN "restore the database to SCN 14590212".

### 6.2 Undo (Security Data and Cancellation)

Undo preserves the "old" information of the data (the "before" relative to your modification), and is stored in the dedicated Tablespace (*UNDO*). It has a fundamental triple purpose:

1. **Rollback**: If a user launches an `UPDATE` accidentally deleting thousands of employees, but has not yet launched `COMMIT`, Oracle reads the previous snapshot from Undo and restores the situation.
2. **Read Consistency (Multi-versioning)**: If user X is modifying the row of John Smith, user Y reading at that same second will not see the locked row, but Oracle will secretly reconstruct *"on the fly"* the previous version of John Smith's row by assembling the old row retrieved from Undo. This avoids the dreadful "Dirty Reads" or perpetually waiting readers typical of other old RDBMS.
3. **Flashback**: Thanks to Undo you can query tables "in the past" (e.g.: `SELECT * FROM employees AS OF TIMESTAMP...`).

*Key Concept*: Undo is considered in all respects as *database data*. Therefore, changes to Undo space in turn produce Redo!

### 6.3 Redo (The Frontier Operational Logs)

The Redo log tells the "after" (the "bare and crude story" of the bits changed on disk). It is the uninterrupted and sacred stream of *any manipulation* or vectorization of the database blocks that occurred in memory.

Used for:
- **Instance Recovery (Crash)**: If someone brutally unplugs the power and the buffers in RAM evaporate, the Redo Log on disk (if it survives) has the exact list of operations to "Redo" or Re-Play the changes and restore committed modifications.
- **Data Guard Feed**: This stream of binary changes is the substance that is pumped over the network to the Disaster Recovery server.

### 6.4 The Art of the Fast Commit

The `COMMIT` command is the most critical moment. It absolutely does not mean that the large blocks of your Datafiles have been saved to disk. That work is assigned with delayed firing (*Lazy*) to `DBWn` to save the slow performance of old disks or storage latency.

WHAT IT MEANS: By executing `COMMIT`, you only put pressure on the Log Writer (`LGWR`). This will write *only the receipt* to the tiny *Online Redo Log*. It is a pure sequential I/O, explosively fast.
As soon as the Online Redo log seals it to disk, Oracle decrees your transaction "100% safe and completed" waking the client process and giving it the green light. Everything else (actual datafile update) could take half an hour, because Oracle, as long as it has the Redo, is confident and unbeatable in case of a crash.

### 6.5 Total Read Consistency

Oracle will never show you "dirty reads" or highly variable data over time. It guarantees that a large query (that may take 20 minutes to run) sees an *exact consistent snapshot* of the data taken at the infinitesimal moment of its logical starting SCN.
If another fast application constantly modifies and "commits" on a row that your slow query has not yet read from disk, at the moment your query gets to it, Oracle will not read the new block, but will temporarily "scaffold" a reconstruction in memory assembling it with the data from *Undo*.

### 6.6 Checkpoint (CKPT and File Harmony)

The Checkpoint is the moment of cleanup and secure marking. It does not mean blocking I/O or pausing business.
It means that the *CKPT* process records in the **Control File** and in the **physical Headers of all Datafiles** what the current guaranteed clean and consolidated SCN is.
A Checkpoint forces *DBWn* to finally flush all pending "Dirty" blocks from RAM to the Datafile (e.g., old ones modified a long time ago). The immense purpose of the checkpoint is to *fix a safety buoy* to enormously shorten the time needed for an Instance Recovery. Fewer dirty buffers in memory -> less logical gap between Datafile and Redo -> less Redo to "Redo" at boot.

### 6.7 Instance Recovery vs Media Recovery

This is the most misunderstood but crucial distinction in Oracle:

**Instance Recovery (The system does it by itself)**
- **When It Occurs**: After brutal shutdown, power loss, kernel panic, critical process killed (`SHUTDOWN ABORT`). The server loses RAM, but the disks and all files are intact.
- **The Mechanism**: At the first `STARTUP` command, the instance understands that SMON did not properly close the files (Control file SCN does not match Datafiles SCN). Automatically the db opens the old *Online Redo Logs*, uses the change-vectors not yet saved to datafile and the Undo, and emulates in 5 seconds the pre-crash hours restoring perfect consistency *without* human intervention at boot.

**Media Recovery (RMAN intervenes and the DBA sweats)**
- **When It Occurs**: When storage corrupts bits, disks break, someone does a catastrophic "rm -rf" on your Datafile binary files, or a storm burns the SAN.
- **The Mechanism**: Here Oracle Database cannot recover by itself, because it is historically missing the basis to understand the changes. The DBA *must* manually call `RMAN` (Recovery Manager), paste old backups into the cluster disk, and start explicit scripts where RMAN will reapply historically tons of *Archived Redo Logs* downloaded from tapes until reaching the present. The database remains OFF or partial for that file until the operation is complete.

---

## 7. Logical Storage Structures

Oracle separates logical and physical architecture.

Correct logical order:

```mermaid
graph TD
    DB[Database] --> TS[Tablespace]
    TS --> SEG[Segment]
    SEG --> EXT[Extent]
    EXT --> BLK[Block]
```

### 7.1 Data block

The block is the minimum logical unit of database operation (I/O). A `Data Block` is logically translated by the DB as the union of one or more OS Blocks (the operating system blocks, formatted at the Linux or Windows level). Decoupling from the OS block dependency allows ASM and Oracle to manage performance in a custom way.

Key parameters:

- `DB_BLOCK_SIZE`: typically 8 KB in the lab. Block sizes of 16 KB or 32 KB are often used for massive Data Warehouses.
- A block has a **header** (which includes metadata, active ITL transactions and row directory) and a **body** (which grows bottom-up, where rows are physically inserted or modified).
- Free space (PCTFREE): percentage (10% by default) left rigorously empty in the block to allow future "expansion" of rows (e.g., you update a row from NULL to the text "JohnDoe" and the data needs a bit more space to expand without causing an annoying row-migration to the next block).

### 7.2 Extent (The spatial allocation unit)

An extent is a set of strictly contiguous (adjacent) data blocks allocated all at once.
When you create a table, Oracle does not give it one tiny block at a time or the hard disk would go crazy. It assigns an initial *Extent* (e.g., 100 blocks together). When the table fills up, Oracle will add another Extent to let it grow.

### 7.3 Segment (The actual object)

A segment is the set of all extents belonging to a specific logical database object (regardless of whether they are stored on different datafiles). If I say "EMPLOYEES Table", at a conceptual level I am referring to a Segment.

Common and vital types of segments:
- **Table segment**: The space that strictly holds the data inserted by users.
- **Index segment**: The special B-Tree structures created to speed up queries. They also occupy valuable space and have their own fragmentation logic.
- **Undo segment**: The vital space used by Oracle in background to store temporary rollbacks.
- **Temporary segment**: "Single-use" areas dynamically allocated when a user runs crazy queries with huge sorts (e.g., massive `HASH JOIN`) that do not fit in PGA memory. Once the computation is complete, the segment evaporates releasing the space.
- **LOB segment**: Used to encapsulate BLOBs or CLOBs (Large Objects such as PDF files, XML, photos) that by nature cannot respect the rigid traditional Oracle block architecture.

### 7.4 Tablespace (The Great Container)

A tablespace is the colossal logical container (an abstraction) that logically groups various segments and which in turn is physically backed by one or more Datafiles.

The default pillars in Oracle:
- `SYSTEM` and `SYSAUX`: The sacred core. Never put application data there. They handle the logical *"brain"*, host the Data Dictionary (system views, built-in PL/SQL code, AWR statistical history). If they get corrupted, you lose the database.
- `UNDO`: Tablespace surgically dedicated to `Undo segments` to guarantee *Read Consistency*.
- `TEMP`: Tablespace for RAM spill-over (computations that overflow to disk).
- **Application tablespaces (e.g.: USERS)**: Tablespaces created by you the DBA to decouple the software client modules (e.g., `TS_HR` for human resources, `TS_SALES` for sales).

### 7.5 Bigfile vs Smallfile Tablespace

Until the last century, file system limits forced splitting a Tablespace into many small Datafiles (Smallfile) of at most 32GB each.
- **Smallfile tablespace**: Classic model. A single tablespace contains up to 1022 datafiles. Multiplication of physical files to manage.
- **Bigfile tablespace**: Modernly designed to work with ASM. *One tablespace = One single enormous datafile* that can reach up to 128 Terabytes. Makes storage management infinitely cleaner and more linear by automating resizing.

---

## 8. Physical Storage Structures

### 8.1 Datafiles

Contain the blocks of permanent and undo tablespaces. The data of a database is collectively stored in Datafiles. A Segment (therefore a table) cannot be split across two Tablespaces, but since a Tablespace can consist of *multiple* physical Datafiles, a Fragment, an Extent or a Table can "span" hundreds of different Datafiles. This abstract disconnection maximizes I/O optimization (especially in ASM via file-striping to read in parallel from various disks).

Do not contain:

- redo logs;
- control files.

### 8.2 Tempfiles

Used for:

- sort;
- hash;
- temporary segments.

Practical difference:

- not recovered like normal datafiles;
- can be recreated.

### 8.3 Control files

They are the minimal and *crucial* physical catalog of the database: a small binary file uniquely linked to the instance. If you lose all active/available control files, the database **cannot be mounted (MOUNT)** and the action will fail with a fatal error.

They contain information on:

- DB name and DBID (Vital Unique Machine Identifier for RMAN);
- the map of all datafiles and redo logs on disk;
- the logical tables of current SCNs (checkpoint);
- Archived Log history and integrated RMAN metadata.

**Multiplexing Control File**:
Since the control file is fundamental, in any real production database you will have 2, or more commonly 3, *identical and simultaneously updated* copies (Multiplexing) stored on independent hardware disks. (e.g., one copy on `+DATA` and a logical mirroring duplicate saved on `+RECO`). This reduces "single points of failure".

### 8.4 Online redo logs

They constitute the most critical component for **Recovery** and protect against sudden power losses or server failures (instance crash). They collect all modifications made to datafiles (*and even* to the undo datafile blocks) written at a frightening pace before they are flushed to the DataFiles.

Organized for solid redundancy architecture:

- **Groups**: at least two groups are required for the database to run, and they are used in a ring (when the 11th fills up it moves to the 12th and so on).
- **Members (Members per Group)**: this is the translation of Redo Multiplexing! Here too, in production each Group has at minimum two Members. (E.g., Group 1 formatted with 2 files called redo1a.log and redo1b.log placed on different ASM disks. If the first storage array dies and redo1a burns, redo1b will ensure that the log group proceeds without losing the last lines modified by bank customers who just withdrew cash at the ATM).

Concepts:

- a group is used as `CURRENT`;
- at the log switch Oracle moves to the next group;
- ARCn archives full groups if the DB is in `ARCHIVELOG`.

### 8.5 Archived redo logs (The Perpetual Chronicle)

While *Online Redo Logs* are like a "continuous-loop tape" that is overwritten hour by hour to preserve space, **Archived Redo Logs** are the permanent and historicized copy placed in safe storage before the overwriting occurs. The process responsible for this snapshot copy is *ARCn* (Archiver).

Without them, you would have protection only against temporary crashes (Instance Recovery) but would lose everything in case of a disk failure.
They are strictly required for:
- **Full Backup and Restores**: RMAN uses them to fill the "time gap" between the last full backup (put on tape a month ago) and the exact moment the server exploded today.
- **Point-in-Time Recovery**: The ability to bring the database back exactly to "yesterday at 2:00:00 PM" before a developer launched a catastrophic DROP TABLE.
- **Standby Data Guard**: In asynchronous modes, archived logs from the primary db are constantly sent to the secondary server to keep it aligned.

### 8.6 SPFILE and PFILE (The Instance DNA)

The instance knows nothing about itself when it starts. It needs a file to tell it how much RAM to use (SGA), what the database is called, and where to find the Control Files.

#### PFILE (Init.ora)
- It is a simple text file (`initSID.ora`), historical and static.
- Can be opened and modified manually with `vi` or `Notepad`.
- Disadvantage: If while the database is running you do an `ALTER SYSTEM SET ...`, the change applies in RAM but *is not* written back to the PFILE. At the next restart, it would be lost.

#### SPFILE (Server Parameter File)
- It is a binary file managed internally by Oracle.
- It is the true production standard. Forbidden to open with text editors, or risk corruption.
- Absolute Advantage: Allows applying tuning or memory changes in real time with persistence. Using the command `ALTER SYSTEM SET memory_target=4G SCOPE=BOTH;`, Oracle applies the change both for the current RAM session, *and by physically modifying the binary parameter in the SPFILE* for future restarts.

### 8.7 Password file (orapw)

If the database is "SHUTDOWN" (off), how do you think you can authenticate the `SYSDBA` user to order it to start up, given that the users table "DBA_USERS" is locked in the powered-off datafiles?
This is where the **Password File** comes in. An external security file to the database itself that resides at the operating system level.

Without it, remote administrators could not administer the server in critical phases. It enables powerful access with explicit privileges: `SYSDBA` (Total Administration), `SYSDG` (Administrators limited to Data Guard only) and `SYSBACKUP` (Administrators for RMAN operations).
It is critical in architectures like Data Guard or RAC where cluster nodes must recognize each other via secure cryptographic strings without accessing tables.

### 8.8 FRA (Fast Recovery Area)

The `Fast Recovery Area` is the huge and fundamental "centralized folder" managed automatically (often mounted on a super-fast storage or on a dedicated ASM Disk Group called `+RECO`). Its purpose is to host all files related to the survival of the database.

More than a folder, it is an ecosystem governed by Oracle: you decide how large it should be (`DB_RECOVERY_FILE_DEST_SIZE`), and Oracle will automatically delete obsolete backups from there to make room for new ones if space runs low (based on RMAN Retention Policies).
It invariably contains:
- Historical Archived Logs and Flashback Logs (the data for "time travel" to an hour ago).
- Backups written by RMAN (Backup Sets, Backup Pieces) and Image Copies.
- Automatic autobackups of the Control File and SPFILE.

**Very high risk**: If the FRA space fills up to 100% (common error `ORA-19809: limit exceeded`), the Archiver will no longer be able to save Redo Logs. As a self-defense measure, *the entire Database will freeze ("Hang") blocking all user sessions and every UPDATE/INSERT transaction* until you free up space and release the semaphore for Redo!

---

## 9. Write Flow: UPDATE -> COMMIT

This is the flow to know by heart.

```text
1. Session executes UPDATE
2. Oracle reads the block into Buffer Cache if necessary
3. Oracle generates undo
4. Oracle generates redo
5. Oracle modifies the block in Buffer Cache
6. The block becomes dirty
7. COMMIT
8. LGWR writes redo to online redo log
9. COMMIT returns OK
10. DBWn will write the dirty block to the datafile later
```

Step-by-step view:

```mermaid
flowchart TD
    UPDATE[UPDATE] --> Fetch["Block read or already in cache"]
    Fetch --> UNDO[UNDO Generated]
    UNDO --> REDO[REDO generated]
    REDO --> Dirty[Block becomes Dirty]

    Dirty --> COMMIT[COMMIT]
    COMMIT --> LGWR[LGWR forces REDO to disk]
    LGWR --> Confirm[Oracle confirms Commit to Client]

    Confirm --> POST[POST-COMMIT]
    POST --> CKPT[CKPT updates checkpoint info]
    CKPT --> DBWn["DBWn flushes the dirty block later"]
```

> **Explanation of the Write Flow (Write-Ahead Logging):**
> When you run an `UPDATE`, you do not write minimally to the data file! Oracle immediately looks for the block in cache or reads it from disk if absent. Once in memory, Oracle does not touch the data before protecting itself: **1)** It generates the rollback information in UNDO. **2)** It declares its intent by creating REDO entries in rapid succession. **3)** At this point it truly "dirties" (Dirty) the block in Buffer Cache. When you give the explicit `COMMIT` command, the final LGWR process is lightning-fast awakened and forced to fire the REDO to sequential disk. Once this lifesaving jump is made, your client receives a glorious "Ok, saved!". Much later (Lazy writing), when the Checkpoint (CKPT) fires, it will be the drowsy DBWn that actually flushes the dirty block to the slow physical Datafile on disk.

Golden rule:

- redo before datafiles;
- this is the basis of Oracle's write-ahead logging.

---

## 10. Oracle Net, Listener, Services and Dynamic Registration

Visual block:

```mermaid
graph TD
    APP["Application / SQL*Plus"] -->|Uses SERVICE_NAME| LIST[Listener]
    LIST --> REG[Service Registration LREG]
    REG --> I1[Instance 1]
    REG --> I2[Instance 2]
    REG --> DG[Role-based service Data Guard]
```

> **Architectural Explanation (Connection Ecosystem):**
> In the diagram, the user (Application) blindly points to the Listener using only a logical `SERVICE_NAME` (e.g., `ecommerce_db`). The Listener has no idea where the Instance is physically located at startup. The intelligence lies below: it is the database's own background process **LREG (Listener Registration)** that wakes up and "knocks on the door" of the Listener saying: *"Hey, I am Instance 1, I am alive, I handle the 'ecommerce_db' service and I am at 50% load. Send me the connections!"*. In RAC or Data Guard environments, LREG notifies the entire ecosystem allowing fluid load balancing without you ever having to modify the `tnsnames.ora` files.
 
### 10.1 Listener

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

- applications should use services, not SID;
- in RAC and Data Guard, the service is the correct access concept.

### 10.3 Dynamic registration and Ecosystem (LREG)

Service registration is a feature in which the background process **LREG (Listener Registration Process)** dynamically communicates instance information to the local and remote listener.
This means you do not need to manually configure almost anything in `listener.ora`. LREG constantly informs the listener about the load (Load Balancing) and available dispatchers.

Parameters involved:

- `LOCAL_LISTENER`: tells LREG where to find the local listener.
- `REMOTE_LISTENER`: indispensable in RAC to notify the main cluster listener (SCAN Listener).

In RAC:

- `REMOTE_LISTENER` typically points to SCAN;
- services can do load balancing and failover.

Useful command:

```sql
ALTER SYSTEM REGISTER;
```

Used to force immediate registration after listener start or service changes.

---

## 11. Multitenant Architecture: CDB and PDB

From the 19c perspective, the multitenant architecture is central.

CDB/PDB schema:

```mermaid
graph TD
    subgraph CDB_ROOT["CDB ROOT (Processes, Memory, Redo, Undo, Common Dictionary)"]
        SEED["PDB$SEED<br>(Template, Read Only)"]
        PDB1["APP_PDB1<br>(App 1 Data, Local Users)"]
        PDB2["APP_PDB2<br>(App 2 Data, Local Users)"]
    end
```

> **Visual Explanation of Multitenant (CDB/PDB):**
> The structure is conceptually modeled after the idea of virtual machines, but for databases. The titanic outer shell is the **CDB ROOT**: it "pays the rent" for all the RAM memory and background processes shared by everyone (it has its own redo logs and process manager that hold up the system).
> Inside it, isolated from each other like private apartments, reside the **Pluggable Databases (PDB)**. The `PDB$SEED` serves exclusively as a read-only template for creating fresh new PDBs. The numbered PDBs `APP_PDB1` and `APP_PDB2` are instead the true virtualized databases of the various client applications: they believe they are autonomous, own their own end users and their own Tablespaces, but in reality they delegate the use of CPU and RAM to the shared Mother Instance.

### 11.1 Components

Each CDB includes:

- `CDB$ROOT`;
- `PDB$SEED`;
- zero or more user PDBs.

### 11.2 Root

`CDB$ROOT` contains:

- common Oracle metadata;
- common users;
- shared structures.

It is not the right place for normal application data.

### 11.3 Seed

`PDB$SEED` is the read-only template used to create new PDBs.

### 11.4 PDB

A Pluggable Database (PDB) appears to the application as an independent and traditional physical database, but at the architectural level it shares heavy resources with the parent container (CDB):

- **Same Instance**: there is no separate RAM/SGA or isolated PDB_CACHE_SIZE (except for limits imposed with the Resource Manager).
- **No own Background Processes**: SMON, PMON, DBWn, LGWR belong only to the CDB Root.
- **Redo Logs**: shared. All changes from all PDBs feed the single Redo Log stream managed by the root.
- **Undo Tablespace**: normally there is the "Local Undo" option (recommended in 19c) in which each PDB has its own undo files, or shared centrally.
- **Control File**: the CDB has a single control file that maps all Datafiles of all PDBs.

This is fundamental:

- a CDB with 10 PDBs does not have 10 separate instances;
- it has a single instance that manages multiple containers.

### 11.5 Common users and local users

- common user: visible in all containers;
- local user: exists only in the PDB.

### 11.6 Services and PDB

Best practice:

- each application uses a service associated with the PDB;
- in RAC, the service is created with `srvctl add service -pdb ...`.

---

### 12. ASM (Automatic Storage Management): The Intelligent File System

ASM is not just disk space; it is a "Volume Manager" and "File System" engineered exclusively for Oracle databases. Before ASM, DBAs had to manually map dozens of Datafiles onto physical Linux disks, fighting against bottlenecks and "hot spots" (slow disks because overused).

**The technical pillars of ASM:**
- **Separate ASM Instance**: ASM runs as a dedicated Oracle instance (with its own small SGA and background processes) independent from the database. The Database "talks" with the ASM instance via the ASMB process to agree on block allocation, but note: *The actual I/O is done by the Database directly to the disk, bypassing the ASM instance to maximize speed.*
- **Allocation Units (AU)**: Instead of saving a 10GB Datafile all in one piece on a disk, ASM slices it into tiny "Allocation Units" (e.g., 1MB or 4MB).
- **Extreme Striping**: ASM takes the millions of AUs of a single file and spreads (stripes) them rigorously across *all* disks comprising a `Disk Group` in round-robin fashion. If you run a complex query, 10 disks will work in parallel to give you the answer, pulverizing bottlenecks!
- **Extent-level Mirroring**: You no longer do RAID at the hardware-LUN level. ASM manages software mirroring: it keeps two or three copies of the same AU mathematically on different disks (Failure Groups).
- **OMF (Oracle Managed Files)**: Full automatic symbiosis. You no longer decide file names. You say `CREATE TABLESPACE users;` and ASM will create under the hood `+DATA/RACDB/DATAFILE/users.259.102394`.

In the lab and in real life you use standardized Disk Groups:
- `+DATA`: Fast-spinning or SSD disks. Contains everything needed to run the db (Datafiles, Online Redo).
- `+RECO`: Very large disks, possibly slower. Contains the life raft (Archived Logs, FRA, RMAN Backups).
- `+CRS`: Ultra-critical files linked solely to the survival of the cluster (Voting Disk and OCR).

Visual block:

```mermaid
graph TD
    DB[Database / Grid] --> ASM[ASM Instance]
    ASM --> DATA["+DATA<br>Datafile<br>Controlfile<br>Online Redo<br>SPFILE / Password File"]
    ASM --> RECO["+RECO<br>Archivelog<br>Backup Pieces<br>Flashback Logs<br>Copies"]
```

> **Explanation of the ASM Flow:**
> The diagram shows how the Database is completely blinded: it no longer sees the Hard Disks. It only sees the ASM Instance, which acts as a magical intermediary and translator.
> On the right, the cylinders (Disk Groups) represent the enormous pools of grouped disks: `+DATA` ingests and routes at blazing speed all the hot I/O operations (Datafiles, active logs), while `+RECO` continuously ingests the historical recovery data (Archives and RMAN copies).

---

## 13. RAC: Cluster Architecture

RAC means multiple instances opening the same shared database.

RAC schema:

```mermaid
graph TD
    subgraph SHARED_STORAGE["Shared Storage (ASM)"]
        SS["Datafiles / Controlfiles / Redo / SPFILE"]
    end

    subgraph RAC["Oracle RAC Cluster"]
        I1["Instance RACDB1 (Node rac1)<br>SGA + PGA + proc"]
        I2["Instance RACDB2 (Node rac2)<br>SGA + PGA + proc"]
    end

    I1 <--> |Cache Fusion / GCS| I2
    I1 --> SS
    I2 --> SS
```

> **Explanation of the RAC Cluster Flow:**
> The immense power of RAC is visible here! Below you have a single indestructible Database placed on ASM disks. But above? You have two or more compute nodes (Instances) armed with tons of RAM (SGA/PGA).
> The vertical arrows (`I1 --> SS`) show that each node reads and writes simultaneously on the same Datafiles independently of the others thanks to distributed locks.
> The enormous horizontal arrow in the center (`Cache Fusion`) is the exclusive high-speed fiber network (Interconnect): if Node 1 has the employee salaries in RAM, and Node 2 needs to calculate taxes, Node 2 does not go to the slow disks (SS), but "sucks" the data directly from Node 1's RAM via Cache Fusion at zero latency.

### 13.1 The "Shared but Independent" Paradigm

In a RAC configuration (e.g., a 2-node cluster), there are physically *two distinct servers* (two Instances, with their SGA and their PMON/SMON), but on the ground there is *one and only one* physical copy of the database (on shared devices like ASM).

**What they share:**
- **ASM Storage**: Datafiles and Controlfiles are simultaneously visible and editable by both instances via distributed I/O technologies.
- **The SPFILE**: It is global, to allow identical structural changes to all nodes.

**What they NEVER share:**
- **Private PGA**: The RAM computations of one node are not connected to the other.
- **Redo Log Threads**: When Instance A does the UPDATE of a block, it uses its own private LGWR and flushes the content to `Online Redo Log (Thread 1)` files. Instance B works on a totally different set of logical disks `Online Redo Log (Thread 2)`. This avoids blocking contention between servers.
- **Undo Tablespace**: Each owns its own local and isolated space to write past transactions.

### 13.2 Cache Fusion (The True Magic of RAC)

If node 1 has read the invoice #10 block into memory (Buffer Cache), and now node 2 wants to read it, what happens?
Pre-RAC, node 2 would have gone pitifully to the hard disk to retrieve it.
In RAC, we have **Cache Fusion**: leveraging a private ultra-fast gigabit network (Interconnect network), Node 1 sends the entire memory block at the speed of light *directly into the RAM* of Node 2 via the UDP protocol. The Global Cache Service processes (`LMS` and `LMD`) orchestrate this ballet constantly, blocking "Ping-Pong" conflicts and merging the two SGAs into a unified "Superbrain".

### 13.3 SCAN (Single Client Access Name)

In classic DBs, you gave the frontend/web application the IP address of the server. But in RAC there are N servers!
The **SCAN** (Often associated with 3 logical IPs distributed round-robin on a DNS Server) acts as the unified castle gate. No client application knows the real IP addresses of the individual physical cluster nodes (`rac1-vip` or `rac2-vip`).
Clients point to the *SCAN Name*. If you add a third node (rac3) or if rac2 burns down, application developers do not change a single character in their JDBC URL, because SCAN silently redistributes connections downstream to the surviving listeners.

### 13.4 Services in RAC (Precision Tailoring)

Instead of giving the various company departments the connection string to the generic database, you configure specialized *Server Names* via SRVCTL.
- You can force the "Human Resources" application to point to the `HR_SRV` service, which via policy works physically **only** on node rac1 (Preferred).
- If rac1 dies, the cluster does "Failover" starting the `HR_SRV` service on node rac2 in zero time.
This mechanism is also indispensable for isolating traffic from multiple PDBs, where each container owns and activates a unique Service to track in case of a disaster on a physical server.

---

## 14. Data Guard: Protection Architecture

Data Guard protects the database with one or more standbys.

Redo transport schema:

```mermaid
graph LR
    subgraph PRIMARY["PRIMARY (RACDB)"]
        USER[User COMMIT] --> LGWR[LGWR]
        LGWR --> ORL[Online Redo Log]
    end

    subgraph STANDBY["STANDBY (RACDB_STBY)"]
        SRL[Standby Redo Log] --> MRP["MRP0 / Redo Apply"]
        MRP --> DF[Standby Datafile]
    end

    LGWR -- "Redo Transport" --> SRL
```

> **Visual Explanation of Data Guard:**
> Two servers kilometers apart in two different Data Centers connected by a network wire.
> In the Primary (on the left), the user modifies something. The tireless `LGWR` process lightning-fast records these changes in its own *Online Redo Log*.
> Simultaneously or asynchronously (depending on the desired security mode), backend processes grab this log stream and "fire" it over the network cable (*Redo Transport*).
> The Standby server (on the right) is in deep receiving mode: RFS processes fill the *Standby Redo Logs* with new changes, and finally the silent worker `MRP0` (Managed Recovery Process) reads these logs and physically applies them to the Datafiles of the backup database, keeping them aligned to the millisecond with the primary.

### 14.1 Essential conceptual components

- Primary database: the one holding active Read/Write Data.
- Standby database: the one consuming data and synchronizing.
- **Redo Transport Services**: In charge of "sending" via network the REDO stream (via SYNC or ASYNC mode, depending on the desired *Protection Mode* such as *MaxProtection*, *MaxAvailability*, or *MaxPerformance*).
- **Apply Services**: The entity (on the destination db) that "applies" the actual redo received to its own datafiles. (Via logical `Redo Apply` if Logical, or physical via Media Recovery).
- **Data Guard Broker (`DGMGRL`)**: The optional (but highly recommended) administration tool that automates instantaneous switchover and failover, piloting the transport and apply processes in the background for you.

### 14.2 Main standby types

- **Physical Standby**: exact byte-for-byte copy of the datafiles. Uses MRP (Managed Recovery Process) to apply the Redo. This is the type used in your practical lab!
- **Logical Standby**: translates and uses SQL statements to keep parts of tables aligned. Rarely used for pure HA.
- **Snapshot Standby**: a Physical Standby temporarily converted to "Read/Write" for application testing with production data without corrupting the future primary synchronization.

### 14.3 Basic flow

```mermaid
flowchart LR
    P[Primary Generates Redo] --> T[Redo Transport Sends Redo]
    T --> R["Standby Receives Redo (RFS/SRL)"]
    R --> A["Apply Services Apply Redo (MRP)"]
```

> **Micro-Analysis of Standby Data Flow:**
> 1) The Primary generates REDO (the chemical recipe of the transaction).
> 2) The Transport Network launches the recipe over the wire.
> 3) The Standby captures the recipe putting it in RAM or on SRL.
> 4) The *Apply* services act as chef: they blindly execute the recipe grinding local I/O copying the "original" transaction without missing a syllable.

### 14.4 Roles, Protection Modes and Operations

**The Roles:**
- `PRIMARY`: The sovereign database. It is open in Read/Write, users work on it actively, and it produces tons of Redo logs.
- `PHYSICAL STANDBY`: The silent twin. It receives the Redo log from the primary and applies it byte-for-byte altering its own copy datafiles. If opened in *Read Only with Apply*, it allows reporting queries relieving the primary (Active Data Guard).

**Role Transition Operations:**
- **Switchover**: A planned scepter handover, without data loss. The Primary cordially closes user connections, transforms into a Standby, and the former Standby becomes the new official Primary. Used for server maintenance or DR drills.
- **Failover**: The red emergency button. The primary explodes or catches fire, and you forcibly open the Standby as the new Primary saving the company. Depending on the protection level, you might lose the very last milliseconds of data.
- **Reinstate**: After a Failover, the old burned Primary (once restarted) is reconditioned and "demoted" to the new Standby to re-establish the Data Guard chain.

**Protection Modes:**
- **MaxPerformance** (Default): The primary sends the log asynchronously (`ASYNC`). The user never waits for arrival at the Standby. Very high performance on the main database, but if the server explodes you might lose a few seconds of transactions that never arrived at the destination.
- **MaxAvailability**: Synchronous sending (`SYNC`). The user waits for the commit only after the Standby has confirmed receiving the log in remote memory. But there is a smart trick: if the network to the standby goes down, the primary automatically "degrades" to MaxPerformance rather than blocking.
- **MaxProtection**: Pure synchronous sending (`SYNC`). If the standby is not reachable via network, *the primary blocks (shutdown)* to prevent data divergence at all costs. Used only by banks or institutions with ultra-redundant networks.

### 14.5 Data Guard Broker (The management brain)

Manually setting up Data Guard through long and convoluted SQL commands on the Redo Transport is a very high risk (Oracle calls it "manual Data Guard").
The **Data Guard Broker** is an internal framework activated via the `DMON` daemon process. It centralizes all configuration in a single configuration file (`dr1.dat`/`dr2.dat`).

Why it is fundamental:
- It creates an abstraction: You talk to the powerful text interface called **`DGMGRL`** or through the intuitive *Enterprise Manager* (OEM).
- Just literally type `switchover to RACDB_STBY;` and dozens of cryptic commands happen under the hood. You do not need to worry about altering parameter files, restarting closed instances, or doing cross-checks of SCNs: the DMON process does everything in synergy between the two sites.

---

## 15. Structural Diagnostics: ADR and Error Investigation

### 15.1 ADR (Automatic Diagnostic Repository)

When the database enters a mystical crisis (`ORA-00600` or `ORA-07445`), the file system tree structure that holds all the "medical reports" is called ADR. It is centralized at a path defined by the `DIAGNOSTIC_DEST` parameter.
Unlike ancient Oracle versions (>10g), in 19c each major component (Instance, Listener, ASM Instance, Clusterware) has its own `ADR Home`. The rigorous and vital utility for ruthlessly querying the ADR from a Bash terminal is `adrci`.

- **Alert Log**: The master "diary" (both XML and text).
- **Trace Files (`.trc`) and Dumps**: The long "reports" where the crashing process screams out its stack trace for technical support (MOS).
- **Incidents and Packages (IPS)**: If the database detects a cyclopean ORA-00600 error ("Oracle software bug"), ADR codes it as a unique `Incident`. `adrci` allows the DBA to package in two seconds all the traces and logs from that stumble into a convenient zipped file to send as an attachment to the Oracle Support Engineer.

### 15.2 Alert Log (`alert_SID.log`)

The sanctuary of high-level diagnostics, it is the first line the DBA looks at in the dark when the alarm rings.
It is a simple sequential text file typically located under the `/trace` folder in the ADR.

What you should obsessively search for:
- Precise details of a crash and sudden restarts (All STARTUP and SHUTDOWN events).
- Any space shortages in RMAN or failures in Archiving the redo (`ORA-00257`).
- Non-application ORA-Errors that stop central background processes.
- Parameter changes (discover who altered a critical parameter at runtime and at what time).
- The recovery or log-apply stream in Data Guard.

### 15.3 Tuning Tools (AWR, ASH and ADDM)

Diagnostics is not only about crashes, but above all about crippled Performance.

- **AWR (Automatic Workload Repository)**: The statistical "brain" that queries I/O metrics, Cache and SQL executions collected by MMON processes *every 60 minutes* by default. It produces heavy snapshots and allows you to compare "Yesterday at 2 PM" vs "Today at 2 PM" with a click, generating an HTML Report with evidence of the main wait-events and system bottlenecks (e.g., Disks saturated by `db file sequential read`).
- **ASH (Active Session History)**: While AWR gives you macro hourly total reports, ASH takes a snapshot of the exact situation of all active v$session *every second*. If you need to know exactly which SQL blocked a process for exactly three miserable minutes between 12:00 and 12:03 yesterday, you find it through the historical tables `DBA_HIST_ACTIVE_SESS_HISTORY`.
- **ADDM (Automatic Database Diagnostic Monitor)**: The robotic expert eye. At each new AWR snapshot generated, it analytically produces human and clear suggestions (Example: "Add more RAM to the buffer cache because this SQL is devouring the CPU in Hard Parse").

*Warning*: These phenomenal tools are not free but fall exclusively under *Diagnostic Pack* or *Tuning Pack* licenses in Oracle Enterprise Edition. Using them without a license is a massive compliance violation in software audits.

---

## 16. Data Dictionary and Dynamic Performance Views

How do you understand what is "in the head" or "on the disks" of Oracle in real time? You do it with simple `SELECT` queries. Oracle encodes itself inside special views divided into two macro and sacred families.

### 16.1 Static / Metadata Family (DBA_, ALL_, USER_)

They represent "immobile" metadata, like the geometry saved in the SYSTEM tablespace vault. They always inherit the same suffix depending on the privileges of the person executing the query:
- `USER_TABLES`: Reveals to user X the tables created and owned by user X (Their confined world).
- `ALL_TABLES`: Shows user X also the incredible tables owned by users Y or Z towards which X has received prior `GRANT SELECT` permissions.
- `DBA_TABLES`: The power of the Total Administrator. Shows the entirety of every single object in the database, regardless of any small user's permissions, enabling top-down diagnostics. In these DBA views you look for example at the space historical logs in `DBA_DATA_FILES` and Undo queues in `DBA_UNDO_EXTENTS`.

### 16.2 Dynamic Runtime Family (The mysterious V$ and GV$)

They reveal the exact present moment loaded in Memory (SGA/PGA). These are not tables physically written on disks permanently, but live projections of background server process parameters read "in real time" by scanning bits in RAM. They vanish if you shut down the instance.

- **V$ (Local Instance Views)**: Rigorously refer to the activity of the *single machine (Instance)* on which you have opened the running terminal.
- **GV$ (Global Views for RAC)**: Essential when Oracle runs in a Multi-Node Cluster. A query on `GV$SESSION` instead of querying only the current three user sessions on `rac1` and ignoring those on `rac2`, descends to the internal Cache Fusion daemons and magically gathers the process states of both SGAs, returning you the collective application picture of the entire RAC infrastructure in its monumental entirety.

Views to know.

| View | Why it is important |
|---|---|
| `v$instance` | instance status |
| `v$database` | role, open mode, DBID, log mode |
| `v$parameter` | effective parameters |
| `v$spparameter` | parameters in SPFILE |
| `v$bgprocess` | background processes |
| `v$session` | active sessions |
| `v$process` | OS and Oracle processes |
| `v$datafile` | datafiles |
| `v$log` | redo log groups |
| `v$logfile` | redo log members |
| `v$archived_log` | archived redo history |
| `v$managed_standby` | standby and apply processes |
| `v$dataguard_stats` | transport and apply lag |
| `v$asm_diskgroup` | ASM status |
| `gv$instance` | all RAC instances |
| `gv$services` | cluster-wide services |

---

## 17. Key Parameters Map

| Parameter | Architectural meaning |
|---|---|
| `DB_NAME` | logical database name |
| `DB_UNIQUE_NAME` | unique site name, crucial for Data Guard |
| `INSTANCE_NAME` | name of the individual instance |
| `SERVICE_NAMES` | database services, today often managed via srvctl |
| `SGA_TARGET` | automatic SGA management |
| `PGA_AGGREGATE_TARGET` | PGA target |
| `DB_BLOCK_SIZE` | database block size |
| `CONTROL_FILES` | active control files |
| `DB_CREATE_FILE_DEST` | primary OMF destination |
| `DB_RECOVERY_FILE_DEST` | FRA |
| `DB_RECOVERY_FILE_DEST_SIZE` | FRA size |
| `REMOTE_LOGIN_PASSWORDFILE` | password file usage |
| `LOCAL_LISTENER` | local listener |
| `REMOTE_LISTENER` | remote listener or SCAN |
| `CLUSTER_DATABASE` | enables RAC behavior |
| `LOG_ARCHIVE_CONFIG` | Data Guard perimeter |
| `LOG_ARCHIVE_DEST_n` | redo transport or local archive destinations |
| `STANDBY_FILE_MANAGEMENT` | automatic standby file management |
| `DG_BROKER_START` | Broker startup |

---

## 18. Common Conceptual Mistakes

1. thinking that `COMMIT` means the datafile has already been written;
2. confusing `service` with `SID`;
3. confusing `instance` with `database`;
4. believing that each PDB has its own separate instance;
5. thinking that `MRP0` must be on all standby RAC instances;
6. ignoring the difference between a local `SPFILE` and a shared `SPFILE` in ASM;
7. believing that the listener contains the database;
8. confusing redo and undo;
9. believing that ASM is just a special directory;
10. using only `v$archived_log` to measure Data Guard status.

---

## 19. Connecting Theory to Your Lab

In your laboratory these concepts become concrete as follows.

### Phase 2

- `RACDB` = a shared database;
- `rac1` and `rac2` = two instances;
- `+DATA`, `+RECO`, `+CRS` = ASM disk groups;
- `SCAN`, VIP, services = correct client access.

### Phase 3

- `RACDB_STBY` = physical standby of the primary;
- `MRP0`, `RFS`, SRL = redo apply and transport;
- SPFILE in ASM = correct RAC standby setup;
- OCR registration = complete clusterware management.

### Phase 4

- Broker = Data Guard orchestration layer;
- `DMON` = key process;
- `DGConnectIdentifier`, protection mode, switchover, failover = true HA and DR management.

### Extra DBA and Modern Oracle (21c/23ai)

- New Oracle versions are pushing heavily on AI Vector Search for RAG and machine learning.
- **Oracle 23ai True Cache**: a revolutionary approach to reduce load on the DB: a high-performance in-memory SQL cache managed transparently by Oracle.
- EM (Enterprise Manager 13c) offers the unified console to monitor this ecosystem (Phase 6).
- RMAN (Phase 5) protects the primary db, standby and target.
- GoldenGate (Phase 7) enables real-time offloading to Local (Oracle 21c/23ai) or Cloud (e.g., OCI Data Integrator or Microservices).

---

## 20. Complete Architecture of Your Lab Ecosystem

```mermaid
graph TD
    EM["ORACLE ENTERPRISE MANAGER 13c<br>Monitoring"] 
    
    subgraph DATAGUARD["Oracle Data Guard (Phase 4)"]
        PR["RAC PRIMARY<br>RACDB"]
        ST["RAC STANDBY<br>RACDB_STBY"]
    end

    subgraph BACKUP["RMAN (Phase 5)"]
        FRA[Backups in FRA]
    end

    subgraph REPLICATION["GoldenGate (Phase 7)"]
        TG["TARGET DB<br>Local / Cloud"]
    end

    EM --> PR
    EM --> ST
    PR -- "Redo Transport" --> ST
    PR --> FRA
    ST --> FRA
    PR -- "Extract / Replicat" --> TG
```

## 21. Essential Queries to Know by Heart

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

## 22. Official Oracle References

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

## 23. Final Architecture Summary

If you need to remember and master only the most deadly and misunderstood concepts of the entire Oracle Database ecosystem:

1.  **The Instance Disappears, the Database Remains:** The instance is just smoke (RAM and Processes) that evaporates when you turn off the machine. The Database is the lead-armored files on disk.
2.  **Public SGA vs Private PGA:** The SGA acts as a gigantic exchange table where all queries put and retrieve cached data. The PGA is the tiny personal calculator used silently by the individual to sort rows.
3.  **Commit Waits for Logs, Not Data:** Doing a commit does not mean data engraved on slow stone data files. It means a super-fast lightning bolt shot sequentially by the *LGWR* process to the tiny Redo Log. At that point Oracle is already happy and safe.
4.  **Redo (Future) and Undo (Past):** Redo Log is used to recover the server if the power goes out by replaying the tape. Undo serves you the human to go back (Read Consistency and Rollback) allowing historical reads while another user edits the row.
5.  **Listener as Switchboard, not Worker:** The Listener only routes network packets assigning them to the right Server Processes, but *never executes a single SQL Query*.
6.  **Multi-Tenants are not Virtual Machines:** In 19c, having 10 PDBs inserted in a CDB_ROOT does not mean having 10 instances. It means all mathematically sharing *the single large memory* (SGA and shared Background Processes).
7.  **The RAC Trinity (Real Application Clusters):** Multiple brutal compute servers that asynchronously assault a single, unified physical copy of the data parked at the bottom in the ASM disk array using the fiber interconnection protocol Cache Fusion to avoid stepping on each other's memory.
8.  **Data Guard is a Pressurized Tube:** High reliability is not achieved just by copying magic files, but by opening a network tube and transactionally firing every Change Vector (REDO) generated on the Production server via TCP/IP, pouring it frantically into the Datafiles of the constantly waiting Emergency server.
"""

with open("/home/runner/work/dba_oracle_lab/dba_oracle_lab/docs/00_fondamenti/GUIDA_ARCHITETTURA_ORACLE.md", "w", encoding="utf-8") as f:
    f.write(content)

print(f"Written {len(content)} bytes")
