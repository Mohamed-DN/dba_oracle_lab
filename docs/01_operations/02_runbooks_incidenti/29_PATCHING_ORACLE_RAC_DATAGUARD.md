# 29 - Patching Oracle RAC e Data Guard

## Casi piu frequenti

- Applicazione Release Update trimestrale.
- Aggiornamento OPatch.
- Esecuzione `datapatch`.
- Patching con Data Guard e switchover.
- Rollback patch.
- Verifica post-patch `dba_registry_sqlpatch`.

## Regola operativa

Il patching non inizia con `opatchauto apply`. Inizia con inventory, backup home, backup database, Data Guard readiness, restore point dove applicabile e piano di rollback.

## Precheck

```bash
echo $ORACLE_HOME
echo $GRID_HOME
$ORACLE_HOME/OPatch/opatch version
$ORACLE_HOME/OPatch/opatch lsinventory
$GRID_HOME/OPatch/opatch version
$GRID_HOME/OPatch/opatch lsinventory
df -h
opatchauto -version
```

Database:

```sql
SELECT name, open_mode, database_role, flashback_on FROM v$database;

SELECT patch_id, patch_type, action, status, action_time, description
FROM dba_registry_sqlpatch
ORDER BY action_time DESC;

SELECT comp_id, comp_name, status
FROM dba_registry
ORDER BY comp_id;
```

Data Guard:

```text
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE 'SOLE';
DGMGRL> VALIDATE DATABASE 'M24';
```

## Backup prima del patching

Home software:

```bash
tar -czf /backup/dbhome_$(date +%Y%m%d).tgz $ORACLE_HOME
tar -czf /backup/gridhome_$(date +%Y%m%d).tgz $GRID_HOME
```

RMAN:

```rman
BACKUP DATABASE PLUS ARCHIVELOG TAG 'PRE_PATCH';
RESTORE DATABASE VALIDATE;
```

Restore point:

```sql
CREATE RESTORE POINT rp_before_patch GUARANTEE FLASHBACK DATABASE;
```

## Strategia con Data Guard

Opzione A - rolling per sito:

1. patch standby;
2. validazione standby;
3. switchover;
4. patch vecchio primary;
5. switchback se richiesto.

Opzione B - patch in-place:

1. ferma servizi applicativi;
2. patch primary;
3. patch standby;
4. `datapatch`;
5. validazione completa.

Scegli A quando vuoi ridurre downtime applicativo, scegli B solo se finestra e rischio sono accettati.

## Applicazione RU RAC

Esempio concettuale, adattare alla patch:

```bash
unzip -q p6880880_190000_Linux-x86-64.zip -d $ORACLE_HOME/..
unzip -q p<RU>_190000_Linux-x86-64.zip -d /u01/app/patch

$GRID_HOME/OPatch/opatchauto apply /u01/app/patch/<RU_DIR>
```

DB home se separata:

```bash
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/<RU_DIR> -oh $ORACLE_HOME
```

## Datapatch

Dopo che DB e istanze sono aperte:

```bash
sqlplus / as sysdba <<EOF
SELECT name, open_mode FROM v\\$database;
EOF

$ORACLE_HOME/OPatch/datapatch -verbose
```

Validazione:

```sql
SELECT patch_id, action, status, action_time, description
FROM dba_registry_sqlpatch
ORDER BY action_time DESC;

SELECT comp_id, comp_name, status
FROM dba_registry
ORDER BY comp_id;
```

## Rollback

Rollback patch software:

```bash
$ORACLE_HOME/OPatch/opatch rollback -id <PATCH_ID>
```

Rollback SQL patch se richiesto:

```bash
$ORACLE_HOME/OPatch/datapatch -verbose
```

Flashback database e' ultima risorsa per rollback dati/dizionario secondo change approvato:

```sql
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
FLASHBACK DATABASE TO RESTORE POINT rp_before_patch;
ALTER DATABASE OPEN RESETLOGS;
```

## Pulizia

Puoi cancellare zip e directory patch estratte solo dopo validazione e se non servono al rollback operativo. Non cancellare:

```text
$ORACLE_HOME/.patch_storage
$GRID_HOME/.patch_storage
```

## Cosa non fare

- Non patchare con OPatch vecchio.
- Non saltare `datapatch`.
- Non cancellare `.patch_storage`.
- Non patchare primary e standby senza verificare broker e lag.
- Non fare switchover se `VALIDATE DATABASE` segnala errori bloccanti.

## Collegamenti

- [Guida Patching RAC](../../02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md)
- [Data Guard produzione single instance](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md)
- [Data Guard produzione RAC](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md)

## Evidence ticket

```text
Patch ID:
OPatch version:
Inventory prima:
Backup home:
Backup RMAN:
Restore point:
Strategia DG:
datapatch status:
Registry status:
Validazione applicativa:
Rollback possibile fino a:
```
