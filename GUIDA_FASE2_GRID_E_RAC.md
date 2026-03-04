# FASE 2: Installazione Grid Infrastructure e Oracle RAC Primario

> Tutti i passaggi di questa fase si riferiscono ai nodi **rac1** e **rac2** (RAC Primario).
> Lo storage condiviso deve essere giÃ  visibile da entrambi i nodi prima di procedere.

### ðŸ“¸ Riferimenti Visivi

![ASM Disk Groups Layout](./images/asm_diskgroups_layout.png)

![Grid Infrastructure Installer â€” Wizard Steps](./images/grid_installer_wizard.png)

![DBCA â€” Creazione Database RAC](./images/dbca_create_database.png)

### Cosa Costruiamo in Questa Fase

```
â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
â•‘                     IL CLUSTER RAC (rac1 + rac2)                     â•‘
â•‘                                                                       â•‘
â•‘    â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”       â•‘
â•‘    â”‚              Oracle Database 19c + RU + OJVM             â”‚       â•‘
â•‘    â”‚         â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”               â”‚       â•‘
â•‘    â”‚         â”‚  Istanza     â”‚  â”‚  Istanza     â”‚               â”‚       â•‘
â•‘    â”‚         â”‚  RACDB1      â”‚  â”‚  RACDB2      â”‚               â”‚       â•‘
â•‘    â”‚         â”‚  (rac1)      â”‚  â”‚  (rac2)      â”‚               â”‚       â•‘
â•‘    â”‚         â””â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”˜               â”‚       â•‘
â•‘    â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜       â•‘
â•‘    â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”       â•‘
â•‘    â”‚         Grid Infrastructure 19c + Release Update         â”‚       â•‘
â•‘    â”‚         â”Œâ”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”               â”‚       â•‘
â•‘    â”‚         â”‚    ASM       â”‚  â”‚    ASM        â”‚               â”‚       â•‘
â•‘    â”‚         â”‚  Instance    â”‚  â”‚  Instance     â”‚               â”‚       â•‘
â•‘    â”‚         â”‚  (+ASM1)     â”‚  â”‚  (+ASM2)      â”‚               â”‚       â•‘
â•‘    â”‚         â””â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”˜               â”‚       â•‘
â•‘    â”‚         Clusterware (CRS) â—„â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â–º              â”‚       â•‘
â•‘    â”‚           crsd, cssd, evmd, ohasd                        â”‚       â•‘
â•‘    â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜       â•‘
â•‘                     â”‚                 â”‚                               â•‘
â•‘    â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”       â•‘
â•‘    â”‚                  Dischi ASM Condivisi                     â”‚       â•‘
â•‘    â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”     â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”     â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”          â”‚       â•‘
â•‘    â”‚  â”‚ +CRS    â”‚     â”‚ +DATA    â”‚     â”‚ +FRA     â”‚          â”‚       â•‘
â•‘    â”‚  â”‚  5 GB   â”‚     â”‚  20 GB   â”‚     â”‚  15 GB   â”‚          â”‚       â•‘
â•‘    â”‚  â”‚ OCR,    â”‚     â”‚ Datafile,â”‚     â”‚ Archive, â”‚          â”‚       â•‘
â•‘    â”‚  â”‚ Voting  â”‚     â”‚ Redo,    â”‚     â”‚ Backup,  â”‚          â”‚       â•‘
â•‘    â”‚  â”‚ Disk    â”‚     â”‚ Control  â”‚     â”‚ Flashbackâ”‚          â”‚       â•‘
â•‘    â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜     â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜     â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜          â”‚       â•‘
â•‘    â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜       â•‘
â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
```

### Ordine di Installazione in Questa Fase

```
Passo 1:  ASM Dischi        â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â–¶  oracleasm, partizioni
Passo 2:  cluvfy             â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â–¶  verifica prerequisiti
Passo 3:  Grid Infrastructure â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â–¶  gridSetup.sh + root.sh
Passo 4:  DATA + FRA          â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â–¶  asmca / sqlplus
Passo 5:  Patch Grid (RU)     â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â–¶  opatchauto (come root)
Passo 6:  DB Software          â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â–¶  runInstaller + root.sh
Passo 7:  Patch DB Home (RU+OJVM)â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â–¶  opatchauto + opatch
Passo 8:  DBCA                  â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â–¶  crea database RACDB
Passo 9:  datapatch              â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â–¶  applica patch al dictionary
```

---

## 2.1 Preparazione Storage Condiviso (ASM)

### Creazione Dischi Condivisi in VirtualBox

Se usi VirtualBox, crea i dischi dal **Virtual Media Manager** (`Ctrl+D`):

| Disco | Dimensione | Uso |
|---|---|---|
| `asm_crs.vdi`  | 5 GB  | OCR + Voting Disk (Clusterware) |
| `asm_data.vdi` | 20 GB | Disk Group DATA (Datafile) |
| `asm_fra.vdi`  | 15 GB | Disk Group FRA (Archive/Recovery) |

**ProprietÃ  importanti**:
- **Dimensione Fissa** (Fixed Size) â€” obbligatorio per i dischi condivisi.
- Dopo la creazione, seleziona ogni disco â†’ **ProprietÃ ** â†’ **Tipo: Condivisibile (Shareable)**.
- Aggiungi tutti e 3 i dischi al controller SATA di **entrambe** le VM (`rac1` e `rac2`).

### Partizionamento Dischi (su rac1 come root)

```bash
# Verifica che i dischi siano visibili
lsblk

# Dovresti vedere sdb, sdc, sdd (oltre a sda che Ã¨ l'OS)
# Partiziona ciascun disco
for disk in sdb sdc sdd; do
  echo -e "n\np\n1\n\n\nw" | fdisk /dev/$disk
done

# Rileggi la tabella delle partizioni
partprobe
```

> **PerchÃ© partizionare?** ASM puÃ² usare dischi raw o partizioni. Le partizioni sono piÃ¹ sicure perchÃ© un `fdisk` accidentale su un disco raw cancella tutto. Con una partizione, il blocco 0 (tabella partizioni) funge da "guardia".

### Configurazione ASMLib (Metodo Consigliato per OL7)

ASMLib Ã¨ il metodo nativo Oracle per gestire i dischi ASM su Linux:

```bash
# Installa ASMLib (su ENTRAMBI i nodi)
yum install -y oracleasm-support
yum install -y kmod-oracleasm

# Configura ASMLib (su ENTRAMBI i nodi)
oracleasm configure -i
# Risposte:
#   Default user to own the driver interface: grid
#   Default group to own the driver interface: asmadmin
#   Start Oracle ASM library driver on boot (y/n): y
#   Scan for Oracle ASM disks on boot (y/n): y

# Carica il modulo kernel
oracleasm init
```

> **PerchÃ© ASMLib e non udev?** Su Oracle Linux, ASMLib Ã¨ supportato direttamente da Oracle e garantisce che i permessi dei dischi ASM sopravvivano ai reboot. Con udev devi scrivere regole personalizzate. ASMLib Ã¨ piÃ¹ semplice e meno soggetto a errori umani.

### Creazione Dischi ASM (solo su rac1)

```bash
# Crea i dischi ASM (SOLO dal nodo 1!)
oracleasm createdisk CRS  /dev/sdb1
oracleasm createdisk DATA /dev/sdc1
oracleasm createdisk FRA  /dev/sdd1

# Verifica
oracleasm listdisks
# Output atteso: CRS, DATA, FRA
```

### Scansione Dischi dal Nodo 2 (su rac2)

```bash
# Il nodo 2 non vede automaticamente i dischi creati dal nodo 1
oracleasm scandisks
oracleasm listdisks
# Output atteso: CRS, DATA, FRA
```

> ðŸ“¸ **SNAPSHOT â€” "SNAP-04: ASM Dischi Configurati"**
> I dischi ASM sono visibili da entrambi i nodi. Se la creazione dei disk group fallisce, torna qui.
> ```
> VBoxManage snapshot "rac1" take "SNAP-04_ASM_Dischi_OK"
> VBoxManage snapshot "rac2" take "SNAP-04_ASM_Dischi_OK"
> ```

> **PerchÃ© scandisks?** ASMLib sul nodo 2 non ha ancora "registrato" i dischi creati dal nodo 1. Il comando `scandisks` forza una scansione per trovarli.

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

> **PerchÃ© scompattare direttamente nella GRID_HOME?** A partire da Oracle 18c, la GRID_HOME Ãˆ il software stesso. Non c'Ã¨ piÃ¹ un "installer" separato: scompatti lo zip e quella diventa la home.

---

## 2.3 Installazione CVU Disk Package

```bash
# Come root su ENTRAMBI i nodi
rpm -ivh /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm
```

> **PerchÃ© cvuqdisk?** Ãˆ il pacchetto del Cluster Verification Utility per la discovery dei dischi. Senza questo, il `runcluvfy.sh` e il Grid installer non riescono a trovare i dischi condivisi.

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

> **PerchÃ© cluvfy?** Questo strumento verifica TUTTI i prerequisiti prima dell'installazione: DNS, SSH, swap, kernel params, dischi, NTP... Se cluvfy passa con tutti PASSED, l'installazione andrÃ  liscia. Se ci sono FAILED, risolvili PRIMA di procedere.

> ðŸ“¸ **SNAPSHOT â€” "SNAP-05: cluvfy PASSED" ðŸ”´ CRITICO**
> Se cluvfy passa, sei pronto per installare il Grid. Questo Ã¨ il punto di non ritorno.
> ```
> VBoxManage snapshot "rac1" take "SNAP-05_CLUVFY_PASSED"
> VBoxManage snapshot "rac2" take "SNAP-05_CLUVFY_PASSED"
> ```

Errori comuni e soluzioni:
- **PRVG-11250 (RPM Database)**: Ignorabile (Ã¨ un WARNING informativo).
- **PRVF-4664 (NTP)**: Configura chrony correttamente (vedi Fase 1).
- **SSH user equivalence FAILED**: Ripeti il setup SSH (Fase 1.12).

---

## 2.5 Installazione Grid Infrastructure

### Metodo GUI (Consigliato per imparare)

```bash
# Come utente grid su rac1
# Abilita il display X11 (serve un X Server sul tuo PC Windows, es. MobaXterm o XMing)
export DISPLAY=<IP_del_tuo_PC_Windows>:0.0

# Avvia l'installer  
cd /u01/app/19.0.0/grid
./gridSetup.sh
```

### Step-by-Step dell'Installer GUI

**Step 1 â€” Configuration Option**:
- Seleziona: **Configure Oracle Grid Infrastructure for a New Cluster**

> Questa opzione installa Clusterware + ASM da zero.

**Step 2 â€” Cluster Configuration**:
- Seleziona: **Configure an Oracle Standalone Cluster**

> Standalone = un cluster "normale" (non Domain Services Cluster, che Ã¨ per cloud/grandi infrastrutture).

**Step 3 â€” Cluster Name e SCAN**:
- Cluster Name: `rac-cluster`
- SCAN Name: `rac-scan.localdomain`  
- SCAN Port: `1521`

> **Il nome SCAN deve corrispondere esattamente a quello nel DNS!** L'installer verifica il DNS in questo momento.

**Step 4 â€” Cluster Nodes**:
- Aggiungi `rac2` cliccando "Add":
  - Public Hostname: `rac2.localdomain`
  - Virtual Hostname: `rac2-vip.localdomain`
- `rac1` sarÃ  giÃ  presente:
  - Virtual Hostname: `rac1-vip.localdomain`
- Clicca **SSH Connectivity** â†’ inserisci password di `grid` â†’ **Setup**
- Clicca **Test** per verificare la connettivitÃ 

**Step 5 â€” Network Interface Usage**:
| Interface | Subnet | Use |
|---|---|---|
| eth0 | 192.168.1.0 | Public |
| eth1 | 192.168.1.0  | ASM & Private |

> L'Interconnect (Private) Ã¨ la rete su cui transita Cache Fusion: le copie dei blocchi di dati tra i nodi. MAI mescolarla con la rete pubblica.

**Step 6 â€” Storage Option**:
- Seleziona: **Use Oracle Flex ASM for Storage**

**Step 7 â€” Grid Infrastructure Management Repository**:
- Seleziona: **No** (non ci serve il GIMR per un lab)

**Step 8 â€” Create ASM Disk Group** (per OCR e Voting Disk):
- Disk Group Name: `CRS`
- Redundancy: **External** (abbiamo un solo disco per CRS)
- Seleziona il disco: `ORCL:CRS`

> **PerchÃ© External Redundancy?** In un lab con un disco solo non possiamo usare Normal (che richiede 3 dischi) o High (che ne richiede 5). In produzione, SEMPRE Normal o High.

**Step 9 â€” ASM Password**:
- Imposta la password per `SYS` e `ASMSNMP`

**Step 10 â€” IPMI**:
- Seleziona: **Do not use IPMI**

**Step 11 â€” EM Registration**:
- Deseleziona: **Register with Enterprise Manager**

**Step 12 â€” OS Groups**:
- OSASM Group: `asmadmin`
- OSDBA for ASM: `asmdba`
- OSOPER for ASM: `asmoper`

**Step 13 â€” Installation Locations**:
- Oracle Base: `/u01/app/grid`
- Software Location: `/u01/app/19.0.0/grid`

**Step 14 â€” Root Script Execution**:
- **DESELEZIONA** "Automatically run configuration scripts"
- Li eseguiremo noi manualmente, uno alla volta, per capire cosa fanno

**Step 15 â€” Summary**:
- Rivedi tutto e clicca **Install**

### Esecuzione degli Script root

L'installer si ferma e chiede di eseguire 2 script come `root`. **ESEGUILI UNO ALLA VOLTA, prima su rac1, poi su rac2!**

**Su rac1 (come root)**:

```bash
/u01/app/oraInventory/orainstRoot.sh
```

> Questo script registra la Central Inventory. Deve essere eseguito una sola volta.

```bash
/u01/app/19.0.0/grid/root.sh
```

> **Questo Ã¨ lo script piÃ¹ importante**. Esegue:
> - Configura Oracle Clusterware (CRS)
> - Crea il CRS daemon (`crsd`, `cssd`, `evmd`)
> - Configura ASM
> - Avvia il cluster su questo nodo
>
> **ASPETTA** che finisca completamente prima di passare al nodo 2! Se lo esegui in parallelo, il cluster si corrompe.

**Su rac2 (come root)**:

```bash
/u01/app/oraInventory/orainstRoot.sh
/u01/app/19.0.0/grid/root.sh
```

> Sul nodo 2, `root.sh` aggiungerÃ  questo nodo al cluster esistente (creato dal nodo 1).

Torna all'installer GUI e clicca **OK** per completare.

> ðŸ“¸ **SNAPSHOT â€” "SNAP-06: Grid Infrastructure Installato" â­ MILESTONE**
> Il cluster Ã¨ attivo! Reinstallare il Grid richiederebbe ore. NON cancellare questo snapshot.
> ```
> VBoxManage snapshot "rac1" take "SNAP-06_Grid_Installato"
> VBoxManage snapshot "rac2" take "SNAP-06_Grid_Installato"
> ```

---

## 2.6 Verifica Cluster

```bash
# Come root o grid
# Stato generale del cluster
crsctl stat res -t

# Elenco nodi
olsnodes -n

# Stato CRS (deve essere tutto ONLINE)
crsctl check crs

# Verifica ASM
su - grid
asmcmd lsdg
# Dovrai vedere il disk group CRS
```

Output atteso di `crsctl check crs`:
```
CRS-4638: Oracle High Availability Services is online
CRS-4537: Cluster Ready Services is online
CRS-4529: Cluster Synchronization Services is online
CRS-4533: Event Manager is online
```

> Se vedi tutto ONLINE, il tuo cluster Ã¨ vivo! ðŸŽ‰

---

## 2.7 Creazione Disk Group DATA e FRA

Ora che il cluster Ã¨ attivo, creiamo i disk group per il database:

```bash
# Come utente grid
su - grid
asmca
```

Oppure da linea di comando:

```sql
-- Connettiti ad ASM come SYSASM
sqlplus / as sysasm

-- Crea disk group DATA
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY
  DISK 'ORCL:DATA'
  ATTRIBUTE 'compatible.asm' = '19.0.0.0.0',
            'compatible.rdbms' = '19.0.0.0.0';

-- Crea disk group FRA
CREATE DISKGROUP FRA EXTERNAL REDUNDANCY
  DISK 'ORCL:FRA'
  ATTRIBUTE 'compatible.asm' = '19.0.0.0.0',
            'compatible.rdbms' = '19.0.0.0.0';

-- Verifica
SELECT name, state, type, total_mb, free_mb FROM v$asm_diskgroup;

EXIT;
```

```bash
# Verifica da asmcmd
asmcmd lsdg
# Dovrai vedere: CRS, DATA, FRA tutti MOUNTED
```

> **PerchÃ© creare DATA e FRA separati?** DATA contiene i datafile (i dati veri). FRA (Fast Recovery Area) contiene gli archivelog, i backup RMAN e i flashback log. Separarli Ã¨ una best practice fondamentale: se il disco DATA si riempie, hai ancora lo spazio per il recovery.

---

## 2.8 Patching Grid Infrastructure (Release Update)

> **PerchÃ© patchare?** Oracle 19c base (19.3) Ã¨ la versione iniziale rilasciata nel 2019. Le Release Update (RU) contengono fix di sicurezza, bug fix e miglioramenti di stabilitÃ . In produzione, patchare Ã¨ **obbligatorio**. Nel lab, ti insegna il processo che userai nel mondo reale.

I patch che ti servono (giÃ  presenti nei tuoi download):

| Patch | Descrizione | Dove si Applica |
|---|---|---|
| **p6880880** | **OPatch** (utility per applicare patch) | Sostituisci in ogni ORACLE_HOME |
| **p37957391** | **Release Update (RU)** â€” Jan 2025 o successiva | Grid Home + DB Home |
| **p33803476** | **OJVM Release Update** o one-off patch | DB Home |

### Step 1: Aggiorna OPatch nella Grid Home

OPatch Ã¨ lo strumento che applica le patch. La versione fornita con il software base 19.3 Ã¨ troppo vecchia. Devi aggiornarla PRIMA di applicare qualsiasi patch.

```bash
# Come utente grid su rac1
su - grid

# Backup del vecchio OPatch
mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bkp.$(date +%Y%m%d)

# Scompatta il nuovo OPatch
unzip -q /tmp/p6880880_230000_Linux-x86-64.zip -d $ORACLE_HOME/

# Verifica la versione
$ORACLE_HOME/OPatch/opatch version
# Deve mostrare: OPatch Version: 12.2.0.1.43 (o superiore)
```

> **PerchÃ© la versione 230000?** Il p6880880_**230000** Ã¨ la versione di OPatch compatibile con Oracle 19c e le RU recenti. La versione nel nome (23.x) indica la build di OPatch, non la versione del database.

```bash
# Ripeti su rac2
ssh rac2
su - grid
mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bkp.$(date +%Y%m%d)
unzip -q /tmp/p6880880_230000_Linux-x86-64.zip -d $ORACLE_HOME/
$ORACLE_HOME/OPatch/opatch version
```

### Step 2: Scompatta la Release Update

```bash
# Come root (o oracle/grid con permessi)
# Scompatta la RU in una directory temporanea
mkdir -p /tmp/patch
cd /tmp/patch
unzip -q /tmp/p37957391_190000_Linux-x86-64.zip

# Vedrai una directory con il numero del patch, es: 37957391/
ls -la
```

### Step 3: Applica la RU alla Grid Home con opatchauto

```bash
# FERMA il database prima del patching (come oracle)
su - oracle
srvctl stop database -d RACDB

# Come root su rac1 â€” opatchauto patcha sia Grid che ASM automaticamente
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/OPatch/opatchauto apply /tmp/patch/37957391 -oh $ORACLE_HOME
```

> **PerchÃ© opatchauto?** Per la Grid Infrastructure, non puoi usare il semplice `opatch apply`. Devi usare `opatchauto` (come root), che:
> 1. Ferma il CRS automaticamente
> 2. Applica la patch
> 3. Riavvia il CRS
> Fa tutto in un colpo, gestendo anche le dipendenze dei servizi cluster.

```bash
# Verifica che il CRS si sia riavviato
crsctl check crs
# Deve mostrare tutto ONLINE

# Verifica la patch applicata
su - grid
$ORACLE_HOME/OPatch/opatch lspatches
# Deve mostrare il numero del patch RU (37957391)
```

```bash
# Ripeti su rac2 come root
ssh rac2
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/OPatch/opatchauto apply /tmp/patch/37957391 -oh $ORACLE_HOME

# Verifica
crsctl check crs
su - grid
$ORACLE_HOME/OPatch/opatch lspatches
```

> ðŸ“¸ **SNAPSHOT â€” "SNAP-07: Grid Patchato con RU"**
> Il Grid Ã¨ aggiornato all'ultima Release Update. Se il patching del DB home fallisce, puoi tornare qui.
> ```
> VBoxManage snapshot "rac1" take "SNAP-07_Grid_Patchato"
> VBoxManage snapshot "rac2" take "SNAP-07_Grid_Patchato"
> ```

---

## 2.9 Installazione Software Database

```bash
# Come utente oracle
su - oracle

# Scompatta il DB nella ORACLE_HOME
unzip -q /tmp/LINUX.X64_193000_db_home.zip -d $ORACLE_HOME

# Avvia l'installer
cd $ORACLE_HOME
export DISPLAY=<IP_del_tuo_PC>:0.0
./runInstaller
```

### Step dell'Installer GUI

**Step 1**: Seleziona **Set Up Software Only**

> Installiamo SOLO i binari. Il database lo creiamo dopo con DBCA. Questo Ã¨ il metodo professionale: prima installi, poi crei.

**Step 2**: Seleziona **Oracle Real Application Clusters database installation**

**Step 3**: Seleziona entrambi i nodi (`rac1`, `rac2`)

**Step 4**: Seleziona **Enterprise Edition**

**Step 5**: Verifica i path:
- Oracle Base: `/u01/app/oracle`
- Software Location: `/u01/app/oracle/product/19.0.0/dbhome_1`

**Step 6**: OS Groups:
- OSDBA: `dba`
- OSOPER: `oper`
- OSBACKUPDBA: `backupdba`
- OSDGDBA: `dgdba`
- OSKMDBA: `kmdba`
- OSRACDBA: `racdba`

**Step 7**: Deseleziona l'esecuzione automatica degli script root

**Step 8**: Rivedi Summary e clicca **Install**

### Esecuzione root.sh

**Su rac1 come root:**

```bash
/u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```

**Su rac2 come root:**

```bash
/u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```

> ðŸ“¸ **SNAPSHOT â€” "SNAP-08: DB Software Installato"**
> I binari del database sono installati. Se il patching o DBCA fallisce, torni qui e riprovi.
> ```
> VBoxManage snapshot "rac1" take "SNAP-08_DB_Software"
> VBoxManage snapshot "rac2" take "SNAP-08_DB_Software"
> ```

---

## 2.11 Patching Database Home (Release Update + OJVM)

### Step 1: Aggiorna OPatch nella DB Home

```bash
# Come utente oracle su rac1
su - oracle

# Backup del vecchio OPatch
mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bkp.$(date +%Y%m%d)

# Scompatta il nuovo OPatch
unzip -q /tmp/p6880880_230000_Linux-x86-64.zip -d $ORACLE_HOME/

# Verifica
$ORACLE_HOME/OPatch/opatch version

# Ripeti su rac2
ssh rac2
su - oracle
mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bkp.$(date +%Y%m%d)
unzip -q /tmp/p6880880_230000_Linux-x86-64.zip -d $ORACLE_HOME/
$ORACLE_HOME/OPatch/opatch version
```

### Step 2: Applica la RU alla DB Home

```bash
# Come root su rac1
# Usiamo opatchauto anche per la DB Home (metodo RAC)
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /tmp/patch/37957391 -oh $ORACLE_HOME
```

> **Nota**: `opatchauto` riconosce automaticamente che Ã¨ una DB Home in un cluster RAC e gestisce il patching di conseguenza.

```bash
# Ripeti su rac2
ssh rac2
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /tmp/patch/37957391 -oh $ORACLE_HOME
```

### Step 3: Applica il Patch OJVM (p33803476)

Il patch OJVM (Oracle Java Virtual Machine) Ã¨ separato dalla RU e si applica con `opatch apply` standard.

```bash
# Scompatta il patch OJVM
cd /tmp/patch
unzip -q /tmp/p33803476_190000_Linux-x86-64.zip

# Come utente oracle su rac1
su - oracle
cd /tmp/patch/33803476
$ORACLE_HOME/OPatch/opatch apply

# Quando chiede "Is the local system ready for patching?" rispondi: y
# Ripeti su rac2
ssh rac2
su - oracle
cd /tmp/patch/33803476
$ORACLE_HOME/OPatch/opatch apply
```

> **PerchÃ© OJVM separato?** La OJVM Ã¨ la Java Virtual Machine interna di Oracle (usata per stored procedure Java, APEX, etc.). Il patch OJVM non Ã¨ incluso nella RU e va applicato separatamente. Dopo averlo applicato, al primo avvio del database dovrai eseguire `datapatch`.

### Step 4: Verifica Patch Applicati

```bash
# Come oracle su rac1
$ORACLE_HOME/OPatch/opatch lspatches
```

Output atteso:
```
37957391;Database Release Update : 19.x.0.0.xxxxxx (37957391)
33803476;OJVM RELEASE UPDATE: 19.x.0.0.xxxxxx (33803476)
```

### Step 5: datapatch (dopo la creazione del DB)

> **IMPORTANTE**: `datapatch` va eseguito DOPO aver creato il database con DBCA (sezione successiva). Non eseguirlo ora â€” non hai ancora un database!
> Dopo DBCA, esegui:

```bash
# Come oracle, DOPO aver creato il database
su - oracle
$ORACLE_HOME/OPatch/datapatch -verbose
```

> **Cos'Ã¨ datapatch?** `opatch` aggiorna i binari (i file .o, le librerie). Ma alcune patch richiedono anche modifiche al Data Dictionary (le tabelle interne di Oracle). `datapatch` applica queste modifiche SQL al database. Senza datapatch, la patch Ã¨ applicata solo a metÃ .

```sql
-- Verifica che datapatch sia andato a buon fine
SELECT patch_id, patch_uid, action, status, description
FROM dba_registry_sqlpatch
ORDER BY action_time DESC;
-- Deve mostrare SUCCESS per entrambi i patch
```

> ðŸ“¸ **SNAPSHOT â€” "SNAP-08b: DB Home Patchato"**
> I binari del database sono patchati con RU + OJVM. Pronto per DBCA.
> ```
> VBoxManage snapshot "rac1" take "SNAP-08b_DB_Patchato"
> VBoxManage snapshot "rac2" take "SNAP-08b_DB_Patchato"
> ```

---

## 2.12 Creazione Database RAC con DBCA

```bash
# Come utente oracle su rac1
su - oracle
export DISPLAY=<IP_del_tuo_PC>:0.0
dbca
```

### Step dell'Installer GUI

**Step 1**: **Create a database**

**Step 2**: **Advanced Configuration** (per avere pieno controllo)

**Step 3**: Database Type:
- **Oracle RAC database**
- Seleziona entrambi i nodi

**Step 4**: Template:
- **Custom Database** (per massimo controllo)

**Step 5**: Database Identification:
- Global Database Name: `RACDB`
- SID Prefix: `RACDB` (diventerÃ  RACDB1 su rac1, RACDB2 su rac2)

**Step 6**: Storage:
- Use following for the database storage: **Automatic Storage Management (ASM)**
- Database Area: `+DATA`

**Step 7**: Fast Recovery Area:
- Recovery Area: `+FRA`
- Size: `10000` MB (o quanto hai disponibile)
- âœ… **Enable archiving** (FONDAMENTALE per Data Guard!)

> **PerchÃ© Enable Archiving?** Senza archivelog mode, Data Guard non funziona. L'archivelog Ã¨ il "diario" di tutte le modifiche. Ãˆ quello che viene spedito allo standby.

**Step 8**: Listener:
- Seleziona il listener del cluster (giÃ  configurato da Grid)

**Step 9**: Database Options:
- Puoi deselezionare componenti non necessari (Oracle Text, Spatial, etc.)

**Step 10**: Configuration Options:
- Memory: **Use Automatic Shared Memory Management**
- SGA: almeno 1500 MB
- PGA: almeno 500 MB
- Character Set: **AL32UTF8** (consigliato)

**Step 11**: Management Options:
- Deseleziona EM Express per semplicitÃ 

**Step 12**: Password:
- Imposta password per SYS, SYSTEM, etc.

**Step 13**: Creation Options:
- âœ… Create Database
- âœ… Save as a Database Template (opzionale)
- âœ… Generate Database Creation Scripts (utile per imparare!)

**Step 14**: Rivedi Summary â†’ **Finish**

L'installazione richiederÃ  15-30 minuti a seconda dell'hardware.

---

## 2.13 Verifica Post-Installazione Database

```bash
# Come utente oracle
sqlplus / as sysdba

-- Verifica le istanze
SELECT inst_id, instance_name, host_name, status FROM gv$instance;
```

Output atteso:
```
   INST_ID INSTANCE_NAME    HOST_NAME       STATUS
---------- ---------------- --------------- --------
         1 RACDB1           rac1            OPEN
         2 RACDB2           rac2            OPEN
```

```bash
# Verifica servizi del cluster
srvctl status database -d RACDB
# Output: Instance RACDB1 is running on node rac1
#         Instance RACDB2 is running on node rac2

# Verifica listener SCAN
srvctl status scan
srvctl status scan_listener

# Verifica servizi del database
srvctl config database -d RACDB
```

> ðŸ“¸ **SNAPSHOT â€” "SNAP-09: Database RAC Creato (RACDB)" â­ MILESTONE**
> Il tuo RAC primario Ã¨ completamente operativo! Questo Ã¨ forse lo snapshot piÃ¹ importante del progetto.
> ```
> VBoxManage snapshot "rac1" take "SNAP-09_RACDB_Creato"
> VBoxManage snapshot "rac2" take "SNAP-09_RACDB_Creato"
> ```

### Abilitare Force Logging (necessario per Data Guard)

```sql
-- Come sysdba
ALTER DATABASE FORCE LOGGING;

-- Verifica
SELECT force_logging FROM v$database;
-- Deve restituire YES
```

> **PerchÃ© Force Logging?** Alcune operazioni (come `INSERT /*+ APPEND */ ...` o `CREATE TABLE ... NOLOGGING`) possono bypassare il redo log per velocitÃ . Ma se non generi redo, lo standby non riceve le modifiche e i dati si corrompono. Force Logging impedisce questo bypass.

---

## âœ… Checklist Fine Fase 2

```bash
# 1. Cluster operativo
crsctl stat res -t | grep -E "ONLINE|OFFLINE"

# 2. ASM Disk Groups
su - grid -c "asmcmd lsdg"
# CRS, DATA, FRA tutti MOUNTED

# 3. Database RAC attivo
su - oracle -c "srvctl status database -d RACDB"

# 4. Archive logging attivo
su - oracle -c "sqlplus -s / as sysdba <<< \"SELECT log_mode FROM v\\\$database;\""

# 5. Force logging attivo
su - oracle -c "sqlplus -s / as sysdba <<< \"SELECT force_logging FROM v\\\$database;\""
```

---

**â†’ Prossimo: [FASE 3: Preparazione e Creazione Oracle RAC Standby](./GUIDA_FASE3_RAC_STANDBY.md)**
