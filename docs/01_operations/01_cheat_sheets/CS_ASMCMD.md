# Cheat Sheet ASMCMD

> [!NOTE]
> **DOCUMENTI CORRELATI - ALTA AFFIDABILITÀ, RAC E DATA GUARD (SCEGLI QUELLO PIÙ ADATTO):**
> - **Cheat Sheet Operativi (Pronto Intervento)**:
>   - **ASMCMD (questa scheda)**: [CS_ASMCMD.md](./CS_ASMCMD.md) (gestione storage ASM).
>   - **SRVCTL & CRSCTL**: [CS_SRVCTL_CRSCTL.md](./CS_SRVCTL_CRSCTL.md) (gestione risorse cluster RAC e Grid).
>   - **DGMGRL (Broker)**: [CS_DGMGRL.md](./CS_DGMGRL.md) (lag, switchover rapido, comandi broker).
>   - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](./CS_MASTER_DBA.md) (tutti i comandi consolidati).
> - **Procedure di Produzione (Non-CDB)**:
>   - **Single Node Data Guard**: [GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md) (architettura a singolo nodo primario e standby).
>   - **RAC Data Guard**: [GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md) (architettura multi-nodo primario e standby).
> - **Guide di Laboratorio (RAC 19c Multi-Tenant/CDB)**:
>   - **Preparazione e Creazione Standby (Fase 3)**: [GUIDA_FASE3_RAC_STANDBY.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE3_RAC_STANDBY.md) (RMAN duplicate active database).
>   - **Configurazione Broker DGMGRL (Fase 4)**: [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md) (creazione e ottimizzazione broker).
>   - **Manuale Switchover Completo**: [GUIDA_SWITCHOVER_COMPLETO.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_SWITCHOVER_COMPLETO.md) (passaggi sicuri di switchover).
>   - **Manuale Failover & Reinstate**: [GUIDA_FAILOVER_E_REINSTATE.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_FAILOVER_E_REINSTATE.md) (gestione dei disastri e ripristino).

## Obiettivo

Usare `asmcmd` per leggere, verificare e gestire file ASM senza confondere datafile, redo, archivelog, backup piece e password file.

## Avvio

```bash
export ORACLE_SID=+ASM1
export ORACLE_HOME=<GRID_HOME>
asmcmd
```

Non interattivo:

```bash
asmcmd lsdg
asmcmd ls +DATA
asmcmd du +DATA/<DB_UNIQUE_NAME>
```

Help:

```bash
asmcmd help
asmcmd help lsdg
asmcmd help pwcopy
```

## Comandi read-only sicuri

```bash
lsdg
lsct
ls +DATA
ls +FRA
pwd
cd +DATA/<DB_UNIQUE_NAME>
du +DATA/<DB_UNIQUE_NAME>
find +DATA <pattern>
lsattr -G DATA
lsof
```

Esempi:

```bash
asmcmd lsdg
asmcmd ls +DATA/SOLE/DATAFILE
asmcmd du +FRA/SOLE/ARCHIVELOG
asmcmd find +DATA spfile*
```

## Capire cosa stai guardando

| Path ASM | Tipo file |
|---|---|
| `+DATA/DB/DATAFILE` | datafile |
| `+DATA/DB/TEMPFILE` | tempfile |
| `+DATA/DB/ONLINELOG` | redo online |
| `+DATA/DB/CONTROLFILE` | controlfile |
| `+FRA/DB/ARCHIVELOG` | archivelog |
| `+FRA/DB/BACKUPSET` | backup piece RMAN |
| `+DATA/DB/PASSWORD` | password file |
| `+DATA/DB/PARAMETERFILE` | spfile |

## Copia file ASM

ASM verso filesystem:

```bash
asmcmd cp +DATA/SOLE/PARAMETERFILE/spfile.123.456 /tmp/spfileSOLE.ora
```

Filesystem verso ASM:

```bash
asmcmd cp /tmp/orapwSOLE +DATA/SOLE/PASSWORD/orapwsole
```

ASM verso ASM:

```bash
asmcmd cp +DATA/SOLE/PASSWORD/orapwsole +DATA/M24/PASSWORD/orapwm24
```

## Password file ASM

Comandi utili:

```bash
asmcmd pwget --dbuniquename SOLE
asmcmd pwcopy +DATA/SOLE/PASSWORD/orapwsole +DATA/M24/PASSWORD/orapwm24
asmcmd pwset --dbuniquename M24 +DATA/M24/PASSWORD/orapwm24
```

Validazione:

```bash
srvctl config database -d SOLE | grep -i password
srvctl config database -d M24 | grep -i password
```

## Diskgroup e rebalance

Read-only in SQL:

```sql
select name, state, type, total_mb, free_mb, required_mirror_free_mb, usable_file_mb
from v$asm_diskgroup
order by name;

select group_number, disk_number, name, path, header_status, mode_status, state
from v$asm_disk
order by group_number, disk_number;

select group_number, operation, state, power, sofar, est_work, est_minutes
from v$asm_operation;
```

Operazioni impattanti:

```sql
alter diskgroup DATA rebalance power 4;
alter diskgroup DATA check all norepair;
```

Non eseguire add/drop disk senza procedura storage approvata.

## File da non cancellare a mano

Non usare `rm` in ASMCMD su:

- datafile;
- controlfile;
- online redo;
- standby redo;
- archivelog necessari a RMAN/Data Guard/GoldenGate;
- backup piece dentro retention;
- broker files;
- password file o spfile.

Prima di cancellare:

```bash
asmcmd ls -l <path>
```

e verifica con SQL/RMAN:

```rman
list archivelog all;
crosscheck archivelog all;
report obsolete;
```

## Diagnosi spazio ASM

```bash
asmcmd lsdg
asmcmd du +DATA
asmcmd du +FRA
asmcmd ls +FRA/<DB_UNIQUE_NAME>/ARCHIVELOG
```

Confronto DB/FRA:

```sql
select name, space_limit/1024/1024/1024 limit_gb,
       space_used/1024/1024/1024 used_gb,
       space_reclaimable/1024/1024/1024 reclaimable_gb
from v$recovery_file_dest;
```

## Runbook collegati

- [25 ASM Storage Incidenti](../02_runbooks_incidenti/25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md)
- [06 Tablespace Pieno](../02_runbooks_incidenti/06_TABLESPACE_PIENO.md)
- [17 Purge Log Oracle](../02_runbooks_incidenti/17_PURGE_LOG_ORACLE.md)
- [22 RMAN + Data Guard Recovery/DR](../02_runbooks_incidenti/22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md)
