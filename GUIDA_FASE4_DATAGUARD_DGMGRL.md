# FASE 4: Configurazione Data Guard Broker (DGMGRL)

> Data Guard Broker è il "pannello di controllo" centralizzato per gestire la configurazione Data Guard. Senza Broker potresti gestire tutto manualmente (con ALTER SYSTEM SET ...), ma Broker semplifica enormemente switchover, failover e monitoraggio.

### Switchover vs Failover — La Differenza Cruciale

```
  SWITCHOVER (Pianificato, 0 data loss)         FAILOVER (Emergenza!)
  ══════════════════════════════════════         ═══════════════════════

  PRIMA:                                        PRIMA:
  ┌────────┐    redo    ┌────────┐              ┌────────┐    redo    ┌────────┐
  │PRIMARY │───────────►│STANDBY │              │PRIMARY │───────────►│STANDBY │
  │ RACDB  │            │RACDB_  │              │ RACDB  │     ✕      │RACDB_  │
  │  OPEN  │            │  STBY  │              │  💀    │   MORTO!   │  STBY  │
  │        │            │ MOUNT  │              │  DOWN  │            │ MOUNT  │
  └────────┘            └────────┘              └────────┘            └────────┘

  DOPO:                                         DOPO:
  ┌────────┐    redo    ┌────────┐              ┌────────┐             ┌────────┐
  │STANDBY │◄───────────│PRIMARY │              │  ???   │             │PRIMARY │
  │ RACDB  │            │RACDB_  │              │Richiede│             │RACDB_  │
  │ MOUNT  │            │  STBY  │              │REINSTATE             │  STBY  │
  │(ex-pri)│            │  OPEN  │              │o rifare│             │  OPEN  │
  └────────┘            └────────┘              │Fase 3  │             └────────┘
                                                └────────┘
  ✅ Ruoli invertiti      ✅ Zero data loss      ⚠️ Possibile data loss
  ✅ Reversibile           ✅ ~30 secondi         ⚠️ Vecchio primary da
                                                    ricostruire
```

---

## 4.1 Abilitare Data Guard Broker

Esegui su **TUTTI** i nodi (primario e standby):

```sql
sqlplus / as sysdba

ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';

EXIT;
```

> **Perché?** Questo parametro avvia il processo DMON (Data Guard Monitor) su ogni istanza. DMON è il "cervello" del Broker: gestisce la comunicazione, il monitoraggio e le operazioni automatiche.

### Verifica che DMON sia attivo

```bash
ps -ef | grep dmon
# Devi vedere un processo dmon_RACDB (o simile)
```

---

## 4.2 Creazione della Configurazione Broker

Connettiti a `dgmgrl` dal **nodo primario**:

```bash
# Come oracle su rac1
dgmgrl sys/<password>@RACDB
```

```
-- Crea la configurazione
CREATE CONFIGURATION dg_config AS
  PRIMARY DATABASE IS RACDB
  CONNECT IDENTIFIER IS RACDB;

-- Aggiungi il database standby
ADD DATABASE RACDB_STBY AS
  CONNECT IDENTIFIER IS RACDB_STBY
  MAINTAINED AS PHYSICAL;

-- Abilita la configurazione
ENABLE CONFIGURATION;
```

> 📸 **SNAPSHOT — "SNAP-13: Pre-DGMGRL"**
> Fai questo snapshot PRIMA di eseguire ENABLE CONFIGURATION. Se il Broker si configura male, può essere difficile da pulire.
> ```
> VBoxManage snapshot "rac1" take "SNAP-13_Pre_DGMGRL"
> VBoxManage snapshot "rac2" take "SNAP-13_Pre_DGMGRL"
> VBoxManage snapshot "racstby1" take "SNAP-13_Pre_DGMGRL"
> VBoxManage snapshot "racstby2" take "SNAP-13_Pre_DGMGRL"
> ```

> **Spiegazione:**
> - `CREATE CONFIGURATION`: Definisce il nome della configurazione DG.
> - `PRIMARY DATABASE IS RACDB`: Dice al Broker quale è il primario.
> - `CONNECT IDENTIFIER IS RACDB`: Usa l'alias TNS `RACDB` per connettersi.
> - `ADD DATABASE ... MAINTAINED AS PHYSICAL`: Aggiunge lo standby come Physical Standby (non Logical).
> - `ENABLE CONFIGURATION`: Attiva tutto. Da questo momento, Broker gestisce il redo shipping.

---

## 4.3 Verifica Stato della Configurazione

```
DGMGRL> SHOW CONFIGURATION;
```

Output atteso:
```
Configuration - dg_config

  Protection Mode: MaxPerformance
  Members:
  RACDB       - Primary database
    RACDB_STBY  - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS   (status updated ... ago)
```

> Se vedi `SUCCESS`, la configurazione è operativa! Se vedi `WARNING` o `ERROR`, usa i comandi sotto per diagnosticare.

```
DGMGRL> SHOW DATABASE RACDB;
DGMGRL> SHOW DATABASE RACDB_STBY;
```

Output di `SHOW DATABASE RACDB_STBY`:
```
Database - RACDB_STBY

  Role:               PHYSICAL STANDBY
  Intended State:     APPLY-ON
  Transport Lag:      0 seconds (computed ... ago)
  Apply Lag:          0 seconds (computed ... ago)
  Apply Rate:         ... KByte/s
  Real Time Query:    OFF
  Instance(s):
    RACDB1    (apply instance)
    RACDB2

Database Status:
SUCCESS
```

> - **Transport Lag**: Quanto ritardo c'è nella spedizione dei redo dal primario allo standby. Idealmente 0.
> - **Apply Lag**: Quanto ritardo c'è nell'applicazione dei redo sullo standby. Idealmente 0 o pochi secondi.
> - **Apply Rate**: La velocità di applicazione.

> 📸 **SNAPSHOT — "SNAP-14: DGMGRL Configurato e SUCCESS" ⭐ MILESTONE**
> Data Guard Broker è operativo con STATUS = SUCCESS. Punto sicuro per i test di switchover.
> ```
> VBoxManage snapshot "rac1" take "SNAP-14_DGMGRL_SUCCESS"
> VBoxManage snapshot "rac2" take "SNAP-14_DGMGRL_SUCCESS"
> VBoxManage snapshot "racstby1" take "SNAP-14_DGMGRL_SUCCESS"
> VBoxManage snapshot "racstby2" take "SNAP-14_DGMGRL_SUCCESS"
> ```

---

## 4.4 Configurazione Protection Mode

Oracle Data Guard offre 3 modalità di protezione:

```
╔═══════════════════╦══════════════════╦══════════════╦═══════════════════════╗
║ Mode              ║ Data Loss?       ║ Performance  ║ Se lo standby muore? ║
╠═══════════════════╬══════════════════╬══════════════╬═══════════════════════╣
║ Max Performance   ║ Possibile        ║ ⚡ Alta       ║ Il primario continua ║
║ (ASYNC - default) ║ (pochi secondi)  ║              ║ senza problemi       ║
╠═══════════════════╬══════════════════╬══════════════╬═══════════════════════╣
║ Max Availability  ║ Zero (se standby ║ ⚡⚡ Media    ║ Fallback ad ASYNC,   ║
║ (SYNC + fallback) ║ raggiungibile)   ║              ║ primario continua    ║
╠═══════════════════╬══════════════════╬══════════════╬═══════════════════════╣
║ Max Protection    ║ Zero (assoluto!) ║ 🐢 Bassa    ║ ⛔ IL PRIMARIO SI    ║
║ (SYNC obbligato)  ║                  ║              ║    FERMA!!!          ║
╚═══════════════════╩══════════════════╩══════════════╩═══════════════════════╝
```

> **Per il lab** → usiamo **Maximum Performance** (default). In produzione la scelta dipende dal RPO (Recovery Point Objective) dell'azienda.

```
DGMGRL> SHOW CONFIGURATION;
-- Deve mostrare "Protection Mode: MaxPerformance"
```

Se volessi cambiare (esempio Maximum Availability):

```
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MaxAvailability;
```

---

## 4.5 Test Switchover

Lo switchover è un'operazione **pianificata** che inverte i ruoli: il primario diventa standby e lo standby diventa primario. È a zero data loss.

```
DGMGRL> VALIDATE DATABASE RACDB_STBY;
```

Output: deve mostrare "Ready for Switchover: Yes"

```
DGMGRL> SWITCHOVER TO RACDB_STBY;
```

> **Cosa succede dietro le quinte?**
> 1. Il primario (RACDB) fa flush di tutti i redo pendenti verso lo standby.
> 2. Il primario si converte in standby (cambia il controlfile).
> 3. Lo standby (RACDB_STBY) si converte in primario.
> 4. Il vecchio primario inizia a ricevere redo dal nuovo primario.
>
> In un RAC, tutte le istanze vengono fermate e riavviate automaticamente dal Broker.

Verifica dopo lo switchover:

```
DGMGRL> SHOW CONFIGURATION;
```

```
Configuration - dg_config
  Members:
  RACDB_STBY  - Primary database    <-- Ora è lui il primario!
    RACDB       - Physical standby database

Configuration Status:
SUCCESS
```

### Switchover di ritorno (ripristina la situazione originale)

```
DGMGRL> SWITCHOVER TO RACDB;

DGMGRL> SHOW CONFIGURATION;
-- RACDB torna primario, RACDB_STBY torna standby
```

> 📸 **SNAPSHOT — "SNAP-15: Post-Switchover/Switchback OK"**
> Lo switchover e il switchback sono riusciti! La tua configurazione DG è solida.
> ```
> VBoxManage snapshot "rac1" take "SNAP-15_Switchover_OK"
> VBoxManage snapshot "rac2" take "SNAP-15_Switchover_OK"
> VBoxManage snapshot "racstby1" take "SNAP-15_Switchover_OK"
> VBoxManage snapshot "racstby2" take "SNAP-15_Switchover_OK"
> ```

---

## 4.6 Test Failover (solo in caso di emergenza reale)

Il failover è un'operazione **NON pianificata** usata quando il primario è irraggiungibile. Può comportare perdita di dati (se non in MaxProtection).

> **⚠️ ATTENZIONE**: Non eseguire un failover in un lab se non sei pronto a reinstanziare lo standby dopo. Dopo un failover, il vecchio primario NON può ridiventare standby automaticamente (serve un "reinstate" o una ricreazione).

```
-- Solo se il primario è davvero down!
DGMGRL> FAILOVER TO RACDB_STBY;
```

Dopo il failover, per ripristinare il vecchio primario come standby:

```
-- Se il vecchio primario è riavviabile
DGMGRL> REINSTATE DATABASE RACDB;
```

> Se `REINSTATE` fallisce, devi ricreare lo standby con RMAN Duplicate (Fase 3).

---

## 4.7 Abilitare Active Data Guard (Read-Only sullo Standby)

Active Data Guard (ADG) permette di aprire lo standby in **READ ONLY** mentre continua ad applicare i redo. Fondamentale per GoldenGate nella Fase 5.

```sql
-- Sullo standby come sysdba
sqlplus / as sysdba

-- Apri in read only
ALTER DATABASE OPEN READ ONLY;

-- Verifica
SELECT open_mode FROM v$database;
-- Deve mostrare: READ ONLY WITH APPLY
```

Oppure con `srvctl`:

```bash
srvctl modify database -d RACDB_STBY -startoption "READ ONLY"
srvctl stop database -d RACDB_STBY
srvctl start database -d RACDB_STBY
```

> **Perché ADG?** Senza ADG, lo standby è in MOUNT (inaccessibile ai client). Con ADG, puoi eseguire query sullo standby per scaricare il carico dal primario. Inoltre, GoldenGate può fare fetch dei dati supplementari direttamente dallo standby.

---

## 4.8 Comandi DGMGRL Utili (Cheat Sheet)

```
-- Stato generale
SHOW CONFIGURATION;
SHOW CONFIGURATION VERBOSE;

-- Dettaglio database
SHOW DATABASE RACDB;
SHOW DATABASE RACDB_STBY;

-- Verifica switchover readiness
VALIDATE DATABASE RACDB_STBY;

-- Controllare i log
SHOW DATABASE RACDB_STBY LogShipping;
SHOW DATABASE RACDB_STBY StatusReport;

-- Disabilitare temporaneamente
DISABLE DATABASE RACDB_STBY;
ENABLE DATABASE RACDB_STBY;

-- Cambiare la proprietà di trasporto
EDIT DATABASE RACDB_STBY SET PROPERTY LogXptMode='SYNC';  -- o 'ASYNC'
```

---

## ✅ Checklist Fine Fase 4

```
DGMGRL> SHOW CONFIGURATION;
-- Configuration Status: SUCCESS

DGMGRL> SHOW DATABASE RACDB_STBY;
-- Transport Lag: 0 seconds
-- Apply Lag: 0 seconds o pochi secondi
-- Database Status: SUCCESS
```

---

**→ Prossimo: [FASE 5: Configurazione GoldenGate](./GUIDA_FASE5_GOLDENGATE.md)**
