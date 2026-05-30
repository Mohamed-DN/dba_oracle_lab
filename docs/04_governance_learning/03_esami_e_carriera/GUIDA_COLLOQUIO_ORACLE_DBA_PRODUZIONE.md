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

### Q001 [P0] Qual e' la differenza tra database e istanza?

**Risposta **: Il database e' l'insieme dei file persistenti; l'istanza e' memoria SGA piu' processi Oracle che aprono e gestiscono quei file.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Come lo spieghi durante un riavvio della sola istanza?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q002 [P0] Come distingui SGA e PGA?

**Risposta **: La SGA e' condivisa dall'istanza; la PGA appartiene al processo server o background e contiene aree private come sort e session state.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Quale rischio introduci aumentando PGA senza guardare la RAM OS?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q003 [P0] A cosa serve il buffer cache?

**Risposta **: Riduce I/O fisico mantenendo copie dei blocchi letti; una cache hit non prova da sola che il sistema sia sano.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Perche' un hit ratio alto puo' convivere con SQL lento?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q004 [P0] Cosa contiene lo shared pool?

**Risposta **: Library cache e dictionary cache supportano parsing, metadata e riuso dei cursori; pressione o frammentazione aumentano hard parse e mutex contention.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Come distingui sintomo da causa nello shared pool?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q005 [P0] A cosa serve il redo log buffer?

**Risposta **: Accoglie redo change vectors prima che LGWR li persista negli online redo log secondo gli eventi di flush.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Perche' non sostituisce gli online redo log?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q006 [P0] Quando scrive LGWR?

**Risposta **: Scrive al commit e in altri eventi di flush; il commit attende la persistenza del redo necessario, non la scrittura immediata dei datafile.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Quale wait event cerchi se i commit sono lenti?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q007 [P0] Quando scrive DBWR?

**Risposta **: DBWR scarica dirty buffers verso i datafile quando serve spazio o durante checkpoint; non e' sul percorso sincrono normale del commit.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Perche' COMMIT non aspetta DBWR?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q008 [P0] Cosa fa CKPT?

**Risposta **: CKPT coordina i checkpoint e aggiorna header dei datafile e controlfile con le informazioni di avanzamento necessarie al recovery.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Che relazione ha con MTTR?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q009 [P0] Cosa fa SMON?

**Risposta **: SMON esegue attivita' di sistema come instance recovery e pulizie interne; non e' il processo da usare come risposta generica a ogni problema.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Cosa succede dopo un instance crash?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q010 [P0] Cosa fa PMON?

**Risposta **: PMON ripulisce risorse di processi falliti e collabora con la registrazione dinamica dei servizi.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Che cosa controlli se un service non compare nel listener?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q011 [P0] A cosa servono ARCn?

**Risposta **: In ARCHIVELOG mode archiviano gli online redo log pieni nelle destinazioni configurate; se non riescono, il database puo' fermare le transazioni.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Quale errore segnala una destinazione satura?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q012 [P0] Perche' il controlfile e' critico?

**Risposta **: Descrive struttura fisica, checkpoint e metadata necessari a mount e recovery; va multiplexato e incluso nella strategia RMAN.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Come riparti se perdi tutte le copie?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q013 [P0] Che cosa contiene un datafile?

**Risposta **: Contiene blocchi persistenti dei tablespace; il recovery ricostruisce le modifiche mancanti applicando redo.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Quando puoi recuperare un singolo datafile online?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q014 [P0] Come dimensioni gli online redo log?

**Risposta **: Cerco switch regolari compatibili con workload e recovery; log troppo piccoli aumentano switch e checkpoint pressure, troppo grandi allungano alcuni recovery.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Quale vista usi per misurare gli switch?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q015 [P0] Perche' servono gli archivelog?

**Risposta **: Conservano la storia redo necessaria a media recovery, PITR, backup online e Data Guard.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Cosa perdi in NOARCHIVELOG?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q016 [P0] Qual e' il ruolo dell'UNDO?

**Risposta **: Supporta read consistency, rollback e alcune operazioni flashback; va dimensionato rispetto a durata query e tasso di modifica.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Come colleghi ORA-01555 a UNDO?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q017 [P0] Come funziona TEMP?

**Risposta **: TEMP ospita segmenti temporanei per sort, hash, operazioni parallele e spill della PGA; non e' un deposito permanente.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Perche' aggiungere tempfile non risolve sempre la causa?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q018 [P0] Perche' SYSTEM e SYSAUX sono speciali?

**Risposta **: Contengono componenti critici del data dictionary e repository; richiedono guardrail piu' severi nelle operazioni di recovery.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Puoi usare RECOVER TABLE per oggetti in SYSTEM?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q019 [P0] Quali sono gli stati NOMOUNT, MOUNT e OPEN?

**Risposta **: NOMOUNT avvia istanza e legge parametri, MOUNT apre il controlfile, OPEN apre datafile e redo rendendo disponibile il database.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: In quale stato ripristini un controlfile?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q020 [P0] Che cos'e' un checkpoint?

**Risposta **: E' un punto logico di avanzamento che limita il redo necessario per instance recovery coordinando persistenza dei dirty buffers.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Aumentare la frequenza ha sempre solo vantaggi?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q021 [P0] Che cos'e' lo SCN?

**Risposta **: E' l'orologio logico Oracle usato per consistenza e recovery; collega blocchi, redo e punti temporali.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Quando preferisci UNTIL SCN a UNTIL TIME?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q022 [P0] Cosa accade internamente al COMMIT?

**Risposta **: Oracle rende durevole il redo tramite LGWR e conferma il commit; i blocchi dati possono essere scritti dopo da DBWR.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Perche' il redo e' write-ahead logging?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q023 [P0] Che cos'e' il crash recovery?

**Risposta **: Dopo perdita dell'istanza Oracle applica redo per roll-forward e undo per rollback delle transazioni non committate.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: In cosa differisce dal media recovery?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q024 [P0] Che cos'e' il media recovery?

**Risposta **: Ripara perdita o arretramento di file usando backup e redo; puo' riguardare database, tablespace, datafile o blocchi.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Quando serve RMAN?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q025 [P0] Come garantisce Oracle la read consistency?

**Risposta **: Una query vede una versione coerente usando SCN e undo per ricostruire versioni precedenti dei blocchi modificati.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Perche' una query lunga puo' fallire con ORA-01555?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q026 [P0] Che differenza c'e' tra lock e latch o mutex?

**Risposta **: I lock proteggono coerenza transazionale; latch e mutex serializzano strutture interne con granularita' e durata molto piu' ridotte.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Perche' non tratti una mutex contention come un lock applicativo?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q027 [P0] Come distingui connection, session e process?

**Risposta **: La connessione e' il canale client, la sessione e' il contesto logico nel DB, il process e' il worker OS o Oracle associato.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Una connection pool puo' avere piu' sessioni?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q028 [P0] Dedicated server o shared server?

**Risposta **: Dedicated assegna un processo server per connessione; shared server riduce processi per workload adatto ma aggiunge complessita'.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Quale scegli per batch pesanti?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q029 [P0] Come funziona la registrazione dinamica al listener?

**Risposta **: PMON o LREG pubblica servizi al listener usando parametri locali e remoti; il listener non contiene i dati del database.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Come forzi una nuova registrazione?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q030 [P0] SERVICE_NAME e SID sono intercambiabili?

**Risposta **: No: il service rappresenta un endpoint logico e puo' seguire workload e ruoli; il SID identifica una specifica istanza.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Perche' RAC usa servizi?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q031 [P0] SPFILE e PFILE: cosa cambia?

**Risposta **: SPFILE e' binario e persistente, gestibile con ALTER SYSTEM; PFILE e' testo utile per bootstrap o recovery.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Come ricrei lo SPFILE da PFILE?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q032 [P0] Cosa significa SCOPE MEMORY, SPFILE o BOTH?

**Risposta **: Determina applicazione immediata e persistenza al riavvio; alcuni parametri richiedono restart e non accettano MEMORY.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Come eviti modifiche non persistenti?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q033 [P0] Dove cerchi alert log e trace?

**Risposta **: Uso ADR e ADRCI per localizzare home, alert e trace; raccolgo evidenze prima di cambiare parametri.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Perche' non basta guardare l'ultimo errore?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q034 [P0] Che cos'e' la FRA?

**Risposta **: E' un'area gestita per file di recovery come archivelog, flashback log e backup; quota logica e spazio fisico vanno verificati entrambi.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Perche' puo' bloccarsi il database?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q035 [P0] Perche' ARCHIVELOG e' obbligatorio in produzione?

**Risposta **: Permette backup online e recovery oltre l'ultimo full, oltre a Data Guard; richiede monitoraggio delle destinazioni.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Come verifichi la modalita'?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q036 [P0] A cosa serve supplemental logging?

**Risposta **: Aggiunge informazioni redo necessarie in scenari di replica o mining logico; va abilitato secondo requisito, non indiscriminatamente.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Quando lo richiede GoldenGate?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q037 [P0] Come usi il recycle bin?

**Risposta **: Per DROP non PURGE puo' consentire FLASHBACK TABLE rapido; prima controllo sempre se l'oggetto e' recuperabile senza RMAN.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Quando non ti salva?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q038 [P0] Come controlli Scheduler e job?

**Risposta **: Interrogo viste DBA_SCHEDULER e log esecuzioni, distinguendo job fallito, bloccato o mai partito.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Quali evidenze raccogli prima del rerun?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q039 [P0] Perche' raccogliere statistiche dictionary e fixed objects?

**Risposta **: Il CBO usa statistiche coerenti anche per metadata e viste dinamiche; dopo cambi importanti possono influenzare performance amministrative.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Le raccogli durante picco?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q040 [P0] Bigfile e smallfile tablespace: differenza?

**Risposta **: Bigfile semplifica gestione di volumi elevati con pochi file; smallfile distribuisce in piu' datafile. La scelta dipende da storage e procedure.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: AUTOEXTEND elimina il capacity planning?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q041 [P0] Che ruolo ha il block size Oracle?

**Risposta **: Il block size definisce l'unita' I/O logica dei datafile e influenza cache, layout e workload; la scelta standard si fissa alla creazione del database.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Lo cambi per correggere una singola query lenta?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q042 [P0] Qual e' il rischio di AUTOEXTEND illimitato?

**Risposta **: Evita alcuni incidenti immediati ma puo' saturare filesystem o diskgroup condivisi; servono maxsize e alert.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Che soglie imposti?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q043 [P0] Quando metti un tablespace offline o read only?

**Risposta **: Offline isola file o abilita recovery; read only protegge dati statici e puo' semplificare backup. Valuto impatto applicativo.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: SYSTEM puo' andare offline?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q044 [P0] A cosa serve il password file?

**Risposta **: Abilita autenticazione amministrativa remota come SYSDBA o SYSBACKUP; deve essere protetto e coerente nei cluster e in Data Guard.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Perche' conta nel roll-forward FROM SERVICE?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q045 [P0] Cosa sono CDB e PDB?

**Risposta **: Il CDB ospita root, seed e PDB; separa amministrazione comune e workload pluggable con impatti su connessione e recovery.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Da dove lanci RECOVER TABLE per una PDB?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

### Q046 [P0] DBID, DB_NAME e DB_UNIQUE_NAME: differenze?

**Risposta **: DBID identifica il database per RMAN, DB_NAME la famiglia database, DB_UNIQUE_NAME distingue siti o membri Data Guard.





**Comandi e verifiche**: `SELECT instance_name, status, database_status FROM v$instance;`

**Trappola / follow-up**: Quale parametro evita ambiguita' tra primary e standby?

**Leggi nel repo**: `docs/04_governance_learning/01_fondamenti_teorici/GUIDA_ARCHITETTURA_ORACLE.md`

## Installazione, configurazione e patching

### Q047 [P0] Come prepari i prerequisiti OS prima dell'installazione?

**Risposta **: Verifico matrice Oracle, RAM, swap, filesystem, pacchetti, kernel, limiti, rete, DNS e time sync prima di lanciare installer.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Quale evidenza conservi nel change?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q048 [P0] Quali kernel parameter controlli?

**Risposta **: Controllo shared memory, semafori, file handle, porte effimere e parametri indicati dalla documentazione della release.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Perche' non copi valori da un server a caso?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q049 [P0] Perche' servono limits.conf e PAM limits?

**Risposta **: Oracle richiede limiti adeguati per file descriptor, processi e stack; verifico il valore effettivo nella sessione oracle.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Come dimostri il valore attivo?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q050 [P0] Come presenti udev, ASMLib e AFD?

**Risposta **: Sono opzioni per rendere i device persistenti e gestibili; scelgo secondo standard aziendale e versione GI, evitando nomi instabili.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Perche' /dev/sdX e' rischioso?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q051 [P0] Perche' NTP o chrony conta per Oracle?

**Risposta **: Timestamp coerenti sono essenziali per diagnosi, cluster e correlazione eventi; controllo drift e sorgenti.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Che rischio crea un salto di tempo?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q052 [P0] Perche' DNS e /etc/hosts sono critici?

**Risposta **: Hostname, VIP, SCAN e risoluzione inversa devono essere coerenti; errori qui emergono come problemi listener o cluster.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Come testi forward e reverse lookup?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q053 [P0] ORACLE_BASE, ORACLE_HOME e inventory: differenze?

**Risposta **: ORACLE_BASE organizza file amministrativi, ORACLE_HOME contiene binari per una release, inventory traccia home e patch installate.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Perche' l'inventory va protetto?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q054 [P0] Quali gruppi OS usi?

**Risposta **: Separazione oinstall, dba e gruppi privilegiati come oper, backupdba o asmadmin supporta least privilege e gestione Grid.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Concedi sempre dba a tutti?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q055 [P0] Quando usi installazione silent?

**Risposta **: Per ripetibilita', automazione e audit uso response file versionati e validati in ambiente non produttivo.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Quali segreti non committi?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q056 [P0] Come usi DBCA in modo controllato?

**Risposta **: DBCA crea o configura database con template e parametri espliciti; salvo response file e verifico output e alert log.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Quando preferisci script manuali?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q057 [P0] Come configuri listener e NETCA?

**Risposta **: Creo listener e alias coerenti con servizi, porte e standard; valido con lsnrctl e connessioni reali.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: tnsping prova il login applicativo?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q058 [P0] Cosa metti in un response file?

**Risposta **: Valori ripetibili non sensibili, inventory, home, gruppi e opzioni; i segreti entrano da vault o canale protetto.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Perche' versionarlo?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q059 [P0] RU e one-off patch: differenza?

**Risposta **: RU aggrega fix periodici e baseline supportata; one-off risolve un bug specifico e richiede verifica conflitti e compatibilita'.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Quale scegli prima?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q060 [P0] Perche' controlli la versione OPatch?

**Risposta **: Una patch puo' richiedere OPatch minimo; aggiorno il tool nell'home corretto e verifico prima dell'applicazione.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Come eviti di usare OPatch di un altro home?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q061 [P0] Come esegui conflict check?

**Risposta **: Uso prereq CheckConflictAgainstOHWithDetail e leggo README patch; conflitti richiedono merge patch o indicazioni Oracle.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Applichi comunque se il check fallisce?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q062 [P0] Cosa leggi da opatch lsinventory?

**Risposta **: Home, inventory, patch installate e dettagli utili a baseline e rollback; salvo evidenza before e after.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Perche' controlli ogni nodo RAC?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q063 [P0] Cosa salvi prima del patching?

**Risposta **: Backup RMAN valido, SPFILE, inventory, Oracle Home secondo standard, configurazioni e piano rollback testato.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Un tar dell'home sostituisce RMAN?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q064 [P0] Che ruolo ha datapatch?

**Risposta **: Allinea componenti SQL nel database ai binari patchati; va eseguito e verificato su CDB e PDB secondo README.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Quale vista controlli dopo?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q065 [P0] Come funziona un rolling patch RAC?

**Risposta **: Patching nodo per nodo mantiene servizio se patch e architettura lo consentono; dreno servizi e verifico cluster tra passi.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Ogni patch e' rolling?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q066 [P0] Come pianifichi patching con Data Guard?

**Risposta **: Valuto standby-first e role transition secondo patch README e compatibilita'; non improvviso l'ordine in produzione.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Quando fai switchover?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q067 [P0] Perche' preferire out-of-place patching?

**Risposta **: Un nuovo home riduce rollback tecnico e rende chiaro il cutover; richiede spazio, inventory e aggiornamento servizi.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Come ritorni al vecchio home?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q068 [P0] Come prepari il rollback?

**Risposta **: Definisco trigger, finestra, backup, comando rollback e ripristino home/config; il rollback e' parte del change, non una nota finale.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Chi decide il go/no-go?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q069 [P0] Come verifichi SQL patch registry?

**Risposta **: Interrogo dba_registry_sqlpatch e log datapatch per stato e errori su container interessati.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Un exit code zero basta?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q070 [P0] A cosa serve CVU?

**Risposta **: Cluster Verification Utility verifica prerequisiti e salute cluster prima o dopo installazioni e patch GI.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Lo usi solo in installazione?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q071 [P0] Come gestisci stop e start servizi?

**Risposta **: Uso strumenti supportati come srvctl e sequenza documentata; verifico dipendenze e session draining prima dello stop.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Perche' evitare kill casuali?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q072 [P0] Cosa deve contenere un patch plan?

**Risposta **: Scope, nodi, prerequisiti, backup, comandi, checkpoint, test, rollback, comunicazioni e responsabilita'.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Quale evidenza serve per audit?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q073 [P0] GI e DB home: quale ordine?

**Risposta **: Dipende da patch README e matrice; GI e DB home sono scope distinti e vanno verificati esplicitamente.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Perche' non assumere stesso RU?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

### Q074 [P0] Come validi una patch a fine finestra?

**Risposta **: Controllo inventory, registry SQL, alert log, servizi, listener, workload smoke test e monitoraggio post-change.





**Comandi e verifiche**: `opatch lsinventory`

**Trappola / follow-up**: Quando chiudi il change?

**Leggi nel repo**: `docs/02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md`

## Linux e automazione Bash

### Q075 [P0] Come distingui filesystem pieno e inode esauriti?

**Risposta **: Uso df -h e df -i: spazio byte e inode sono risorse diverse, entrambe possono bloccare scritture.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Perche' cancellare un file grande non aiuta gli inode?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q076 [P0] Come trovi cosa occupa spazio?

**Risposta **: Parto da du per directory, poi find controllato; evito scansioni costose indiscriminate durante il picco.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Come gestisci file cancellati ma ancora aperti?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q077 [P0] Come leggi dischi, partizioni e LVM?

**Risposta **: Uso lsblk, pvs, vgs e lvs per mappare device, volume group e logical volume prima di proporre resize.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Cosa verifichi prima di estendere filesystem?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q078 [P0] Quali opzioni NFS controlli per backup?

**Risposta **: Verifico mount, latenza, hard mount e opzioni certificate dallo standard; un timeout NFS puo' sembrare errore RMAN.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Come distingui rete e storage?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q079 [P0] Come usi iostat?

**Risposta **: Guardo latenza, utilization e queue per device nel tempo; un singolo snapshot non basta a diagnosticare I/O.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Quale metrica correli ai wait Oracle?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q080 [P0] Come usi vmstat?

**Risposta **: Osservo runnable queue, swap, paging, I/O e CPU steal o wait per capire la pressione sistemica.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Perche' free memory bassa non implica problema?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q081 [P0] Come leggi top e ps?

**Risposta **: Identifico processi CPU o memoria, PID e comando, poi collego processo OS a sessione Oracle prima di intervenire.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Killi un processo Oracle senza analisi?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q082 [P0] Cosa significa free -m su Linux moderno?

**Risposta **: Distinguo free, available, cache e swap; Linux usa RAM libera come cache e questo e' normale.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Quando la swap e' un segnale serio?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q083 [P0] Come verifichi HugePages?

**Risposta **: Controllo /proc/meminfo, configurazione e uso effettivo; HugePages riduce overhead per SGA ma richiede sizing coerente.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: AMM e HugePages convivono bene?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q084 [P0] Come valuti swappiness?

**Risposta **: Controllo sysctl e comportamento reale; ridurre swappiness non sostituisce capacity planning della memoria.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Imposti sempre zero?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q085 [P0] Quali ulimit controlli?

**Risposta **: Verifico nofile, nproc, stack e limiti effettivi dell'utente oracle nella sessione e nei servizi systemd.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Perche' limits.conf puo' non bastare?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q086 [P0] Come gestisci un servizio systemd?

**Risposta **: Uso systemctl status, start, stop, enable e unit file controllato; raccolgo log e dipendenze.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Quando usi restart?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q087 [P0] Come usi journalctl?

**Risposta **: Filtro per unit, boot e finestra temporale per correlare eventi OS con alert log Oracle.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Come esporti evidenze?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q088 [P0] Quando guardi dmesg?

**Risposta **: Cerco errori kernel, OOM, device reset, filesystem e network; e' utile per problemi sotto il livello Oracle.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Cosa fai se trovi I/O error?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q089 [P0] Come testi rete e DNS?

**Risposta **: Uso ss, nc, dig o getent e test applicativi; separo reachability, porta, listener e autenticazione DB.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Perche' ping non basta?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q090 [P0] Come gestisci ownership e permessi?

**Risposta **: Uso utente, gruppo e mode minimi necessari; evito chmod ricorsivi improvvisati su Oracle Home o datafile.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Perche' 777 e' inaccettabile?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q091 [P0] Come usi find in sicurezza?

**Risposta **: Prima elenco i candidati con criteri precisi, poi approvo la cancellazione; per file Oracle preferisco tool supportati.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Perche' find -delete e' rischioso?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q092 [P0] Come gestisci log rotation?

**Risposta **: Uso strumenti previsti per log OS e ADRCI per ADR; preservo evidenze incidenti e retention concordata.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Ruoti manualmente alert log durante Sev1?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q093 [P0] Come scheduli task con cron?

**Risposta **: Imposto ambiente esplicito, path assoluti, logging, exit code e lock contro sovrapposizioni.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Perche' uno script funziona a mano ma non da cron?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q094 [P0] Perche' usare set -euo pipefail?

**Risposta **: Rende visibili errori, variabili non definite e pipeline fallite; va gestito consapevolmente con cleanup e trap.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Può rompere script legacy?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q095 [P0] Come parametrizzi ORACLE_SID e ORACLE_HOME?

**Risposta **: Non dipendo dal profilo interattivo: carico ambiente controllato e valido binari e target prima delle azioni.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Come eviti di operare sul DB sbagliato?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q096 [P0] Come impedisci esecuzioni concorrenti?

**Risposta **: Uso flock o lockfile robusto con cleanup e timeout; registro PID e timestamp.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Cosa succede dopo crash dello script?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q097 [P0] Come gestisci exit code e logging?

**Risposta **: Ogni fase scrive timestamp, comando logico, esito e messaggio; propago exit code al scheduler o monitoring.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Perche' echo generico non basta?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q098 [P0] Come richiami SQLPlus da Bash?

**Risposta **: Uso here-document o file SQL controllato, whenever sqlerror exit e segreti fuori dalla command line.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Come rilevi un errore SQL?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q099 [P0] Come richiami RMAN da Bash?

**Risposta **: Uso command file e log dedicato, controllo exit code e pattern RMAN/ORA, con target validato.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Un job verde garantisce backup usabile?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q100 [P0] Come raccogli un evidence bundle?

**Risposta **: Salvo timestamp, hostname, comandi non distruttivi, alert log, metriche OS e output Oracle in directory ticketizzata.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Perche' raccogliere prima del fix?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q101 [P0] Cosa significa automazione idempotente?

**Risposta **: Rieseguire lo script porta allo stato desiderato senza duplicare o danneggiare risorse; includo pre-check e post-check.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Come testi il secondo run?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

### Q102 [P0] Come proteggi segreti negli script?

**Risposta **: Uso wallet, vault, permessi e input sicuro; non inserisco password in process list, repo o log.





**Comandi e verifiche**: `df -h; df -i; vmstat 1 5; iostat -xz 1 5`

**Trappola / follow-up**: Perche' ps puo' esporre credenziali?

**Leggi nel repo**: `docs/04_governance_learning/03_esami_e_carriera/GUIDA_ATTIVITA_LAB_RAC.md`

## RMAN, backup e business continuity

### Q103 [P0] Qual e' l'architettura minima RMAN?

**Risposta **: RMAN client orchestra operazioni sul target usando metadata nel controlfile e opzionalmente nel recovery catalog, con channel verso storage.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quando il catalog diventa importante?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q104 [P0] Full backup e incremental level 0 sono uguali?

**Risposta **: Entrambi leggono tutti i blocchi usati, ma solo level 0 e' baseline per successivi level 1.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' la differenza conta nel piano incrementale?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q105 [P0] Level 1 differential e cumulative: differenze?

**Risposta **: Differential prende blocchi cambiati dall'ultimo L0 o L1; cumulative dall'ultimo L0, con backup piu' grande ma restore piu' semplice.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quale riduce MTTR?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q106 [P0] Backupset e image copy: differenze?

**Risposta **: Backupset e' formato RMAN in piece, efficiente e comprimibile; image copy e' copia file utilizzabile in strategie switch e merge.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quando scegli image copy?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q107 [P0] Backup piece e backup set: relazione?

**Risposta **: Un backup set contiene uno o piu' piece fisici; channel, max piece size e storage influenzano layout e parallelismo.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' un piece mancante invalida il set?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q108 [P0] A cosa servono i channel?

**Risposta **: Sono sessioni server RMAN che eseguono I/O; numero e device type vanno dimensionati su CPU, rete e storage.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Più channel sono sempre meglio?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q109 [P0] Come usi FORMAT e substitution variable?

**Risposta **: Definisco nomi univoci come %U e path controllati; evito collisioni e verifico accessibilita' dello storage.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' %U e' utile?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q110 [P0] Che rapporto c'e' tra FRA e RMAN?

**Risposta **: La FRA puo' ospitare backup e archivelog gestiti; quota e reclaimability dipendono da policy e file ancora necessari.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' DELETE OBSOLETE non basta sempre?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q111 [P0] Perche' abilitare controlfile autobackup?

**Risposta **: Permette di recuperare controlfile e SPFILE anche in disaster recovery con metadata limitati.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quando serve SET DBID?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q112 [P0] Retention policy: redundancy o recovery window?

**Risposta **: Redundancy conserva copie; recovery window protegge recuperabilita' temporale. Scelgo in base a RPO, storage e compliance.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: La retention elimina automaticamente tutto?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q113 [P0] DELETE OBSOLETE e DELETE EXPIRED: differenze?

**Risposta **: Obsolete segue retention; expired rimuove metadata di file assenti dopo CROSSCHECK. Non sono sinonimi.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Expired cancella sempre il file fisico?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q114 [P0] Cosa fa CROSSCHECK?

**Risposta **: Confronta repository RMAN e disponibilita' fisica dei file aggiornando lo stato; non valida il contenuto del backup.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' serve prima della pulizia?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q115 [P0] Come configuri deletion policy con Data Guard?

**Risposta **: Uso APPLIED ON ALL STANDBY o SHIPPED secondo requisito; una policy prudente evita di cancellare redo ancora necessari.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: DELETE FORCE la rispetta?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q116 [P0] Come usi BACKUP ARCHIVELOG ALL DELETE INPUT?

**Risposta **: Backup e cancellazione input possono liberare spazio, ma devono rispettare policy e accessibilita' delle copie.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: DELETE ALL INPUT cosa cambia?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q117 [P0] RESTORE VALIDATE cosa prova?

**Risposta **: Simula lettura dei backup necessari al restore senza scrivere datafile; dimostra disponibilita' tecnica, non l'intero RTO.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Come lo scheduli?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q118 [P0] BACKUP VALIDATE cosa prova?

**Risposta **: Legge blocchi del target e rileva corruzioni senza produrre backup; posso aggiungere CHECK LOGICAL.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quale vista registra corruzioni?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q119 [P0] Come leggi LIST e REPORT?

**Risposta **: LIST mostra backup registrati; REPORT evidenzia schema, obsolete, unrecoverable o need backup secondo scopo.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quale comando usi prima di un restore?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q120 [P0] Qual e' la sequenza restore e recover database?

**Risposta **: Monto il database, ripristino file dal backup, applico redo e apro normalmente o RESETLOGS secondo completezza recovery.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quando serve RESETLOGS?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q121 [P0] RESTORE e RECOVER sono intercambiabili?

**Risposta **: No: RESTORE copia file dal backup; RECOVER applica modifiche redo fino al punto desiderato.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' servono entrambi?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q122 [P0] Come recuperi un controlfile?

**Risposta **: Avvio NOMOUNT, imposto DBID se necessario, ripristino da autobackup, monto e proseguo con recovery.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' non puoi mount senza controlfile?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q123 [P0] Come recuperi lo SPFILE?

**Risposta **: Con autobackup e DBID posso ripristinarlo da RMAN dopo startup NOMOUNT con PFILE minimo o bootstrap.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Come ricrei PFILE temporaneo?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q124 [P0] Perche' conservare DBID fuori dal database?

**Risposta **: In perdita totale aiuta RMAN a localizzare autobackup quando controlfile e catalog non sono disponibili.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Dove lo registri?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q125 [P0] Come recuperi un datafile perso?

**Risposta **: Offline se necessario, RESTORE DATAFILE, RECOVER DATAFILE e online; valuto ruolo del file e impatto.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Puoi farlo sempre a DB aperto?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q126 [P0] Come recuperi un tablespace?

**Risposta **: Isolo il tablespace, ripristino e applico redo ai suoi file, poi valido e rimetto online.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: SYSTEM segue la stessa procedura online?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q127 [P0] Come usi block media recovery?

**Risposta **: BLOCKRECOVER o RECOVER BLOCK ripara pochi blocchi corrotti riducendo impatto rispetto a restore file completo.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quando non basta?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q128 [P0] Come recuperi una tabella cancellata?

**Risposta **: Uso RECOVER TABLE con PITR, AUXILIARY DESTINATION e REMAP TABLE; RMAN crea auxiliary e usa Data Pump.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' rinomini l'oggetto recuperato?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q129 [P0] Come recuperi una tabella in una PDB?

**Risposta **: Mi collego localmente alla root e uso RECOVER TABLE ... OF PLUGGABLE DATABASE, verificando backup di root, seed e PDB.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Puoi farlo dalla PDB?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q130 [P0] RECOVER TABLE e TSPITR: differenze?

**Risposta **: RECOVER TABLE estrae oggetti via auxiliary e Data Pump; TSPITR riporta indietro un tablespace isolato.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quale ha blast radius minore?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q131 [P0] Come esegui un DB PITR?

**Risposta **: Definisco UNTIL TIME o SCN prima dell'errore, restore, recover incompleto e OPEN RESETLOGS, comunicando perdita dati prevista.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Come scegli il punto corretto?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q132 [P0] Cosa comporta OPEN RESETLOGS?

**Risposta **: Crea una nuova incarnation e nuova storia redo; richiede backup post-operazione e gestione coerente degli standby.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' il catalog deve conoscerla?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q133 [P0] Che cos'e' una incarnation RMAN?

**Risposta **: Rappresenta un ramo della storia redo dopo RESETLOGS; LIST INCARNATION e RESET DATABASE aiutano recovery su rami precedenti.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quando torni a una vecchia incarnation?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q134 [P0] Quando usi CATALOG START WITH?

**Risposta **: Quando copie o backup esistono su storage ma non sono noti al repository corrente; catalogo path verificati.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' non catalogare directory casuali?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q135 [P0] Come funziona SWITCH DATABASE TO COPY?

**Risposta **: Fa puntare il database a image copy gia' preparate, riducendo tempo di restore in strategie incrementally updated.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quale recovery resta da fare?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q136 [P0] Che cos'e' incremental merge?

**Risposta **: Aggiorna image copy con level 1 periodici per mantenere una base vicina al presente e ridurre MTTR.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Qual e' il costo storage?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q137 [P0] Come funziona DUPLICATE FROM ACTIVE DATABASE?

**Risposta **: Trasferisce blocchi dal target verso auxiliary senza backup pre-staged; richiede rete, password file e configurazione attenta.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quando preferisci duplicate da backup?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q138 [P0] Come fai DUPLICATE da backup?

**Risposta **: Preparo backup accessibili, catalogo se necessario e duplico con parametri e conversioni path coerenti.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quale vantaggio offre su rete lenta?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q139 [P0] Come crei uno standby con RMAN?

**Risposta **: Uso DUPLICATE TARGET DATABASE FOR STANDBY, parametri DB_UNIQUE_NAME, connettivita' e redo transport corretti.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' servono standby redo log?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q140 [P0] Quando usi compressione RMAN?

**Risposta **: Riduce banda o storage pagando CPU; testo algoritmo e throughput sul workload reale.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: BASIC richiede licenza extra?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q141 [P0] Come proteggi backup cifrati?

**Risposta **: Uso encryption RMAN e gestione wallet o password secondo standard; testo restore, non solo backup.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Cosa succede se perdi il wallet?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q142 [P0] Che cos'e' SBT?

**Risposta **: E' l'interfaccia RMAN verso media manager o tape; channel e librerie vendor devono essere verificati end-to-end.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Come diagnostichi errore media manager?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q143 [P0] Come registri un database nel catalog?

**Risposta **: Connetto target e catalog, eseguo REGISTER DATABASE e sincronizzo metadata, mantenendo sicurezza separata.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Registri ogni standby allo stesso modo?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q144 [P0] A cosa serve RESYNC CATALOG?

**Risposta **: Allinea metadata controlfile e catalog; in Data Guard posso configurare connect identifier per siti diversi.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' il catalog non va sul primary?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q145 [P0] Quali vantaggi offre il recovery catalog?

**Risposta **: Storico piu' lungo, script, metadata centralizzati e gestione Data Guard piu' robusta rispetto al solo controlfile.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: E' obbligatorio per ogni piccolo DB?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q146 [P0] Che cos'e' un Virtual Private Catalog?

**Risposta **: Espone un sottoinsieme del catalog a utenti delegati, supportando separazione dei compiti.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quando e' utile?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q147 [P0] Come usi RESTORE PREVIEW?

**Risposta **: Mostra backup e archivelog richiesti senza eseguire il restore; aiuta a scoprire dipendenze mancanti.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Sostituisce RESTORE VALIDATE?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q148 [P0] Quando usi SECTION SIZE?

**Risposta **: Divide grandi datafile in sezioni lavorabili in parallelo per backup o restore multisection.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Perche' non abusarne?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q149 [P0] Come usi RATE e MAXPIECESIZE?

**Risposta **: RATE limita throughput channel, MAXPIECESIZE limita dimensione piece per vincoli media manager o trasferimento.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quale impatto ha su RTO?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q150 [P0] A cosa serve backup optimization?

**Risposta **: Evita copie identiche non necessarie in comandi supportati; va compresa con retention e deletion policy.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Puo' saltare tutto senza errore?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q151 [P1] Come usi TAG e KEEP?

**Risposta **: TAG identifica famiglie di backup; KEEP protegge backup speciali fino a data o per sempre secondo compliance.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: KEEP sostituisce retention?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q152 [P1] Che differenza c'e' tra VALIDATE e CHECK LOGICAL?

**Risposta **: Validate legge blocchi; CHECK LOGICAL aggiunge controlli logici oltre alla corruzione fisica rilevabile.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quale costo introduce?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q153 [P1] Dove vedi i blocchi corrotti?

**Risposta **: Interrogo v$database_block_corruption e correlo file e blocchi con validate e alert log.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Come scegli BLOCKRECOVER?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q154 [P1] Come affronti perdita totale server?

**Risposta **: Seguo runbook: ambiente, DBID, SPFILE, controlfile, mount, catalog backup, restore, recover e apertura controllata.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Qual e' il primo prerequisito fuori sito?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q155 [P1] Come usi backup da standby Data Guard?

**Risposta **: Offload riduce carico primary; con catalog e accessibilita' corretta i backup fisici possono supportare restore sull'altro sito.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: SPFILE ha una particolarita'?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q156 [P1] Come riallinei standby con FROM SERVICE?

**Risposta **: Fermo MRP e lancio RECOVER STANDBY DATABASE FROM SERVICE primary_service sullo standby 19c, poi riattivo apply e valido lag.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quale prerequisito password file serve?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q157 [P1] Quando usi incremental FROM SCN per standby?

**Risposta **: E' fallback se il roll-forward diretto non e' praticabile: genero incremental dal primary a partire dallo SCN standby e lo applico.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quando ricostruisci da zero?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q158 [P1] Quali limiti ricordi per RECOVER TABLE?

**Risposta **: Target locale read-write e ARCHIVELOG, backup e redo continui, spazio auxiliary; non supporta oggetti SYS, SYSTEM, SYSAUX o physical standby.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Che effetto hanno alcuni named constraint con REMAP?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q159 [P1] Come provi davvero i backup?

**Risposta **: Eseguo restore validate periodici e restore drill isolati con misurazione tempi; un job backup verde non prova recuperabilita'.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quale evidenza presenti all'audit?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

### Q160 [P1] Come traduci RPO e RTO in strategia RMAN?

**Risposta **: RPO guida frequenza e redo protection; RTO guida restore path, parallelismo, copie e drill. Li misuro, non li dichiaro soltanto.





**Comandi e verifiche**: `rman target /; SHOW ALL; LIST BACKUP SUMMARY; REPORT NEED BACKUP;`

**Trappola / follow-up**: Quale compromesso discuti col business?

**Leggi nel repo**: `docs/02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md`

## Performance tuning e ottimizzazione

### Q161 [P1] Qual e' il metodo corretto per un incidente performance?

**Risposta **: Definisco finestra, impatto e baseline, raccolgo DB e OS evidence, identifico bottleneck dominante, applico una modifica misurabile e valido.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Perche' non inizi aumentando memoria?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q162 [P1] AWR, ASH e ADDM: cosa fanno?

**Risposta **: AWR conserva snapshot, ASH campiona sessioni attive, ADDM interpreta alcune evidenze; verifico licenze prima dell'uso in produzione.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Statspack quando serve?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q163 [P1] Come usi le wait class?

**Risposta **: Raggruppo tempo atteso per capire se il limite e' CPU, I/O, commit, concurrency, network o configuration.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Una wait alta e' sempre causa?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q164 [P1] Che cos'e' DB Time?

**Risposta **: Somma tempo CPU e wait foreground delle sessioni; puo' superare tempo wall-clock perche' aggrega concorrenza.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Come lo confronti tra due finestre?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q165 [P1] Come trovi Top SQL per elapsed time?

**Risposta **: Ordino statistiche SQL o AWR per elapsed e executions, distinguendo query lenta singola e carico cumulativo.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Perche' guardi anche rows processed?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q166 [P1] Come trovi Top SQL per CPU e buffer gets?

**Risposta **: Confronto CPU, gets, reads ed executions per capire costo logico e fisico; scelgo il candidato con impatto reale.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Un SQL_ID alto in gets e' sempre sbagliato?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q167 [P1] SQL_ID e child cursor: differenza?

**Risposta **: SQL_ID identifica testo normalizzato; child cursor rappresenta varianti compilate per ambiente, bind o mismatch.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Perche' controlli VERSION_COUNT?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q168 [P1] EXPLAIN PLAN e DISPLAY_CURSOR: differenze?

**Risposta **: EXPLAIN stima un piano senza esecuzione reale; DISPLAY_CURSOR mostra piano effettivo e statistiche se raccolte.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quale usi per regressione reale?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q169 [P1] Che cos'e' PLAN_HASH_VALUE?

**Risposta **: E' una firma pratica del piano utile per confronti; non sostituisce analisi di operazioni, cardinalita' e predicate.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Due piani con stesso hash sono sempre identici?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q170 [P1] Perche' le statistiche contano?

**Risposta **: Il CBO stima cardinalita' e costo usando statistiche; stale o assenti possono produrre scelte inefficienti.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Raccogli sempre con cascade?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q171 [P1] Quando servono istogrammi?

**Risposta **: Aiutano con distribuzioni skewed e predicate selettivi; troppi istogrammi possono aumentare instabilita' e child cursor.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Come decidi?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q172 [P1] Che cos'e' bind peeking?

**Risposta **: Al primo hard parse il CBO puo' usare valori bind per stimare selettivita'; workload variabile puo' produrre piano inadatto.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quale meccanismo mitiga?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q173 [P1] Che cos'e' adaptive cursor sharing?

**Risposta **: Oracle puo' creare child cursor bind-aware per gestire selettivita' diverse osservate a runtime.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Perche' aumenta VERSION_COUNT?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q174 [P1] Come riconosci stale statistics?

**Risposta **: Controllo DBA_TAB_STATISTICS e modification monitoring, correlando cambio piano e finestra raccolta stats.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Blocchi sempre le stats?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q175 [P1] Quando un indice e' utile?

**Risposta **: Quando riduce accessi rispetto al full scan considerando selettivita', clustering, predicate e costo manutenzione DML.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Perche' un indice puo' peggiorare INSERT?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q176 [P1] Perche' un full table scan non e' sempre male?

**Risposta **: Per grandi percentuali di righe o scansioni efficienti multiblock puo' essere la scelta corretta.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quando diventa sospetto?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q177 [P1] Come scegli join method?

**Risposta **: Nested loop e' adatto a input piccoli con lookup efficienti; hash join a insiemi grandi; merge join a casi ordinati.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quale errore di cardinalita' cambia la scelta?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q178 [P1] Come diagnostichi TEMP alta?

**Risposta **: Cerco sort o hash spill, SQL, PGA e parallelismo; aggiungere tempfile mitiga l'emergenza ma non sempre la causa.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quale vista usi?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q179 [P1] Che cos'e' hard parse?

**Risposta **: Compilazione completa con costo CPU e contention; riduco literal proliferation e verifico shared pool e cursor sharing.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Perche' flush shared pool e' rischioso?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q180 [P1] Come leggi library cache contention?

**Risposta **: Correlazione con hard parse, invalidation, version count e mutex wait; cerco causa applicativa o metadata.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Aumentare shared pool basta?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q181 [P1] Cosa indica buffer busy waits?

**Risposta **: Sessioni competono su blocchi buffer; analizzo segmenti, blocchi hot e pattern concorrenti.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Come distingui da I/O?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q182 [P1] Cosa indica db file sequential read?

**Risposta **: Tipicamente single-block I/O, spesso index lookup; valuto latenza storage e volume generato dal piano SQL.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Sequential significa scansione sequenziale?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q183 [P1] Cosa indica db file scattered read?

**Risposta **: Tipicamente multiblock read associata a scansioni; valuto piano, latenza e opportunita' di ridurre letture.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: E' sempre full scan?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q184 [P1] Cosa indica log file sync?

**Risposta **: Foreground attende conferma commit da LGWR; analizzo storage redo, commit frequency e log file parallel write.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Aumenti redo log size?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q185 [P1] Cosa indica enq: TX row lock contention?

**Risposta **: Una transazione attende lock riga detenuto da un'altra; identifico blocker, SQL e transazione applicativa.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Killi subito il blocker?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q186 [P1] Come distingui latch e mutex contention?

**Risposta **: Entrambe serializzano strutture interne; mutex spesso library cache. Uso wait specifiche e causa a monte.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quale workaround temporaneo proponi?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q187 [P1] Come affronti CPU alta?

**Risposta **: Confermo saturazione OS, poi mappo processi, sessioni e SQL; distinguo domanda utile, parsing e runaway workload.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Perche' limitare CPU senza capire carico e' rischioso?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q188 [P1] Come affronti I/O alto?

**Risposta **: Correlazione tra iostat e wait Oracle, device, file e SQL; valuto throughput, latenza e piani.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quale team coinvolgi?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q189 [P1] Come bilanci PGA e TEMP?

**Risposta **: PGA adeguata riduce spill ma eccesso minaccia RAM OS; dimensiono con workload e metriche, non a intuito.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quale parametro controlli?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q190 [P1] Come valuti SGA?

**Risposta **: Controllo componenti, advisory e workload; evito tuning basato solo su hit ratio.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quando modifichi shared pool?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q191 [P1] AMM, ASMM e HugePages: rapporto?

**Risposta **: AMM gestisce memoria totale ma non si combina bene con HugePages; ASMM con HugePages e' comune in produzione Linux.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quale standard documenti?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q192 [P1] Come gestisci connection storm?

**Risposta **: Proteggo listener, process e pool, identifico origine e applico rate limit o fix applicativo; non alzo solo processes.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Come dimostri la sorgente?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q193 [P1] Come controlli sessions e processes?

**Risposta **: Confronto uso corrente, picco e limite, collegando pool e servizi; pianifico headroom.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Perche' sono parametri statici o dinamici?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q194 [P1] Come trovi blocker e waiter?

**Risposta **: Uso viste session e lock o script repo, identificando catena, SQL e durata prima di intervenire.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quale prova salvi prima del kill?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q195 [P1] Come usi SQL Tuning Advisor?

**Risposta **: Come supporto per candidati selezionati e con licenza; valuto raccomandazioni e testo prima di accettare.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Accetti automaticamente un profile?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q196 [P1] SQL Profile, Baseline e Patch: differenze?

**Risposta **: Profile corregge stime, baseline governa piani accettati, SQL Patch applica hint mirati; scelgo con controllo e rollback.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quale e' il piu' adatto a stabilizzare piano noto?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q197 [P1] Come verifichi partition pruning?

**Risposta **: Leggo piano e predicate per confermare partizioni selezionate; funzioni o cast possono impedirlo.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Perche' un indice globale complica manutenzione?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q198 [P1] Quando usi parallel query?

**Risposta **: Per workload analitici controllati con risorse adeguate; evito che saturi OLTP.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Come limiti parallelismo?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q199 [P1] Cosa sono RAC gc waits?

**Risposta **: Riflettono trasferimenti global cache tra istanze; cerco blocchi hot, affinità servizi e SQL, non colpevolizzo subito la rete.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Quando un service placement aiuta?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q200 [P1] Come validi before e after?

**Risposta **: Mantengo stessa finestra comparabile, metriche DB e OS, piano SQL e impatto business; una modifica senza misura non e' tuning.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Cosa fai se migliora media ma peggiora p95?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q201 [P1] Come produci un AWR report utile?

**Risposta **: Scelgo snapshot che coprono problema e baseline, leggo DB Time, load profile, top waits e SQL, poi verifico ipotesi.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Perche' una giornata intera diluisce il segnale?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

### Q202 [P1] Come comunichi un incidente performance?

**Risposta **: Dichiaro impatto, evidenza dominante, mitigazione, rischio, prossimo checkpoint e proprietario della root cause.





**Comandi e verifiche**: `SELECT event, total_waits, time_waited FROM v$system_event ORDER BY time_waited DESC;`

**Trappola / follow-up**: Perche' separare workaround e fix definitivo?

**Leggi nel repo**: `docs/02_core_dba/03_performance_and_diagnostics/GUIDA_AWR_ASH_ADDM.md`

## Troubleshooting L2/L3 e incident response

### Q203 [P1] Come imposti i primi cinque minuti di un Sev1?

**Risposta **: Definisco impatto, timeline e scope, raccolgo evidenze non distruttive, attivo comunicazione e scelgo mitigazione reversibile.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Perche' non iniziare da un restart?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q204 [P1] Come usi alert log durante incidente?

**Risposta **: Cerco prima errore e catena temporale, poi trace correlati; distinguo causa primaria da errori secondari.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Quale timestamp condividi nel bridge?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q205 [P1] Come usi ADRCI?

**Risposta **: Individuo ADR home, mostro alert, filtro messaggi e preparo package per escalation senza navigare path a memoria.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Quando fai IPS package?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q206 [P1] Come gestisci ORA-00257?

**Risposta **: Verifico destinazione, FRA e Data Guard; ripristino spazio preservando redo quando possibile e tratto DELETE FORCE come ultima scelta autorizzata.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Cosa fai se standby e' giu'?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q207 [P1] Come gestisci ORA-19809 o ORA-19815?

**Risposta **: Misuro limite, usato e reclaimable; libero solo file eleggibili o aumento quota con storage reale disponibile.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Quota FRA e spazio filesystem sono la stessa cosa?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q208 [P1] Come gestisci ORA-01653?

**Risposta **: Identifico tablespace, segmento e crescita; aggiungo o estendo datafile con guardrail e poi correggo capacity planning.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: AUTOEXTEND e' gia' attivo?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q209 [P1] Come gestisci ORA-01652?

**Risposta **: Identifico TEMP, SQL e consumo per sessione; mitigo spazio se necessario e correggo query, PGA o parallelismo.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Perche' non basta aggiungere tempfile?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q210 [P1] Come gestisci ORA-01555?

**Risposta **: Correlazione durata query, undo retention, undo space e tasso DML; valuto tuning query e dimensionamento UNDO.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Imposti retention enorme?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q211 [P1] Come gestisci ORA-00060?

**Risposta **: Oracle sceglie una vittima e produce trace; analizzo ordine lock applicativo e SQL per eliminare root cause.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Perche' kill manuale non e' la soluzione?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q212 [P1] Come gestisci sessioni bloccate?

**Risposta **: Identifico blocker chain, impatto e transazione; prima di kill salvo evidenze e ottengo autorizzazione secondo runbook.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Come scegli tra kill session e disconnect?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q213 [P1] Come gestisci ORA-12514?

**Risposta **: Listener vivo ma service non noto: controllo lsnrctl services, stato DB, service e registrazione dinamica.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Quando usi alter system register?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q214 [P1] Come gestisci ORA-12541?

**Risposta **: Nessun listener raggiungibile: controllo processo, porta, host, firewall e configurazione client/server.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: tnsping basta?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q215 [P1] Come gestisci ORA-01034?

**Risposta **: Verifico ORACLE_SID, PMON, stato istanza e alert log; startup solo dopo aver capito perche' e' giu'.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Come distingui ambiente errato da crash?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q216 [P1] Come tratti ORA-00600?

**Risposta **: E' errore interno: raccolgo alert, trace, incident package, versione e contesto; applico workaround solo documentato o indicato da Oracle.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Apri SR con quale severita'?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q217 [P1] Come tratti ORA-07445?

**Risposta **: Raccolgo stack, trace, processo e operazione; cerco correlazione e coinvolgo supporto Oracle per crash interni.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Riavvii alla cieca?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q218 [P1] Come gestisci un datafile offline inatteso?

**Risposta **: Identifico file, tablespace, errore I/O e stato; ripristino storage o uso RMAN restore/recover secondo criticita'.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Puoi metterlo online senza recovery?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q219 [P1] Come tratti destinazione archivelog MANDATORY guasta?

**Risposta **: Verifico LOG_ARCHIVE_DEST e impatto; ripristino destinazione o applico cambio autorizzato preservando protezione richiesta.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Disabiliti subito la destinazione?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q220 [P1] Come tratti backup fallito per disco pieno?

**Risposta **: Valuto storage, FRA, piece e retention; libero file eleggibili o uso storage alternativo e rilancio con validazione.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Cancellare file con rm e' accettabile?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q221 [P1] Come tratti invalid objects dopo patch?

**Risposta **: Controllo registry, datapatch log e DBA_OBJECTS; ricompilo dove previsto e apro escalation se componente resta invalido.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: utlrp risolve sempre?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q222 [P1] Come tratti job Scheduler bloccato?

**Risposta **: Leggo stato, run history, sessione e dipendenze; evito rerun duplicati senza idempotenza applicativa.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Come gestisci finestra batch?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q223 [P1] Come tratti una session storm?

**Risposta **: Identifico servizio e sorgente, proteggo process limit e pool, mitigo lato applicazione o rete e misuro recupero.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Alzare sessions basta?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q224 [P1] Come correli latenza storage OS e DB?

**Risposta **: Uso iostat e wait event sulla stessa finestra, mappo file e device, coinvolgo storage con evidenze.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Come distingui throughput da latency?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q225 [P1] Come gestisci filesystem con inode esauriti?

**Risposta **: Uso df -i e find controllato, pulisco file corretti con tool supportati e introduco monitoraggio inode.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Perche' df -h puo' sembrare sano?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q226 [P2] Cosa includi in una escalation Oracle SR?

**Risposta **: Versione, impatto, timeline, riproducibilita', error stack, alert, trace, IPS package, modifiche recenti ed evidenze.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Perche' serve un testcase se possibile?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q227 [P2] Come definisci rollback operativo?

**Risposta **: Stabilisco trigger e percorso prima del change, con ownership, checkpoint, test di ritorno e comunicazione.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Quando smetti di tentare fix?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

### Q228 [P2] Come chiudi un incidente?

**Risposta **: Valido servizio, rischio residuo e monitoraggio, salvo evidenze, assegno root cause e azioni preventive con owner e data.





**Comandi e verifiche**: `adrci exec="show homes"; adrci exec="show alert -tail 100"`

**Trappola / follow-up**: Workaround e problem record sono distinti?

**Leggi nel repo**: `docs/01_operations/02_runbooks_incidenti/RUNBOOK_00_TRIAGE_INCIDENTI_ORACLE.md`

## RAC, ASM e Data Guard

### Q229 [P2] RAC e Data Guard risolvono lo stesso problema?

**Risposta **: No: RAC protegge disponibilita' locale e scala istanze su storage condiviso; Data Guard protegge sito e database con replica redo.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Quale protegge da perdita storage condiviso?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q230 [P2] Che cos'e' ASM?

**Risposta **: ASM gestisce storage Oracle in diskgroup, distribuendo extent e offrendo ridondanza secondo configurazione.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: E' un filesystem generico?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q231 [P2] External, normal e high redundancy ASM: differenze?

**Risposta **: Definiscono responsabilita' e numero di copie ASM; external delega resilienza allo storage sottostante.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Quale scegli con SAN ridondata?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q232 [P2] Che cos'e' Allocation Unit ASM?

**Risposta **: E' unita' base di allocazione; influenza layout e operazioni ma non si cambia casualmente su sistemi esistenti.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Quando la scegli?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q233 [P2] Come funziona rebalance ASM?

**Risposta **: Redistribuisce extent dopo variazioni dischi; POWER controlla aggressivita' e impatto sul workload.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Metti POWER massimo in picco?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q234 [P2] Cosa sono OCR e voting disk?

**Risposta **: OCR conserva configurazione cluster; voting supporta membership e quorum. Sono critici per Clusterware.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Come li verifichi?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q235 [P2] Che ruolo ha Clusterware?

**Risposta **: Avvia, monitora e orchestra risorse cluster secondo dipendenze e policy; uso tool supportati per operare.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Perche' non avviare manualmente tutto?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q236 [P2] SRVCTL e CRSCTL: differenze?

**Risposta **: SRVCTL gestisce risorse Oracle ad alto livello; CRSCTL diagnostica e gestisce Clusterware e risorse con maggiore cautela.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Quale usi per un database?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q237 [P2] SCAN, VIP, listener e service: relazione?

**Risposta **: SCAN offre endpoint client, VIP facilita failover rete, listener accetta connessioni, service indirizza workload.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Perche' il service e' il contratto applicativo?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q238 [P2] Che cos'e' Cache Fusion?

**Risposta **: RAC trasferisce blocchi tra buffer cache delle istanze tramite interconnect per mantenere coerenza globale.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Quali wait indicano blocchi hot?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q239 [P2] Come analizzi RAC gc waits?

**Risposta **: Correlazione SQL, oggetti, istanze, service placement e interconnect; evito di attribuire tutto alla rete.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Quando partizionare workload?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q240 [P2] Come gestisci node eviction?

**Risposta **: Raccolgo Clusterware, OS e interconnect evidence, stabilizzo servizio sugli altri nodi e analizzo causa quorum o heartbeat.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Riavvii il nodo immediatamente?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q241 [P2] Come progetti service failover?

**Risposta **: Definisco preferred e available instance, policy, draining e test client; il service separa workload dall'istanza.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Come provi il failover applicativo?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q242 [P2] TAF e Application Continuity: differenze?

**Risposta **: TAF copre alcuni failover sessione; Application Continuity mira a replay trasparente con driver e servizi compatibili.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Basta configurare il DB?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q243 [P2] Che cos'e' una physical standby?

**Risposta **: Replica block-for-block che riceve e applica redo; e' base comune per DR e role transition.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Protegge da DROP TABLE?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q244 [P2] SYNC e ASYNC redo transport: trade-off?

**Risposta **: SYNC riduce data loss pagando latenza commit; ASYNC favorisce performance con possibile perdita redo in failover.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Come colleghi scelta a RPO?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q245 [P2] Perche' servono standby redo log?

**Risposta **: Ricevono redo sullo standby e supportano real-time apply e role transition; numero e size devono essere coerenti.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Quanti ne crei per thread?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q246 [P2] LNS, RFS e MRP: ruoli?

**Risposta **: LNS spedisce redo dal primary, RFS riceve sullo standby, MRP applica ai datafile physical standby.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Dove cerchi lag transport e apply?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q247 [P2] A cosa serve Data Guard Broker?

**Risposta **: Centralizza configurazione, validazione e role transition con DGMGRL; riduce errori manuali ma richiede preflight.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Quali comandi usi prima di switchover?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q248 [P2] Switchover e failover: differenze?

**Risposta **: Switchover e' role transition pianificata senza perdita prevista; failover e' risposta a indisponibilita' primary con rischio dati secondo protezione.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Quando fai reinstate?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q249 [P2] Perche' Flashback aiuta reinstate?

**Risposta **: Permette di riportare il vecchio primary a un punto coerente e reinserirlo come standby senza rebuild completo quando condizioni lo consentono.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: E' requisito assoluto per ogni Data Guard?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q250 [P2] Come colmi un archive gap?

**Risposta **: FAL spesso recupera automaticamente; altrimenti copio archivelog, registro con ALTER DATABASE REGISTER PHYSICAL LOGFILE e valido v$archive_gap sullo standby.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Dove interroghi v$archive_gap?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q251 [P2] Come gestisci FRA primary piena con standby in lag?

**Risposta **: Preservo redo, aumento capacita' o backup su storage alternativo; DELETE FORCE e' ultima scelta autorizzata con piano di riallineamento.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Cosa succede al ritorno rete?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

### Q252 [P2] Come riallinei standby senza redo originali?

**Risposta **: Fermo MRP e uso RECOVER STANDBY DATABASE FROM SERVICE sullo standby 19c; incremental FROM SCN e' fallback.





**Comandi e verifiche**: `srvctl status database -d RACDB; crsctl stat res -t; dgmgrl /`

**Trappola / follow-up**: Quando fai rebuild completo?

**Leggi nel repo**: `docs/02_core_dba/04_high_availability_and_rac/README.md`

## Security, multitenant e change management

### Q253 [P2] Come amministri CDB e PDB senza confonderti?

**Risposta **: Identifico container corrente, scope del comando e impatto su root o PDB; valido sempre con show con_name e v$pdbs.





**Comandi e verifiche**: `SELECT name, open_mode FROM v$pdbs; SELECT * FROM v$encryption_wallet;`

**Trappola / follow-up**: Perche' un comando dalla root puo' avere blast radius maggiore?

**Leggi nel repo**: `docs/02_core_dba/01_administration_and_security/README.md`

### Q254 [P2] Common user e local user: differenze?

**Risposta **: Il common user opera secondo privilegi comuni nei container previsti; il local user vive nella singola PDB.





**Comandi e verifiche**: `SELECT name, open_mode FROM v$pdbs; SELECT * FROM v$encryption_wallet;`

**Trappola / follow-up**: Quando usi C##?

**Leggi nel repo**: `docs/02_core_dba/01_administration_and_security/README.md`

### Q255 [P2] Come applichi least privilege?

**Risposta **: Concedo ruoli e privilegi minimi, separo account nominali e tecnici, rivedo grant e traccio eccezioni.





**Comandi e verifiche**: `SELECT name, open_mode FROM v$pdbs; SELECT * FROM v$encryption_wallet;`

**Trappola / follow-up**: Perche' evitare DBA agli account applicativi?

**Leggi nel repo**: `docs/02_core_dba/01_administration_and_security/README.md`

### Q256 [P2] Perche' usare SYSBACKUP?

**Risposta **: Separa operazioni backup e recovery da SYSDBA, migliorando least privilege e auditabilita'.





**Comandi e verifiche**: `SELECT name, open_mode FROM v$pdbs; SELECT * FROM v$encryption_wallet;`

**Trappola / follow-up**: RMAN richiede sempre SYSDBA?

**Leggi nel repo**: `docs/02_core_dba/01_administration_and_security/README.md`

### Q257 [P2] Come gestisci TDE wallet?

**Risposta **: Proteggo keystore, backup e password, verifico stato wallet e procedure restore su tutti i siti.





**Comandi e verifiche**: `SELECT name, open_mode FROM v$pdbs; SELECT * FROM v$encryption_wallet;`

**Trappola / follow-up**: Cosa succede al restore senza chiavi?

**Leggi nel repo**: `docs/02_core_dba/01_administration_and_security/README.md`

### Q258 [P2] Come imposti auditing utile?

**Risposta **: Traccio eventi rilevanti senza generare rumore ingestibile, proteggo trail e definisco retention e review.





**Comandi e verifiche**: `SELECT name, open_mode FROM v$pdbs; SELECT * FROM v$encryption_wallet;`

**Trappola / follow-up**: Come eviti filesystem pieno per audit?

**Leggi nel repo**: `docs/02_core_dba/01_administration_and_security/README.md`

### Q259 [P2] Come gestisci credenziali nelle command line?

**Risposta **: Uso wallet, vault o input protetto; password in argomenti possono comparire in process list, history e log.





**Comandi e verifiche**: `SELECT name, open_mode FROM v$pdbs; SELECT * FROM v$encryption_wallet;`

**Trappola / follow-up**: Come configuri automazione non interattiva?

**Leggi nel repo**: `docs/02_core_dba/01_administration_and_security/README.md`

### Q260 [P2] Cosa deve avere un change di produzione?

**Risposta **: Scope, rischio, evidenze before, piano esecuzione, test, rollback, owner e comunicazione; chiudo solo dopo validazione osservabile.





**Comandi e verifiche**: `SELECT name, open_mode FROM v$pdbs; SELECT * FROM v$encryption_wallet;`

**Trappola / follow-up**: Quale trigger avvia rollback?

**Leggi nel repo**: `docs/02_core_dba/01_administration_and_security/README.md`

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
