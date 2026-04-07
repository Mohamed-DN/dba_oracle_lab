# Glossario Oracle — Tutti gli Acronimi del Lab

> Riferimento rapido per tutti i termini e acronimi Oracle usati in questo repository.

---

## Architettura Database

| Termine | Definizione |
|---------|------------|
| **CDB** | Container Database — il database "contenitore" che ospita i PDB |
| **PDB** | Pluggable Database — un database "innestabile" dentro un CDB |
| **SGA** | System Global Area — memoria condivisa del database (buffer cache, shared pool, ecc.) |
| **PGA** | Program Global Area — memoria privata di ogni sessione/processo |
| **DBID** | Database IDentifier — numero unico che identifica un database (usato da RMAN) |
| **SCN** | System Change Number — contatore delle modifiche del database (il "timestamp logico") |
| **REDO** | File di log transazionale — registra ogni modifica per il recovery |
| **UNDO** | Segmento di rollback — conserva i valori "prima" per rollback e read consistency |
| **FRA** | Fast Recovery Area — area su disco per backup, archivelog, flashback logs |
| **BCT** | Block Change Tracking — file che traccia i blocchi modificati per velocizzare backup incrementali |
| **SPFILE** | Server Parameter File — file binario con i parametri del database |
| **PFILE** | Parameter File — file testo con i parametri (init.ora, usato come fallback) |

## Processi

| Termine | Definizione |
|---------|------------|
| **LGWR** | Log Writer — scrive il redo buffer nei redo log files (COMMIT) |
| **DBWR/DBWn** | Database Writer — scrive i dirty blocks dalla buffer cache ai datafile |
| **ARCH/ARCn** | Archiver — copia i redo log pieni negli archivelog (ARCHIVELOG mode) |
| **CKPT** | Checkpoint — aggiorna gli header dei datafile con l'ultimo SCN |
| **SMON** | System Monitor — recovery automatico al startup, pulizia |
| **PMON** | Process Monitor — pulizia sessioni morte, rilascio lock orfani |
| **MMON** | Manageability Monitor — raccoglie statistiche AWR, lancia ADDM |
| **MRP0** | Managed Recovery Process — applica i redo sullo standby (Data Guard) |
| **RFS** | Remote File Server — riceve i redo dal primary (Data Guard) |
| **DMON** | Data Guard Monitor — il processo del Broker |
| **RVWR** | Recovery Writer — scrive i flashback logs |

## RAC (Real Application Clusters)

| Termine | Definizione |
|---------|------------|
| **RAC** | Real Application Clusters — più istanze Oracle su nodi diversi, un database condiviso |
| **ASM** | Automatic Storage Management — volume manager Oracle per dischi condivisi |
| **CRS** | Cluster Ready Services — il framework di clustering di Oracle |
| **OCR** | Oracle Cluster Registry — configurazione del cluster (quali risorse, dove) |
| **OLR** | Oracle Local Registry — copia locale dell'OCR su ogni nodo |
| **VIP** | Virtual IP — IP virtuale che migra tra nodi per HA |
| **SCAN** | Single Client Access Name — VIP + DNS round-robin per connessioni client |
| **Cache Fusion** | Meccanismo RAC per condividere blocchi tra istanze via interconnect |
| **GES** | Global Enqueue Service — gestisce i lock distribuiti tra nodi RAC |
| **GCS** | Global Cache Service — gestisce il trasferimento blocchi tra nodi |
| **HAIP** | High Availability IP — IP ridondante per l'interconnect RAC |

## Data Guard

| Termine | Definizione |
|---------|------------|
| **DG** | Data Guard — tecnologia Oracle per replica sincrona/asincrona del database |
| **DGMGRL** | Data Guard Manager (CLI) — il client a riga di comando per gestire il Broker |
| **Broker** | Data Guard Broker — framework di gestione automatica di Data Guard |
| **FAL** | Fetch Archive Log — meccanismo per richiedere archivelog mancanti |
| **FSFO** | Fast-Start Failover — failover automatico con Observer |
| **Observer** | Processo che monitora Primary/Standby e avvia FSFO |
| **MaxPerformance** | Protection mode: nessun impatto sul Primary (ASYNC) |
| **MaxAvailability** | Protection mode: sincrono ma degrada a async se standby non raggiungibile |
| **MaxProtection** | Protection mode: sincrono assoluto, Primary si ferma se standby non risponde |
| **ADG** | Active Data Guard — standby aperto in READ ONLY con apply attivo |

## RMAN

| Termine | Definizione |
|---------|------------|
| **RMAN** | Recovery Manager — tool Oracle per backup e recovery |
| **Backupset** | Formato nativo RMAN: contiene solo blocchi utilizzati (compatto) |
| **Image Copy** | Copia 1:1 dei datafile (come `cp`, ma gestita da RMAN) |
| **Level 0** | Backup incrementale base: copia tutti i blocchi |
| **Level 1** | Backup incrementale: copia solo i blocchi modificati dal Level 0 |
| **PITR** | Point-In-Time Recovery — ripristino a un momento specifico |
| **TSPITR** | Tablespace Point-In-Time Recovery |
| **DBPITR** | Database Point-In-Time Recovery |

## GoldenGate

| Termine | Definizione |
|---------|------------|
| **GG/OGG** | Oracle GoldenGate — replica logica in tempo reale |
| **Extract** | Processo GG che cattura le modifiche dai redo log |
| **Pump** | Processo GG secondario che trasporta i trail via rete |
| **Replicat** | Processo GG che applica le modifiche sul database target |
| **Trail** | File binario GG contenente le transazioni catturate |
| **GGSCI** | GoldenGate Software Command Interface — CLI di GoldenGate |
| **MGR** | Manager — processo supervisore di GoldenGate |
| **DEFGEN** | Definition Generator — genera file di definizione tabelle per target eterogenei |

## Performance

| Termine | Definizione |
|---------|------------|
| **AWR** | Automatic Workload Repository — statistiche performance persistenti |
| **ASH** | Active Session History — campionamento sessioni attive in tempo reale |
| **ADDM** | Automatic Database Diagnostic Monitor — analisi automatica AWR |
| **SQL Profile** | Set di hint che l'optimizer usa per una query specifica |
| **SQL Plan Baseline** | Piano di esecuzione "congelato" per una query |
| **Wait Event** | Cosa sta aspettando una sessione (I/O, lock, CPU, ecc.) |
| **DB Time** | Tempo totale speso dalle sessioni nel database |

## Alta Disponibilità

| Termine | Definizione |
|---------|------------|
| **HA** | High Availability — alta disponibilità |
| **MAA** | Maximum Availability Architecture — architettura Oracle per HA massima |
| **TAF** | Transparent Application Failover — reconnect automatico del client |
| **FCF** | Fast Connection Failover — failover rapido basato su FAN events |
| **FAN** | Fast Application Notification — eventi push dal cluster ai client |
| **CLB** | Connection Load Balancing — bilanciamento connessioni tra nodi |
| **RLB** | Runtime Load Balancing — bilanciamento dinamico basato sul carico |
| **RPO** | Recovery Point Objective — massimo dato perdibile ("quanti dati perdo?") |
| **RTO** | Recovery Time Objective — tempo massimo di ripristino ("quanto sto fermo?") |

## Sicurezza

| Termine | Definizione |
|---------|------------|
| **TDE** | Transparent Data Encryption — encryption dei datafile a riposo |
| **NNE** | Native Network Encryption — encryption delle connessioni di rete |
| **Wallet** | Keystore Oracle per chiavi di encryption e certificati |

## Strumenti

| Termine | Definizione |
|---------|------------|
| **OEM/EM** | Oracle Enterprise Manager — console di monitoring centralizzata |
| **OMS** | Oracle Management Service — server centrale di Enterprise Manager |
| **OPatch** | Tool Oracle per applicare patch ai binari |
| **OUI** | Oracle Universal Installer |
| **sqlplus** | Client SQL a riga di comando Oracle |
| **adrci** | Automatic Diagnostic Repository Command Interpreter |
| **orachk** | Tool Oracle per health check automatizzato |
| **expdp/impdp** | Data Pump Export/Import |
