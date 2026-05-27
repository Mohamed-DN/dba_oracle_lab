-- ============================================================================
-- SCRIPT 08: RMAN E BACKUP STATUS
-- Scenario: Morning check backup, pre-upgrade validation
-- ============================================================================

-- Runbook collegati:
--   - ../02_runbooks_incidenti/02_VERIFICA_BACKUP.md
--   - ../02_runbooks_incidenti/19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md
--   - ../02_runbooks_incidenti/22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md
-- Uso rapido:
--   sqlplus / as sysdba @08_rman_backup_status.sql
-- Nota: verificare sempre ambiente, ruolo database e privilegi prima di eseguire azioni correttive.
SET LINESIZE 220
SET PAGESIZE 200
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT ====================================================================
PROMPT  1. ULTIMO BACKUP — Riepilogo per tipo
PROMPT ====================================================================

COL input_type FOR A22
COL status FOR A12
COL start_time FOR A18
COL end_time FOR A18
COL duration_min FOR 999,999
COL input_gb FOR 999,999.99
COL output_gb FOR 999,999.99

SELECT
    input_type, status,
    TO_CHAR(start_time, 'DD-MON-YY HH24:MI') AS start_time,
    TO_CHAR(end_time, 'DD-MON-YY HH24:MI') AS end_time,
    ROUND(elapsed_seconds/60) AS duration_min,
    ROUND(input_bytes/1024/1024/1024, 2) AS input_gb,
    ROUND(output_bytes/1024/1024/1024, 2) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time > SYSDATE - 7
ORDER BY start_time DESC;


PROMPT ====================================================================
PROMPT  2. ⚠️ BACKUP FALLITI (ultimi 7 giorni)
PROMPT ====================================================================

SELECT
    input_type, status,
    TO_CHAR(start_time, 'DD-MON-YY HH24:MI') AS start_time,
    output_device_type
FROM v$rman_backup_job_details
WHERE status NOT IN ('COMPLETED', 'RUNNING')
  AND start_time > SYSDATE - 7
ORDER BY start_time DESC;

-- Se non esce nulla → 0 fallimenti → OK!


PROMPT ====================================================================
PROMPT  3. ULTIMO BACKUP PER DATAFILE (per verifica completa)
PROMPT ====================================================================

COL file# FOR 9999
COL tablespace FOR A20
COL last_backup FOR A18
COL hours_ago FOR 999,999

SELECT
    f.file#,
    f.tablespace_name AS tablespace,
    TO_CHAR(b.completion_time, 'DD-MON-YY HH24:MI') AS last_backup,
    ROUND((SYSDATE - b.completion_time) * 24) AS hours_ago
FROM dba_data_files f
LEFT JOIN (
    SELECT file#, MAX(completion_time) AS completion_time
    FROM v$backup_datafile
    GROUP BY file#
) b ON f.file_id = b.file#
ORDER BY b.completion_time ASC NULLS FIRST;


PROMPT ====================================================================
PROMPT  4. BACKUP IN ESECUZIONE
PROMPT ====================================================================

COL sid FOR 99999
COL operation FOR A25
COL pct_done FOR 999.9
COL elapsed_min FOR 999,999
COL remaining_min FOR 999,999

SELECT sid, serial#, opname AS operation,
       ROUND(sofar/NULLIF(totalwork,0)*100, 1) AS pct_done,
       ROUND(elapsed_seconds/60) AS elapsed_min,
       ROUND(time_remaining/60) AS remaining_min
FROM v$session_longops
WHERE opname LIKE 'RMAN%'
  AND sofar != totalwork
ORDER BY start_time DESC;


PROMPT ====================================================================
PROMPT  5. CONFIGURAZIONE RMAN CORRENTE
PROMPT ====================================================================

-- Esegui da RMAN: SHOW ALL;
-- Da SQL:
COL name FOR A45
COL value FOR A60
SELECT name, value FROM v$rman_configuration ORDER BY name;


PROMPT ====================================================================
PROMPT  6. ARCHIVELOG NON BACKUPPATI
PROMPT ====================================================================

SELECT COUNT(*) AS archivelog_non_backuppati
FROM v$archived_log
WHERE backup_count = 0
  AND deleted = 'NO'
  AND completion_time > SYSDATE - 7;

-- Se > 0, fai immediatamente:
-- rman target /
-- RMAN> BACKUP ARCHIVELOG ALL NOT BACKED UP;

PROMPT ====================================================================
PROMPT  Fine Script 08 — RMAN & Backup Status
PROMPT ====================================================================
