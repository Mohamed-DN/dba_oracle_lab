# Artifact SHAMS PROJECT Data Guard

Questo pacchetto contiene gli export versionati della documentazione operativa
`SHAMS PROJECT`.

## Da dove iniziare

Non usare tutti i documenti come se descrivessero la stessa installazione.
Il pacchetto contiene quattro architetture alternative. Prima scegli una sola
riga della tabella seguente.

| ID | Primary e standby | Container | Data Guard | Observer FSFO | Documento da leggere |
| --- | --- | --- | --- | --- | --- |
| `S1` | Single instance | non-CDB | Si | Change separato | SOP `M24SHAMS_*_NON_CDB` |
| `S2` | Single instance | CDB con PDB | Si | Si, dopo stabilizzazione | Portfolio SHAMS PROJECT |
| `S3` | RAC | non-CDB | Si | Si, dopo stabilizzazione | Portfolio SHAMS PROJECT |
| `S4` | RAC | CDB con PDB | Si | Si, dopo stabilizzazione | Portfolio SHAMS PROJECT |

`CDB con PDB` significa che il database applicativo vive in un pluggable
database. `non-CDB` indica il modello legacy senza PDB. `RAC` aggiunge alta
affidabilita' locale con piu' istanze; Data Guard mantiene invece la copia
standby sul sito secondario.

Per una nuova installazione enterprise, il target preferito e' `S4`. Usa `S1`
o `S3` solo quando esiste un requisito applicativo legacy non-CDB. Usa `S2`
quando serve il modello CDB/PDB ma non e' richiesta HA locale RAC.

## Mappa dei file

| File | Contenuto | Quando aprirlo |
| --- | --- | --- |
| `M24SHAMS_RUN_SHEET_STAGING_DATAGUARD.*` | Run sheet breve `S1` | Durante il change single instance non-CDB |
| `M24SHAMS_SOP_ENTERPRISE_STAGING_DATAGUARD_NON_CDB.*` | SOP completa `S1`, incluso host Oracle Restart/ASM | Per progettare o implementare `S1` |
| `SHAMS_PROJECT_PORTFOLIO_ENTERPRISE_19C.*` | Baseline comune, `S1`-`S4`, Observer FSFO e allegati host single/RAC | Per scegliere l'architettura e implementare `S2`, `S3` o `S4` |
| `SHAMS_PROJECT_RUN_SHEET_VARIANTI.*` | Checklist sintetica comparativa | Per il gate iniziale e l'approvazione del blueprint |

Le estensioni `.docx` e `.pdf` contengono lo stesso documento in due formati.

## Scenario S1: run sheet sintetica

- [DOCX](./M24SHAMS_RUN_SHEET_STAGING_DATAGUARD.docx)
- [PDF](./M24SHAMS_RUN_SHEET_STAGING_DATAGUARD.pdf)

## Scenario S1: SOP completa

- [DOCX](./M24SHAMS_SOP_ENTERPRISE_STAGING_DATAGUARD_NON_CDB.docx)
- [PDF](./M24SHAMS_SOP_ENTERPRISE_STAGING_DATAGUARD_NON_CDB.pdf)

Questa SOP riguarda esclusivamente `S1`: single instance non-CDB con Data
Guard. Include anche l'allegato host Oracle Restart/ASM.

## Scenari S1-S4: portfolio SHAMS PROJECT

- [DOCX](./SHAMS_PROJECT_PORTFOLIO_ENTERPRISE_19C.docx)
- [PDF](./SHAMS_PROJECT_PORTFOLIO_ENTERPRISE_19C.pdf)
- [Run sheet DOCX](./SHAMS_PROJECT_RUN_SHEET_VARIANTI.docx)
- [Run sheet PDF](./SHAMS_PROJECT_RUN_SHEET_VARIANTI.pdf)

Il portfolio raccoglie baseline PEYTECH, quattro blueprint alternativi,
Observer FSFO e allegati host single/RAC.

## Rigenerazione

Da PowerShell, nella root del repository:

```powershell
& .\scripts\powershell\export_shams_project_docs.ps1
```

I file sorgente Markdown sono:

- [Indice progetto](../../docs/02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/README.md)
- [SOP M24SHAMS single non-CDB](../../docs/02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_01_M24SHAMS_SINGLE_NON_CDB_DATAGUARD.md)
- [SOP M24SHAMS single CDB/PDB](../../docs/02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_02_M24SHAMS_SINGLE_CDB_DATAGUARD_OBSERVER.md)
- [SOP M24SHAMS RAC non-CDB](../../docs/02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_03_M24SHAMS_RAC_NON_CDB_DATAGUARD_OBSERVER.md)
- [SOP M24SHAMS RAC CDB/PDB](../../docs/02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_04_M24SHAMS_RAC_CDB_DATAGUARD_OBSERVER.md)
- [Observer FSFO condiviso](../../docs/02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_05_OBSERVER_FSFO_PEYTECH.md)
- [Allegato Host single](../../docs/02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md)
- [Allegato Host RAC](../../docs/02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_07_HOST_RAC_GRID_ASM_19C.md)
- [Run Sheet M24SHAMS](../../docs/02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/RUN_SHEET_01_M24SHAMS_SINGLE_NON_CDB.md)
- [Run Sheet scelta varianti](../../docs/02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/RUN_SHEET_02_SHAMS_PROJECT_VARIANTI.md)
