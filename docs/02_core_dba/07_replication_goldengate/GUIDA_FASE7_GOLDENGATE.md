# FASE 7: Oracle GoldenGate - Microservices Architecture (MA)

> [!NOTE]
> **DOCUMENTI GOLDENGATE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Guida di Riferimento 19c Core (Single Source of Truth)**: [GUIDA_GOLDENGATE_19C_COMPLETA.md](./GUIDA_GOLDENGATE_19C_COMPLETA.md) (manuale completo di architettura, parametri e best practices).
> - **Cheat Sheet Operativo (Veloce)**: [CS_GOLDENGATE.md](../../01_operations/01_cheat_sheets/CS_GOLDENGATE.md) (comandi rapidi, lag, stop/start).
> - **Cheat Sheet Verticale 19c**: [GUIDA_GOLDENGATE_19C_CHEAT_SHEET.md](./GUIDA_GOLDENGATE_19C_CHEAT_SHEET.md) (comandi analitici e grant).

> Questa fase configura Oracle GoldenGate **19c Microservices Architecture (MA)** per replicare dati in tempo reale dal RAC Primary verso un database Oracle target. Classic Architecture (`ggsci`) non e' il percorso principale del lab, ma resta fondamentale da conoscere per ambienti legacy e troubleshooting.

> Prima di eseguire questa fase leggi il percorso GoldenGate completo:
> - [Prerequisiti DB e Architettura](./GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md)
> - [Collegamento Source e Target](./GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md)
> - [Microservices Architecture 19c](./GUIDA_GOLDENGATE_MICROSERVICES_ARCHITECTURE_19C.md)
> - [Classic Architecture 19c](./GUIDA_GOLDENGATE_CLASSIC_ARCHITECTURE_19C.md)

---
## Obiettivo operativo

Configurare un percorso GoldenGate 19c MA cifrato dal CDB RAC `RACDB`, con
PDB applicativa `RACDBPDB`, verso il target Oracle del lab.

## Procedura operativa

Prepara logging e privilegi minimi, crea i deployment TLS, registra le
credenziali nel credential store e valida Extract, Distribution Path e Replicat.

## Validazione finale

Conferma che una transazione applicativa attraversi `EXT_RAC`, il Distribution
Path WSS e `REP_TGT`, senza password in script o argomenti shell.

## Troubleshooting rapido

Se la replica non avanza, separa capture, trail locale, Distribution Path,
Receiver Server e apply. Usa `adminclient` o la UI MA; `ggsci` resta solo per
ambienti Classic legacy.

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
  -----------------------                          --------------------------
  
  +------------------------+                       +------------------------+
  | Service Manager (SM)   |                       | Service Manager (SM)   |
  | Porta: 9011            |                       | Porta: 9011            |
  +------------------------+                       +------------------------+
  
  +------------------------+                       +------------------------+
  | Administration Server  |                       | Administration Server  |
  | Porta: 9012            |                       | Porta: 9012            |
  | - Gestisce EXTRACT     |                       | - Gestisce REPLICAT    |
  +----------+-------------+                       +----------^-------------+
             |                                                |
             v                                                |
  +------------------------+                       +----------+-------------+
  | Distribution Server    |-- Rete (HTTPS/WSS) -->| Receiver Server        |
  | Porta: 9013            |                       | Porta: 9014            |
  | - Invia i Trail files  |                       | - Riceve i Trail files |
  +------------------------+                       +------------------------+
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

### 7.1.2 Utenti GoldenGate e privilegi minimi

Sul source CDB usa un common user per capture. La password viene inserita in
modo interattivo in SQL*Plus o recuperata dal vault: il token seguente è solo
un promemoria e non va salvato in script.

```sql
-- Su rac1, CDB root di RACDB, come sysdba
sqlplus / as sysdba

CREATE USER c##ggadmin IDENTIFIED BY "<INSERIRE_DA_VAULT_NEL_PROMPT_SQLPLUS>" CONTAINER=ALL;

GRANT CREATE SESSION TO c##ggadmin CONTAINER=ALL;
ALTER USER c##ggadmin SET CONTAINER_DATA=ALL CONTAINER=CURRENT;

BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'C##GGADMIN',
    privilege_type          => 'CAPTURE',
    grant_select_privileges => TRUE,
    do_grants               => TRUE,
    container               => 'ALL');
END;
/
```

Sul target crea un account apply dedicato nel container che ospita gli oggetti
applicativi. Concedi solo i privilegi richiesti dal mapping e usa
`DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE` con `privilege_type => 'APPLY'`.
Se il target è CDB, connettiti al relativo servizio PDB. Non concedere
`ALTER SYSTEM`, `ALTER USER` o quote illimitate come default.

```sql
-- Esempio target Oracle: sostituisci GGAPPLY con l'account approvato
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.CUSTOMERS TO ggapply;
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.ORDERS TO ggapply;
```

Se usi schema intero e devi generare i grant:

```sql
SELECT 'GRANT SELECT, INSERT, UPDATE, DELETE ON ' || owner || '.' || table_name || ' TO GGAPPLY;'
FROM   dba_tables
WHERE  owner = 'APP'
ORDER  BY table_name;
```

Runbook completo: [GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).

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

Usa `oggca.sh` (Oracle GoldenGate Configuration Assistant) per generare e
revisionare un response file locale. Il file valorizzato contiene segreti:
mantienilo `0600`, fuori dal repository, e cancellalo appena terminata la
configurazione.

```bash
# Su rac1 come oracle
export OGG_HOME=/u01/app/oracle/product/ogg_ma
umask 077
install -d -m 700 /home/oracle/secure

# Genera e revisiona /home/oracle/secure/oggca_SourceDeploy.rsp con oggca.sh.
# Inserisci la password da vault nel file temporaneo, non nella command line.
$OGG_HOME/bin/oggca.sh -silent \
  -responseFile /home/oracle/secure/oggca_SourceDeploy.rsp

shred -u /home/oracle/secure/oggca_SourceDeploy.rsp
```

Nel response file imposta `SourceDeploy`, le porte `9011`-`9014`, l'utente
amministrativo e `securityEnabled=true`. Configura certificati e wallet secondo
la PKI del laboratorio. La variante non cifrata non è il default del percorso.

### 7.3.2 Deployment sul Target (dbtarget)

```bash
# Su dbtarget come oracle
export OGG_HOME=/u01/app/oracle/product/ogg_ma
umask 077
install -d -m 700 /home/oracle/secure

# Genera e revisiona /home/oracle/secure/oggca_TargetDeploy.rsp con oggca.sh.
$OGG_HOME/bin/oggca.sh -silent \
  -responseFile /home/oracle/secure/oggca_TargetDeploy.rsp

shred -u /home/oracle/secure/oggca_TargetDeploy.rsp
```

Una volta terminato, puoi accedere all'interfaccia web:
- **Source SM**: `https://rac1.localdomain:9011`
- **Target SM**: `https://dbtarget.localdomain:9011`

---

## 7.4 Configurazione Tramite Web UI / REST

Da qui in poi, il lavoro si svolge interamente nel browser (Administration Server).

### 7.4.1 Aggiunta delle Credenziali (Credential Store)

Prima di configurare Extract/Replicat, OGG deve potersi connettere al DB.

1. Apri **Administration Server** del Source (`https://rac1.localdomain:9012`).
2. Login come `oggadmin`.
3. Vai nel menu a sinistra -> **Configuration**.
4. Clicca su **+** nella sezione **Database**.
5. Aggiungi il database:
   - **Domain**: `OracleDB`
   - **Alias**: `RACDB`
   - **User ID**: `c##ggadmin`
   - **Password**: inseriscila nel form HTTPS; viene salvata nel credential store
   - **Connect String**: `//rac1-scan.localdomain:1521/RACDBPDB.localdomain` (usa lo SCAN e il servizio PDB)
6. Ripeti sul Target (`https://dbtarget.localdomain:9012`) usando il servizio applicativo del target.

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
   TABLE RACDBPDB.HR.*;
   TABLE RACDBPDB.APP.*;
   ```
6. Clicca **Create and Run**.
7. L'Extract ora è verde (Running) e sta scrivendo il Trail File locale (`er000000001`).

### 7.4.3 Creazione del Distribution Path (Distribution Server)

Il Distribution Path è la freccia che collega il Source al Target. Sostituisce il vecchio `Data Pump`.

1. Apri il **Distribution Server** sul Source (`https://rac1.localdomain:9013`).
2. Clicca **+** sotto **Paths**.
3. **Path Name**: `RAC_TO_TGT`
4. **Source**:
   - **Extract Name**: `EXT_RAC`
   - **Trail Name**: `er`
5. **Target**:
   - **Protocol**: `wss`
   - **Host**: `dbtarget.localdomain`
   - **Port**: `9014` (Porta del Receiver Server target)
   - **Trail Name**: `rt`
   - **Domain**: `OracleDB`
   - **Alias**: `dbtarget`
6. Clicca **Create and Run**.
7. Il Path diventerà verde. I trail `er` ora vengono spediti e salvati come `rt` sul target.

---

## 7.5 Initial Load con Data Pump e SCN controllato

> [!IMPORTANT]
> Prima di avviare il Replicat, i dati sul target devono essere istanziati
> partendo da uno SCN registrato. Il percorso base usa Data Pump con parfile
> temporanei: riduce la superficie di rischio e non lascia password nella
> command line.

```sql
-- Sul source RACDB come sysdba
sqlplus / as sysdba

SELECT current_scn FROM v$database;
-- Registra lo SCN nel change, ad esempio 3847291.
```

Prepara i parfile `0600` con directory Oracle approvate e lo SCN registrato.
Avvia `expdp` e `impdp` senza credenziali negli argomenti: Data Pump richiede
utente e password nel prompt interattivo.

```bash
# Sul source: il parfile include SCHEMAS=HR,APP e FLASHBACK_SCN=<SCN_REGISTRATO>
umask 077
expdp parfile=/home/oracle/secure/expdp_initial_load.par

# Trasferisci il dump con il canale approvato, poi sul target:
impdp parfile=/home/oracle/secure/impdp_initial_load.par
```

Elimina i parfile temporanei dopo la verifica. Per un caricamento via network
link usa un account dedicato e un secret store approvato: non creare database
link con password in script o cronologia.

---

## 7.6 Creazione del Replicat (Target)

Ora che i dati base ci sono, diciamo a GoldenGate di applicare le transazioni partendo dall'SCN catturato durante l'Initial Load.

1. Apri l'**Administration Server** del Target (`https://dbtarget.localdomain:9012`).
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
OGG (https://dbtarget.localdomain:9012 TargetDeploy) 1> CONNECT https://dbtarget.localdomain:9012 AS oggadmin
Password:
OGG (https://dbtarget.localdomain:9012 TargetDeploy) 2> START REPLICAT REP_TGT, AFTERCSN 3847291
```
> L'opzione `AFTERCSN` (Commit Sequence Number = SCN in Oracle) assicura che il Replicat applichi solo le transazioni committate *dopo* il momento in cui hai effettuato l'export via Data Pump.

---

## 7.7 Verifica e Monitoraggio (Web Dashboard)

Nel percorso MA usa dashboard, API REST e `adminclient`. `INFO ALL` tramite
`ggsci` resta utile solo per installazioni Classic legacy.

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

Se la riga compare, registra evidenza del test, checkpoint e lag osservato.

---

**← [FASE 6: Enterprise Manager](../../02_core_dba/06_monitoring_systems/GUIDA_FASE6_ENTERPRISE_MANAGER.md)** | 📍 [Indice Percorso Lab](../../04_governance_learning/03_esami_e_carriera/README.md) | **→ [FASE 8: Test e Verifica End-to-End](../../03_infra_lab/02_oracle_installation_asm/GUIDA_FASE8_TEST_VERIFICA.md)**
