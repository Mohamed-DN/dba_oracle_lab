# Oracle DBA Tools Command Center

Questa pagina e il punto unico per scegliere il tool Oracle corretto durante attivita operative, incidenti o change.

## Regola di scelta rapida

| Devo fare | Tool principale | Guida |
|---|---|---|
| Gestire database, istanze, listener, servizi RAC | `srvctl` | [SRVCTL/CRSCTL](./CHEAT_SHEET_SRVCTL_CRSCTL.md) |
| Verificare o gestire Clusterware, CRS, OCR, voting disk | `crsctl` | [SRVCTL/CRSCTL](./CHEAT_SHEET_SRVCTL_CRSCTL.md) |
| Guardare o copiare file ASM, diskgroup, password file | `asmcmd` | [ASMCMD](./CHEAT_SHEET_ASMCMD.md) |
| Leggere alert log, incidenti, trace, IPS package | `adrci` | [ADRCI](./CHEAT_SHEET_ADRCI.md) |
| Gestire Data Guard Broker | `dgmgrl` | [DGMGRL](./CHEAT_SHEET_DGMGRL.md) |
| Backup, restore, duplicate, validate | `rman` | [RMAN Full](./RMAN_FULL_CHEATSHEET.md) |
| Listener, TNS, Easy Connect, connessioni | `lsnrctl`, `tnsping` | [LSNRCTL/Oracle Net](./CHEAT_SHEET_LSNRCTL_NET.md) |
| Patch Grid/DB home e SQL patch registry | `opatch`, `opatchauto`, `datapatch` | [OPatch/datapatch](./CHEAT_SHEET_OPATCH_DATAPATCH.md) |
| SQL amministrativo, startup/shutdown, spool | `sqlplus`, `sqlcl` | [SQLPlus/SQLcl/DBCA/NETCA](./CHEAT_SHEET_SQLPLUS_SQLCL_DBCA_NETCA.md) |
| Creare/configurare DB e listener in modo assistito/silent | `dbca`, `netca` | [SQLPlus/SQLcl/DBCA/NETCA](./CHEAT_SHEET_SQLPLUS_SQLCL_DBCA_NETCA.md) |
| Export/import logico | `expdp`, `impdp` | [Export/Import Prod-Preprod](../02_runbooks_incidenti/20_EXPORT_IMPORT_PROD_PREPROD.md) |
| Wallet/certificati | `orapki`, `mkstore` | [TCPS Wallet](../02_runbooks_incidenti/34_TCPS_WALLET_CERTIFICATI.md) |

## Utente corretto

| Tool | Utente tipico | Motivo |
|---|---|---|
| `srvctl database/service` | owner DB, spesso `oracle` | gestisce risorse DB e servizi del DB home |
| `srvctl listener/asm`, `crsctl`, `ocrcheck` | owner Grid, spesso `grid` | gestisce Grid Infrastructure |
| `asmcmd` | `grid` o `oracle` secondo ownership e operazione | accesso ASM e file DB |
| `rman` | `oracle` | backup/recovery del database |
| `dgmgrl` | `oracle` o account con `SYSDG/SYSDBA` | broker Data Guard |
| `adrci` | `oracle` o `grid` | diagnostica DB/Grid/ASM |
| `opatchauto` | spesso `root` per Grid, `oracle/grid` per home specifica | patching software |
| `datapatch` | owner DB home | applica SQL patch dentro DB |

## Sequenza standard prima di toccare produzione

```bash
date
hostname -f
id
echo $ORACLE_HOME
echo $ORACLE_SID
echo $TNS_ADMIN
```

Database:

```sql
select name, open_mode, database_role from v$database;
select instance_name, status, host_name, startup_time from gv$instance;
```

RAC/Grid:

```bash
crsctl check crs
crsctl stat res -t
srvctl status database -d <DB_UNIQUE_NAME> -v
srvctl status service -d <DB_UNIQUE_NAME>
```

## Sequenza standard dopo il fix

```bash
crsctl stat res -t
srvctl status database -d <DB_UNIQUE_NAME> -v
srvctl status service -d <DB_UNIQUE_NAME>
lsnrctl services
```

```sql
select name, open_mode, database_role from v$database;
select inst_id, instance_name, status from gv$instance order by inst_id;
```

## Dove sono le guide grandi

| Area | Guida completa |
|---|---|
| RMAN enterprise | [GUIDA_RMAN_COMANDI_ENTERPRISE](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMANDI_ENTERPRISE.md) |
| RMAN architettura e recovery | [GUIDA_RMAN_COMPLETA_19C](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md) |
| ADRCI enterprise | [GUIDA_ADRCI_TRACE_ENTERPRISE](../../02_core_dba/03_performance_and_diagnostics/GUIDA_ADRCI_TRACE_ENTERPRISE.md) |
| Data Guard Broker | [GUIDA_FASE4_DATAGUARD_DGMGRL](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md) |
| Listener/services | [GUIDA_LISTENER_SERVICES_DBA](../../02_core_dba/01_administration_and_security/GUIDA_LISTENER_SERVICES_DBA.md) |
| Patching RAC | [GUIDA_PATCHING_RAC](../../02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md) |

## Riferimenti ufficiali Oracle 19c

- SRVCTL Command Reference: <https://docs.oracle.com/en/database/oracle/oracle-database/19/cwadd/server-control-command-reference.html>
- CRSCTL Utility Reference: <https://docs.oracle.com/en/database/oracle/oracle-database/19/cwadd/oracle-clusterware-control-crsctl-utility-reference.html>
- ASMCMD: <https://docs.oracle.com/en/database/oracle/oracle-database/19/ostmg/about-asmcmd.html>
- ADRCI: <https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-adr-command-interpreter-adrci.html>
- DGMGRL: <https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/oracle-data-guard-broker-commands.html>
- RMAN: <https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/getting-started-rman.html>
- RMAN command reference: <https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/about-rman-commands.html>
- SQL*Plus quick reference: <https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpqr/toc.htm>
- Oracle patch maintenance: <https://docs.oracle.com/en/database/oracle/oracle-database/19/dbptc/index.html>
