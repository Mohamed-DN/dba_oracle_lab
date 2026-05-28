# GUIDA MONUMENTALE: Performance Tuning Data Pump — Ottimizzazione & Diagnostica per Database >10 TB


## [ARCHITETTURA VISIVA] Data Pump Parallelism
```text

                               +----------------+
                               | Master (DM00)  |
                               +-------+--------+
                                       | (Distribuisce lavoro)
             +-------------------------+-------------------------+
             |                         |                         |
             v                         v                         v
       Worker 1 (DW01)           Worker 2 (DW02)           Worker N (DWnn)
             |                         |                         |
             v                         v                         v
     [ Dump File 1 ]           [ Dump File 2 ]           [ Dump File N ]
```

> [!NOTE]
> **DOCUMENTI DI MIGRAZIONE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Tuning Data Pump Enterprise (questa guida)**: [GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md](./GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md) (ottimizzazione export/import per database >10 TB, parametri avanzati, Streams Pool, troubleshooting, trace flags).
> - **Cross-Platform XTTS**: [GUIDA_MIGRAZIONE_XTTS_RMAN.md](./GUIDA_MIGRAZIONE_XTTS_RMAN.md) (migrazioni di database multi-TB cross-endian AIX/Solaris -> Linux con downtime minimo).
> - **Data Pump Base**: [GUIDA_DATA_PUMP.md](./GUIDA_DATA_PUMP.md) (import/export di base, remap schema e tablespace).

---

## 1. Architettura delle Performance di Data Pump

Oracle Data Pump (`expdp` e `impdp`) è una tecnologia server-side introdotta per superare i limiti strutturali del vecchio export classico (`exp`/`imp`). Il client a riga di comando invia semplicemente comandi SQL/API al database tramite pacchetti PL/SQL (`DBMS_DATAPUMP`). Il vero carico di lavoro (estrazione, formattazione, compressione, crittografia e scrittura fisica) è gestito da processi di background interni del database:

```
                      [ CLINET RIGA DI COMANDO expdp ]
                                     │
                                     ▼ (Invia comandi PL/SQL)
                         [ MASTER PROCESS DM00 ]
                                     │
               ┌─────────────────────┴─────────────────────┐
               ▼ (Assegna Lavoro)                          ▼ (Crea/Aggiorna)
      [ WORKER PROCESSES DWnn ] ◄────────────────────► [ MASTER TABLE ]
        - Leggono datafile                               - Stato del job
        - Scrivono dumpfiles                             - Elenco oggetti
        - Parallelizzazione                              - Monitoraggio
```

### I Processi Chiave in Dettaglio:
*   **Master Process (`DM00`)**: Coordina l'intero job, gestisce le code di lavoro (Advanced Queuing) e distribuisce i task ai worker. Provvede alla creazione e all'aggiornamento costante della **Master Table** (una tabella di tracciamento fisica creata nello schema che avvia il job, avente lo stesso nome del job, es. `SYSTEM.SYS_EXPORT_SCHEMA_01`).
*   **Worker Processes (`DWnn`)**: I processi operativi che eseguono fisicamente la lettura e la scrittura dei blocchi dati e dei file di dump.
*   **Shadow Process**: Il processo del server dedicato ad ascoltare le chiamate dell'interfaccia client.

Per velocizzare le importazioni ed esportazioni su database di classe Enterprise (>10 TB), occorre agire in modo mirato eliminando i tre colli di bottiglia principali:
1.  **I/O dei Datafile**: Velocità di lettura fisica dal tablespace sorgente.
2.  **I/O del Dumpfile**: Velocità di scrittura sul file system o disk group ASM di destinazione.
3.  **Memoria SGA (Streams Pool)**: Capacità di scambiare messaggi tra il Master ed i Worker senza latenza.

---

## 2. Parametri Enterprise di Ottimizzazione

### 2.1 Parallelismo Avanzato e Metacaratteri (`PARALLEL` & `%U`)
Il parallelismo definisce il numero di worker process attivi contemporaneamente.
*   *Regola d'oro*: Imposta `PARALLEL` al massimo pari a **due volte il numero di core CPU fisici disponibili** sul server DB, assicurandoti che lo storage sia in grado di sostenere l'I/O.
*   *Vincolo dei Dumpfile*: Se configuri `PARALLEL=16`, **devi specificare almeno 16 file di dump distinti** (o usare il metacarattere `%U` per la generazione automatica). Se più worker provano a scrivere sullo stesso file dump, l'I/O viene serializzato eliminando i benefici del parallelismo.

```bash
expdp system/SecureEnterprisePassword123# \
  schemas=APP_CRM \
  directory=DPUMP_DIR \
  dumpfile=crm_prod_export_%U.dmp \ -- %U genera file multipli (es. crm_prod_export_01.dmp, crm_prod_export_02.dmp)
  logfile=crm_prod_export.log \
  parallel=16
```

### 2.2 Disabilitare il Clustering in RAC (`CLUSTER=NO`)
In ambienti Real Application Clusters (RAC), di default Data Pump tenta di distribuire i worker process su tutte le istanze attive del cluster per parallelizzare l'elaborazione.
*   *Problema*: Questa configurazione provoca una latenza di comunicazione mostruosa sulla rete privata Interconnect (Cache Fusion) a causa dello scambio di blocchi e della coordinazione dei metadata tra i nodi.
*   *Soluzione*: Impostare sempre **`CLUSTER=NO`**. Questo forza tutti i worker process a girare **esclusivamente sull'istanza locale** a cui ci si connette, azzerando il traffico di rete privata Interconnect.

```bash
expdp system/SecureEnterprisePassword123#@RACDB_INST1 \
  schemas=APP_CRM \
  directory=DPUMP_DIR \
  dumpfile=crm_prod_export_%U.dmp \
  parallel=16 \
  cluster=NO -- Esegui il lavoro solo sul nodo locale 1!
```

### 2.3 Forzare il Direct Path (`ACCESS_METHOD=DIRECT_PATH`)
Data Pump sceglie autonomamente il metodo di caricamento/scaricamento dei dati:
1.  **Direct Path**: Salta completamente lo stack SQL di Oracle, leggendo/scrivendo direttamente i blocchi fisici del database (velocissimo, riduce l'uso di CPU e azzera la generazione di UNDO).
2.  **External Tables**: Utilizza comandi SQL interni. È più lento ma necessario se ci sono tabelle con colonne crittografate, trigger attivi o LOB complessi.

Se le tue tabelle non hanno vincoli bloccanti, forza il metodo Direct Path per raddoppiare le performance:
```bash
expdp system/SecureEnterprisePassword123# \
  schemas=APP_CRM \
  directory=DPUMP_DIR \
  dumpfile=crm_prod_export_%U.dmp \
  access_method=DIRECT_PATH
```

### 2.4 Tracciamento Dettagliato: Metriche, Timestamp ed Esclusioni (`METRICS`, `LOGTIME`, `EXCLUDE`)
Per analizzare dove si perdono secondi preziosi durante operazioni su database da terabyte, è fondamentale tracciare i tempi esatti di esportazione di ciascun oggetto.
*   `METRICS=YES`: Scrive nel file di log il numero di righe esportate/importate e i secondi impiegati per ogni singola tabella.
*   `LOGTIME=ALL`: Antepone un timestamp preciso (data e ora al millisecondo) ad ogni riga del log di Data Pump.
*   `EXCLUDE=STATISTICS`: Esclude le statistiche in fase di importazione. Le statistiche verranno rigenerate successivamente in parallelo tramite `DBMS_STATS`, riducendo i tempi di importazione del 30%.

```bash
impdp system/SecureEnterprisePassword123# \
  schemas=APP_CRM \
  directory=DPUMP_DIR \
  dumpfile=crm_prod_export_01.dmp \
  parallel=16 \
  exclude=STATISTICS \
  metrics=YES \
  logtime=ALL
```

---

## 3. Tuning di Memoria della SGA (Streams Pool Sizing)

Data Pump utilizza Advanced Queuing (AQ) in memoria per lo scambio di messaggi tra il Master ed i Worker. Questa memoria risiede nello **Streams Pool** all'interno della SGA.
Se il parametro `streams_pool_size` è a zero o è troppo basso, Oracle alloca la memoria dinamicamente sottraendola ad altri pool (Buffer Cache o Shared Pool), provocando continui ridimensionamenti strutturali in memoria SGA con wait event del tipo `latch: shared pool` o `SGA: allocation force`.

> [!IMPORTANT]
> **Calcolo dello Streams Pool per parallelismo elevato:**
> *   Per `PARALLEL` fino a 8: impostare `streams_pool_size` ad almeno **256M**.
> *   Per `PARALLEL` da 9 a 32: impostare ad almeno **512M** o **1G**.

```sql
sqlplus / as sysdba

-- Imposta una dimensione minima fissa per evitare ridimensionamenti dinamici della SGA
ALTER SYSTEM SET streams_pool_size=1G SCOPE=BOTH SID='*';
```

---

## 4. Triage & Risoluzione Errori Comuni di Produzione

### 4.1 stuck Master Table: Risolvere `ORA-31626` / `ORA-31633`
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

### 4.3 Tracciamento I/O profondo tramite Trace Flags
In caso di rallentamenti inspiegabili dell'I/O sui file di dump, è possibile avviare Data Pump abilitando un tracciamento di dettaglio a livello di kernel tramite il parametro **`TRACE`**.
*   `TRACE=480300`: Abilita il tracciamento completo delle performance di I/O e dei worker process, scrivendo file di trace dettagliati sotto la directory di diagnostica ADR del database.

```bash
expdp system/SecureEnterprisePassword123# \
  schemas=APP_CRM \
  directory=DPUMP_DIR \
  dumpfile=crm_prod_export_%U.dmp \
  trace=480300
```
