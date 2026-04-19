# 🔒 Guida Completa: Locking, Concurrency e Wait Events — Come Oracle Gestisce il Traffico

> **Questa guida** spiega come Oracle permette a migliaia di utenti di lavorare sullo stessi dati senza corromperli, come diagnosticare i problemi di performance leggendo i Wait Events, e perché Oracle è l'unico RDBMS dove "readers never block writers".
>
> **Fonti**: Oracle Database Concepts 19c — Data Concurrency and Consistency. Oracle Database Performance Tuning Guide 19c.

---

## 📑 Indice

1. [Il Principio Fondamentale: MVCC](#-1-mvcc--readers-never-block-writers)
2. [Row-Level Locking](#-2-row-level-locking)
3. [ITL — Interested Transaction List](#-3-itl--interested-transaction-list)
4. [Tipi di Lock Oracle](#-4-tipi-di-lock)
5. [Deadlock](#-5-deadlock)
6. [Wait Events — Leggere la Matrice](#-6-wait-events)
7. [I 15 Wait Events Più Importanti](#-7-i-15-wait-events-più-importanti)
8. [Metodologia di Diagnosi](#-8-metodologia-di-diagnosi)
9. [Domande da Colloquio](#-9-domande-da-colloquio)
10. [Comandi di Verifica](#-10-comandi-di-verifica)

---

## 🌐 1. MVCC — Readers Never Block Writers

### Il Concetto Rivoluzionario

```
REGOLA D'ORO DI ORACLE:
Chi LEGGE non blocca MAI chi SCRIVE.
Chi SCRIVE non blocca MAI chi LEGGE.

In PostgreSQL/MySQL (MVCC diverso), questo non è sempre vero.
In Oracle, SEMPRE.
```

### Come Funziona

Quando la **Sessione A** modifica una riga e la **Sessione B** la legge:

```
Sessione A:  UPDATE emp SET salary = 5000 WHERE id = 1;  (non ha fatto COMMIT)
Sessione B:  SELECT salary FROM emp WHERE id = 1;

Cosa vede B?  → salary = 3000 (il valore VECCHIO!)
```

**Perché?** Perché Oracle usa gli **Undo Segments**:

1. La Sessione A scrive il valore nuovo (5000) nel blocco in memoria.
2. Ma prima, Oracle ha salvato il valore vecchio (3000) nell'**Undo Segment**.
3. Quando la Sessione B legge il blocco, vede che è stato modificato da una transazione non committata.
4. Oracle va a prendere il valore vecchio dall'Undo e lo mostra a B.
5. B vede un **Consistent Read** (lettura consistente) → il dato come era al momento dell'inizio della sua query.

> [!TIP]
> Questo meccanismo si chiama **Read Consistency** ed è ciò che rende Oracle unico. In altri database, la Sessione B sarebbe **bloccata** in attesa che A faccia COMMIT. In Oracle, B continua tranquillamente.

---

## 🔐 2. Row-Level Locking

Oracle usa **lock a livello di riga**, non a livello di tabella o pagina.

```
Sessione A: UPDATE emp SET salary = 5000 WHERE id = 1;
    → Blocca SOLO la riga con id = 1

Sessione B: UPDATE emp SET salary = 6000 WHERE id = 2;
    → Può procedere! La riga id=2 non è bloccata.

Sessione C: UPDATE emp SET salary = 7000 WHERE id = 1;
    → BLOCCATA! Deve aspettare che A faccia COMMIT o ROLLBACK.
    → Wait event: "enq: TX - row lock contention"
```

### Caratteristiche Uniche di Oracle

| Caratteristica | Oracle | Alcuni altri RDBMS |
|---|---|---|
| **Lock Escalation** | ❌ Mai. 1 milione di righe = 1 milione di lock. | ✅ Row → Page → Table (automatico) |
| **SELECT blocca?** | ❌ Mai | Dipende dall'isolation level |
| **Lock storage** | Dentro il blocco dati (ITL) | Tabelle di lock separate in memoria |

---

## 📋 3. ITL — Interested Transaction List

### Cos'è

L'**ITL** è una struttura dati nell'**header di ogni blocco Oracle** (8KB). È il "registro presenze" delle transazioni che stanno modificando righe in quel blocco.

### Come Funziona

```
┌─────────────────────────────────────────┐
│         BLOCCO ORACLE (8KB)              │
│                                          │
│  ┌───────────────────────────────────┐  │
│  │       BLOCK HEADER                │  │
│  │                                    │  │
│  │  ITL Slot 1: TxID=10.5.312        │  │
│  │              Undo Block=file#3     │  │
│  │              Lock Count=5          │  │
│  │              Flag=C--- (Committed) │  │
│  │                                    │  │
│  │  ITL Slot 2: TxID=10.12.890       │  │
│  │              Undo Block=file#7     │  │
│  │              Lock Count=2          │  │
│  │              Flag=---- (Active)    │  │
│  │                                    │  │
│  │  ITL Slot 3: [VUOTO]              │  │
│  └───────────────────────────────────┘  │
│                                          │
│  ┌───────────────────────────────────┐  │
│  │       ROW DATA                     │  │
│  │  Row 1: (locked by ITL slot 2)     │  │
│  │  Row 2: (locked by ITL slot 2)     │  │
│  │  Row 3: (free)                     │  │
│  │  Row 4: (free)                     │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

- **INITRANS**: Numero iniziale di slot ITL preconfigurati nel blocco. Default: 1 per le tabelle, 2 per gli indici.
- **MAXTRANS**: Limite massimo di slot ITL. Dalla 10g è fisso a 255.
- **Problema**: Se tutte le slot ITL sono occupate e non c'è spazio per crearne di nuove, una sessione deve aspettare → Wait event: `enq: TX - allocate ITL entry`.

```sql
-- Diagnosticare problemi ITL
SELECT owner, object_name, statistic_name, value
FROM v$segment_statistics
WHERE statistic_name = 'ITL waits'
  AND value > 0
ORDER BY value DESC;
-- Se value > 0: aumentare INITRANS su quella tabella/indice

ALTER TABLE schema.tabella MOVE INITRANS 4;  -- Default è 1
ALTER INDEX schema.indice REBUILD INITRANS 4; -- Default è 2
```

---

## 🏷️ 4. Tipi di Lock

### 4.1 DML Lock (Data Lock)

| Lock | Livello | Quando | Compatibilità |
|---|---|---|---|
| **TX** (Transaction) | Riga | INSERT, UPDATE, DELETE, SELECT FOR UPDATE | Esclusivo per riga |
| **TM** (Table DML) | Tabella | Qualsiasi DML sulla tabella | Row-Share, Row-Exclusive, Share, ecc. |

### 4.2 DDL Lock (Dictionary Lock)

Proteggono la definizione degli oggetti durante le operazioni DDL (ALTER TABLE, DROP INDEX).

### 4.3 Latch e Mutex

| Tipo | Cosa Protegge | Durata |
|---|---|---|
| **Latch** | Strutture interne in SGA (buffer cache, shared pool) | Microsecondi |
| **Mutex** | Singoli oggetti (cursor, pin) | Microsecondi |

> [!NOTE]
> I latch e i mutex **non** sono lock classici. Sono meccanismi di serializzazione interni ultra-veloci. Se diventano un collo di bottiglia, è un segnale di problemi architetturali profondi (troppi hard parse, hot blocks).

---

## 💀 5. Deadlock

### Cos'è

Un deadlock è un **abbraccio mortale** tra due sessioni che si aspettano a vicenda:

```
Sessione A: UPDATE emp SET salary=5000 WHERE id=1;  (blocca riga 1)
Sessione B: UPDATE emp SET salary=6000 WHERE id=2;  (blocca riga 2)

Sessione A: UPDATE emp SET salary=7000 WHERE id=2;  → Aspetta B...
Sessione B: UPDATE emp SET salary=8000 WHERE id=1;  → Aspetta A...

→ DEADLOCK! Nessuno può procedere.
```

### Come Oracle lo Risolve

1. Oracle **rileva** il deadlock automaticamente (entro ~3 secondi).
2. Oracle sceglie **una** delle due sessioni come "vittima".
3. Fa il **rollback solo dello statement** (non dell'intera transazione) della vittima.
4. Ritorna l'errore `ORA-00060: deadlock detected while waiting for resource`.
5. Genera un **trace file** con il dettaglio (chi bloccava chi).

```sql
-- Dove trovare il trace file
SELECT value FROM v$diag_info WHERE name = 'Default Trace File';
-- Cerca nel trace: "Deadlock graph"
```

> [!WARNING]
> Un deadlock è **SEMPRE** un bug dell'applicazione. Non è un problema del database. La soluzione è **ordinare le operazioni** nello stesso modo in tutte le transazioni (es: aggiornare sempre per ID crescente).

---

## 📊 6. Wait Events — Leggere la Matrice

### Il Concetto

Una sessione Oracle può trovarsi in solo **due stati**:
1. **ON CPU**: Sta lavorando (calcoli, parse, esecuzione).
2. **IN WAIT**: Sta aspettando qualcosa (disco, lock, rete, memoria).

Se il database è lento, la domanda è: **quanto tempo passano le sessioni in wait, e su COSA aspettano?**

### Wait Classes

| Wait Class | Cosa Significa | Esempio |
|---|---|---|
| **User I/O** | Attese per I/O da disco | `db file sequential read` |
| **System I/O** | I/O del controlfile/redo | `log file parallel write` |
| **Commit** | Attese al momento del COMMIT | `log file sync` |
| **Concurrency** | Contesa per risorse condivise | `buffer busy waits`, `cursor: pin S` |
| **Configuration** | Parametri impostati male | `log buffer space`, `free buffer waits` |
| **Network** | Attesa di dati dalla rete | `SQL*Net message from client` (idle!) |
| **Cluster** | Contesa tra nodi RAC | `gc buffer busy`, `gc cr block busy` |
| **Idle** | La sessione non sta facendo nulla | `SQL*Net message from client` → **IGNORARE** |

---

## 🏆 7. I 15 Wait Events Più Importanti

### I/O

| Wait Event | Significato | Diagnosi |
|---|---|---|
| `db file sequential read` | Legge 1 blocco da disco (index scan) | SQL non ottimale, indice non selettivo, cache troppo piccola |
| `db file scattered read` | Legge N blocchi da disco (full table scan) | Manca un indice, tabella troppo grande per la query |
| `direct path read` | Lettura diretta dal disco (bypass cache) | Sort su disco (PGA piccola), parallel query |
| `direct path read temp` | Sort/hash su temp tablespace | PGA_AGGREGATE_TARGET troppo basso |

### Commit / Redo

| Wait Event | Significato | Diagnosi |
|---|---|---|
| `log file sync` | Il COMMIT aspetta che LGWR scriva il redo | Troppi mini-commit, redo log su disco lento |
| `log file parallel write` | LGWR sta scrivendo il redo su disco | I/O su redo log lento; metti i redo su SSD/NVMe |
| `log buffer space` | Il Redo Log Buffer è pieno | Buffer troppo piccolo o LGWR troppo lento |

### Concurrency

| Wait Event | Significato | Diagnosi |
|---|---|---|
| `buffer busy waits` | Due sessioni vogliono lo stesso blocco | Hot block; indice reverse key, hash parti table |
| `enq: TX - row lock contention` | Sessione aspetta il rilascio di un row lock | Transazione lunga che blocca, applicazione mal disegnata |
| `enq: TX - allocate ITL entry` | ITL piena nel blocco | Aumentare INITRANS |
| `cursor: pin S wait on X` | Contesa sullo shared pool per un cursor | Hard parse eccessivi, usare bind variables |
| `library cache lock` | DDL concorrente sulla stessa struttura | Evitare DDL durante carico OLTP |

### RAC (Cluster)

| Wait Event | Significato | Diagnosi |
|---|---|---|
| `gc buffer busy acquire/release` | Block contention tra nodi RAC | Hot block cross-instance; partizionare l'tabella |
| `gc cr/current block busy` | Cache Fusion transfer bloccato | Interconnect lenta o saturata |

---

## 🔬 8. Metodologia di Diagnosi

### Il Metodo "Top-Down" (Raccomandato da Oracle)

```
Step 1: Quanto "DB Time" c'è?
        → Se DB Time >> CPU Time della macchina: il DB è sovraccarico

Step 2: Dove va il DB Time?
        → AWR Report → "Top 5 Timed Foreground Events"

Step 3: Qual è la Wait Class dominante?
        → User I/O? → Tuning SQL
        → Commit?   → Tuning redo/transazioni
        → Concurrency? → Tuning locking/parsing

Step 4: Qual è il SQL colpevole?
        → SQL_ID dall'ASH → DBMS_XPLAN.DISPLAY_CURSOR
```

```sql
-- Step rapido: cosa sta aspettando il database ADESSO?
SELECT wait_class, event, COUNT(*) AS sessions_waiting
FROM v$session
WHERE status = 'ACTIVE'
  AND wait_class != 'Idle'
GROUP BY wait_class, event
ORDER BY sessions_waiting DESC;
```

---

## 🎯 9. Domande da Colloquio

| Domanda | Risposta |
|---|---|
| Cos'è l'ITL? | Una struttura nell'header del blocco che registra le transazioni attive su quel blocco. Ogni slot = 1 transazione. |
| Oracle fa lock escalation? | No, mai. Ogni riga ha il suo lock. Anche con 10 milioni di righe. |
| Cos'è un Consistent Read? | Un blocco letto dall'Undo per ricostruire la versione dei dati al momento dell'inizio della query (MVCC). |
| `db file sequential read` vs `scattered read`? | Sequential = 1 blocco (index), Scattered = multi-blocco (full scan). |
| Come diagnostichi un database lento? | Top-Down: guardo l'AWR → Top 5 Events → Wait Class → SQL_ID → Piano di esecuzione. |
| Cos'è un deadlock in Oracle? | Due sessioni si aspettano a vicenda. Oracle lo rileva in ~3 sec, fa rollback dello statement di una vittima, e restituisce ORA-00060. |

---

## 🔍 10. Comandi di Verifica

```sql
-- Sessioni bloccate ADESSO
SELECT s.sid, s.serial#, s.username, s.event,
       s.blocking_session, s.seconds_in_wait
FROM v$session s
WHERE s.blocking_session IS NOT NULL;

-- Top Wait Events dell'istanza
SELECT event, wait_class, total_waits,
       ROUND(time_waited_micro/1000000, 1) AS time_sec,
       ROUND(average_wait/100, 2) AS avg_wait_ms
FROM v$system_event
WHERE wait_class != 'Idle'
ORDER BY time_waited_micro DESC
FETCH FIRST 15 ROWS ONLY;

-- Top SQL per CPU (dall'ASH, ultima ora)
SELECT sql_id, COUNT(*) AS samples,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM v$active_session_history
WHERE session_state = 'ON CPU'
  AND sample_time > SYSDATE - 1/24
GROUP BY sql_id
ORDER BY samples DESC
FETCH FIRST 10 ROWS ONLY;

-- Top SQL per Wait (dall'ASH, ultima ora) 
SELECT sql_id, event, COUNT(*) AS samples
FROM v$active_session_history
WHERE session_state = 'WAITING'
  AND sample_time > SYSDATE - 1/24
  AND wait_class != 'Idle'
GROUP BY sql_id, event
ORDER BY samples DESC
FETCH FIRST 10 ROWS ONLY;
```

---

> **Riferimenti**: Oracle Database Concepts 19c — Chapter 9: Data Concurrency and Consistency.
> Oracle Database Performance Tuning Guide 19c — Chapter 4: Configuring a Database for Performance.
> Oracle Wait Interface: A Practical Guide to Performance Diagnostics & Tuning (Richmond Shee, Kirtikumar Deshpande, K. Gopalakrishnan).
