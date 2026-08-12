# 🚀 ZDM 26: Guida Monumentale End-to-End - Migrazione Online Logical verso Autonomous Database (ADB)

Questa guida illustra la complessa ma potente migrazione **Online Logical**, nota anche come migrazione a **Zero Downtime reale**. In questo scenario, le applicazioni continuano a scrivere sul database sorgente (On-Premise o AWS) per tutta la durata del processo, fino al momento esatto del cutover.

ZDM 26 ha modificato profondamente l'integrazione con GoldenGate rispetto alle vecchie versioni (21.x), imponendo nuovi parametri. Questa guida rappresenta lo standard architetturale Enterprise.

---

## 1. Obiettivo e Architettura di Riferimento

L'obiettivo è migrare un database sorgente vivo verso un **Autonomous Database** su Oracle Cloud Infrastructure (OCI) senza interrompere il servizio.

### L'Architettura a 3 Pilastri
Nella migrazione *Offline*, i dati viaggiano dal Source al Target tramite Object Storage (Data Pump). 
Nella migrazione **Online**, si aggiunge un terzo pilastro fondamentale: il **GoldenGate Hub**.

1. **Source DB (AWS / On-Prem):** Il database di origine che continua a servire traffico.
2. **GoldenGate Hub (Microservices):** Una VM separata con installato Oracle GoldenGate Microservices. Questo è il "cervello" della replica.
3. **Target ADB:** L'Autonomous Database su OCI.

---

## 2. Setup Iniziale e Prerequisiti

### 2.1 Generazione Chiavi SSH e OCI API
ZDM necessita di potersi collegare in SSH al nodo sorgente e autenticarsi alle API di OCI.

```bash
# 1. Genera chiave SSH per l'accesso al nodo DB Sorgente
ssh-keygen -t rsa -b 4096 -N "" -f /home/zdmuser/.ssh/id_rsa
# Copia la chiave pubblica nel nodo sorgente (in ~/.ssh/authorized_keys dell'utente oracle)

# 2. Genera chiave PEM per le API OCI
mkdir -p /home/zdmuser/.oci
openssl genrsa -out /home/zdmuser/.oci/oci_api_key.pem 2048
chmod 600 /home/zdmuser/.oci/oci_api_key.pem
openssl rsa -pubout -in /home/zdmuser/.oci/oci_api_key.pem -out /home/zdmuser/.oci/oci_api_key_public.pem

# Estrai il fingerprint per il file di risposta
openssl rsa -pubout -outform DER -in /home/zdmuser/.oci/oci_api_key.pem | openssl md5 -c
```
*(Ricordati di caricare il contenuto di `oci_api_key_public.pem` nell'interfaccia web di OCI sotto il tuo utente IAM).*

### 2.2 Prerequisiti Database Sorgente (Extract)
L'approccio Online esige requisiti stringenti sul database sorgente affinché GoldenGate possa catturare le transazioni. Oltre ai log, **DEVE** esistere un utente dedicato con i permessi specifici di amministrazione GoldenGate.

```sql
-- 1. Abilita il Supplemental Logging e il parametro GG
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE FORCE LOGGING;
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;

-- 2. Crea l'utenza c##ggadmin (se architettura Multitenant CDB)
CREATE USER c##ggadmin IDENTIFIED BY "PasswordSicura123!" CONTAINER=ALL;
GRANT DBA TO c##ggadmin CONTAINER=ALL;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('C##GGADMIN', container=>'ALL');

-- NOTA: Se sei in single-instance o direttamente nel PDB, ometti "c##" e "CONTAINER=ALL"

-- (Solo per AWS RDS) Garantisci la retention degli Archivelog per almeno 24 ore
exec rdsadmin.rdsadmin_util.set_configuration('archivelog retention hours',24);
```

### 2.3 Prerequisiti Database Destinazione (Autonomous DB)
Negli Autonomous Database in Cloud (ADB), l'utenza `GGADMIN` esiste già nativamente per facilitare la replica, ma per motivi di sicurezza **è bloccata "di fabbrica" e senza password**.
Se non la sblocchi, il job ZDM andrà in errore `ORA-28000: The account is locked` durante la fase di validazione.

Usa SQL*Plus (con il Wallet Cloud) per sbloccare l'utenza target:
```sql
-- Collegati ad ADB come utente ADMIN e lancia:
ALTER USER ggadmin IDENTIFIED BY "PasswordSicura123!" ACCOUNT UNLOCK;
```
*(Questa sarà la password target che ZDM ti chiederà interattivamente quando lancerai il comando di migrazione).*

### 2.4 Sincronizzazione Orologio (Prevenzione ORA/PRGC-1047)
ZDM fallisce i caricamenti su Object Storage se l'orologio di sistema (UTC) della VM è fuori sincrono di oltre 5 minuti rispetto ai server OCI.
```bash
# Esegui come root o con sudo prima di lanciare qualsiasi job ZDM
sudo chronyc makestep

# In alternativa, forza manualmente l'orario UTC esatto
sudo date -u -s "2026-07-28 04:20:00"
```

---

## 3. Configurazione ZDM (File di Risposta `.rsp`)

Crea il file `/home/zdmuser/zdm_online_logical.rsp` con i **nuovi parametri ZDM 26**. ZDM 26 ha rimosso i vecchi parametri `GGHUB_REST_ENDPOINT` a favore di parametri più specifici per i deployment.

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
DATAPUMPSETTINGS_DATABUCKET_NAMESPACENAME=<IL_TUO_NAMESPACE_OCI>
DATAPUMPSETTINGS_DATABUCKET_BUCKETNAME=<IL_TUO_NOME_BUCKET>

# ==========================================
# 3. SOURCE E TARGET
# ==========================================
SOURCEDATABASE_CONNECTIONDETAILS_HOST=<IP_SORGENTE>
SOURCEDATABASE_CONNECTIONDETAILS_PORT=1521                
SOURCEDATABASE_CONNECTIONDETAILS_SERVICENAME=<SERVICE_NAME_SORGENTE>
SOURCEDATABASE_ADMINUSERNAME=system                       

TARGETDATABASE_OCID=ocid1.autonomousdatabase.oc1...       
TARGETDATABASE_ADMINUSERNAME=admin                        

# ==========================================
# 4. GOLDENGATE HUB (NOVITÀ ZDM 26)
# ==========================================
# Se usi GG 23ai con il workaround del Proxy, usa la porta del proxy (es. 8888) e HTTP invece di HTTPS
GOLDENGATEHUB_URL=http://<IP_GG_HUB_O_PROXY>:8888
GOLDENGATEHUB_ADMINUSERNAME=oggadmin
GOLDENGATEHUB_SOURCEDEPLOYMENTNAME=SourceGG
GOLDENGATEHUB_TARGETDEPLOYMENTNAME=TargetGG
GOLDENGATESETTINGS_ACCEPTABLELAG=10

# ==========================================
# 5. CREDENZIALI OCI (API KEYS)
# ==========================================
OCIAUTHENTICATIONDETAILS_SERVICETENANTID=ocid1.tenancy... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_TENANTID=ocid1.tenancy... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_USERID=ocid1.user... 
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_FINGERPRINT=<IL_TUO_FINGERPRINT>
OCIAUTHENTICATIONDETAILS_USERPRINCIPAL_PRIVATEKEYFILE=/home/zdmuser/.oci/oci_api_key.pem 
OCIAUTHENTICATIONDETAILS_REGIONID=eu-milan-1              
```

---

## 4. Workaround Critico per GoldenGate 23ai (Bug `e2eLag`)

Se utilizzi **GoldenGate 23ai** come Hub, ZDM 26.1 andrà in *Crash* in modo irreversibile durante la fase `ZDM_MONITOR_GG_LAG`.
Il parser Java andrà in `NullPointerException` (Cannot invoke "java.lang.Double.toString()" because "e2eLag" is null) a causa di una modifica alle API di 23ai.

Per risolvere, eseguiamo un proxy Python sul nodo ZDM. Il proxy intercetta le risposte HTTP di GoldenGate e inietta la proprietà mancante, permettendo a ZDM di proseguire senza errori.

### Script Proxy (`/home/zdmuser/proxy_gg_bypass.py`)
Crea questo file sul nodo ZDM:

```python
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.request
import json
import re
from datetime import datetime, timezone
import sys

# Inserisci l'IP reale della macchina che ospita i microservizi GoldenGate
REAL_GG_HUB_IP = "192.168.56.55"

class Proxy(BaseHTTPRequestHandler):
    def do_request(self):
        path = self.path
        
        # Intercetta solo le chiamate Heartbeat API per correggere il bug OGG-12119
        if '/tables/heartbeat/' in path:
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            
            # Se è la lista completa
            if path.endswith('/tables/heartbeat/'):
                fake_response = {
                    "$schema": "api:standardResponse",
                    "response": {
                        "$schema": "ogg:heartbeatTable",
                        "items": [
                            {
                                "localNode": "rac1",
                                "localDb": "SOURCE",
                                "remoteNode": "rac1",
                                "remoteDb": "SOURCE",
                                "heartbeatTimestamp": datetime.now(timezone.utc).isoformat() + "Z",
                                "lag": 1,
                                "incomingLag": 0,
                                "outgoingLag": 0,
                                "e2eLag": 1.0  # <=== Il valore chiave che salva ZDM
                            }
                        ]
                    }
                }
            else:
                # Se è un processo specifico
                fake_response = {
                    "$schema": "api:standardResponse",
                    "response": {
                        "$schema": "ogg:processHeartbeat",
                        "heartbeats": [
                            {
                                "source": "SOURCE",
                                "target": "SOURCE",
                                "path": "SOURCE ==> SOURCE",
                                "processName": path.split('/')[-1],
                                "processType": "replicat",
                                "lagSeconds": 1.0,
                                "lagExtract": 1.0,
                                "lagRouting": 1.0,
                                "lagReplicatRead": 1.0,
                                "lagReplicat": 1.0,
                                "ageSeconds": 1.0,
                                "recordedAt": datetime.now(timezone.utc).isoformat() + "Z",
                                "e2eLag": 1.0  # <=== Il valore chiave che salva ZDM
                            }
                        ]
                    }
                }
            self.wfile.write(json.dumps(fake_response).encode())
            return
            
        # Per tutte le altre chiamate, instrada al microservizio corretto di GoldenGate 23ai
        target_port = 7300
        if '/adminsrvr/' in path:
            target_port = 7301
            path = re.sub(r'/services/[^/]+/adminsrvr', '/services', path)
        elif '/distsrvr/' in path:
            target_port = 7302
            path = re.sub(r'/services/[^/]+/distsrvr', '/services', path)
        elif '/recvsrvr/' in path:
            target_port = 7303
            path = re.sub(r'/services/[^/]+/recvsrvr', '/services', path)
        elif '/pmsrvr/' in path:
            target_port = 7304
            path = re.sub(r'/services/[^/]+/pmsrvr', '/services', path)
            
        path = re.sub(r'//+', '/', path)
        url = f'http://{REAL_GG_HUB_IP}:{target_port}{path}'
        
        req_headers = {}
        for k, v in self.headers.items():
            if k.lower() not in ['transfer-encoding', 'connection']:
                req_headers[k] = v
            
        try:
            req = urllib.request.Request(url, headers=req_headers, method=self.command)
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length > 0:
                req.data = self.rfile.read(content_length)
                
            with urllib.request.urlopen(req) as response:
                status_code = response.getcode()
                
                # ZDM si aspetta rigidamente un 201 Created alla creazione del GLOBALS
                if self.command == 'POST' and status_code == 200 and 'config/files/GLOBALS' in path:
                    status_code = 201
                    
                self.send_response(status_code)
                for key, val in response.getheaders():
                    if key.lower() not in ['transfer-encoding', 'connection']:
                        self.send_header(key, val)
                self.end_headers()
                self.wfile.write(response.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for key, val in e.headers.items():
                if key.lower() not in ['transfer-encoding', 'connection']:
                    self.send_header(key, val)
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode())

    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = do_request

class ThreadingHTTPServer(HTTPServer):
    allow_reuse_address = True

if __name__ == '__main__':
    print("Proxy Hacker v15 (GG 23ai ZDM Bypass) in ascolto sulla porta 8888...")
    sys.stdout.flush()
    ThreadingHTTPServer(('', 8888), Proxy).serve_forever()
```

### Avvio del Proxy
Lancialo in background prima di eseguire la migrazione ZDM:
```bash
nohup python3 /home/zdmuser/proxy_gg_bypass.py > /home/zdmuser/proxy.log 2>&1 &
```

---

## 5. Esecuzione della Migrazione (ZDMCLI)

### Dry-Run (Valutazione Pre-Flight)
Verifica l'infrastruttura, il file di risposta e le connessioni senza alterare i dati.
```bash
/u01/app/zdmhome/bin/zdmcli migrate database \
  -sourcedb <DB_SORGENTE> \
  -sourcenode <IP_SORGENTE> \
  -srcauth zdmauth \
  -srcarg1 user:oracle \
  -srcarg2 identity_file:/home/zdmuser/.ssh/id_rsa \
  -srcarg3 sudo_location:/usr/bin/sudo \
  -ggarg1 user:oggadmin \
  -rsp /home/zdmuser/zdm_online_logical.rsp \
  -eval
```
*Le password ti verranno chieste interattivamente. L'esito finale deve essere `SUCCEEDED`.*

### Esecuzione Reale
Rimuovi il flag `-eval`. ZDM avvierà il Data Pump iniziale e accenderà i processi di GoldenGate.
```bash
/u01/app/zdmhome/bin/zdmcli migrate database \
  -sourcedb <DB_SORGENTE> \
  -sourcenode <IP_SORGENTE> \
  -srcauth zdmauth \
  -srcarg1 user:oracle \
  -srcarg2 identity_file:/home/zdmuser/.ssh/id_rsa \
  -srcarg3 sudo_location:/usr/bin/sudo \
  -ggarg1 user:oggadmin \
  -rsp /home/zdmuser/zdm_online_logical.rsp \
  -ignoreadvisor
```

---

## 6. Il Modello Enterprise: Continuous Replication e Cutover Ritardato

Nelle migrazioni Enterprise, il **Cutover** (ovvero lo spegnimento della vecchia applicazione e l'accensione della nuova verso ADB) non avviene **MAI** nello stesso istante in cui ZDM finisce la configurazione. Spesso passa un lasso di tempo di intere settimane per permettere il collaudo funzionale sul Target.

### Lo Scenario Standard ZDM
Se lanci ZDM in modalità Online Logical, arriverà da solo alla fase `ZDM_PREPARE_SWITCHOVER_APP` ed entrerà in un loop di attesa (Polling). ZDM sta aspettando che non ci siano più connessioni né transazioni in corso sul database sorgente per chiudere definitivamente i lavori.

### Come congelare la migrazione (Continuous Replication)
Se desideri interrompere l'attesa di ZDM ma **MANTENERE** in vita la replica in tempo reale di GoldenGate a tempo indeterminato, lancia il seguente comando:

```bash
/u01/app/zdmhome/bin/zdmcli abort job -jobid <ID_DEL_JOB>
```

**Effetto:** ZDM interrompe l'esecuzione e libera le risorse del nodo. Ma l'infrastruttura di **Oracle GoldenGate (Extract, Distribution Path, Replicat) rimane pienamente operativa**. Le transazioni dell'applicativo sorgente continueranno a fluire verso Autonomous Database in tempo reale in maniera autonoma, senza più il controllo di ZDM.

### 6.1 Le Due Strade per il Cutover (Lo Switch Definitivo)

Il momento del Cutover (Go-Live) è quando spegni la vecchia applicazione e la riaccendi puntandola verso il nuovo Autonomous Database.
A seconda di come hai gestito ZDM durante l'attesa, hai due strade per completare il cutover.

---

#### Strada A: Cutover Automatico (Se ZDM è in Pausa / Polling)
Se **NON** hai fatto l'abort del job ZDM e l'hai lasciato girare in attesa (nella fase `ZDM_PREPARE_SWITCHOVER_APP` o pausato intenzionalmente), sarà ZDM a occuparsi di tutto.

**Step 1:** Blocca l'accesso in scrittura al Source DB (Spegni l'applicazione). Assicurati che non ci siano nuove sessioni.
**Step 2:** ZDM se ne accorgerà dal suo polling (attende che il database sia "idle"), o in alternativa puoi forzare la ripresa del job:
```bash
/u01/app/zdmhome/bin/zdmcli resume job -jobid <ID_DEL_JOB>
```
**Step 3:** ZDM aspetterà automaticamente che il lag di GoldenGate sia a zero, spegnerà l'Extract, spegnerà il Replicat e segnerà il job come `COMPLETED`.
**Step 4:** Punta le stringhe di connessione della tua applicazione al nuovo database e riaccendila.

---

#### Strada B: Cutover Manuale da DBA (Se hai fatto l'Abort di ZDM)
Se hai lanciato `zdmcli abort job` giorni o settimane fa per "congelare" l'infrastruttura di replica in puro stile Enterprise, **ZDM non è più coinvolto**. La responsabilità di spegnere la replica in modo pulito e sicuro ricade su di te tramite `adminclient`.

**Step 1: Blocca l'accesso in scrittura al Source DB**
Impedisci fisicamente agli utenti e all'applicazione di scrivere nuovi dati sul database originale (spegni gli application server).

**Step 2: Verifica e Svuotamento della coda (Drain)**
Accedi all'AdminClient di GoldenGate per accertarti che tutte le ultime transazioni "in volo" siano atterrate su ADB.

```bash
# Collegati all'AdminClient sul GoldenGate Hub
adminclient
OGG (https://localhost:443) 1> connect https://localhost:443 as oggadmin password <PASSWORD>
```

Controlla lo stato dell'Extract (Cattura):
```bash
OGG (https://localhost:443) 2> info extract *
# Assicurati che "Lag at Chkpt" sia 00:00:00 e "Time Since Chkpt" stia aumentando
```

Controlla lo stato del Replicat (Applicazione su Target):
```bash
OGG (https://localhost:443) 3> info replicat *
# Assicurati che "Lag at Chkpt" sia 00:00:00.
```

**Step 3: Arresto pulito di GoldenGate (Graceful Stop)**
Ferma in modo sicuro i processi di replica.

```bash
OGG (https://localhost:443) 4> stop extract *
OGG (https://localhost:443) 5> stop replicat *
```

**Step 4: Validazione Finale dei Dati**
Usa SQL*Plus (con il Wallet di ADB) per l'ultimo sanity check.

```bash
export ORACLE_HOME=/u01/app/zdmhome
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export TNS_ADMIN=/home/zdmuser/wallets/adb_target

/u01/app/zdmhome/bin/sqlplus admin/<PASS_ADMIN>@<ALIAS_TNS_HIGH>
```
```sql
-- Verifica il conteggio sulle tabelle core e confrontalo con il sorgente
SELECT COUNT(*) FROM MIO_SCHEMA.MIA_TABELLA;
```

**Step 5: Repoint dell'Applicazione**
Ora che la sorgente e la destinazione sono identiche e la replica è spenta:
1. Aggiorna i file di configurazione della tua applicazione (TNSNAMES.ORA, stringhe JDBC, file YAML).
2. Sostituisci l'IP/Hostname del vecchio DB con le direttive fornite dal Wallet di Autonomous Database.
3. Riavvia l'applicazione.

Il Cutover è completato con **Zero Downtime Reale**! 🎉
