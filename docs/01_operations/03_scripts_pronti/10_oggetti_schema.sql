-- ============================================================================
-- SCRIPT 10: OGGETTI E SCHEMA — Invalidi, segmenti grandi, pulizia
-- Scenario: Capacity planning, post-upgrade, pulizia schema
-- ============================================================================

-- Runbook collegati:
--   - ../02_runbooks_incidenti/09_GESTIONE_UTENTI.md
--   - ../02_runbooks_incidenti/13_REFRESH_SCHEMA_TEST.md
--   - ../02_runbooks_incidenti/20_EXPORT_IMPORT_PROD_PREPROD.md
--   - ../02_runbooks_incidenti/23_SQL_TUNING_CASI_ENTERPRISE.md
-- Uso rapido:
--   sqlplus / as sysdba @10_oggetti_schema.sql
-- Nota: verificare sempre ambiente, ruolo database e privilegi prima di eseguire azioni correttive.
SET LINESIZE 220
SET PAGESIZE 200
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT ====================================================================
PROMPT  1. OGGETTI INVALIDI — Ricompilare dopo patching/upgrade
PROMPT ====================================================================

COL owner FOR A20
COL object_type FOR A20
COL count_invalid FOR 9999

SELECT owner, object_type, COUNT(*) AS count_invalid
FROM dba_objects
WHERE status = 'INVALID'
GROUP BY owner, object_type
ORDER BY owner, object_type;

-- FIX: Ricompila tutti gli invalidi:
-- @$ORACLE_HOME/rdbms/admin/utlrp.sql
--
-- Ricompila un singolo oggetto:
-- ALTER PACKAGE schema.package_name COMPILE;
-- ALTER PACKAGE schema.package_name COMPILE BODY;
-- ALTER VIEW schema.view_name COMPILE;


PROMPT ====================================================================
PROMPT  2. TOP 20 TABELLE PIÙ GRANDI (per schema)
PROMPT ====================================================================

COL owner FOR A20
COL segment_name FOR A35
COL size_gb FOR 999,999.99
COL tablespace_name FOR A20
COL partitioned FOR A5

SELECT * FROM (
    SELECT
        s.owner,
        s.segment_name,
        ROUND(SUM(s.bytes)/1024/1024/1024, 2) AS size_gb,
        s.tablespace_name,
        t.partitioned
    FROM dba_segments s
    LEFT JOIN dba_tables t ON s.owner = t.owner AND s.segment_name = t.table_name
    WHERE s.segment_type LIKE 'TABLE%'
      AND s.owner NOT IN ('SYS', 'SYSTEM', 'DBSNMP', 'APPQOSSYS', 'WMSYS', 'XDB', 'MDSYS', 'ORDSYS', 'CTXSYS')
    GROUP BY s.owner, s.segment_name, s.tablespace_name, t.partitioned
    ORDER BY SUM(s.bytes) DESC
)
WHERE ROWNUM <= 20;


PROMPT ====================================================================
PROMPT  3. TOP 20 INDICI PIÙ GRANDI
PROMPT ====================================================================

COL index_name FOR A35
COL table_name FOR A30
COL uniqueness FOR A10

SELECT * FROM (
    SELECT
        s.owner,
        s.segment_name AS index_name,
        i.table_name,
        i.uniqueness,
        ROUND(SUM(s.bytes)/1024/1024/1024, 2) AS size_gb
    FROM dba_segments s
    JOIN dba_indexes i ON s.owner = i.owner AND s.segment_name = i.index_name
    WHERE s.segment_type LIKE 'INDEX%'
      AND s.owner NOT IN ('SYS', 'SYSTEM', 'DBSNMP', 'APPQOSSYS', 'WMSYS', 'XDB', 'MDSYS')
    GROUP BY s.owner, s.segment_name, i.table_name, i.uniqueness
    ORDER BY SUM(s.bytes) DESC
)
WHERE ROWNUM <= 20;


PROMPT ====================================================================
PROMPT  4. DIMENSIONE PER SCHEMA (totale segmenti)
PROMPT ====================================================================

COL owner FOR A20
COL total_gb FOR 999,999.99
COL num_segments FOR 99,999

SELECT
    owner,
    ROUND(SUM(bytes)/1024/1024/1024, 2) AS total_gb,
    COUNT(*) AS num_segments
FROM dba_segments
WHERE owner NOT IN ('SYS', 'SYSTEM', 'DBSNMP', 'APPQOSSYS', 'WMSYS', 'XDB', 'MDSYS', 'CTXSYS', 'ORDSYS')
GROUP BY owner
ORDER BY SUM(bytes) DESC;


PROMPT ====================================================================
PROMPT  5. TABELLE CON HIGH WATER MARK ALTO (spazio sprecato)
PROMPT ====================================================================

-- Tabelle con molti DELETE ma senza SHRINK → occupano spazio inutilmente.

COL owner FOR A15
COL table_name FOR A30
COL num_rows FOR 999,999,999
COL actual_mb FOR 999,999.99
COL estimated_mb FOR 999,999.99
COL waste_pct FOR 999.9

SELECT
    s.owner,
    s.segment_name AS table_name,
    t.num_rows,
    ROUND(s.bytes/1024/1024, 2) AS actual_mb,
    ROUND(t.num_rows * t.avg_row_len / 1024 / 1024, 2) AS estimated_mb,
    -- Se actual >> estimated, c'è spazio sprecato
    CASE WHEN t.num_rows > 0 AND t.avg_row_len > 0
         THEN ROUND((1 - (t.num_rows * t.avg_row_len) / NULLIF(s.bytes, 0)) * 100, 1)
         ELSE NULL END AS waste_pct
FROM dba_segments s
JOIN dba_tables t ON s.owner = t.owner AND s.segment_name = t.table_name
WHERE s.segment_type = 'TABLE'
  AND s.bytes > 104857600  -- > 100MB
  AND s.owner NOT IN ('SYS', 'SYSTEM')
  AND t.num_rows > 0
ORDER BY waste_pct DESC NULLS LAST
FETCH FIRST 20 ROWS ONLY;

-- FIX: ALTER TABLE schema.tabella ENABLE ROW MOVEMENT;
--      ALTER TABLE schema.tabella SHRINK SPACE CASCADE;


PROMPT ====================================================================
PROMPT  6. INDICI INUTILIZZATI (da Oracle 12.2+)
PROMPT ====================================================================

-- Richiede MONITORING USAGE abilitato:
-- ALTER INDEX schema.idx_name MONITORING USAGE;
-- Dopo qualche settimana:

COL index_name FOR A30
COL used FOR A5

SELECT u.index_name, u.table_name, u.monitoring, u.used
FROM v$object_usage u
WHERE u.used = 'NO'
ORDER BY u.index_name;


PROMPT ====================================================================
PROMPT  7. RECYCLEBIN — Oggetti nel cestino (occupano spazio!)
PROMPT ====================================================================

COL original_name FOR A30
COL type FOR A15
COL space_mb FOR 999,999.99

SELECT original_name, type,
       ROUND(SUM(space * 8192)/1024/1024, 2) AS space_mb
FROM dba_recyclebin
GROUP BY original_name, type
ORDER BY SUM(space) DESC
FETCH FIRST 20 ROWS ONLY;

-- PULIZIA:
-- PURGE DBA_RECYCLEBIN;  -- Svuota tutto il cestino (tutti gli schema)
-- PURGE RECYCLEBIN;      -- Svuota solo il cestino dell'utente corrente

PROMPT ====================================================================
PROMPT  Fine Script 10 — Oggetti & Schema
PROMPT ====================================================================
