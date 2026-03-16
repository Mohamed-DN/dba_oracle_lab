# Oracle DBA Questions Guide

> Structured collection of questions, answers and technical scenarios about Oracle DBA. The questions have been curated from multiple public sources, but the answers have been realigned to official Oracle terminology and concepts, with a practical focus on 19c, RAC, Data Guard, ASM, RMAN, multitenant and troubleshooting.

---

## 1. How to Use This Document

Per ogni domanda, costruisci la risposta in 3 strati:

1. definizione corretta in 1-2 frasi;
2. why it matters in production;
3. a working example, a `V$` view or a real command.

Formula pratica:

- `definizione`: che cos'e;
- `impatto`: because the business or DBA takes care of it;
- `operativita`: How do you check or handle it.

Example:

- domanda: `Che differenza c'e tra redo e undo?`
- weak answer: `Redo serve per recovery e undo per rollback.`
- strong answer: `Redo registra le modifiche necessarie a riprodurre i cambiamenti durante recovery o replica Data Guard. Undo conserva la vecchia immagine logica dei dati per rollback e read consistency. Li verifico con il flusso commit, v$log, tablespace UNDO e casi ORA-01555.`

Errore classico da evitare:

- talk only about theoretical definitions without citing a practical case;
- naming tools without knowing when to use them;
- confondere `instance`, `database`, `service`, `SID`, `redo`, `undo`, `restore`, `recover`, `RAC`, `Data Guard`.

---

## 2. Architettura e Concetti Base

### 2.1 Che differenza c'e tra instance e database?

Risposta chiara:

- `instance` = memoria `SGA` + processi background e server;
- `database` = file persistenti: datafile, control file, redo log, archived log, parameter file.

Why it matters:

- when you do `shutdown`, you stop the instance;
- when you do `startup`, the instance goes back to managing the physical database.

Follow-up forte:

- `NOMOUNT` just starts the instance;
- `MOUNT` opens the control file;
- `OPEN` opens datafiles.

### 2.2 Qual e la differenza tra SGA e PGA?

Risposta chiara:

- `SGA` and memory shared between the processes of the instance;
- `PGA` e memoria privata del singolo processo.

Dettagli utili:

- in `SGA` trovi `Buffer Cache`, `Shared Pool`, `Redo Log Buffer`;
- in `PGA` you find sort area, hash area, stack, private state of the process.

Domanda successiva tipica:

- `Se manca memoria dove guardi?`
- risposta: `AWR`, `v$sga_dynamic_components`, `v$pgastat`, `v$memory_target_advice`, wait events e paging OS.

### 2.3 What is the Buffer Cache for?

Risposta chiara:

- mantiene in memoria i blocchi letti o modificati;
- riduce I/O fisico;
- also contains dirty blocks not yet written to datafile.

Punto importante da dire:

- the `commit` does not wait for the block to be written to the datafile;
- aspetta il redo su disco.

### 2.4 Cos'e la Shared Pool?

Risposta chiara:

- and the area of ​​`SGA` which contains already parsed SQL and PL/SQL and dictionary metadata;
- comprende soprattutto `Library Cache` e `Data Dictionary Cache`.

Segnali di problema:

- hard parse eccessivo;
- `ORA-04031`;
- invalidazioni frequenti.

### 2.5 Che differenza c'e tra hard parse e soft parse?

Risposta chiara:

- `hard parse`: Oracle needs to do full parsing, optimization and creation of a new plan;
- `soft parse`: Oracle riusa strutture gia esistenti in cache.

Why it matters:

- troppi hard parse aumentano CPU e latch/mutex contention;
- le bind variables riducono hard parse inutili in molti workload OLTP.

### 2.6 What happens during a commit?

Risposta chiara:

- Oracle genera redo;
- `LGWR` scrive il redo nei redo log online;
- only then does it confirm the commit to the session.

Punto da dire bene:

- `DBWn` can write datafiles later;
- e il principio del write-ahead logging.

### 2.7 Redo e undo: differenza reale?

Risposta chiara:

- `redo` descrive le modifiche per recovery e replica;
- `undo` preserves the previous state of the data for rollback and read consistency.

Domanda-trabocchetto tipica:

- `Si puo fare recovery con il solo undo?`
- No. Oracle recovery is based on redo.

### 2.8 Cos'e uno SCN?

Risposta chiara:

- `SCN` e il contatore logico del tempo interno Oracle;
- serves to coordinate consistency, recovery, flashback and block synchronization.

Why it's important:

- Oracle usa SCN + undo per garantire read consistency;
- SCN appare in backup, RMAN, Data Guard, flashback, recovery e clone consistenti.

### 2.9 What are control files and why are they critical?

Risposta chiara:

- i control file contengono metadati strutturali del database;
- Oracle li usa per sapere quali datafile, redo log, checkpoint e incarnazioni esistono.

Se si perdono:

- il database non monta;
- servono restore/recreate e recovery accurati.

### 2.10 SPFILE e PFILE: differenza?

Risposta chiara:

- `PFILE` e testo leggibile e modificabile a mano;
- `SPFILE` e binario, gestito da Oracle, supporta `ALTER SYSTEM ... SCOPE=SPFILE/BOTH`.

Nota pratica:

- in single instance spesso va bene uno `SPFILE` locale;
- in RAC lo `SPFILE` it must typically be in ASM or shared storage.

### 2.11 What does the password file do?

Risposta chiara:

- enable remote authentication for administrative users such as `SYS`, `SYSDG`, `SYSBACKUP`, `SYSKM`;
- e controllato da `REMOTE_LOGIN_PASSWORDFILE`.

Caso pratico:

- Data Guard uses consistent file passwords between primary and standby for remote administrative connections.

### 2.12 Why is the listener not the database?

Risposta chiara:

- the listener accepts network connections and forwards them to the correct service;
- non esegue SQL e non contiene dati.

Errore tipico:

- think that restarting the listener restarts the database. It's not like that.

### 2.13 Service name e SID: quale usi per le applicazioni?

Risposta chiara:

- per le applicazioni si usa il `service`;
- the `SID` identifies a specific instance.

Why it's a best practice:

- services support load balancing, failover, role-based routing, PDB and RAC;
- il `SID` e troppo rigido per ambienti HA.

### 2.14 What are data blocks, extents, segments and table spaces?

Risposta chiara:

- `data block`: unita minima di I/O Oracle;
- `extent`: gruppo di blocchi allocati insieme;
- `segment`: set of extents for an object such as table or index;
- `tablespace`: contenitore logico di segmenti.

### 2.15 Che differenza c'e tra tempfiles e datafiles?

Risposta chiara:

- i `datafile` contengono dati permanenti;
- `tempfile` supports sort, hash and temporary operations, they are not recovered in the same way as datafiles.

---

## 3. Backup, Recovery e RMAN

### 3.1 Why is RMAN preferable to manual OS backups?

Risposta chiara:

- conosce la struttura Oracle;
- manages consistent backups, block-level checks, restore, recover, cataloging, retention and integration with control file/catalog.

What more to say:

- sa leggere corruption a livello blocco;
- integra `validate`, `crosscheck`, `duplicate`, `block media recovery`.
### 3.2 Che differenza c'e tra restore e recover?

Risposta chiara:

- `restore` = rimettere i file da backup;
- `recover` = apply redo/archivelog to bring them to a consistent state.

Questa e una domanda base ma eliminatoria.

### 3.3 Che differenza c'e tra backup set e image copy?

Risposta chiara:

- `backup set` e il formato RMAN compresso/logico piu comune;
- `image copy` e una copia fisica molto simile al file originale.

Quando citarli:

- `backup set` per backup tradizionali;
- `image copy` useful in incremental merge or rapid copy recovery strategies.

### 3.4 Are full backup and level 0 the same thing?

Risposta chiara:

- no, non sempre dal punto di vista concettuale RMAN;
- `incremental level 0` e la base di una catena incrementale;
- `full` is not used as the basis for incrementals `level 1` in the same way.

### 3.5 What are incremental level 1 differential and cumulative?

Risposta chiara:

- `differential`: saves blocks changed since the last incremental backup of a lower or equal level;
- `cumulative`: Save the blocks changed since the last level 0.

Impatto pratico:

- differential = backup giornalieri piu piccoli;
- cumulative = recovery piu semplice ma backup piu grandi.

### 3.6 What are `crosscheck`, `delete expired` and `delete obsolete` for?

Risposta chiara:

- `crosscheck` checks whether backups still exist on the media;
- `expired` = backup attesi ma non piu trovati;
- `obsolete` = backup non piu necessari secondo retention policy.

Errore comune:

- confuse `expired` with `obsolete`.

### 3.7 What does `validate` do?

Risposta chiara:

- checks the integrity and readability of backup files or datafiles without performing a complete restore in production;
- It is used to test whether the backups are really usable.

### 3.8 What is the control file autobackup for?

Risposta chiara:

- automatically protects control files and SPFILEs after structurally relevant backups;
- and often the lifesaver when you lose control files and local catalog.

### 3.9 Catalog or nocatalog: what do you choose?

Risposta chiara:

- `nocatalog` va bene per ambienti semplici e piccoli;
- `recovery catalog` provides more history, reporting and centralized management, useful in enterprise environments.

### 3.10 Cos'e il block change tracking?

Risposta chiara:

- and a file that helps RMAN know which blocks have changed after level 0;
- accelera gli incremental backup.

### 3.11 How do you recover a lost datafile?

Risposta chiara:

- put the database/tablespace into the correct state if necessary;
- `RESTORE DATAFILE ...`;
- `RECOVER DATAFILE ...`;
- poi rimetti online il file o apri il database a seconda del caso.

### 3.12 How do you handle a crash with `shutdown abort`?

Risposta chiara:

- al successivo startup Oracle esegue `instance recovery`;
- usa redo per rifare le modifiche committate non scritte nei datafile e undo per ripulire le transazioni incomplete.

### 3.13 `ARCHIVELOG` vs `NOARCHIVELOG`: differenza pratica?

Risposta chiara:

- in `ARCHIVELOG` you can make online backups and more complete point-in-time media recovery;
- in `NOARCHIVELOG` hai recovery piu limitata e normalmente backup offline per consistenza forte.

### 3.14 How do you recover SPFILE if you lose it?

Risposta chiara:

- you can use a `PFILE` di emergenza;
- you can recover from RMAN autobackup or create one from memory/SPFILE backup if available.

### 3.15 Quando useresti `DUPLICATE`?

Risposta chiara:

- to create standby, clone/test, refresh, assisted migration or duplicate environments from active database.

---

## 4. Data Guard

### 4.1 What is the difference between physical, logical and snapshot standby?

Risposta chiara:

- `physical standby`: apply redo physically to datafiles;
- `logical standby`: apply logical SQL transformations;
- `snapshot standby`: standby temporarily opened to read write for testing, then reconvertible.

In your lab the strong answer is: `uso physical standby per robustezza e allineamento semplice con RMAN e Broker.`

### 4.2 What main processes do you need to know about in Data Guard?

Risposta chiara:

- lato transport: `LGWR`, `ARCn`, `LNS`, `RFS`;
- apply side: `MRP0` for physical standby.

Follow-up forte:

- `RFS` receives redo on standby;
- `MRP0` applica redo;
- with real-time apply the standby uses the `SRL`s without waiting for the archivelog to complete.

### 4.3 Why are standby redo logs needed?

Risposta chiara:

- they allow real-time apply and a more correct transport to standby;
- sono necessari per molte configurazioni sane di Data Guard.

Regola pratica da ricordare:

- for each thread standby redo logs >= online redo logs of the primary + 1.

### 4.4 `SYNC` vs `ASYNC`: differenza?

Risposta chiara:

- `SYNC` requires acknowledgment for higher protection and greater potential impact on primary latency;
- `ASYNC` prioritizes performance and throughput, with possible small data loss in the event of a sudden disaster.

### 4.5 Qual e la differenza tra switchover e failover?

Risposta chiara:

- `switchover` = role change planned and without expected data loss;
- `failover` = emergency standby promotion after primary loss or switchover failure.

### 4.6 What is the Broker and why use it?

Risposta chiara:

- `Data Guard Broker` centralizes management and validation of Data Guard;
- semplifica switchover, failover, fast-start failover, health checks e proprieta.

### 4.7 What are `transport lag` and `apply lag`?

Risposta chiara:

- `transport lag` = delay in redo transfer from primary to standby;
- `apply lag` = ritardo tra redo ricevuto e redo applicato.

Vista da citare:

- `v$dataguard_stats`.

### 4.8 `db_name` e `db_unique_name`: differenza?

Risposta chiara:

- `db_name` remains the same between primary and standby in the same DG configuration;
- `db_unique_name` uniquely identifies each database in the configuration.

### 4.9 What are `FAL_SERVER` and `FAL_CLIENT` for?

Risposta chiara:

- servono alla gap resolution per recuperare archive log mancanti;
- diventano particolarmente importanti in scenari di ruolo invertibile e riconnessione.

### 4.10 What does `MRP0 APPLYING_LOG` mean?

Risposta chiara:

- that the standby managed recovery process is applying redo;
- In a RAC standby it is normal for the apply to live on only one instance at a time.

### 4.11 MaxPerformance, MaxAvailability, MaxProtection: differenze?

Risposta chiara:

- `MaxPerformance`: tipicamente `ASYNC`, minima latenza, data loss minimo possibile ma non nullo in disastro;
- `MaxAvailability`: attempt zero data loss with `SYNC`, while still keeping the primary available in many manageable faults;
- `MaxProtection`: maximum protection, but the primary can stop if it fails to protect redos as required.

### 4.12 Active Data Guard che vantaggio da?

Risposta chiara:

- allows use of standby in `READ ONLY WITH APPLY`;
- useful for reporting, read-only queries, some workload offloads, and GoldenGate/monitoring cases.

### 4.13 How do you seriously verify that Data Guard is healthy?

Risposta chiara:

- on the primary: `v$archive_dest` and no errors on the remote destination;
- on standby: `v$managed_standby`, `v$dataguard_stats`, `v$database`, alert log, Broker `show configuration` if used.

### 4.14 Quali errori comuni guardi per primi in Data Guard?

Risposta chiara:

- `ORA-12514`, `ORA-12154`, `ORA-01017`, archived log gap, missing SRLs, inconsistent file password, wrong listener/service, bad `DB_UNIQUE_NAME`, standby in incorrect state.

---

## 5. RAC e ASM

### 5.1 Qual e la differenza tra RAC e Data Guard?

Risposta chiara:

- `RAC` provides high availability and active/active scalability on the same shared database;
- `Data Guard` fornisce disaster recovery e protezione dati mantenendo database distinti.

Risposta forte:

- RAC non sostituisce DR;
- Data Guard non sostituisce la scalabilita locale di RAC.
### 5.2 Cos'e Cache Fusion?

Risposta chiara:

- e il meccanismo RAC che trasferisce blocchi tra buffer cache di istanze diverse via interconnect, invece di forzare sempre la scrittura preventiva su disco.

Why it is central:

- e il cuore dell'accesso concorrente RAC al database condiviso.

### 5.3 Che cos'e lo SCAN?

Risposta chiara:

- `Single Client Access Name` e il nome logico usato dai client per connettersi a un cluster RAC;
- simplifies failover and load balancing without making all nodes known to clients.

### 5.4 What are OCR and Voting Disk used for?

Risposta chiara:

- `OCR` preserves cluster configuration and resources;
- `Voting Disk` aiuta il cluster a determinare membership e quorum.

### 5.5 Why are services used in RAC and not connections fixed to the node?

Risposta chiara:

- per load balancing, failover, role separation, patching rolling e associazione a PDB o workload specifici.

### 5.6 Cos'e ASM?

Risposta chiara:

- `ASM` e il layer storage Oracle specializzato per file database;
- simplifies naming, striping, mirroring and file management for databases, RMAN, RAC and Data Guard.

### 5.7 Che differenza c'e tra disk group e failure group?

Risposta chiara:

- `disk group` = logical set of ASM disks;
- `failure group` = group that ASM uses for redundancy, to prevent mirror copies from ending up in the same fault domain.

### 5.8 Why put SPFILE and password file in ASM in RAC?

Risposta chiara:

- per avere file condivisi e consistenti tra i nodi;
- avoids divergences between local files and simplifies clusterware startup.

### 5.9 Cos'e un rebalance ASM?

Risposta chiara:

- and ASM data rebalancing when you add or remove disks;
- ha impatto I/O e va monitorato.

Vista da citare:

- `v$asm_operation`.

### 5.10 How do you distinguish a cluster problem from a database problem?

Risposta chiara:

- cluster side look at `crsctl`, `srvctl`, OCR, listener, VIP, SCAN, resource status;
- lato database guardi alert log, `v$instance`, `v$database`, wait events, storage e parametri.

### 5.11 Che differenza c'e tra `srvctl` e `sqlplus startup` in RAC?

Risposta chiara:

- `srvctl` manages the database as a clusterware resource;
- `sqlplus startup` acts only on the local instance and can bypass the cluster logic.

Best practice:

- in RAC e Data Guard clusterizzati, usa `srvctl` per start/stop normali.

### 5.12 How do you check the cluster status?

Risposta chiara:

- `crsctl stat res -t`;
- `srvctl status database -d <db_unique_name> -v`;
- `olsnodes -n -s`;
- `asmcmd lsdg` per storage.

---

## 6. Multitenant, Security e TDE

### 6.1 Cos'e un CDB e cos'e un PDB?

Risposta chiara:

- `CDB` e il container database che ospita root, seed e PDB;
- `PDB` is the pluggable database which appears almost independent but shares the instance and infrastructure of the CDB.

### 6.2 What is `PDB$SEED` for?

Risposta chiara:

- e il template read-only usato per creare nuovi PDB in modo rapido e consistente.

### 6.3 Common user e local user: differenza?

Risposta chiara:

- `common user` esiste a livello CDB e segue regole di naming/presenza comuni;
- `local user` exists only in the specific PDB.

### 6.4 Does a PDB have its own separate instance?

Risposta chiara:

- no;
- PDBs share the CDB instance, memory, and processes.

### 6.5 How do you connect an application to a PDB correctly?

Risposta chiara:

- tramite un `service` associato al PDB;
- non tramite login al root o SID nudo.

### 6.6 Cos'e TDE?

Risposta chiara:

- `Transparent Data Encryption` protegge i dati a riposo cifrando colonne o tablespace;
- keys are managed via keystore/wallet.

### 6.7 Chi dovrebbe gestire il keystore TDE?

Risposta chiara:

- ideally an account with dedicated privileges such as `SYSKM` or role consistent with internal governance;
- not always just `SYSDBA`.

### 6.8 What happens if you lose the TDE wallet/keystore?

Risposta chiara:

- i dati cifrati possono diventare inutilizzabili;
- il backup del keystore e critico quanto il backup del database.

### 6.9 In RAC where do you put the TDE keystore?

Risposta chiara:

- on supported shared storage, so all nodes see the same keystore;
- Oracle sconsiglia wallet locali non condivisi per casi RAC comuni.

### 6.10 What do you check when a keystore doesn't open?

Risposta chiara:

- `WALLET_ROOT`, `TDE_CONFIGURATION`, OS permissions, wallet type, keystore status in `v$encryption_wallet`, sincronizzazione tra nodi se cluster.

### 6.11 Why is password policy management not enough for DBA security?

Risposta chiara:

- la sicurezza DBA include auditing, least privilege, secret management, network encryption, TDE, patching, segregazione dei ruoli e hardening OS.

---

## 7. Performance, Diagnostica e Tuning

### 7.1 What are AWR, ASH and ADDM for?

Risposta chiara:

- `AWR` raccoglie snapshot e metriche storiche di performance;
- `ASH` traccia campioni di session activity ad alta frequenza;
- `ADDM` analizza i dati e propone findings.

### 7.2 Quando usi AWR e quando ASH?

Risposta chiara:

- `AWR` per analisi storiche su un intervallo;
- `ASH` to see who was waiting for what at a time or in a narrow window.

### 7.3 What do you look at first in an AWR report?

Risposta chiara:

- DB time;
- top foreground waits;
- load profile;
- SQL ordered by elapsed time / CPU / gets / reads;
- instance efficiency only with prudence, not as absolute truth.

### 7.4 How do you analyze a high CPU problem?

Risposta chiara:

- distingui CPU Oracle vs OS;
- guardi AWR/ASH, top SQL, hard parse, parallelismo, execution plan regressi, processi OS e scheduling.
### 7.5 How do you find a blocking session?

Risposta chiara:

- `v$session`, `v$lock`, `gv$session` in RAC, eventualmente ASH/AWR se il blocco non e piu attivo.

### 7.6 `ORA-01555 snapshot too old`: what does it really come from?

Risposta chiara:

- typically from insufficient undo or override too early relative to the duration of the consistent query;
- It's not just a problem of long queries, but of retention, workload and undo pressure.

### 7.7 `ORA-04031` what does it tell you?

Risposta chiara:

- that Oracle is unable to allocate contiguous memory from a shared memory structure, often `Shared Pool` or similar pool;
- va indagato su dimensionamento, frammentazione, hard parse e componenti attivi.

### 7.8 If a query is slow, where do you start?

Risposta chiara:

- I confirm whether the problem is new or historical;
- I look at real execution plan, statistics freshness, waits, cardinality mismatch, bind peeking, I/O, locking, temp and parallelism.

### 7.9 Why are statistics important?

Risposta chiara:

- the cost-based optimizer decides the plan based on statistics;
- statistiche stale o sbagliate possono generare piani pessimi.

### 7.10 Rebuild index: soluzione standard?

Risposta chiara:

- no;
- it is only done if there is a real reason, not as an automatic reflex.

Risposta forte:

- first I check real fragmentation, blevel, clustering factor, access pattern and if the problem really lies in the index.

### 7.11 How do you check the status of tablespaces and FRAs?

Risposta chiara:

- tablespace: `DBA_DATA_FILES`, `DBA_FREE_SPACE`, `DBA_TEMP_FREE_SPACE`, metriche OEM;
- FRA: `v$recovery_file_dest`, `v$flash_recovery_area_usage`.

### 7.12 Alert log o trace file: quando usi uno e quando l'altro?

Risposta chiara:

- alert log per eventi principali e cronologia di alto livello;
- trace file per dettaglio tecnico di errori, incidenti, sessioni e processi specifici.

### 7.13 What is ADRCI and why is it useful?

Risposta chiara:

- e la CLI dell'Automatic Diagnostic Repository;
- It is used to navigate alert, incident, trace and diagnostic purge also in RAC/Data Guard.

---

## 8. Operational Troubleshooting and Interview Scenarios

### 8.1 The database does not start and see `ORA-01034`. Where are you leaving from?

Risposta chiara:

- I check if the instance is really down;
- check `ORACLE_SID`, `ORACLE_HOME`, alert log, parameter file, spfile/pfile, listener status and clusterware if RAC.

### 8.2 A listener is on but returns `ORA-12514`. What does it mean?

Risposta chiara:

- the listener does not yet know the requested service;
- typically dynamic registration problem, wrong service, wrong TNS alias or database not in expected state.

### 8.3 Standby is mounted but does not apply redo. What do you control?

Risposta chiara:

- `MRP0`, `RFS`, `v$archive_dest`, `v$dataguard_stats`, listener/service, file password, SRL, gap archive, TNS errors, database role and Broker if active.

### 8.4 `DEST_ID=2 ERROR` on primary in Data Guard: what do you think immediately?

Risposta chiara:

- trasporto redo fallito;
- control `error` in `v$archive_dest`, aka TNS, standby listener, service standby, file password, standby status and network.

### 8.5 La FRA e piena. Quali rischi hai?

Risposta chiara:

- archiving can stop;
- backup/recovery/flashback possono degradare o bloccarsi;
- in severe cases it also impacts the primary.

Azioni tipiche:

- understand what takes up space;
- liberare in modo controllato;
- riallineare retention e dimensionamento.

### 8.6 A tablespace is almost full. What are you doing?

Risposta chiara:

- verifico autoextend, spazio reale, crescita, segmenti maggiori, business impact;
- then I add space, extend files or clean up only if supported.

### 8.7 A RAC node falls. How do you answer correctly?

Risposta chiara:

- I check clusterware, vip/service relocation, alert/trace, interconnect, ASM and resource status;
- then I understand if the problem is node, GI, network, storage or database.

### 8.8 Hai backup RMAN, ma nessuno ha mai testato restore. E sufficiente?

Risposta chiara:

- no;
- backup non verificato non e un backup affidabile.

Risposta forte:

- servono `validate`, restore test, runbook e prove periodiche di recovery.

### 8.9 How do you distinguish `restore controlfile` from `recover database using backup controlfile`?

Risposta chiara:

- il primo rimette il control file;
- il secondo entra nel flusso di recovery quando il control file usato non e perfettamente allineato alla storia corrente e richiede approccio di recovery compatibile.

### 8.10 If an application suddenly stops connecting, where do you start?

Risposta chiara:

- listener, service, DNS/SCAN if RAC, firewall, `sqlnet.ora`, DB status, account lock, recent errors in alert log and client side.

### 8.11 How do you respond if they ask you about a typical day as a DBA?

Risposta chiara:

- checking availability, backup, alerts, space, DG lag, critical jobs, listeners/services, performance regressions, open incidents and planned changes.

### 8.12 What do you do before patching?

Risposta chiara:

- verified backups, sufficient space, patch prerequisites, clean inventory, opatch/opatchauto conflicts, change window, rollback plan, cluster status and validated runbook.

### 8.13 What do you do after patching?

Risposta chiara:

- I check version, inventory, alert log, services, listener, broker, backup, job, initial performance and application health check.

### 8.14 How do you explain a difference between `READ ONLY`, `MOUNTED` and `READ ONLY WITH APPLY`?

Risposta chiara:

- `MOUNTED`: standby not open to normal users;
- `READ ONLY`: open for read only but without apply in the simple case;
- `READ ONLY WITH APPLY`: Active Data Guard, query e apply insieme.

### 8.15 If the topic enters critical production, what do you change in your approach?

Risposta chiara:

- more standardization, change control, RPO/RTO, hardening, monitoring, test recovery, runbook, role segregation, zero hardcoded secrets, DR tests and periodic validation.

---

## 9. Senior or Team Lead questions

### 9.1 How do you define RPO and RTO to a non-technical manager?

Risposta chiara:

- `RPO` = how much data you can afford to lose;
- `RTO` = how long it takes to get back up and running.

### 9.2 How do you choose between single instance, RAC and Data Guard?

Risposta chiara:

- single instance per semplicita;
- RAC per HA locale e scalabilita;
- Data Guard per DR;
- spesso in ambienti seri RAC + Data Guard insieme.

### 9.3 How do you defend an enterprise backup strategy?

Risposta chiara:

- full/incremental backups consistent with RPO/RTO;
- retention chiara;
- FRA dimensionata;
- control file autobackup;
- restore test periodici;
- offsite or standby-based backup where useful.
### 9.4 How do you set up serious monitoring?

Risposta chiara:

- availability, redo transport/apply lag, FRA, table space, backup success, wait anomalies, listener/service health, cluster resources, job failures, CPU/memory/I/O, and incident routing.

### 9.5 What would you never do as a DBA in production?

Risposta chiara:

- destructive commands without recovery path;
- modifiche manuali non documentate su cluster/ASM;
- patching without rollback plan;
- change multiple variables together without isolating the risk;
- leave hardcoded password in script or repo.

### 9.6 How do you explain a regression after application release?

Risposta chiara:

- AWR/ASH before-after comparison, new SQLs, changed plan, mutated statistics, different bind pattern, locking, data volume, parameter drift, new code path.

### 9.7 Quando usi switchover invece di failover?

Risposta chiara:

- when the primary is still healthy and the role transition is plannable;
- for maintenance, DR testing or low-risk migration.

### 9.8 How do you demonstrate technical maturity?

Risposta chiara:

- parli per runbook, verifiche, trade-off e failure mode;
- you don't sell magic, you sell operational control.

---

## 10. Rapid Fire: Short High Frequency Questions

Use them for quick review.

1. `Che cos'e LGWR?` Scrive redo online.
2. `Che cos'e DBWn?` Scrive dirty blocks ai datafile.
3. `Che cos'e CKPT?` Coordina checkpoint e aggiorna header/control file.
4. `Che cos'e SMON?` Does system recovery and housekeeping.
5. `Che cos'e PMON?` Ripulisce risorse di processi/sessioni fallite; in release moderne alcune responsabilita sono cambiate ma il concetto resta.
6. `Che cos'e ARCn?` Archivia redo online in archived log.
7. `Che cos'e LREG?` Register services to the listener.
8. `Che cos'e MRP0?` Apply redo on physical standby.
9. `Che cos'e RFS?` Receive redo on standby.
10. `Che cos'e FRA?` Area recovery per archived log, backup, flashback e file collegati.
11. `Che cos'e OMF?` Oracle Managed Files, naming/placement gestiti da Oracle.
12. `Che cos'e ASM?` Storage layer Oracle per file database.
13. `Che cos'e SCAN?` Nome unico per accesso client a un cluster RAC.
14. `Che cos'e OCR?` Cluster configuration repository.
15. `Che cos'e Voting Disk?` Quorum e membership cluster.
16. `Che cos'e AWR?` Repository storico performance.
17. `Che cos'e ASH?` Session activity sampling.
18. `Che cos'e ADDM?` Analisi automatica dei dati AWR.
19. `Che cos'e TDE?` Cifratura dati a riposo.
20. `Che cos'e un PDB?` Database pluggable dentro un CDB.

---

## 11. Scenario Questions to Simulate Orally

Queste valgono piu di molte definizioni.

1. `Lo standby e in lag ma il primary e sano. Dimmi il piano di triage.`
2. `Hai perso un datafile utente. Dimmi restore e recover.`
3. `Il listener e up ma le app ricevono ORA-12514.`
4. `Dopo patching un solo nodo RAC non riparte.`
5. `La FRA ha raggiunto il 95%.`
6. `Un PDB non apre dopo clone o plug.`
7. `AWR mostra CPU alta ma l'app dice lentezza I/O.`
8. `DGMGRL dice warning ma SQL mostra apply attivo.`
9. `Un job RMAN e green, ma validate fallisce.`
10. `Dopo switchover alcune app puntano ancora al vecchio ruolo.`

Recommended response method:

- initial state;
- impatto business;
- verifiche immediate;
- ipotesi ordinate per probabilita;
- fix;
- final check;
- prevenzione futura.

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

- un runbook rapido per datafile loss;
- un runbook rapido per DG lag;
- un runbook rapido per ORA-12514;
- un runbook rapido per tablespace/FRA pieni;
- un confronto serio tra `MaxPerformance` e `MaxAvailability`.

---

## 13. Fonti Usate

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

## 14. Sintesi Finale

If you want to be convincing in a technical discussion, you need to demonstrate three things:

1. you know the basic concepts without confusing them;
2. you can connect the concept to a real command, view or error;
3. you know how to think in an operational mode, not just a definitional one.

Una risposta forte da DBA non e lunga. E precisa, gerarchica e verificabile.


