# Artifact M24SHAMS Data Guard

Questo pacchetto contiene gli export versionati della documentazione operativa
`M24SHAMS`.

## Run sheet sintetica

- [DOCX](./M24SHAMS_RUN_SHEET_STAGING_DATAGUARD.docx)
- [PDF](./M24SHAMS_RUN_SHEET_STAGING_DATAGUARD.pdf)

## SOP completa

- [DOCX](./M24SHAMS_SOP_ENTERPRISE_STAGING_DATAGUARD_NON_CDB.docx)
- [PDF](./M24SHAMS_SOP_ENTERPRISE_STAGING_DATAGUARD_NON_CDB.pdf)

La SOP completa include anche l'allegato host Oracle Restart/ASM.

## Rigenerazione

Da PowerShell, nella root del repository:

```powershell
& .\scripts\powershell\export_m24shams_docs.ps1
```

I file sorgente Markdown sono:

- [SOP Enterprise](../../docs/02_core_dba/04_high_availability_and_rac/GUIDA_ENTERPRISE_M24SHAMS_STAGING_DATAGUARD_NON_CDB.md)
- [Allegato Host](../../docs/02_core_dba/04_high_availability_and_rac/GUIDA_M24SHAMS_HOST_ORACLE_RESTART_ASM_19C.md)
- [Run Sheet](../../docs/02_core_dba/04_high_availability_and_rac/RUN_SHEET_M24SHAMS_STAGING_DATAGUARD.md)
