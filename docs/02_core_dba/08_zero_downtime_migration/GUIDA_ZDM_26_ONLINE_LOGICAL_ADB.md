# 🚀 ZDM 26: Guida Monumentale End-to-End - Migrazione Online Logical verso Autonomous Database (ADB)

Questa guida illustra la complessa ma potente migrazione **Online Logical**, nota anche come migrazione a **Zero Downtime reale**. In questo scenario, le applicazioni continuano a scrivere sul database sorgente (On-Premise o AWS) per tutta la durata del processo, fino al momento esatto del cutover.

ZDM 26 ha modificato profondamente l'integrazione con GoldenGate rispetto alle vecchie versioni (21.x), imponendo nuovi parametri.

---

## 1. Obiettivo e Architettura di Riferimento

L'obiettivo è migrare un database sorgente vivo (es. su AWS EC2 o RDS) verso un **Autonomous Database** su Oracle Cloud Infrastructure (OCI) senza interrompere il servizio.

### L'Architettura a 3 Pilastri
Nella migrazione *Offline*, i dati viaggiano dal Source al Target tramite Object Storage (Data Pump). 
Nella migrazione **Online**, si aggiunge un terzo pilastro fondamentale: il **GoldenGate Hub**.

1. **Source DB (AWS / On-Prem):** Il database di origine che continua a servire traffico.
2. **GoldenGate Hub (Microservices):** Una VM separata (tipicamente su OCI) con installato Oracle GoldenGate Microservices. Questo è il "cervello" della replica.
3. **Target ADB:** L'Autonomous Database su OCI.

**Il Flusso (Network Flows):**
1. **Fase Iniziale (Data Pump):** ZDM orchestra un export Data Pump dal Source verso l'Object Storage e lo importa in ADB.
2. **Cattura (Extract):** Nel frattempo, l'hub GoldenGate si collega al Source e "ascolta" i Redo Log/Archivelog catturando tutte le transazioni (INSERT/UPDATE/DELETE) avvenute da quando è iniziato il Data Pump.
3. **Applicazione (Replicat):** GoldenGate applica in tempo reale queste transazioni sull'Autonomous Database tramite API sicure.

---

## 2. Procedura Operativa: Setup End-to-End

### STEP 0 - 3: Setup Iniziale e Connettività
Tutta la fase preparatoria (Creazione ADB, Setup della VM ZDM, Fix IPv6, Generazione Chiavi OCI e Configurazione `~/.oci/config`) è **identica** alla migrazione Offline.
Fai riferimento alla [Guida ZDM Offline Logical](./GUIDA_ZDM_26_OFFLINE_LOGICAL_ADB.md) per questi passaggi.

### STEP 4: Prerequisiti GoldenGate Hub e Sorgente
L'approccio Online esige requisiti stringenti:
1. **Supplemental Logging sul Source:** Devi abilitarlo a livello di database.
   ```sql
   ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
   ```
2. **Se il Source è AWS RDS:** La retention degli Archivelog deve essere garantita (minimo 24 ore):
   ```sql
   exec rdsadmin.rdsadmin_util.set_configuration('archivelog retention hours',24);
   ```
3. **Il GoldenGate Hub:** Devi avere installato Oracle GoldenGate Microservices Architecture (MA) e configurato due "Deployment" separati (es. `SourceGG` e `TargetGG`). ZDM non installa GoldenGate, lo usa!

### STEP 5: Il File di Risposta ZDM (`.rsp`) per la v26
Qui risiede la novità principale. I vecchi parametri `GGHUB_REST_ENDPOINT` sono morti. Crea il file `/home/zdmuser/zdm_online_logical.rsp` con i **nuovi parametri ZDM 26**:

```ini
# ==========================================
# 1. METODO E TRASPORTO
# ==========================================
MIGRATION_METHOD=ONLINE_LOGICAL  
DATA_TRANSFER_MEDIUM=OSS          

# ==========================================
# 2. CONFIGURAZIONE DATA PUMP
# ==========================================
DATAPUMPSETTINGS_JOBMODE=SCHEMA   
DATAPUMPSETTINGS_SCHEMABATCH-1=ZDM_TEST 
DATAPUMPSETTINGS_DATABUCKET_NAMESPACENAME=<IL_TUO_NAMESPACE>
DATAPUMPSETTINGS_DATABUCKET_BUCKETNAME=bucket-dn          

# ==========================================
# 3. SOURCE E TARGET
# ==========================================
SOURCEDATABASE_CONNECTIONDETAILS_HOST=192.168.56.101      
SOURCEDATABASE_CONNECTIONDETAILS_PORT=1521                
SOURCEDATABASE_CONNECTIONDETAILS_SERVICENAME=sole         
SOURCEDATABASE_ADMINUSERNAME=system                       

TARGETDATABASE_OCID=ocid1.autonomousdatabase.oc1...       
TARGETDATABASE_ADMINUSERNAME=admin                        

# ==========================================
# 4. GOLDENGATE HUB (NOVITÀ ZDM 26)
# ==========================================
# URL REST del Service Manager del GG Hub
GOLDENGATEHUB_URL=https://<IP_GG_HUB>:443
# Username admin di GoldenGate
GOLDENGATEHUB_ADMINUSERNAME=oggadmin
# I nomi esatti dei deployment creati nel GG Hub
GOLDENGATEHUB_SOURCEDEPLOYMENTNAME=SourceGG
GOLDENGATEHUB_TARGETDEPLOYMENTNAME=TargetGG
# (Opzionale ma consigliato per limitare il lag)
GOLDENGATESETTINGS_ACCEPTABLELAG=10

# ==========================================
# 5. CREDENZIALI OCI (API KEYS)
# ==========================================
OCIAUTHENTICATIONDETAILS_SERVICETENANTID=ocid1.tenancy... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_TENANTID=ocid1.tenancy... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_USERID=ocid1.user... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_FINGERPRINT=fc:e0... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_PRIVATEKEYFILE=/home/zdmuser/.oci/oci_api_key.pem 
OCIAUTHENTICATIONDETAILS_REGIONID=eu-milan-1              
```

### STEP 6: Esecuzione del Dry-Run
Essendoci GoldenGate di mezzo, dovrai passare un parametro in più a riga di comando: la password dell'amministratore di GoldenGate (`-ggarg1`).

```bash
/u01/app/zdmhome/bin/zdmcli migrate database \
  -sourcedb sole \
  -sourcenode 192.168.56.101 \
  -srcauth zdmauth \
  -srcarg1 user:oracle \
  -srcarg2 identity_file:/home/zdmuser/.ssh/id_rsa \
  -srcarg3 sudo_location:/usr/bin/sudo \
  -ggarg1 user:oggadmin \
  -rsp /home/zdmuser/zdm_online_logical.rsp \
  -eval
```
Ti verrà richiesta in modo sicuro la password del Source, del Target e dell'utente `oggadmin` di GoldenGate. Se restituisce `SUCCEEDED`, rilancia rimuovendo `-eval`.

### STEP 7: Il Cutover (Switchover)
A differenza dell'Offline (che finisce da solo), un job Online **rimane appeso (PAUSED)**.
Questo perché ZDM tiene attivi i processi di replica finché tu non decidi che è arrivato il momento del "Go-Live".

Quando sei pronto a staccare il vecchio database e passare al cloud, stoppa le applicazioni che scrivono sul sorgente e lancia il resume del job di ZDM per completare il Cutover:
```bash
/u01/app/zdmhome/bin/zdmcli resume job -jobid <ID_DEL_JOB>
```
ZDM applicherà le ultimissime transazioni, spegnerà i processi GoldenGate e terminerà il job.

---

## 3. Validazione Finale: Verifica e Connessione ADB

Durante la fase di replica attiva, prima ancora di lanciare il cutover, puoi connetterti al database Target per verificare che GoldenGate stia effettivamente scrivendo in tempo reale!

Collegati con SQL*Plus usando l'ambiente ZDM e il Wallet:
```bash
export ORACLE_HOME=/u01/app/zdmhome
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export TNS_ADMIN=/home/zdmuser/wallets/adb_target

/u01/app/zdmhome/bin/sqlplus admin/LaTuaPassword@<NOME_TNS_HIGH>
```

Al prompt `SQL>`, verifica:
```sql
-- Controlla quante transazioni al secondo sta applicando il Replicat
SELECT count(*) FROM "ZDM_TEST"."NOME_TABELLA_FREQUENTE";

-- Oppure controlla lo stato delle code tramite le view interne (se accessibili)
SELECT * FROM dba_apply_progress;
```

---

## 4. Troubleshooting: FPP Startup e Sincronia Temporale

Oltre al ben noto errore di avvio IPv6 (da fixare in `/etc/hosts` come nella guida Offline), i problemi in `ONLINE_LOGICAL` derivano quasi tutti dal networking verso l'hub GoldenGate.

- **Connessione Refused verso il GG Hub:** Assicurati che il firewall di OCI (Security Lists) o del nodo permetta il traffico sulla porta 443 e sulle porte specifiche assegnate ai deployment (`SourceGG` e `TargetGG`).
- **ORA-01280 / Archivelog mancanti su AWS RDS:** Se ZDM fallisce durante la fase di *Extract*, significa che RDS ha cancellato i vecchi Archivelog prima che GoldenGate potesse leggerli. Aumenta la retention a 48 ore (`exec rdsadmin.rdsadmin_util.set_configuration...`).

---

## 5. Variante Architetturale: Oracle AI Database@Azure

Una delle architetture cloud più recenti e complesse prevede la migrazione verso **Autonomous Database (ADB-S)** o Exadata in hosting all'interno dei data center Microsoft Azure, tramite il servizio **Oracle AI Database@Azure**.

In questo scenario, la topologia di rete e lo storage cambiano radicalmente. Invece di usare un Object Storage OCI (bucket) per parcheggiare i dump di Data Pump, si sfrutta un **NFS Share** (ad esempio fornito da Azure Files o Azure NetApp), e GoldenGate viene spesso eseguito in un **Container Docker** all'interno di una VM su Azure.

### 5.1 Il trasporto dati via NFS (Azure Files)
ZDM orchestra l'export e l'import tramite file system di rete montato su entrambi i lati (Source e Target).
1. **Lato Source (On-Prem / AWS):** Devi montare la share NFS di Azure a livello di sistema operativo.
   ```bash
   mount -t nfs odaamigration.file.core.windows.net:/odaamigration/testmigration /nfstest -o vers=4,minorversion=1,sec=sys
   ```
   E poi creare una directory logica sul database Oracle: `CREATE DIRECTORY DATA_PUMP_DIR_NFS AS '/nfstest';`

2. **Lato Target (Autonomous su Azure):** Usa i package nativi OCI/Azure per agganciare la share NFS direttamente dentro ADB:
   ```sql
   BEGIN
     DBMS_CLOUD_ADMIN.ATTACH_FILE_SYSTEM(
       file_system_name => 'AZUREFILES',
       file_system_location => 'odaamigration.file.core.windows.net:/odaamigration/testmigration',
       directory_name => 'FSS_DIR',
       description => 'Attach Azure Files',
       params => JSON_OBJECT('nfs_version' value 4)
     );
   END;
   /
   ```

### 5.2 GoldenGate Hub su Docker
Se utilizzi una VM Azure (IaaS) per ospitare l'Hub GoldenGate, il metodo più rapido e supportato è usare l'immagine Docker ufficiale di Oracle.
```bash
sudo docker load < ./ora21c-2113000.tar
sudo docker run --name ogg2113 -p 443:443 docker.io/oracle/goldengate:21.13.0.0.0
```
Affinché ZDM riesca a configurare i flussi, dovrai poi entrare nel container (`docker exec -it ogg2113 /bin/bash`) e copiare al suo interno sia il Wallet dell'Autonomous Database (nella directory `/u02/Deployment/etc/adb`) sia l'Instant Client.

### 5.3 Parametri Esclusivi `.rsp` per Database@Azure
Se non c'è connettività verso gli endpoint REST pubblici di OCI (es. traffico vincolato esclusivamente alla VNet Azure locale), si omettono tutte le chiavi `OCIAUTHENTICATIONDETAILS_*` nel file `.rsp` e si forza un "Local Data Pump" via NFS.

Parametri vitali per questo Use Case:
```ini
DATA_TRANSFER_MEDIUM=NFS
DATAPUMPSETTINGS_EXPORTDIRECTORYOBJECT_NAME=DATA_PUMP_DIR_NFS
DATAPUMPSETTINGS_IMPORTDIRECTORYOBJECT_NAME=FSS_DIR

# Dettagli Target se l'endpoint OCI non è raggiungibile (ZDM 26)
TARGETDATABASE_DBTYPE=ADBCC
TARGETDATABASE_CONNECTIONDETAILS_HOST=example.adb.us-ashburn-1.oraclecloud.com
TARGETDATABASE_CONNECTIONDETAILS_PORT=1522
TARGETDATABASE_CONNECTIONDETAILS_SERVICENAME=adbzdm_high
```
> [!IMPORTANT]
> Quando `TARGETDATABASE_DBTYPE` è settato a `ADBCC`, ZDM sa che si trova in un ambiente blindato (es. Azure o Cloud@Customer) e non cercherà di fare chiamate API Cloud per gestire i file. Si fiderà ciecamente delle share NFS montate (`FSS_DIR`).
