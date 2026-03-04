# Architettura Oracle: Come Funziona un Database Oracle

> Questo documento spiega l'architettura interna di Oracle Database. Capire questi concetti è fondamentale per ogni DBA: senza questa conoscenza, i comandi che esegui sono solo "magia nera".

---

## 1. Visione d'Insieme

Un database Oracle è composto da due parti fondamentali:

```
┌─────────────────────────────────────────────────────────────────┐
│                     ISTANZA ORACLE                              │
│  (Strutture in MEMORIA + Processi di background)                │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   SGA (System Global Area)               │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │    │
│  │  │  Shared  │ │ Database │ │   Redo   │ │   Large   │  │    │
│  │  │  Pool    │ │ Buffer   │ │   Log    │ │   Pool    │  │    │
│  │  │          │ │ Cache    │ │  Buffer  │ │           │  │    │
│  │  └──────────┘ └──────────┘ └──────────┘ └───────────┘  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌──────────┐  (Ogni sessione utente ha la propria PGA)         │
│  │ PGA Pool │                                                   │
│  └──────────┘                                                   │
│                                                                 │
│  Processi: PMON, SMON, DBWn, LGWR, CKPT, ARCn, MMON, RECO...   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │  Legge/Scrive
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     DATABASE (File su disco)                     │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Datafile     │  │  Online Redo │  │  Controlfile │          │
│  │  (.dbf)       │  │  Log (.log)  │  │  (.ctl)      │          │
│  │               │  │              │  │              │          │
│  │  SYSTEM,      │  │  Gruppo 1    │  │  Metadati    │          │
│  │  SYSAUX,      │  │  Gruppo 2    │  │  del DB      │          │
│  │  USERS,       │  │  Gruppo 3    │  │              │          │
│  │  UNDOTBS      │  │              │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Tempfile     │  │  Archived    │  │  Parameter   │          │
│  │  (.tmp)       │  │  Redo Log    │  │  File (SPFILE)│         │
│  │               │  │  (.arc)      │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

> **Concetto chiave**: L'ISTANZA è in memoria (volatile). Il DATABASE è su disco (persistente). Quando dici "il database è down", intendi che l'istanza è stata fermata. I file su disco esistono sempre.

---

## 2. La SGA (System Global Area) — Il Cuore della Memoria

### 2.1 Database Buffer Cache

```
┌─────────────────────────────────────────┐
│          Database Buffer Cache          │
│                                         │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐  │
│  │Block │ │Block │ │Block │ │Block │  │
│  │  1   │ │  2   │ │  3   │ │ ...  │  │
│  │DIRTY │ │CLEAN │ │FREE  │ │      │  │
│  └──────┘ └──────┘ └──────┘ └──────┘  │
└─────────────────────────────────────────┘
```

- **Cos'è?** Una cache in RAM dei blocchi di dati letti dal disco.
- **Come funziona?** Quando una query legge una tabella, Oracle non legge dal disco ogni volta. Prima controlla se il blocco è già nella Buffer Cache. Se sì → **cache hit** (velocissimo). Se no → **cache miss** (deve leggere dal disco).
- **Dirty vs Clean**: Un blocco "dirty" è stato modificato in memoria ma non ancora scritto su disco. Un blocco "clean" è identico alla copia su disco.
- **Dimensione**: Controllata da `DB_CACHE_SIZE` o `SGA_TARGET` (automatico).

```sql
-- Verifica il cache hit ratio (deve essere > 95%)
SELECT ROUND((1 - (physical.value / (db_block.value + consistent.value))) * 100, 2) AS "Cache Hit Ratio %"
FROM v$sysstat physical, v$sysstat db_block, v$sysstat consistent
WHERE physical.name = 'physical reads'
  AND db_block.name = 'db block gets'
  AND consistent.name = 'consistent gets';
```

### 2.2 Shared Pool

- **Cos'è?** Contiene il **Library Cache** (SQL parsati e piani di esecuzione) e il **Data Dictionary Cache** (metadati delle tabelle).
- **Library Cache**: Quando esegui `SELECT * FROM employees`, Oracle deve "parsare" la query (analisi sintattica, semantica, ottimizzazione). Il risultato viene salvato qui. Se un altro utente esegue la stessa query, Oracle la trova già parsata → 0 overhead.
- **Data Dictionary Cache**: Contiene informazioni su tabelle, colonne, utenti, privilegi. Leggere queste info dal disco ogni volta sarebbe lentissimo.

### 2.3 Redo Log Buffer

- **Cos'è?** Un buffer circolare in RAM dove vengono scritte le "change vectors" (le descrizioni delle modifiche) PRIMA di essere scritte sui Redo Log file su disco.
- **Come funziona?** Ogni `INSERT`, `UPDATE`, `DELETE` genera un redo record. Questo record va nel Redo Log Buffer → poi il processo LGWR lo scrive sul disco nei Redo Log file.
- **Dimensione**: Tipicamente piccolo (pochi MB). Controllato da `LOG_BUFFER`.

### 2.4 Large Pool

- **Cos'è?** Area opzionale usata per operazioni che necessitano di grandi allocazioni di memoria: backup RMAN, operazioni parallele, Shared Server.
- **Senza Large Pool**: Queste operazioni rubano memoria dalla Shared Pool, degradando le performance.

---

## 3. La PGA (Program Global Area) — Memoria Privata

```
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
│    PGA Sessione 1 │  │    PGA Sessione 2 │  │    PGA Sessione 3 │
│  ┌─────────────┐  │  │  ┌─────────────┐  │  │  ┌─────────────┐  │
│  │ Sort Area   │  │  │  │ Sort Area   │  │  │  │ Sort Area   │  │
│  │ Hash Area   │  │  │  │ Hash Area   │  │  │  │ Hash Area   │  │
│  │ Cursori     │  │  │  │ Cursori     │  │  │  │ Cursori     │  │
│  │ Stack Space │  │  │  │ Stack Space │  │  │  │ Stack Space │  │
│  └─────────────┘  │  │  └─────────────┘  │  │  └─────────────┘  │
└───────────────────┘  └───────────────────┘  └───────────────────┘
```

- **Cos'è?** Ogni sessione utente (ogni connessione) ha la propria PGA. Non è condivisa.
- **Cosa contiene?** Sort area (per ORDER BY), hash area (per join), variabili di sessione, cursori aperti.
- **Perché è separata dalla SGA?** Per sicurezza: un utente non può leggere la memoria di un altro.

---

## 4. I Processi di Background — I "Lavoratori" Invisibili

| Processo | Nome Completo | Cosa Fa |
|---|---|---|
| **DBWn** | Database Writer | Scrive i blocchi "dirty" dalla Buffer Cache ai datafile su disco |
| **LGWR** | Log Writer | Scrive i redo record dal Redo Log Buffer ai Online Redo Log file |
| **CKPT** | Checkpoint | Aggiorna i datafile header e il controlfile dopo un checkpoint |
| **SMON** | System Monitor | Recovery automatico all'avvio, pulizia segmenti temporanei |
| **PMON** | Process Monitor | Pulizia dopo il crash di un processo utente (rollback, rilascio lock) |
| **ARCn** | Archiver | Copia gli Online Redo Log pieni negli Archived Redo Log |
| **MMON** | Manageability Monitor | Raccoglie statistiche di performance (AWR snapshots) |
| **RECO** | Recoverer | Risolve le transazioni distribuite in dubbio |

### Il Flusso di Scrittura (FONDAMENTALE!)

```
1. L'utente esegue: UPDATE employees SET salary = 5000 WHERE id = 1;

2. Oracle:
   a) Legge il blocco dal disco nella Buffer Cache (se non c'è già)
   b) Crea una COPIA del blocco PRIMA della modifica → UNDO (nel tablespace UNDO)
   c) Scrive un REDO RECORD nel Redo Log Buffer (descrive la modifica)
   d) Modifica il blocco nella Buffer Cache (il blocco diventa "dirty")
   e) L'utente vede il dato modificato IMMEDIATAMENTE

3. COMMIT:
   a) LGWR scrive il Redo Log Buffer nei Online Redo Log file
   b) Il COMMIT ritorna OK all'utente
   c) Il blocco dirty è ANCORA nella Buffer Cache, NON è stato scritto su disco!
   d) DBWn lo scriverà "quando gli pare" (lazy write)

4. PERCHÉ? Scrivere il redo (sequenziale, piccolo) è velocissimo.
   Scrivere il datafile (random I/O, grande) è lento.
   Oracle garantisce il recovery tramite il redo, non tramite la scrittura immediata.
```

> **Questa è l'idea geniale di Oracle**: Il COMMIT non aspetta che i dati siano scritti su disco. Aspetta SOLO che il REDO sia scritto. Se il server crasha, al riavvio SMON legge il redo e "ri-applica" le modifiche ai datafile. Questo si chiama **Write-Ahead Logging (WAL)**.

---

## 5. I File del Database — Separazione Logica vs Fisica

### 5.1 Struttura LOGICA

```
Database
  └── Tablespace (contenitore logico)
        ├── SYSTEM    → Data Dictionary (metadati)
        ├── SYSAUX    → Componenti ausiliari (AWR, EM, etc.)
        ├── UNDOTBS1  → Undo (per rollback e read consistency)
        ├── TEMP      → Ordinamenti, hash join temporanei
        └── USERS     → Dati utente
              └── Segment (tabella, indice, LOB)
                    └── Extent (blocco contiguo di blocchi)
                          └── Block (unità minima I/O, default 8 KB)
```

### 5.2 Struttura FISICA

```
Filesystem / ASM
  ├── Datafile  → system01.dbf, sysaux01.dbf, users01.dbf
  ├── Tempfile  → temp01.dbf
  ├── Online Redo Log → redo01.log, redo02.log, redo03.log
  ├── Archived Redo Log → arc_00001.arc, arc_00002.arc, ...
  ├── Controlfile → control01.ctl, control02.ctl
  ├── SPFILE → spfileRACDB.ora
  └── Password File → orapwRACDB1
```

### 5.3 La Relazione tra Logica e Fisica

```
┌────────────────────────────────────────────────┐
│              LOGICO                             │
│                                                 │
│  Tablespace "USERS"                             │
│    └── Segment "HR.EMPLOYEES" (tabella)         │
│          ├── Extent 1 (8 blocchi contigui)       │
│          ├── Extent 2 (8 blocchi contigui)       │
│          └── Extent 3 (8 blocchi contigui)       │
│                                                 │
│              ↕ MAPPING ↕                        │
│                                                 │
│              FISICO                             │
│                                                 │
│  Datafile "users01.dbf"                         │
│    ├── Blocco 100-107 (Extent 1 di EMPLOYEES)   │
│    ├── Blocco 200-207 (Extent 2 di EMPLOYEES)   │
│    └── Blocco 300-307 (Extent 3 di EMPLOYEES)   │
└────────────────────────────────────────────────┘
```

> **Perché questa separazione?** Il DBA ragiona in termini logici: "la tabella EMPLOYEES è nel tablespace USERS". Oracle gestisce il fisico: "il blocco 100 del file users01.dbf". Puoi spostare un datafile senza che gli utenti se ne accorgano (la struttura logica non cambia).

---

## 6. Redo Log — Il "Diario" delle Modifiche

### Come Funzionano i Redo Log

```
                    ┌──── FASE 1: Scrittura Circolare ────┐
                    │                                      │
                    ▼                                      │
┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│ Redo     │  │ Redo     │  │ Redo     │                 │
│ Group 1  │→│ Group 2  │→│ Group 3  │─────────────────┘
│ CURRENT  │  │ INACTIVE │  │ INACTIVE │
│ (attivo) │  │          │  │          │
└──────────┘  └──────────┘  └──────────┘
     │
     │ Quando pieno → Log Switch
     │
     ▼
┌──────────┐
│ ARCn     │ → Copia il gruppo pieno nell'Archived Redo Log
│ (Archiver)│   (SOLO se ARCHIVELOG MODE è attivo)
└──────────┘
     │
     ▼
┌──────────┐
│ Archived │ → arc_00001.arc, arc_00002.arc, ...
│ Redo Log │   Questi vengono spediti allo Standby (Data Guard)
└──────────┘
```

- **Online Redo Log**: File circolari (minimo 2 gruppi, consigliati 3+). LGWR scrive qui ogni COMMIT.
- **Log Switch**: Quando un gruppo di redo è pieno, LGWR passa al gruppo successivo.
- **Archived Redo Log**: Copia del redo "pieno", creata da ARCn. Necessaria per recovery e Data Guard.
- **ARCHIVELOG MODE**: Se attivo, Oracle archivia ogni redo prima di sovrascriverlo. Se disattivo, il redo viene sovrascritto e perdi la possibilità di recovery point-in-time.

### Perché i Redo Log sono così importanti?

1. **Recovery dopo crash**: Al riavvio, SMON legge i redo e ri-applica le transazioni committate che DBWn non aveva ancora scritto su disco.
2. **Data Guard**: I redo vengono spediti allo standby per mantenerlo sincronizzato.
3. **Flashback**: Permettono il flashback database (tornare indietro nel tempo).
4. **GoldenGate**: L'Extract legge i redo (tramite LogMiner) per catturare le modifiche.

---

## 7. Undo Segments — Il "Viaggio nel Tempo"

### Cos'è l'Undo?

L'Undo è il meccanismo con cui Oracle salva la **versione precedente** dei dati PRIMA di modificarli. È fondamentale per 3 operazioni critiche.

```
┌──────────────────────────────────────────────────────────────────┐
│                    UNDO — 3 Funzioni Vitali                       │
│                                                                   │
│  1. ROLLBACK                    2. READ CONSISTENCY               │
│  ┌────────────┐                 ┌────────────────────────┐       │
│  │ UPDATE ... │                 │ Utente A: UPDATE       │       │
│  │ ROLLBACK;  │                 │ salary = 5000          │       │
│  │            │                 │ (non ha ancora fatto   │       │
│  │ Oracle     │                 │  COMMIT)               │       │
│  │ legge UNDO │                 │                        │       │
│  │ e ripristina│                │ Utente B: SELECT       │       │
│  │ i dati     │                 │ salary FROM employees  │       │
│  │ originali  │                 │ → Vede 3000 (dal UNDO) │       │
│  └────────────┘                 │ → NON vede 5000!       │       │
│                                 └────────────────────────┘       │
│                                                                   │
│  3. CRASH RECOVERY                                               │
│  ┌────────────────────────────────────────────┐                  │
│  │ Se il server crasha durante una transazione│                  │
│  │ non committata, al riavvio SMON usa l'UNDO │                  │
│  │ per fare ROLLBACK automatico               │                  │
│  └────────────────────────────────────────────┘                  │
└──────────────────────────────────────────────────────────────────┘
```

### Come Funzionano gli Undo Segments — Step by Step

```
Transazione: UPDATE employees SET salary = 5000 WHERE id = 1;
                                                (vecchio valore: 3000)

Passo 1: Oracle trova il blocco nella Buffer Cache (o lo legge dal disco)

Passo 2: PRIMA di modificare, Oracle:
         ┌──────────────────────────────────┐
         │ Scrive nell'UNDO TABLESPACE:     │
         │                                  │
         │ "Riga ID=1, Colonna SALARY,      │
         │  Vecchio valore: 3000"           │
         │                                  │
         │ + Genera REDO per l'UNDO stesso  │ ← Sì, Oracle fa il redo
         │   (per proteggere anche l'undo!) │   dell'undo!
         └──────────────────────────────────┘

Passo 3: Modifica il blocco nella Buffer Cache → salary = 5000 (dirty block)

Passo 4: Genera REDO per la modifica stessa

Passo 5: Se COMMIT → L'undo diventa "expired" (può essere sovrascritto)
         Se ROLLBACK → Oracle legge l'undo e ripristina salary = 3000
```

### Parametri Chiave

```sql
-- Tipo di gestione UNDO (deve essere AUTO!)
SHOW PARAMETER undo_management;     -- AUTO (non usare mai MANUAL)

-- Nome del tablespace UNDO attivo
SHOW PARAMETER undo_tablespace;     -- UNDOTBS1

-- Per quanto Oracle conserva l'undo dopo il COMMIT
SHOW PARAMETER undo_retention;      -- 900 (secondi = 15 minuti)

-- Verifica spazio UNDO usato
SELECT tablespace_name, status, 
       ROUND(SUM(bytes)/1024/1024) AS MB
FROM dba_undo_extents 
GROUP BY tablespace_name, status;
-- Status: ACTIVE = in uso, UNEXPIRED = ancora utile, EXPIRED = riusabile
```

### L'Errore Più Temuto: ORA-01555 "Snapshot Too Old"

```
Scenario:
  09:00 - Utente B inizia una query lunga su una tabella da 10 milioni di righe
  09:05 - Utente A fa UPDATE + COMMIT su alcune righe della stessa tabella
  09:06 - Oracle sovrascrive l'UNDO di A (perché è expired)
  09:10 - La query di B arriva alle righe modificate da A
         → B ha bisogno della versione "vecchia" (dal suo SCN)
         → Ma l'UNDO è stato sovrascritto!
         → ORA-01555: Snapshot too old !!!

Soluzioni:
  1. Aumenta undo_retention (es. ALTER SYSTEM SET undo_retention=3600)
  2. Aumenta la dimensione dell'UNDO tablespace
  3. Garantisci la retention: ALTER TABLESPACE UNDOTBS1 RETENTION GUARANTEE;
```

### Undo in RAC — Ogni Istanza ha il Proprio!

```
┌──────────────────┐        ┌──────────────────┐
│   Istanza 1      │        │   Istanza 2      │
│   (rac1)         │        │   (rac2)         │
│                  │        │                  │
│   UNDOTBS1 ✅    │        │   UNDOTBS2 ✅    │
│   (proprio!)     │        │   (proprio!)     │
└────────┬─────────┘        └────────┬─────────┘
         │                           │
         └─────────┬─────────────────┘
                   ▼
         ┌──────────────────┐
         │  +DATA (ASM)     │
         │  UNDOTBS1.dbf    │    Fisicamente sullo stesso
         │  UNDOTBS2.dbf    │    storage condiviso!
         └──────────────────┘
```

> **Perché undo tablespace separati?** In un RAC, ogni istanza gestisce le proprie transazioni. Se l'istanza 1 crasha, l'istanza 2 usa UNDOTBS1 per fare il recovery delle transazioni incomplete dell'istanza 1.

```sql
-- In DBCA scegli "Custom Database" e crea UNDO separati:
-- UNDOTBS1 per istanza 1 (RACDB1)
-- UNDOTBS2 per istanza 2 (RACDB2)

-- Verifica assegnazione
SELECT inst_id, name, value FROM gv$parameter WHERE name = 'undo_tablespace';
```

---

## 7b. Temp Tablespace — L'Area di Lavoro Temporanea

### Cos'è il Temp Tablespace?

Il Temp è l'area dove Oracle mette i dati **temporanei** che non entrano in memoria (PGA). È come un "banco da lavoro" di emergenza.

```
Situazione: ORDER BY su 10 milioni di righe

┌──────────────────────────────────────────────┐
│         PGA (Sort Area - in RAM)              │
│                                              │
│  ┌──────┐ ┌──────┐ ┌──────┐                 │
│  │ Riga │ │ Riga │ │ Riga │ ... 500.000     │
│  │  1   │ │  2   │ │  3   │     righe max   │
│  └──────┘ └──────┘ └──────┘                 │
│                                              │
│  La PGA è PIENA! Non entra più niente!       │
│  → Oracle "spilla" i dati sul TEMP           │
└──────────────────────┬───────────────────────┘
                       │ "Sort Spill" (Disk Sort)
                       ▼
┌──────────────────────────────────────────────┐
│         TEMP TABLESPACE (su disco)            │
│                                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│  │ Run 1    │ │ Run 2    │ │ Run 3    │ ... │
│  │ (righe   │ │ (righe   │ │ (righe   │     │
│  │ ordinate │ │ ordinate │ │ ordinate │     │
│  │ 1-500K)  │ │ 500K-1M) │ │ 1M-1.5M)│     │
│  └──────────┘ └──────────┘ └──────────┘     │
│                                              │
│  Oracle poi fa un MERGE delle run ordinate   │
│  per produrre il risultato finale            │
└──────────────────────────────────────────────┘
```

### Quando Viene Usato il Temp?

| Operazione | Perché usa Temp |
|---|---|
| `ORDER BY` | Ordinamento di più righe di quante ne entrano in PGA |
| `GROUP BY` | Hash aggregation overflow |
| `DISTINCT` | Rimozione duplicati con hash overflow |
| `UNION` (non `UNION ALL`) | Unione con deduplicazione |
| `Hash Join` | Quando la hash table non entra in PGA |
| `CREATE INDEX` | Ordinamento dei dati per l'indice |
| `WITH ... AS (query)` | Global Temporary Table implicita |
| `Parallel Query` | Buffer temporanei per i processi paralleli |

### Monitoraggio Temp

```sql
-- Quanto TEMP è usato in questo momento
SELECT tablespace_name, 
       ROUND(tablespace_size * 8 / 1024) AS total_mb,
       ROUND(allocated_space * 8 / 1024) AS allocated_mb,
       ROUND(free_space * 8 / 1024) AS free_mb
FROM dba_temp_free_space;

-- CHI sta usando il TEMP (quale sessione)
SELECT s.sid, s.serial#, s.username, 
       ROUND(su.blocks * 8 / 1024) AS temp_mb,
       s.sql_id
FROM v$sort_usage su
JOIN v$session s ON s.saddr = su.session_addr
ORDER BY su.blocks DESC;

-- Quanti "sort disk" vs "sort memory" (vuoi più memory!)
SELECT name, value FROM v$sysstat 
WHERE name IN ('sorts (disk)', 'sorts (memory)');
-- Se sorts(disk) è alto → PGA troppo piccola o query inefficienti
```

### Temp in RAC — Temp Group

```
┌──────────────────┐        ┌──────────────────┐
│   Istanza 1      │        │   Istanza 2      │
│   usa TEMP ✅    │        │   usa TEMP ✅    │
│                  │        │                  │
│   Stesso TEMP!   │        │   Stesso TEMP!   │
└────────┬─────────┘        └────────┬─────────┘
         │                           │
         └─────────┬─────────────────┘
                   ▼
         ┌──────────────────┐
         │  TEMP tablespace │    Condiviso tra le istanze
         │  temp01.dbf      │    (a differenza dell'UNDO)
         └──────────────────┘
```

> **Differenza con l'Undo**: L'UNDO è separato per istanza. Il TEMP è condiviso (ma puoi creare Temp Groups per distribuire il carico).

---

## 8. ASM (Automatic Storage Management) — Lo Storage "Intelligente"

```
┌──────────────────────────────────────────────────┐
│                    ASM Instance                   │
│                                                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐│
│  │ Disk Group  │ │ Disk Group  │ │ Disk Group  ││
│  │ +CRS        │ │ +DATA       │ │ +FRA        ││
│  │             │ │             │ │             ││
│  │ OCR, VD    │ │ Datafile,   │ │ Archivelog, ││
│  │             │ │ Controlfile │ │ Backup,     ││
│  │             │ │ Redo Log    │ │ Flashback   ││
│  │             │ │             │ │             ││
│  │ Dischi:     │ │ Dischi:     │ │ Dischi:     ││
│  │ /dev/sdb1   │ │ /dev/sdc1   │ │ /dev/sdd1   ││
│  └─────────────┘ └─────────────┘ └─────────────┘│
└──────────────────────────────────────────────────┘
```

- **Cos'è?** Un volume manager e filesystem integrato in Oracle, progettato specificamente per il database.
- **Perché non usare un filesystem normale (ext4, xfs)?** ASM fa automaticamente striping (distribuire i dati su più dischi per parallelismo) e mirroring (copie di sicurezza). In un RAC, ASM gestisce l'accesso concorrente ai dati da più nodi.
- **Disk Group**: Un "contenitore" logico che raggruppa uno o più dischi fisici.

---

## 9. Oracle RAC — Come Funziona il Cluster

```
┌────────────────────┐        ┌────────────────────┐
│    Istanza 1       │        │    Istanza 2       │
│    (rac1)          │        │    (rac2)          │
│                    │        │                    │
│  SGA 1             │        │  SGA 2             │
│  ┌──────────────┐  │ Cache  │  ┌──────────────┐  │
│  │Buffer Cache 1│←─│─Fusion─│→│Buffer Cache 2│  │
│  │              │  │        │  │              │  │
│  └──────────────┘  │        │  └──────────────┘  │
│                    │        │                    │
│  Background Procs  │        │  Background Procs  │
│  + GCS (LMS)       │        │  + GCS (LMS)       │
│  + GES (LMD)       │        │  + GES (LMD)       │
└────────┬───────────┘        └────────┬───────────┘
         │                              │
         │    Interconnect Privato      │
         │    (10 GbE consigliato)       │
         │◄────────────────────────────►│
         │                              │
         └──────────┬───────────────────┘
                    │
                    ▼
         ┌──────────────────┐
         │  Shared Storage  │
         │  (ASM)           │
         │  +DATA, +FRA     │
         └──────────────────┘
```

### Cache Fusion

- **Cos'è?** Il meccanismo che permette a due istanze di condividere i blocchi in memoria via rete, SENZA scrivere su disco.
- **Esempio**: L'istanza 1 modifica il blocco 100. L'istanza 2 ha bisogno del blocco 100. Invece di aspettare che DBWn scriva il blocco su disco e poi rileggerlo, l'istanza 1 spedisce il blocco direttamente via interconnect all'istanza 2.
- **Performance**: Cache Fusion è veloce quanto una lettura da disco SSD, se l'interconnect è veloce (10 GbE o InfiniBand).

### GCS e GES

- **GCS (Global Cache Service)**: Gestisce i blocchi condivisi tra i nodi. Tiene traccia di chi ha quale blocco e in che stato (shared, exclusive).
- **GES (Global Enqueue Service)**: Gestisce i lock distribuiti. Se l'istanza 1 fa un lock su una riga, GES assicura che l'istanza 2 non possa modificarla.

---

## 10. Ciclo di Vita di una Query — Dall'Utente al Disco

```
1. UTENTE: SELECT * FROM hr.employees WHERE department_id = 10;

2. SERVER PROCESS (dedicato all'utente):
   a) PARSE:
      - Controlla la sintassi SQL
      - Controlla i permessi dell'utente
      - Cerca nella Library Cache se la query è già parsata
      - Se no → Hard Parse (genera il piano di esecuzione)
      - Se sì → Soft Parse (riusa il piano esistente)

   b) EXECUTE:
      - Segue il piano di esecuzione
      - Cerca i blocchi nella Buffer Cache
      - Se non presenti → legge dal disco (Physical Read)
      - Filtra le righe secondo WHERE department_id = 10

   c) FETCH:
      - Restituisce le righe all'utente

3. Se la query è un UPDATE:
   a) Stesso PARSE e EXECUTE
   b) Genera UNDO record (valore precedente)
   c) Genera REDO record (descrizione della modifica)
   d) Modifica il blocco nella Buffer Cache

4. COMMIT:
   a) LGWR scrive il redo dal buffer ai redo log file
   b) Rilascia il lock sulla riga
   c) Restituisce OK all'utente
```

---

## Schema Riassuntivo

| Componente | Tipo | Scopo | Persistente? |
|---|---|---|---|
| SGA | Memoria | Cache dati, SQL, redo | No (volatile) |
| PGA | Memoria | Sort, hash, variabili sessione | No (volatile) |
| Datafile | Disco | Dati delle tabelle/indici | Sì |
| Online Redo Log | Disco | Record delle modifiche recenti | Sì (circolare) |
| Archived Redo Log | Disco | Storico delle modifiche | Sì |
| Controlfile | Disco | Metadati del database | Sì |
| SPFILE | Disco | Parametri di configurazione | Sì |
| Undo Tablespace | Disco | Rollback + Read Consistency | Sì |
| Temp Tablespace | Disco | Sort/hash temporanei | Sì |
