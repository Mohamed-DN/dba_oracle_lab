# GUIDA COMPLETA: Performance Tuning Data Pump — Ottimizzazione per database di grandi dimensioni (>10 TB)

> [!NOTE]
> **DOCUMENTI DI MIGRAZIONE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Tuning Data Pump Enterprise (questa guida)**: [GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md](./GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md) (ottimizzazione export/import per database >10 TB, parametri avanzati, Streams Pool, troubleshooting).
> - **Cross-Platform XTTS**: [GUIDA_MIGRAZIONE_XTTS_RMAN.md](./GUIDA_MIGRAZIONE_XTTS_RMAN.md) (migrazioni di database multi-TB cross-endian con downtime minimo).
> - **Data Pump Base**: [GUIDA_DATA_PUMP.md](./GUIDA_DATA_PUMP.md) (import/export di base, remap schema e tablespace).

---

## 1. Architettura delle Performance di Data Pump

Oracle Data Pump (`expdp` e `impdp`) è una tecnologia server-side. Il client a riga di comando non esegue l'elaborazione dei dati; si limita a inviare comandi al database. Il vero carico di lavoro (estrazione, formattazione, compressione e scrittura) è delegato a processi di background interni gestiti da Grid/Database:
*   **Master Process (`DM00`)**: Coordina l'intero job, gestisce la coda di lavoro e distribuisce i task. Creazione e controllo della **Master Table** (una tabella temporanea creata nello schema che esegue l'export, contenente lo stato di tutti gli oggetti del job).
*   **Worker Processes (`DWnn`)**: I processi operativi che eseguono fisicamente la lettura/scrittura dei blocchi dati e dei file di dump.

```
                   [ expdp / impdp Client ]
                              │
                              ▼ (Invia comandi SQL/API)
                       [ Master Process DM00 ]
                              │
               ┌──────────────┴──────────────┐
               ▼ (Coordina)                  ▼ (Crea/Aggiorna)
      [ Worker Processes DWnn ] ◄────► [ Master Table ]
        - Leggono datafile
        - Scrivono dumpfiles
```

Per velocizzare le operazioni di importazione ed esportazione su database di classe Enterprise (>10 TB), occorre agire in modo mirato eliminando i colli di bottiglia legati a I/O, CPU e coordinazione di rete.

---

## 2. Parametri Enterprise di Ottimizzazione

### 2.1 Parallelismo Calibrato e Dumpfile Multipli (`PARALLEL` & `%U`)
Il parallelismo determina il numero di worker process attivi simultaneamente.
*   *Regola d'oro*: Imposta `PARALLEL` al massimo pari a **due volte il numero di core CPU fisici disponibili** sul server DB, assicurandoti che lo storage sia in grado di sostenere il throughput di I/O.
*   *Scrittura Multi-File*: Se imposti `PARALLEL=16`, **devi fornire almeno 16 file di dump fisici distinti** (o usare il metacarattere `%U`). Se i worker scrivono tutti sullo stesso file dump, l'I/O viene serializzato bloccando i vantaggi del parallelismo.

```bash
expdp system/SecurePwd123# \
  schemas=APP_CRM \
  directory=DPUMP_DIR \
  dumpfile=crm_prod_export_%U.dmp \ -- %U genera automaticamente file multipli (es. crm_prod_export_01.dmp)
  logfile=crm_prod_export.log \
  parallel=16
```

### 2.2 Disabilitare il Clustering in RAC (`CLUSTER=NO`)
Di default in ambienti RAC, Data Pump distribuisce i worker process su tutte le istanze del cluster per distribuire la CPU.
*   *Problema*: Questa impostazione genera un overhead devastante sulla rete privata Interconnect (Cache Fusion) a causa dello scambio continuo di blocchi dati e del coordinamento dei metadati tra i nodi.
*   *Soluzione*: Utilizzare sempre **`CLUSTER=NO`**. Questo forza tutti i worker a girare su **un solo nodo** locale (quello a cui si è connessi), azzerando la latenza dell'Interconnect.

```bash
expdp system/SecurePwd123#@RACDB_INST1 \
  schemas=APP_CRM \
  directory=DPUMP_DIR \
  dumpfile=crm_prod_export_%U.dmp \
  parallel=16 \
  cluster=NO -- Esegui il lavoro esclusivamente sull'istanza 1 locale!
```

### 2.3 Forzare il Direct Path (`ACCESS_METHOD=DIRECT_PATH`)
Data Pump sceglie tra due metodi di caricamento:
1.  **Direct Path**: Salta completamente lo stack SQL di Oracle, leggendo/scrivendo direttamente i blocchi fisici del database (velocissimo, riduce l'uso di CPU e azzera la generazione di UNDO).
2.  **External Tables**: Utilizza comandi SQL interni. È più lento ma necessario se ci sono tabelle con colonne crittografate, trigger attivi o LOB complessi.

Se le tue tabelle non hanno vincoli bloccanti, forza il metodo Direct Path per raddoppiare le performance:
```bash
expdp system/SecurePwd123# \
  schemas=APP_CRM \
  directory=DPUMP_DIR \
  dumpfile=crm_prod_export_%U.dmp \
  access_method=DIRECT_PATH
```

### 2.4 Metriche, Timestamp ed Esclusione Statistiche (`METRICS`, `LOGTIME`, `EXCLUDE`)
Per diagnosticare dove si perdono secondi preziosi in database da terabyte, è fondamentale tracciare con esattezza i tempi di ogni singolo oggetto.
*   `METRICS=YES`: Scrive nel file di log il numero di righe esportate/importate e i secondi impiegati per ogni singola tabella.
*   `LOGTIME=ALL`: Antepone un timestamp preciso (data e ora al millisecondo) ad ogni riga del log di Data Pump.
*   `EXCLUDE=STATISTICS`: Esclude le statistiche dell'ottimizzatore in import. Le statistiche verranno rigenerate in modo ottimizzato successivamente con `DBMS_STATS` in parallelo, riducendo i tempi di importazione del 30%.

```bash
impdp system/SecurePwd123# \
  schemas=APP_CRM \
  directory=DPUMP_DIR \
  dumpfile=crm_prod_export_01.dmp \
  parallel=16 \
  exclude=STATISTICS \
  metrics=YES \
  logtime=ALL
```

---

## 3. Ottimizzazione della Memoria (SGA Streams Pool)

Data Pump si basa su code in memoria (Advanced Queuing) per far comunicare il processo Master con i Worker. Questa memoria risiede all'interno dello **Streams Pool** della SGA.
Se il parametro `streams_pool_size` è impostato a zero (o è troppo basso), Oracle alloca la memoria dinamicamente ridimensionando altri pool (Buffer Cache o Shared Pool), causando stalli temporanei del database e wait event del tipo `latch: shared pool` o `SGA: allocation force`.

> [!IMPORTANT]
> **Calcolo dello Streams Pool per parallelismo elevato:**
> *   Per `PARALLEL` fino a 8: impostare `streams_pool_size` ad almeno **256M**.
> *   Per `PARALLEL` da 9 a 32: impostare ad almeno **512M** o **1G**.

```sql
sqlplus / as sysdba

-- Imposta un valore minimo fisso per prevenire il ridimensionamento dinamico durante l'export
ALTER SYSTEM SET streams_pool_size=1G SCOPE=BOTH SID='*';
```

---

## 4. Triage & Troubleshooting di Errori Comuni

### 4.1 Risoluzione ORA-31626 / ORA-31633 (Stuck Master Table)
*   **Problema**: L'esportazione fallisce all'avvio restituendo `ORA-31626: rollback transaction failed` o `ORA-31633: unable to create master table`.
*   **Causa**: La Master Table non può essere creata a causa di spazio insufficiente nel tablespace dell'utente che esegue il job, o per la presenza di un job precedente interrotto brutalmente che ha lasciato la tabella master orfana nel dizionario.
*   **Risoluzione**:
    1.  Trovare la tabella orfana:
        ```sql
        SELECT owner, object_name, object_type 
        FROM   dba_objects 
        WHERE  object_name LIKE 'SYS_EXPORT_%' OR object_name LIKE 'SYS_IMPORT_%';
        ```
    2.  Eliminare manualmente la tabella master rimasta bloccata:
        ```sql
        DROP TABLE SYSTEM.SYS_EXPORT_SCHEMA_01;
        ```

### 4.2 Risoluzione ORA-01555 (Snapshot too old in exports lunghi)
*   **Problema**: Durante l'esportazione di tabelle da terabyte, dopo ore di esecuzione Data Pump crasha restituendo `ORA-01555: snapshot too old`.
*   **Causa**: Le tabelle vengono modificate da altre sessioni attive mentre Data Pump le esporta. Poiché Data Pump deve garantire la consistenza del dato a inizio export, cerca i blocchi storici nel tablespace di `UNDO`. Se l'UNDO viene sovrascritto, si verifica l'errore.
*   **Risoluzione**:
    1.  Utilizzare il parametro **`FLASHBACK_SCN`** o **`FLASHBACK_TIME`** per bloccare la consistenza all'avvio del job.
    2.  Aumentare la dimensione del tablespace di `UNDO` e regolare il parametro `undo_retention` ad un valore superiore alla durata stimata dell'export (es. 8 ore = 28800 secondi):
        ```sql
        ALTER SYSTEM SET undo_retention=28800 SCOPE=BOTH SID='*';
        ```

### 4.3 Uso dei Trace Flags per Diagnostica I/O Profonda
In caso di rallentamenti inspiegabili dell'I/O sui file di dump, è possibile avviare Data Pump abilitando un tracciamento di dettaglio a livello di kernel tramite il parametro **`TRACE`**.
*   `TRACE=480300`: Abilita il tracciamento completo delle performance di I/O e dei worker process, scrivendo file di trace dettagliati sotto la directory di diagnostica ADR del database.

```bash
expdp system/SecurePwd123# \
  schemas=APP_CRM \
  directory=DPUMP_DIR \
  dumpfile=crm_prod_export_%U.dmp \
  trace=480300
```
