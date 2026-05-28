# Cheat Sheet OPatch & Datapatch — Enterprise Completo 🩹

> [!NOTE]
> **DOCUMENTI CORRELATI:**
> - **Guida Patching RAC + DG**: [GUIDA_PATCHING_RAC.md](../../02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md)
> - **Runbook Patching**: [RUNBOOK_29_PATCHING_ORACLE_RAC_DATAGUARD.md](../02_runbooks_incidenti/RUNBOOK_29_PATCHING_ORACLE_RAC_DATAGUARD.md)
> - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](./CS_MASTER_DBA.md)

---

## 1. OPatch — Gestione Patch

### 1.1 Informazioni Base
```bash
# Versione OPatch
$ORACLE_HOME/OPatch/opatch version

# Inventario patch applicati
$ORACLE_HOME/OPatch/opatch lsinventory
$ORACLE_HOME/OPatch/opatch lsinventory -detail

# Inventario in formato leggibile (solo patch ID)
$ORACLE_HOME/OPatch/opatch lspatches

# Verificare un patch specifico
$ORACLE_HOME/OPatch/opatch lsinventory | grep 35642822

# Inventario locale Oracle (oraInst.loc)
cat /etc/oraInst.loc
```

### 1.2 Aggiornare OPatch (SEMPRE prima di applicare patch!)
```bash
# Rimuovere il vecchio OPatch
mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bak

# Estrarre il nuovo (scaricato da MOS Patch 6880880)
unzip -d $ORACLE_HOME p6880880_190000_Linux-x86-64.zip

# Verificare
$ORACLE_HOME/OPatch/opatch version
# Deve essere >= 12.2.0.1.42 per 19c RU recenti
```

### 1.3 Prerequisite Check (SEMPRE prima dell'apply)
```bash
# Conflict detection
$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -ph ./35642822

# System space check
$ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -ph ./35642822

# Check completo
$ORACLE_HOME/OPatch/opatch prereq CheckApplicable -ph ./35642822
```

### 1.4 Applicare Patch (One-off)
```bash
# Single Instance (DB ferma!)
cd /stage/patches/35642822
$ORACLE_HOME/OPatch/opatch apply

# Con -silent (non interattivo)
$ORACLE_HOME/OPatch/opatch apply -silent

# Con force (se ci sono conflitti gestiti)
$ORACLE_HOME/OPatch/opatch apply -force
```

### 1.5 Rollback Patch
```bash
# Rollback di un patch specifico
$ORACLE_HOME/OPatch/opatch rollback -id 35642822

# Rollback silenzioso
$ORACLE_HOME/OPatch/opatch rollback -id 35642822 -silent
```

---

## 2. OPatchAuto — RAC e Grid Infrastructure

### 2.1 Combo Patch (Release Update) su RAC
```bash
# DEVE essere eseguito come ROOT!
# Applica automaticamente alla Grid Home e alla DB Home

# Analyze (dry-run)
opatchauto apply /stage/patches/35940989 -analyze

# Apply
opatchauto apply /stage/patches/35940989

# Con logging verboso
opatchauto apply /stage/patches/35940989 -log /tmp/opatchauto.log

# Solo Grid Home
opatchauto apply /stage/patches/35940989 -oh $GRID_HOME

# Solo DB Home
opatchauto apply /stage/patches/35940989 -oh $ORACLE_HOME
```

### 2.2 Rollback OPatchAuto
```bash
# Rollback (come root)
opatchauto rollback /stage/patches/35940989
opatchauto rollback /stage/patches/35940989 -oh $ORACLE_HOME
```

### 2.3 Resume (dopo un'interruzione)
```bash
# Se opatchauto viene interrotto, resumere
opatchauto resume
```

---

## 3. Datapatch — Post-Patch SQL

### 3.1 Applicare Datapatch (FONDAMENTALE dopo ogni RU!)
```bash
# Come utente oracle, DB aperta
$ORACLE_HOME/OPatch/datapatch -verbose

# Per una PDB specifica (Multitenant)
$ORACLE_HOME/OPatch/datapatch -verbose -pdbs PDB1

# Tutte le PDB
$ORACLE_HOME/OPatch/datapatch -verbose -pdbs ALL
```

### 3.2 Verificare lo stato di Datapatch
```sql
-- Verificare se datapatch è stato eseguito
SELECT patch_id, patch_uid, version, action, status, description
FROM DBA_REGISTRY_SQLPATCH
ORDER BY action_time DESC;

-- Status deve essere: SUCCESS
-- Se APPLYING o WITH ERRORS: rieseguire datapatch

-- In CDB: verificare per ogni PDB
ALTER SESSION SET CONTAINER = PDB1;
SELECT patch_id, status, description FROM DBA_REGISTRY_SQLPATCH;
```

### 3.3 Rollback Datapatch
```bash
# Rollback SQL di un patch specifico
$ORACLE_HOME/OPatch/datapatch -rollback_id 35642822 -verbose
```

---

## 4. Workflow Completo di Patching (Single Instance)

```text
Step 1:  Backup DB + controlfile + SPFILE
Step 2:  Aggiornare OPatch (p6880880)
Step 3:  Estrarre il patch nella staging area
Step 4:  opatch prereq CheckConflictAgainstOHWithDetail
Step 5:  Fermare il database e il listener
Step 6:  opatch apply (dalla directory del patch)
Step 7:  Start database e listener
Step 8:  datapatch -verbose
Step 9:  Verificare: opatch lspatches + DBA_REGISTRY_SQLPATCH
Step 10: Compilare oggetti invalidi: @?/rdbms/admin/utlrp.sql
```

### Compilazione Post-Patch
```sql
-- Compilare tutti gli oggetti invalidi
@?/rdbms/admin/utlrp.sql

-- Verificare oggetti invalidi residui
SELECT owner, object_type, object_name, status
FROM DBA_OBJECTS
WHERE status = 'INVALID'
ORDER BY owner, object_type;

-- Conteggio
SELECT COUNT(*) FROM DBA_OBJECTS WHERE status = 'INVALID';

-- Compilare un singolo oggetto
ALTER PACKAGE schema.pkg_name COMPILE;
ALTER PACKAGE schema.pkg_name COMPILE BODY;
```

---

## 5. Workflow RAC + Data Guard (Standby-First)

```text
Step 1:  Backup su entrambi i siti (primary + standby)
Step 2:  Fermare apply sullo standby (MRP)
Step 3:  Aggiornare OPatch su TUTTI i nodi
Step 4:  opatchauto apply sullo STANDBY (come root, nodo per nodo)
Step 5:  Riavviare standby, verificare apply
Step 6:  Switchover (standby diventa primary)
Step 7:  opatchauto apply sul VECCHIO primary (ora standby)
Step 8:  Riavviare, verificare sincronizzazione
Step 9:  datapatch -verbose sul nuovo primary
Step 10: (Opzionale) Switchback
```

---

## 6. OJVM Patch (Java in DB)

```bash
# Applicare il patch OJVM (separato dalla RU)
cd /stage/patches/35926646   # OJVM patch ID
$ORACLE_HOME/OPatch/opatch apply

# Datapatch è obbligatorio per OJVM
$ORACLE_HOME/OPatch/datapatch -verbose

# Verificare
SELECT comp_name, version, status FROM DBA_REGISTRY WHERE comp_name LIKE '%JAVA%';
```

---

## 7. Troubleshooting

| Problema | Causa | Fix |
|---|---|---|
| `OPatch failed: prerequisite check` | Conflitto con patch esistente | `opatch lspatches`, rollback conflitto |
| `Inventory corrupted` | oraInventory danneggiato | `opatch util renew -oh $ORACLE_HOME` |
| `datapatch: ORA-20000` | Eseguito con utente sbagliato | Eseguire come SYS con SYSDBA |
| `opatchauto: permission denied` | Non eseguito come root | `sudo opatchauto apply ...` |
| Oggetti INVALID dopo patch | Normale, serve ricompilazione | `@?/rdbms/admin/utlrp.sql` |
| `OPatch version too old` | OPatch non aggiornato | Scaricare p6880880 da MOS |
| `datapatch: PDB not open` | PDB chiusa durante datapatch | Aprire tutte le PDB prima |

---

## 8. Quick Reference

```text
+---------------------------+----------------------------------------------+
| OPERAZIONE                | COMANDO                                      |
+---------------------------+----------------------------------------------+
| Versione OPatch           | opatch version                               |
| Patch installati          | opatch lspatches                             |
| Inventario completo       | opatch lsinventory                           |
| Prerequisite check        | opatch prereq CheckConflictAgainstOH...      |
| Apply patch               | opatch apply                                 |
| Rollback patch            | opatch rollback -id XXXXXX                   |
| RAC patch (root)          | opatchauto apply /stage/patch_dir            |
| Datapatch post-apply      | datapatch -verbose                           |
| Verifica SQL patch        | SELECT * FROM DBA_REGISTRY_SQLPATCH          |
| Ricompila invalidi        | @?/rdbms/admin/utlrp.sql                     |
| Aggiorna OPatch           | unzip p6880880 in $ORACLE_HOME               |
+---------------------------+----------------------------------------------+
```
