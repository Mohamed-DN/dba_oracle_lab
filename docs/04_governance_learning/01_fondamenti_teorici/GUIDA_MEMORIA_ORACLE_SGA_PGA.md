# 🧠 Guida Completa: Architettura della Memoria Oracle (SGA, PGA, AMM, ASMM)

> **Questa guida** spiega a fondo come Oracle gestisce la memoria. Capire SGA e PGA è la **prima domanda** che fanno ai colloqui DBA. Se non sai spiegare la differenza tra Buffer Cache e Shared Pool, il colloquio finisce lì.
>
> **Fonti**: Oracle Database Concepts 19c (docs.oracle.com), Oracle Database Performance Tuning Guide 19c.

---

## 📑 Indice

1. [Il Quadro Generale](#-1-il-quadro-generale)
2. [SGA — La Memoria Condivisa](#-2-sga--la-memoria-condivisa)
3. [PGA — La Memoria Privata](#-3-pga--la-memoria-privata)
4. [I 3 Metodi di Gestione della Memoria](#-4-i-3-metodi-di-gestione-della-memoria)
5. [HugePages: Perché Servono in Produzione](#-5-hugepages)
6. [Domande da Colloquio](#-6-domande-da-colloquio)
7. [Comandi di Verifica](#-7-comandi-di-verifica)

---

## 🌍 1. Il Quadro Generale

Quando avvii un'istanza Oracle, il sistema operativo alloca **due grandi aree di memoria**:

```
+-----------------------------------------------------+
|                     ISTANZA ORACLE                   |
|                                                      |
|  +----------------------------------------------+   |
|  |           SGA (System Global Area)            |   |
|  |         CONDIVISA tra tutti i processi        |   |
|  |                                               |   |
|  |  +----------+  +----------+  +------------+ |   |
|  |  |  Buffer  |  |  Shared  |  | Redo Log   | |   |
|  |  |  Cache   |  |   Pool   |  |  Buffer    | |   |
|  |  +----------+  +----------+  +------------+ |   |
|  |  +----------+  +----------+  +------------+ |   |
|  |  |  Large   |  |  Java    |  |  Streams   | |   |
|  |  |   Pool   |  |  Pool    |  |   Pool     | |   |
|  |  +----------+  +----------+  +------------+ |   |
|  +----------------------------------------------+   |
|                                                      |
|  +------+  +------+  +------+  +------+            |
|  | PGA  |  | PGA  |  | PGA  |  | PGA  |  ← 1 per  |
|  | Sess1|  | Sess2|  | Sess3|  | Sess4|    sessione|
|  +------+  +------+  +------+  +------+            |
|                                                      |
|  +----------------------------------------------+   |
|  |          Background Processes                 |   |
|  |  DBWR  LGWR  CKPT  SMON  PMON  LREG  ARCn   |   |
|  +----------------------------------------------+   |
+-----------------------------------------------------+
```

---

## 🏗️ 2. SGA — La Memoria Condivisa

La SGA è un'area di memoria **condivisa** tra tutti i processi server e background. È il "cervello" dell'istanza.

### 2.1 Database Buffer Cache

```
Il Buffer Cache è la "RAM del database".
Invece di leggere i dati dal disco ogni volta, Oracle li tiene in memoria.
```

- **Cosa contiene**: Copie dei **blocchi dati** (tipicamente 8KB ciascuno) letti dai datafile.
- **Come funziona**: Quando una query ha bisogno di un blocco, Oracle cerca prima nel Buffer Cache (**logical read**). Se non lo trova, lo legge dal disco (**physical read**) e lo mette in cache.
- **Algoritmo**: Usa una variante di **LRU** (Least Recently Used) con una touch count list. I blocchi "caldi" (usati spesso) restano in cache, quelli "freddi" vengono espulsi.
- **Parametro**: `DB_CACHE_SIZE` (con ASMM, Oracle lo autotuna).

```sql
-- Quanto è grande il buffer cache?
SELECT component, current_size/1024/1024 AS size_mb
FROM v$sga_dynamic_components
WHERE component = 'DEFAULT buffer cache';

-- Hit Ratio: quante letture vengono soddisfatte dalla cache?
SELECT ROUND(
    (1 - (SELECT value FROM v$sysstat WHERE name = 'physical reads') /
         (SELECT value FROM v$sysstat WHERE name = 'session logical reads')
    ) * 100, 2
) AS buffer_cache_hit_pct FROM dual;
-- ATTESO: > 95% in OLTP. Se < 90%, il buffer cache è troppo piccolo.
```

> [!TIP]
> **Domanda colloquio**: "Cosa succede se il Buffer Cache è troppo piccolo?"
> **Risposta**: Oracle deve fare troppe **Physical Reads** (wait event `db file sequential read` e `db file scattered read`). Il database rallenta perché il disco è 1000x più lento della RAM. La soluzione è aumentare `SGA_TARGET` o `DB_CACHE_SIZE`.

---

### 2.2 Shared Pool

```
Lo Shared Pool è la "biblioteca" del database.
Contiene tutte le query SQL già parsate, pronte per essere riutilizzate.
```

- **Library Cache**: Memorizza i **piani di esecuzione** delle query SQL e PL/SQL già parsate. Quando una nuova query arriva, Oracle cerca prima qui (**Soft Parse**). Se la trova, la riusa senza doverla rianalizzare. Se non la trova, esegue un **Hard Parse** (costoso in CPU).
- **Data Dictionary Cache (Row Cache)**: Memorizza informazioni sul dizionario dati (nomi tabelle, colonne, permessi). Evita di dover leggere le tabelle `SYS` da disco ad ogni operazione.
- **Parametro**: `SHARED_POOL_SIZE` (con ASMM, auto-tunato).

```sql
-- Misurare la Library Cache Hit Ratio
SELECT ROUND(SUM(pins - reloads) * 100 / SUM(pins), 2) AS lib_cache_hit_pct
FROM v$librarycache;
-- ATTESO: > 99%. Se < 95%, hai troppi HARD PARSE.

-- Quanti hard parse ci sono?
SELECT name, value FROM v$sysstat
WHERE name IN ('parse count (total)', 'parse count (hard)');
-- Se hard/total > 30% → l'applicazione NON usa bind variables!
```

> [!CAUTION]
> **Il killer silenzioso**: Un'applicazione che non usa **bind variables** genera migliaia di hard parse, riempie la Shared Pool di piani di esecuzione unici e provoca il temutissimo wait event `cursor: pin S wait on X`. La soluzione è **sempre** usare bind variables nel codice applicativo.

---

### 2.3 Redo Log Buffer

- **Cosa contiene**: Le **redo entries** (registrazioni di ogni modifica ai dati) prima che il processo **LGWR** le scriva sui Redo Log files su disco.
- **Dimensione**: Tipicamente piccolo (pochi MB). Parametro: `LOG_BUFFER`.
- **Come funziona**: Quando fai un `UPDATE`, Oracle genera un'entry nel Redo Log Buffer. Quando fai `COMMIT`, LGWR scrive dal buffer al disco (write-ahead logging).

```sql
-- Dimensione Redo Log Buffer
SELECT name, value/1024/1024 AS size_mb
FROM v$parameter WHERE name = 'log_buffer';
```

### 2.4 Large Pool

- **Per cosa si usa**: Allocazioni "grandi" che altrimenti frammenterebbero la Shared Pool:
  - **RMAN** (backup/recovery buffers)
  - **Parallel Query** (message buffers tra processi paralleli)
  - **Shared Server** (session memory per connessioni shared)
- **Parametro**: `LARGE_POOL_SIZE`

---

## 👤 3. PGA — La Memoria Privata

La PGA è la memoria **privata** di ogni processo server. Non è condivisa.

```
Ogni sessione utente ha la propria PGA.
100 sessioni = 100 PGA separate.
```

### Cosa contiene la PGA:

| Area | Cosa Fa |
|---|---|
| **Sort Area** | Spazio per le operazioni di `ORDER BY`, `GROUP BY`, `DISTINCT`. Se i dati non ci stanno, Oracle va su disco (temp tablespace). |
| **Hash Join Area** | Spazio per le hash join tra tabelle. |
| **Bitmap Merge Area** | Per le operazioni con indici bitmap. |
| **Session Memory** | Variabili di sessione, cursori aperti, stack. |

```sql
-- Memoria PGA totale usata dall'istanza
SELECT name, ROUND(value/1024/1024) AS mb
FROM v$pgastat
WHERE name IN ('total PGA allocated', 'total PGA inuse', 
               'maximum PGA allocated', 'extra bytes read/written');
```

> [!IMPORTANT]
> **Il warning critico**: Se la PGA è troppo piccola, le operazioni di sort e hash join vanno su **disco** (temp tablespace). Questo è 100x più lento. Il wait event che ne risulta è `direct path read temp` / `direct path write temp`.

---

## ⚙️ 4. I 3 Metodi di Gestione della Memoria

### 4.1 AMM — Automatic Memory Management

```
AMM = "Oracle, gestisci TUTTO tu. Ecco N GB. Arrangiati."
```

| Pro | Contro |
|---|---|
| Zero configurazione | **Incompatibile con HugePages** (uccide le performance!) |
| Buono per piccoli DB/lab | Non raccomandato per produzione |

```sql
-- Abilitare AMM
ALTER SYSTEM SET memory_target = 4G SCOPE=SPFILE;
ALTER SYSTEM SET memory_max_target = 6G SCOPE=SPFILE;
ALTER SYSTEM SET sga_target = 0 SCOPE=SPFILE;
-- RESTART necessario
```

### 4.2 ASMM — Automatic Shared Memory Management (RACCOMANDATO)

```
ASMM = "Oracle, gestisci la SGA tu. La PGA la limito io con un target."
Questo è il GOLD STANDARD per la produzione.
```

| Pro | Contro |
|---|---|
| **Compatibile con HugePages** | Richiede di impostare 2 parametri |
| Oracle autotuna i componenti SGA | |
| Standard in tutte le Enterprise | |

```sql
-- Configurazione ASMM tipica per un server con 32GB RAM
ALTER SYSTEM SET memory_target = 0 SCOPE=SPFILE;           -- Disabilita AMM
ALTER SYSTEM SET sga_target = 16G SCOPE=SPFILE;             -- 50% della RAM per SGA
ALTER SYSTEM SET sga_max_size = 18G SCOPE=SPFILE;           -- Max dinamico
ALTER SYSTEM SET pga_aggregate_target = 4G SCOPE=SPFILE;    -- PGA target
-- In RAC: moltiplicare per il numero di istanze
```

### 4.3 Manual — Gestione Manuale

```
Manual = "So esattamente cosa fare. Imposto ogni componente a mano."
Solo per DBA con 15+ anni di esperienza su workload molto specifici.
```

```sql
-- Solo in casi molto particolari
ALTER SYSTEM SET sga_target = 0;
ALTER SYSTEM SET db_cache_size = 8G;
ALTER SYSTEM SET shared_pool_size = 2G;
ALTER SYSTEM SET large_pool_size = 512M;
ALTER SYSTEM SET pga_aggregate_target = 4G;
```

### Tabella Comparativa

| Metodo | Parametro Chiave | HugePages? | Produzione? |
|---|---|---|---|
| **AMM** | `MEMORY_TARGET` | ❌ No | ❌ Solo lab/test |
| **ASMM** | `SGA_TARGET` + `PGA_AGGREGATE_TARGET` | ✅ Sì | ✅ Standard |
| **Manual** | `DB_CACHE_SIZE`, `SHARED_POOL_SIZE`, ecc. | ✅ Sì | ⚠️ Solo esperti |

---

## 🐘 5. HugePages

### Perché Sono Fondamentali

Di default, Linux gestisce la memoria in pagine da **4KB**. Per una SGA di 16GB, il kernel deve gestire **4 milioni di pagine**. Ogni pagina ha una entry nella Page Table del kernel, consumando CPU e memoria.

Con **HugePages** (2MB per pagina su x86_64), le pagine diventano solo **8.192** → la gestione è 500x più efficiente.

```bash
# Calcolare quante HugePages servono
# SGA = 16GB, HugePage = 2MB
echo "16384 / 2 + 10" | bc    # = 8202 (aggiungiamo margine)

# Impostare nel kernel
echo 8202 > /proc/sys/vm/nr_hugepages

# Rendere permanente
echo "vm.nr_hugepages = 8202" >> /etc/sysctl.conf
sysctl -p
```

> [!WARNING]
> **Regola aurea**: Se usi `MEMORY_TARGET` (AMM), le HugePages **non funzionano**. Devi usare ASMM (`SGA_TARGET`). Questo è il motivo principale per cui AMM è sconsigliato in produzione.

---

## 🎯 6. Domande da Colloquio

| Domanda | Risposta Sintetica |
|---|---|
| Differenza SGA vs PGA? | SGA è condivisa (tutti la vedono), PGA è privata (una per sessione) |
| Cos'è un Hard Parse? | Analisi completa di una query SQL: syntax check → semantic check → optimizer → piano. Costoso in CPU. |
| Cos'è un Soft Parse? | Oracle trova la query già parsata nella Library Cache e riusa il piano. Veloce. |
| Perché AMM è sconsigliato? | Perché non supporta HugePages, che sono essenziali per le performance in produzione. |
| Che wait event indica PGA insufficiente? | `direct path read temp` e `direct path write temp` (sort su disco). |
| Come verifichi il Buffer Cache Hit? | `V$SYSSTAT`: rapporto tra `session logical reads` e `physical reads`. Deve essere >95%. |

---

## 🔍 7. Comandi di Verifica

```sql
-- Vista completa della SGA
SELECT * FROM v$sgainfo;

-- Componenti SGA e dimensioni attuali
SELECT component, current_size/1024/1024 AS mb,
       min_size/1024/1024 AS min_mb,
       max_size/1024/1024 AS max_mb,
       oper_count AS resize_ops
FROM v$sga_dynamic_components
ORDER BY current_size DESC;

-- Statistiche PGA
SELECT name, ROUND(value/1024/1024) AS mb
FROM v$pgastat
WHERE name IN ('total PGA allocated', 'total PGA inuse',
               'maximum PGA allocated', 'aggregate PGA target parameter',
               'over allocation count');
-- Se "over allocation count" > 0: PGA_AGGREGATE_TARGET è troppo piccolo!

-- Memory Advisors (Oracle ti dice cosa fare)
SELECT * FROM v$memory_target_advice ORDER BY memory_size;
SELECT * FROM v$sga_target_advice ORDER BY sga_size;
SELECT * FROM v$pga_target_advice ORDER BY pga_target_for_estimate;
```

---

> **Riferimenti**: Oracle Database Concepts 19c — Chapter 14: Memory Architecture.
> Oracle Database Performance Tuning Guide 19c — Chapter 7: Memory Configuration and Use.
