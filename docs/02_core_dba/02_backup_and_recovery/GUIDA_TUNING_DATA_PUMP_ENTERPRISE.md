# GUIDA: Performance Tuning Data Pump — Ottimizzazione per database di grandi dimensioni (>10 TB)

> [!NOTE]
> **DOCUMENTI DI MIGRAZIONE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Tuning Data Pump Enterprise (questa guida)**: [GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md](./GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md) (ottimizzazione export/import per database >10 TB).
> - **Cross-Platform XTTS**: [GUIDA_MIGRAZIONE_XTTS_RMAN.md](./GUIDA_MIGRAZIONE_XTTS_RMAN.md) (migrazioni di database multi-TB cross-endian con downtime minimo).
> - **Data Pump Base**: [GUIDA_DATA_PUMP.md](./GUIDA_DATA_PUMP.md) (import/export di base, remap schema e tablespace).

---

## 1. Architettura delle Performance di Data Pump

Oracle Data Pump (`expdp`/`impdp`) è un motore server-side, il che significa che il lavoro pesante di lettura, formattazione e scrittura non è svolto dal client a riga di comando, ma da processi di background del database (`DM00` Master Process e `DWnn` Worker Processes).

Per velocizzare le importazioni ed esportazioni su database di classe Enterprise, dobbiamo eliminare i tre colli di bottiglia principali:
*   **I/O dei Datafile**: La velocità con cui il DB legge i blocchi dal disco.
*   **I/O del Dumpfile**: La velocità con cui i Worker scrivono/leggono i file `.dmp` sulla directory del server.
*   **Latenza CPU/Dizionario**: Overhead legato alla rigenerazione degli indici, constraint e statistiche.

---

## 2. Parametri Chiave di Tuning (expdp / impdp)

### 2.1 Parallelismo Avanzato (`PARALLEL`)
Il parallelismo definisce quanti worker process lavoreranno simultaneamente.
*   *Regola d'oro*: Imposta `PARALLEL` al massimo pari a **due volte il numero di core CPU disponibili** sul server database (es. con 16 CPU core, imposta `PARALLEL=16` o `32` se lo storage è in grado di gestire l'I/O).
*   *Vincolo sui Dumpfile*: Se imposti `PARALLEL=8`, **devi specificare almeno 8 file di dump distinti** (o usare il metacarattere `%U`), altrimenti tutti i worker proveranno a scrivere sullo stesso file serializzando l'I/O ed eliminando i vantaggi del parallelismo.

```bash
# Esempio ottimizzato con parallelismo e file multipli
expdp system/<password> \
  schemas=HR \
  directory=DPUMP_DIR \
  dumpfile=hr_export_%U.dmp \ -- %U genera automaticamente file multipli (es. hr_export_01.dmp, hr_export_02.dmp)
  logfile=hr_export_perf.log \
  parallel=8
```

### 2.2 Disabilitare il Clustering in RAC (`CLUSTER=NO`)
In ambienti RAC, di default Data Pump prova a distribuire i worker process su tutte le istanze attive del cluster per parallelizzare il calcolo.
*   *Problema*: Questo genera una latenza di comunicazione mostruosa sulla rete privata Interconnect (Cache Fusion) a causa dello scambio di blocchi e della coordinazione dei metadata.
*   *Soluzione*: Imposta sempre **`CLUSTER=NO`** in RAC. Questo forza tutti i worker process a lavorare su **un solo nodo** locale (l'istanza a cui ti connetti), azzerando la latenza di rete privata Interconnect.

```bash
expdp system/<password>@RACDB1 \
  schemas=HR \
  directory=DPUMP_DIR \
  dumpfile=hr_export_%U.dmp \
  parallel=8 \
  cluster=NO -- Esegui il lavoro esclusivamente sull'istanza 1 locale!
```

### 2.3 Forzare l'Accesso Diretto (`ACCESS_METHOD`)
Data Pump sceglie autonomamente tra due metodi di caricamento/scaricamento dei dati:
1.  **Direct Path**: Salta completamente lo stack SQL di Oracle, leggendo/scrivendo direttamente i blocchi fisici del database (velocissimo, riduce l'uso di CPU e azzera la generazione di UNDO).
2.  **External Tables**: Utilizza comandi SQL interni. È più lento ma necessario se ci sono tabelle con colonne crittografate, trigger attivi o LOB complessi.

Se le tue tabelle non hanno vincoli bloccanti, puoi forzare il metodo Direct Path per raddoppiare le performance:

```bash
expdp system/<password> \
  schemas=HR \
  directory=DPUMP_DIR \
  dumpfile=hr_export_%U.dmp \
  access_method=DIRECT_PATH -- Forza il salto dello stack SQL!
```

### 2.4 Esclusione delle Statistiche (`EXCLUDE=STATISTICS`)
Durante l'importazione di un grande schema, una quantità enorme di tempo viene persa per importare ed allineare le statistiche dell'optimizer.
*   *Soluzione*: Escludi le statistiche in fase di importazione e rigenerale in modo pulito e ad alta velocità in un secondo momento tramite il package ottimizzato `DBMS_STATS`.

```bash
# In fase di Import:
impdp system/<password> \
  schemas=HR \
  directory=DPUMP_DIR \
  dumpfile=hr_export_01.dmp \
  exclude=STATISTICS -- Salta le statistiche!
```

Dopo che l'import è completato, rigenera le statistiche in parallelo sfruttando tutte le CPU disponibili:
```sql
sqlplus / as sysdba
EXEC DBMS_STATS.GATHER_SCHEMA_STATS(ownname=>'HR', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>8);
```

---

## 3. Ottimizzazione della Memoria (SGA Streams Pool)

Data Pump utilizza code asincrone in memoria (Advanced Queuing) per scambiare informazioni tra il Master e i Worker. Questa memoria risiede all'interno dello **Streams Pool** della SGA.
Se lo Streams Pool è troppo piccolo (o non configurato), Oracle è costretto ad allocarlo dinamicamente ridimensionando altri pool della SGA (come il Buffer Cache o Shared Pool), causando stalli temporanei (wait event `latch: shared pool` o `SGA: allocation force`).

Prima di lanciare import/export di terabyte:
```sql
sqlplus / as sysdba

-- Imposta una dimensione minima fissa per lo Streams Pool (almeno 256MB o 512MB per parallelismi elevati)
ALTER SYSTEM SET streams_pool_size=512M SCOPE=BOTH SID='*';
```

---

## 4. Triage & Monitoraggio di Job Data Pump Rallentati

Se un import/export sembra congelato, non ucciderlo brutalmente con `kill -9` (rischi di lasciare tabelle master e dizionari inconsistenti). Monitora lo stato in tempo reale.

### 4.1 Monitorare il Progresso (v$session_longops)
```sql
sqlplus / as sysdba

SELECT opname,
       target_desc,
       sofar,
       totalwork,
       ROUND(sofar/totalwork*100, 2) AS pct_complete,
       time_remaining AS seconds_left
FROM   v$session_longops
WHERE  opname LIKE '%Data Pump%'
AND    totalwork > 0;
```

### 4.2 Connettersi a un Job Attivo in modalità Interattiva
Puoi collegarti a un job Data Pump in esecuzione per monitorarne lo stato o modificarne il parallelismo al volo senza interromperlo:

```bash
# Trova prima il nome del job attivo
sqlplus / as sysdba
SELECT owner_name, job_name, state FROM dba_datapump_jobs;
-- Esempio job_name: SYS_EXPORT_SCHEMA_01

# Connettiti in modalità interattiva tramite impdp/expdp:
expdp system/<password> attach=SYS_EXPORT_SCHEMA_01

# All'interno dell'interfaccia interattiva di Data Pump (DUMP>):
Export> status -- Mostra lo stato dei worker attivi e cosa stanno elaborando
Export> increase_parallel=4 -- Aumenta il parallelismo al volo di 4 worker!
Export> kill_job -- Arresta e pulisce il job in modo ordinato e pulito
```
