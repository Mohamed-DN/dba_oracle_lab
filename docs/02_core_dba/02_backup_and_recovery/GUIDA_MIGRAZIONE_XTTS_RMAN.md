# GUIDA MONUMENTALE: Cross-Platform Transportable Tablespaces (XTTS) con RMAN Incremental Backups


## [ARCHITETTURA VISIVA] XTTS RMAN Migration
```text

[ Source DB (Endian A) ]                           [ Dest DB (Endian B) ]
           |                                                 |
  Read-Only Tablespaces                                      |
           |---------- Trasferimento Datafiles (SCP) ------->|
           |                                                 |
  Esportazione Metadati                                      |
           |------------- Trasferimento Dump --------------->|
                                                             |
                                                   RMAN Convert Datafiles
                                                   Importazione Metadati
                                                   Read-Write Tablespaces
```

> [!NOTE]
> **DOCUMENTI DI MIGRAZIONE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Cross-Platform XTTS (questa guida)**: [GUIDA_MIGRAZIONE_XTTS_RMAN.md](./GUIDA_MIGRAZIONE_XTTS_RMAN.md) (migrazioni di database multi-TB cross-endian AIX/Solaris -> Linux con downtime minimo).
> - **Tuning Data Pump Enterprise**: [GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md](./GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md) (ottimizzazione export/import per database >10 TB, parametri avanzati, Streams Pool, troubleshooting).
> - **Data Pump Base**: [GUIDA_DATA_PUMP.md](./GUIDA_DATA_PUMP.md) (import/export di base, remap schema e tablespace).
> - **RMAN Enterprise Completa**: [GUIDA_RMAN_COMANDI_ENTERPRISE.md](./GUIDA_RMAN_COMANDI_ENTERPRISE.md) (manuale di riferimento per backup, restore e duplication).

---

## 1. Il problema delle Migrazioni Cross-Platform e la soluzione XTTS

Nelle migrazioni di database di grandi dimensioni (da 5 TB fino a oltre 50 TB), uno dei vincoli più stringenti imposti dal business è la riduzione della finestra di downtime (spesso limitata a poche ore o persino minuti durante il fine settimana). Se la migrazione richiede anche un cambio di architettura hardware e di sistema operativo — tipicamente il passaggio da sistemi UNIX Big-Endian (es. **IBM AIX**, **HP-UX** o **Oracle Solaris**) a piattaforme moderne x86_64 Little-Endian (**Oracle Linux**, **Exadata** o **Oracle Cloud Infrastructure - OCI**) — le tecniche tradizionali falliscono:

*   **Data Pump (Export/Import) classico**: Estremamente lento su database multi-terabyte. La conversione logica dei dati richiede decine di ore di elaborazione CPU ed I/O intenso, rendendo impossibile rispettare la finestra di downtime.
*   **Standard Transportable Tablespaces (TTS)**: Richiede di impostare i tablespace della sorgente in modalità `READ ONLY` per l'intera durata del trasferimento fisico dei datafile e della loro conversione di Endianness. Per un database di 10 TB, la sola copia fisica dei file via rete può richiedere più di 15 ore, costringendo l'applicazione a un downtime prolungato e inaccettabile.

### La Soluzione: RMAN Cross-Platform Incremental Backups (XTTS)
La tecnica **XTTS con RMAN Incremental Backups** (MOS Note **1389592.1**) risolve radicalmente questo scenario. Consente di copiare e convertire i datafile in anticipo mentre il database di origine è **aperto in lettura e scrittura (`READ WRITE`)**, mantenendo allineato il database di destinazione (target) tramite l'applicazione periodica di backup incrementali eseguiti a caldo sulla sorgente.

```
 SORGENTE (AIX / Big-Endian)                              TARGET (Linux / Little-Endian)
 ┌─────────────────────────┐                              ┌─────────────────────────┐
 │   DATABASE ATTIVO       │                              │   DATABASE STANDBY      │
 │    (READ WRITE)         │                              │       (MOUNT)           │
 ├─────────────────────────┤                              ├─────────────────────────┤
 │                         │                              │                         │
 │ 1. Backup Level 0 ──────┼─────── Copia Rete ──────────►│ 2. Conversione Endian   │
 │    (A caldo - 10 TB)    │                              │    (Carica in ASM Target)│
 │                         │                              │                         │
 │ 3. Backup Level 1 ──────┼─────── Copia Rete ──────────►│ 4. Conversione + Apply  │
 │    (Delta Giornaliero)  │                              │    (RMAN Incremental)   │
 │                         │                              │                         │
 │                         │   --- FINESTRA DI CUTOVER ---│                         │
 │ 5. Tablespace READ ONLY │                              │                         │
 │ 6. Ultimo Level 1 (Delta)───► Copia ed Apply finale ──►│ 7. plugging Metadati    │
 │    (Pochi MB / Secondi) │                              │ 8. Tablespace READ WRITE│
 └─────────────────────────┘                              └─────────────────────────┘
```

Durante il cutover finale, il downtime è ridotto esclusivamente al tempo necessario per:
1.  Impostare i tablespace della sorgente in `READ ONLY`.
2.  Eseguire l'ultimo backup incrementale (estremamente piccolo, contenente solo le modifiche dell'ultima giornata o ora).
3.  Applicare l'ultimo incrementale e importare i metadati logici nel target (operazione che richiede circa 15-30 minuti complessivi indipendentemente dalla dimensione fisica del database).

---

## 2. Architettura & Teoria dell'Endianness

L'**Endianness** rappresenta l'ordine in cui i byte che compongono un dato numerico o testuale sono memorizzati nella memoria fisica e sul disco.
*   **Big-Endian (MSB al primo indirizzo)**: Utilizzato da processori proprietari RISC (IBM POWER su AIX, SPARC su Solaris). Il byte più significativo viene memorizzato per primo.
*   **Little-Endian (LSB al primo indirizzo)**: Utilizzato da processori x86_64 (Intel, AMD) e ARM. Il byte meno significativo viene memorizzato per primo.

A causa di questa incompatibilità strutturale, un datafile Oracle generato su IBM AIX non può essere montato e letto nativamente da un'istanza Oracle su Linux. I blocchi fisici del database devono essere convertiti.
Il tool `xtt.pl` provvede alla conversione dei blocchi sfruttando comandi interni di RMAN (`CONVERT DATAFILE`), invertendo l'ordine dei byte a livello strutturale per renderli compatibili con l'architettura target.

---

## 3. Dissezione Dettagliata di `xtt.properties`

Il file `xtt.properties` è il file di configurazione centrale utilizzato dal motore Perl `xtt.pl`. Deve essere posizionato sul server sorgente e destinazione ed allineato meticolosamente.

```properties
# =====================================================================
# CONFIGURAZIONE ENTERPRISE XTTS - xtt.properties
# =====================================================================

# 1. Elenco dei tablespace da migrare.
# IMPORTANTE: Separare i nomi solo con la virgola, SENZA SPAZI.
tablespaces=TS_CRM_DATA,TS_CRM_INDEX,TS_CRM_LOB,TS_CRM_ARCHIVE

# 2. Platform ID della piattaforma sorgente.
# Per trovare l'ID esatto, interroga v$transportable_platform sul primario.
# Esempio: 6 = IBM AIX (64-bit), 2 = Oracle Solaris (64-bit), 18 = HP-UX IA (64-bit)
platformid=6

# 3. Stringhe di connessione TNS per gli utenti amministrativi.
# Devono puntare alle istanze corrette ed usare utenze dotate di privilegi SYSDBA.
src_conn_str=sys/SecureEnterprisePassword123#@AIX_CRM_SORGENTE
dest_conn_str=sys/SecureEnterprisePassword123#@LINUX_CRM_TARGET

# 4. Directory di staging sul server SORGENTE.
# Deve risiedere su un filesystem veloce dotato di spazio sufficiente per ospitare
# i backup incrementali correnti e il file descrittore xttplan.txt.
dfcopydir=/u01/app/oracle/backup/xtts_stage

# 5. Formato del nome per il backup incrementale.
# La directory indicata deve essere scrivibile dall'utente oracle.
backupformat=/u01/app/oracle/backup/xtts_backups

# 6. Directory di staging sul server TARGET.
# È la directory di transito in cui vengono copiati i datafile e gli incrementali
# prima di essere convertiti e caricati in ASM.
stageondest=/u02/app/oracle/backup/xtts_stage

# 7. Destinazione fisica finale in ASM sul server target.
# Il tool caricherà qui i datafile convertiti in formato Little-Endian.
storageondest=+DATACG

# 8. Parametri di tuning opzionali (consigliati per ottimizzare il parallelismo RMAN)
# Definisce quanti canali RMAN paralleli utilizzare per la conversione fisica.
parallel=8
```

---

## 4. Validazione del Transportable Set: `DBMS_TTS`

Prima di avviare il backup iniziale Level 0, è **condizione bloccante** assicurarsi che l'insieme di tablespace selezionati non contenga violazioni referenziali logiche o fisiche. L'omissione di questo controllo causerà il fallimento del plugging finale durante la finestra di cutover, rendendo nullo tutto il lavoro di allineamento incrementale eseguito nei giorni precedenti.

### 4.1 Eseguire il controllo di autosufficienza
Connettiti al database sorgente come `SYSDBA` ed avvia l'analisi:

```sql
sqlplus / as sysdba

-- 1. Avvia la validazione
EXEC DBMS_TTS.TRANSPORT_SET_CHECK('TS_CRM_DATA,TS_CRM_INDEX,TS_CRM_LOB,TS_CRM_ARCHIVE', TRUE);

-- 2. Verifica se ci sono violazioni registrate a dizionario
SELECT * FROM transport_set_violations;
```

### 4.2 Analisi e Risoluzione dei principali errori di violazione:

| Violazione Riscontrata | Causa Primaria | Azione Correttiva del DBA |
|---|---|---|
| `Constraint VIOLATED: Foreign key on table APP_CRM.ORDERS (TS_CRM_DATA) references table APP_CRM.CUSTOMERS (USERS)` | Il tablespace `USERS` non è incluso nella lista di migrazione, ma contiene la tabella padre di un vincolo di foreign key. | Spostare la tabella padre nel set di tablespace migrati, oppure includere il tablespace `USERS` nella lista, oppure disabilitare temporaneamente il vincolo prima dell'export dei metadati. |
| `Index APP_CRM.CUST_EMAIL_IDX in tablespace USERS points to table APP_CRM.CUSTOMERS in tablespace TS_CRM_DATA` | Un indice risiede al di fuori del set di tablespace migrati. | Eseguire un rebuild dell'indice spostandolo all'interno del tablespace corretto: `ALTER INDEX APP_CRM.CUST_EMAIL_IDX REBUILD TABLESPACE TS_CRM_INDEX;` |
| `Lob segment LOB_PAYLOAD in tablespace TS_TEMP_LOB belongs to table APP_CRM.TRANSACTIONS in tablespace TS_CRM_DATA` | Il segmento LOB di una tabella risiede in un tablespace escluso. | Eseguire la migrazione fisica del segmento LOB: `ALTER TABLE APP_CRM.TRANSACTIONS MOVE LOB(LOB_PAYLOAD) STORE AS (TABLESPACE TS_CRM_LOB);` |

*Assicurarsi che la query `SELECT * FROM transport_set_violations;` restituisca esattamente **ZERO** righe prima di procedere.*

---

## 5. Esecuzione Pratica della Migrazione: Runbook Operativo

### Fase 1: Creazione e Inizializzazione (Sorgente ➔ Target)

#### 1. Setup dell'ambiente su Sorgente e Target
Scaricare lo zip del tool XTTS da My Oracle Support (MOS Note 1389592.1) e scompattarlo su entrambi i server sotto `/home/oracle/xtts/`. Configurare il file `xtt.properties` come descritto al punto 3.

#### 2. Esecuzione del Backup Level 0 (Sorgente in READ WRITE)
Il database sorgente è attivo e operativo. Avviamo la cattura iniziale dei datafile:

```bash
# SUL SERVER SORGENTE (AIX), come utente oracle:
export ORACLE_SID=crmdb
cd /home/oracle/xtts
perl xtt.pl -p
```
*Questo comando crea le copie fisiche dei datafile nella directory `/u01/app/oracle/backup/xtts_stage/` e genera il file descrittore delle modifiche `xttplan.txt`.*

#### 3. Trasferimento fisico dei datafile sul server Target
Trasferiamo i file sul server di destinazione Linux. Per database di grandi dimensioni, utilizzare strumenti in grado di parallelizzare la copia (es. `rsync` con ssh multiplo o canali NFS condivisi).

```bash
# Esempio di copia con rsync
rsync -avP /u01/app/oracle/backup/xtts_stage/* oracle@linux_target:/u02/app/oracle/backup/xtts_stage/
```

#### 4. Conversione di Endianness e Caricamento in ASM (Target)
Sul database target (che deve essere avviato in stato di `NOMOUNT` o `MOUNT`), convertiamo i datafile da Big-Endian a Little-Endian e carichiamoli direttamente in ASM:

```bash
# SUL SERVER TARGET (Linux), come utente oracle:
export ORACLE_SID=crmdb_tgt
cd /home/oracle/xtts
perl xtt.pl -c
```
*I file vengono scritti nel disk group ASM `+DATACG` con la struttura corretta. Il tool genera un file `xttnewdatafiles.txt` contenente la mappatura dei nuovi file in ASM.*

---

### Fase 2: Sincronizzazione Incrementale (Ripetuta per ridurre il Lag)

Nei giorni o nelle settimane che precedono il go-live finale, eseguiamo periodicamente la cattura e l'applicazione dei backup incrementali (Level 1) per mantenere allineata la destinazione.

#### 1. Creazione del Backup Incrementale sulla Sorgente
```bash
# SUL SERVER SORGENTE
cd /home/oracle/xtts
perl xtt.pl -a
```
*Questo comando analizza il file `xttplan.txt`, rileva il SCN dell'ultimo backup ed esegue un backup incrementale contenente solo i blocchi fisici modificati a partire da quella data.*

#### 2. Trasferimento dei file incrementali e del piano sul Target
```bash
scp /u01/app/oracle/backup/xtts_backups/* oracle@linux_target:/u01/app/oracle/backup/xtts_backups/
scp /home/oracle/xtts/xttplan.txt oracle@linux_target:/home/oracle/xtts/
```

#### 3. Applicazione del Backup Incrementale sul Target
```bash
# SUL SERVER TARGET
cd /home/oracle/xtts
perl xtt.pl -r
```
*Il tool converte al volo l'incrementale Little-Endian ed esegue un `RECOVER` RMAN sui datafile già caricati in ASM.*

> [!TIP]
> **Finestra di Sincronizzazione**: In ambienti critici, ripeti questo ciclo di Fase 2 ogni 12 o 24 ore. L'ultimo giorno di allineamento prima del cutover, ripetilo ogni 4 ore. Questo garantisce che l'incrementale finale sia microscopico, riducendo il tempo di applicazione a meno di 5 minuti.

---

### Fase 3: Cutover Finale & Go-Live (Downtime App)

Durante la finestra di manutenzione pianificata:

#### 1. Stop dell'applicazione e Tablespace in Sola Lettura sulla Sorgente
Assicurati che non vi siano transazioni attive sul database sorgente, quindi metti i tablespace in `READ ONLY`:

```sql
-- SUL SERVER SORGENTE
sqlplus / as sysdba
ALTER TABLESPACE TS_CRM_DATA READ ONLY;
ALTER TABLESPACE TS_CRM_INDEX READ ONLY;
ALTER TABLESPACE TS_CRM_LOB READ ONLY;
ALTER TABLESPACE TS_CRM_ARCHIVE READ ONLY;
```

#### 2. Esecuzione dell'ultimo Backup Incrementale finale
```bash
# SUL SERVER SORGENTE
cd /home/oracle/xtts
perl xtt.pl -a
```
*Questo backup incrementale finale congela lo stato dei dati al secondo esatto dell'impostazione in READ ONLY.*

#### 3. Trasferimento e applicazione sul Target
```bash
# Copia l'ultimo delta
scp /u01/app/oracle/backup/xtts_backups/* oracle@linux_target:/u01/app/oracle/backup/xtts_backups/
scp /home/oracle/xtts/xttplan.txt oracle@linux_target:/home/oracle/xtts/

# SUL SERVER TARGET: applica l'ultimo delta
cd /home/oracle/xtts
perl xtt.pl -r
```
*Ora i datafile residenti in ASM sul target sono identici bit-per-bit alla sorgente.*

#### 4. Esportazione dei Metadati logici dal database Sorgente
Data Pump esporterà solo la struttura logica (sinonimi, grant, dizionario, viste) associata ai tablespace, poiché i dati fisici sono già stati copiati e convertiti in ASM sul target.

```bash
# SUL SERVER SORGENTE
expdp system/SecureEnterprisePassword123# \
  transport_tablespaces=TS_CRM_DATA,TS_CRM_INDEX,TS_CRM_LOB,TS_CRM_ARCHIVE \
  transport_full_check=y \
  directory=DPUMP_DIR \
  dumpfile=xtts_metadata_plug.dmp \
  logfile=xtts_export_metadata.log
```

#### 5. Plugging del Tablespace sul database Target
Trasferisci il file dump `xtts_metadata_plug.dmp` sul target. Colleghiamo fisicamente i datafile in ASM al dizionario dati del nuovo database Linux. La lista esatta dei datafile ASM da passare può essere ricavata dal file di configurazione generato dal tool `/home/oracle/xtts/xttnewdatafiles.txt`.

```bash
# SUL SERVER TARGET
impdp system/SecureEnterprisePassword123# \
  directory=DPUMP_DIR \
  dumpfile=xtts_metadata_plug.dmp \
  logfile=xtts_import_metadata.log \
  transport_datafiles= \
'+DATACG/crmdb_tgt/datafile/ts_crm_data.256.10394857', \
'+DATACG/crmdb_tgt/datafile/ts_crm_index.257.10394859', \
'+DATACG/crmdb_tgt/datafile/ts_crm_lob.258.10394861', \
'+DATACG/crmdb_tgt/datafile/ts_crm_archive.259.10394863'
```

#### 6. Attivazione dei Tablespace in Scrittura sul Target
```sql
-- SUL SERVER TARGET
sqlplus / as sysdba
ALTER TABLESPACE TS_CRM_DATA READ WRITE;
ALTER TABLESPACE TS_CRM_INDEX READ WRITE;
ALTER TABLESPACE TS_CRM_LOB READ WRITE;
ALTER TABLESPACE TS_CRM_ARCHIVE READ WRITE;
```
**MIGRAZIONE COMPLETATA CON SUCCESSO!** L'applicazione può ora essere riavviata puntando al nuovo database target Linux.

---

## 6. Risoluzione Problemi & Triage Avanzato

### 6.1 Errore ORA-19721 durante il backup incrementale (`xtt.pl -a`)
*   **Problema**: L'esecuzione della fase `-a` fallisce restituendo `ORA-19721: Cannot find change tracking file` o `RMAN-00554`.
*   **Causa**: Il file descrittore `xttplan.txt` è stato modificato, eliminato accidentalmente o non è allineato tra la sorgente e la destinazione.
*   **Risoluzione**:
    1.  Verificare la presenza di `xttplan.txt` in `/home/oracle/xtts/` su entrambi i server.
    2.  Se il file è andato perso, è possibile rigenerarlo estraendo il SCN minimo corrente dei datafile sul database target in ASM tramite query SQL:
        ```sql
        SELECT MIN(checkpoint_change#) FROM v$datafile_header WHERE tablespace_name IN ('TS_CRM_DATA','TS_CRM_INDEX','TS_CRM_LOB','TS_CRM_ARCHIVE');
        ```
    3.  Inserire manualmente questo valore SCN all'interno di un nuovo file `xttplan.txt` per consentire al tool di riprendere la cattura incrementale da quel punto preciso.

### 6.2 Risoluzione dei Gap di Sincronizzazione SCN
Se per motivi infrastrutturali non è stato possibile eseguire la sincronizzazione per diversi giorni e l'applicazione del backup incrementale fallisce a causa di un gap eccessivo di SCN:
*   **Soluzione**: È possibile forzare l'applicazione manuale bypassando momentaneamente il tool `xtt.pl`. Genera un backup incrementale RMAN classico sulla sorgente a partire dal SCN minimo del target, trasferisci il file dump di backup ed applicalo manualmente sul target avviando RMAN:
    ```
    RMAN> RECOVER DATAFILE '+DATACG/crmdb_tgt/datafile/ts_crm_data.256.10394857' FROM BACKUPSET '/percorso/file_incrementale';
    ```
