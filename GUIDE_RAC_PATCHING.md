# Post-Installation Patching Guide (Oracle RAC 19c)

This guide is a "day-2" reference for administering your RAC cluster. It explains how to manage quarterly updates (Release Update), how to switch from one version to another, what a *Combo Patch* is and how to keep the filesystem clean so as not to run out of space.

> [!IMPORTANT]
> **REQUISITO MINIMO OPATCH (Patch Gennaio 2026)**
> If you are applying the January 2026 Combo Patch (p38658588) or later, you must be using **OPatch version 12.2.0.1.48** or higher. Older versions (such as .47 or .43) will fail the pre-requisites of `opatchauto`.

---

## 1. What is a "Combo Patch"?

Often on Oracle Support (MOS) you will find two types of downloads for quarterly patches:
1. **Individual Patches**: For example, you download the zip for the *Grid Infrastructure Release Update (GI RU)* and a separate zip for the *Oracle Java VM (OJVM) Release Update*.
2. **Combo Patch**: It's a single mega-zip (like `p38658588` for Jan 2026) that includes **both** patches inside.

### How do you use a Combo Patch?
It's very simple: when you unzip the Combo Patch, two numeric subfolders will be created. For example, extracting `p38658588` you might find:
- `/u01/app/patch/38658588/38629535` (which is the real GI/DB RU)
- `/u01/app/patch/38658588/38523609` (which is the real OJVM RU)

At that point, you use `opatchauto` pointing to the first folder, and `opatch apply` pointing to the second folder. The Combo Patch is just a "container" for download convenience.

---

## 2. Upgrade from an "old" RU to a "new" one

If you have already patched your cluster (e.g. to Jan 2025) and now want to move to Jan 2026, **you DO NOT need to manually uninstall the previous patch**. 

The `opatchauto` tool (which you use to apply Release Updates) is smart:
1. Automatically detects which RU is installed.
2. Check which RU you are trying to install.
3. If the new one is superior, **automatically rollback (uninstall) the old one** before applying the new one.
4. Restart CRS services.

It does everything by itself in one command! (But remember to make a compressed backup of the ORACLE_HOME and GRID_HOME before running the command, as *Best Practice*).

---

## 3. Disk Space Cleanup (Clean Old Patches)

Oracle patches are huge (often >3GB unpacked). In our VMs, the space on `/u01` is around 50 GB. If you keep every single extracted patch in the `/u01/app/patch` folder, in two update cycles you will fill the disk.

### What you can delete SAFELY:
Once a patch has been successfully applied (`opatchauto apply` and `datapatch` finished), **the extracted files in `/u01/app/patch` are no longer of any use**. The `opatch` utility has already copied everything it needs into `$ORACLE_HOME/.patch_storage` (hidden folder used for rollback).

**Cleanup Procedure (on all nodes as root):**
```bash
su - root

#1. Remove unzipped patch folders
rm -rf /u01/app/patch/*

#2. Remove the original downloaded ZIP files (if they remained in /tmp or /u01)
rm -f /tmp/p*.zip
rm -f /u01/app/patch/*.zip

# 3. Elimina i backup .tar.gz vecchi delle ORACLE_HOME 
# (Keep only the last working one, delete those from months ago)
# Esempio: rm /u01/app/grid_home_backup_20250101.tar.gz
```

> **MAI CANCELLARE la cartella `$ORACLE_HOME/.patch_storage`**. If you do, you destroy OPatch's ability to rollback or apply future patches, irreparably corrupting the homepage!

---

## 4. Patching Procedure with the Combo Patch (Example)

Hai scaricato la Combo Patch `p38658588_190000_Linux-x86-64.zip` e l'ultima patch OPatch `p6880880_190000_Linux-x86-64.zip` in `/tmp/` su entrambi i nodi.

### ⚠️ Step 0: Update the OPatch utility (REQUIRED)

Before applying any RU patches, you must update the OPatch utility in **each** Home (Grid and Database) on **all** nodes. If you don't do this, `opatchauto` will fail with error `CheckMinimumOPatchVersion`.

```bash
# Come root su rac1
su - root

#1. Update OPatch for Grid Home
mv /u01/app/19.0.0/grid/OPatch /u01/app/19.0.0/grid/OPatch.bkp
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.0.0/grid/
chown -R grid:oinstall /u01/app/19.0.0/grid/OPatch

#2. Update OPatch for the Home Database
mv /u01/app/oracle/product/19.0.0/dbhome_1/OPatch /u01/app/oracle/product/19.0.0/dbhome_1/OPatch.bkp
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d /u01/app/oracle/product/19.0.0/dbhome_1/
chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1/OPatch

# Repeat the same commands on rac2!
```

### Step 1: Combo Patch Extraction (Both Nodes)
```bash
su - root
mkdir -p /u01/app/patch/
cd /u01/app/patch/
unzip -q /tmp/p38658588_190000_Linux-x86-64.zip

# Find the two internal IDs:
ls -l /u01/app/patch/38658588/
# Esempio output (i numeri reali trovati):
# drwxr-xr-x 38523609  (questa è la OJVM)
# drwxr-x--- 38629535  (questa è la RU di DB/Grid)

# Assign correct rights
chown -R grid:oinstall /u01/app/patch/
```

### Step 2: Application to Grid Home (`opatchauto`)
Use the folder ID of the Grid/DB RU.
```bash
# Come root
cd /u01/app/patch/38658588/38629535
export GRID_HOME=/u01/app/19.0.0/grid
$GRID_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $GRID_HOME
# Ripeti su rac2
```

### Step 3: Application to DB Home (`opatchauto`)
```bash
# Come root
cd /u01/app/patch/38658588/38629535
chown -R oracle:oinstall /u01/app/patch/
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME
# Ripeti su rac2
```

### Step 4: Apply OJVM to the Home DB (`opatch`)
```bash
# Come oracle
su - oracle
cd /u01/app/patch/38658588/38523609
$ORACLE_HOME/OPatch/opatch apply
# Reply 'y' when prompted
# Ripeti su rac2
```

### Step 5: Datapatch (Only after the DB is created and opened)
```bash
# Like oracle on rac1
$ORACLE_HOME/OPatch/datapatch -verbose
```

---

## 5. How to Rollback (Emergency)

If an applied patch causes very serious problems and you want to remove it, you can go back using the local OPatch repository. There is no need to re-download the original zip.

**Per una Release Update (Grid o DB):**
```bash
# Come root
export ORACLE_HOME=/u01/app/19.0.0/grid   # o dbhome_1
$ORACLE_HOME/OPatch/opatchauto rollback -id 38629535 -oh $ORACLE_HOME
```

**Per la patch OJVM (DB Home):**
```bash
# Come oracle
$ORACLE_HOME/OPatch/opatch rollback -id 38523609
```

---

## 6. Post-Patching Verification

Verify binaries (OS level):
```bash
$ORACLE_HOME/OPatch/opatch lspatches
```

Check the Data Dictionary (Database level):
```sql
SELECT patch_id, action, status, action_time, description
FROM dba_registry_sqlpatch
ORDER BY action_time DESC;
```
*(The final status must always be `SUCCESS`).*
