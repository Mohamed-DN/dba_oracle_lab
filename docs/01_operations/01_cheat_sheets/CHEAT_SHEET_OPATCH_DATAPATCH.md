# Cheat Sheet OPatch, OPatchAuto e Datapatch

> [!NOTE]
> **DOCUMENTI DI PATCHING CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Cheat Sheet Rapido (questa scheda)**: [CHEAT_SHEET_OPATCH_DATAPATCH.md](./CHEAT_SHEET_OPATCH_DATAPATCH.md) (comandi rapidi di inventario, prereq e datapatch).
> - **Master DBA Cheat Sheet**: [CHEAT_SHEET_MASTER_DBA.md](./CHEAT_SHEET_MASTER_DBA.md) (comandi consolidati, include sezione patching).
> - **Procedure di Produzione (RAC + DG - Fase 16)**: [GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md#fase-16---patching-in-ambiente-rac-dataguard-standby-first) (manuale completo di patching in produzione rolling Standby-First).
> - **Guida al Patching Post-Installazione**: [GUIDA_PATCHING_RAC.md](../../02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md) (gestione RU trimestrali e Combo Patch).
> - **Guida all'Upgrade delle RU**: [GUIDA_UPGRADE_RU_RAC.md](../../02_core_dba/05_patching_and_upgrades/GUIDA_UPGRADE_RU_RAC.md) (upgrade rolling di RU con opatchauto).

## Differenza strumenti

| Tool | Cosa fa |
|---|---|
| `opatch` | Applica patch a una Oracle Home specifica |
| `opatchauto` | Orchestra patch Grid/RAC e piu home, spesso con step root |
| `datapatch` | Applica componenti SQL della patch dentro i database |
| `dba_registry_sqlpatch` | Verifica cosa e stato applicato lato SQL |

## Precheck minimo

```bash
echo $ORACLE_HOME
echo $GRID_HOME
$ORACLE_HOME/OPatch/opatch version
$ORACLE_HOME/OPatch/opatch lsinventory
$GRID_HOME/OPatch/opatch version
$GRID_HOME/OPatch/opatch lsinventory
```

Spazio:

```bash
df -h
du -sh $ORACLE_HOME $GRID_HOME 2>/dev/null
```

Cluster:

```bash
crsctl check crs
crsctl stat res -t
srvctl status database -d <DB_UNIQUE_NAME> -v
```

Database:

```sql
select name, open_mode, database_role from v$database;
select patch_id, action, status, action_time, description
from dba_registry_sqlpatch
order by action_time desc;
```

## Analisi patch prima di applicare

```bash
cd /u01/app/patch/<PATCH_DIR>
$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -ph ./
$ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -ph ./
```

Inventory:

```bash
$ORACLE_HOME/OPatch/opatch lsinventory -detail
$ORACLE_HOME/OPatch/opatch lsinventory -bugs_fixed
```

## Backup home

```bash
tar -czf /backup/dbhome_$(date +%Y%m%d_%H%M).tgz $ORACLE_HOME
tar -czf /backup/gridhome_$(date +%Y%m%d_%H%M).tgz $GRID_HOME
```

Backup database:

```rman
backup database plus archivelog tag 'PRE_PATCH';
restore database validate;
```

## Applicare patch DB home single instance

Stop DB/listener secondo change:

```bash
sqlplus / as sysdba
shutdown immediate
exit
lsnrctl stop
```

Patch:

```bash
cd /u01/app/patch/<PATCH_DIR>
$ORACLE_HOME/OPatch/opatch apply
```

Start e datapatch:

```bash
lsnrctl start
sqlplus / as sysdba
startup
exit
$ORACLE_HOME/OPatch/datapatch -verbose
```

## Applicare patch RAC/Grid con opatchauto

Precheck:

```bash
opatchauto apply /u01/app/patch/<PATCH_DIR> -analyze
```

Applicazione:

```bash
opatchauto apply /u01/app/patch/<PATCH_DIR>
```

Se patch solo DB home:

```bash
opatchauto apply /u01/app/patch/<PATCH_DIR> -oh $ORACLE_HOME
```

## Datapatch

Eseguire come owner DB home, con DB aperto quando richiesto.

```bash
$ORACLE_HOME/OPatch/datapatch -verbose
```

Verifica:

```sql
select patch_id, patch_type, action, status, action_time, description
from dba_registry_sqlpatch
order by action_time desc;
```

Invalidi:

```sql
select owner, object_type, object_name
from dba_objects
where status <> 'VALID'
order by owner, object_type, object_name;
```

## Rollback

Software:

```bash
$ORACLE_HOME/OPatch/opatch rollback -id <PATCH_ID>
```

SQL:

```bash
$ORACLE_HOME/OPatch/datapatch -verbose
```

RAC/Grid rollback segue readme patch e deve essere testato in preprod.

## Errori comuni

| Sintomo | Controllo |
|---|---|
| `opatch` vecchio | aggiornare OPatch con patch 6880880 secondo policy |
| conflict prereq | leggere `CheckConflictAgainstOHWithDetail` |
| datapatch fallisce | controllare DB aperto, registry, log in `$ORACLE_BASE/cfgtoollogs/sqlpatch` |
| risorsa non riparte | `crsctl stat res -t`, alert CRS/DB con ADRCI |
| standby non allineato | DGMGRL validate e `dba_registry_sqlpatch` su entrambi |

## Runbook collegati

- [29 Patching Oracle RAC/Data Guard](../02_runbooks_incidenti/29_PATCHING_ORACLE_RAC_DATAGUARD.md)
- [GUIDA_PATCHING_RAC](../../02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md)
- [GUIDA_UPGRADE_RU_RAC](../../02_core_dba/05_patching_and_upgrades/GUIDA_UPGRADE_RU_RAC.md)
