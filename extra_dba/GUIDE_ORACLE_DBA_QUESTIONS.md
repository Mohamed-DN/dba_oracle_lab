# Oracle DBA Questions Guide

> Structured collection of questions, answers and technical scenarios about Oracle DBA. The questions have been curated from multiple public sources, but the answers have been realigned to official Oracle terminology and concepts, with a practical focus on 19c, RAC, Data Guard, ASM, RMAN, multitenant and troubleshooting.

---

## 1. How to Use This Document

For each question, build the answer in 3 layers:

1. correct definition in 1-2 sentences;
2. why it matters in production;
3. a working example, a `V$` view or a real command.

Formula pratica:

- `definizione`: what is it;
- `impatto`: because the business or DBA takes care of it;
- `operativita`: How do you check or handle it.

Example:

- domanda: `Che differenza c'e tra redo e undo?`
- weak answer: `Redo serve per recovery e undo per rollback.`
- strong answer: `Redo registra le modifiche necessarie a riprodurre i cambiamenti durante recovery o replica Data Guard. Undo conserva la vecchia immagine logica dei dati per rollback e read consistency. Li verifico con il flusso commit, v$log, tablespace UNDO e casi ORA-01555.`

Classic mistake to avoid:

- talk only about theoretical definitions without citing a practical case;
- naming tools without knowing when to use them;
- confuse`instance`, `database`, `service`, `SID`, `redo`, `undo`, `restore`, `recover`, `RAC`, `Data Guard`.

---

## 2. Architecture and Basic Concepts

### 2.1 What is the difference between instance and database?

Clear answer:

- `instance` = memoria `SGA` + processi background e server;
- `database`= persistent files: datafile, control file, redo log, archived log, parameter file.

Why it matters:

- when you do `shutdown`, you stop the instance;
- when you do `startup`, the instance goes back to managing the physical database.

Follow-up forte:

- `NOMOUNT` just starts the instance;
- `MOUNT` opens the control file;
- `OPEN` opens datafiles.

### 2.2 What is the difference between SGA and PGA?

Clear answer:

- `SGA` and memory shared between the processes of the instance;
- `PGA`and private memory of the single process.

Useful details:

- in `SGA` trovi `Buffer Cache`, `Shared Pool`, `Redo Log Buffer`;
- in `PGA` you find sort area, hash area, stack, private state of the process.

Typical next question:

- `Se manca memoria dove guardi?`
- risposta: `AWR`, `v$sga_dynamic_components`, `v$pgastat`, `v$memory_target_advice`, wait events e paging OS.

### 2.3 What is the Buffer Cache for?

Clear answer:

- keeps the blocks read or modified in memory;
- riduce I/O fisico;
- also contains dirty blocks not yet written to datafile.

Important point to say:

- the `commit` does not wait for the block to be written to the datafile;
- wait for the redo on disk.

### 2.4 Cos'e la Shared Pool?

Clear answer:

- and the area of ​​`SGA` which contains already parsed SQL and PL/SQL and dictionary metadata;
- understands above all`Library Cache` e `Data Dictionary Cache`.

Problem signs:

- hard parse excessive;
- `ORA-04031`;
- frequent invalidations.

### 2.5 What is the difference between hard parse and soft parse?

Clear answer:

- `hard parse`: Oracle needs to do full parsing, optimization and creation of a new plan;
- `soft parse`: Oracle reuses structures already existing in cache.

Why it matters:

- too many hard parses increase CPU and latch/mutex contention;
- le bind variables riducono hard parse inutili in molti workload OLTP.

### 2.6 What happens during a commit?

Clear answer:

- Oracle genera redo;
- `LGWR`writes the redo in the online redo logs;
- only then does it confirm the commit to the session.

Punto da dire bene:

- `DBWn` can write datafiles later;
- and the principle of write-ahead logging.

### 2.7 Redo and undo: real difference?

Clear answer:

- `redo`describes changes for recovery and replication;
- `undo` preserves the previous state of the data for rollback and read consistency.

Typical trick question:

- `Si puo fare recovery con il solo undo?`
- No. Oracle recovery is based on redo.

### 2.8 Cos'e uno SCN?

Clear answer:

- `SCN`and the Oracle internal logical time counter;
- serves to coordinate consistency, recovery, flashback and block synchronization.

Why it's important:

- Oracle usa SCN + undo per garantire read consistency;
- SCN appare in backup, RMAN, Data Guard, flashback, recovery e clone consistenti.

### 2.9 What are control files and why are they critical?

Clear answer:

- control files contain structural metadata of the database;
- Oracle uses them to know what datafiles, redo logs, checkpoints and incarnations exist.

If they get lost:

- the database does not mount;
- accurate restore/recreate and recovery are needed.

### 2.10 SPFILE and PFILE: difference?

Clear answer:

- `PFILE`and hand-readable and editable text;
- `SPFILE`and binary, managed by Oracle, supports`ALTER SYSTEM ... SCOPE=SPFILE/BOTH`.

Practical note:

- in single instance one is often fine`SPFILE` locale;
- in RAC lo `SPFILE` it must typically be in ASM or shared storage.

### 2.11 What does the password file do?

Clear answer:

- enable remote authentication for administrative users such as `SYS`, `SYSDG`, `SYSBACKUP`, `SYSKM`;
- and controlled by`REMOTE_LOGIN_PASSWORDFILE`.

Practical case:

- Data Guard uses consistent file passwords between primary and standby for remote administrative connections.

### 2.12 Why is the listener not the database?

Clear answer:

- the listener accepts network connections and forwards them to the correct service;
- does not execute SQL and contains no data.

Errore tipico:

- think that restarting the listener restarts the database. It's not like that.

### 2.13 Service name and SID: which one do you use for applications?

Clear answer:

- for applications use the`service`;
- the `SID` identifies a specific instance.

Why it's a best practice:

- services support load balancing, failover, role-based routing, PDB and RAC;
- il `SID`and too rigid for HA environments.

### 2.14 What are data blocks, extents, segments and table spaces?

Clear answer:

- `data block`: minimum Oracle I/O unit;
- `extent`: group of blocks allocated together;
- `segment`: set of extents for an object such as table or index;
- `tablespace`: logical container of segments.

### 2.15 What is the difference between tempfiles and datafiles?

Clear answer:

- i `datafile`contain permanent data;
- `tempfile` supports sort, hash and temporary operations, they are not recovered in the same way as datafiles.

---

## 3. Backup, Recovery e RMAN

### 3.1 Why is RMAN preferable to manual OS backups?

Clear answer:

- knows the Oracle structure;
- manages consistent backups, block-level checks, restore, recover, cataloging, retention and integration with control file/catalog.

What more to say:

- knows how to read corruption at block level;
- integra `validate`, `crosscheck`, `duplicate`, `block media recovery`.
### 3.2 What is the difference between restore and recover?

Clear answer:

- `restore`= put files back from backup;
- `recover` = apply redo/archivelog to bring them to a consistent state.

This is a basic but preliminary question.

### 3.3 What is the difference between backup set and image copy?

Clear answer:

- `backup set`is the most common compressed/logical RMAN format;
- `image copy`and a physical copy very similar to the original file.

When to cite them:

- `backup set` per backup tradizionali;
- `image copy` useful in incremental merge or rapid copy recovery strategies.

### 3.4 Are full backup and level 0 the same thing?

Clear answer:

- no, not always from the RMAN conceptual point of view;
- `incremental level 0`and the basis of an incremental chain;
- `full` is not used as the basis for incrementals `level 1` in the same way.

### 3.5 What are incremental level 1 differential and cumulative?

Clear answer:

- `differential`: saves blocks changed since the last incremental backup of a lower or equal level;
- `cumulative`: Save the blocks changed since the last level 0.

Practical impact:

- differential = smaller daily backups;
- cumulative = recovery piu semplice ma backup piu grandi.

### 3.6 What are `crosscheck`, `delete expired` and `delete obsolete` for?

Clear answer:

- `crosscheck` checks whether backups still exist on the media;
- `expired`= backups expected but no longer found;
- `obsolete`= backups no longer necessary according to retention policy.

Common mistake:

- confuse `expired` with `obsolete`.

### 3.7 What does `validate` do?

Clear answer:

- checks the integrity and readability of backup files or datafiles without performing a complete restore in production;
- It is used to test whether the backups are really usable.

### 3.8 What is the control file autobackup for?

Clear answer:

- automatically protects control files and SPFILEs after structurally relevant backups;
- and often the lifesaver when you lose control files and local catalog.

### 3.9 Catalog or nocatalog: what do you choose?

Clear answer:

- `nocatalog`it is good for simple and small environments;
- `recovery catalog` provides more history, reporting and centralized management, useful in enterprise environments.

### 3.10 Cos'e il block change tracking?

Clear answer:

- and a file that helps RMAN know which blocks have changed after level 0;
- accelerates incremental backups.

### 3.11 How do you recover a lost datafile?

Clear answer:

- put the database/tablespace into the correct state if necessary;
- `RESTORE DATAFILE ...`;
- `RECOVER DATAFILE ...`;
- then put the file back online or open the database as appropriate.

### 3.12 How do you handle a crash with `shutdown abort`?

Clear answer:

- at the next startup Oracle executes`instance recovery`;
- use redo to redo committed changes not written to datafiles and undo to clean up incomplete transactions.

### 3.13 `ARCHIVELOG` vs `NOARCHIVELOG`: practical difference?

Clear answer:

- in `ARCHIVELOG` you can make online backups and more complete point-in-time media recovery;
- in `NOARCHIVELOG`you have more limited recovery and normally offline backups for strong consistency.

### 3.14 How do you recover SPFILE if you lose it?

Clear answer:

- you can use a `PFILE` di emergenza;
- you can recover from RMAN autobackup or create one from memory/SPFILE backup if available.

### 3.15 Quando useresti `DUPLICATE`?

Clear answer:

- to create standby, clone/test, refresh, assisted migration or duplicate environments from active database.

---

## 4. Data Guard

### 4.1 What is the difference between physical, logical and snapshot standby?

Clear answer:

- `physical standby`: apply redo physically to datafiles;
- `logical standby`: apply logical SQL transformations;
- `snapshot standby`: standby temporarily opened to read write for testing, then reconvertible.

In your lab the strong answer is: `uso physical standby per robustezza e allineamento semplice con RMAN e Broker.`

### 4.2 What main processes do you need to know about in Data Guard?

Clear answer:

- transport side:`LGWR`, `ARCn`, `LNS`, `RFS`;
- apply side: `MRP0` for physical standby.

Follow-up forte:

- `RFS` receives redo on standby;
- `MRP0`apply redo;
- with real-time apply the standby uses the `SRL`s without waiting for the archivelog to complete.

### 4.3 Why are standby redo logs needed?

Clear answer:

- they allow real-time apply and a more correct transport to standby;
- are required for many healthy Data Guard configurations.

Rule of thumb to remember:

- for each thread standby redo logs >= online redo logs of the primary + 1.

### 4.4 `SYNC` vs `ASYNC`: differenza?

Clear answer:

- `SYNC` requires acknowledgment for higher protection and greater potential impact on primary latency;
- `ASYNC` prioritizes performance and throughput, with possible small data loss in the event of a sudden disaster.

### 4.5 What is the difference between switchover and failover?

Clear answer:

- `switchover` = role change planned and without expected data loss;
- `failover` = emergency standby promotion after primary loss or switchover failure.

### 4.6 What is the Broker and why use it?

Clear answer:

- `Data Guard Broker` centralizes management and validation of Data Guard;
- semplifica switchover, failover, fast-start failover, health checks e proprieta.

### 4.7 What are `transport lag` and `apply lag`?

Clear answer:

- `transport lag` = delay in redo transfer from primary to standby;
- `apply lag`= delay between redo received and redo applied.

View to mention:

- `v$dataguard_stats`.

### 4.8 `db_name` e `db_unique_name`: difference?

Clear answer:

- `db_name` remains the same between primary and standby in the same DG configuration;
- `db_unique_name` uniquely identifies each database in the configuration.

### 4.9 What are `FAL_SERVER` and `FAL_CLIENT` for?

Clear answer:

- they are used for gap resolution to recover missing archive logs;
- become especially important in role reversal and reconnection scenarios.

### 4.10 What does `MRP0 APPLYING_LOG` mean?

Clear answer:

- that the standby managed recovery process is applying redo;
- In a RAC standby it is normal for the apply to live on only one instance at a time.

### 4.11 MaxPerformance, MaxAvailability, MaxProtection: differenze?

Clear answer:

- `MaxPerformance`: typically`ASYNC`, minimum latency, minimum data loss possible but not zero in disaster;
- `MaxAvailability`: attempt zero data loss with `SYNC`, while still keeping the primary available in many manageable faults;
- `MaxProtection`: maximum protection, but the primary can stop if it fails to protect redos as required.

### 4.12 Active Data Guard what benefit does it give?

Clear answer:

- allows use of standby in `READ ONLY WITH APPLY`;
- useful for reporting, read-only queries, some workload offloads, and GoldenGate/monitoring cases.

### 4.13 How do you seriously verify that Data Guard is healthy?

Clear answer:

- on the primary: `v$archive_dest` and no errors on the remote destination;
- on standby: `v$managed_standby`, `v$dataguard_stats`, `v$database`, alert log, Broker `show configuration` if used.

### 4.14 What common errors do you look for first in Data Guard?

Clear answer:

- `ORA-12514`, `ORA-12154`, `ORA-01017`, archived log gap, missing SRLs, inconsistent file password, wrong listener/service, bad `DB_UNIQUE_NAME`, standby in incorrect state.

---

## 5. RAC e ASM

### 5.1 What is the difference between RAC and Data Guard?

Clear answer:

- `RAC` provides high availability and active/active scalability on the same shared database;
- `Data Guard`provides disaster recovery and data protection by maintaining distinct databases.

Risposta forte:

- RAC does not replace DR;
- Data Guard does not replace the local scalability of RAC.
### 5.2 Cos'e Cache Fusion?

Clear answer:

- and the RAC mechanism that transfers blocks between buffer caches of different instances via interconnect, instead of always forcing prior writing to disk.

Why it is central:

- and the heart of RAC concurrent access to the shared database.

### 5.3 Che cos'e lo SCAN?

Clear answer:

- `Single Client Access Name`and the logical name used by clients to connect to a RAC cluster;
- simplifies failover and load balancing without making all nodes known to clients.

### 5.4 What are OCR and Voting Disk used for?

Clear answer:

- `OCR` preserves cluster configuration and resources;
- `Voting Disk` aiuta il cluster a determinare membership e quorum.

### 5.5 Why are services used in RAC and not connections fixed to the node?

Clear answer:

- per load balancing, failover, role separation, patching rolling e associazione a PDB o workload specifici.

### 5.6 Cos'e ASM?

Clear answer:

- `ASM`and the specialized Oracle storage layer for database files;
- simplifies naming, striping, mirroring and file management for databases, RMAN, RAC and Data Guard.

### 5.7 What is the difference between disk group and failure group?

Clear answer:

- `disk group` = logical set of ASM disks;
- `failure group` = group that ASM uses for redundancy, to prevent mirror copies from ending up in the same fault domain.

### 5.8 Why put SPFILE and password file in ASM in RAC?

Clear answer:

- to have shared and consistent files between nodes;
- avoids divergences between local files and simplifies clusterware startup.

### 5.9 Cos'e un rebalance ASM?

Clear answer:

- and ASM data rebalancing when you add or remove disks;
- has an I/O impact and must be monitored.

View to mention:

- `v$asm_operation`.

### 5.10 How do you distinguish a cluster problem from a database problem?

Clear answer:

- cluster side look at `crsctl`, `srvctl`, OCR, listener, VIP, SCAN, resource status;
- database side look at alert log,`v$instance`, `v$database`, wait events, storage e parametri.

### 5.11 What is the difference between`srvctl` e `sqlplus startup` in RAC?

Clear answer:

- `srvctl` manages the database as a clusterware resource;
- `sqlplus startup` acts only on the local instance and can bypass the cluster logic.

Best practice:

- in clustered RAC and Data Guard, use`srvctl` per start/stop normali.

### 5.12 How do you check the cluster status?

Clear answer:

- `crsctl stat res -t`;
- `srvctl status database -d <db_unique_name> -v`;
- `olsnodes -n -s`;
- `asmcmd lsdg` per storage.

---

## 6. Multitenant, Security e TDE

### 6.1 Cos'e un CDB e cos'e un PDB?

Clear answer:

- `CDB`and the database container that hosts the root, seed, and PDB;
- `PDB` is the pluggable database which appears almost independent but shares the instance and infrastructure of the CDB.

### 6.2 What is `PDB$SEED` for?

Clear answer:

- and the read-only template used to create new PDBs quickly and consistently.

### 6.3 Common user and local user: difference?

Clear answer:

- `common user`exists at CDB level and follows common naming/presence rules;
- `local user` exists only in the specific PDB.

### 6.4 Does a PDB have its own separate instance?

Clear answer:

- no;
- PDBs share the CDB instance, memory, and processes.

### 6.5 How do you connect an application to a PDB correctly?

Clear answer:

- tramite un `service`associated with the PDB;
- non tramite login al root o SID nudo.

### 6.6 Cos'e TDE?

Clear answer:

- `Transparent Data Encryption`protects data at rest by encrypting columns or table spaces;
- keys are managed via keystore/wallet.

### 6.7 Chi dovrebbe gestire il keystore TDE?

Clear answer:

- ideally an account with dedicated privileges such as `SYSKM` or role consistent with internal governance;
- not always just `SYSDBA`.

### 6.8 What happens if you lose the TDE wallet/keystore?

Clear answer:

- encrypted data may become unusable;
- keystore backup is as critical as database backup.

### 6.9 In RAC where do you put the TDE keystore?

Clear answer:

- on supported shared storage, so all nodes see the same keystore;
- Oracle does not recommend non-shared local wallets for common RAC cases.

### 6.10 What do you check when a keystore doesn't open?

Clear answer:

- `WALLET_ROOT`, `TDE_CONFIGURATION`, OS permissions, wallet type, keystore status in `v$encryption_wallet`, sincronizzazione tra nodi se cluster.

### 6.11 Why is password policy management not enough for DBA security?

Clear answer:

- DBA security includes auditing, least privilege, secret management, network encryption, TDE, patching, role segregation and OS hardening.

---

## 7. Performance, Diagnostics and Tuning

### 7.1 What are AWR, ASH and ADDM for?

Clear answer:

- `AWR`collects snapshots and historical performance metrics;
- `ASH`tracks high-frequency session activity samples;
- `ADDM`analyzes the data and proposes findings.

### 7.2 Quando usi AWR e quando ASH?

Clear answer:

- `AWR`for historical analysis over an interval;
- `ASH` to see who was waiting for what at a time or in a narrow window.

### 7.3 What do you look at first in an AWR report?

Clear answer:

- DB time;
- top foreground waits;
- load profile;
- SQL ordered by elapsed time / CPU / gets / reads;
- instance efficiency only with prudence, not as absolute truth.

### 7.4 How do you analyze a high CPU problem?

Clear answer:

- distingui CPU Oracle vs OS;
- look at AWR/ASH, top SQL, hard parse, parallelism, execution plan regressions, OS processes and scheduling.
### 7.5 How do you find a blocking session?

Clear answer:

- `v$session`, `v$lock`, `gv$session`in RAC, possibly ASH/AWR if the block is no longer active.

### 7.6 `ORA-01555 snapshot too old`: what does it really come from?

Clear answer:

- typically from insufficient undo or override too early relative to the duration of the consistent query;
- It's not just a problem of long queries, but of retention, workload and undo pressure.

### 7.7 `ORA-04031` what does it tell you?

Clear answer:

- that Oracle is unable to allocate contiguous memory from a shared memory structure, often `Shared Pool` or similar pool;
- sizing, fragmentation, hard parse and active components must be investigated.

### 7.8 If a query is slow, where do you start?

Clear answer:

- I confirm whether the problem is new or historical;
- I look at real execution plan, statistics freshness, waits, cardinality mismatch, bind peeking, I/O, locking, temp and parallelism.

### 7.9 Why are statistics important?

Clear answer:

- the cost-based optimizer decides the plan based on statistics;
- stale or incorrect statistics can generate terrible plans.

### 7.10 Rebuild index: standard solution?

Clear answer:

- no;
- it is only done if there is a real reason, not as an automatic reflex.

Risposta forte:

- first I check real fragmentation, blevel, clustering factor, access pattern and if the problem really lies in the index.

### 7.11 How do you check the status of tablespaces and FRAs?

Clear answer:

- tablespace: `DBA_DATA_FILES`, `DBA_FREE_SPACE`, `DBA_TEMP_FREE_SPACE`, metriche OEM;
- FRA: `v$recovery_file_dest`, `v$flash_recovery_area_usage`.

### 7.12 Alert log or trace file: when do you use one and when the other?

Clear answer:

- alert log for major events and high-level history;
- trace files for technical detail of errors, incidents, sessions and specific processes.

### 7.13 What is ADRCI and why is it useful?

Clear answer:

- and the Automatic Diagnostic Repository CLI;
- It is used to navigate alert, incident, trace and diagnostic purge also in RAC/Data Guard.

---

## 8. Operational Troubleshooting and Interview Scenarios

### 8.1 The database does not start and see `ORA-01034`. Where are you leaving from?

Clear answer:

- I check if the instance is really down;
- check `ORACLE_SID`, `ORACLE_HOME`, alert log, parameter file, spfile/pfile, listener status and clusterware if RAC.

### 8.2 A listener is on but returns `ORA-12514`. What does it mean?

Clear answer:

- the listener does not yet know the requested service;
- typically dynamic registration problem, wrong service, wrong TNS alias or database not in expected state.

### 8.3 Standby is mounted but does not apply redo. What do you control?

Clear answer:

- `MRP0`, `RFS`, `v$archive_dest`, `v$dataguard_stats`, listener/service, file password, SRL, gap archive, TNS errors, database role and Broker if active.

### 8.4 `DEST_ID=2 ERROR` on primary in Data Guard: what do you think immediately?

Clear answer:

- redo transport failed;
- control `error` in `v$archive_dest`, aka TNS, standby listener, service standby, file password, standby status and network.

### 8.5 The FRA is full. What risks do you have?

Clear answer:

- archiving can stop;
- backup/recovery/flashback possono degradare o bloccarsi;
- in severe cases it also impacts the primary.

Typical actions:

- understand what takes up space;
- release in a controlled manner;
- realign retention and sizing.

### 8.6 A tablespace is almost full. What are you doing?

Clear answer:

- I check autoextend, real space, growth, major segments, business impact;
- then I add space, extend files or clean up only if supported.

### 8.7 A RAC node falls. How do you answer correctly?

Clear answer:

- I check clusterware, vip/service relocation, alert/trace, interconnect, ASM and resource status;
- then I understand if the problem is node, GI, network, storage or database.

### 8.8 You have RMAN backups, but no one has ever tested restore. Is it enough?

Clear answer:

- no;
- unverified backup is not a reliable backup.

Risposta forte:

- servono `validate`, restore tests, runbooks and periodic recovery tests.

### 8.9 How do you distinguish `restore controlfile` from `recover database using backup controlfile`?

Clear answer:

- the first puts the control file back;
- the second enters the recovery flow when the control file used is not perfectly aligned with the current history and requires a compatible recovery approach.

### 8.10 If an application suddenly stops connecting, where do you start?

Clear answer:

- listener, service, DNS/SCAN if RAC, firewall, `sqlnet.ora`, DB status, account lock, recent errors in alert log and client side.

### 8.11 How do you respond if they ask you about a typical day as a DBA?

Clear answer:

- checking availability, backup, alerts, space, DG lag, critical jobs, listeners/services, performance regressions, open incidents and planned changes.

### 8.12 What do you do before patching?

Clear answer:

- verified backups, sufficient space, patch prerequisites, clean inventory, opatch/opatchauto conflicts, change window, rollback plan, cluster status and validated runbook.

### 8.13 What do you do after patching?

Clear answer:

- I check version, inventory, alert log, services, listener, broker, backup, job, initial performance and application health check.

### 8.14 How do you explain a difference between `READ ONLY`, `MOUNTED` and `READ ONLY WITH APPLY`?

Clear answer:

- `MOUNTED`: standby not open to normal users;
- `READ ONLY`: open for read only but without apply in the simple case;
- `READ ONLY WITH APPLY`: Active Data Guard, query e apply insieme.

### 8.15 If the topic enters critical production, what do you change in your approach?

Clear answer:

- more standardization, change control, RPO/RTO, hardening, monitoring, test recovery, runbook, role segregation, zero hardcoded secrets, DR tests and periodic validation.

---

## 9. Senior or Team Lead questions

### 9.1 How do you define RPO and RTO to a non-technical manager?

Clear answer:

- `RPO` = how much data you can afford to lose;
- `RTO` = how long it takes to get back up and running.

### 9.2 How do you choose between single instance, RAC and Data Guard?

Clear answer:

- single instance for simplicity;
- RAC for local HA and scalability;
- Data Guard per DR;
- often in serious environments RAC + Data Guard together.

### 9.3 How do you defend an enterprise backup strategy?

Clear answer:

- full/incremental backups consistent with RPO/RTO;
- clear retention;
- Dimensioned FRA;
- control file autobackup;
- restore test periodici;
- offsite or standby-based backup where useful.
### 9.4 How do you set up serious monitoring?

Clear answer:

- availability, redo transport/apply lag, FRA, table space, backup success, wait anomalies, listener/service health, cluster resources, job failures, CPU/memory/I/O, and incident routing.

### 9.5 What would you never do as a DBA in production?

Clear answer:

- destructive commands without recovery path;
- modifiche manuali non documentate su cluster/ASM;
- patching without rollback plan;
- change multiple variables together without isolating the risk;
- leave hardcoded password in script or repo.

### 9.6 How do you explain a regression after application release?

Clear answer:

- AWR/ASH before-after comparison, new SQLs, changed plan, mutated statistics, different bind pattern, locking, data volume, parameter drift, new code path.

### 9.7 When do you use switchover instead of failover?

Clear answer:

- when the primary is still healthy and the role transition is plannable;
- for maintenance, DR testing or low-risk migration.

### 9.8 How do you demonstrate technical maturity?

Clear answer:

- parli per runbook, verifiche, trade-off e failure mode;
- you don't sell magic, you sell operational control.

---

## 10. Rapid Fire: Short High Frequency Questions

Use them for quick review.

1. `Che cos'e LGWR?` Scrive redo online.
2. `Che cos'e DBWn?` Scrive dirty blocks ai datafile.
3. `Che cos'e CKPT?`Coordinate checkpoints and update header/control files.
4. `Che cos'e SMON?` Does system recovery and housekeeping.
5. `Che cos'e PMON?`Cleans up resources of failed processes/sessions; in modern releases some responsibilities have changed but the concept remains.
6. `Che cos'e ARCn?` Archivia redo online in archived log.
7. `Che cos'e LREG?` Register services to the listener.
8. `Che cos'e MRP0?` Apply redo on physical standby.
9. `Che cos'e RFS?` Receive redo on standby.
10. `Che cos'e FRA?` Area recovery per archived log, backup, flashback e file collegati.
11. `Che cos'e OMF?` Oracle Managed Files, naming/placement gestiti da Oracle.
12. `Che cos'e ASM?` Storage layer Oracle per file database.
13. `Che cos'e SCAN?`Unique name for client access to a RAC cluster.
14. `Che cos'e OCR?` Cluster configuration repository.
15. `Che cos'e Voting Disk?` Quorum e membership cluster.
16. `Che cos'e AWR?` Repository storico performance.
17. `Che cos'e ASH?` Session activity sampling.
18. `Che cos'e ADDM?`Automatic analysis of AWR data.
19. `Che cos'e TDE?`Data encryption at rest.
20. `Che cos'e un PDB?` Database pluggable dentro un CDB.

---

## 11. Scenario Questions to Simulate Orally

These are worth more than many definitions.

1. `The standby is lagging but the primary is healthy. Walk me through the triage plan.`
2. `You lost a user datafile. Walk me through restore and recovery.`
3. `The listener is up but the applications receive ORA-12514.`
4. `After patching, only one RAC node does not come back up.`
5. `The FRA has reached 95%.`
6. `Un PDB non apre dopo clone o plug.`
7. `AWR mostra CPU alta ma l'app dice lentezza I/O.`
8. `DGMGRL dice warning ma SQL mostra apply attivo.`
9. `Un job RMAN e green, ma validate fallisce.`
10. `Dopo switchover alcune app puntano ancora al vecchio ruolo.`

Recommended response method:

- initial state;
- business impact;
- immediate checks;
- hypotheses ordered by probability;
- fix;
- final check;
- future prevention.

---

## 12. Final Checklist Before the Interview

You must be able to explain without reading:

- `instance vs database`;
- `SGA/PGA`;
- `redo vs undo`;
- `commit`;
- `startup nomount/mount/open`;
- `restore vs recover`;
- `RMAN level 0/1`;
- `RAC vs Data Guard`;
- `physical standby flow`;
- `service vs SID`;
- `CDB/PDB`;
- `AWR/ASH/ADDM`;
- `TDE basics`;
- `tablespace / FRA / alert log / ADRCI`;
- `daily DBA checks`;
- `patching pre-check e post-check`.

If you want to go from junior to intermediate, you also need to know how to do:

- a fast runbook for datafile loss;
- un runbook rapido per DG lag;
- un runbook rapido per ORA-12514;
- un runbook rapido per tablespace/FRA pieni;
- a serious comparison between`MaxPerformance` e `MaxAvailability`.

---

## 13. Sources Used

### 13.1 Sources for coverage of questions

Questions curated and cleaned from multiple public sources of technical collection:

- InterviewBit Oracle DBA question set: https://www.interviewbit.com/oracle-dba-interview-questions/
- GeeksforGeeks Oracle topic roundup: https://www.geeksforgeeks.org/oracle-topics-for-interview-preparation/
- GeeksforGeeks Oracle question roundup: https://www.geeksforgeeks.org/to-50-oracle-interview-questions-and-answers-for-2024/
- GeekInterview Oracle DBA question bank: https://www.geekinterview.com/Interview-Questions/Oracle/Database-Administration/
- Oracle DBA question guide article: https://www.oracledbaonlinetraining.com/post/oracle-dba-interview-guide-questions-answers

### 13.2 Official Oracle sources used to realign answers

- Oracle Database 19c Concepts - Memory Architecture: https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/memory-architecture.html
- Oracle Database 19c Concepts - Process Architecture: https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/process-architecture.html
- Oracle Database 19c Concepts - Logical Storage Structures: https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/logical-storage-structures.html
- Oracle Database 19c Concepts - Physical Storage Structures: https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/physical-storage-structures.html
- Oracle Database Net Services Administrator's Guide: https://docs.oracle.com/en/database/oracle/oracle-database/19/netag/configuring-and-administering-oracle-net-listener.html
- Oracle RAC Administration and Deployment Guide: https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/real-application-clusters-administration-and-deployment-guide.pdf
- Oracle ASM Administrator's Guide: https://docs.oracle.com/en/database/oracle/oracle-database/19/ostmg/automatic-storage-management-administrators-guide.pdf
- Oracle Data Guard Concepts and Administration: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/data-guard-concepts-and-administration.pdf
- Oracle Data Guard Redo Apply Services: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-apply-services.html
- Oracle Multitenant Guide: https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/overview-of-the-multitenant-architecture.html
- Oracle Database Backup and Recovery User's Guide / RMAN Architecture: https://docs.oracle.com/en/database/oracle/oracle-database/26/bradv/rman-architecture.html
- Oracle Database Advanced Security Guide - TDE: https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/configuring-transparent-data-encryption.html
- Oracle Database Performance Tuning Guide / 2-Day Performance Tuning Guide: https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/database-performance-tuning-guide.pdf
- Oracle Database 2-Day Performance Tuning Guide: https://docs.oracle.com/en/database/oracle/oracle-database/19/tdppt/2-day-performance-tuning-guide.pdf

---

## 14. Final Summary

If you want to be convincing in a technical discussion, you need to demonstrate three things:

1. you know the basic concepts without confusing them;
2. you can connect the concept to a real command, view or error;
3. you know how to think in an operational mode, not just a definitional one.

A strong response from DBA is not long. It is precise, hierarchical and verifiable.


