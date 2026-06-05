# Standard Enterprise Directory Backup RMAN Oracle 19c

## Obiettivi

Definire una struttura unica e leggibile per backup Oracle RMAN 19c, log,
report ed evidenze. La Fast Recovery Area ASM `+RECO` resta un'area operativa:
non sostituisce il repository durevole montato su filesystem.

La baseline Data Guard usa due catene RMAN complete e indipendenti:

- primary `RACDB`;
- physical standby `RACDB_STBY`, anche quando resta in `MOUNT`.

Il recovery catalog e' obbligatorio in produzione Data Guard. Prima di questa
guida completa [CATRMAN: Recovery Catalog RMAN 19c](./GUIDA_RMAN_CATALOGO_CATRMAN_19C.md).
Ogni backup e' associato al relativo `DB_UNIQUE_NAME`, quindi il nome condiviso
`DB_NAME=RACDB` non basta per separare le catene.

## Architettura Delle Directory

La share centrale e' montata con lo stesso path su primary e standby:

```text
/backup/
+-- rman/
|   +-- RACDB/
|   |   +-- pieces/{database,archivelog,controlfile,spfile}/
|   |   +-- metadata/
|   |   +-- logs/{backup,validate,cleanup}/
|   |   +-- reports/
|   |   +-- evidence/
|   |   +-- tmp/
|   +-- RACDB_STBY/
|       +-- stessa struttura
+-- datapump/
+-- xtts/
+-- manual/
```

`/backup/rman` deve essere una share di backup reale, raggiungibile dai due
siti e monitorata dalla macchina centrale o da OEM. Non confonderla con:

| Area | Uso |
| --- | --- |
| `+RECO` | FRA: archivelog, flashback log e file gestiti da Oracle |
| `/backup/rman/<DB_UNIQUE_NAME>` | backupset RMAN, log, status ed evidenze durevoli |
| `/backup/datapump` | export logici Data Pump |
| `/backup/xtts` | staging XTTS |
| `/backup/manual` | backup patching, PDB unplug e copie approvate ad hoc |

## Procedura Operativa

### 1. Preflight Storage

Prima di schedulare i job:

```bash
mountpoint -q /backup/rman
df -h /backup/rman
test -w /backup/rman
```

Verifica latenza, capacita', protezione della share e ownership
`oracle:oinstall`. Il mount deve essere stabile dopo reboot. Un path locale
creato per errore quando la share e' smontata non e' un backup valido.

### 2. Configurazione RMAN

Connettiti localmente con autenticazione OS e usa un alias wallet per il
recovery catalog. Non mettere password negli argomenti shell.

```bash
rman target / catalog /@RMAN_CATALOG
```

Sul primary:

```rman
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO
  '/backup/rman/RACDB/pieces/controlfile/%F';
CONFIGURE SNAPSHOT CONTROLFILE NAME TO
  '/backup/rman/RACDB/metadata/snapcf_RACDB.f';
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
CONFIGURE ARCHIVELOG DELETION POLICY TO
  APPLIED ON ALL STANDBY BACKED UP 1 TIMES TO DEVICE TYPE DISK;
```

Sullo standby terminale usa la directory `RACDB_STBY` e:

```rman
CONFIGURE ARCHIVELOG DELETION POLICY TO
  BACKED UP 1 TIMES TO DEVICE TYPE DISK;
```

`BASIC` e' la baseline. `LOW`, `MEDIUM` e `HIGH` richiedono il gate licenza
Advanced Compression.

### 3. Frequenze

I job sono sfalsati per evitare picchi I/O contemporanei:

| Job | Standby | Primary |
| --- | ---: | ---: |
| Level 0 domenicale | `01:00` | `04:00` |
| Level 1 lun-sab | `01:00` | `04:00` |
| Archivelog ogni 2 ore | minuto `15` | minuto `45` |
| Cleanup gated domenicale | `08:00` | `09:00` |

Ogni ciclo include controlfile e SPFILE espliciti. Il backup non contiene
comandi `DELETE`.

### 4. Status Per OEM

La share espone file semplici da monitorare:

```text
reports/latest_backup.status
reports/latest_validate.status
reports/latest_cleanup.status
```

Esempio:

```text
STATUS=SUCCESS
TIMESTAMP=2026-06-01T04:00:00Z
HOST=rac1
DB_UNIQUE_NAME=RACDB
DATABASE_ROLE=PRIMARY
BACKUP_TYPE=LEVEL1
LOG=/backup/rman/RACDB/logs/backup/backup_level1_20260601T040000Z.log
EVIDENCE=/backup/rman/RACDB/evidence/backup_level1_20260601T040000Z.txt
```

### 5. Cleanup Separato

Il cleanup e' una procedura autorizzata distinta dal backup:

1. verifica mount, spazio, catalogo, ruolo e `DB_UNIQUE_NAME`;
2. blocca l'esecuzione se un backup RMAN e' in corso;
3. richiede almeno due Level 0, due controlfile e due SPFILE recuperabili;
4. verifica continuita' archivelog, sequenze applied e `V$ARCHIVE_GAP` solo
   sullo standby;
5. salva evidenze pre-cleanup;
6. esegue `CROSSCHECK`, `REPORT OBSOLETE` e `LIST EXPIRED`;
7. cancella esclusivamente tramite RMAN secondo deletion policy;
8. salva report post-cleanup e status finale.

Sono vietati nei job periodici:

- `DELETE FORCE`;
- `DELETE INPUT` e `DELETE ALL INPUT`;
- purge `.bkp` tramite `find`, `rm` o script filesystem.

Ruota solo output testuali: comprimi log oltre 7 giorni, elimina log e report
oltre 30 giorni, elimina evidence oltre 90 giorni salvo hold formale.

### 6. Automazione Ansible

Usa:

```bash
ansible-playbook -i inventory/production.ini playbooks/rman_schedule.yml
ansible-playbook -i inventory/production.ini playbooks/rman_backup.yml \
  -e rman_backup_type=LEVEL0
ansible-playbook -i inventory/production.ini playbooks/rman_cleanup.yml
```

Il ruolo `oracle_rman_backup` e' backup-only. Il ruolo `oracle_rman_cleanup`
contiene i gate e gira serialmente su primo nodo primary e primo nodo standby.

## Validazione Finale

Verifica su entrambe le catene:

```bash
find /backup/rman/RACDB /backup/rman/RACDB_STBY -maxdepth 3 -type d | sort
grep '^STATUS=' /backup/rman/*/reports/latest_*.status
```

In RMAN:

```rman
LIST DB_UNIQUE_NAME OF DATABASE;
LIST BACKUP SUMMARY;
SHOW ARCHIVELOG DELETION POLICY;
REPORT OBSOLETE;
```

Conserva l'output di almeno un `RESTORE DATABASE VALIDATE` e prova un restore
controllato. La presenza dei file non dimostra da sola che il restore funzioni.

## Troubleshooting Rapido

| Sintomo | Verifica | Azione |
| --- | --- | --- |
| `/backup/rman` non montato | `mountpoint`, `df -h` | blocca il job; non scrivere su un path locale accidentale |
| FRA `+RECO` piena | alert log, deletion policy, lag e gap | usa DG-061; non cancellare archivelog alla cieca |
| Cleanup bloccato | evidence `cleanup_gate_*` | ricrea una seconda catena valida o riallinea Data Guard |
| Backup non visibile | catalogo e `DB_UNIQUE_NAME` | verifica registrazione catalogo e path della catena corretta |
| Status OEM vecchio | timestamp e log associato | controlla cron, lock e ultimo errore RMAN |

Per FRA piena con standby in lag usa
[DG-061](../../01_operations/02_runbooks_incidenti/RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md#dg-061---primary-fra-piena-per-standby-lag).

## Fonti Oracle

- [RMAN con Data Guard](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/using-RMAN-in-oracle-data-guard-configurations.html)
- [RMAN CONFIGURE](https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/CONFIGURE.html)
- [RMAN DELETE](https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/DELETE.html)
- [RMAN BACKUP](https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/BACKUP.html)
- [Fast Recovery Area](https://docs.oracle.com/en/database/oracle/oracle-database/19/cwhpx/about-the-fast-recoveryarea.html)
