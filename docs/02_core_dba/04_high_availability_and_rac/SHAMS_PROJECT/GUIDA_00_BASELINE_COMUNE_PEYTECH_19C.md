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
- [Licensing Oracle Database 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/dblic/Licensing-Information.html)
- [Oracle Developer Downloads](https://www.oracle.com/downloads/)

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
| `DB_NAME` condiviso / CDB name | `M24SHAMS` |
| Primary `DB_UNIQUE_NAME` | `M24SHAMSPEC` |
| Standby `DB_UNIQUE_NAME` | `M24SHAMSSEC` |
| DBCA Global Database Name primary | `M24SHAMSPEC` oppure `M24SHAMSPEC.<DB_DOMAIN>` |
| DBCA SID primary single instance | `M24SHAMSPEC` |
| DBCA SID prefix primary RAC | `M24SHAMSPEC` |
| SID locale auxiliary standby single instance | `M24SHAMSSEC` |
| PDB applicativo, solo CDB | `M24SHAMSC_APP` |
| Service read-write | `M24SHAMSC_PRY` |
| Service Active Data Guard | `M24SHAMSC_RO` |
| TNS primary DG | `M24SHAMSPEC_DG` |
| TNS standby DG | `M24SHAMSSEC_DG` |
| Listener DG | `1531/TCP` |
| ASM DATA | `+M24SHAMS_DATA` |
| ASM FRA | `+M24SHAMS_FRA` |

Il nome si costruisce come:

```text
DB_UNIQUE_NAME = <NOME_BASE><DATACENTER><AMBIENTE>
```

Per `M24SHAMS`:

| Ambiente | Primary PE | Standby SE |
| --- | --- | --- |
| Collaudo `C` | `M24SHAMSPEC` | `M24SHAMSSEC` |
| Produzione `P` | `M24SHAMSPEP` | `M24SHAMSSEP` |

Questo pacchetto implementa il collaudo `C`. La riga produzione serve solo a
rendere esplicita la regola di naming: non sostituire automaticamente
l'ambiente senza un change approvato.

Per RAC:

| Oggetto | Primary PE | Standby SE |
| --- | --- | --- |
| SID prefix | `M24SHAMSPEC` | `M24SHAMSSEC` |
| Istanza nodo 1 | `M24SHAMSPEC1` | `M24SHAMSSEC1` |
| Istanza nodo 2 | `M24SHAMSPEC2` | `M24SHAMSSEC2` |
| SCAN | `<PRIMARY_SCAN>` | `<STANDBY_SCAN>` |

Il SID prefix deve richiamare `DB_UNIQUE_NAME` e includere datacenter e
ambiente. Per RAC DBCA aggiunge il numero dell'istanza al prefix.

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
| Active Data Guard | `<PRODUZIONE_CON_EVIDENZA/LAB_PERSONALE/NO>` |
| TDE richiesto | `<SI/NO - evidenza>` |
| FSFO richiesto | `<SI/NO - evidenza>` |
| Trasporto approvato | `<SYNC_AFFIRM/FASTSYNC_NOAFFIRM/ASYNC>` |

## Procedura operativa

### 1. Preparazione database

Regole comuni:

1. primary e physical standby condividono `DB_NAME` e DBID;
2. `DB_UNIQUE_NAME` deve essere diverso;
3. in DBCA sul primary inserire Global Database Name site-specific
   `M24SHAMSPEC[.<DB_DOMAIN>]`; usare SID `M24SHAMSPEC` per single instance
   oppure SID prefix `M24SHAMSPEC` per RAC;
4. aprire `All Initialization Parameters` e verificare
   `DB_NAME=M24SHAMS`, `DB_UNIQUE_NAME=M24SHAMSPEC` e inclusione nello SPFILE;
5. lo standby si crea con RMAN duplicate o metodo fisico approvato, non con
   DBCA indipendente;
6. sullo standby usare il SID locale auxiliary `M24SHAMSSEC` oppure
   `M24SHAMSSEC1/2` per RAC, secondo la SOP scelta;
7. abilitare `ARCHIVELOG`, `FORCE LOGGING`, OMF, FRA e
   `STANDBY_FILE_MANAGEMENT=AUTO`;
8. creare SRL su entrambi i ruoli prima di uno switchover;
9. usare password file coerenti, prompt interattivo o wallet SEPS;
10. non scrivere password negli argomenti shell.

Per la compilazione puntuale del wizard usare la
[matrice campi DBCA](./GUIDA_08_DBCA_GUI_FIELD_MATRIX_PEYTECH_19C.md).

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

- Il setup Data Guard base resta valido con standby `MOUNTED` e Redo Apply.
- Active Data Guard `READ ONLY WITH APPLY` e' opzionale. In produzione
  richiede evidenza formale; nel lab personale e' esercitabile nei limiti dei
  termini developer accettati al download.
- RMAN offload sul physical standby usa recovery catalog e deletion policy
  Data Guard-aware.
- TDE richiede assessment; se attivo, distribuire keystore e validare apertura
  sullo standby prima del duplicate e dopo ogni rekey.
- In CDB, valutare keystore root e PDB, query `CDB_*` e servizi PDB dedicati.

Per rete, duplicate e Broker usa
[Network e Broker](./GUIDA_09_DATAGUARD_NETWORK_BROKER_PEYTECH_19C.md).
Per la variante read-only usa
[Active Data Guard e servizi](./GUIDA_10_ACTIVE_DATAGUARD_SERVIZI_ROLE_BASED_PEYTECH_19C.md).
Per evidenze e drill usa
[Evidence e drill test book](./GUIDA_11_DATAGUARD_EVIDENCE_DRILL_TESTBOOK_PEYTECH_19C.md).

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
- servizi presenti solo sul ruolo previsto; `_RO` solo se ADG e' autorizzato;
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
