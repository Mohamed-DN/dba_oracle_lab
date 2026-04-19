# 🎯 Ripasso Concetti Oracle DBA — Note di Studio Avanzate

> **Obiettivo**: Consolidare i concetti fondamentali Oracle DBA in forma di domande e risposte.
> Ogni sezione ha: domande chiave + risposte strutturate + note tecniche.
>
> ⏱️ **Formato**: 12 sezioni tematiche, ~3h di lettura totale.

---

## 📅 Piano di Ripasso

| Giorno | Tema | Sezione | Tempo |
|---|---|---|---|
| 1 | Architettura + RAC | Sez. 1-2 | 3h |
| 2 | Data Guard + Backup | Sez. 3-4 | 3h |
| 3 | Performance & Troubleshooting | Sez. 5-6 | 3h |
| 4 | Storage + Patching + Admin | Sez. 7-8-9 | 3h |
| 5 | Scenari Produzione | Sez. 10 | 3h |
| 6 | Ripasso + punti deboli | Tutto | 3h |
| 7 | Quiz pratico (rispondi ad alta voce) | Tutto | 2h |

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

### Q: "Cosa sono i Protection Mode?"

| Mode | Perdita dati | Come funziona | Impatto |
|---|---|---|---|
| **Maximum Performance** | Possibile (pochi secondi) | ASYNC — non aspetta conferma standby | Nessun impatto sulle performance |
| **Maximum Availability** | Zero (in condizioni normali) | SYNC — aspetta conferma standby, ma se lo standby va giù torna async | Leggero impatto latenza |
| **Maximum Protection** | Mai, garantito | SYNC — se lo standby va giù, il primary si **ferma** | ⚠️ Rischio disponibilità |

**Trappola**: "Quale consigli per la produzione?"
→ **Maximum Availability** — è il giusto compromesso. MaxProtection è troppo rischioso (il primary si blocca se lo standby muore).

### Q: "Come verifichi che il Data Guard funziona?"

```sql
-- 1. Controlla il lag
SELECT name, value FROM v$dataguard_stats WHERE name LIKE '%lag%';

-- 2. Controlla lo switchover status
SELECT switchover_status FROM v$database;
-- Deve essere: TO STANDBY (sul primary) o TO PRIMARY (sullo standby)

-- 3. Controlla il MRP (deve fare APPLYING)
SELECT process, status, sequence# FROM v$managed_standby WHERE process = 'MRP0';

-- 4. Controlla i GAP
SELECT * FROM v$archive_gap;
-- Se esce qualcosa → c'è un buco → lo standby è indietro
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

# 5. Verifica
SELECT file#, status FROM v$datafile WHERE name LIKE '%users%';
```

### Q: "Cos'è un Flashback Database?"

**Risposta**: È come una "macchina del tempo" — riporta l'intero DB a un punto nel passato **SENZA** restore da backup.

```sql
-- Prerequisiti: flashback ON + guaranteed restore point
ALTER DATABASE FLASHBACK ON;
CREATE RESTORE POINT BEFORE_UPGRADE GUARANTEE FLASHBACK DATABASE;

-- Uso: "Oh no, l'upgrade è andato male!"
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
FLASHBACK DATABASE TO RESTORE POINT BEFORE_UPGRADE;
ALTER DATABASE OPEN RESETLOGS;
```

---

## 5. PERFORMANCE & TUNING

### Q: "Il database è lento. Come fai troubleshooting?"

**Metodo sistematico in 5 step** (questa risposta vale ORO):

```
STEP 1: È veramente il DB?
   → top / vmstat / iostat → se CPU/IO è al 100% ma il DB è idle, non è Oracle

STEP 2: Quali WAIT EVENTS?
   → SELECT event, count(*) FROM v$session WHERE status='ACTIVE' GROUP BY event;
   I wait events ti DICONO il problema:
   - "db file sequential read" → troppi I/O (indici mancanti o full scan)
   - "log file sync"          → commit troppo frequenti o disco lento
   - "enq: TX"                → lock/contesa fra sessioni
   - "latch free"             → contesa in memoria (hard parse eccessivi)

STEP 3: Top SQL
   → SELECT sql_id, elapsed_time, executions FROM v$sql ORDER BY elapsed_time DESC;
   → Trova le query che consumano di più

STEP 4: Execution Plan
   → SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('sql_id'));
   → Cerca: FULL TABLE SCAN su tabelle grandi, nested loops su molte righe

STEP 5: AWR Report
   → @$ORACLE_HOME/rdbms/admin/awrrpt.sql
   → Confronta periodo "lento" vs periodo "normale"
```

### Q: "Quali sono i wait event più comuni e come li risolvi?"

| Wait Event | Significato | Soluzione |
|---|---|---|
| `db file sequential read` | Lettura singolo blocco (index access) | Indici mancanti, statistiche stale |
| `db file scattered read` | Full table scan | Aggiungi indice o partiziona |
| `log file sync` | Aspetta che LGWR scriva il commit | Batch commit, disco redo più veloce |
| `enq: TX - row lock contention` | Due sessioni vogliono la stessa riga | Fix applicativo (reduce lock time) |
| `gc buffer busy` | RAC: contesa su blocco fra nodi | Partizionare per ridurre inter-node |
| `library cache: mutex X` | Hard parse eccessivi | Usa bind variable! |
| `latch: shared pool` | Shared pool sotto stress | Aumenta shared_pool_size, bind var |

### Q: "Cos'è un AWR report e come lo leggi?"

**Risposta**: AWR (Automatic Workload Repository) cattura snapshot ogni ora. Il report confronta 2 snapshot e mostra:

1. **Top 5 Timed Events** ← GUARDA PRIMA QUESTO!
   - Ti dice dove il DB sta "perdendo tempo"
2. **Top SQL** — le query che consumano di più (per elapsed, CPU, I/O)
3. **Instance Efficiency** — buffer cache hit ratio (deve essere >95%)
4. **Wait Event Histogram** — distribuzione dei tempi di attesa

```sql
-- Genera AWR report
@$ORACLE_HOME/rdbms/admin/awrrpt.sql
-- Scegli: HTML, periodo (inizio/fine snapshot), output file
```

### Q: "Cos'è un Execution Plan? Come capisci se è buono?"

**Segnali di un piano cattivo**:
- `TABLE ACCESS FULL` su tabelle grandi (milioni di righe)
- `NESTED LOOPS` con molte righe nella outer table (meglio HASH JOIN)
- `Cardinality Feedback` che cambia il piano → statistiche imprecise
- Costo reale >> costo stimato

```sql
-- Vedi il piano reale (non quello stimato!)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('abc123def', NULL, 'ALLSTATS LAST'));
```

### Q: "Shared Pool piena: ORA-04031. Cos'è e come risolvi?"

**Sintomo**: Il database restituisce errore ORA-04031 e le sessioni non possono fare parse di nuove query.
**Causa**: La Shared Pool (dove Oracle tiene i piani di esecuzione e lo sql compilato) è così frammentata o piena che non si trova un chunk di memoria contiguo. Spesso causato da **Hard Parsing cronico** per colpa di un'applicazione che non usa le bind variables (es. `SELECT * FROM emp WHERE id = 1`, `WHERE id = 2`, ecc.).
**Soluzione Rapida**:
1. `ALTER SYSTEM FLUSH SHARED_POOL;` (svuota la cache, dà respiro momentaneo ma causa un picco di CPU subito dopo per i nuovi hard parse).
2. Se il parametro `CURSOR_SHARING` è `EXACT`, valuta di impostarlo temporaneamente a `FORCE` (anche se in 19c è deprecato usarlo come fix a lungo termine).
**Soluzione Permanente**: Correggere l'applicazione introducendo le **Bind Variables**.

---

## 6. TROUBLESHOOTING SCENARI REALI

### Q: "ORA-00060: deadlock detected. Cosa fai?"

1. **Non panico** — Oracle risolve automaticamente il deadlock (killa UNA delle sessioni)
2. Vai a leggere il **trace file** generato (contiene l'albero del deadlock)
3. Trova le **due tabelle/righe** coinvolte
4. Chiedi al team applicativo di **cambiare l'ordine dei DML** (i deadlock sono sempre colpa dell'applicazione)

### Q: "Il tablespace è pieno (ORA-01654). Cosa fai?"

```sql
-- 1. DIAGNOSTICA: quanto è pieno?
SELECT tablespace_name, ROUND(used_percent,1) AS pct FROM dba_tablespace_usage_metrics
WHERE used_percent > 85 ORDER BY pct DESC;

-- 2. Chi sta occupando spazio?
SELECT owner, segment_name, ROUND(bytes/1024/1024) AS mb
FROM dba_segments WHERE tablespace_name = 'USERS' ORDER BY bytes DESC FETCH FIRST 5 ROWS ONLY;

-- 3. FIX IMMEDIATO: aggiungi datafile
ALTER TABLESPACE USERS ADD DATAFILE '+DATA' SIZE 10G AUTOEXTEND ON MAXSIZE 30G;

-- 4. FIX LUNGO TERMINE: capisci perché cresce (tabelle di log? purge mancante?)
```

### Q: "La FRA è piena, il database si blocca. Cosa fai?"

```bash
# EMERGENZA! La FRA piena = archivelog non si possono scrivere = DB HANG!

# 1. Entra con RMAN
rman target /

# 2. Cancella archivelog vecchi (> 1 giorno)
RMAN> DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-1';
RMAN> DELETE NOPROMPT OBSOLETE;

# 3. Se non basta, aumenta la FRA
ALTER SYSTEM SET db_recovery_file_dest_size = 100G SCOPE=BOTH;

# 4. Capire PERCHÉ si è riempita:
#    - I backup non cancellano gli archivelog?
#    - Il Data Guard è in GAP e non consuma gli archivelog?
#    - Flashback log troppo grossi?
```

### Q: "Un utente dice che la sua sessione è bloccata. Come indaghi?"

```sql
-- 1. Chi blocca chi? (l'albero dei blocchi)
SELECT
    'SID ' || s1.sid || ' (' || s1.username || ')' AS blocker,
    'SID ' || s2.sid || ' (' || s2.username || ')' AS blocked,
    s2.seconds_in_wait
FROM v$session s1
JOIN v$session s2 ON s1.sid = s2.blocking_session
WHERE s2.blocking_session IS NOT NULL;

-- 2. Che SQL sta eseguendo il bloccante?
SELECT sql_text FROM v$sql WHERE sql_id = (
    SELECT sql_id FROM v$session WHERE sid = <SID_BLOCCANTE>
);

-- 3. Contatta l'utente bloccante. Se non risponde:
ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
```

---

## 7. ASM (Automatic Storage Management)

### Q: "Cos'è ASM e come funziona?"

**Risposta**: ASM è un **volume manager + filesystem** fatto da Oracle, specifico per database. Sostituisce LVM + filesystem tradizionale.

Vantaggi:
- **Striping automatico** su tutti i dischi
- **Mirroring** integrato (NORMAL = 2 copie, HIGH = 3 copie)
- **Rebalance automatico** quando aggiungi/rimuovi dischi

```
Diskgroup +DATA (NORMAL redundancy):
├── Disco 1 (LUN1) — 20GB
├── Disco 2 (LUN2) — 20GB   → Totale USABILE: 20GB (perché mirrored)
```

**Trappola**: "Se ho +DATA con NORMAL redundancy e 2 dischi da 100GB, quanti dati posso salvare?"
→ **100GB** (non 200GB), perché NORMAL = 2 copie di ogni blocco.

### Q: "Come aggiungi un disco ad ASM in produzione?"

```sql
-- 1. Lo storage team presenta la nuova LUN al server OS
-- 2. Il DBA la tagga con ASMLib o AFD:
oracleasm createdisk DATA_DISK5 /dev/sdd1

-- 3. Aggiunge al diskgroup (SENZA downtime!):
ALTER DISKGROUP DATA ADD DISK '/dev/oracleasm/data_disk5';

-- 4. Il rebalance parte automaticamente
-- Per controllare:
SELECT * FROM v$asm_operation;
```

---

## 8. PATCHING & UPGRADE

### Q: "Descrivi il processo di patching in RAC"

**Risposta chiave**: In RAC si fa **rolling patching** — un nodo alla volta, **ZERO downtime**!

```
1. Ferma l'istanza sul NODO 1 (le sessioni vanno al NODO 2)
2. Applica la patch sul NODO 1 con opatchauto
3. Riavvia l'istanza sul NODO 1
4. Esegui datapatch (aggiorna il dizionario dati)
5. Ripeti per il NODO 2
```

**Comandi chiave**:
```bash
# Pre-check
opatch prereq CheckConflictAgainstOH -ph ./

# Applica
opatchauto apply /path/to/patch -oh $ORACLE_HOME

# Post-patch
datapatch -verbose
```

### Q: "Cosa fai PRIMA di un patching?"

1. **Backup RMAN Level 0** (completo, verificato)
2. **Guaranteed Restore Point** (per rollback veloce con flashback)
3. **Verifica spazio disco** (la patch ha bisogno di spazio)
4. **Verifica OPatch** è alla versione richiesta
5. **Comunica il CAB** (Change Advisory Board) + applicativi

---

## 9. AMMINISTRAZIONE QUOTIDIANA

### Q: "Cosa fai come DBA ogni mattina?"

**Morning Check (5-10 minuti)**:
1. ✅ **Istanze e CRS**: `srvctl status database -d RACDB` → tutte le istanze sono UP?
2. ✅ **Alert log**: Cerco ORA- nelle ultime 24h
3. ✅ **Backup**: L'ultimo RMAN è completato con successo?
4. ✅ **Data Guard**: Il lag è < qualche minuto?
5. ✅ **Tablespace**: Nessuno > 85%?
6. ✅ **ASM**: Diskgroup non pieni?
7. ✅ **Listener**: SCAN e listener locali UP?

### Q: "Come crei un utente in Oracle?"

```sql
-- 1. In un CDB, crei un utente LOCAL nella PDB
ALTER SESSION SET CONTAINER = PDB_APP;

CREATE USER scott IDENTIFIED BY "Password123!"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 500M ON USERS;

-- 2. Grant
GRANT CREATE SESSION TO scott;
GRANT CREATE TABLE, CREATE VIEW, CREATE PROCEDURE TO scott;

-- 3. Se serve read-only su un altro schema:
GRANT SELECT ANY TABLE TO scott;  -- ⚠️ troppo permissivo!
-- Meglio:
GRANT SELECT ON hr.employees TO scott;
```

### Q: "Differenza fra CDB, PDB, e perché Oracle Multitenant?"

```
CDB (Container Database) = il "contenitore"
├── CDB$ROOT    → Dizionario dati master, non toccare
├── PDB$SEED    → Template per nuove PDB
├── PDB_APP1    → Database dell'applicazione 1
├── PDB_APP2    → Database dell'applicazione 2
└── PDB_TEST    → Database di test
```

**Perché**: Consolida N database in 1 istanza → meno RAM, meno patching, più facile da gestire.

---

## 10. SCENARI DI PRODUZIONE (Le Domande Killer!)

> Queste sono le domande che separano un junior da un senior. **Studia bene questa sezione.**

### Scenario 1: "È sabato notte, il primary è andato giù e non riparte. Cosa fai?"

```
1. CALMA. Non fare panic.
2. Prova a riavviare:
   srvctl start database -d RACDB
3. Se non parte, guarda l'ALERT LOG:
   tail -100 $ORACLE_BASE/diag/rdbms/racdb/RACDB1/trace/alert_RACDB1.log
4. Se è corruzione di controlfile:
   RMAN> RESTORE CONTROLFILE FROM AUTOBACKUP;
5. Se è corruzione di un datafile:
   RMAN> RESTORE DATAFILE X; RECOVER DATAFILE X;
6. Se NULLA funziona e il business deve andare avanti:
   → FAILOVER sullo standby:
   DGMGRL> FAILOVER TO 'RACDB_STBY';
   → Chiama il DBA senior / apri un SR con Oracle Support
```

### Scenario 2: "Dev ti dice: 'Ho cancellato tutti i dati dalla tabella CLIENTI per sbaglio!'"

```sql
-- OPZIONE 1: Flashback Table (se < qualche ora e row movement è attivo)
FLASHBACK TABLE clienti TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '2' HOUR);

-- OPZIONE 2: Flashback Query (ricostruisci i dati)
INSERT INTO clienti
SELECT * FROM clienti AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '2' HOUR);

-- OPZIONE 3: Se è troppo tardi per flashback → RMAN point-in-time recovery
-- (ma richiede downtime e restore completo)

-- OPZIONE 4: Auxiliary instance (restore su un altro server, poi estrai i dati)
-- → Questo è il metodo PRO perché non tocchi la produzione
```

### Scenario 3: "CPU al 100% sul server database. Cosa fai?"

```sql
-- 1. È Oracle o altro?
-- top → guarda chi consuma CPU. Se è un processo "ora_*" → è Oracle.

-- 2. Quale sessione?
SELECT s.sid, s.serial#, s.username, s.sql_id,
       p.spid AS os_pid  -- ← questo è il PID che vedi in top!
FROM v$session s
JOIN v$process p ON s.paddr = p.addr
WHERE s.status = 'ACTIVE'
ORDER BY p.spid;

-- 3. Quale SQL?
SELECT sql_text FROM v$sql WHERE sql_id = 'abc123';

-- 4. Perché consuma tanto? (execution plan)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('abc123'));

-- 5. FIX:
-- a) Se è una query nuova con piano cattivo → raccogli statistiche:
EXEC DBMS_STATS.GATHER_TABLE_STATS('SCHEMA', 'TABELLA');
-- b) Se manca un indice → crealo
-- c) Se è un job impazzito → kill session
-- d) Se è un parallel query che ha preso troppi core → limita il DOP
```

### Scenario 4: "L'import Data Pump sta per riempire la FRA. Cosa fai?"

```
1. PRIMA DI TUTTO: controlla la FRA ADESSO:
   SELECT ROUND(space_used*100/space_limit,1) FROM v$recovery_file_dest;

2. Se > 80%:
   a) Pulisci archivelog vecchi con RMAN
   b) Oppure aumenta la FRA: ALTER SYSTEM SET db_recovery_file_dest_size = 150G SCOPE=BOTH;

3. Se > 95% e il DB si sta bloccando:
   a) SOSPENDI l'import (Ctrl+C oppure STOP_JOB nel Data Pump)
   b) Pulisci con RMAN
   c) Riprendi l'import

4. LEZIONE: La prossima volta, PRIMA dell'import
   → controlla FRA e pulisci archivelog
   → valuta NOLOGGING sulle tabelle grandi
```

---

## 11. SOFT SKILLS DBA (Gestione Incidenti & Comunicazione)

### "Come gestisci la crescita professionale?"

**Approccio**: *Cercare sempre ambienti dove si può crescere tecnicamente. Costruire basi solide (Lab RAC, Data Guard, GoldenGate), poi cercare sfide più complesse e team da cui imparare.*

### "Come gestisci una situazione di emergenza alle 3 di notte?"

**Template**: *"Prima di tutto, non faccio nulla senza capire il problema. Leggo l'alert log, verifico lo stato dei servizi, e seguo le procedure operative documentate. Se il fix è semplice (restart, kill session), lo faccio. Se è qualcosa che non ho mai visto, escalo subito al senior DBA e nel frattempo raccolgo tutte le informazioni (screenshot, log, timestamp) per facilitare la diagnosi."*

### "Come ti tieni aggiornato sulle tecnologie Oracle?"

- My Oracle Support (MOS) per le advisory e patch
- Blog: Oracle Base, Tim Hall, Jonathan Lewis, Tanel Poder
- Reddit r/oracle
- Oracle ACE program
- Release notes di ogni nuovo RU

---

## 12. COMANDI CHE DEVI SAPERE A MEMORIA

```sql
-- Istanza
SELECT instance_name, status, version_full FROM v$instance;
SELECT name, open_mode, database_role FROM v$database;

-- Tablespace
SELECT tablespace_name, ROUND(used_percent,1) FROM dba_tablespace_usage_metrics ORDER BY 2 DESC;

-- Sessioni attive
SELECT sid, username, sql_id, event, seconds_in_wait FROM v$session WHERE status='ACTIVE' AND type='USER';

-- Lock
SELECT * FROM v$lock WHERE block=1;

-- Top SQL
SELECT sql_id, elapsed_time/1000000 AS sec, executions FROM v$sql ORDER BY elapsed_time DESC FETCH FIRST 5 ROWS ONLY;

-- Alert log (ultimi errori)
SELECT originating_timestamp, message_text FROM v$diag_alert_ext 
WHERE message_text LIKE '%ORA-%' AND originating_timestamp > SYSDATE-1;

-- Data Guard
SELECT name, value FROM v$dataguard_stats WHERE name LIKE '%lag%';

-- ASM
SELECT name, total_mb, free_mb, ROUND((1-free_mb/total_mb)*100,1) AS pct FROM v$asm_diskgroup;

-- Backup
SELECT input_type, status, start_time FROM v$rman_backup_job_details WHERE start_time > SYSDATE-2 ORDER BY start_time DESC;

-- RAC
srvctl status database -d RACDB
srvctl status listener
crsctl check crs
```

---

## 📌 Note Finali

1. **Disegna**: Quando spieghi, disegna l'architettura. Pensare visivamente aiuta a comunicare.
2. **Sii strutturato**: Rispondi sempre in STEP (1, 2, 3...). L'organizzazione è la chiave.
3. **Ammetti i limiti**: Non conoscere tutto è normale — l'importante è sapere DOVE cercare.
4. **Documenta tutto**: Un lab ben documentato dimostra disciplina professionale.
5. **Continua a studiare**: "Quanti database gestite?", "Che versione usate?", "Avete Data Guard?" — fai sempre domande.
