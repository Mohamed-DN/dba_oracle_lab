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

## 3. Creazione del Service Manager e del Deployment

L'installazione dei binari (Fase 2) non avvia alcun servizio. Per utilizzare GoldenGate 23ai, devi inizializzare il **Service Manager** (il coordinatore Web) e creare un **Deployment** (l'istanza di replica).

Questo si fa lanciando il tool grafico/silenzioso `oggca.sh` (Oracle GoldenGate Configuration Assistant).

*... (Sezione in costruzione: verrà popolata nella Fase 3 del lab) ...*
