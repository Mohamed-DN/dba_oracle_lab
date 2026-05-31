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
| SID o SID prefix | `M24SHAMSPEC` | `M24SHAMSPEC` |
| SID risultanti | `M24SHAMSPEC` | `M24SHAMSPEC1`, `M24SHAMSPEC2` |
| `DB_NAME` nei parametri | `M24SHAMS` | `M24SHAMS` |
| `DB_UNIQUE_NAME` nei parametri | `M24SHAMSPEC` | `M24SHAMSPEC` |

Lo standby SE non viene creato con DBCA: deriva dal duplicate RMAN e usa
`DB_UNIQUE_NAME=M24SHAMSSEC`, SID `M24SHAMSSEC` per single instance oppure
`M24SHAMSSEC1`, `M24SHAMSSEC2` per RAC.

Il prefisso di esempio e' `M24SHAMS`. Prima dell'uso reale sostituiscilo con il
prefisso approvato mantenendo la stessa convenzione di naming.

## Documenti comuni

| Documento | Uso |
| --- | --- |
| [Baseline PEYTECH](./GUIDA_00_BASELINE_COMUNE_PEYTECH_19C.md) | Requisiti, naming, gate, redo, TDE, RMAN ed evidence pack |
| [Observer FSFO](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md) | Installazione Observer, wallet SEPS, observe-only, attivazione e rollback |
| [Host single instance](./GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md) | Linux, Oracle Restart/HAS, ASM e Database Home |
| [Host RAC](./GUIDA_07_HOST_RAC_GRID_ASM_19C.md) | Linux, Grid Infrastructure Clusterware, ASM, SCAN e Database Home |
| [Run sheet varianti](./RUN_SHEET_02_SHAMS_PROJECT_VARIANTI.md) | Checklist breve per scegliere ed eseguire il blueprint corretto |
| [Artifact DOCX/PDF](../../../../artifacts/shams_project/README.md) | Export versionati del pacchetto |

## Percorso operativo

1. compila la baseline comune;
2. scegli `S1`, `S2`, `S3` oppure `S4`;
3. prepara gli host con l'allegato single o RAC;
4. crea primary e standby seguendo la guida specifica;
5. valida Broker e switchover;
6. stabilizza il servizio;
7. attiva FSFO tramite la guida Observer condivisa.

## Validazione finale

Il blueprint e' pronto quando:

- l'architettura scelta e' registrata nel change;
- `DB_NAME`, `DB_UNIQUE_NAME`, servizi e PDB sono coerenti;
- Broker restituisce `SUCCESS`;
- switchover e switchback sono stati provati;
- Observer e FSFO sono attivati solo dopo il periodo di stabilita';
- il pacchetto di evidenze non contiene password.

## Troubleshooting rapido

Se una procedura specifica non e' chiara, torna alla
[baseline comune](./GUIDA_00_BASELINE_COMUNE_PEYTECH_19C.md) e verifica di aver
selezionato un solo blueprint. Non combinare comandi RAC e Oracle Restart o
comandi CDB e non-CDB nella stessa installazione.
