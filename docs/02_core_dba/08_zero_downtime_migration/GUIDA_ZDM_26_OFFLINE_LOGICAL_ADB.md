# ðŸš€ ZDM 26: Guida - Migrazione Offline Logical verso Autonomous Database (ADB)

Questa guida raccoglie tutto il sudore, gli errori e le scoperte fatte sul campo (reverse engineering) per far funzionare **Oracle Zero Downtime Migration versione 26** in una migrazione *Offline Logical* verso un Autonomous Database.

ZDM 26 ha introdotto cambiamenti drastici, rimozioni di vecchi parametri e controlli molto piÃ¹ stringenti rispetto alle versioni precedenti (21.x).

---

## 1. Obiettivo e Analisi del Comando `zdmcli` (Riga per Riga)

Il comando di lancio del job Ã¨ il cuore dell'infrastruttura ZDM. Ecco cosa fa ogni singola riga:

```bash
/u01/app/zdmhome/bin/zdmcli migrate database \
  -sourcedb sole \                                     # 1
  -sourcenode 192.168.56.101 \                         # 2
  -srcauth zdmauth \                                   # 3
  -srcarg1 user:oracle \                               # 4
  -srcarg2 identity_file:/home/zdmuser/.ssh/id_rsa \   # 5
  -srcarg3 sudo_location:/usr/bin/sudo \               # 6
  -rsp /home/zdmuser/zdm_migrazione_rac1.rsp \         # 7
  -eval                                                # 8
```

1. **`-sourcedb sole`**: Ãˆ il `db_unique_name` del database sorgente. ZDM lo usa per creare la cartella dei log (`zdm_sole_jobid`).
2. **`-sourcenode 192.168.56.101`**: L'indirizzo IP (o hostname risolvibile) del server sorgente.
3. **`-srcauth zdmauth`**: Indica a ZDM quale plugin usare per autenticarsi sulla macchina sorgente. `zdmauth` Ã¨ il plugin standard basato su SSH.
4. **`-srcarg1 user:oracle`**: L'utente di sistema operativo sulla macchina sorgente con cui ZDM effettuerÃ  la login SSH.
5. **`-srcarg2 identity_file:...`**: Il percorso della chiave privata SSH sul nodo ZDM. 
   > **ERRORE COMUNE (Fallimento in 0 secondi - null):** La chiave **DEVE essere in formato PEM**. I sistemi moderni generano chiavi OpenSSH che fanno crashare il parser Java di ZDM prima ancora che scriva i log.
   > *Fix:* Convertire con `ssh-keygen -p -m PEM -f ~/.ssh/id_rsa`.
6. **`-srcarg3 sudo_location:/usr/bin/sudo`**: Il percorso dell'eseguibile `sudo` sulla macchina sorgente. ZDM lo usa per eseguire comandi privilegiati.
   > **ERRORE COMUNE (Timeout/PRCZ-4001):** L'utente SSH (`oracle`) DEVE essere nel file `/etc/sudoers` con il permesso `NOPASSWD: ALL`. Se sudo chiede la password, ZDM va in timeout e fallisce (spesso alla fase `ZDM_VALIDATE_SRC`). Ometterlo scatena un `invalid argument`.
7. **`-rsp /path/file.rsp`**: Il file di risposta (spiegato sotto).
8. **`-eval`**: Flag per la modalitÃ  "Dry-Run". ZDM esegue tutti i controlli di connessione, spazio, privilegi e limiti senza alterare i dati o avviare l'export reale. Ãˆ fondamentale prima della migrazione vera (che si avvia lanciando lo stesso comando senza `-eval`).

---

## 2. Procedura Operativa: Il File di Risposta (`.rsp`) (Riga per Riga)

ZDM 26 esige un file molto pulito. Vecchi parametri (come `HOSTCONNECTIONDETAILS` o il `WALLETDIRECTORY`) fanno fallire immediatamente il parser.

```ini
# ==========================================
# 1. METODO E TRASPORTO
# ==========================================
MIGRATION_METHOD=OFFLINE_LOGICAL  
# Indica una migrazione tramite Oracle Data Pump (Logical) e che prevede un downtime (Offline).

DATA_TRANSFER_MEDIUM=OSS          
# Indica che i file di dump verranno caricati su un Bucket Cloud (Oracle Object Storage).

# ==========================================
# 2. CONFIGURAZIONE DATA PUMP E SCHEMI
# ==========================================
DATAPUMPSETTINGS_JOBMODE=SCHEMA   
# Migriamo solo schemi specifici, non l'intero database (FULL).

DATAPUMPSETTINGS_SCHEMABATCH-1=ZDM_TEST 
# Il nome dello schema da migrare. 
# âš ï¸ IN ZDM 26: NON si usa piÃ¹ METADATAFILTERS con le sintassi complesse (IN('SCHEMA')). Si usa SCHEMABATCH e basta, altrimenti il parser Java crasha con PRCG-1036.

DATAPUMPSETTINGS_DATAPUMPPARAMETERS_EXPORTPARALLELISMDEGREE=2 
DATAPUMPSETTINGS_DATAPUMPPARAMETERS_IMPORTPARALLELISMDEGREE=2 
# Velocizzano Export/Import dividendo il carico su 2 thread. Da aumentare su server potenti.

DATAPUMPSETTINGS_EXPORTDIRECTORYOBJECT_NAME=DATA_PUMP_DIR 
DATAPUMPSETTINGS_IMPORTDIRECTORYOBJECT_NAME=DATA_PUMP_DIR 
# Le cartelle fisiche mappate a livello di database. ZDM salverÃ  i dump in DATA_PUMP_DIR sul source e li sposterÃ  sul target.

DATAPUMPSETTINGS_DATABUCKET_NAMESPACENAME=ax6qpq21dvct    
# âš ï¸ NOVITÃ€ ZDM 26 (OBBLIGATORIO): Senza questo parametro, la costruzione dell'URL Cloud va in NullPointerException e il job fallisce in 0 secondi. (Lo trovi nei dettagli del Bucket OCI).

DATAPUMPSETTINGS_DATABUCKET_BUCKETNAME=bucket-dn          
# Il nome del tuo bucket su OCI.

# ==========================================
# 3. DATABASE SORGENTE (SOURCE)
# ==========================================
SOURCEDATABASE_CONNECTIONDETAILS_HOST=192.168.56.101      
SOURCEDATABASE_CONNECTIONDETAILS_PORT=1521                
SOURCEDATABASE_CONNECTIONDETAILS_SERVICENAME=sole         
SOURCEDATABASE_ADMINUSERNAME=system                       
# Le classiche credenziali JDBC. 
# âš ï¸ ATTENZIONE (ORA-28009): Ãˆ una best practice usare `system` e non `sys`. Usando `sys` in una JDBC connection normale, Oracle rifiuta la connessione chiedendo `AS SYSDBA`. ZDM usa JDBC nudo e crudo, quindi `system` Ã¨ perfetto per aggirare l'errore (avendo giÃ  tutti i privilegi Datapump).

# ==========================================
# 4. DATABASE DESTINAZIONE (TARGET ADB)
# ==========================================
TARGETDATABASE_OCID=ocid1.autonomousdatabase.oc1...       
# âš ï¸ NOVITÃ€ ZDM 26 (OBBLIGATORIO): Non ci sono piÃ¹ HOST o WALLET da specificare. Inserendo l'OCID, ZDM capisce che stai andando verso un Autonomous DB gestito e smette di chiederti il flag `-targetnode` (PRCG-1030).

TARGETDATABASE_ADMINUSERNAME=admin                        
# L'amministratore supremo su Autonomous Database (sempre admin).

# ==========================================
# 5. CREDENZIALI OCI (API KEYS)
# ==========================================
OCIAUTHENTICATIONDETAILS_SERVICETENANTID=ocid1.tenancy... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_TENANTID=ocid1.tenancy... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_USERID=ocid1.user... 
# I tuoi OCID cloud (Tenancy, Tenancy ripetuta, User). 
# âš ï¸ IN ZDM 26: I parametri TENANCYID sono stati rinominati rispetto alla v21 (il parser rifiuterÃ  la vecchia sintassi).

OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_FINGERPRINT=fc:e0... 
# Impronta digitale (MD5) della tua chiave API pubblica caricata su OCI.

OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_PRIVATEKEYFILE=/home/zdmuser/.oci/oci_api_key.pem 
# La tua chiave privata locale associata alla chiave API Cloud.

OCIAUTHENTICATIONDETAILS_REGIONID=eu-milan-1              
# La region (es. Francoforte, Milano). In ZDM 26 il parametro REGION Ã¨ diventato REGIONID.
```

---

## 3. Validazione Finale: Connessione all'Autonomous Database (Post-Migrazione)
Una volta concluso il Job ZDM, per verificare la presenza dei dati sull'Autonomous Database da riga di comando (es. usando `sqlplus` dal nodo ZDM), Ã¨ necessario usare il Wallet ufficiale. 

PoichÃ© ZDM 26 gestisce e poi cancella il proprio wallet temporaneo in autonomia durante il job, dovrai procurartelo manualmente:

1. **Scaricare il Wallet da OCI:**
   - Dalla Web Console di OCI, vai sul tuo Autonomous Database -> **Database Connection**.
   - Scarica l'**Instance Wallet** in formato `.zip` impostando una password temporanea.

2. **Caricare e Scompattare il Wallet sul nodo:**
   - Porta il file `.zip` sul nodo Linux e scompattalo (ad esempio nella cartella `/home/zdmuser/wallets/adb_target`).

3. **Esportare le Variabili ed Entrare:**
   - Prima di lanciare `sqlplus`, il client Oracle deve sapere dove si trovano le librerie, l'eseguibile e il file `tnsnames.ora`.
   - Lancia in sequenza questo blocco di comandi:
   
   ```bash
   # 1. Esporta le librerie dinamiche di SQL*Plus incluse in ZDM
   export LD_LIBRARY_PATH=/u01/app/zdmhome/lib:$LD_LIBRARY_PATH
   
   # 2. Punta alla cartella esatta dove hai scompattato il wallet
   export TNS_ADMIN=/home/zdmuser/wallets/adb_target
   
   # 3. Imposta la Oracle Home puntando alla base di ZDM
   export ORACLE_HOME=/u01/app/zdmhome
   
   # 4. Lancia la connessione usando l'alias TNS corretto (es. miodb_high)
   /u01/app/zdmhome/bin/sqlplus admin/LaTuaPassword@jwp9xbanryu8cmik_high
   ```
   
   > [!TIP]
   > Se ricevi l'errore `libsqlplus.so: cannot open shared object file`, significa che hai saltato l'export di `LD_LIBRARY_PATH`. Se ti dice `ORA-12154`, significa che `TNS_ADMIN` sta puntando a una cartella vuota o che l'alias TNS che hai scritto non esiste nel file `tnsnames.ora`.

---

## 4. Troubleshooting: Sincronia Temporale
Se ZDM riesce a fare discovery ma **fallisce con errore HTTP 401 NotAuthenticated** sul Cloud, il problema non sono gli OCID, ma la **sincronizzazione dell'orologio della macchina ZDM**. 

Oracle Cloud rifiuta le firme API (Authorization Header) se l'orologio locale differisce da quello reale. 
*Fix:* Sincronizzare il nodo con `sudo chronyc -a makestep` o NTP.

---
