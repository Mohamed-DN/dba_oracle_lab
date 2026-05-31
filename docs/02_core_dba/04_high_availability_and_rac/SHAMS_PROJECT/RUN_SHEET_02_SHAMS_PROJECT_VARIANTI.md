# SHAMS PROJECT: Run Sheet Scelta Blueprint

## Obiettivo operativo

Selezionare e collaudare una sola variante SHAMS PROJECT senza mescolare
comandi single instance, RAC, CDB e non-CDB.

## Scelta iniziale

| ID | Architettura | Guida | Selezione |
| --- | --- | --- | --- |
| `S1` | Single non-CDB | [Guida S1](./GUIDA_01_M24SHAMS_SINGLE_NON_CDB_DATAGUARD.md) | `<SI/NO>` |
| `S2` | Single CDB/PDB | [Guida S2](./GUIDA_02_M24SHAMS_SINGLE_CDB_DATAGUARD_OBSERVER.md) | `<SI/NO>` |
| `S3` | RAC non-CDB | [Guida S3](./GUIDA_03_M24SHAMS_RAC_NON_CDB_DATAGUARD_OBSERVER.md) | `<SI/NO>` |
| `S4` | RAC CDB/PDB | [Guida S4](./GUIDA_04_M24SHAMS_RAC_CDB_DATAGUARD_OBSERVER.md) | `<SI/NO>` |

Deve esistere un solo `SI`.

## Procedura operativa

### 1. Gate comune

Apri la [baseline PEYTECH](./GUIDA_00_BASELINE_COMUNE_PEYTECH_19C.md) e
compila:

| Gate | Esito |
| --- | --- |
| naming PE/SE e ambiente `C` | `<OK/KO>` |
| RPO, RTO e latenza | `<OK/KO>` |
| storage DATA/FRA | `<OK/KO>` |
| RU Grid e DB Home | `<OK/KO>` |
| licenza Active Data Guard | `<OK/KO>` |
| decisione TDE | `<OK/KO>` |
| recovery catalog RMAN | `<OK/KO>` |

### 2. Gate host

| Blueprint | Allegato |
| --- | --- |
| `S1`, `S2` | [Host single](./GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md) |
| `S3`, `S4` | [Host RAC](./GUIDA_07_HOST_RAC_GRID_ASM_19C.md) |

### 3. Gate database

| Check | Single | RAC |
| --- | --- | --- |
| istanze | una per sito | due per sito |
| redo thread | `THREAD 1` | `THREAD 1`, `THREAD 2` |
| SRL | online group + 1 | online group + 1 per thread |
| gestione | Oracle Restart | Clusterware RAC |
| endpoint client | listener | SCAN |

| Check | non-CDB | CDB |
| --- | --- | --- |
| `CDB` | `NO` | `YES` |
| PDB | N/A | `M24SHAMSC_APP` |
| service applicativo | database | PDB |
| role transition | database | intera CDB |

### 4. Gate Data Guard

```text
SHOW CONFIGURATION;
VALIDATE DATABASE M24SHAMSPEC;
VALIDATE DATABASE M24SHAMSSEC;
```

Verifica:

- redo transport;
- apply;
- lag;
- SRL;
- TDE;
- servizi role-based;
- backup RMAN standby;
- switchover e switchback.

### 5. Gate Observer

Dopo stabilizzazione apri
[Observer FSFO PEYTECH](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md):

```text
ENABLE FAST_START FAILOVER OBSERVE ONLY;
VALIDATE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
SHOW OBSERVER;
```

Attiva FSFO solo dopo la finestra observe-only approvata.

## Validazione finale

| Evidenza | Esito |
| --- | --- |
| blueprint univoco selezionato | `<OK/KO>` |
| host checklist chiusa | `<OK/KO>` |
| database checklist chiusa | `<OK/KO>` |
| Broker `SUCCESS` | `<OK/KO>` |
| RMAN standby e restore test | `<OK/KO>` |
| switchover e switchback | `<OK/KO>` |
| Observer wallet-backed | `<OK/KO>` |
| drill FSFO autorizzato | `<OK/KO>` |

## Rollback rapido

Se la rete non supporta il profilo sincrono:

```text
DISABLE FAST_START FAILOVER;
EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
EDIT DATABASE M24SHAMSSEC SET PROPERTY LogXptMode='ASYNC';
SHOW CONFIGURATION;
```

## Troubleshooting rapido

| Sintomo | Azione |
| --- | --- |
| comandi RAC su server single | torna alla matrice e scegli il blueprint corretto |
| PDB non disponibile | usa solo guida `S2` o `S4`, controlla PDB e service |
| thread 2 assente | atteso su single; errore su RAC |
| Observer non parte | wallet SEPS, TNS, permessi, Broker |
| FRA piena con lag | usa [DG-061](../../../01_operations/02_runbooks_incidenti/RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md#dg-061---primary-fra-piena-per-standby-lag) |
