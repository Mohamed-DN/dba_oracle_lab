set line 3000
set pages 5000
col INTERVAL for a30

select
     to_char(BEGIN_INTERVAL_TIME,'dd/mm/yyyy hh24:mi') INTERVAL,
     avgwait "Avg Wait (ms)",
     event
from
    (select
          s.snap_id
          , S.BEGIN_INTERVAL_TIME
          , S.END_INTERVAL_TIME
          , e.event_name event
          , e.total_waits - nvl(b.total_waits,0)  waits
          , e.total_timeouts - nvl(b.total_timeouts,0) timeouts
          , ROUND((e.time_waited_micro - nvl(b.time_waited_micro,0))/1000000,2)  time
          ,  ROUND(decode ((e.total_waits - nvl(b.total_waits, 0)), 0, to_number(NULL),
            ((e.time_waited_micro - nvl(b.time_waited_micro,0))/1000) / (e.total_waits - nvl(b.total_waits,0)) ),2) avgwait
          , e.wait_class waitclass
     from
        dba_hist_system_event b ,
        dba_hist_system_event e ,
        dba_hist_snapshot s
     where
                      e.snap_id = s.snap_id
                  and s.begin_interval_time > SYSDATE - 90
                  and S.INSTANCE_NUMBER = 1
                  and e.snap_id  = ( b.snap_id  + 1 )
                  and b.instance_number(+)  = 1
                  and e.instance_number     = 1
                  and b.event_id(+)         = e.event_id
                  and e.total_waits         > nvl(b.total_waits,0)
                  and e.wait_class          <> 'Idle'
                  and e.event_name in (
                                    'log file sync'
                        )
                                    )
ORDER BY SNAP_ID, EVENT ASC
/


***********
 --'control file parallel write',
 --'control file sequential read',
 --'control file single write',
 --'control file parallel write',
 --'db file parallel read',
 --'db file scattered read',
-- 'db file sequential read'-- ,
-- 'direct path read',
 --'direct path read temp',
 --'direct path write',
 --'direct path sync',
 --'direct path write temp'--,
 --'log file parallel write',
 --'db file single write',
 --'db file parallel write'
 --'log file sync'
 --'direct path sync'
****************



SET LIN 190 PAGES 5000

COL BEGIN_INTERVAL_TIME FOR a30



  SELECT TO_CHAR (BEGIN_INTERVAL_TIME, 'dd/mm/yyyy hh24:mi'),
         avgwait "Avg Wait (ms)"
    FROM (SELECT s.snap_id,
                 S.BEGIN_INTERVAL_TIME,
                 S.END_INTERVAL_TIME,
                 e.event_name event,
                 e.total_waits - NVL (b.total_waits, 0) waits,
                 e.total_timeouts - NVL (b.total_timeouts, 0) timeouts,
                 ROUND (
                      (e.time_waited_micro - NVL (b.time_waited_micro, 0))
                    / 1000000,
                    2)
                    time,
                 ROUND (
                    DECODE (
                       (e.total_waits - NVL (b.total_waits, 0)),
                       0, TO_NUMBER (NULL),
                         (  (e.time_waited_micro - NVL (b.time_waited_micro, 0))
                          / 1000)
                       / (e.total_waits - NVL (b.total_waits, 0))),
                    2)
                    avgwait,
                 e.wait_class waitclass
            FROM dba_hist_system_event b,
                 dba_hist_system_event e,
                 dba_hist_snapshot s
           WHERE     e.snap_id = s.snap_id
                 AND s.begin_interval_time > SYSDATE - 30
                 AND S.INSTANCE_NUMBER = 1
                 AND e.snap_id = (b.snap_id + 1)
                 AND b.instance_number(+) = 1
                 AND e.instance_number = 1
                 AND b.event_id(+) = e.event_id
                 AND e.total_waits > NVL (b.total_waits, 0)
                 AND e.wait_class <> 'Idle'
                 AND e.event_name IN ('log file sync'))
ORDER BY SNAP_ID, EVENT ASC
/
