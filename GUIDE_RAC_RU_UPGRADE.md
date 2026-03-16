# Guide to Upgrading Release Updates (RU) in Oracle RAC

This guide explains how to manage the transition from an existing RU (e.g. r19.25) to a newer one (e.g. r19.30) using the **Combo Patch** format and **opatchauto** automation.

> [!WARNING]
> The **January 2026** Release Update requires **OPatch 12.2.0.1.48** or higher. Make sure to update the OPatch utility in all Homes before starting the upgrade.

---

## 1. Oracle Upgrade Logic 19c

In Oracle 19c, applying a new Release Update (RU) over an existing one follows an automated flow:

1. **Detection**:`opatchauto`scans the Home and discovers the currently installed RU patch.
2. **Automatic Rollback**: If the patch you are applying is a new version of the same type (RU), the tool automatically *rollbacks* the previous patch.
3. **Application**: Once the old version is removed, the new release is applied.
4. **Cluster Management**: For the Grid Infrastructure, `opatchauto` independently manages the stop and start of the CRS (Oracle High Availability Services) services.

> **Advantage**: No need to issue manual uninstall commands. A single command (`opatchauto apply`) manages the entire update lifecycle.

---

Combo Patches (like `p38658588`) contain both the **Database/Grid RU** and the **OJVM RU**. Here is the workflow for upgrading on an already patched system.

### ⚠️ Step 0: OPatch Update (MANDATORY)

Before starting the RU upgrade, you must update the OPatch utility in **all Homes** (Grid and Database) on **all nodes**. Without the minimum version (e.g. `.48` for Jan 2026), the upgrade will fail.

```bash
# Come root su rac1
mv /u01/app/19.0.0/grid/OPatch /u01/app/19.0.0/grid/OPatch.bkp
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.0.0/grid/
chown -R grid:oinstall /u01/app/19.0.0/grid/OPatch

mv /u01/app/oracle/product/19.0.0/dbhome_1/OPatch /u01/app/oracle/product/19.0.0/dbhome_1/OPatch.bkp
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/dbhome_1/
chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1/OPatch
# Ripeti su rac2
```

### Step 1: Cleaning and Preparation
Before unzipping the new patch, free up space on `/u01/app/patch` (which is our 50GB workspace, since `/tmp` is too small in our VMs).

```bash
# Come root su rac1
rm -rf /u01/app/patch/*
cd /u01/app/patch
unzip -q /tmp/p38658588_190000_Linux-x86-64.zip
chown -R grid:oinstall /u01/app/patch
```

### Step 2: Identification of Sub-Patches
The Combo Patch will extract two directories. For Jan 2026:
- `38629535`: The main Release Update (RU).
- `38523609`: La OJVM Release Update.

### Step 3: Upgrade the Grid Home (Nodes 1 and 2)
```bash
# Come root
cd /u01/app/patch/38658588/38629535
export GRID_HOME=/u01/app/19.0.0/grid
$GRID_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $GRID_HOME
```
*`opatchauto` will detect the previous version (e.g. Jan 2025), roll back and apply Jan 2026.*

### Step 4: Upgrade the Home Database (Nodes 1 and 2)
```bash
# Come root
cd /u01/app/patch/38658588/38629535
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME
```

### Step 5: Upgrade OJVM (Oracle Home)
The OJVM patch applies over the old one with `opatch apply`.

```bash
# Like oracle on rac1
su - oracle
cd /u01/app/patch/38658588/38523609
$ORACLE_HOME/OPatch/opatch apply
```

---

## 3. Post-Upgrade: Datapatch

After updating the binaries on all nodes, you need to align the database data dictionary. This command must be executed on **ONE NODE** (rac1) with the DB open.

```bash
# Like oracle on rac1
$ORACLE_HOME/OPatch/datapatch -verbose
```

### Final check
```sql
SELECT patch_id, status, description FROM dba_registry_sqlpatch;
```
*Status must be `SUCCESS` for all most recent entries.*

---

## 4. Troubleshooting: Spazio Disco

If an upgrade fails with "Space Check" errors, remember that `opatch` keeps backups of previous patches in `$ORACLE_HOME/.patch_storage`.

**Best Practice di Pulizia:**
Once the upgrade is successfully completed, always **DELETE** the extracted files to avoid saturating the `/u01` partition.

```bash
# Come root
rm -rf /u01/app/patch/*
```
*(NEVER delete the hidden folder`.patch_storage` dentro le Home).*
