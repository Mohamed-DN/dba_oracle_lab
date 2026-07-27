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

---

## 5. Variante Architetturale: Cross-Cloud (Source Azure ➔ Target OCI)

Nel mondo reale (e nel caso d'uso specifico di questa guida), capita spesso che il database sorgente si trovi su una VM in **Microsoft Azure** (o AWS) e il target sia un Autonomous Database nativo su **OCI**.

Il documento ufficiale Oracle "Oracle AI Database@Azure" descrive un target ospitato su Azure, ma molti concetti e parametri (NFS, Docker) sono preziosissimi anche quando Azure funge solo da "Source".

### 5.1 Trasporto Dati e Storage
Quando si sposta una mole di dati da Azure a OCI, ci sono due approcci per ZDM:
1. **Object Storage (Consigliato per Cross-Cloud):** La VM su Azure (Source) si collega a Internet o via tunnel VPN/FastConnect per caricare i dump sul Bucket OCI. Si usa `DATA_TRANSFER_MEDIUM=OSS` e ZDM gestisce l'upload tramite le chiavi API (`OCIAUTHENTICATIONDETAILS_*`).
2. **NFS Cross-Cloud (Tramite VPN):** Se hai un collegamento di rete diretto (FastConnect/ExpressRoute) tra Azure e OCI, puoi montare una share NFS (es. Azure Files o OCI File Storage) su **entrambi** i mondi. ZDM sposterà i dump senza usare chiamate REST OCI, basandosi solo su mount point locali. 
   - *Parametro ZDM:* `DATA_TRANSFER_MEDIUM=NFS`

### 5.2 GoldenGate Hub su Docker (Lato Azure)
Per abbattere i costi e ottimizzare il traffico di replica, è consigliato far girare il GoldenGate Hub (Microservices) su una VM IaaS direttamente in Azure (vicino alla sorgente). Il metodo più rapido e supportato è l'uso dell'immagine Docker ufficiale di Oracle.
```bash
sudo docker load < ./ora21c-2113000.tar
sudo docker run --name ogg2113 -p 443:443 docker.io/oracle/goldengate:21.13.0.0.0
```
Affinché ZDM e GoldenGate comunichino con l'Autonomous Database in OCI, dovrai entrare nel container Azure (`docker exec -it ogg2113 /bin/bash`) e copiare al suo interno sia il Wallet (`/u02/Deployment/etc/adb`) sia l'Instant Client.

### 5.3 Il parametro ADBCC (Per Ambienti Disconnessi)
Nel documento tecnico Oracle appare il parametro `TARGETDATABASE_DBTYPE=ADBCC`. 
> [!IMPORTANT]
> Usa `ADBCC` **solo** se il tuo Autonomous Database è di tipo Cloud@Customer (on-prem) o ospitato su Azure (Oracle Database@Azure), ovvero in contesti "disconnessi" in cui la VM ZDM non ha accesso a Internet per interrogare le API REST pubbliche del cloud OCI per orchestrare lo storage.
> Se il tuo target è un Autonomous Database nativo su OCI (raggiungibile via Internet o NAT Gateway), **NON USARE** `ADBCC`, ma usa i classici parametri `TARGETDATABASE_OCID` e `OCIAUTHENTICATIONDETAILS_*`.
