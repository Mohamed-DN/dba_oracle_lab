-- Backup completati 
col STATUS format a15
col hrs format 999.99
col min format 999.99
col  input_type for a15
col start_time for a15
col end_time for a15
---- Check output parameter where view is based:
-- CONFIGURE RMAN OUTPUT TO KEEP FOR 31 DAYS;

 
select SESSION_KEY, INPUT_TYPE, STATUS,
 to_char(START_TIME,'dd/mm/yy hh24:mi') start_time,
 to_char(END_TIME,'dd/mm/yy hh24:mi') end_time,
 elapsed_seconds/3600 hrs,
 elapsed_seconds/60 min
 from V$RMAN_BACKUP_JOB_DETAILS
 --where INPUT_TYPE='DB FULL'
  --where  input_type <> 'ARCHIVELOG'
 order by session_key;
 
-- Backup in corso  
 SELECT SID, SERIAL#, CONTEXT, SOFAR, TOTALWORK, 
ROUND (SOFAR/TOTALWORK*100, 2) "% COMPLETE"
FROM V$SESSION_LONGOPS
WHERE OPNAME LIKE 'RMAN%' AND OPNAME NOT LIKE '%aggregate%'
AND TOTALWORK != 0 AND SOFAR <> TOTALWORK;


-- Backup completati 
col STATUS format a9
col hrs format 999.99
select SESSION_KEY, INPUT_TYPE, STATUS,
 to_char(START_TIME,'dd/mm/yy hh24:mi') start_time,
 to_char(END_TIME,'dd/mm/yy hh24:mi') end_time,
 elapsed_seconds/3600 hrs
 from V$BACKUP_SET
 order by session_key;
 
 
 
 
-- Backup completati 
col STATUS format a9
col hrs format 999.99
select   
 to_char(START_TIME,'mm/dd/yy hh24:mi') start_time,
 to_char(completion_TIME,'mm/dd/yy hh24:mi') end_time,
 elapsed_seconds/3600 hrs
 from V$BACKUP_SET
 order by session_key;
 
 
 SELECT BD.FILE#, BD.INCREMENTAL_LEVEL, BD.COMPLETION_TIME, BD.BLOCKS, BD.DATAFILE_BLOCKS, BS.BACKUP_TYPE 
  FROM V$BACKUP_DATAFILE BD,
       V$BACKUP_SET BS
  WHERE BS.RECID = BD.RECID
  AND INCREMENTAL_LEVEL > 0 
  AND BLOCKS / DATAFILE_BLOCKS > .5 
  ORDER BY BD.COMPLETION_TIME;

----------------------------------------------------------------------------------------------------------------------

Viewing RMAN Jobs Status And Output
by André Araújo August 26, 2011
Posted in: Technical Track
Tags: Group Blog Posts, Oracle, Technical Blog
Yesterday I was discussing with a fellow DBA about ways to check the status of existing and/or past RMAN jobs. Good backup scripts usually write their output to some sort of log file so, checking the output is usually a straight-forward task. However, backup jobs can be scheduled in many different ways (crontab, Grid Control, Scheduled Tasks, etc) and finding the log file may be tricky if you dont know the environment well.
Furthermore, log files may also have already been overwritten by the next backup or simply just deleted. An alternative way of accessing that information, thus, may come handy.

Fortunately, RMAN keeps the backup metadata around for some time and it can be accessed through the databases V$ views. Obviously, if you need this information because your database just crashed and needs to be restored, the method described here is useless.


Backup Jobs Status And Metadata
A lot of metadata about the RMAN backup jobs can be found in the V$RMAN_% views. These views show past RMAN jobs as well as jobs currently running. Once the jobs complete backup sets, metadata about the sets and pieces are also added to the control file and can be accessed through the V$BACKUP_% views.

For the queries in this post I need only four of those views:

V$BACKUP_SET
V$BACKUP_SET_DETAILS
V$RMAN_BACKUP_JOB_DETAILS
GV$RMAN_OUTPUT

NOTE: I havent tested the below in Oracle 10g or earlier.

In the query below I used these views to combine in a single query the information Im usually interested in when verifying backup jobs:

-- CF: Number of controlfile backups included in the backup set
-- DF: Number of datafile full backups included in the backup set
-- I0: Number of datafile incremental level-0 backups included in the backup set
-- I1: Number of datafile incremental level-1 backups included in the backup set
-- L : Number of archived log backups included in the backup set  
-- Please note that the aggregations are only shown for the recent backup jobs in the example above, since they are purged from the catalog after a few days.
-- Another important thing to note is that in a RAC environment some fields for a RUNNING backup job may contain invalid information until the backup job is finished. To get consistent information, run this query on the node where the backup is running.
  
set lines 220
set pages 1000
col cf for 9,999
col df for 9,999
col elapsed_seconds heading "ELAPSED|SECONDS"
col i0 for 9,999
col i1 for 9,999
col l for 9,999
col output_mbytes for 9,999,999 heading "OUTPUT|MBYTES"
col session_recid for 999999 heading "SESSION|RECID"
col session_stamp for 99999999999 heading "SESSION|STAMP"
col status for a10 trunc
col time_taken_display for a10 heading "TIME|TAKEN"
col output_instance for 9999 heading "OUT|INST"
select
  j.session_recid, j.session_stamp,
  to_char(j.start_time, 'yyyy-mm-dd hh24:mi:ss') start_time,
  to_char(j.end_time, 'yyyy-mm-dd hh24:mi:ss') end_time,
  (j.output_bytes/1024/1024) output_mbytes, j.status, j.input_type,
  decode(to_char(j.start_time, 'd'), 1, 'Sunday', 2, 'Monday',
                                     3, 'Tuesday', 4, 'Wednesday',
                                     5, 'Thursday', 6, 'Friday',
                                     7, 'Saturday') dow,
  j.elapsed_seconds, j.time_taken_display,
  x.cf, x.df, x.i0, x.i1, x.l,
  ro.inst_id output_instance
from V$RMAN_BACKUP_JOB_DETAILS j
  left outer join (select
                     d.session_recid, d.session_stamp,
                     sum(case when d.controlfile_included = 'YES' then d.pieces else 0 end) CF,
                     sum(case when d.controlfile_included = 'NO'
                               and d.backup_type||d.incremental_level = 'D' then d.pieces else 0 end) DF,
                     sum(case when d.backup_type||d.incremental_level = 'D0' then d.pieces else 0 end) I0,
                     sum(case when d.backup_type||d.incremental_level = 'I1' then d.pieces else 0 end) I1,
                     sum(case when d.backup_type = 'L' then d.pieces else 0 end) L
                   from
                     V$BACKUP_SET_DETAILS d
                     join V$BACKUP_SET s on s.set_stamp = d.set_stamp and s.set_count = d.set_count
                   where s.input_file_scan_only = 'NO'
                   group by d.session_recid, d.session_stamp) x
    on x.session_recid = j.session_recid and x.session_stamp = j.session_stamp
  left outer join (select o.session_recid, o.session_stamp, min(inst_id) inst_id
                   from GV$RMAN_OUTPUT o
                   group by o.session_recid, o.session_stamp)
    ro on ro.session_recid = j.session_recid and ro.session_stamp = j.session_stamp
where j.start_time > trunc(sysdate)-&NUMBER_OF_DAYS
order by j.start_time;                        



--Backup Set Details                                                                                                                                                                                                                                                              

--Once you found the general information about the backup sets available, you may need to get more information about the backup sets for one particular backup job. Each backup job is uniquely identified by (SESSION_RECID, SESSION_STAMP), which are listed by the query above.                                                                                                                                                                                                                                                                                
--The query below retrieves details for a backup job, given a pair of values for (SESSION_RECID, SESSION_STAMP):                                                                                                                                                                  
                                                                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                                            
set lines 220                                                                                                                                                                                                                                                                   
set pages 1000                                                                                                                                                                                                                                                                  
col backup_type for a4 heading "TYPE"                                                                                                                                                                                                                                           
col controlfile_included heading "CF?"                                                                                                                                                                                                                                          
col incremental_level heading "INCR LVL"                                                                                                                                                                                                                                        
col pieces for 999 heading "PCS"                                                                                                                                                                                                                                                
col elapsed_seconds heading "ELAPSED|SECONDS"                                                                                                                                                                                                                                   
col device_type for a10 trunc heading "DEVICE|TYPE"                                                                                                                                                                                                                             
col compressed for a4 heading "ZIP?"                                                                                                                                                                                                                                            
col output_mbytes for 9,999,999 heading "OUTPUT|MBYTES"                                                                                                                                                                                                                         
col input_file_scan_only for a4 heading "SCAN|ONLY"                                                                                                                                                                                                                             
select                                                                                                                                                                                                                                                                          
  d.bs_key, d.backup_type, d.controlfile_included, d.incremental_level, d.pieces, 
  to_char(d.start_time, 'yyyy-mm-dd hh24:mi:ss') start_time,   
  to_char(d.completion_time, 'yyyy-mm-dd hh24:mi:ss') completion_time, 
  d.elapsed_seconds, d.device_type, d.compressed, (d.output_bytes/1024/1024) output_mbytes, s.input_file_scan_only 
  from V$BACKUP_SET_DETAILS d 
  join V$BACKUP_SET s on s.set_stamp = d.set_stamp and s.set_count = d.set_count
where session_recid = &SESSION_RECID 
  and session_stamp = &SESSION_STAMP
order by d.start_time;              



Backup Job Output
And finally, sometimes it may be helpful to retrieve the jobs output from the metadata kept by the instance.
It might be that the original log on disk, if any, may have been overwritten by a more recent backup, or just that selecting it from a V$ view may be easier than connecting to a server to find out were the log file is.

The tricky thing here, though, is that the view that contains the output, V$RMAN_OUTPUT, exists in memory only; the jobs output is not stored in the controlfile or anywhere else in the database. Thus, if the instance gets restarted, the contents of that view are reset.

To retrieve the job output for a specific backup job, identified by the (SESSION_RECID, SESSION_STAMP) pair, you can use the following query:

set lines 200
set pages 1000
select output
from GV$RMAN_OUTPUT
where session_recid = &SESSION_RECID
  and session_stamp = &SESSION_STAMP
order by recid;                                                                                                                                                                                                                                           