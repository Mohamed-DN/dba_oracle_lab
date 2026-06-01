# FASE 4: Configurazione Data Guard Broker (DGMGRL)

> [!NOTE]
> **DOCUMENTI CORRELATI - ALTA AFFIDABILITÀ, RAC E DATA GUARD (SCEGLI QUELLO PIÙ ADATTO):**
> - **Procedure di Produzione (Non-CDB)**:
>   - **Single Node Data Guard**: [GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md](./GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md) (architettura a singolo nodo primario e standby).
>   - **RAC Data Guard**: [GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md](./GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md) (architettura multi-nodo primario e standby).
> - **Guide di Laboratorio (RAC 19c Multi-Tenant/CDB)**:
>   - **Preparazione e Creazione Standby (Fase 3)**: [GUIDA_FASE3_RAC_STANDBY.md](./GUIDA_FASE3_RAC_STANDBY.md) (RMAN duplicate active database).
>   - **Configurazione Broker DGMGRL (Fase 4 - questa guida)**: [GUIDA_FASE4_DATAGUARD_DGMGRL.md](./GUIDA_FASE4_DATAGUARD_DGMGRL.md) (creazione e ottimizzazione broker).
>   - **Manuale Switchover Completo**: [GUIDA_SWITCHOVER_COMPLETO.md](./GUIDA_SWITCHOVER_COMPLETO.md) (passaggi sicuri di switchover).
>   - **Manuale Failover & Reinstate**: [GUIDA_FAILOVER_E_REINSTATE.md](./GUIDA_FAILOVER_E_REINSTATE.md) (gestione dei disastri e ripristino).
> - **Cheat Sheet Operativi (Pronto Intervento)**:
>   - **DGMGRL (Broker)**: [CS_DGMGRL.md](../../01_operations/01_cheat_sheets/CS_DGMGRL.md) (lag, switchover rapido, comandi broker).
>   - **SRVCTL & CRSCTL**: [CS_SRVCTL_CRSCTL.md](../../01_operations/01_cheat_sheets/CS_SRVCTL_CRSCTL.md) (gestione risorse cluster RAC e Grid).
>   - **ASMCMD**: [CS_ASMCMD.md](../../01_operations/01_cheat_sheets/CS_ASMCMD.md) (gestione storage ASM).
>   - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](../../01_operations/01_cheat_sheets/CS_MASTER_DBA.md) (tutti i comandi consolidati).

> Data Guard Broker è il "pannello di controllo" centralizzato per gestire la configurazione Data Guard. Senza Broker potresti gestire tutto manualmente (con ALTER SYSTEM SET ...), ma Broker semplifica enormemente switchover, failover e monitoraggio.

## Obiettivo

Configurare e validare Data Guard Broker come prerequisito della successiva Fase 4B dedicata a Observer e FSFO.

## Procedura Operativa

### Switchover vs Failover — La Differenza Cruciale

```
  SWITCHOVER (Pianificato, 0 data loss)         FAILOVER (Emergenza!)
  --------------------------------------         -----------------------

  PRIMA:                                        PRIMA:
  +--------+    redo    +--------+              +--------+    redo    +--------+
  |PRIMARY |-----------&gt;|STANDBY |              |PRIMARY |-----------&gt;|STANDBY |
  | RACDB  |            |RACDB_  |              | RACDB  |     ✕      |RACDB_  |
  |  OPEN  |            |  STBY  |              |  💀    |   MORTO!   |  STBY  |
  |        |            | MOUNT  |              |  DOWN  |            | MOUNT  |
  +--------+            +--------+              +--------+            +--------+

  DOPO:                                         DOPO:
  +--------+    redo    +--------+              +--------+             +--------+
  |STANDBY |<-----------|PRIMARY |              | EX-PRI |             |PRIMARY |
  | RACDB  |            |RACDB_  |              |Richiede|             |RACDB_  |
  | MOUNT  |            |  STBY  |              |REINSTATE             |  STBY  |
  |(ex-pri)|            |  OPEN  |              |o rifare|             |  OPEN  |
  +--------+            +--------+              |Fase 3  |             +--------+
                                                +--------+
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

- primario `READ WRITE` con ruolo `PRIMARY`
- standby `PHYSICAL STANDBY` con `MRP0` (se ti da no rows selected) non panicare il database e' in mounted close
- standby registrato nel cluster e montato su `racstby1` / `racstby2`
- SPFILE standby in ASM, non in `dbs/spfileRACDB1.ora`
- connettivita TNS ok sia alias SCAN (`RACDB`,`RACDB_STBY`) sia alias redo transport (`RACDB_DG`,`RACDB_STBY_DG`)

Nota RAC:

- in physical standby RAC e normale vedere `MRP0` su una sola istanza;
- non usare l'assenza di `MRP0` su `racstby2` come criterio di errore.

Se questi check falliscono, rientra in [GUIDA_FASE3_RAC_STANDBY.md](./GUIDA_FASE3_RAC_STANDBY.md) prima di continuare.

Nota per la Fase 5:

- quando passerai a GoldenGate, il percorso base del repo usera il `primary` come sorgente di capture;
- Data Guard rimane la piattaforma di DR e role transition;
- eventuali varianti con offload dal redo o dallo standby sono trattate come avanzate, non come flusso base.

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

> **Perché?** Questo parametro avvia il processo DMON (Data Guard Monitor) su ogni istanza. DMON è il "cervello" del Broker: gestisce la comunicazione, il monitoraggio e le operazioni automatiche.

### Verifica che DMON sia attivo

```bash
ps -ef | grep dmon
# Devi vedere un processo dmon_RACDB (o simile)
```

### 4.1a Best practice RAC: file Broker condivisi in ASM

In RAC, `DG_BROKER_CONFIG_FILE1` e `DG_BROKER_CONFIG_FILE2` non devono stare nel filesystem locale del singolo nodo. Devono stare su storage condiviso.

Verifica prima i parametri:

```sql
sqlplus / as sysdba
SHOW PARAMETER dg_broker_config_file;
```

Se vedi path locali sotto `$ORACLE_HOME/dbs`, normalizzali prima di proseguire.

Sul primary (`rac1`):

```sql
sqlplus / as sysdba

ALTER SYSTEM SET dg_broker_start=FALSE SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_config_file1='+DATA/RACDB/dr1RACDB.dat' SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_config_file2='+RECO/RACDB/dr2RACDB.dat' SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';
```

Sullo standby (`racstby1`):

```sql
sqlplus / as sysdba

ALTER SYSTEM SET dg_broker_start=FALSE SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_config_file1='+DATA/RACDB_STBY/dr1RACDB_STBY.dat' SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_config_file2='+RECO/RACDB_STBY/dr2RACDB_STBY.dat' SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';
```

Questa normalizzazione e coerente con la Fase 3:

- SPFILE condiviso in ASM;
- database standby registrato in OCR;
- configurazione RAC piena su entrambi i nodi.

---

## 4.2 Presa in Carico Controllata da Parte del Broker

La Fase 3 ha configurato temporaneamente il trasporto redo manuale per
dimostrare che standby e apply funzionano prima di introdurre il Broker. Ora
trasferisci la gestione al Broker senza cancellare parametri alla cieca.

### 4.2.1 Naming obbligatorio della configurazione

Usa sempre:

```text
DR_<DB_NAME><ENV_OPZIONALE>_CONF
```

Il nome deriva dal `DB_NAME` condiviso, non dal `DB_UNIQUE_NAME` del sito
primary. In questo lab il nome e' `DR_RACDB_CONF`. Resta stabile dopo
switchover e deve rispettare il limite Oracle di 30 byte.

### 4.2.2 Salva evidenze e rollback SQL

Prima del passaggio di ownership esegui su primary e standby:

```sql
SET LINES 240 PAGES 200
COL name FORMAT A28
COL value FORMAT A180

SELECT name, value
FROM v$parameter
WHERE name LIKE 'log_archive_dest_%'
   OR name IN ('log_archive_config', 'fal_server', 'fal_client')
ORDER BY name;
```

Conserva l'output nell'evidence pack. Registra separatamente i comandi SQL
necessari per ripristinare i valori manuali se il commissioning Broker deve
essere annullato.

### 4.2.3 Rimuovi solo le destinazioni remote incompatibili

Secondo la reference Oracle 19c:

- prima di `CREATE CONFIGURATION`, sul primary devono essere rimosse le
  destinazioni remote redo transport prive di `NOREGISTER`;
- prima di `ADD DATABASE`, sullo standby devono essere rimosse le
  destinazioni remote redo transport;
- la destinazione locale FRA non deve essere rimossa;
- non devi resettare `LOCAL_LISTENER`, `REMOTE_LISTENER`,
  `LISTENER_NETWORKS` o altri parametri di rete.

Individua il parametro remoto con la query precedente. Nel lab e'
normalmente `LOG_ARCHIVE_DEST_2`, ma verifica sempre prima di eseguire:

```sql
-- Esegui sul membro corretto solo dopo aver salvato il valore precedente.
-- Sostituisci <DEST_N> con il parametro remoto verificato.
ALTER SYSTEM RESET <DEST_N> SCOPE=BOTH SID='*';
```

> [!WARNING]
> Non copiare un reset indiscriminato su entrambi i siti. La rimozione e'
> mirata al parametro remoto incompatibile e avviene nel momento corretto:
> primary prima di `CREATE CONFIGURATION`, standby prima di `ADD DATABASE`.

### 4.2.4 Crea e abilita la configurazione

Connettiti localmente dal nodo primary come utente `oracle`:

```bash
dgmgrl /
```

Se esiste una configurazione di test precedente, raccogli prima
`SHOW CONFIGURATION VERBOSE`, poi rimuovila solo se il change lo prevede:

```text
DISABLE CONFIGURATION;
REMOVE CONFIGURATION;
```

Crea la configurazione usando gli alias `_DG`, gia' testati da tutti i nodi:

```text
CREATE CONFIGURATION 'DR_RACDB_CONF' AS
  PRIMARY DATABASE IS 'RACDB'
  CONNECT IDENTIFIER IS 'RACDB_DG';

ADD DATABASE 'RACDB_STBY' AS
  CONNECT IDENTIFIER IS 'RACDB_STBY_DG'
  MAINTAINED AS PHYSICAL;

ENABLE CONFIGURATION;
```

`PRIMARY DATABASE IS` e `ADD DATABASE` usano i rispettivi
`DB_UNIQUE_NAME`. Il nome `DR_RACDB_CONF` identifica invece l'intera
configurazione.

### 4.2.5 Verifica proprietà di connessione

I tre concetti non sono intercambiabili:

| Oggetto | Uso |
| --- | --- |
| alias `_DG` | redo transport, FAL e `DGConnectIdentifier` raggiungibile da tutti i membri |
| servizio `_AUX` | registrazione statica temporanea per RMAN auxiliary `NOMOUNT` |
| servizio `_DGMGRL` | restart Broker quando richiesto; validare separatamente |

Verifica e, se necessario, normalizza `DGConnectIdentifier`:

```text
SHOW DATABASE VERBOSE 'RACDB';
SHOW DATABASE VERBOSE 'RACDB_STBY';

EDIT DATABASE 'RACDB' SET PROPERTY DGConnectIdentifier='RACDB_DG';
EDIT DATABASE 'RACDB_STBY' SET PROPERTY DGConnectIdentifier='RACDB_STBY_DG';

VALIDATE DATABASE 'RACDB';
VALIDATE DATABASE 'RACDB_STBY';
VALIDATE DATABASE 'RACDB' SPFILE;
VALIDATE DATABASE 'RACDB_STBY' SPFILE;
VALIDATE NETWORK CONFIGURATION FOR ALL;
VALIDATE STATIC CONNECT IDENTIFIER FOR ALL;
```

Da questo punto modifica trasporto redo e protection mode tramite DGMGRL.
Non tornare a editare direttamente `LOG_ARCHIVE_DEST_n` durante la gestione
ordinaria del Broker.

---

## 4.3 Verifica Stato della Configurazione

```
DGMGRL> SHOW CONFIGURATION;
```

Output atteso:
```
Configuration - DR_RACDB_CONF

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
> - In RAC standby e normale che il Broker mostri una sola `apply instance` attiva.

> **MILESTONE - Broker configurato**
> Data Guard Broker e' operativo con `STATUS=SUCCESS`. Salva output DGMGRL,
> parametri e log nel pacchetto di evidenze. Non usare snapshot VM come
> rollback quando esistono dischi ASM condivisi: usa un backup consistente a
> VM spente oppure ricostruzione documentata.

---

## 4.4 Configurazione Protection Mode

Questa sezione ti dice:
1. come scegliere la modalita corretta;
2. quali prerequisiti Oracle sono obbligatori;
3. come impostare davvero `MaxPerformance`, `MaxAvailability`, `MaxProtection`;
4. come verificare e tornare indietro senza rompere la configurazione.

### 4.4.1 Capire le 3 modalita (in pratica)

```
+-------------------+-----------------------------------------------------------+--------------+
| Mode              | RPO / comportamento commit                               | Impatto       |
+-------------------+-----------------------------------------------------------+--------------+
| MaxPerformance    | Commit locale immediato, redo spedito ASYNC             | Minimo        |
| (default)         | (possibile perdita secondi in disastro)                 |              |
+-------------------+-----------------------------------------------------------+--------------+
| MaxAvailability   | Obiettivo zero data loss quando standby sincronizzato;   | Medio         |
|                   | se standby non risponde, primario resta disponibile      |              |
+-------------------+-----------------------------------------------------------+--------------+
| MaxProtection     | Zero data loss prioritario assoluto; se non puo          | Alto          |
|                   | proteggere i commit, il primario si ferma                |              |
+-------------------+-----------------------------------------------------------+--------------+
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
dgmgrl /@RACDB
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
dgmgrl /@RACDB
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
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/oracle-data-guard-broker-commands.html
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
Configuration - DR_RACDB_CONF
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

> [!CAUTION]
> Prima di ogni failover conferma il fencing del vecchio primary: istanze
> arrestate o host isolati da rete e storage applicativo. Senza fencing puoi
> creare due primary concorrenti. Nel lab conserva prima una baseline RMAN e
> segui il [runbook Failover e Reinstate](./GUIDA_FAILOVER_E_REINSTATE.md).

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

Active Data Guard (ADG) permette di aprire lo standby in **READ ONLY** mentre
continua ad applicare i redo. È opzionale: Data Guard base e backup RMAN dello
standby funzionano anche in `MOUNT`. In produzione usa `READ ONLY WITH APPLY`
solo dopo approvazione del gate licenza Active Data Guard. Il percorso
GoldenGate del lab cattura dal primary e non richiede ADG.

```sql
-- Sullo standby come sysdba
sqlplus / as sysdba

-- Sequenza sicura: cancel apply -> open read only -> riabilita apply realtime
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
ALTER DATABASE OPEN READ ONLY;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

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

Dopo ogni restart verifica `READ ONLY WITH APPLY`; la sola start option non
sostituisce il controllo MRP. Per servizi role-based e variante CDB/PDB usa la
[guida SHAMS Active Data Guard](./SHAMS_PROJECT/GUIDA_10_ACTIVE_DATAGUARD_SERVIZI_ROLE_BASED_PEYTECH_19C.md).

---

## 4.8 Passaggio alla Fase 4B: Observer Server e FSFO

Il Broker configurato in questa fase abilita il passo successivo. Per rendere operativo il
failover automatico usa la [Fase 4B: Observer Server e FSFO](./GUIDA_FASE4B_FSFO_OBSERVER.md).

La procedura dedicata include VM Observer separata, Oracle Client Administrator 19c,
wallet SEPS, attivazione iniziale `OBSERVE ONLY`, validazione, rollback e persistenza
`systemd`. Non avviare l'Observer su primary o standby e non inserire password nella
command line.

---

## 4.9 Comandi DGMGRL Utili (Cheat Sheet)

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

## Validazione Finale

## ✅ Checklist Fine Fase 4

```
DGMGRL> SHOW CONFIGURATION;
-- Configuration Status: SUCCESS

DGMGRL> SHOW DATABASE RACDB_STBY;
-- Transport Lag: 0 seconds
-- Apply Lag: 0 seconds o pochi secondi
-- Database Status: SUCCESS

DGMGRL> VALIDATE DATABASE RACDB;
DGMGRL> VALIDATE DATABASE RACDB_STBY;
DGMGRL> VALIDATE DATABASE RACDB SPFILE;
DGMGRL> VALIDATE DATABASE RACDB_STBY SPFILE;
DGMGRL> VALIDATE NETWORK CONFIGURATION FOR ALL;
DGMGRL> VALIDATE STATIC CONNECT IDENTIFIER FOR ALL;
```

Conserva output, proprietà Broker e rollback SQL nel pacchetto di evidenze.
La consegna alla Fase 4B avviene solo dopo switchover e switchback riusciti.

## Troubleshooting Rapido

Se il Broker non restituisce `SUCCESS`, risolvi gli errori prima di procedere alla
[Fase 4B](./GUIDA_FASE4B_FSFO_OBSERVER.md). Usa `SHOW CONFIGURATION VERBOSE`,
`VALIDATE DATABASE RACDB_STBY` e `SHOW DATABASE RACDB_STBY StatusReport`.

---

**← [FASE 3: RAC Standby](./GUIDA_FASE3_RAC_STANDBY.md)** | 📍 [Indice Percorso Lab](../../04_governance_learning/03_esami_e_carriera/README.md) | **→ [FASE 4B: Observer FSFO](./GUIDA_FASE4B_FSFO_OBSERVER.md)**
