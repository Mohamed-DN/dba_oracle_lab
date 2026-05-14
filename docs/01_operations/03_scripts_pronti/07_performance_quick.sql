-- ============================================================================
-- SCRIPT 07: PERFORMANCE QUICK — Top SQL, Wait Events, Hit Ratio
-- Scenario: "Il database è lento!" — diagnosi rapida in 2 minuti
-- ============================================================================

PROMPT ====================================================================
PROMPT  1. TOP 10 SQL — Per tempo di esecuzione totale
PROMPT ====================================================================

COL sql_id FOR A15
COL elapsed_sec FOR 999,999
COL executions FOR 9,999,999
COL avg_sec FOR 999.999
COL buffer_gets FOR 999,999,999
COL sql_text_short FOR A60

SELECT * FROM (
    SELECT
        sql_id,
        ROUND(elapsed_time/1000000) AS elapsed_sec,
        executions,
        ROUND(elapsed_time/NULLIF(executions,0)/1000000, 3) AS avg_sec,
        buffer_gets,
        SUBSTR(sql_text, 1, 60) AS sql_text_short
    FROM v$sql
    WHERE parsing_schema_name NOT IN ('SYS', 'SYSTEM', 'DBSNMP', 'MDSYS')
    ORDER BY elapsed_time DESC
)
WHERE ROWNUM <= 10;


PROMPT ====================================================================
PROMPT  2. TOP 10 SQL — Per buffer gets (logical I/O)
PROMPT ====================================================================

SELECT * FROM (
    SELECT
        sql_id,
        buffer_gets,
        executions,
        ROUND(buffer_gets/NULLIF(executions,0)) AS gets_per_exec,
        disk_reads,
        SUBSTR(sql_text, 1, 60) AS sql_text_short
    FROM v$sql
    WHERE parsing_schema_name NOT IN ('SYS', 'SYSTEM', 'DBSNMP', 'MDSYS')
    ORDER BY buffer_gets DESC
)
WHERE ROWNUM <= 10;


PROMPT ====================================================================
PROMPT  3. WAIT EVENTS TOP — Dove il DB sta "aspettando"
PROMPT ====================================================================

COL event FOR A45
COL wait_class FOR A15
COL total_waits FOR 999,999,999
COL time_waited_sec FOR 999,999
COL avg_wait_ms FOR 999.99

SELECT * FROM (
    SELECT
        event,
        wait_class,
        total_waits,
        ROUND(time_waited/100) AS time_waited_sec,
        ROUND(average_wait * 10, 2) AS avg_wait_ms
    FROM v$system_event
    WHERE wait_class NOT IN ('Idle', 'Other')
      AND total_waits > 0
    ORDER BY time_waited DESC
)
WHERE ROWNUM <= 15;


PROMPT ====================================================================
PROMPT  4. SESSIONI IN ATTESA — Adesso, in real-time
PROMPT ====================================================================

COL sid FOR 99999
COL username FOR A15
COL event FOR A40
COL wait_sec FOR 99999
COL sql_id FOR A15

SELECT
    s.sid, s.username,
    s.event,
    s.seconds_in_wait AS wait_sec,
    s.sql_id,
    s.blocking_session AS blocker
FROM v$session s
WHERE s.status = 'ACTIVE'
  AND s.type = 'USER'
  AND s.wait_class != 'Idle'
ORDER BY s.seconds_in_wait DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT ====================================================================
PROMPT  5. BUFFER CACHE HIT RATIO (deve essere > 95%)
PROMPT ====================================================================

SELECT
    ROUND(1 - (phy.value / (con.value + db.value)) , 4) * 100 AS buffer_cache_hit_pct
FROM v$sysstat phy, v$sysstat con, v$sysstat db
WHERE phy.name = 'physical reads'
  AND con.name = 'consistent gets'
  AND db.name = 'db block gets';

-- < 90% → Probabilmente SGA troppo piccola o full table scan frequenti.


PROMPT ====================================================================
PROMPT  6. LIBRARY CACHE HIT RATIO (deve essere > 99%)
PROMPT ====================================================================

SELECT
    ROUND(1 - SUM(reloads)/NULLIF(SUM(pins), 0), 4) * 100 AS library_cache_hit_pct
FROM v$librarycache;

-- < 95% → Shared pool troppo piccolo o hard parse eccessivi.


PROMPT ====================================================================
PROMPT  7. PGA — Uso memoria (sort, hash join in memoria vs disco)
PROMPT ====================================================================

COL name FOR A50
COL value_mb FOR 999,999.99

SELECT name, ROUND(value/1024/1024, 2) AS value_mb
FROM v$pgastat
WHERE name IN (
    'total PGA allocated',
    'total PGA inuse',
    'over allocation count',
    'extra bytes read/written',
    'aggregate PGA target parameter'
);


PROMPT ====================================================================
PROMPT  8. ASH — Cosa sta succedendo ADESSO (Active Session History)
PROMPT ====================================================================

COL sample_time FOR A20
COL session_id FOR 99999
COL sql_id FOR A15
COL event FOR A35
COL session_state FOR A10

SELECT TO_CHAR(sample_time, 'HH24:MI:SS') AS sample_time,
       session_id, sql_id,
       CASE session_state WHEN 'ON CPU' THEN 'ON CPU' ELSE event END AS event,
       session_state
FROM v$active_session_history
WHERE sample_time > SYSDATE - INTERVAL '5' MINUTE
ORDER BY sample_time DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT ====================================================================
PROMPT  9. SQL PLAN — Vedi il piano di una query specifica
PROMPT ====================================================================

-- Usa: SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('&SQL_ID'));
-- Oppure: SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_AWR('&SQL_ID'));

PROMPT ====================================================================
PROMPT  Fine Script 07 — Performance Quick
PROMPT ====================================================================
