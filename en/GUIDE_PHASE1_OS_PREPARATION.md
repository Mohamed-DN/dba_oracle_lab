# PHASE 1: OS Preparation and Configuration

> All commands in this phase are executed on **rac1** first. After completion, we clone rac1 → rac2 and adjust hostname/IP.

### How RAC Networks Work

```
                     ┌───────────────────────────────────────────┐
                     │          PUBLIC NETWORK (eth0)             │
                     │       192.168.1.0/24 (Bridged)           │
      Client App     │                                           │
          │          │  ┌──────┐  ┌──────┐  ┌──────┐            │
          ▼          │  │SCAN  │  │SCAN  │  │SCAN  │            │
    ┌──────────┐     │  │ .120 │  │ .121 │  │ .122 │            │
    │ SCAN     │◄────│──┤      │  │      │  │      │ DNS        │
    │ Listener │     │  └──────┘  └──────┘  └──────┘ Round-Robin│
    └────┬─────┘     │                                           │
         │           │  ┌─────────────┐   ┌─────────────┐       │
         ├──────────►│  │ rac1        │   │ rac2        │       │
         │           │  │ IP: .101    │   │ IP: .102    │       │
         │           │  │ VIP: .111   │   │ VIP: .112   │       │
         │           │  └──────┬──────┘   └──────┬──────┘       │
         │           └─────────┼──────────────────┼─────────────┘
         │                     │                  │
         │           ┌─────────┼──────────────────┼─────────────┐
         │           │         │  PRIVATE NET     │   (eth1)    │
         │           │         │  10.10.10.0/24   │  Host-Only  │
         │           │  ┌──────┴──────┐   ┌──────┴──────┐      │
         │           │  │ rac1-priv   │   │ rac2-priv   │      │
         │           │  │ 10.10.10.1  │◄═►│ 10.10.10.2  │      │
         │           │  └─────────────┘   └─────────────┘      │
         │           │         Cache Fusion (GCS/GES)           │
         │           └─────────────────────────────────────────┘
```

---

## 1.1 IP Plan

| Hostname | Public IP | Private IP | VIP | Type |
|---|---|---|---|---|
| rac1 | 192.168.1.101 | 10.10.10.1 | 192.168.1.111 | RAC Node 1 |
| rac2 | 192.168.1.102 | 10.10.10.2 | 192.168.1.112 | RAC Node 2 |
| rac-scan | 192.168.1.120-122 | — | — | SCAN (3 IPs) |

## 1.2 Configure /etc/hosts

```bash
cat >> /etc/hosts <<'EOF'
# Public
192.168.1.101   rac1.oracleland.local    rac1
192.168.1.102   rac2.oracleland.local    rac2
# Private
10.10.10.1      rac1-priv.oracleland.local rac1-priv
10.10.10.2      rac2-priv.oracleland.local rac2-priv
# VIP
192.168.1.111   rac1-vip.oracleland.local  rac1-vip
192.168.1.112   rac2-vip.oracleland.local  rac2-vip
EOF
```

## 1.3 Static Network Configuration (eth0 + eth1)

```bash
# Public (eth0)
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<'EOF'
DEVICE=eth0
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.1.101
NETMASK=255.255.255.0
GATEWAY=192.168.1.1
DNS1=192.168.1.101
DOMAIN=oracleland.local
EOF

# Private Interconnect (eth1)
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 <<'EOF'
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
IPADDR=10.10.10.1
NETMASK=255.255.255.0
EOF

systemctl restart network
```

## 1.4 DNS Configuration (BIND on rac1)

```bash
yum install -y bind bind-utils
```

Configure BIND with zone `oracleland.local` containing A records for all hosts + 3 SCAN IPs (round-robin).

> 📸 **SNAPSHOT — "SNAP-02: Network and DNS Configured"**

## 1.5-1.8 Firewall, Packages, Users

```bash
# Disable firewall & SELinux
systemctl stop firewalld && systemctl disable firewalld
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# Install Oracle prerequisites
yum install -y oracle-database-preinstall-19c

# Create grid user
useradd -g oinstall -G dba,asmdba,asmoper,asmadmin grid
echo "oracle" | passwd --stdin grid
echo "oracle" | passwd --stdin oracle
```

## 1.9-1.12 Directories, Environment, Kernel, SSH

```bash
# Directories
mkdir -p /u01/app/19.0.0/grid /u01/app/grid /u01/app/oracle/product/19.0.0/dbhome_1
chown -R grid:oinstall /u01/app/19.0.0/grid /u01/app/grid
chown -R oracle:oinstall /u01/app/oracle

# SSH equivalency (on both nodes for grid and oracle users)
su - grid
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
ssh-copy-id grid@rac1 && ssh-copy-id grid@rac2

# Kernel parameters (already set by oracle-preinstall-19c, verify)
sysctl -a | grep -E "shmmax|shmall|sem|file-max"
```

> 📸 **SNAPSHOT — "SNAP-03: Prerequisites Complete (Pre-Grid)"** ⭐ MILESTONE

---

**→ Next: [PHASE 2: Grid Infrastructure & RAC](./GUIDE_PHASE2_GRID_AND_RAC.md)**
