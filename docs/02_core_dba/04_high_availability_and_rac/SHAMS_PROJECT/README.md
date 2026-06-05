# SHAMS PROJECT: Oracle 19c Data Guard Blueprint

## Obiettivo operativo

Raccogliere in un unico pacchetto i blueprint PEYTECH per database Oracle 19c
in staging/collaudo `C`, con Data Guard Broker e Observer FSFO. Le guide sono
alternative architetturali: prima del change scegli un solo blueprint.

## Matrice dei blueprint

| ID | Primary e standby | Container | HA locale | Guida | Quando usarla |
| --- | --- | --- | --- | --- | --- |
| `S1` | Single instance | non-CDB | Oracle Restart/HAS | [M24SHAMS single non-CDB](./GUIDA_01_M24SHAMS_SINGLE_NON_CDB_DATAGUARD.md) | Compatibilita' applicativa legacy |
| `S2` | Single instance | CDB con PDB | Oracle Restart/HAS | [M24SHAMS single CDB](./GUIDA_02_M24SHAMS_SINGLE_CDB_DATAGUARD_OBSERVER.md) | Nuove installazioni senza HA locale RAC |
| `S3` | RAC | non-CDB | RAC e Clusterware | [M24SHAMS RAC non-CDB](./GUIDA_03_M24SHAMS_RAC_NON_CDB_DATAGUARD_OBSERVER.md) | HA locale RAC con compatibilita' legacy |
| `S4` | RAC | CDB con PDB | RAC e Clusterware | [M24SHAMS RAC CDB](./GUIDA_04_M24SHAMS_RAC_CDB_DATAGUARD_OBSERVER.md) | Target preferito per nuovi database enterprise |

Ogni riga descrive una coppia Data Guard: un primary sul sito principale e un
physical standby sul sito secondario. `CDB con PDB` significa che il database
applicativo vive in un pluggable database. `non-CDB` indica il modello legacy
senza PDB. `RAC` protegge dai guasti locali di un nodo; Data Guard protegge
invece dalla perdita del database o del sito primario.

Non combinare le righe: per esempio, non aggiungere comandi PDB a `S1` e non
usare procedure RAC per `S2`.

## Naming DBCA

Per il collaudo `C`, la creazione DBCA del primary PE parte da:

| Campo | Single instance | RAC |
| --- | --- | --- |
| Global Database Name | `M24SHAMSPEC[.<DB_DOMAIN>]` | `M24SHAMSPEC[.<DB_DOMAIN>]` |
| SID o SID prefix | SID `M24SHAMSPEC` | SID prefix `M24SHAMSPEC` |
| SID risultanti | `M24SHAMSPEC` | `M24SHAMSPEC1`, `M24SHAMSPEC2` |
| `DB_NAME` nei parametri | `M24SHAMS` | `M24SHAMS` |
| `DB_UNIQUE_NAME` nei parametri | `M24SHAMSPEC` | `M24SHAMSPEC` |

Lo standby SE non viene creato con DBCA: deriva dal duplicate RMAN e usa
`DB_UNIQUE_NAME=M24SHAMSSEC`. Le SOP usano SID locali auxiliary
`M24SHAMSSEC` per single instance oppure `M24SHAMSSEC1`, `M24SHAMSSEC2` per
RAC.

Il prefisso di esempio e' `M24SHAMS`. Prima dell'uso reale sostituiscilo con il
prefisso approvato mantenendo la stessa convenzione di naming.

La configurazione Broker usa il `DB_NAME` condiviso e il codice ambiente:

```text
DR_<DB_NAME><ENV>_CONF
```

Per il collaudo SHAMS il nome e' `DR_M24SHAMSC_CONF`; per produzione sarebbe
`DR_M24SHAMSP_CONF`. Non usare `DB_UNIQUE_NAME` nel nome Broker: il nome deve
restare stabile dopo switchover. Verifica sempre il limite Oracle di 30 byte.

Ogni SOP contiene una scheda iniziale di sostituzione. Compilala prima di
riusare il blueprint per un prefisso diverso da `M24SHAMS`.

## Documenti comuni

| Documento | Uso |
| --- | --- |
| [Baseline PEYTECH](./GUIDA_00_BASELINE_COMUNE_PEYTECH_19C.md) | Requisiti, naming, gate, redo, TDE, RMAN ed evidence pack |
| [Observer FSFO](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md) | Installazione Observer, wallet SEPS, observe-only, attivazione e rollback |
| [Host single instance](./GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md) | Linux, Oracle Restart/HAS, ASM e Database Home |
| [Host RAC](./GUIDA_07_HOST_RAC_GRID_ASM_19C.md) | Linux, Grid Infrastructure Clusterware, ASM, SCAN e Database Home |
| [Matrice campi DBCA](./GUIDA_08_DBCA_GUI_FIELD_MATRIX_PEYTECH_19C.md) | Checklist schermata-per-schermata, naming single/RAC e audit delle scelte GUI |
| [Network e Broker](./GUIDA_09_DATAGUARD_NETWORK_BROKER_PEYTECH_19C.md) | Setup comune: rete DG, listener, duplicate RMAN, apply e Broker |
| [Active Data Guard e servizi](./GUIDA_10_ACTIVE_DATAGUARD_SERVIZI_ROLE_BASED_PEYTECH_19C.md) | Percorso opzionale licenza-gated per `READ ONLY WITH APPLY`, `_PRY` e `_RO` |
| [Evidence e drill test book](./GUIDA_11_DATAGUARD_EVIDENCE_DRILL_TESTBOOK_PEYTECH_19C.md) | Evidenze, switchover, gap, servizi, Observer e rollback |
| [CATRMAN recovery catalog](../../02_backup_and_recovery/GUIDA_RMAN_CATALOGO_CATRMAN_19C.md) | Catalogo RMAN centralizzato, wallet/SEPS e `DB_UNIQUE_NAME` per Data Guard |
| [Standard directory backup RMAN](../../02_backup_and_recovery/GUIDA_STANDARD_DIRECTORY_BACKUP_RMAN_19C.md) | Share `/backup/rman`, catene indipendenti PE/SE, status OEM e cleanup gated |
| [RMAN backup SHAMS](../../02_backup_and_recovery/SHAMS_RMAN/SHAMS_PROJECT/GUIDA_RMAN_BACKUP_SHAMS_PROJECT.md) | Wrapper, cmdfile, schedule, catalogo e cleanup sicuro per SHAMS |
| [Standby SHAMS con RMAN](../../02_backup_and_recovery/SHAMS_RMAN/SHAMS_PROJECT/GUIDA_SHAMS_STANDBY_RMAN_SINGLE_NON_CDB.md) | Procedura active duplicate single non-CDB con comandi reali e placeholder |
| [SHAMS Produzione MaxPerformance](../../02_backup_and_recovery/SHAMS_RMAN/SHAMS_PROJECT/GUIDA_SHAMS_PROD_MAXPERFORMANCE_WITH_RMAN.md) | Coppia produzione `M24SHAMSPEP/M24SHAMSSEP`, Broker `MAXPERFORMANCE`, catalogo e backup |
| [SHAMS Migration With RMAN](../../02_backup_and_recovery/SHAMS_RMAN/SHAMS_PROJECT/GUIDA_SHAMS_MIGRATION_WITH_RMAN.md) | Clone produzione -> STG, NID fallback e standby STG |
| [Run sheet varianti](./RUN_SHEET_02_SHAMS_PROJECT_VARIANTI.md) | Checklist breve per scegliere ed eseguire il blueprint corretto |
| [Artifact DOCX/PDF](../../../../artifacts/shams_project/README.md) | Export versionati del pacchetto |

## Percorso operativo

1. compila la baseline comune;
2. scegli `S1`, `S2`, `S3` oppure `S4`;
3. prepara gli host con l'allegato single o RAC;
4. crea primary e standby seguendo la guida specifica e il setup comune DG;
5. valida Broker e switchover compilando il test book;
6. attiva Active Data Guard solo se il gate licenza lo consente;
7. stabilizza i servizi;
8. attiva FSFO tramite la guida Observer condivisa.

## Validazione finale

Il blueprint e' pronto quando:

- l'architettura scelta e' registrata nel change;
- `DB_NAME`, `DB_UNIQUE_NAME`, servizi e PDB sono coerenti;
- Broker restituisce `SUCCESS`;
- switchover e switchback sono stati provati;
- Active Data Guard e `_RO` sono attivi solo con evidenza licenza o in lab personale;
- Observer e FSFO sono attivati solo dopo il periodo di stabilita';
- il pacchetto di evidenze non contiene password.

## Troubleshooting rapido

Se una procedura specifica non e' chiara, torna alla
[baseline comune](./GUIDA_00_BASELINE_COMUNE_PEYTECH_19C.md) e verifica di aver
selezionato un solo blueprint. Non combinare comandi RAC e Oracle Restart o
comandi CDB e non-CDB nella stessa installazione.
