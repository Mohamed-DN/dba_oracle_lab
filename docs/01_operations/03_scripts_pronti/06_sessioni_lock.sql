-- ============================================================================
-- SCRIPT 06: SESSIONI E LOCK - Chi blocca chi, kill session
-- Scenario: applicazione bloccata, deadlock, enqueue wait, lock RAC
-- ============================================================================

-- Runbook collegati:
--   - ../02_runbooks_incidenti/04_LOCK_SESSIONI_BLOCCATE.md
--   - ../02_runbooks_incidenti/07_CPU_ALTA.md
--   - ../02_runbooks_incidenti/08_ORA_ERRORS.md
-- Uso rapido:
--   sqlplus / as sysdba @06_sessioni_lock.sql
-- RAC: usa GV$ dove serve; controlla sempre INST_ID prima di killare.
-- Nota: verificare ambiente, ruolo database e privilegi prima di azioni correttive.
SET LINESIZE 220
SET PAGESIZE 200
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT ====================================================================
PROMPT  1. SESSIONI ATTIVE - overview RAC-aware
PROMPT ====================================================================

COL inst_id FOR 999
COL username FOR A20
COL status FOR A10
COL machine FOR A25
COL program FOR A30
COL sql_id FOR A15
COL event FOR A35
COL wait_sec FOR 999999

SELECT
    s.inst_id,
    s.sid,
    s.serial#,
    s.username,
    s.status,
    SUBSTR(s.machine, 1, 25) AS machine,
    SUBSTR(s.program, 1, 30) AS program,
    s.sql_id,
    SUBSTR(s.event, 1, 35) AS event,
    s.seconds_in_wait AS wait_sec
FROM gv$session s
WHERE s.type = 'USER'
  AND s.username IS NOT NULL
ORDER BY s.inst_id, s.status, s.seconds_in_wait DESC;


PROMPT ====================================================================
PROMPT  2. CHI BLOCCA CHI - lock holder/waiter cross-instance
PROMPT ====================================================================

COL blocker FOR A32
COL blocked FOR A32
COL lock_type FOR A15
COL blocked_sql FOR A50

SELECT
    'I' || l1.inst_id || ' SID ' || l1.sid || ' (' || s1.username || ')' AS blocker,
    'I' || l2.inst_id || ' SID ' || l2.sid || ' (' || s2.username || ')' AS blocked,
    l1.type AS lock_type,
    l2.ctime AS wait_seconds,
    SUBSTR((SELECT q.sql_text
            FROM gv$sql q
            WHERE q.inst_id = s2.inst_id
              AND q.sql_id = s2.sql_id
              AND ROWNUM = 1), 1, 50) AS blocked_sql
FROM gv$lock l1
JOIN gv$lock l2 ON l1.id1 = l2.id1 AND l1.id2 = l2.id2
JOIN gv$session s1 ON l1.inst_id = s1.inst_id AND l1.sid = s1.sid
JOIN gv$session s2 ON l2.inst_id = s2.inst_id AND l2.sid = s2.sid
WHERE l1.block IN (1, 2)
  AND l2.request > 0
ORDER BY l2.ctime DESC;


PROMPT ====================================================================
PROMPT  3. CATENA BLOCCHI RAC - blocker/waiter con INST_ID
PROMPT ====================================================================

COL session_ref FOR A28
COL blocker_ref FOR A28
COL username FOR A15
COL status FOR A10
COL sql_id FOR A15
COL event FOR A35
COL wait_sec FOR 999999

SELECT
    'I' || s.inst_id || ' SID=' || s.sid || ',' || s.serial# AS session_ref,
    CASE
        WHEN s.blocking_session IS NOT NULL
        THEN 'I' || s.blocking_instance || ' SID=' || s.blocking_session
        ELSE 'ROOT/BLOCKER'
    END AS blocker_ref,
    s.username,
    s.status,
    s.sql_id,
    SUBSTR(s.event, 1, 35) AS event,
    s.seconds_in_wait AS wait_sec
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
PROMPT  4. DETTAGLIO LOCK - Tipo di lock e oggetti
PROMPT ====================================================================

COL owner FOR A15
COL object_name FOR A30
COL object_type FOR A15
COL locked_mode FOR A20

SELECT
    s.inst_id,
    s.sid,
    s.serial#,
    s.username,
    o.owner,
    o.object_name,
    o.object_type,
    DECODE(l.locked_mode,
        0, 'NONE',
        1, 'NULL',
        2, 'ROW-S (SS)',
        3, 'ROW-X (SX)',
        4, 'SHARE (S)',
        5, 'S/ROW-X (SSX)',
        6, 'EXCLUSIVE (X)',
        l.locked_mode) AS locked_mode
FROM gv$locked_object l
JOIN gv$session s ON l.inst_id = s.inst_id AND l.session_id = s.sid
JOIN dba_objects o ON l.object_id = o.object_id
WHERE s.username IS NOT NULL
ORDER BY s.inst_id, o.object_name;


PROMPT ====================================================================
PROMPT  5. DDL LOCK - Lock da ALTER TABLE, CREATE INDEX, etc.
PROMPT ====================================================================

COL owner FOR A15
COL name FOR A30
COL type FOR A15
COL mode_held FOR A15

SELECT
    d.session_id AS sid,
    d.owner,
    d.name,
    d.type,
    d.mode_held
FROM dba_ddl_locks d
WHERE d.owner NOT IN ('SYS', 'SYSTEM')
ORDER BY d.owner, d.name;


PROMPT ====================================================================
PROMPT  6. KILL SESSION - Comandi pronti
PROMPT ====================================================================

-- KILL SINGOLA SESSIONE single instance:
-- ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
--
-- KILL SINGOLA SESSIONE RAC:
-- ALTER SYSTEM KILL SESSION 'sid,serial#,@inst_id' IMMEDIATE;
--
-- GENERA COMANDI KILL RAC PER UN UTENTE:
-- SELECT 'ALTER SYSTEM KILL SESSION ''' || sid || ',' || serial# || ',@' || inst_id || ''' IMMEDIATE;' AS kill_cmd
-- FROM gv$session
-- WHERE username = 'UTENTE_BLOCCANTE';
--
-- KILL A LIVELLO OS se la sessione non muore:
-- SELECT s.inst_id, 'kill -9 ' || p.spid AS os_kill_cmd
-- FROM gv$session s
-- JOIN gv$process p ON s.inst_id = p.inst_id AND s.paddr = p.addr
-- WHERE s.inst_id = &INST_ID AND s.sid = &SID_DA_KILLARE;


PROMPT ====================================================================
PROMPT  7. DEADLOCK - Check recenti alert log locale
PROMPT ====================================================================

-- In RAC il trace/alert e per istanza: eseguire sul nodo interessato o usare ADRCI.
COL message FOR A120

SELECT TO_CHAR(originating_timestamp, 'DD-MON HH24:MI:SS') AS ts,
       SUBSTR(message_text, 1, 120) AS message
FROM v$diag_alert_ext
WHERE message_text LIKE '%deadlock%'
  AND originating_timestamp > SYSDATE - 7
ORDER BY originating_timestamp DESC
FETCH FIRST 10 ROWS ONLY;


PROMPT ====================================================================
PROMPT  8. ENQUEUE WAITS - Top lock wait events per istanza
PROMPT ====================================================================

COL event FOR A40
COL total_waits FOR 999999999
COL time_waited_sec FOR 999999

SELECT *
FROM (
    SELECT inst_id, event, total_waits, ROUND(time_waited/100, 0) AS time_waited_sec
    FROM gv$system_event
    WHERE event LIKE 'enq:%'
      AND total_waits > 0
    ORDER BY time_waited DESC
)
WHERE ROWNUM <= 15;

PROMPT ====================================================================
PROMPT  Fine Script 06 - Sessioni & Lock
PROMPT ====================================================================
