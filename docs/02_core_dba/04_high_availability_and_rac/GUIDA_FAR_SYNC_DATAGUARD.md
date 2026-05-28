# GUIDA: Oracle Data Guard Far Sync — Zero Data Loss a Distanza Illimitata

> [!NOTE]
> **DOCUMENTI DI ALTA AFFIDABILITÀ CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Data Guard Far Sync (questa guida)**: [GUIDA_FAR_SYNC_DATAGUARD.md](./GUIDA_FAR_SYNC_DATAGUARD.md) (architettura, setup, SYNC a corto raggio, ASYNC a lungo raggio).
> - **Application Continuity & Failover**: [GUIDA_APPLICATION_CONTINUITY_TAF.md](./GUIDA_APPLICATION_CONTINUITY_TAF.md) (transparent application failover, JDBC, UCP).
> - **Single Node Data Guard**: [GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md](./GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md) (architettura a singolo nodo primario e standby).
> - **RAC Data Guard**: [GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md](./GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md) (architettura multi-nodo primario e standby).

---

## 1. Cos'è e a cosa serve un'istanza Far Sync?

Nelle architetture di Disaster Recovery (DR) geografiche, la distanza introduce latenza di rete (Round Trip Time - RTT). 
*   Se usiamo il trasporto **SYNC** (sincrono) verso un sito DR lontano 500 km, la latenza di rete rallenta pesantemente i `COMMIT` delle applicazioni sul database primario.
*   Se usiamo il trasporto **ASYNC** (asincrono) per non impattare sulle prestazioni, in caso di disastro sul sito primario rischiamo una **perdita di dati** (RPO > 0).

**Oracle Data Guard Far Sync** risolve questo dilemma. È un'istanza "leggera" (senza datafile, contenente solo controlfile e standby redo logs, che gira in stato di `MOUNT`) posizionata a **brevissima distanza** dal sito primario (es. 10-20 km, con RTT < 2ms):

```
 ┌─────────────────┐             ┌─────────────────┐             ┌─────────────────┐
 │   SITO LOCAL    │   SYNC/AFFIRM │  SITO PROSSIMO  │   ASYNC     │   SITO REMOTE   │
 │                 │──────────────►│    FAR SYNC     │────────────►│  RECO STANDBY   │
 │   RAC PRIMARY   │  (No Latenza) │  (Solo Redo/SRL)│  (Distanza) │  PHYS STANDBY   │
 │   (RACDB)       │               │  (RACDB_FSYNC)  │             │  (RACDB_STBY)   │
 └─────────────────┘             └─────────────────┘             └─────────────────┘
```

1.  Il Primario invia i redo log in **SYNC** all'istanza Far Sync locale. La latenza è trascurabile, salvaguardando le prestazioni applicative.
2.  L'istanza Far Sync riceve i redo nei suoi Standby Redo Logs (SRL) e invia immediatamente l'ACK al primario (garantendo **Zero Data Loss**).
3.  L'istanza Far Sync rilancia in tempo reale i redo in modalità **ASYNC** verso il vero database Standby remoto situato a centinaia di chilometri.

---

## 2. Caratteristiche Fisiche del Far Sync
Un'istanza Far Sync:
*   **NON ha datafile**: occupa pochissimo spazio su disco (solo controlfile, tempfile e redo log).
*   **NON esegue recovery**: non applica i redo log (non consuma CPU per l'applicazione dei dati).
*   **Gira solo in MOUNT**: non può essere aperta in sola lettura (non consuma licenze Active Data Guard).
*   **È gestita interamente dal Broker (DGMGRL)**: in caso di switchover o failover, il Broker riconfigura automaticamente i flussi di redo (Redo Routes).

---

## 3. Workflow di Setup Operativo

### Step 1: Creazione della Directory e del Controlfile del Far Sync
Sul database primario (`RACDB`), crea il file di controllo speciale per l'istanza Far Sync:

```sql
sqlplus / as sysdba

ALTER DATABASE CREATE STANDBY CONTROLFILE AS '/tmp/control_fsync.ctl';
```

### Step 2: Preparazione del Parameter File (PFILE)
Crea un file di parametri (`initRACDB_FSYNC.ora`) per l'istanza Far Sync. Poiché non ci sono datafile, i parametri di memoria possono essere ridotti al minimo:

```ini
db_name=RACDB
db_unique_name=RACDB_FSYNC
compatible=19.0.0
control_files='+DATA/RACDB_FSYNC/control1.ctl'
db_recovery_file_dest='+RECO'
db_recovery_file_dest_size=10G
sga_target=2G
pga_aggregate_target=1G
fal_server=RACDB
```

Copia il controlfile creato al punto 1 nel disk group ASM della nuova istanza (`+DATA/RACDB_FSYNC/control1.ctl`) ed avvia l'istanza Far Sync in stato di `MOUNT`:

```sql
export ORACLE_SID=RACDB_FSYNC
sqlplus / as sysdba

STARTUP NOMOUNT PFILE='/tmp/initRACDB_FSYNC.ora';
-- Crea spfile condiviso in ASM:
CREATE SPFILE FROM PFILE='/tmp/initRACDB_FSYNC.ora';
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
```

---

## 4. Configurazione degli Standby Redo Logs (SRL)

L'istanza Far Sync deve avere abbastanza Standby Redo Logs (SRL) per ricevere i redo log dal primario. Gli SRL devono essere della stessa dimensione dei Redo Log del primario (es. 200MB) e deve essercene almeno uno in più rispetto al totale dei Redo Log del primario:

```sql
-- Esegui sull'istanza Far Sync in MOUNT
ALTER DATABASE ADD STANDBY LOGFILE GROUP 10 '+RECO' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 11 '+RECO' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 12 '+RECO' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE GROUP 13 '+RECO' SIZE 200M;
```

---

## 5. Configurazione del Broker & Redo Routes

Il vero potere di Far Sync si scatena configurando il Broker tramite **Redo Routes** (Rotte dei Redo). Dobbiamo istruire il Broker su come instradare i log durante l'operatività normale o dopo uno switchover.

Connettiti a `dgmgrl` sul primario:

```bash
dgmgrl sys/<password>@RACDB
```

### Step 1: Registrazione del Far Sync nel Broker
```
DGMGRL> ADD FAR_SYNC RACDB_FSYNC AS CONNECT IDENTIFIER IS RACDB_FSYNC;
```

### Step 2: Configurazione delle Rotte dei Redo (RedoRoutes)
Dobbiamo configurare le regole di instradamento in modo che:
*   Quando **`RACDB`** è primario: deve mandare in `SYNC` a `RACDB_FSYNC`, e `RACDB_FSYNC` deve rilanciare in `ASYNC` a `RACDB_STBY`.
*   Se l'istanza Far Sync cade: il primario deve poter mandare direttamente in `ASYNC` allo standby remoto (comportamento di fallback).

Impostiamo la proprietà `RedoRoutes` sul primario (`RACDB`):

```
DGMGRL> EDIT DATABASE RACDB SET PROPERTY RedoRoutes='(LOCAL : RACDB_FSYNC SYNC PRIORITY=1, RACDB_STBY ASYNC PRIORITY=2)';
```

Impostiamo la proprietà `RedoRoutes` sull'istanza Far Sync (`RACDB_FSYNC`):

```
DGMGRL> EDIT FAR_SYNC RACDB_FSYNC SET PROPERTY RedoRoutes='(RACDB : RACDB_STBY ASYNC)';
```

Impostiamo la configurazione speculare nel caso in cui avvenga uno switchover e **`RACDB_STBY`** diventi il primario (configurando un'eventuale seconda istanza Far Sync remota, o mandando in `ASYNC` speculare):

```
DGMGRL> EDIT DATABASE RACDB_STBY SET PROPERTY RedoRoutes='(LOCAL : RACDB ASYNC)';
```

### Step 3: Abilitare la Configurazione
```
DGMGRL> ENABLE FAR_SYNC RACDB_FSYNC;
DGMGRL> SHOW CONFIGURATION;
```

---

## 6. Verifica Post-Setup & Validazione dello Stato

```
DGMGRL> SHOW CONFIGURATION;
```

### Output Atteso:
```
Configuration - dg_config
  Protection Mode: MaxAvailability    <-- Ora puoi abilitare MaxAvailability senza rallentare il primario!
  Members:
  RACDB       - Primary database
    RACDB_FSYNC - Far sync instance   <-- Integrata e attiva!
      RACDB_STBY  - Physical standby database (sincronizzato via Far Sync)

Configuration Status: SUCCESS
```

Verifica il flusso reale dei redo log sul primario:

```sql
sqlplus / as sysdba

-- Controlla lo stato delle destinazioni di archiviazione
SELECT dest_id, destination, status, target, error 
FROM   v$archive_dest_status 
WHERE  status != 'INACTIVE';
```
*Dovresti vedere la destinazione puntare all'alias TNS `RACDB_FSYNC` in stato `VALID` e con tipo trasporto `SYNC`.*
