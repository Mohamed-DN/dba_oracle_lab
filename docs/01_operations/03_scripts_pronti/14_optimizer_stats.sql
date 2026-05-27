-- ============================================================================
-- SCRIPT 14: Optimizer Stats Operations
-- Scenario: regressioni SQL, stale stats, tuning post-load
-- ============================================================================

-- Runbook collegati:
--   - ../02_runbooks_incidenti/18_GESTIONE_STATISTICHE_OPTIMIZER.md
--   - ../02_runbooks_incidenti/05_QUERY_LENTA.md
--   - ../02_runbooks_incidenti/23_SQL_TUNING_CASI_ENTERPRISE.md
--   - ../02_runbooks_incidenti/20_EXPORT_IMPORT_PROD_PREPROD.md
-- Uso rapido:
--   sqlplus / as sysdba @14_optimizer_stats.sql
-- Nota: verificare sempre ambiente, ruolo database e privilegi prima di eseguire azioni correttive.
SET LINESIZE 220
SET PAGESIZE 200
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT ====================================================================
PROMPT  1. TABELLE CON STATS STALE
PROMPT ====================================================================

COL owner FOR A20
COL table_name FOR A35
COL stale_stats FOR A10
COL last_analyzed FOR A20

SELECT owner, table_name, stale_stats,
       TO_CHAR(last_analyzed, 'YYYY-MM-DD HH24:MI') AS last_analyzed
FROM dba_tab_statistics
WHERE owner NOT IN ('SYS','SYSTEM')
  AND temporary = 'N'
  AND stale_stats = 'YES'
ORDER BY last_analyzed NULLS FIRST
FETCH FIRST 100 ROWS ONLY;

PROMPT ====================================================================
PROMPT  2. GATHER STALE A LIVELLO DATABASE
PROMPT ====================================================================

BEGIN
  DBMS_STATS.GATHER_DATABASE_STATS(
    options          => 'GATHER STALE',
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
    cascade          => TRUE,
    degree           => DBMS_STATS.AUTO_DEGREE,
    no_invalidate    => DBMS_STATS.AUTO_INVALIDATE
  );
END;
/

PROMPT ====================================================================
PROMPT  3. GATHER MIRATO TABELLA
PROMPT ====================================================================

-- EXEC DBMS_STATS.GATHER_TABLE_STATS('&OWNER','&TABLE_NAME',cascade=>TRUE,method_opt=>'FOR ALL COLUMNS SIZE AUTO');

PROMPT ====================================================================
PROMPT  Fine Script 14 — Optimizer Stats
PROMPT ====================================================================
