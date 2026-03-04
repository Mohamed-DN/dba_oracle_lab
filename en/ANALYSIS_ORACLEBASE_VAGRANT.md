# Analysis: Oracle Base Vagrant RAC vs Our Lab — Best Practices Extracted

> Source: [oraclebase/vagrant/rac/ol7_19](https://github.com/oraclebase/vagrant/tree/master/rac/ol7_19) + [oracle-base.com article](https://oracle-base.com/articles/19c/oracle-db-19c-rac-installation-on-oracle-linux-7-using-virtualbox)

---

## Architecture Comparison

| Area | Our Lab | Oracle Base Vagrant |
|---|---|---|
| DNS | BIND (on rac1) | dnsmasq (dedicated VM) |
| ASM Disks | oracleasm driver | **udev rules + scsi_id** |
| Time Sync | NTP/chrony | **chrony (burst+makestep)** |
| /u01 | Dir on root disk | **Dedicated XFS disk** |
| CRS Redundancy | EXTERNAL (1 disk) | **NORMAL (3 disks + FG)** |
| NetworkManager | Not configured | **dns=none** (protects resolv.conf) |
| Grid Install | GUI (recommended) | **Silent mode** (response file) |
| Database Type | Non-CDB | **CDB + PDB** |
| PDB Auto-start | Not configured | **ALTER PDB SAVE STATE** |
| SSH Setup | Manual | **sshpass + ssh-keyscan** |
| cvuqdisk | Mentioned | Explicitly installed |
| ASM compatibility | Not specified | **compatible.asm=19.0** |
| SELinux | Disabled | **Permissive** |

---

## Top 10 Improvements Integrated

### 1. udev Rules for ASM Disks
Oracle-recommended method for 19c+. Uses `scsi_id` + persistent symlinks at `/dev/oracleasm/`.

### 2. chrony Time Sync
Modern replacement for NTP with `burst 4/4` and `makestep` for fast sync.

### 3. NetworkManager dns=none
Prevents NetworkManager from overwriting `/etc/resolv.conf` after reboot — avoids SCAN resolution failures.

### 4. Dedicated /u01 XFS Disk
Separates Oracle binaries from OS disk — prevents filesystem full from crashing Oracle.

### 5. CRS NORMAL Redundancy
3 CRS disks with Failure Groups — teaches real production redundancy.

### 6. Grid Silent Install
Full `gridSetup.sh` with response file parameters — reproducible and scriptable.

### 7. CDB + PDB with Auto-Start
`ALTER PLUGGABLE DATABASE SAVE STATE;` — ensures PDB starts automatically.

### 8. SSH via sshpass
Automated SSH key exchange without manual interaction.

### 9. ASM Compatibility Attributes
`compatible.asm='19.0'` — enables 19c-specific ASM features.

### 10. cvuqdisk RPM
Must be installed on ALL nodes before Grid install — discovers ASM disks.

---

> All improvements have been integrated into the Italian guides (Fase 0, 1, 2, 3).
