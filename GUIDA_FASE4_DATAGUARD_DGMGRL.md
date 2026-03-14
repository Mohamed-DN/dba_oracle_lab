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

## 4.0 Ingresso da Fase 3 (allineamento rapido)

Prima di toccare DGMGRL, verifica che la Fase 3 sia davvero chiusa.

```sql
-- Sul primario
sqlplus / as sysdba
SELECT name, open_mode, database_role, db_unique_name FROM v$database;

-- Sullo standby
sqlplus / as sysdba
SELECT name, open_mode, database_role, db_unique_name FROM v$database;
SELECT process, status FROM v$managed_standby WHERE process='MRP0';
```

```bash
# Verifica TNS dal primario
tnsping RACDB
tnsping RACDB_STBY
tnsping RACDB_DG
tnsping RACDB_STBY_DG
```

Criteri minimi:

- primario `READ WRITE` con ruolo `PRIMARY`
- standby `PHYSICAL STANDBY` con `MRP0` attivo
- connettivita TNS ok sia alias SCAN (`RACDB`,`RACDB_STBY`) sia alias redo transport (`RACDB_DG`,`RACDB_STBY_DG`)

Se questi check falliscono, rientra in [GUIDA_FASE3_RAC_STANDBY.md](./GUIDA_FASE3_RAC_STANDBY.md) prima di continuare.

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

Se in passato hai gia creato una configurazione Broker (test precedenti), pulisci prima di ricreare:

```bash
dgmgrl sys/<password>@RACDB
SHOW CONFIGURATION;
-- Se esiste una configurazione precedente:
DISABLE CONFIGURATION;
REMOVE CONFIGURATION;
```

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



> **Spiegazione:**
> - `CREATE CONFIGURATION`: Definisce il nome della configurazione DG.
> - `PRIMARY DATABASE IS RACDB`: Dice al Broker quale è il primario.
> - `CONNECT IDENTIFIER IS RACDB`: Usa l'alias TNS `RACDB` per connettersi.
> - `ADD DATABASE ... MAINTAINED AS PHYSICAL`: Aggiunge lo standby come Physical Standby (non Logical).
> - `ENABLE CONFIGURATION`: Attiva tutto. Da questo momento, Broker gestisce il redo shipping.

### 4.2a Best practice Broker: DGConnectIdentifier esplicito

In RAC, e buona pratica usare alias dedicati al trasporto redo anche nel Broker.

```bash
dgmgrl sys/<password>@RACDB
```

```
DGMGRL> SHOW DATABASE VERBOSE RACDB;
DGMGRL> SHOW DATABASE VERBOSE RACDB_STBY;
```

Verifica il valore di `DGConnectIdentifier`. Se non e coerente con gli alias `_DG`, impostalo esplicitamente:

```
DGMGRL> EDIT DATABASE RACDB SET PROPERTY DGConnectIdentifier='RACDB_DG';
DGMGRL> EDIT DATABASE RACDB_STBY SET PROPERTY DGConnectIdentifier='RACDB_STBY_DG';
```

Poi riesegui:

```
DGMGRL> VALIDATE DATABASE RACDB;
DGMGRL> VALIDATE DATABASE RACDB_STBY;
```

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

> 📸 **SNAPSHOT — "SNAP-09: DGMGRL_Configurato" ⭐ MILESTONE**
> Data Guard Broker è operativo con STATUS = SUCCESS. Hai un vero sito di Disaster Recovery.
> ```bash
> VBoxManage snapshot "rac1" take "SNAP-09: DGMGRL_Configurato"
> VBoxManage snapshot "rac2" take "SNAP-09: DGMGRL_Configurato"
> VBoxManage snapshot "racstby1" take "SNAP-09: DGMGRL_Configurato"
> VBoxManage snapshot "racstby2" take "SNAP-09: DGMGRL_Configurato"
> ```

---

## 4.4 Configurazione Protection Mode

Questa sezione ti dice:
1. come scegliere la modalita corretta;
2. quali prerequisiti Oracle sono obbligatori;
3. come impostare davvero `MaxPerformance`, `MaxAvailability`, `MaxProtection`;
4. come verificare e tornare indietro senza rompere la configurazione.

### 4.4.1 Capire le 3 modalita (in pratica)

```
╔═══════════════════╦═══════════════════════════════════════════════════════════╦══════════════╗
║ Mode              ║ RPO / comportamento commit                               ║ Impatto       ║
╠═══════════════════╬═══════════════════════════════════════════════════════════╬══════════════╣
║ MaxPerformance    ║ Commit locale immediato, redo spedito ASYNC             ║ Minimo        ║
║ (default)         ║ (possibile perdita secondi in disastro)                 ║              ║
╠═══════════════════╬═══════════════════════════════════════════════════════════╬══════════════╣
║ MaxAvailability   ║ Obiettivo zero data loss quando standby sincronizzato;   ║ Medio         ║
║                   ║ se standby non risponde, primario resta disponibile      ║              ║
╠═══════════════════╬═══════════════════════════════════════════════════════════╬══════════════╣
║ MaxProtection     ║ Zero data loss prioritario assoluto; se non puo          ║ Alto          ║
║                   ║ proteggere i commit, il primario si ferma                ║              ║
╚═══════════════════╩═══════════════════════════════════════════════════════════╩══════════════╝
```

Regola veloce:
- se vuoi priorita performance: `MaxPerformance`
- se vuoi zero data loss sul primo fault ma senza bloccare il primario: `MaxAvailability`
- se vuoi zero data loss assoluto e accetti fermo primario: `MaxProtection`

Nota RAC:
- in `MaxAvailability`, se una sola istanza RAC perde la connettivita verso standby sincronizzato puo bloccarsi quella istanza; se tutte le istanze perdono connettivita, il database continua in comportamento equivalente a `MaxPerformance`.

### 4.4.2 Prerequisiti tecnici obbligatori (best practice Oracle)

Prima di cambiare mode, verifica:
1. `FORCE LOGGING` attivo sul primario.
2. Standby Redo Log (SRL) presenti su standby e anche sul primario (per role change/FSFO).
3. Standby in real-time apply.
4. Broker in `SUCCESS` e senza gap redo.
5. Per `MaxAvailability`/`MaxProtection`: almeno uno standby con redo transport `SYNC` o `FASTSYNC` (broker).
6. `Fast-Start Failover` disabilitato quando cambi protection mode (vincolo broker).
7. In RAC, `LOG_ARCHIVE_DEST_n` coerenti su tutte le istanze e net service con address list di tutti i nodi standby.
8. Se usi `SYNC`, configura timeout/retry coerenti (`NET_TIMEOUT`, `REOPEN`) per evitare stalli lunghi su fault di rete.

### 4.4.3 Pre-check operativo (prima del cambio mode)

```bash
dgmgrl sys/<password>@RACDB
```

```
DGMGRL> SHOW CONFIGURATION;
DGMGRL> SHOW DATABASE VERBOSE RACDB;
DGMGRL> SHOW DATABASE VERBOSE RACDB_STBY;
```

```sql
sqlplus / as sysdba
SELECT protection_mode, protection_level, database_role FROM v$database;
SELECT process, status FROM v$managed_standby WHERE process='MRP0';
SELECT dest_id, status, error FROM v$archive_dest_status WHERE dest_id IN (1,2);
```

### 4.4.4 Procedura A - Tenere/Impostare Maximum Performance (default lab)

Usala quando vuoi impatto minimo sul primario.

```
DGMGRL> EDIT DATABASE 'RACDB_STBY' SET PROPERTY LogXptMode='ASYNC';
DGMGRL> EDIT DATABASE 'RACDB'      SET PROPERTY LogXptMode='ASYNC';
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
DGMGRL> SHOW CONFIGURATION;
```

### 4.4.5 Procedura B - Passare a Maximum Availability (zero data loss sul primo fault)

Usala quando vuoi un equilibrio serio tra protezione e disponibilita.

Opzione standard (piu protettiva):
```
DGMGRL> EDIT DATABASE 'RACDB_STBY' SET PROPERTY LogXptMode='SYNC';
DGMGRL> EDIT DATABASE 'RACDB'      SET PROPERTY LogXptMode='SYNC';
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
```

Opzione ottimizzata latenza (FASTSYNC):
```
DGMGRL> EDIT DATABASE 'RACDB_STBY' SET PROPERTY LogXptMode='FASTSYNC';
DGMGRL> EDIT DATABASE 'RACDB'      SET PROPERTY LogXptMode='FASTSYNC';
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
```

Nota pratica:
- `SYNC` (con `AFFIRM`) protegge di piu, ma costa piu latenza.
- `FASTSYNC` (equivale a `SYNC/NOAFFIRM`) riduce impatto, ma in scenari multipli estremi puo esporre a perdita dati.

### 4.4.6 Procedura C - Passare a Maximum Protection (solo se consapevole dell'impatto)

Attenzione:
- da `MAXPERFORMANCE` non puoi passare direttamente a `MAXPROTECTION`;
- devi fare prima `MAXAVAILABILITY`;
- con un solo standby, la perdita di quello standby puo fermare il primario.

```
-- Step 1: assicurati che transport sia SYNC (non FASTSYNC)
DGMGRL> EDIT DATABASE 'RACDB_STBY' SET PROPERTY LogXptMode='SYNC';
DGMGRL> EDIT DATABASE 'RACDB'      SET PROPERTY LogXptMode='SYNC';

-- Step 2: passaggio intermedio obbligatorio
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;

-- Step 3: upgrade finale
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXPROTECTION;
DGMGRL> SHOW CONFIGURATION;
```

### 4.4.7 Rollback sicuro (downgrade)

Se vuoi tornare indietro:
1. prima abbassa la protection mode;
2. poi cambia il transport mode.

Esempio ritorno a `MaxPerformance`:
```
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
DGMGRL> EDIT DATABASE 'RACDB_STBY' SET PROPERTY LogXptMode='ASYNC';
DGMGRL> EDIT DATABASE 'RACDB'      SET PROPERTY LogXptMode='ASYNC';
DGMGRL> SHOW CONFIGURATION;
```

### 4.4.8 Verifica post-change (obbligatoria)

```sql
SELECT protection_mode, protection_level, database_role
FROM   v$database;
```

```bash
dgmgrl sys/<password>@RACDB
```

```
DGMGRL> SHOW CONFIGURATION;
DGMGRL> SHOW DATABASE RACDB_STBY;
```

Output atteso:
- `Protection Mode` coerente con quello impostato;
- `Configuration Status: SUCCESS`;
- lag trasporto/apply vicino a zero nel lab.

### 4.4.9 Best practice Oracle (riassunto operativo)

1. Usa sempre Broker (`DGMGRL` o EM) per gestione mode e role transition.
2. Configura SRL su tutti i standby e anche sul primario.
3. In `MaxProtection`, Oracle raccomanda almeno 2 standby sincronizzati.
4. Usa real-time apply per rilevare prima eventuali corruzioni e ridurre lag.
5. In RAC, mantieni stesso `LOG_ARCHIVE_DEST_n` su tutte le istanze e usa net service con indirizzi multipli dello standby.
6. Misura latenza/rete prima di imporre `SYNC`; se RTT e alta valuta `FASTSYNC` o torna `ASYNC`.
7. Con `SYNC`, usa timeout/retry (`NET_TIMEOUT`, `REOPEN`) per rientro automatico dopo fault brevi.
8. Monitora continuamente protection level/lag e chiudi subito anomalie di trasporto.

### 4.4.10 Riferimenti Oracle ufficiali (consultati)

- Data Guard Concepts and Administration 19c (Protection Modes):
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-protection-modes.html
- Data Guard Broker 19c PDF (Managing Data Protection Modes):
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/data-guard-broker.pdf
- Data Guard Broker command reference (`EDIT CONFIGURATION ... PROTECTION MODE`):
  https://docs.oracle.com/en/database/oracle/oracle-database/21/dgbkr/oracle-data-guard-broker-commands.html
- Data Guard Concepts and Administration 19c (Redo Transport Services):
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-transport-services.html
- MAA Best Practices for Oracle Database 19c (Data Guard):
  https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/overview-oracle-maximum-availability-architecture-best-practices.html

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

-- Sequenza sicura: cancel apply -> open read only -> riabilita apply realtime
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
ALTER DATABASE OPEN READ ONLY;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;

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
EDIT DATABASE RACDB_STBY SET PROPERTY LogXptMode='SYNC';  -- o 'ASYNC' / 'FASTSYNC'
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
