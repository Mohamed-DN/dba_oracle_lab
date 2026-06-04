# Script RMAN SHAMS Project

Questa cartella contiene la versione SHAMS, sanitizzata e pronta da adattare,
degli script RMAN passati nel TXT aziendale.

Non contiene password, host reali o nomi aziendali originali. Prima
dell'installazione sostituire solo i placeholder tra `<...>` e verificare i path
Oracle del server.

## Mapping dal TXT

| Artefatto nel TXT aziendale | File in questa cartella |
| --- | --- |
| wrapper backup RMAN | `rman_backup.sh` |
| helper encoding password | `encrypt_pwd.sh` |
| esempio crontab collaudo | `crontab_shams_example` |
| esempio crontab produzione | `crontab_shams_prod_maxperformance_example` |
| `cfg/rman_backup_<DB_UNIQUE_NAME>.conf` collaudo | `cfg/rman_backup_M24SHAMSPEC.conf.example` e `cfg/rman_backup_M24SHAMSSEC.conf.example` |
| `cfg/rman_backup_<DB_UNIQUE_NAME>.conf` produzione | `cfg/rman_backup_M24SHAMSPEP.conf.example` e `cfg/rman_backup_M24SHAMSSEP.conf.example` |
| `rman/bck_full_*` | `rman/bck_full_primary.rcv` e `rman/bck_full_standby.rcv` |
| `rman/bck_incr_cumulative_*` | `rman/bck_incr_cumulative_primary.rcv` e `rman/bck_incr_cumulative_standby.rcv` |
| `rman/bck_incr_differential_*` | `rman/bck_incr_differential_primary.rcv` e `rman/bck_incr_differential_standby.rcv` |
| `rman/bck_archive_*` | `rman/bck_archive_primary.rcv` e `rman/bck_archive_standby.rcv` |
| `duplicate.rcv` | `rman/duplicate_standby_from_active.rcv` |

## Installazione consigliata

Sul nodo Oracle che esegue i job:

```bash
export SCRIPT_DIR=/opt/oracle/rman_scripts
mkdir -p "$SCRIPT_DIR"/{cfg,rman,logs}
cp rman_backup.sh encrypt_pwd.sh crontab_shams_example "$SCRIPT_DIR/"
cp crontab_shams_prod_maxperformance_example "$SCRIPT_DIR/"
cp cfg/rman_backup_M24SHAMSSEC.conf.example "$SCRIPT_DIR/cfg/rman_backup_M24SHAMSSEC.conf"
cp cfg/rman_backup_M24SHAMSPEC.conf.example "$SCRIPT_DIR/cfg/rman_backup_M24SHAMSPEC.conf"
cp rman/*.rcv "$SCRIPT_DIR/rman/"
chmod 750 "$SCRIPT_DIR"/rman_backup.sh "$SCRIPT_DIR"/encrypt_pwd.sh
chmod 640 "$SCRIPT_DIR"/cfg/*.conf "$SCRIPT_DIR"/rman/*.rcv
```

Poi compilare i placeholder nelle config e caricare la schedule:

```bash
crontab crontab_shams_example
```

Per produzione `M24SHAMSPEP/M24SHAMSSEP`, copiare invece:

```bash
cp cfg/rman_backup_M24SHAMSPEP.conf.example "$SCRIPT_DIR/cfg/rman_backup_M24SHAMSPEP.conf"
cp cfg/rman_backup_M24SHAMSSEP.conf.example "$SCRIPT_DIR/cfg/rman_backup_M24SHAMSSEP.conf"
crontab crontab_shams_prod_maxperformance_example
```

## Uso rapido

```bash
/opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC full
/opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC cumulative
/opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEC differential
/opt/oracle/rman_scripts/rman_backup.sh M24SHAMSPEC archive
/opt/oracle/rman_scripts/rman_backup.sh M24SHAMSPEP full
/opt/oracle/rman_scripts/rman_backup.sh M24SHAMSSEP archive
```

Il wrapper usa wallet alias per il catalogo RMAN (`/@RMAN_CATALOG`) e OS
authentication per il target (`/`). Evitare password in chiaro nei comandi e nei
file di configurazione.
