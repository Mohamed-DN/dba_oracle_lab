-- ################
-- ### AUTOTASK ###
-- ################

-- Check Autotask job history
set line 200 
set pages 200
col job_status for a12
col CLIENT_NAME for a35
col WINDOW_NAME for a25
col WINDOW_START_TIME for a35
col JOB_START_TIME for a45
col JOB_DURATION for a35
select job_status, window_name, window_start_time, job_start_time, job_duration
from dba_autotask_job_history
where client_name='auto optimizer stats collection'
order by 3,4;

-- ##################
-- ### JOB ERRORS ###
-- ##################

-- Check the reason for the failure
col log_date for a40
col actual_start_date for a40
col run_duration for a15
select log_date, actual_start_date, run_duration, status, additional_info from dba_scheduler_job_run_details where job_name like 'ORA$AT_OS_OPT%' order by log_date;

-- ##################
-- ### LAST STATS ###
-- ##################

-- Check if the autotask did something during the last maintenance window

alter session set nls_date_format='dd/mm/yyyy hh24:mi:ss';
col owner for a25
col table_owner for a25
col table_name for a40
col partition_name for a40
col subpartition_name for a40

select owner, table_name, last_analyzed from dba_tables where owner not in ('SYS','SYSTEM') and last_analyzed > sysdate -1 order by last_analyzed;

select table_owner, table_name, partition_name, last_analyzed from dba_tab_partitions where table_owner not in ('SYS','SYSTEM') and last_analyzed > sysdate -1 order by last_analyzed;

select table_owner, table_name, partition_name, subpartition_name, last_analyzed from dba_tab_subpartitions where table_owner not in ('SYS','SYSTEM') and last_analyzed > sysdate -1 order by last_analyzed;

-- ###################
-- ### STALE STATS ###
-- ###################

-- Flush the stats info from the cache, then check the objects with stale statitics, ordered by their size

exec dbms_stats.flush_database_monitoring_info

alter session set nls_date_format='dd/mm/yyyy hh24:mi:ss';
col owner for a25
col table_owner for a25
col table_name for a40
col partition_name for a40
col subpartition_name for a40
select owner, table_name, partition_name, subpartition_name, blocks, num_rows, last_analyzed from dba_tab_statistics where stale_stats ='YES' and owner not in ('SYS','SYSTEM') order by blocks;

-- ###################
-- ### BIG OBJECTS ###
-- ###################

-- Check the biggest objects of the DB. Usually the biggest tables (both not-partitioned or "partitioned without incremental stats set") can lead to high execution time for statistics

col owner for a25
col segment_name for a40
col tablespace_name for a30
select owner, segment_name, segment_type, tablespace_name, count(1) COUNT, round(sum(bytes)/1024/1024/1024) GB from dba_segments where owner not in ('SYS','SYSTEM')
group by owner, segment_name, segment_type, tablespace_name having round(sum(bytes)/1024/1024/1024) > 100 order by 6 desc;

-- ##############################
-- ### FASTER STATS GATHERING ###
-- ##############################

-- Statistics gathering can be parallelized at system level, or only for the biggest tables
-- Increment it gradually

COLUMN autostats_target FORMAT A20
COLUMN cascade FORMAT A25
COLUMN degree FORMAT A10
COLUMN estimate_percent FORMAT A30
COLUMN method_opt FORMAT A25
COLUMN no_invalidate FORMAT A30
COLUMN granularity FORMAT A15
COLUMN publish FORMAT A10
COLUMN incremental FORMAT A15
COLUMN stale_percent FORMAT A15

SELECT DBMS_STATS.GET_PREFS('AUTOSTATS_TARGET') AS autostats_target,
       DBMS_STATS.GET_PREFS('CASCADE') AS cascade,
       DBMS_STATS.GET_PREFS('DEGREE') AS degree,
       DBMS_STATS.GET_PREFS('ESTIMATE_PERCENT') AS estimate_percent,
       DBMS_STATS.GET_PREFS('METHOD_OPT') AS method_opt,
       DBMS_STATS.GET_PREFS('NO_INVALIDATE') AS no_invalidate,
       DBMS_STATS.GET_PREFS('GRANULARITY') AS granularity,
       DBMS_STATS.GET_PREFS('PUBLISH') AS publish,
       DBMS_STATS.GET_PREFS('INCREMENTAL') AS incremental,
       DBMS_STATS.GET_PREFS('STALE_PERCENT') AS stale_percent
FROM   dual;

AUTOSTATS_TARGET     CASCADE                   DEGREE     ESTIMATE_PERCENT               METHOD_OPT                NO_INVALIDATE                  GRANULARITY     PUBLISH    INCREMENTAL     STALE_PERCENT
-------------------- ------------------------- ---------- ------------------------------ ------------------------- ------------------------------ --------------- ---------- --------------- ---------------
AUTO                 TRUE                      8          10                             FOR ALL COLUMNS SIZE AUTO DBMS_STATS.AUTO_INVALIDATE     AUTO            TRUE       FALSE           10

exec dbms_stats.set_global_prefs('DEGREE', 8);

-- ###############################
-- ### SCHEDULER WINDOW CHANGE ###
-- ###############################

-- We can increase the maintenance window duration
-- We can also decide to have a very big window for the weekend, for services that works mainly during office hours

col WINDOW_NAME for a22
col REPEAT_INTERVAL for a70
col DURATION for a15
select WINDOW_NAME, REPEAT_INTERVAL, DURATION, ENABLED, ACTIVE from DBA_SCHEDULER_WINDOWS;

WINDOW_NAME            REPEAT_INTERVAL                                                        DURATION        ENABL ACTIV
---------------------- ---------------------------------------------------------------------- --------------- ----- -----
MONDAY_WINDOW          freq=daily;byday=MON;byhour=22;byminute=0; bysecond=0                  +000 04:00:00   TRUE  FALSE
TUESDAY_WINDOW         freq=daily;byday=TUE;byhour=22;byminute=0; bysecond=0                  +000 04:00:00   TRUE  FALSE
WEDNESDAY_WINDOW       freq=daily;byday=WED;byhour=22;byminute=0; bysecond=0                  +000 04:00:00   TRUE  FALSE
THURSDAY_WINDOW        freq=daily;byday=THU;byhour=22;byminute=0; bysecond=0                  +000 04:00:00   TRUE  FALSE
FRIDAY_WINDOW          freq=daily;byday=FRI;byhour=22;byminute=0; bysecond=0                  +000 04:00:00   TRUE  FALSE
SATURDAY_WINDOW        freq=daily;byday=SAT;byhour=6;byminute=0; bysecond=0                   +000 20:00:00   TRUE  FALSE
SUNDAY_WINDOW          freq=daily;byday=SUN;byhour=6;byminute=0; bysecond=0                   +000 20:00:00   TRUE  FALSE

exec DBMS_SCHEDULER.SET_ATTRIBUTE('MONDAY_WINDOW',    'DURATION', '+000 08:00:00');
exec DBMS_SCHEDULER.SET_ATTRIBUTE('TUESDAY_WINDOW',   'DURATION', '+000 08:00:00');
exec DBMS_SCHEDULER.SET_ATTRIBUTE('WEDNESDAY_WINDOW', 'DURATION', '+000 08:00:00');
exec DBMS_SCHEDULER.SET_ATTRIBUTE('THURSDAY_WINDOW',  'DURATION', '+000 08:00:00');
exec DBMS_SCHEDULER.SET_ATTRIBUTE('FRIDAY_WINDOW',    'DURATION', '+002 12:00:00');
exec DBMS_SCHEDULER.DISABLE('SATURDAY_WINDOW');
exec DBMS_SCHEDULER.DISABLE('SUNDAY_WINDOW');

--per modificare la partenza
EXECUTE DBMS_SCHEDULER.SET_ATTRIBUTE('MONDAY_WINDOW','repeat_interval','freq=daily;byday=MON;byhour=20;byminute=0; bysecond=0');

-- #########################
-- ### INCREMENTAL STATS ###
-- #########################

-- It is suggested to implement in on DB > 12.2, on 12.1 it can lead to very big synopsys tables

-- Set INCREMENTAL=TRUE
select DBMS_STATS.GET_PREFS ('INCREMENTAL','MKT', 'TBMK2_AU_AUTORIZZ') from dual;
exec DBMS_STATS.SET_TABLE_PREFS ('MKT', 'TBMK2_AU_AUTORIZZ','INCREMENTAL', 'TRUE'); 

-- Verify PUBLISH=TRUE, mainly useful in 12.1
select DBMS_STATS.GET_PREFS ('PUBLISH','MKT', 'TBMK2_AU_AUTORIZZ') from dual;

-- Verify AUTO_SAMPLE_SIZE, mainly useful in 12.1
select DBMS_STATS.GET_PREFS ('ESTIMATE_PERCENT','MKT', 'TBMK2_AU_AUTORIZZ') from dual;
exec DBMS_STATS.SET_TABLE_PREFS ('MKT', 'TBMK2_AU_AUTORIZZ','ESTIMATE_PERCENT','DBMS_STATS.AUTO_SAMPLE_SIZE'); 

-- ##################
-- ### LOCK STATS ###
-- ##################

-- We can temporary lock the stats for the biggest tables, in order to let the job complete, and manage them using a separate gather stats with force=>y, in order to override the lock

col owner for a25
col table_name for a40
select owner, table_name, count(1), stattype_locked from dba_tab_statistics where stattype_locked is not null group by owner, table_name, stattype_locked order by 1,2;

exec DBMS_STATS.LOCK_TABLE_STATS ('MKT','TBMK2_AU_AUTORIZZ');
exec dbms_stats.gather_table_stats('MKT','TBMK2_AU_AUTORIZZ',degree=>8,cascade=>TRUE,force=>true);
exec DBMS_STATS.UNLOCK_TABLE_STATS ('MKT','TBMK2_AU_AUTORIZZ'); 

-- ### MANUAL GATHER STATS ###

-- In case you need to urgently fix a situation with a lot of stale statistics

-- GATHER GLOBAL STATS, starting from the ones with older stats

select 'exec dbms_stats.gather_table_stats(''' || owner || ''',''' || table_name || ''',degree=>8,cascade=>TRUE);'
from dba_tab_statistics where stale_stats ='YES' and owner not in ('SYS','SYSTEM') and partition_name is null and subpartition_name is null and last_analyzed < sysdate -3 
order by owner, table_name;

select 'exec dbms_stats.gather_table_stats(''' || owner || ''',''' || table_name || ''',degree=>8,cascade=>TRUE);'
from dba_tab_statistics where stale_stats ='YES' and owner not in ('SYS','SYSTEM') and partition_name is null and subpartition_name is null order by owner, table_name;

-- GATHER PARTITION STATS, starting from the ones with older stats

select 'exec dbms_stats.gather_table_stats(''' || owner || ''',''' || table_name || ''',''' || partition_name || ''',granularity=>''PARTITION'',degree=>8);'
from dba_tab_statistics where stale_stats ='YES' and owner not in ('SYS','SYSTEM') and partition_name is not null and subpartition_name is null and last_analyzed < sysdate -3 
order by owner, table_name, partition_name, subpartition_name;

select 'exec dbms_stats.gather_table_stats(''' || owner || ''',''' || table_name || ''',''' || partition_name || ''',granularity=>''PARTITION'',degree=>8);'
from dba_tab_statistics where stale_stats ='YES' and owner not in ('SYS','SYSTEM') and partition_name is not null and subpartition_name is null
order by owner, table_name, partition_name, subpartition_name;

-- ####################
-- ### CHECK SYSAUX ###
-- ####################

-- Mainly useful on 12.1 and lower, they have bigger synopsys tables

select a.tablespace_name, b.mb_occupati, a.mb_allocati, a.mb_maxsize from
(select tablespace_name, round(sum(bytes)/1024/1024) mb_allocati, round(sum(maxbytes)/1024/1024) mb_maxsize from dba_data_files group by tablespace_name) a,
(select tablespace_name, round(sum(bytes)/1024/1024) mb_occupati from dba_segments group by tablespace_name) b
where a.tablespace_name=b.tablespace_name (+) and a.tablespace_name = 'SYSAUX';

TABLESPACE_NAME                MB_OCCUPATI MB_ALLOCATI MB_MAXSIZE
------------------------------ ----------- ----------- ----------
SYSAUX                              108677      120353     163840

col owner for a22
col segment_name for a33
select owner, segment_name, segment_type, round(sum(bytes/1024/1024)) MB, count(1) from dba_segments where tablespace_name='SYSAUX' 
group by owner, segment_name, segment_type having round(sum(bytes/1024/1024)) > 500 order by 4;

-- ######################
-- ### CHECK SYNOPSYS ###
-- ######################

col "Table Name" for a40
col "Part" for a40

SELECT o.name "Table Name", p.subname "Part", h.analyzetime "Synopsis Creation Time", count(1)
FROM   WRI$_OPTSTAT_SYNOPSIS_HEAD$ h, OBJ$ o, USER$ u, COL$ c, OBJ$ p,
       ((SELECT TABPART$.bo#  BO#, TABPART$.obj# OBJ# FROM TABPART$ tabpart$) UNION ALL (SELECT TABCOMPART$.bo#  BO#, TABCOMPART$.obj# OBJ# FROM TABCOMPART$ tabcompart$)) tp
WHERE  tp.obj# = p.obj# AND h.bo# = tp.bo# AND h.group# = tp.obj# * 2 AND h.bo# = c.obj#(+) AND h.intcol# = c.intcol#(+) AND o.owner# = u.user# AND h.bo# = o.obj#
AND    u.name = 'MKT' AND o.name = 'TBMK2_AU_AUTORIZZ' 
GROUP BY o.name, p.subname, h.analyzetime ORDER  BY 1,2,3,4;

select NOTES,count(1) from DBA_PART_COL_STATISTICS where OWNER='MKT' and TABLE_NAME='TBMK2_AU_AUTORIZZ' group by NOTES;

select NOTES,count(1) from DBA_SUBPART_COL_STATISTICS where OWNER='MKT' and TABLE_NAME='TBMK2_AU_AUTORIZZ' group by NOTES;

-- ############################
-- ### STALE_PERCENT CHANGE ###
-- ############################

-- Utile in caso di grosse partizioni mensili, per evitare di ricalcolare le stats ogni giorno durante i primi giorni del mese

exec dbms_stats.set_table_prefs('MKT','TBMK2_AU_AUTORIZZ','STALE_PERCENT','20');


####################### ###########################
per capire su quale tabella si e' fermato il job
###################################################
select OPERATION,TARGET,START_TIME,END_TIME,STATUS,NOTES from DBA_OPTSTAT_OPERATIONS where START_TIME > (sysdate - 1) order by START_TIME asc;