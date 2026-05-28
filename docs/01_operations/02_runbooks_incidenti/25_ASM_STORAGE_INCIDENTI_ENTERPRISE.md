# 25 - ASM e Storage: Incidenti Enterprise

<!-- READY_SCRIPTS_START -->
## Script pronti collegati

- [05_asm_storage.sql](../03_scripts_pronti/05_asm_storage.sql) - diskgroup, dischi ASM, capacity e rebalance.
- [03_fra_archivelog.sql](../03_scripts_pronti/03_fra_archivelog.sql) - FRA, archivelog e ORA-19809/ORA-00257.
<!-- READY_SCRIPTS_END -->

## Casi piu frequenti

- Diskgroup ASM sopra soglia o pieno.
- Rebalance lento o bloccato.
- Disco ASM `OFFLINE`, `FORMER`, `CANDIDATE` inatteso.
- Database non parte per file ASM non accessibile.
- Latenza storage alta con impatto su DBWR/LGWR/RMAN.
- FRA su ASM piena.
- Errore ORA-150xx / ORA-175xx / ORA-270xx.

## Regola operativa

Non cancellare file da ASM a mano. Prima capisci se il file e datafile, tempfile, redo, controlfile, archivelog, backup piece o file broker. In produzione ogni azione su ASM puo impattare piu database.

## Triage in 5 minuti

Come `grid`:

```bash
asmcmd lsdg
asmcmd ls +DATA
asmcmd ls +FRA
crsctl stat res -t
```

Da ASM:

```sql
sqlplus / as sysasm

SELECT name, state, type,
       ROUND(total_mb/1024) AS total_gb,
       ROUND(free_mb/1024) AS free_gb,
       ROUND(required_mirror_free_mb/1024) AS req_mirror_free_gb,
       ROUND(usable_file_mb/1024) AS usable_gb
FROM v$asm_diskgroup
ORDER BY name;

SELECT group_number, disk_number, name, path, header_status, mode_status,
       state, total_mb, free_mb, failgroup
FROM v$asm_disk
ORDER BY group_number, disk_number;

SELECT group_number, operation, state, power, actual, sofar, est_work,
       est_rate, est_minutes
FROM v$asm_operation;
```

Dal database:

```sql
SELECT name, open_mode, database_role FROM v$database;

SELECT file#, name, status FROM v$datafile ORDER BY file#;
SELECT file#, name, status FROM v$tempfile ORDER BY file#;

SELECT name,
       ROUND(space_limit/1024/1024/1024, 2) AS limit_gb,
       ROUND(space_used/1024/1024/1024, 2) AS used_gb,
       ROUND(space_reclaimable/1024/1024/1024, 2) AS reclaimable_gb
FROM v$recovery_file_dest;
```

## Scenario A - Diskgroup quasi pieno

1. Identifica se lo spazio e realmente utilizzabile:

```sql
SELECT name, total_mb, free_mb, required_mirror_free_mb, usable_file_mb
FROM v$asm_diskgroup
ORDER BY name;
```

2. Se il problema e FRA, non agire da ASM: usa RMAN/FRA.

```sql
SELECT file_type, percent_space_used, percent_space_reclaimable, number_of_files
FROM v$flash_recovery_area_usage
ORDER BY percent_space_used DESC;
```

3. Se il problema e data diskgroup, valuta:

- aggiunta LUN/dischi;
- resize ASM disk se storage lo consente;
- purge di oggetti applicativi solo con owner;
- spostamento backup fuori ASM se impropriamente collocati.

## Scenario B - Aggiunta disco ASM

Precheck OS:

```bash
lsblk
multipath -ll
oracleasm listdisks
oracleasm scandisks
```

Da ASM:

```sql
SELECT path, header_status, mode_status, state
FROM v$asm_disk
WHERE header_status IN ('CANDIDATE','FORMER','PROVISIONED')
ORDER BY path;
```

Aggiunta:

```sql
ALTER DISKGROUP DATA ADD DISK 'ORCL:DATA_EXP01' REBALANCE POWER 4;
```

Monitor:

```sql
SELECT operation, state, power, actual, sofar, est_work, est_minutes
FROM v$asm_operation;
```

## Scenario C - Rebalance lento

Controlla carico e stato:

```sql
SELECT operation, state, power, actual, est_minutes
FROM v$asm_operation;
```

Modifica power solo se accettato dal change owner:

```sql
ALTER DISKGROUP DATA REBALANCE POWER 8;
```

Riduci se impatta la produzione:

```sql
ALTER DISKGROUP DATA REBALANCE POWER 2;
```

## Scenario D - Disco offline o errore ORA-150xx

Raccogli evidenze:

```sql
SELECT name, path, header_status, mode_status, state, failgroup
FROM v$asm_disk
ORDER BY group_number, disk_number;

SELECT group_number, name, offline_disks, voting_files
FROM v$asm_diskgroup;
```

OS:

```bash
dmesg | tail -100
journalctl -xe | tail -100
multipath -ll
```

Azioni:

- se path sparito: coinvolgi storage/sysadmin;
- se disco torna visibile: `ALTER DISKGROUP ... ONLINE DISK`;
- se disco perso definitivamente: sostituzione LUN e rebalance;
- se OCR/voting coinvolti: apri war room, non improvvisare.

## Validazione finale

```sql
SELECT name, state, total_mb, free_mb, usable_file_mb
FROM v$asm_diskgroup
ORDER BY name;

SELECT * FROM v$asm_operation;
```

Dal database:

```sql
SELECT name, open_mode FROM v$database;
SELECT COUNT(*) FROM v$database_block_corruption;
```

## Cosa non fare

- Non usare `asmcmd rm` su file che non hai identificato.
- Non cancellare archivelog fuori da RMAN.
- Non portare un disco offline se non sai la redundancy del diskgroup.
- Non aumentare rebalance power in pieno picco senza valutare I/O.
- Non trattare `free_mb` come spazio realmente usabile senza `required_mirror_free_mb`.

## Evidence ticket

```text
Diskgroup:
Sintomo:
DB impattati:
Output asmcmd lsdg:
Output v$asm_diskgroup:
Output v$asm_disk:
Operazioni eseguite:
Validazione:
Rischio residuo:
```
