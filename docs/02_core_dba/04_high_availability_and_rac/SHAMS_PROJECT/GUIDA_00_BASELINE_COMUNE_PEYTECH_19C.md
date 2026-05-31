# SHAMS PROJECT: Baseline Comune PEYTECH Oracle 19c

## Obiettivo operativo

Definire il contratto comune per i blueprint SHAMS PROJECT prima di scegliere
single instance o RAC, CDB o non-CDB. Questa guida centralizza i requisiti che
non devono essere duplicati nelle procedure specifiche.

## Fonti Oracle ufficiali

- [Creazione standby fisico](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/creating-oracle-data-guard-physical-standby.html)
- [Standby fisico con RMAN](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/creating-data-guard-standby-database-using-RMAN.html)
- [Redo Transport Services](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-transport-services.html)
- [Protection Modes](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-protection-modes.html)
- [RMAN con Data Guard](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/using-RMAN-in-oracle-data-guard-configurations.html)
- [Creazione database con DBCA](https://docs.oracle.com/en/database/oracle/oracle-database/19/admqs/installing-oracle-database-creating-database.html)
- [Creazione RAC con DBCA](https://docs.oracle.com/en/database/oracle/oracle-database/19/racpd/create-oracle-rac-database-dbca.html)
- [CDB physical standby e PDB](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/using-data-guard-with-a-cdb.html)
- [Observer FSFO](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/using-data-guard-broker-to-manage-switchovers-failovers.html)

## Decisione architetturale

Le quattro varianti sono alternative. Non installarle insieme usando gli stessi
nomi.

| ID | Cluster locale | Multitenant | Host guide | Note |
| --- | --- | --- | --- | --- |
| `S1` | Oracle Restart single | No | Host single | Compatibilita' legacy |
| `S2` | Oracle Restart single | Si | Host single | CDB con PDB applicativo |
| `S3` | RAC due nodi | No | Host RAC | Legacy con HA locale |
| `S4` | RAC due nodi | Si | Host RAC | Target preferito greenfield |

Oracle 19c supporta ancora non-CDB, ma l'architettura e' deprecata. Per nuovi
database preferire CDB/PDB salvo vincoli applicativi documentati.

## Naming PEYTECH

| Oggetto | Valore di esempio |
| --- | --- |
| Prefisso progetto | `M24SHAMS` |
| Ambiente | `C` |
| Sito primary | `PE` |
| Sito standby | `SE` |
| `DB_NAME` / CDB name | `M24SHAMS` |
| Primary `DB_UNIQUE_NAME` | `M24SHAMSPEC` |
| Standby `DB_UNIQUE_NAME` | `M24SHAMSSEC` |
| PDB applicativo, solo CDB | `M24SHAMSC_APP` |
| Service read-write | `M24SHAMSC_PRY` |
| Service Active Data Guard | `M24SHAMSC_RO` |
| TNS primary DG | `M24SHAMSPEC_DG` |
| TNS standby DG | `M24SHAMSSEC_DG` |
| Listener DG | `1531/TCP` |
| ASM DATA | `+M24SHAMS_DATA` |
| ASM FRA | `+M24SHAMS_FRA` |

Per RAC:

| Oggetto | Primary PE | Standby SE |
| --- | --- | --- |
| Istanza nodo 1 | `M24SHAMS1` | `M24SHAMS1` |
| Istanza nodo 2 | `M24SHAMS2` | `M24SHAMS2` |
| SCAN | `<PRIMARY_SCAN>` | `<STANDBY_SCAN>` |

I SID uguali tra siti sono ammessi perche' i cluster sono distinti. Se lo
standard locale richiede SID site-specific, registralo nell'inventario prima
della creazione.

## Scheda inventario

| Campo | Primary PE | Standby SE |
| --- | --- | --- |
| FQDN host o nodi RAC | `<PRIMARY_HOSTS>` | `<STANDBY_HOSTS>` |
| IP public | `<PRIMARY_PUBLIC_IPS>` | `<STANDBY_PUBLIC_IPS>` |
| IP rete Data Guard | `<PRIMARY_DG_IPS>` | `<STANDBY_DG_IPS>` |
| SCAN, solo RAC | `<PRIMARY_SCAN>` | `<STANDBY_SCAN>` |
| Grid Home | `<GRID_HOME>` | `<GRID_HOME>` |
| Oracle Home | `<ORACLE_HOME>` | `<ORACLE_HOME>` |
| RU Grid / DB | `<RU_APPROVATA>` | `<RU_APPROVATA>` |
| FRA bytes | `<FRA_BYTES>` | `<FRA_BYTES>` |
| Keystore | `<KEYSTORE_DIR oppure N/A>` | `<KEYSTORE_DIR oppure N/A>` |
| Recovery catalog | `<RMAN_CATALOG_TNS>` | `<RMAN_CATALOG_TNS>` |
| Backup destination | `<BACKUP_DEST>` | `<BACKUP_DEST>` |

Gate business e Security:

| Gate | Valore |
| --- | --- |
| Blueprint scelto | `<S1/S2/S3/S4>` |
| RPO / RTO | `<RPO>` / `<RTO>` |
| Latenza PE-SE | `<LATENZA_MS>` |
| Redo medio e picco | `<MB_SEC>` |
| Active Data Guard richiesto e licenziato | `<SI/NO - evidenza>` |
| TDE richiesto | `<SI/NO - evidenza>` |
| FSFO richiesto | `<SI/NO - evidenza>` |
| Trasporto approvato | `<SYNC_AFFIRM/FASTSYNC_NOAFFIRM/ASYNC>` |

## Procedura operativa

### 1. Preparazione database

Regole comuni:

1. primary e physical standby condividono `DB_NAME` e DBID;
2. `DB_UNIQUE_NAME` deve essere diverso;
3. lo standby si crea con RMAN duplicate o metodo fisico approvato, non con
   DBCA indipendente;
4. abilitare `ARCHIVELOG`, `FORCE LOGGING`, OMF, FRA e
   `STANDBY_FILE_MANAGEMENT=AUTO`;
5. creare SRL su entrambi i ruoli prima di uno switchover;
6. usare password file coerenti, prompt interattivo o wallet SEPS;
7. non scrivere password negli argomenti shell.

### 2. Redo e SRL

La baseline PEYTECH parte da quattro online redo log group da `4G` per thread,
ma il sizing finale dipende dal carico reale.

| Architettura | Thread | SRL minimi |
| --- | --- | --- |
| Single instance | `THREAD 1` | online group + 1 |
| RAC due nodi | `THREAD 1`, `THREAD 2` | online group + 1 per thread |

Query:

```sql
SELECT thread#, group#, bytes / 1024 / 1024 AS mb, status
FROM v$log
ORDER BY thread#, group#;

SELECT thread#, group#, bytes / 1024 / 1024 AS mb, status
FROM v$standby_log
ORDER BY thread#, group#;
```

### 3. Protection mode

Configurare Broker e scegliere il profilo dopo test di latenza:

| Profilo | Uso |
| --- | --- |
| `MaxAvailability` + `SYNC` | Preferito se latenza commit accettabile |
| `MaxAvailability` + `FASTSYNC` | Solo con rischio residuo `NOAFFIRM` approvato |
| `MaxPerformance` + `ASYNC` | Rollback operativo o rete non compatibile |

### 4. Active Data Guard, RMAN e TDE

- Active Data Guard `READ ONLY WITH APPLY` richiede licenza verificata.
- RMAN offload sul physical standby usa recovery catalog e deletion policy
  Data Guard-aware.
- TDE richiede assessment; se attivo, distribuire keystore e validare apertura
  sullo standby prima del duplicate e dopo ogni rekey.
- In CDB, valutare keystore root e PDB, query `CDB_*` e servizi PDB dedicati.

### 5. FSFO

Configurare prima Broker e switchover manuale. Attivare Observer e FSFO solo
dopo stabilizzazione usando
[Observer FSFO PEYTECH](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md).

## Validazione finale

```text
SHOW CONFIGURATION;
VALIDATE DATABASE M24SHAMSPEC;
VALIDATE DATABASE M24SHAMSSEC;
SHOW FAST_START FAILOVER;
SHOW OBSERVER;
```

Verificare inoltre:

- lag entro soglia;
- SRL completi per ogni thread;
- servizi presenti solo sul ruolo previsto;
- PDB aperta e propagata sullo standby per `S2` e `S4`;
- backup RMAN standby visibile nel catalogo;
- switchover e switchback riusciti;
- FSFO provato con drill autorizzato.

## Troubleshooting rapido

| Sintomo | Prima azione |
| --- | --- |
| Duplicate fallisce | listener statico, password file, NOMOUNT, ASM, keystore |
| SRL non usati | confronta thread, gruppi e dimensioni |
| PDB assente sullo standby | controlla `STANDBYS`, apply e `ENABLED_PDBS_ON_STANDBY` |
| Commit lenti | rollback a `MaxPerformance ASYNC` |
| FRA piena con lag | usa [DG-061](../../../01_operations/02_runbooks_incidenti/RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md#dg-061---primary-fra-piena-per-standby-lag) |
| Observer non parte | wallet SEPS, TNS, permessi file, Broker |
