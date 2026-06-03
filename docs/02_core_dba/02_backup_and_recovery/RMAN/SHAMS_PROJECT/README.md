# SHAMS Project RMAN

## Percorso operativo

1. Installa e valida il backup RMAN con
   [GUIDA_RMAN_BACKUP_SHAMS_PROJECT.md](./GUIDA_RMAN_BACKUP_SHAMS_PROJECT.md).
2. Crea il physical standby single non-CDB con
   [GUIDA_SHAMS_STANDBY_RMAN_SINGLE_NON_CDB.md](./GUIDA_SHAMS_STANDBY_RMAN_SINGLE_NON_CDB.md).
3. Per refresh o nuova STG da produzione usa
   [GUIDA_SHAMS_MIGRATION_WITH_RMAN.md](./GUIDA_SHAMS_MIGRATION_WITH_RMAN.md).

## Naming di default

| Oggetto | Valore |
| --- | --- |
| SHAMS primary | `M24SHAMSPEC` |
| SHAMS standby | `M24SHAMSSEC` |
| SHAMS `DB_NAME` | `M24SHAMS` |
| STG primary clonato | `M24STGPEC` |
| STG standby | `M24STGSEC` |
| STG `DB_NAME` | `M24STG` |

Compila sempre i placeholder prima di eseguire. I nomi sono esempi approvati per
la documentazione SHAMS e possono essere sostituiti solo con una convenzione
coerente con il limite Oracle sul `DB_NAME`.
