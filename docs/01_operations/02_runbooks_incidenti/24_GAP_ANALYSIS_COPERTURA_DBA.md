# 24 - Gap Analysis Copertura Runbook DBA Oracle

## Casi piu frequenti da aprire prima
- Se devi capire cosa studiare dopo: parti da [Priorita consigliata](#priorita-consigliata).
- Se vuoi capire cosa manca per produzione bancaria: vai a [Gap enterprise ancora aperti](#gap-enterprise-ancora-aperti).
- Se vuoi trasformare il repo in runbook operativo: vai a [Backlog documentale suggerito](#backlog-documentale-suggerito).
- Se vuoi evitare duplicazioni: vai a [Cosa e gia coperto bene](#cosa-e-gia-coperto-bene).

## Indice rapido
- [Obiettivo](#obiettivo)
- [Cosa e gia coperto bene](#cosa-e-gia-coperto-bene)
- [Gap enterprise ancora aperti](#gap-enterprise-ancora-aperti)
- [Priorita consigliata](#priorita-consigliata)
- [Backlog documentale suggerito](#backlog-documentale-suggerito)
- [Criteri di qualita per i prossimi runbook](#criteri-di-qualita-per-i-prossimi-runbook)

## Obiettivo

Questo documento non e un runbook di emergenza. E una fotografia della copertura documentale del repository per capire cosa manca rispetto a un perimetro DBA Oracle enterprise: banca, assicurazione, PA critica, telco o grande retail.

## Cosa e gia coperto bene

| Area | Stato | Documenti principali |
|---|---|---|
| Health check giornaliero | Buono | [01](./01_MORNING_HEALTH_CHECK.md) |
| Backup RMAN e diagnosi fallimenti | Molto buono | [02](./02_VERIFICA_BACKUP.md), [19](./19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md), [22](./22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) |
| Data Guard operativo e DR | Molto buono | [03](./03_CHECK_DATAGUARD.md), [22](./22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) |
| SQL tuning | Molto buono | [05](./05_QUERY_LENTA.md), [11](./11_REVIEW_AWR.md), [18](./18_GESTIONE_STATISTICHE_OPTIMIZER.md), [23](./23_SQL_TUNING_CASI_ENTERPRISE.md) |
| Spazio, TEMP, FRA, log | Buono | [06](./06_TABLESPACE_PIENO.md), [16](./16_RESIZE_TEMP.md), [17](./17_PURGE_LOG_ORACLE.md) |
| Data Pump refresh | Buono | [13](./13_REFRESH_SCHEMA_TEST.md), [20](./20_EXPORT_IMPORT_PROD_PREPROD.md) |
| DB link e 2PC | Buono | [21](./21_GESTIONE_DB_LINK.md) |
| Utenti e privilegi | Buono | [09](./09_GESTIONE_UTENTI.md) |
| RAC start/stop | Base solida | [10](./10_START_STOP_RAC.md) |

## Gap enterprise ancora aperti

| Gap | Perche conta | Documento suggerito |
|---|---|---|
| Incidenti ASM e storage | In RAC bancario molti incidenti partono da ASM diskgroup, path multipath, latency o rebalance | `25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md` |
| Listener, SCAN, servizi e FAN/ONS | Molti outage applicativi sono service/listener, non database down | `26_LISTENER_SCAN_SERVICES_RAC.md` |
| TDE wallet/keystore | In ambienti regolati TDE e wallet sono critici per startup, refresh, clone, restore | `27_TDE_WALLET_KEYSTORE_RUNBOOK.md` |
| Patching RU/RUR e rollback | Serve procedura rolling/non-rolling, precheck opatch, datapatch, rollback | `28_PATCHING_ORACLE_RAC_DATAGUARD.md` |
| Multitenant CDB/PDB operations | Open/close PDB, clone, unplug/plug, refreshable PDB, restore PDB | `29_MULTITENANT_PDB_OPERATIONS.md` |
| GoldenGate incidenti | Lag, abend, trail pieno, extract fermo, replicat conflict | `30_GOLDENGATE_INCIDENT_RUNBOOK.md` |
| OEM/EM alert handling | In produzione gli incidenti arrivano da EM, non da query manuali | `31_ENTERPRISE_MANAGER_ALERT_RUNBOOK.md` |
| Audit, compliance e evidence | Banca richiede tracciabilita: chi ha fatto cosa, quando, con quale ticket | `32_AUDIT_COMPLIANCE_EVIDENCE.md` |
| Encryption network e certificates | TCPS, wallet client/server, rotazione certificati | `33_TCPS_WALLET_CERTIFICATI.md` |
| Capacity forecasting avanzato | Trend AWR/DBA_HIST, forecast ASM/FRA/TEMP/UNDO | `34_CAPACITY_FORECAST_ENTERPRISE.md` |

## Priorita consigliata

1. ASM/storage incidenti: impatta RAC, RMAN, FRA, Data Guard e performance.
2. Listener/SCAN/services: molto frequente nei ticket applicativi.
3. TDE wallet/keystore: essenziale per ambienti bancari e restore cifrati.
4. Patching RAC/Data Guard: necessario per parlare di produzione vera.
5. GoldenGate incidenti: se il percorso professionale punta a replication expert.
6. Multitenant PDB operations: 19c in produzione e quasi sempre CDB/PDB.
7. OEM/EM alert handling: chiude il ciclo monitoraggio -> runbook -> evidence.

## Backlog documentale suggerito

### 25 - ASM e storage

Contenuti minimi:

- `asmcmd lsdg`, `v$asm_diskgroup`, `v$asm_disk`, `v$asm_operation`.
- Diskgroup full, rebalance lento, disk offline, voting disk/OCR issue.
- Differenza tra capacity usable, required mirror free e free MB.
- Check multipath e latency OS.
- Regole: mai cancellare file ASM a mano se non sai cosa rappresentano.

### 26 - Listener, SCAN e servizi RAC

Contenuti minimi:

- `srvctl status listener`, `srvctl status scan_listener`, `lsnrctl status`.
- Service non registrato: `LOCAL_LISTENER`, `REMOTE_LISTENER`, PMON/LREG.
- Failover applicativo, service relocation, preferred/available instances.
- Test Easy Connect e TNS alias.
- Diagnosi `ORA-12514`, `ORA-12541`, `ORA-12154`.

### 27 - TDE wallet/keystore

Contenuti minimi:

- Wallet open/closed dopo restart.
- Backup keystore prima di refresh o restore.
- `ADMINISTER KEY MANAGEMENT`.
- Auto-login wallet: quando usarlo e rischi.
- Restore RMAN con backup cifrati e wallet mancante.

### 28 - Patching RAC/Data Guard

Contenuti minimi:

- Precheck `opatch lsinventory`, `opatchauto`, `datapatch -verbose`.
- Rolling patch Grid/DB home.
- Data Guard switchover-first patching.
- Rollback plan e validazione SQL registry.
- Evidence per change management.

### 30 - GoldenGate incidenti

Contenuti minimi:

- `INFO ALL`, lag extract/replicat, abend, report/discard.
- Trail pieno o checkpoint bloccato.
- Archive retention quando extract e fermo.
- Conflict detection/resolution.
- Microservices: Admin Server, Distribution Server, Receiver Server, REST API.

## Criteri di qualita per i prossimi runbook

Ogni nuovo runbook dovrebbe avere sempre:

- casi frequenti in alto;
- indice rapido;
- precheck;
- procedura con comandi;
- validazione finale;
- rollback o piano di rientro;
- rischi enterprise;
- riferimenti ufficiali;
- template ticket/evidence se l'operazione e critica.
