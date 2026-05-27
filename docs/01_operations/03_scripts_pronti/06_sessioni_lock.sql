-- ============================================================================
-- SCRIPT 06: SESSIONI E LOCK — Chi blocca chi, kill session
-- Scenario: "L'applicazione è bloccata!", deadlock, enqueue wait
-- ============================================================================

-- Runbook collegati:
--   - ../02_runbooks_incidenti/04_LOCK_SESSIONI_BLOCCATE.md
--   - ../02_runbooks_incidenti/07_CPU_ALTA.md
--   - ../02_runbooks_incidenti/08_ORA_ERRORS.md
-- Uso rapido:
--   sqlplus / as sysdba @06_sessioni_lock.sql
-- Nota: verificare sempre ambiente, ruolo database e privilegi prima di eseguire azioni correttive.
SET LINESIZE 220
SET PAGESIZE 200
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT ====================================================================
PROMPT  1. SESSIONI ATTIVE (overview)
PROMPT ====================================================================

COL username FOR A20
COL status FOR A10
COL machine FOR A25
COL program FOR A30
COL sql_id FOR A15
COL event FOR A35
COL wait_sec FOR 999999

SELECT
    s.sid, s.serial#, s.username, s.status,
    SUBSTR(s.machine, 1, 25) AS machine,
    SUBSTR(s.program, 1, 30) AS program,
    s.sql_id,
    SUBSTR(s.event, 1, 35) AS event,
    s.seconds_in_wait AS wait_sec
FROM v$session s
WHERE s.type = 'USER'
  AND s.username IS NOT NULL
ORDER BY s.status, s.seconds_in_wait DESC;


PROMPT ====================================================================
PROMPT  2. CHI BLOCCA CHI — Albero dei blocchi
PROMPT ====================================================================

COL blocker FOR A30
COL blocked FOR A30
COL lock_type FOR A15
COL blocked_sql FOR A50

SELECT
    'SID ' || l1.sid || ' (' || s1.username || ')' AS blocker,
    'SID ' || l2.sid || ' (' || s2.username || ')' AS blocked,
    l1.type AS lock_type,
    l2.ctime AS wait_seconds,
    SUBSTR((SELECT sql_text FROM v$sql WHERE sql_id = s2.sql_id AND ROWNUM = 1), 1, 50) AS blocked_sql
FROM v$lock l1
JOIN v$lock l2 ON l1.id1 = l2.id1 AND l1.id2 = l2.id2
JOIN v$session s1 ON l1.sid = s1.sid
JOIN v$session s2 ON l2.sid = s2.sid
WHERE l1.block = 1
  AND l2.request > 0
ORDER BY l2.ctime DESC;


PROMPT ====================================================================
PROMPT  3. ALBERO BLOCCHI (gerarchico) — Più elegante
PROMPT ====================================================================

COL tree FOR A60
COL username FOR A15
COL status FOR A10
COL sql_id FOR A15
COL wait_sec FOR 999999

SELECT
    LPAD(' ', 2 * (LEVEL - 1)) ||
    'SID=' || s.sid || ' SER=' || s.serial# || ' ' || s.username AS tree,
    s.status,
    s.sql_id,
    s.seconds_in_wait AS wait_sec
FROM v$session s
WHERE s.blocking_session IS NOT NULL
   OR s.sid IN (SELECT blocking_session FROM v$session WHERE blocking_session IS NOT NULL)
START WITH s.blocking_session IS NULL
       AND s.sid IN (SELECT blocking_session FROM v$session WHERE blocking_session IS NOT NULL)
CONNECT BY PRIOR s.sid = s.blocking_session;


PROMPT ====================================================================
PROMPT  4. DETTAGLIO LOCK — Tipo di lock e oggetti
PROMPT ====================================================================

COL owner FOR A15
COL object_name FOR A30
COL object_type FOR A15
COL locked_mode FOR A20

SELECT
    s.sid, s.serial#, s.username,
    o.owner, o.object_name, o.object_type,
    DECODE(l.locked_mode,
        0, 'NONE',
        1, 'NULL',
        2, 'ROW-S (SS)',
        3, 'ROW-X (SX)',
        4, 'SHARE (S)',
        5, 'S/ROW-X (SSX)',
        6, 'EXCLUSIVE (X)',
        l.locked_mode) AS locked_mode
FROM v$locked_object l
JOIN v$session s ON l.session_id = s.sid
JOIN dba_objects o ON l.object_id = o.object_id
WHERE s.username IS NOT NULL
ORDER BY o.object_name;


PROMPT ====================================================================
PROMPT  5. DDL LOCK — Lock da ALTER TABLE, CREATE INDEX, etc.
PROMPT ====================================================================

COL owner FOR A15
COL name FOR A30
COL type FOR A15
COL mode_held FOR A15

SELECT
    d.session_id AS sid,
    d.owner, d.name, d.type,
    d.mode_held
FROM dba_ddl_locks d
WHERE d.owner NOT IN ('SYS', 'SYSTEM')
ORDER BY d.owner, d.name;


PROMPT ====================================================================
PROMPT  6. KILL SESSION — Comandi pronti (decommentare se necessario)
PROMPT ====================================================================

-- #### KILL SINGOLA SESSIONE ####
-- ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
--
-- #### KILL A LIVELLO OS (se la sessione non muore) ####
-- SELECT 'kill -9 ' || p.spid AS os_kill_cmd
-- FROM v$session s JOIN v$process p ON s.paddr = p.addr
-- WHERE s.sid = &SID_DA_KILLARE;
--
-- #### KILL TUTTE LE SESSIONI DI UN UTENTE ####
-- BEGIN
--   FOR r IN (SELECT sid, serial# FROM v$session WHERE username = 'UTENTE_BLOCCANTE') LOOP
--     EXECUTE IMMEDIATE 'ALTER SYSTEM KILL SESSION ''' || r.sid || ',' || r.serial# || ''' IMMEDIATE';
--   END LOOP;
-- END;
-- /


PROMPT ====================================================================
PROMPT  7. DEADLOCK — Check recenti
PROMPT ====================================================================

-- I deadlock generano un trace file. Cerca nell'alert log:
COL message FOR A120
SELECT TO_CHAR(originating_timestamp, 'DD-MON HH24:MI:SS') AS ts,
       SUBSTR(message_text, 1, 120) AS message
FROM v$diag_alert_ext
WHERE message_text LIKE '%deadlock%'
  AND originating_timestamp > SYSDATE - 7
ORDER BY originating_timestamp DESC
FETCH FIRST 10 ROWS ONLY;


PROMPT ====================================================================
PROMPT  8. ENQUEUE WAITS — Top lock wait events
PROMPT ====================================================================

COL event FOR A40
COL total_waits FOR 999999999
COL time_waited_sec FOR 999999

SELECT event, total_waits, ROUND(time_waited/100, 0) AS time_waited_sec
FROM v$system_event
WHERE event LIKE 'enq:%'
  AND total_waits > 0
ORDER BY time_waited DESC
FETCH FIRST 15 ROWS ONLY;

PROMPT ====================================================================
PROMPT  Fine Script 06 — Sessioni & Lock
PROMPT ====================================================================
