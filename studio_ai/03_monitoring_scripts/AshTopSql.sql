COL type FOR a10
COL "CPU" FOR 999999
COL "IO" FOR 999999

SELECT *
  FROM (  SELECT ash.SQL_ID,
                 ash.SQL_PLAN_HASH_VALUE Plan_hash,
                 aud.name TYPE,
                 SUM (DECODE (ash.session_state, 'ON CPU', 1, 0)) "CPU",
                   SUM (DECODE (ash.session_state, 'WAITING', 1, 0))
                 - SUM (
                      DECODE (ash.session_state,
                              'WAITING', DECODE (wait_class, 'User I/O', 1, 0),
                              0))
                    "WAIT",
                 SUM (
                    DECODE (ash.session_state,
                            'WAITING', DECODE (wait_class, 'User I/O', 1, 0),
                            0))
                    "IO",
                 SUM (DECODE (ash.session_state, 'ON CPU', 1, 1)) "TOTAL"
            FROM dba_hist_active_sess_history ash, audit_actions aud
           WHERE SQL_ID IS NOT NULL
                 AND ash.sql_opcode = aud.action
        -- and ash.sample_time > sysdate - minutes /( 60*24)
        GROUP BY sql_id, SQL_PLAN_HASH_VALUE, aud.name
        ORDER BY SUM (DECODE (session_state, 'ON CPU', 1, 1)) DESC)
 WHERE ROWNUM < 10
/
