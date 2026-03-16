-- ###########
-- ### AWR ###
-- ###########

----------------------------------------------------------------------------------------
--
-- File name:   unstable_plans.sql
--
-- Purpose:     Attempts to find SQL statements with plan instability.
--
-- Author:      Kerry Osborne
--
-- Usage:       This scripts prompts for two values, both of which can be left blank.
--
--              min_stddev: the minimum "normalized" standard deviation between plans 
--                          (the default is 2)
--
--              min_etime:  only include statements that have an avg. etime > this value
--                          (the default is .1 second)
--
-- See http://kerryosborne.oracle-guy.com/2008/10/unstable-plans/ for more info.
---------------------------------------------------------------------------------------

set lines 155
col execs for 999,999,999
col min_etime for 999,999.99
col max_etime for 999,999.99
col avg_etime for 999,999.999
col avg_lio for 999,999,999.9
col norm_stddev for 999,999.9999
col begin_interval_time for a30
col node for 99999
break on plan_hash_value on startup_time skip 1
select * from (
select sql_id, sum(execs), min(avg_etime) min_etime, max(avg_etime) max_etime, stddev_etime/min(avg_etime) norm_stddev
from (
select sql_id, plan_hash_value, execs, avg_etime,
stddev(avg_etime) over (partition by sql_id) stddev_etime
from (
select sql_id, plan_hash_value,
sum(nvl(executions_delta,0)) execs,
(sum(elapsed_time_delta)/decode(sum(nvl(executions_delta,0)),0,1,sum(executions_delta))/1000000) avg_etime
-- sum((buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta))) avg_lio
from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT SS
where ss.snap_id = S.snap_id
and ss.instance_number = S.instance_number
and executions_delta > 0
group by sql_id, plan_hash_value
)
)
group by sql_id, stddev_etime
)
where norm_stddev > nvl(to_number('&min_stddev'),2)
and max_etime > nvl(to_number('&min_etime'),.1)
order by norm_stddev;

-- ################
-- ### SQL AREA ###
-- ################

-- Email "Ideas for sql_id control with multiple execution plans"

select * from (
select sql_id,sum(execs), min(avg_etime) min_etime, max(avg_etime) max_etime, stddev_etime/min(avg_etime) norm_stddev
from (
select sql_id, plan_hash_value, execs, avg_etime,
stddev(avg_etime) over (partition by sql_id) stddev_etime
from (
select sql_id, plan_hash_value,
sum(nvl(executions,0)) execs,
(sum(elapsed_time)/decode(sum(nvl(executions,0)),0,1,sum(executions))/1000000) avg_etime
from gv$sql s
where executions > 100
group by sql_id, plan_hash_value
)
)
group by sql_id, stddev_etime
)
where norm_stddev > 50
order by sql_id;

--              min_stddev: the minimum "normalized" standard deviation between plans 
--                          (the default is 2)
--
--              min_etime:  only include statements that have an avg. etime > this value
--                          (the default is .1 second)
--       
--              executions > 100
--
	
select * from (
select sql_id, sum(execs), min(avg_etime) min_etime, max(avg_etime) max_etime, stddev_etime/min(avg_etime) norm_stddev
from (
select sql_id, plan_hash_value, execs, avg_etime,
stddev(avg_etime) over (partition by sql_id) stddev_etime
from (
select sql_id, plan_hash_value,
sum(nvl(executions,0)) execs,
(sum(elapsed_time)/decode(sum(nvl(executions,0)),0,1,sum(executions))/1000000) avg_etime
from gv$sql s
where 
executions > 100
group by sql_id, plan_hash_value
)
)
group by sql_id, stddev_etime
)
where norm_stddev > nvl(to_number('&min_stddev'),2)
and max_etime > nvl(to_number('&min_etime'),.1)
order by norm_stddev;

-- Find the plan:

select plan_hash_value,executions,ROUND((elapsed_time/1000000)/executions,0) from gv$sql where sql_id='&SQL_ID';



--- in SQLAREA:

--	sql_id in v$sqlarea with more than one associated plan and :
--average execution time greater than X milliseconds
--total execution number greater than X times
SELECT sql_id, count(plan_hash_value)
	FROM gv$sql s
    WHERE executions > 1
	and parsing_schema_name in (select username from dba_users where oracle_maintained='N')
   and ROUND((elapsed_time/1000)/executions,0) > 3000
	group by sql_id having count(plan_hash_value)>1;
	
	
	
-- Email "statistical data on plan changes" from Maria Bagnato dated 10/14/2021 3:03 pm

select
           a.sql_id sql_id
           , S.END_INTERVAL_TIME pod_time
           , t.END_INTERVAL_TIME exa_time
           , b.ELAPSED_TIME_TOTAL pod_elapsed
           , a.ELAPSED_TIME_TOTAL exa_elapsed
           ,b.ROWS_PROCESSED_TOTAL pod_row_processed
           ,b.ROWS_PROCESSED_TOTAL exa_row_processed
--           , b.EXECUTIONS_TOTAL
            ,b.PLAN_HASH_VALUE pod_plan_hash_value
            ,a.PLAN_HASH_VALUE exa_plan_hash_value
--           ,b.MODULE
--           ,b.DISK_READS_TOTAL
--           ,b.PHYSICAL_READ_REQUESTS_TOTAL
--           ,b.PHYSICAL_WRITE_REQUESTS_TOTAL
      from
         DBA_HIST_SQLSTAT b ,
         dba_hist_snapshot s,
         DBA_HIST_SQLSTAT@TOEXA a,
         dba_hist_snapshot@TOEXA t
      where        s.BEGIN_INTERVAL_TIME > to_date('13-10-2021 19:00','dd-mm-yyyy hh24:mi') and
                        b.snap_id = s.snap_id
                        and a.snap_id=t.snap_id
                        and a.sql_id=b.sql_id 
                        and a.plan_hash_value<>b.plan_hash_value
                        and b.ROWS_PROCESSED_TOTAL>a.ROWS_PROCESSED_TOTAL

-- ALTRA QUERY

col INST for 9
col BEGIN for a16
col END for a16
select sq.sql_id, sq.PLAN_HASH_VALUE, count(1)
from dba_hist_sqlstat sq, dba_hist_snapshot sn
where sq.snap_id = sn.snap_id
  and sq.dbid = sn.dbid
  and sq.instance_number = sn.instance_number
  and executions_delta>0
group by sq.sql_id, sq.PLAN_HASH_VALUE
having count(1) > 1
order by 1,2;