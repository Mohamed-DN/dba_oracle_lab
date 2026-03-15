# Guida Domande DBA Oracle

> Raccolta strutturata di domande, risposte e scenari tecnici su Oracle DBA. Le domande sono state curate da piu fonti pubbliche, ma le risposte sono state riallineate alla terminologia e ai concetti Oracle ufficiali, con focus pratico su 19c, RAC, Data Guard, ASM, RMAN, multitenant e troubleshooting.

---

## 1. Come Usare Questo Documento

Per ogni domanda, costruisci la risposta in 3 strati:

1. definizione corretta in 1-2 frasi;
2. perche conta in produzione;
3. un esempio operativo, una vista `V$` o un comando reale.

Formula pratica:

- `definizione`: che cos'e;
- `impatto`: perche il business o il DBA se ne occupa;
- `operativita`: come lo verifichi o lo gestisci.

Esempio:

- domanda: `Che differenza c'e tra redo e undo?`
- risposta debole: `Redo serve per recovery e undo per rollback.`
- risposta forte: `Redo registra le modifiche necessarie a riprodurre i cambiamenti durante recovery o replica Data Guard. Undo conserva la vecchia immagine logica dei dati per rollback e read consistency. Li verifico con il flusso commit, v$log, tablespace UNDO e casi ORA-01555.`

Errore classico da evitare:

- parlare solo di definizioni teoriche senza citare un caso pratico;
- nominare strumenti senza sapere quando usarli;
- confondere `instance`, `database`, `service`, `SID`, `redo`, `undo`, `restore`, `recover`, `RAC`, `Data Guard`.

---

## 2. Architettura e Concetti Base

### 2.1 Che differenza c'e tra instance e database?

Risposta chiara:

- `instance` = memoria `SGA` + processi background e server;
- `database` = file persistenti: datafile, control file, redo log, archived log, parameter file.

Perche conta:

- quando fai `shutdown`, fermi l'istanza;
- quando fai `startup`, l'istanza torna a gestire il database fisico.

Follow-up forte:

- `NOMOUNT` avvia solo l'istanza;
- `MOUNT` apre il control file;
- `OPEN` apre i datafile.

### 2.2 Qual e la differenza tra SGA e PGA?

Risposta chiara:

- `SGA` e memoria condivisa tra i processi dell'istanza;
- `PGA` e memoria privata del singolo processo.

Dettagli utili:

- in `SGA` trovi `Buffer Cache`, `Shared Pool`, `Redo Log Buffer`;
- in `PGA` trovi sort area, hash area, stack, stato privato del processo.

Domanda successiva tipica:

- `Se manca memoria dove guardi?`
- risposta: `AWR`, `v$sga_dynamic_components`, `v$pgastat`, `v$memory_target_advice`, wait events e paging OS.

### 2.3 A cosa serve il Buffer Cache?

Risposta chiara:

- mantiene in memoria i blocchi letti o modificati;
- riduce I/O fisico;
- contiene anche blocchi dirty non ancora scritti su datafile.

Punto importante da dire:

- il `commit` non aspetta la scrittura del blocco sul datafile;
- aspetta il redo su disco.

### 2.4 Cos'e la Shared Pool?

Risposta chiara:

- e l'area della `SGA` che contiene SQL e PL/SQL gia parsati e metadata del dizionario;
- comprende soprattutto `Library Cache` e `Data Dictionary Cache`.

Segnali di problema:

- hard parse eccessivo;
- `ORA-04031`;
- invalidazioni frequenti.

### 2.5 Che differenza c'e tra hard parse e soft parse?

Risposta chiara:

- `hard parse`: Oracle deve fare parsing completo, ottimizzazione e creazione di un piano nuovo;
- `soft parse`: Oracle riusa strutture gia esistenti in cache.

Perche conta:

- troppi hard parse aumentano CPU e latch/mutex contention;
- le bind variables riducono hard parse inutili in molti workload OLTP.

### 2.6 Cosa succede durante un commit?

Risposta chiara:

- Oracle genera redo;
- `LGWR` scrive il redo nei redo log online;
- solo dopo conferma il commit alla sessione.

Punto da dire bene:

- `DBWn` puo scrivere i datafile dopo;
- e il principio del write-ahead logging.

### 2.7 Redo e undo: differenza reale?

Risposta chiara:

- `redo` descrive le modifiche per recovery e replica;
- `undo` conserva lo stato precedente dei dati per rollback e read consistency.

Domanda-trabocchetto tipica:

- `Si puo fare recovery con il solo undo?`
- no. Il recovery Oracle si basa sul redo.

### 2.8 Cos'e uno SCN?

Risposta chiara:

- `SCN` e il contatore logico del tempo interno Oracle;
- serve a coordinare consistenza, recovery, flashback e sincronizzazione dei blocchi.

Perche e importante:

- Oracle usa SCN + undo per garantire read consistency;
- SCN appare in backup, RMAN, Data Guard, flashback, recovery e clone consistenti.

### 2.9 Cosa sono control file e perche sono critici?

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
- in RAC lo `SPFILE` deve stare tipicamente in ASM o shared storage.

### 2.11 Cosa fa il password file?

Risposta chiara:

- abilita autenticazione remota per utenti amministrativi come `SYS`, `SYSDG`, `SYSBACKUP`, `SYSKM`;
- e controllato da `REMOTE_LOGIN_PASSWORDFILE`.

Caso pratico:

- Data Guard usa password file coerenti tra primary e standby per connessioni amministrative remote.

### 2.12 Perche il listener non e il database?

Risposta chiara:

- il listener accetta connessioni di rete e le inoltra al servizio corretto;
- non esegue SQL e non contiene dati.

Errore tipico:

- pensare che riavviare il listener riavvii il database. Non e cosi.

### 2.13 Service name e SID: quale usi per le applicazioni?

Risposta chiara:

- per le applicazioni si usa il `service`;
- il `SID` identifica una specifica istanza.

Perche e una best practice:

- i servizi supportano load balancing, failover, role-based routing, PDB e RAC;
- il `SID` e troppo rigido per ambienti HA.

### 2.14 Cosa sono data block, extent, segment e tablespace?

Risposta chiara:

- `data block`: unita minima di I/O Oracle;
- `extent`: gruppo di blocchi allocati insieme;
- `segment`: insieme di extents per un oggetto come tabella o indice;
- `tablespace`: contenitore logico di segmenti.

### 2.15 Che differenza c'e tra tempfiles e datafiles?

Risposta chiara:

- i `datafile` contengono dati permanenti;
- i `tempfile` supportano sort, hash e operazioni temporanee, non vengono recoverati allo stesso modo dei datafile.

---

## 3. Backup, Recovery e RMAN

### 3.1 Perche RMAN e preferibile a backup manuali OS?

Risposta chiara:

- conosce la struttura Oracle;
- gestisce backup consistenti, block-level checks, restore, recover, catalogazione, retention e integrazione con control file/catalog.

Cosa dire in piu:

- sa leggere corruption a livello blocco;
- integra `validate`, `crosscheck`, `duplicate`, `block media recovery`.
### 3.2 Che differenza c'e tra restore e recover?

Risposta chiara:

- `restore` = rimettere i file da backup;
- `recover` = applicare redo/archivelog per portarli a uno stato consistente.

Questa e una domanda base ma eliminatoria.

### 3.3 Che differenza c'e tra backup set e image copy?

Risposta chiara:

- `backup set` e il formato RMAN compresso/logico piu comune;
- `image copy` e una copia fisica molto simile al file originale.

Quando citarli:

- `backup set` per backup tradizionali;
- `image copy` utile in strategie incremental merge o recovery rapida su copy.

### 3.4 Full backup e level 0 sono la stessa cosa?

Risposta chiara:

- no, non sempre dal punto di vista concettuale RMAN;
- `incremental level 0` e la base di una catena incrementale;
- `full` non viene usato come base per incrementali `level 1` nello stesso modo.

### 3.5 Cosa sono incremental level 1 differential e cumulative?

Risposta chiara:

- `differential`: salva i blocchi cambiati dall'ultimo backup incrementale di livello inferiore o uguale;
- `cumulative`: salva i blocchi cambiati dall'ultimo level 0.

Impatto pratico:

- differential = backup giornalieri piu piccoli;
- cumulative = recovery piu semplice ma backup piu grandi.

### 3.6 A cosa servono `crosscheck`, `delete expired` e `delete obsolete`?

Risposta chiara:

- `crosscheck` verifica se i backup esistono ancora sul media;
- `expired` = backup attesi ma non piu trovati;
- `obsolete` = backup non piu necessari secondo retention policy.

Errore comune:

- confondere `expired` con `obsolete`.

### 3.7 Cosa fa `validate`?

Risposta chiara:

- controlla integrita e leggibilita dei file di backup o dei datafile senza eseguire un restore completo in produzione;
- serve a testare se i backup sono davvero utilizzabili.

### 3.8 A cosa serve il control file autobackup?

Risposta chiara:

- protegge automaticamente control file e SPFILE dopo backup strutturalmente rilevanti;
- e spesso il salvagente quando perdi control file e catalogo locale.

### 3.9 Catalog o nocatalog: cosa scegli?

Risposta chiara:

- `nocatalog` va bene per ambienti semplici e piccoli;
- `recovery catalog` da piu storico, reporting e gestione centralizzata, utile in ambienti enterprise.

### 3.10 Cos'e il block change tracking?

Risposta chiara:

- e un file che aiuta RMAN a sapere quali blocchi sono cambiati dopo il level 0;
- accelera gli incremental backup.

### 3.11 Come recuperi un datafile perso?

Risposta chiara:

- metti il database/tablespace nello stato corretto se necessario;
- `RESTORE DATAFILE ...`;
- `RECOVER DATAFILE ...`;
- poi rimetti online il file o apri il database a seconda del caso.

### 3.12 Come gestisci un crash con `shutdown abort`?

Risposta chiara:

- al successivo startup Oracle esegue `instance recovery`;
- usa redo per rifare le modifiche committate non scritte nei datafile e undo per ripulire le transazioni incomplete.

### 3.13 `ARCHIVELOG` vs `NOARCHIVELOG`: differenza pratica?

Risposta chiara:

- in `ARCHIVELOG` puoi fare backup online e media recovery point-in-time piu completa;
- in `NOARCHIVELOG` hai recovery piu limitata e normalmente backup offline per consistenza forte.

### 3.14 Come recuperi SPFILE se lo perdi?

Risposta chiara:

- puoi usare un `PFILE` di emergenza;
- puoi recuperare da autobackup RMAN o crearne uno da memoria/SPFILE backup se disponibile.

### 3.15 Quando useresti `DUPLICATE`?

Risposta chiara:

- per creare standby, ambienti clone/test, refresh, migration assistita o duplicate from active database.

---

## 4. Data Guard

### 4.1 Che differenza c'e tra physical, logical e snapshot standby?

Risposta chiara:

- `physical standby`: applica redo fisicamente ai datafile;
- `logical standby`: applica trasformazioni SQL logiche;
- `snapshot standby`: standby temporaneamente aperto in read write per test, poi riconvertibile.

Nel tuo lab la risposta forte e: `uso physical standby per robustezza e allineamento semplice con RMAN e Broker.`

### 4.2 Quali processi principali devi conoscere in Data Guard?

Risposta chiara:

- lato transport: `LGWR`, `ARCn`, `LNS`, `RFS`;
- lato apply: `MRP0` per physical standby.

Follow-up forte:

- `RFS` riceve redo sullo standby;
- `MRP0` applica redo;
- con real-time apply lo standby usa gli `SRL` senza aspettare il completamento dell'archivelog.

### 4.3 Perche servono gli standby redo logs?

Risposta chiara:

- permettono real-time apply e un transport piu corretto verso lo standby;
- sono necessari per molte configurazioni sane di Data Guard.

Regola pratica da ricordare:

- per ogni thread standby redo logs >= online redo logs del primary + 1.

### 4.4 `SYNC` vs `ASYNC`: differenza?

Risposta chiara:

- `SYNC` richiede acknowledgment per protezione piu alta e maggiore impatto potenziale sulla latenza del primary;
- `ASYNC` privilegia performance e throughput, con possibile piccolo data loss in caso di disastro improvviso.

### 4.5 Qual e la differenza tra switchover e failover?

Risposta chiara:

- `switchover` = cambio ruolo pianificato e senza perdita dati prevista;
- `failover` = promozione d'emergenza dello standby dopo perdita del primary o impossibilita di switchover.

### 4.6 Cos'e il Broker e perche usarlo?

Risposta chiara:

- `Data Guard Broker` centralizza gestione e validazione di Data Guard;
- semplifica switchover, failover, fast-start failover, health checks e proprieta.

### 4.7 Cosa sono `transport lag` e `apply lag`?

Risposta chiara:

- `transport lag` = ritardo nel trasferimento redo dal primary allo standby;
- `apply lag` = ritardo tra redo ricevuto e redo applicato.

Vista da citare:

- `v$dataguard_stats`.

### 4.8 `db_name` e `db_unique_name`: differenza?

Risposta chiara:

- `db_name` resta uguale tra primary e standby nella stessa configurazione DG;
- `db_unique_name` identifica in modo univoco ogni database della configurazione.

### 4.9 A cosa servono `FAL_SERVER` e `FAL_CLIENT`?

Risposta chiara:

- servono alla gap resolution per recuperare archive log mancanti;
- diventano particolarmente importanti in scenari di ruolo invertibile e riconnessione.

### 4.10 Cosa vuol dire `MRP0 APPLYING_LOG`?

Risposta chiara:

- che il managed recovery process dello standby sta applicando redo;
- in uno standby RAC e normale che l'apply viva su una sola istanza alla volta.

### 4.11 MaxPerformance, MaxAvailability, MaxProtection: differenze?

Risposta chiara:

- `MaxPerformance`: tipicamente `ASYNC`, minima latenza, data loss minimo possibile ma non nullo in disastro;
- `MaxAvailability`: tenta zero data loss con `SYNC`, mantenendo comunque il primary disponibile in molti fault gestibili;
- `MaxProtection`: massima protezione, ma il primary puo fermarsi se non riesce a proteggere i redo come richiesto.

### 4.12 Active Data Guard che vantaggio da?

Risposta chiara:

- permette uso dello standby in `READ ONLY WITH APPLY`;
- utile per reporting, query read-only, alcuni workload offload e casi GoldenGate/monitoring.

### 4.13 Come verifichi in modo serio che Data Guard sia sana?

Risposta chiara:

- sul primary: `v$archive_dest` e assenza errori sul destination remoto;
- sullo standby: `v$managed_standby`, `v$dataguard_stats`, `v$database`, alert log, Broker `show configuration` se usato.

### 4.14 Quali errori comuni guardi per primi in Data Guard?

Risposta chiara:

- `ORA-12514`, `ORA-12154`, `ORA-01017`, gap di archived log, SRL mancanti, password file non coerente, listener/service sbagliato, `DB_UNIQUE_NAME` errato, standby in stato non corretto.

---

## 5. RAC e ASM

### 5.1 Qual e la differenza tra RAC e Data Guard?

Risposta chiara:

- `RAC` fornisce alta disponibilita e scalabilita attiva/attiva sullo stesso database condiviso;
- `Data Guard` fornisce disaster recovery e protezione dati mantenendo database distinti.

Risposta forte:

- RAC non sostituisce DR;
- Data Guard non sostituisce la scalabilita locale di RAC.
### 5.2 Cos'e Cache Fusion?

Risposta chiara:

- e il meccanismo RAC che trasferisce blocchi tra buffer cache di istanze diverse via interconnect, invece di forzare sempre la scrittura preventiva su disco.

Perche e centrale:

- e il cuore dell'accesso concorrente RAC al database condiviso.

### 5.3 Che cos'e lo SCAN?

Risposta chiara:

- `Single Client Access Name` e il nome logico usato dai client per connettersi a un cluster RAC;
- semplifica failover e load balancing senza far conoscere tutti i nodi ai client.

### 5.4 A cosa servono OCR e Voting Disk?

Risposta chiara:

- `OCR` conserva configurazione cluster e risorse;
- `Voting Disk` aiuta il cluster a determinare membership e quorum.

### 5.5 Perche in RAC si usano i services e non connessioni fissate al nodo?

Risposta chiara:

- per load balancing, failover, role separation, patching rolling e associazione a PDB o workload specifici.

### 5.6 Cos'e ASM?

Risposta chiara:

- `ASM` e il layer storage Oracle specializzato per file database;
- semplifica naming, striping, mirroring e gestione file per database, RMAN, RAC e Data Guard.

### 5.7 Che differenza c'e tra disk group e failure group?

Risposta chiara:

- `disk group` = insieme logico di dischi ASM;
- `failure group` = gruppo che ASM usa per ridondanza, per evitare che copie mirror finiscano nello stesso dominio di guasto.

### 5.8 Perche mettere SPFILE e password file in ASM in RAC?

Risposta chiara:

- per avere file condivisi e consistenti tra i nodi;
- evita divergenze tra file locali e semplifica avvio clusterware.

### 5.9 Cos'e un rebalance ASM?

Risposta chiara:

- e il riequilibrio dei dati ASM quando aggiungi o rimuovi dischi;
- ha impatto I/O e va monitorato.

Vista da citare:

- `v$asm_operation`.

### 5.10 Come distingui un problema cluster da un problema database?

Risposta chiara:

- lato cluster guardi `crsctl`, `srvctl`, OCR, listener, VIP, SCAN, resource status;
- lato database guardi alert log, `v$instance`, `v$database`, wait events, storage e parametri.

### 5.11 Che differenza c'e tra `srvctl` e `sqlplus startup` in RAC?

Risposta chiara:

- `srvctl` gestisce il database come risorsa clusterware;
- `sqlplus startup` agisce solo sull'istanza locale e puo bypassare la logica cluster.

Best practice:

- in RAC e Data Guard clusterizzati, usa `srvctl` per start/stop normali.

### 5.12 Come verifichi lo stato del cluster?

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
- `PDB` e il pluggable database che appare quasi indipendente ma condivide istanza e infrastruttura del CDB.

### 6.2 A cosa serve `PDB$SEED`?

Risposta chiara:

- e il template read-only usato per creare nuovi PDB in modo rapido e consistente.

### 6.3 Common user e local user: differenza?

Risposta chiara:

- `common user` esiste a livello CDB e segue regole di naming/presenza comuni;
- `local user` esiste solo nel PDB specifico.

### 6.4 Un PDB ha una sua istanza separata?

Risposta chiara:

- no;
- i PDB condividono istanza, memoria e processi del CDB.

### 6.5 Come colleghi un'applicazione a un PDB in modo corretto?

Risposta chiara:

- tramite un `service` associato al PDB;
- non tramite login al root o SID nudo.

### 6.6 Cos'e TDE?

Risposta chiara:

- `Transparent Data Encryption` protegge i dati a riposo cifrando colonne o tablespace;
- le chiavi sono gestite tramite keystore/wallet.

### 6.7 Chi dovrebbe gestire il keystore TDE?

Risposta chiara:

- idealmente un account con privilegi dedicati come `SYSKM` o ruolo coerente con governance interna;
- non sempre il solo `SYSDBA`.

### 6.8 Cosa succede se perdi il wallet/keystore TDE?

Risposta chiara:

- i dati cifrati possono diventare inutilizzabili;
- il backup del keystore e critico quanto il backup del database.

### 6.9 In RAC dove metti il keystore TDE?

Risposta chiara:

- su storage condiviso supportato, cosi tutti i nodi vedono lo stesso keystore;
- Oracle sconsiglia wallet locali non condivisi per casi RAC comuni.

### 6.10 Cosa controlli quando un keystore non si apre?

Risposta chiara:

- `WALLET_ROOT`, `TDE_CONFIGURATION`, permessi OS, tipo wallet, stato keystore in `v$encryption_wallet`, sincronizzazione tra nodi se cluster.

### 6.11 Perche il password policy management non basta come sicurezza DBA?

Risposta chiara:

- la sicurezza DBA include auditing, least privilege, secret management, network encryption, TDE, patching, segregazione dei ruoli e hardening OS.

---

## 7. Performance, Diagnostica e Tuning

### 7.1 A cosa servono AWR, ASH e ADDM?

Risposta chiara:

- `AWR` raccoglie snapshot e metriche storiche di performance;
- `ASH` traccia campioni di session activity ad alta frequenza;
- `ADDM` analizza i dati e propone findings.

### 7.2 Quando usi AWR e quando ASH?

Risposta chiara:

- `AWR` per analisi storiche su un intervallo;
- `ASH` per vedere chi stava aspettando cosa in un momento o in una finestra stretta.

### 7.3 Che cosa guardi per prima in un AWR report?

Risposta chiara:

- DB time;
- top foreground waits;
- load profile;
- SQL ordered by elapsed time / CPU / gets / reads;
- instance efficiency solo con prudenza, non come verita assoluta.

### 7.4 Come analizzi un problema di CPU alta?

Risposta chiara:

- distingui CPU Oracle vs OS;
- guardi AWR/ASH, top SQL, hard parse, parallelismo, execution plan regressi, processi OS e scheduling.
### 7.5 Come trovi una blocking session?

Risposta chiara:

- `v$session`, `v$lock`, `gv$session` in RAC, eventualmente ASH/AWR se il blocco non e piu attivo.

### 7.6 `ORA-01555 snapshot too old`: da cosa nasce davvero?

Risposta chiara:

- tipicamente da undo insufficiente o sovrascritto troppo presto rispetto alla durata della query coerente;
- non e solo un problema di query lunga, ma di retention, workload e undo pressure.

### 7.7 `ORA-04031` cosa ti dice?

Risposta chiara:

- che Oracle non riesce ad allocare memoria contigua da una struttura della shared memory, spesso `Shared Pool` o pool simili;
- va indagato su dimensionamento, frammentazione, hard parse e componenti attivi.

### 7.8 Se una query e lenta, da dove parti?

Risposta chiara:

- confermo se il problema e nuovo o storico;
- guardo piano di esecuzione reale, statistics freshness, waits, cardinality mismatch, bind peeking, I/O, locking, temp e parallelismo.

### 7.9 Perche le statistiche sono importanti?

Risposta chiara:

- il cost-based optimizer decide il piano basandosi sulle statistiche;
- statistiche stale o sbagliate possono generare piani pessimi.

### 7.10 Rebuild index: soluzione standard?

Risposta chiara:

- no;
- si fa solo se c'e motivo reale, non come riflesso automatico.

Risposta forte:

- prima verifico fragmentation reale, blevel, clustering factor, access pattern e se il problema sta davvero nell'indice.

### 7.11 Come controlli lo stato di tablespace e FRA?

Risposta chiara:

- tablespace: `DBA_DATA_FILES`, `DBA_FREE_SPACE`, `DBA_TEMP_FREE_SPACE`, metriche OEM;
- FRA: `v$recovery_file_dest`, `v$flash_recovery_area_usage`.

### 7.12 Alert log o trace file: quando usi uno e quando l'altro?

Risposta chiara:

- alert log per eventi principali e cronologia di alto livello;
- trace file per dettaglio tecnico di errori, incidenti, sessioni e processi specifici.

### 7.13 Cos'e ADRCI e perche e utile?

Risposta chiara:

- e la CLI dell'Automatic Diagnostic Repository;
- serve per navigare alert, incident, trace e purge diagnostico anche in RAC/Data Guard.

---

## 8. Troubleshooting Operativo e Scenari da Colloquio

### 8.1 Il database non parte e vedi `ORA-01034`. Da dove parti?

Risposta chiara:

- verifico se l'istanza e davvero giu;
- controllo `ORACLE_SID`, `ORACLE_HOME`, alert log, parameter file, spfile/pfile, stato listener e clusterware se RAC.

### 8.2 Un listener e su ma restituisce `ORA-12514`. Cosa significa?

Risposta chiara:

- il listener non conosce ancora il service richiesto;
- tipicamente problema di registrazione dinamica, service sbagliato, alias TNS errato o database non nello stato atteso.

### 8.3 Lo standby e montato ma non applica redo. Cosa controlli?

Risposta chiara:

- `MRP0`, `RFS`, `v$archive_dest`, `v$dataguard_stats`, listener/service, password file, SRL, gap archive, errori TNS, ruolo del database e Broker se attivo.

### 8.4 `DEST_ID=2 ERROR` sul primary in Data Guard: cosa pensi subito?

Risposta chiara:

- trasporto redo fallito;
- controllo `error` in `v$archive_dest`, alias TNS, listener standby, service standby, password file, stato standby e rete.

### 8.5 La FRA e piena. Quali rischi hai?

Risposta chiara:

- archiving puo fermarsi;
- backup/recovery/flashback possono degradare o bloccarsi;
- in casi gravi impatta anche il primary.

Azioni tipiche:

- capire cosa occupa spazio;
- liberare in modo controllato;
- riallineare retention e dimensionamento.

### 8.6 Un tablespace e quasi pieno. Cosa fai?

Risposta chiara:

- verifico autoextend, spazio reale, crescita, segmenti maggiori, business impact;
- poi aggiungo spazio, estendo file o faccio pulizia solo se supportata.

### 8.7 Un nodo RAC cade. Come rispondi in modo corretto?

Risposta chiara:

- verifico clusterware, vip/service relocation, alert/trace, interconnect, ASM e stato delle risorse;
- poi capisco se e problema node, GI, rete, storage o database.

### 8.8 Hai backup RMAN, ma nessuno ha mai testato restore. E sufficiente?

Risposta chiara:

- no;
- backup non verificato non e un backup affidabile.

Risposta forte:

- servono `validate`, restore test, runbook e prove periodiche di recovery.

### 8.9 Come distingui `restore controlfile` da `recover database using backup controlfile`?

Risposta chiara:

- il primo rimette il control file;
- il secondo entra nel flusso di recovery quando il control file usato non e perfettamente allineato alla storia corrente e richiede approccio di recovery compatibile.

### 8.10 Se un'applicazione improvvisamente non si connette piu, da dove parti?

Risposta chiara:

- listener, service, DNS/SCAN se RAC, firewall, `sqlnet.ora`, stato DB, lock di account, errori recenti in alert log e lato client.

### 8.11 Come rispondi se ti chiedono una giornata tipica da DBA?

Risposta chiara:

- controllo availability, backup, alert, spazio, lag DG, job critici, listener/services, performance regressions, incident aperti e cambi pianificati.

### 8.12 Cosa fai prima di un patching?

Risposta chiara:

- backup verificati, spazio sufficiente, prerequisiti patch, inventory pulito, conflitti opatch/opatchauto, finestra di change, rollback plan, stato cluster e runbook validato.

### 8.13 Cosa fai dopo un patching?

Risposta chiara:

- verifico versione, inventory, alert log, servizi, listener, broker, backup, job, performance iniziale e health check applicativo.

### 8.14 Come spieghi una differenza tra `READ ONLY`, `MOUNTED` e `READ ONLY WITH APPLY`?

Risposta chiara:

- `MOUNTED`: standby non aperto agli utenti normali;
- `READ ONLY`: aperto in sola lettura ma senza apply nel caso semplice;
- `READ ONLY WITH APPLY`: Active Data Guard, query e apply insieme.

### 8.15 Se il tema entra su produzione critica, cosa cambi nel tuo approccio?

Risposta chiara:

- piu standardizzazione, change control, RPO/RTO, hardening, monitoraggio, test recovery, runbook, segregazione ruoli, zero hardcoded secrets, prove DR e validazione periodica.

---

## 9. Domande Senior o da Team Lead

### 9.1 Come definisci RPO e RTO a un manager non tecnico?

Risposta chiara:

- `RPO` = quanti dati puoi permetterti di perdere;
- `RTO` = in quanto tempo devi tornare operativo.

### 9.2 Come scegli tra single instance, RAC e Data Guard?

Risposta chiara:

- single instance per semplicita;
- RAC per HA locale e scalabilita;
- Data Guard per DR;
- spesso in ambienti seri RAC + Data Guard insieme.

### 9.3 Come difendi una strategia backup enterprise?

Risposta chiara:

- backup full/incremental coerenti con RPO/RTO;
- retention chiara;
- FRA dimensionata;
- control file autobackup;
- restore test periodici;
- offsite o standby-based backup dove utile.
### 9.4 Come imposti monitoraggio serio?

Risposta chiara:

- availability, redo transport/apply lag, FRA, spazio tablespace, backup success, wait anomalies, listener/service health, cluster resources, job failures, CPU/memory/I/O e incident routing.

### 9.5 Cosa non faresti mai come DBA in produzione?

Risposta chiara:

- comandi distruttivi senza recovery path;
- modifiche manuali non documentate su cluster/ASM;
- patching senza rollback plan;
- cambiare piu variabili insieme senza isolare il rischio;
- lasciare password hardcoded in script o repo.

### 9.6 Come spieghi una regressione dopo rilascio applicativo?

Risposta chiara:

- confronto AWR/ASH prima-dopo, nuovi SQL, piano cambiato, statistics mutate, bind pattern diverso, locking, volume dati, parameter drift, code path nuovo.

### 9.7 Quando usi switchover invece di failover?

Risposta chiara:

- quando il primary e ancora sano e la role transition e pianificabile;
- per manutenzioni, test DR o migrazione con rischio ridotto.

### 9.8 Come dimostri maturita tecnica?

Risposta chiara:

- parli per runbook, verifiche, trade-off e failure mode;
- non vendi magia, vendi controllo operativo.

---

## 10. Rapid Fire: Domande Brevi ad Alta Frequenza

Usale per ripasso veloce.

1. `Che cos'e LGWR?` Scrive redo online.
2. `Che cos'e DBWn?` Scrive dirty blocks ai datafile.
3. `Che cos'e CKPT?` Coordina checkpoint e aggiorna header/control file.
4. `Che cos'e SMON?` Fa recovery e housekeeping di sistema.
5. `Che cos'e PMON?` Ripulisce risorse di processi/sessioni fallite; in release moderne alcune responsabilita sono cambiate ma il concetto resta.
6. `Che cos'e ARCn?` Archivia redo online in archived log.
7. `Che cos'e LREG?` Registra servizi al listener.
8. `Che cos'e MRP0?` Applica redo su physical standby.
9. `Che cos'e RFS?` Riceve redo sullo standby.
10. `Che cos'e FRA?` Area recovery per archived log, backup, flashback e file collegati.
11. `Che cos'e OMF?` Oracle Managed Files, naming/placement gestiti da Oracle.
12. `Che cos'e ASM?` Storage layer Oracle per file database.
13. `Che cos'e SCAN?` Nome unico per accesso client a un cluster RAC.
14. `Che cos'e OCR?` Repository della configurazione cluster.
15. `Che cos'e Voting Disk?` Quorum e membership cluster.
16. `Che cos'e AWR?` Repository storico performance.
17. `Che cos'e ASH?` Campionamento activity delle sessioni.
18. `Che cos'e ADDM?` Analisi automatica dei dati AWR.
19. `Che cos'e TDE?` Cifratura dati a riposo.
20. `Che cos'e un PDB?` Database pluggable dentro un CDB.

---

## 11. Domande Scenario da Simulare a Voce

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

Metodo di risposta consigliato:

- stato iniziale;
- impatto business;
- verifiche immediate;
- ipotesi ordinate per probabilita;
- fix;
- verifica finale;
- prevenzione futura.

---

## 12. Checklist Finale Prima del Colloquio

Devi saper spiegare senza leggere:

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

Se vuoi passare da junior a intermedio, devi anche saper fare a voce:

- un runbook rapido per datafile loss;
- un runbook rapido per DG lag;
- un runbook rapido per ORA-12514;
- un runbook rapido per tablespace/FRA pieni;
- un confronto serio tra `MaxPerformance` e `MaxAvailability`.

---

## 13. Fonti Usate

### 13.1 Fonti per la copertura delle domande

Domande curate e ripulite a partire da piu sorgenti pubbliche di raccolta tecnica:

- InterviewBit Oracle DBA question set: https://www.interviewbit.com/oracle-dba-interview-questions/
- GeeksforGeeks Oracle topic roundup: https://www.geeksforgeeks.org/oracle-topics-for-interview-preparation/
- GeeksforGeeks Oracle question roundup: https://www.geeksforgeeks.org/to-50-oracle-interview-questions-and-answers-for-2024/
- GeekInterview Oracle DBA question bank: https://www.geekinterview.com/Interview-Questions/Oracle/Database-Administration/
- Oracle DBA question guide article: https://www.oracledbaonlinetraining.com/post/oracle-dba-interview-guide-questions-answers

### 13.2 Fonti Oracle ufficiali usate per riallineare le risposte

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

Se vuoi essere convincente in una discussione tecnica, devi dimostrare tre cose:

1. sai i concetti di base senza confonderli;
2. sai collegare il concetto a un comando, una vista o un errore reale;
3. sai ragionare in modalita operativa, non solo definitoria.

Una risposta forte da DBA non e lunga. E precisa, gerarchica e verificabile.


