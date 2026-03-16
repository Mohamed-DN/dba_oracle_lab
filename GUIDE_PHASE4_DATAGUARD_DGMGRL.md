# STEP 4: Data Guard Broker Configuration (DGMGRL)

> Data Guard Broker is the centralized "control panel" for managing your Data Guard configuration. Without Broker you could manage everything manually (with ALTER SYSTEM SET...), but Broker greatly simplifies switchover, failover and monitoring.

### Switchover vs Failover — La Differenza Cruciale

```
  SWITCHOVER (Pianificato, 0 data loss)         FAILOVER (Emergenza!)
  ══════════════════════════════════════         ═══════════════════════

  BEFORE: BEFORE:
  ┌────────┐    redo    ┌────────┐              ┌────────┐    redo    ┌────────┐
  │PRIMARY │───────────►│STANDBY │ │PRIMARY │───────────►│STANDBY │
  │ RACDB  │            │RACDB_  │              │ RACDB  │     ✕      │RACDB_  │
  │  OPEN  │            │  STBY  │              │  💀    │   MORTO!   │  STBY  │
  │        │            │ MOUNT  │              │  DOWN  │            │ MOUNT  │
  └────────┘            └────────┘              └────────┘            └────────┘

  AFTER: AFTER:
  ┌────────┐    redo    ┌────────┐              ┌────────┐             ┌────────┐
  │STANDBY │◄───────────│PRIMARY │ │ ???   │ │PRIMARY │
  │ RACDB  │            │RACDB_  │              │Richiede│             │RACDB_  │
  │ MOUNT  │            │  STBY  │              │REINSTATE             │  STBY  │
  │(ex-pri)│            │  OPEN  │              │o rifare│             │  OPEN  │
  └────────┘ └────────┘ │Phase 3 │ └────────┘
                                                └────────┘
  ✅ Ruoli invertiti      ✅ Zero data loss      ⚠️ Possibile data loss
  ✅ Reversible ✅ ~30 seconds ⚠️ Old primary from
                                                    ricostruire
```

---

## 4.0 Entry from Phase 3 (rapid alignment)

Before tapping DGMGRL, verify that Phase 3 is really closed.

```sql
-- Sul primario
sqlplus / as sysdba
SELECT name, open_mode, database_role, db_unique_name FROM v$database;

-- Sullo standby
sqlplus / as sysdba
SELECT name, open_mode, database_role, db_unique_name FROM v$database;
SELECT process, status FROM v$managed_standby WHERE process='MRP0';
SHOW PARAMETER spfile;
```

```bash
# Sullo standby
srvctl status database -d RACDB_STBY -v
```

```bash
# Verifica TNS dal primario
tnsping RACDB
tnsping RACDB_STBY
tnsping RACDB_DG
tnsping RACDB_STBY_DG
```

Criteri minimi:

- primary `READ WRITE` con ruolo `PRIMARY`
- standby `PHYSICAL STANDBY` con `MRP0` attivo
- standby registered in the cluster and mounted on `racstby1` / `racstby2`
- SPFILE standby in ASM, not in `dbs/spfileRACDB1.ora`
- connettivita TNS ok sia alias SCAN (`RACDB`,`RACDB_STBY`) sia alias redo transport (`RACDB_DG`,`RACDB_STBY_DG`)

Nota RAC:

- in physical standby RAC is normal to see `MRP0` on a single instance;
- non usare l'assenza di `MRP0` su `racstby2` as an error criterion.

Se questi check falliscono, rientra in [GUIDE_PHASE3_RAC_STANDBY.md](./GUIDE_PHASE3_RAC_STANDBY.md) before continuing.

Note for Phase 5:

- quando passerai a GoldenGate, il percorso base del repo usera il `primary` as a capture source;
- Data Guard rimane la piattaforma di DR e role transition;
- any variants with offload from redo or standby are treated as advanced, not as basic flow.

---

## 4.1 Abilitare Data Guard Broker

In RAC basta eseguire il settaggio una volta per database:

- da `rac1` per `RACDB`
- da `racstby1` per `RACDB_STBY`

```sql
sqlplus / as sysdba

ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';

EXIT;
```

> **Why?** This parameter starts the Data Guard Monitor (DMON) process on each instance. DMON is the "brain" of the Broker: it manages communication, monitoring and automatic operations.

### Verify that DMON is active

```bash
ps -ef | grep dmon
# Devi vedere un processo dmon_RACDB (o simile)
```

### 4.1a Best practice RAC: file Broker condivisi in ASM

In RAC, `DG_BROKER_CONFIG_FILE1` e `DG_BROKER_CONFIG_FILE2` they do not have to be in the individual node's local filesystem. They must be on shared storage.

Check the parameters first:

```sql
sqlplus / as sysdba
SHOW PARAMETER dg_broker_config_file;
```

Se vedi path locali sotto `$ORACLE_HOME/dbs`, normalize them before continuing.

Sul primary (`rac1`):

```sql
sqlplus / as sysdba

ALTER SYSTEM SET dg_broker_start=FALSE SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_config_file1='+DATA/RACDB/dr1RACDB.dat' SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_config_file2='+RECO/RACDB/dr2RACDB.dat' SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';
```

On standby (`racstby1`):

```sql
sqlplus / as sysdba

ALTER SYSTEM SET dg_broker_start=FALSE SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_config_file1='+DATA/RACDB_STBY/dr1RACDB_STBY.dat' SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_config_file2='+RECO/RACDB_STBY/dr2RACDB_STBY.dat' SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';
```

This normalization is consistent with Phase 3:

- SPFILE condiviso in ASM;
- standby database recorded in OCR;
- Full RAC configuration on both nodes.

---

## 4.2 Creating the Broker Configuration

If you have already created a Broker configuration in the past (previous tests), clean before recreating:

```bash
dgmgrl sys/<password>@RACDB
SHOW CONFIGURATION;
-- Se esiste una configurazione precedente:
DISABLE CONFIGURATION;
REMOVE CONFIGURATION;
```

Connettiti a `dgmgrl` from **primary node**:

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



> **Explanation:**
> - `CREATE CONFIGURATION`: Defines the name of the DG configuration.
> - `PRIMARY DATABASE IS RACDB`: Tells the Broker which one is the primary one.
> - `CONNECT IDENTIFIER IS RACDB`: Usa l'alias TNS `RACDB` per connettersi.
> - `ADD DATABASE ... MAINTAINED AS PHYSICAL`: Adds standby as Physical Standby (not Logical).
> - `ENABLE CONFIGURATION`: Attiva tutto. Da questo momento, Broker gestisce il redo shipping.

### 4.2a Best practice Broker: DGConnectIdentifier esplicito

In RAC, it is good practice to use aliases dedicated to redo transport also in the Broker.

```bash
dgmgrl sys/<password>@RACDB
```

```
DGMGRL> SHOW DATABASE VERBOSE RACDB;
DGMGRL> SHOW DATABASE VERBOSE RACDB_STBY;
```

Check the value of `DGConnectIdentifier`. Se non e coerente con gli alias `_DG`, impostalo esplicitamente:

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

## 4.3 Check Configuration Status

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

> Se vedi `SUCCESS`, the configuration is operational! If you see `WARNING` o `ERROR`, use the commands below to diagnose.

```
DGMGRL> SHOW DATABASE RACDB;
DGMGRL> SHOW DATABASE RACDB_STBY;
```

Output di `SHOW DATABASE RACDB_STBY`:
```
Database - RACDB_STBY

  Role: PHYSICAL STANDBY
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

> - **Transport Lag**: How much delay there is in sending the redos from primary to standby. Ideally 0.
> - **Apply Lag**: How much delay there is in applying redos on standby. Ideally 0 or a few seconds.
> - **Apply Rate**: The application speed.
> - In RAC standby it is normal for the Broker to show only one `apply instance` attiva.

> 📸 **SNAPSHOT — "SNAP-09: DGMGRL_Configurato" ⭐ MILESTONE**
> Data Guard Broker is operational with STATUS = SUCCESS. You have a real Disaster Recovery site.
> ```bash
> VBoxManage snapshot "rac1" take "SNAP-09: DGMGRL_Configurato"
> VBoxManage snapshot "rac2" take "SNAP-09: DGMGRL_Configurato"
> VBoxManage snapshot "racstby1" take "SNAP-09: DGMGRL_Configurato"
> VBoxManage snapshot "racstby2" take "SNAP-09: DGMGRL_Configurato"
> ```

---

## 4.4 Protection Mode configuration

This section tells you:
1. how to choose the correct mode;
2. quali prerequisiti Oracle sono obbligatori;
3. how to actually set it up `MaxPerformance`, `MaxAvailability`, `MaxProtection`;
4. how to check and go back without breaking the configuration.

### 4.4.1 Capire le 3 modalita (in pratica)

```
╔═══════════════════╦═══════════════════════════════════════════════════════════╦══════════════╗
║ Mode              ║ RPO / comportamento commit                               ║ Impatto       ║
╠═══════════════════╬═══════════════════════════════════════════════════════════╬══════════════╣
║ MaxPerformance    ║ Commit locale immediato, redo spedito ASYNC             ║ Minimo        ║
║ (default)         ║ (possibile perdita secondi in disastro)                 ║              ║
╠═══════════════════╬═══════════════════════════════════════════════════════════╬══════════════╣
║ MaxAvailability ║ Target zero data loss when synchronized standby;   ║ Medium ║
║ ║ if standby does not respond, primary remains available ║ ║
╠═══════════════════╬═══════════════════════════════════════════════════════════╬══════════════╣
║ MaxProtection ║ Absolute priority zero data loss; if he can't ║ High ║
║ ║ protect commits, primary stops ║ ║
╚═══════════════════╩═══════════════════════════════════════════════════════════╩══════════════╝
```

Regola veloce:
- se vuoi priorita performance: `MaxPerformance`
- if you want zero data loss on the first fault but without blocking the primary: `MaxAvailability`
- if you want zero absolute data loss and accept primary stop: `MaxProtection`

Nota RAC:
- in `MaxAvailability`, if a single RAC instance loses connectivity to synchronized standby, that instance may crash; if all instances lose connectivity, the database continues in behavior equivalent to `MaxPerformance`.

### 4.4.2 Prerequisiti tecnici obbligatori (best practice Oracle)

Before changing modes, check:
1. `FORCE LOGGING` active on the primary.
2. Standby Redo Log (SRL) present on standby and also on primary (for role change/FSFO).
3. Standby in real-time apply.
4. Broker in `SUCCESS` e senza gap redo.
5. Per `MaxAvailability`/`MaxProtection`: at least one standby with redo transport `SYNC` o `FASTSYNC` (broker).
6. `Fast-Start Failover` disabilitato quando cambi protection mode (vincolo broker).
7. In RAC, `LOG_ARCHIVE_DEST_n` consistent across all instances and net service with address list of all standby nodes.
8. Se usi `SYNC`, configura timeout/retry coerenti (`NET_TIMEOUT`, `REOPEN`) to avoid long stalls on network faults.

### 4.4.3 Operational pre-check (before mode change)

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

### 4.4.4 Procedure A - Hold/Set Maximum Performance (default lab)

Use it when you want minimal impact on the primary.

```
DGMGRL> EDIT DATABASE 'RACDB_STBY' SET PROPERTY LogXptMode='ASYNC';
DGMGRL> EDIT DATABASE 'RACDB'      SET PROPERTY LogXptMode='ASYNC';
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
DGMGRL> SHOW CONFIGURATION;
```

### 4.4.5 Procedure B - Switch to Maximum Availability (zero data loss on the first fault)

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
- `FASTSYNC` (equivale a `SYNC/NOAFFIRM`) reduces impact, but in multiple extreme scenarios can expose you to data loss.

### 4.4.6 Procedure C - Switch to Maximum Protection (only if aware of the impact)

Attenzione:
- da `MAXPERFORMANCE` you can't jump straight to `MAXPROTECTION`;
- you have to do it first `MAXAVAILABILITY`;
- with only one standby, the loss of that standby can stop the primary.

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
1. first lower the protection mode;
2. poi cambia il transport mode.

Example return to `MaxPerformance`:
```
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
DGMGRL> EDIT DATABASE 'RACDB_STBY' SET PROPERTY LogXptMode='ASYNC';
DGMGRL> EDIT DATABASE 'RACDB'      SET PROPERTY LogXptMode='ASYNC';
DGMGRL> SHOW CONFIGURATION;
```

### 4.4.8 Post-change verification (mandatory)

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

### 4.4.9 Oracle Best Practices (Operational Summary)

1. Usa sempre Broker (`DGMGRL` or EM) for mode and role transition management.
2. Configure SRL on all standbys and also on the primary.
3. In `MaxProtection`, Oracle recommends at least 2 synchronized standbys.
4. Use real-time apply to detect corruption earlier and reduce lag.
5. In RAC, keep same `LOG_ARCHIVE_DEST_n` on all instances and use net service with multiple standby addresses.
6. Measure latency/network before enforcing `SYNC`; se RTT e alta valuta `FASTSYNC` o torna `ASYNC`.
7. Con `SYNC`, usa timeout/retry (`NET_TIMEOUT`, `REOPEN`) for automatic recovery after short faults.
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

Switchover is a **scheduled** operation that reverses roles: the primary becomes the standby and the standby becomes the primary. It has zero data loss.

```
DGMGRL> VALIDATE DATABASE RACDB_STBY;
```

Output: Must show "Ready for Switchover: Yes"

```
DGMGRL> SWITCHOVER TO RACDB_STBY;
```

> **What happens behind the scenes?**
> 1. The primary (RACDB) flushes all pending redos to the standby.
> 2. Primary converts to standby (changes controlfile).
> 3. Standby (RACDB_STBY) converts to primary.
> 4. The old primary begins to receive feedback from the new primary.
>
> In a RAC, all instances are stopped and restarted automatically by the Broker.

Check after switchover:

```
DGMGRL> SHOW CONFIGURATION;
```

```
Configuration - dg_config
  Members:
  RACDB_STBY  - Primary database <-- Now he is the primary one!
    RACDB - Physical standby database

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

Failover is an **UNscheduled** operation used when the primary is unreachable. May result in data loss (if not in MaxProtection).

> **⚠️ CAUTION**: Do not perform a failover in a lab if you are not prepared to reinstantiate standby afterward. After a failover, the old primary cannot automatically become standby again (requires a "reinstate" or recreation).

```
-- Solo se il primario è davvero down!
DGMGRL> FAILOVER TO RACDB_STBY;
```

After failover, to restore the old primary as standby:

```
-- Se il vecchio primario è riavviabile
DGMGRL> REINSTATE DATABASE RACDB;
```

> Se `REINSTATE` fails, you need to recreate standby with RMAN Duplicate (Step 3).

---

## 4.7 Enable Active Data Guard (Read-Only on Standby)

Active Data Guard (ADG) allows you to open standby in **READ ONLY** while continuing to apply redos. Fundamental for GoldenGate in Phase 5.

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

> **Why ADG?** Without ADG, standby is in MOUNT (inaccessible to clients). With ADG, you can query the standby to offload the load from the primary. Furthermore, GoldenGate can fetch additional data directly from standby.

---

## 4.8 Useful DGMGRL Commands (Cheat Sheet)

```
-- General condition
SHOW CONFIGURATION;
SHOW CONFIGURATION VERBOSE;

-- Dettaglio database
SHOW DATABASE RACDB;
SHOW DATABASE RACDB_STBY;

-- Check switchover readiness
VALIDATE DATABASE RACDB_STBY;

-- Controllare i log
SHOW DATABASE RACDB_STBY LogShipping;
SHOW DATABASE RACDB_STBY StatusReport;

-- Disabilitare temporaneamente
DISABLE DATABASE RACDB_STBY;
ENABLE DATABASE RACDB_STBY;

-- Change the transport property
EDIT DATABASE RACDB_STBY SET PROPERTY LogXptMode='SYNC';  -- o 'ASYNC' / 'FASTSYNC'
```

---

## ✅ End of Phase 4 Checklist

```
DGMGRL> SHOW CONFIGURATION;
-- Configuration Status: SUCCESS

DGMGRL> SHOW DATABASE RACDB_STBY;
-- Transport Lag: 0 seconds
-- Apply Lag: 0 seconds o pochi secondi
-- Database Status: SUCCESS
```

---

**→ Next: [STEP 5: GoldenGate Configuration](./GUIDE_PHASE5_GOLDENGATE.md)**
