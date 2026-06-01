# Run Sheet M24SHAMS: Staging Data Guard

## Obiettivo operativo

Fornire la sequenza breve per il change `M24SHAMS`: primary PE
`M24SHAMSPEC`, standby SE `M24SHAMSSEC`, single instance non-CDB Oracle 19c,
ASM, Oracle Restart, Broker, Active Data Guard opzionale e backup RMAN sullo
standby.

Usare questo run sheet durante il change. Per motivazioni, comandi completi e
troubleshooting consultare la
[SOP Enterprise M24SHAMS](./GUIDA_01_M24SHAMS_SINGLE_NON_CDB_DATAGUARD.md).

## Architettura

```text
Applicazione staging
        |
        v
M24SHAMSC_PRY
        |
PE: M24SHAMSPEC  -- redo transport -->  SE: M24SHAMSSEC
PRIMARY                                 PHYSICAL STANDBY
+M24SHAMS_DATA / +M24SHAMS_FRA         +M24SHAMS_DATA / +M24SHAMS_FRA
                                        |
                                        +-- M24SHAMSC_RO
                                        +-- RMAN backup offload
```

## Inventario da compilare

| Campo | Valore |
| --- | --- |
| Change ID e finestra | `<CHANGE_ID>` |
| DBA owner | `<NOME>` |
| Host PE / IP DG | `<PRIMARY_FQDN>` / `<PRIMARY_DG_IP>` |
| Host SE / IP DG | `<STANDBY_FQDN>` / `<STANDBY_DG_IP>` |
| Grid Home / DB Home | `<GRID_HOME>` / `<ORACLE_HOME>` |
| RU 19c approvata e allineata | `<RU>` |
| FRA PE / SE | `<FRA_BYTES>` / `<FRA_BYTES>` |
| Latenza PE-SE | `<LATENZA_MS>` |
| Recovery catalog | `<RMAN_CATALOG_TNS>` |
| Destinazione backup | `/backup/rman/M24SHAMSPEC` e `/backup/rman/M24SHAMSSEC` |
| Active Data Guard | `<PRODUZIONE_CON_EVIDENZA/LAB_PERSONALE/NO>` |
| Decisione TDE | `<SI/NO - RIFERIMENTO>` |
| Metodo creazione primary | `<DBCA_SCRIPT_REVIEW/GOLDEN_RMAN>` |
| Trasporto approvato | `<SYNC_AFFIRM/FASTSYNC_NOAFFIRM>` |
| Broker configuration name | `DR_M24SHAMSC_CONF` |

## Gate Go/No-Go

| Gate | Go se | Esito |
| --- | --- | --- |
| Host | Oracle Restart, ASM, DNS, NTP e listener DG validi | `<GO/NO-GO>` |
| Patch | Grid e DB Home PE/SE hanno stessa RU | `<GO/NO-GO>` |
| Storage | DATA e FRA dimensionati con crescita disponibile | `<GO/NO-GO>` |
| Licensing | ADG disattivo oppure evidenza formale; lab personale marcato | `<GO/NO-GO>` |
| TDE | decisione Security registrata e keystore distribuito se necessario | `<GO/NO-GO>` |
| RMAN | catalogo e destinazione backup raggiungibili dallo standby | `<GO/NO-GO>` |
| Rete | test latenza e stabilita' compatibili con il profilo scelto | `<GO/NO-GO>` |

## Procedura operativa

### 1. Preparazione host

Apri l'[Allegato Host](./GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md) e
chiudi la checklist:

```bash
crsctl check has
srvctl status asm
asmcmd lsdg
<GRID_HOME>/OPatch/opatch lsinventory
<ORACLE_HOME>/OPatch/opatch lsinventory
lsnrctl status LISTENER_DG
```

### 2. Creazione primary

Scegli e registra uno dei percorsi:

| Percorso | Check |
| --- | --- |
| DBCA `Generate Database Creation Scripts`, review, esecuzione | `<OK/KO>` |
| Golden template RMAN vuoto approvato | `<OK/KO>` |

Se usi DBCA GUI, inserisci prima:

| Campo DBCA primary PE | Valore |
| --- | --- |
| Global Database Name | `M24SHAMSPEC` oppure `M24SHAMSPEC.<DB_DOMAIN>` |
| SID | `M24SHAMSPEC` |
| `All Initialization Parameters`: `DB_NAME` | `M24SHAMS` |
| `All Initialization Parameters`: `DB_UNIQUE_NAME` | `M24SHAMSPEC` |

Chiudi i controlli:

```sql
SELECT name, db_unique_name, database_role, open_mode, log_mode, force_logging
FROM v$database;

SELECT group#, thread#, bytes / 1024 / 1024 AS mb, status
FROM v$log
ORDER BY group#;
```

### 3. Prerequisiti Data Guard

Conferma:

| Controllo | Esito |
| --- | --- |
| `DB_NAME=M24SHAMS` | `<OK/KO>` |
| primary `DB_UNIQUE_NAME=M24SHAMSPEC` | `<OK/KO>` |
| primary SID `M24SHAMSPEC` | `<OK/KO>` |
| standby SID `M24SHAMSSEC` | `<OK/KO>` |
| `ARCHIVELOG` e `FORCE LOGGING` | `<OK/KO>` |
| OMF DATA/FRA | `<OK/KO>` |
| password file trasferito in modo sicuro | `<OK/KO>` |
| TNS dinamici `M24SHAMSPEC_DG`, `M24SHAMSSEC_DG` | `<OK/KO>` |
| TNS auxiliary temporaneo `M24SHAMSSEC_AUX` | `<OK/KO>` |
| listener `1531/TCP`, static `_AUX` e `_DGMGRL` distinti | `<OK/KO>` |
| cinque SRL da `4G` o sizing approvato sul primary | `<OK/KO>` |

### 4. Duplicate standby

Avvia auxiliary `M24SHAMSSEC` in `NOMOUNT`, quindi:

```bash
rman target sys@M24SHAMSPEC_DG auxiliary sys@M24SHAMSSEC_AUX
```

Esegui lo script `DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE`
approvato nella SOP. Non inserire password nella command line.

### 5. Apply, Active Data Guard e SRL

Sullo standby crea gli SRL approvati e abilita il Redo Apply base:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

Solo se ADG e' autorizzato, applica la sequenza:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
ALTER DATABASE OPEN READ ONLY;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

Atteso nel percorso Data Guard base:

```sql
SELECT open_mode, database_role FROM v$database;
```

```text
MOUNTED | PHYSICAL STANDBY
```

Con Active Data Guard autorizzato l'atteso diventa
`READ ONLY WITH APPLY | PHYSICAL STANDBY`.

### 6. Broker e protection mode

Prima salva l'inventario `LOG_ARCHIVE_DEST_n` e il relativo rollback SQL.
Rimuovi in modo mirato le sole destinazioni redo remote manuali incompatibili:
sul primary prima di `CREATE CONFIGURATION`, sullo standby prima di
`ADD DATABASE`. Non azzerare FRA, `local_listener`, `remote_listener` o
`listener_networks`.

Da `dgmgrl`, con autenticazione interattiva o wallet:

```text
CREATE CONFIGURATION 'DR_M24SHAMSC_CONF' AS
  PRIMARY DATABASE IS 'M24SHAMSPEC'
  CONNECT IDENTIFIER IS 'M24SHAMSPEC_DG';

ADD DATABASE 'M24SHAMSSEC' AS
  CONNECT IDENTIFIER IS 'M24SHAMSSEC_DG'
  MAINTAINED AS PHYSICAL;

ENABLE CONFIGURATION;
SHOW CONFIGURATION;
SHOW DATABASE VERBOSE 'M24SHAMSPEC';
SHOW DATABASE VERBOSE 'M24SHAMSSEC';
VALIDATE DATABASE 'M24SHAMSPEC';
VALIDATE DATABASE 'M24SHAMSSEC';
VALIDATE DATABASE 'M24SHAMSPEC' SPFILE;
VALIDATE DATABASE 'M24SHAMSSEC' SPFILE;
VALIDATE NETWORK CONFIGURATION FOR ALL;
VALIDATE STATIC CONNECT IDENTIFIER FOR ALL;
```

`DR_M24SHAMSC_CONF` deriva dal `DB_NAME=M24SHAMS` e dall'ambiente `C`:
non contiene il sito PE o SE e resta invariato dopo lo switchover.

Applica il profilo approvato:

| Profilo | Uso |
| --- | --- |
| `SYNC` | `SYNC AFFIRM`, preferito se latenza commit accettabile |
| `FASTSYNC` | `SYNC NOAFFIRM`, solo con rischio residuo approvato |

Imposta:

```text
EDIT DATABASE 'M24SHAMSSEC' SET PROPERTY 'LogXptMode'='<SYNC oppure FASTSYNC>';
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
SHOW CONFIGURATION;
```

### 7. RMAN sullo standby

Connetti standby e recovery catalog:

```bash
rman target sys@M24SHAMSSEC_DG catalog <CATALOG_USER>@<RMAN_CATALOG_TNS>
```

Verifica configurazione e avvia backup baseline:

```rman
LIST DB_UNIQUE_NAME OF DATABASE;
SHOW ALL;
BACKUP AS COMPRESSED BACKUPSET DATABASE TAG 'M24SHAMS_STBY_BASELINE';
BACKUP ARCHIVELOG ALL NOT BACKED UP 1 TIMES TAG 'M24SHAMS_STBY_ARCH';
LIST BACKUP SUMMARY;
```

Esegui backup SPFILE locale anche sul primary.

### 8. Drill switchover

Con applicazione drenata:

```text
SWITCHOVER TO M24SHAMSSEC;
SHOW CONFIGURATION;
```

Verifica servizi, scrittura su `M24SHAMSC_PRY`, lettura su `M24SHAMSC_RO` e
apply. Esegui switchback:

```text
SWITCHOVER TO M24SHAMSPEC;
SHOW CONFIGURATION;
```

FSFO resta fuori dal change. Pianifica la
[Observer FSFO PEYTECH](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md) dopo stabilizzazione.

## Validazione finale

| Evidenza | Esito |
| --- | --- |
| `SHOW CONFIGURATION` senza errori bloccanti | `<OK/KO>` |
| `VALIDATE DATABASE` primary e standby | `<OK/KO>` |
| `VALIDATE DATABASE ... SPFILE` primary e standby | `<OK/KO>` |
| network e static connect identifier validati | `<OK/KO>` |
| transport lag e apply lag entro soglia | `<OK/KO>` |
| standby `MOUNTED` oppure `READ ONLY WITH APPLY` autorizzato | `<OK/KO>` |
| servizio `M24SHAMSC_PRY` sul primary | `<OK/KO>` |
| servizio `M24SHAMSC_RO` sullo standby se ADG autorizzato | `<OK/KO/N.A.>` |
| backup RMAN standby visibile nel catalogo | `<OK/KO>` |
| backup SPFILE locale PE e SE | `<OK/KO>` |
| restore test registrato | `<OK/KO>` |
| switchover e switchback completati | `<OK/KO>` |

Firme:

| Ruolo | Nome | Firma / ticket |
| --- | --- | --- |
| DBA | `<NOME>` | `<RIFERIMENTO>` |
| Application owner | `<NOME>` | `<RIFERIMENTO>` |
| Networking | `<NOME>` | `<RIFERIMENTO>` |
| Security / licensing | `<NOME>` | `<RIFERIMENTO>` |
| Change manager | `<NOME>` | `<RIFERIMENTO>` |

## Rollback rapido

Se il trasporto sincrono impatta l'applicazione:

```text
EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
EDIT DATABASE 'M24SHAMSSEC' SET PROPERTY 'LogXptMode'='ASYNC';
SHOW CONFIGURATION;
```

Se lo standby non e' affidabile, mantieni il primary aperto, preserva gli
archivelog e pianifica la ricostruzione. Non eseguire purge ciechi e non
improvvisare un failover.

## Troubleshooting rapido

| Sintomo | Azione iniziale |
| --- | --- |
| Auxiliary irraggiungibile | `lsnrctl status LISTENER_DG`, `tnsping M24SHAMSSEC_AUX` |
| RMAN duplicate fallisce | alert log, password file, NOMOUNT, ASM, rete |
| Apply lag | `V$DATAGUARD_STATS`, `V$MANAGED_STANDBY`, alert log |
| Wallet chiuso | runbook TDE e copia keystore approvata |
| Commit lenti | rollback a `MaxPerformance ASYNC` |
| FRA piena | [DG-061](../../../01_operations/02_runbooks_incidenti/RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md#dg-061---primary-fra-piena-per-standby-lag) |
