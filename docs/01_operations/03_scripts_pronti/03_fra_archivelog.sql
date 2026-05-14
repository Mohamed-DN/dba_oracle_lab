-- ============================================================================
-- SCRIPT 03: FRA E ARCHIVELOG — Monitoraggio e Pulizia
-- Scenario: FRA piena, archivelog che crescono, DB suspended
-- Errori: ORA-19815, ORA-00257, "ARCH: Error archiving" 
-- ⚠️ SE LA FRA SI RIEMPIE IL DATABASE SI BLOCCA (HANG/SUSPEND)!
-- ============================================================================

PROMPT ====================================================================
PROMPT  1. STATO FRA (Flash Recovery Area / Fast Recovery Area)
PROMPT ====================================================================

COL name FOR A50
COL space_limit_gb FOR 999.99
COL space_used_gb FOR 999.99
COL space_reclaimable_gb FOR 999.99
COL pct_used FOR 999.9

SELECT
    name,
    ROUND(space_limit/1024/1024/1024, 2) AS space_limit_gb,
    ROUND(space_used/1024/1024/1024, 2) AS space_used_gb,
    ROUND(space_reclaimable/1024/1024/1024, 2) AS space_reclaimable_gb,
    ROUND((space_used - space_reclaimable) * 100 / NULLIF(space_limit, 0), 1) AS pct_used,
    number_of_files
FROM v$recovery_file_dest;


PROMPT ====================================================================
PROMPT  2. DETTAGLIO FRA — Cosa occupa spazio
PROMPT ====================================================================

COL file_type FOR A25
COL pct_space_used FOR 999.9
COL pct_space_reclaimable FOR 999.9
COL number_of_files FOR 9999

SELECT
    file_type,
    ROUND(percent_space_used, 1) AS pct_space_used,
    ROUND(percent_space_reclaimable, 1) AS pct_space_reclaimable,
    number_of_files
FROM v$flash_recovery_area_usage
ORDER BY percent_space_used DESC;


PROMPT ====================================================================
PROMPT  3. PARAMETRI FRA CORRENTI
PROMPT ====================================================================

COL name FOR A40
COL value FOR A60
SELECT name, value FROM v$parameter
WHERE name IN ('db_recovery_file_dest', 'db_recovery_file_dest_size', 'log_archive_dest_1', 'log_archive_dest_2', 'log_archive_dest_state_1', 'log_archive_dest_state_2')
ORDER BY name;


PROMPT ====================================================================
PROMPT  4. ARCHIVELOG — Volume generato nelle ultime 24h
PROMPT ====================================================================

COL day FOR A12
COL count_logs FOR 9999
COL total_gb FOR 999.99

SELECT
    TO_CHAR(completion_time, 'DD-MON HH24') AS day,
    COUNT(*) AS count_logs,
    ROUND(SUM(blocks * block_size)/1024/1024/1024, 2) AS total_gb
FROM v$archived_log
WHERE completion_time > SYSDATE - 1
  AND dest_id = 1
GROUP BY TO_CHAR(completion_time, 'DD-MON HH24')
ORDER BY day;


PROMPT ====================================================================
PROMPT  5. ARCHIVELOG — Volume per giorno (ultima settimana)
PROMPT ====================================================================

SELECT
    TO_CHAR(completion_time, 'DD-MON-YYYY') AS giorno,
    COUNT(*) AS num_logs,
    ROUND(SUM(blocks * block_size)/1024/1024/1024, 2) AS total_gb
FROM v$archived_log
WHERE completion_time > SYSDATE - 7
  AND dest_id = 1
GROUP BY TO_CHAR(completion_time, 'DD-MON-YYYY')
ORDER BY giorno;


PROMPT ====================================================================
PROMPT  6. ARCHIVELOG DESTINATIONS — Stato e errori
PROMPT ====================================================================

COL dest_name FOR A25
COL status FOR A10
COL destination FOR A50
COL error FOR A30

SELECT dest_name, status, type, destination, error
FROM v$archive_dest
WHERE status != 'INACTIVE'
ORDER BY dest_id;


PROMPT ====================================================================
PROMPT  7. LOG SWITCH — Frequenza (troppe switch = troppi archivelog)
PROMPT ====================================================================

-- Se fai più di 3-4 switch/ora, i redo log sono troppo piccoli o c'è carico anomalo.

SELECT
    TO_CHAR(first_time, 'DD-MON HH24') AS ora,
    COUNT(*) AS switches
FROM v$log_history
WHERE first_time > SYSDATE - 1
GROUP BY TO_CHAR(first_time, 'DD-MON HH24')
ORDER BY ora;


PROMPT ====================================================================
PROMPT  8. ⚠️ SOLUZIONI — FRA piena (EMERGENZA!)
PROMPT ====================================================================

-- ---- SITUAZIONE: FRA > 95% → il DB rischia il SUSPEND! ----
--
-- FIX 1: Pulizia con RMAN (più sicuro)
-- rman target /
-- RMAN> CROSSCHECK ARCHIVELOG ALL;
-- RMAN> DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
-- RMAN> DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-2';
-- RMAN> DELETE NOPROMPT OBSOLETE;
--
-- FIX 2: Aumenta FRA (se hai spazio disco)
-- ALTER SYSTEM SET db_recovery_file_dest_size = 100G SCOPE=BOTH;
--
-- FIX 3: Sposta la destinazione archivelog FUORI dalla FRA
-- ALTER SYSTEM SET log_archive_dest_1 = 'LOCATION=/u01/archive' SCOPE=BOTH;
-- ⚠️ Piano B, solo se i backup non usano la FRA.
--
-- FIX 4: Cancella flashback log (se non serve)
-- ALTER DATABASE FLASHBACK OFF;
-- ALTER DATABASE FLASHBACK ON;

-- ---- PREVENZIONE: monitorare ogni giorno ----
-- Se pct_used > 80%, agisci SUBITO. Non aspettare il 95%.

PROMPT ====================================================================
PROMPT  9. IMPATTO DATA PUMP SULLA FRA
PROMPT ====================================================================

-- Data Pump (expdp/impdp) può saturare la FRA indirettamente:
-- 1. IMPORT genera REDO LOG → archivelog → riempie la FRA!
-- 2. Un import di 50GB può generare 50-100GB di archivelog
--
-- PRIMA DI UN IMPORT GRANDE:
-- a) Controlla la FRA (sez. 1 sopra)
-- b) Pulisci gli archivelog vecchi (sez. 8 sopra)
-- c) Considera di usare NOLOGGING per tabelle grandi:
--    ALTER TABLE schema.tabella NOLOGGING;
--    -- dopo l'import:
--    ALTER TABLE schema.tabella LOGGING;
--
-- DURANTE L'IMPORT: monitorare con:
-- SELECT ROUND(space_used*100/space_limit, 1) AS pct FROM v$recovery_file_dest;

PROMPT ====================================================================
PROMPT  10. VERIFICA — DB NON è in SUSPEND
PROMPT ====================================================================

SELECT database_status FROM v$instance;
-- DEVE essere ACTIVE. Se è "SUSPENDED" → la FRA è piena!

SELECT * FROM v$blocking_quiesce;

PROMPT ====================================================================
PROMPT  Fine Script 03 — FRA & Archivelog
PROMPT ====================================================================
