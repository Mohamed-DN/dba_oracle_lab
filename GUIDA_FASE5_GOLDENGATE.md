# FASE 5: Configurazione GoldenGate su Standby (Extract) verso Terzo DB (Replicat)

> In questa fase configuriamo Oracle GoldenGate per catturare le modifiche dal database standby (Active Data Guard) e replicarle verso un terzo database target indipendente (`dbtarget`).

### 📸 Flusso GoldenGate

![GoldenGate: Extract → Pump → Replicat](./images/goldengate_flow.png)

---

## 5.0 Preparazione Macchina Target (`dbtarget`)

Nelle versioni precedenti di questo lab, costruivamo un terzo server VirtualBox per ospitare il database di destinazione. Tuttavia, questo richiedeva troppa RAM locale (portando il totale a 5 VM pesanti).

> ☁️ **IL NUOVO APPROCCIO (CLOUD FIRST)**
> Al posto di una VM locale, useremo il tier gratuito (Always Free) di **Oracle Cloud Infrastructure (OCI)**. Creeremo una potente istanza ARM con ben 4 CPU e 24GB di RAM, su cui faremo girare il nuovissimo **Oracle Database 23ai Free** e **Oracle GoldenGate 23ai Free**.

👉 **Smetti di leggere qui e segui la guida:** [**Setup OCI ARM come Target GoldenGate**](./GUIDA_GOLDENGATE_OCI_ARM.md).

Torna a questo punto (Step 5.1) **solo dopo** aver completato la guida OCI e aver verificato che i due nodi Standby riescano a pingare il tuo nuovo IP pubblico OCI (tramite il record in `/etc/hosts` che configurerai).

---

## 5.1 Architettura GoldenGate con ADG Standby

L'architettura che implementiamo è chiamata **Downstream Integrated Extract**:

```
┌────────────────┐      Redo Shipping       ┌──────────────────┐
│  RAC PRIMARY   │ ─────────────────────────→│  RAC STANDBY     │
│  (RACDB)       │                           │  (RACDB_STBY)    │
│                │                           │  Active DG       │
└────────────────┘                           │                  │
                                             │  ┌────────────┐  │
                                             │  │ GG Extract │  │     Trails
                                             │  │ (Integrated│──│──────────────→ ┌────────────────────┐
                                             │  │  Capture)  │  │                │  TARGET VMS        │
                                             │  └────────────┘  │                │  ┌───────────────┐ │
                                             └──────────────────┘                │  │ GG Replicat   │ │
                                                                                 │  │ (Oracle dbtar)│ │
                                                                                 │  └───────────────┘ │
                                                                                 │  ┌───────────────┐ │
                                                                                 │  │ GG Replicat   │ │
                                                                                 │  │ (PostgreSQL)  │ │
                                                                                 │  └───────────────┘ │
                                                                                 └────────────────────┘
```

> **Perché estrarre dallo standby e non dal primario?**
> 1. **Zero impatto sul primario**: L'Extract legge i redo log sullo standby, non tocca il primario.
> 2. **Ridondanza**: Se il primario muore, l'Extract continua a lavorare sullo standby (che diventa primario dopo failover).
> 3. **Best practice Oracle**: Consigliato per ambienti mission-critical.

---

## 5.2 Prerequisiti Database

### Sul Primario (RACDB) — Abilitare GoldenGate Replication

```sql
sqlplus / as sysdba

-- Abilita GoldenGate
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH SID='*';

-- Abilita supplemental logging minimale
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- Abilita supplemental logging per le tabelle che vuoi replicare
-- Per TUTTE le tabelle (approccio semplice per lab):
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Verifica
SELECT supplemental_log_data_min, supplemental_log_data_all FROM v$database;
-- Deve mostrare: YES / YES
```

> **Perché Supplemental Logging?** GoldenGate ha bisogno di informazioni aggiuntive nei redo log per ricostruire correttamente le operazioni DML. Senza supplemental logging, GG non sa quali colonne sono state modificate in un UPDATE.

### Sullo Standby (RACDB_STBY)

```sql
sqlplus / as sysdba

ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH SID='*';
```

### Sul Target (dbtarget)

```sql
sqlplus / as sysdba

ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
```

---

## 5.3 Creazione Utente GoldenGate

### Sul Primario (replicato automaticamente sullo standby da DG):

```sql
sqlplus / as sysdba

-- Crea utente GoldenGate
CREATE USER ggadmin IDENTIFIED BY <password>
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

-- Assegna privilegi necessari
GRANT DBA TO ggadmin;
GRANT SELECT ANY DICTIONARY TO ggadmin;
GRANT SELECT ANY TABLE TO ggadmin;
GRANT CREATE SESSION TO ggadmin;
GRANT ALTER SESSION TO ggadmin;
GRANT RESOURCE TO ggadmin;

-- Privilegi specifici GoldenGate
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');
```

### Sul Target (dbtarget):

```sql
sqlplus / as sysdba

CREATE USER ggadmin IDENTIFIED BY <password>
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

GRANT DBA TO ggadmin;
GRANT SELECT ANY DICTIONARY TO ggadmin;
GRANT CREATE SESSION TO ggadmin;
GRANT ALTER SESSION TO ggadmin;
GRANT RESOURCE TO ggadmin;

EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');
```

---

## 5.4 Download e Installazione GoldenGate

Scarica Oracle GoldenGate 19c (o 21c) da [Oracle eDelivery](https://edelivery.oracle.com):
- Per lo Standby: **Oracle GoldenGate 19c for Oracle Database on Linux x86-64**
- Per il Target ARM (se OCI ARM): **Oracle GoldenGate for Oracle Database on Linux ARM**

> 📸 **SNAPSHOT — "SNAP-10: Pre_GoldenGate" 🔴 CRITICO**
> Fai snapshot PRIMA di installare GoldenGate. Se GG crea problemi, torni al tuo ambiente DG perfettamente funzionante.
> ```bash
> VBoxManage snapshot "rac1" take "SNAP-10: Pre_GoldenGate"
> VBoxManage snapshot "rac2" take "SNAP-10: Pre_GoldenGate"
> VBoxManage snapshot "racstby1" take "SNAP-10: Pre_GoldenGate"
> VBoxManage snapshot "racstby2" take "SNAP-10: Pre_GoldenGate"
> VBoxManage snapshot "dbtarget" take "SNAP-10: Pre_GoldenGate"
> ```

### Installazione sullo Standby (`racstby1`)

```bash
# Come root (crea la directory)
mkdir -p /u01/app/goldengate
chown oracle:oinstall /u01/app/goldengate

# Come oracle
su - oracle
cd /u01/app/goldengate

# Scompatta GoldenGate
unzip /tmp/fbo_ggs_Linux_x64_Oracle_shiphome.zip
cd fbo_ggs_Linux_x64_Oracle_shiphome/Disk1

# Lancia l'installer (GUI)
> ⚠️ **ATTENZIONE MOBAXTERM**: Questo comando avvia una GUI. Devi essere connesso con **MobaXterm** e **X11-Forwarding** attivo (vedi Fase 0.12).
# Il DISPLAY di solito viene settato in automatico da MobaXterm.
./runInstaller
```

**Installer Steps:**
1. Software Location: `/u01/app/goldengate/ogg`
2. Database Location: Point al tuo ORACLE_HOME
3. Seleziona **Oracle GoldenGate for Oracle Database 19c**

Oppure **installazione silente**:

```bash
cat > /tmp/oggcore.rsp <<'EOF'
oracle.install.responseFileVersion=/oracle/install/rspfmt_ogginstall_response_schema_v19_1_0
INSTALL_OPTION=ORA19c
SOFTWARE_LOCATION=/u01/app/goldengate/ogg
INVENTORY_LOCATION=/u01/app/oraInventory
UNIX_GROUP_NAME=oinstall
EOF

cd fbo_ggs_Linux_x64_Oracle_shiphome/Disk1
./runInstaller -silent -responseFile /tmp/oggcore.rsp
```

### Installazione sul Target OCI (Cloud)

L'installazione e la creazione del Service Manager sul Cloud sono interamente coperte dalla **[Nuova Guida OCI ARM](./GUIDA_GOLDENGATE_OCI_ARM.md)**. Se l'hai seguita, il tuo target è già pronto a ricevere i dati sulla porta 7809 e ha l'interfaccia Web attiva in HTTPS.

---

## 5.5 Configurazione Variabili d'Ambiente GoldenGate

Su ogni macchina dove GG è installato:

```bash
cat >> /home/oracle/.bash_profile <<'EOF'
# GoldenGate Environment
export OGG_HOME=/u01/app/goldengate/ogg
export PATH=$OGG_HOME:$PATH
export LD_LIBRARY_PATH=$OGG_HOME/lib:$ORACLE_HOME/lib:$LD_LIBRARY_PATH
EOF

source /home/oracle/.bash_profile
```

---

## 5.6 Configurazione Manager (su Standby e Target)

Il Manager è il processo "supervisore" di GoldenGate: gestisce tutti gli altri processi.

### Sullo Standby (`racstby1`)

```bash
cd $OGG_HOME
./ggsci
```

```
GGSCI> CREATE SUBDIRS

GGSCI> EDIT PARAMS MGR

-- Inserisci:
PORT 7809
DYNAMICPORTLIST 7810-7820
AUTORESTART EXTRACT *, RETRIES 3, WAITMINUTES 5, RESETMINUTES 60
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPHOURS 24
```

> **Spiegazione parametri MGR:**
> - `PORT 7809`: Porta TCP su cui il Manager ascolta.
> - `DYNAMICPORTLIST`: Range di porte per i processi Extract/Pump/Replicat.
> - `AUTORESTART`: Se un Extract crasha, il Manager lo riavvia automaticamente (max 3 tentativi, aspetta 5 minuti tra un tentativo e l'altro).
> - `PURGEOLDEXTRACTS`: Pulisce automaticamente i trail file vecchi.

```
GGSCI> START MGR
GGSCI> INFO MGR
-- Output: Manager is running (port 7809).
```

### Sul Target (`dbtarget`)

```
GGSCI> CREATE SUBDIRS
GGSCI> EDIT PARAMS MGR

PORT 7809
DYNAMICPORTLIST 7810-7820
AUTORESTART REPLICAT *, RETRIES 3, WAITMINUTES 5, RESETMINUTES 60
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPHOURS 24

GGSCI> START MGR
```

---

## 5.7 Configurazione Extract (sullo Standby)

L'Extract cattura le modifiche dai redo log. Usiamo **Integrated Capture** che sfrutta il LogMiner interno di Oracle — è il metodo più robusto e supportato.

### Preparazione Database per Integrated Extract

```sql
-- Sullo standby come sysdba
sqlplus / as sysdba

-- Registra lo schema di heartbeat GoldenGate
@$OGG_HOME/admin_setup.sql
-- Quando richiesto:
-- Tablespace for GoldenGate: USERS
-- Temp tablespace: TEMP
```

### Creazione e Configurazione Extract

```bash
cd $OGG_HOME
./ggsci
```

```
-- Login al database
GGSCI> DBLOGIN USERID ggadmin@RACDB_STBY PASSWORD <password>

-- Registra l'Integrated Extract nel database
GGSCI> REGISTER EXTRACT ext_racdb DATABASE

-- Aggiungi l'Extract
GGSCI> ADD EXTRACT ext_racdb, INTEGRATED TRANLOG, BEGIN NOW

-- Aggiungi il Trail locale (dove l'Extract scrive le modifiche catturate)
GGSCI> ADD EXTTRAIL ./dirdat/ea, EXTRACT ext_racdb, MEGABYTES 100
```

> **Perché `INTEGRATED TRANLOG`?** A differenza del Classic Extract che legge direttamente i redo file, l'Integrated Extract usa il LogMiner Server integrato nel database. Questo è più efficiente, supporta più data types, e funziona nativamente con RAC/ADG.

### Creazione Parameter File dell'Extract

```
GGSCI> EDIT PARAMS ext_racdb
```

```
EXTRACT ext_racdb
USERID ggadmin@RACDB_STBY, PASSWORD <password>
EXTTRAIL ./dirdat/ea
LOGALLSUPCOLS
UPDATERECORDFORMAT COMPACT

-- Specifica lo schema e le tabelle da replicare
-- Esempio: replicare tutto lo schema HR
TABLE HR.*;

-- Oppure per tabelle specifiche:
-- TABLE HR.EMPLOYEES;
-- TABLE HR.DEPARTMENTS;
```

> **Spiegazione parametri:**
> - `LOGALLSUPCOLS`: Include tutte le colonne supplemental log nel trail (necessario per conflitti e CDC).
> - `UPDATERECORDFORMAT COMPACT`: Riduce la dimensione dei trail file includendo solo le colonne modificate.
> - `TABLE HR.*`: Cattura tutte le tabelle dello schema HR.

---

## 5.8 Configurazione Data Pump (sullo Standby)

Il Data Pump legge i trail locali e li trasmette via rete al Target.

```
GGSCI> ADD EXTRACT pump_racdb, EXTTRAILSOURCE ./dirdat/ea

GGSCI> ADD RMTTRAIL ./dirdat/ra, EXTRACT pump_racdb, MEGABYTES 100

GGSCI> EDIT PARAMS pump_racdb
```

```
EXTRACT pump_racdb
USERID ggadmin@RACDB_STBY, PASSWORD <password>
RMTHOST dbtarget.localdomain, MGRPORT 7809
RMTTRAIL ./dirdat/ra
TABLE HR.*;
```

> **Perché un Data Pump?** È un livello di indirezione: l'Extract scrive localmente, il Pump trasmette via rete. Se la rete cade, l'Extract non si ferma — il Pump accumula i trail e li spedisce quando la rete torna. Senza Pump, un problema di rete fermerebbe l'Extract.

---

## 5.9 Configurazione Replicat (sul Target OCI)

A differenza dell'Extract locale, sul target in Cloud abbiamo installato **GoldenGate 23ai Microservices**. Non useremo `ggsci` da riga di comando, ma l'interfaccia grafica Web super reattiva!

1. Apri il browser e vai al Service Manager OCI: `https://<IP_PUBBLICO_CLOUD>:9011`
2. Accedi con `admin` / `oracle` (o la password che hai scelto).
3. Vai all'Administration Server (porta 9012).
4. Nel menu laterale, seleziona **Credentials** e aggiungi le credenziali del database (Username: `ggadmin`, Password: `ggadmin`, Connect String: `//localhost:1521/FREEPDB1`).
5. Vai su **Replicats** e clicca su **+ (Add Replicat)**.
6. Scegli **Integrated Replicat** e usa questi parametri nel wizard:
   - Replicat Name: `REPTAR`
   - Trail Name: `./dirdat/ra`
   - Parameter File (Mapping):
     ```text
     REPLICAT REPTAR
     USERIDALIAS ggadminAlias
     ASSUMETARGETDEFS
     MAP HR.*, TARGET HR.*;
     ```

> **Microservices vs Classic:** In GG 23ai, il credential store si nasconde dietro un *Alias* (es. `ggadminAlias`) gestito dalla Web UI, quindi nel file dei parametri non si scrive più la password in chiaro rispetto all'architettura Classic di 19c.

> **Spiegazione parametri:**
> - `ASSUMETARGETDEFS`: Assume che la struttura delle tabelle sul target sia identica al source. Se le tabelle fossero diverse, useresti un file `DEFGEN`.
> - `DISCARDFILE`: Se una transazione non può essere applicata (es. conflitto chiave), viene scritta qui invece di fermare il Replicat.
> - `MAP ... TARGET`: Mappa le tabelle source alle tabelle target. `HR.* -> HR.*` significa "stesse tabelle".

---

## 5.10 Initial Load (Instanziazione) tramite CSN

Prima di avviare la replica continua, devi caricare i dati esistenti sul target. La **Best Practice Oracle** è usare Data Pump (`expdp`/`impdp`) sincronizzato tramite un **SCN (System Change Number)** specifico. Senza questo, il Replicat applicherebbe modifiche sovrapposte al dump, causando errori di violazione chiave primaria!

### Step 1: Trova l'SCN corrente sullo Standby

```sql
-- Su racstby1 (come sysdba)
sqlplus / as sysdba
SELECT current_scn FROM v$database;
-- Annota questo numero! Es: 3456789
```

### Step 2: Esporta i dati congelati a quell'SCN

```bash
# Sullo Standby - esporta specificando l'SCN
expdp ggadmin/<password>@RACDB_STBY schemas=HR directory=DATA_PUMP_DIR dumpfile=hr_initial.dmp logfile=hr_export.log flashback_scn=3456789
```

### Step 3: Trasferisci e Importa sul Target OCI

Dato che il sistema remoto è su Oracle Cloud, l'utente per l'SSH è `opc`.

```bash
# Sullo Standby - trasferisci il dump nel cloud (assicurati che la SSH key funzioni da qui!)
# Metti l'IP corretto del cloud:
scp /u01/app/oracle/admin/RACDB_STBY/dpdump/hr_initial.dmp opc@130.x.x.x:/tmp/

# Nel terminale MobaXterm collegato al Cloud (dbtarget-arm):
sudo su - oracle
# Sposta il dump nella directory DataPump di Oracle 23ai Free
mv /tmp/hr_initial.dmp /opt/oracle/admin/FREE/dpdump/

# Importa i dati nel Pluggable Database (FREEPDB1)
impdp ggadmin/<password>@localhost:1521/FREEPDB1 schemas=HR directory=DATA_PUMP_DIR dumpfile=hr_initial.dmp logfile=hr_import.log
```

> 💡 **Il trucco del DBA**: Avendo importato i dati fermi all'SCN `3456789`, diremo al Replicat di ignorare tutte le transazioni precedenti a quel momento e di applicare solo le novità!

---

## 5.11 Avvio dei Processi

### Sequenza di avvio (ORDINE IMPORTANTE):

```
-- 1. Avvia Manager (su entrambi, se non già attivo)
-- Già fatto in 5.6

-- 2. Avvia l'Extract sullo Standby
GGSCI> START EXTRACT ext_racdb

-- 3. Avvia il Data Pump sullo Standby
GGSCI> START EXTRACT pump_racdb

-- 4. Avvia il Replicat sul Target OCI (Dall'interfaccia WEB Microservices)
-- Dato che stiamo usando la Web UI, vai su Replicats -> Action -> Start con opzione "After CSN"
-- e inserisci lì il tuo CSN (es. 3456789).
```

### Verifica

```
-- Sullo Standby
GGSCI> INFO ALL

Program     Status      Group       Lag at Chkpt  Time Since Chkpt
MANAGER     RUNNING
EXTRACT     RUNNING     ext_racdb   00:00:02      00:00:05
EXTRACT     RUNNING     pump_racdb  00:00:00      00:00:03

-- Sul Target OCI (Microservices)
-- Dalla Home Page web (porta 9011), naviga in Administration Server (9012)
-- Il Replicat `REPTAR` deve avere la spunta verde (Running) e un ritardo minimo.
```

> Se tutti i processi sono `RUNNING` con lag minimo, hai un sistema di replica funzionante! 🎉

> 📸 **SNAPSHOT — "SNAP-11: GoldenGate_Running" ⭐ MILESTONE FINALE**
> L'intero ambiente è operativo: RAC + Data Guard + GoldenGate! Questo è il tuo punto di partenza "gold".
> ```bash
> VBoxManage snapshot "rac1" take "SNAP-11: GoldenGate_Running"
> VBoxManage snapshot "rac2" take "SNAP-11: GoldenGate_Running"
> VBoxManage snapshot "racstby1" take "SNAP-11: GoldenGate_Running"
> VBoxManage snapshot "racstby2" take "SNAP-11: GoldenGate_Running"
> VBoxManage snapshot "dbtarget" take "SNAP-11: GoldenGate_Running"
> ```

---

## 5.12 Monitoraggio Continuo

```
-- Statistiche dettagliate dell'Extract
GGSCI> STATS EXTRACT ext_racdb, LATEST

-- Statistiche del Replicat
GGSCI> STATS REPLICAT rep_racdb, LATEST

-- Lag dell'Extract
GGSCI> LAG EXTRACT ext_racdb

-- Report dettagliato
GGSCI> VIEW REPORT ext_racdb
GGSCI> VIEW REPORT rep_racdb
```

---

## 🚨 TROUBLESHOOTING: L'Extract o il Replicat vanno in ABENDED?

Se lanci `INFO ALL` e vedi che un processo è in stato `ABENDED` invece di `RUNNING`, qualcosa è andato storto. Non andare nel panico, GoldenGate registra tutto dettagliatamente.

**Come capire l'errore:**
1. **Controlla il file di log generale (ggserr.log)**:
   ```bash
   # Dalla directory $OGG_HOME
   tail -n 50 ggserr.log
   ```
   > Questo file ti dirà il motivo ad alto livello del crash (es. "OGG-00446: Could not find archived log", oppure errori di permessi su Oracle).

2. **Controlla il report specifico del processo**:
   ```
   GGSCI> VIEW REPORT ext_racdb
   # Oppure
   GGSCI> VIEW REPORT rep_racdb
   ```
   > Scorri fino in fondo al report. Lì troverai la query SQL esatta che ha bloccato il Replicat (es. violazione di chiave primaria sul target) o il motivo per cui l'Extract si è fermato sul source. Nella maggior parte dei casi troverai un codice ORA-XXXXX.

---

## ✅ Checklist Fine Fase 5

```
-- Sullo Standby
GGSCI> INFO ALL
-- ext_racdb: RUNNING
-- pump_racdb: RUNNING

-- Sul Target
GGSCI> INFO ALL
-- rep_racdb: RUNNING

-- Lag < 10 secondi
GGSCI> LAG EXTRACT ext_racdb
GGSCI> LAG REPLICAT rep_racdb
```

---

**→ Prossimo: [FASE 6: Test di Verifica](./GUIDA_FASE6_TEST_VERIFICA.md)**
