# Full Automation: Primary RAC + Standby RAC + Data Guard
> Based on the official `oraclebase/vagrant` repositories, re-adapted to fully simulate **Phases 0 through 4** of your study plan.

This Vagrant module lets you bring up the entire lab infrastructure with just a few commands, automating hours of tedious manual configuration (Grid installation, DBCA, clones, Standby Redo Logs, RMAN Duplicate and Broker).

## ⚠️ Hardware Requirements (ATTENTION)
You will have 5 VMs running simultaneously:
- `dnsnode` (1 GB)
- `rac1` (8 GB)
- `rac2` (8 GB)
- `racstby1` (8 GB)
- `racstby2` (8 GB)

**Total RAM required: 33 GB physical on your host**. If you don't have at least 64 GB of RAM on your machine, it will swap heavily and slow everything down. In that case, edit `config/vagrant.yml` to lower `mem_size` to `4096` (at the cost of a slower Oracle installer).

## Software Preparation (MANUAL)
Before running any command, you must download the original Oracle binaries and place them in the `/software` folder.
1. Create the `software` folder here in the root: `mkdir software`
2. Place the two Oracle 19c zip files for Linux inside it:
   - `LINUX.X64_193000_grid_home.zip`
   - `LINUX.X64_193000_db_home.zip`

*(Note: The Oracle Linux ISO is automatically downloaded from Vagrant Cloud via the ol7 base box)*

## Startup Instructions (Order is MANDATORY)
The RAC architecture strictly depends on DNS, and Node 2 depends on Node 1. Open 5 different terminals and launch in this order:

### 1. The Core (DNS)
```bash
cd dns
vagrant up
```
*(Wait for installation to complete)*

### 2. Primary RAC (Production)
```bash
cd rac1
vagrant up
```
*(Wait 40-50 minutes. It will install Grid and configure `RACDB`, setting the DB to ARCHIVELOG mode and creating the SRLs)*

```bash
cd rac2
vagrant up
```
*(Wait 30 minutes. It joins the cluster and starts instance 2).*

### 3. Standby RAC (Protection)
```bash
cd racstby1
vagrant up
```
*(Wait 40 minutes. It will install Grid, then run an `RMAN DUPLICATE FOR STANDBY FROM ACTIVE DATABASE` to physically copy `RACDB` over the network to the Standby site)*

```bash
cd racstby2
vagrant up
```
*(Wait 30 minutes. It joins the Standby Cluster)*

### 4. Broker Activation (DGMGRL)
Unlike the rest, Broker activation MUST be performed when all 5 machines are 100% operational and visible on the network.
From an SSH session to `rac1`:
```bash
sh /vagrant_scripts/configure_broker.sh
```

## How to Destroy the Lab
When you have finished the experiment:
```bash
cd racstby2 && vagrant destroy -f
cd racstby1 && vagrant destroy -f
cd rac2 && vagrant destroy -f
cd rac1 && vagrant destroy -f
cd dns && vagrant destroy -f
```
To also physically remove the heavy shared ASM disks generated in `/shared_disks`:
```bash
rm -rf ../shared_disks/*
```
