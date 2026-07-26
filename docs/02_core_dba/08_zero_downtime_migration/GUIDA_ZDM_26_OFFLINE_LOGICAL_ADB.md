# 🚀 ZDM 26: Guida Monumentale End-to-End - Migrazione Offline Logical verso Autonomous Database (ADB)

Questa guida raccoglie tutto il sudore, gli errori e le scoperte fatte sul campo (reverse engineering) per far funzionare Oracle Zero Downtime Migration versione 26 in una migrazione **Offline Logical** verso un **Autonomous Database**.

ZDM 26 ha introdotto cambiamenti drastici, rimozioni di vecchi parametri e controlli molto più stringenti rispetto alle versioni precedenti (21.x). Partiremo da zero: dall'installazione della VM, fino al completamento del job in cloud.

---

## 1. Obiettivo e Architettura di Riferimento

L'obiettivo è migrare un database RAC locale (simulato su VirtualBox) verso Oracle Cloud Infrastructure (OCI) Autonomous Database, esplorando l'approccio Logico.

### Physical vs Logical Migration

Poiché il nostro target è un **Autonomous Database (ADB)**, siamo **obbligati** a testare la **Migrazione Logica**. Su ADB non hai accesso `SYSDBA` a livello di sistema operativo per ripristinare i blocchi, quindi l'approccio Fisico (RMAN) non è supportato.

| Caratteristica | Migrazione Fisica (Physical) | Migrazione Logica (Logical) |
| :--- | :--- | :--- |
| **Tecnologia Sottostante** | RMAN Active Duplicate / Data Guard | Data Pump + Oracle GoldenGate |
| **Target Supportati su OCI** | VM DB Systems, Bare Metal, ExaCS | **Autonomous Database (ADB)**, VM, Bare Metal, ExaCS |
| **Cosa sposta?** | Interi blocchi fisici del disco | Dati logici (INSERT, UPDATE, DELETE) |
| **Vantaggio Principale** | Veloce per DB enormi, clone perfetto | Permette cambi di architettura, upgrade e ADB |

### Architettura del Lab e Flussi di Rete (Network Flows)

Per questo lab useremo:
1. **RAC Sorgente:** `rac1` e `rac2` (On-Premise / VirtualBox).
2. **Nodo ZDM (NUOVO):** Una VM dedicata `zdmnode`.
3. **Target:** Autonomous Database Free su OCI.
4. **Object Storage:** Bucket OCI (Ponte per il Data Pump).

**I "Flussi" della Migrazione Logica (Offline):**
1. **Control Flow (SSH):** `zdmnode` entra in SSH sui nodi sorgente (`rac1`/`rac2`) per configurare i job di Data Pump.
2. **Data Flow (Data Pump):** Il database sorgente estrae i dati e li spinge direttamente sull'Object Storage OCI tramite HTTPS (porta 443). *Nota: I dati non passano attraverso la VM ZDM, ZDM dà solo gli ordini!*
3. **Import Flow:** Autonomous Database legge i dati dall'Object Storage e li importa internamente tramite `DBMS_CLOUD`.

---

## 2. Procedura Operativa: Setup End-to-End

### STEP 0: Creazione Autonomous Database (Target) su OCI
1. Nella console OCI, vai su **Oracle Database -> Autonomous Data Warehouse** (o Transaction Processing).
2. Clicca su **Create Autonomous Database**.
3. **Nome:** Inserisci un nome (es. `ZDMTargetDB`).
4. **Workload Type:** Scegli *Transaction Processing*.
5. **Deployment Type:** *Shared Infrastructure*.
6. **Always Free:** ATTIVA la spunta **Always Free**.
7. **Credenziali:** Imposta una password forte per l'utente `ADMIN` (segnatela).
8. **Network:** Seleziona *Secure access from everywhere*.
9. Clicca su **Create**.

### STEP 1: Creazione e Setup del Nodo ZDM (Installazione da Zero)
1. Crea una VM `zdmnode` (2 CPU, 10-12GB RAM, Oracle Linux 7/8).
2. **Installazione Prerequisiti OS:**
   ZDM necessita di pacchetti specifici e dell'utente dedicato. Accedi come `root`:
   ```bash
   yum install -y oracle-database-preinstall-19c glibc-devel unzip expect wget
   # Creazione utente zdmuser
   useradd -g oinstall -G dba zdmuser
   echo "zdmuser" | passwd --stdin zdmuser
   
   # Creazione delle cartelle per ZDM
   mkdir -p /u01/app/zdmbase
   mkdir -p /u01/app/zdmhome
   chown -R zdmuser:oinstall /u01/
   chmod -R 775 /u01/
   ```
3. **Installazione del Software ZDM 26:**
   Scarica lo zip di ZDM dal sito Oracle, portalo sul nodo (es. `/tmp`) e avvia l'installer:
   ```bash
   su - zdmuser
   cd /tmp
   unzip V1044434-01.zip -d /tmp/zdm_installer
   
   /tmp/zdm_installer/zdminstall.sh setup oraclehome=/u01/app/zdmhome oraclebase=/u01/app/zdmbase ziploc=/tmp/zdm_installer/zdm26.zip -zdm
   ```

> [!WARNING]
> **Risoluzione Problemi Avvio ZDM (FPP startup failed)**
> L'avvio di ZDM fallisce se il nome host risolve in IPv6 (`fe80::`) o `127.0.0.1`.
> **Fix:** Modificare `/etc/hosts` e disabilitare IPv6 per forzare un binding pulito su IPv4.
> ```bash
> # Da root
> sed -i '/zdmnode/d' /etc/hosts
> echo "192.168.56.55    zdmnode.localdomain    zdmnode" >> /etc/hosts
> sysctl -w net.ipv6.conf.all.disable_ipv6=1
> 
> # Ora puoi avviare il servizio:
> su - zdmuser
> /u01/app/zdmhome/bin/zdmservice start
> /u01/app/zdmhome/bin/zdmservice status
> ```

### STEP 2: Connettività OCI e API Keys
Mettiamo in comunicazione il nodo ZDM con il Cloud.

**Sulla Web Console OCI:**
1. **Bucket:** Crea un bucket *Private* in Object Storage (es. `bucket-dn`).
2. **Genera l'API Key:** Dal tuo profilo (User Settings -> API Keys), aggiungi una chiave e scarica la chiave privata (`.pem`). Copia il blocco di configurazione mostrato.
3. **Scarica il Wallet ADB:** Da *Database Connection*, scarica l'Instance Wallet `.zip` impostando una password temporanea.

**Sul Nodo Linux (`zdmnode`):**
1. Crea la cartella e carica la chiave privata:
   ```bash
   mkdir -p ~/.oci
   # Metti il file .pem qui dentro, es. oci_api_key.pem
   chmod 600 ~/.oci/oci_api_key.pem
   ```
2. Crea il file `~/.oci/config` e incolla il testo di configurazione. Aggiorna la riga della chiave:
   ```ini
   key_file=/home/zdmuser/.oci/oci_api_key.pem
   ```
3. Genera la chiave SSH per ZDM e copiala sul RAC sorgente:
   ```bash
   ssh-keygen -t rsa -N "" -m PEM -f ~/.ssh/id_rsa
   ssh-copy-id oracle@192.168.56.101
   ```
   > [!IMPORTANT]
   > ZDM 26 esige chiavi SSH in formato **PEM**, altrimenti il parser Java va in crash (fallimento in 0 secondi). Convertila se necessario con `ssh-keygen -p -m PEM -f ~/.ssh/id_rsa`. 
   > Inoltre, l'utente oracle sul RAC sorgente deve essere in `/etc/sudoers` con `NOPASSWD: ALL`.

### STEP 3: Preparazione del File di Risposta (`.rsp`)
ZDM non ha GUI, si comanda da un file `.rsp`. ZDM 26 esige un file molto pulito e senza parametri vecchi (es. `WALLETDIRECTORY`).

Crea il file `/home/zdmuser/zdm_migrazione_rac1.rsp`:
```ini
# ==========================================
# 1. METODO E TRASPORTO
# ==========================================
MIGRATION_METHOD=OFFLINE_LOGICAL  
DATA_TRANSFER_MEDIUM=OSS          

# ==========================================
# 2. CONFIGURAZIONE DATA PUMP E SCHEMI
# ==========================================
DATAPUMPSETTINGS_JOBMODE=SCHEMA   
# ⚠️ IN ZDM 26: Si usa SCHEMABATCH e basta. METADATAFILTERS crasha con PRCG-1036.
DATAPUMPSETTINGS_SCHEMABATCH-1=ZDM_TEST 

DATAPUMPSETTINGS_DATAPUMPPARAMETERS_EXPORTPARALLELISMDEGREE=2 
DATAPUMPSETTINGS_DATAPUMPPARAMETERS_IMPORTPARALLELISMDEGREE=2 
DATAPUMPSETTINGS_EXPORTDIRECTORYOBJECT_NAME=DATA_PUMP_DIR 
DATAPUMPSETTINGS_IMPORTDIRECTORYOBJECT_NAME=DATA_PUMP_DIR 

# ⚠️ NOVITÀ ZDM 26 (OBBLIGATORIO): Senza NAMESPACENAME, il job fallisce in 0 secondi (NullPointerException).
DATAPUMPSETTINGS_DATABUCKET_NAMESPACENAME=<IL_TUO_NAMESPACE>    
DATAPUMPSETTINGS_DATABUCKET_BUCKETNAME=bucket-dn          

# ==========================================
# 3. DATABASE SORGENTE (SOURCE)
# ==========================================
SOURCEDATABASE_CONNECTIONDETAILS_HOST=192.168.56.101      
SOURCEDATABASE_CONNECTIONDETAILS_PORT=1521                
SOURCEDATABASE_CONNECTIONDETAILS_SERVICENAME=sole         
SOURCEDATABASE_ADMINUSERNAME=system                       
# ⚠️ ATTENZIONE: Usare system, non sys. ZDM usa JDBC puro e sys causerebbe ORA-28009 (richiede AS SYSDBA).

# ==========================================
# 4. DATABASE DESTINAZIONE (TARGET ADB)
# ==========================================
# ⚠️ NOVITÀ ZDM 26 (OBBLIGATORIO): Basta l'OCID, ZDM non chiede più né HOST né WALLET (-targetnode non serve più).
TARGETDATABASE_OCID=ocid1.autonomousdatabase.oc1...       
TARGETDATABASE_ADMINUSERNAME=admin                        

# ==========================================
# 5. CREDENZIALI OCI (API KEYS)
# ==========================================
# ⚠️ IN ZDM 26: I parametri TENANCYID sono stati rinominati.
OCIAUTHENTICATIONDETAILS_SERVICETENANTID=ocid1.tenancy... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_TENANTID=ocid1.tenancy... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_USERID=ocid1.user... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_FINGERPRINT=fc:e0... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_PRIVATEKEYFILE=/home/zdmuser/.oci/oci_api_key.pem 
OCIAUTHENTICATIONDETAILS_REGIONID=eu-milan-1              
```

### STEP 4: Analisi del Comando `zdmcli` ed Esecuzione
Lanceremo prima un **Dry-Run** (`-eval`), per far simulare tutto a ZDM senza toccare byte.

```bash
/u01/app/zdmhome/bin/zdmcli migrate database \
  -sourcedb sole \
  -sourcenode 192.168.56.101 \
  -srcauth zdmauth \
  -srcarg1 user:oracle \
  -srcarg2 identity_file:/home/zdmuser/.ssh/id_rsa \
  -srcarg3 sudo_location:/usr/bin/sudo \
  -rsp /home/zdmuser/zdm_migrazione_rac1.rsp \
  -eval
```
Se il risultato è `SUCCEEDED`, rilancia lo stesso comando senza il flag `-eval` per scatenare la vera migrazione!

---

## 3. Validazione Finale: Verifica e Connessione ADB

Una volta concluso il Job ZDM, per verificare la presenza dei dati sull'Autonomous Database dal nodo Linux, è necessario usare il Wallet ufficiale. ZDM 26 gestisce e poi cancella il proprio wallet temporaneo in autonomia.

1. **Caricare il Wallet sul nodo ZDM:**
   Porta il file `.zip` (scaricato allo step 2) sul nodo e scompattalo:
   ```bash
   mkdir -p ~/wallets/adb_target
   unzip Wallet_*.zip -d ~/wallets/adb_target
   ```

2. **Esportare le Variabili ed Entrare:**
   ZDM ha un suo client SQL*Plus nascosto. Configura l'ambiente e collegati usando l'alias TNS corretto (es. il suffisso `_high` in `tnsnames.ora`):
   
   ```bash
   export ORACLE_HOME=/u01/app/zdmhome
   export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
   export TNS_ADMIN=/home/zdmuser/wallets/adb_target
   
   /u01/app/zdmhome/bin/sqlplus admin/LaTuaPassword@<NOME_TNS_HIGH>
   ```
   
   > [!TIP]
   > Se ricevi l'errore `libsqlplus.so: cannot open shared object file`, hai saltato l'export di `LD_LIBRARY_PATH`. Se ti dice `ORA-12154`, `TNS_ADMIN` punta a una cartella vuota o l'alias TNS è sbagliato.

3. **Verifica dello Schema e dei Dati:**
   Una volta connesso al prompt `SQL>`, lancia queste query per confermare che ZDM abbia fatto il suo dovere:
   
   ```sql
   -- Controlla se lo schema è arrivato sano e salvo
   SELECT username, created FROM dba_users WHERE username = 'ZDM_TEST';
   
   -- Verifica quali tabelle sono state importate e il numero di righe stimate
   SELECT table_name, num_rows FROM dba_tables WHERE owner = 'ZDM_TEST';
   
   -- Controlla se ci sono oggetti rimasti invalidi post-import
   SELECT object_name, object_type, status FROM dba_objects 
   WHERE owner = 'ZDM_TEST' AND status = 'INVALID';
   ```

---

## 4. Troubleshooting: FPP Startup e Sincronia Temporale

Oltre ai problemi SSH (`sudo NOPASSWD` e chiavi non PEM) o `ORA-28009` già trattati sopra, ecco un errore classico e insidioso in fase di startup/run:

### Errore Sincronizzazione Temporale (HTTP 401 NotAuthenticated)
Se ZDM riesce a fare discovery ma **fallisce con errore HTTP 401 NotAuthenticated** sul Cloud, il problema quasi sicuramente non sono gli OCID errati, ma la **sincronizzazione dell'orologio della macchina ZDM**. 

Oracle Cloud rifiuta rigidamente le firme API (Authorization Header) se l'orologio locale differisce anche di poco da quello reale mondiale. 
*Fix:* Sincronizzare il nodo con:
```bash
sudo chronyc -a makestep
```
Oppure assicurarsi che il demone NTP (`chronyd`) sia in esecuzione e sincronizzato.
