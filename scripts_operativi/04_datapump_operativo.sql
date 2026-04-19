-- ============================================================================
-- SCRIPT 04: DATA PUMP OPERATIVO — Export/Import con Monitoraggio
-- Scenario: expdp/impdp sicuri in produzione senza far cadere il DB
-- ⚠️ Data Pump genera REDO → ARCHIVELOG → riempie FRA → DB SUSPEND!
-- ============================================================================

PROMPT ====================================================================
PROMPT  1. PRE-CHECK PRIMA DI UN DATA PUMP
PROMPT ====================================================================

-- Verifica TUTTO prima di lanciare un export/import:

PROMPT --- 1A. Spazio FRA ---
SELECT
    ROUND(space_limit/1024/1024/1024, 2) AS fra_limit_gb,
    ROUND(space_used/1024/1024/1024, 2) AS fra_used_gb,
    ROUND((space_used) * 100 / NULLIF(space_limit, 0), 1) AS pct_used
FROM v$recovery_file_dest;
-- ⚠️ Se > 70%, pulisci PRIMA di fare l'import!

PROMPT --- 1B. Spazio UNDO ---
SELECT tablespace_name, ROUND(used_percent, 1) AS pct
FROM dba_tablespace_usage_metrics
WHERE tablespace_name LIKE '%UNDO%';
-- ⚠️ Se > 80%, non fare import grandi

PROMPT --- 1C. Spazio TEMP ---
SELECT tablespace_name,
       ROUND(allocated_space * 100 / NULLIF(tablespace_size, 0), 1) AS pct_used
FROM dba_temp_free_space;

PROMPT --- 1D. Spazio tablespace target ---
SELECT tablespace_name, ROUND(used_percent, 1) AS pct
FROM dba_tablespace_usage_metrics
WHERE used_percent > 70
ORDER BY used_percent DESC;


PROMPT ====================================================================
PROMPT  2. DIRECTORY DATA PUMP — Dove esportare/importare
PROMPT ====================================================================

COL owner FOR A15
COL directory_name FOR A25
COL directory_path FOR A60

SELECT owner, directory_name, directory_path
FROM dba_directories
WHERE directory_name LIKE '%DATA%PUMP%'
   OR directory_name = 'DATA_PUMP_DIR'
ORDER BY directory_name;

-- CREA DIRECTORY (se non esiste):
-- CREATE OR REPLACE DIRECTORY DPUMP_DIR AS '/u01/dpump';
-- GRANT READ, WRITE ON DIRECTORY DPUMP_DIR TO schema_owner;


PROMPT ====================================================================
PROMPT  3. MONITORARE DATA PUMP IN ESECUZIONE
PROMPT ====================================================================

-- 3A. Job Data Pump attivi
COL owner_name FOR A15
COL job_name FOR A25
COL operation FOR A10
COL job_mode FOR A10
COL state FOR A12

SELECT owner_name, job_name, operation, job_mode, state,
       attached_sessions
FROM dba_datapump_jobs
WHERE state != 'NOT RUNNING';


-- 3B. Progresso dettagliato (percentuale)
COL message FOR A80
SELECT sid, serial#, opname,
       ROUND(sofar/NULLIF(totalwork, 0) * 100, 1) AS pct_done,
       ROUND(elapsed_seconds/60, 1) AS elapsed_min,
       message
FROM v$session_longops
WHERE opname LIKE 'DATAPUMP%' OR opname LIKE '%EXPORT%' OR opname LIKE '%IMPORT%'
ORDER BY start_time DESC;


-- 3C. Sessioni Data Pump (per kill se necessario)
SELECT s.sid, s.serial#, s.username, s.program, s.status,
       ROUND(t.used_ublk * 8192 / 1024/1024, 1) AS undo_mb
FROM v$session s
LEFT JOIN v$transaction t ON s.saddr = t.ses_addr
WHERE s.program LIKE '%DM%' OR s.program LIKE '%DW%'
ORDER BY undo_mb DESC NULLS LAST;


PROMPT ====================================================================
PROMPT  4. MONITORARE IMPATTO FRA DURANTE L'IMPORT
PROMPT ====================================================================

-- Esegui questo ogni 5 minuti durante un import grande:
SELECT
    TO_CHAR(SYSDATE, 'HH24:MI:SS') AS ora,
    ROUND(space_used * 100 / NULLIF(space_limit, 0), 1) AS fra_pct
FROM v$recovery_file_dest;

-- Se supera l'80%, fai SUBITO:
-- rman target /
-- RMAN> DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-1';


PROMPT ====================================================================
PROMPT  5. COMANDI EXPORT (expdp) — Template Produzione
PROMPT ====================================================================

-- ---- EXPORT SCHEMA (il più comune) ----
-- expdp system/password \
--   DIRECTORY=DPUMP_DIR \
--   DUMPFILE=schema_export_%U.dmp \
--   LOGFILE=schema_export.log \
--   SCHEMAS=HR \
--   PARALLEL=4 \
--   FILESIZE=10G \
--   COMPRESSION=ALL

-- ---- EXPORT TABELLA SINGOLA ----
-- expdp system/password \
--   DIRECTORY=DPUMP_DIR \
--   DUMPFILE=tabella_export.dmp \
--   LOGFILE=tabella_export.log \
--   TABLES=HR.EMPLOYEES

-- ---- EXPORT FULL DATABASE ----
-- ⚠️ Solo con spazio disco sufficiente!
-- expdp system/password \
--   DIRECTORY=DPUMP_DIR \
--   DUMPFILE=full_%U.dmp \
--   LOGFILE=full_export.log \
--   FULL=Y \
--   PARALLEL=4 \
--   FILESIZE=10G \
--   COMPRESSION=ALL


PROMPT ====================================================================
PROMPT  6. COMANDI IMPORT (impdp) — Template Produzione
PROMPT ====================================================================

-- ---- IMPORT SCHEMA ----
-- impdp system/password \
--   DIRECTORY=DPUMP_DIR \
--   DUMPFILE=schema_export_%U.dmp \
--   LOGFILE=schema_import.log \
--   SCHEMAS=HR \
--   REMAP_SCHEMA=HR:HR_TEST \
--   REMAP_TABLESPACE=USERS:USERS_TEST \
--   TABLE_EXISTS_ACTION=REPLACE

-- ---- IMPORT CON TRANSFORM (no storage clause) ----
-- impdp system/password \
--   DIRECTORY=DPUMP_DIR \
--   DUMPFILE=schema_export.dmp \
--   LOGFILE=import.log \
--   SCHEMAS=HR \
--   TRANSFORM=SEGMENT_ATTRIBUTES:N \
--   TABLE_EXISTS_ACTION=REPLACE

-- ---- IMPORT IN PARALLELO (accelera ma genera più redo!) ----
-- impdp system/password \
--   DIRECTORY=DPUMP_DIR \
--   DUMPFILE=schema_export_%U.dmp \
--   LOGFILE=import_parallel.log \
--   SCHEMAS=HR \
--   PARALLEL=4


PROMPT ====================================================================
PROMPT  7. RIDURRE IMPATTO DATA PUMP (best practice)
PROMPT ====================================================================

-- 1. USA COMPRESSION=ALL nell'export → dump più piccoli, meno I/O
-- 2. USA FILESIZE=10G → split in file multipli, gestibili
-- 3. Prima dell'import, metti le tabelle grandi in NOLOGGING:
--    ALTER TABLE schema.tabella NOLOGGING;
--    -- DOPO l'import:
--    ALTER TABLE schema.tabella LOGGING;
--    -- ⚠️ Con NOLOGGING il Data Guard NON replica quei dati!
--    -- Dopo, fai backup RMAN per proteggere.
--
-- 4. Se usi REMAP_TABLESPACE, assicurati che il target abbia spazio.
-- 5. Lancia di notte per minimizzare l'impatto sugli utenti.
-- 6. EXCLUDE=STATISTICS → non importare stats, rigenerale dopo:
--    EXEC DBMS_STATS.GATHER_SCHEMA_STATS('HR_TEST');

PROMPT ====================================================================
PROMPT  8. STIMA DIMENSIONE EXPORT
PROMPT ====================================================================

-- Quanto peserà l'export?
COL owner FOR A20
COL size_gb FOR 999.99

SELECT owner, ROUND(SUM(bytes)/1024/1024/1024, 2) AS size_gb
FROM dba_segments
WHERE owner = UPPER('&SCHEMA_NAME')
GROUP BY owner;

-- Il dump sarà circa il 30-50% della dimensione raw con COMPRESSION=ALL.

PROMPT ====================================================================
PROMPT  Fine Script 04 — Data Pump Operativo
PROMPT ====================================================================
