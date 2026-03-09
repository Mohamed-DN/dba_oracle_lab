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

## 2. Configurazione Rete OCI (Security List)

Di default, Oracle Cloud blocca tutto il traffico in ingresso tranne la porta SSH (22). Dobbiamo aprire le porte per far comunicare il tuo RAC locale con il nuovo Target.

1. Dalla pagina della tua Istanza, clicca sul link della **Subnet** (nella sezione *Instance information*).
2. Clicca sulla **Default Security List**.
3. Clicca su **Add Ingress Rules**.
4. Inserisci una regola per il DB e GoldenGate:
   - **Source CIDR:** Il tuo **Indirizzo IP Pubblico di casa** (cercalo su *mio-ip.it*). Aggiungi `/32` alla fine (es. `93.45.122.5/32`) per permettere l'accesso *solo* a te. *Se hai un IP dinamico, potresti dover aggiornare questa regola ogni tanto, oppure mettere `0.0.0.0/0` (molto insicuro, sconsigliato per il DB!).*
   - **IP Protocol:** `TCP`
   - **Destination Port Range:** `1521, 7809` (1521 per il DB, 7809 per il manager di GoldenGate Classic).
   - **Description:** `Accesso DB e GoldenGate dal Lab Locale`
5. Clicca **Add Ingress Rules**.

---

## 3. Connessione MobaXterm e Setup OS

Apri MobaXterm sul tuo PC e crea una nuova sessione SSH:
- **Remote host:** L'IP Pubblico OCI.
- **Specify username:** `opc` (l'utente di default su OCI, *non* root).
- **Advanced SSH settings:** Spunta `Use private key` e seleziona il file della chiave privata che hai scaricato nello step 1.

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

# 2. Apri il firewall interno di Linux (firewalld) per Oracle e GG
firewall-cmd --permanent --zone=public --add-port=1521/tcp
firewall-cmd --permanent --zone=public --add-port=7809/tcp
firewall-cmd --reload
```

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

GoldenGate Microservices usa HTTPS. Dobbiamo aprire le porte nel firewall Linux e nella Security List di OCI.

1. **Firewall Linux (come root):**
   ```bash
   # Service Manager (Porta default 9011)
   firewall-cmd --permanent --zone=public --add-port=9011/tcp
   # Administration Server (Porta default 9012)
   firewall-cmd --permanent --zone=public --add-port=9012/tcp
   # Distribution Server (Porta default 9013)
   firewall-cmd --permanent --zone=public --add-port=9013/tcp
   # Receiver Server (Porta default 9014 - FONDAMENTALE per ricevere i dati!)
   firewall-cmd --permanent --zone=public --add-port=9014/tcp
   firewall-cmd --reload
   ```

2. **Security List OCI (Torna al Browser):**
   Come fatto nello Step 2 della guida, vai nella tua Security List su Oracle Cloud e aggiungi una regola per le porte Web di GoldenGate:
   - **Source CIDR:** Il tuo IP di casa (es. `93.45.122.5/32`)
   - **Destination Port Range:** `9011-9014`
   - **Description:** `GoldenGate Microservices Web UI`

**Testa l'accesso!** Apri il browser dal tuo PC e vai su:
👉 `https://<IP_PUBBLICO_CLOUD>:9011`
Accedi con utente `admin` e password `oracle`.

---

## 6. Il Ponte Magico: Collegare il Locale al Cloud

Sui tuoi due nodi RAC locali (in VirtualBox), GoldenGate ("Pump") dovrà spedire i file di log ("Trail") a questa macchina in Cloud.

Per farlo, apri MobaXterm, collegati a **`rac1`** e **`rac2`** come root e aggiungi semplicemente l'IP pubblico del Cloud al file `/etc/hosts`:

```bash
# SU RAC1 (Root)
# Sostituisci 130.x.x.x con il VERO IP PUBBLICO della tua macchina OCI!
echo "130.x.x.x   dbtarget.localdomain   dbtarget" >> /etc/hosts

# SU RAC2 (Root)
echo "130.x.x.x   dbtarget.localdomain   dbtarget" >> /etc/hosts
```

Da questo momento, quando installeremo GoldenGate sul Primario Locale (Fase 5) e gli diremo *"Spedisci i dati a `dbtarget`"*, i dati viaggeranno in modo trasparente dal tuo PC casalingo dritto al tuo DB 23ai nell'Always Free Cloud di Oracle (sulla porta 7809)!

---
## ✨ Prossimi Passi
Ora hai completato la **Fase "0" per GoldenGate Cloud**. 
Quando arriverai alla [FASE 5 - Configurazione GoldenGate](./GUIDA_FASE5_GOLDENGATE.md), salterai lo "Step 5.0" (perché l'hai appena fatto nel cloud in modo molto più smart!) e inizierai direttamente scaricando il software di GoldenGate. Suggerimento: scarica **Oracle GoldenGate 23ai Free per Linux ARM** per l'istanza OCI!
