# FASE 7: Oracle GoldenGate - Microservices Architecture (MA)

> Questa fase configura Oracle GoldenGate **19c Microservices Architecture (MA)** per replicare dati in tempo reale dal RAC Primary verso un database Oracle target. Classic Architecture (`ggsci`) non e' il percorso principale del lab, ma resta fondamentale da conoscere per ambienti legacy e troubleshooting.

> Prima di eseguire questa fase leggi il percorso GoldenGate completo:
> - [Prerequisiti DB e Architettura](./GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md)
> - [GoldenGate 19c Completa](./GUIDA_GOLDENGATE_19C_COMPLETA.md)
> - [Collegamento Source e Target](./GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md)
> - [Microservices Architecture 19c](./GUIDA_GOLDENGATE_MICROSERVICES_ARCHITECTURE_19C.md)
> - [Classic Architecture 19c](./GUIDA_GOLDENGATE_CLASSIC_ARCHITECTURE_19C.md)
> - [Cheat Sheet GoldenGate 19c](./CHEAT_SHEET_GOLDENGATE_19C.md)

---
## 7.0 Teoria Profonda: L'Architettura a Microservizi

Prima di configurare, è essenziale comprendere come i componenti interagiscono nella MA rispetto alla Classic Architecture.

### 7.0.1 Componenti Principali (I 4 Pilastri di OGG MA)

In GoldenGate MA, i processi classici (Manager, Extract, Pump, Replicat) sono stati reingegnerizzati in servizi RESTful indipendenti:

1. **Service Manager (SM)**: È il "watchdog" dell'architettura. Sostituisce parzialmente il vecchio Manager. Gestisce e monitora gli altri servizi sulla stessa host. È il punto di ingresso per configurare i deployment.
2. **Administration Server (AdminServer)**: Sostituisce l'interfaccia a riga di comando `ggsci` (anche se esiste un client `adminclient` per lo scripting). È qui che crei, avvii e fermi gli **Extract** e i **Replicat**.
3. **Distribution Server (DistServer)**: Sostituisce il vecchio processo **Data Pump**. Si occupa di leggere i Trail file generati dall'Extract e di spedirli via rete al target in modo asincrono.
4. **Receiver Server (RecvServer)**: Sostituisce la parte di ricezione del vecchio Manager. Riceve i Trail file inviati dal Distribution Server remoto e li salva su disco locale affinché il Replicat li possa leggere.

```
  SOURCE DATABASE (rac1)                           TARGET DATABASE (dbtarget)
  ═══════════════════════                          ══════════════════════════
  
  ┌────────────────────────┐                       ┌────────────────────────┐
  │ Service Manager (SM)   │                       │ Service Manager (SM)   │
  │ Porta: 9011            │                       │ Porta: 9011            │
  └────────────────────────┘                       └────────────────────────┘
  
  ┌────────────────────────┐                       ┌────────────────────────┐
  │ Administration Server  │                       │ Administration Server  │
  │ Porta: 9012            │                       │ Porta: 9012            │
  │ - Gestisce EXTRACT     │                       │ - Gestisce REPLICAT    │
  └──────────┬─────────────┘                       └──────────▲─────────────┘
             │                                                │
             ▼                                                │
  ┌────────────────────────┐                       ┌──────────┴─────────────┐
  │ Distribution Server    │══ Rete (HTTPS/WSS) ══►│ Receiver Server        │
  │ Porta: 9013            │                       │ Porta: 9014            │
  │ - Invia i Trail files  │                       │ - Riceve i Trail files │
  └────────────────────────┘                       └────────────────────────┘
```

> [!TIP]
> **Vantaggi chiave della MA:** Sicurezza integrata (TLS end-to-end), gestione tramite interfaccia web moderna (HTML5), metriche native (integrazione con Prometheus/Grafana) e design REST-first per l'automazione.

---

## 7.1 Prerequisiti Database Source (RACDB) e Target

> [!IMPORTANT]
> GoldenGate MA richiede che entrambi i database (Source e Target) siano preparati a livello di `LOGGING` e `SUPPLEMENTAL LOGGING`.

### 7.1.1 Abilitare Logging e GoldenGate (Su ENTRAMBI i DB)

```sql
-- Su rac1 (Source) e dbtarget (Target) come sysdba
sqlplus / as sysdba

-- 1. Abilita la replica GoldenGate (necessario per Integrated Extract/Replicat)
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH SID='*';

-- 2. Attiva FORCE LOGGING (Garantisce che nessuna transazione DML sia NOLOGGING)
ALTER DATABASE FORCE LOGGING;

-- 3. Attiva il supplemental logging minimo.
-- NON usare ALL COLUMNS a livello database come default: genera molto redo.
-- Per gli oggetti replicati userai ADD SCHEMATRANDATA / ADD TRANDATA da GoldenGate.
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- Verifica
SELECT force_logging, supplemental_log_data_min FROM v$database;
```

### 7.1.2 Creazione Utente GoldenGate (Su ENTRAMBI i DB)

```sql
-- Su rac1 (Source) e dbtarget (Target) come sysdba
sqlplus / as sysdba

CREATE USER c##ggadmin IDENTIFIED BY "<PASSWORD_SICURA>" CONTAINER=ALL;
-- Nota: In architetture CDB/PDB si usa un utente comune c## per l'Extract.

GRANT CREATE SESSION TO c##ggadmin CONTAINER=ALL;
BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'C##GGADMIN',
    privilege_type          => '*',
    grant_select_privileges => TRUE,
    do_grants               => TRUE,
    container               => 'ALL');
END;
/
```

---

## 7.2 Installazione di GoldenGate Microservices

### 7.2.1 Download e Struttura Directory

Scarica **Oracle GoldenGate 19c (Microservices Architecture)** dal portale eDelivery Oracle. La 26ai e' trattata nelle guide dedicate come evoluzione/upgrade, non come baseline del lab.

```bash
# Come utente oracle su rac1 e dbtarget

# 1. Crea la ORACLE_HOME dedicata per OGG MA
mkdir -p /u01/app/oracle/product/ogg_ma
mkdir -p /u01/app/oracle/gg_deploy

# 2. Decomprimi il software
cd /u01/app/oracle/product/ogg_ma
unzip /tmp/V*.zip # Esempio: ZIP GoldenGate 19c MA scaricato da eDelivery
```

### 7.2.2 Installazione Silenziosa del Software Base (Su rac1 e dbtarget)

OGG MA si installa in due fasi: prima il software base (OUI), poi la creazione del Deployment.

```bash
cd /u01/app/oracle/product/ogg_ma
./runInstaller -silent \
  -responseFile /u01/app/oracle/product/ogg_ma/response/oggcore.rsp \
  oracle.install.option=ORA19c \
  ORACLE_HOME=/u01/app/oracle/product/ogg_ma \
  UNIX_GROUP_NAME=oinstall \
  INVENTORY_LOCATION=/u01/app/oraInventory
```

---

## 7.3 Creazione del Deployment (Service Manager)

Il **Deployment** è un gruppo logico di servizi (Admin, Dist, Recv).

### 7.3.1 Deployment sul Source (rac1)

Usiamo il tool `oggca.sh` (Oracle GoldenGate Configuration Assistant) per creare il deployment.

```bash
# Su rac1 come oracle
export OGG_HOME=/u01/app/oracle/product/ogg_ma

$OGG_HOME/bin/oggca.sh -silent \
  -responseFile $OGG_HOME/response/oggca.rsp \
  deploymentName=SourceDeploy \
  deploymentHome=/u01/app/oracle/gg_deploy/SourceDeploy \
  serviceManagerPort=9011 \
  adminServerPort=9012 \
  distributionServerPort=9013 \
  receiverServerPort=9014 \
  administrator=oggadmin \
  password=<password_sicura> \
  securityEnabled=false # In lab disabilitiamo TLS per semplicità, MAI in produzione!
```

> [!CAUTION]
> **Sicurezza TLS:** Nel lab stiamo usando `securityEnabled=false` (HTTP). In produzione DEVE essere `true` (HTTPS) generando certificati o usando wallet.

### 7.3.2 Deployment sul Target (dbtarget)

```bash
# Su dbtarget come oracle
export OGG_HOME=/u01/app/oracle/product/ogg_ma

$OGG_HOME/bin/oggca.sh -silent \
  -responseFile $OGG_HOME/response/oggca.rsp \
  deploymentName=TargetDeploy \
  deploymentHome=/u01/app/oracle/gg_deploy/TargetDeploy \
  serviceManagerPort=9011 \
  adminServerPort=9012 \
  distributionServerPort=9013 \
  receiverServerPort=9014 \
  administrator=oggadmin \
  password=<password_sicura> \
  securityEnabled=false
```

Una volta terminato, puoi accedere all'interfaccia web:
- **Source SM**: `http://192.168.56.101:9011`
- **Target SM**: `http://192.168.56.120:9011`

---

## 7.4 Configurazione Tramite Web UI / REST

Da qui in poi, il lavoro si svolge interamente nel browser (Administration Server).

### 7.4.1 Aggiunta delle Credenziali (Credential Store)

Prima di configurare Extract/Replicat, OGG deve potersi connettere al DB.

1. Apri **Administration Server** del Source (`http://192.168.56.101:9012`).
2. Login come `oggadmin`.
3. Vai nel menu a sinistra -> **Configuration**.
4. Clicca su **+** nella sezione **Database**.
5. Aggiungi il database:
   - **Domain**: `OracleDB`
   - **Alias**: `RACDB`
   - **User ID**: `c##ggadmin`
   - **Password**: `<password>`
   - **Connect String**: `//rac1-scan.localdomain:1521/RACDB.localdomain` (Usa lo SCAN alias!)
6. Ripeti sul Target (`http://192.168.56.120:9012`) usando la stringa TNS del dbtarget.

### 7.4.2 Creazione dell'Integrated Extract (Source)

1. Nel Source Admin Server, torna alla **Overview**.
2. Clicca **+** sotto la voce **Extracts**.
3. Seleziona **Integrated Extract**.
4. **Process Name**: `EXT_RAC`
   - **Trail Name**: `er` (lungo 2 caratteri)
   - **Credential Domain**: `OracleDB`
   - **Credential Alias**: `RACDB`
5. Vai alla tab **Parameter File**. OGG genererà un template. Modificalo:
   ```text
   EXTRACT EXT_RAC
   USERIDALIAS RACDB DOMAIN OracleDB
   EXTTRAIL er
   LOGALLSUPCOLS
   UPDATERECORDFORMAT COMPACT
   -- Tabelle da estrarre
   TABLE HR.*;
   TABLE APP.*;
   ```
6. Clicca **Create and Run**.
7. L'Extract ora è verde (Running) e sta scrivendo il Trail File locale (`er000000001`).

### 7.4.3 Creazione del Distribution Path (Distribution Server)

Il Distribution Path è la freccia che collega il Source al Target. Sostituisce il vecchio `Data Pump`.

1. Apri il **Distribution Server** sul Source (`http://192.168.56.101:9013`).
2. Clicca **+** sotto **Paths**.
3. **Path Name**: `RAC_TO_TGT`
4. **Source**:
   - **Extract Name**: `EXT_RAC`
   - **Trail Name**: `er`
5. **Target**:
   - **Protocol**: `wss` (o `ws` se HTTP)
   - **Host**: `192.168.56.120` (IP del dbtarget)
   - **Port**: `9014` (Porta del Receiver Server target)
   - **Trail Name**: `rt`
   - **Domain**: `OracleDB`
   - **Alias**: `dbtarget`
6. Clicca **Create and Run**.
7. Il Path diventerà verde. I trail `er` ora vengono spediti e salvati come `rt` sul target.

---

## 7.5 Initial Load via DBMS_DATAPUMP (Zero Downtime)

> [!IMPORTANT]
> Prima di avviare il Replicat, i dati sul target devono essere instanziati partendo da un SCN specifico (Point-In-Time). Invece del vecchio expdp/impdp manuale, useremo Data Pump via Network Link per un caricamento diretto (Zero Downtime).

```sql
-- Su dbtarget come sysdba
sqlplus / as sysdba

-- 1. Crea un database link verso il Source (rac1)
CREATE DATABASE LINK source_db_link 
CONNECT TO c##ggadmin IDENTIFIED BY <password> 
USING '192.168.56.101:1521/RACDB.localdomain';

-- 2. Trova l'SCN corrente del Source per instanziare i dati a questo esatto istante
SELECT current_scn FROM v$database@source_db_link;
-- Supponiamo restituisca: 3847291
```

Esegui l'import via Network Link (senza creare file fisici):

```bash
# Su dbtarget
impdp c##ggadmin/<password> \
  NETWORK_LINK=source_db_link \
  SCHEMAS=HR,APP \
  FLASHBACK_SCN=3847291 \
  TABLE_EXISTS_ACTION=REPLACE \
  PARALLEL=4
```

> I dati target ora sono un'esatta copia al SCN `3847291`.

---

## 7.6 Creazione del Replicat (Target)

Ora che i dati base ci sono, diciamo a GoldenGate di applicare le transazioni partendo dall'SCN catturato durante l'Initial Load.

1. Apri l'**Administration Server** del Target (`http://192.168.56.120:9012`).
2. Clicca **+** sotto **Replicats**.
3. Seleziona **Integrated Replicat**.
4. **Process Name**: `REP_TGT`
   - **Trail Name**: `rt`
   - **Credential Domain**: `OracleDB`
   - **Credential Alias**: `dbtarget`
5. In **Checkpoints**, seleziona "Checkpoint Table" (se creata in precedenza tramite il tab Configuration).
6. Tab **Parameter File**:
   ```text
   REPLICAT REP_TGT
   USERIDALIAS dbtarget DOMAIN OracleDB
   -- Associazione mapping: MAP Source_Schema.*, TARGET Target_Schema.*;
   MAP HR.*, TARGET HR.*;
   MAP APP.*, TARGET APP.*;
   ```
7. **NON** cliccare "Create and Run" (premi solo **Create**).

Per garantire consistenza, dobbiamo avviare il replicat indicando all'SCN di partenza.
Apri `adminclient` (l'equivalente moderno di ggsci per MA):

```bash
# Su dbtarget
$OGG_HOME/bin/adminclient
```

```
OGG (https://192.168.56.120:9012 TargetDeploy) 1> CONNECT http://192.168.56.120:9012 as oggadmin PASSWORD <password>
OGG (https://192.168.56.120:9012 TargetDeploy) 2> START REPLICAT REP_TGT, AFTERCSN 3847291
```
> L'opzione `AFTERCSN` (Commit Sequence Number = SCN in Oracle) assicura che il Replicat applichi solo le transazioni committate *dopo* il momento in cui hai effettuato l'export via Data Pump.

---

## 7.7 Verifica e Monitoraggio (Web Dashboard)

GoldenGate MA rende obsoleto il comando `info all`. Tutto è visualizzabile tramite dashboard e API REST.

1. Torna sulla **Overview** del Target Administration Server.
2. Controlla che `REP_TGT` sia verde. Clicca sul processo per vedere i dettagli.
3. Nella sezione **Statistics**, potrai vedere il numero di `INSERT`, `UPDATE`, e `DELETE` applicate in tempo reale.
4. Esegui una DML sul Source (`rac1`):
   ```sql
   INSERT INTO hr.employees (employee_id, last_name, email, hire_date, job_id) 
   VALUES (999, 'GoldenGate Test', 'gg@test.com', SYSDATE, 'IT_PROG');
   COMMIT;
   ```
5. Verifica sul Target (`dbtarget`):
   ```sql
   SELECT * FROM hr.employees WHERE employee_id = 999;
   ```

Se la riga compare, la tua **Microservices Architecture** è perfettamente configurata e operativa in conformità alle Oracle Best Practices moderne.

---

**← [FASE 6: Enterprise Manager](../../02_core_dba/06_monitoring_systems/GUIDA_FASE6_ENTERPRISE_MANAGER.md)** | 📍 [Indice Percorso Lab](../../04_governance_learning/03_esami_e_carriera/README.md) | **→ [FASE 8: Test e Verifica End-to-End](../../03_infra_lab/02_oracle_installation_asm/GUIDA_FASE8_TEST_VERIFICA.md)**
