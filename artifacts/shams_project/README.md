# Artifact SHAMS PROJECT Data Guard

Questo pacchetto contiene gli export versionati della documentazione operativa
`SHAMS PROJECT`.

## Run sheet sintetica

- [DOCX](./M24SHAMS_RUN_SHEET_STAGING_DATAGUARD.docx)
- [PDF](./M24SHAMS_RUN_SHEET_STAGING_DATAGUARD.pdf)

## SOP completa

- [DOCX](./M24SHAMS_SOP_ENTERPRISE_STAGING_DATAGUARD_NON_CDB.docx)
- [PDF](./M24SHAMS_SOP_ENTERPRISE_STAGING_DATAGUARD_NON_CDB.pdf)

La SOP completa include anche l'allegato host Oracle Restart/ASM.

## Portfolio SHAMS PROJECT

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
- [Allegato Host single](../../docs/02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md)
- [Run Sheet M24SHAMS](../../docs/02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/RUN_SHEET_01_M24SHAMS_SINGLE_NON_CDB.md)
