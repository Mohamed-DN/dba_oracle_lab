# FASE 1: Preparazione Nodi e OS (Proxmox VE + Oracle Linux 8.10)

## Obiettivo operativo

Preparare nodi coerenti per Grid Infrastructure e RAC prima dell'installazione Oracle.

## Procedura operativa

Configura rete, DNS, utenti, limiti, filesystem, tempo e SSH trust; ripeti i controlli su ogni nodo.

## Validazione finale

Conferma hostname, SCAN DNS, reachability, SSH senza password e prerequisiti OS.

## Troubleshooting rapido

Se un nodo diverge, correggi la golden image o la configurazione locale prima di installare Grid.

> **Architettura di riferimento**: 2 nodi RAC primario (`rac1`, `rac2`) + 2 nodi RAC standby (`racstby1`, `racstby2`).
> Tutti i comandi vanno eseguiti come `root` salvo dove diversamente indicato.
> I passaggi di questa fase vanno eseguiti su **`rac1`** e clonati sugli altri nodi.

---

### Cos'è il DNS e Perché Ci Serve?

**DNS (Domain Name System)** è il servizio che traduce i nomi in indirizzi IP. Quando digiti `rac-scan.localdomain`, il DNS risponde con `192.168.56.105, 192.168.56.106, 192.168.56.107`.

```text
  Senza DNS:                          Con DNS:
  ----------                          ---------

  Applicazione:                       Applicazione:
  "Connettimi a                       "Connettimi a
   192.168.56.105"                      rac-scan.localdomain"
           |                                    |
           v                                    v
  +----------------+                  +----------------+
  |  Connessione   |                  |  DNS Server    |
  |  a UN solo IP  |                  |  Risponde con  |
  |  (se cambia,   |                  |  3 IP in round |
  |   tutto si     |                  |  robin:        |
  |   rompe!)      |                  |  .105 .106 .107|
  +----------------+                  +--------+-------+
                                               |
                                      Load balanced!
                                      Se cambi un IP,
                                      aggiorni solo il DNS
```

**Perché Oracle RAC lo richiede?**
- Lo **SCAN** (Single Client Access Name) DEVE risolvere a 3 IP simultaneamente.
- `/etc/hosts` **NON** basta per lo SCAN. Non supporta il Round-Robin.
- Il DNS invece permette il **round-robin**: le connessioni dei client vengono distribuite automaticamente tra i 3 IP.

**Che DNS usiamo nel Lab? (Dnsmasq vs BIND)**
In produzione si usano server DNS complessi come **BIND**. In laboratorio, noi useremo **Dnsmasq**. Dnsmasq è un DNS leggerissimo che fa una cosa magica: **legge il suo file `/etc/hosts` e lo trasforma in record DNS interrogabili dalla rete**.

---

## 1.1 Piano IP e Hostname

| Ruolo | Hostname | IP Pubblica | IP Privata (Interconnect) | IP VIP |
|---|---|---|---|---|
| RAC Nodo 1 | rac1 | 192.168.56.101 | 192.168.1.101 | 192.168.56.103 |
| RAC Nodo 2 | rac2 | 192.168.56.102 | 192.168.1.102 | 192.168.56.104 |
| RAC SCAN | rac-scan | 192.168.56.105, .106, .107 | - | - |
| Standby Nodo 1 | racstby1 | 192.168.56.111 | 192.168.2.111 | 192.168.56.113 |
| Standby Nodo 2 | racstby2 | 192.168.56.112 | 192.168.2.112 | 192.168.56.114 |
| Standby SCAN | racstby-scan | 192.168.56.115, .116, .117 | - | - |

> **Perché?** Oracle RAC necessita di minimo 3 tipi di IP per nodo: Pubblica (comunicazione client), Privata (Cache Fusion, il "sangue" del cluster), VIP (failover trasparente).

### Come Funzionano le Reti del RAC

```text
                     +-------------------------------------------+
                     |        RETE PUBBLICA (vmbr1)              |
                     |     192.168.56.0/24 (Linux Bridge)        |
      Client App     |                                           |
          |          |  +------+  +------+  +------+            |
          v          |  |SCAN  |  |SCAN  |  |SCAN  |            |
    +----------+     |  | .105 |  | .106 |  | .107 |            |
    | SCAN     |<----|--+      |  |      |  |      | DNS        |
    | Listener |     |  +------+  +------+  +------+ Round-Robin|
    +----+-----+     |                                           |
         |           |  +-------------+   +-------------+       |
         +---------->|  | rac1        |   | rac2        |       |
         |           |  | IP: .101    |   | IP: .102    |       |
         |           |  | VIP: .111   |   | VIP: .112   |       |
         |           |  | (Se rac1    |   | (Se rac2    |       |
         |           |  |  muore, VIP |   |  muore, VIP |       |
         |           |  |  migra su   |   |  migra su   |       |
         |           |  |  rac2)      |   |  rac1)      |       |
         |           |  +------+------+   +------+------+       |
         |           +---------+------------------+-------------+
         |                     |                  |
         |           +---------+------------------+-------------+
         |           |         |  RETE PRIVATA    |  (vmbr2)    |
         |           |         |  192.168.1.0/24   |  Internal   |
         |           |  +------+------+   +------+------+      |
         |           |  | rac1-priv   |   | rac2-priv   |      |
         |           |  | 192.168.1.101  |<->| 192.168.1.102  |      |
         |           |  +-------------+   +-------------+      |
         |           |         Cache Fusion (GCS/GES)           |
         |           |    Blocchi dati trasferiti via RAM        |
         |           +-----------------------------------------+
```

---

## 1.2 Il Problema del Copia-Incolla (MobaXterm)

> ⚠️ **ATTENZIONE**: Appena installato il sistema operativo, ti trovi nella console VNC di Proxmox dove **non puoi incollare testo**. Tutte le configurazioni successive (come l'`/etc/hosts`) sono file lunghissimi. 
> Per procedere devi **prima dare un IP** alla macchina usando l'interfaccia testuale, e poi collegarti dal tuo PC tramite **MobaXterm**. 

**Passo 1: Assegna un IP Temporaneo e Hostname (dalla console VNC Proxmox)**

Ti trovi nella console VNC di Proxmox per `rac1`. Fai login come `root`.

1. **Imposta l'Hostname**:
   ```bash
   hostnamectl set-hostname rac1.localdomain
   ```

2. **Lancia l'interfaccia di rete**:
   ```bash
   nmtui
   ```

3. **Configura le Schede**:
   - Seleziona **Edit a connection** e premi `Invio`.
   - **SCHEDA 1 (NAT/Internet - vmbr0)**: Assicurati che **IPv4 CONFIGURATION** sia su `<Automatic>` e spunta `[X] Automatically connect`.
   - **SCHEDA 2 (Pubblica - vmbr1)**: Cambia **IPv4 CONFIGURATION** in `<Manual>`. Inserisci l'indirizzo `192.168.56.101/24`. Lascia vuoto gateway e DNS. Spunta `[X] Automatically connect`.
   - Esci e fai OK.

4. **Applica**:
   ```bash
   nmcli connection reload
   systemctl restart NetworkManager
   ```

5. **Verifica TASSATIVA**:
   - `ip addr`
   - `ping -c 2 google.com`

**Passo 2: Connettiti tramite MobaXterm**
Ora che la macchina ha un IP raggiungibile dal tuo PC:
1. Apri **MobaXterm**.
2. **Session** -> **SSH** -> Remote Host: `192.168.56.101`.
3. Username: `root`.
4. **Advanced SSH settings**: Spunta **X11-Forwarding** ✅.
5. Clicca OK e **D'ORA IN POI COPIA-INCOLLA I COMANDI DA QUI!**

---

## 1.3 Configurazione Rete Permanente (OL8 NetworkManager)

> ⚠️ **ATTENZIONE AI NOMI DELLE SCHEDE**: Su Oracle Linux 8 i file in `/etc/sysconfig/network-scripts/` sono stati rimpiazzati nativamente da `nmcli`, ma il sistema li legge ancora per retrocompatibilità. Controlla `ip addr` per i nomi corretti (es. `eth0`, `eth1` o `ens18`).

Esempio per `rac1` (adatta `eth0`, `eth1`, `eth2` ai tuoi nomi reali):

### 1. Interfaccia NAT (Internet) $\rightarrow$ `eth0`
```bash
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<'EOF'
TYPE=Ethernet
BOOTPROTO=dhcp
NAME=eth0
DEVICE=eth0
ONBOOT=yes
EOF
```

### 2. Interfaccia Pubblica (192.168.56.x) $\rightarrow$ `eth1`
```bash
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 <<'EOF'
TYPE=Ethernet
BOOTPROTO=static
NAME=eth1
DEVICE=eth1
ONBOOT=yes
IPADDR=192.168.56.101
NETMASK=255.255.255.0
DOMAIN=localdomain
EOF
```

### 3. Interfaccia Privata (Interconnect) $\rightarrow$ `eth2`
L'interconnect per il traffico esclusivo del cluster. **NIENTE GATEWAY QUI**.
```bash
cat > /etc/sysconfig/network-scripts/ifcfg-eth2 <<'EOF'
TYPE=Ethernet
BOOTPROTO=static
NAME=eth2
DEVICE=eth2
ONBOOT=yes
IPADDR=192.168.1.101
NETMASK=255.255.255.0
EOF
```

> **Perché BOOTPROTO=static?** L'interconnect del RAC NON deve MAI cambiare IP. Se usi DHCP e l'IP cambia, il cluster va in split-brain.

```bash
# Riavvia il networking via NetworkManager (Standard OL8)
nmcli connection reload
systemctl restart NetworkManager

# Verifica
ip addr show eth1
ip addr show eth2
```

---

## 1.4 Configurazione /etc/hosts e DNS

```bash
cat >> /etc/hosts <<'EOF'
# === RAC PRIMARY ===
192.168.56.101   rac1.localdomain       rac1
192.168.56.102   rac2.localdomain       rac2
192.168.1.101    rac1-priv.localdomain  rac1-priv
192.168.1.102    rac2-priv.localdomain  rac2-priv
192.168.56.103   rac1-vip.localdomain   rac1-vip
192.168.56.104   rac2-vip.localdomain   rac2-vip

# === RAC STANDBY ===
192.168.56.111   racstby1.localdomain      racstby1
192.168.56.112   racstby2.localdomain      racstby2
192.168.2.111    racstby1-priv.localdomain racstby1-priv
192.168.2.112    racstby2-priv.localdomain racstby2-priv
192.168.56.113   racstby1-vip.localdomain  racstby1-vip
192.168.56.114   racstby2-vip.localdomain  racstby2-vip
EOF
```

> 💡 **IL SEGRETO DEL DBA: Perché non mettiamo lo SCAN qui?**
> Il file hosts NON fa Round-Robin: Linux userebbe sempre il primo IP. Il DNS invece lo fa! Lo SCAN deve stare solo nel DNS (il tuo `dnsnode`).

### Configura resolv.conf

```bash
# 1. Sblocca il file (se precedentemente protetto)
chattr -i /etc/resolv.conf 2>/dev/null

# 2. Punta al DNS server (la VM dnsnode)
cat > /etc/resolv.conf <<'EOF'
search localdomain
nameserver 192.168.56.50
options timeout:1
options attempts:5
EOF

# 3. CRITICO: Impedisci a NetworkManager di sovrascrivere resolv.conf
# Usiamo il metodo corretto per OL8
cat > /etc/NetworkManager/conf.d/90-dns-none.conf <<'EOF'
[main]
dns=none
EOF
systemctl restart NetworkManager.service

# 4. Blocca il file per sicurezza extra (Protezione "anti-overwrite")
chattr +i /etc/resolv.conf
```

> **Cosa fa dns=none?** Dice a NetworkManager di NON toccare `/etc/resolv.conf` dopo un reboot. Senza questo fix, dopo ogni restart il file viene riscritto e lo SCAN smette di funzionare. È uno dei bug più insidiosi!

### Test DNS
```bash
nslookup rac1 192.168.56.50
nslookup rac-scan 192.168.56.50  # DEVE ritornare 3 IP!
```

---

## 1.5 Firewall e SELinux: Eccezione Solo per Lab Isolato

> [!WARNING]
> I comandi seguenti sono una scorciatoia ammessa solo sulle VM domestiche
> isolate del Core Lab.

```bash
# Disabilitare il Firewall (firewalld)
systemctl stop firewalld
systemctl disable firewalld

# Impostare SELinux permissive
sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
setenforce 0
```

---

## 1.5b Configurare /tmp come Filesystem Dedicato (tmpfs)

> 🛑 **Cosa dice Oracle ufficialmente su `/tmp`?**
> La documentazione Oracle consiglia **tra i 5 GB e i 10 GB**. Il nostro lab con 8GB di RAM si posiziona nel mezzo. Useremo **4 GB**, senza sprecare RAM preziosa per il database.

### 💡 Ma cos'è `tmpfs`? RAM o Storage?
`tmpfs` è un filesystem che vive interamente nella RAM del server, NON su disco. Quando monti `/tmp` come `tmpfs`, ogni file che ci scrivi dentro va dritto nella memoria RAM. Velocissimo (1000x), ma non persiste al reboot. Non "ruba" RAM se è vuoto: `size=4g` è solo il tetto massimo.

```bash
# Aggiungi la riga tmpfs al file fstab per il montaggio permanente
echo "tmpfs  /tmp  tmpfs  defaults,size=4g,mode=1777  0 0" >> /etc/fstab

# Monta il nuovo tmpfs ADESSO
mount -o remount /tmp 2>/dev/null || mount /tmp

# Verifica
df -hT /tmp
```

> 💡 **Tip da DBA: Perché `mode=1777`?**
> È lo "sticky bit" (`drwxrwxrwt`). Significa che chiunque può scrivere in `/tmp`, ma **solo il proprietario** di un file può cancellarlo. Senza, l'utente `grid` potrebbe cancellare i file di `oracle`.

---

## 1.6 Fix BUG INS-06006 per Oracle Linux 8.10 (TASSATIVO)

> [!CAUTION]
> **ATTENZIONE CRITICA PER OEL 8+**: Nelle versioni recenti di Linux come la nostra OEL 8.10, il comando `scp` è stato silenziosamente aggiornato per usare il protocollo SFTP. L'installer Oracle 19c, che è vecchio, non capisce SFTP e **crasha con l'errore fatale INS-06006**. Il workaround è creare un wrapper che forza il vecchio protocollo.

```bash
# 1. Backup del vero scp
cp -p /usr/bin/scp /usr/bin/scp.bkp

# 2. Creiamo il wrapper che forza il vecchio protocollo
cat > /usr/bin/scp <<'EOF'
#!/bin/bash
/usr/bin/scp.bkp -T "$@"
EOF

# 3. Permessi di esecuzione
chmod +x /usr/bin/scp

# 4. Verifica
cat /usr/bin/scp
```

---

## 1.7 Installazione Pacchetti Prerequisiti (OL8 `dnf`)

```bash
# In OL8 usiamo dnf
dnf install -y oracle-database-preinstall-19c

# Pacchetti aggiuntivi necessari
dnf install -y ksh libaio-devel net-tools nfs-utils \
    smartmontools sysstat unzip wget xorg-x11-xauth \
    xorg-x11-utils xterm bind-utils vim
```

> **Perché oracle-database-preinstall-19c?** Questo RPM magico fa il 70% del lavoro: crea l'utente `oracle`, configura `sysctl.conf`, imposta i limiti di risorse, installa le dipendenze. Senza questo, dovresti fare tutto a mano.

---

## 1.8 Fix Bug Systemd (RemoveIPC) - CRITICO!

> **Perché?** Su Red Hat 7/8, `systemd` ha un'impostazione predefinita mortale per Oracle: `RemoveIPC=yes`. Questo fa sì che il demone di login distrugga automaticamente i segmenti di memoria condivisa (IPC) quando l'utente si disconnette. Il Clusterware andrà in crash silenzioso (`CRS-4639`)!

```bash
echo "RemoveIPC=no" >> /etc/systemd/logind.conf
systemctl restart systemd-logind
```

---

## 1.9 Creazione Gruppi e Utenti (Role Separation)

> **Perché due utenti (oracle e grid)?** Questa è la "Role Separation" Oracle. `grid` installerà il clusterware e gestirà ASM. `oracle` gestirà solo il database. 

```bash
# Step 1: Creazione dei gruppi ASM
groupadd -g 54327 asmdba
groupadd -g 54328 asmoper
groupadd -g 54329 asmadmin

# Step 2: Aggiungi "oracle" al gruppo ASM
usermod -a -G asmdba oracle

# Step 3: Creazione dell'utente "grid"
useradd -u 54331 -g oinstall -G dba,asmdba,asmadmin,asmoper,racdba grid

# Step 4: Imposta password
passwd oracle
passwd grid
```

---

## 1.10 Creazione Directory (Albero ORACLE_BASE)

> **Perché questa struttura complessa?** Oracle segue l'architettura OFA. Separa i binari di Grid dai binari di Database. Il software Grid risiede in `GRID_HOME`, e *non può mai essere una sottocartella* dell' `ORACLE_BASE` di grid, deve essere "fuori".

```bash
# Grid Infrastructure
mkdir -p /u01/app/19.0.0/grid        # GRID_HOME
mkdir -p /u01/app/grid                # ORACLE_BASE (grid)
mkdir -p /u01/app/oraInventory        # Inventario Globale

# Database 19c
mkdir -p /u01/app/oracle                              # ORACLE_BASE (oracle)
mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1      # DB_HOME

# Proprietari e Permessi
chown -R grid:oinstall   /u01/app/19.0.0/grid
chown -R grid:oinstall   /u01/app/grid
chown -R grid:oinstall   /u01/app/oraInventory
chown -R oracle:oinstall /u01/app/oracle

chmod -R 775 /u01
```

---

## 1.11 Variabili d'Ambiente

### Per l'utente `grid`
```bash
cat > /home/grid/.grid_env <<'ENVEOF'
host=$(hostname -s)
if [ "$host" == "rac1" ]; then
    ORA_SID=+ASM1
elif [ "$host" == "rac2" ]; then
    ORA_SID=+ASM2
elif [ "$host" == "racstby1" ]; then
    ORA_SID=+ASM1
elif [ "$host" == "racstby2" ]; then
    ORA_SID=+ASM2
fi

export ORACLE_SID=$ORA_SID
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/19.0.0/grid
export ORACLE_TERM=xterm
export TNS_ADMIN=$ORACLE_HOME/network/admin
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
ENVEOF

echo '. ~/.grid_env' >> /home/grid/.bash_profile
chown grid:oinstall /home/grid/.grid_env
```

### Per l'utente `oracle`
```bash
cat > /home/oracle/.db_env <<'ENVEOF'
host=$(hostname -s)
if [ "$host" == "rac1" ]; then
    ORA_SID=RACDB1
elif [ "$host" == "rac2" ]; then
    ORA_SID=RACDB2
elif [ "$host" == "racstby1" ]; then
    ORA_SID=RACDB1
elif [ "$host" == "racstby2" ]; then
    ORA_SID=RACDB2
fi

export ORACLE_SID=$ORA_SID
export ORACLE_UNQNAME=RACDB
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_TERM=xterm
export TNS_ADMIN=$ORACLE_HOME/network/admin
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
ENVEOF

echo '. ~/.db_env' >> /home/oracle/.bash_profile
chown oracle:oinstall /home/oracle/.db_env
```

---

## 1.12 Parametri Kernel e Ottimizzazioni (Tassative)

> 💡 **IMPORTANTE**: Tutti i passaggi di questa sezione rappresentano il cuore della tua **Golden Image**. Vanno eseguiti **SOLO su `rac1`**. Quando clonerai la macchina, queste ottimizzazioni saranno già presenti.

### 1. Limits per Grid
Il pacchetto preinstall crea i limiti per `oracle`, non per `grid`. Dobbiamo copiare e adattare il file:
```bash
cp /etc/security/limits.d/oracle-database-preinstall-19c.conf \
   /etc/security/limits.d/grid-database-preinstall-19c.conf
   
sed -i 's/oracle/grid/g' /etc/security/limits.d/grid-database-preinstall-19c.conf
```

### 2. Disabilitare Transparent HugePages (THP)
I THP causano frammentazione e crolli delle prestazioni sul DB. In OL8 modifichiamo GRUB:
```bash
# 1. Modifica la configurazione
sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="transparent_hugepage=never /g' /etc/default/grub

# 2. Ricompila GRUB (Su OL8 EFI e BIOS usano lo stesso path unificato)
grub2-mkconfig -o /boot/grub2/grub.cfg
```

### 3. Disabilitare Avahi Daemon e NOZEROCONF
Evita pacchetti multicast (Bonjour) che disturbano il Clusterware.
```bash
systemctl stop avahi-daemon.socket avahi-daemon.service
systemctl disable avahi-daemon.socket avahi-daemon.service

echo "NOZEROCONF=yes" >> /etc/sysconfig/network
```

### 4. Configurazione Standard HugePages (Raccomandata)
Assegniamo 1024 pagine (2GB) di RAM fisica inamovibile ad Oracle per la SGA. Il kernel fatica molto meno, e Oracle non va mai in swap!
```bash
echo "vm.nr_hugepages = 1024" >> /etc/sysctl.d/99-oracle-hugepages.conf
sysctl -p /etc/sysctl.d/99-oracle-hugepages.conf
```

---

## 1.13 Configurazione Chrony (NTP)

Oracle richiede che i clock siano sincronizzati:
```bash
# Chrony è lo standard in OL8.
systemctl enable chronyd --now
chronyc sources
```
> **Perché?** Se i clock divergono troppo, il Clusterware forza un "node eviction" per proteggere i dati.

---

## 1.14 Inventory Location e Chiavi SSH

### Inventory Loc
```bash
cat > /etc/oraInst.loc <<'EOF'
inventory_loc=/u01/app/oraInventory
inst_group=oinstall
EOF

chmod 664 /etc/oraInst.loc
chown grid:oinstall /etc/oraInst.loc
```

### ⚠️ Predisposizione SSH
> **NON generare le chiavi SSH sulla Golden Image.** 
> Se lo fai ora, tutti i nodi avrebbero la stessa identica chiave privata copiata! Genereremo le chiavi nella Sezione 1.16, **dopo** la clonazione.

---

## 🛑 IL MOMENTO DELLA VERITÀ: Clonazione Golden Image

Hai completato il setup su `rac1`. Spegni la VM.
```bash
poweroff
```

### La Procedura di Clonazione in Proxmox

In Proxmox, quando fai un Full Clone, vengono clonati anche i dischi locali (inclusi i 5 dischi condivisi di ASM). Dobbiamo evitare di sdoppiare lo storage ASM!

**Per `rac2` (Nodo 2 Primario):**
1. Dalla GUI Proxmox, tasto destro su `rac1` -> **Clone**.
   - Mode: **Full Clone**
   - Name: `rac2`
2. Appena il clone finisce, vai su `rac2` -> **Hardware**.
3. **Seleziona e fai DETACH e REMOVE** per tutti i 5 dischi ASM che Proxmox ha clonato inutilmente (lascia SOLO il disco OS 50GB e il disco /u01 100GB).
4. Fai **Add -> Hard Disk**: scegli lo storage locale e nel percorso seleziona l'immagine dei dischi originari di `rac1` (es. `vm-101-disk-2` ecc.). Ricordati di impostare "No Cache".
5. Vai nella shell dell'host Proxmox e riaggiungi il flag `shared=1` per `rac2` (es. VM 102):
   ```bash
   nano /etc/pve/qemu-server/102.conf
   # Aggiungi ,shared=1 a tutte le righe scsi2, scsi3, ecc.
   ```

**Per `racstby1` e `racstby2` (Standby):**
La logica è identica, ma ricorda che un RAC Standby **deve avere dischi ASM nuovi e vergini**, NON quelli del primario! 
- Rimuovi i cloni ASM in Proxmox.
- Attacca i 5 dischi vuoti creati in Fase 0 specifici per lo Standby.

---

## 1.15 Customizzazione Cloni (IP e Hostname)

Accendi i cloni **uno alla volta** usando la console VNC di Proxmox, loggati come root ed esegui i fix di rete. 
*(Esempio per `rac2`)*:

```bash
hostnamectl set-hostname rac2.localdomain

# Modifica IP via nmcli
nmcli con mod eth1 ipv4.addresses 192.168.56.102/24
nmcli con mod eth2 ipv4.addresses 192.168.1.102/24
nmcli con reload
nmcli con up eth1
nmcli con up eth2

ping -c 2 google.com
```

Fai lo stesso per i nodi Standby (ricordando che la Privata è sulla subnet `.2.x`).
Una volta dati gli IP, **torna su MobaXterm!**

---

## 1.16 Configurazione Post-Clonazione: SSH Trust

Ora che i nodi hanno vita propria, scambiamoci le chiavi.

**Come utente `grid` (su ENTRAMBI i nodi):**
```bash
su - grid
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
# Da rac1 manda la chiave a se stesso e a rac2
ssh-copy-id grid@rac1; ssh-copy-id grid@rac2
# Da rac2 manda la chiave a se stesso e a rac1
ssh-copy-id grid@rac1; ssh-copy-id grid@rac2
```

**Fai lo STESSO per gli utenti `oracle` e `root`**.

---

## 1.17 Sincronizzazione Dischi ASM

> 💡 **Il concetto del "Timbro" ASM**
> `rac2` condivide gli stessi dischi di `rac1`. Poiché `rac1` in Fase 0 ha già formattato i dischi, `rac2` deve solo leggerli.

**SOLO su `rac2` e `racstby2`:**
```bash
oracleasm scandisks
oracleasm listdisks
# Deve mostrarti tutti i dischi (CRS1, DATA, ecc.)
```

**Sui nodi Standby (`racstby1`):**
Avendo dischi nuovi e vergini, devi fare il comando inverso:
```bash
oracleasm createdisk STBY_CRS1 /dev/sdb1
# ecc... per tutti e 5 i dischi
```

---

## ✅ Checklist Fine Fase 1

Esegui questi controlli finali su **ENTRAMBI** i nodi prima di passare alla Fase 2:

```bash
# 1. Hostname corretto
hostname

# 2. Tutti i nodi pingabili
ping -c 1 rac1 && ping -c 1 rac2 && ping -c 1 rac1-priv && ping -c 1 rac2-priv

# 3. DNS SCAN funzionante
nslookup rac-scan.localdomain

# 4. SSH senza password (grid e oracle)
su - grid -c "ssh rac2 hostname"

# 5. BUG OEL 8 SCP (Verifica che sia stato wrappato)
cat /usr/bin/scp | grep -q "scp.bkp" && echo "SCP FIX OK" || echo "ERRORE FIX SCP MANCANTE!"
```

**← [FASE 0: Setup Macchine](./GUIDA_FASE0_SETUP_MACCHINE.md)** | 📍 [Indice Percorso Lab](../../04_governance_learning/03_esami_e_carriera/README.md) | **→ [FASE 2: Grid + RAC](./GUIDA_FASE2_GRID_E_RAC.md)**
