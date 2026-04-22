-- ============================================================================
-- SCRIPT 11: TEMP Resize & Capacity
-- Scenario: ORA-01652, TEMP piena, sort su disco
-- ============================================================================

PROMPT ====================================================================
PROMPT  1. STATO TEMP
PROMPT ====================================================================

COL tablespace_name FOR A20
COL total_gb FOR 999.99
COL used_gb FOR 999.99
COL free_gb FOR 999.99
COL pct_used FOR 999.9

SELECT tablespace_name,
       ROUND(tablespace_size * 8192 / 1024 / 1024 / 1024, 2) AS total_gb,
       ROUND(allocated_space * 8192 / 1024 / 1024 / 1024, 2) AS used_gb,
       ROUND(free_space * 8192 / 1024 / 1024 / 1024, 2) AS free_gb,
       ROUND(allocated_space * 100 / NULLIF(tablespace_size,0), 1) AS pct_used
FROM dba_temp_free_space;

PROMPT ====================================================================
PROMPT  2. SESSIONI TOP CONSUMO TEMP
PROMPT ====================================================================

COL username FOR A20
COL program FOR A30
COL sql_id FOR A15
COL temp_mb FOR 999999.99

SELECT s.sid, s.serial#, s.username, s.program, s.sql_id,
       ROUND(t.blocks * 8192 / 1024 / 1024, 2) AS temp_mb
FROM v$sort_usage t
JOIN v$session s ON s.saddr = t.session_addr
ORDER BY t.blocks DESC;

PROMPT ====================================================================
PROMPT  3. DETTAGLIO TEMPFILE
PROMPT ====================================================================

COL file_name FOR A70
COL size_mb FOR 999999
COL max_mb FOR 999999
COL autoextensible FOR A5

SELECT file_id, file_name,
       ROUND(bytes/1024/1024) AS size_mb,
       ROUND(maxbytes/1024/1024) AS max_mb,
       autoextensible
FROM dba_temp_files
ORDER BY file_id;

PROMPT ====================================================================
PROMPT  AZIONI RAPIDE (UNCOMMENT PER ESEGUIRE)
PROMPT ====================================================================

-- ALTER DATABASE TEMPFILE '&tempfile_name' AUTOEXTEND ON NEXT 512M MAXSIZE 32G;
-- ALTER TABLESPACE TEMP ADD TEMPFILE '+DATA' SIZE 4G AUTOEXTEND ON NEXT 512M MAXSIZE 32G;
-- ALTER DATABASE TEMPFILE '&tempfile_name' RESIZE 8G;

PROMPT ====================================================================
PROMPT  Fine Script 11 — TEMP Resize
PROMPT ====================================================================
