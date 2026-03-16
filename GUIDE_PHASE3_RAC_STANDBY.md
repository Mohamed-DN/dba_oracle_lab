# STEP 3: Preparing and Creating Oracle RAC Standby (via RMAN Duplicate)

> This phase covers the preparation of standby nodes (`racstby1`, `racstby2`) and creating the physical standby database using RMAN Duplicate from Active Database.

> 🛑 **BEFORE CONTINUING: CONNECT VIA MOBAXTERM!**
> This phase, like Phase 2, requires continuous use of shell + Oracle GUI (`gridSetup.sh`, `runInstaller`) and precise copy/paste of commands.
>
> **Reference IP Table (Public Network):**
> - `rac1`: 192.168.56.101
> - `rac2`: 192.168.56.102
> - `racstby1`: 192.168.56.111
> - `racstby2`: 192.168.56.112

### 📸 Riferimenti Visivi

![Data Guard RAC Primary Architecture → RAC Standby](./images/dataguard_architecture.png)

### What Happens in This Phase

```
  BEFORE AFTER
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
│ RAC STANDBY │ RMAN Duplicate ┌──────────────────┐
│ (empty) │ ═══════════════► │ RAC STANDBY │
│ Grid + SW   │   Copia DB via       │ RACDB_STBY       │
│ NO database │ network on time │ ┌────┐ ┌────┐ │
│ racstby1/2  │   reale!             │ │DB1 │ │DB2 │   │
└─────────────┘                      │ └────┘ └────┘   │
                                     │ in tempo reale   │
                                     └──────────────────┘
```

### Installation Order in This Phase (Phase 2 style)

```text
Step 1: Golden Image clone standby ━━━━━━━━━━━━━━━━━━━▶ racstby1/racstby2 ready
Step 2: Network + hostname + fix systemd ━━━━━━━━━━━━━━━━━━━▶ stable and reachable nodes
Step 3: ASM standby disks ━━━━━━━━━━━━━━━━━━━▶ CRS/DATA/RECO visible
Step 4: Grid Infrastructure standby ━━━━━━━━━━━━━━━━━━━▶ online standby cluster
Step 5: Patch Grid RU ━━━━━━━━━━━━━━━━━━━▶ alignment with primary
Step 6: DB Home Software Only ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━▶ DB engine installed
Step 7: Patch DB Home RU + OJVM ━━━━━━━━━━━━━━━━━━━▶ home standby aligned
Step 8: Config DG network/listener/TNS ━━━━━━━━━━━━━━━━━━━▶ primary-standby connectivity
Step 9: RMAN Duplicate Active Database ━━━━━━━━━━━━━━━━━━━▶ RACDB_STBY creato
Step 10: OCR registration + MRP apply ━━━━━━━━━━━━━━━━━━━▶ synchronized standby
```

### Percorso da seguire in pratica

1. **Recommended path (default):** execute the section `3.0B` (Golden Image) e poi continua da `3.1`.
2. **Percorso alternativo:** usa `3.0A` only if the standby was already prepared in Phase 2 and you only have to do smoke-check.

---

## 3.0A Alternative Path: If you have already prepared Standby in Phase 2

If during Phase 2 you have already installed su `racstby1`/`racstby2`:

- Grid Infrastructure
- disk group `+DATA` e `+RECO`
- DB Home software only (senza DBCA)
- patch RU/OJVM su Grid e DB Home

then **do not redo** section 3.0B. Just do this smoke-check and then go straight to `3.2`.

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

## 3.0B Recommended Path (Default): Creation of Standby Machines from Golden Image

This is the main path of Phase 3. Before you can configure Data Guard, you must **physically build** the Standby cluster. As explained in Step 0, **do not re-install Linux from scratch**. USA `rac1` (exactly in the post-Phase 1 state, before installing Grid) as your **Golden Image**.

### Step 1: Clona le Macchine dalla Golden Image
1. Assicurati che `rac1` sia spento.
2. Open **VirtualBox Manager**, click on the VM `rac1`, go to the "Snapshots" section, select `SNAP-04_Prerequisiti_Cloni_Pronti` and click on **Clone**. *(You must start from this exact snapshot, NOT from the current state or subsequent snapshots!)*
3. Nome: `racstby1` -> Select **Generate new MAC addresses** -> Complete cloning.
4. Ripeti l'operazione per creare `racstby2` (clonando sempre da `rac1`).
5. Assegna a `racstby1` e `racstby2` the 5 dummy shared disks created for standby (`asm-stby-crs1`, `asm-stby-crs2`, ecc.).

### Step 2: Modifica IP e Hostname
Power on **ONE VM AT A TIME** (from the black VirtualBox console, don't use MobaXterm yet) and make these changes:

**Su `racstby1`:**
- `hostnamectl set-hostname racstby1.localdomain`
- Lancia `nmtui` e cambia Scheda Pubblica a **`192.168.56.111`**
- Lancia `nmtui` e cambia Scheda Privata (Interconnect) a **`192.168.2.111`** (Attention, 2.x network!)
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
Even if the VMs are cloned, it is best to ensure that the Oracle Linux 7 IPC bug fix is ​​applied. Do this on **both** standby nodes as `root`:
```bash
echo "RemoveIPC=no" >> /etc/systemd/logind.conf
systemctl restart systemd-logind
```

### Step 3: Initialize ASM Disks for Standby (ONLY on `racstby1`)
The 5 new disks you assigned in VirtualBox are "blank". You need to partition them and make them ASMLib disks, exactly as you did in Phase 0 and Phase 2 for the primary.

1. **Partizionamento base:** Usa MobaXterm collegandoti a `racstby1` as `root`.
   Esegui `fdisk` per `/dev/sdc`, `/dev/sdd`, `/dev/sde`, `/dev/sdf`, `/dev/sdg`.
   The sequence for each is always: `n`, `p`, `1`, `Invio`, `Invio`, `w`.
   Infine lancia `partprobe`.

2. **ASM Disk Creation (Always on `racstby1` as `root`):**
   ```bash
   oracleasm createdisk CRS1 /dev/sdc1
   oracleasm createdisk CRS2 /dev/sdd1
   oracleasm createdisk CRS3 /dev/sde1
   oracleasm createdisk DATA /dev/sdf1
   oracleasm createdisk RECO /dev/sdg1
   
   oracleasm scandisks
   oracleasm listdisks
   ```

3. **Check on `racstby2` (as `root`):**
   ```bash
   oracleasm scandisks
   oracleasm listdisks
   ```
   *If you also see the 5 disks here, the shared standby storage is ready!*

### Step 4: Installing and Patching Grid and Database (Phase 2 Adapted for Standby)

Now that the standby nodes exist, the network is working, and the ASMLib disks are ready, we need to recreate the Oracle infrastructure. **We do EXACTLY the robust steps we used on the primary**, adapting the names for the standby.

#### 4.1 Preparazione Binari e Prerequisiti
1. **Scompatta Grid (`racstby1`)**:
   ```bash
   su - grid
   unzip -q /tmp/LINUX.X64_193000_grid_home.zip -d /u01/app/19.0.0/grid
   ```
2. **Setup CVU Disk (`racstby1` e `racstby2` as root)**:
   ```bash
   # racstby1
   rpm -ivh /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm
   scp /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm root@racstby2:/tmp/
   # racstby2
   ssh racstby2 "rpm -ivh /tmp/cvuqdisk-1.0.10-1.rpm"
   ```
3. **Pointers Inventory (`racstby1` e `racstby2` as root)**:
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
4. **Pulizia Reti Fantasma (`racstby1` e `racstby2` as root)**:
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
   > Se `enp0s9` non mostra un IPv4 (`192.168.2.111` su `racstby1`, `192.168.2.112` su `racstby2`), configura subito l'interconnect con `nmtui` before continuing with `cluvfy`.

#### 4.1a User Equivalence SSH (MANDATORY) - `grid`, `oracle`, `root`

L'errore `PRVG-2019` durante `cluvfy` indicates that the SSH trust is not ready.
Configure user equivalence on **both nodes** for all operational users:
For complete reset and troubleshooting (Permission denied, Host key verification failed), see also: [GUIDA_SSH_KEYS_RAC](./GUIDE_RAC_SSH_KEYS.md).

```bash
# Step 0 (opzionale) reset totale chiavi su entrambi i nodi
rm -rf /home/grid/.ssh
rm -rf /home/oracle/.ssh
rm -rf /root/.ssh
```

Key generation on both nodes:

```bash
su - grid   -c "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"
su - oracle -c "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"
su - root   -c "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"
```

Manual key exchange (two-way trust):

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

Final verification (must enter without password):

```bash
su - grid   -c "ssh racstby1 hostname"
su - grid   -c "ssh racstby2 hostname"
su - oracle -c "ssh racstby1 hostname"
su - oracle -c "ssh racstby2 hostname"
su - root   -c "ssh racstby1 hostname"
su - root   -c "ssh racstby2 hostname"
```

#### 4.1b Pre-Grid: Host synchronization block + Chrony hardening (MANDATORY)

Before installing Grid on standby, block the time synchronization imposed by the hypervisor and leave time control to `chronyd`.

Why:
1. `chronyd` sincronizza la VM con NTP.
2. VirtualBox Guest Additions can force the guest clock on reboot.
3. I salti orari fanno fallire i check NTP di `cluvfy` e possono sporcare il pre-check Grid.

VirtualBox-first su `racstby1` e `racstby2` (as `root`):

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

Hardening Chrony su `racstby1` e `racstby2` (as `root`):

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

Reboot persistence test (mandatory on both nodes):

```bash
reboot
```

After login:

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
- go to the section `4.1c` e poi `4.2` solo quando entrambi i nodi sono sincronizzati;
- warning NAT duplicata `10.0.2.15` su `enp0s3` e benigno nel lab VirtualBox.

#### 4.1c Pre-check cluvfy (same standard as Phase 2)

```bash
# Su racstby1 come grid
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/runcluvfy.sh stage -pre crsinst -n racstby1,racstby2 -verbose -method root
```

Se non usi `-method root`, vedrai `PRVG-11250` (RPM check non eseguito): e solo informativo.

Output interpretation (aligned to Phase 2):

| Errore | Tipo | Azione |
|---|---|---|
| `PRVF-7530` (Physical Memory < 8GB) | Warning | In lab you can proceed; optional increase RAM to 9 GB |
| `PRVG-1172` / `PRVG-11067` su `10.0.2.15` (`enp0s3`) | Warning | NAT duplicata VirtualBox: ignorabile se `enp0s3` e `Do Not Use` in installer |
| `PRVG-13606` (chrony non sync) | Errore da chiudere | Torna a `4.1b`, verify `makestep 1.0 3`, sincronizza e rilancia cluvfy |
| `PRVG-11250` (RPM DB check) | Info | Ignora o rilancia con `-method root` |
| `PRVG-2019` (User Equivalence) | Errore reale | Correggi SSH (`4.1a`) before continuing |

Se compare `PRVG-13606`, do not continue with the installer: close time synchronization first `4.1b` e rilancia `runcluvfy.sh`.

#### 4.2 Installazione Grid Infrastructure (GUI)

Avvia `gridSetup.sh` su `racstby1` (as `grid`, via MobaXterm with X11). Follow the steps, paying attention to these **key differences** for standby:

| Parametro Installer | Value for Standby |
|---|---|
| Cluster Name | `racstby-cluster` |
| SCAN Name | `racstby-scan.localdomain` |
| Node 1 | `racstby1.localdomain` / VIP: `racstby1-vip.localdomain` |
| Node 2 | `racstby2.localdomain` / VIP: `racstby2-vip.localdomain` |

> ⚠️ **At Step 5 (Network Interface Usage)**, use the same configuration: `enp0s8` (Pubblica), `enp0s9` (ASM & Private - 192.168.2.0), `enp0s3` (Do Not Use).
>
> 🛑 **Allo Step 8 (ASM Disk Group 'CRS') RICORDA IL WORKAROUND ASMLIB:**
> Cambia il Discovery Path in `/dev/oracleasm/disks/*`. Seleziona SOLO `CRS1`, `CRS2`, `CRS3`.

Proceed to the end. In the Prerequisites screen you can ignore warnings about RAM and NAT (`enp0s3`).  
Non ignorare errori reali su SSH equivalence, discovery ASM o chrony sync.
Run **LIKE ROOT** scripts on `racstby1` (`orainstRoot.sh`, poi `root.sh`), and wait for the end before putting them on `racstby2`.

Immediate post-installation verification:

```bash
# Come grid su racstby1
crsctl check cluster -all
olsnodes -n
asmcmd lsdg
```

#### 4.3 Creation of Disk Group DATA and RECO (Standby)
After the cluster is online, it creates disk groups for standby via `asmca` o SQL:
```sql
-- Su racstby1 come grid (sqlplus / as sysasm)
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY DISK '/dev/oracleasm/disks/DATA' ATTRIBUTE 'compatible.asm'='19.0', 'compatible.rdbms'='19.0';
CREATE DISKGROUP RECO EXTERNAL REDUNDANCY DISK '/dev/oracleasm/disks/RECO' ATTRIBUTE 'compatible.asm'='19.0', 'compatible.rdbms'='19.0';
```
> **PLEASE NOTE**: The disk groups are called EXACTLY the same as on the primary (`+DATA`, `+RECO`). This is critical for RMAN Duplicate!

#### 4.4 Patching Grid Infrastructure (Combo Patch) on Standby

> **Why patch?** Oracle 19c base (19.3) is the initial version released in 2019. Release Updates (RUs) contain security fixes, bug fixes, and stability improvements. In production, patching is **required**. In the lab, it teaches you the process you will use in the real world.

The patches you need (already present in your downloads):

| Patch | Descrizione | Dove si Applica |
|---|---|---|
| **p6880880** | **OPatch** (utility per applicare patch) | Sostituisci in ogni ORACLE_HOME |
| **p38658588** | **Combo Patch (GI RU + OJVM RU)** — Jan 2026 | Grid Home + DB Home |

### Step 1: Aggiorna OPatch nella Grid Home

OPatch is the tool that applies patches. The version shipped with the base software 19.3 is too old. You must update it BEFORE applying any patches.

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

> ⚠️ **ATTENZIONE**: NON scompattare la patch in `/tmp`! Nelle nostre VM, `/tmp` it is a RAM disk (tmpfs) of only 4GB. The extracted patch takes up more than 3GB, filling up `/tmp` to 100% and blocking the node. Always use `/u01` che ha 50GB di spazio!

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

> ⚠️ **Oracle Best Practice (MOS 2632107.1)**: Before applying any patch, ALWAYS run:
> 1. **Conflict check** — checks that there are no conflicts with patches already applied
> 2. **Space check** — checks for sufficient disk space
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

> **Why opatchauto?** For Grid Infrastructure, you can't use plain `opatch apply`. You have to use `opatchauto` (as root), which:
> 1. Ferma il CRS automaticamente
> 2. Applica la patch
> 3. Riavvia il CRS
> It does everything in one go, even managing cluster service dependencies.

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
**⚠️ DO NOT USE DBCA! DO NOT CREATE THE DATABASE!** We only need the software (engine off) because we will clone the data via the network.

#### 4.6 Patching Database Home (Combo Patch) on Standby

> [!IMPORTANT]
> **ORDER OF OPERATIONS**: You must update the OPatch utility **BEFORE** launching `opatchauto apply`. If you try to apply the January 2026 RU with an older OPatch (version < 12.2.0.1.48), the operation will fail.

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

> **Nota**: `opatchauto` automatically recognizes that it is a Home DB in a RAC cluster and handles patching accordingly.

```bash
# Ripeti su racstby2
ssh racstby2 "chown -R oracle:oinstall /u01/app/patch"
ssh racstby2
cd /u01/app/patch/38658588/38629535
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME
```

### Step 3: Applica il Patch OJVM

The OJVM patch is bundled inside the Combo Patch. We have already unpacked everything in Step 2 of Grid, so the files are already ready in `/u01/app/patch/38658588/`. Si applica con `opatch apply` standard puntando alla sottocartella OJVM.

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

### Step 4: Check Applied Patches and Cleaning

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

At this point, the Standby infrastructure (Grid engine + patched RDBMS) is identical to the Primary cluster. We are ready to connect the database.

> Important note: in this standby phase you **do not** have to run `DBCA` and you **don't** have to execute `datapatch` on standby. The patched dictionary will arrive from the primary via redo after the duplicate.

---

## 3.1 Standby Node Prerequisites

To verify that you are ready to continue with Data Guard, perform this checklist on the standby nodes:
- ✅ **Phase 1 complete** via cloning (OS, DNS, users, SSH) on `racstby1` e `racstby2`.
- ✅ **Grid Infrastructure installed** (aligned with Phase 2 steps: 2.3-2.7) on `racstby1` e `racstby2`.
- ✅ **RU/OJVM Grid Patch applied** (Phase 2 alignment: 2.8) and verifiable with `opatch lspatches`.
- ✅ **Database Software Installed** (Phase 2 alignment: 2.9, Software Only, no DBCA).
- ✅ **DB Home RU/OJVM patches applied** (Phase 2 alignment: 2.11) and verifiable with `opatch lspatches`.
- ✅ The Disk Groups **DATA** and **RECO** exist on standby with the same names as the primary and discovery path `/dev/oracleasm/disks/*`.
- ✅ No standby database created via DBCA; it will only be created via RMAN Duplicate.

> **Why same names as Disk Groups?** RMAN Duplicate searches for disk groups by name. If on the primary the datafiles are in `+DATA` and on standby it does not exist `+DATA`, il duplicate fallisce.

---

## 3.2 Static Listener Configuration on the Primary

The Dynamic Listener (registered by PMON) is not sufficient for Data Guard. We need to add a **static** entry because the standby database needs to be able to connect even when the primary instance is not fully open.

### On the Primary (`rac1`, as a user `grid`)

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

Do the same on `rac2` cambiando `SID_NAME = RACDB2`.

```bash
# Riavvia il listener
srvctl stop listener
srvctl start listener

# Verifica
lsnrctl status
# Deve mostrare le entry statiche
```

> **Why Static Listener?** When the database is mounted (not open), the PMON service does not dynamically register with the listener. But Data Guard needs to connect to the database in mount to apply redos. The static listener solves this problem.

---

## 3.3 Static Listener Configuration on Standby

### Su `racstby1` (as a user `grid`)

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

Same up `racstby2` con `SID_NAME = RACDB2`.

```bash
srvctl stop listener
srvctl start listener
```

---

## 3.4 TNS Names configuration

Il file `tnsnames.ora` must be identical on **ALL** nodes (primary and standby).

### On Primary and Standby (`$ORACLE_HOME/network/admin/tnsnames.ora`, as a user `oracle`)

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
> - alias dedicati al trasporto redo (`RACDB_DG`, `RACDB_STBY_DG`) con `ADDRESS_LIST` on all nodes for Data Guard robustness.
>
> Questo approccio ibrido evita single point of failure e riduce errori tipo `ORA-12514` during node restart/failover.
>
> In pratica:
> - SCAN = ingresso "front door" del cluster;
> - alias `_DG` = canale redo/FAL resiliente con piu indirizzi.

### Alias ​​map (when to use what)

- `RACDB`, `RACDB_STBY`: connessioni client/app e amministrazione generale (SCAN).
- `RACDB_DG`, `RACDB_STBY_DG`: redo transport (`LOG_ARCHIVE_DEST_n`) e gap resolution (`FAL_SERVER`).
- `RACDB1`, `RACDB2`, `RACDB1_STBY`, `RACDB2_STBY`: instance-specific connections (duplicate RMAN, targeted troubleshooting).

> **Why is tnsnames.ora identical everywhere?** Data Guard uses these TNS aliases to communicate between primary and standby. If an entry is missing on a node, redo shipping fails.

> **Things `(UR=A)`?** "Use Role = Any" — allows connection even when the database is in NOMOUNT or MOUNT state (not just OPEN). Essential for standby that is never in READ WRITE. Without `UR=A`, `tnsping` funziona ma `sqlplus sys@RACDB_STBY as sysdba` fallisce con timeout.

### TNS Connectivity Test

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

### Official Oracle references (network/redo transport best practices)

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
- Oracle Data Guard 19c (Creating Physical Standby with Duplicate RMANs):
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/creating-oracle-data-guard-physical-standby.html

---

## 3.5 Configuring the Primary for Data Guard

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

> **Why Standby Redo Logs?** When redo logs arrive from the primary, the standby first writes them to the Standby Redo Logs and THEN applies them. Without SRL, it uses archived redo logs, which are slower. The "+1" rule ensures that there is always an SRL available even during a log switch.

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

> **Expected at this stage (pre-duplicate):**
> - if the standby is not still standing with instance available, `DEST_ID=2` can show `ERROR` con `ORA-01034` oppure `ORA-12514`;
> - non e un blocco, e normale finche non completi `3.9` (startup standby) e `3.10` (RMAN duplicate).
>
> **Gate corretto:**
> - **before** the duplicate: `DEST_ID=1=VALID`, `DEST_ID=2` can be `ERROR`;
> - **after** duplicate + apply active: `DEST_ID=2` it must become `VALID` con `ERROR` nullo.
>
> **Oracle best practices:** on standby do not use DBCA in this flow; the standby database is created with `RMAN DUPLICATE ... FOR STANDBY FROM ACTIVE DATABASE`.
>
> **Nota critica per evitare `BAD PARAM` on standby:**
> - the commands in this block are from the **primary**;
> - on standby, `log_archive_dest_1` must use `DB_UNIQUE_NAME=RACDB_STBY`, non `RACDB`;
> - if you copy on standby `log_archive_dest_1 ... DB_UNIQUE_NAME=RACDB`, `V$ARCHIVE_DEST.STATUS` can become `BAD PARAM` and the alert log can show `ARCn: Archiving not possible: error count exceeded`.

```sql
-- Re-check obbligatorio post-duplicate (quando standby e in MOUNT + apply)
SELECT dest_id, status, target, valid_role, error
FROM   v$archive_dest
WHERE  dest_id IN (1,2)
ORDER  BY dest_id;
```

### Detailed explanation (command by command)

This is the backbone of Data Guard: you are telling the primary who is the standby, where to send the redos and how to behave in case of switchover/failover.

1. **Definizione perimetro Data Guard (`log_archive_config`)**
   - Comando:
   ```sql
   ALTER SYSTEM SET log_archive_config='DG_CONFIG=(RACDB,RACDB_STBY)' SCOPE=BOTH SID='*';
   ```
   - What it does: Only authorize databases with `DB_UNIQUE_NAME` `RACDB` e `RACDB_STBY` to participate in the configuration.
   - Why it is needed: avoid shipments/redo acceptances to unforeseen targets.
   - Nota RAC: `SID='*'` applies the parameter to all instances (`rac1`, `rac2`).

2. **Destinazioni archivelog locale e remota (`log_archive_dest_1`/`_2`)**
   - Commands:
   ```sql
   ALTER SYSTEM SET log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=RACDB' SCOPE=BOTH SID='*';
   ALTER SYSTEM SET log_archive_dest_2='SERVICE=RACDB_STBY_DG LGWR ASYNC REOPEN=15 VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB_STBY' SCOPE=BOTH SID='*';
   ```
   - `dest_1` locale: archivia sempre in FRA, sia in ruolo `PRIMARY` sia in ruolo `STANDBY`.
   - `dest_2` remota:
     - `SERVICE=RACDB_STBY_DG`: uses TNS alias dedicated to redo transport to standby.
     - `LGWR ASYNC`: spedizione asincrona (modalita tipica `Maximum Performance`).
     - `REOPEN=15`: se il link cade, ritenta automaticamente ogni 15 secondi.
     - `VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE)`: send redo only when this DB is primary.

3. **Attivazione destinazioni (`log_archive_dest_state_n`)**
   - Commands:
   ```sql
   ALTER SYSTEM SET log_archive_dest_state_1=ENABLE SCOPE=BOTH SID='*';
   ALTER SYSTEM SET log_archive_dest_state_2=ENABLE SCOPE=BOTH SID='*';
   ```
   - What it does: Operationally enables the newly defined destinations.
   - Se resta `DEFER`, the configuration is correct but the shipment does not start.

4. **Redo gap management (`fal_server` / `fal_client`)**
   - Commands:
   ```sql
   ALTER SYSTEM SET fal_server='RACDB_STBY_DG' SCOPE=BOTH SID='*';
   ALTER SYSTEM SET fal_client='RACDB' SCOPE=BOTH SID='*';
   ```
   - What it does: Prepares the Fetch Archive Log (FAL) mechanism to automatically retrieve missing archivelogs.
   - Because even on the primary: in the event of a switchover the roles are reversed, so the parameters must already be ready.

5. **Automatic file creation on standby (`standby_file_management=AUTO`)**
   - Comando:
   ```sql
   ALTER SYSTEM SET standby_file_management=AUTO SCOPE=BOTH SID='*';
   ```
   - What it does: When you add datafiles/tablespaces on the primary, the standby handles them automatically.
   - Rischio con `MANUAL`: apply can stop on every structural change.

6. **Conversione path file (`db_file_name_convert`, `log_file_name_convert`)**
   - Commands:
   ```sql
   ALTER SYSTEM SET db_file_name_convert='+DATA/RACDB_STBY/','+DATA/RACDB/' SCOPE=SPFILE SID='*';
   ALTER SYSTEM SET log_file_name_convert='+DATA/RACDB_STBY/','+DATA/RACDB/','+FRA/RACDB_STBY/','+FRA/RACDB/' SCOPE=SPFILE SID='*';
   ```
   - What it does: Maps ASM paths between primary and standby for datafile/redofile when role changes.
   - Why `SCOPE=SPFILE`: These parameters are static and require restart instance to take effect.

### Quick checks after configuration

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

### How Redo Shipping Works

```
PRIMARY (RACDB) STANDBY (RACDB_STBY)
════════════════                              ═════════════════════

User does COMMIT
     │
     ▼
┌──────────┐                                  
│  LGWR    │──── Scrive ───►┌──────────────┐  
│          │                │ Online Redo  │  
│          │                │ Log (locale) │  
│          │                └──────┬───────┘  
│          │                       │          
│          │── Spedisce ──────────────────────►┌──────────────┐
│ │ (ASYNC via network) │ Standby Redo │
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

### Written explanation (step-by-step)

1. On the primary, when a user does `COMMIT`, il processo `LGWR` writes to local redo logs first.
2. Con `LOG_ARCHIVE_DEST_2` active, the same redo is sent to standby using the net service (`RACDB_STBY_DG`).
3. On standby, the incoming redo doesn't go into the datafiles straight away: it goes into the datafiles first `Standby Redo Log` (SRL).
4. Il processo `MRP` (Managed Recovery Process) reads the SRLs and applies changes to the standby datafiles.
5. Finche `MRP` e attivo (`APPLYING_LOG`), the standby remains aligned with the primary with minimal lag.

In this guide we use `LGWR ASYNC` (modalita `Maximum Performance`):
- the primary does not wait for the standby's ack before confirming the commit;
- maximum performance, but in the event of a simultaneous primary+network crash there may be minimal loss of the last redos that have not yet arrived.

### How to check that the flow is healthy

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
- `DEST_ID=2` con `STATUS=VALID` e `ERROR` null on the primary;
- `MRP0` in state `APPLYING_LOG` on standby.

Se `DEST_ID=2` va in `ERROR`:
- `ORA-12514`: service/listener/TNS problem;
- `ORA-01034`: standby not available (typical pre-duplicate or down instance).

---

## 3.6 File Password Creation and Copy

### What are we really doing

In questo punto non stai "creando ASM". Stai facendo due operazioni diverse:

1. read or extract the database password file from where it is saved on the primary;
2. put an identical copy on the standby nodes, with the right name for each instance.

In RAC the database password file is often saved in ASM, so:

- per entrare in ASM usi `grid` + `~/.grid_env`
- per lavorare nel database home usi `oracle` + `~/.db_env`

Questa e' la logica corretta:

- `grid` gestisce Grid Infrastructure e ASM
- `oracle` gestisce il database home e i file sotto `$ORACLE_HOME/dbs`

The password file is a database file, but if it is located in `+DATA/...` you have to go through ASM first to get it out. That's why in this step you start as `grid`.

### Because Data Guard needs the password file

Data Guard and RMAN use the password file to authenticate remote administrative connections (`SYS`, redo transport, duplicate, broker).

Regole da ricordare:

- the contents of the password file must be consistent between primary and standby
- the local file on the standby must have the right name for the instance
- in your lab, before `RMAN DUPLICATE`, standby starts from local files in the home database

If the file is wrong or missing, you may see errors like:

- `ORA-01017`
- `ORA-01031`
- `ORA-17627`
- `ORA-19909`

### Step 1 - Figure out where the password file is on the primary

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

Se `pwget` restituisce un path ASM (`+DATA/...`), the password file is in ASM and you need to use the flow from step 2.

If you don't find anything in ASM, check the home database side:

```bash
su - oracle
. ~/.db_env
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1
```

### Step 2 - If the password file is in ASM, copy it from ASM to the filesystem

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

What does it do `chgrp oinstall /tmp/orapwRACDB1`?

- non cambia il proprietario del file
- cambia solo il gruppo Unix associato al file in `oinstall`

In pratica:

- owner resta `grid`
- group diventa `oinstall`

This helps in the lab because:

- the user `oracle` appartiene al gruppo `oinstall`
- con `chmod 640`, the group can read the file
- Therefore `oracle` riesce a fare `scp` of the password file without having to use `root`

Waiting check:

```bash
ls -l /tmp/orapwRACDB1
```

Output tipico:

```text
-rw-r----- 1 grid oinstall ... /tmp/orapwRACDB1
```

If you prefer to avoid any doubts about permissions, you can also make the copy as `grid` and then place owner/perms on the standby node as `oracle`.

Because here you use `grid`?

- `asmcmd` vive nel Grid home
- ASM e' amministrato dalla Grid Infrastructure
- Oracle documenta `pwcopy` e `pwget` as ASMCMD commands for ASM file/database passwords

### Step 3 - If the password file is already in the filesystem on the primary

In this case you don't need it `grid`. You work directly as `oracle`.

Se il file esiste gia':

```bash
su - oracle
. ~/.db_env
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1
```

If instead you need to create a new one on the filesystem:

```bash
su - oracle
. ~/.db_env
cd /u01/app/oracle/product/19.0.0/dbhome_1/dbs
orapwd file=orapwRACDB1 password=<tua_password_sys> entries=10 force=y
```

### Step 4 - Copy the file to the standby nodes

Before duplicating you want a local password file in the home DB of each standby node.

Nel tuo lab:

- `racstby1` usa `ORACLE_SID=RACDB1`
- `racstby2` usa `ORACLE_SID=RACDB2`

So the names must be:

- `orapwRACDB1` su `racstby1`
- `orapwRACDB2` su `racstby2`

The two files have equivalent content, but different names because each instance reads `orapw$ORACLE_SID`.

```bash
# Su rac1 come oracle
su - oracle
. ~/.db_env

scp /tmp/orapwRACDB1 oracle@racstby1:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1
scp /tmp/orapwRACDB1 oracle@racstby2:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB2
```

### Step 5 - Check on standby

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

### Step 6 - What already exists and what does NOT yet exist

Nel tuo lab, a questo punto:

- Standby servers already exist `racstby1` e `racstby2`
- The standby Grid Infrastructure already exists
- the DB Home standby already exists
- ASM, listener, network and standby storage already exist

But there is NO standby database yet `RACDB_STBY` as a duplicate physical database.

Questo e' il punto chiave:

- standby as infrastructure already exists
- the standby as Oracle database still needs to be created by RMAN

Soon after you will use:

- il `pfile` locale in `dbs/initRACDB1.ora`
- the local file password in `dbs/orapwRACDB1`

to start just ONE auxiliary instance:

- node `racstby1`
- instance `RACDB1`
- state `NOMOUNT`

e poi lanciare:

- `RMAN DUPLICATE FOR STANDBY`

So, at this stage:

- `racstby1` is used to create the standby database
- `racstby2` it should not be started as a database instance yet
- `orapwRACDB2` su `racstby2` you prepare him in advance for the next step

For this reason you do not need to re-enter the standby password file in ASM yet. The local file in the home DB is fine to start with the auxiliary instance.

### Step 7 - Note post-duplicate best practices

After the RAC standby is created and registered correctly, you can decide to realign the standby password file in ASM as well.

This is a next step, not mandatory to unlock the duplicate.

Conceptual example:

```bash
# Esempio post-duplicate, non farlo adesso se non hai ancora creato lo standby
su - grid
. ~/.grid_env
asmcmd
ASMCMD> pwcopy --dbuniquename RACDB_STBY /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwRACDB1 +DATA/RACDB_STBY/PASSWORD/orapwRACDB_STBY -f
ASMCMD> exit
```

### Quick procedure to follow now in the lab

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

## 3.7 Creation of the PFILE for Standby

### Real objective of step 3.7

Here you are not yet configuring all the standby RAC.

Stai creando un `pfile` temporary to start ONLY the first standby instance:

- node `racstby1`
- instance `RACDB1`
- state `NOMOUNT`

Questo basta a RMAN per usare `racstby1` as `AUXILIARY` and build the standby database.

`racstby2` will come into play later, when the duplication is finished and the standby database is registered in the cluster.

```bash
# Sul primario come oracle
su - oracle
. ~/.db_env
sqlplus / as sysdba
CREATE PFILE='/tmp/initRACDB_stby.ora' FROM SPFILE;
EXIT;
```

Edit the pfile for standby:

```bash
vi /tmp/initRACDB_stby.ora
```

### How to clean up pfile exported from primary

Il `CREATE PFILE FROM SPFILE` it generates a "dirty" file of primary parameters.

In the standby file you need to do three things:

1. change the parameters that identify the standby role
2. correggere i convert `PRIMARY -> STANDBY`
3. remove automatic or too specific primary parameters

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
- specific to the primary
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

- in the standby pfile the correct direction is `PRIMARY -> STANDBY`
- Therefore `RACDB` va convertito in `RACDB_STBY`
- if you leave the direction reversed, RMAN and standby startup point to the wrong paths
- durante il duplicate RAC, tieni `cluster_database=FALSE` sull'auxiliary; lo riporterai a `TRUE` after the duplicate, when you will switch to shared SPFILE and OCR recording

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

Operational note:

- in questo pfile temporaneo evita `*.control_files`
- con ASM + OMF (`db_create_file_dest` / FRA) e `RMAN DUPLICATE`, it is best to let Oracle/RMAN build the standby control files
- the pfile here is just for bringing up `racstby1` in `NOMOUNT` in modo pulito

Copy on standby:

```bash
# Copia SOLO su racstby1: per il duplicate basta una sola istanza auxiliary
scp /tmp/initRACDB_stby.ora oracle@racstby1:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB1.ora
```

Nota importante:

- in this step DO NOT copy yet `initRACDB2.ora` su `racstby2`
- the second node will be aligned after the duplicate when you create it `SPFILE` condiviso in ASM e il pointer file per `RACDB2`

---

## 3.8 Creation of Audit Folders on Standby

You prepare these directories on both nodes to avoid errors when, later, you also mount the second standby instance.

```bash
# Su racstby1 e racstby2 come oracle
mkdir -p /u01/app/oracle/admin/RACDB_STBY/adump
mkdir -p /u01/app/oracle/admin/RACDB/adump
```

---

## 3.9 Starting Standby Instance in NOMOUNT

### Real objective of step 3.9

Here you are NOT starting full standby RAC.

Stai avviando solo:

- `racstby1`
- instance `RACDB1`
- con `PFILE` locale
- in state `NOMOUNT`

Questo e' il prerequisito richiesto da `RMAN DUPLICATE FROM ACTIVE DATABASE`.

`racstby2` in questo momento resta fermo. E' normale.

Before the command `STARTUP`, fai sempre questi pre-check (best practice):

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

If the file does not exist, go back to the step `3.7` e ricopia il pfile:

```bash
scp /tmp/initRACDB_stby.ora oracle@racstby1:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB1.ora
```

If the password file is missing, go back to the step `3.6` e ricopialo da `rac1`.

```bash
# Su racstby1 come oracle
su - oracle
. ~/.db_env
export ORACLE_SID=RACDB1
sqlplus / as sysdba
STARTUP NOMOUNT PFILE='/u01/app/oracle/product/19.0.0/dbhome_1/dbs/initRACDB1.ora';
EXIT;
```

> Note: **NOMOUNT** (not MOUNT) is used at this point in the guide to allow the `RMAN DUPLICATE`.
> Nota 2: `racstby2` It should NOT be started now. It will be handled after the duplicate.

Mandatory pre-check before entering RMAN:

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
- `cluster_database = FALSE` during the duplication phase
- login remoto su `RACDB1_STBY` riuscito

Se il login remoto fallisce con:

- `ORA-01034`: the auxiliary instance is not actually started `NOMOUNT`
- `ORA-12514` o `ORA-12528`: static listener problem / alias TNS / `(UR=A)`

---

## 3.10 RMAN Duplicate da Active Database

This is the magic! RMAN copies the database from primary to standby **in real time**, without the need for physical backups.

### What is RMAN really doing here

RMAN usa:

- the primary database `RACDB` as `TARGET`
- the only instance `RACDB1` su `racstby1` as `AUXILIARY`

So the duplicate, at this stage, is a single-instance operation on node 1, even if the final standby will be two-node RAC.

La sequenza corretta e':

1. build standby database using `racstby1`
2. metti `SPFILE` in ASM
3. register the standby database in OCR
4. start too `RACDB2` su `racstby2`

> 📸 **SNAPSHOT — "SNAP-07: Standby_Grid_e_OS_Pronti" 🔴 CRITICO**
> RMAN Duplicate is the most delicate operation. If it fails (and it often happens the first time), you come back here and save a LOT of time.
> **Take snapshots on ALL VMs (rac1, rac2, racstby1, racstby2)!**
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
- You do NOT have to write the characters `<` e `>` nel comando reale
- Bash interpreta `<password>` as input redirection and tries to open a file called `password`
- the Oracle password is case-sensitive, therefore `Root_1234` e `root_1234` They are NOT the same thing

Real example:

```bash
rman TARGET "sys/Root_1234@RACDB" AUXILIARY "sys/Root_1234@RACDB1_STBY"
```

If you want to avoid leaving the password in the command history, first enter RMAN and then do the connect:

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

> **Explanation of the RMAN command:**
> - `FOR STANDBY`: Create a standby database, not a clone.
> - `FROM ACTIVE DATABASE`: Copy data files directly over the network, without the need for a disk backup.
> - `DORECOVER`: Automatically apply missing archivelogs after copying.
> - `SPFILE SET ...`: Overwrites the parameters in the standby SPFILE.
> - `NOFILENAMECHECK`: Don't check that the file paths are different (useful because we use the same ASM names).

### Warning RMAN attesi con ASM / OMF

During duplication you may see warnings like:

- `RMAN-05538: warning: implicitly using DB_FILE_NAME_CONVERT`
- `RMAN-05529: warning: DB_FILE_NAME_CONVERT resulted in invalid ASM names; names changed to disk group only`
- `RMAN-05158: WARNING: auxiliary file name ... conflicts with a file used by the target database`

In your lab these warnings are normally benign if all of these conditions hold:

- primary and standby are on separate ASM storage
- i disk group hanno gli stessi nomi (`+DATA`, `+RECO`) but they are NOT the same disks shared between the two clusters
- il duplicate continua a creare/restore i file senza fermarsi con errore fatale

Why they appear:

- RMAN sees primary OMF names as `+DATA/RACDB/...`
- prova a usare `DB_FILE_NAME_CONVERT`
- with ASM + OMF the result may not be a full valid ASM name
- then Oracle reduces the name to just the disk group and automatically generates the correct OMF name on standby

So:

- `RMAN-05529` in questo contesto e' spesso solo informativo
- `RMAN-05158` segnala un conflitto "logico di nome", non necessariamente un conflitto reale di storage
- con `NOFILENAMECHECK` and separate standby storage, you can normally let the duplicate continue

When you need to stop and correct:

- se il duplicate si arresta con errori successivi di restore/create file
- if standby and primary are really using the same ASM disks
- se hai lasciato i convert nel verso sbagliato
- se `db_create_file_dest` / `db_recovery_file_dest` they do not point to the correct disk groups on standby

Expected status at the end of the step:

- the standby database exists
- `racstby1` it is the node used to build it
- `racstby2` it hasn't started as a second database instance yet

The operation can take 20-60 minutes depending on the size of the DB.

---

## 3.11 SPFILE creation in ASM and Pointer File

After the duplicate, the standby can be in one of these states:

- use one more `spfileRACDB1.ora` locale in `$ORACLE_HOME/dbs`
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

So if it still exists `$ORACLE_HOME/dbs/spfileRACDB1.ora`, Oracle usera' quello e ignorera' il pointer file `initRACDB1.ora`.

Questo spiega esattamente il caso in cui:

- hai creato `initRACDB1.ora` con `SPFILE='+DATA/...'`
- ma `SHOW PARAMETER spfile` continua a mostrare `/u01/app/oracle/product/19.0.0/dbhome_1/dbs/spfileRACDB1.ora`

### Correct and complete sequence

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

Se ricevi:

- `ORA-17502`
- `ORA-15173: entry 'PARAMETERFILE' does not exist in directory 'RACDB_STBY'`

This means that the alias directory for the parameter file is still missing in ASM. Create it before re-rolling `CREATE SPFILE`:

```bash
# Su racstby1 come grid
su - grid
. ~/.grid_env
asmcmd

ASMCMD> ls +DATA
ASMCMD> mkdir +DATA/RACDB_STBY
ASMCMD> mkdir +DATA/RACDB_STBY/PARAMETERFILE
ASMCMD> exit
```

Then it comes back as `oracle` e rilancia:

```sql
sqlplus / as sysdba
CREATE SPFILE='+DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora'
  FROM PFILE='/tmp/racdb_stby_after_duplicate.ora';
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

Expected status at the end of the step:

- `SHOW PARAMETER spfile` mostra `+DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora`
- `cluster_database` risulta `TRUE`
- `racstby1` monta il database usando lo SPFILE condiviso
- `racstby2` already has the pointer file ready for the next step

> Why SPFILE in ASM? In RAC, parameters must be shared among all nodes. If you leave the SPFILE in the local filesystem of `racstby1`, `racstby2` he doesn't see it. In ASM, however, the file is shared and consistent for the entire standby cluster.

> Operational best practice:
> - before duplicate, manual startup with `PFILE` e `NOMOUNT`;
> - durante il duplicate, usa solo `racstby1` as auxiliary;
> - immediately after the duplicate, move the configuration to the shared SPFILE in ASM;
> - after recording in OCR (step `3.12`), usa `srvctl` for start/stop standby instead of `startup` manuale.

---

## 3.12 Registration in the Cluster (OCR) and Starting the Second Node

After the duplicate, you need to register the standby database in the Oracle Cluster Registry (OCR) for the Clusterware to manage it.

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

## 3.13 Starting Redo Apply (MRP)

```sql
-- Su racstby1 come sysdba
sqlplus / as sysdba

-- Prima verifica se MRP e' gia' attivo
SELECT process, status, thread#, sequence#
FROM   v$managed_standby
WHERE  process IN ('MRP0','RFS');

-- Se NON vedi MRP0, avvia il Managed Recovery Process (MRP)
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

-- Verifica finale
SELECT process, status, thread#, sequence#
FROM   v$managed_standby
WHERE  process IN ('MRP0','RFS');
-- MRP0 deve risultare APPLYING_LOG o WAIT_FOR_LOG
```

Regola pratica:

- se `MRP0` e' gia' presente, non rilanciare il comando
- se `MRP0` non c'e', lancialo una volta su `racstby1`
- il fatto che le istanze risultino `Mounted (Closed)` it doesn't prove that redo apply is active: it just proves that standby is up and registered in the cluster

Nota Oracle 19c:

- in 19c il Real-Time Apply e' abilitato durante Redo Apply senza dover scrivere `USING CURRENT LOGFILE`
- la clausola `USING CURRENT LOGFILE` e' deprecata da 12.1 e non e' piu' necessaria
- if you have the Standby Redo Logs configured correctly, `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;` basta

```sql
-- Comandi utili per gestire MRP
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
SELECT process, status, thread#, sequence# FROM v$managed_standby WHERE process IN ('MRP0','RFS');
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

> **Why?** Without this policy, archivelogs will accumulate in the FRA until it is full (ORA-19502). With this policy, RMAN automatically deletes archivelogs that have already been applied to standby.

---

## 3.15 Check Synchronization

```sql
-- Sul PRIMARIO: forza attivita' redo su entrambi i thread RAC
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM ARCHIVE LOG CURRENT;

-- Verifica che la destinazione Data Guard sia sana
SELECT dest_id, status, error
FROM   v$archive_dest
WHERE  dest_id = 2;
```

```sql
-- Sullo STANDBY (racstby1): verifica ruolo e stato
SELECT open_mode, database_role
FROM   v$database;
```

```sql
-- Sullo STANDBY (racstby1): verifica transport/apply lag
SELECT name, value, unit
FROM   v$dataguard_stats
WHERE  name IN ('transport lag','apply lag','apply finish time');
```

```sql
-- Sullo STANDBY (racstby1): verifica processo di apply
SELECT process, status, thread#, sequence#
FROM   v$managed_standby
WHERE  process IN ('MRP0','RFS');
```

```sql
-- Sullo STANDBY (racstby1): confronto corretto tra ultimo log ricevuto e ultimo log applicato
SELECT thread#,
       MAX(sequence#) AS last_received,
       MAX(CASE WHEN applied = 'YES' THEN sequence# END) AS last_applied
FROM   v$archived_log
GROUP  BY thread#
ORDER  BY thread#;
```

How to read these results correctly:

- `database_role` it must be `PHYSICAL STANDBY`
- `open_mode` it must be `MOUNTED`
- `MRP0` must be present on `racstby1`, with state `APPLYING_LOG` oppure `WAIT_FOR_LOG`
- `DEST_ID=2` must appear on the primary `VALID` e senza errore
- `transport lag` e `apply lag` devono essere nulli o molto bassi

Nota importante:

- do not use the query as the only criterion `MAX(sequence#)` between primary and standby
- in Real-Time Apply, a 1 sequence gap may be normal for a few seconds
- the primary may have already opened the next sequence while the standby is still receiving or applying the previous one
- il confronto corretto e' `last_received` vs `last_applied` on standby, together with `MRP0` e `v$dataguard_stats`

Shell one-liner utili:

```bash
sqlplus -s / as sysdba <<< "SELECT process, status, thread#, sequence# FROM v\$managed_standby WHERE process IN ('MRP0','RFS');"
sqlplus -s / as sysdba <<< "SELECT thread#, MAX(sequence#) AS last_received, MAX(CASE WHEN applied='YES' THEN sequence# END) AS last_applied FROM v\$archived_log GROUP BY thread# ORDER BY thread#;"
sqlplus -s / as sysdba <<< "SELECT name, value, unit FROM v\$dataguard_stats WHERE name IN ('transport lag','apply lag','apply finish time');"
```

---

## 3.16 Troubleshooting Phase 3

| Problema | Causa | Soluzione |
|---|---|---|
| `ORA-01078` + `LRM-00109` on startup standby | File `initRACDB1.ora` assente o path errato | Esegui runbook `Fix ORA-01078/LRM-00109` qui sotto |
| `ORA-01034` + `SP2-1545` su `show pdbs` | Standby instance not started or standby in MOUNT | Start instance (NOMOUNT/MOUNT) and use query `v$database` invece di `show pdbs` |
| `ORA-01017` su `sqlplus sys@RACDB_STBY` | Incorrect file password | Check name = `orapw<SID>`, owner = `oracle` |
| `ORA-12514` su `V$ARCHIVE_DEST` (`DEST_ID=2`) | Standby service not registered/reachable | Esegui runbook `Fix ORA-12514` qui sotto |
| `ORA-12528: TNS:listener: all ... blocked` | DB in NOMOUNT senza `UR=A` | Aggiungi `(UR=A)` in the standby TNS |
| `ORA-16055: FAL request rejected` | `log_archive_dest` errato | Correggi su ENTRAMBI i lati (vedi sotto) |
| RMAN Duplicate timeout/hang | Slow network or SSH session dropped | Usa `nohup` o `screen`, check network |
| MRP non parte: `ORA-00270` | FRA full on standby | Pulisci archivelog: `DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-2';` |
| `v$archive_gap` mostra gap | Archivelog missing | `ALTER SYSTEM SET fal_server='RACDB_DG' SCOPE=BOTH;` → FAL recupera automaticamente |

### Valutazione `ARCn: Archiving not possible: error count exceeded`

Sintomo tipico nel `alert.log` of standby:

```text
ARC1 (PID:...): Archiving not possible: error count exceeded
PR00 (PID:...): Media Recovery Waiting for T-1.S-30 (in transit)
rfs  (PID:...): Selected LNO:...
```

How to read it correctly:

- if in the same period see also `MRP0` in `APPLYING_LOG` o `WAIT_FOR_LOG`, il redo apply sta comunque funzionando;
- la presenza di `RFS` e messaggi `Media Recovery Waiting for ... (in transit)` indica tipicamente che il trasporto redo e' vivo;
- questo warning, da solo, non significa che hai rotto Data Guard.

Checks to do on standby (`racstby1`):

```sql
SELECT process, status, thread#, sequence#
FROM   v$managed_standby
WHERE  process IN ('MRP0','RFS');

SELECT name, value, unit
FROM   v$dataguard_stats
WHERE  name IN ('transport lag','apply lag','apply finish time');

SELECT dest_id, status, type, valid_type, valid_role, error, destination
FROM   v$archive_dest
WHERE  dest_id IN (1,2)
ORDER  BY dest_id;
```

Check to do on the primary:

```sql
SELECT dest_id, status, error
FROM   v$archive_dest
WHERE  dest_id = 2;
```

Interpretazione corretta:

- se `MRP0` e' attivo;
- se `transport lag` e `apply lag` sono nulli o bassi;
- se sul primary `DEST_ID=2` e' `VALID`;

then the ARCn warning is secondary and does not require immediate action.

Intervieni davvero solo se succede almeno uno di questi casi:

- `MRP0` sparisce o non e' piu' in apply;
- `DEST_ID=2` va in `ERROR`;
- compaiono ORA espliciti su FRA piena, ASM, archivelog destination o file create;
- il lag cresce stabilmente e non rientra.

Caso tipico nel lab:

- standby with `MRP0` sano;
- primary con `DEST_ID=2` `VALID`;
- standby with `DEST_ID=1` `BAD PARAM`;
- `log_archive_dest_1` configurato con `DB_UNIQUE_NAME=RACDB` invece di `RACDB_STBY`.

Correct fix on standby:

```sql
ALTER SYSTEM SET log_archive_dest_1=
'LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=RACDB_STBY'
SCOPE=BOTH SID='*';

ALTER SYSTEM SET log_archive_dest_state_1=ENABLE SCOPE=BOTH SID='*';
```

Then check:

```sql
SELECT dest_id, status, error, destination
FROM   v$archive_dest
WHERE  dest_id IN (1,2)
ORDER  BY dest_id;
```

### Fix ORA-01078 / LRM-00109 on standby (file parameter missing)

Sintomo tipico:

```text
ORA-01078: failure in processing system parameters
LRM-00109: could not open parameter file '.../dbs/initRACDB1.ora'
```

Procedure:

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

If you are already in the post-duplicate phase and have SPFILE in ASM:

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

### Fix ORA-12514 su `DEST_ID=2` (redo transport to standby)

Sintomo tipico:

```sql
SELECT dest_id, status, error
FROM   v$archive_dest
WHERE  dest_id = 2;
-- STATUS = ERROR
-- ERROR  = ORA-12514: listener does not currently know of service requested
```

Quick procedure:

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
2. verify `listener.ora` static on both standbys (`GLOBAL_DBNAME = RACDB_STBY`);
3. restart standby listener:

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

## ✅ End of Phase 3 Checklist

```bash
# 1. Standby in mount su entrambi i nodi
srvctl status database -d RACDB_STBY -v

# 2. MRP attivo e APPLYING_LOG
sqlplus -s / as sysdba <<< "SELECT process, status FROM v\$managed_standby WHERE process='MRP0';"

# 3. Nessun gap
sqlplus -s / as sysdba <<< "SELECT * FROM v\$archive_gap;"
# (nessuna riga = tutto OK)

# 4. Apply attivo e lag basso
sqlplus -s / as sysdba <<< "SELECT process, status, thread#, sequence# FROM v\$managed_standby WHERE process IN ('MRP0','RFS');"
sqlplus -s / as sysdba <<< "SELECT name, value, unit FROM v\$dataguard_stats WHERE name IN ('transport lag','apply lag','apply finish time');"

# 5. Confronto corretto last_received vs last_applied sullo standby
sqlplus -s / as sysdba <<< "SELECT thread#, MAX(sequence#) AS last_received, MAX(CASE WHEN applied='YES' THEN sequence# END) AS last_applied FROM v\$archived_log GROUP BY thread# ORDER BY thread#;"

# 6. SPFILE in ASM (non locale!)
SHOW PARAMETER spfile;
# +DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora

# 7. Archivelog deletion policy configurata
rman target / <<< "SHOW ARCHIVELOG DELETION POLICY;"

# 8. Errori nel alert log? In ADRCI devi selezionare una singola home
adrci
set base /u01/app/oracle
show homes
# scegli una home rdbms, ad esempio:
# set homepath diag/rdbms/racdb_stby/RACDB1
# oppure sul primario:
# set homepath diag/rdbms/racdb/RACDB1
show alert -tail 30
```

Nota pratica su ADRCI:

- `DIA-48449: Tail alert can only apply to single ADR home` significa che sei in un host RAC con piu' ADR home disponibili
- `DIA-48494: ADR home is not set` it means you need to set up first `set base` e poi `set homepath`
- `show homes` ti restituisce il valore esatto da usare in `set homepath`

Quick example:

```bash
adrci
set base /u01/app/oracle
show homes
set homepath diag/rdbms/racdb_stby/RACDB1
show alert -tail 30
```

### What is ADRCI and how to actually use it

`ADRCI` significa `Automatic Diagnostic Repository Command Interpreter`.
E' la shell Oracle per leggere e navigare i file diagnostici:

- alert log;
- trace file;
- incidenti;
- homes diagnostics of databases, listeners, ASM and Clusterware.

Why you need it in the lab:

- in RAC you have more instances and therefore more alert logs;
- in Data Guard vuoi leggere rapidamente il lato giusto (`RACDB1`, `RACDB2`, `RACDB_STBY`, listener, ASM);
- `adrci` e' piu' preciso di un semplice `tail -f` when you have multiple diagnostic homes in the same host.

Concetti chiave:

- `ADR base`: radice del repository diagnostico, nel tuo lab tipicamente `/u01/app/oracle`
- `ADR home`: single concrete diagnostic area, for example:
  - `diag/rdbms/racdb/RACDB1`
  - `diag/rdbms/racdb/RACDB2`
  - `diag/rdbms/racdb_stby/RACDB1`
  - `diag/tnslsnr/rac1/listener`

Sequenza standard di uso:

```bash
adrci
set base /u01/app/oracle
show homes
set homepath diag/rdbms/racdb_stby/RACDB1
show alert -tail 30
```

Useful commands:

```bash
show homes
show alert -tail 50
show alert -term
show incident
show problem
purge -age 1440 -type alert
```

When to use what:

- `show alert -tail 30`: ultimi messaggi rapidi
- `show alert -term`: streaming in terminale
- `show incident`: elenco incidenti Oracle registrati
- `show problem`: raggruppamento per problema

Regola pratica nel tuo lab:

- for standby errors use first `diag/rdbms/racdb_stby/RACDB1`
- for primary errors use `diag/rdbms/racdb/RACDB1`
- if the problem seems to be network or registration service, also check the listener home

Differenza rispetto a `tail -f`:

- `tail -f` e' ottimo se sai gia' il file esatto
- `adrci` It's better when you first have to understand which home diagnostics to look at

Errori comuni ADRCI:

- `DIA-48449`: hai piu' home e non ne hai scelta una
- `DIA-48494`: you haven't set yet `ADR base` / `homepath`

Mini runbook RAC/Data Guard:

```bash
# Standby instance alert log
adrci
set base /u01/app/oracle
set homepath diag/rdbms/racdb_stby/RACDB1
show alert -tail 50

# Primary instance alert log
set homepath diag/rdbms/racdb/RACDB1
show alert -tail 50

# Listener alert log
set homepath diag/tnslsnr/racstby1/listener
show alert -tail 50
```

> 📸 **SNAPSHOT — "SNAP-08: RMAN_Duplicate_Finito" ⭐ MILESTONE**
> Standby is operational with MRP active and 0 gap! This is probably the most important snapshot after the primary is created.
> ```bash
> VBoxManage snapshot "rac1" take "SNAP-08: RMAN_Duplicate_Finito"
> VBoxManage snapshot "rac2" take "SNAP-08: RMAN_Duplicate_Finito"
> VBoxManage snapshot "racstby1" take "SNAP-08: RMAN_Duplicate_Finito"
> VBoxManage snapshot "racstby2" take "SNAP-08: RMAN_Duplicate_Finito"
> ```

---

## 📋 Useful Data Guard Commands — Quick Reference

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

**→ Next: [STEP 4: Configuring Data Guard and DGMGRL](./GUIDE_PHASE4_DATAGUARD_DGMGRL.md)**
