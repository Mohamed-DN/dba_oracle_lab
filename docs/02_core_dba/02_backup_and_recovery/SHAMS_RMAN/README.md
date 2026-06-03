# RMAN: Procedure Operative Oracle 19c

## Obiettivo operativo

Questa area raccoglie procedure RMAN applicabili in ambienti Oracle 19c con
Data Guard, Oracle Restart e recovery catalog. I comandi sono reali e devono
essere eseguiti solo dopo aver sostituito i placeholder con i valori approvati
nel change.

I file aziendali usati come fonte sono stati trasformati in template sicuri:
nessuna password, hostname reale o path sensibile viene riportato nel repository.

## Guide principali

| Guida | Uso |
| --- | --- |
| [RMAN Backup SHAMS Project](./SHAMS_PROJECT/GUIDA_RMAN_BACKUP_SHAMS_PROJECT.md) | Setup repository, wrapper, cmdfile, schedule e cleanup separato |
| [Standby SHAMS con RMAN](./SHAMS_PROJECT/GUIDA_SHAMS_STANDBY_RMAN_SINGLE_NON_CDB.md) | Creazione physical standby single non-CDB con active duplicate |
| [SHAMS Migration With RMAN](./SHAMS_PROJECT/GUIDA_SHAMS_MIGRATION_WITH_RMAN.md) | Clone produzione -> STG, rename/NID fallback e standby STG |

## Script SHAMS pronti

Per il progetto SHAMS usare prima la cartella
[SHAMS_PROJECT/scripts/](./SHAMS_PROJECT/scripts/). Contiene la versione
sanitizzata degli script del TXT: `rman_backup.sh`, `encrypt_pwd.sh`,
`crontab_shams_example`, config per `M24SHAMSPEC/M24SHAMSSEC` e cmdfile RMAN.

## Template

| Template | Uso |
| --- | --- |
| [rman_backup.sh](./templates/rman_backup.sh) | Wrapper backup con config esterna, lock e role detection |
| [rman_backup.conf.example](./templates/rman_backup.conf.example) | Config per database, catalog alias e policy |
| [crontab_example](./templates/crontab_example) | Schedule full/cumulative/differential/archivelog |
| [duplicate_standby_from_active.rcv](./templates/rman/duplicate_standby_from_active.rcv) | RMAN duplicate physical standby |
| [Cmdfile RMAN](./templates/rman/) | Level 0, cumulative, differential, archivelog e cleanup gated |
| [SQL checks](./templates/sql/) | Precheck e post-check Data Guard/RMAN |

## Regole di sicurezza

- Non mettere password in command line, crontab o file versionati.
- Usare wallet/SEPS o prompt interattivo per `SYS` e recovery catalog.
- Non usare base64 come protezione password: e' solo encoding.
- Non cancellare backup piece con `rm`, `find -delete` o script filesystem.
- Il cleanup dei backup deve passare da RMAN dopo gate di recuperabilita'.

## Fonti Oracle

- RMAN duplicate: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-duplicating-databases.html
- RMAN in Data Guard: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/using-RMAN-in-oracle-data-guard-configurations.html
- DBNEWID/NID: https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-dbnewid-utility.html
- Data Guard MAA: https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/configure-and-deploy-oracle-data-guard.html
