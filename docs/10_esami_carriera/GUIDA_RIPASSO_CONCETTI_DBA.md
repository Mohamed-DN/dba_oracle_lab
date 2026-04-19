# 🎯 Ripasso Concetti Oracle DBA — Note di Studio e Preparazione Colloqui

> **Obiettivo**: Consolidare i concetti fondamentali Oracle DBA in forma di domande e risposte.
> Ogni sezione ha: domande chiave + risposte strutturate + note tecniche.
>
> ⏱️ **Formato**: 15 sezioni tematiche, inclusa la preparazione ai colloqui tecnici.

---

## 📅 Piano di Ripasso & Strategia

| Giorno | Tema | Sezione | Tempo |
|---|---|---|---|
| 1 | Mindset & Architettura | [Sez. 0-1](#0-mindset-e-strategia-di-risposta) | 3h |
| 2 | RAC + Data Guard | [Sez. 2-3](#2-rac-real-application-clusters) | 3h |
| 3 | Backup + Performance | [Sez. 4-5](#4-backup--recovery-rman) | 3h |
| 4 | Troubleshooting + ASM | [Sez. 6-7](#6-troubleshooting-scenari-reali) | 3h |
| 5 | Patching + Admin | [Sez. 8-9](#8-patching--upgrade) | 3h |
| 6 | Scenari PRO + Replica | [Sez. 10-11](#10-scenari-di-produzione-le-domande-killer) | 3h |
| 7 | Cloud + Crisi + Skills | [Sez. 12-13-14-15](#12-cloud--oci-oracle-cloud-infrastructure) | 3h |

---

## 🧠 0. MINDSET E STRATEGIA DI RISPOSTA

### Il Mindset del DBA Senior
Un DBA Junior risponde dicendo *quale comando lanciare*. Un DBA Senior risponde spiegando *perché lo lancia* e *come funziona il motore sotto il cofano*.

**Regole d'Oro per il Colloquio:**
1. **Padroneggia il vocabolario**: Non dire "la memoria sbarella". Di' "ho una forte contesa di latch sulla shared pool, causando il wait event `cursor: pin S wait on X`".
2. **Vai a fondo**: Se ti chiedono un comando, tu spiega prima la teoria. (Es: "Faccio `ALTER SYSTEM SWITCH LOGFILE`, questo forza il processo LGWR a chiudere il gruppo corrente, scatenando poi l'ARCn...").
3. **Pensa in ottica MAA (Maximum Availability Architecture)**: Ogni tua risposta deve contemplare l'impatto sul business (niente downtime, niente perdita di dati).
4. **Non indovinare**: Se non sai un comando a memoria, dillo apertamente: *"Non ricordo la sintassi esatta, andrei sulla documentazione ufficiale, ma so che serve per fare X tramite il processo Y."* La teoria conta più del comando mnemonico.

### La Metodologia di Risposta (Metodo STAR)
Quando ti fanno domande del tipo *"Parlami di quella volta che hai avuto un server giù"*, usa il framework **STAR**:
*   **S (Situation)**: Contesto. *"Avevo un RAC a 2 nodi in produzione."* (Fornisci dettagli tecnici: versione DB, piattaforma).
*   **T (Task)**: Il problema. *"Il nodo 1 crashava misteriosamente alle 3 di notte senza evidente picco di CPU."*
*   **A (Action)**: Cosa hai fatto TU. *"Ho usato il metodo Top-Down. Ho analizzato AWR e wait events. Ho verificato i dischi redo."*
*   **R (Result)**: L'impatto. *"Problema risolto e latenza query abbattuta del 40%."*

---

## 1. ARCHITETTURA ORACLE (Fondamentale — te la chiedono SEMPRE)

### Q: "Spiegami l'architettura di un'istanza Oracle"

**Risposta strutturata** (disegnala su carta se puoi):

```
ISTANZA = Memoria (SGA) + Processi in background

SGA (System Global Area) — memoria condivisa fra TUTTE le sessioni:
├── Buffer Cache      → Cache dei blocchi dati (evita letture disco)
├── Shared Pool       → Cache di SQL parsed + dizionario dati
│   ├── Library Cache → SQL e PL/SQL compilati
│   └── Data Dict Cache → Metadati tabelle/colonne
├── Redo Log Buffer   → Buffer per le scritture redo (transazioni)
├── Large Pool        → RMAN, shared server, parallel query
└── PGA (per sessione) → Sort, hash join, variabili di sessione

Processi Background:
├── DBWR (DB Writer)  → Scrive i dirty blocks dal buffer cache al disco
├── LGWR (Log Writer) → Scrive il redo log buffer ai redo log files
├── CKPT (Checkpoint) → Coordina i checkpoint (sync buffer cache ↔ disco)
├── SMON (System Mon) → Recovery all'avvio, pulizia segmenti temp
├── PMON (Process Mon)→ Pulizia sessioni morte, rilascia lock
├── ARCH (Archiver)   → Copia i redo log pieni → archivelog
└── MMON (Manageability)→ AWR snapshots automatici
```

**Trappola**: "Qual è la differenza fra SGA e PGA?"
- SGA = **condivisa** (tutti i processi la vedono)
- PGA = **privata** (ogni sessione ha la sua, per sort e hash join)

### Q: "Come funziona una transazione in Oracle?"

```
1. L'utente fa un UPDATE → Oracle modifica il blocco nel Buffer Cache
2. PRIMA di modificare, scrive nel Redo Log Buffer (per recovery)
3. Il blocco originale va nell'UNDO Tablespace (per rollback e read consistency)
4. L'utente fa COMMIT → LGWR scrive il Redo Log Buffer su disco (redo log file)
   ← Il COMMIT è "veloce" perché scrive SOLO il redo, non i dati!
5. Il DBWR scriverà il blocco modificato su disco più tardi (lazy write)
```

**Perché è importante**: Se il server crasha dopo il COMMIT, Oracle fa **crash recovery** riapplicando i redo log → garantisce ACID (durability).

### Q: "Cos'è un checkpoint?"

Un checkpoint forza DBWR a scrivere tutti i dirty blocks su disco. Serve per:
- Ridurre il tempo di recovery (meno redo da applicare)
- Si fa automaticamente a ogni log switch

### Q: "Differenza fra shutdown immediate, abort, transactional?"

| Tipo | Sessioni | Transazioni | Recovery | Quando |
|---|---|---|---|---|
| `NORMAL` | Aspetta che si disconnettano | Aspetta commit/rollback | No | Mai in pratica |
| `TRANSACTIONAL` | Aspetta solo le transazioni attive | Aspetta commit/rollback | No | Raramente |
| `IMMEDIATE` | Disconnette tutti | Rollback automatico | No | **Uso normale** |
| `ABORT` | Kill brutale | Nessun rollback | **SÌ** (instance recovery) | Emergenza |

### Q: "Cos'è il Multiplexing e cosa si multiplexa in Oracle?"

**Risposta**: Il multiplexing è la pratica di mantenere **copie multiple (mirroring a livello Oracle)** dei file critici su dischi fisici diversi per prevenire la perdita del database.

Si applica a due componenti fondamentali:
1. **Control Files** (`CONTROL_FILES` parameter): Contengono la struttura fisica del DB e l'SCN corrente. Se perdi tutti i control file, il DB va giù e serve il recovery. Regola d'oro: minimo 2 copie in percorsi diversi.
2. **Redo Log Groups**: Ogni gruppo dovrebbe avere almeno 2 **membri** su dischi diversi. Se un disco si brucia mentre LGWR sta scrivendo, il DB continua a funzionare scrivendo sull'altro membro.

*Nota moderna*: Con ASM in ridondanza NORMAL o HIGH, il multiplexing a livello logico (Oracle) spesso non è più "strettamente" necessario perché ASM fa già il mirroring dei blocchi sotto il cofano, ma le best practice MAA raccomandano ancora il multiplexing dei redo su diskgroup ASM separati (es. `+DATA` e `+RECO`).

### Q: "Perché LGWR scrive prima di DBWR? (Write-Ahead Logging)"

È il fondamento dei database relazionali per garantire l'integrità anche in caso di crash di corrente. **Prima** che il DBWR possa scrivere un blocco dati modificato (dirty block) sul datafile, il LGWR **deve** aver già scritto nel Redo Log File il record di quella transazione. Questo perché, in caso di crash, Oracle usa il Redo Log per ricostruire i dati che erano in memoria e non ancora scritti su disco.

### Q: "Spiegami la differenza tra un Logical Read e un Physical Read."
**Risposta Perfetta**: "Un **Physical Read** avviene quando Oracle deve andare sul disco per leggere un blocco e portarlo in memoria (SGA - Buffer Cache). Questo è lento (latenza di ms) ed è indicato dai wait event `db file sequential/scattered read`. Un **Logical Read** (o memory hit) avviene quando Oracle trova il blocco già presente nel Buffer Cache. È estremamente veloce (microsecondi), consuma solo CPU e latch."

### Q: "Cosa è un ITL all'interno di un blocco Oracle e perché ci interessa?"
L'ITL (Interested Transaction List) è una struttura dati presente nell'header di ogni blocco Oracle. È il registro delle transazioni che stanno attualmente bloccando delle righe all'interno di quel blocco. Ci interessa perché se abbiamo un'alta concorrenza su un unico blocco (hot block) e le slot ITL finiscono, le sessioni si bloccheranno con l'evento `enq: TX - allocate ITL entry`. In questi casi, devo ricreare l'oggetto aumentando il parametro `INITRANS`.

---

## 2. RAC (Real Application Clusters)

### Q: "Cos'è Oracle RAC e come funziona?"

**Risposta**: RAC = **più istanze Oracle** su server diversi che accedono allo **stesso database** (dischi condivisi su ASM).

```
     rac1 (Istanza 1)          rac2 (Istanza 2)
     ┌──────────────┐          ┌──────────────┐
     │ SGA + PGA    │          │ SGA + PGA    │
     │ Background   │          │ Background   │
     └──────┬───────┘          └──────┬───────┘
            │     Interconnect         │
            │◄════ Cache Fusion ══════►│
            │     (privata, bassa      │
            │      latenza)            │
     ┌──────┴──────────────────────────┴──────┐
     │        STORAGE CONDIVISO (ASM)          │
     │   +DATA  +RECO  +CRS (dischi condivisi) │
     └─────────────────────────────────────────┘
```

**Cache Fusion**: Quando rac1 ha bisogno di un blocco che è nel buffer cache di rac2, lo trasferisce via interconnect **senza andare al disco**. È la chiave delle performance RAC.

### Q: "Cos'è un VIP, uno SCAN, e perché servono?"

| Componente | Cos'è | Perché |
|---|---|---|
| **VIP** | IP virtuale associata a ogni nodo | Se il nodo muore, il VIP si sposta → i client lo scoprono subito (non aspettano TCP timeout) |
| **SCAN** | Single Client Access Name (3 IP) | Un unico hostname per tutti i client. Il DNS risolve a 3 IP, il load balancing è automatico |
| **Interconnect** | Rete privata ad alta velocità | Per Cache Fusion. **DEVE** essere dedicata e a bassa latenza |

### Q: "Che succede se un nodo RAC va giù?"

1. Il cluster **rileva il guasto** (CSS — Cluster Synchronization Services)
2. Le **VIP si spostano** sui nodi sopravvissuti → gli utenti si riconnettono
3. Il SMON del nodo sopravvissuto **fa instance recovery** (applica i redo del nodo morto)
4. Le sessioni che usavano TAF (Transparent Application Failover) si riconnettono automaticamente

**Follow-up trappola**: "E i lock del nodo morto?"
→ LMON (Lock Manager) fa **lock recovery** —rilascia i lock del nodo morto dopo il crash recovery.

### Q: "Cos'è lo Split-Brain nel RAC e come interviene il Node Eviction?"

**Domanda per Senior DBA**:
Se la rete privata (Interconnect) cade tra i due nodi, il *Node 1* pensa che il *Node 2* sia morto e viceversa. Entrambi provano a scrivere sugli stessi dischi. Questo è il problema dello **Split-Brain** (data corruption mortale).

**Cosa fa Oracle**:
Usa il **Voting Disk** su ASM (deve esserci un numero dispari di dischi di voto). Entrambi i nodi "votano" per dichiararsi vivi e isolare l'altro nodo. Il nodo (o il gruppo di nodi) che ha la maggioranza accede all'ASM, mentre l'altro si rende conto di essere isolato e commette un **Node Eviction** — fa volontariamente un kernel panic (reboot forzato) per fermare i propri I/O ed evitare la corruzione dei dati.

### Q: "Cos'è un service in RAC? Perché è importante?"

Un **service** è un nome logico che i client usano per connettersi. Puoi configurarlo per:
- **Preferred/Available**: il servizio gira sulla preferred instance, se va giù migra sull'available
- **Connection Load Balancing (CLB)**: distribuisce nuove connessioni
- **Runtime Load Balancing (RLB)**: distribuisce in base al carico reale
- **Application Continuity**: replay trasparente delle transazioni dopo failover

```sql
-- Crea un service che preferisce rac1, con failover su rac2
srvctl add service -d RACDB -s APP_SVC -preferred rac1 -available rac2 -failovertype AUTO
srvctl start service -d RACDB -s APP_SVC
```

---

## 3. DATA GUARD

### Q: "Spiegami Data Guard. Come funziona?"

**Risposta**:
- Data Guard = **replica in tempo reale** del database su un server separato (standby)
- Il primary genera **redo log** → li spedisce allo standby → lo standby li **applica**
- Se il primary muore → fai **switchover** (controllato) o **failover** (emergenza)

```
PRIMARY (RACDB)                    STANDBY (RACDB_STBY)
┌───────────────┐                  ┌───────────────┐
│ Read-Write    │   Redo Transport │ Read-Only     │
│ Applicazione  │ ════════════════►│ Apply (MRP)   │
│ attiva qui    │   LGWR/ARCH ASYNC│ Report, query │
└───────────────┘                  └───────────────┘
```

### Q: "Differenza fra switchover e failover?"

| | Switchover | Failover |
|---|---|---|
| **Quando** | Manutenzione pianificata | Emergenza (primary distrutto) |
| **Rischio** | Zero — è reversibile | Potenziale perdita dati |
| **Procedura** | Scambia i ruoli in modo controllato | Il standby diventa primary |
| **Dopo** | Puoi fare switchback | Devi fare **reinstate** del vecchio primary |
| **Comando** | `SWITCHOVER TO 'RACDB_STBY'` | `FAILOVER TO 'RACDB_STBY'` |

### Q: "Cosa accade durante un processo di Switchover sotto il cofano?"
Durante uno Switchover effettuato con DGMGRL:
1. Il Primary chiude i servizi applicativi (se configurati con l'attributo `-role`).
2. Termina la scrittura dei dati correnti, fa lo switch dell'ultimo log e si assicura che lo Standby riceva e applichi l'ultimo redo (Data Guard Sync).
3. Il Primary smonta i datafiles e cambia ruolo in Standby.
4. Lo Standby originario finisce di applicare i redo, apre il database in modalità READ WRITE, e diventa il nuovo Primary.
5. Clusterware avvia in automatico i Servizi sul nuovo Primary.

### Q: "Cosa sono i Protection Mode?"

| Mode | Perdita dati | Come funziona | Impatto |
|---|---|---|---|
| **Maximum Performance** | Possibile (pochi secondi) | ASYNC — non aspetta conferma standby | Nessun impatto sulle performance |
| **Maximum Availability** | Zero (in condizioni normali) | SYNC — aspetta conferma standby, ma se lo standby va giù torna async | Leggero impatto latenza |
| **Maximum Protection** | Mai, garantito | SYNC — se lo standby va giù, il primary si **ferma** | ⚠️ Rischio disponibilità |

**Trappola**: "Quale consigli per la produzione?"
→ **Maximum Availability** — è il giusto compromesso. MaxProtection è troppo rischioso.

### Q: "Come verifichi che il Data Guard funziona?"

```sql
-- 1. Controlla il lag
SELECT name, value FROM v$dataguard_stats WHERE name LIKE '%lag%';

-- 2. Controlla lo switchover status
SELECT switchover_status FROM v$database;

-- 3. Controlla il MRP (deve fare APPLYING)
SELECT process, status, sequence# FROM v$managed_standby WHERE process = 'MRP0';
```

---

## 4. BACKUP & RECOVERY (RMAN)

### Q: "Qual è la tua strategia di backup?"

**Risposta standard produzione**:

```
GIORNALIERO:
- Level 0 (full) ogni domenica
- Level 1 (incrementale) lunedì-sabato
- Archivelog backup ogni 30 minuti
- Retention: 7 giorni su disco, 30 giorni su tape

SEMPRE ATTIVO:
- Block Change Tracking (BCT) per velocizzare Level 1
- Controlfile autobackup ON
- Validate settimanale
```

### Q: "Abbiamo perso il Recovery Catalog di RMAN. Possiamo ancora recuperare il database? Come?"
Sì, assolutamente. Oracle memorizza i metadati dei backup anche nel **Controlfile** del database (secondo il parametro `CONTROL_FILE_RECORD_KEEP_TIME`). Posso puntare RMAN al target DB e usare le informazioni nel controlfile per il restore.

### Q: "Differenza fra backup full, Level 0 e Level 1?"

| Tipo | Cosa include | Usabile come base incrementale? |
|---|---|---|
| **Full** | Tutto il database | NO |
| **Level 0** | Tutto il database | SÌ — è il "punto di partenza" |
| **Level 1 Differential** | Solo blocchi cambiati dal Level 1 o 0 più recente | — |
| **Level 1 Cumulative** | Solo blocchi cambiati dal Level 0 | — |

### Q: "Hai mai fatto un restore/recovery? Descrivimi il processo"

```bash
# Scenario: tablespace USERS corrotto
# 1. Metti il datafile offline
ALTER DATABASE DATAFILE '/path/users01.dbf' OFFLINE;
# 2. Restore il datafile da backup
RMAN> RESTORE DATAFILE '/path/users01.dbf';
# 3. Recovery (applica i redo/archivelog fino all'ultimo)
RMAN> RECOVER DATAFILE '/path/users01.dbf';
# 4. Rimetti online
ALTER DATABASE DATAFILE '/path/users01.dbf' ONLINE;
```

### Q: "Cos'è un Flashback Database?"

**Risposta**: È come una "macchina del tempo" — riporta l'intero DB a un punto nel passato **SENZA** restore da backup.

```sql
-- Prerequisiti: flashback ON + guaranteed restore point
ALTER DATABASE FLASHBACK ON;
CREATE RESTORE POINT BEFORE_UPGRADE GUARANTEE FLASHBACK DATABASE;
```

---

## 5. PERFORMANCE & TUNING

### Q: "Il database è lento. Come fai troubleshooting?"

**Metodo sistematico in 5 step**:

```
STEP 1: È veramente il DB? (top / vmstat / iostat)
STEP 2: Quali WAIT EVENTS? (v$session)
   I wait events ti DICONO il problema:
   - "db file sequential read" → troppi I/O (indici mancanti)
   - "log file sync"          → commit troppo frequenti
   - "enq: TX"                → lock/contesa
   - "latch free"             → contesa in memoria (hard parse)
STEP 3: Top SQL (v$sql)
STEP 4: Execution Plan (DBMS_XPLAN)
STEP 5: AWR Report (@$ORACLE_HOME/rdbms/admin/awrrpt.sql)
```

### Q: "Il server è lentissimo. Vedi che l'80% del DB Time è consumato dall'evento `log file sync`. Come indaghi?"
Questo indica che il processo **LGWR** è lento a scrivere il Redo Log Buffer sui dischi, oppure che l'applicazione committa troppo spesso. Indago in due direzioni:
1. Lato applicazione: Verifico il numero di 'user commits' al secondo. Se è troppo alto, l'applicazione fa commit per ogni riga in cicli `FOR` invece di fare commit in batch.
2. Lato Storage: Controllo la latenza dei Redo Log. I redo non dovrebbero mai stare su dischi RAID-5, ma su dischi ultra veloci (SSD/NVMe).

### Q: "Perché l'ottimizzatore sceglie una FULL TABLE SCAN su una colonna con indice?"
L'ottimizzatore sceglie saggiamente una full table scan (`db file scattered read`) se la colonna ha **bassa selettività** (solo due valori distinti, quindi ~5 milioni di righe per valore su 10M). Leggere l'indice per poi estrarre milioni di righe tramite ROWID provocherebbe tantissimi I/O randomici (`db file sequential read`) risultando più lento di una lettura multiblock.

### Q: "Vedo molte attese su `cursor: pin S wait on X`. Cosa succede in memoria?"
C'è una forte contesa nella Shared Pool (Library Cache). Una sessione sta cercando di ottenere un lock esclusivo (X) su un cursore — spesso per fare un **Hard Parse** — mentre altre sessioni stanno cercando di eseguirlo. La causa primaria nel 99% dei casi è la **mancanza di bind variables**.

### Q: "Chiaro il concetto di Hard Parse vs Soft Parse?"
1. **Hard Parse**: La query è nuova. Oracle deve controllare sintassi, semantica, l'optimizer genera vari piani e sceglie il migliore. *Costoso in CPU e Mutex.*
2. **Soft Parse**: La query esiste già nella Shared Pool. Oracle riutilizza il vecchio piano esecutivo.

---

## 6. TROUBLESHOOTING SCENARI REALI

### Q: "ORA-00060: deadlock detected. Cosa fai?"

1. **Non panico** — Oracle risolve automaticamente il deadlock (killa UNA delle sessioni)
2. Vai a leggere il **trace file** generato (contiene l'albero del deadlock)
3. Trova le **due tabelle/righe** coinvolte e chiedi al team dev di cambiare l'ordine dei DML.

### Q: "Il tablespace è pieno (ORA-01654). Cosa fai?"

```sql
-- 1. DIAGNOSTICA: quanto è pieno?
SELECT tablespace_name, ROUND(used_percent,1) AS pct FROM dba_tablespace_usage_metrics
WHERE used_percent > 85 ORDER BY pct DESC;
-- 2. FIX IMMEDIATO: aggiungi datafile
ALTER TABLESPACE USERS ADD DATAFILE '+DATA' SIZE 10G AUTOEXTEND ON MAXSIZE 30G;
```

### Q: "La FRA è piena, il database si blocca. Cosa fai?"

```bash
# EMERGENZA! La FRA piena = archivelog non si possono scrivere = DB HANG!
# 1. Entra con RMAN e cancella archivelog vecchi (> 1 giorno)
RMAN> DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-1';
# 2. Se non basta, aumenta la FRA
ALTER SYSTEM SET db_recovery_file_dest_size = 100G SCOPE=BOTH;
```

### Q: "Un utente dice che la sua sessione è bloccata. Come indaghi?"

```sql
-- 1. Chi blocca chi? (l'albero dei blocchi)
SELECT blocker.sid, blocked.sid, blocked.seconds_in_wait
FROM v$session blocker
JOIN v$session blocked ON blocker.sid = blocked.blocking_session;
```

---

## 7. ASM (Automatic Storage Management)

### Q: "Cos'è ASM e come funziona?"

**Risposta**: ASM è un **volume manager + filesystem** fatto da Oracle.
Vantaggi:
- **Striping automatico**
- **Mirroring** (NORMAL = 2 copie)
- **Rebalance automatico**

### Q: "Come aggiungi un disco ad ASM in produzione?"
1. Lo storage team presenta la LUN. 2. Tagga con ASMLib/AFD. 3. Aggiunge: `ALTER DISKGROUP DATA ADD DISK '...';`.

---

## 8. PATCHING & UPGRADE

### Q: "Descrivi il processo di patching in RAC"
In RAC si fa **rolling patching** — un nodo alla volta, **ZERO downtime**!
1. Ferma l'istanza sul NODO 1. 2. Applica patch con `opatchauto`. 3. Riavvia ed esegui `datapatch`. 4. Ripeti sul NODO 2.

---

## 9. AMMINISTRAZIONE QUOTIDIANA

### Q: "Cosa fai come DBA ogni mattina?"
1. ✅ **Istanze e CRS** UP?
2. ✅ **Alert log**: Cerco ORA- nelle ultime 24h.
3. ✅ **Backup**: L'ultimo RMAN è OK?
4. ✅ **Data Guard**: Lag sotto controllo?
5. ✅ **Tablespace/ASM**: Spazio sufficiente?

---

## 10. SCENARI DI PRODUZIONE (Le Domande Killer!)

### Scenario 1: "È sabato notte, il primary è andato giù e non riparte."
1. Guarda l'ALERT LOG. 2. Se è corruzione hardware/file: `DGMGRL> FAILOVER TO standby`.

### Scenario 2: "Dev dice: 'Ho cancellato i dati da CLIENTI per sbaglio!'"
1. **Flashback Table** o **Flashback Query**. 2. Se tardi: RMAN auxiliary instance restore.

### Scenario 3: "CPU al 100% sul server database. Cosa fai?"
1. Verifico con `top` se è un processo `ora_*`. 2. Trovo il `sql_id` del processo. 3. Analizzo l'execution plan. 4. Fix (indice, stats o kill session).

---

## 11. GOLDENGATE & REPLICA AVANZATA

### Q: "Se il Replicat è in forte lag, quali sono i primi 3 controlli?"
1. `stats replicat`: Guardo se ci sono lock o query lente sul target.
2. `lag replicat`: Verifico se il ritardo è nel network o nel caricamento dei trail file.
3. Transazioni lunghe: Verifico se c'è un unico update gigante che occupa il processo.

### Q: "Integrated Capture vs Classic Capture?"
- **Classic**: Estrazione esterna (legge i log dal file system).
- **Integrated**: LogMiner integrato nel DB kernel. Più performante per compressione, multitenant e RAC.

---

## 12. CLOUD & OCI (Oracle Cloud Infrastructure)

### Q: "DBA in OCI: DBCS vs Autonomous?"
- **Base DB Service (PaaS)**: Hai accesso root, gestisci patching, backup e configurazione.
- **Autonomous Database**: Oracle gestisce tutto il ciclo di vita (self-patching/tuning/backup). Il DBA diventa Architect.

---

## 13. CRISIS MANAGEMENT (Il database è HANG)

### Q: "Database bloccato (HANG), login SYSDBA impossibile."
Uso una **Preliminary Connection** (`sqlplus -prelim / as sysdba`). Lancio `ORADEBUG HANGANALYZE 3` per trovare il 'final blocker' e intervenire lato OS se necessario.

---

## 14. SOFT SKILLS DBA (Gestione Incidenti & Comunicazione)

### "Emergenza alle 3 di notte: come ti comporti?"
*"Non agisco d'impulso. Diagnostico (alert log, ASH), seguo i runbook. Se il tempo di risoluzione supera la soglia critica, escalo al team e comunico in modo chiaro."*

---

## 15. COMANDI CHE DEVI SAPERE A MEMORIA

```sql
SELECT instance_name, status FROM v$instance;
SELECT name, open_mode, database_role FROM v$database;
SELECT event, count(*) FROM v$session WHERE status='ACTIVE' GROUP BY event;
SELECT name, total_mb, free_mb FROM v$asm_diskgroup;
srvctl status database -d RACDB;
```

---

## ✅ CHECKLIST PERMANENTE DEL DBA SENIOR
- [ ] Ho verificato l'Alert Log oggi?
- [ ] L'ultimo backup RMAN è "VALIDATED"?
- [ ] I servizi RAC sono bilanciati correttamente?
- [ ] Ho testato lo Switchover negli ultimi 6 mesi?
- [ ] Le HugePages sono attive sul server?

---

<p align="center">
  <sub>Questa guida è parte del repository <b>Oracle RAC Lab</b>. Condividila con saggezza.</sub>
</p>
