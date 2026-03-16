# PHASE 1: Node and OS Preparation (Oracle Linux 7.9)

> **Reference architecture**: 2 primary RAC nodes (`rac1`, `rac2`) + 2 standby RAC nodes (`racstby1`, `racstby2`).
> All commands must be executed as `root` salvo dove diversamente indicato.
> The steps in this phase must be repeated on **all nodes** except where specified.

### 📸 Visual References

![OS Disk Partitioning](./images/os_install_partitions.png)

![DNS BIND Architecture](./images/dns_bind_architecture.png)

---

### What is DNS and Why Do We Need It?

**DNS (Domain Name System)** is the service that translates names into IP addresses. When you type `rac-scan.localdomain`, il DNS risponde con `192.168.56.105, 192.168.56.106, 192.168.56.107`.

```
Without DNS: With DNS:
  ══════════                          ═════════

Application: Application:
  "Connettimi a                       "Connettimi a
   192.168.56.105"                      rac-scan.localdomain"
           │                                    │
           ▼                                    ▼
  ┌────────────────┐                  ┌────────────────┐
  │  Connessione   │                  │  DNS Server    │
│ to ONE IP only │ │ Replies with │
  │  (se cambia,   │                  │  3 IP in round │
│ everything yes │ │ robin: │
  │   rompe!)      │                  │  .105 .106 .107│
  └────────────────┘                  └────────┬───────┘
                                               │
                                      Load balanced!
                                      Se cambi un IP,
you only update the DNS
```

**Why does Oracle RAC require this?**
- The **SCAN** (Single Client Access Name) MUST resolve to 3 IPs simultaneously.
- `/etc/hosts` **NON** basta per lo SCAN. Non supporta il Round-Robin. Se metti 3 IP per `rac-scan` in the hosts file, Linux will always only use the first one.
- DNS, on the other hand, allows **round-robin**: client connections are automatically distributed between the 3 IPs.

**What DNS do we use in the Lab? (Dnsmasq vs BIND)**
In production, complex DNS servers such as **BIND** or Microsoft DNS are used. In the lab, installing BIND requires dozens of configuration files made up of tricky syntax.
To **greatly simplify**, we will use **Dnsmasq**. Dnsmasq is a very lightweight DNS that does a magical thing: **reads its file `/etc/hosts` and transforms it into DNS records that can be queried by the network**.

```
The DNSmasq trick:
  ═════════════════════
  1. We compile /etc/hosts on the 'dnsnode' node with all the IPs (including the 3 SCANs)
  2. Avviamo dnsmasq
  3. dnsmasq reads that file and "serves" those translations to the other nodes (rac1, rac2)
  4. When rac1 asks "who is rac-scan?", dnsmasq returns the 3 IPs in round-robin!
```

**Types of DNS records we configure:**

| Tipo | Example | What does he do |
|---|---|---|
| **A** | `rac1 → 192.168.56.101` | Nome → IP (forward) |
| **PTR** | `192.168.56.101 → rac1` | IP → Nome (reverse) |
| **SOA** | `localdomain` | Authority of the area |
| **NS** | `ns1.localdomain` |Who is responsible for this area|

---

## 1.1 IP Plan and Hostname

First of all, let's define the addressing plan. This is the heart of any cluster: if you get the IPs wrong, nothing works.

| Role | Hostname | Public IP | Private IP (Interconnect) | VIP IP |
|---|---|---|---|---|
| RAC Node 1 | rac1 | 192.168.56.101 | 192.168.1.101 | 192.168.56.103 |
| RAC Node 2 | rac2 | 192.168.56.102 | 192.168.1.102 | 192.168.56.104 |
| RAC SCAN | rac-scan | 192.168.56.105, .106, .107 | - | - |
| Standby Node 1 | racstby1 | 192.168.56.111 | 192.168.2.111 | 192.168.56.113 |
| Standby Node 2 | racstby2 | 192.168.56.112 | 192.168.2.112 | 192.168.56.114 |
| Standby SCAN | racstby-scan | 192.168.56.115, .116, .117 | - | - |
| Target GoldenGate | dbtarget | 192.168.56.150 | - | - |

> **Why?** Oracle RAC requires a minimum of 3 types of IPs per node: Public (client communication), Private (Cache Fusion, the "blood" of the cluster), VIP (transparent failover). The SCAN (Single Client Access Name) is a DNS load balancer integrated into the cluster.

### How the RAC Networks Work

```
                     ┌───────────────────────────────────────────┐
                     │ PUBLIC NETWORK (enp0s8) │
                     │     192.168.56.0/24 (Host-Only)           │
      Client App     │                                           │
          │          │  ┌──────┐  ┌──────┐  ┌──────┐            │
          ▼          │  │SCAN  │  │SCAN  │  │SCAN  │            │
    ┌──────────┐     │  │ .105 │  │ .106 │  │ .107 │            │
    │ SCAN     │◄────│──┤      │  │      │  │      │ DNS        │
    │ Listener │ │ └──────┘ └──────┘ └──────┘ Round-Robin│
    └────┬─────┘     │                                           │
         │           │  ┌─────────────┐   ┌─────────────┐       │
         ├──────────►│  │ rac1        │   │ rac2        │       │
         │           │  │ IP: .101    │   │ IP: .102    │       │
         │           │  │ VIP: .111   │   │ VIP: .112   │       │
         │           │  │ (Se rac1    │   │ (Se rac2    │       │
         │           │  │  muore, VIP │   │  muore, VIP │       │
         │           │  │  migra su   │   │  migra su   │       │
         │           │  │  rac2)      │   │  rac1)      │       │
         │           │  └──────┬──────┘   └──────┬──────┘       │
         │           └─────────┼──────────────────┼─────────────┘
         │                     │                  │
         │           ┌─────────┼──────────────────┼─────────────┐
         │ │ │ PRIVATE NETWORK │ (enp0s9) │
         │           │         │  192.168.1.0/24   │  Internal   │
         │           │  ┌──────┴──────┐   ┌──────┴──────┐      │
         │           │  │ rac1-priv   │   │ rac2-priv   │      │
         │           │  │ 192.168.1.101  │◄═►│ 192.168.1.102  │      │
         │           │  └─────────────┘   └─────────────┘      │
         │           │         Cache Fusion (GCS/GES)           │
│ │ Data blocks transferred via RAM │
         │           └─────────────────────────────────────────┘
```

> **VIP (Virtual IP)**: When a node crashes, its VIP "migrates" to the other node in a few seconds. Clients connected to the VIP are automatically redirected without changing configuration.

> **SCAN**: Clients ALWAYS connect to the SCAN, NEVER directly to the nodes. SCAN load-balances connections between available nodes.

---

## 1.2 The Copy-Paste Problem (MobaXterm)

> ⚠️ **ATTENTION**: As soon as the operating system is installed, you are in the black VirtualBox console where **you cannot paste text**. All subsequent configurations (such as`/etc/hosts`) sono file lunghissimi. 
> To proceed you must **first give an IP** to the machine using the text interface, and then connect from your PC via **MobaXterm**. This applies to **ALL machines** (`rac1`, `rac2`, `racstby1`, etc.) man mano che le crei.

**Step 1: Assign a Temporary IP and Hostname (from the VirtualBox console)**

You are in the "black console" of VirtualBox. Log in as `root`.

1. **Imposta l'Hostname**:
   ```bash
   hostnamectl set-hostname rac1.localdomain
   ```

2. **Launches the network interface**:
   ```bash
   nmtui
   ```

3. **Configura le Schede (Step-by-Step)**:
- Select **Edit a connection** and press`Invio`.
- **CARD 1 (NAT/Internet - usually`enp0s3`)**:
     - Vai su **Edit...**
- Make sure **IPv4 CONFIGURATION** is on`<Automatic>`.
- ⚠️ **VERY IMPORTANT**: Scroll down and tick with the space bar`[X] Automatically connect`.
     - Vai su `<OK>`at the bottom and press`Invio`.
- **SHEET 2 (Publish - usually`enp0s8`)**:
     - Vai su **Edit...**
     - Cambia **IPv4 CONFIGURATION** da `<Automatic>` a `<Manual>`.
- Select`<Show>` a destra di IPv4 per espandere i campi.
     - **Addresses**: Enter the address for the node (e.g. `192.168.56.101/24`).
     - **Gateway**: Lascia VUOTO.
     - **DNS Servers**: Lascia VUOTO.
     - Spunta `[X] Automatically connect`.
     - Vai su `<OK>`at the bottom and press`Invio`.

4. **Exit and Apply**:
   - Premi `Esc` o seleziona `<Back>` until you return to the main menu, then select **Quit**.
   - Riavvia il networking per applicare:
     ```bash
     systemctl restart network
     ```

5. **Quick Reference Table (Public IPs)**:

| Node | Hostname |Public IP (Tab 2)|
| :--- | :--- | :--- |
| **rac1** | `rac1.localdomain` | `192.168.56.101/24` |
| **rac2** | `rac2.localdomain` | `192.168.56.102/24` |
| **racstby1** | `racstby1.localdomain` | `192.168.56.111/24` |
| **racstby2** | `racstby2.localdomain` | `192.168.56.112/24` |

6. **MANDATORY check**:
- Check IPs:`ip addr`
   - Controlla Internet: `ping -c 2 google.com` (If he doesn't answer, you missed the step on Card 1).

**Step 2: Connect via MobaXterm**
Now that the machine has an IP reachable from your PC:
1. Apri **MobaXterm**.
2. **Session** -> **SSH** -> Remote Host: `192.168.56.101`(or whatever you chose).
3. Username: `root`.
4. **Advanced SSH settings**: Spunta **X11-Forwarding** ✅.
5. Click OK and **FROM NOW COPY-PASTE THE COMMANDS FROM HERE!**

---

---

## 1.3 Network Configuration (Static Files)

> 🛑 **ALT! STOP! ARE YOU STILL IN THE VIRTUALBOX BLACK SCREEN?**
>
> **ALL COMMANDS FROM HERE ON OUT MUST BE EXECUTED VIA MOBAXTERM!**
> The VirtualBox console does not support copy-paste. Now that your VM has an IP, minimize the VirtualBox window, open MobaXterm and create an SSH session to the IP you just gave it. Do this for each VM you are setting up!
> 
> **Reference IP Table for MobaXterm:**
> - `rac1`: 192.168.56.101
> - `rac2`: 192.168.56.102
> - `racstby1`: 192.168.56.111
> - `racstby2`: 192.168.56.112
> - `dbtarget`: 192.168.56.150

Now that you have opened the terminal in MobaXterm and logged in as `root`, we make the configuration permanent and rigorous by writing the files. 

> ⚠️ **BEWARE OF BOARD NAMES**: Physical names depend on the OS. In Oracle Linux 7, it is usually called Adapter 1 (NAT). `enp0s3`, Adapter 2 (Public) is called`enp0s8`, e l'Adattatore 3 (Privata) si chiama `enp0s9`. Sostituisci i nomi negli script se necessario controllando `ip addr`.

Example for `rac1`(remember to change the IP in step 2 and 3 if you are on another VM!):

### 1. Interfaccia NAT (Internet) $\rightarrow$ `enp0s3`
> **Node: rac1** | **User: root**
Don't use static IPs here. It must get IP, Gateway and DNS from VirtualBox's DHCP.
```bash
cat > /etc/sysconfig/network-scripts/ifcfg-enp0s3 <<'EOF'
TYPE=Ethernet
BOOTPROTO=dhcp
NAME=enp0s3
DEVICE=enp0s3
ONBOOT=yes
EOF
```

### 2. Public Interface (192.168.56.x) $\rightarrow$`enp0s8`
> **Node: rac1** | **User: root**
This is the Lab network where the nodes communicate with each other and with your PC.
```bash
cat > /etc/sysconfig/network-scripts/ifcfg-enp0s8 <<'EOF'
TYPE=Ethernet
BOOTPROTO=static
NAME=enp0s8
DEVICE=enp0s8
ONBOOT=yes
IPADDR=192.168.56.101
NETMASK=255.255.255.0
DOMAIN=localdomain
EOF
```
> *(Note: We have voluntarily omitted the GATEWAY here to prevent it from bypassing the NAT and interrupting Internet access)*

### 3. Interfaccia Privata (Interconnect) $\rightarrow$ `enp0s9`
> **Node: rac1** | **User: root**
The interconnect for exclusive cluster traffic. **NO GATEWAY HERE**.
```bash
cat > /etc/sysconfig/network-scripts/ifcfg-enp0s9 <<'EOF'
TYPE=Ethernet
BOOTPROTO=static
NAME=enp0s9
DEVICE=enp0s9
ONBOOT=yes
IPADDR=192.168.1.101
NETMASK=255.255.255.0
EOF
```

> **Why BOOTPROTO=static?** The RAC interconnect must NEVER change IP. If you use DHCP and the IP changes, the cluster goes into split-brain (the two nodes think they are alone and corrupt the data).

```bash
# Riavvia il networking
systemctl restart network

#Check (Replace names if different on your system)
ip addr show enp0s3
ip addr show enp0s8
ip addr show enp0s9

ping -c 2 rac2 # From rac1 (after configuring hosts)
ping -c 2 rac2-priv # From rac1 (private network)
```

> ⚠️ **WHY DOES ETH0 NOT EXIST?**
> In modern versions of Oracle Linux (such as 7.9), the system no longer uses nomenclature `eth0`, `eth1` etc. but "consistent" names based on hardware location (e.g. `enp0s3`). Se provi a fare `ip addr show eth0` and you get error, it's because your card is called `enp0s3`. Usa sempre `ip addr` to see the real names assigned by your VM's BIOS.

---

## 1.4 Configuring /etc/hosts

Run on **ALL** nodes (again from MobaXterm!):

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

> 💡 **THE SECRET OF THE DBA: Why don't we put the SCAN here?**
> Did you notice that we left out the SCAN? Here's why:
> 1. **The hosts file is NOT Round-Robin**: If you write 3 IPs to SCAN here, Linux will always only use the first one. Load balancing would die in the bud.
> 2. **DNS does this instead**: The SCAN must only be in the DNS so that the DNS responds to each request with a different order of IPs, distributing the clients across the entire cluster.
> 3. **VIPs and Privates should be placed instead**: They are used by the nodes to "talk" to each other quickly and ensure that the cluster starts even if the DNS has a moment of crisis.

---

## 1.4 DNS configuration (Dnsmasq on separate VM)

> **DNS has already been configured in Phase 0** on the VM `dnsnode` con Dnsmasq.
> If you have not yet completed [Phase 0 — section 0.3](./GUIDE_PHASE0_MACHINE_SETUP.md), torna indietro e falla ora.
>
> **Why a separate DNS VM?** (Oracle Base approach)
> - DNS does not stop when you restart RAC nodes
> - SCAN always works, even during cluster restarts
> - Dnsmasq legge `/etc/hosts` and exposes it as DNS — zero zone configuration
> - It only costs 1 GB of RAM

### Configure resolv.conf on ALL RAC nodes

```bash
#== RUN ON EVERY NODE (rac1, rac2, racstby1, racstby2) ==

#1. Unlock the file (if previously protected)
chattr -i /etc/resolv.conf

# 2. Punta al DNS server (la VM dnsnode)
cat > /etc/resolv.conf <<'EOF'
search localdomain
nameserver 192.168.56.50
options timeout:1
options attempts:5
EOF

#3. CRITICAL: Prevent NetworkManager from overwriting resolv.conf
sed -i -e "s|\[main\]|\[main\]\ndns=none|g" /etc/NetworkManager/NetworkManager.conf
systemctl restart NetworkManager.service

#4. Lock the file for extra security (“anti-overwrite” protection)
chattr +i /etc/resolv.conf
```

> 💡 **WHY "Operation not permitted"?**
> Se ricevi questo errore pur essendo `root`, it's because the file is "immutable" (protected by the command `chattr +i`). Linux prevents ANYONE (even root) from modifying it until you unlock it with `chattr -i`. 
> We use this to prevent NetworkManager or other processes from deleting our DNS configuration, which is vital for SCAN.

> **What does dns=none do?** Tells NetworkManager NOT to touch `/etc/resolv.conf` after a reboot. Without this fix, after each restart the file is rewritten and SCAN stops working. It's one of the most insidious bugs!

### DNS Test (from each node)

```bash
#Verify that DNS resolves hostnames
nslookup rac1 192.168.56.50
nslookup rac2 192.168.56.50

# SCAN must return 3 IPs!
nslookup rac-scan 192.168.56.50
# Server:  192.168.56.50
# Address: 192.168.56.50#53
# Name:    rac-scan.localdomain
# Address: 192.168.56.105
# Name:    rac-scan.localdomain
# Address: 192.168.56.106
# Name:    rac-scan.localdomain
# Address: 192.168.56.107

# Standby SCAN
nslookup racstby-scan 192.168.56.50
```

### (Optional but Recommended) Configure DNS on Windows (Host)

If you want to access EM Express or other lab web services directly from your physical PC browser using names (e.g. `https://rac1.localdomain:5500/em`), you have to tell Windows to use your `dnsnode`.

1. On Windows, open **Network Settings** -> **Change adapter options**.
2. Trova la scheda **VirtualBox Host-Only Network** (quella relativa a `192.168.56.x`).
3. Right click -> **Properties** -> Double click on **Internet Protocol Version 4 (TCP/IPv4)**.
4. Select **Use the following DNS server addresses**.
5. Preferred DNS Server: Enter the dnsnode IP (`192.168.56.50`).
6. Click OK. Now from your Windows browser you can navigate using the lab's hostnames!

> **If DNS is not working, DO NOT proceed!** The Grid installer will fail if it cannot resolve the SCAN.

> 📸 **NOTA SNAPSHOT:**
> *The old "SNAP-03: Rete_e_DNS_OK" here has been removed to save space. Continue rac1 configuration towards the Golden Image.*

---

## 1.5 Disable Firewall and SELinux

> **Why?** In a lab environment, firewalls and SELinux add unnecessary complexity and often block ports needed for RAC interconnect or Grid Infrastructure processes. In production you would use painstaking network policies and rules, but to learn the architecture it is imperative to eliminate them to avoid false positives.

### Step 1: Disabilitare il Firewall (firewalld)
Run these two commands as root to stop the firewall now and prevent it from starting on the next reboot:
```bash
systemctl stop firewalld
systemctl disable firewalld
```

### Step 2: Disabilitare SELinux (Modifica Manuale)
SELinux is kernel security. Let's disable it permanently by editing its configuration file.

1. Open the file with the text editor`vi`:
   ```bash
   vi /etc/selinux/config
   ```
2. Cerca la riga che dice `SELINUX=enforcing` (use the keyboard arrows to move).
3. Press the button`i` to enter ARM mode.
4. Cancella `enforcing` e scrivi `disabled`. The line must look exactly:
   `SELINUX=disabled`
5. Premi `Esc`to exit the entry, then write`:wq` e premi `Invio`to save and exit.
6. To avoid having to reboot the machine immediately, lower the SELinux defenses in RAM for the current session like this:
   ```bash
   setenforce 0
   ```

---

## 1.5b Configuring /tmp as a Dedicated Filesystem (tmpfs)

> 🛑 **What Oracle officially says about `/tmp`?**
> The Oracle 19c documentation gives different requirements depending on the context:
> 
> |Official Oracle Document| Requisito `/tmp` |
> |---|---|
> | Grid Infrastructure Installation Checklist | **Almeno 1 GB** libero |
> | Server Configuration Checklist for Oracle Database |**At least 5 GB** of space|
> | Best Practice per ambienti RAC complessi (MOS) |**10 GB recommended**|
> 
> Our lab with 8 GB of RAM falls somewhere in between. We'll use **4GB**, which far exceeds the 1GB minimum requirement and is in line with the recommended 5GB, without wasting precious database RAM.

### 💡 But what is it `tmpfs`? RAM or Storage? — Full Explanation

This is one of the nifty things about Linux. Normally, when you write a file, the path is:

```
Application → Linux Kernel → Disk Controller → Physical Disk (HDD/SSD)
↑ SLOW (milliseconds)
```

Con `tmpfs`, the path becomes:

```
Application → Linux Kernel → RAM
                                ↑ VERY FAST (nanoseconds, ~1000x faster!)
```

**`tmpfs` it's a filesystem that lives entirely in the server's RAM, NOT on disk.** When you mount `/tmp` as `tmpfs`, every file you write into it goes straight into RAM memory. Here are the practical consequences:

|Characteristic| `/tmp`to disk (XFS/EXT4)| `/tmp` su `tmpfs` (RAM) |
|---|---|---|
| **Speed** |Slow (depends on the disc)| ⚡ Velocissima (~1000x) |
| **Persistenza** |Files survive reboot|❌ **Everything disappears on reboot**|
|**Space occupied**|Takes up hard disk space|Takes up RAM space|
|**Risk of filling up the root disk**| ✅ Yes! `/tmp` e `/`they share space | ❌ No, they are separated |

### ⚠️ Ma se `/tmp` usa la RAM, non mi ruba memoria per Oracle?

Fundamental question! The answer has **two parts**:

**Part 1: RAM is ONLY used for actual files.**
`tmpfs` NON pre-alloca tutta la memoria. Se `/tmp` contains 200 MB of files → uses 200 MB of RAM. If it is empty → use 0 MB. The `size=4g` it's just the **maximum** (like a credit card limit: you can spend *up to* €4000, but if you buy a sandwich you only pay €5).

**Part 2: How much to give to`/tmp` in base alla RAM che hai?**
There is no single answer. The size depends on the total RAM of your VM:

```
╔══════════════════════════════════════════════════════════════════╗
║ /tmp (tmpfs) SIZING GUIDE FOR ORACLE 19c ║
╠════════════════════╦════════════════════╦════════════════════════╣
║ VM RAM ║ Size /tmp ║ Notes ║
╠════════════════════╬════════════════════╬════════════════════════╣
║ 8 GB (ours!) ║ size=4g ║ OK for teaching lab ║
║ 16GB ║ size=6g ║ Comfortable ║
║ 32 GB              ║ size=10g           ║ Enterprise standard   ║
║ 64 GB+ ║ size=10g ║ 10 GB is always enough ║
╚════════════════════╩════════════════════╩════════════════════════╝
```

In our case with **8 GB of total RAM**, we have to divide it between different tenants:

```
╔══════════════════════════════════════════════════════════╗
║              BUDGET RAM (8 GB totali)                    ║
╠══════════════════════════════════════════════════════════╣
║ Linux Operating System ~1.0 GB (fixed) ║
║ Oracle SGA (shared memory)~1.5 GB (for DB) ║
║ Oracle PGA (process memory) ~0.5 GB (for the DB) ║
║  Grid Infrastructure (ASM/CRS) ~0.5 GB                  ║
║  ─────────────────────────────────────────────────       ║
║  /tmp (tmpfs) — TETTO MASSIMO   4.0 GB ← il nostro!    ║
║  ─────────────────────────────────────────────────       ║
║ Safety margin ~0.5 GB ║
╚══════════════════════════════════════════════════════════╝
```

This is why we choose **4 GB**: it exceeds the Oracle minimum by 4 times (1 GB), is close to best practice (5 GB), and does not take away too much RAM from the DB. In practice, `/tmp` it will never get to use all 4 GB (the Oracle installer uses a maximum of 1-2 GB peak), but the ceiling protects us from surprises.

> 📘 **What if the RAM really fills up?** Linux is smart: when RAM runs low, the kernel automatically moves "cold" files to `tmpfs` in the **swap** (which is on disk). That's why in Phase 0 we created 8 GB of swap — it also serves as a "safety net" for `tmpfs`! So the cycle is: RAM → Swap (disk) → and when they are needed again, Linux puts them back in RAM. Everything transparent.
>
> **In practice**: even if `/tmp` it is in RAM, in case of emergency Linux "parks" it on disk without anyone noticing. The best of both worlds!

---

### Commands to execute

**As a user `root`, copy and paste this block onto`rac1`:**

```bash
#1. Check the current situation (probably /tmp is on /)
df -hT /tmp

#2. Add tmpfs line to fstab file for permanent mounting
# Maximum ceiling: 4 GB (enough for Oracle, without wasting RAM)
echo "tmpfs  /tmp  tmpfs  defaults,size=4g,mode=1777  0 0" >> /etc/fstab

#3. Mount the new tmpfs NOW (without rebooting)
mount -o remount /tmp 2>/dev/null || mount /tmp

#4. Verify that /tmp is now on tmpfs
df -hT /tmp
# Deve mostrare: tmpfs    tmpfs   4.0G  ...  /tmp

#5. Verify that the RAM has NOT been "stolen"
free -h
# The "available" column should still show almost all free RAM!
```

> 💡 **Tip from DBA: Why `size=4g` e `mode=1777`?**
> - `size=4g`: Maximum limit of 4 GB. It's the right compromise for a lab with 8 GB of RAM: enough for any Oracle installer, without stealing too much memory from the DB. **Remember: RAM is consumed ONLY for files actually present in /tmp.**
> - `mode=1777`: It's the "sticky bit" (`drwxrwxrwt`). It means anyone can write in `/tmp`, but **only the owner** of a file can delete it. Without the sticky bit, the user `grid` potrebbe cancellare i file temporanei di `oracle` e viceversa, causando crash dell'installer.
> - `0 0`: As for `/u01`, you don't need dump or fsck for a filesystem in RAM.

---

## 1.6 Installing Prerequisite Packages

```bash
# Install the preinstall package that configures automatically
#kernel params, user limits, groups and much more
yum install -y oracle-database-preinstall-19c

# Additional packages needed
yum install -y ksh libaio-devel net-tools nfs-utils \
    smartmontools sysstat unzip wget xorg-x11-xauth \
    xorg-x11-utils xterm bind-utils
```

> **Why oracle-database-preinstall-19c?** This magical RPM package does 70% of the OS prep work: create the user `oracle`, configure the kernel parameters (`sysctl.conf`), set resource limits (`limits.conf`), install RPM dependencies. Without this, you would have to do everything by hand.

---

## 1.6 Fix Bug Systemd (RemoveIPC) - CRITICO!

> **Why?** On Oracle Linux 7 (and Red Hat 7+ derivatives), `systemd` ha un'impostazione predefinita mortale per Oracle: `RemoveIPC=yes`. This parameter causes the login daemon to automatically destroy shared memory (IPC) segments when a user logs out. If this happens to the user `grid` durante l'installazione, il servizio vitale del cluster (`ohasd`) will crash silently (`CRS-4639: Could not contact Oracle High Availability Services`) costringendoti a distruggere e rifare mezza installazione!

We absolutely need to force this value to`no` in the main systemd configuration file.

Run this command as root to add (or modify) the line in the configuration file and restart the daemon:

```bash
# Add RemoveIPC=no to logind.conf
echo "RemoveIPC=no" >> /etc/systemd/logind.conf

# Restart the login manager to apply the change
systemctl restart systemd-logind
```

---

## 1.7 Creation of Groups and Users

> **Why two users (oracle and grid)?** This is an Oracle "Role Separation" best practice. The user `grid` will install and manage clusterware and storage (ASM). The user `oracle` will install and manage database engines only. If one account is compromised, the other remains protected. The package `preinstall` has already created the user `oracle` base, ora dobbiamo creare il resto.

### Step 1: Creating ASM groups
Let's create three specific Linux groups to administer ASM shared storage. The -g numbers indicate the fixed GroupID (must be the same on all nodes!).
```bash
groupadd -g 54327 asmdba
groupadd -g 54328 asmoper
groupadd -g 54329 asmadmin
```

### Step 2: Add "oracle" to the ASM group
The oracle user must be able to read the ASM storage in order to write database datafiles to it. Let's add it to the group `asmdba`:
```bash
usermod -a -G asmdba oracle
```

### Step 3: Creating the "grid" user
Let's create the user `grid`, which will have as its main group `oinstall` and will be part of all administrative groups (dba, asmdba, asmadmin, asmoper, racdba):
```bash
useradd -u 54331 -g oinstall -G dba,asmdba,asmadmin,asmoper,racdba grid
```

### Step 4: Set Passwords (Manually)
We are in a laboratory, let's give the same easy password to both of us.
Run these commands. Linux will ask you to type the new password (you won't see the characters as you type for security). You write `oracle` per il primo e `grid` per il secondo, dando sempre Invio.

```bash
passwd oracle
# (Type: oracle -> Enter -> oracle -> Enter)

passwd grid
# (Digita: grid -> Invio -> grid -> Invio)
```

---

## 1.8 Directory Creation (Tree ORACLE_BASE)

> **Why this complex structure?** Oracle follows a rigid architecture called *OFA (Optimal Flexible Architecture)*. Separate Grid binaries from Database binaries. Memorize this concept: Grid software resides in `GRID_HOME`, and *can never be a subfolder* of `ORACLE_BASE` of grid, must be "out" (MOS Note 1373511.1).

### Step 1: Crea le cartelle per il Grid Infrastructure (Gestore Cluster)
These will host the global inventory, the base path for the grid logs, and the actual home of the 19c binaries.
```bash
mkdir -p /u01/app/19.0.0/grid # This will be theGRID_HOME
mkdir -p /u01/app/grid # This will be theORACLE_BASEof the user grid
mkdir -p /u01/app/oraInventory        # L'inventario unico per tutto il server
```

### Step 2: Create the Database folders
The Oracle 19c Database binaries will reside here instead.
```bash
mkdir -p /u01/app/oracle # This will be theORACLE_BASEof the oracle user
mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1 # This will be theDB_HOME
```

### Step 3: Assign Owners and Permissions
Now we tell the operating system that stuff `grid` belongs to the user `grid`, e la roba del database appartiene ad `oracle`. Entrambi fanno parte del gruppo installatori (`oinstall`).
```bash
chown -R grid:oinstall   /u01/app/19.0.0/grid
chown -R grid:oinstall   /u01/app/grid
chown -R grid:oinstall   /u01/app/oraInventory
chown -R oracle:oinstall /u01/app/oracle

# Give correct read/write/execute permissions to the entire /u01 tree
chmod -R 775 /u01
```

---

## 1.9 Environment Variables

### For the user `grid`

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

### For the user `oracle`

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

## 1.10 Kernel Parameters and Golden Image Optimizations (mandatory)

> 💡 **IMPORTANT**: All the steps in this section represent the heart of your **Golden Image**. They must be performed **ONLY on `rac1`**. When you clone the machine, these optimizations will already be present in all nodes, saving you hours of work and manual configurations.

### 1.10.1 Oracle Pre-Install Limits

Il pacchetto `oracle-database-preinstall-19c` has already configured them, but let's check:

```bash
#Check sysctl
sysctl -a | grep -E "shm|sem|file-max|ip_local_port|rmem|wmem"
```

Minimum expected values:
```
kernel.shmmax = 4398046511104
kernel.shmall = 1073741824
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
fs.file-max = 6815744
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
```

```bash
#Check limits
cat /etc/security/limits.d/oracle-database-preinstall-19c.conf
```

If the limits for the user `grid`they don't exist (the preinstall only creates them for`oracle`), we have to create them ourselves by copying those of oracle.

1. Copy the existing configuration file:
   ```bash
   cp /etc/security/limits.d/oracle-database-preinstall-19c.conf \
      /etc/security/limits.d/grid-database-preinstall-19c.conf
   ```
2. Open the new file with `vi`:
   ```bash
   vi /etc/security/limits.d/grid-database-preinstall-19c.conf
   ```
3. 💡 **Vim Pro Tip (Quick Replacement)**:
   Instead of changing each line by hand, use this "magic" Vim command. Type (while not in insert mode):
   `:%s/oracle/grid/g`
   E poi premi `Invio`. Vim will replace ALL "oracle" expirations with "grid" in one fell swoop!
4. Save and close (`Esc`, poi `:wq`, poi `Invio`).

---

## 🚀 DBA Pro Tip: How to do everything quickly (MobaXterm)

If you find it boring to repeat the same commands on `rac1`, `rac2`, ecc., usa queste due tecniche:

1. **Multi-Execution Mode (Il Top!)**:
   In MobaXterm, click on the **"Multi-exec"** button (icon with four terminals). Any command you write in a tab will be instantly replicated on ALL open tabs. Perfect for `/etc/hosts`, package installation and user setup.
   > ⚠️ **ATTENTION**: Disable it when you need to write specific IPs for each node!

2. **Copy files between nodes (scp)**:
Instead of doing`cat` on each machine, you can configure a su `rac1`and copy it to the others:
   ```bash
   scp /etc/resolv.conf rac2:/etc/
   ```

---

---

### 1.10.1 Oracle Best Practices (Tassative)
In addition to the standard parameters, Oracle strongly recommends disabling some Linux features that cause instability and performance degradation on RAC clusters:

#### 1. Disabilitare Transparent HugePages (THP)
THPs cause severe memory fragmentation and performance degradation on the database. They must be disabled at kernel level (`grub`).

```bash
#Open the GRUB configuration file
vi /etc/default/grub

# Trova la riga che inizia con GRUB_CMDLINE_LINUXand add at the end (before the closing quotes of the string):
# transparent_hugepage=never

#Example:
# GRUB_CMDLINE_LINUX="crashkernel=auto ... rhgb quiet transparent_hugepage=never"

# Recompile the grub file to apply the change on the next reboot
grub2-mkconfig -o /boot/grub2/grub.cfg
```

> 💡 **Live Verification (Without Rebooting)**:
> If you want to make sure THP is disabled now (or if you already had it in the file), run this:
> ```bash
> cat /sys/kernel/mm/transparent_hugepage/enabled
> ```
> Se vedi `[never]`, allora sei a posto! Se vedi `[always]`, you need to restart your machine after launching `grub2-mkconfig`.

#### 2. Disabilitare Avahi Daemon (mDNS)
The Avahi daemon sends constant multicast (Bonjour/mDNS) packets over the network. On the private interface of the RAC this generates "background noise" which can disturb the heartbeat protocol of the Clusterware.
```bash
systemctl stop avahi-daemon.socket
systemctl stop avahi-daemon.service
systemctl disable avahi-daemon.socket
systemctl disable avahi-daemon.service
```

#### 3. Disable NOZEROCONF (Route 169.254.x.x)
Prevents Linux from automatically assigning link-local addresses (169.254.0.0) on network interfaces, keeping the routing table clean.
```bash
echo "NOZEROCONF=yes" >> /etc/sysconfig/network
```

#### 4. Standard HugePages Configuration (Optional but Recommended)

Unlike Transparent HugePages (which must be turned off), pre-allocated **Standard HugePages** are a critical best practice.

##### 💡 Why use them? (Simplified)
1. **Giant Pages**: By default Linux uses 4KB pages. For a 1.5GB SGA, Linux has to handle millions of "little pieces". With HugePages, we use **2MB** pages (512 times larger!). The processor finds data much faster.
2. **No Swap**: HugePages remain "nailed" in physical RAM. Oracle will never end up in "swap" (slow disk), guaranteeing constant performance.
3. **Less CPU Load**: The kernel has much less effort managing database memory.

##### 🧮 The Mathematics of the Lab
- Our **SGA** Oracle will be approximately **1.5 GB**.
- By configuring **1024 pages** of 2MB each, we allocate **2 GB** in total of ultra-fast RAM.
- This way the SGA will fit comfortably inside.

```bash
# Imposta 1024 HugePages (2MB l'una = 2GB totali)
echo "vm.nr_hugepages = 1024" >> /etc/sysctl.conf
sysctl -p
```

> ⚠️ **Nota**: Una volta dato il comando `sysctl -p`, the RAM is "seized" by the kernel for Oracle. Not seeing it as "Free" anymore is normal!

---

## 1.11 NTP/Chrony configuration

Oracle Clusterware requires clocks to be synchronized between all nodes (max 1 second difference):

```bash
# Configura Chrony
vi /etc/chrony.conf
# Add/edit:
# server 0.pool.ntp.org iburst
# server 1.pool.ntp.org iburst

systemctl enable chronyd
systemctl restart chronyd

#Verify
chronyc sources
```

> **Why?** If the clocks of the cluster nodes diverge too much, the Clusterware forces a "node eviction" (ejects the node from the cluster) to protect the data.


---

## 1.12 SSH Setup (REVISED GUIDE)

> ⚠️ **IMPORTANT**: We have decided to **NOT** generate keys on the Golden Image. 
> Se le generassimo su `rac1` and then cloned, all nodes would have the **exact same key**, which is not security best practice.
> 
> **WHAT TO DO NOW**: Skip this step and go directly to step 1.13. We will generate unique keys for each node in **Section 1.15**, right after cloning.

> 🛠️ **OPS! HAVE YOU ALREADY GENERATED THE KEYS?**
> If you have already launched the commands and the "randomart image" has appeared, don't worry. To return to the "clean" Golden Image and avoid duplicate keys, run these commands as root:
> ```bash
> rm -rf /home/grid/.ssh
> rm -rf /home/oracle/.ssh
> rm -rf /root/.ssh
> ```
> Done! Now your machine is virgin again and ready to be cloned properly.

---

---

## 1.13 Inventory Location (Golden Image)
> **Node: rac1** | **User: root**

```bash
## 1.13 Inventory Location (Golden Image)

> 💡 **Node: rac1** | **User: root**

This file is crucial: it tells the Oracle installer where to keep the registry (inventory) of all products installed on the machine.

**Why do we do this in the Golden Image?**
Configurandolo qui, tutti i nodi clonati (`rac2`, `racstby`...) will already have the correct pointing and the right permissions. This prevents the installer from crashing asking you to create it manually during the Grid installation.

```bash
cat > /etc/oraInst.loc <<'EOF'
inventory_loc=/u01/app/oraInventory
inst_group=oinstall
EOF

chmod 664 /etc/oraInst.loc
chown grid:oinstall /etc/oraInst.loc
```

---
```

---

## 🛑 THE MOMENT OF TRUTH: Golden Image Cloning

You have just completed all OS configuration, users, groups, limits and binaries on **`rac1`**. 

> 🔍 **Verify ASM (Before Clone)**:
> As a user `root`, check that the ASM driver is ready (even if you don't see the disks yet):
> ```bash
> oracleasm status
> # Must respond: "Checking if ASM is loaded: yes" and "Checking if /dev/oracleasm is mounted: yes"
> ```

> ⚠️ **WARNING:** This is the exact moment you need to stop. If you proceed further or try to do SSH key exchange, you will fail. **YOU MUST CLONE NOW.**

### 1.14 Cloning Procedure (FROM RAC1 TO ALL)

#### Step 1: Spegni `rac1`
```bash
# Da MobaXterm su rac1
poweroff
```

> 📸 **SNAPSHOT — "SNAP-02: Golden_Image_Pronta" ⭐ MILESTONE**
> As soon as the machine is turned off, take the snapshot NOW. This is your **Golden Image**.
> ```bash
> VBoxManage snapshot "rac1" take "SNAP-02: Golden_Image_Pronta"
> ```

#### Step 2: Crea i Cloni (rac2, racstby1, racstby2)
1. In VirtualBox, seleziona `rac1` -> Section **Snapshots**.
2. Tasto destro su `SNAP-04` -> **Clona**.
3. **MAC POLICY**: Select **Generate new MAC addresses** (CRUCIAL).
4. **CLONE TYPE**: Full cloning.
5. Ripeti per creare: `rac2`, `racstby1`, `racstby2`.

#### Step 3: FIX STORAGE (Crucial!) - Remove shared disk "clones"
Quando cloni `rac1`, VirtualBox unfortunately creates useless copies of ASM disks (e.g. `rac2-disk1.vdi`). We need to remove them and connect the original ones.

**Per RAC2:**
1. Select`rac2`-> **Settings** -> **Storage**.
2. Under the SATA Controller, you will see many disks. **You must keep the first TWO discs:**
   - The operating system disk (approximately 50GB).
- The disk with the Oracle binaries on`/u01`(exactly **100GB**).
   > 🛑 **DO NOT REMOVE THE 100GB DISK!** Contains all the Oracle software you installed on the Golden Image.
3. **Instead, remove all the other 5 clone disks** (the 2GB, 20GB, 15GB ones that VirtualBox automatically renamed, e.g. `rac2-disk3.vdi`).
4. Now click on the "Add Hard Disk" icon and select **Choose an existing disk**.
5. Select the 5 original discs created in Phase 0: `asm_crs1`, `asm_crs2`, `asm_crs3`, `asm_data`, `asm_reco`.
6. Clicca OK. Ora `rac1` e `rac2` they point to the SAME disks (crucial for the RAC).

**Per RACSTBY1 e RACSTBY2:**
1. Just like for RAC2: **Remove duplicate disks from clone**.
2. Click the "Add Hard Disk" icon and select **Choose an existing disk**.
3. Select the **5 Standby specific disks** created in Phase 0: `asm_stby_crs1`, `asm_stby_crs2`, `asm_stby_crs3`, `asm_stby_data`, `asm_stby_reco`.
> 🛑 **FUNDAMENTAL**: A Standby RAC is in effect an independent cluster! **MUST** have its 3 CRS disks for the Clusterware and its DATA/RECO disks. Do not share disks between the primary and standby clusters.

#### Step 4: Customize the Clones (The 3 COMPLETE Checklists)

Power on the clones **one at a time** from the black VirtualBox console.
> ⚠️ **WARNING**: Do not use MobaXterm! As soon as they are turned on, all clones have the IP `.101` di `rac1` e farebbero conflitto.

Log in as `root`. The procedure to "clean" the Golden Image and adapt it to the new node is divided into two phases: **System** and **Network**.

##### 🟢 Checklist per `rac2`
**1. System & Network (Copy-Paste this script)**
To do it first and not make mistakes with `nmtui`, **copia e incolla questo script intero** nel terminale di `rac2` as soon as you turn it on. Will change Hostname, Public IP (a `.102`), IP Privato (a `.102` su subnet `.1.x`) and will restart the network service in one go.

```bash
# === SCRIPT AUTOMATICO PER RAC2 ===
hostnamectl set-hostname rac2.localdomain

# Change Public IP (enp0s8) from .101 to .102
sed -i 's/192.168.56.101/192.168.56.102/g' /etc/sysconfig/network-scripts/ifcfg-enp0s8

# Change Private IP (enp0s9) from .101 to .102
sed -i 's/192.168.1.101/192.168.1.102/g' /etc/sysconfig/network-scripts/ifcfg-enp0s9

#Restart the network to apply
systemctl restart network
ping -c 2 google.com
```

> 💡 **Done!** Now you can close the uncomfortable VirtualBox window, open **MobaXterm** and conveniently connect via SSH to the IP `192.168.56.102` as root.

**2. Storage (To be done with the VM turned off in VirtualBox)**
- [ ] You have removed the clones`.vdi` inutili?
- [ ] You attached the original 5 shared disks (`asm_crs1`, `crs2`, `crs3`, `data`, `reco`)?

##### 🔵 Checklist per `racstby1`
**1. System & Network (Copy-Paste this script)**
Incolla questo nel terminale nativo di `racstby1`. Attention: the private network changes subnet here! This will go on `.2.x`.

```bash
# === SCRIPT AUTOMATICO PER RACSTBY1 ===
hostnamectl set-hostname racstby1.localdomain

# Change Public IP (enp0s8) from .101 to .111
sed -i 's/192.168.56.101/192.168.56.111/g' /etc/sysconfig/network-scripts/ifcfg-enp0s8

# Change Private IP (enp0s9) from 192.168.1.101 to 192.168.2.111
sed -i 's/192.168.1.101/192.168.2.111/g' /etc/sysconfig/network-scripts/ifcfg-enp0s9

#Restart the network to apply
systemctl restart network
ping -c 2 google.com
```

> 💡 **Done!** Now open MobaXterm and connect to the IP`192.168.56.111`.

**2. Storage (To be done with the VM turned off in VirtualBox)**
- [ ] You have removed the clones`.vdi` inutili?
- [ ] You have attached the 5 PHYSICALLY DIFFERENT disks created in Phase 0 for standby (`asm_stby_crs1`, `crs2`, `crs3`, `data`, `reco`)?

##### 🔵 Checklist per `racstby2`
**1. System & Network (Copy-Paste this script)**

```bash
# === SCRIPT AUTOMATICO PER RACSTBY2 ===
hostnamectl set-hostname racstby2.localdomain

# If you cloned from rac1 (final ip .101) or racstby1 (final ip .111) use the appropriate sed command.
# Let's assume you are cloning from Golden Image rac1 (IP .101):
sed -i 's/192.168.56.101/192.168.56.112/g' /etc/sysconfig/network-scripts/ifcfg-enp0s8
sed -i 's/192.168.1.101/192.168.2.112/g' /etc/sysconfig/network-scripts/ifcfg-enp0s9

#Restart the network to apply
systemctl restart network
ping -c 2 google.com
```

> 💡 **Done!** Now open MobaXterm and connect to the IP`192.168.56.112`.

**2. Storage (To be done with the VM turned off in VirtualBox)**
- [ ] You attached the 5 standby disks in the same way (`asm_stby...`) condividendoli con `racstby1`?


---

## 1.15 Post-Cloning Configuration: SSH Trust (UNIQUE Keys)

> 💡 **Nodes: rac1 AND rac2** | **User: grid / oracle / root**
> Now that both nodes are alive and have different IPs, let's create their unique digital identities and make them "trust" each other.

### STEP 1: Key Generation (Run on BOTH nodes)
Apri due tab in MobaXterm (uno per `rac1`and one for`rac2`) and activate **Multi-Execution Mode**.

**As a user `grid`:**
```bash
su - grid
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
```

**As a user `oracle`:**
```bash
su - oracle
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
```

**As a user `root`:**
```bash
su - root
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
```

### STEP 2: Key Exchange (SSH Trust)
Now **DISABLE** Multi-Execution Mode and proceed node by node.

#### For the user `grid`:
```bash
#From rac1 it sends the key to itself and to rac2
ssh-copy-id grid@rac1
ssh-copy-id grid@rac2

#From rac2 it sends the key to itself and to rac1
ssh-copy-id grid@rac1
ssh-copy-id grid@rac2

# Test finale (NON deve chiedere password)
ssh grid@rac1 date
ssh grid@rac2 date
```

#### For the user `oracle`:
```bash
# Da rac1
ssh-copy-id oracle@rac1
ssh-copy-id oracle@rac2

# Da rac2
ssh-copy-id oracle@rac1
ssh-copy-id oracle@rac2

# Test finale (NON deve chiedere password)
ssh oracle@rac1 date
ssh oracle@rac2 date
```

#### For the user `root`:
```bash
# Da rac1
ssh-copy-id root@rac1
ssh-copy-id root@rac2

# Da rac2
ssh-copy-id root@rac1
ssh-copy-id root@rac2

# Test finale (NON deve chiedere password)
ssh root@rac1 date
ssh root@rac2 date
```

> 💡 **WHY NOW?** By doing this right now, each machine generates its own specific key. If we had done it in the Golden Image, `rac1` e `rac2` they would have been "identical twins" at the SSH security level (same private key), which is not recommended.

---

## 1.16 Synchronization and Creation of ASM Disks (Post-Cloning)

There is a **fundamental difference** between how `rac2` and standby nodes manage disks after cloning:
- `rac2` received the discs originally created on `rac1`. They already have the ASM header. You just "scan" them.
- Standby nodes received **NEW AND EMPTY** disks created in Phase 0. You must first "format" them for ASM on `racstby1`, e poi scansionarli su `racstby2`.

> 💡 **Tip from DBA: The concept of the ASM "Stamp"**
> Many get confused at this stage. Create the files `.vdi` in VirtualBox e fare `fdisk` (as done in Phase 0) just means providing raw "pieces of iron" to the operating system. 
> Until you use the command `oracleasm createdisk` (which we are about to launch), Oracle doesn't know those disks exist. `createdisk` scrive fisicamente un "header ASM" nel primo megabyte del disco. Lo `scandisks` what you do on the other node simply tells the kernel: *"Hey, look, the other node just put the Oracle stamp on this disk, read it!"*

> 💡 **User: root** on all machines.

### Case A: Primary Nodes (`rac1` e `rac2`)

**1. SOLO su `rac1` (Creation):**
The shared disks that we partitioned in Phase 0 now need to be "stamped" to ASM. This must be done **exclusively from the first node**.

> ⚠️ **ATTENZIONE ALLA LETTERA DEL DISCO (`/dev/sdX`)!**
> La lettera assegnata da Linux (`sdb`, `sdc`, `sdd`...) depends on the random order in which VirtualBox attacked the SATA disks on reboot. **DO NOT COPY THE COMMANDS BELOW BLINDLY!**
> Throw first `lsblk` to understand who is who, based on **size**:
> - The three partitions from **2G** $\rightarrow$ are`CRS1`, `CRS2`, `CRS3`
> - The **20G** $\rightarrow$ partition is `DATA`
> - The **15G** $\rightarrow$ partition is `RECO`

Sostituisci le lettere `sdX1` in the commands below with those you see in yours `lsblk`:

```bash
#EXAMPLE: Replace sdc1, sdd1 etc. with your real letters!
oracleasm createdisk CRS1 /dev/sdc1
oracleasm createdisk CRS2 /dev/sdd1
oracleasm createdisk CRS3 /dev/sde1
oracleasm createdisk DATA /dev/sdf1
oracleasm createdisk RECO /dev/sdg1

#Check that they have been created
oracleasm listdisks
```

**2. SOLO su `rac2`(Scan):**
Node 2 doesn't have to format anything, it shares disks with `rac1`. He just has to tell his kernel to reread the disks to notice the work just done.

```bash
# Make rac2 aware of the volumes just created by rac1
oracleasm scandisks

#Check that rac2 now also sees the 5 disks (CRS1, CRS2...)
oracleasm listdisks
```

### Case B: On Standby nodes (`racstby1` e `racstby2`)

**1. SOLO su `racstby1` (Creation):**
Since the disks chosen for standby in VirtualBox were blank, you have to "stamp" them with the ASM header. 

> ⚠️ **ATTENZIONE ALLA LETTERA DEL DISCO!**
> Here too, based on the dimensions detected by `lsblk` per assegnare le etichette corrette:
> - The three **2G** $\rightarrow$ partitions`STBY_CRS1`, `STBY_CRS2`, `STBY_CRS3`
> - The **20G** $\rightarrow$ partition`STBY_DATA`
> - The **15G** $\rightarrow$ partition`STBY_RECO`

```bash
#EXAMPLE: Replace sdb1, sdc1 etc. with your actual letters based on lsblk!
oracleasm createdisk STBY_CRS1 /dev/sdb1
oracleasm createdisk STBY_CRS2 /dev/sdc1
oracleasm createdisk STBY_CRS3 /dev/sdd1
oracleasm createdisk STBY_DATA /dev/sde1
oracleasm createdisk STBY_RECO /dev/sdf1

#Check that they have been created
oracleasm listdisks
```

**2. SOLO su `racstby2` (Scansione):**
Standby node 2 does not have to format them (node ​​1 has already done it), it just needs to realize that the other node has prepared them.

```bash
# Scan newly formatted disks from racstby1
oracleasm scandisks

#Make sure you see all 5
oracleasm listdisks
```

> **Why?** After cloning and reattaching disks in VirtualBox, the clone kernel needs a "refresh" to map new devices `/dev/sdX` e passarli al driver `oracleasm`.

---

## 1.17 Fix for error INS-06006 (SCP Protocol)

> ⚠️ **This fix is ​​ONLY needed if you use Oracle Linux 8 or 9!**
> Su **Oracle Linux 7** (il nostro caso nel lab), il comando `scp` it already uses the old protocol and the Oracle installer works perfectly **without modifications**. If you apply this fix on OEL 7, **break the command `scp`** because the flag `-T` it doesn't exist in the old version!

### How to understand if you need the fix

```bash
# Run this command to see your OS version:
cat /etc/oracle-release
```

|Result| Azione |
|---|---|
| Oracle Linux Server release **7.x** | ❌ **NON FARE NULLA!** `scp` it already works. Skip this section. |
| Oracle Linux Server release **8.x** o **9.x** | ✅ Apply the fix below on all nodes. |

### Il Fix (SOLO per Oracle Linux 8/9!)

**Why is it needed?** In recent versions of Linux (OEL 8+), the command `scp` has been quietly updated to use the SFTP protocol. The Oracle 19c installer, which is old, does not understand SFTP and crashes with the fatal error **INS-06006**. The workaround renames the real `scp` and creates a fake one that forces the old protocol.

```bash
# ===== SOLO SU ORACLE LINUX 8/9! NON ESEGUIRE SU OEL 7! =====
#As root user, on all nodes:

#1. Backup the real scp
cp -p /usr/bin/scp /usr/bin/scp.bkp

#2. We create the wrapper that forces the old protocol
cat > /usr/bin/scp <<'EOF'
#!/bin/bash
/usr/bin/scp.bkp -T "$@"
EOF

#3. Execution permissions
chmod +x /usr/bin/scp

#4. Check
cat /usr/bin/scp
```

### 🚨 Have you already applied the fix on Oracle Linux 7 by mistake?

If you have already done the fix, now what `scp` it doesn't work anymore (error `unknown option -- T`), ripristina il comando originale:

```bash
# Restore the backup of the real scp
cp -p /usr/bin/scp.bkp /usr/bin/scp

#Check that it works
scp --help
#Must no longer give "unknown option -- T"
```

---

## ✅ End of Phase 1 Checklist

Perform these final checks on **BOTH** nodes before moving on to Step 2:

```bash
#1. Correct hostname (Must be rac1 on one and rac2 on the other)
hostname

#2. All Nodes Pingable (Must Reply All!)
ping -c 1 rac1 && ping -c 1 rac2 && ping -c 1 rac1-priv && ping -c 1 rac2-priv

#3. DNS SCAN working (Must return 3 IPs)
nslookup rac-scan.localdomain

#4. SSH without password (grid, oracle and root)
# Su rac1 prova a entrare in rac2
su - grid -c "ssh rac2 hostname"
su - oracle -c "ssh rac2 hostname"
su - root -c "ssh rac2 hostname"

#5. Firewall and SELinux (Must be disabled/Permissive)
systemctl is-active firewalld || echo "Firewall OK (Disabled)"
getenforce
```

> 📸 **SNAPSHOT FINALE — "SNAP-03: Cloni_In_Rete_Dischi_ASM_OK"**
> This is your golden restore point for the entire cluster. If the Grid installation fails, return here discarding the failed Phase 2.
> **Do this on ALL nodes turned on at this time (`rac1` e `rac2`, plus any standby if you have already configured them on the network).**

---

**→ Next: [PHASE 2: Installing Grid Infrastructure and Primary Oracle RAC](./GUIDE_PHASE2_GRID_AND_RAC.md)**
