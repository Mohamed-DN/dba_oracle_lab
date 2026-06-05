# SHAMS Project RMAN

## Percorso operativo

1. Installa e valida il backup RMAN con
   [GUIDA_RMAN_BACKUP_SHAMS_PROJECT.md](./GUIDA_RMAN_BACKUP_SHAMS_PROJECT.md).
2. Crea il physical standby single non-CDB con
   [GUIDA_SHAMS_STANDBY_RMAN_SINGLE_NON_CDB.md](./GUIDA_SHAMS_STANDBY_RMAN_SINGLE_NON_CDB.md).
3. Per produzione `MAXPERFORMANCE` usa
   [GUIDA_SHAMS_PROD_MAXPERFORMANCE_WITH_RMAN.md](./GUIDA_SHAMS_PROD_MAXPERFORMANCE_WITH_RMAN.md).
4. Per refresh o nuova STG da produzione usa
   [GUIDA_SHAMS_MIGRATION_WITH_RMAN.md](./GUIDA_SHAMS_MIGRATION_WITH_RMAN.md).
5. Per incident recovery usa:
   [database danneggiato](./GUIDA_SHAMS_RMAN_RECOVERY_DATABASE_DANNEGGIATO.md),
   [restore su nuova istanza](./GUIDA_SHAMS_RMAN_RESTORE_DATABASE_SU_NUOVA_ISTANZA.md)
   oppure [tabella droppata](./GUIDA_SHAMS_RMAN_RECOVERY_TABELLA_DROPPATA.md).

## Procedure di recovery

| Guida | Quando usarla |
| --- | --- |
| [Recovery DB danneggiato](./GUIDA_SHAMS_RMAN_RECOVERY_DATABASE_DANNEGGIATO.md) | Datafile perso, tablespace corrotto, controlfile/SPFILE perso, blocchi corrotti o restore completo |
| [Restore su nuova istanza](./GUIDA_SHAMS_RMAN_RESTORE_DATABASE_SU_NUOVA_ISTANZA.md) | Ricostruzione su nuovo host avendo catalogo, backup pieces, pfile, password file o wallet |
| [Recovery tabella droppata](./GUIDA_SHAMS_RMAN_RECOVERY_TABELLA_DROPPATA.md) | `DROP TABLE`, recycle bin, `DROP PURGE`, RMAN `RECOVER TABLE`, clone auxiliary |

## Script RMAN pronti

Gli script operativi SHAMS sono in [scripts/](./scripts/):

| File | Uso |
| --- | --- |
| [scripts/rman_backup.sh](./scripts/rman_backup.sh) | wrapper backup RMAN con role detection e lock |
| [scripts/encrypt_pwd.sh](./scripts/encrypt_pwd.sh) | helper compatibile con il TXT; preferire wallet alias |
| [scripts/crontab_shams_example](./scripts/crontab_shams_example) | schedule SHAMS full/cumulative/differential/archive |
| [scripts/crontab_shams_prod_maxperformance_example](./scripts/crontab_shams_prod_maxperformance_example) | schedule produzione primary-backup per `M24SHAMSPEP/M24SHAMSSEP` |
| [scripts/cfg/](./scripts/cfg/) | config di esempio per collaudo e produzione SHAMS |
| [scripts/rman/](./scripts/rman/) | cmdfile RMAN per backup, cleanup e duplicate standby |

## Naming di default

| Oggetto | Valore |
| --- | --- |
| SHAMS primary | `M24SHAMSPEC` |
| SHAMS standby | `M24SHAMSSEC` |
| SHAMS produzione primary | `M24SHAMSPEP` |
| SHAMS produzione standby | `M24SHAMSSEP` |
| SHAMS `DB_NAME` | `M24SHAMS` |
| STG primary clonato | `M24STGPEC` |
| STG standby | `M24STGSEC` |
| STG `DB_NAME` | `M24STG` |

Compila sempre i placeholder prima di eseguire. I nomi sono esempi approvati per
la documentazione SHAMS e possono essere sostituiti solo con una convenzione
coerente con il limite Oracle sul `DB_NAME`.
