# FASE 3: Preparazione e Creazione Oracle RAC Standby (tramite RMAN Duplicate)

> Questa fase copre la preparazione dei nodi standby (`racstby1`, `racstby2`) e la creazione del database standby fisico usando RMAN Duplicate from Active Database.

> 🛑 **PRIMA DI CONTINUARE: CONNETTITI VIA MOBAXTERM!**
> Questa fase, come la Fase 2, richiede uso continuo di shell + GUI Oracle (`gridSetup.sh`, `runInstaller`) e copia/incolla preciso dei comandi.
>
> **Tabella IP di Riferimento (Rete Pubblica):**
> - `rac1`: 192.168.56.101
> - `rac2`: 192.168.56.102
> - `racstby1`: 192.168.56.111
> - `racstby2`: 192.168.56.112

### 📸 Riferimenti Visivi

![Architettura Data Guard RAC Primary → RAC Standby](./images/dataguard_architecture.png)

### Cosa Succede in Questa Fase

```
  PRIMA                                           DOPO
  ═════                                           ════

┌─────────────┐                          ┌─────────────┐
│ RAC PRIMARY │                          │ RAC PRIMARY │
│   RACDB     │                          │   RACDB     │
│ ┌────┐┌────┐│                          │ ┌────┐┌────┐│
│ │DB1 ││DB2 ││                          │ │DB1 ││DB2 ││
│ └────┘└────┘│                          │ └────┘└────┘│
│ rac1  rac2  │                          │ rac1  rac2  │
└─────────────┘                          └──────┬──────┘
                                                │ Redo Shipping
                                                │ (LGWR ASYNC)
┌─────────────┐                                 ▼
│ RAC STANDBY │   RMAN Duplicate     ┌──────────────────┐
│  (vuoto)    │  ═══════════════►    │ RAC STANDBY      │
│ Grid + SW   │   Copia DB via       │ RACDB_STBY       │
│ NO database │   rete in tempo      │ ┌────┐ ┌────┐   │
│ racstby1/2  │   reale!             │ │DB1 │ │DB2 │   │
└─────────────┘                      │ └────┘ └────┘   │
                                     │ in tempo reale   │
                                     └──────────────────┘
```

### Ordine di Installazione in Questa Fase (stile Fase 2)

```text
Passo 1:  Golden Image clone standby        ━━━━━━━━━━━━━━━━━━━▶ racstby1/racstby2 pronti
Passo 2:  Rete + hostname + fix systemd     ━━━━━━━━━━━━━━━━━━━▶ nodi stabili e raggiungibili
Passo 3:  ASM dischi standby                ━━━━━━━━━━━━━━━━━━━▶ CRS/DATA/RECO visibili
Passo 4:  Grid Infrastructure standby       ━━━━━━━━━━━━━━━━━━━▶ cluster standby online
Passo 5:  Patch Grid RU                     ━━━━━━━━━━━━━━━━━━━▶ allineamento con primario
Passo 6:  DB Home Software Only             ━━━━━━━━━━━━━━━━━━━▶ motore DB installato
Passo 7:  Patch DB Home RU + OJVM           ━━━━━━━━━━━━━━━━━━━▶ home standby allineata
Passo 8:  Config DG network/listener/TNS    ━━━━━━━━━━━━━━━━━━━▶ connettivita primaria-standby
Passo 9:  RMAN Duplicate Active Database    ━━━━━━━━━━━━━━━━━━━▶ RACDB_STBY creato
Passo 10: OCR registration + MRP apply      ━━━━━━━━━━━━━━━━━━━▶ standby sincronizzato
```

### Percorso da seguire in pratica

1. **Percorso consigliato (default):** esegui la sezione `3.0B` (Golden Image) e poi continua da `3.1`.
2. **Percorso alternativo:** usa `3.0A` solo se lo standby era già stato preparato in Fase 2 e devi fare solo smoke-check.

---

## 3.0A Percorso Alternativo: Se hai già preparato lo Standby in Fase 2

Se durante la Fase 2 hai già installato anche su `racstby1`/`racstby2`:

- Grid Infrastructure
- disk group `+DATA` e `+RECO`
- DB Home software only (senza DBCA)
- patch RU/OJVM su Grid e DB Home

allora **non rifare** la sezione 3.0B. Esegui solo questo smoke-check e poi vai direttamente a `3.2`.

```bash
# Come grid su racstby1
crsctl check cluster -all
olsnodes -n
asmcmd lsdg

# Verifica patch Grid su entrambi i nodi
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/OPatch/opatch lspatches
ssh racstby2 "export ORACLE_HOME=/u01/app/19.0.0/grid; \$ORACLE_HOME/OPatch/opatch lspatches"

# Verifica patch DB Home su entrambi i nodi
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatch lspatches
ssh racstby2 "export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1; \$ORACLE_HOME/OPatch/opatch lspatches"

# Verifica che NON esista un database standby gia creato
srvctl config database -d RACDB_STBY
# Se non esiste ancora, e normale in questa fase.
```

---

## 3.0B Percorso Consigliato (Default): Creazione Macchine Standby da Golden Image

Questo è il percorso principale della Fase 3. Prima di poter configurare Data Guard, devi **costruire fisicamente** il cluster Standby. Come spiegato in Fase 0, **non re-installare Linux da zero**. Usa `rac1` (esattamente allo stato post-Fase 1, prima di installare Grid) come tua **Golden Image**.

### Step 1: Clona le Macchine dalla Golden Image
1. Assicurati che `rac1` sia spento.
2. Apri **VirtualBox Manager**, fai clic sulla VM `rac1`, vai nella sezione "Istantanee" (Snapshots), seleziona `SNAP-04_Prerequisiti_Cloni_Pronti` e clicca su **Clona**. *(Devi partire da questo esatto snapshot, NON dallo stato attuale o da snapshot successivi!)*
3. Nome: `racstby1` -> Seleziona **Genera nuovi indirizzi MAC** -> Clonazione completa.
4. Ripeti l'operazione per creare `racstby2` (clonando sempre da `rac1`).
5. Assegna a `racstby1` e `racstby2` i 5 dischi condivisi fittizi creati per lo standby (`asm-stby-crs1`, `asm-stby-crs2`, ecc.).

### Step 2: Modifica IP e Hostname
Accendi **UNA VM ALLA VOLTA** (dalla console nera di VirtualBox, non usare MobaXterm ancora) ed esegui queste modifiche:

**Su `racstby1`:**
- `hostnamectl set-hostname racstby1.localdomain`
- Lancia `nmtui` e cambia Scheda Pubblica a **`192.168.56.111`**
- Lancia `nmtui` e cambia Scheda Privata (Interconnect) a **`192.168.2.111`** (Attenzione, rete 2.x!)
- Riavvia (`reboot`)

**Su `racstby2`:**
- `hostnamectl set-hostname racstby2.localdomain`
- Lancia `nmtui` e cambia Scheda Pubblica a **`192.168.56.112`**
- Lancia `nmtui` e cambia Scheda Privata (Interconnect) a **`192.168.2.112`**
- Riavvia (`reboot`)

> Se in `nmtui` non vedi il profilo `enp0s9` (oppure `nmcli ... | grep ':enp0s9'` non restituisce nulla), crea il profilo manualmente:
```bash
# racstby1
nmcli con add type ethernet ifname enp0s9 con-name stby-interconnect \
  ipv4.method manual ipv4.addresses 192.168.2.111/24 \
  ipv4.never-default yes ipv6.method ignore connection.autoconnect yes
nmcli con up stby-interconnect

# racstby2
nmcli con add type ethernet ifname enp0s9 con-name stby-interconnect \
  ipv4.method manual ipv4.addresses 192.168.2.112/24 \
  ipv4.never-default yes ipv6.method ignore connection.autoconnect yes
nmcli con up stby-interconnect

# verifica
ip -4 addr show enp0s9
```

### Step 2b: Applicare il Fix Systemd (CRITICO!)
Anche se le VM sono clonate, è bene assicurarsi che il fix per il bug IPC di Oracle Linux 7 sia applicato. Fallo su **entrambi** i nodi standby come `root`:
```bash
echo "RemoveIPC=no" >> /etc/systemd/logind.conf
systemctl restart systemd-logind
```

### Step 3: Inizializzazione Dischi ASM per lo Standby (SOLO su `racstby1`)
I 5 nuovi dischi che hai assegnato in VirtualBox sono "vergini". Devi partizionarli e renderli dischi ASMLib, esattamente come hai fatto in Fase 0 e Fase 2 per il primario.

1. **Partizionamento base:** Usa MobaXterm collegandoti a `racstby1` come `root`.
   Esegui `fdisk` per `/dev/sdc`, `/dev/sdd`, `/dev/sde`, `/dev/sdf`, `/dev/sdg`.
   La sequenza per ognuno è sempre: `n`, `p`, `1`, `Invio`, `Invio`, `w`.
   Infine lancia `partprobe`.

2. **Creazione Dischi ASM (Sempre su `racstby1` come `root`):**
   ```bash
   oracleasm createdisk CRS1 /dev/sdc1
   oracleasm createdisk CRS2 /dev/sdd1
   oracleasm createdisk CRS3 /dev/sde1
   oracleasm createdisk DATA /dev/sdf1
   oracleasm createdisk RECO /dev/sdg1
   
   oracleasm scandisks
   oracleasm listdisks
   ```

3. **Verifica su `racstby2` (come `root`):**
   ```bash
   oracleasm scandisks
   oracleasm listdisks
   ```
   *Se vedi i 5 dischi anche qui, lo storage condiviso dello standby è pronto!*

### Step 4: Installazione e Patching Grid e Database (Fase 2 Adattata per Standby)

Ora che i nodi standby esistono, la rete funziona e i dischi ASMLib sono pronti, dobbiamo ricreare l'infrastruttura Oracle. **Eseguiamo ESATTAMENTE i passaggi robusti che abbiamo usato sul primario**, adattando i nomi per lo standby.

#### 4.1 Preparazione Binari e Prerequisiti
1. **Scompatta Grid (`racstby1`)**:
   ```bash
   su - grid
   unzip -q /tmp/LINUX.X64_193000_grid_home.zip -d /u01/app/19.0.0/grid
   ```
2. **Setup CVU Disk (`racstby1` e `racstby2` come root)**:
   ```bash
   # racstby1
   rpm -ivh /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm
   scp /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm root@racstby2:/tmp/
   # racstby2
   ssh racstby2 "rpm -ivh /tmp/cvuqdisk-1.0.10-1.rpm"
   ```
3. **Pointers Inventory (`racstby1` e `racstby2` come root)**:
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
4. **Pulizia Reti Fantasma (`racstby1` e `racstby2` come root)**:
```bash
# ============================================================
# 1. ELIMINA virbr0 (bridge di libvirt/KVM — non serve a RAC)
# ============================================================
# virbr0 è creato dal demone libvirtd, che serve per gestire
# macchine virtuali KVM *dentro* la VM stessa.
# Nel nostro lab non faremo mai VM-in-VM, quindi lo disabilitiamo.

# Esegui su entrambi i nodi per non far fallire cluvfy
   # 1) Libvirt/virbr0: se non esiste e' gia OK
   systemctl disable --now libvirtd 2>/dev/null || true
   if ip link show virbr0 >/dev/null 2>&1; then
     ip link set virbr0 down
     brctl delbr virbr0 2>/dev/null || true
   else
     echo "virbr0 non presente: OK (nessuna azione)"
   fi

# Verifica: virbr0 non deve più comparire
ip addr show virbr0 2>&1
# Deve dire: "Device virbr0 does not exist."

# ============================================================
# 2. DISABILITA IPv6 SULLA NAT (enp0s3)
# ============================================================
# L'IPv6 auto-configurato sulla NAT di VirtualBox genera indirizzi
# IPv6 diversi su ogni VM, ma NON sono raggiungibili tra di loro
# perché la NAT è isolata. Cluvfy prova a fare ping IPv6 e fallisce.
echo "net.ipv6.conf.enp0s3.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

# Verifica: enp0s3 non deve più mostrare indirizzi "inet6"
ip -6 addr show enp0s3
# Deve essere vuoto o mostrare solo link-local

# ============================================================
# (OPZIONALE) NOTA SULL'INTERFACCIA NAT (enp0s3)
# ============================================================
# L'interfaccia enp0s3 (10.0.2.15) serve per dare internet alla
# VM (download pacchetti, yum update). NON la disabilitiamo
# perché ci serve, ma cluvfy darà comunque un WARNING perché
# entrambe le VM hanno lo stesso IP 10.0.2.15 sulla NAT.
# Questo WARNING è HARMLESS: Oracle non userà mai questa rete.

   sysctl --system | grep -E "enp0s3.disable_ipv6|Applying"

   # 3) Verifica rete cluster
   ip -4 addr show enp0s8
   ip -4 addr show enp0s9
   ip -6 addr show enp0s3
    ```
   > Se `enp0s9` non mostra un IPv4 (`192.168.2.111` su `racstby1`, `192.168.2.112` su `racstby2`), configura subito l'interconnect con `nmtui` prima di proseguire con `cluvfy`.

#### 4.1a User Equivalence SSH (OBBLIGATORIO) - `grid`, `oracle`, `root`

L'errore `PRVG-2019` durante `cluvfy` indica che la trust SSH non è pronta.
Configura l'equivalenza utenti su **entrambi i nodi** per tutte le utenze operative:
Per reset completo e troubleshooting (Permission denied, Host key verification failed), vedi anche: [GUIDA_SSH_KEYS_RAC](./GUIDA_SSH_KEYS_RAC.md).

```bash
# Step 0 (opzionale) reset totale chiavi su entrambi i nodi
rm -rf /home/grid/.ssh
rm -rf /home/oracle/.ssh
rm -rf /root/.ssh
```

Generazione chiavi su entrambi i nodi:

```bash
su - grid   -c "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"
su - oracle -c "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"
su - root   -c "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"
```

Scambio chiavi manuale (trust bidirezionale):

```bash
# Per grid
# da racstby1
su - grid -c "ssh-copy-id grid@racstby1"
su - grid -c "ssh-copy-id grid@racstby2"
# da racstby2
su - grid -c "ssh-copy-id grid@racstby1"
su - grid -c "ssh-copy-id grid@racstby2"

# Per oracle
# da racstby1
su - oracle -c "ssh-copy-id oracle@racstby1"
su - oracle -c "ssh-copy-id oracle@racstby2"
# da racstby2
su - oracle -c "ssh-copy-id oracle@racstby1"
su - oracle -c "ssh-copy-id oracle@racstby2"

# Per root
# da racstby1
su - root -c "ssh-copy-id root@racstby1"
su - root -c "ssh-copy-id root@racstby2"
# da racstby2
su - root -c "ssh-copy-id root@racstby1"
su - root -c "ssh-copy-id root@racstby2"
```

Verifica finale (deve entrare senza password):

```bash
su - grid   -c "ssh racstby1 hostname"
su - grid   -c "ssh racstby2 hostname"
su - oracle -c "ssh racstby1 hostname"
su - oracle -c "ssh racstby2 hostname"
su - root   -c "ssh racstby1 hostname"
su - root   -c "ssh racstby2 hostname"
```

#### 4.1b Pre-Grid: Blocco sincronizzazione host + hardening Chrony (OBBLIGATORIO)

Prima di installare Grid sullo standby, blocca la sincronizzazione oraria imposta dall'hypervisor e lascia il controllo del tempo a `chronyd`.

Perche:
1. `chronyd` sincronizza la VM con NTP.
2. VirtualBox Guest Additions puo forzare il clock guest al reboot.
3. I salti orari fanno fallire i check NTP di `cluvfy` e possono sporcare il pre-check Grid.

VirtualBox-first su `racstby1` e `racstby2` (come `root`):

```bash
# Disabilita i servizi VBox che possono forzare il clock guest
if systemctl list-unit-files | grep -q '^vboxadd-service.service'; then
  systemctl disable --now vboxadd-service
fi

if systemctl list-unit-files | grep -q '^vboxservice.service'; then
  systemctl disable --now vboxservice
fi

# Verifica (se non esistono e normale)
systemctl is-enabled vboxadd-service 2>/dev/null || true
systemctl is-active vboxadd-service 2>/dev/null || true
systemctl is-enabled vboxservice 2>/dev/null || true
systemctl is-active vboxservice 2>/dev/null || true
```

Nota rapida altri hypervisor:
- VMware: disattiva "Synchronize guest time with host" nelle opzioni VM.
- Proxmox/KVM: disabilita il time sync guest-side equivalente, poi usa solo `chronyd`.

Hardening Chrony su `racstby1` e `racstby2` (come `root`):

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

Test persistenza al reboot (obbligatorio su entrambi i nodi):

```bash
reboot
```

Dopo il login:

```bash
# Verifica che VBox time sync resti disattivo
systemctl is-active vboxadd-service 2>/dev/null || true
systemctl is-active vboxservice 2>/dev/null || true

# Verifica sync Chrony
chronyc sources -v
chronyc tracking
timedatectl
```

Criterio PASS/FAIL:
- PASS: `chronyc tracking` mostra `Leap status     : Normal`.
- PASS: `chronyc sources -v` mostra almeno una sorgente valida (`*` o `+`).
- FAIL: `Leap status : Not synchronised` su uno dei due nodi.

Gate di avanzamento:
- vai alla sezione `4.1c` e poi `4.2` solo quando entrambi i nodi sono sincronizzati;
- warning NAT duplicata `10.0.2.15` su `enp0s3` e benigno nel lab VirtualBox.

#### 4.1c Pre-check cluvfy (stesso standard della Fase 2)

```bash
# Su racstby1 come grid
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/runcluvfy.sh stage -pre crsinst -n racstby1,racstby2 -verbose -method root
```

Se non usi `-method root`, vedrai `PRVG-11250` (RPM check non eseguito): e solo informativo.

Interpretazione output (allineata alla Fase 2):

| Errore | Tipo | Azione |
|---|---|---|
| `PRVF-7530` (Physical Memory < 8GB) | Warning | In lab puoi procedere; opzionale aumentare RAM a 9 GB |
| `PRVG-1172` / `PRVG-11067` su `10.0.2.15` (`enp0s3`) | Warning | NAT duplicata VirtualBox: ignorabile se `enp0s3` e `Do Not Use` in installer |
| `PRVG-13606` (chrony non sync) | Errore da chiudere | Torna a `4.1b`, verifica `makestep 1.0 3`, sincronizza e rilancia cluvfy |
| `PRVG-11250` (RPM DB check) | Info | Ignora o rilancia con `-method root` |
| `PRVG-2019` (User Equivalence) | Errore reale | Correggi SSH (`4.1a`) prima di continuare |

Se compare `PRVG-13606`, non proseguire con l'installer: chiudi prima la sincronizzazione tempo in `4.1b` e rilancia `runcluvfy.sh`.

#### 4.2 Installazione Grid Infrastructure (GUI)

Avvia `gridSetup.sh` su `racstby1` (come `grid`, via MobaXterm con X11). Segui i passi, prestando attenzione a queste **differenze fondamentali** per lo standby:

| Parametro Installer | Valore per lo Standby |
|---|---|
| Cluster Name | `racstby-cluster` |
| SCAN Name | `racstby-scan.localdomain` |
| Nodo 1 | `racstby1.localdomain` / VIP: `racstby1-vip.localdomain` |
| Nodo 2 | `racstby2.localdomain` / VIP: `racstby2-vip.localdomain` |

> ⚠️ **Allo Step 5 (Network Interface Usage)**, usa la stessa configurazione: `enp0s8` (Pubblica), `enp0s9` (ASM & Private - 192.168.2.0), `enp0s3` (Do Not Use).
>
> 🛑 **Allo Step 8 (ASM Disk Group 'CRS') RICORDA IL WORKAROUND ASMLIB:**
> Cambia il Discovery Path in `/dev/oracleasm/disks/*`. Seleziona SOLO `CRS1`, `CRS2`, `CRS3`.

Procedi fino in fondo. In schermata Prerequisite puoi ignorare warning su RAM e NAT (`enp0s3`).  
Non ignorare errori reali su SSH equivalence, discovery ASM o chrony sync.
Esegui gli script **COME ROOT** su `racstby1` (`orainstRoot.sh`, poi `root.sh`), e attendi la fine prima di farli su `racstby2`.

Verifica immediata post-installazione:

```bash
# Come grid su racstby1
crsctl check cluster -all
olsnodes -n
asmcmd lsdg
```

#### 4.3 Creazione Disk Group DATA e RECO (Standby)
Dopo che il cluster è online, crea i disk group per lo standby via `asmca` o SQL:
```sql
-- Su racstby1 come grid (sqlplus / as sysasm)
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY DISK '/dev/oracleasm/disks/DATA' ATTRIBUTE 'compatible.asm'='19.0', 'compatible.rdbms'='19.0';
CREATE DISKGROUP RECO EXTERNAL REDUNDANCY DISK '/dev/oracleasm/disks/RECO' ATTRIBUTE 'compatible.asm'='19.0', 'compatible.rdbms'='19.0';
```
> **NOTA BENE**: I disk group si chiamano ESATTAMENTE come sul primario (`+DATA`, `+RECO`). Questo è fondamentale per l'RMAN Duplicate!

#### 4.4 Patching Grid Infrastructure (Combo Patch) sullo Standby

> **Perché patchare?** Oracle 19c base (19.3) è la versione iniziale rilasciata nel 2019. Le Release Update (RU) contengono fix di sicurezza, bug fix e miglioramenti di stabilità. In produzione, patchare è **obbligatorio**. Nel lab, ti insegna il processo che userai nel mondo reale.

I patch che ti servono (già presenti nei tuoi download):

| Patch | Descrizione | Dove si Applica |
|---|---|---|
| **p6880880** | **OPatch** (utility per applicare patch) | Sostituisci in ogni ORACLE_HOME |
| **p38658588** | **Combo Patch (GI RU + OJVM RU)** — Jan 2026 | Grid Home + DB Home |

### Step 1: Aggiorna OPatch nella Grid Home

OPatch è lo strumento che applica le patch. La versione fornita con il software base 19.3 è troppo vecchia. Devi aggiornarla PRIMA di applicare qualsiasi patch.

```bash
# ⚠️ Come ROOT su racstby1 (la directory OPatch ha owner root dopo l'installazione!)
su - root

# Backup del vecchio OPatch
mv /u01/app/19.0.0/grid/OPatch /u01/app/19.0.0/grid/OPatch.bkp.$(date +%Y%m%d)

# Scompatta il nuovo OPatch
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.0.0/grid/

# Rimetti i permessi corretti all'utente grid
chown -R grid:oinstall /u01/app/19.0.0/grid/OPatch

# Verifica la versione (torna a grid)
su - grid
$ORACLE_HOME/OPatch/opatch version
# Deve mostrare: OPatch Version: 12.2.0.1.48 (o superiore per patch Gennaio 2026)
```

```bash
# Ripeti su racstby2 (sempre come root!)
ssh racstby2
su - root
mv /u01/app/19.0.0/grid/OPatch /u01/app/19.0.0/grid/OPatch.bkp.$(date +%Y%m%d)
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.0.0/grid/
chown -R grid:oinstall /u01/app/19.0.0/grid/OPatch
su - grid
$ORACLE_HOME/OPatch/opatch version
```

### Step 2: Scompatta la Combo Patch

> ⚠️ **ATTENZIONE**: NON scompattare la patch in `/tmp`! Nelle nostre VM, `/tmp` è un disco RAM (tmpfs) di soli 4GB. La patch estratta occupa più di 3GB, riempendo `/tmp` al 100% e bloccando il nodo. Usa sempre `/u01` che ha 50GB di spazio!

```bash
# Scompatta su racstby1 (come root)
mkdir -p /u01/app/patch
cd /u01/app/patch
unzip -q /tmp/p38658588_190000_Linux-x86-64.zip
chown -R grid:oinstall /u01/app/patch

# Identifica gli ID delle RU all'interno della Combo Patch:
ls -l /u01/app/patch/38658588
# Vedrai due cartelle numeriche: una per OJVM (38523609) e una per la vera e propria RU (38629535).
# Useremo il path 38629535 per opatchauto!

# Ripeti l'estrazione su racstby2!
ssh racstby2
mkdir -p /u01/app/patch
cd /u01/app/patch
unzip -q /tmp/p38658588_190000_Linux-x86-64.zip
chown -R grid:oinstall /u01/app/patch
exit
```

### Step 3: Applica la RU alla Grid Home con opatchauto

> ⚠️ **Best Practice Oracle (MOS 2632107.1)**: Prima di applicare qualsiasi patch, esegui SEMPRE:
> 1. **Conflict check** — verifica che non ci siano conflitti con patch già applicate
> 2. **Space check** — verifica spazio disco sufficiente
> 3. **Backup dell'ORACLE_HOME** — per poter fare rollback in caso di problemi

```bash
# Come root su racstby1
su - root

# --- BEST PRACTICE 1: Verifica spazio disco (servono almeno 15 GB in /u01) ---
df -h /u01
# Se hai meno di 15 GB liberi, libera spazio prima di proseguire!

# --- BEST PRACTICE 2: Backup dell'ORACLE_HOME (per rollback) ---
tar czf /u01/app/grid_home_backup_$(date +%Y%m%d).tar.gz -C /u01/app/19.0.0 grid --exclude='*.log'

# --- BEST PRACTICE 3: Pre-check con opatchauto analyze (dry run senza applicare!) ---
cd /u01/app/patch/38658588/38629535
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME -analyze
# Sostituisci 38629535 con l'ID reale della RU che hai trovato nello step 2!
# Se mostra errori di conflitto, risolvili PRIMA di applicare!
# Se mostra "Patch analysis is complete" -> puoi proseguire.

# --- APPLICAZIONE VERA (solo dopo che analyze è OK) ---
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME
```

> **Perché opatchauto?** Per la Grid Infrastructure, non puoi usare il semplice `opatch apply`. Devi usare `opatchauto` (come root), che:
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
# Deve mostrare il numero del patch RU
```

```bash
# Ripeti su racstby2 come root
ssh racstby2
cd /u01/app/patch/38658588/38629535
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME

# Verifica
crsctl check crs
su - grid
$ORACLE_HOME/OPatch/opatch lspatches
```

#### 4.5 Installazione Software Database (Software Only)
```bash
# Scompatta su racstby1 come oracle
su - oracle
unzip -q /tmp/LINUX.X64_193000_db_home.zip -d $ORACLE_HOME

# Avvia l'installer (MobaXterm)
cd $ORACLE_HOME && ./runInstaller
```
Seleziona **Set Up Software Only** → **Oracle RAC database installation** (seleziona `racstby1` e `racstby2`) → **Enterprise Edition**.
Ignora gli script root automatici. Alla fine, esegui il `root.sh` proposto su `racstby1` e poi su `racstby2`.
**⚠️ NON USARE DBCA! NON CREARE IL DATABASE!** Ci serve solo il software (motore spento) perché i dati li cloneremo via rete.

#### 4.6 Patching Database Home (Combo Patch) sullo Standby

> [!IMPORTANT]
> **ORDINE DELLE OPERAZIONI**: Devi aggiornare l'utility OPatch **PRIMA** di lanciare `opatchauto apply`. Se provi ad applicare la RU di Gennaio 2026 con un OPatch vecchio (versione < 12.2.0.1.48), l'operazione fallirà.

### Step 1: Aggiorna OPatch nella DB Home

```bash
# ⚠️ Come ROOT su racstby1 (anche la DB Home OPatch può avere owner root dopo root.sh)
su - root

# Backup del vecchio OPatch
mv /u01/app/oracle/product/19.0.0/dbhome_1/OPatch /u01/app/oracle/product/19.0.0/dbhome_1/OPatch.bkp.$(date +%Y%m%d)

# Scompatta il nuovo OPatch
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/dbhome_1/

# Rimetti i permessi corretti all'utente oracle
chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1/OPatch

# Verifica (torna a oracle)
su - oracle
$ORACLE_HOME/OPatch/opatch version

# Ripeti su racstby2 (come root!)
ssh racstby2
su - root
mv /u01/app/oracle/product/19.0.0/dbhome_1/OPatch /u01/app/oracle/product/19.0.0/dbhome_1/OPatch.bkp.$(date +%Y%m%d)
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/dbhome_1/
chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1/OPatch
su - oracle
$ORACLE_HOME/OPatch/opatch version
```

### Step 2: Applica la RU alla DB Home

```bash
# Come root su racstby1
su - root

# Cambia ownership della patch directory a oracle, altrimenti opatchauto fallisce (OPATCHAUTO-72083)
chown -R oracle:oinstall /u01/app/patch

# Backup DB Home (Best Practice)
tar czf /u01/app/dbhome_backup_$(date +%Y%m%d).tar.gz -C /u01/app/oracle/product/19.0.0 dbhome_1 --exclude='*.log'

# Pre-check (dry run)
cd /u01/app/patch/38658588/38629535
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME -analyze

# Se analyze OK -> applica
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME
```

> **Nota**: `opatchauto` riconosce automaticamente che è una DB Home in un cluster RAC e gestisce il patching di conseguenza.

```bash
# Ripeti su racstby2
ssh racstby2 "chown -R oracle:oinstall /u01/app/patch"
ssh racstby2
cd /u01/app/patch/38658588/38629535
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME
```

### Step 3: Applica il Patch OJVM

Il patch OJVM è raggruppato all'interno della Combo Patch. Abbiamo già scompattato tutto allo Step 2 di Grid, quindi i file sono già pronti in `/u01/app/patch/38658588/`. Si applica con `opatch apply` standard puntando alla sottocartella OJVM.

```bash
# Come utente oracle su racstby1
su - oracle
cd /u01/app/patch/38658588/38523609   # Usa l'ID reale della cartella OJVM trovato prima
$ORACLE_HOME/OPatch/opatch apply

# Quando chiede "Is the local system ready for patching?" rispondi: y

# Ripeti su racstby2
ssh racstby2
su - oracle
cd /u01/app/patch/38658588/38523609
$ORACLE_HOME/OPatch/opatch apply
```

### Step 4: Verifica Patch Applicati e Pulizia

```bash
# Come oracle su racstby1
$ORACLE_HOME/OPatch/opatch lspatches
```

Output atteso:
```
38629535;Database Release Update : 19.x.0.0.xxxxxx
38523609;OJVM RELEASE UPDATE: 19.x.0.0.xxxxxx
```

```bash
# Verifica anche su racstby2
ssh racstby2
su - oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatch lspatches
```

Pulizia file patch:

```bash
# Come root su racstby1
rm -rf /u01/app/patch/*
rm -f /tmp/p*.zip

# Come root su racstby2
ssh racstby2 "rm -rf /u01/app/patch/* && rm -f /tmp/p*.zip"
```

A questo punto, l'infrastruttura Standby (motore Grid + RDBMS patchato) è identica al cluster Primario. Siamo pronti a connettere il database.

> Nota importante: in questa fase standby **non** devi eseguire `DBCA` e **non** devi eseguire `datapatch` sullo standby. Il dictionary patchato arrivera dal primario tramite redo dopo il duplicate.

---

## 3.1 Prerequisiti sui Nodi Standby

Per verificare di essere pronto per proseguire con Data Guard, fai questa check-list sui nodi standby:
- ✅ **Fase 1 completa** tramite clonazione (OS, DNS, utenti, SSH) su `racstby1` e `racstby2`.
- ✅ **Grid Infrastructure installata** (allineata ai passi Fase 2: 2.3-2.7) su `racstby1` e `racstby2`.
- ✅ **Patch Grid RU/OJVM applicate** (allineamento Fase 2: 2.8) e verificabili con `opatch lspatches`.
- ✅ **Software Database installato** (allineamento Fase 2: 2.9, solo Software Only, nessun DBCA).
- ✅ **Patch DB Home RU/OJVM applicate** (allineamento Fase 2: 2.11) e verificabili con `opatch lspatches`.
- ✅ I Disk Group **DATA** e **RECO** esistono sullo standby con gli stessi nomi del primario e discovery path `/dev/oracleasm/disks/*`.
- ✅ Nessun database standby creato via DBCA; verrà creato solo via RMAN Duplicate.

> **Perché stessi nomi dei Disk Group?** RMAN Duplicate cerca i disk group per nome. Se sul primario i datafile sono in `+DATA` e sullo standby non esiste `+DATA`, il duplicate fallisce.

---

## 3.2 Configurazione Listener Statico sul Primario

Il Listener dinamico (registrato da PMON) non è sufficiente per Data Guard. Dobbiamo aggiungere un'entry **statica** perché il database standby deve potersi connettere anche quando l'istanza primaria non è completamente aperta.

### Sul Primario (`rac1`, come utente `grid`)

```bash
su - grid
vi $ORACLE_HOME/network/admin/listener.ora
```

Aggiungi alla fine:

```
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = RACDB_DGMGRL)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = RACDB1)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = RACDB)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = RACDB1)
    )
  )
```

Fai lo stesso su `rac2` cambiando `SID_NAME = RACDB2`.

```bash
# Riavvia il listener
srvctl stop listener
srvctl start listener

# Verifica
lsnrctl status
# Deve mostrare le entry statiche
```

> **Perché il Listener Statico?** Quando il database è in mount (non aperto), il servizio PMON non fa la registrazione dinamica con il listener. Ma Data Guard ha bisogno di connettersi al database in mount per applicare i redo. Il listener statico risolve questo problema.

---

## 3.3 Configurazione Listener Statico sullo Standby

### Su `racstby1` (come utente `grid`)

```bash
su - grid
vi $ORACLE_HOME/network/admin/listener.ora
```

Aggiungi:

```
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = RACDB_STBY_DGMGRL)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = RACDB1)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = RACDB_STBY)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = RACDB1)
    )
  )
```

Stesso su `racstby2` con `SID_NAME = RACDB2`.

```bash
srvctl stop listener
srvctl start listener
```

---

## 3.4 Configurazione TNS Names

Il file `tnsnames.ora` deve essere identico su **TUTTI** i nodi (primario e standby).

### Sul Primario e Standby (`$ORACLE_HOME/network/admin/tnsnames.ora`, come utente `oracle`)

```bash
su - oracle
cat > $ORACLE_HOME/network/admin/tnsnames.ora <<'EOF'
RACDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = RACDB)
    )
  )

RACDB_STBY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = racstby-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = RACDB_STBY)
      (UR=A)
    )
  )

# Alias dedicati al REDO TRANSPORT Data Guard (best practice RAC)
# Usali in LOG_ARCHIVE_DEST_n e FAL
RACDB_DG =
  (DESCRIPTION =
    (FAILOVER=ON)
    (LOAD_BALANCE=OFF)
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = rac1.localdomain)(PORT = 1521))
      (ADDRESS = (PROTOCOL = TCP)(HOST = rac2.localdomain)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = RACDB)
      (UR=A)
    )
  )

RACDB_STBY_DG =
  (DESCRIPTION =
    (FAILOVER=ON)
    (LOAD_BALANCE=OFF)
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = racstby1.localdomain)(PORT = 1521))
      (ADDRESS = (PROTOCOL = TCP)(HOST = racstby2.localdomain)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = RACDB_STBY)
      (UR=A)
    )
  )

RACDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac1.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = RACDB1)
    )
  )

RACDB2 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac2.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = RACDB2)
    )
  )

RACDB1_STBY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = racstby1.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = RACDB1)
      (UR=A)
    )
  )

RACDB2_STBY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = racstby2.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = RACDB2)
      (UR=A)
    )
  )
EOF
```

> **Best practice Oracle RAC**:
> - alias cluster (`RACDB`, `RACDB_STBY`) via **SCAN** per accesso client e amministrazione generale;
> - alias dedicati al trasporto redo (`RACDB_DG`, `RACDB_STBY_DG`) con `ADDRESS_LIST` su tutti i nodi per robustezza di Data Guard.
>
> Questo approccio ibrido evita single point of failure e riduce errori tipo `ORA-12514` durante restart/failover nodo.
>
> In pratica:
> - SCAN = ingresso "front door" del cluster;
> - alias `_DG` = canale redo/FAL resiliente con piu indirizzi.

### Mappa alias (quando usare cosa)

- `RACDB`, `RACDB_STBY`: connessioni client/app e amministrazione generale (SCAN).
- `RACDB_DG`, `RACDB_STBY_DG`: redo transport (`LOG_ARCHIVE_DEST_n`) e gap resolution (`FAL_SERVER`).
- `RACDB1`, `RACDB2`, `RACDB1_STBY`, `RACDB2_STBY`: connessioni istanza-specifiche (RMAN duplicate, troubleshooting mirato).

> **Perché tnsnames.ora identico ovunque?** Data Guard usa questi alias TNS per comunicare tra primario e standby. Se manca un'entry su un nodo, il redo shipping fallisce.

> **Cos'è `(UR=A)`?** "Use Role = Any" — permette la connessione anche quando il database è in stato NOMOUNT o MOUNT (non solo OPEN). Essenziale per lo standby che non è mai in READ WRITE. Senza `UR=A`, `tnsping` funziona ma `sqlplus sys@RACDB_STBY as sysdba` fallisce con timeout.

### Test Connettività TNS

```bash
# Da rac1 verso lo standby
tnsping RACDB1_STBY
tnsping RACDB_STBY
tnsping RACDB_STBY_DG

# Da racstby1 verso il primario
tnsping RACDB1
tnsping RACDB
tnsping RACDB_DG
```

```bash
# Test SQL reale (piu affidabile di tnsping)
sqlplus 'sys/<password>@RACDB_STBY as sysdba'
sqlplus 'sys/<password>@RACDB_STBY_DG as sysdba'
sqlplus 'sys/<password>@RACDB as sysdba'
sqlplus 'sys/<password>@RACDB_DG as sysdba'
```

### Riferimenti Oracle ufficiali (best practice rete/redo transport)

- Data Guard Concepts and Administration 19c (redo transport services):
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-transport-services.html
- Data Guard Broker 19c (RAC best practices per `LOG_ARCHIVE_DEST_n` e net service):
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/data-guard-broker.pdf
- Oracle RAC (SCAN per connessioni client):
  https://docs.oracle.com/en/database/oracle/oracle-database/19/rilin/about-the-scan.html
- Oracle RAC (connessioni via SCAN):
  https://docs.oracle.com/en/database/oracle/oracle-database/21/rilin/about-connecting-to-an-oracle-rac-database-using-scans.html
- Oracle MAA 19c (configure/deploy Data Guard):
  https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/configure-and-deploy-oracle-data-guard.html
- Oracle Data Guard 19c (creazione Physical Standby con RMAN duplicate):
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/creating-oracle-data-guard-physical-standby.html

---

## 3.5 Configurazione del Primario per Data Guard

```sql
-- Connettiti al primario come sysdba
sqlplus / as sysdba

-- 1. Verifica Force Logging (già fatto in Fase 2)
SELECT force_logging FROM v$database;

-- 2. Configura Standby Redo Logs
-- Regola: N. di Standby Redo Log Groups = (N. Online Redo Log Groups + 1) PER THREAD
-- Se hai 3 online redo log groups per thread, crea 4 standby redo log groups per thread

-- Verifica quanti online redo log groups hai
SELECT thread#, group#, bytes/1024/1024 size_mb FROM v$log ORDER BY thread#, group#;

-- Crea Standby Redo Logs (esempio: 3 ORL per thread -> 4 SRL per thread)
-- Thread 1 (rac1)
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1
  GROUP 11 ('+DATA') SIZE 200M,
  GROUP 12 ('+DATA') SIZE 200M,
  GROUP 13 ('+DATA') SIZE 200M,
  GROUP 14 ('+DATA') SIZE 200M;

-- Thread 2 (rac2)
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2
  GROUP 21 ('+DATA') SIZE 200M,
  GROUP 22 ('+DATA') SIZE 200M,
  GROUP 23 ('+DATA') SIZE 200M,
  GROUP 24 ('+DATA') SIZE 200M;

-- Verifica
SELECT group#, thread#, bytes/1024/1024 size_mb, status FROM v$standby_log;
```

> **Perché i Standby Redo Logs?** Quando i redo log arrivano dal primario, lo standby li scrive prima negli Standby Redo Logs e POI li applica. Senza SRL, usa gli archived redo logs, che sono più lenti. La regola "+1" garantisce che ci sia sempre uno SRL disponibile anche durante un log switch.

```sql
-- 3. Imposta i parametri Data Guard
ALTER SYSTEM SET log_archive_config='DG_CONFIG=(RACDB,RACDB_STBY)' SCOPE=BOTH SID='*';

ALTER SYSTEM SET log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=RACDB' SCOPE=BOTH SID='*';

ALTER SYSTEM SET log_archive_dest_2='SERVICE=RACDB_STBY_DG LGWR ASYNC REOPEN=15 VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB_STBY' SCOPE=BOTH SID='*';

ALTER SYSTEM SET log_archive_dest_state_1=ENABLE SCOPE=BOTH SID='*';
ALTER SYSTEM SET log_archive_dest_state_2=ENABLE SCOPE=BOTH SID='*';

ALTER SYSTEM SET fal_server='RACDB_STBY_DG' SCOPE=BOTH SID='*';
ALTER SYSTEM SET fal_client='RACDB' SCOPE=BOTH SID='*';

ALTER SYSTEM SET standby_file_management=AUTO SCOPE=BOTH SID='*';

ALTER SYSTEM SET db_file_name_convert='+DATA/RACDB_STBY/','+DATA/RACDB/' SCOPE=SPFILE SID='*';
ALTER SYSTEM SET log_file_name_convert='+DATA/RACDB_STBY/','+DATA/RACDB/','+FRA/RACDB_STBY/','+FRA/RACDB/' SCOPE=SPFILE SID='*';
```

```sql
-- Verifica operativa subito dopo il settaggio
SELECT dest_id, status, target, valid_role, error
FROM   v$archive_dest
WHERE  dest_id IN (1,2)
ORDER  BY dest_id;

-- Se db_file_name_convert/log_file_name_convert sono SCOPE=SPFILE,
-- verifica il valore su SPFILE (non solo in memoria)
SELECT name, value
FROM   v$spparameter
WHERE  name IN ('db_file_name_convert','log_file_name_convert')
AND    value IS NOT NULL;
```

> **Atteso in questa fase (pre-duplicate):**
> - se lo standby non e ancora in piedi con istanza disponibile, `DEST_ID=2` puo mostrare `ERROR` con `ORA-01034` oppure `ORA-12514`;
> - non e un blocco, e normale finche non completi `3.9` (startup standby) e `3.10` (RMAN duplicate).
>
> **Gate corretto:**
> - **prima** del duplicate: `DEST_ID=1=VALID`, `DEST_ID=2` puo essere `ERROR`;
> - **dopo** duplicate + apply attivo: `DEST_ID=2` deve diventare `VALID` con `ERROR` nullo.
>
> **Best practice Oracle:** sullo standby non usare DBCA in questo flusso; il database standby si crea con `RMAN DUPLICATE ... FOR STANDBY FROM ACTIVE DATABASE`.

```sql
-- Re-check obbligatorio post-duplicate (quando standby e in MOUNT + apply)
SELECT dest_id, status, target, valid_role, error
FROM   v$archive_dest
WHERE  dest_id IN (1,2)
ORDER  BY dest_id;
```

### Spiegazione dettagliata (comando per comando)

Questa e la spina dorsale di Data Guard: stai dicendo al primario chi e lo standby, dove spedire i redo e come comportarsi in caso di switchover/failover.

1. **Definizione perimetro Data Guard (`log_archive_config`)**
   - Comando:
   ```sql
   ALTER SYSTEM SET log_archive_config='DG_CONFIG=(RACDB,RACDB_STBY)' SCOPE=BOTH SID='*';
   ```
   - Cosa fa: autorizza solo i database con `DB_UNIQUE_NAME` `RACDB` e `RACDB_STBY` a partecipare alla configurazione.
   - Perche serve: evita spedizioni/accettazioni redo verso target non previsti.
   - Nota RAC: `SID='*'` applica il parametro a tutte le istanze (`rac1`, `rac2`).

2. **Destinazioni archivelog locale e remota (`log_archive_dest_1`/`_2`)**
   - Comandi:
   ```sql
   ALTER SYSTEM SET log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=RACDB' SCOPE=BOTH SID='*';
   ALTER SYSTEM SET log_archive_dest_2='SERVICE=RACDB_STBY_DG LGWR ASYNC REOPEN=15 VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB_STBY' SCOPE=BOTH SID='*';
   ```
   - `dest_1` locale: archivia sempre in FRA, sia in ruolo `PRIMARY` sia in ruolo `STANDBY`.
   - `dest_2` remota:
     - `SERVICE=RACDB_STBY_DG`: usa alias TNS dedicato al redo transport verso standby.
     - `LGWR ASYNC`: spedizione asincrona (modalita tipica `Maximum Performance`).
     - `REOPEN=15`: se il link cade, ritenta automaticamente ogni 15 secondi.
     - `VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE)`: invia redo solo quando questo DB e primario.

3. **Attivazione destinazioni (`log_archive_dest_state_n`)**
   - Comandi:
   ```sql
   ALTER SYSTEM SET log_archive_dest_state_1=ENABLE SCOPE=BOTH SID='*';
   ALTER SYSTEM SET log_archive_dest_state_2=ENABLE SCOPE=BOTH SID='*';
   ```
   - Cosa fa: abilita operativamente le destinazioni appena definite.
   - Se resta `DEFER`, la configurazione e corretta ma la spedizione non parte.

4. **Gestione gap redo (`fal_server` / `fal_client`)**
   - Comandi:
   ```sql
   ALTER SYSTEM SET fal_server='RACDB_STBY_DG' SCOPE=BOTH SID='*';
   ALTER SYSTEM SET fal_client='RACDB' SCOPE=BOTH SID='*';
   ```
   - Cosa fa: prepara il meccanismo FAL (Fetch Archive Log) per recuperare automaticamente archivelog mancanti.
   - Perche anche sul primario: in caso di switchover i ruoli si invertono, quindi i parametri devono essere gia pronti.

5. **Creazione automatica file su standby (`standby_file_management=AUTO`)**
   - Comando:
   ```sql
   ALTER SYSTEM SET standby_file_management=AUTO SCOPE=BOTH SID='*';
   ```
   - Cosa fa: quando aggiungi datafile/tablespace sul primario, lo standby li gestisce automaticamente.
   - Rischio con `MANUAL`: apply puo fermarsi a ogni modifica strutturale.

6. **Conversione path file (`db_file_name_convert`, `log_file_name_convert`)**
   - Comandi:
   ```sql
   ALTER SYSTEM SET db_file_name_convert='+DATA/RACDB_STBY/','+DATA/RACDB/' SCOPE=SPFILE SID='*';
   ALTER SYSTEM SET log_file_name_convert='+DATA/RACDB_STBY/','+DATA/RACDB/','+FRA/RACDB_STBY/','+FRA/RACDB/' SCOPE=SPFILE SID='*';
   ```
   - Cosa fa: mappa i path ASM tra primario e standby per datafile/redofile quando cambia il ruolo.
   - Perche `SCOPE=SPFILE`: questi parametri sono statici e richiedono restart istanza per entrare in vigore.

### Check rapidi dopo la configurazione

```sql
SHOW PARAMETER log_archive_config;
SHOW PARAMETER log_archive_dest_1;
SHOW PARAMETER log_archive_dest_2;
SHOW PARAMETER fal_server;
SHOW PARAMETER fal_client;
SHOW PARAMETER standby_file_management;
SHOW PARAMETER db_file_name_convert;
SHOW PARAMETER log_file_name_convert;
```

```sql
SELECT DEST_ID, STATUS, TARGET, VALID_ROLE, ERROR
FROM   V$ARCHIVE_DEST
WHERE  DEST_ID IN (1,2)
ORDER  BY DEST_ID;
```

### Come Funziona il Redo Shipping

```
PRIMARIO (RACDB)                              STANDBY (RACDB_STBY)
════════════════                              ═════════════════════

Utente fa COMMIT
     │
     ▼
┌──────────┐                                  
│  LGWR    │──── Scrive ───►┌──────────────┐  
│          │                │ Online Redo  │  
│          │                │ Log (locale) │  
│          │                └──────┬───────┘  
│          │                       │          
│          │── Spedisce ──────────────────────►┌──────────────┐
│          │   (ASYNC via rete)               │ Standby Redo │
└──────────┘                                  │ Log (SRL)    │
                                              └──────┬───────┘
                                                     │
                                                     ▼
                                              ┌──────────────┐
                                              │  MRP (Managed│
                                              │  Recovery    │
                                              │  Process)    │
                                              │              │
                                              │  Applica i   │
                                              │  redo ai     │
                                              │  datafile    │
                                              └──────────────┘
```

### Spiegazione scritta (passo-passo)

1. Sul primario, quando un utente fa `COMMIT`, il processo `LGWR` scrive prima nei redo log locali.
2. Con `LOG_ARCHIVE_DEST_2` attivo, lo stesso redo viene spedito allo standby usando il net service (`RACDB_STBY_DG`).
3. Sullo standby, il redo in arrivo non va subito nei datafile: entra prima negli `Standby Redo Log` (SRL).
4. Il processo `MRP` (Managed Recovery Process) legge gli SRL e applica le modifiche ai datafile standby.
5. Finche `MRP` e attivo (`APPLYING_LOG`), lo standby resta allineato al primario con lag minimo.

In questa guida usiamo `LGWR ASYNC` (modalita `Maximum Performance`):
- il primario non aspetta l'ack dello standby prima di confermare il commit;
- massime prestazioni, ma in caso di crash simultaneo primario+rete puo esserci perdita minima degli ultimi redo non ancora arrivati.

### Come verificare che il flusso e sano

```sql
-- Primario: transport verso standby
SELECT dest_id, status, error
FROM   v$archive_dest
WHERE  dest_id = 2;

-- Standby: apply attivo
SELECT process, status, thread#, sequence#
FROM   v$managed_standby
WHERE  process IN ('RFS','MRP0');
```

Atteso:
- `DEST_ID=2` con `STATUS=VALID` e `ERROR` nullo sul primario;
- `MRP0` in stato `APPLYING_LOG` sullo standby.

Se `DEST_ID=2` va in `ERROR`:
- `ORA-12514`: problema service/listener/TNS;
- `ORA-01034`: standby non disponibile (tipico pre-duplicate o istanza giu).

---

## 3.6 Creazione Password File e Copia

### Cosa stiamo facendo davvero

In questo punto non stai "creando ASM". Stai facendo due operazioni diverse:

1. leggere o estrarre il password file del database dal posto in cui e' salvato sul primario;
2. mettere una copia identica sui nodi standby, con il nome giusto per ogni istanza.

In RAC il password file del database e' spesso salvato in ASM, quindi:

- per entrare in ASM usi `grid` + `~/.grid_env`
- per lavorare nel database home usi `oracle` + `~/.db_env`

Questa e' la logica corretta:

- `grid` gestisce Grid Infrastructure e ASM
- `oracle` gestisce il database home e i file sotto `$ORACLE_HOME/dbs`

Il password file e' un file del database, ma se si trova in `+DATA/...` devi prima passare da ASM per tirarlo fuori. Ecco perche' in questo step inizi come `grid`.

### Perche' Data Guard ha bisogno del password file

Data Guard e RMAN usano il password file per autenticare le connessioni amministrative remote (`SYS`, redo transport, duplicate, broker).

Regole da ricordare:

- il contenuto del password file deve essere coerente tra primario e standby
- il file locale sullo standby deve avere il nome giusto per l'istanza
- nel tuo lab, prima del `RMAN DUPLICATE`, lo standby parte da file locali nel database home

Se il file e' sbagliato o manca, puoi vedere errori tipo:

- `ORA-01017`
- `ORA-01031`
- `ORA-17627`
- `ORA-19909`

### Passo 1 - Capire dove sta il password file sul primario

Metodo raccomandato in RAC + ASM:

```bash
# Su rac1 come grid
su - grid
. ~/.grid_env
echo $ORACLE_SID
echo $ORACLE_HOME
which asmcmd
asmcmd pwget --dbuniquename RACDB
```

Output atteso:

```text
+ASM1
/u01/app/19.0.0/grid
/u01/app/19.0.0/grid/bin/asmcmd
+DATA/RACDB/PASSWORD/pwdracdb.256.1188432663
```

Se `pwget` restituisce un path ASM (`+DATA/...`), il password file e' in ASM e devi usare il flusso del passo 2.

Se invece non trovi nulla in ASM, verifica lato database home:

```bash
su - oracle
. ~/.db_env
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1
```

### Passo 2 - Se il password file e' in ASM, copialo da ASM al filesystem

```bash
# Su rac1 come grid
su - grid
. ~/.grid_env
asmcmd
ASMCMD> pwget --dbuniquename RACDB
ASMCMD> pwcopy +DATA/RACDB/PASSWORD/pwdracdb.256.1188432663 /tmp/orapwRACDB1
ASMCMD> exit

# Verifica il file estratto sul filesystem
ls -l /tmp/orapwRACDB1
chmod 640 /tmp/orapwRACDB1
chgrp oinstall /tmp/orapwRACDB1
```

Che cosa fa `chgrp oinstall /tmp/orapwRACDB1`?

- non cambia il proprietario del file
- cambia solo il gruppo Unix associato al file in `oinstall`

In pratica:

- owner resta `grid`
- group diventa `oinstall`

Questo aiuta nel lab perche':

- l'utente `oracle` appartiene al gruppo `oinstall`
- con `chmod 640`, il gruppo puo' leggere il file
- quindi `oracle` riesce a fare `scp` del password file senza dover usare `root`

Verifica attesa:

```bash
ls -l /tmp/orapwRACDB1
```

Output tipico:

```text
-rw-r----- 1 grid oinstall ... /tmp/orapwRACDB1
```

Se preferisci evitare ogni dubbio sui permessi, puoi anche fare la copia come `grid` e poi sistemare owner/perms sul nodo standby come `oracle`.

Perche' qui usi `grid`?

- `asmcmd` vive nel Grid home
- ASM e' amministrato dalla Grid Infrastructure
- Oracle documenta `pwcopy` e `pwget` come comandi ASMCMD per password file ASM/database

### Passo 3 - Se il password file e' gia nel filesystem sul primario

In questo caso non ti serve `grid`. Lavori direttamente come `oracle`.

Se il file esiste gia':

```bash
su - oracle
. ~/.db_env
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1
```

Se invece devi crearne uno nuovo sul filesystem:

```bash
su - oracle
. ~/.db_env
cd /u01/app/oracle/product/19.0.0/dbhome_1/dbs
orapwd file=orapwRACDB1 password=<tua_password_sys> entries=10 force=y
```

### Passo 4 - Copiare il file sui nodi standby

Prima del duplicate vuoi un password file locale nel DB home di ciascun nodo standby.

Nel tuo lab:

- `racstby1` usa `ORACLE_SID=RACDB1`
- `racstby2` usa `ORACLE_SID=RACDB2`

Quindi i nomi devono essere:

- `orapwRACDB1` su `racstby1`
- `orapwRACDB2` su `racstby2`

I due file hanno contenuto equivalente, ma nome diverso perche' ogni istanza legge `orapw$ORACLE_SID`.

```bash
# Su rac1 come oracle
su - oracle
. ~/.db_env

scp /tmp/orapwRACDB1 oracle@racstby1:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1
scp /tmp/orapwRACDB1 oracle@racstby2:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB2
```

### Passo 5 - Verifica sullo standby

```bash
# Su racstby1 come oracle
su - oracle
. ~/.db_env
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1

# Su racstby2 come oracle
su - oracle
. ~/.db_env
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB2
```

Atteso:

```text
-rw-r----- 1 oracle oinstall 2048 ... orapwRACDB1
-rw-r----- 1 oracle oinstall 2048 ... orapwRACDB2
```

### Passo 6 - Cosa esiste gia' e cosa NON esiste ancora

Nel tuo lab, a questo punto:

- esistono gia' i server standby `racstby1` e `racstby2`
- esiste gia' la Grid Infrastructure standby
- esiste gia' la DB Home standby
- esistono gia' ASM, listener, rete e storage standby

Ma NON esiste ancora il database standby `RACDB_STBY` come database fisico duplicato.

Questo e' il punto chiave:

- lo standby come infrastruttura esiste gia'
- lo standby come database Oracle deve ancora essere creato da RMAN

Subito dopo userai:

- il `pfile` locale in `dbs/initRACDB1.ora`
- il password file locale in `dbs/orapwRACDB1`

per avviare UNA sola istanza auxiliary:

- nodo `racstby1`
- istanza `RACDB1`
- stato `NOMOUNT`

e poi lanciare:

- `RMAN DUPLICATE FOR STANDBY`

Quindi, in questa fase:

- `racstby1` viene usato per creare il database standby
- `racstby2` non va ancora avviato come istanza database
- `orapwRACDB2` su `racstby2` lo prepari in anticipo per il passo successivo

Per questo motivo non ti serve ancora rimettere il password file dello standby in ASM. Il file locale nel DB home va bene per partire con l'istanza auxiliary.

### Passo 7 - Nota best practice post-duplicate

Dopo che lo standby RAC sara' creato e registrato correttamente, potrai decidere di riallineare anche il password file dello standby in ASM.

Questo e' un passo successivo, non obbligatorio per sbloccare il duplicate.

Esempio concettuale:

```bash
# Esempio post-duplicate, non farlo adesso se non hai ancora creato lo standby
su - grid
. ~/.grid_env
asmcmd
ASMCMD> pwcopy --dbuniquename RACDB_STBY /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1 +DATA/RACDB_STBY/PASSWORD/orapwRACDB_STBY -f
ASMCMD> exit
```

### Procedura rapida da seguire adesso nel lab

Se vuoi solo andare avanti senza perderti:

```bash
# 1) Su rac1 come grid
su - grid
. ~/.grid_env
asmcmd pwget --dbuniquename RACDB
asmcmd
# dentro ASMCMD:
# pwcopy +DATA/RACDB/PASSWORD/pwdracdb.256.1188432663 /tmp/orapwRACDB1
# exit

# 2) Sempre su rac1
ls -l /tmp/orapwRACDB1
chmod 640 /tmp/orapwRACDB1
chgrp oinstall /tmp/orapwRACDB1

# 3) Su rac1 come oracle
su - oracle
. ~/.db_env
scp /tmp/orapwRACDB1 oracle@racstby1:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1
scp /tmp/orapwRACDB1 oracle@racstby2:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB2

# 4) Verifica su entrambi gli standby
ssh oracle@racstby1 'ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1'
ssh oracle@racstby2 'ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB2'
```

---

## 3.7 Creazione del PFILE per lo Standby

### Obiettivo reale del passo 3.7

Qui non stai ancora configurando tutto il RAC standby.

Stai creando un `pfile` temporaneo per avviare SOLO la prima istanza standby:

- nodo `racstby1`
- istanza `RACDB1`
- stato `NOMOUNT`

Questo basta a RMAN per usare `racstby1` come `AUXILIARY` e costruire il database standby.

`racstby2` entrera' in gioco dopo, quando il duplicate sara' finito e il database standby verra' registrato nel cluster.

```bash
# Sul primario come oracle
su - oracle
. ~/.db_env
sqlplus / as sysdba
CREATE PFILE='/tmp/initRACDB_stby.ora' FROM SPFILE;
EXIT;
```

Modifica il pfile per lo standby:

```bash
vi /tmp/initRACDB_stby.ora
```

### Come ripulire il pfile esportato dal primario

Il `CREATE PFILE FROM SPFILE` ti genera un file "sporco" di parametri del primario.

Nel pfile standby devi fare tre cose:

1. cambiare i parametri che identificano il ruolo standby
2. correggere i convert `PRIMARY -> STANDBY`
3. togliere i parametri automatici o troppo specifici del primario

### Parametri da cambiare sicuramente

```ini
*.audit_file_dest='/u01/app/oracle/admin/RACDB_STBY/adump'
*.cluster_database=FALSE
*.db_name='RACDB'
*.db_unique_name='RACDB_STBY'
*.db_create_file_dest='+DATA'
*.db_recovery_file_dest='+RECO'
*.db_file_name_convert='+DATA/RACDB/','+DATA/RACDB_STBY/'
*.fal_client='RACDB_STBY'
*.fal_server='RACDB_DG'
*.log_archive_config='DG_CONFIG=(RACDB,RACDB_STBY)'
*.log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=RACDB_STBY'
*.log_archive_dest_2='SERVICE=RACDB_DG LGWR ASYNC REOPEN=15 VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB'
*.log_archive_dest_state_1='ENABLE'
*.log_archive_dest_state_2='ENABLE'
*.log_file_name_convert='+DATA/RACDB/','+DATA/RACDB_STBY/','+RECO/RACDB/','+RECO/RACDB_STBY/'
*.remote_listener='racstby-scan.localdomain:1521'
*.remote_login_passwordfile='exclusive'
*.standby_file_management='AUTO'
RACDB1.instance_number=1
RACDB2.instance_number=2
RACDB1.thread=1
RACDB2.thread=2
RACDB1.undo_tablespace='UNDOTBS1'
RACDB2.undo_tablespace='UNDOTBS2'
```

### Parametri da lasciare uguali

```ini
*.compatible='19.0.0'
*.db_block_size=8192
*.db_recovery_file_dest_size=10794m
*.diagnostic_dest='/u01/app/oracle'
*.enable_pluggable_database=TRUE
*.nls_language='AMERICAN'
*.nls_territory='AMERICA'
*.open_cursors=300
*.pga_aggregate_target=767m
*.processes=320
*.sga_target=2300m
```

### Parametri da rimuovere dal pfile temporaneo

Togli tutto cio' che e':

- auto-tuned (`__...`)
- specifico del primario
- generato dal clusterware e non adatto al bootstrap manuale

Da rimuovere, se presenti:

```ini
RACDB1.__...
RACDB2.__...
*.control_files=...
*.local_listener='-oraagent-dummy-'
*.dispatchers='(PROTOCOL=TCP) (SERVICE=RACDBXDB)'
family:dw_helper.instance_mode='read-only'
```

Nota critica sui convert:

- nel pfile standby la direzione corretta e' `PRIMARY -> STANDBY`
- quindi `RACDB` va convertito in `RACDB_STBY`
- se lasci il verso invertito, RMAN e lo startup dello standby puntano ai path sbagliati
- durante il duplicate RAC, tieni `cluster_database=FALSE` sull'auxiliary; lo riporterai a `TRUE` dopo il duplicate, quando passerai allo SPFILE condiviso e alla registrazione OCR

### Template pulito pronto da incollare

```ini
*.audit_file_dest='/u01/app/oracle/admin/RACDB_STBY/adump'
*.audit_trail='db'
*.cluster_database=FALSE
*.compatible='19.0.0'
*.db_block_size=8192
*.db_create_file_dest='+DATA'
*.db_file_name_convert='+DATA/RACDB/','+DATA/RACDB_STBY/'
*.db_name='RACDB'
*.db_unique_name='RACDB_STBY'
*.db_recovery_file_dest='+RECO'
*.db_recovery_file_dest_size=10794m
*.diagnostic_dest='/u01/app/oracle'
*.enable_pluggable_database=TRUE
*.fal_client='RACDB_STBY'
*.fal_server='RACDB_DG'
*.log_archive_config='DG_CONFIG=(RACDB,RACDB_STBY)'
*.log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=RACDB_STBY'
*.log_archive_dest_2='SERVICE=RACDB_DG LGWR ASYNC REOPEN=15 VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB'
*.log_archive_dest_state_1='ENABLE'
*.log_archive_dest_state_2='ENABLE'
*.log_archive_format='%t_%s_%r.dbf'
*.log_file_name_convert='+DATA/RACDB/','+DATA/RACDB_STBY/','+RECO/RACDB/','+RECO/RACDB_STBY/'
*.nls_language='AMERICAN'
*.nls_territory='AMERICA'
*.open_cursors=300
*.pga_aggregate_target=767m
*.processes=320
*.remote_listener='racstby-scan.localdomain:1521'
*.remote_login_passwordfile='exclusive'
*.sga_target=2300m
*.standby_file_management='AUTO'
RACDB1.instance_number=1
RACDB2.instance_number=2
RACDB1.thread=1
RACDB2.thread=2
RACDB1.undo_tablespace='UNDOTBS1'
RACDB2.undo_tablespace='UNDOTBS2'
```

Nota operativa:

- in questo pfile temporaneo evita `*.control_files`
- con ASM + OMF (`db_create_file_dest` / FRA) e `RMAN DUPLICATE`, e' meglio lasciare che Oracle/RMAN costruiscano i control file dello standby
- il pfile qui serve solo a portare su `racstby1` in `NOMOUNT` in modo pulito

Copia sullo standby:

```bash
# Copia SOLO su racstby1: per il duplicate basta una sola istanza auxiliary
scp /tmp/initRACDB_stby.ora oracle@racstby1:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB1.ora
```

Nota importante:

- in questo passo NON copiare ancora `initRACDB2.ora` su `racstby2`
- il secondo nodo verra' allineato dopo il duplicate, quando creerai lo `SPFILE` condiviso in ASM e il pointer file per `RACDB2`

---

## 3.8 Creazione Cartelle Audit sullo Standby

Queste directory le prepari su entrambi i nodi per evitare errori quando, piu' avanti, monterai anche la seconda istanza standby.

```bash
# Su racstby1 e racstby2 come oracle
mkdir -p /u01/app/oracle/admin/RACDB_STBY/adump
mkdir -p /u01/app/oracle/admin/RACDB/adump
```

---

## 3.9 Avvio Istanza Standby in NOMOUNT

### Obiettivo reale del passo 3.9

Qui NON stai avviando il RAC standby completo.

Stai avviando solo:

- `racstby1`
- istanza `RACDB1`
- con `PFILE` locale
- in stato `NOMOUNT`

Questo e' il prerequisito richiesto da `RMAN DUPLICATE FROM ACTIVE DATABASE`.

`racstby2` in questo momento resta fermo. E' normale.

Prima del comando `STARTUP`, fai sempre questi pre-check (best practice):

```bash
# Su racstby1 come oracle
su - oracle
. ~/.db_env
echo "ORACLE_HOME=$ORACLE_HOME"
export ORACLE_SID=RACDB1
echo "ORACLE_SID=$ORACLE_SID"

# Il file deve esistere PRIMA di startup nomount
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB1.ora
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1
```

Se il file non esiste, torna al passo `3.7` e ricopia il pfile:

```bash
scp /tmp/initRACDB_stby.ora oracle@racstby1:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB1.ora
```

Se manca invece il password file, torna al passo `3.6` e ricopialo da `rac1`.

```bash
# Su racstby1 come oracle
su - oracle
. ~/.db_env
export ORACLE_SID=RACDB1
sqlplus / as sysdba
STARTUP NOMOUNT PFILE='/u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB1.ora';
EXIT;
```

> Nota: in questo punto della guida si usa **NOMOUNT** (non MOUNT) per permettere il `RMAN DUPLICATE`.
> Nota 2: `racstby2` NON va avviato adesso. Verra' gestito dopo il duplicate.

Pre-check obbligatorio prima di entrare in RMAN:

```bash
# Su racstby1 come oracle
su - oracle
. ~/.db_env
export ORACLE_SID=RACDB1

sqlplus / as sysdba <<'EOF'
startup force nomount pfile='/u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB1.ora';
select instance_name, status from v$instance;
show parameter cluster_database;
exit
EOF

lsnrctl status | grep -Ei "RACDB1|RACDB_STBY|UNKNOWN|READY"

sqlplus 'sys/<password>@RACDB1_STBY as sysdba'
```

Atteso:

- `v$instance.status = STARTED`
- `cluster_database = FALSE` durante la fase di duplicate
- login remoto su `RACDB1_STBY` riuscito

Se il login remoto fallisce con:

- `ORA-01034`: l'istanza auxiliary non e' realmente partita in `NOMOUNT`
- `ORA-12514` o `ORA-12528`: problema listener statico / alias TNS / `(UR=A)`

---

## 3.10 RMAN Duplicate da Active Database

Questa è la magia! RMAN copia il database dal primario allo standby **in tempo reale**, senza bisogno di backup fisici.

### Cosa sta facendo davvero RMAN qui

RMAN usa:

- il database primario `RACDB` come `TARGET`
- la sola istanza `RACDB1` su `racstby1` come `AUXILIARY`

Quindi il duplicate, in questa fase, e' un'operazione single-instance su nodo 1, anche se lo standby finale sara' RAC a due nodi.

La sequenza corretta e':

1. costruisci il database standby usando `racstby1`
2. metti `SPFILE` in ASM
3. registri il database standby in OCR
4. avvii anche `RACDB2` su `racstby2`

> 📸 **SNAPSHOT — "SNAP-07: Standby_Grid_e_OS_Pronti" 🔴 CRITICO**
> L'RMAN Duplicate è l'operazione più delicata. Se fallisce (e succede spesso la prima volta), torni qui e risparmi MOLTO tempo.
> **Fai snapshot su TUTTE le VM (rac1, rac2, racstby1, racstby2)!**
> ```bash
> VBoxManage snapshot "rac1" take "SNAP-07: Standby_Grid_e_OS_Pronti"
> VBoxManage snapshot "rac2" take "SNAP-07: Standby_Grid_e_OS_Pronti"
> VBoxManage snapshot "racstby1" take "SNAP-07: Standby_Grid_e_OS_Pronti"
> VBoxManage snapshot "racstby2" take "SNAP-07: Standby_Grid_e_OS_Pronti"
> ```

```bash
# Da racstby1 come oracle
# Qui l'auxiliary e' solo la prima istanza standby
rman TARGET sys/<password>@RACDB AUXILIARY sys/<password>@RACDB1_STBY
```

Nota importante:

- `<password>` e' un placeholder documentale
- NON devi scrivere i caratteri `<` e `>` nel comando reale
- Bash interpreta `<password>` come redirezione input e prova ad aprire un file chiamato `password`
- la password Oracle e' case-sensitive, quindi `Root_1234` e `root_1234` NON sono la stessa cosa

Esempio reale:

```bash
rman TARGET "sys/Root_1234@RACDB" AUXILIARY "sys/Root_1234@RACDB1_STBY"
```

Se vuoi evitare di lasciare la password nella command history, entra prima in RMAN e poi fai le connect:

```bash
rman
RMAN> CONNECT TARGET sys/Root_1234@RACDB;
RMAN> CONNECT AUXILIARY sys/Root_1234@RACDB1_STBY;
```

> **Per database grandi (>50 GB)**, lancia con `nohup` o in un `screen`/`tmux` per evitare che un timeout SSH interrompa l'operazione:
> ```bash
> nohup rman TARGET sys/<password>@RACDB AUXILIARY sys/<password>@RACDB1_STBY <<EOF > /tmp/duplicate.log 2>&1 &
> DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE DORECOVER ...
> EOF
> tail -f /tmp/duplicate.log   # Per monitorare il progresso
> ```

```rman
DUPLICATE TARGET DATABASE
  FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
    SET db_unique_name='RACDB_STBY'
    SET cluster_database='FALSE'
    SET remote_listener='racstby-scan.localdomain:1521'
    SET fal_server='RACDB_DG'
    SET log_archive_dest_2='SERVICE=RACDB_DG LGWR ASYNC REOPEN=15 VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB'
  NOFILENAMECHECK;
```

> **Spiegazione del comando RMAN:**
> - `FOR STANDBY`: Crea un database standby, non un clone.
> - `FROM ACTIVE DATABASE`: Copia i datafile direttamente via rete, senza bisogno di un backup su disco.
> - `DORECOVER`: Applica automaticamente gli archivelog mancanti dopo la copia.
> - `SPFILE SET ...`: Sovrascrive i parametri nel SPFILE dello standby.
> - `NOFILENAMECHECK`: Non verificare che i path dei file siano diversi (utile perché usiamo gli stessi nomi ASM).

### Warning RMAN attesi con ASM / OMF

Durante il duplicate potresti vedere warning come:

- `RMAN-05538: warning: implicitly using DB_FILE_NAME_CONVERT`
- `RMAN-05529: warning: DB_FILE_NAME_CONVERT resulted in invalid ASM names; names changed to disk group only`
- `RMAN-05158: WARNING: auxiliary file name ... conflicts with a file used by the target database`

Nel tuo lab questi warning sono normalmente benigni se valgono tutte queste condizioni:

- primario e standby sono su storage ASM separato
- i disk group hanno gli stessi nomi (`+DATA`, `+RECO`) ma NON sono gli stessi dischi condivisi tra i due cluster
- il duplicate continua a creare/restore i file senza fermarsi con errore fatale

Perche' compaiono:

- RMAN vede nomi OMF del primario come `+DATA/RACDB/...`
- prova a usare `DB_FILE_NAME_CONVERT`
- con ASM + OMF il risultato puo' non essere un nome ASM valido completo
- allora Oracle riduce il nome al solo disk group e genera automaticamente il nome OMF corretto sullo standby

Quindi:

- `RMAN-05529` in questo contesto e' spesso solo informativo
- `RMAN-05158` segnala un conflitto "logico di nome", non necessariamente un conflitto reale di storage
- con `NOFILENAMECHECK` e storage standby separato, puoi normalmente lasciare proseguire il duplicate

Quando invece devi fermarti e correggere:

- se il duplicate si arresta con errori successivi di restore/create file
- se standby e primario stanno davvero usando gli stessi dischi ASM
- se hai lasciato i convert nel verso sbagliato
- se `db_create_file_dest` / `db_recovery_file_dest` non puntano ai disk group corretti sullo standby

Stato atteso a fine passo:

- il database standby esiste
- `racstby1` e' il nodo usato per costruirlo
- `racstby2` non e' ancora partito come seconda istanza database

L'operazione può richiedere 20-60 minuti a seconda della dimensione del DB.

---

## 3.11 Creazione SPFILE in ASM e Pointer File

Dopo il duplicate, lo standby puo' trovarsi in uno di questi stati:

- usa ancora un `spfileRACDB1.ora` locale in `$ORACLE_HOME/dbs`
- usa un `PFILE` locale `initRACDB1.ora`
- hai gia' creato uno `SPFILE` in ASM, ma Oracle continua comunque a leggere quello locale

L'obiettivo finale per RAC e' uno solo:

- SPFILE condiviso in ASM
- file `initRACDB1.ora` e `initRACDB2.ora` ridotti a semplici pointer file
- `cluster_database=TRUE` scritto nello SPFILE condiviso

### Regola importante: ordine di ricerca dei parameter file

Quando fai `STARTUP` senza specificare `PFILE=...`, Oracle cerca i file in questo ordine:

1. `spfile<SID>.ora`
2. `spfile.ora`
3. `init<SID>.ora`

Quindi, se esiste ancora `$ORACLE_HOME/dbs/spfileRACDB1.ora`, Oracle usera' quello e ignorera' il pointer file `initRACDB1.ora`.

Questo spiega esattamente il caso in cui:

- hai creato `initRACDB1.ora` con `SPFILE='+DATA/...'`
- ma `SHOW PARAMETER spfile` continua a mostrare `/u01/app/oracle/product/19.0.0/dbhome_1/dbs/spfileRACDB1.ora`

### Sequenza corretta e completa

```sql
-- Su racstby1 come sysdba
sqlplus / as sysdba

-- 1) Verifica quale file Oracle sta usando davvero
SHOW PARAMETER spfile;

-- 2) Crea un PFILE di sicurezza partendo dallo SPFILE corrente
CREATE PFILE='/tmp/racdb_stby_after_duplicate.ora' FROM SPFILE;

-- 3) Crea o ricrea lo SPFILE condiviso in ASM con i parametri correnti
CREATE SPFILE='+DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora'
  FROM PFILE='/tmp/racdb_stby_after_duplicate.ora';

-- 4) Arresta l'istanza
SHUTDOWN IMMEDIATE;
```

```bash
# Su racstby1 come oracle
. ~/.db_env
cd $ORACLE_HOME/dbs

# 5) Metti da parte il vecchio spfile locale: finche' resta qui, Oracle ha precedenza su questo file
mv spfileRACDB1.ora spfileRACDB1.ora.bkp

# 6) Metti da parte anche il vecchio pfile, se presente
mv initRACDB1.ora initRACDB1.ora.bkp 2>/dev/null || true

# 7) Crea il pointer file verso ASM
echo "SPFILE='+DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora'" > initRACDB1.ora

# 8) Copia il pointer file anche al secondo nodo standby
scp initRACDB1.ora oracle@racstby2:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB2.ora

# 9) Verifica
cat $ORACLE_HOME/dbs/initRACDB1.ora
# SPFILE='+DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora'
```

```sql
-- Torna in sqlplus su racstby1
sqlplus / as sysdba

-- 10) Riavvia SENZA specificare PFILE: cosi' Oracle usera' il pointer file
STARTUP NOMOUNT;

-- 11) Adesso SHOW PARAMETER spfile deve mostrare il path ASM
SHOW PARAMETER spfile;

-- 12) Solo ora scrivi cluster_database=TRUE nello SPFILE condiviso
ALTER SYSTEM SET cluster_database=TRUE SCOPE=SPFILE SID='*';

-- 13) Da NOMOUNT, SHUTDOWN IMMEDIATE puo' mostrare ORA-01507: e' normale
SHUTDOWN IMMEDIATE;

-- 14) Riavvia in MOUNT per proseguire con la fase RAC
STARTUP MOUNT;

SHOW PARAMETER cluster_database;
SHOW PARAMETER spfile;
```

Stato atteso a fine passo:

- `SHOW PARAMETER spfile` mostra `+DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora`
- `cluster_database` risulta `TRUE`
- `racstby1` monta il database usando lo SPFILE condiviso
- `racstby2` ha gia' il pointer file pronto per il passo successivo

> Perche' SPFILE in ASM? In RAC, i parametri devono essere condivisi tra tutti i nodi. Se lasci lo SPFILE nel filesystem locale di `racstby1`, `racstby2` non lo vede. In ASM, invece, il file e' condiviso e coerente per tutto il cluster standby.

> Best practice operativa:
> - prima del duplicate, startup manuale con `PFILE` e `NOMOUNT`;
> - durante il duplicate, usa solo `racstby1` come auxiliary;
> - subito dopo il duplicate, sposta la configurazione su SPFILE condiviso in ASM;
> - dopo registrazione in OCR (passo `3.12`), usa `srvctl` per start/stop dello standby invece di `startup` manuale.

---

## 3.12 Registrazione nel Cluster (OCR) e Avvio Secondo Nodo

Dopo il duplicate, devi registrare il database standby nell'Oracle Cluster Registry (OCR) perché il Clusterware possa gestirlo.

```bash
# Su racstby1 come oracle
srvctl add database -d RACDB_STBY \
  -oraclehome $ORACLE_HOME \
  -spfile '+DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora' \
  -role PHYSICAL_STANDBY \
  -startoption MOUNT

srvctl add instance -d RACDB_STBY -instance RACDB1 -node racstby1
srvctl add instance -d RACDB_STBY -instance RACDB2 -node racstby2

# Il password file di racstby2 dovrebbe essere gia' presente dal passo 3.6.
# Qui fai solo una verifica. Se manca, ricopialo adesso.
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1
ssh oracle@racstby2 "ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB2" || \
scp /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1 oracle@racstby2:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB2

# Avvia il database (entrambe le istanze)
srvctl start database -d RACDB_STBY

# Verifica
srvctl status database -d RACDB_STBY -v
# Instance RACDB1 is running on node racstby1...
# Instance RACDB2 is running on node racstby2...

crsctl stat res -t | grep -A2 RACDB_STBY
```

---

## 3.13 Avvio Redo Apply (MRP)

```sql
-- Su racstby1 come sysdba
sqlplus / as sysdba

-- Avvia il Managed Recovery Process (MRP)
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;

-- Verifica che MRP sia attivo
SELECT process, status, thread#, sequence# FROM v$managed_standby WHERE process = 'MRP0';
-- STATUS deve essere APPLYING_LOG
```

> **Perché `USING CURRENT LOGFILE`?** Questo abilita il **Real-Time Apply**: lo standby applica i redo APPENA arrivano, senza aspettare che l'archivelog sia completo. Il ritardo è tipicamente di pochi secondi.

```sql
-- Comandi utili per gestire MRP
-- Fermare MRP:
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;

-- Verificare MRP a livello OS:
-- ps -ef | grep mrp
```

---

## 3.14 Configura Archivelog Deletion Policy

```bash
# Sullo standby come oracle
rman target /

RMAN> SHOW ARCHIVELOG DELETION POLICY;
# default: NONE

RMAN> CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

RMAN> SHOW ARCHIVELOG DELETION POLICY;
# CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```

> **Perché?** Senza questa policy, gli archivelog si accumulano nella FRA fino a riempirla (ORA-19502). Con questa policy, RMAN elimina automaticamente gli archivelog che sono già stati applicati sullo standby.

---

## 3.15 Verifica Sincronizzazione

```sql
-- Sul PRIMARIO: esegui alcuni log switch per testare
ALTER SYSTEM SWITCH LOGFILE;   -- Thread 1
ALTER SYSTEM SWITCH LOGFILE;

-- Sul PRIMARIO: verifica ultimo sequence archiviato
SELECT thread#, MAX(sequence#) FROM v$archived_log
WHERE archived='YES' GROUP BY thread#;

-- Sullo STANDBY: verifica ultimo sequence applicato
SELECT thread#, MAX(sequence#) FROM v$archived_log
WHERE applied='YES' GROUP BY thread#;

-- I numeri DEVONO corrispondere!
```

---

## 3.16 Troubleshooting Fase 3

| Problema | Causa | Soluzione |
|---|---|---|
| `ORA-01078` + `LRM-00109` su startup standby | File `initRACDB1.ora` assente o path errato | Esegui runbook `Fix ORA-01078/LRM-00109` qui sotto |
| `ORA-01034` + `SP2-1545` su `show pdbs` | Istanza standby non avviata oppure standby in MOUNT | Avvia istanza (NOMOUNT/MOUNT) e usa query `v$database` invece di `show pdbs` |
| `ORA-01017` su `sqlplus sys@RACDB_STBY` | Password file errato | Verifica nome = `orapw<SID>`, owner = `oracle` |
| `ORA-12514` su `V$ARCHIVE_DEST` (`DEST_ID=2`) | Service standby non registrato/raggiungibile | Esegui runbook `Fix ORA-12514` qui sotto |
| `ORA-12528: TNS:listener: all ... blocked` | DB in NOMOUNT senza `UR=A` | Aggiungi `(UR=A)` nel TNS dello standby |
| `ORA-16055: FAL request rejected` | `log_archive_dest` errato | Correggi su ENTRAMBI i lati (vedi sotto) |
| RMAN Duplicate timeout/hang | Rete lenta o sessione SSH caduta | Usa `nohup` o `screen`, verifica rete |
| MRP non parte: `ORA-00270` | FRA piena sullo standby | Pulisci archivelog: `DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-2';` |
| `v$archive_gap` mostra gap | Archivelog mancante | `ALTER SYSTEM SET fal_server='RACDB_DG' SCOPE=BOTH;` → FAL recupera automaticamente |

### Fix ORA-01078 / LRM-00109 su standby (parameter file mancante)

Sintomo tipico:

```text
ORA-01078: failure in processing system parameters
LRM-00109: could not open parameter file '.../dbs/initRACDB1.ora'
```

Procedura:

```bash
# 1) Su racstby1, come oracle
export ORACLE_SID=RACDB1
echo "ORACLE_HOME=$ORACLE_HOME"
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB1.ora
```

Se il file manca:

```bash
# 2) Ricopia il pfile generato al passo 3.7
scp /tmp/initRACDB_stby.ora oracle@racstby1:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB1.ora
```

```bash
# 3) Riparti con NOMOUNT (fase pre-duplicate)
sqlplus / as sysdba <<EOF
STARTUP NOMOUNT PFILE='/u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB1.ora';
EXIT;
EOF
```

Se sei gia nella fase post-duplicate e hai SPFILE in ASM:

```bash
# 4) Crea/ricrea il pointer locale
echo "SPFILE='+DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora'" > /u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB1.ora
```

```sql
-- 5) Avvia e verifica
STARTUP MOUNT;
SHOW PARAMETER spfile;
SELECT name, open_mode, database_role FROM v$database;
```

### Fix ORA-12514 su `DEST_ID=2` (redo transport verso standby)

Sintomo tipico:

```sql
SELECT dest_id, status, error
FROM   v$archive_dest
WHERE  dest_id = 2;
-- STATUS = ERROR
-- ERROR  = ORA-12514: listener does not currently know of service requested
```

Procedura rapida:

```sql
-- 1) Sul primario, metti in pausa la destinazione remota mentre correggi
ALTER SYSTEM SET log_archive_dest_state_2=DEFER SCOPE=BOTH SID='*';
```

```bash
# 2) Su racstby1/racstby2 (come grid): verifica servizi esposti dal listener
lsnrctl status | grep -Ei "RACDB_STBY|RACDB_STBY_DGMGRL|READY|UNKNOWN"
```

```bash
# 3) Dal primario testa il service standby usato dal transport
sqlplus 'sys/<password>@RACDB_STBY_DG as sysdba'
```

Se il test SQL fallisce:
1. ricontrolla `tnsnames.ora` con `ADDRESS_LIST` su `racstby1` + `racstby2`;
2. verifica `listener.ora` statico su entrambi gli standby (`GLOBAL_DBNAME = RACDB_STBY`);
3. riavvia listener standby:

```bash
srvctl stop listener
srvctl start listener
```

Quando il test SQL passa, riabilita il transport:

```sql
ALTER SYSTEM SET log_archive_dest_state_2=ENABLE SCOPE=BOTH SID='*';

SELECT dest_id, status, target, error
FROM   v$archive_dest
WHERE  dest_id IN (1,2)
ORDER  BY dest_id;
```

Atteso:
- `DEST_ID=2` con `STATUS=VALID`
- colonna `ERROR` vuota

### Fix ORA-16055 (Comune!)

```sql
-- Il problema: i parametri log_archive_dest non sono simmetrici.
-- Fix sul PRIMARIO:
ALTER SYSTEM SET LOG_ARCHIVE_DEST_1='LOCATION=USE_DB_RECOVERY_FILE_DEST
  VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=RACDB' SID='*' SCOPE=BOTH;

ALTER SYSTEM SET LOG_ARCHIVE_DEST_2='SERVICE=RACDB_STBY_DG LGWR ASYNC REOPEN=15
  VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB_STBY' SID='*' SCOPE=BOTH;

-- Fix sullo STANDBY:
ALTER SYSTEM SET LOG_ARCHIVE_DEST_1='LOCATION=USE_DB_RECOVERY_FILE_DEST
  VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=RACDB_STBY' SID='*' SCOPE=BOTH;

ALTER SYSTEM SET LOG_ARCHIVE_DEST_2='SERVICE=RACDB_DG LGWR ASYNC REOPEN=15
  VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB' SID='*' SCOPE=BOTH;
```

> **Riferimento**: MOS Doc ID 2988948.1 — "ORA-16055: FAL Request Rejected on primary alert log"

---

## ✅ Checklist Fine Fase 3

```bash
# 1. Standby in mount su entrambi i nodi
srvctl status database -d RACDB_STBY -v

# 2. MRP attivo e APPLYING_LOG
sqlplus -s / as sysdba <<< "SELECT process, status FROM v\$managed_standby WHERE process='MRP0';"

# 3. Nessun gap
sqlplus -s / as sysdba <<< "SELECT * FROM v\$archive_gap;"
# (nessuna riga = tutto OK)

# 4. Sequence primario == standby
# Sul primario:
sqlplus -s / as sysdba <<< "SELECT thread#, max(sequence#) FROM v\$archived_log WHERE archived='YES' GROUP BY thread#;"

# Sullo standby:
sqlplus -s / as sysdba <<< "SELECT thread#, max(sequence#) FROM v\$archived_log WHERE applied='YES' GROUP BY thread#;"

# 5. SPFILE in ASM (non locale!)
SHOW PARAMETER spfile;
# +DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora

# 6. Archivelog deletion policy configurata
rman target / <<< "SHOW ARCHIVELOG DELETION POLICY;"

# 7. Errori nel alert log?
adrci
SHOW ALERT -tail 30
```

> 📸 **SNAPSHOT — "SNAP-08: RMAN_Duplicate_Finito" ⭐ MILESTONE**
> Lo standby è operativo con MRP attivo e 0 gap! Questo è probabilmente lo snapshot più importante dopo la creazione del primario.
> ```bash
> VBoxManage snapshot "rac1" take "SNAP-08: RMAN_Duplicate_Finito"
> VBoxManage snapshot "rac2" take "SNAP-08: RMAN_Duplicate_Finito"
> VBoxManage snapshot "racstby1" take "SNAP-08: RMAN_Duplicate_Finito"
> VBoxManage snapshot "racstby2" take "SNAP-08: RMAN_Duplicate_Finito"
> ```

---

## 📋 Comandi Data Guard Utili — Riferimento Rapido

```sql
-- Verificare errori DG sul primario
SELECT error FROM v$archive_dest WHERE dest_id = 2;

-- Stato MRP completo sullo standby
SELECT PROCESS, CLIENT_PROCESS, STATUS, THREAD#, SEQUENCE#, BLOCK#, BLOCKS
FROM GV$MANAGED_STANDBY;

-- Ruolo attuale del database
SELECT name, open_mode, database_role, db_unique_name FROM v$database;

-- Parametri DG attuali
SELECT name, value FROM v$parameter
WHERE name IN ('db_name','db_unique_name','log_archive_config',
  'log_archive_dest_1','log_archive_dest_2','fal_server','fal_client',
  'standby_file_management','db_file_name_convert','log_file_name_convert');
```

---

**→ Prossimo: [FASE 4: Configurazione Data Guard e DGMGRL](./GUIDA_FASE4_DATAGUARD_DGMGRL.md)**
