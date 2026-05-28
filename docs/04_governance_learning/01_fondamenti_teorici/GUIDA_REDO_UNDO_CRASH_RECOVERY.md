# 🔄 Guida Completa: Redo Log, Undo e Crash Recovery — Gli Ingranaggi della Sopravvivenza

> **Questa guida** spiega il meccanismo che permette a Oracle di **non perdere mai un singolo COMMIT**, anche se il server esplode durante una transazione. Se capisci Redo + Undo, capisci Oracle al 90%.
>
> **Fonti**: Oracle Database Concepts 19c, Oracle Database Administrator's Guide 19c, Oracle Database Backup and Recovery User's Guide 19c.

---

## 📑 Indice

1. [Il Patto Fondamentale: Write-Ahead Logging](#-1-write-ahead-logging)
2. [Redo Log — Il Registratore di Volo](#-2-redo-log)
3. [Undo — La Macchina del Tempo](#-3-undo)
4. [I Processi Background Chiave](#-4-i-processi-background)
5. [Checkpoint — Il Punto di Salvataggio](#-5-checkpoint)
6. [Crash Recovery — Come Oracle Risorge](#-6-crash-recovery)
7. [Multiplexing — Proteggere il Redo](#-7-multiplexing-del-redo-log)
8. [Redo Log Sizing — Quanto Devono Essere Grandi?](#-8-redo-log-sizing)
9. [Domande da Colloquio](#-9-domande-da-colloquio)
10. [Comandi di Verifica](#-10-comandi-di-verifica)

---

## 📝 1. Write-Ahead Logging

```
LA REGOLA D'ORO DI ORACLE (non negoziabile):
"Prima di scrivere un dato modificato sul disco, DEVI PRIMA scrivere
la registrazione della modifica (redo) sul disco."

PRIMA il redo → POI il dato.
MAI il contrario.
```

Perché?
- Se il server crasha **dopo** aver scritto il redo ma **prima** di aver scritto il dato: Oracle rilegge il redo e riapplica la modifica. **Nessuna perdita.**
- Se il server crasha **dopo** aver scritto il dato ma **senza** il redo: Oracle non saprebbe cosa è stato modificato. **Corruzione silenziosa.**

---

## 📼 2. Redo Log — Il Registratore di Volo

### 2.1 Cos'è

Il Redo Log è l'equivalente della **scatola nera** di un aereo. Registra **ogni singola modifica** fatta al database: ogni INSERT, UPDATE, DELETE, ogni modifica di segmento, ogni DDL.

### 2.2 Come Funziona

```
Flusso di una transazione:

1. L'utente esegue: UPDATE emp SET salary=5000 WHERE id=1;

2. Oracle:
   a) Legge il blocco dati dal disco al Buffer Cache (se non c'è già)
   b) Scrive il "BEFORE IMAGE" nell'Undo Segment (valore vecchio)
   c) Modifica il blocco nel Buffer Cache (valore nuovo)
   d) Genera una REDO ENTRY nel Redo Log Buffer (descrive la modifica)
   e) Il blocco nel Buffer Cache è ora "DIRTY" (modificato ma non su disco)

3. L'utente esegue: COMMIT;

4. Oracle:
   a) LGWR scrive IMMEDIATAMENTE il Redo Log Buffer su disco (redo log file)
   b) LGWR scrive il "commit record" nel redo log
   c) Il COMMIT ritorna all'utente (velocissimo, <1ms)
   d) Il blocco dirty resta nel Buffer Cache
      (DBWR lo scriverà su disco PIÙ TARDI, quando vuole lui)
```

> [!IMPORTANT]
> **Il punto chiave**: Al momento del COMMIT, il **dato** non è ancora su disco! Solo il **redo** è su disco. Il dato verrà scritto dal DBWR in futuro (quando il buffer cache ha bisogno di spazio o durante un checkpoint). Questo è il segreto della velocità di Oracle: COMMIT non aspetta la scrittura dei dati.

### 2.3 Struttura dei Redo Log

I Redo Log files sono organizzati in **gruppi** che vengono usati in modo **circolare**:

```
+----------+    +----------+    +----------+
| Gruppo 1 |---▶| Gruppo 2 |---▶| Gruppo 3 |--+
| CURRENT  |    | ACTIVE   |    | INACTIVE |  |
| (LGWR    |    | (serve   |    | (non     |  |
|  scrive  |    |  ancora  |    |  serve   |  |
|  qui)    |    |  per     |    |  più)    |  |
|          |    |  recovery|    |          |  |
+----------+    +----------+    +----------+  |
     ^                                         |
     +-----------------------------------------+
                    LOG SWITCH (circolare)
```

| Stato | Significato |
|---|---|
| **CURRENT** | LGWR sta scrivendo qui adesso |
| **ACTIVE** | Contiene redo che servono ancora per il crash recovery (non ancora checkpointed) |
| **INACTIVE** | Tutti i dirty buffers sono già stati scritti su disco. Può essere sovrascritta |
| **UNUSED** | Mai usato (appena creato) |

---

## ⏪ 3. Undo — La Macchina del Tempo

### 3.1 Cos'è

L'Undo Segment memorizza il **valore precedente** dei dati prima di ogni modifica. Serve per:

1. **Rollback**: Se l'utente fa ROLLBACK, Oracle usa l'Undo per riportare i dati allo stato originale.
2. **Read Consistency (MVCC)**: Se una query inizia e nel frattempo qualcuno modifica un dato, la query vede il **valore vecchio** (ricostruito dall'Undo). Readers never block writers.
3. **Crash Recovery (fase 2)**: Dopo un crash, Oracle usa l'Undo per annullare le transazioni non committate.
4. **Flashback**: Le tecnologie Flashback Query/Table usano l'Undo per "viaggiare nel tempo".

### 3.2 Undo Retention

```sql
-- Quanto tempo Oracle conserva l'undo DOPO il commit?
SHOW PARAMETER undo_retention;
-- Default: 900 secondi (15 minuti)
-- Per Flashback Query lunghe, aumentare a 3600+ (1 ora)
```

> [!WARNING]
> **ORA-01555: snapshot too old** — Questo errore leggendario significa che Oracle ha cancellato l'Undo di cui una query aveva bisogno per ricostruire una versione vecchia dei dati. Fix: aumentare `UNDO_RETENTION` o far girare le query più veloci.

---

## ⚙️ 4. I Processi Background

| Processo | Nome Completo | Cosa Fa |
|---|---|---|
| **LGWR** | Log Writer | Scrive il Redo Log Buffer sui Redo Log files. Scatta al COMMIT, quando il buffer è 1/3 pieno, o ogni 3 secondi. |
| **DBWR** | Database Writer | Scrive i blocchi "dirty" dal Buffer Cache ai datafile. **Non** è legato al COMMIT! Scrive quando ha bisogno di spazio o durante un checkpoint. |
| **CKPT** | Checkpoint | Segnala a DBWR di scrivere tutti i dirty buffers, poi aggiorna gli header dei datafile e del controlfile con l'SCN del checkpoint. |
| **SMON** | System Monitor | Esegue il **crash recovery** all'avvio dell'istanza (roll forward + roll back). Fa anche la pulizia dei segmenti temporanei. |
| **PMON** | Process Monitor | Pulisce le risorse delle sessioni terminate in modo anomalo (rilascia lock, rollback delle transazioni). |
| **ARCn** | Archiver | Copia i Redo Log pieni nella destinazione di archivio (archivelog). Necessario per il recovery point-in-time e Data Guard. |

---

## 💾 5. Checkpoint

### Cos'è

Un checkpoint è il momento in cui Oracle dice: "OK, stop. Tutti i dati modificati fino a questo SCN sono ora scritti su disco."

### Perché è Importante

Il checkpoint determina **da dove parte il crash recovery**. Se l'ultimo checkpoint è all'SCN 10.000 e il crash avviene all'SCN 15.000, Oracle deve solo riapplicare 5.000 SCN di redo (non tutto dall'inizio).

### Tipi di Checkpoint

| Tipo | Quando Avviene | Impatto |
|---|---|---|
| **Full Checkpoint** | `ALTER SYSTEM CHECKPOINT`, shutdown | Pesante (scrive TUTTO) |
| **Incremental** | Continuo (ogni 3 secondi circa) | Leggero, riduce il tempo di recovery |
| **Log Switch** | Quando LGWR passa al gruppo successivo | Medio |
| **Tablespace** | `ALTER TABLESPACE ... OFFLINE/READ ONLY` | Solo quel tablespace |

---

## 🔥 6. Crash Recovery — Come Oracle Risorge

Quando l'istanza crasha (power failure, kill -9, panico del kernel), al riavvio Oracle esegue automaticamente il **Instance Recovery**:

### Fase 1: Roll Forward (Redo Application)

```
SMON legge i Redo Log (da l'ultimo checkpoint in poi) e RIAPPLICA
tutte le modifiche al database — anche quelle di transazioni
NON ancora committate.

Risultato: il database è nello stato ESATTO in cui era un istante
prima del crash. Comprese le transazioni a metà.
```

### Fase 2: Roll Back (Undo Application)

```
Ora il database contiene sia dati committati sia dati NON committati.
SMON identifica le transazioni che al momento del crash erano ancora
attive (non committate) e le ANNULLA usando i segmenti Undo.

Risultato: il database contiene SOLO transazioni committate.
È transazionalmente consistente.
```

```
Timeline di un crash:

T1: COMMIT (transazione A)           ← salvata nel redo ✅
T2: UPDATE (transazione B, non commit) ← salvata nel redo, ma non committata
T3: COMMIT (transazione C)           ← salvata nel redo ✅
T4: ████ CRASH! ████

Recovery:
1. Roll Forward: riapplica A, B, C dal redo
2. Roll Back: annulla B (non era committata) usando l'undo
3. Risultato finale: solo A e C sono nel database
```

> [!TIP]
> **Domanda colloquio**: "Quanto tempo ci mette il crash recovery?"
> **Risposta**: Dipende dalla quantità di redo da riapplicare, che dipende dall'intervallo tra l'ultimo checkpoint e il crash. Per controllarlo: `FAST_START_MTTR_TARGET` (in secondi). Impostalo a 60-300 secondi per limitare il tempo di recovery.

---

## 🔀 7. Multiplexing del Redo Log

### Il Problema

Se il disco con i Redo Log si rompe, Oracle **si ferma**. Non può continuare senza sapere dove scrivere le modifiche. Perdi TUTTI i dati uncommitted.

### La Soluzione: Multiplexing

Ogni **gruppo** di redo log contiene più **membri** (copie identiche) su dischi fisici diversi:

```
Gruppo 1:
  Membro A: /u01/oradata/redo01a.log   (disco 1)
  Membro B: /u02/oradata/redo01b.log   (disco 2)

Gruppo 2:
  Membro A: /u01/oradata/redo02a.log   (disco 1)
  Membro B: /u02/oradata/redo02b.log   (disco 2)

Gruppo 3:
  Membro A: /u01/oradata/redo03a.log   (disco 1)
  Membro B: /u02/oradata/redo03b.log   (disco 2)
```

LGWR scrive **simultaneamente** su entrambi i membri. Se un membro fallisce, usa l'altro.

```sql
-- Aggiungere un membro a un gruppo esistente (multiplexing)
ALTER DATABASE ADD LOGFILE MEMBER
  '/u02/oradata/RACDB/redo01b.log' TO GROUP 1;

-- Verificare lo stato del multiplexing
SELECT group#, member, status FROM v$logfile ORDER BY group#, member;
```

> [!CAUTION]
> **Oracle MAA Best Practice**: Avere **minimo 2 membri per gruppo** su dischi separati. In ASM, se hai diskgroup con redundancy NORMAL o HIGH, il multiplexing è gestito automaticamente dal layer ASM ed è **inutile** farlo manualmente.

---

## 📏 8. Redo Log Sizing

### La Regola d'Oro

```
I log switch NON devono avvenire più di 1 volta ogni 15-20 minuti.
Se switchano ogni 2 minuti → troppo piccoli!
Se switchano ogni 2 ore → troppo grandi (recovery lento).
```

```sql
-- Frequenza dei log switch nelle ultime 24 ore
SELECT TO_CHAR(first_time, 'DD-MON HH24') AS hour,
       COUNT(*) AS switches
FROM v$log_history
WHERE first_time > SYSDATE - 1
GROUP BY TO_CHAR(first_time, 'DD-MON HH24')
ORDER BY 1;

-- Se vedi più di 4 switch/ora → aumenta la dimensione dei redo log
```

### Dimensione Raccomandata

| Carico | Dimensione Consigliata |
|---|---|
| Lab/Test | 200MB - 500MB |
| OLTP Medio | 1GB - 2GB |
| OLTP Pesante / DWH | 4GB - 8GB |

---

## 🎯 9. Domande da Colloquio

| Domanda | Risposta |
|---|---|
| Cosa succede prima: il COMMIT o la scrittura del dato su disco? | Il COMMIT. LGWR scrive il redo su disco. Il dato resta nel Buffer Cache e verrà scritto dopo dal DBWR. |
| Come funziona il crash recovery? | 2 fasi: Roll Forward (riapplica redo), poi Roll Back (annulla transazioni uncommitted con l'undo). |
| Cos'è il multiplexing dei redo log? | Mantenere copie multiple di ogni gruppo redo su dischi diversi. LGWR scrive su tutte le copie. |
| Cosa è ORA-01555? | Lo snapshot è troppo vecchio: l'undo dei dati richiesti dalla query è stato sovraScritto. |
| Cosa controlla FAST_START_MTTR_TARGET? | Il tempo massimo (in secondi) che il crash recovery può impiegare. Influenza la frequenza dei checkpoint. |
| Differenza tra ARCHIVELOG e NOARCHIVELOG? | In ARCHIVELOG, i redo log pieni vengono copiati (archiviati) prima di essere sovrascritti. Permette il point-in-time recovery. |

---

## 🔍 10. Comandi di Verifica

```sql
-- Stato dei Redo Log Groups
SELECT group#, thread#, sequence#, bytes/1024/1024 AS size_mb,
       members, status, archived
FROM v$log ORDER BY group#;

-- Membri dei gruppi (multiplexing)
SELECT group#, member, status, type FROM v$logfile ORDER BY group#;

-- Undo Tablespace
SELECT tablespace_name, status, contents FROM dba_tablespaces
WHERE contents = 'UNDO';

-- Undo retention e utilizzo
SELECT TO_CHAR(begin_time, 'HH24:MI') AS time,
       undotsn, undoblks, txncount, activeblks, unexpiredblks
FROM v$undostat
WHERE begin_time > SYSDATE - 1/24
ORDER BY begin_time;

-- Verificare FAST_START_MTTR_TARGET
SELECT target_mttr, estimated_mttr, optimal_logfile_size
FROM v$instance_recovery;
```

---

> **Riferimenti**: Oracle Database Concepts 19c — Chapter 13: Data Concurrency and Consistency.
> Oracle Database Administrator's Guide 19c — Chapter 11: Managing the Redo Log.
> Oracle Database Backup and Recovery User's Guide 19c — Managing Undo.
