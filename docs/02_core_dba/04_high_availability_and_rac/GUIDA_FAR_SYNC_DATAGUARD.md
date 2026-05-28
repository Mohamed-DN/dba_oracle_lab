# GUIDA MONUMENTALE: Oracle Data Guard Far Sync — Zero Data Loss a Distanza Geografica Illimitata


## [ARCHITETTURA VISIVA] Far Sync Data Guard
```text

[ Primary DB ] --- SYNC Redo ---> [ Far Sync Instance ] --- ASYNC Redo ---> [ Standby DB ]
 (New York)        (Bassa Latenza)     (New York)         (Alta Latenza)       (London)
```

> [!NOTE]
> **DOCUMENTI DI ALTA AFFIDABILITÀ CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Data Guard Far Sync (questa guida)**: [GUIDA_FAR_SYNC_DATAGUARD.md](./GUIDA_FAR_SYNC_DATAGUARD.md) (architettura, setup, SYNC a corto raggio, ASYNC a lungo raggio, Broker & Redo Routes).
> - **Application Continuity & Failover**: [GUIDA_APPLICATION_CONTINUITY_TAF.md](./GUIDA_APPLICATION_CONTINUITY_TAF.md) (transparent application failover, JDBC, UCP, Transaction Guard).
> - **Single Node Data Guard**: [GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md](./GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md) (architettura a singolo nodo primario e standby).
> - **RAC Data Guard**: [GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md](./GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md) (architettura multi-nodo primario e standby).

---

## 1. Cos'è un'istanza Far Sync? Architettura e Benefici

Nelle architetture di Disaster Recovery (DR) geografiche, la distanza fisica introduce inevitabilmente una latenza di rete basata sul Round Trip Time (RTT).
*   Se usiamo il trasporto **SYNC** (sincrono) verso un database secondario distante centinaia di chilometri per evitare perdite di dati (RPO = 0), la latenza della rete rallenta i commit delle applicazioni sul sito primario ad ogni transazione.
*   Se usiamo il trasporto **ASYNC** (asincrono) per salvaguardare le performance applicative, in caso di disastro sul sito primario rischiamo una perdita di dati (RPO > 0).

**Oracle Data Guard Far Sync** risolve brillantemente questo problema. È un membro speciale della configurazione Data Guard, un'istanza **"leggera"** (priva di datafile) situata a **brevissima distanza dal sito primario** (es. 10-30 km, RTT < 2ms) che funge da buffer ad alta velocità:

```
  SITO A (LOCAL)                   SITO B (PROSSIMO)               SITO C (REMOTE)
 +-----------------+             +-----------------+             +-----------------+
 |                 | SYNC/AFFIRM |                 |   ASYNC     |                 |
 |   PRIMARY DB    |------------&gt;|    FAR SYNC     |------------&gt;| PHYSICAL STANDBY|
 |   (RACDB)       |             |  (RACDB_FSYNC)  |             |   (RACDB_STBY)  |
 +-----------------+             +-----------------+             +-----------------+
                                   - In Mount                      - Applica Redo
                                   - No Datafiles                  - Datafiles attivi
                                   - Solo Controlfile & SRL
```

1.  Il database **Primario** invia i blocchi di redo in modalità **SYNC** (sincrona) all'istanza **Far Sync**. La latenza di rete è trascurabile grazie alla vicinanza geografica.
2.  L'istanza Far Sync riceve i redo all'interno dei suoi **Standby Redo Logs (SRL)** e risponde immediatamente al primario confermando la scrittura persistente. L'applicazione sul primario effettua il commit a piena velocità e i dati sono protetti contro disastri completi del sito principale (**Zero Data Loss**).
3.  L'istanza Far Sync inoltra in tempo reale i redo in modalità **ASYNC** (asincrona) verso il vero database **Standby Fisico** remoto situato a centinaia di chilometri.

### Caratteristiche Fisiche di un'istanza Far Sync:
*   **Zero Datafiles**: Non occupa spazio per i dati degli utenti (richiede solo controlfile, tempfile ed SRL).
*   **Zero Recovery Overhead**: Non applica i redo log ai file dati (gira sempre in stato di `MOUNT`). Non consuma CPU per elaborazioni SQL o allineamenti interni.
*   **Zero Costi di Licenza Extra**: Non richiede licenze Active Data Guard poiché il database non viene mai aperto in lettura (`OPEN READ ONLY`).
*   **Riconfigurazione Automatica**: Gestito al 100% dal Broker Data Guard (`DGMGRL`).

---

## 2. Regole di Dimensionamento degli Standby Redo Logs (SRL)

Affinché l'istanza Far Sync possa ricevere i redo log senza generare stalli sul primario, gli Standby Redo Logs (SRL) devono essere dimensionati in modo ottimale seguendo regole precise.

> [!IMPORTANT]
> **La Formula di Sizing Enterprise per gli SRL:**
> *   La dimensione di ogni SRL deve corrispondere **esattamente** alla dimensione del Redo Log Online (ORL) più grande del database primario.
> *   Il numero di SRL deve essere pari a: **(Numero totale di ORL per istanza sul Primario + 1) * Numero di istanze**.
> *   *Esempio*: In un cluster RAC a 2 nodi, dove ogni nodo ha 3 gruppi di redo log da 200MB, l'istanza Far Sync deve avere: `(3 + 1) * 2 = 8` Standby Redo Log da 200MB ciascuno.

---

## 3. Workflow di Setup Operativo Passo-Passo

### Step 1: Generazione del Controlfile di Standby sul Primario
Sul database primario (`RACDB`), creiamo il file di controllo specifico:

```sql
sqlplus / as sysdba

ALTER DATABASE CREATE STANDBY CONTROLFILE AS '/tmp/control_fsync.ctl';
```

### Step 2: Preparazione del PFILE per Far Sync
Crea un parameter file ridotto. Poiché Far Sync non contiene datafile, non necessita di buffer cache elevate o PGA massive.

```ini
db_name=RACDB
db_unique_name=RACDB_FSYNC
compatible=19.0.0
control_files='+DATA/RACDB_FSYNC/control1.ctl'
db_recovery_file_dest='+RECO'
db_recovery_file_dest_size=50G
sga_target=2G
pga_aggregate_target=1G
fal_server=RACDB
```

Copia il file di controllo `/tmp/control_fsync.ctl` all'interno dello storage ASM nella directory dell'istanza Far Sync (`+DATA/RACDB_FSYNC/control1.ctl`).

### Step 3: Avvio in Stato di MOUNT
```sql
export ORACLE_SID=RACDB_FSYNC
sqlplus / as sysdba

STARTUP NOMOUNT PFILE='/tmp/initRACDB_FSYNC.ora';
CREATE SPFILE FROM PFILE='/tmp/initRACDB_FSYNC.ora';
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
```

### Step 4: Setup degli Standby Redo Logs (SRL)
Aggiungiamo gli Standby Redo Logs all'istanza Far Sync seguendo la formula di sizing:

```sql
ALTER DATABASE ADD STANDBY LOGFILE GROUP 20 '+RECO' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 21 '+RECO' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 22 '+RECO' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 23 '+RECO' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 24 '+RECO' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 25 '+RECO' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 26 '+RECO' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 27 '+RECO' SIZE 200M;
```

---

## 4. Configurazione del Broker & Redo Routes (Rotte di Inoltro)

Le **Redo Routes** permettono di definire il flusso dinamico di transito dei blocchi di redo a seconda di chi detiene il ruolo di primario nel cluster.

Connettiti a `dgmgrl` sul primario per configurare la topologia:

```bash
dgmgrl sys/SecurePwd123#@RACDB
```

### Step 1: Registrazione di Far Sync nel Broker
```
DGMGRL> ADD FAR_SYNC RACDB_FSYNC AS CONNECT IDENTIFIER IS RACDB_FSYNC;
```

### Step 2: Configurazione delle Regole di Instradamento
Definiamo le regole in modo che:
*   Se **`RACDB`** è primario: invia in `SYNC` a `RACDB_FSYNC`. `RACDB_FSYNC` a sua volta rilancia in `ASYNC` allo standby remoto `RACDB_STBY`.
*   Se `RACDB_FSYNC` cade: il primario `RACDB` effettua il fallback automatico inviando direttamente in `ASYNC` allo standby `RACDB_STBY` (garantendo la continuità operativa del primario, sebbene in modalità MaxPerformance temporanea).

```
-- Configura le rotte sul primario
DGMGRL> EDIT DATABASE RACDB SET PROPERTY RedoRoutes='(LOCAL : RACDB_FSYNC SYNC PRIORITY=1, RACDB_STBY ASYNC PRIORITY=2)';

-- Configura le rotte sull'istanza Far Sync
DGMGRL> EDIT FAR_SYNC RACDB_FSYNC SET PROPERTY RedoRoutes='(RACDB : RACDB_STBY ASYNC)';

-- Configura la configurazione speculare di failover sul primario remoto
DGMGRL> EDIT DATABASE RACDB_STBY SET PROPERTY RedoRoutes='(LOCAL : RACDB ASYNC)';
```

### Step 3: Attivazione globale
```
DGMGRL> ENABLE FAR_SYNC RACDB_FSYNC;
```

---

## 5. Validazione Avanzata, Fast-Start Failover (FSFO) & Triage

Una volta attivata, possiamo sfruttare gli strumenti diagnostici di Data Guard per convalidare lo stato.

### 5.1 Validare l'istanza Far Sync tramite Broker
Il Broker fornisce un comando specifico per verificare la configurazione fisica ed i parametri di connessione dell'istanza Far Sync:

```
DGMGRL> VALIDATE FAR_SYNC RACDB_FSYNC;
```
*Questo comando esamina la raggiungibilità del listener, la presenza corretta degli Standby Redo Logs e l'allineamento dei blocchi.*

### 5.2 Interazione con Fast-Start Failover (FSFO) ed RPO = 0
In una classica configurazione geografica con trasporto asincrono, abilitare il **Fast-Start Failover (FSFO)** (il meccanismo di failover automatico controllato dall'Observer) presenta dei rischi: l'Observer potrebbe non autorizzare il failover per evitare la perdita di dati (se la proprietà `FastStartFailoverLagLimit` viene violata).

Con l'introduzione di **Far Sync**:
1.  Poiché il primario scrive in `SYNC` a Far Sync, i redo log sono **sempre completi al 100%** su quest'ultimo.
2.  In caso di crash improvviso del Primario, l'Observer rileva l'interruzione ed avvia la procedura di failover automatico.
3.  Lo Standby fisico remoto si connette a Far Sync, esegue il pull di tutti i blocchi di redo residui che non erano ancora stati inviati ed esegue il recovery completo.
4.  L'Observer conclude il failover automatico **garantendo Zero Data Loss (RPO = 0)** anche se lo standby è situato a centinaia di chilometri dal sito primario.

---

## 6. Risoluzione Problemi e Scenari di Emergenza

### 6.1 Stato di Lag Elevato sullo Standby Fisico remoto
*   **Problema**: Lo standby mostra un ritardo di applicazione elevato, ma la connessione tra Primario e Far Sync è valida.
*   **Causa**: La banda di rete o la latenza tra Far Sync ed il sito DR remoto non è sufficiente a gestire la velocità di scrittura (`ASYNC`).
*   **Triage (Esegui sul primario)**:
    ```sql
    SELECT destination, status, error FROM v$archive_dest_status WHERE dest_name = 'LOG_ARCHIVE_DEST_2';
    ```
    Verificare sul server Far Sync lo stato dei processi d'archiviazione:
    ```sql
    SELECT process, status, group# FROM v$managed_standby;
    ```
    *Assicurarsi che i processi `RFS` stiano scrivendo correttamente negli Standby Redo Logs di Far Sync e che il processo `ARC` o `ASYNC` li stia inoltrando.*
