-- ============================================================================
-- SCRIPT 02: UNDO e TEMP - Diagnosi e Gestione
-- Scenario: undo pieno, ORA-01555, ORA-30036, TEMP piena, sort disk
-- ============================================================================

-- Runbook collegati:
--   - ../02_runbooks_incidenti/06_TABLESPACE_PIENO.md
--   - ../02_runbooks_incidenti/16_RESIZE_TEMP.md
--   - ../02_runbooks_incidenti/23_SQL_TUNING_CASI_ENTERPRISE.md
-- Uso rapido:
--   sqlplus / as sysdba @02_undo_temp.sql
-- RAC: usa GV$ per distinguere TEMP/UNDO e sessioni per istanza.
-- Nota: verificare ambiente, ruolo database e privilegi prima di azioni correttive.
SET LINESIZE 220
SET PAGESIZE 200
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT ====================================================================
PROMPT  1. STATO UNDO TABLESPACE PER ISTANZA
PROMPT ====================================================================

COL inst_id FOR 999
COL tablespace_name FOR A20
COL status FOR A10
COL size_gb FOR 999.99
COL used_gb FOR 999.99
COL free_gb FOR 999.99
COL pct_used FOR 999.9

SELECT
    u.inst_id,
    u.tablespace_name,
    t.status,
    ROUND(d.total_bytes/1024/1024/1024, 2) AS size_gb,
    ROUND((d.total_bytes - NVL(f.free_bytes,0))/1024/1024/1024, 2) AS used_gb,
    ROUND(NVL(f.free_bytes,0)/1024/1024/1024, 2) AS free_gb,
    ROUND((d.total_bytes - NVL(f.free_bytes,0)) * 100 / NULLIF(d.total_bytes,0), 1) AS pct_used
FROM (SELECT inst_id, value AS tablespace_name FROM gv$parameter WHERE name = 'undo_tablespace') u
JOIN dba_tablespaces t ON t.tablespace_name = u.tablespace_name
JOIN (
    SELECT tablespace_name, SUM(bytes) total_bytes
    FROM dba_data_files
    GROUP BY tablespace_name
) d ON d.tablespace_name = u.tablespace_name
LEFT JOIN (
    SELECT tablespace_name, SUM(bytes) free_bytes
    FROM dba_free_space
    GROUP BY tablespace_name
) f ON f.tablespace_name = u.tablespace_name
ORDER BY u.inst_id;


PROMPT ====================================================================
PROMPT  2. PARAMETRI UNDO CORRENTI PER ISTANZA
PROMPT ====================================================================

COL name FOR A30
COL value FOR A30

SELECT inst_id, name, value
FROM gv$parameter
WHERE name IN ('undo_tablespace', 'undo_retention', 'undo_management')
ORDER BY inst_id, name;


PROMPT ====================================================================
PROMPT  3. SEGMENTI UNDO ACTIVE
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
PROMPT  4. UNDO ADVISOR - retention sostenibile per istanza
PROMPT ====================================================================

WITH p AS (
    SELECT inst_id,
           MAX(CASE WHEN name = 'undo_tablespace' THEN value END) AS undo_tablespace,
           MAX(CASE WHEN name = 'undo_retention' THEN value END) AS undo_retention
    FROM gv$parameter
    WHERE name IN ('undo_tablespace', 'undo_retention')
    GROUP BY inst_id
),
u AS (
    SELECT p.inst_id, SUM(df.bytes) AS undo_size
    FROM p
    JOIN dba_data_files df ON df.tablespace_name = p.undo_tablespace
    GROUP BY p.inst_id
),
r AS (
    SELECT inst_id,
           SUM(undoblks * (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'db_block_size'))
           / NULLIF(SUM((end_time - begin_time) * 86400), 0) AS undo_per_sec
    FROM gv$undostat
    WHERE begin_time > SYSDATE - 1
    GROUP BY inst_id
)
SELECT
    p.inst_id,
    ROUND(u.undo_size / (1024*1024), 0) AS undo_size_mb,
    SUBSTR(p.undo_retention, 1, 10) AS undo_retention_sec,
    ROUND(u.undo_size / (NVL(r.undo_per_sec, 1) * TO_NUMBER(p.undo_retention)), 1) AS retention_possible_hours,
    ROUND(r.undo_per_sec * TO_NUMBER(p.undo_retention) / (1024*1024), 0) AS needed_undo_mb
FROM p
JOIN u ON u.inst_id = p.inst_id
LEFT JOIN r ON r.inst_id = p.inst_id
ORDER BY p.inst_id;


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
    ROUND(tablespace_size * (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'db_block_size') / 1024/1024/1024, 2) AS total_gb,
    ROUND(allocated_space * (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'db_block_size') / 1024/1024/1024, 2) AS used_gb,
    ROUND(free_space * (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'db_block_size') / 1024/1024/1024, 2) AS free_gb,
    ROUND(allocated_space * 100 / NULLIF(tablespace_size, 0), 1) AS pct_used
FROM dba_temp_free_space;


PROMPT ====================================================================
PROMPT  6. CHI STA USANDO TEMP - Sessioni con sort on disk
PROMPT ====================================================================

COL username FOR A20
COL sid FOR 99999
COL serial# FOR 999999
COL sql_id FOR A15
COL temp_mb FOR 999,999.99
COL tablespace FOR A15

SELECT
    s.inst_id,
    s.username,
    s.sid,
    s.serial#,
    s.sql_id,
    ROUND(t.blocks * (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'db_block_size') / 1024/1024, 2) AS temp_mb,
    t.tablespace AS tablespace
FROM gv$session s
JOIN gv$sort_usage t ON s.inst_id = t.inst_id AND s.saddr = t.session_addr
ORDER BY t.blocks DESC;


PROMPT ====================================================================
PROMPT  7. TEMPFILE - Dettaglio file temp
PROMPT ====================================================================

COL file_name FOR A70
COL size_gb FOR 999.99
COL max_gb FOR 999.99
COL autoext FOR A7

SELECT file_name,
       ROUND(bytes/1024/1024/1024, 2) AS size_gb,
       ROUND(maxbytes/1024/1024/1024, 2) AS max_gb,
       autoextensible AS autoext
FROM dba_temp_files
ORDER BY tablespace_name, file_name;


PROMPT ====================================================================
PROMPT  8. SOLUZIONI UNDO
PROMPT ====================================================================

-- ORA-30036: unable to extend segment in undo tablespace
-- FIX immediato:
-- ALTER DATABASE DATAFILE '/path/undo01.dbf' RESIZE 10G;
-- ALTER TABLESPACE UNDOTBS1 ADD DATAFILE '+DATA' SIZE 5G AUTOEXTEND ON MAXSIZE 30G;
--
-- Trova la transazione che consuma troppo undo:
-- SELECT s.inst_id, s.sid, s.serial#, s.sql_id, t.used_ublk * 8192/1024/1024 AS undo_mb
-- FROM gv$session s
-- JOIN gv$transaction t ON s.inst_id = t.inst_id AND s.saddr = t.ses_addr
-- ORDER BY t.used_ublk DESC;
--
-- ORA-01555: snapshot too old
-- ALTER SYSTEM SET undo_retention = 3600 SCOPE=BOTH;
-- ALTER TABLESPACE UNDOTBS1 RETENTION GUARANTEE;
-- Attenzione: con GUARANTEE, se UNDO si riempie, falliscono le transazioni DML.


PROMPT ====================================================================
PROMPT  9. SOLUZIONI TEMP
PROMPT ====================================================================

-- TEMP piena:
-- ALTER TABLESPACE TEMP ADD TEMPFILE '+DATA' SIZE 10G AUTOEXTEND ON MAXSIZE 30G;
--
-- Kill session single instance:
-- ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
--
-- Kill session RAC:
-- ALTER SYSTEM KILL SESSION 'sid,serial#,@inst_id' IMMEDIATE;
--
-- Ricrea TEMP se serve cleanup totale:
-- CREATE TEMPORARY TABLESPACE TEMP2 TEMPFILE '+DATA' SIZE 10G;
-- ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP2;
-- DROP TABLESPACE TEMP INCLUDING CONTENTS AND DATAFILES;
-- CREATE TEMPORARY TABLESPACE TEMP TEMPFILE '+DATA' SIZE 10G AUTOEXTEND ON MAXSIZE 30G;
-- ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP;
-- DROP TABLESPACE TEMP2 INCLUDING CONTENTS AND DATAFILES;

PROMPT ====================================================================
PROMPT  Fine Script 02 - Undo & Temp
PROMPT ====================================================================
