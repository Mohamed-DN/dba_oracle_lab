# Guida all'Installazione Bare Metal di Oracle GoldenGate 23ai (Microservices)

Questa guida illustra la procedura di installazione "Bare Metal" (tradizionale, senza container Docker) di **Oracle GoldenGate 23ai Microservices Architecture** su un server Linux (Oracle Linux / Red Hat). 

A partire dalla release 23ai, Oracle ha rimosso l'architettura *Classic*, rendendo *Microservices* l'unico standard supportato.

---

## 1. Prerequisiti di Sistema (Utente `root`)

Prima di scompattare i binari, è necessario preparare l'utente di sistema operativo e la struttura delle directory. Questa separazione garantisce sicurezza e aderenza alle Best Practice Oracle.

```bash
# 1. Creazione gruppo e utente Oracle GoldenGate (ogg)
sudo groupadd -g 54321 oinstall
sudo useradd -u 54322 -g oinstall ogg
echo "ogg2026" | sudo passwd --stdin ogg

# 2. Creazione della struttura directory
# /u01 per i binari software, /u02 per le configurazioni e i Trail file
sudo mkdir -p /u01/app/ogg
sudo mkdir -p /u02/deployments

# 3. Assegnazione permessi
sudo chown -R ogg:oinstall /u01 /u02
sudo chmod -R 775 /u01 /u02
```

---

## 2. Installazione dei Binari (Utente `ogg`)

L'installazione del "motore" di GoldenGate può essere fatta in due modi: tramite interfaccia grafica (GUI) o in modalità silenziosa (Silent Mode). In un ambiente di laboratorio, la GUI è ottima per prendere confidenza con i parametri.

1. Accedi al server come utente `ogg` (assicurati di avere il forwarding X11 attivo se usi SSH/MobaXterm):
   ```bash
   su - ogg
   ```

2. Scompatta il pacchetto software (es. `V1054774-01.zip`) in una directory temporanea:
   ```bash
   mkdir -p /tmp/ogg_installer
   unzip /tmp/V1054774-01.zip -d /tmp/ogg_installer
   cd /tmp/ogg_installer/fbo_ggs_Linux_x64_Oracle_services_shiphome/Disk1
   ```

### Opzione A: Installazione Grafica (Consigliata per i Lab)
Se hai un server X11 configurato, lancia semplicemente:
```bash
./runInstaller
```
Si aprirà l'Oracle Universal Installer. I parametri chiave da inserire nelle schermate saranno:
- **Software Location:** `/u01/app/ogg`
- **Database Version:** Scegli l'opzione unificata 23ai/Oracle.
- **Inventory Directory:** `/u01/app/oraInventory` (gruppo `oinstall`).

### Opzione B: Installazione Silenziosa (Per Automazioni)
Se non hai accesso grafico, crea un file di risposta:
```bash
cat <<EOF > /tmp/ogg_installer/oggcore.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_ogginstall_response_schema_v23_0_0
INSTALL_OPTION=ORA23ai
SOFTWARE_LOCATION=/u01/app/ogg
INVENTORY_LOCATION=/u01/app/oraInventory
UNIX_GROUP_NAME=oinstall
EOF
```
E lancialo:
```bash
./runInstaller -silent -nowait -responseFile /tmp/ogg_installer/oggcore.rsp
```

### Script Root Finale
Al termine dell'installazione (sia Grafica che Silenziosa), l'installer ti chiederà di eseguire uno script come utente `root`. Apri un'altra finestra terminale ed esegui:
```bash
sudo /u01/app/oraInventory/orainstRoot.sh
```

---

## 3. Creazione del Service Manager e del Deployment (Utente `ogg`)

L'installazione dei binari (Fase 2) non avvia alcun servizio. Per utilizzare GoldenGate 23ai, devi inizializzare il **Service Manager** (il coordinatore Web) e creare un **Deployment** (l'istanza di replica).

Questo si fa lanciando il tool grafico `oggca.sh` (Oracle GoldenGate Configuration Assistant).

1. Assicurati di essere loggato come `ogg` con il forwarding X11 attivo.
2. Lancia il Configuration Assistant:
   ```bash
   cd /u01/app/ogg/bin
   ./oggca.sh
   ```

### Schermate del Configuration Assistant (GUI)

Quando si apre l'assistente, segui questi step:
1. **Service Manager:** Scegli "Add New Service Manager".
2. **Directories:** 
   - *Deployment Home:* `/u02/deployments`
3. **Register Service Manager:**
   - *Administrator User:* `oggadmin` (Questo è l'utente Web, non l'utente OS o DB).
   - *Password:* Scegli una password (es. `OggAdmin_2026`).
   - *Port:* `7300` (Porta di default del Service Manager).
4. **Add Deployment:**
   - *Deployment Name:* `zdm_hub`
   - *Software Location:* `/u01/app/ogg`
5. **Deployment Details:**
   - *Administrator:* Usa lo stesso `oggadmin`.
   - *Port (Administration Server):* `7301`
   - *Environment Variables:* Aggiungi `ORACLE_HOME` se il database è sulla stessa macchina (ma nel nostro lab il DB è su `rac1`, quindi puoi lasciare vuoto o mettere il path del client Oracle).

Clicca su **Finish**. L'assistente avvierà i demoni di GoldenGate.

### Verifica Finale
Apri un browser (dal tuo PC o dalla VM) e vai su:
**`https://<IP_ZDM_NODE>:7300`**
Fai il login con `oggadmin` e vedrai la maestosa console Web di GoldenGate Microservices 23ai!
