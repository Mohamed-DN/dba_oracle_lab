# Oracle Architecture: Complete Guide to Fundamental Concepts

> This guide explains the architectural concepts that an Oracle DBA must truly master. The goal is not to memorize isolated definitions, but to understand how Oracle reads, writes, retrieves, scales and protects data.

---

## 1. Modello Mentale di Base

Un database Oracle e' composto da due parti distinte:

1. the Oracle instance;
2. il database fisico su disco.

```text
+---------------------------------------------------------------+
|                        ORACLE INSTANCE                         |
|                                                               |
|  SGA (memoria condivisa)                                      |
|  - Database Buffer Cache                                      |
|  - Shared Pool                                                |
|  - Redo Log Buffer                                            |
|  - Large Pool / Java Pool / Streams Pool                      |
|                                                               |
|  PGA (memoria privata per processo)                           |
|                                                               |
|  Processi                                                     |
|  - Server processes                                           |
|  - Background processes                                       |
+-------------------------------+-------------------------------+
                                |
                                | legge / scrive
                                v
+---------------------------------------------------------------+
|                        DATABASE FILES                          |
|                                                               |
|  Datafiles                                                    |
|  Tempfiles                                                    |
|  Control files                                                |
|  Online redo logs                                             |
|  Archived redo logs                                           |
|  SPFILE / PFILE                                               |
|  File password                                                |
|  FRA                                                          |
+---------------------------------------------------------------+
```

Definizioni corrette:

- `istanza` = memoria + processi;
- `database` = insieme dei file persistenti;
- quando fai `shutdown immediate`, stop the instance, do not delete the database;
- quando fai `startup`, the instance returns to managing database files.

Concetto chiave:

- the instance is volatile;
- il database e' persistente.

Blocco visivo:

```text
           STARTUP
              |
              v
   +-----------------------+
   | NOMOUNT               |
   | SGA + processi attivi |
   | nessun control file   |
   +-----------------------+
              |
              v
   +-----------------------+
   | MOUNT                 |
   | control file aperto   |
   | struttura nota        |
   +-----------------------+
              |
              v
   +-----------------------+
   | OPEN                  |
   | datafile e redo aperti|
   | utenti ammessi        |
   +-----------------------+
```

---

## 2. Ciclo di Vita del Database: NOMOUNT, MOUNT, OPEN

Oracle non parte sempre direttamente in `OPEN`. Ci sono tre fasi distinte.

### 2.1 NOMOUNT

In `NOMOUNT`, Oracle reads the parameter file and starts the instance.

Disponibile:

- SGA;
- background processes;
- parameter file.

Not available yet:

- control file aperto;
- datafile montati;
- redo log aperti per uso normale.

Uso tipico:

- database creation;
- RMAN duplicate;
- recupero di SPFILE;
- bootstrap standby.

### 2.2 MOUNT

In `MOUNT`, Oracle opens the control file and knows the database structure.

Disponibile:

- control file;
- elenco datafile e redo log;
- metadati di montaggio.

Not available yet:

- normal access to data by users.

Uso tipico:

- media recovery;
- database standby;
- rename file;
- enable/disable archivelog;
- operazioni Data Guard.

### 2.3 OPEN

In `OPEN`, Oracle opens datafiles and redo logs and the database becomes usable.

Varianti comuni:

- `OPEN READ WRITE`;
- `OPEN READ ONLY`;
- `MOUNTED` for physical standby;
- `READ ONLY WITH APPLY` per Active Data Guard.

### 2.4 Shutdown Modes

I principali sono:

- `SHUTDOWN NORMAL`: wait for all users to log out;
- `SHUTDOWN IMMEDIATE`: rollback of uncommitted transactions and clean closure;
- `SHUTDOWN ABORT`: brutal stop, recovery at next startup;
- `SHUTDOWN TRANSACTIONAL`: aspetta fine transazioni attive.

Nel lab, il piu' usato e' `IMMEDIATE`.

---

## 3. Memory Architecture

Oracle usa due grandi aree di memoria:

1. `SGA` condivisa;
2. `PGA` privata.

Schema rapido:

```text
+-------------------------------------------------------------------+
|                           ORACLE INSTANCE                          |
|                                                                   |
|  +--------------------------- SGA -------------------------------+ |
|  | Buffer Cache | Shared Pool | Redo Buffer | Large/Java/Streams| |
|  +---------------------------------------------------------------+ |
|                                                                   |
|  +--------------------------- PGA -------------------------------+ |
|  | memoria privata del singolo processo: sort, hash, stack      | |
|  +---------------------------------------------------------------+ |
+-------------------------------------------------------------------+
```

### 3.1 SGA: Instance shared memory

All server and background processes read or write the SGA.

Componenti principali.

#### Database Buffer Cache

Contiene blocchi di dati letti dai datafile.

Funzione:

- ridurre I/O fisico;
- mantenere in RAM i blocchi piu' usati;
- host blocks that have been modified but not yet written to disk.

Stati logici dei blocchi:

- `clean`: blocco uguale alla copia su disco;
- `dirty`: modified in memory, not yet written by DBWn.

Concetto importante:

- il commit non aspetta la scrittura del blocco dirty sul datafile;
- il commit aspetta il redo su disco.

#### Shared Pool

Contiene strutture condivise necessarie all'esecuzione SQL.

Sottocomponenti chiave:

- `Library Cache`: SQL parsato, PL/SQL, execution plans;
- `Data Dictionary Cache`: metadata of tables, users, objects, privileges.

If the Shared Pool is small or fragmented you can see:

- hard parse eccessivi;
- invalidazioni;
- errori `ORA-04031`.

#### Redo Log Buffer

Circular buffer in RAM where Oracle accumulates redo records before LGWR writes them to the online redo logs.

Contiene:

- description of the changes;
- non i blocchi interi, ma change vectors.

#### Large Pool

Area opzionale usata da:

- RMAN;
- parallel execution;
- shared server;
- alcune operazioni I/O e messaging.

It serves to avoid unnecessary pressure on the Shared Pool.

#### Java Pool

Usata se il database esegue componenti Java interni.

#### Streams Pool

Usata da funzionalita' di streaming e replication in alcuni scenari.

### 3.2 PGA: memoria privata

Ogni processo Oracle ha la propria PGA.

Contiene tipicamente:

- sort area;
- hash area;
- stack;
- informazioni di sessione o processo;
- cursor state lato processo.

Caratteristiche:

- non e' condivisa;
- cresce per sessione o processo;
- e' critica per sort, hash join, bitmap merge, parallel execution.

### 3.3 UGA

La `UGA` it is the memory associated with the user session.

Dipende dal modello di connessione:

- con `dedicated server`, la UGA sta nella PGA del server process;
- con `shared server`, la UGA sta nella SGA.

### 3.4 Automatic memory management

Modelli principali.

#### ASMM

Automatic Shared Memory Management.

Parametri tipici:

- `SGA_TARGET`;
- `SGA_MAX_SIZE`;
- `PGA_AGGREGATE_TARGET`.

E' il modello piu' comune nel lab Oracle classico.

#### AMM

Automatic Memory Management.

Parametri tipici:

- `MEMORY_TARGET`;
- `MEMORY_MAX_TARGET`.

It can handle SGA and PGA together, but in many real world environments ASMM or explicit tuning is preferred.

---

## 4. Architettura dei Processi

Oracle usa:

1. processi client;
2. listener;
3. server processes;
4. background processes.

### 4.1 Client process

E' il processo applicativo o lo strumento che si connette a Oracle:

- SQL*Plus;
- JDBC;
- Python;
- applicazione web.

### 4.2 Listeners

The listener receives the network connection and forwards it to the correct service.

Non esegue SQL.

Fa da dispatcher iniziale:

- listen at the door;
- knows the registered services;
- passa la sessione al server process.

### 4.3 Server process

It is the process that actually does the work of the session.

Compiti:

- parse;
- execute;
- fetch;
- accesso ai blocchi;
- cursor management;
- interazione con PGA e SGA.

Modelli:

- `dedicated server`: un server process per sessione;
- `shared server`: piu' sessioni condividono risorse server.

Nel tuo lab usi quasi sempre `dedicated server`.

### 4.4 Background processes fondamentali

| Processo | Ruolo pratico |
|---|---|
| `DBWn` | scrive i dirty buffers dalla Buffer Cache ai datafile |
| `LGWR` | scrive redo dal Redo Log Buffer agli online redo logs |
| `CKPT` | segnala checkpoint e aggiorna header/control file |
| `SMON` | instance recovery e housekeeping |
| `PMON` | cleanup di processi/sessioni fallite |
| `ARCn` | archivia redo log pieni in archived redo logs |
| `RECO` | recupero transazioni distribuite in dubbio |
| `MMON` | raccolta statistiche manageability/AWR |
| `MMNL` | supporto a MMON |
| `LREG` | Dynamically registers services and instances to listeners |
| `CJQ0` | coordina job scheduler |
| `RVWR` | scrive flashback logs se Flashback e' attivo |
| `FBDA` | Flashback Data Archive |
| `DMON` | Data Guard Broker |
| `VKTM` | gestisce il tempo virtuale interno |

### 4.5 Processi RAC-specifici

Cluster-specific processes also appear in RAC, for example:

- `LMON`;
- `LMD`;
- `LMS`;
- `LCK`.

Servono a:

- cache fusion;
- global enqueue service;
- coordinamento dei blocchi tra istanze.

---

## 5. How Oracle Executes a Query

Flusso semplificato.

```text
1. Client invia SQL
2. Listener forwards to the correct service
3. Server process riceve SQL
4. Parse
5. Bind
6. Execute
7. Lettura blocchi o accesso indici
8. Fetch righe al client
```

Disegno mentale:

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

Il parse non e' solo analisi sintattica.

Include:

- syntax check;
- verify objects and privileges;
- ottimizzazione;
- scelta execution plan;
- lookup o reuse in Library Cache.

Tipi di parse:

- `hard parse`: need new complete parse;
- `soft parse`: Oracle reuses an existing plan.

Obiettivo DBA:

- ridurre hard parse inutili;
- usare bind variables quando ha senso.

### 5.2 Execute

Durante l'execute Oracle:

- acquisisce lock o enqueue necessari;
- legge blocchi richiesti;
- modifica blocchi in memoria se la SQL cambia dati;
- genera redo e undo.

### 5.3 Fetch

Le righe vengono restituite al client in fetch successivi.

Importante:

- a query can be executed once and then fetched many times;
- most of the application time can be spent in fetches, not parse.

---

## 6. Transazioni, SCN, Redo, Undo e Consistenza

Schema del commit:

```text
Sessione
  |
  | UPDATE
  v
Server process
  |
  +--> modifica blocco in Buffer Cache
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
      Online Redo Log su disco
               |
               v
           COMMIT OK

DBWn writes the datafiles afterwards.
```

Questa e' la parte che separa chi usa Oracle da chi lo capisce.

### 6.1 SCN

Lo `SCN` e' il System Change Number.

E' il riferimento temporale o logico interno di Oracle.

It is used for:

- ordinare le modifiche;
- garantire consistenza di lettura;
- recovery;
- flashback;
- Data Guard;
- backup consistency.

### 6.2 Undo

L'undo conserva l'informazione necessaria per:

- fare rollback di transazioni non committate;
- ricostruire versioni precedenti dei blocchi per query consistenti.

Concetto chiave:

- quando fai `UPDATE`, Oracle non sovrascrive solo il dato;
- first record the logical image needed in undo.

### 6.3 Redo

The redo describes all the changes necessary for recovery.

It is used for:

- redo changes after crash;
- alimentare archived redo;
- alimentare Data Guard;
- consentire media recovery.

### 6.4 Commit

Un `COMMIT` non significa che il datafile e' gia' scritto.

Significa:

- the redo of that transaction has been made durable on the online redo logs;
- da quel momento la transazione e' committed.

Per questo il commit e' veloce:

- LGWR fa scrittura sequenziale;
- DBWn writes the datafiles later, with lazy logic.

### 6.5 Read consistency

Oracle garantisce che una query veda una fotografia consistente dei dati a uno SCN logico.

If another session modifies a row while a long query is reading it, Oracle can:

- usare il blocco corrente se compatibile;
- oppure ricostruire la versione precedente tramite undo.

Questo evita letture sporche.

### 6.6 Checkpoint

Il checkpoint non significa stop.

Significa che Oracle:

- aggiorna informazioni di checkpoint in control file e datafile header;
- riduce la quantita' di redo da rileggere in instance recovery.

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
- control file o catalog RMAN.

---

## 7. Strutture Logiche di Storage

Oracle separa architettura logica e fisica.

Ordine logico corretto:

```text
Database
  -> Tablespace
     -> Segment
        -> Extent
           -> Block
```

### 7.1 Data block

Il blocco e' l'unita' minima logica di I/O database.

Parametri chiave:

- `DB_BLOCK_SIZE`;
- tipicamente 8 KB nel lab.

### 7.2 Extent

Un extent e' un insieme di blocchi contigui allocati a un segmento.

### 7.3 Segment

Un segmento e' l'insieme di extents appartenenti a un oggetto.

Tipi comuni:

- table segment;
- index segment;
- undo segment;
- temporary segment;
- LOB segment.

### 7.4 Tablespace

Un tablespace e' il contenitore logico dei segmenti.

Comuni in Oracle:

- `SYSTEM`;
- `SYSAUX`;
- `UNDO`;
- `TEMP`;
- tablespace applicativi.

Tipi importanti:

- permanent;
- temporary;
- undo;
- bigfile;
- smallfile.

### 7.5 Bigfile vs smallfile

#### Smallfile tablespace

- multiple datafiles in the same tablespace;
- modello storico piu' comune.

#### Bigfile tablespace

- un solo datafile molto grande;
- useful in ASM and automated environments.

---

## 8. Strutture Fisiche di Storage

### 8.1 Datafiles

Contengono i blocchi dei tablespace permanenti e undo.

Non contengono:

- redo log;
- control file.

### 8.2 Tempfiles

Usati per:

- sort;
- hash;
- temporary segments.

Differenza pratica:

- they are not recovered like normal datafiles;
- possono essere ricreati.

### 8.3 Control files

They are the minimum physical catalog of the database.

Contengono informazioni su:

- nome DB e DBID;
- datafiles e redo log;
- checkpoint;
- archived log history;
- RMAN metadata minima.

If you lose all control files, the database will not mount.

### 8.4 Online redo logs

Sono il journal attivo del database.

Organizzati in:

- gruppi;
- membri.

Concetti:

- a group is used as `CURRENT`;
- al log switch Oracle passa al gruppo successivo;
- ARCn archivia i gruppi pieni se il DB e' in `ARCHIVELOG`.

### 8.5 Archived redo logs

Sono copie storiche dei redo log online pieni.

Servono per:

- backup e recovery;
- point-in-time recovery;
- standby Data Guard.

### 8.6 SPFILE e PFILE

#### PFILE

- file testuale;
- leggibile e modificabile a mano;
- useful for bootstrap and recovery.

#### SPFILE

- file binario server parameter file;
- normally used in production;
- consente `ALTER SYSTEM SET ... SCOPE=SPFILE|BOTH`.

### 8.7 File passwords

Usato per autenticazione amministrativa remota:

- `SYSDBA`;
- `SYSDG`;
- `SYSBACKUP`;
- `SYSASM`;
- `SYSKM`.

E' critico in:

- RAC;
- Data Guard;
- RMAN duplicate;
- Broker.

### 8.8 FRA

La `Fast Recovery Area` e' un'area gestita da Oracle per file di recovery.

Contiene tipicamente:

- archived logs;
- flashback logs;
- backup pieces;
- copies;
- control file autobackups.

Se si riempie:

- backup e archiviazione possono fermarsi;
- Data Guard can degrade;
- compaiono errori di spazio recovery.

---

## 9. Flusso di Scrittura: UPDATE -> COMMIT

Questo e' il flusso da sapere a memoria.

```text
1. Sessione esegue UPDATE
2. Oracle legge il blocco in Buffer Cache se necessario
3. Oracle genera undo
4. Oracle genera redo
5. Oracle modifica il blocco in Buffer Cache
6. Il blocco diventa dirty
7. COMMIT
8. LGWR scrive redo su online redo log
9. COMMIT ritorna OK
10. DBWn scrivera' il blocco dirty sul datafile piu' tardi
```

Vista step-by-step:

```text
UPDATE
  |
  +--> blocco letto o gia' in cache
  +--> undo generato
  +--> redo generato
  +--> blocco diventa dirty

COMMIT
  |
  +--> LGWR forza il redo su disco
  +--> Oracle conferma il commit

POST-COMMIT
  |
  +--> CKPT aggiorna checkpoint info
  +--> DBWn scarica il dirty block piu' tardi
```

Regola d'oro:

- redo before datafiles;
- questa e' la base del write-ahead logging Oracle.

---

## 10. Oracle Net, Listeners, Services and Dynamic Recording

Blocco visivo:

```text
Applicazione / sqlplus
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

File tipici:

- `listener.ora`;
- `tnsnames.ora`;
- `sqlnet.ora`.

### 10.2 Service vs SID

`SID`:

- identifies a specific instance.

`SERVICE_NAME`:

- identifica il servizio logico usato dalle applicazioni.

Best practice:

- applications must use services, not SIDs;
- in RAC e Data Guard, il service e' il concetto corretto di accesso.

### 10.3 Registrazione dinamica

Il processo `LREG` registers services to the listener.

Parametri coinvolti:

- `LOCAL_LISTENER`;
- `REMOTE_LISTENER`.

In RAC:

- `REMOTE_LISTENER` punta tipicamente allo SCAN;
- services can do load balancing and failover.

Useful command:

```sql
ALTER SYSTEM REGISTER;
```

It is used to force immediate registration after start listener or service changes.

---

## 11. Architettura Multitenant: CDB e PDB

Dal punto di vista 19c, l'architettura multitenant e' centrale.

Schema CDB/PDB:

```text
+---------------------------------------------------------------+
|                           CDB ROOT                            |
|  processi, memoria, redo, undo, dizionario comune            |
|                                                               |
|  +----------------+  +----------------+  +----------------+   |
|  | PDB$SEED       |  | APP_PDB1       |  | APP_PDB2       |   |
|  | template       |  | dati app 1     |  | dati app 2     |   |
|  | read only      |  | local users  |  | local users  |   |
|  +----------------+  +----------------+  +----------------+   |
+---------------------------------------------------------------+
```

### 11.1 Componenti

Ogni CDB include:

- `CDB$ROOT`;
- `PDB$SEED`;
- zero or more user PDBs.

### 11.2 Root

`CDB$ROOT` contiene:

- metadata Oracle comuni;
- common users;
- strutture condivise.

Non e' il posto giusto per i dati applicativi normali.

### 11.3 Seed

`PDB$SEED` e' il template read only usato per creare nuovi PDB.

### 11.4 PDB

A PDB appears to the application as a quasi-independent database, but shares with the CDB:

- instance;
- SGA;
- background processes;
- redo logs;
- control file.

Questo e' fondamentale:

- un CDB con 10 PDB non ha 10 istanze separate;
- has a single instance that manages multiple containers.

### 11.5 Common users e local users

- common user: visible in all containers;
- local user: esiste solo nel PDB.

### 11.6 Services and PDB

Best practice:

- ogni applicazione usa un service associato al PDB;
- in RAC si crea il service con `srvctl add service -pdb ...`.

---

## 12. ASM: Automatic Storage Management

ASM e' il layer storage Oracle ottimizzato per file database.

Fa da:

- volume manager;
- file system specializzato Oracle.

Concetti base:

- ASM instance;
- disk groups;
- failure groups;
- allocation units;
- template, striping e mirroring.

Nel tuo lab usi disk group tipici:

- `+DATA`;
- `+RECO`;
- `+CRS`.

Why ASM is important:

- semplifica naming e placement file;
- supporta OMF;
- si integra bene con RAC, RMAN, Data Guard.

Blocco visivo:

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
datafile                  archivelog
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
- SPFILE condiviso;
- ASM storage.

Non condividono:

- PGA;
- buffer cache locale;
- server processes locali.

Each instance has:

- propria SGA;
- propri processi;
- proprio redo thread;
- proprio undo tablespace.

### 13.2 Cache Fusion

It is the mechanism by which a RAC instance can receive blocks in memory from another instance without going through disk.

E' la chiave di RAC.

### 13.3 SCAN

Lo `SCAN` e' il nome virtuale di accesso al cluster.

It is used for:

- semplificare connessioni client;
- load balancing;
- failover.

### 13.4 Services in RAC

I services permettono di decidere:

- where the workload should run;
- failover;
- ruolo applicativo;
- pinning a PDB.

---

## 14. Data Guard: Architettura di Protezione

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

### 14.1 Componenti concettuali

- primary database;
- database standby;
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

### 14.4 Ruoli e modalita'

Ruoli:

- `PRIMARY`;
- `PHYSICAL STANDBY`.

Operazioni:

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

Processo chiave:

- `DMON`.

---

## 15. Diagnostica: ADR, Alert Log, Trace, AWR, ASH

### 15.1 ADR

L'ADR e' l'Automatic Diagnostic Repository.

Contiene:

- alert log;
- trace files;
- incidenti;
- homes diagnostics database, listener and ASM.

Tool principale:

- `adrci`.

### 15.2 Alert log

It is the operational diary of the database.

Da controllare per:

- ORA errors;
- archiver issues;
- crash recovery;
- Data Guard apply;
- parameter changes;
- startup e shutdown.

### 15.3 Trace files

Contengono dettaglio tecnico per processi o errori specifici.

### 15.4 AWR, ASH, ADDM

Sono strumenti di performance e diagnostica.

Uso concettuale:

- `AWR`: snapshot storici;
- `ASH`: campionamento sessioni attive;
- `ADDM`: analisi automatica.

Nota pratica:

- Full AWR, ASH and ADDM require appropriate licenses or packs in production.

---

## 16. Dizionario Dati e Dynamic Performance Views

Due famiglie fondamentali.

### 16.1 DBA_, ALL_, USER_

Metadati persistenti:

- oggetti;
- users;
- tablespace;
- quote;
- segmenti.

### 16.2 V$ e GV$

Vista runtime dinamica.

- `V$`: local instance;
- `GV$`: cluster-wide in RAC.

Viste da conoscere.

| Vista | Because it's important |
|---|---|
| `v$instance` | status of the instance |
| `v$database` | ruolo, open mode, DBID, log mode |
| `v$parameter` | parametri effettivi |
| `v$spparameter` | parametri nello SPFILE |
| `v$bgprocess` | background processes |
| `v$session` | sessioni attive |
| `v$process` | processi OS e Oracle |
| `v$datafile` | datafiles |
| `v$log` | redo log groups |
| `v$logfile` | redo log members |
| `v$archived_log` | archived redo history |
| `v$managed_standby` | standby and apply processes |
| `v$dataguard_stats` | transport e apply lag |
| `v$asm_diskgroup` | ASM status |
| `gv$instance` | all RAC instances |
| `gv$services` | services cluster-wide |

---

## 17. Mappa dei Parametri piu' Importanti

| Parametro | Significato architetturale |
|---|---|
| `DB_NAME` | nome logico del database |
| `DB_UNIQUE_NAME` | nome unico del sito, cruciale per Data Guard |
| `INSTANCE_NAME` | name of the single instance |
| `SERVICE_NAMES` | database services, today often managed via srvctl |
| `SGA_TARGET` | automatic EMS management |
| `PGA_AGGREGATE_TARGET` | target PGA |
| `DB_BLOCK_SIZE` | block size del database |
| `CONTROL_FILES` | control file attivi |
| `DB_CREATE_FILE_DEST` | OMF destination primaria |
| `DB_RECOVERY_FILE_DEST` | FRA |
| `DB_RECOVERY_FILE_DEST_SIZE` | dimensione FRA |
| `REMOTE_LOGIN_PASSWORDFILE` | use of the password file |
| `LOCAL_LISTENER` | local listener |
| `REMOTE_LISTENER` | remote listener or SCAN |
| `CLUSTER_DATABASE` | abilita comportamento RAC |
| `LOG_ARCHIVE_CONFIG` | perimetro Data Guard |
| `LOG_ARCHIVE_DEST_n` | destinazioni redo transport o local archive |
| `STANDBY_FILE_MANAGEMENT` | standby file self-management |
| `DG_BROKER_START` | Broker startup |

---

## 18. Errori Concettuali Comuni

1. pensare che `COMMIT` significhi datafile gia' scritto;
2. confondere `service` con `SID`;
3. confondere `istanza` con `database`;
4. believe that each PDB has its own separate instance;
5. pensare che `MRP0` must be on all RAC standby instances;
6. ignorare la differenza tra `SPFILE` locale e `SPFILE` condiviso in ASM;
7. believe that the listener contains the database;
8. confondere redo e undo;
9. credere che ASM sia solo una directory speciale;
10. usare solo `v$archived_log` to measure Data Guard status.

---

## 19. How to Connect Theory to Your Lab

Nel tuo laboratorio questi concetti diventano concreti cosi'.

### Phase 2

- `RACDB` = un database condiviso;
- `rac1` e `rac2` = due istanze;
- `+DATA`, `+RECO`, `+CRS` = disk group ASM;
- `SCAN`, VIP, services = accesso client corretto.

### Phase 3

- `RACDB_STBY` = primary physical standby;
- `MRP0`, `RFS`, SRL = apply e transport redo;
- SPFILE in ASM = standby RAC corrected attitude;
- OCR registration = complete clusterware management.

### Phase 4

- Broker = strato di orchestrazione Data Guard;
- `DMON` = processo chiave;
- `DGConnectIdentifier`, protection mode, switchover, failover = true HA and DR management.

### Extra DBA

- PDB propagation primary -> standby;
- services PDB `PRIMARY` vs `PHYSICAL_STANDBY`;
- EM, RMAN, TDE, troubleshooting listener and alert log.

---

## 20. Query Minime da Sapere a Memoria

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

## 21. Riferimenti Oracle Ufficiali

- Oracle Database 19c Concepts - Memory Architecture
- Oracle Database 19c Concepts - Process Architecture
- Oracle Database 19c Concepts - Logical Storage Structures
- Oracle Database 19c Concepts - Physical Storage Structures
- Oracle Database 19c Concepts - Application and Networking Architecture
- Oracle Database 19c Multitenant - Overview of the Multitenant Architecture
- Oracle RAC Administration and Deployment Guide - Overview of Oracle RAC Architecture
- Oracle Data Guard Concepts and Administration - Redo Transport and Apply Services
- Oracle ASM Administrator's Guide - ASM Overview

Link ufficiali:

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

## 22. Sintesi Finale

If you only need to remember 10 ideas, remember these:

1. instance and database are not the same thing;
2. SGA e' condivisa, PGA e' privata;
3. commit aspetta redo, non datafile;
4. redo e undo sono entrambi essenziali ma fanno cose diverse;
5. Oracle garantisce read consistency tramite SCN + undo;
6. listener forwards connections, does not execute SQL;
7. service batte SID per applicazioni, RAC e Data Guard;
8. a CDB has only one instance for its PDBs, not one for each PDB;
9. RAC = multiple instances on the same shared database;
10. Data Guard = redo transport + redo apply, non copia file \"magica\".
