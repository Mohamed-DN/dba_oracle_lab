# 02 — Verifica Backup RMAN

> ⏱️ Tempo: 5 minuti | 📅 Frequenza: Ogni mattina | 👤 Chi: DBA on-call

---

## Obiettivo

Verificare che tutti i backup notturni siano andati a buon fine e che la recovery sia possibile.

---

## Step 1: Stato Ultimo Ciclo di Backup

```sql
sqlplus / as sysdba

-- Backup delle ultime 48 ore
SELECT input_type,
       status,
       TO_CHAR(start_time, 'DD-MON HH24:MI') AS started,
       TO_CHAR(end_time, 'DD-MON HH24:MI') AS ended,
       ROUND(elapsed_seconds/60) AS min,
       ROUND(output_bytes/1024/1024/1024, 2) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time > SYSDATE - 2
ORDER BY start_time DESC;
```

| Status | Significato | Azione |
|---|---|---|
| `COMPLETED` | ✅ OK | Nessuna |
| `COMPLETED WITH WARNINGS` | ⚠️ Funzionato con avvisi | Controlla warning nel log |
| `COMPLETED WITH ERRORS` | 🔴 Errori parziali | Verifica quali file mancano |
| `FAILED` | 🔴 Fallito | Investigare subito |
| `RUNNING` | 🔄 In corso | Monitorare avanzamento |

## Step 2: Backup Più Recente per Tipo

```sql
-- Ultimo backup per ogni tipo
SELECT input_type,
       MAX(TO_CHAR(start_time, 'DD-MON-YY HH24:MI')) AS ultimo_backup,
       ROUND(SYSDATE - MAX(start_time), 1) AS giorni_fa
FROM v$rman_backup_job_details
WHERE status IN ('COMPLETED', 'COMPLETED WITH WARNINGS')
GROUP BY input_type
ORDER BY MAX(start_time) DESC;

-- ⚠️ Se DB FULL > 7 giorni → problema!
-- ⚠️ Se ARCHIVELOG > 1 giorno → problema!
```

## Step 3: Verifica Integrità (VALIDATE)

```bash
# Connettiti a RMAN
rman TARGET /

# Validate dei backup (NON esegue restore, solo verifica leggibilità)
RMAN> CROSSCHECK BACKUP;
RMAN> CROSSCHECK ARCHIVELOG ALL;

# Verifica se i backup sono restoribili
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RESTORE ARCHIVELOG ALL VALIDATE;
```

## Step 4: Backup Obsoleti e Pulizia

```bash
RMAN> REPORT OBSOLETE;

# Se ci sono backup obsoleti, pulisci
RMAN> DELETE OBSOLETE;
# Conferma con YES

# Verifica expired (file spariti dal disco)
RMAN> DELETE EXPIRED BACKUP;
RMAN> DELETE EXPIRED ARCHIVELOG ALL;
```

## Step 5: Controlfile e SPFILE

```sql
-- Verifica che autobackup controlfile sia attivo
SHOW PARAMETER control_file_record_keep_time;

-- Da RMAN:
RMAN> SHOW CONTROLFILE AUTOBACKUP;
-- ATTESO: CONFIGURE CONTROLFILE AUTOBACKUP ON
```

## Step 6: FRA e Spazio Backup

```sql
-- Flash Recovery Area usage
SELECT
    file_type,
    ROUND(percent_space_used, 1) AS pct_used,
    ROUND(percent_space_reclaimable, 1) AS pct_reclaimable,
    number_of_files
FROM v$flash_recovery_area_usage
WHERE percent_space_used > 0
ORDER BY percent_space_used DESC;

-- Totale FRA
SELECT name,
       ROUND(space_limit/1024/1024/1024, 1) AS limit_gb,
       ROUND(space_used/1024/1024/1024, 1) AS used_gb,
       ROUND(space_used/space_limit * 100, 1) AS pct_used
FROM v$recovery_file_dest;
```

---

## 🔴 Se il Backup è FAILED

```bash
# 1. Trova il log del backup fallito
RMAN> LIST BACKUP SUMMARY;

# 2. Controlla il log RMAN
cat /home/oracle/scripts/logs/rman_*.log | tail -100

# 3. Cause comuni:
# - FRA piena → DELETE OBSOLETE, espandi FRA
# - Disco pieno → controlla df -h
# - Archivelog mancanti → verifica gap DG
# - Timeout → aumenta RMAN timeout
# - Canale fallito → verifica ASM

# 4. Rilancia backup manualmente
RMAN> BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 DATABASE
      PLUS ARCHIVELOG DELETE INPUT;
```

---

## ✅ Check di Conferma

| Controllo | Atteso |
|---|---|
| Ultimo backup DB | < 24 ore |
| Ultimo backup archivelog | < 12 ore |
| CROSSCHECK | Tutti AVAILABLE |
| RESTORE VALIDATE | Successo |
| Autobackup controlfile | ON |
| FRA usage | < 85% |
