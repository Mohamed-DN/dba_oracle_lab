-- EVENT HISTOGRAMS

db file sequential read (read I/O timing)
log file parallel write (I/O writing times by the Log Writer)
log file sync (overall commit time)
enq: TX - index contention
enq: TX - row lock contention

-- INST 1

set pages 1000
set lines   1000

col BEGIN_INTERVAL_TIME for a20
col END_INTERVAL_TIME for a20
col "Event Name" for a30
col "Wait Class" for a15

ALTER SESSION SET NLS_TIMESTAMP_FORMAT='DD/MM/YYYY HH24:MI' ;

select
       snap_id,
       BEGIN_INTERVAL_TIME,
       END_INTERVAL_TIME,
--     event "Event Name",
       waits "Waits",
       timeouts "Timeouts",
       time "Wait Time (s)",
       avgwait "Avg Wait (ms)",
       waitclass "Wait Class"
from
      (select
            s.snap_id
            , S.BEGIN_INTERVAL_TIME
            , S.END_INTERVAL_TIME
       --     , e.event_name event
            , e.total_waits - nvl(b.total_waits,0)  waits
            , e.total_timeouts - nvl(b.total_timeouts,0) timeouts
            , ROUND((e.time_waited_micro -
nvl(b.time_waited_micro,0))/1000000,2)  time
            ,  ROUND(decode ((e.total_waits - nvl(b.total_waits, 0)), 0, to_number(NULL),
              ((e.time_waited_micro - nvl(b.time_waited_micro,0))/1000) / (e.total_waits - nvl(b.total_waits,0)) ),2) avgwait
            , e.wait_class waitclass
       from
          dba_hist_system_event b ,
          dba_hist_system_event e ,
          dba_hist_snapshot s
       where        s.BEGIN_INTERVAL_TIME > sysdate-7 and
                          e.snap_id = s.snap_id
                    and S.INSTANCE_NUMBER = 1
                    and e.snap_id  = ( b.snap_id  + 1 )
                    and b.instance_number(+)  = 1
                    and e.instance_number     = 1
                    and b.event_id(+)         = e.event_id
                    and e.total_waits > nvl(b.total_waits,0)
                    and e.wait_class <> 'Idle'
                    and e.event_name in ('db file sequential read' )) ORDER BY SNAP_ID ASC;

-- INST 2

set pages 1000
set lines   1000

col BEGIN_INTERVAL_TIME for a20
col END_INTERVAL_TIME for a20
col "Event Name" for a30
col "Wait Class" for a15

ALTER SESSION SET NLS_TIMESTAMP_FORMAT='DD/MM/YYYY HH24:MI' ;

select
       snap_id,
       BEGIN_INTERVAL_TIME,
       END_INTERVAL_TIME,
--     event "Event Name",
       waits "Waits",
       timeouts "Timeouts",
       time "Wait Time (s)",
       avgwait "Avg Wait (ms)",
       waitclass "Wait Class"
from
      (select
            s.snap_id
            , S.BEGIN_INTERVAL_TIME
            , S.END_INTERVAL_TIME
       --     , e.event_name event
            , e.total_waits - nvl(b.total_waits,0)  waits
            , e.total_timeouts - nvl(b.total_timeouts,0) timeouts
            , ROUND((e.time_waited_micro -
nvl(b.time_waited_micro,0))/1000000,2)  time
            ,  ROUND(decode ((e.total_waits - nvl(b.total_waits, 0)), 0, to_number(NULL),
              ((e.time_waited_micro - nvl(b.time_waited_micro,0))/1000) / (e.total_waits - nvl(b.total_waits,0)) ),2) avgwait
            , e.wait_class waitclass
       from
          dba_hist_system_event b ,
          dba_hist_system_event e ,
          dba_hist_snapshot s
       where        s.BEGIN_INTERVAL_TIME > sysdate-7 and
                          e.snap_id = s.snap_id
                    and S.INSTANCE_NUMBER = 2
                    and e.snap_id  = ( b.snap_id  + 1 )
                    and b.instance_number(+)  = 2
                    and e.instance_number     = 2
                    and b.event_id(+)         = e.event_id
                    and e.total_waits > nvl(b.total_waits,0)
                    and e.wait_class <> 'Idle'
                    and e.event_name in ('db file sequential read' )) ORDER BY SNAP_ID ASC;
