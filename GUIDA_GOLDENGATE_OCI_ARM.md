# GUIDA EXTRA: Setup OCI ARM (Always Free) come Target GoldenGate

> 🚀 **Obiettivo:** Invece di creare un'ennesima macchina virtuale pesante sul tuo PC locale per il Target di GoldenGate (rischiando di esaurire la RAM), sfrutteremo il **Tier Always Free di Oracle Cloud (OCI)**. 
> Installeremo un'istanza ARM potentissima (4 OCPU, 24GB RAM - gratis per sempre!) e ci metteremo sopra **Oracle Database 23ai Free** con un solo comando. Questo database nel cloud sarà il bersaglio remoto (Replicat) per i dati estratti dal tuo RAC 19c on-premise!

---

## 1. Creazione dell'Istanza ARM su Oracle Cloud

1. Accedi alla tua console **Oracle Cloud Infrastructure (OCI)**.
2. Vai su **Compute** -> **Instances** -> **Create Instance**.
3. Compila i campi chiave:
   - **Name:** `dbtarget-arm`
   - **Image and shape:** 
     - **Image:** `Oracle Linux 8` (Assicurati che sia la versione 8, non 9).
     - **Shape:** Clicca `Change Shape` -> `Virtual Machine` -> `Ampere` -> Seleziona **`VM.Standard.A1.Flex`**. Imposta **4 OCPU** e **24 GB Memory**. (È sempre "Always Free").
   - **Networking:** Lascia le impostazioni di default (Crea una nuova VCN se non ne hai o usane una esistente). Assicurati che **Assign a public IPv4 address** sia su `Yes`.
   - **SSH Keys:** Seleziona `Generate a key pair for me` e scarica la **Private Key** (ti servirà per MobaXterm!).
   - **Boot volume:** Puoi lasciare 50 GB.
4. Clicca su **Create** e aspetta che l'istanza diventi verde (**RUNNING**).
5. **Copia l'Indirizzo IP Pubblico** (es. `130.x.x.x`).

---

## 2. Architettura di Rete: Locale ↔ Cloud

> 💡 **La Domanda del DBA:** "Come facciamo comunicare un server di casa (VirtualBox) con un server nel Cloud in modo sicuro?"

In un ambiente di lavoro reale (**Enterprise**), collegheresti il tuo data center locale ad Oracle Cloud tramite:
1. **IPsec Site-to-Site VPN:** Un tunnel crittografato tra il firewall aziendale e OCI.
2. **Oracle FastConnect:** Una linea in fibra ottica privata e dedicata (costosa, ma ad altissime prestazioni).
In entrambi i casi, le macchine si parlerebbero tramite **IP Privati**.

Per il nostro **Lab**, esporre il database o le porte di GoldenGate (1521, 9011-9014) sull'IP pubblico di Internet, anche se filtrato, **NON è una Best Practice**.

### La Soluzione Lab Ottimale: Tailscale (WireGuard)
Useremo **Tailscale**, una VPN mesh basata su WireGuard estremamente leggera. Permetterà alle macchine VirtualBox e alla VM OCI di vedersi su una rete privata virtuale (es. `100.x.x.x`), crittografando tutto il traffico (i "Trail" di GoldenGate) in transito su Internet. Proprio come una vera VPN Site-to-Site aziendale!

---

## 3. Connessione Iniziale MobaXterm e Setup OS

Prima di installare la VPN, connettiti all'IP **Pubblico** temporaneo di OCI per preparare la macchina.

Apri MobaXterm sul tuo PC e crea una sessione SSH:
- **Remote host:** L'IP Pubblico OCI.
- **Specify username:** `opc` (l'utente di default su OCI).
- **Advanced SSH...\*: Spunta `Use private key` e seleziona il file chiave scaricato.

Appena dentro, esegui questi comandi per preparare il sistema operativo:

```bash
# Diventa root
sudo su -

# 1. Le istanze OCI non hanno swap di default, il DB Oracle lo pretende!
# Creiamo 4GB di Swap
dd if=/dev/zero of=/swapfile count=4096 bs=1MiB
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile   swap    swap    sw  0 0" >> /etc/fstab

# 2. Configura il firewall: permettiamo l'accesso a DB e GG *solo* dall'interfaccia VPN!
firewall-cmd --permanent --zone=trusted --add-interface=tailscale0
firewall-cmd --reload
```

### Installazione Tailscale (Cloud)
Sempre sull'istanza OCI (come root):
```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```
*Copia il link di autenticazione che appare a schermo, incollalo nel browser del tuo PC fisso e fai il login con il tuo account (es. Google/GitHub). La macchina Cloud otterrà un IP del tipo `100.x.x.C`.*

---

## 4. Installazione "Magica" di Oracle Database 23ai Free

Il bello dell'ambiente ARM su OCI con Oracle Linux 8 è che Oracle ha reso l'installazione del Database una passeggiata. Non serve scaricare archivi pesanti, decomprimere o usare `dbca`. È tutto nei repository `yum` ufficiali!

Sempre come utente `root`, lancia:

```bash
# 1. Installa i prerequisiti (crea utente oracle, gruppi, sysctl)
dnf install -y oracle-database-preinstall-23ai

# 2. Installa e configura il software del Database (ci metterà un paio di minuti)
dnf install -y oracle-database-free-23ai

# 3. Crea e avvia il database! 
# Ti chiederà di inserire una password per sys/system. (es. metti "oracle")
/etc/init.d/oracle-free-23ai configure
```

### Configurazione Ambiente Utente `oracle`

Passiamo all'utente `oracle` appena creato per configurare le variabili d'ambiente:

```bash
# Cambia utente
su - oracle

# Aggiungi le variabili al profilo
cat >> ~/.bash_profile <<EOF
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/23ai/dbhomeFree
export ORACLE_SID=FREE
export PATH=\$PATH:\$ORACLE_HOME/bin
EOF

# Caricale
source ~/.bash_profile

# Verifica che il DB sia su
sqlplus sys/oracle as sysdba
```

Vittoria! Hai un DB 23ai su ARM up & running in 5 minuti. Questo DB ha il Container (`FREE`) e un Pluggable Database di default (`FREEPDB1`).

---

## 5. Preparazione del Target per GoldenGate

Ora che il database è su, gli diciamo di prepararsi a ricevere dati da GoldenGate. Dal prompt di `sqlplus sys/oracle as sysdba` sull'istanza cloud:

```sql
-- Cambia modalità sul Pluggable Database dove scriverai i dati
ALTER SESSION SET CONTAINER=FREEPDB1;

-- Crea l'utente per GoldenGate (ggadmin)
CREATE USER ggadmin IDENTIFIED BY ggadmin QUOTA UNLIMITED ON users;

-- In 21c/23ai, GoldenGate ha un ruolo nativo comodissimo
GRANT DBA TO ggadmin;
GRANT OGG_APPLY TO ggadmin;

exit;
```

---

## 6. Installazione Oracle GoldenGate 23ai Free (Microservices)

Su Oracle Linux 8 (ARM), anche GoldenGate 23ai Free è disponibile direttamente dai repository ufficiali `yum`. Non c'è bisogno di scaricare file zip dal sito Oracle! GoldenGate 23ai usa esclusivamente la **Microservices Architecture (MA)** (interfaccia web sicura), avendo deprecato la vecchia architettura Classic a riga di comando.

Esegui questi comandi come `root` sull'istanza cloud:

```bash
# 1. Installa il pacchetto software di GoldenGate 23ai Free
dnf install -y oracle-goldengate-free-23ai

# 2. Il pacchetto crea un utente 'ogg' di default, ma noi vogliamo 
# usare l'utente 'oracle' per semplificare il lab. Creiamo le directory:
mkdir -p /opt/oracle/gg_home
mkdir -p /opt/oracle/gg_deploy
chown -R oracle:oinstall /opt/oracle/gg_*

# 3. Lancia lo script di configurazione interattiva (come root)
# Attenzione: Questo script crea il "Service Manager" e il primo "Deployment"
/opt/oracle/goldengate/bin/oggca.sh \
  -silent \
  -responseFile /opt/oracle/goldengate/response/oggca.rsp \
  -showProgress \
  oggDeploy.deploymentName=Target \
  oggDeploy.deploymentDirectory=/opt/oracle/gg_deploy \
  oggDeploy.administratorUser=admin \
  oggDeploy.administratorPassword=oracle \
  oggDeploy.dbVersion=Oracle \
  oggSoftwareHome=/opt/oracle/goldengate
  
# (Nota: In un ambiente reale non si usa la password "oracle" in chiaro negli script!)
```

### Aprire le Porte Web (Microservices)

1. **Firewall Linux interno (come root):**
   ```bash
   # Service Manager (Porta default 9011)
   firewall-cmd --permanent --zone=trusted --add-port=9011/tcp
   # Administration Server (Porta default 9012)
   firewall-cmd --permanent --zone=trusted --add-port=9012/tcp
   # Distribution Server (Porta default 9013)
   firewall-cmd --permanent --zone=trusted --add-port=9013/tcp
   # Receiver Server (Porta default 9014 - FONDAMENTALE per ricevere i dati!)
   firewall-cmd --permanent --zone=trusted --add-port=9014/tcp
   firewall-cmd --reload
   ```

> 🔒 **Sicurezza Assoluta!** Non abbiamo bisogno di aprire NESSUNA di queste porte nella "Security List" di Oracle Cloud. Tutto il traffico passerà invisibile attraverso il tunnel crittografato di Tailscale sulla porta UDP 41641.

**Testa l'accesso!** Dal PC fisso dove hai installato Tailscale, apri il browser e vai al tuo nuovo IP privato:
👉 `https://100.x.x.C:9011` (Sostituisci con l'IP Tailscale del Cloud)
Accedi con utente `admin` e password `oracle`.

---

## 6. Il Ponte Magico: Collegare il Locale al Cloud

Sui tuoi due nodi RAC locali (in VirtualBox), dobbiamo installare Tailscale affinché possano "vedere" la macchina Cloud.

**Sui nodi RAC Locali (`rac1`, `rac2`, `racstby1`):**

1. Installazione Tailscale (come root):
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   tailscale up
   ```
   *Autenticati nel browser con lo stesso account usato prima. Questi nodi otterranno IP del tipo `100.x.x.R1`, `100.x.x.R2`.*

2. Aggiungi l'IP VPN del Cloud al file `/etc/hosts` locale:

   ```bash
   # Scopri l'IP Tailscale della macchina Cloud
   # (Vai nella dashboard web di Tailscale o esegui 'tailscale status' sul Cloud)
   
   # SU RAC1 e RAC2 (Root)
   # Sostituisci 100.x.x.C con l'IP TAILSCALE della tua macchina OCI!
   echo "100.x.x.C   dbtarget.localdomain   dbtarget" >> /etc/hosts
   ```

   # Su RAC 2 (Root)
   echo "100.x.x.C   dbtarget.localdomain   dbtarget" >> /etc/hosts
   ```

Da questo momento, quando installeremo GoldenGate sul Primario Locale (Fase 5) e gli diremo *"Spedisci i dati a `dbtarget`"*, i dati viaggeranno in modo trasparente dal tuo PC casalingo dritto al tuo DB 23ai nell'Always Free Cloud di Oracle (sulla porta 7809) all'interno del tunnel crittografato Tailscale!

---
## ✨ Prossimi Passi
Ora hai completato la **Fase "0" per GoldenGate Cloud**. 
Quando arriverai alla [FASE 5 - Configurazione GoldenGate](./GUIDA_FASE5_GOLDENGATE.md), salterai lo "Step 5.0" (perché l'hai appena fatto nel cloud in modo molto più smart!) e inizierai direttamente scaricando il software di GoldenGate. Suggerimento: scarica **Oracle GoldenGate 23ai Free per Linux ARM** per l'istanza OCI!
