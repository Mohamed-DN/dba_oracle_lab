COL name FOR a12
COL program FOR a25
COL CPU FOR 9999
COL IO FOR 9999
COL TOTAL FOR 99999
COL WAIT FOR 9999
COL user_id FOR 99999
COL sid FOR 9999
SET LINESIZE 120

  SELECT DECODE (NVL (TO_CHAR (s.sid), -1), -1, 'DISCONNECTED', 'CONNECTED')
            "STATUS",
         topsession.sid "SID",
         u.username "NAME",
         topsession.program "PROGRAM",
         MAX (topsession.CPU) "CPU",
         MAX (topsession.WAIT) "WAITING",
         MAX (topsession.IO) "IO",
         MAX (topsession.TOTAL) "TOTAL"
    FROM (SELECT *
            FROM (  SELECT ash.session_id sid,
                           ash.session_serial# serial#,
                           ash.user_id user_id,
                           ash.program,
                           SUM (DECODE (ash.session_state, 'ON CPU', 1, 0)) "CPU",
                             SUM (DECODE (ash.session_state, 'WAITING', 1, 0))
                           - SUM (
                                DECODE (
                                   ash.session_state,
                                   'WAITING', DECODE (wait_class,
                                                      'User I/O', 1,
                                                      0),
                                   0))
                              "WAIT",
                           SUM (
                              DECODE (
                                 ash.session_state,
                                 'WAITING', DECODE (wait_class, 'User I/O', 1, 0),
                                 0))
                              "IO",
                           SUM (DECODE (session_state, 'ON CPU', 1, 1)) "TOTAL"
                      FROM v$active_session_history ash
                  GROUP BY session_id,
                           user_id,
                           session_serial#,
                           program
                  ORDER BY SUM (DECODE (session_state, 'ON CPU', 1, 1)) DESC)
           WHERE ROWNUM < 10) topsession,
         v$session s,
         all_users u
   WHERE     u.user_id = topsession.user_id
         AND /* outer join to v$session because the session might be disconnected */
             topsession.sid = s.sid(+)
         AND topsession.serial# = s.serial#(+)
GROUP BY topsession.sid,
         topsession.serial#,
         topsession.user_id,
         topsession.program,
         s.username,
         s.sid,
         s.paddr,
         u.username
ORDER BY MAX (topsession.TOTAL) DESC
/
