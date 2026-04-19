-- ============================================================================
-- SCRIPT 02: UNDO e TEMP — Diagnosi e Gestione
-- Scenario: Undo pieno, ORA-01555, ORA-30036, Temp piena, sort disk
-- ============================================================================

PROMPT ====================================================================
PROMPT  1. STATO UNDO TABLESPACE
PROMPT ====================================================================

COL tablespace_name FOR A20
COL status FOR A10
COL size_gb FOR 999.99
COL used_gb FOR 999.99
COL free_gb FOR 999.99
COL pct_used FOR 999.9

SELECT
    u.tablespace_name,
    t.status,
    ROUND(d.total_bytes/1024/1024/1024, 2) AS size_gb,
    ROUND((d.total_bytes - NVL(f.free_bytes,0))/1024/1024/1024, 2) AS used_gb,
    ROUND(NVL(f.free_bytes,0)/1024/1024/1024, 2) AS free_gb,
    ROUND((d.total_bytes - NVL(f.free_bytes,0)) * 100 / d.total_bytes, 1) AS pct_used
FROM (SELECT value AS tablespace_name FROM v$parameter WHERE name = 'undo_tablespace') u
JOIN dba_tablespaces t ON t.tablespace_name = u.tablespace_name
JOIN (SELECT tablespace_name, SUM(bytes) total_bytes FROM dba_data_files GROUP BY tablespace_name) d ON d.tablespace_name = u.tablespace_name
LEFT JOIN (SELECT tablespace_name, SUM(bytes) free_bytes FROM dba_free_space GROUP BY tablespace_name) f ON f.tablespace_name = u.tablespace_name;


PROMPT ====================================================================
PROMPT  2. PARAMETRI UNDO CORRENTI
PROMPT ====================================================================

COL name FOR A30
COL value FOR A30
SELECT name, value FROM v$parameter
WHERE name IN ('undo_tablespace', 'undo_retention', 'undo_management')
ORDER BY name;


PROMPT ====================================================================
PROMPT  3. SEGMENTI UNDO — Chi sta usando UNDO
PROMPT ====================================================================

COL segment_name FOR A30
COL status FOR A12
COL size_mb FOR 999,999.99

SELECT segment_name, status,
       ROUND(bytes/1024/1024, 2) AS size_mb
FROM dba_undo_extents
WHERE status = 'ACTIVE'
ORDER BY bytes DESC;


PROMPT ====================================================================
PROMPT  4. UNDO ADVISOR — Quanta retention puoi garantire?
PROMPT ====================================================================

-- Quanto UNDO serve per la retention corrente?
SELECT
    ROUND(d.undo_size / (1024*1024), 0) AS "UNDO_SIZE_MB",
    SUBSTR(e.value, 1, 10) AS "UNDO_RETENTION_SEC",
    ROUND(d.undo_size / (NVL(f.undo_per_sec, 1) * TO_NUMBER(e.value)), 1) AS "RETENTION_POSSIBLE_HOURS",
    ROUND(f.undo_per_sec * TO_NUMBER(e.value) / (1024*1024), 0) AS "NEEDED_UNDO_MB"
FROM (SELECT SUM(bytes) AS undo_size FROM dba_data_files
      WHERE tablespace_name = (SELECT value FROM v$parameter WHERE name = 'undo_tablespace')) d,
     v$parameter e,
     (SELECT SUM(undoblks * (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'db_block_size'))
             / SUM(((end_time - begin_time) * 86400)) AS undo_per_sec
      FROM v$undostat WHERE begin_time > SYSDATE - 1) f
WHERE e.name = 'undo_retention';


PROMPT ====================================================================
PROMPT  5. STATO TEMP TABLESPACE
PROMPT ====================================================================

COL tablespace_name FOR A20
COL total_gb FOR 999.99
COL used_gb FOR 999.99
COL free_gb FOR 999.99
COL pct_used FOR 999.9

SELECT
    tablespace_name,
    ROUND(tablespace_size * (SELECT value FROM v$parameter WHERE name = 'db_block_size') / 1024/1024/1024, 2) AS total_gb,
    ROUND(allocated_space * (SELECT value FROM v$parameter WHERE name = 'db_block_size') / 1024/1024/1024, 2) AS used_gb,
    ROUND(free_space * (SELECT value FROM v$parameter WHERE name = 'db_block_size') / 1024/1024/1024, 2) AS free_gb,
    ROUND(allocated_space * 100 / NULLIF(tablespace_size, 0), 1) AS pct_used
FROM dba_temp_free_space;


PROMPT ====================================================================
PROMPT  6. CHI STA USANDO TEMP — Sessioni con sort on disk
PROMPT ====================================================================

COL username FOR A20
COL sid FOR 99999
COL serial# FOR 99999
COL sql_id FOR A15
COL temp_mb FOR 999,999.99
COL tablespace FOR A15

SELECT
    s.username,
    s.sid,
    s.serial#,
    s.sql_id,
    ROUND(t.blocks * (SELECT value FROM v$parameter WHERE name = 'db_block_size') / 1024/1024, 2) AS temp_mb,
    t.tablespace AS tablespace
FROM v$session s
JOIN v$sort_usage t ON s.saddr = t.session_addr
ORDER BY t.blocks DESC;


PROMPT ====================================================================
PROMPT  7. TEMPFILE — Dettaglio file temp
PROMPT ====================================================================

COL file_name FOR A60
COL size_gb FOR 999.99
COL max_gb FOR 999.99
COL autoext FOR A7

SELECT file_name,
       ROUND(bytes/1024/1024/1024, 2) AS size_gb,
       ROUND(maxbytes/1024/1024/1024, 2) AS max_gb,
       autoextensible AS autoext
FROM dba_temp_files;


PROMPT ====================================================================
PROMPT  8. SOLUZIONI UNDO
PROMPT ====================================================================

-- ---- ORA-30036: unable to extend segment in undo tablespace ----
-- CAUSA: Le transazioni attive consumano più UNDO di quanto disponibile.
--
-- FIX IMMEDIATO:
-- ALTER DATABASE DATAFILE '/path/undo01.dbf' RESIZE 10G;
-- oppure:
-- ALTER TABLESPACE UNDOTBS1 ADD DATAFILE '+DATA' SIZE 5G AUTOEXTEND ON MAXSIZE 30G;
--
-- FIX DEFINITIVO:
-- ALTER SYSTEM SET undo_retention = 900 SCOPE=BOTH;  -- riduci retention
-- O trova e risolvi la transazione che consuma troppo undo:
-- SELECT s.sid, s.serial#, s.sql_id, t.used_ublk * 8192/1024/1024 AS undo_mb
-- FROM v$session s JOIN v$transaction t ON s.saddr = t.ses_addr ORDER BY t.used_ublk DESC;

-- ---- ORA-01555: snapshot too old ----
-- CAUSA: La query chiede dati UNDO già sovrascritta (retention troppo bassa).
-- FIX: ALTER SYSTEM SET undo_retention = 3600 SCOPE=BOTH;
-- OPPURE: Usa UNDO GUARANTEE:
-- ALTER TABLESPACE UNDOTBS1 RETENTION GUARANTEE;
-- ⚠️ ATTENZIONE: con GUARANTEE, se l'undo si riempie, le transazioni FALLISCONO.


PROMPT ====================================================================
PROMPT  9. SOLUZIONI TEMP
PROMPT ====================================================================

-- ---- TEMP tablespace pieno ----
-- FIX IMMEDIATO: aggiungi tempfile
-- ALTER TABLESPACE TEMP ADD TEMPFILE '+DATA' SIZE 10G AUTOEXTEND ON MAXSIZE 30G;
--
-- TROVA LA QUERY CHE CONSUMA TEMP e valuta se killarla:
-- ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
--
-- RICREA TEMP (cleanup totale):
-- CREATE TEMPORARY TABLESPACE TEMP2 TEMPFILE '+DATA' SIZE 10G;
-- ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP2;
-- DROP TABLESPACE TEMP INCLUDING CONTENTS AND DATAFILES;
-- CREATE TEMPORARY TABLESPACE TEMP TEMPFILE '+DATA' SIZE 10G AUTOEXTEND ON MAXSIZE 30G;
-- ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP;
-- DROP TABLESPACE TEMP2 INCLUDING CONTENTS AND DATAFILES;

PROMPT ====================================================================
PROMPT  Fine Script 02 — Undo & Temp
PROMPT ====================================================================
