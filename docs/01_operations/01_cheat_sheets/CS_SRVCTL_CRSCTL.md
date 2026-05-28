# Cheat Sheet SRVCTL e CRSCTL

> [!NOTE]
> **DOCUMENTI CORRELATI - ALTA AFFIDABILITÀ, RAC E DATA GUARD (SCEGLI QUELLO PIÙ ADATTO):**
> - **Cheat Sheet Operativi (Pronto Intervento)**:
>   - **SRVCTL & CRSCTL (questa scheda)**: [CS_SRVCTL_CRSCTL.md](./CS_SRVCTL_CRSCTL.md) (gestione risorse cluster RAC e Grid).
>   - **DGMGRL (Broker)**: [CS_DGMGRL.md](./CS_DGMGRL.md) (lag, switchover rapido, comandi broker).
>   - **ASMCMD**: [CS_ASMCMD.md](./CS_ASMCMD.md) (gestione storage ASM).
>   - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](./CS_MASTER_DBA.md) (tutti i comandi consolidati).
> - **Procedure di Produzione (Non-CDB)**:
>   - **Single Node Data Guard**: [GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md) (architettura a singolo nodo primario e standby).
>   - **RAC Data Guard**: [GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md) (architettura multi-nodo primario e standby).
> - **Guide di Laboratorio (RAC 19c Multi-Tenant/CDB)**:
>   - **Preparazione e Creazione Standby (Fase 3)**: [GUIDA_FASE3_RAC_STANDBY.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE3_RAC_STANDBY.md) (RMAN duplicate active database).
>   - **Configurazione Broker DGMGRL (Fase 4)**: [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md) (creazione e ottimizzazione broker).
>   - **Manuale Switchover Completo**: [GUIDA_SWITCHOVER_COMPLETO.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_SWITCHOVER_COMPLETO.md) (passaggi sicuri di switchover).
>   - **Manuale Failover & Reinstate**: [GUIDA_FAILOVER_E_REINSTATE.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_FAILOVER_E_REINSTATE.md) (gestione dei disastri e ripristino).

## Differenza fondamentale

| Tool | Uso corretto |
|---|---|
| `srvctl` | Gestire risorse Oracle: database, istanze, servizi, listener, SCAN, ASM, diskgroup |
| `crsctl` | Verificare e gestire Oracle Clusterware, CRS, CSS, EVM, OCR, voting disk, risorse cluster |

Regola di produzione: per risorse Oracle con nome `ora.*`, usa `srvctl` quando esiste un comando equivalente. Usa `crsctl` per stato cluster e diagnostica Clusterware.

## Comandi help e versione

```bash
srvctl -version
srvctl -help
srvctl status database -help
srvctl config service -help

crsctl -help
crsctl query crs activeversion
crsctl query crs softwareversion
```

## Health check RAC/Grid

```bash
crsctl check crs
crsctl check cluster -all
crsctl stat res -t
crsctl stat res -t -init
olsnodes -n -s -t
```

OCR e voting disk:

```bash
ocrcheck
ocrconfig -showbackup
crsctl query css votedisk
```

Network cluster:

```bash
oifcfg getif
srvctl config network
srvctl config scan
srvctl status scan
srvctl status scan_listener
```

## Database RAC con SRVCTL

Configurazione:

```bash
srvctl config database
srvctl config database -d <DB_UNIQUE_NAME>
srvctl config database -d <DB_UNIQUE_NAME> -a
```

Stato:

```bash
srvctl status database -d <DB_UNIQUE_NAME>
srvctl status database -d <DB_UNIQUE_NAME> -v
srvctl status instance -d <DB_UNIQUE_NAME> -i <INSTANCE_NAME>
```

Start/stop:

```bash
srvctl start database -d <DB_UNIQUE_NAME>
srvctl stop database -d <DB_UNIQUE_NAME>
srvctl stop database -d <DB_UNIQUE_NAME> -o immediate
srvctl stop database -d <DB_UNIQUE_NAME> -o transactional
```

Istanza singola:

```bash
srvctl start instance -d <DB_UNIQUE_NAME> -i <INSTANCE_NAME>
srvctl stop instance -d <DB_UNIQUE_NAME> -i <INSTANCE_NAME> -o immediate
```

## Policy di startup

```bash
srvctl config database -d <DB_UNIQUE_NAME> | grep -i "management policy"
srvctl modify database -d <DB_UNIQUE_NAME> -policy AUTOMATIC
srvctl modify database -d <DB_UNIQUE_NAME> -policy MANUAL
```

Uso pratico:

- `AUTOMATIC`: DB parte con cluster/node.
- `MANUAL`: DB non parte automaticamente, utile per standby/test/change.

## Services RAC

Listare:

```bash
srvctl config service -d <DB_UNIQUE_NAME>
srvctl status service -d <DB_UNIQUE_NAME>
```

Creare service role-based:

```bash
srvctl add service -d <DB_UNIQUE_NAME> -s APP_RW \
  -preferred <INST1>,<INST2> \
  -role PRIMARY \
  -policy AUTOMATIC
```

Service per standby read only:

```bash
srvctl add service -d <DB_UNIQUE_NAME> -s APP_RO \
  -preferred <INST1>,<INST2> \
  -role PHYSICAL_STANDBY \
  -policy AUTOMATIC
```

Start/stop/relocate:

```bash
srvctl start service -d <DB_UNIQUE_NAME> -s APP_RW
srvctl stop service -d <DB_UNIQUE_NAME> -s APP_RW
srvctl relocate service -d <DB_UNIQUE_NAME> -s APP_RW -oldinst <INST1> -newinst <INST2>
```

Validazione SQL:

```sql
select name, network_name, enabled from dba_services order by name;
select inst_id, name from gv$active_services order by name, inst_id;
```

## Listener e SCAN

```bash
srvctl status listener
srvctl config listener
srvctl start listener
srvctl stop listener

srvctl status scan_listener
srvctl config scan_listener
srvctl start scan_listener
srvctl stop scan_listener

lsnrctl status
lsnrctl services
```

## ASM e diskgroup con SRVCTL

```bash
srvctl status asm
srvctl config asm
srvctl status diskgroup -g DATA
srvctl start diskgroup -g DATA
srvctl stop diskgroup -g DATA
```

## Resource troubleshooting con CRSCTL

Vista sintetica:

```bash
crsctl stat res -t
```

Dettaglio risorsa:

```bash
crsctl stat res ora.<db>.db -p
crsctl stat res ora.<db>.db -f
```

Log cluster:

```bash
crsctl get log crs all
crsctl get log css all
crsctl get log evm all
```

## Stop/start cluster

Singolo nodo:

```bash
crsctl stop crs
crsctl start crs
```

Tutto il cluster, alto impatto:

```bash
crsctl stop cluster -all
crsctl start cluster -all
```

Usare solo in change approvata. Prima salvare:

```bash
crsctl stat res -t
srvctl status database -d <DB_UNIQUE_NAME> -v
srvctl status service -d <DB_UNIQUE_NAME>
```

## Comandi da evitare senza SR/change

```bash
crsctl delete resource ora.*
crsctl modify resource ora.*
crsctl stop resource ora.* -f
```

Motivo: puoi rompere configurazione Clusterware gestita da Oracle. Preferire `srvctl`.

## Runbook collegati

- [10 Start/Stop Database RAC](../02_runbooks_incidenti/RUNBOOK_10_START_STOP_RAC.md)
- [25 ASM Storage Incidenti](../02_runbooks_incidenti/RUNBOOK_25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md)
- [26 Listener, SCAN e Services RAC](../02_runbooks_incidenti/RUNBOOK_26_LISTENER_SCAN_SERVICES_RAC.md)
- [29 Patching Oracle RAC/Data Guard](../02_runbooks_incidenti/RUNBOOK_29_PATCHING_ORACLE_RAC_DATAGUARD.md)
