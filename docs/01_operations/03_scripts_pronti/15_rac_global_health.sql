-- ============================================================================
-- SCRIPT 15: RAC GLOBAL HEALTH - overview cluster DB con GV$
-- Scenario: diagnosi rapida RAC, servizi sbilanciati, lock cross-instance,
--           top SQL globale, wait event gc/ges, longops per istanza.
-- ============================================================================

-- Runbook collegati:
--   - ../02_runbooks_incidenti/00_TRIAGE_INCIDENTI_ORACLE.md
--   - ../02_runbooks_incidenti/04_LOCK_SESSIONI_BLOCCATE.md
--   - ../02_runbooks_incidenti/05_QUERY_LENTA.md
--   - ../02_runbooks_incidenti/07_CPU_ALTA.md
--   - ../02_runbooks_incidenti/10_START_STOP_RAC.md
--   - ../02_runbooks_incidenti/26_LISTENER_SCAN_SERVICES_RAC.md
-- Uso rapido:
--   sqlplus / as sysdba @15_rac_global_health.sql
-- Nota: in RAC non killare mai usando solo SID/SERIAL#. Usa anche INST_ID.
SET LINESIZE 240
SET PAGESIZE 200
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT ====================================================================
PROMPT  1. RUOLO DATABASE E PROTEZIONE
PROMPT ====================================================================

COL db_unique_name FOR A20
COL database_role FOR A20
COL open_mode FOR A22
COL protection_mode FOR A25
COL switchover_status FOR A20

SELECT db_unique_name, database_role, open_mode, protection_mode, switchover_status
FROM v$database;


PROMPT ====================================================================
PROMPT  2. ISTANZE RAC
PROMPT ====================================================================

COL instance_name FOR A15
COL host_name FOR A35
COL status FOR A12
COL database_status FOR A18
COL active_state FOR A15
COL startup_time FOR A20

SELECT inst_id, instance_name, host_name, status, database_status, active_state,
       TO_CHAR(startup_time, 'DD-MON-YY HH24:MI') AS startup_time
FROM gv$instance
ORDER BY inst_id;


PROMPT ====================================================================
PROMPT  3. SERVIZI ATTIVI PER ISTANZA
PROMPT ====================================================================

COL name FOR A45
COL con_id FOR 99999

SELECT inst_id, name, con_id
FROM gv$active_services
WHERE name NOT LIKE 'SYS$%'
ORDER BY name, inst_id;


PROMPT ====================================================================
PROMPT  4. SESSIONI USER PER ISTANZA / STATO / WAIT CLASS
PROMPT ====================================================================

COL status FOR A10
COL wait_class FOR A20
COL sessions FOR 999999

SELECT inst_id, status, wait_class, COUNT(*) AS sessions
FROM gv$session
WHERE type = 'USER'
GROUP BY inst_id, status, wait_class
ORDER BY inst_id, sessions DESC;


PROMPT ====================================================================
PROMPT  5. BLOCKER/WAITER CROSS-INSTANCE E KILL COMMAND SICURO
PROMPT ====================================================================

COL username FOR A18
COL event FOR A40
COL kill_cmd FOR A80

SELECT s.inst_id, s.sid, s.serial#, s.username, s.status, s.sql_id,
       SUBSTR(s.event, 1, 40) AS event,
       s.blocking_instance, s.blocking_session,
       'ALTER SYSTEM KILL SESSION ''' || s.sid || ',' || s.serial# || ',@' || s.inst_id || ''' IMMEDIATE;' AS kill_cmd
FROM gv$session s
WHERE s.blocking_session IS NOT NULL
   OR EXISTS (
       SELECT 1
       FROM gv$session w
       WHERE w.blocking_instance = s.inst_id
         AND w.blocking_session = s.sid
   )
ORDER BY NVL(s.blocking_instance, s.inst_id), NVL(s.blocking_session, s.sid), s.inst_id, s.sid;


PROMPT ====================================================================
PROMPT  6. TOP SQL GLOBALE PER ELAPSED TIME
PROMPT ====================================================================

COL sql_id FOR A15
COL elapsed_sec FOR 999,999,999
COL executions FOR 999,999,999
COL avg_sec FOR 999,999.999
COL buffer_gets FOR 999,999,999,999
COL disk_reads FOR 999,999,999,999
COL sql_text_short FOR A70

SELECT *
FROM (
    SELECT sql_id,
           ROUND(SUM(elapsed_time)/1000000) AS elapsed_sec,
           SUM(executions) AS executions,
           ROUND(SUM(elapsed_time)/NULLIF(SUM(executions),0)/1000000, 3) AS avg_sec,
           SUM(buffer_gets) AS buffer_gets,
           SUM(disk_reads) AS disk_reads,
           MIN(SUBSTR(sql_text, 1, 70)) AS sql_text_short
    FROM gv$sql
    WHERE NVL(parsing_schema_name, '-') NOT IN ('SYS', 'SYSTEM', 'DBSNMP', 'MDSYS')
    GROUP BY sql_id
    ORDER BY SUM(elapsed_time) DESC
)
WHERE ROWNUM <= 15;


PROMPT ====================================================================
PROMPT  7. WAIT EVENT RAC GLOBAL CACHE / ENQUEUE SERVICE
PROMPT ====================================================================

COL event FOR A50
COL total_waits FOR 999,999,999
COL time_waited_sec FOR 999,999,999

SELECT *
FROM (
    SELECT inst_id, event, total_waits, ROUND(time_waited/100) AS time_waited_sec
    FROM gv$system_event
    WHERE (event LIKE 'gc%' OR event LIKE 'ges%')
      AND total_waits > 0
    ORDER BY time_waited DESC
)
WHERE ROWNUM <= 20;


PROMPT ====================================================================
PROMPT  8. LONGOPS PER ISTANZA
PROMPT ====================================================================

COL opname FOR A45
COL pct_done FOR 999.9
COL remaining_min FOR 999999

SELECT inst_id, sid, serial#, SUBSTR(opname, 1, 45) AS opname,
       ROUND(sofar/NULLIF(totalwork,0)*100, 1) AS pct_done,
       ROUND(time_remaining/60) AS remaining_min
FROM gv$session_longops
WHERE totalwork > 0
  AND sofar <> totalwork
ORDER BY start_time DESC;


PROMPT ====================================================================
PROMPT  9. TEMP USAGE PER ISTANZA
PROMPT ====================================================================

COL tablespace FOR A18
COL temp_mb FOR 999,999,999.99

SELECT s.inst_id, s.sid, s.serial#, s.username, s.sql_id,
       t.tablespace,
       ROUND(t.blocks * (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'db_block_size') / 1024/1024, 2) AS temp_mb
FROM gv$session s
JOIN gv$sort_usage t ON t.inst_id = s.inst_id AND t.session_addr = s.saddr
ORDER BY temp_mb DESC;


PROMPT ====================================================================
PROMPT  Fine Script 15 - RAC Global Health
PROMPT ====================================================================
