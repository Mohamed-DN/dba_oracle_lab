# FASE 2: Installazione Grid Infrastructure e Oracle RAC Primario

> Tutti i passaggi di questa fase si riferiscono ai nodi **rac1** e **rac2** (RAC Primario).
> Lo storage condiviso deve essere già visibile da entrambi i nodi prima di procedere.

> 🛑 **PRIMA DI CONTINUARE: CONNETTITI VIA MOBAXTERM!**
> Questa fase è densa di script e configurazioni grafiche. È **obbligatorio** usare MobaXterm con X11-Forwarding attivato. Apri due tab in MobaXterm per avere entrambi i nodi sottomano.
>
> **Tabella IP di Riferimento (Rete Pubblica):**
> - `rac1`: 192.168.56.101
> - `rac2`: 192.168.56.102

## Obiettivo operativo

Installare Grid Infrastructure e Oracle Database 19c sul RAC primary, creare il
CDB `RACDB` con PDB `RACDBPDB` e arrivare a un cluster validato per il duplicate
Data Guard della Fase 3.

## Procedura operativa

Esegui storage, preflight, Grid, ASM, patching, Database Home e DBCA in ordine.
Il track usa nativamente **Oracle Linux 8.10** su **Proxmox VE**.

## Validazione finale

Conferma CRS, ASM, istanze `RACDB1`/`RACDB2`, CDB, PDB, `ARCHIVELOG` e
`FORCE LOGGING` prima di passare allo standby.

## Troubleshooting rapido

Se un passaggio fallisce, conserva log e output, identifica il livello
interessato e correggi solo quello: OS/rete, Grid/ASM, Database Home, patch o
DBCA.

### 📸 Riferimenti Visivi

> 📸 *Nota Bene: Gli screenshot dell'installer grafico provengono dal track originale su VirtualBox. Pertanto mostreranno nomi di schede di rete diversi (es. enp0s3) o riferimenti a VBox. Usa sempre i riferimenti testuali della guida (es. eth0, eth1) durante la tua configurazione.*

![ASM Disk Groups Layout](../images/asm_diskgroups_layout.png)

![Grid Infrastructure Installer — Wizard Steps](../images/grid_installer_wizard.png)

![DBCA — Creazione Database RAC](../images/dbca_create_database.png)

### Cosa Costruiamo in Questa Fase

```
+-----------------------------------------------------------------------+
|                     IL CLUSTER RAC (rac1 + rac2)                     |
|                                                                       |
|    +----------------------------------------------------------+       |
|    |              Oracle Database 19c + RU + OJVM             |       |
|    |         +--------------+  +--------------+               |       |
|    |         |  Istanza     |  |  Istanza     |               |       |
|    |         |  RACDB1      |  |  RACDB2      |               |       |
|    |         |  (rac1)      |  |  (rac2)      |               |       |
|    |         +------+-------+  +------+-------+               |       |
|    +----------------+-----------------+-----------------------+       |
|    +----------------+-----------------+-----------------------+       |
|    |         Grid Infrastructure 19c + Release Update         |       |
|    |         +------+-------+  +------+-------+               |       |
|    |         |    ASM       |  |    ASM        |               |       |
|    |         |  Instance    |  |  Instance     |               |       |
|    |         |  (+ASM1)     |  |  (+ASM2)      |               |       |
|    |         +------+-------+  +------+-------+               |       |
|    |         Clusterware (CRS) <---------------&gt;              |       |
|    |           crsd, cssd, evmd, ohasd                        |       |
|    +----------------+-----------------+-----------------------+       |
|                     |                 |                               |
|    +----------------+-----------------+-----------------------+       |
|    |                  Dischi ASM Condivisi                     |       |
|    |  +---------+     +----------+     +----------+          |       |
|    |  | +CRS    |     | +DATA    |     | +RECO    |          |       |
|    |  |  5 GB   |     |  20 GB   |     |  15 GB   |          |       |
|    |  | OCR,    |     | Datafile,|     | Archive, |          |       |
|    |  | Voting  |     | Redo,    |     | Backup,  |          |       |
|    |  | Disk    |     | Control  |     | Flashback|          |       |
|    |  +---------+     +----------+     +----------+          |       |
|    +----------------------------------------------------------+       |
+-----------------------------------------------------------------------+
```

### Ordine di Installazione in Questa Fase

```
Passo 1:  ASM Dischi        -----------------------▶  oracleasm, partizioni
Passo 2:  cluvfy             -----------------------▶  verifica prerequisiti
Passo 3:  Grid Infrastructure ---------------------▶  gridSetup.sh + root.sh
Passo 4:  DATA + RECO         ---------------------▶  asmca / sqlplus
Passo 5:  Patch Grid (RU)     ---------------------▶  opatchauto (come root)
Passo 6:  DB Software          --------------------▶  runInstaller + root.sh
Passo 7:  Patch DB Home (RU+OJVM)-----------------▶  opatchauto + opatch
Passo 8:  DBCA                  -------------------▶  crea database RACDB
Passo 9:  datapatch              ------------------▶  applica patch al dictionary
```

---

## 2.1 Verifica Storage Condiviso (ASM) su Proxmox

Nella [Fase 0](./GUIDA_FASE0_SETUP_MACCHINE.md) hai già creato i dischi condivisi (assegnati a `rac1` e `rac2` tramite Proxmox con i flag `shared=1` e `iothread=1`).

**Verifica Partizioni (su rac1 come root)**:

I dischi per ASM sono già stati partizionati manualmente e etichettati con ASMLib. Verifichiamo che le partizioni siano visibili:
```bash
lsblk
# Devi vedere sdc1, sdd1, sde1, sdf1, sdg1
```

---

## 2.2 Download e Preparazione Binari

Scarica dal sito [Oracle eDelivery](https://edelivery.oracle.com):
- `LINUX.X64_193000_grid_home.zip` (Grid Infrastructure 19.3)
- `LINUX.X64_193000_db_home.zip` (Database 19.3)

Trasferisci i file su `rac1` (ad esempio in `/tmp/`):

```bash
# Scompatta Grid nella GRID_HOME (come utente grid)
su - grid
unzip -q /tmp/LINUX.X64_193000_grid_home.zip -d /u01/app/19.0.0/grid
```

> **Perché scompattare direttamente nella GRID_HOME?** A partire da Oracle 18c, la GRID_HOME È il software stesso. Non c'è più un "installer" separato: scompatti lo zip e quella diventa la home.

---

## 2.3 Installazione CVU Disk Package

> ⚠️ **ATTENZIONE**: Il file `cvuqdisk` si trova dentro la GRID_HOME che hai appena scompattato. Siccome lo zip è stato estratto **solo su `rac1`**, il path `/u01/app/19.0.0/grid/` **NON ESISTE ancora su `rac2`!** Devi quindi copiare il file RPM da `rac1` a `rac2` prima di installarlo.

**Step 1: Su `rac1` (come `root`) — Installa direttamente:**
```bash
# Su rac1 il file esiste già perché hai scompattato il Grid qui
rpm -ivh /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm
```

**Step 2: Copia il file RPM su `rac2`:**
```bash
# Ancora da rac1, spedisci il file a rac2 via scp
scp /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm root@rac2:/tmp/
```

**Step 3: Su `rac2` (come `root`) — Installa dalla copia in /tmp:**
```bash
# Su rac2, installa dalla copia che hai appena trasferito
rpm -ivh /tmp/cvuqdisk-1.0.10-1.rpm
```

> **Perché cvuqdisk?** È il pacchetto del Cluster Verification Utility per la discovery dei dischi. Senza questo, il `runcluvfy.sh` e il Grid installer non riescono a trovare i dischi condivisi. L'installer di Grid copierà poi automaticamente tutti i binari su `rac2` durante l'installazione — ma `cvuqdisk` serve **PRIMA** dell'installazione per il pre-check.

---

## 2.3b Creare il file Oracle Inventory Pointer (`/etc/oraInst.loc`)

> ⚠️ **Da fare su ENTRAMBI i nodi (`rac1` e `rac2`) come `root`**, altrimenti `cluvfy` fallisce con l'errore: `PRVG-10467: The default Oracle Inventory group could not be determined.`

**Perché serve?** Oracle usa il file `/etc/oraInst.loc` per sapere dove salvare il suo "registro di installazione" (l'Inventory) e quale gruppo Linux lo possiede. Questo file normalmente viene creato automaticamente alla prima installazione Oracle — ma siccome non hai ancora installato nulla, non esiste! Dobbiamo crearlo a mano prima di lanciare il pre-check.

**Su `rac1` E `rac2`, come utente `root`:**

```bash
# 1. Crea il file pointer che dice a Oracle dove sta l'Inventory
cat > /etc/oraInst.loc <<'EOF'
inventory_loc=/u01/app/oraInventory
inst_group=oinstall
EOF

# 2. Permessi corretti sul file
chown root:oinstall /etc/oraInst.loc
chmod 644 /etc/oraInst.loc

# 3. Crea la directory dell'Inventory (se non esiste già)
mkdir -p /u01/app/oraInventory
chown grid:oinstall /u01/app/oraInventory
chmod 775 /u01/app/oraInventory

# 4. Verifica
cat /etc/oraInst.loc
ls -ld /u01/app/oraInventory
```

## 2.3c (Rimossa) - Niente IP Duplicati su Proxmox!

Su VirtualBox, l'interfaccia NAT condivideva lo stesso IP `10.0.2.15` su tutti i nodi scatenando fastidiosi errori su `cluvfy` (PRVG-1172) per IP duplicato e conflitti. 

**Vantaggio Proxmox**: Nel nostro lab su Proxmox VE bare-metal, la tua interfaccia internet (`eth0`) mappata su `vmbr0` riceve IP separati e univoci per ogni VM direttamente dal DHCP del tuo router domestico o del data center. 
Risultato? Nessun conflitto, nessun warning `PRVG-1172`, nessuna necessità di disabilitare interfacce! Puoi saltare a piè pari i fix per la rete.

---

## 2.3d Pre-Grid: Hardening Chrony (OBBLIGATORIO)

Prima di creare il software Grid, dobbiamo assicurarci che Chrony forzi rapidamente la sincronizzazione del tempo in caso di drift, che è critico per la Cluster Synchronization Services (CSSD).

### Hardening Chrony su `rac1` e `rac2`

Esegui su entrambi i nodi come `root`:

```bash
# Imposta makestep per correggere subito drift >1s nei primi 3 update
if grep -q '^makestep' /etc/chrony.conf; then
  sed -i 's/^makestep.*/makestep 1.0 3/' /etc/chrony.conf
else
  echo 'makestep 1.0 3' >> /etc/chrony.conf
fi

systemctl enable chronyd
systemctl restart chronyd
sleep 8

chronyc sources -v
chronyc tracking
timedatectl
```

Criterio PASS/FAIL:
- PASS: `chronyc tracking` mostra `Leap status     : Normal`.
- PASS: `chronyc sources -v` mostra almeno una sorgente valida (`*` o `+`).
- FAIL: `Leap status : Not synchronised` su uno dei due nodi.

Vai avanti con `2.4` (cluvfy) solo se entrambi i nodi sono sincronizzati.

---

## 2.4 Pre-Check con Cluster Verification Utility

```bash
# Come utente grid su rac1
su - grid
cd /u01/app/19.0.0/grid

./runcluvfy.sh stage -pre crsinst \
    -n rac1,rac2 \
    -verbose
```

> **Cosa aspettarsi?** Il pre-check segnalerà probabilmente dei **FAILED** su:
> - **RAM** (Se hai assegnato meno di 8 GB di RAM).
>
> **Questo warning NON è bloccante!** Il `cluvfy` è solo un "consulente" che ti avvisa. Il vero cancello è l'installer (`gridSetup.sh`), che ti mostrerà gli stessi avvisi ma avrà una **checkbox "Ignore All"** in basso a sinistra per proseguire.
> **Importante**: gli errori NTP (`PRVF-4664`) e SSH equivalence vanno risolti prima della Grid.

### Errori da risolvere vs Warning da ignorare

| Errore | Tipo | Azione |
|---|---|---|
| `PRVF-7530`: RAM insufficiente | ⚠️ Warning | Procedi — l'installer ha "Ignore All" |
| `PRVG-11250`: RPM Database check | ℹ️ Info | Ignorabile (serve root per questo check) |
| `PRVF-4664`: NTP non configurato | ❌ Errore | Applica `2.3d` (hardening Chrony) e rilancia cluvfy |
| SSH user equivalence FAILED | ❌ Errore | Ripeti il setup SSH (Fase 1) |

---

## 2.5 Installazione Grid Infrastructure

### Metodo GUI (Consigliato per imparare)

> ⚠️ **ATTENZIONE MOBAXTERM**: Questo step lancia un'interfaccia grafica (GUI). L'unico modo per vederla dal tuo PC Windows è aver effettuato l'accesso a `rac1` tramite **MobaXterm** con la spunta su **X11-Forwarding** (vedi Fase 0). 
> Se sei connesso dalla console VNC di Proxmox o da un Putty senza Xming, il comando fallirà dicendo "Display not set".

```bash
# Come utente grid su rac1 (connesso via MobaXterm)
# Il DISPLAY di solito viene settato in automatico da MobaXterm.
# Se hai problemi, verifica con `echo $DISPLAY` (dovrebbe darti qualcosa come localhost:10.0)

# Avvia l'installer  
cd /u01/app/19.0.0/grid
./gridSetup.sh
```

### Step-by-Step dell'Installer GUI

**Step 1 — Configuration Option**:
- Seleziona: **Configure Oracle Grid Infrastructure for a New Cluster**

**Step 2 — Cluster Configuration**:
- Seleziona: **Configure an Oracle Standalone Cluster**

**Step 3 — Cluster Name e SCAN**:
- Cluster Name: `rac-cluster`
- SCAN Name: `rac-scan.localdomain`  
- SCAN Port: `1521`

> **Il nome SCAN deve corrispondere esattamente a quello nel DNS!** L'installer verifica il DNS in questo momento.

**Step 4 — Cluster Nodes**:
- Aggiungi `rac2` cliccando "Add":
  - Public Hostname: `rac2.localdomain`
  - Virtual Hostname: `rac2-vip.localdomain`
- `rac1` sarà già presente:
  - Virtual Hostname: `rac1-vip.localdomain`
- Clicca **SSH Connectivity** → inserisci password di `grid` → **Setup**
- Clicca **Test** per verificare la connettività

**Step 5 — Network Interface Usage**:

> ⚠️ **ATTENZIONE**: Imposta in questo modo basandoti sui nomi di Oracle Linux 8 su Proxmox:

| Interface | Subnet | Use for |
|---|---|---|
| `eth0` | la tua rete locale | ❌ **Do Not Use** (è la NAT/Internet) |
| `eth1` | 192.168.56.0 | ✅ **Public** |
| `eth2` | 192.168.1.0 | ✅ **ASM & Private** |

> **Perché questa configurazione?**
> - `eth1` (192.168.56.0) → È la rete **pubblica** (vmbr1). I client si connettono al database attraverso questa rete tramite SCAN.
> - `eth2` (192.168.1.0) → È la rete **privata** (vmbr2). Qui transita **Cache Fusion**: le copie dei blocchi di dati tra i nodi. MAI mescolarla con la rete pubblica!
> - `eth0` → È l'uscita Internet (per scaricare pacchetti). Oracle non deve usarla.

**Step 6 — Storage Option**:
- Seleziona: **Use Oracle Flex ASM for Storage**

**Step 7 — Grid Infrastructure Management Repository**:
- Seleziona: **No** (non ci serve il GIMR per un lab)

**Step 8 — Create ASM Disk Group** (per OCR e Voting Disk):

**Procedura passo-passo:**
1. **Disk Group Name**: `CRS`
2. **Redundancy**: seleziona **Normal**
3. **Allocation Unit Size**: lascia `4 MB` (default)
4. **Discovery Path**: clicca **"Change Discovery Path..."** e scrivi:
   ```text
   /dev/oracleasm/disks/*
   ```
5. **Seleziona SOLO questi 3 dischi** (metti la spunta ☑️):
   - ☑️ `/dev/oracleasm.../CRS1` (2047 MB)
   - ☑️ `/dev/oracleasm.../CRS2` (2047 MB)
   - ☑️ `/dev/oracleasm.../CRS3` (2047 MB)
6. **NON selezionare** `DATA` e `RECO`! Li userai dopo per creare disk group separati
7. **NON selezionare** "Configure Oracle ASM Filter Driver" (usiamo ASMLib, non AFD)
8. Clicca **Next**

> ⚠️ **Perché NON selezionare DATA e RECO qui?**
> Questo step crea il disk group `CRS` che conterrà **solo** i metadati del cluster (OCR e Voting Disk). I disk group `DATA` e `RECO` verranno creati separatamente dopo l'installazione Grid.

**Step 9 — ASM Password**:
- Seleziona: **"Use same passwords for these accounts"**
- Inserisci la password (es. `oracle`) in entrambe. Ignora il warning giallo `INS-30011` sulla complessità cliccando **Next → Yes**.

**Step 10 — IPMI**:
- Seleziona: **Do not use IPMI**

**Step 11 — EM Registration**:
- Deseleziona: **Register with Enterprise Manager**

**Step 12 — OS Groups**:
- OSASM Group: `asmadmin`
- OSDBA for ASM: `asmdba`
- OSOPER for ASM: `asmoper`

**Step 13 — Installation Locations**:
- Oracle Base: `/u01/app/grid`
- Software Location: `/u01/app/19.0.0/grid`

**Step 14 — Root Script Execution**:
- **DESELEZIONA** "Automatically run configuration scripts"

**Step 15 — Prerequisite Checks**:
L'installer eseguirà un `cluvfy` interno. 

| Controllo | Risultato | Cosa fare |
|---|---|---|
| **Physical Memory** (PRVF-7530) | ⚠️ Warning | **Ignoralo**. |
| **RPM Package Manager** (PRVG-11250) | ℹ️ Info | **Ignoralo**. |
| 🛑 **Device Checks for ASM** (PRVG-11800) | ❌ Se **FAILED** | **DEVI RISOLVERLO!** (Vedi sotto) |

> 🛠️ **Troubleshooting: Errore PRVG-11800**
> Se ottieni questo FAILED, sei incappato in un bug noto.
> 1. Clicca **Back** fino allo **Step 8 (Create ASM Disk Group)**.
> 2. Clicca **"Change Discovery Path..."** e scrivi: `/dev/oracleasm/disks/*`
> 3. Seleziona di nuovo SOLO CRS1, CRS2, CRS3.
> 4. Vai **Next** fino allo Step 15.

**Se tutti i FAILED sono risolti (e rimangono solo Warning):**
- Spunta la casella **"Ignore All"** in alto a destra.
- Clicca **Next → Yes** per proseguire.

L'installer si fermerà allo **Step 17** e ti mostrerà un pop-up che chiede di eseguire 2 script come `root`.

> 🛑 **ATTENZIONE:** ESEGUI GLI SCRIPT **UNO ALLA VOLTA**, prima su `rac1`, e **SOLO QUANDO HA FINITO** passali su `rac2`.

**Su `rac1` (come root)**:
```bash
/u01/app/oraInventory/orainstRoot.sh
```
```bash
/u01/app/19.0.0/grid/root.sh
# Premi invio al prompt [/usr/local/bin]:
```
> **ASPETTA (ci vorranno 5-10 minuti)** che finisca completamente e ritorni al prompt dei comandi prima di passare al nodo 2!

**Su rac2 (come root)**:
```bash
/u01/app/oraInventory/orainstRoot.sh
/u01/app/19.0.0/grid/root.sh
```

Torna all'installer GUI e clicca **OK** per completare lo step.

---

### 🚨 TROUBLESHOOTING: Cosa fare se l'installazione fallisce?

Se l'esecuzione di `root.sh` fallisce (es. per timeout SSH, problemi di rete), il cluster rimane a metà configurazione.
**Per pulire l'installazione fallita e riprovare (come `root`):**
```bash
# Sul nodo dove ha fallito
/u01/app/19.0.0/grid/crs/install/rootcrs.sh -deconfig -force
```

---

## 2.6 Verifica Cluster

```bash
# Come root o grid
crsctl stat res -t
olsnodes -n
crsctl check crs

# Verifica ASM
su - grid
asmcmd lsdg
```

Output atteso di `crsctl check crs`:
```
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
...
```

---

## 2.6b Checkpoint Freddo Pre-Database (Proxmox)

> 🛑 **ATTENZIONE:** Non usare gli snapshot tradizionali di Proxmox mentre la VM è in esecuzione con dischi RAW ASM `shared=1` e `iothread=1`. Potrebbero fallire o corrompere lo storage.

1. **Spegni il cluster in modo pulito (su `rac1` come root):**
   ```bash
   /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
   ```
2. **Spegni le macchine:**
   ```bash
   shutdown -h now # Su rac1 e rac2
   ```
3. Fai un backup usando Proxmox Backup Server (PBS) o tramite la funzionalità `vzdump` (Backup locale) di Proxmox sui nodi spenti.

---

## 2.7 Creazione Disk Group DATA e RECO

```sql
# Come utente grid (puoi farlo da un nodo qualsiasi, es. rac1)
su - grid
sqlplus / as sysasm

-- Crea disk group DATA (Usiamo il path fisico come fatto nell'installer!)
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY
  DISK '/dev/oracleasm/disks/DATA'
  ATTRIBUTE 'compatible.asm' = '19.0.0.0.0',
            'compatible.rdbms' = '19.0.0.0.0';

-- Crea disk group RECO
CREATE DISKGROUP RECO EXTERNAL REDUNDANCY
  DISK '/dev/oracleasm/disks/RECO'
  ATTRIBUTE 'compatible.asm' = '19.0.0.0.0',
            'compatible.rdbms' = '19.0.0.0.0';

EXIT;
```

```bash
asmcmd lsdg
# Dovrai vedere: CRS, DATA, RECO tutti MOUNTED
```

---

## 2.8 Patching Grid Infrastructure (Release Update)

I patch che ti servono (già presenti nei tuoi download):
- **p6880880**: OPatch
- **p`<COMBO_PATCH_ID>`**: Combo Patch (GI RU + OJVM RU)

> Se stai usando le variabili di ambiente, ricordati di esportare gli ID della patch scelti prima di iniziare.

### Step 1: Aggiorna OPatch nella Grid Home

```bash
# ⚠️ Come ROOT su rac1
su - root
mv /u01/app/19.0.0/grid/OPatch /u01/app/19.0.0/grid/OPatch.bkp.$(date +%Y%m%d)
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.0.0/grid/
chown -R grid:oinstall /u01/app/19.0.0/grid/OPatch

# Verifica la versione (torna a grid)
su - grid
$ORACLE_HOME/OPatch/opatch version

# Ripeti su rac2 (sempre come root!)
ssh rac2
su - root
mv /u01/app/19.0.0/grid/OPatch /u01/app/19.0.0/grid/OPatch.bkp.$(date +%Y%m%d)
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.0.0/grid/
chown -R grid:oinstall /u01/app/19.0.0/grid/OPatch
su - grid
$ORACLE_HOME/OPatch/opatch version
```

### Step 2: Scompatta la Combo Patch

> ⚠️ **ATTENZIONE**: NON scompattare la patch in `/tmp`! Nelle nostre VM, `/tmp` è un disco RAM (tmpfs) limitato. Usa sempre `/u01`!

```bash
# Scompatta su rac1 (come root)
mkdir -p /u01/app/patch
cd /u01/app/patch
unzip -q /tmp/p${COMBO_PATCH_ID}_190000_Linux-x86-64.zip
chown -R grid:oinstall /u01/app/patch

# Ripeti su rac2!
ssh rac2
mkdir -p /u01/app/patch
cd /u01/app/patch
unzip -q /tmp/p${COMBO_PATCH_ID}_190000_Linux-x86-64.zip
chown -R grid:oinstall /u01/app/patch
exit
```

### Step 3: Applica la RU alla Grid Home con opatchauto

```bash
# Come root su rac1
su - root

# Backup dell'ORACLE_HOME
tar czf /u01/app/grid_home_backup_$(date +%Y%m%d).tar.gz -C /u01/app/19.0.0 grid --exclude='*.log'

# Pre-check con opatchauto analyze (dry run)
cd /u01/app/patch/${COMBO_PATCH_ID}/${RU_PATCH_ID}
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/${COMBO_PATCH_ID}/${RU_PATCH_ID} -oh $ORACLE_HOME -analyze

# APPLICAZIONE VERA (solo dopo che analyze è OK)
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/${COMBO_PATCH_ID}/${RU_PATCH_ID} -oh $ORACLE_HOME

# Ripeti su rac2 come root
ssh rac2
cd /u01/app/patch/${COMBO_PATCH_ID}/${RU_PATCH_ID}
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/${COMBO_PATCH_ID}/${RU_PATCH_ID} -oh $ORACLE_HOME
```

---

## 2.9 Installazione Software Database

```bash
# Come utente oracle
su - oracle

# Scompatta il DB nella ORACLE_HOME
unzip -q /tmp/LINUX.X64_193000_db_home.zip -d $ORACLE_HOME

# Avvia l'installer
cd $ORACLE_HOME
export DISPLAY=${WINDOWS_HOST_IP}:0.0
./runInstaller
```

### Step dell'Installer GUI
- **Step 1**: Seleziona **Set Up Software Only**
- **Step 2**: Seleziona **Oracle Real Application Clusters database installation**
- **Step 3**: Seleziona entrambi i nodi (`rac1`, `rac2`)
- **Step 4**: Seleziona **Enterprise Edition**
- **Step 5**: Oracle Base: `/u01/app/oracle`
- **Step 6**: OS Groups: OSDBA (`dba`), OSOPER (`oper`), OSBACKUPDBA (`backupdba`), OSDGDBA (`dgdba`), OSKMDBA (`kmdba`), OSRACDBA (`racdba`).
- **Step 7**: Deseleziona l'esecuzione automatica degli script root.

### Esecuzione root.sh
**Su rac1 come root:**
```bash
/u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```
**Su rac2 come root:**
```bash
/u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```

---

## 2.10 Patching Database Home (Release Update + OJVM)

### Step 1: Aggiorna OPatch nella DB Home

```bash
# ⚠️ Come ROOT su rac1
su - root
mv /u01/app/oracle/product/19.0.0/dbhome_1/OPatch /u01/app/oracle/product/19.0.0/dbhome_1/OPatch.bkp.$(date +%Y%m%d)
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/dbhome_1/
chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1/OPatch

# Ripeti su rac2 (come root!)
ssh rac2
su - root
mv /u01/app/oracle/product/19.0.0/dbhome_1/OPatch /u01/app/oracle/product/19.0.0/dbhome_1/OPatch.bkp.$(date +%Y%m%d)
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/dbhome_1/
chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1/OPatch
```

### Step 2: Applica la RU alla DB Home

```bash
# Come root su rac1
su - root
chown -R oracle:oinstall /u01/app/patch

cd /u01/app/patch/${COMBO_PATCH_ID}/${RU_PATCH_ID}
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/${COMBO_PATCH_ID}/${RU_PATCH_ID} -oh $ORACLE_HOME

# Ripeti su rac2
ssh rac2 "chown -R oracle:oinstall /u01/app/patch"
ssh rac2
cd /u01/app/patch/${COMBO_PATCH_ID}/${RU_PATCH_ID}
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/${COMBO_PATCH_ID}/${RU_PATCH_ID} -oh $ORACLE_HOME
```

### Step 3: Applica il Patch OJVM

```bash
# Come utente oracle su rac1
su - oracle
cd /u01/app/patch/${COMBO_PATCH_ID}/${OJVM_PATCH_ID}
$ORACLE_HOME/OPatch/opatch apply
# Rispondi: y

# Ripeti su rac2
ssh rac2
su - oracle
cd /u01/app/patch/${COMBO_PATCH_ID}/${OJVM_PATCH_ID}
$ORACLE_HOME/OPatch/opatch apply
```

---

## 2.11 Creazione Database RAC con DBCA

```bash
# Come utente oracle su rac1 (connesso via MobaXterm)
su - oracle
dbca
```

### Step dell'Installer GUI
- **Step 1**: **Create a database**
- **Step 2**: **Advanced Configuration** 
- **Step 3**: Database Type: **Oracle RAC database** (seleziona entrambi i nodi)
- **Step 4**: Template: **Custom Database**
- **Step 5**: Global Database Name: `RACDB`. SID Prefix: `RACDB`. ✅ Create as Container Database. PDB Name: `RACDBPDB`.
- **Step 6**: Storage: **Automatic Storage Management (ASM)**, Area: `+DATA`.
- **Step 7**: Fast Recovery Area: `+RECO`, Size: `10000` MB, ✅ **Enable archiving** (FONDAMENTALE per Data Guard!).
- **Step 10**: Memory: **Use Automatic Shared Memory Management** (SGA: 1500, PGA: 500). Character Set: **AL32UTF8**.
- **Step 12**: Password per SYS/SYSTEM.
- **Step 14**: Rivedi Summary → **Finish**.

---

## 2.12 Verifica Post-Installazione e datapatch

Essendo applicata la patch OJVM e il database creato, esegui il datapatch sul dictionary:
```bash
# Come oracle, DOPO aver creato il database
su - oracle
$ORACLE_HOME/OPatch/datapatch -verbose
```

### Abilitare Force Logging (necessario per Data Guard)
```sql
# Come utente oracle
sqlplus / as sysdba
ALTER DATABASE FORCE LOGGING;

-- Apri il PDB su tutti i nodi
ALTER PLUGGABLE DATABASE RACDBPDB OPEN INSTANCES=ALL;
ALTER PLUGGABLE DATABASE RACDBPDB SAVE STATE INSTANCES=ALL;
```

---

## 2.13 Pulizia File Temporanei e Patch

I file zip e le patch scompattate occupano GB preziosi, eliminali:

```bash
# Come root su rac1
rm -rf /u01/app/patch
rm -f /tmp/p*.zip

# Come root su rac2
ssh rac2 'rm -rf /u01/app/patch; rm -f /tmp/p*.zip'
```

---

## ✅ Checklist Fine Fase 2

```bash
# 1. Cluster operativo
crsctl stat res -t | grep -E "ONLINE|OFFLINE"

# 2. ASM Disk Groups
su - grid -c "asmcmd lsdg"
# CRS, DATA, RECO tutti MOUNTED

# 3. Database RAC attivo
su - oracle -c "srvctl status database -d RACDB"

# 4. Archive logging e Force logging attivo
su - oracle -c "sqlplus -s / as sysdba <<< \"SELECT log_mode, force_logging FROM v\\\$database;\""
```

---

**← [FASE 1: Preparazione OS](./GUIDA_FASE1_PREPARAZIONE_OS.md)** | 📍 [Indice Percorso Lab](./README.md) | **→ [FASE 3: RAC Standby](../02_core_dba/04_high_availability_and_rac/GUIDA_FASE3_RAC_STANDBY.md)**
