-- ============================================================================
-- SCRIPT 07: PERFORMANCE QUICK - Top SQL, Wait Events, Hit Ratio
-- Scenario: database lento, CPU alta, I/O alto, diagnosi rapida RAC-aware
-- ============================================================================

-- Runbook collegati:
--   - ../02_runbooks_incidenti/05_QUERY_LENTA.md
--   - ../02_runbooks_incidenti/07_CPU_ALTA.md
--   - ../02_runbooks_incidenti/11_REVIEW_AWR.md
--   - ../02_runbooks_incidenti/23_SQL_TUNING_CASI_ENTERPRISE.md
-- Uso rapido:
--   sqlplus / as sysdba @07_performance_quick.sql
-- RAC: le query principali usano GV$ e aggregano per cluster oppure espongono INST_ID.
-- Nota: verificare ambiente, ruolo database e privilegi prima di azioni correttive.
SET LINESIZE 220
SET PAGESIZE 200
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT ====================================================================
PROMPT  1. TOP 10 SQL - Per tempo di esecuzione totale globale
PROMPT ====================================================================

COL sql_id FOR A15
COL elapsed_sec FOR 999,999,999
COL executions FOR 999,999,999
COL avg_sec FOR 999,999.999
COL buffer_gets FOR 999,999,999,999
COL sql_text_short FOR A60

SELECT *
FROM (
    SELECT
        sql_id,
        ROUND(SUM(elapsed_time)/1000000) AS elapsed_sec,
        SUM(executions) AS executions,
        ROUND(SUM(elapsed_time)/NULLIF(SUM(executions),0)/1000000, 3) AS avg_sec,
        SUM(buffer_gets) AS buffer_gets,
        MIN(SUBSTR(sql_text, 1, 60)) AS sql_text_short
    FROM gv$sql
    WHERE NVL(parsing_schema_name, '-') NOT IN ('SYS', 'SYSTEM', 'DBSNMP', 'MDSYS')
    GROUP BY sql_id
    ORDER BY SUM(elapsed_time) DESC
)
WHERE ROWNUM <= 10;


PROMPT ====================================================================
PROMPT  2. TOP 10 SQL - Per buffer gets globale
PROMPT ====================================================================

COL disk_reads FOR 999,999,999,999

SELECT *
FROM (
    SELECT
        sql_id,
        SUM(buffer_gets) AS buffer_gets,
        SUM(executions) AS executions,
        ROUND(SUM(buffer_gets)/NULLIF(SUM(executions),0)) AS gets_per_exec,
        SUM(disk_reads) AS disk_reads,
        MIN(SUBSTR(sql_text, 1, 60)) AS sql_text_short
    FROM gv$sql
    WHERE NVL(parsing_schema_name, '-') NOT IN ('SYS', 'SYSTEM', 'DBSNMP', 'MDSYS')
    GROUP BY sql_id
    ORDER BY SUM(buffer_gets) DESC
)
WHERE ROWNUM <= 10;


PROMPT ====================================================================
PROMPT  3. WAIT EVENTS TOP - Dove il cluster sta aspettando
PROMPT ====================================================================

COL event FOR A45
COL wait_class FOR A15
COL total_waits FOR 999,999,999
COL time_waited_sec FOR 999,999,999
COL avg_wait_ms FOR 999,999.99

SELECT *
FROM (
    SELECT
        event,
        wait_class,
        SUM(total_waits) AS total_waits,
        ROUND(SUM(time_waited)/100) AS time_waited_sec,
        ROUND(SUM(time_waited) / NULLIF(SUM(total_waits),0) * 10, 2) AS avg_wait_ms
    FROM gv$system_event
    WHERE wait_class NOT IN ('Idle', 'Other')
      AND total_waits > 0
    GROUP BY event, wait_class
    ORDER BY SUM(time_waited) DESC
)
WHERE ROWNUM <= 15;


PROMPT ====================================================================
PROMPT  4. SESSIONI IN ATTESA - real-time per istanza
PROMPT ====================================================================

COL inst_id FOR 999
COL sid FOR 99999
COL username FOR A15
COL event FOR A40
COL wait_sec FOR 99999
COL sql_id FOR A15

SELECT
    s.inst_id,
    s.sid,
    s.username,
    SUBSTR(s.event, 1, 40) AS event,
    s.seconds_in_wait AS wait_sec,
    s.sql_id,
    s.blocking_instance AS blocker_inst,
    s.blocking_session AS blocker
FROM gv$session s
WHERE s.status = 'ACTIVE'
  AND s.type = 'USER'
  AND s.wait_class != 'Idle'
ORDER BY s.seconds_in_wait DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT ====================================================================
PROMPT  5. BUFFER CACHE HIT RATIO globale
PROMPT ====================================================================

WITH s AS (
    SELECT name, SUM(value) AS value
    FROM gv$sysstat
    WHERE name IN ('physical reads', 'consistent gets', 'db block gets')
    GROUP BY name
)
SELECT
    ROUND(1 - (phy.value / NULLIF(con.value + db.value, 0)), 4) * 100 AS buffer_cache_hit_pct
FROM s phy, s con, s db
WHERE phy.name = 'physical reads'
  AND con.name = 'consistent gets'
  AND db.name = 'db block gets';

-- Valori bassi vanno interpretati con AWR/ASH: possono indicare SGA piccola o full scan frequenti.


PROMPT ====================================================================
PROMPT  6. LIBRARY CACHE HIT RATIO globale
PROMPT ====================================================================

SELECT
    ROUND(1 - SUM(reloads)/NULLIF(SUM(pins), 0), 4) * 100 AS library_cache_hit_pct
FROM gv$librarycache;

-- Valori bassi possono indicare shared pool piccolo o hard parse eccessivi.


PROMPT ====================================================================
PROMPT  7. PGA - Uso memoria per istanza
PROMPT ====================================================================

COL name FOR A50
COL value_mb FOR 999,999.99

SELECT inst_id, name, ROUND(value/1024/1024, 2) AS value_mb
FROM gv$pgastat
WHERE name IN (
    'total PGA allocated',
    'total PGA inuse',
    'over allocation count',
    'extra bytes read/written',
    'aggregate PGA target parameter'
)
ORDER BY inst_id, name;


PROMPT ====================================================================
PROMPT  8. ASH - Ultimi 5 minuti per istanza
PROMPT ====================================================================

COL sample_time FOR A20
COL session_id FOR 99999
COL event FOR A35
COL session_state FOR A10

SELECT inst_id,
       TO_CHAR(sample_time, 'HH24:MI:SS') AS sample_time,
       session_id,
       sql_id,
       CASE session_state WHEN 'ON CPU' THEN 'ON CPU' ELSE SUBSTR(event,1,35) END AS event,
       session_state
FROM gv$active_session_history
WHERE sample_time > SYSDATE - INTERVAL '5' MINUTE
ORDER BY sample_time DESC, inst_id
FETCH FIRST 30 ROWS ONLY;


PROMPT ====================================================================
PROMPT  9. SQL PLAN - Vedi il piano di una query specifica
PROMPT ====================================================================

-- Cursor cache:
-- SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('&SQL_ID'));
--
-- Storico AWR:
-- SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_AWR('&SQL_ID'));

PROMPT ====================================================================
PROMPT  Fine Script 07 - Performance Quick
PROMPT ====================================================================
