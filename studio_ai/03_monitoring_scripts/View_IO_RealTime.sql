with TOTAL_WAITS_LAST_SNAP as(
    SELECT
       TOTAL_WAITS,TIME_WAITED_MICRO,EVENT_NAME
    FROM dba_hist_system_event e
    WHERE SNAP_ID = (
            SELECT
               MAX(SNAP_ID)
            FROM dba_hist_system_event
       )
)
select
    ROUND((se.TIME_WAITED_MICRO - tw.time_waited_micro )/(se.TOTAL_WAITS - tw.TOTAL_WAITS)/1000,2) AS AVG_TIME_MS,event
from sys.v_$system_event se,
        TOTAL_WAITS_LAST_SNAP tw
where event in (
                                       --'control file parallel write'
                                       --'control file sequential read',
                                       --'control file single write',
                                       --'control file parallel write',
                                       --'db file parallel read'
                                       --'db file scattered read'
                                       --'db file sequential read'
                                       --'flashback log file sync'
                                       --'direct path read',
                                       --'direct path read temp'
                                       --'direct path write'
                                       --'direct path write temp'
                                       --'log file parallel write'
                                       --'db file single write',
                                       --'db file parallel write',
                                       'log file sync'
                        )
and se.event = tw.event_name
/
