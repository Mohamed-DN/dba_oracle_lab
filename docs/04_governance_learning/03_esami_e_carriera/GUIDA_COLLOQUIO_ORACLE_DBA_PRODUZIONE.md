# Dossier Colloquio Oracle DBA Produzione

> Target: colloquio tecnico per DBA Oracle senior autonomo.
> Prima scadenza: mercoledi 3 giugno 2026 sera. Ripasso extra: giovedi 4 giugno 2026.

## Obiettivo

Preparare risposte tecniche difendibili per amministrazione Oracle Enterprise, RMAN, Linux,
performance tuning, troubleshooting L2/L3 e alta affidabilita'. Le risposte sono pensate
per essere esposte ad alta voce: prima decisione, evidenze, rischio, validazione e prevenzione.

## Procedura operativa

1. Studia prima tutte le schede `P0`, poi le `P1`; usa le `P2` come rifinitura.
2. Per ogni domanda rispondi senza leggere per 60-90 secondi.
3. Apri il file indicato in `Leggi nel repo` quando una risposta non e' fluida.
4. Svolgi i 15 drill Severity 1 ad alta voce usando: impatto, evidenze, mitigazione, rischio residuo, validazione, prevenzione.
5. Completa almeno una mock interview prima del colloquio.

## Piano di studio rapido

| Data | Priorita | Attivita |
| --- | --- | --- |
| Sabato 30 maggio 2026 | P0 | Architettura, amministrazione, Linux e prime 30 schede RMAN |
| Domenica 31 maggio 2026 | P0 | RMAN completo, restore drill e RECOVER TABLE |
| Lunedi 1 giugno 2026 | P0 | Performance, troubleshooting e drill Sev1 1-8 |
| Martedi 2 giugno 2026 | P0/P1 | RAC, ASM, Data Guard, patching e drill Sev1 9-15 |
| Mercoledi 3 giugno 2026 | Ripasso | Mock 1, risposte deboli, comandi RMAN e scenario FRA/DG |
| Giovedi 4 giugno 2026 | Extra | Mock 2 e rifinitura P1/P2 se il colloquio e' giovedi |

## Metodo di risposta senior

Una risposta forte non e' una lista di comandi. Parti dall'impatto, raccogli evidenze prima
di modificare lo stato, scegli il fix meno distruttivo, dichiara il rischio residuo e chiudi
con una validazione osservabile. Nei Sev1 separa sempre workaround immediato e root cause.

## Domande tecniche

## Architettura Oracle e amministrazione ordinaria
### Scheda di capitolo

**Cosa ripassare**: istanza, file fisici, SGA/PGA, processi background, redo,
UNDO, listener, parametri e multitenant.

**Verifiche da ricordare**:

```sql
SELECT instance_name, status, database_status FROM v$instance;
SELECT name, open_mode, database_role, log_mode FROM v$database;
SHOW PARAMETER spfile;
```

**Leggi nel repo**:
[Architettura Oracle](../01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md).


### Q001 [P0] Qual e' la differenza tra database e istanza?

**Risposta orale**: Il database e' l'insieme dei file persistenti; l'istanza e' memoria SGA piu' processi Oracle che aprono e gestiscono quei file.

**Trappola / follow-up**: Come lo spieghi durante un riavvio della sola istanza?

### Q002 [P0] Come distingui SGA e PGA?

**Risposta orale**: La SGA e' condivisa dall'istanza; la PGA appartiene al processo server o background e contiene aree private come sort e session state.

**Trappola / follow-up**: Quale rischio introduci aumentando PGA senza guardare la RAM OS?

### Q003 [P0] A cosa serve il buffer cache?

**Risposta orale**: Riduce I/O fisico mantenendo copie dei blocchi letti; una cache hit non prova da sola che il sistema sia sano.

**Trappola / follow-up**: Perche' un hit ratio alto puo' convivere con SQL lento?

### Q004 [P0] Cosa contiene lo shared pool?

**Risposta orale**: Library cache e dictionary cache supportano parsing, metadata e riuso dei cursori; pressione o frammentazione aumentano hard parse e mutex contention.

**Trappola / follow-up**: Come distingui sintomo da causa nello shared pool?

### Q005 [P0] A cosa serve il redo log buffer?

**Risposta orale**: Accoglie redo change vectors prima che LGWR li persista negli online redo log secondo gli eventi di flush.

**Trappola / follow-up**: Perche' non sostituisce gli online redo log?

### Q006 [P0] Quando scrive LGWR?

**Risposta orale**: Scrive al commit e in altri eventi di flush; il commit attende la persistenza del redo necessario, non la scrittura immediata dei datafile.

**Trappola / follow-up**: Quale wait event cerchi se i commit sono lenti?

### Q007 [P0] Quando scrive DBWR?

**Risposta orale**: DBWR scarica dirty buffers verso i datafile quando serve spazio o durante checkpoint; non e' sul percorso sincrono normale del commit.

**Trappola / follow-up**: Perche' COMMIT non aspetta DBWR?

### Q008 [P0] Cosa fa CKPT?

**Risposta orale**: CKPT coordina i checkpoint e aggiorna header dei datafile e controlfile con le informazioni di avanzamento necessarie al recovery.

**Trappola / follow-up**: Che relazione ha con MTTR?

### Q009 [P0] Cosa fa SMON?

**Risposta orale**: SMON esegue attivita' di sistema come instance recovery e pulizie interne; non e' il processo da usare come risposta generica a ogni problema.

**Trappola / follow-up**: Cosa succede dopo un instance crash?

### Q010 [P0] Cosa fa PMON?

**Risposta orale**: PMON ripulisce risorse di processi falliti e collabora con la registrazione dinamica dei servizi.

**Trappola / follow-up**: Che cosa controlli se un service non compare nel listener?

### Q011 [P0] A cosa servono ARCn?

**Risposta orale**: In ARCHIVELOG mode archiviano gli online redo log pieni nelle destinazioni configurate; se non riescono, il database puo' fermare le transazioni.

**Trappola / follow-up**: Quale errore segnala una destinazione satura?

### Q012 [P0] Perche' il controlfile e' critico?

**Risposta orale**: Descrive struttura fisica, checkpoint e metadata necessari a mount e recovery; va multiplexato e incluso nella strategia RMAN.

**Trappola / follow-up**: Come riparti se perdi tutte le copie?

### Q013 [P0] Che cosa contiene un datafile?

**Risposta orale**: Contiene blocchi persistenti dei tablespace; il recovery ricostruisce le modifiche mancanti applicando redo.

**Trappola / follow-up**: Quando puoi recuperare un singolo datafile online?

### Q014 [P0] Come dimensioni gli online redo log?

**Risposta orale**: Cerco switch regolari compatibili con workload e recovery; log troppo piccoli aumentano switch e checkpoint pressure, troppo grandi allungano alcuni recovery.

**Trappola / follow-up**: Quale vista usi per misurare gli switch?

### Q015 [P0] Perche' servono gli archivelog?

**Risposta orale**: Conservano la storia redo necessaria a media recovery, PITR, backup online e Data Guard.

**Trappola / follow-up**: Cosa perdi in NOARCHIVELOG?

### Q016 [P0] Qual e' il ruolo dell'UNDO?

**Risposta orale**: Supporta read consistency, rollback e alcune operazioni flashback; va dimensionato rispetto a durata query e tasso di modifica.

**Trappola / follow-up**: Come colleghi ORA-01555 a UNDO?

### Q017 [P0] Come funziona TEMP?

**Risposta orale**: TEMP ospita segmenti temporanei per sort, hash, operazioni parallele e spill della PGA; non e' un deposito permanente.

**Trappola / follow-up**: Perche' aggiungere tempfile non risolve sempre la causa?

### Q018 [P0] Perche' SYSTEM e SYSAUX sono speciali?

**Risposta orale**: Contengono componenti critici del data dictionary e repository; richiedono guardrail piu' severi nelle operazioni di recovery.

**Trappola / follow-up**: Puoi usare RECOVER TABLE per oggetti in SYSTEM?

### Q019 [P0] Quali sono gli stati NOMOUNT, MOUNT e OPEN?

**Risposta orale**: NOMOUNT avvia istanza e legge parametri, MOUNT apre il controlfile, OPEN apre datafile e redo rendendo disponibile il database.

**Verifica utile**: `STARTUP NOMOUNT`, `ALTER DATABASE MOUNT`, `ALTER DATABASE OPEN`.

**Trappola / follow-up**: In quale stato ripristini un controlfile?

### Q020 [P0] Che cos'e' un checkpoint?

**Risposta orale**: E' un punto logico di avanzamento che limita il redo necessario per instance recovery coordinando persistenza dei dirty buffers.

**Trappola / follow-up**: Aumentare la frequenza ha sempre solo vantaggi?

### Q021 [P0] Che cos'e' lo SCN?

**Risposta orale**: E' l'orologio logico Oracle usato per consistenza e recovery; collega blocchi, redo e punti temporali.

**Trappola / follow-up**: Quando preferisci UNTIL SCN a UNTIL TIME?

### Q022 [P0] Cosa accade internamente al COMMIT?

**Risposta orale**: Oracle rende durevole il redo tramite LGWR e conferma il commit; i blocchi dati possono essere scritti dopo da DBWR.

**Trappola / follow-up**: Perche' il redo e' write-ahead logging?

### Q023 [P0] Che cos'e' il crash recovery?

**Risposta orale**: Dopo perdita dell'istanza Oracle applica redo per roll-forward e undo per rollback delle transazioni non committate.

**Trappola / follow-up**: In cosa differisce dal media recovery?

### Q024 [P0] Che cos'e' il media recovery?

**Risposta orale**: Ripara perdita o arretramento di file usando backup e redo; puo' riguardare database, tablespace, datafile o blocchi.

**Trappola / follow-up**: Quando serve RMAN?

### Q025 [P0] Come garantisce Oracle la read consistency?

**Risposta orale**: Una query vede una versione coerente usando SCN e undo per ricostruire versioni precedenti dei blocchi modificati.

**Trappola / follow-up**: Perche' una query lunga puo' fallire con ORA-01555?

### Q026 [P0] Che differenza c'e' tra lock e latch o mutex?

**Risposta orale**: I lock proteggono coerenza transazionale; latch e mutex serializzano strutture interne con granularita' e durata molto piu' ridotte.

**Trappola / follow-up**: Perche' non tratti una mutex contention come un lock applicativo?

### Q027 [P0] Come distingui connection, session e process?

**Risposta orale**: La connessione e' il canale client, la sessione e' il contesto logico nel DB, il process e' il worker OS o Oracle associato.

**Trappola / follow-up**: Una connection pool puo' avere piu' sessioni?

### Q028 [P0] Dedicated server o shared server?

**Risposta orale**: Dedicated assegna un processo server per connessione; shared server riduce processi per workload adatto ma aggiunge complessita'.

**Trappola / follow-up**: Quale scegli per batch pesanti?

### Q029 [P0] Come funziona la registrazione dinamica al listener?

**Risposta orale**: PMON o LREG pubblica servizi al listener usando parametri locali e remoti; il listener non contiene i dati del database.

**Trappola / follow-up**: Come forzi una nuova registrazione?

### Q030 [P0] SERVICE_NAME e SID sono intercambiabili?

**Risposta orale**: No: il service rappresenta un endpoint logico e puo' seguire workload e ruoli; il SID identifica una specifica istanza.

**Trappola / follow-up**: Perche' RAC usa servizi?

### Q031 [P0] SPFILE e PFILE: cosa cambia?

**Risposta orale**: SPFILE e' binario e persistente, gestibile con ALTER SYSTEM; PFILE e' testo utile per bootstrap o recovery.

**Trappola / follow-up**: Come ricrei lo SPFILE da PFILE?

### Q032 [P0] Cosa significa SCOPE MEMORY, SPFILE o BOTH?

**Risposta orale**: Determina applicazione immediata e persistenza al riavvio; alcuni parametri richiedono restart e non accettano MEMORY.

**Trappola / follow-up**: Come eviti modifiche non persistenti?

### Q033 [P0] Dove cerchi alert log e trace?

**Risposta orale**: Uso ADR e ADRCI per localizzare home, alert e trace; raccolgo evidenze prima di cambiare parametri.

**Trappola / follow-up**: Perche' non basta guardare l'ultimo errore?

### Q034 [P0] Che cos'e' la FRA?

**Risposta orale**: E' un'area gestita per file di recovery come archivelog, flashback log e backup; quota logica e spazio fisico vanno verificati entrambi.

**Verifica utile**: `SELECT * FROM v$recovery_file_dest;` e `SELECT * FROM v$recovery_area_usage;`.

**Trappola / follow-up**: Perche' puo' bloccarsi il database?

### Q035 [P0] Perche' ARCHIVELOG e' obbligatorio in produzione?

**Risposta orale**: Permette backup online e recovery oltre l'ultimo full, oltre a Data Guard; richiede monitoraggio delle destinazioni.

**Trappola / follow-up**: Come verifichi la modalita'?

### Q036 [P0] A cosa serve supplemental logging?

**Risposta orale**: Aggiunge informazioni redo necessarie in scenari di replica o mining logico; va abilitato secondo requisito, non indiscriminatamente.

**Trappola / follow-up**: Quando lo richiede GoldenGate?

### Q037 [P0] Come usi il recycle bin?

**Risposta orale**: Per DROP non PURGE puo' consentire FLASHBACK TABLE rapido; prima controllo sempre se l'oggetto e' recuperabile senza RMAN.

**Trappola / follow-up**: Quando non ti salva?

### Q038 [P0] Come controlli Scheduler e job?

**Risposta orale**: Interrogo viste DBA_SCHEDULER e log esecuzioni, distinguendo job fallito, bloccato o mai partito.

**Trappola / follow-up**: Quali evidenze raccogli prima del rerun?

### Q039 [P0] Perche' raccogliere statistiche dictionary e fixed objects?

**Risposta orale**: Il CBO usa statistiche coerenti anche per metadata e viste dinamiche; dopo cambi importanti possono influenzare performance amministrative.

**Trappola / follow-up**: Le raccogli durante picco?

### Q040 [P0] Bigfile e smallfile tablespace: differenza?

**Risposta orale**: Bigfile semplifica gestione di volumi elevati con pochi file; smallfile distribuisce in piu' datafile. La scelta dipende da storage e procedure.

**Trappola / follow-up**: AUTOEXTEND elimina il capacity planning?

### Q041 [P0] Che ruolo ha il block size Oracle?

**Risposta orale**: Il block size definisce l'unita' I/O logica dei datafile e influenza cache, layout e workload; la scelta standard si fissa alla creazione del database.

**Trappola / follow-up**: Lo cambi per correggere una singola query lenta?

### Q042 [P0] Qual e' il rischio di AUTOEXTEND illimitato?

**Risposta orale**: Evita alcuni incidenti immediati ma puo' saturare filesystem o diskgroup condivisi; servono maxsize e alert.

**Trappola / follow-up**: Che soglie imposti?

### Q043 [P0] Quando metti un tablespace offline o read only?

**Risposta orale**: Offline isola file o abilita recovery; read only protegge dati statici e puo' semplificare backup. Valuto impatto applicativo.

**Trappola / follow-up**: SYSTEM puo' andare offline?

### Q044 [P0] A cosa serve il password file?

**Risposta orale**: Abilita autenticazione amministrativa remota come SYSDBA o SYSBACKUP; deve essere protetto e coerente nei cluster e in Data Guard.

**Trappola / follow-up**: Perche' conta nel roll-forward FROM SERVICE?

### Q045 [P0] Cosa sono CDB e PDB?

**Risposta orale**: Il CDB ospita root, seed e PDB; separa amministrazione comune e workload pluggable con impatti su connessione e recovery.

**Trappola / follow-up**: Da dove lanci RECOVER TABLE per una PDB?

### Q046 [P0] DBID, DB_NAME e DB_UNIQUE_NAME: differenze?

**Risposta orale**: DBID identifica il database per RMAN, DB_NAME la famiglia database, DB_UNIQUE_NAME distingue siti o membri Data Guard.

**Trappola / follow-up**: Quale parametro evita ambiguita' tra primary e standby?

## Installazione, configurazione e patching
### Scheda di capitolo

**Cosa ripassare**: prerequisiti OS, inventory, response file, patch RU,
`opatch`, `datapatch`, rolling patch e rollback.

**Verifiche da ricordare**:

```bash
opatch version
opatch lsinventory
opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir <patch_dir>
```

**Leggi nel repo**:
[Patching RAC](../../02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md).

### Q047 [P0] Come prepari i prerequisiti OS prima dell'installazione?

**Risposta orale**: Verifico matrice Oracle, RAM, swap, filesystem, pacchetti, kernel, limiti, rete, DNS e time sync prima di lanciare installer.

**Trappola / follow-up**: Quale evidenza conservi nel change?

### Q048 [P0] Quali kernel parameter controlli?

**Risposta orale**: Controllo shared memory, semafori, file handle, porte effimere e parametri indicati dalla documentazione della release.

**Trappola / follow-up**: Perche' non copi valori da un server a caso?

### Q049 [P0] Perche' servono limits.conf e PAM limits?

**Risposta orale**: Oracle richiede limiti adeguati per file descriptor, processi e stack; verifico il valore effettivo nella sessione oracle.

**Trappola / follow-up**: Come dimostri il valore attivo?

### Q050 [P0] Come presenti udev, ASMLib e AFD?

**Risposta orale**: Sono opzioni per rendere i device persistenti e gestibili; scelgo secondo standard aziendale e versione GI, evitando nomi instabili.

**Trappola / follow-up**: Perche' /dev/sdX e' rischioso?

### Q051 [P0] Perche' NTP o chrony conta per Oracle?

**Risposta orale**: Timestamp coerenti sono essenziali per diagnosi, cluster e correlazione eventi; controllo drift e sorgenti.

**Trappola / follow-up**: Che rischio crea un salto di tempo?

### Q052 [P0] Perche' DNS e /etc/hosts sono critici?

**Risposta orale**: Hostname, VIP, SCAN e risoluzione inversa devono essere coerenti; errori qui emergono come problemi listener o cluster.

**Trappola / follow-up**: Come testi forward e reverse lookup?

### Q053 [P0] ORACLE_BASE, ORACLE_HOME e inventory: differenze?

**Risposta orale**: ORACLE_BASE organizza file amministrativi, ORACLE_HOME contiene binari per una release, inventory traccia home e patch installate.

**Trappola / follow-up**: Perche' l'inventory va protetto?

### Q054 [P0] Quali gruppi OS usi?

**Risposta orale**: Separazione oinstall, dba e gruppi privilegiati come oper, backupdba o asmadmin supporta least privilege e gestione Grid.

**Trappola / follow-up**: Concedi sempre dba a tutti?

### Q055 [P0] Quando usi installazione silent?

**Risposta orale**: Per ripetibilita', automazione e audit uso response file versionati e validati in ambiente non produttivo.

**Trappola / follow-up**: Quali segreti non committi?

### Q056 [P0] Come usi DBCA in modo controllato?

**Risposta orale**: DBCA crea o configura database con template e parametri espliciti; salvo response file e verifico output e alert log.

**Trappola / follow-up**: Quando preferisci script manuali?

### Q057 [P0] Come configuri listener e NETCA?

**Risposta orale**: Creo listener e alias coerenti con servizi, porte e standard; valido con lsnrctl e connessioni reali.

**Trappola / follow-up**: tnsping prova il login applicativo?

### Q058 [P0] Cosa metti in un response file?

**Risposta orale**: Valori ripetibili non sensibili, inventory, home, gruppi e opzioni; i segreti entrano da vault o canale protetto.

**Trappola / follow-up**: Perche' versionarlo?

### Q059 [P0] RU e one-off patch: differenza?

**Risposta orale**: RU aggrega fix periodici e baseline supportata; one-off risolve un bug specifico e richiede verifica conflitti e compatibilita'.

**Trappola / follow-up**: Quale scegli prima?

### Q060 [P0] Perche' controlli la versione OPatch?

**Risposta orale**: Una patch puo' richiedere OPatch minimo; aggiorno il tool nell'home corretto e verifico prima dell'applicazione.

**Trappola / follow-up**: Come eviti di usare OPatch di un altro home?

### Q061 [P0] Come esegui conflict check?

**Risposta orale**: Uso prereq CheckConflictAgainstOHWithDetail e leggo README patch; conflitti richiedono merge patch o indicazioni Oracle.

**Verifica utile**: `opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir <patch_dir>`.

**Trappola / follow-up**: Applichi comunque se il check fallisce?

### Q062 [P0] Cosa leggi da opatch lsinventory?

**Risposta orale**: Home, inventory, patch installate e dettagli utili a baseline e rollback; salvo evidenza before e after.

**Trappola / follow-up**: Perche' controlli ogni nodo RAC?

### Q063 [P0] Cosa salvi prima del patching?

**Risposta orale**: Backup RMAN valido, SPFILE, inventory, Oracle Home secondo standard, configurazioni e piano rollback testato.

**Trappola / follow-up**: Un tar dell'home sostituisce RMAN?

### Q064 [P0] Che ruolo ha datapatch?

**Risposta orale**: Allinea componenti SQL nel database ai binari patchati; va eseguito e verificato su CDB e PDB secondo README.

**Trappola / follow-up**: Quale vista controlli dopo?

### Q065 [P0] Come funziona un rolling patch RAC?

**Risposta orale**: Patching nodo per nodo mantiene servizio se patch e architettura lo consentono; dreno servizi e verifico cluster tra passi.

**Trappola / follow-up**: Ogni patch e' rolling?

### Q066 [P0] Come pianifichi patching con Data Guard?

**Risposta orale**: Valuto standby-first e role transition secondo patch README e compatibilita'; non improvviso l'ordine in produzione.

**Trappola / follow-up**: Quando fai switchover?

### Q067 [P0] Perche' preferire out-of-place patching?

**Risposta orale**: Un nuovo home riduce rollback tecnico e rende chiaro il cutover; richiede spazio, inventory e aggiornamento servizi.

**Trappola / follow-up**: Come ritorni al vecchio home?

### Q068 [P0] Come prepari il rollback?

**Risposta orale**: Definisco trigger, finestra, backup, comando rollback e ripristino home/config; il rollback e' parte del change, non una nota finale.

**Trappola / follow-up**: Chi decide il go/no-go?

### Q069 [P0] Come verifichi SQL patch registry?

**Risposta orale**: Interrogo dba_registry_sqlpatch e log datapatch per stato e errori su container interessati.

**Trappola / follow-up**: Un exit code zero basta?

### Q070 [P0] A cosa serve CVU?

**Risposta orale**: Cluster Verification Utility verifica prerequisiti e salute cluster prima o dopo installazioni e patch GI.

**Trappola / follow-up**: Lo usi solo in installazione?

### Q071 [P0] Come gestisci stop e start servizi?

**Risposta orale**: Uso strumenti supportati come srvctl e sequenza documentata; verifico dipendenze e session draining prima dello stop.

**Trappola / follow-up**: Perche' evitare kill casuali?

### Q072 [P0] Cosa deve contenere un patch plan?

**Risposta orale**: Scope, nodi, prerequisiti, backup, comandi, checkpoint, test, rollback, comunicazioni e responsabilita'.

**Trappola / follow-up**: Quale evidenza serve per audit?

### Q073 [P0] GI e DB home: quale ordine?

**Risposta orale**: Dipende da patch README e matrice; GI e DB home sono scope distinti e vanno verificati esplicitamente.

**Trappola / follow-up**: Perche' non assumere stesso RU?

### Q074 [P0] Come validi una patch a fine finestra?

**Risposta orale**: Controllo inventory, registry SQL, alert log, servizi, listener, workload smoke test e monitoraggio post-change.

**Trappola / follow-up**: Quando chiudi il change?

## Linux e automazione Bash
### Scheda di capitolo

**Cosa ripassare**: filesystem, inode, CPU, memoria, I/O, rete, systemd,
cron, logging, idempotenza e gestione sicura dei segreti.

**Verifiche da ricordare**:

```bash
df -h
df -i
vmstat 1 5
iostat -xz 1 5
systemctl status <service>
```

**Leggi nel repo**:
[Attivita lab RAC](./GUIDA_ATTIVITA_LAB_RAC.md).

### Q075 [P0] Come distingui filesystem pieno e inode esauriti?

**Risposta orale**: Uso df -h e df -i: spazio byte e inode sono risorse diverse, entrambe possono bloccare scritture.

**Verifica utile**: `df -h` e `df -i`: misurano problemi diversi.

**Trappola / follow-up**: Perche' cancellare un file grande non aiuta gli inode?

### Q076 [P0] Come trovi cosa occupa spazio?

**Risposta orale**: Parto da du per directory, poi find controllato; evito scansioni costose indiscriminate durante il picco.

**Trappola / follow-up**: Come gestisci file cancellati ma ancora aperti?

### Q077 [P0] Come leggi dischi, partizioni e LVM?

**Risposta orale**: Uso lsblk, pvs, vgs e lvs per mappare device, volume group e logical volume prima di proporre resize.

**Trappola / follow-up**: Cosa verifichi prima di estendere filesystem?

### Q078 [P0] Quali opzioni NFS controlli per backup?

**Risposta orale**: Verifico mount, latenza, hard mount e opzioni certificate dallo standard; un timeout NFS puo' sembrare errore RMAN.

**Trappola / follow-up**: Come distingui rete e storage?

### Q079 [P0] Come usi iostat?

**Risposta orale**: Guardo latenza, utilization e queue per device nel tempo; un singolo snapshot non basta a diagnosticare I/O.

**Trappola / follow-up**: Quale metrica correli ai wait Oracle?

### Q080 [P0] Come usi vmstat?

**Risposta orale**: Osservo runnable queue, swap, paging, I/O e CPU steal o wait per capire la pressione sistemica.

**Trappola / follow-up**: Perche' free memory bassa non implica problema?

### Q081 [P0] Come leggi top e ps?

**Risposta orale**: Identifico processi CPU o memoria, PID e comando, poi collego processo OS a sessione Oracle prima di intervenire.

**Trappola / follow-up**: Killi un processo Oracle senza analisi?

### Q082 [P0] Cosa significa free -m su Linux moderno?

**Risposta orale**: Distinguo free, available, cache e swap; Linux usa RAM libera come cache e questo e' normale.

**Trappola / follow-up**: Quando la swap e' un segnale serio?

### Q083 [P0] Come verifichi HugePages?

**Risposta orale**: Controllo /proc/meminfo, configurazione e uso effettivo; HugePages riduce overhead per SGA ma richiede sizing coerente.

**Trappola / follow-up**: AMM e HugePages convivono bene?

### Q084 [P0] Come valuti swappiness?

**Risposta orale**: Controllo sysctl e comportamento reale; ridurre swappiness non sostituisce capacity planning della memoria.

**Trappola / follow-up**: Imposti sempre zero?

### Q085 [P0] Quali ulimit controlli?

**Risposta orale**: Verifico nofile, nproc, stack e limiti effettivi dell'utente oracle nella sessione e nei servizi systemd.

**Trappola / follow-up**: Perche' limits.conf puo' non bastare?

### Q086 [P0] Come gestisci un servizio systemd?

**Risposta orale**: Uso systemctl status, start, stop, enable e unit file controllato; raccolgo log e dipendenze.

**Trappola / follow-up**: Quando usi restart?

### Q087 [P0] Come usi journalctl?

**Risposta orale**: Filtro per unit, boot e finestra temporale per correlare eventi OS con alert log Oracle.

**Trappola / follow-up**: Come esporti evidenze?

### Q088 [P0] Quando guardi dmesg?

**Risposta orale**: Cerco errori kernel, OOM, device reset, filesystem e network; e' utile per problemi sotto il livello Oracle.

**Trappola / follow-up**: Cosa fai se trovi I/O error?

### Q089 [P0] Come testi rete e DNS?

**Risposta orale**: Uso ss, nc, dig o getent e test applicativi; separo reachability, porta, listener e autenticazione DB.

**Trappola / follow-up**: Perche' ping non basta?

### Q090 [P0] Come gestisci ownership e permessi?

**Risposta orale**: Uso utente, gruppo e mode minimi necessari; evito chmod ricorsivi improvvisati su Oracle Home o datafile.

**Trappola / follow-up**: Perche' 777 e' inaccettabile?

### Q091 [P0] Come usi find in sicurezza?

**Risposta orale**: Prima elenco i candidati con criteri precisi, poi approvo la cancellazione; per file Oracle preferisco tool supportati.

**Trappola / follow-up**: Perche' find -delete e' rischioso?

### Q092 [P0] Come gestisci log rotation?

**Risposta orale**: Uso strumenti previsti per log OS e ADRCI per ADR; preservo evidenze incidenti e retention concordata.

**Trappola / follow-up**: Ruoti manualmente alert log durante Sev1?

### Q093 [P0] Come scheduli task con cron?

**Risposta orale**: Imposto ambiente esplicito, path assoluti, logging, exit code e lock contro sovrapposizioni.

**Trappola / follow-up**: Perche' uno script funziona a mano ma non da cron?

### Q094 [P0] Perche' usare set -euo pipefail?

**Risposta orale**: Rende visibili errori, variabili non definite e pipeline fallite; va gestito consapevolmente con cleanup e trap.

**Trappola / follow-up**: Può rompere script legacy?

### Q095 [P0] Come parametrizzi ORACLE_SID e ORACLE_HOME?

**Risposta orale**: Non dipendo dal profilo interattivo: carico ambiente controllato e valido binari e target prima delle azioni.

**Trappola / follow-up**: Come eviti di operare sul DB sbagliato?

### Q096 [P0] Come impedisci esecuzioni concorrenti?

**Risposta orale**: Uso flock o lockfile robusto con cleanup e timeout; registro PID e timestamp.

**Trappola / follow-up**: Cosa succede dopo crash dello script?

### Q097 [P0] Come gestisci exit code e logging?

**Risposta orale**: Ogni fase scrive timestamp, comando logico, esito e messaggio; propago exit code al scheduler o monitoring.

**Trappola / follow-up**: Perche' echo generico non basta?

### Q098 [P0] Come richiami SQLPlus da Bash?

**Risposta orale**: Uso here-document o file SQL controllato, whenever sqlerror exit e segreti fuori dalla command line.

**Trappola / follow-up**: Come rilevi un errore SQL?

### Q099 [P0] Come richiami RMAN da Bash?

**Risposta orale**: Uso command file e log dedicato, controllo exit code e pattern RMAN/ORA, con target validato.

**Trappola / follow-up**: Un job verde garantisce backup usabile?

### Q100 [P0] Come raccogli un evidence bundle?

**Risposta orale**: Salvo timestamp, hostname, comandi non distruttivi, alert log, metriche OS e output Oracle in directory ticketizzata.

**Trappola / follow-up**: Perche' raccogliere prima del fix?

### Q101 [P0] Cosa significa automazione idempotente?

**Risposta orale**: Rieseguire lo script porta allo stato desiderato senza duplicare o danneggiare risorse; includo pre-check e post-check.

**Trappola / follow-up**: Come testi il secondo run?

### Q102 [P0] Come proteggi segreti negli script?

**Risposta orale**: Uso wallet, vault, permessi e input sicuro; non inserisco password in process list, repo o log.

**Trappola / follow-up**: Perche' ps puo' esporre credenziali?

## RMAN, backup e business continuity
### Scheda di capitolo

**Cosa ripassare**: retention, deletion policy, restore, recover, validate,
catalog, duplicate, Data Guard e recupero puntuale di una tabella.

**Verifiche da ricordare**:

```rman
SHOW ALL;
LIST BACKUP SUMMARY;
REPORT NEED BACKUP;
RESTORE DATABASE PREVIEW SUMMARY;
RESTORE DATABASE VALIDATE;
```

**Leggi nel repo**:
[RMAN completa 19c](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md),
[comandi RMAN enterprise](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMANDI_ENTERPRISE.md)
e [cheat sheet RMAN](../../01_operations/01_cheat_sheets/CS_RMAN_RAPIDO.md).

### Q103 [P0] Qual e' l'architettura minima RMAN?

**Risposta orale**: RMAN e' un client che si connette al database target e orchestra backup, restore e recovery. I metadata — cosa e' stato backuppato, quando, dove — vivono nel controlfile del target. In aggiunta puoi avere un recovery catalog su un database separato, che conserva storico piu' lungo, supporta script centralizzati e gestisce Data Guard con piu' robustezza. I channel sono le sessioni server che eseguono l'I/O fisico verso disco o tape: il numero di channel e il device type determinano parallelismo e throughput. In produzione verifico tutto con `SHOW ALL` e `LIST BACKUP SUMMARY`.

**In produzione**: Uso sempre catalog in ambienti enterprise con piu' database o Data Guard. Il controlfile da solo ha retention limitata da `CONTROL_FILE_RECORD_KEEP_TIME`.

**Trappola / follow-up**: Quando il catalog diventa importante?

### Q104 [P0] Full backup e incremental level 0 sono uguali?

**Risposta orale**: Fisicamente fanno la stessa cosa: leggono tutti i blocchi usati del database. La differenza e' che il full backup non puo' essere usato come base per successivi incrementali level 1: e' un backup standalone. Il level 0 invece e' riconosciuto da RMAN come baseline e i successivi level 1 calcoleranno i blocchi cambiati a partire da quel punto. Quindi in una strategia incrementale il primo backup della settimana deve essere level 0, non full. In produzione uso `BACKUP INCREMENTAL LEVEL 0 DATABASE TAG 'WK_L0'`.

**In produzione**: Piantifico L0 la domenica e L1 lun-sab. Con Block Change Tracking abilitato, i L1 sono molto piu' veloci.

**Trappola / follow-up**: Perche' la differenza conta nel piano incrementale?

### Q105 [P0] Level 1 differential e cumulative: differenze?

**Risposta orale**: Il differential (default) cattura i blocchi cambiati dall'ultimo backup di livello uguale o inferiore — cioe' dall'ultimo L0 o L1. Il cumulative cattura tutti i blocchi cambiati dall'ultimo L0, quindi e' piu' grande ma al restore ne serve solo uno. Il trade-off e': differential riduce finestra backup ma al restore servono tutti i L1 in sequenza; cumulative allarga il backup ma semplifica e velocizza il restore. Per ridurre MTTR scelgo cumulative, per ridurre finestra backup scelgo differential. Esempio: `BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE`.

**In produzione**: Scelgo in base all'RTO richiesto. Con RTO stretto preferisco cumulative o strategie incrementally updated con image copy.

**Trappola / follow-up**: Quale riduce MTTR?

### Q106 [P0] Backupset e image copy: differenze?

**Risposta orale**: Backupset e' formato RMAN in piece, efficiente e comprimibile; image copy e' copia file utilizzabile in strategie switch e merge.

**Trappola / follow-up**: Quando scegli image copy?

### Q107 [P0] Backup piece e backup set: relazione?

**Risposta orale**: Un backup set contiene uno o piu' piece fisici; channel, max piece size e storage influenzano layout e parallelismo.

**Trappola / follow-up**: Perche' un piece mancante invalida il set?

### Q108 [P0] A cosa servono i channel?

**Risposta orale**: Sono sessioni server RMAN che eseguono I/O; numero e device type vanno dimensionati su CPU, rete e storage.

**Trappola / follow-up**: Più channel sono sempre meglio?

### Q109 [P0] Come usi FORMAT e substitution variable?

**Risposta orale**: Definisco nomi univoci come %U e path controllati; evito collisioni e verifico accessibilita' dello storage.

**Trappola / follow-up**: Perche' %U e' utile?

### Q110 [P0] Che rapporto c'e' tra FRA e RMAN?

**Risposta orale**: La FRA puo' ospitare backup e archivelog gestiti; quota e reclaimability dipendono da policy e file ancora necessari.

**Trappola / follow-up**: Perche' DELETE OBSOLETE non basta sempre?

### Q111 [P0] Perche' abilitare controlfile autobackup?

**Risposta orale**: Permette di recuperare controlfile e SPFILE anche in disaster recovery con metadata limitati.

**Trappola / follow-up**: Quando serve SET DBID?

### Q112 [P0] Retention policy: redundancy o recovery window?

**Risposta orale**: Redundancy conserva copie; recovery window protegge recuperabilita' temporale. Scelgo in base a RPO, storage e compliance.

**Trappola / follow-up**: La retention elimina automaticamente tutto?

### Q113 [P0] DELETE OBSOLETE e DELETE EXPIRED: differenze?

**Risposta orale**: Obsolete segue retention; expired rimuove metadata di file assenti dopo CROSSCHECK. Non sono sinonimi.

**Trappola / follow-up**: Expired cancella sempre il file fisico?

### Q114 [P0] Cosa fa CROSSCHECK?

**Risposta orale**: CROSSCHECK confronta i metadata nel repository RMAN (controlfile o catalog) con la disponibilita' fisica dei file su storage. Se un backup piece non e' piu' raggiungibile, viene marcato EXPIRED. Attenzione: non valida il contenuto del backup — per quello serve `RESTORE VALIDATE` o `BACKUP VALIDATE CHECK LOGICAL`. Lo uso sempre prima di `DELETE EXPIRED` per evitare di cancellare metadata di file ancora utili, e prima di un restore critico per sapere cosa e' realmente disponibile. Comandi: `CROSSCHECK BACKUP; CROSSCHECK ARCHIVELOG ALL;`.

**In produzione**: Schedulo crosscheck giornaliero nel maintenance job. Dopo un cambio storage o migrazione NFS, crosscheck e' obbligatorio.

**Trappola / follow-up**: Perche' serve prima della pulizia?

### Q115 [P0] Come configuri deletion policy con Data Guard?

**Risposta orale**: Uso APPLIED ON ALL STANDBY o SHIPPED secondo requisito; una policy prudente evita di cancellare redo ancora necessari.

**Trappola / follow-up**: DELETE FORCE la rispetta?

### Q116 [P0] Come usi BACKUP ARCHIVELOG ALL DELETE INPUT?

**Risposta orale**: Backup e cancellazione input possono liberare spazio, ma devono rispettare policy e accessibilita' delle copie.

**Trappola / follow-up**: DELETE ALL INPUT cosa cambia?

### Q117 [P0] RESTORE VALIDATE cosa prova?

**Risposta orale**: Simula lettura dei backup necessari al restore senza scrivere datafile; dimostra disponibilita' tecnica, non l'intero RTO.

**Trappola / follow-up**: Come lo scheduli?

### Q118 [P0] BACKUP VALIDATE cosa prova?

**Risposta orale**: Legge blocchi del target e rileva corruzioni senza produrre backup; posso aggiungere CHECK LOGICAL.

**Trappola / follow-up**: Quale vista registra corruzioni?

### Q119 [P0] Come leggi LIST e REPORT?

**Risposta orale**: LIST mostra backup registrati; REPORT evidenzia schema, obsolete, unrecoverable o need backup secondo scopo.

**Trappola / follow-up**: Quale comando usi prima di un restore?

### Q120 [P0] Qual e' la sequenza restore e recover database?

**Risposta orale**: La sequenza e': 1) `SHUTDOWN IMMEDIATE` se il database e' ancora aperto; 2) `STARTUP MOUNT` per rendere accessibili i metadata nel controlfile; 3) `RESTORE DATABASE` per ripristinare i datafile dal backup; 4) `RECOVER DATABASE` per applicare redo (archivelog e online redo) e portare i file al punto desiderato; 5) `ALTER DATABASE OPEN` se il recovery e' completo, oppure `ALTER DATABASE OPEN RESETLOGS` se e' incompleto. RESETLOGS crea una nuova incarnation e richiede backup immediato dopo l'apertura. Per un recovery puntuale uso `SET UNTIL TIME` o `UNTIL SCN` prima del restore. In produzione verifico sempre con `RESTORE DATABASE PREVIEW SUMMARY` prima di partire.

**In produzione**: Prima del restore faccio sempre preview per confermare che tutti i piece e archivelog siano disponibili. Dopo RESETLOGS aggiorno subito Data Guard e backup.

**Trappola / follow-up**: Quando serve RESETLOGS?

### Q121 [P0] RESTORE e RECOVER sono intercambiabili?

**Risposta orale**: No: RESTORE copia file dal backup; RECOVER applica modifiche redo fino al punto desiderato.

**Trappola / follow-up**: Perche' servono entrambi?

### Q122 [P0] Come recuperi un controlfile?

**Risposta orale**: Senza controlfile non puoi montare il database perche' il controlfile contiene la struttura fisica — nomi file, checkpoint SCN, incarnation. La procedura e': 1) `STARTUP NOMOUNT` con PFILE minimo o bootstrap; 2) `SET DBID <dbid>` — il DBID deve essere conservato fuori dal database, nel CMDB o nella documentazione operativa; 3) `RESTORE CONTROLFILE FROM AUTOBACKUP` — RMAN cerca nella FRA con naming convention standard; 4) `ALTER DATABASE MOUNT`; 5) `CATALOG START WITH` per registrare backup se necessario; 6) `RECOVER DATABASE` e poi `OPEN RESETLOGS`. Se non hai autobackup, puoi ripristinare dal catalog se disponibile. Per questo `CONTROLFILE AUTOBACKUP ON` e' obbligatorio.

**In produzione**: Conservo DBID nel CMDB e in un file separato. Testo questo scenario almeno una volta all'anno nel DR drill.

**Trappola / follow-up**: Perche' non puoi mount senza controlfile?

### Q123 [P0] Come recuperi lo SPFILE?

**Risposta orale**: Con autobackup e DBID posso ripristinarlo da RMAN dopo startup NOMOUNT con PFILE minimo o bootstrap.

**Trappola / follow-up**: Come ricrei PFILE temporaneo?

### Q124 [P0] Perche' conservare DBID fuori dal database?

**Risposta orale**: In perdita totale aiuta RMAN a localizzare autobackup quando controlfile e catalog non sono disponibili.

**Trappola / follow-up**: Dove lo registri?

### Q125 [P0] Come recuperi un datafile perso?

**Risposta orale**: Offline se necessario, RESTORE DATAFILE, RECOVER DATAFILE e online; valuto ruolo del file e impatto.

**Trappola / follow-up**: Puoi farlo sempre a DB aperto?

### Q126 [P0] Come recuperi un tablespace?

**Risposta orale**: Isolo il tablespace, ripristino e applico redo ai suoi file, poi valido e rimetto online.

**Trappola / follow-up**: SYSTEM segue la stessa procedura online?

### Q127 [P0] Come usi block media recovery?

**Risposta orale**: BLOCKRECOVER o RECOVER BLOCK ripara pochi blocchi corrotti riducendo impatto rispetto a restore file completo.

**Trappola / follow-up**: Quando non basta?

### Q128 [P0] Come recuperi una tabella cancellata?

**Risposta orale**: Dopo un `DROP TABLE ... PURGE`, il recycle bin non aiuta. La soluzione e' `RECOVER TABLE`: RMAN crea un'istanza auxiliary temporanea, esegue un restore e PITR fino al momento prima del DROP, poi estrae la tabella con Data Pump e la importa nel database target. Uso `REMAP TABLE` per importare con nome diverso ed evitare conflitti, poi valido i dati e faccio il cutover applicativo. Prerequisiti: database target aperto READ WRITE in ARCHIVELOG, backup e redo continui fino al punto desiderato, spazio per auxiliary destination. Non funziona per oggetti SYS, SYSTEM, SYSAUX. In CDB mi collego alla root e specifico `OF PLUGGABLE DATABASE`. Esempio: `RECOVER TABLE HR.ORDERS UNTIL TIME "TO_DATE(...)" AUXILIARY DESTINATION '/u01/aux' REMAP TABLE 'HR'.'ORDERS':'ORDERS_RECOVERED';`.

**In produzione**: Prima di ogni RECOVER TABLE verifico lo spazio auxiliary, i backup disponibili e la continuita' degli archivelog. Importo sempre con REMAP e valido prima di sostituire.

**Trappola / follow-up**: Perche' rinomini l'oggetto recuperato?

### Q129 [P0] Come recuperi una tabella in una PDB?

**Risposta orale**: Mi collego localmente alla root e uso RECOVER TABLE ... OF PLUGGABLE DATABASE, verificando backup di root, seed e PDB.

**Trappola / follow-up**: Puoi farlo dalla PDB?

### Q130 [P0] RECOVER TABLE e TSPITR: differenze?

**Risposta orale**: RECOVER TABLE estrae oggetti via auxiliary e Data Pump; TSPITR riporta indietro un tablespace isolato.

**Trappola / follow-up**: Quale ha blast radius minore?

### Q131 [P0] Come esegui un DB PITR?

**Risposta orale**: Definisco UNTIL TIME o SCN prima dell'errore, restore, recover incompleto e OPEN RESETLOGS, comunicando perdita dati prevista.

**Trappola / follow-up**: Come scegli il punto corretto?

### Q132 [P0] Cosa comporta OPEN RESETLOGS?

**Risposta orale**: Crea una nuova incarnation e nuova storia redo; richiede backup post-operazione e gestione coerente degli standby.

**Trappola / follow-up**: Perche' il catalog deve conoscerla?

### Q133 [P0] Che cos'e' una incarnation RMAN?

**Risposta orale**: Rappresenta un ramo della storia redo dopo RESETLOGS; LIST INCARNATION e RESET DATABASE aiutano recovery su rami precedenti.

**Trappola / follow-up**: Quando torni a una vecchia incarnation?

### Q134 [P0] Quando usi CATALOG START WITH?

**Risposta orale**: Quando copie o backup esistono su storage ma non sono noti al repository corrente; catalogo path verificati.

**Trappola / follow-up**: Perche' non catalogare directory casuali?

### Q135 [P0] Come funziona SWITCH DATABASE TO COPY?

**Risposta orale**: Fa puntare il database a image copy gia' preparate, riducendo tempo di restore in strategie incrementally updated.

**Trappola / follow-up**: Quale recovery resta da fare?

### Q136 [P0] Che cos'e' incremental merge?

**Risposta orale**: Aggiorna image copy con level 1 periodici per mantenere una base vicina al presente e ridurre MTTR.

**Trappola / follow-up**: Qual e' il costo storage?

### Q137 [P0] Come funziona DUPLICATE FROM ACTIVE DATABASE?

**Risposta orale**: DUPLICATE FROM ACTIVE DATABASE trasferisce blocchi direttamente dal database sorgente all'auxiliary via rete, senza bisogno di backup pre-staged su storage condiviso. RMAN apre channel sul target e sull'auxiliary, trasferisce datafile, controlfile, SPFILE e applica redo. Prerequisiti: password file coerente sull'auxiliary, connettivita' TNS bidirezionale, spazio sufficiente. E' il metodo piu' rapido per creare clone o standby se la rete lo permette. Lo uso per creare standby Data Guard con `DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE DORECOVER NOFILENAMECHECK`. Preferisco da backup se la rete e' lenta, il target e' sotto carico o se devo fare PITR durante il duplicate.

**In produzione**: Uso wallet per l'autenticazione, mai password sulla command line. Misuro throughput rete prima di partire.

**Trappola / follow-up**: Quando preferisci duplicate da backup?

### Q138 [P0] Come fai DUPLICATE da backup?

**Risposta orale**: Preparo backup accessibili, catalogo se necessario e duplico con parametri e conversioni path coerenti.

**Trappola / follow-up**: Quale vantaggio offre su rete lenta?

### Q139 [P0] Come crei uno standby con RMAN?

**Risposta orale**: La creazione di uno standby con RMAN prevede: 1) preparare l'host standby con Oracle Home compatibile, networking e parametri; 2) creare PFILE/SPFILE standby con `DB_UNIQUE_NAME`, `FAL_SERVER`, `LOG_ARCHIVE_DEST_n` coerenti; 3) creare password file identico o copiarlo dal primary; 4) avviare l'auxiliary in NOMOUNT; 5) connettere RMAN con `CONNECT TARGET ... AUXILIARY ...`; 6) eseguire `DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE DORECOVER NOFILENAMECHECK`. Dopo il duplicate, aggiungo standby redo log (n+1 gruppi per thread) per abilitare real-time apply, configuro redo transport e avvio il managed recovery con `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION`. In 19c non serve la clausola storica `USING CURRENT LOGFILE`, deprecata da 12.1. Valido con `v$dataguard_stats` e `v$managed_standby`.

**In produzione**: Uso Broker DGMGRL per gestire la configurazione dopo il setup iniziale. Gli SRL devono avere la stessa dimensione degli online redo log.

**Trappola / follow-up**: Perche' servono standby redo log?

### Q140 [P0] Quando usi compressione RMAN?

**Risposta orale**: Riduce banda o storage pagando CPU; testo algoritmo e throughput sul workload reale.

**Trappola / follow-up**: BASIC richiede licenza extra?

### Q141 [P0] Come proteggi backup cifrati?

**Risposta orale**: Uso encryption RMAN e gestione wallet o password secondo standard; testo restore, non solo backup.

**Trappola / follow-up**: Cosa succede se perdi il wallet?

### Q142 [P0] Che cos'e' SBT?

**Risposta orale**: E' l'interfaccia RMAN verso media manager o tape; channel e librerie vendor devono essere verificati end-to-end.

**Trappola / follow-up**: Come diagnostichi errore media manager?

### Q143 [P0] Come registri un database nel catalog?

**Risposta orale**: Connetto target e catalog, eseguo REGISTER DATABASE e sincronizzo metadata, mantenendo sicurezza separata.

**Trappola / follow-up**: Registri ogni standby allo stesso modo?

### Q144 [P0] A cosa serve RESYNC CATALOG?

**Risposta orale**: Allinea metadata controlfile e catalog; in Data Guard posso configurare connect identifier per siti diversi.

**Trappola / follow-up**: Perche' il catalog non va sul primary?

### Q145 [P0] Quali vantaggi offre il recovery catalog?

**Risposta orale**: Storico piu' lungo, script, metadata centralizzati e gestione Data Guard piu' robusta rispetto al solo controlfile.

**Trappola / follow-up**: E' obbligatorio per ogni piccolo DB?

### Q146 [P0] Che cos'e' un Virtual Private Catalog?

**Risposta orale**: Espone un sottoinsieme del catalog a utenti delegati, supportando separazione dei compiti.

**Trappola / follow-up**: Quando e' utile?

### Q147 [P0] Come usi RESTORE PREVIEW?

**Risposta orale**: Mostra backup e archivelog richiesti senza eseguire il restore; aiuta a scoprire dipendenze mancanti.

**Trappola / follow-up**: Sostituisce RESTORE VALIDATE?

### Q148 [P0] Quando usi SECTION SIZE?

**Risposta orale**: Divide grandi datafile in sezioni lavorabili in parallelo per backup o restore multisection.

**Trappola / follow-up**: Perche' non abusarne?

### Q149 [P0] Come usi RATE e MAXPIECESIZE?

**Risposta orale**: RATE limita throughput channel, MAXPIECESIZE limita dimensione piece per vincoli media manager o trasferimento.

**Trappola / follow-up**: Quale impatto ha su RTO?

### Q150 [P0] A cosa serve backup optimization?

**Risposta orale**: Evita copie identiche non necessarie in comandi supportati; va compresa con retention e deletion policy.

**Trappola / follow-up**: Puo' saltare tutto senza errore?

### Q151 [P1] Come usi TAG e KEEP?

**Risposta orale**: TAG identifica famiglie di backup; KEEP protegge backup speciali fino a data o per sempre secondo compliance.

**Trappola / follow-up**: KEEP sostituisce retention?

### Q152 [P1] Che differenza c'e' tra VALIDATE e CHECK LOGICAL?

**Risposta orale**: Validate legge blocchi; CHECK LOGICAL aggiunge controlli logici oltre alla corruzione fisica rilevabile.

**Trappola / follow-up**: Quale costo introduce?

### Q153 [P1] Dove vedi i blocchi corrotti?

**Risposta orale**: Interrogo v$database_block_corruption e correlo file e blocchi con validate e alert log.

**Trappola / follow-up**: Come scegli BLOCKRECOVER?

### Q154 [P1] Come affronti perdita totale server?

**Risposta orale**: Seguo runbook: ambiente, DBID, SPFILE, controlfile, mount, catalog backup, restore, recover e apertura controllata.

**Trappola / follow-up**: Qual e' il primo prerequisito fuori sito?

### Q155 [P1] Come usi backup da standby Data Guard?

**Risposta orale**: Offload riduce carico primary; con catalog e accessibilita' corretta i backup fisici possono supportare restore sull'altro sito.

**Trappola / follow-up**: SPFILE ha una particolarita'?

### Q156 [P1] Come riallinei standby con FROM SERVICE?

**Risposta orale**: Quando lo standby ha un gap e gli archivelog originali sono persi, in Oracle 19c posso usare `RECOVER STANDBY DATABASE FROM SERVICE <primary_service>`. La procedura e': 1) fermo MRP sullo standby con `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL`; 2) da RMAN connesso al solo standby, lancio `RECOVER STANDBY DATABASE FROM SERVICE <primary_tns_alias>` - RMAN contatta il primary via rete e trasferisce i blocchi necessari, come un incremental intelligente; 3) riattivo MRP con `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION`; 4) valido con `v$archive_gap` sullo standby, `v$dataguard_stats` e `SHOW DATABASE` nel Broker. Prerequisiti: password file coerente, connettivita' TNS, primary accessibile. Se la rete non lo permette, il fallback e' `BACKUP INCREMENTAL FROM SCN` sul primary, trasferimento fisico e applicazione sullo standby.

**In produzione**: E' il metodo preferito in 19c per riallineare senza rebuild completo. Molto piu' veloce del duplicate.

**Trappola / follow-up**: Quale prerequisito password file serve?

### Q157 [P1] Quando usi incremental FROM SCN per standby?

**Risposta orale**: E' fallback se il roll-forward diretto non e' praticabile: genero incremental dal primary a partire dallo SCN standby e lo applico.

**Trappola / follow-up**: Quando ricostruisci da zero?

### Q158 [P1] Quali limiti ricordi per RECOVER TABLE?

**Risposta orale**: Target locale read-write e ARCHIVELOG, backup e redo continui, spazio auxiliary; non supporta oggetti SYS, SYSTEM, SYSAUX o physical standby.

**Trappola / follow-up**: Che effetto hanno alcuni named constraint con REMAP?

### Q159 [P1] Come provi davvero i backup?

**Risposta orale**: Eseguo restore validate periodici e restore drill isolati con misurazione tempi; un job backup verde non prova recuperabilita'.

**Trappola / follow-up**: Quale evidenza presenti all'audit?

### Q160 [P1] Come traduci RPO e RTO in strategia RMAN?

**Risposta orale**: RPO guida frequenza e redo protection; RTO guida restore path, parallelismo, copie e drill. Li misuro, non li dichiaro soltanto.

**Trappola / follow-up**: Quale compromesso discuti col business?

## Performance tuning e ottimizzazione
### Scheda di capitolo

**Cosa ripassare**: metodo evidence-first, DB Time, wait event, Top SQL,
piano reale, cardinalita, statistiche, bind e fix reversibili.

**Verifiche da ricordare**:

```sql
SELECT event, total_waits, time_waited
FROM   v$system_event
ORDER  BY time_waited DESC;

SELECT *
FROM   table(dbms_xplan.display_cursor('<SQL_ID>', NULL, 'ALLSTATS LAST'));
```

**Leggi nel repo**:
[AWR, ASH e ADDM](../../02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md)
e [runbook SQL tuning](../../01_operations/02_runbooks_incidenti/RUNBOOK_23_SQL_TUNING_CASI_ENTERPRISE.md).

### Q161 [P0] Qual e' il metodo corretto per un incidente performance?

**Risposta orale**: Il metodo e' evidence-first: 1) definisco impatto e finestra temporale del problema; 2) misuro DB Time e confronto con una baseline (periodo buono); 3) identifico il bottleneck dominante tramite wait class e top event; 4) trovo i top SQL responsabili per elapsed, CPU, buffer gets o physical reads; 5) confronto piano attuale con piano storico cercando cambio plan hash; 6) applico UNA sola modifica misurabile e valido with before/after. Non aumento mai risorse alla cieca: se la CPU e' alta, prima mappo i processi ai SQL responsabili. Strumenti: AWR report, ASH real-time, `v$system_event`, `v$sql`, `DBMS_XPLAN.DISPLAY_CURSOR`.

**In produzione**: Nei Sev1 separo sempre workaround reversibile (baseline, SQL Patch) dal fix strutturale (indice, rewrite SQL).

**Trappola / follow-up**: Perche' non inizi aumentando memoria?

### Q162 [P0] AWR, ASH e ADDM: cosa fanno?

**Risposta orale**: AWR (Automatic Workload Repository) scatta snapshot periodici delle metriche del database e li conserva su disco. Un AWR report e' un'analisi differenziale tra due snapshot che mostra DB Time, load profile, top wait e top SQL. ASH (Active Session History) campiona le sessioni attive ogni secondo in memoria (`v$active_session_history`) e ogni 10 secondi su disco (`dba_hist_active_sess_history`): e' fondamentale per isolare picchi transitori che AWR diluisce nella media. ADDM (Automatic Database Diagnostic Monitor) e' un motore di regole che analizza gli snapshot AWR e produce raccomandazioni automatiche con impact percentage. Attenzione: AWR e ASH richiedono licenza Diagnostics Pack (o Tuning Pack per SQL Tuning Advisor). Senza licenza, uso Statspack come alternativa AWR.

**In produzione**: Configuro AWR a 30 min interval e 30+ giorni retention. Uso AWR per analisi aggregata e ASH per drill-down sul minuto esatto.

**Trappola / follow-up**: Statspack quando serve?

### Q163 [P1] Come usi le wait class?

**Risposta orale**: Raggruppo tempo atteso per capire se il limite e' CPU, I/O, commit, concurrency, network o configuration.

**Trappola / follow-up**: Una wait alta e' sempre causa?

### Q164 [P1] Che cos'e' DB Time?

**Risposta orale**: Somma tempo CPU e wait foreground delle sessioni; puo' superare tempo wall-clock perche' aggrega concorrenza.

**Trappola / follow-up**: Come lo confronti tra due finestre?

### Q165 [P0] Come trovi Top SQL per elapsed time?

**Risposta orale**: Il primo passo e' ordinare i SQL per elapsed time nella finestra dell'incidente. In real-time uso `v$sql` ordinando per `elapsed_time DESC` o per `elapsed_time/executions` se voglio il costo per esecuzione. Nello storico AWR uso `dba_hist_sqlstat` oppure la sezione 'SQL ordered by Elapsed Time' del report AWR. Distinguo tra query singola lenta (una esecuzione con elapsed alto) e query leggera eseguita milioni di volte (elapsed cumulativo alto). Poi per ogni candidato confronto `SQL_ID`, `PLAN_HASH_VALUE`, `BUFFER_GETS`, `DISK_READS` e `ROWS_PROCESSED`. Uso `DBMS_XPLAN.DISPLAY_CURSOR('<SQL_ID>', NULL, 'ALLSTATS LAST')` per il piano reale con righe effettive.

**In produzione**: Non guardo mai solo elapsed: guardo anche buffer gets/execution per capire il costo logico. Un SQL con 10M buffer gets per esecuzione e' un problema anche se l'elapsed e' basso.

**Verifica utile**: `v$sql`, `DBMS_XPLAN.DISPLAY_CURSOR` e storico AWR se licenziato.

**Trappola / follow-up**: Perche' guardi anche rows processed?

### Q166 [P1] Come trovi Top SQL per CPU e buffer gets?

**Risposta orale**: Confronto CPU, gets, reads ed executions per capire costo logico e fisico; scelgo il candidato con impatto reale.

**Trappola / follow-up**: Un SQL_ID alto in gets e' sempre sbagliato?

### Q167 [P1] SQL_ID e child cursor: differenza?

**Risposta orale**: SQL_ID identifica testo normalizzato; child cursor rappresenta varianti compilate per ambiente, bind o mismatch.

**Trappola / follow-up**: Perche' controlli VERSION_COUNT?

### Q168 [P0] EXPLAIN PLAN e DISPLAY_CURSOR: differenze?

**Risposta orale**: `EXPLAIN PLAN` genera un piano stimato senza eseguire realmente la query: ti dice cosa l'optimizer PENSA di fare, ma i valori E-Rows sono solo stime basate su statistiche. `DBMS_XPLAN.DISPLAY_CURSOR` mostra il piano REALE usato durante l'ultima esecuzione, con statistiche effettive come A-Rows (righe reali per step), Starts (quante volte ogni step e' stato eseguito), buffer gets e reads reali. Per il tuning devo SEMPRE usare DISPLAY_CURSOR perche' mi permette di confrontare E-Rows vs A-Rows e trovare dove l'optimizer stima male. La chiamata completa e': `SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('<SQL_ID>', NULL, 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'))`. Se il SQL non e' piu' in cache, uso `DBMS_XPLAN.DISPLAY_AWR` per lo storico.

**In produzione**: Per una regressione reale uso sempre DISPLAY_CURSOR, mai EXPLAIN PLAN. EXPLAIN puo' mostrare un piano diverso da quello effettivo.

**Trappola / follow-up**: Quale usi per regressione reale?

### Q169 [P1] Che cos'e' PLAN_HASH_VALUE?

**Risposta orale**: E' una firma pratica del piano utile per confronti; non sostituisce analisi di operazioni, cardinalita' e predicate.

**Trappola / follow-up**: Due piani con stesso hash sono sempre identici?

### Q170 [P0] Perche' le statistiche contano?

**Risposta orale**: L'optimizer Oracle (CBO) basa tutte le decisioni di piano su stime di cardinalita' derivate dalle statistiche degli oggetti: num_rows, num_distinct, density, histogram, extended statistics. Se le statistiche sono stale, mancanti o non rappresentative, l'optimizer puo' stimare 10 righe quando in realta' ce ne sono 10 milioni, producendo un piano disastroso (es. nested loop invece di hash join). Oracle raccoglie statistiche automaticamente con il maintenance window, ma in caso di bulk load, partition exchange o deploy applicativo devo verificare e raccogliere miratamente con `DBMS_STATS.GATHER_TABLE_STATS` usando `AUTO_SAMPLE_SIZE` e `NO_INVALIDATE => DBMS_STATS.AUTO_INVALIDATE`.

**In produzione**: Non raccolgo statistiche sull'intero database durante un incidente. Raccolgo solo sulla tabella sospettata e poi valido il piano.

**Trappola / follow-up**: Raccogli sempre con cascade?

### Q171 [P1] Quando servono istogrammi?

**Risposta orale**: Aiutano con distribuzioni skewed e predicate selettivi; troppi istogrammi possono aumentare instabilita' e child cursor.

**Trappola / follow-up**: Come decidi?

### Q172 [P1] Che cos'e' bind peeking?

**Risposta orale**: Al primo hard parse il CBO puo' usare valori bind per stimare selettivita'; workload variabile puo' produrre piano inadatto.

**Trappola / follow-up**: Quale meccanismo mitiga?

### Q173 [P1] Che cos'e' adaptive cursor sharing?

**Risposta orale**: Oracle puo' creare child cursor bind-aware per gestire selettivita' diverse osservate a runtime.

**Trappola / follow-up**: Perche' aumenta VERSION_COUNT?

### Q174 [P1] Come riconosci stale statistics?

**Risposta orale**: Controllo DBA_TAB_STATISTICS e modification monitoring, correlando cambio piano e finestra raccolta stats.

**Trappola / follow-up**: Blocchi sempre le stats?

### Q175 [P1] Quando un indice e' utile?

**Risposta orale**: Quando riduce accessi rispetto al full scan considerando selettivita', clustering, predicate e costo manutenzione DML.

**Trappola / follow-up**: Perche' un indice puo' peggiorare INSERT?

### Q176 [P1] Perche' un full table scan non e' sempre male?

**Risposta orale**: Per grandi percentuali di righe o scansioni efficienti multiblock puo' essere la scelta corretta.

**Trappola / follow-up**: Quando diventa sospetto?

### Q177 [P1] Come scegli join method?

**Risposta orale**: Nested loop e' adatto a input piccoli con lookup efficienti; hash join a insiemi grandi; merge join a casi ordinati.

**Trappola / follow-up**: Quale errore di cardinalita' cambia la scelta?

### Q178 [P1] Come diagnostichi TEMP alta?

**Risposta orale**: Cerco sort o hash spill, SQL, PGA e parallelismo; aggiungere tempfile mitiga l'emergenza ma non sempre la causa.

**Trappola / follow-up**: Quale vista usi?

### Q179 [P1] Che cos'e' hard parse?

**Risposta orale**: Compilazione completa con costo CPU e contention; riduco literal proliferation e verifico shared pool e cursor sharing.

**Trappola / follow-up**: Perche' flush shared pool e' rischioso?

### Q180 [P1] Come leggi library cache contention?

**Risposta orale**: Correlazione con hard parse, invalidation, version count e mutex wait; cerco causa applicativa o metadata.

**Trappola / follow-up**: Aumentare shared pool basta?

### Q181 [P1] Cosa indica buffer busy waits?

**Risposta orale**: Sessioni competono su blocchi buffer; analizzo segmenti, blocchi hot e pattern concorrenti.

**Trappola / follow-up**: Come distingui da I/O?

### Q182 [P1] Cosa indica db file sequential read?

**Risposta orale**: Tipicamente single-block I/O, spesso index lookup; valuto latenza storage e volume generato dal piano SQL.

**Trappola / follow-up**: Sequential significa scansione sequenziale?

### Q183 [P1] Cosa indica db file scattered read?

**Risposta orale**: Tipicamente multiblock read associata a scansioni; valuto piano, latenza e opportunita' di ridurre letture.

**Trappola / follow-up**: E' sempre full scan?

### Q184 [P1] Cosa indica log file sync?

**Risposta orale**: Foreground attende conferma commit da LGWR; analizzo storage redo, commit frequency e log file parallel write.

**Trappola / follow-up**: Aumenti redo log size?

### Q185 [P1] Cosa indica enq: TX row lock contention?

**Risposta orale**: Una transazione attende lock riga detenuto da un'altra; identifico blocker, SQL e transazione applicativa.

**Trappola / follow-up**: Killi subito il blocker?

### Q186 [P1] Come distingui latch e mutex contention?

**Risposta orale**: Entrambe serializzano strutture interne; mutex spesso library cache. Uso wait specifiche e causa a monte.

**Trappola / follow-up**: Quale workaround temporaneo proponi?

### Q187 [P1] Come affronti CPU alta?

**Risposta orale**: Confermo saturazione OS, poi mappo processi, sessioni e SQL; distinguo domanda utile, parsing e runaway workload.

**Trappola / follow-up**: Perche' limitare CPU senza capire carico e' rischioso?

### Q188 [P1] Come affronti I/O alto?

**Risposta orale**: Correlazione tra iostat e wait Oracle, device, file e SQL; valuto throughput, latenza e piani.

**Trappola / follow-up**: Quale team coinvolgi?

### Q189 [P1] Come bilanci PGA e TEMP?

**Risposta orale**: PGA adeguata riduce spill ma eccesso minaccia RAM OS; dimensiono con workload e metriche, non a intuito.

**Trappola / follow-up**: Quale parametro controlli?

### Q190 [P1] Come valuti SGA?

**Risposta orale**: Controllo componenti, advisory e workload; evito tuning basato solo su hit ratio.

**Trappola / follow-up**: Quando modifichi shared pool?

### Q191 [P1] AMM, ASMM e HugePages: rapporto?

**Risposta orale**: AMM gestisce memoria totale ma non si combina bene con HugePages; ASMM con HugePages e' comune in produzione Linux.

**Trappola / follow-up**: Quale standard documenti?

### Q192 [P1] Come gestisci connection storm?

**Risposta orale**: Proteggo listener, process e pool, identifico origine e applico rate limit o fix applicativo; non alzo solo processes.

**Trappola / follow-up**: Come dimostri la sorgente?

### Q193 [P1] Come controlli sessions e processes?

**Risposta orale**: Confronto uso corrente, picco e limite, collegando pool e servizi; pianifico headroom.

**Trappola / follow-up**: Perche' sono parametri statici o dinamici?

### Q194 [P1] Come trovi blocker e waiter?

**Risposta orale**: Uso viste session e lock o script repo, identificando catena, SQL e durata prima di intervenire.

**Trappola / follow-up**: Quale prova salvi prima del kill?

### Q195 [P1] Come usi SQL Tuning Advisor?

**Risposta orale**: Come supporto per candidati selezionati e con licenza; valuto raccomandazioni e testo prima di accettare.

**Trappola / follow-up**: Accetti automaticamente un profile?

### Q196 [P0] SQL Profile, Baseline e Patch: differenze?

**Risposta orale**: Sono tre meccanismi per controllare i piani SQL senza modificare il codice applicativo, ma funzionano in modo molto diverso. **SQL Profile** corregge le stime di cardinalita' dell'optimizer: Oracle inserisce 'coefficienti correttivi' che aiutano l'optimizer a scegliere il piano giusto, ma l'optimizer resta libero di calcolare piani nuovi. Richiede licenza Tuning Pack. **SQL Plan Baseline (SPM)** controlla esattamente quali piani sono permessi: solo i piani 'accepted' possono essere usati. E' prescrittivo e molto stabile. Incluso in Enterprise Edition. **SQL Patch** applica hint specifici a un SQL_ID senza toccare il codice: utile come workaround emergenziale in Sev1 quando non puoi modificare l'applicazione. Per stabilizzare un piano noto buono la scelta migliore e' SPM Baseline.

**In produzione**: In emergenza Sev1 uso SQL Patch per workaround immediato. Per stabilita' uso SPM Baseline. SQL Profile lo uso quando le stime sono sistematicamente sbagliate.

**Trappola / follow-up**: Quale e' il piu' adatto a stabilizzare piano noto?

### Q197 [P1] Come verifichi partition pruning?

**Risposta orale**: Leggo piano e predicate per confermare partizioni selezionate; funzioni o cast possono impedirlo.

**Trappola / follow-up**: Perche' un indice globale complica manutenzione?

### Q198 [P1] Quando usi parallel query?

**Risposta orale**: Per workload analitici controllati con risorse adeguate; evito che saturi OLTP.

**Trappola / follow-up**: Come limiti parallelismo?

### Q199 [P1] Cosa sono RAC gc waits?

**Risposta orale**: Riflettono trasferimenti global cache tra istanze; cerco blocchi hot, affinità servizi e SQL, non colpevolizzo subito la rete.

**Trappola / follow-up**: Quando un service placement aiuta?

### Q200 [P1] Come validi before e after?

**Risposta orale**: Mantengo stessa finestra comparabile, metriche DB e OS, piano SQL e impatto business; una modifica senza misura non e' tuning.

**Trappola / follow-up**: Cosa fai se migliora media ma peggiora p95?

### Q201 [P1] Come produci un AWR report utile?

**Risposta orale**: Scelgo snapshot che coprono problema e baseline, leggo DB Time, load profile, top waits e SQL, poi verifico ipotesi.

**Trappola / follow-up**: Perche' una giornata intera diluisce il segnale?

### Q202 [P1] Come comunichi un incidente performance?

**Risposta orale**: Dichiaro impatto, evidenza dominante, mitigazione, rischio, prossimo checkpoint e proprietario della root cause.

**Trappola / follow-up**: Perche' separare workaround e fix definitivo?

## Troubleshooting L2/L3 e incident response
### Scheda di capitolo

**Cosa ripassare**: primi cinque minuti, alert log, ADRCI, escalation,
mitigazione reversibile, rollback e chiusura con evidenze.

**Verifiche da ricordare**:

```bash
adrci exec="show homes"
adrci exec="show alert -tail 100"
```

**Leggi nel repo**:
[Triage incidenti Oracle](../../01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md).

### Q203 [P1] Come imposti i primi cinque minuti di un Sev1?

**Risposta orale**: Definisco impatto, timeline e scope, raccolgo evidenze non distruttive, attivo comunicazione e scelgo mitigazione reversibile.

**Trappola / follow-up**: Perche' non iniziare da un restart?

### Q204 [P1] Come usi alert log durante incidente?

**Risposta orale**: Cerco prima errore e catena temporale, poi trace correlati; distinguo causa primaria da errori secondari.

**Trappola / follow-up**: Quale timestamp condividi nel bridge?

### Q205 [P1] Come usi ADRCI?

**Risposta orale**: Individuo ADR home, mostro alert, filtro messaggi e preparo package per escalation senza navigare path a memoria.

**Trappola / follow-up**: Quando fai IPS package?

### Q206 [P1] Come gestisci ORA-00257?

**Risposta orale**: Verifico destinazione, FRA e Data Guard; ripristino spazio preservando redo quando possibile e tratto DELETE FORCE come ultima scelta autorizzata.

**Verifica utile**: `v$recovery_file_dest`, `v$recovery_area_usage`, `v$archive_dest_status` e deletion policy RMAN.

**Trappola / follow-up**: Cosa fai se standby e' giu'?

### Q207 [P1] Come gestisci ORA-19809 o ORA-19815?

**Risposta orale**: Misuro limite, usato e reclaimable; libero solo file eleggibili o aumento quota con storage reale disponibile.

**Trappola / follow-up**: Quota FRA e spazio filesystem sono la stessa cosa?

### Q208 [P1] Come gestisci ORA-01653?

**Risposta orale**: Identifico tablespace, segmento e crescita; aggiungo o estendo datafile con guardrail e poi correggo capacity planning.

**Trappola / follow-up**: AUTOEXTEND e' gia' attivo?

### Q209 [P1] Come gestisci ORA-01652?

**Risposta orale**: Identifico TEMP, SQL e consumo per sessione; mitigo spazio se necessario e correggo query, PGA o parallelismo.

**Trappola / follow-up**: Perche' non basta aggiungere tempfile?

### Q210 [P1] Come gestisci ORA-01555?

**Risposta orale**: Correlazione durata query, undo retention, undo space e tasso DML; valuto tuning query e dimensionamento UNDO.

**Trappola / follow-up**: Imposti retention enorme?

### Q211 [P1] Come gestisci ORA-00060?

**Risposta orale**: Oracle sceglie una vittima e produce trace; analizzo ordine lock applicativo e SQL per eliminare root cause.

**Trappola / follow-up**: Perche' kill manuale non e' la soluzione?

### Q212 [P1] Come gestisci sessioni bloccate?

**Risposta orale**: Identifico blocker chain, impatto e transazione; prima di kill salvo evidenze e ottengo autorizzazione secondo runbook.

**Trappola / follow-up**: Come scegli tra kill session e disconnect?

### Q213 [P1] Come gestisci ORA-12514?

**Risposta orale**: Listener vivo ma service non noto: controllo lsnrctl services, stato DB, service e registrazione dinamica.

**Trappola / follow-up**: Quando usi alter system register?

### Q214 [P1] Come gestisci ORA-12541?

**Risposta orale**: Nessun listener raggiungibile: controllo processo, porta, host, firewall e configurazione client/server.

**Trappola / follow-up**: tnsping basta?

### Q215 [P1] Come gestisci ORA-01034?

**Risposta orale**: Verifico ORACLE_SID, PMON, stato istanza e alert log; startup solo dopo aver capito perche' e' giu'.

**Trappola / follow-up**: Come distingui ambiente errato da crash?

### Q216 [P1] Come tratti ORA-00600?

**Risposta orale**: E' errore interno: raccolgo alert, trace, incident package, versione e contesto; applico workaround solo documentato o indicato da Oracle.

**Trappola / follow-up**: Apri SR con quale severita'?

### Q217 [P1] Come tratti ORA-07445?

**Risposta orale**: Raccolgo stack, trace, processo e operazione; cerco correlazione e coinvolgo supporto Oracle per crash interni.

**Trappola / follow-up**: Riavvii alla cieca?

### Q218 [P1] Come gestisci un datafile offline inatteso?

**Risposta orale**: Identifico file, tablespace, errore I/O e stato; ripristino storage o uso RMAN restore/recover secondo criticita'.

**Trappola / follow-up**: Puoi metterlo online senza recovery?

### Q219 [P1] Come tratti destinazione archivelog MANDATORY guasta?

**Risposta orale**: Verifico LOG_ARCHIVE_DEST e impatto; ripristino destinazione o applico cambio autorizzato preservando protezione richiesta.

**Trappola / follow-up**: Disabiliti subito la destinazione?

### Q220 [P1] Come tratti backup fallito per disco pieno?

**Risposta orale**: Valuto storage, FRA, piece e retention; libero file eleggibili o uso storage alternativo e rilancio con validazione.

**Trappola / follow-up**: Cancellare file con rm e' accettabile?

### Q221 [P1] Come tratti invalid objects dopo patch?

**Risposta orale**: Controllo registry, datapatch log e DBA_OBJECTS; ricompilo dove previsto e apro escalation se componente resta invalido.

**Trappola / follow-up**: utlrp risolve sempre?

### Q222 [P1] Come tratti job Scheduler bloccato?

**Risposta orale**: Leggo stato, run history, sessione e dipendenze; evito rerun duplicati senza idempotenza applicativa.

**Trappola / follow-up**: Come gestisci finestra batch?

### Q223 [P1] Come tratti una session storm?

**Risposta orale**: Identifico servizio e sorgente, proteggo process limit e pool, mitigo lato applicazione o rete e misuro recupero.

**Trappola / follow-up**: Alzare sessions basta?

### Q224 [P1] Come correli latenza storage OS e DB?

**Risposta orale**: Uso iostat e wait event sulla stessa finestra, mappo file e device, coinvolgo storage con evidenze.

**Trappola / follow-up**: Come distingui throughput da latency?

### Q225 [P1] Come gestisci filesystem con inode esauriti?

**Risposta orale**: Uso df -i e find controllato, pulisco file corretti con tool supportati e introduco monitoraggio inode.

**Trappola / follow-up**: Perche' df -h puo' sembrare sano?

### Q226 [P2] Cosa includi in una escalation Oracle SR?

**Risposta orale**: Versione, impatto, timeline, riproducibilita', error stack, alert, trace, IPS package, modifiche recenti ed evidenze.

**Trappola / follow-up**: Perche' serve un testcase se possibile?

### Q227 [P2] Come definisci rollback operativo?

**Risposta orale**: Stabilisco trigger e percorso prima del change, con ownership, checkpoint, test di ritorno e comunicazione.

**Trappola / follow-up**: Quando smetti di tentare fix?

### Q228 [P2] Come chiudi un incidente?

**Risposta orale**: Valido servizio, rischio residuo e monitoraggio, salvo evidenze, assegno root cause e azioni preventive con owner e data.

**Trappola / follow-up**: Workaround e problem record sono distinti?

## RAC, ASM e Data Guard
### Scheda di capitolo

**Cosa ripassare**: Clusterware, service, ASM redundancy, Cache Fusion,
redo transport, redo apply, Broker, FSFO, gap e reinstate.

**Verifiche da ricordare**:

```bash
srvctl status database -d RACDB
crsctl stat res -t
dgmgrl /@RACDB
```

**Leggi nel repo**:
[Alta affidabilita e RAC](../../02_core_dba/04_high_availability_and_rac/README.md)
e [Observer FSFO](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4B_FSFO_OBSERVER.md).

### Q229 [P1] RAC e Data Guard risolvono lo stesso problema?

**Risposta orale**: No, sono complementari. RAC protegge dalla perdita di un nodo o di un'istanza: piu' istanze accedono allo stesso storage condiviso, se un nodo cade gli altri servono i client. Ma se perdi lo storage condiviso — la SAN, il diskgroup ASM — RAC non ti salva. Data Guard protegge dalla perdita dell'intero sito o del database: mantiene una copia fisica su storage separato, anche remoto, sincronizzata tramite redo. In un'architettura MAA (Maximum Availability Architecture) usi entrambi: RAC per HA locale, Data Guard per DR e zero/near-zero data loss. La combinazione RAC + Data Guard e' lo standard enterprise.

**In produzione**: La domanda chiave e': "da cosa ti proteggi?". Nodo down = RAC. Sito down/storage corrotto = Data Guard. Errore logico = nessuno dei due, serve RMAN/Flashback.

**Trappola / follow-up**: Quale protegge da perdita storage condiviso?

### Q230 [P1] Che cos'e' ASM?

**Risposta orale**: ASM (Automatic Storage Management) e' il volume manager e filesystem di Oracle progettato per gestire lo storage del database. Organizza i dischi in diskgroup, distribuisce automaticamente gli extent tra i dischi per bilanciare I/O (striping) e puo' fornire mirroring (ridondanza). Non e' un filesystem generico: non ci metti file applicativi, solo file Oracle (datafile, redo, controlfile, SPFILE, FRA). I comandi principali sono `asmcmd` per navigare e `ALTER DISKGROUP` per operazioni. Si gestisce tramite l'istanza ASM che gira sotto Grid Infrastructure. In RAC, ASM e' condiviso tra tutti i nodi.

**In produzione**: Verifico spazio con `v$asm_diskgroup` (TOTAL_MB, FREE_MB, USABLE_FILE_MB). USABLE_FILE_MB tiene conto della ridondanza ed e' il valore reale da monitorare.

**Trappola / follow-up**: E' un filesystem generico?

### Q231 [P1] External, normal e high redundancy ASM: differenze?

**Risposta orale**: External redundancy non fa mirroring: un solo extent per blocco. La resilienza e' delegata allo storage sottostante (SAN, RAID). Normal redundancy mantiene 2 copie degli extent su failure group diversi: tollera la perdita di un failure group. High redundancy mantiene 3 copie: tollera la perdita di 2 failure group. Con SAN gia' ridondata, external e' la scelta piu' comune per evitare doppio mirroring (ASM + SAN). Con storage locale o non ridondato, uso normal o high. La scelta si fa alla creazione del diskgroup e non si cambia facilmente.

**In produzione**: Con SAN enterprise ridondato uso external per DATA e RECO. Con storage locale nel lab uso normal. Monitoro `v$asm_disk` per stato di ogni disco.

**Trappola / follow-up**: Quale scegli con SAN ridondata?

### Q232 [P2] Che cos'e' Allocation Unit ASM?

**Risposta orale**: E' unita' base di allocazione; influenza layout e operazioni ma non si cambia casualmente su sistemi esistenti.

**Trappola / follow-up**: Quando la scegli?

### Q233 [P2] Come funziona rebalance ASM?

**Risposta orale**: Redistribuisce extent dopo variazioni dischi; POWER controlla aggressivita' e impatto sul workload.

**Trappola / follow-up**: Metti POWER massimo in picco?

### Q234 [P2] Cosa sono OCR e voting disk?

**Risposta orale**: OCR conserva configurazione cluster; voting supporta membership e quorum. Sono critici per Clusterware.

**Trappola / follow-up**: Come li verifichi?

### Q235 [P2] Che ruolo ha Clusterware?

**Risposta orale**: Avvia, monitora e orchestra risorse cluster secondo dipendenze e policy; uso tool supportati per operare.

**Trappola / follow-up**: Perche' non avviare manualmente tutto?

### Q236 [P2] SRVCTL e CRSCTL: differenze?

**Risposta orale**: SRVCTL gestisce risorse Oracle ad alto livello; CRSCTL diagnostica e gestisce Clusterware e risorse con maggiore cautela.

**Trappola / follow-up**: Quale usi per un database?

### Q237 [P1] SCAN, VIP, listener e service: relazione?

**Risposta orale**: SCAN (Single Client Access Name) e' un unico hostname DNS che risolve a 1-3 IP: il client si connette a SCAN senza conoscere i nodi individuali. VIP (Virtual IP) e' un IP assegnato a ogni nodo che migra su un altro nodo in caso di failure, permettendo al client di ricevere un errore rapido invece di un timeout TCP. Il SCAN listener ascolta sulle SCAN VIP e instrada le connessioni verso il listener locale del nodo appropriato in base al servizio richiesto. Il service e' il contratto applicativo: definisce quale workload gira su quale istanza (preferred/available) e gestisce failover e draining. In un colloquio dico: "il client conosce solo SCAN e service, non i nodi".

**In produzione**: Uso un service per ogni applicazione/workload. Mai connettere direttamente al SID o al VIP di un nodo specifico.

**Trappola / follow-up**: Perche' il service e' il contratto applicativo?

### Q238 [P1] Che cos'e' Cache Fusion?

**Risposta orale**: Cache Fusion e' il meccanismo che permette alle istanze RAC di condividere blocchi dati tramite l'interconnect privato ad alta velocita'. Quando un'istanza ha bisogno di un blocco modificato da un'altra, il Global Cache Service (GCS) coordina il trasferimento diretto memoria-a-memoria via interconnect, senza passare dal disco. I wait event `gc buffer busy`, `gc cr request`, `gc current request` indicano trasferimenti tra istanze. Se questi wait sono alti, non colpevolizzo subito la rete: prima verifico se ci sono hot block, SQL inefficienti o service mal distribuiti che causano contesa cross-instance.

**In produzione**: Monitoro interconnect con `v$cluster_interconnects` e correlo con `gv$system_event` per le wait gc. La latenza dell'interconnect deve essere sub-millisecondo.

**Trappola / follow-up**: Quali wait indicano blocchi hot?

### Q239 [P2] Come analizzi RAC gc waits?

**Risposta orale**: Correlazione SQL, oggetti, istanze, service placement e interconnect; evito di attribuire tutto alla rete.

**Trappola / follow-up**: Quando partizionare workload?

### Q240 [P2] Come gestisci node eviction?

**Risposta orale**: Raccolgo Clusterware, OS e interconnect evidence, stabilizzo servizio sugli altri nodi e analizzo causa quorum o heartbeat.

**Trappola / follow-up**: Riavvii il nodo immediatamente?

### Q241 [P2] Come progetti service failover?

**Risposta orale**: Definisco preferred e available instance, policy, draining e test client; il service separa workload dall'istanza.

**Trappola / follow-up**: Come provi il failover applicativo?

### Q242 [P2] TAF e Application Continuity: differenze?

**Risposta orale**: TAF copre alcuni failover sessione; Application Continuity mira a replay trasparente con driver e servizi compatibili.

**Trappola / follow-up**: Basta configurare il DB?

### Q243 [P1] Che cos'e' una physical standby?

**Risposta orale**: Una physical standby e' una copia block-for-block del primary mantenuta sincronizzata applicando redo. Il primary genera redo, lo spedisce via rete (tramite LNS) allo standby dove RFS lo riceve e MRP lo applica ai datafile. Il risultato e' un database identico al primary dal punto di vista fisico. Puo' essere aperto in READ ONLY per query (Active Data Guard, richiede licenza) oppure rimanere in MOUNT. Lo switchover inverte i ruoli senza perdita dati; il failover promuove lo standby in emergenza. Una physical standby NON protegge da errori logici: un `DROP TABLE` sul primary viene replicato sullo standby.

**In produzione**: Uso lo standby per offload backup (RMAN sullo standby), query di reportistica (ADG) e come target DR. Verifico lag con `v$dataguard_stats` quotidianamente.

**Trappola / follow-up**: Protegge da DROP TABLE?

### Q244 [P1] SYNC e ASYNC redo transport: trade-off?

**Risposta orale**: Con ASYNC il primary scrive redo e conferma il commit immediatamente; il redo viene spedito allo standby in parallelo. Vantaggio: zero impatto sulla latenza commit. Svantaggio: in caso di failover si possono perdere le transazioni non ancora arrivate allo standby. Con SYNC il primary aspetta la conferma dallo standby prima di confermare il commit. Vantaggio: zero data loss (se AFFIRM). Svantaggio: ogni commit paga la latenza di rete andata e ritorno. FASTSYNC (19c) e' un compromesso: trasporto sincrono ma senza attendere la scrittura fisica su disco dello standby (NOAFFIRM). La scelta dipende dall'RPO concordato con il business e dalla latenza di rete.

**In produzione**: Misuro RTT di rete prima di scegliere SYNC. Con RTT > 5-10ms su WAN, valuto FASTSYNC o ASYNC. Configuro via Broker con `EDIT DATABASE SET PROPERTY LogXptMode`.

**Trappola / follow-up**: Come colleghi scelta a RPO?

### Q245 [P1] Perche' servono standby redo log?

**Risposta orale**: Gli standby redo log (SRL) sullo standby ricevono il redo dal primary in tempo reale. Senza SRL, il redo viene scritto negli archivelog e MRP deve aspettare che l'archivelog sia completo prima di applicarlo — questo introduce lag. Con SRL, il real-time apply puo' leggere il redo appena arriva, riducendo l'apply lag quasi a zero. Inoltre gli SRL sono necessari per il switchover: quando lo standby diventa primary, gli SRL diventano i suoi online redo log temporanei. La regola Oracle e': crea SRL anche sul primary (n+1 gruppi per thread, dove n e' il numero di online redo log group per thread), stessa dimensione degli online redo log.

**In produzione**: Verifico SRL con `SELECT GROUP#, THREAD#, BYTES/1024/1024 MB FROM v$standby_log`. Se mancano, li creo prima di configurare Broker.

**Trappola / follow-up**: Quanti ne crei per thread?

### Q246 [P1] LNS, RFS e MRP: ruoli?

**Risposta orale**: LNS (Log Network Server) e' il processo sul primary che legge il redo log buffer o gli online redo log e li spedisce allo standby via rete. RFS (Remote File Server) e' il processo sullo standby che riceve il redo da LNS e lo scrive negli standby redo log o negli archivelog. MRP0 (Managed Recovery Process) e' il processo sullo standby che applica il redo ai datafile — e' il cuore del recovery continuo. Per diagnosticare problemi uso: `v$archive_dest_status` sul primary per controllare LNS; `v$managed_standby` sullo standby per controllare RFS e MRP; `v$dataguard_stats` per transport lag e apply lag.

**In produzione**: Se transport lag cresce, il problema e' tra LNS e RFS (rete, destinazione). Se apply lag cresce ma transport lag e' zero, il problema e' MRP (I/O standby, carico ADG).

**Trappola / follow-up**: Dove cerchi lag transport e apply?

### Q247 [P1] A cosa serve Data Guard Broker?

**Risposta orale**: Il Broker (DGMGRL) e' il pannello di controllo centralizzato di Data Guard. Invece di gestire parametri `LOG_ARCHIVE_DEST_n` manualmente su ogni istanza, il Broker mantiene una configurazione coerente e offre comandi semplificati per switchover, failover, validazione e monitoraggio. Il processo DMON gira su ogni istanza e coordina la configurazione. I comandi chiave sono: `SHOW CONFIGURATION` per stato generale; `VALIDATE DATABASE <name>` per verificare readiness switchover; `SWITCHOVER TO <standby>` per role transition; `FAILOVER TO <standby>` per emergenza. Prerequisito: `DG_BROKER_START=TRUE` e file Broker in ASM condiviso in ambiente RAC.

**In produzione**: Uso sempre Broker in produzione. Non modifico mai `LOG_ARCHIVE_DEST_n` a mano se Broker e' attivo — il Broker ha il controllo esclusivo.

**Trappola / follow-up**: Quali comandi usi prima di switchover?

### Q248 [P1] Switchover e failover: differenze?

**Risposta orale**: Lo switchover e' una role transition pianificata: il primary fa flush di tutti i redo pendenti verso lo standby, poi si converte in standby, e lo standby si promuove a primary. Zero data loss, reversibile, tipicamente ~30 secondi con Broker. Lo uso per manutenzione programmata, patching standby-first o DR drill. Il failover e' una promozione emergenziale: il primary e' down o irraggiungibile, lo standby viene promosso unilateralmente. Possibile perdita dati secondo il protection mode (in ASYNC si perdono le transazioni non ancora trasportate). Dopo failover il vecchio primary richiede reinstate (se Flashback Database era attivo) o rebuild completo. Il failover e' una decisione formale con owner applicativo.

**In produzione**: Prima di ogni switchover eseguo `VALIDATE DATABASE <standby>` e verifico lag. Per failover dichiaro RPO osservato al management.

**Trappola / follow-up**: Quando fai reinstate?

### Q249 [P1] Perche' Flashback aiuta reinstate?

**Risposta orale**: Dopo un failover, il vecchio primary ha diverged dalla nuova timeline del nuovo primary. Per reinserirlo come standby senza ricostruirlo da zero, Oracle usa Flashback Database per riportarlo a un punto coerente prima della divergenza, poi lo converte in standby e inizia ad applicare i redo del nuovo primary. Senza Flashback Database abilitato, l'unica opzione e' il rebuild completo con RMAN Duplicate. Per questo abilito Flashback Database su tutti i membri Data Guard. Verifica: `SELECT FLASHBACK_ON FROM v$database`. Broker: `REINSTATE DATABASE <old_primary>`.

**In produzione**: Abilito Flashback Database su primary e standby. Dimensiono `DB_FLASHBACK_RETENTION_TARGET` e verifico FRA sufficientemente grande per i flashback log.

**Trappola / follow-up**: E' requisito assoluto per ogni Data Guard?

### Q250 [P1] Come colmi un archive gap?

**Risposta orale**: Un gap si verifica quando lo standby non ha ricevuto uno o piu' archivelog dal primary — tipicamente dopo interruzione rete o restart. Prima verifico il gap con `SELECT thread#, low_sequence#, high_sequence# FROM v$archive_gap` sullo standby e `v$archive_dest_status` sul primary. Nella maggior parte dei casi, FAL (Fetch Archive Log) recupera automaticamente i log mancanti quando la connettivita' riprende. Se FAL non risolve, copio manualmente gli archivelog e li registro con `ALTER DATABASE REGISTER PHYSICAL LOGFILE '<path>'`. Se gli archivelog originali sono persi (es. cancellati dalla FRA), uso `RECOVER STANDBY DATABASE FROM SERVICE` in 19c o `BACKUP INCREMENTAL FROM SCN` come fallback. Solo in ultima istanza ricostruisco lo standby.

**In produzione**: `v$archive_gap` va interrogato sullo standby, non sul primary. Dopo la risoluzione verifico che MRP avanzi e che lag torni a zero.

**Verifica utile**: `v$archive_gap` sullo standby e `v$archive_dest_status` sul primary.

**Trappola / follow-up**: Dove interroghi v$archive_gap?

### Q251 [P2] Come gestisci FRA primary piena con standby in lag?

**Risposta orale**: Preservo redo, aumento capacita' o backup su storage alternativo; DELETE FORCE e' ultima scelta autorizzata con piano di riallineamento.

**Verifica utile**: Prima preserva redo; `DELETE FORCE` e' solo l'ultima scelta autorizzata.

**Trappola / follow-up**: Cosa succede al ritorno rete?

### Q252 [P2] Come riallinei standby senza redo originali?

**Risposta orale**: Fermo MRP e uso RECOVER STANDBY DATABASE FROM SERVICE sullo standby 19c; incremental FROM SCN e' fallback.

**Trappola / follow-up**: Quando fai rebuild completo?

### Q253 [P1] MaxPerformance, MaxAvailability e MaxProtection: differenze pratiche?

**Risposta orale**: Sono i tre protection mode di Data Guard, determinano il trade-off tra performance e protezione dati. **MaxPerformance** (default): redo spedito ASYNC, commit immediato, possibile perdita di secondi di dati in caso di failover. Impatto zero sul primary. **MaxAvailability**: redo spedito SYNC, zero data loss quando lo standby e' raggiungibile; se lo standby cade, il primary continua in modalita' degradata (equivalente MaxPerformance). **MaxProtection**: zero data loss assoluto — se lo standby non puo' confermare la ricezione del redo, il primary si BLOCCA. Non si passa direttamente da MaxPerformance a MaxProtection: serve il passaggio intermedio a MaxAvailability. Via Broker: `EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY`. La scelta dipende dall'RPO concordato con il business e dalla latenza di rete.

**In produzione**: La maggior parte degli ambienti usa MaxAvailability con FASTSYNC come buon compromesso. MaxProtection solo con almeno 2 standby.

**Trappola / follow-up**: Puoi passare direttamente da MaxPerformance a MaxProtection?

### Q254 [P1] Cosa succede con NOLOGGING sul primary?

**Risposta orale**: Le operazioni NOLOGGING (Direct Path Load, CTAS con NOLOGGING, `ALTER TABLE NOLOGGING`) non generano redo completo — scrivono un marker 'invalidation redo' nel redo stream. Lo standby riceve il marker e marca i blocchi come 'logically corrupt': una query su quei blocchi restituira' `ORA-01578` e `ORA-26040`. Per individuare il problema: `v$nonlogged_block` sullo standby lista i blocchi non protetti. Per risolvere: `RECOVER STANDBY DATABASE FROM SERVICE <primary>` o backup incrementale e applicazione. La prevenzione: `ALTER DATABASE FORCE LOGGING` sul primary che forza il logging completo indipendentemente dalla clausola NOLOGGING sugli oggetti. E' un prerequisito obbligatorio per Data Guard in produzione.

**In produzione**: `FORCE LOGGING` deve essere ON sempre. Lo verifico con `SELECT FORCE_LOGGING FROM v$database`. Lo imposto come parametro obbligatorio nel setup Data Guard.

**Trappola / follow-up**: Come trovi i blocchi corrotti?

### Q255 [P1] Active Data Guard: cos'e' e quando lo usi?

**Risposta orale**: Active Data Guard (ADG) permette di aprire lo standby in READ ONLY mentre MRP continua ad applicare redo in real-time. Lo stato e' `READ ONLY WITH APPLY`. Senza ADG lo standby resta in MOUNT. Use case: offload query di reportistica e validazione dati. Richiede licenza ADG separata (non inclusa in EE base). Attivazione: cancello apply, eseguo `ALTER DATABASE OPEN READ ONLY` e riavvio con `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION`. In 19c non uso la clausola storica `USING CURRENT LOGFILE`. Un DBA deve conoscere il licensing: in un colloquio cito sempre che ADG richiede licenza aggiuntiva.

**In produzione**: Uso ADG per backup sullo standby (riduco finestra backup sul primary) e per reportistica non critica. Attento al carico sullo standby che puo' rallentare MRP.

**Trappola / follow-up**: E' incluso nella licenza Enterprise Edition base?

### Q256 [P1] Snapshot standby: quando e come?

**Risposta orale**: Lo snapshot standby converte temporaneamente uno standby fisico in un database aperto READ WRITE per test, UAT o validazione prima di un deploy. L'MRP viene fermato e un punto di ripristino Flashback viene creato automaticamente. Posso fare qualsiasi modifica (DML, DDL) e poi riconvertire a physical standby: Oracle usa Flashback Database per annullare tutte le modifiche e ricomincia ad applicare redo dal primary. Requisito: Flashback Database abilitato. Via Broker: `CONVERT DATABASE <name> TO SNAPSHOT STANDBY; ... test ... CONVERT DATABASE <name> TO PHYSICAL STANDBY`. Attenzione: durante il periodo snapshot, i redo dal primary si accumulano ma NON vengono applicati — il lag cresce.

**In produzione**: Lo uso per validare patch o deploy prima del rilascio in produzione. Durata limitata per contenere il lag.

**Trappola / follow-up**: Cosa succede al redo durante snapshot?

### Q257 [P1] Far Sync: cos'e' e quando serve?

**Risposta orale**: Far Sync e' un'istanza Oracle leggera (non contiene datafile) che funge da relay per il redo transport. Si posiziona geograficamente vicino al primary per ricevere redo in SYNC (zero data loss, bassa latenza) e poi lo inoltra ASYNC allo standby remoto su WAN. Questo permette zero data loss senza pagare la latenza WAN sul commit del primary. Architettura: Primary -> (SYNC) -> Far Sync (vicino) -> (ASYNC) -> Standby (remoto). Requisito: licenza Active Data Guard. Non ha datafile, non serve per query. E' gestito dal Broker come membro della configurazione.

**In produzione**: Valuto Far Sync quando la latenza verso lo standby DR e' troppo alta per SYNC diretto ma l'RPO richiede zero data loss.

**Trappola / follow-up**: Contiene datafile?

### Q258 [P1] Come verifichi la readiness dello standby per switchover?

**Risposta orale**: Prima di ogni switchover eseguo la checklist: 1) `DGMGRL> SHOW CONFIGURATION` deve restituire SUCCESS; 2) `DGMGRL> VALIDATE DATABASE <standby>` deve dire 'Ready for Switchover: Yes' e mostrare tutti i check verdi; 3) verifico transport lag e apply lag vicini a zero; 4) verifico che non ci siano gap redo; 5) controllo che SRL esistano su entrambi i membri; 6) verifico connettivita' TNS bidirezionale; 7) notifico gli stakeholder applicativi. Solo dopo tutti i check eseguo `SWITCHOVER TO <standby>`. Dopo lo switchover: verifico `SHOW CONFIGURATION`, testo connessioni applicative, verifico che il vecchio primary sia in `PHYSICAL STANDBY` e che MRP sia attivo.

**In produzione**: Lo switchover e' una procedura con Change Request. Non lo faccio senza validazione e comunicazione preventiva.

**Trappola / follow-up**: Cosa fai se VALIDATE dice 'Not Ready'?

---

### Q259 [P1] Come verifichi interconnect RAC e cosa fai se degrada?

**Risposta orale**: L'interconnect e' il backbone di RAC: tutti i trasferimenti Cache Fusion e la comunicazione Clusterware passano da li'. Lo verifico con `SELECT name, ip_address, is_public FROM v$cluster_interconnects` e verifico che sia la rete privata dedicata (non la pubblica). Monitoro latenza e throughput con `oifcfg getif`. Per diagnosticare degradazione: guardo wait event `gc cr request`, `gc current request`, `gc buffer busy` in AWR e ASH. Se le latenze gc superano 1-2ms, indago rete, switch, configurazione MTU (consiglio jumbo frames 9000). Uso `AWR global report` per comparare i nodi. Se un nodo genera troppi trasferimenti, verifico se i service sono mal distribuiti o se ci sono hot block.

**In produzione**: Interconnect deve essere rete dedicata, separata dal traffico applicativo. Configuro jumbo frames e monitoro con tool OS come `ping -s 8972`.

**Trappola / follow-up**: Basta aumentare la banda?

### Q260 [P1] Grid Infrastructure stack: come parte e come diagnostichi?

**Risposta orale**: La sequenza di avvio GI e': 1) OHASD (Oracle High Availability Services Daemon) parte per primo tramite init/systemd; 2) OHASD avvia i sotto-processi: CSSD (Cluster Synchronization Services, heartbeat e membership), CRSD (Cluster Ready Services, gestione risorse); 3) CRSD avvia le risorse registrate: ASM, listener, database, servizi. Per diagnosticare: `crsctl stat res -t` per stato risorse; `crsctl check cluster` per stato nodi; log in `$GRID_HOME/log/<hostname>/` — `alertHOSTNAME.log` per CRS, `cssd/ocssd.log` per membership, `crsd/crsd.log` per risorse. Se un nodo non joina il cluster, guardo CSSD log per split-brain detection o voting disk issues.

**In produzione**: I log GI sono la prima fonte di verita' per qualsiasi problema cluster. `crsctl stat res -t` e' il comando che uso 10 volte al giorno.

**Trappola / follow-up**: Come diagnostichi un nodo che non joina?

### Q261 [P1] Rolling patching in RAC: come funziona?

**Risposta orale**: Il rolling patching permette di applicare patch Oracle a un nodo RAC alla volta, senza downtime del database. La procedura e': 1) verifico che la patch sia 'rolling applicable' (non tutte lo sono — alcune richiedono downtime completo); 2) fermo le istanze sul nodo1 con `srvctl stop instance`; 3) applico la patch con OPatch sul nodo1; 4) riavvio le istanze sul nodo1; 5) ripeto per il nodo2. Durante il patching il database e' accessibile tramite le istanze attive sugli altri nodi. Per patch GI uso `opatchauto` che orchestra fermata e riavvio del GI stack. Le patch RU (Release Update) trimestrali di Oracle sono generalmente rolling applicable.

**In produzione**: Applico prima sullo standby Data Guard, poi rolling sul RAC primary. Sempre in finestra di manutenzione anche se rolling.

**Trappola / follow-up**: Tutte le patch sono rolling?

### Q262 [P1] Come aggiungi/rimuovi dischi ad ASM?

**Risposta orale**: Per aggiungere dischi: 1) presento i nuovi LUN/dischi all'OS; 2) configuro ownership e permessi (oracle:oinstall, o con ASMLib/udev rules); 3) `ALTER DISKGROUP DATA ADD DISK '/dev/sdd1', '/dev/sde1'`. ASM avvia automaticamente il rebalance per distribuire i dati sui nuovi dischi. Per rimuovere: `ALTER DISKGROUP DATA DROP DISK disk_name`. Il rebalance si monitora con `v$asm_operation` (est_minutes mostra il tempo stimato). Il `POWER` del rebalance (1-1024) controlla la velocita': valori alti accelerano ma impattano l'I/O applicativo. In produzione uso `POWER 4` o meno durante le ore di punta.

**In produzione**: Verifico sempre `v$asm_disk` per stato dei dischi e `v$asm_diskgroup` per spazio. Mai rimuovere dischi se lo spazio rimanente non e' sufficiente.

**Trappola / follow-up**: Come controlli il rebalance?

---

### Q263 [P0] Come leggi un AWR report sezione per sezione?

**Risposta orale**: Non leggo l'AWR dall'inizio alla fine — vado diritto alle sezioni critiche: 1) **Load Profile**: controllo logical reads, physical reads, redo size e parse count. Se logical reads esplodono rispetto alla baseline, un piano e' degrato. 2) **Top 10 Foreground Events**: e' il riassunto dell'incidente. 'db file sequential read' = I/O random (indici mancanti?), 'log file sync' = commit lenti, 'enq: TX' = lock applicativi, 'gc buffer busy' = contesa RAC. 3) **SQL ordered by Elapsed Time/CPU/Gets**: qui trovo i colpevoli — SQL_ID con il maggior consumo. 4) **Instance Efficiency**: buffer hit ratio (deve essere >98%), library cache hit ratio. 5) **Tablespace I/O**: quale tablespace e' sotto stress. Confronto sempre con un AWR di periodo buono usando `awrddrpt.sql`.

**In produzione**: Il compare period report (`awrddrpt.sql`) e' lo strumento piu' potente per isolare regressioni post-deploy.

**Trappola / follow-up**: Quale sezione guardi per prima?

### Q264 [P1] SQL Monitor: quando e come lo usi?

**Risposta orale**: SQL Monitor cattura automaticamente le query che durano piu' di 5 secondi, usano parallelismo, o sono marcate con hint `/*+ MONITOR */`. Mostra il piano di esecuzione in tempo reale con metriche per ogni step: righe prodotte, wait, I/O, tempo CPU. E' superiore a DISPLAY_CURSOR perche' mostra lo stato live della query durante l'esecuzione. Lo uso per: diagnosi di query long-running in esecuzione, verificare dove la query sta spendendo tempo, identificare parallelismo sub-ottimale. Comandi: `SELECT * FROM v$sql_monitor WHERE status = 'EXECUTING'`; per il report dettagliato: `SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(sql_id => '<sql_id>', type => 'HTML') FROM dual`. In Enterprise Manager e' accessibile visualmente.

**In produzione**: E' il primo strumento che uso per query in esecuzione troppo lunghe. Richiede licenza Tuning Pack.

**Trappola / follow-up**: Qual e' la soglia di cattura automatica?

### Q265 [P1] Come dimensioni SGA e PGA in produzione?

**Risposta orale**: Il metodo evidence-based parte dal carico reale. Per SGA: uso `MEMORY_TARGET` o preferibilmente gestione separata con `SGA_TARGET` e `PGA_AGGREGATE_TARGET`. SGA si dimensiona in base a: buffer cache hit ratio (target >98%), shared pool free memory (non deve essere quasi zero), redo log buffer. Verifico con AWR advisory sections: 'Buffer Pool Advisory', 'PGA Memory Advisory', 'SGA Target Advisory'. Questi advisory mostrano il beneficio stimato per ogni incremento di memoria. Per PGA: guardo 'PGA Memory Advisory' e `v$pga_target_advice`. Se vedo molti multi-pass workarea executions (sort/hash join che spillano su disco), aumento PGA. Regola pratica iniziale: 75-80% della RAM a Oracle (SGA + PGA), con SGA 60-70% di quella quota.

**In produzione**: Non dimensiono alla cieca — uso gli advisory dell'AWR per decisioni basate su evidenze. In container, attenzione ai limiti cgroup.

**Trappola / follow-up**: Perche' non dai tutta la RAM alla SGA?

### Q266 [P1] Optimizer hints: quando li usi e quando no?

**Risposta orale**: Gli hint sono direttive che forzano l'optimizer a usare un comportamento specifico: join method, access path, parallelismo. Li uso SOLO come workaround temporaneo quando non posso modificare il codice applicativo e il piano e' urgentemente sbagliato. Non li uso come pratica standard perche': 1) l'optimizer ha piu' informazioni di me sulle statistiche future; 2) un hint che funziona oggi puo' essere disastroso dopo un cambio di volumi; 3) sono fragili — un cambio di alias o di struttura della query li invalida silenziosamente. Alternative migliori: SQL Plan Baseline per stabilizzare, SQL Profile per correggere stime, raccolta statistiche per dare all'optimizer dati corretti. Se devo usare un hint in emergenza, lo implemento via SQL Patch (`DBMS_SQLDIAG.CREATE_SQL_PATCH`) cosi' non tocco il codice applicativo.

**In produzione**: Hint solo come workaround in Sev1 con SQL Patch. Mai nel codice applicativo permanente.

**Trappola / follow-up**: Perche' sono pericolosi a lungo termine?

### Q267 [P1] Come gestisci un patching Oracle in produzione?

**Risposta orale**: Il patching Oracle segue un flusso strutturato: 1) scarico la Release Update (RU) trimestrale da My Oracle Support; 2) leggo il README e il Known Issues; 3) applico prima in ambiente di test; 4) applico sullo standby Data Guard (primo punto di validazione senza rischio); 5) faccio switchover per promuovere lo standby patchato a primary; 6) patcho il vecchio primary (ora standby); 7) verifico applicazioni. Se RAC, uso rolling patching nodo per nodo. Pre-patching: backup RMAN completo, snapshot VM se possibile. Strumenti: `opatch apply` per patch singole, `opatchauto` per GI stack, `datapatch` per SQL changes post-patch. Verifico con `opatch lsinventory`.

**In produzione**: La sequenza standby-first + switchover e' lo standard MAA. Riduce il rischio e il downtime quasi a zero.

**Trappola / follow-up**: Cos'e' datapatch e quando serve?

### Q268 [P1] FORCE LOGGING, ARCHIVELOG e FLASHBACK: perche' tutti e tre?

**Risposta orale**: Sono tre meccanismi indipendenti che proteggono livelli diversi. **ARCHIVELOG mode**: conserva i redo log archiviati necessari per point-in-time recovery e per alimentare Data Guard. Senza ARCHIVELOG non puoi fare recovery a un punto specifico. **FORCE LOGGING**: forza Oracle a generare redo completo anche per operazioni NOLOGGING (Direct Path, CTAS). Senza FORCE LOGGING, lo standby Data Guard avra' blocchi corrotti. **FLASHBACK DATABASE**: permette di riportare il database a un punto precedente nel tempo senza restore, usando i flashback log nella FRA. Necessario per reinstate dopo failover DG. I tre sono complementari: ARCHIVELOG per PITR, FORCE LOGGING per protezione standby, FLASHBACK per agilita' operativa. Tutti e tre devono essere ON in un ambiente enterprise con Data Guard.

**In produzione**: Verifico i tre con: `SELECT LOG_MODE, FORCE_LOGGING, FLASHBACK_ON FROM v$database`. Se uno manca, lo correggo prima di procedere.

**Trappola / follow-up**: Quale protegge da operazioni NOLOGGING?

## Security, multitenant e change management
### Scheda di capitolo

**Cosa ripassare**: container corrente, common/local user, least privilege,
`SYSBACKUP`, wallet TDE, auditing e change con rollback.

**Verifiche da ricordare**:

```sql
SHOW CON_NAME;
SELECT name, open_mode FROM v$pdbs;
SELECT * FROM v$encryption_wallet;
```

**Leggi nel repo**:
[Amministrazione e security](../../02_core_dba/01_administration_and_security/README.md).

### Q253 [P2] Come amministri CDB e PDB senza confonderti?

**Risposta orale**: Identifico container corrente, scope del comando e impatto su root o PDB; valido sempre con show con_name e v$pdbs.

**Verifica utile**: `SHOW CON_NAME;` prima di ogni comando con impatto multitenant.

**Trappola / follow-up**: Perche' un comando dalla root puo' avere blast radius maggiore?

### Q254 [P2] Common user e local user: differenze?

**Risposta orale**: Il common user opera secondo privilegi comuni nei container previsti; il local user vive nella singola PDB.

**Trappola / follow-up**: Quando usi C##?

### Q255 [P2] Come applichi least privilege?

**Risposta orale**: Concedo ruoli e privilegi minimi, separo account nominali e tecnici, rivedo grant e traccio eccezioni.

**Trappola / follow-up**: Perche' evitare DBA agli account applicativi?

### Q256 [P2] Perche' usare SYSBACKUP?

**Risposta orale**: Separa operazioni backup e recovery da SYSDBA, migliorando least privilege e auditabilita'.

**Trappola / follow-up**: RMAN richiede sempre SYSDBA?

### Q257 [P2] Come gestisci TDE wallet?

**Risposta orale**: Proteggo keystore, backup e password, verifico stato wallet e procedure restore su tutti i siti.

**Trappola / follow-up**: Cosa succede al restore senza chiavi?

### Q258 [P2] Come imposti auditing utile?

**Risposta orale**: Traccio eventi rilevanti senza generare rumore ingestibile, proteggo trail e definisco retention e review.

**Trappola / follow-up**: Come eviti filesystem pieno per audit?

### Q259 [P2] Come gestisci credenziali nelle command line?

**Risposta orale**: Uso wallet, vault o input protetto; password in argomenti possono comparire in process list, history e log.

**Trappola / follow-up**: Come configuri automazione non interattiva?

### Q260 [P2] Cosa deve avere un change di produzione?

**Risposta orale**: Scope, rischio, evidenze before, piano esecuzione, test, rollback, owner e comunicazione; chiudo solo dopo validazione osservabile.

**Trappola / follow-up**: Quale trigger avvia rollback?

## Drill Severity 1

Per ogni drill rispondi come se fossi nel bridge di produzione. Non saltare la
comunicazione del rischio residuo.

### Drill 01 - FRA primary piena e standby irraggiungibile

**Scenario**: L'applicazione non scrive, alert log con ORA-00257, FRA al 100%, standby remoto non raggiungibile da 12 ore.

**Risposta attesa**:
1. Dichiara Sev1, congela modifiche non essenziali e raccogli timeline.
2. Controlla alert log, spazio fisico, v$recovery_file_dest, v$recovery_area_usage, v$archive_dest_status e deletion policy RMAN.
3. Registra thread e sequence non ancora spedite o applicate.
4. Prima scelta: aumenta temporaneamente FRA solo se esiste storage reale oppure esegui backup controllato degli archivelog verso storage alternativo.
5. Libera solo file eleggibili. Non usare rm e non cancellare alla cieca per eta'.
6. Solo se il business autorizza degrado DR e non esiste alternativa, usa DELETE FORCE per il minimo intervallo necessario: Oracle documenta che ignora la deletion policy.
7. Al ritorno rete: se i log esistono, copiali e registrali sullo standby. Se sono persi, ferma MRP e usa RECOVER STANDBY DATABASE FROM SERVICE primary_service; incremental FROM SCN resta il fallback.

**Trappola**: La risposta debole e' applicare un purge cieco per eta' senza verificare Data Guard: sblocca oggi e puo' rompere il riallineamento domani.

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md`

### Drill 02 - Backup notturno fallito e finestra chiusa

**Scenario**: Il full RMAN e' fallito alle 03:00 per storage pieno; il batch diurno e' iniziato.

**Risposta attesa**:
1. Misura RPO corrente e individua ultimo backup valido.
2. Controlla log RMAN, storage, FRA, piece e catalog.
3. Evita purge indiscriminato; libera solo file eleggibili o devia su storage alternativo.
4. Esegui backup prioritario coerente con RPO e pianifica restore validate.

**Trappola**: Rilanciare lo stesso job senza rimuovere la causa prolunga l'esposizione e puo' saturare ancora lo storage.

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md`

### Drill 03 - DROP TABLE con PURGE in produzione

**Scenario**: Una tabella applicativa e' stata eliminata con PURGE; recycle bin vuoto.

**Risposta attesa**:
1. Identifica oggetto, dipendenze e punto temporale prima dell'errore.
2. Valuta Flashback solo se applicabile; altrimenti usa RMAN RECOVER TABLE con auxiliary destination.
3. Importa con REMAP TABLE verso nome sicuro, valida dati e concorda cutover applicativo.

**Trappola**: Data Guard replica anche l'errore logico: failover allo standby non recupera la tabella.

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_FASE5_RMAN_BACKUP.md`

### Drill 04 - Perdita di un datafile applicativo

**Scenario**: Un datafile non SYSTEM risulta assente dopo errore storage.

**Risposta attesa**:
1. Identifica file, tablespace e causa OS.
2. Isola il file se necessario, usa RESTORE DATAFILE e RECOVER DATAFILE.
3. Riporta online, valida alert log e workload applicativo.

**Trappola**: Mettere online il file senza recovery non risolve l'incoerenza SCN.

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Drill 05 - Perdita controlfile e SPFILE

**Scenario**: Il server riparte ma non esistono copie leggibili di controlfile e SPFILE.

**Risposta attesa**:
1. Recupera DBID dal registro operativo o catalog.
2. Avvia NOMOUNT con bootstrap minimo e ripristina SPFILE da autobackup.
3. Riavvia NOMOUNT, ripristina controlfile, monta e completa restore o recover.

**Trappola**: Il DBID deve essere conservato fuori dal database per il disaster recovery.

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMANDI_ENTERPRISE.md`

### Drill 06 - ORA-01555 durante report critico

**Scenario**: Un report lungo fallisce con snapshot too old durante alto volume DML.

**Risposta attesa**:
1. Misura durata query, spazio UNDO, retention effettiva e tasso di modifica.
2. Valuta tuning query e scheduling prima di aumentare indiscriminatamente UNDO_RETENTION.
3. Dimensiona UNDO e valida con workload comparabile.

**Trappola**: Aumentare il parametro senza spazio sufficiente non garantisce retention.

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_REDO_UNDO_CRASH_RECOVERY.md`

### Drill 07 - ORA-01652 TEMP esaurita

**Scenario**: ETL notturno satura TEMP e blocca altre query.

**Risposta attesa**:
1. Identifica sessione, SQL, tempseg usage, PGA e parallelismo.
2. Aggiungi tempfile come mitigazione solo se storage disponibile.
3. Correggi piano SQL, spill o parallelismo e misura il batch successivo.

**Trappola**: Aggiungere spazio senza trovare la query lascia invariato il rischio operativo.

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_06_TABLESPACE_PIENO.md`

### Drill 08 - SQL improvvisamente lento

**Scenario**: Una query prima rapida passa da secondi a minuti dopo raccolta statistiche.

**Risposta attesa**:
1. Confronta SQL_ID, child cursor, plan hash e statistiche before/after.
2. Verifica cardinalita', istogrammi e bind sensitivity.
3. Mitiga con meccanismo controllato e correggi root cause con test.

**Trappola**: Un indice aggiunto in emergenza puo' peggiorare DML e non correggere la stima errata.

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_23_SQL_TUNING_CASI_ENTERPRISE.md`

### Drill 09 - CPU database al 100%

**Scenario**: Il server e' saturo e l'applicazione degrada.

**Risposta attesa**:
1. Conferma CPU OS e finestra temporale con top, ps e vmstat.
2. Mappa processi a sessioni e Top SQL per CPU.
3. Mitiga runaway workload e prepara tuning misurabile.

**Trappola**: Aumentare CPU o killare processi senza mappatura puo' nascondere una regressione applicativa.

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_07_CPU_ALTA.md`

### Drill 10 - Catena di lock applicativi

**Scenario**: Molte sessioni attendono una transazione aperta da oltre venti minuti.

**Risposta attesa**:
1. Trova blocker chain, SQL, utente, modulo e durata.
2. Salva evidenze e concorda kill o rollback con owner applicativo.
3. Analizza pattern transazionale per prevenzione.

**Trappola**: Il blocker puo' essere inattivo lato CPU ma trattenere lock critici.

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_04_LOCK_SESSIONI_BLOCCATE.md`

### Drill 11 - Listener vivo ma servizio assente

**Scenario**: Il client riceve ORA-12514 mentre il processo listener e' attivo.

**Risposta attesa**:
1. Controlla lsnrctl services, stato DB e servizi.
2. Verifica LOCAL_LISTENER o REMOTE_LISTENER e registrazione dinamica.
3. Usa alter system register solo dopo aver verificato configurazione.

**Trappola**: tnsping verifica reachability dell'alias, non login applicativo completo.

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_26_LISTENER_SCAN_SERVICES_RAC.md`

### Drill 12 - RAC node eviction

**Scenario**: Un nodo viene espulso dal cluster durante picco; servizi migrano sugli altri nodi.

**Risposta attesa**:
1. Stabilizza servizio e verifica capacity residua.
2. Raccogli Clusterware, OS, voting, interconnect e timeline.
3. Analizza quorum, heartbeat e storage prima del reintegro.

**Trappola**: Riavviare subito il nodo puo' distruggere evidenze e ripetere l'eviction.

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_10_START_STOP_RAC.md`

### Drill 13 - ASM diskgroup quasi pieno

**Scenario**: Il diskgroup DATA supera il 95% durante crescita batch.

**Risposta attesa**:
1. Verifica usable file MB, redundancy, file grandi e rebalance.
2. Aggiungi capacita' o riduci crescita con change controllato.
3. Valuta impatto di rebalance POWER sul workload.

**Trappola**: Free MB e usable file MB non sono equivalenti con ridondanza ASM.

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md`

### Drill 14 - Archive gap dopo manutenzione rete

**Scenario**: La rete torna disponibile ma MRP non avanza.

**Risposta attesa**:
1. Interroga v$archive_gap sullo standby e v$archive_dest_status sul primary.
2. Lascia lavorare FAL oppure copia e registra i log mancanti.
3. Se i redo non esistono piu', usa roll-forward FROM SERVICE o incremental FROM SCN.

**Trappola**: v$archive_gap va interrogata sul target standby.

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md`

### Drill 15 - Rollback patching dopo datapatch problematico

**Scenario**: Dopo RU applicata, smoke test fallisce e registry SQL mostra errori.

**Risposta attesa**:
1. Ferma il rollout e applica i trigger di rollback definiti nel change.
2. Conserva inventory, datapatch log, alert log e stato servizi.
3. Segui README patch per rollback binari e SQL, quindi valida registry e workload.

**Trappola**: Rollback binari e rollback SQL sono passi distinti e dipendono dalla patch.

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_29_PATCHING_ORACLE_RAC_DATAGUARD.md`

---

## Linux & OS Troubleshooting (P1)

Questa sezione risponde direttamente al requisito: *"Troubleshooting avanzato e ottimizzazione dei DB operanti su sistemi operativi Linux."*

### Q269 [P1] Il database muore improvvisamente, niente nell'alert log. Cosa guardi su Linux?

**Risposta orale**: Se l'alert log di Oracle tace, il problema è del sistema operativo. Guardo immediatamente `/var/log/messages` (o `dmesg -T` / `journalctl`) per cercare l'intervento dell'**OOM Killer** (Out Of Memory). Se la RAM e la Swap del server finiscono, il kernel Linux "spara" ai processi più grandi per non morire, uccidendo tipicamente `PMON` o `smon` e causando il crash silenzioso del database.

**In produzione**: Controllo chi ha saturato la RAM (un altro processo, uno script di backup o una PGA impazzita di Oracle).

**Trappola / follow-up**: Perché l'OOM Killer uccide PMON e non un processo minore? Perché colpisce chi alloca più risorse o la memoria condivisa.

### Q270 [P1] Quali comandi Linux usi per fare un primo triage delle performance?

**Risposta orale**: Inizio con `top` o `htop` per identificare l'utilizzo CPU e se c'è un processo zombie. Uso `free -m` per vedere la memoria disponibile e lo stato dello swapping. Uso `iostat -x 1` o `sar -d` per monitorare la latenza e l'utilizzazione dei dischi (cercando un `%util` al 100% o alti `await`). Infine uso `vmstat 1` per vedere colli di bottiglia su run queue della CPU, paging o block I/O.

**In produzione**: Se vedo molta IO wait (wa% in top), il problema quasi certamente si rifletterà su AWR come `db file sequential read` o `log file sync`.

**Trappola / follow-up**: Cosa indica un alto valore di Load Average?

### Q271 [P1] Che cosa sono le HugePages e perché sono vitali per Oracle?

**Risposta orale**: Di default Linux gestisce la memoria in blocchi (pages) da 4KB. Per un database con 100GB di SGA, questo significa gestire milioni di piccoli puntatori nella Page Table (consumando tantissima CPU in TLB miss). Le **HugePages** pre-allocano blocchi grandi (tipicamente 2MB o 1GB). Benefici: la SGA non può mai andare in swap, il consumo CPU del sistema operativo crolla, e l'accesso alla memoria diventa molto più veloce. 

**In produzione**: Uso lo script Oracle `hugepages_settings.sh` per calcolare il valore esatto da mettere in `sysctl.conf` (`vm.nr_hugepages`).

**Trappola / follow-up**: Si usano le Transparent Huge Pages (THP)? NO. Vanno sempre disabilitate (`never`) per Oracle, pena crolli di performance improvvisi.

### Q272 [P1] Come fai troubleshooting di un processo Oracle bloccato "appeso" su Linux?

**Risposta orale**: Se un processo server Oracle (es. `LOCAL=NO`) è in "hang" e non riesco a killarlo da dentro SQL*Plus, scendo a livello Linux. Trovo l'SPID del processo (dal `v$process` o con `ps -ef`). Uso **`strace -p <PID>`** per tracciare le system call del processo in tempo reale: questo mi dice esattamente su quale chiamata il processo è bloccato (es. un read() in rete o un read() su disco o un lock semaphore).

**In produzione**: Se lo devo "uccidere" brutalmente, uso `kill -9 <PID>` solo se so esattamente cosa fa, perché killare un processo background critico (LGWR, PMON) spegne l'intera istanza.

**Trappola / follow-up**: Cosa succede se killi PMON? Il database va in crash immediato (Instance Abort).

---

## Mock Interview 1 - Core, Linux e RMAN (45 minuti)

1. Spiega istanza, database, SGA, PGA e percorso di un COMMIT.
2. Descrivi un health check Linux e Oracle nei primi cinque minuti.
3. Disegna una strategia RMAN coerente con RPO e RTO.
4. Recupera verbalmente SPFILE, controlfile, datafile e singola tabella.
5. Gestisci il Drill 01 FRA primary piena con standby irraggiungibile.
6. Chiudi con prevenzione, monitoring e comunicazione business.

## Mock Interview 2 - Performance e alta affidabilita' (60 minuti)

1. Diagnostica un SQL improvvisamente lento usando evidence before/after.
2. Spiega wait event, DB Time, AWR, ASH e limiti di licenza.
3. Confronta RAC e Data Guard e descrivi una role transition.
4. Risolvi archive gap con log disponibili e poi con redo persi.
5. Gestisci RAC eviction e ASM diskgroup quasi pieno.
6. Proponi patching con rollback e smoke test misurabili.

## Validazione finale

- Sai rispondere senza appunti a tutte le schede `P0` in 60-90 secondi.
- Sai eseguire verbalmente i 15 drill separando evidenza, mitigazione e root cause.
- Sai spiegare perche' `DELETE FORCE` e' una scelta Sev1 autorizzata e non una routine.
- Sai descrivere `RECOVER TABLE` e `RECOVER STANDBY DATABASE FROM SERVICE` con prerequisiti e limiti.
- Hai completato almeno una mock interview cronometrata.

## Troubleshooting rapido

- Risposta troppo vaga: apri il file indicato e annota un comando e una validazione.
- Risposta solo teorica: aggiungi impatto business, prima evidenza e rollback.
- Risposta troppo lunga: esponi prima la decisione, poi tre evidenze e il rischio residuo.
- Comando non ricordato: usa il cheat sheet RMAN e ripeti il drill correlato.

## Fonti Oracle ufficiali

- [RMAN table recovery](https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-recovering-tables-partitions.html)
- [RMAN CONFIGURE deletion policy](https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/CONFIGURE.html)
- [RMAN DELETE e FORCE](https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/DELETE.html)
- [RMAN con Data Guard](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/using-RMAN-in-oracle-data-guard-configurations.html)
- [ORA-00257](https://docs.oracle.com/en/error-help/db/ora-00257/)
