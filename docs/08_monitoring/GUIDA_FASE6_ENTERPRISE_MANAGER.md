# FASE 6: Oracle Enterprise Manager Cloud Control 24ai (Single OMS Lab)

Aggiornata: 27 aprile 2026
Target lab: Oracle Linux 7.9/8.x, Oracle DB 19c, RAC + Data Guard già operativi.

> **Versione software**: Oracle Enterprise Manager 24ai Release 1 (24.1.0.0.0)
> Compatibile con Oracle Database 19c, 21c, 23ai come repository.

Questa fase aggiunge una console centralizzata per monitorare e governare tutto il laboratorio:

- host e metriche OS
- database single instance e RAC
- ASM, listener, Data Guard
- alerting, incident management, notification, jobs, blackout
- monitoraggio backup RMAN

---

## 6.0A Ingresso da Fase 5 (preflight)

Prima di installare EM, verifica che il lab Oracle sia stabile:

```bash
dgmgrl sys/<password>@RACDB "show configuration;"
```

```sql
-- Sul DB principale
sqlplus / as sysdba
SELECT name, open_mode, log_mode FROM v$database;
SELECT value FROM v$parameter WHERE name='compatible';
```

```bash
# Dal nodo OMS: risoluzione DNS e reachability target
getent hosts rac1 rac2 racstby1 racstby2
```

Gate minimo:

- Data Guard in `SUCCESS`
- repository DB raggiungibile dal nodo OMS
- spazio disco e RAM adeguati

> **Nota**: GoldenGate (Fase 7) NON è un prerequisito per questa fase. EM funziona indipendentemente dalla presenza di GoldenGate.

## 6.0B Se OMS è già installato

Se hai già un OMS funzionante (test precedenti), non reinstallare:

```bash
$OMS_HOME/bin/emctl status oms -details
$AGENT_HOME/bin/emctl status agent
```

Se `OMS Up` e `Agent Up`, vai direttamente a `6.8` (deploy agent target) oppure `6.9` (onboarding target).

---

## 6.1 Obiettivo operativo

A fine fase devi avere:

- 1 host dedicato (o VM) con OMS + local Agent
- repository database 19c per EM
- target registrati (host + DB + ASM + listener)
- rule set incidenti e notifiche email
- dashboard operative giornaliere
- runbook test alert validato

---

## 6.2 Architettura consigliata nel tuo lab

Scelta bloccata: Single OMS su host dedicato (o sulla stessa macchina del repository DB in lab).

```text
+------------------------+            +---------------------------+
| Host OMS               |            | Repository DB             |
| OMS + Agent + Console  |----------->| Oracle 19c (EMREP)        |
| Porta console HTTPS    |            | SYSMAN schema             |
+------------+-----------+            +-------------+-------------+
             |
             | Agent uploads / discovery
             v
+----------------+  +----------------+
| RAC primary    |  | RAC standby    |
| host/db/asm    |  | host/db/asm    |
+----------------+  +----------------+
```

Nota pratica:

- In lab puoi mettere OMS e repository DB sullo stesso host per risparmiare RAM.
- In produzione si preferisce separazione dedicata OMS vs repository.

---

## 6.3 Prerequisiti minimi

### 6.3.1 Hardware

Configurazione consigliata:

| Risorsa | Minimo Lab | Consigliato | Note |
|---------|-----------|-------------|------|
| vCPU    | 4         | 8           | Minimo 4 core |
| RAM     | 8 GB      | 16 GB       | Con 8 GB: spegni GUI, SGA ridotta |
| Disco   | 120 GB    | 200 GB      | Usa partizione grande (es. `/home`) |

> **⚠️ Con 8 GB di RAM**: L'installazione è possibile ma al limite. Spegni l'interfaccia grafica (`sudo systemctl isolate multi-user.target`) prima di lanciare l'installer OMS per recuperare ~1.5 GB di RAM. Configura il DB repository con SGA ridotta (2 GB max).

### 6.3.2 Software

- Oracle Linux 7.9, 8.x o 9.x
- Oracle Database 19c (repository)
- Oracle Enterprise Manager 24ai Release 1 (24.1.0.0.0) — 5 file ZIP, ~7.8 GB totali
- Download da: [Oracle Software Delivery Cloud](https://edelivery.oracle.com/) → cerca "Enterprise Manager Base Platform - OMS 24.1.0.0.0"

### 6.3.3 Rete e porte

Apri almeno:

- 7802/7803 (upload/communication)
- 3872 (agent)
- 4903, 4904 (OMS internal)
- 1521 (repository DB)
- 7803 (console HTTPS OMS default)

Usa DNS risolvibile per tutti gli host coinvolti.

### 6.3.4 Utenti e path consigliati

- utente software OMS: `oracle` (lab) o `omsuser` (enterprise)
- base directory: `/home/oracle/app` (se `/home` ha più spazio di `/`)
- middleware home OMS: `/home/oracle/app/emcc/middleware`
- agent base: `/home/oracle/app/emcc/agent`

### 6.3.5 Naming Convention: Rinomina Hostname (Best Practice)

Per evitare problemi con l'installer (che potrebbe prendere nomi generici o legati al router di casa, es. `Host-010.homenet...`), è **fortemente raccomandato** assegnare alla macchina un nome pulito e descrittivo prima di iniziare.

Nome consigliato: `oem` oppure `oms`.

**Come rinominare la macchina correttamente:**
```bash
# 1. Imposta il nuovo nome host a livello OS
sudo hostnamectl set-hostname oem

# 2. Aggiorna il file hosts locale (IMPORTANTE)
# Aggiungi il nuovo nome accanto al tuo IP (es. 192.168.x.x oem Host-010)
sudo nano /etc/hosts

# 3. Riavvia la sessione SSH per applicare le modifiche
```

> ⚠️ **Attenzione**: Il campo "Nome host" all'interno del wizard di installazione Oracle **NON** rinomina la macchina. L'installer si aspetta che la macchina Linux sia già configurata con il nome corretto e che questo sia risolvibile tramite `ping oem`.

---

## 6.4 Analisi risorse — Esempio reale con 8 GB RAM

Se il tuo host ha risorse limitate (es. 8 GB RAM, disco root piccolo), ecco la strategia:

```bash
# Verifica risorse
df -h          # Identifica la partizione con più spazio
free -h        # Verifica RAM disponibile
ps -ef | grep pmon  # Verifica se ci sono DB già attivi
```

Esempio output tipico:

```text
/dev/mapper/ol-root   70G   37G     34G  53% /          ← POCO SPAZIO
/dev/mapper/ol-home  387G   11G    376G   3% /home      ← USA QUESTA!
Mem:   7,4Gi  used: 1,1Gi  free: 3,9Gi  available: 6,0Gi
Swap:  7,8Gi  used: 0B     free: 7,8Gi
```

**Regola**: installa tutto sotto `/home/oracle/app/` per evitare di saturare la root.

---

## 6.5 Installazione Database 19c di Repository (da zero)

> **Se hai già un database 19c attivo**, salta al punto 6.6.

Questa sezione mostra come installare Oracle 19c da zero e creare il database `EMREP` che OEM userà come repository.

### 6.5.1 Preparazione directory

```bash
# Crea le directory (tutto sotto /home per sfruttare lo spazio)
sudo mkdir -p /home/oracle/app/product/19.3.0/dbhome_1
sudo mkdir -p /home/oracle/app/oraInventory
sudo mkdir -p /home/oracle/app/oradata
sudo chown -R oracle:oinstall /home/oracle/app
sudo chmod -R 775 /home/oracle/app
```

### 6.5.2 Scompattare il software Oracle 19c

```bash
# IMPORTANTE: scompattare DENTRO la directory che sarà ORACLE_HOME
cd /home/oracle/app/product/19.3.0/dbhome_1
unzip /percorso/del/file/LINUX.X64_193000_db_home.zip
```

> **Attenzione alla sintassi `unzip`**: NON aggiungere il percorso di destinazione dopo il file ZIP. Scompatta dalla directory di destinazione, oppure usa il flag `-d`:
> ```bash
> unzip /percorso/LINUX.X64_193000_db_home.zip -d /home/oracle/app/product/19.3.0/dbhome_1
> ```

### 6.5.3 Installazione Software Only (silent)

Crea il response file e lancia l'installazione con un unico blocco copia-incolla:

```bash
# Crea il response file
cat > /home/oracle/db_install.rsp <<'EOF'
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_tty_v19.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/home/oracle/app/oraInventory
ORACLE_HOME=/home/oracle/app/product/19.3.0/dbhome_1
ORACLE_BASE=/home/oracle/app
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=dba
oracle.install.db.OSBACKUPDBA_GROUP=dba
oracle.install.db.OSDGDBA_GROUP=dba
oracle.install.db.OSKMDBA_GROUP=dba
oracle.install.db.OSRACDBA_GROUP=dba
oracle.install.db.ConfigureAsContainerDB=false
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
DECLINE_SECURITY_UPDATES=true
EOF

# Lancia l'installazione (circa 2-5 minuti)
cd /home/oracle/app/product/19.3.0/dbhome_1
./runInstaller -silent -responseFile /home/oracle/db_install.rsp -ignorePrereq
```

Output atteso:

```text
Successfully Setup Software.
```

### 6.5.4 Esegui gli script root

```bash
sudo /home/oracle/app/oraInventory/orainstRoot.sh
sudo /home/oracle/app/product/19.3.0/dbhome_1/root.sh
```

### 6.5.5 Imposta le variabili d'ambiente

```bash
# Aggiungi al profilo e carica
cat >> /home/oracle/.bash_profile <<'EOF'
export ORACLE_SID=EMREP
export ORACLE_HOME=/home/oracle/app/product/19.3.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
EOF

source /home/oracle/.bash_profile
```

### 6.5.6 Creazione del database EMREP

```bash
# Crea la directory per i datafile
mkdir -p /home/oracle/app/oradata

# Crea il database (circa 10-15 minuti)
# totalMemory 2048 = 2 GB di SGA (minimo per OEM con 8 GB di RAM totale)
dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -gdbName EMREP -sid EMREP \
  -createAsContainerDatabase false \
  -numberOfPDBs 0 \
  -storageType FS \
  -datafileDestination /home/oracle/app/oradata \
  -totalMemory 2048 \
  -characterset AL32UTF8 \
  -sysPassword <tua_password> \
  -systemPassword <tua_password>
```

Output atteso:

```text
Creazione del database completata.
Informazioni database:
Nome database globale:EMREP
Identificativo di sistema (SID):EMREP
```

### 6.5.7 Verifica post-creazione

```bash
sqlplus / as sysdba <<'EOF'
SELECT name, open_mode, log_mode FROM v$database;
SELECT value FROM v$parameter WHERE name='compatible';
SHOW PARAMETER sga_target;
EXIT;
EOF
```

### 6.5.8 Configurazione ARCHIVELOG (richiesto da OEM)

```bash
sqlplus / as sysdba 
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
SELECT log_mode FROM v$database;
EXIT;

```

### 6.5.9 Configura e Avvia il Listener

> ⚠️ **ERRORE COMUNE: `TNS-12541: TNS:no listener`**
> Se dopo un riavvio della macchina esegui `lsnrctl status` e ottieni questo errore, significa semplicemente che il listener non è stato avviato. Oracle **NON avvia il listener automaticamente al boot** a meno che non lo configuri esplicitamente (vedi sezione 6.5.10).

#### Step 1: Crea il file `listener.ora` (se non esiste)

```bash
# Verifica se esiste già
cat $ORACLE_HOME/network/admin/listener.ora 2>/dev/null || echo "FILE NON TROVATO"

# Se non esiste, crealo:
cat > $ORACLE_HOME/network/admin/listener.ora <<'EOF'
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = EMREP)
      (ORACLE_HOME = /home/oracle/app/product/19.3.0/dbhome_1)
      (SID_NAME = EMREP)
    )
  )
EOF
```

> 💡 **Perché `SID_LIST`?** Il listener "dinamico" registra il database solo quando il DB è già aperto e si auto-registra tramite il processo LREG. Ma se il DB non è ancora avviato (es. dopo un reboot), il listener non sa che EMREP esiste. La sezione `SID_LIST` è una **registrazione statica** che dice al listener: "il database EMREP sta qui, anche se non è ancora partito". Questo è **fondamentale** per permettere all'installer OEM di connettersi al repository.

#### Step 2: Avvia il Listener

```bash
# Assicurati che le variabili siano caricate
source /home/oracle/.bash_profile

# Avvia il listener
lsnrctl start

# Verifica che sia attivo
lsnrctl status
# Deve mostrare: "TNS-12541" → NO!
# Deve mostrare: "The listener supports no services" (se il DB non è ancora up)
# Oppure: "Service EMREP has 1 instance(s)" (se il DB è già up)
```

#### Step 3: Avvia il Database e Registralo

```bash
# Avvia il database
sqlplus / as sysdba <<'EOF'
STARTUP;
ALTER SYSTEM REGISTER;
EXIT;
EOF

# Verifica che il listener ora veda il servizio
lsnrctl status
# Deve mostrare: Service "EMREP" has 1 instance(s).
```

> 💡 **`ALTER SYSTEM REGISTER`** forza la registrazione immediata del database nel listener. Senza questo comando, il processo LREG del database si registra automaticamente, ma solo ogni 60 secondi.

### 6.5.10 Avvio automatico al boot (FONDAMENTALE!)

Senza questa configurazione, ogni volta che riavvii Host-010 dovrai avviare manualmente listener e database. Ecco come automatizzare.

#### Opzione A: Usa `/etc/oratab` + `dbstart` (Metodo Oracle Standard)

```bash
# 1. Configura /etc/oratab per avvio automatico
# Cambia la 'N' finale in 'Y' per il database EMREP
sudo sed -i 's/^EMREP:.*/EMREP:\/home\/oracle\/app\/product\/19.3.0\/dbhome_1:Y/' /etc/oratab

# Verifica:
grep EMREP /etc/oratab
# Deve mostrare: EMREP:/home/oracle/app/product/19.3.0/dbhome_1:Y
```

#### Opzione B: Crea un servizio systemd (Metodo Moderno)

```bash
# Crea lo script di avvio/spegnimento
sudo cat > /usr/local/bin/oracle_emrep.sh <<'SCRIPT'
#!/bin/bash
export ORACLE_HOME=/home/oracle/app/product/19.3.0/dbhome_1
export ORACLE_SID=EMREP
export PATH=$ORACLE_HOME/bin:$PATH

case "$1" in
  start)
    su - oracle -c "$ORACLE_HOME/bin/lsnrctl start"
    su - oracle -c "$ORACLE_HOME/bin/sqlplus / as sysdba <<< 'STARTUP;'"
    su - oracle -c "$ORACLE_HOME/bin/sqlplus / as sysdba <<< 'ALTER SYSTEM REGISTER;'"
    ;;
  stop)
    su - oracle -c "$ORACLE_HOME/bin/sqlplus / as sysdba <<< 'SHUTDOWN IMMEDIATE;'"
    su - oracle -c "$ORACLE_HOME/bin/lsnrctl stop"
    ;;
esac
SCRIPT
sudo chmod +x /usr/local/bin/oracle_emrep.sh

# Crea il servizio systemd
sudo cat > /etc/systemd/system/oracle-emrep.service <<'SVC'
[Unit]
Description=Oracle Database EMREP + Listener
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/oracle_emrep.sh start
ExecStop=/usr/local/bin/oracle_emrep.sh stop
TimeoutStartSec=300
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
SVC

# Abilita e testa
sudo systemctl daemon-reload
sudo systemctl enable oracle-emrep

# Test manuale (senza dover riavviare la macchina)
sudo systemctl start oracle-emrep
sudo systemctl status oracle-emrep
```

> 💡 **Quale scegliere?** L'Opzione A è più semplice ma richiede che qualcosa invochi `dbstart`. L'Opzione B è autonoma: systemd avvia tutto automaticamente al boot senza intervento manuale.

### 6.5.11 Procedura di avvio manuale dopo un reboot (Cheat Sheet)

> 🛑 **Sei appena rientrato su Host-010 dopo un riavvio e non funziona niente?**
> Copia e incolla questo blocco intero:

```bash
# === RIAVVIO COMPLETO STACK ORACLE SU HOST-010 ===
source /home/oracle/.bash_profile

# 1. Avvia il Listener
lsnrctl start

# 2. Avvia il Database
sqlplus / as sysdba <<'EOF'
STARTUP;
ALTER SYSTEM REGISTER;
SELECT name, open_mode FROM v$database;
EXIT;
EOF

# 3. Verifica finale
lsnrctl status
echo "=== Stack Oracle OK ==="
```

---

## 6.6 Installazione OMS 24ai

### 6.6.1 Download del software

Scarica tutti i 5 file ZIP da [Oracle Software Delivery Cloud](https://edelivery.oracle.com/):

| File | Descrizione | Dimensione |
|------|------------|------------|
| V1046951-01.zip | Oracle Enterprise Manager 24ai R1 (1 of 5) | 1.8 GB |
| V1046952-01.zip | Oracle Enterprise Manager 24ai R1 (2 of 5) | 1.4 GB |
| V1046953-01.zip | Oracle Enterprise Manager 24ai R1 (3 of 5) | 1.6 GB |
| V1046954-01.zip | Oracle Enterprise Manager 24ai R1 (4 of 5) | 1.6 GB |
| V1046955-01.zip | Oracle Enterprise Manager 24ai R1 (5 of 5) | 1.5 GB |

> **Totale**: ~7.8 GB. Scarica TUTTI i file, altrimenti l'installazione fallisce.

### 6.6.2 Preparazione (copia-incolla unico blocco)

```bash
# Crea le directory per OEM
mkdir -p /home/oracle/app/emcc/middleware
mkdir -p /home/oracle/app/emcc/agent
mkdir -p /home/oracle/Scaricati/em24ai

# Sposta i file ZIP nella cartella dedicata (modifica il percorso se diverso)
mv /home/oracle/Scaricati/V104695*.zip /home/oracle/Scaricati/em24ai/

# Scompatta tutti i file
cd /home/oracle/Scaricati/em24ai
for f in V104695*.zip; do unzip -o "$f"; done

# Rendi eseguibile il binario dell'installer
chmod +x em*.bin 2>/dev/null || chmod +x em_install.pl 2>/dev/null
```

### 6.6.3 Installazione grafica (consigliata in lab)

```bash
cd /home/oracle/Scaricati/em24ai
./em*.bin
```

Nel wizard grafico:

1. **Installation Type**: "Create a new Enterprise Manager System" → "Advanced"
2. **Software Location**:
   - Middleware Home: `/home/oracle/app/emcc/middleware`
   - Agent Base: `/home/oracle/app/emcc/agent`
3. **Dettagli di connessione al database** (Passo 7):
   - **Nome host database**: `oem.localdomain` (o il nome host che hai impostato)
   - **Porta**: `1521`
   - **Servizio/SID**: `EMREP`
   - **Password SYS**: la password dell'utente SYS (es. `root`)
   - **Dimensione distribuzione**: `SMALL` (adatta al nostro lab)
   *(Non spuntare le opzioni SSL a meno che non le hai esplicitamente configurate sul DB)*
4. **Tablespace**: lascia i default (verranno creati automaticamente)
5. **Port Configuration**: lascia i default (7803 per console HTTPS)
6. **Review e Install**

> **⚠️ Con 8 GB di RAM**: Prima di lanciare l'installer, spegni la GUI per liberare ~1.5 GB:
> ```bash
> sudo systemctl isolate multi-user.target
> ```
> Poi accedi via SSH dal tuo PC Windows e lancia l'installer.

### 6.6.4 Installazione Silente OMS (Response File)

Per automazione e ripetibilità, usa il response file:

```bash
# Crea il response file per installazione silente
cat > /tmp/em_install.rsp <<'EOF'
RESPONSEFILE_VERSION=2.2.1.0.0
INSTALL_TYPE="TYPICAL"

# Percorsi (tutto sotto /home per sfruttare lo spazio)
ORACLE_MIDDLEWARE_HOME_LOCATION="/home/oracle/app/emcc/middleware"
ORACLE_HOSTNAME=<tuo_hostname>
AGENT_BASE_DIR="/home/oracle/app/emcc/agent"

# Repository DB
DATABASE_HOSTNAME=localhost
LISTENER_PORT=1521
SERVICENAME_OR_SID=EMREP
SYS_PASSWORD=<sys_password>
SYSMAN_PASSWORD=<sysman_password>

# Tablespace su filesystem
MANAGEMENT_TABLESPACE_LOCATION=/home/oracle/app/oradata/EMREP/mgmt.dbf
CONFIGURATION_DATA_TABLESPACE_LOCATION=/home/oracle/app/oradata/EMREP/mgmt_ecm_depot.dbf
JVM_DIAGNOSTICS_TABLESPACE_LOCATION=/home/oracle/app/oradata/EMREP/mgmt_deepdive.dbf

# Security
WLS_ADMIN_SERVER_USERNAME=weblogic
WLS_ADMIN_SERVER_PASSWORD=<wls_password>
WLS_ADMIN_SERVER_CONFIRM_PASSWORD=<wls_password>

# Porte (default)
EM_UPLOAD_PORT=4903
EM_CENTRAL_CONSOLE_PORT=7803
EOF
```

```bash
# Installazione silente
cd /home/oracle/Scaricati/em24ai
./em*.bin -silent -responseFile /tmp/em_install.rsp \
  -invPtrLoc /etc/oraInst.loc \
  -J-Djava.io.tmpdir=/tmp

# Post-install root scripts
sudo /home/oracle/app/emcc/middleware/allroot.sh
```

> **Best Practice**: In produzione, salva il response file (senza password) nel repository per riproducibilità. Le password vanno gestite via vault o variabili d'ambiente.

### 6.6.5 Comandi post-install obbligatori

```bash
# OMS status
/home/oracle/app/emcc/middleware/bin/emctl status oms -details

# Agent locale status
/home/oracle/app/emcc/agent/agent_inst/bin/emctl status agent

# URL console
/home/oracle/app/emcc/middleware/bin/emctl status oms -details | egrep "Console URL|Upload URL"
```

Login console:

- URL: `https://<tuo_hostname>:7803/em`
- user: `SYSMAN`

---

## 6.7 Variabili d'ambiente per OMS e Agent

Aggiungi al profilo per comodità:

```bash
cat >> /home/oracle/.bash_profile <<'EOF'
export OMS_HOME=/home/oracle/app/emcc/middleware
export AGENT_HOME=/home/oracle/app/emcc/agent/agent_inst
EOF

source /home/oracle/.bash_profile
```

---

## 6.8 Deploy agent sui target host

Per ogni host target (rac1, rac2, racstby1, racstby2):

1. Deploy Agent da console (Add Host Targets).
2. Configura named credentials SSH + sudo.
3. Verifica upload heartbeat agent.

Comandi diagnostici su host target:

```bash
$AGENT_HOME/bin/emctl status agent
$AGENT_HOME/bin/emctl upload agent
$AGENT_HOME/bin/emctl clearstate agent
```

---

## 6.9 Onboarding target Oracle

Ordine consigliato:

1. Host target
2. Listener
3. Database instances
4. ASM instance + diskgroups
5. RAC database target
6. Data Guard association

Verifiche minime in console:

- target status: Up
- metric collection senza errori
- availability timeline coerente

---

## 6.10 Setup operativo giornaliero

### 6.10.1 Dashboard e homepage

Crea homepage operative:

- Infrastructure Overview
- Database Group (RAC primary)
- Database Group (standby)
- Critical Incidents

### 6.10.2 Metric thresholds

Definisci soglie realistiche per lab:

- CPU host > 85% per 15 min
- Filesystem usage > 85%
- Tablespace usage > 85%
- Failed login attempts
- Data Guard transport/apply lag

### 6.10.3 Incident Rules

Crea almeno due rule set:

- `LAB_CRITICAL_DB`
- `LAB_WARNING_INFRA`

Routing esempio:

- Critical -> email immediata
- Warning -> digest ogni 30 minuti

### 6.10.4 Notifications (SMTP)

Configura:

- SMTP server
- sender address
- recipient groups (DBA team)

Testa con invio notifica di prova e con incidente reale simulato.

### 6.10.5 Jobs e library

Crea job standard:

- SQL health check giornaliero
- check FRA usage
- verifica Data Guard lag
- stato backup RMAN

Salva job template nella library per riuso.

### 6.10.6 Blackout

Usa blackout per manutenzione:

- patching Grid/DB
- reboot host
- test failover/switchover

Regola: nessuna attività pianificata senza blackout aperto.

---

## 6.11 Monitoraggio specifico RMAN

In EM crea viste/favorite su:

- ultimo backup job
- backup failed negli ultimi 7 giorni
- recovery area usage
- missing archived logs

Cross-check SQL utile:

```sql
SELECT session_key, input_type, status, start_time, end_time
FROM v$rman_backup_job_details
ORDER BY session_key DESC;
```

Collega questa fase alla tua guida:

- `GUIDA_FASE5_RMAN_BACKUP.md`

---

## 6.12 Runbook test pratici (lab)

Ogni test deve registrare: data, obiettivo, tempo rilevazione alert, esito.

### Test 1 - Alert CPU host

1. genera carico CPU sul target
2. attende superamento soglia
3. verifica incidente e notifica email

Esito atteso:

- incidente warning/critical creato
- email ricevuta

### Test 2 - Tablespace alert

1. riempi tablespace test oltre soglia
2. verifica evento in EM
3. riduci uso tablespace e chiudi incidente

Esito atteso:

- incidente auto-clear dopo rientro soglia

### Test 3 - Listener down

1. stop listener su host target
2. verifica target unavailable
3. restart listener

Esito atteso:

- stato target torna Up e incidente chiuso

### Test 4 - Data Guard lag

1. simula backlog apply (lab controllato)
2. verifica metrica lag e incidente
3. ripristina apply realtime

Esito atteso:

- alert DG visibile nella dashboard

### Test 5 - Job fail/success

1. crea job SQL con errore intenzionale
2. verifica fallimento e notifica
3. correggi job e riesegui

Esito atteso:

- storico job mostra fail poi success

---

## 6.13 Troubleshooting più comune

### TNS-12541: TNS:no listener (dopo reboot)

Sintomi:

```text
$ lsnrctl status
TNS-12541: TNS:no listener
 TNS-12560: TNS:protocol adapter error
  TNS-00511: No listener
   Linux Error: 111: Connection refused
```

Causa: il listener non è partito al boot (Oracle NON lo avvia automaticamente).

Fix rapido:

```bash
source /home/oracle/.bash_profile
lsnrctl start
sqlplus / as sysdba <<< 'STARTUP;'
sqlplus / as sysdba <<< 'ALTER SYSTEM REGISTER;'
lsnrctl status
```

Fix permanente: configura l'avvio automatico (vedi sezione **6.5.10**).

### ORA-01034: ORACLE not available (database non avviato)

Sintomi:

```text
SQL> SELECT name FROM v$database;
ORA-01034: ORACLE not available
```

Causa: il database non è stato avviato dopo il reboot.

Fix:

```bash
source /home/oracle/.bash_profile
echo $ORACLE_SID    # Deve mostrare EMREP
echo $ORACLE_HOME   # Deve mostrare /home/oracle/app/product/19.3.0/dbhome_1

sqlplus / as sysdba <<< 'STARTUP;'
```

> Se `ORACLE_SID` o `ORACLE_HOME` sono vuoti, le variabili non sono nel `.bash_profile`. Vedi sezione **6.5.5**.

### Agent down

Sintomi:

- host target Down
- last upload timestamp vecchio

Azioni:

```bash
$AGENT_HOME/bin/emctl status agent
$AGENT_HOME/bin/emctl start agent
$AGENT_HOME/bin/emctl upload agent
```

### Upload backlog OMS

Sintomi:

- metriche in ritardo
- pending uploads alto

Azioni:

- verifica risorse OMS (CPU/RAM/disk)
- controlla repository DB load
- riavvio controllato OMS in finestra manutenzione

```bash
$OMS_HOME/bin/emctl status oms -details
$OMS_HOME/bin/emctl stop oms -all
$OMS_HOME/bin/emctl start oms
```

### Target unavailable ma host raggiungibile

Azioni:

- valida credentials target
- forzare rediscovery
- controlla listener/service

### Metric collection error

Azioni:

- review metric extension e collection schedule
- verifica privilegio DB user monitor
- controlla clock drift host/OMS

---

## 6.14 EMCLI — Command Line Interface

`emcli` è il tool da riga di comando per automatizzare EM. Essenziale per DBA che vogliono scriptare le operazioni.

### Setup Iniziale

```bash
# Configura emcli
$OMS_HOME/bin/emcli setup \
  -url=https://<hostname>:7803/em \
  -username=SYSMAN \
  -password=<password> \
  -trustall

# Login (sessione)
$OMS_HOME/bin/emcli login -username=SYSMAN -password=<password>
```

### Comandi Essenziali

```bash
# Lista target
emcli get_targets -targets="oracle_database"
emcli get_targets -targets="host"
emcli get_targets -targets="osm_instance"    # ASM

# Status target specifico
emcli get_targets -targets="RACDB:rac_database" -format="name:csv"

# Lista incidenti aperti
emcli get_open_incidents

# Crea blackout
emcli create_blackout \
  -name="PATCHING_RAC_$(date +%Y%m%d)" \
  -add_targets="RACDB:rac_database" \
  -schedule="duration::02:00" \
  -reason="RU Patching"

# Rimuovi blackout
emcli stop_blackout -name="PATCHING_RAC_20260407"

# Job submission
emcli submit_job \
  -name="RMAN_HEALTH_CHECK" \
  -type="SQLScript" \
  -targets="RACDB:rac_database" \
  -input="sql_script:SELECT status FROM v$instance;"
```

### Script di Health Check via EMCLI

```bash
#!/bin/bash
# /home/oracle/scripts/em_health_check.sh
# Verifica rapida via EMCLI

$OMS_HOME/bin/emcli login -username=SYSMAN -password=$(cat /home/oracle/.em_pwd)

echo "=== TARGET STATUS ==="
$OMS_HOME/bin/emcli get_targets -targets="oracle_database" -format="name:pretty" \
  | grep -E "Status|RACDB"

echo ""
echo "=== INCIDENTI APERTI ==="
$OMS_HOME/bin/emcli get_open_incidents | head -20

echo ""
echo "=== BLACKOUT ATTIVI ==="
$OMS_HOME/bin/emcli get_blackouts -format="name:pretty" | grep "ACTIVE"
```

---

## 6.15 Metric Extensions — Metriche Custom

Le Metric Extensions permettono di creare metriche personalizzate per monitorare ciò che EM non copre di default.

### Esempio 1: Monitorare Tabelle con Troppi Extent

```sql
-- Query per la Metric Extension
SELECT owner, segment_name, extents, bytes/1024/1024 AS mb
FROM dba_segments
WHERE extents > 500
ORDER BY extents DESC;
```

**Setup nella Console EM:**
1. Enterprise → Monitoring → Metric Extensions → Create
2. Target Type: `Database Instance`
3. Collection Type: `SQL`
4. Incolla la query sopra
5. Definisci colonne: Owner, Segment, Extents (metrica), Size_MB (metrica)
6. Alert: Warning se extents > 500, Critical se > 1000
7. Deploy sul target group RAC

### Esempio 2: Monitorare FRA Usage (più granulare)

```sql
SELECT
    name,
    ROUND(space_limit/1024/1024/1024, 1) AS limit_gb,
    ROUND(space_used/1024/1024/1024, 1) AS used_gb,
    ROUND(space_used/space_limit * 100, 1) AS pct_used
FROM v$recovery_file_dest;
```

### Esempio 3: Data Guard Lag Alert Custom

```sql
SELECT
    name AS metric_name,
    TO_NUMBER(REGEXP_SUBSTR(value, '\d+')) AS lag_seconds
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');
```

> **Importante**: Le Metric Extensions devono essere testate su un target singolo prima del deploy massivo. Usa la Console EM per il test prima di gestirle via EMCLI.

---

## 6.16 Hardening minimo consigliato in lab

- password policy forte per SYSMAN e named credentials
- backup periodico repository DB
- snapshot VM pre-change
- audit delle modifiche di soglie/rules/job

---

## 6.17 Checklist di completamento fase 6

- [ ] OMS Up e console accessibile
- [ ] agent deployato su tutti i nodi target
- [ ] RAC + standby visibili e monitorati
- [ ] rule set incidenti attivo
- [ ] notifiche email testate
- [ ] almeno 5 test runbook eseguiti con esito registrato

---

## 6.18 Integrazione con il resto del lab

Dopo questa fase puoi:

- usare EM per seguire switchover/failover in tempo reale
- correlare alert DG con backup RMAN
- schedulare controlli DBA periodici
- avere evidenze operative per review/cv

---

## 6.19 Riferimenti ufficiali Oracle

- Oracle Enterprise Manager Cloud Control Installation Guide:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/
- Oracle Enterprise Manager 24ai Documentation:
  https://docs.oracle.com/en/enterprise-manager/
- Oracle Enterprise Manager Cloud Control Administrator's Guide:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/
- EMCLI Reference:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/
- Oracle Software Delivery Cloud (Download):
  https://edelivery.oracle.com/

---

**← [FASE 5: RMAN Backup](../03_backup_recovery/GUIDA_FASE5_RMAN_BACKUP.md)** | 📍 [Indice Percorso Lab](../00_lab_percorso/README.md) | **→ [FASE 7: GoldenGate](../07_replication/GUIDA_FASE7_GOLDENGATE.md)**
