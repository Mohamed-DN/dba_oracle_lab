-- HISTORICAL SQL STATISTICS
-- The times are expressed in seconds, to express them in milliseconds use "/1000" instead of "/1000000", to express them in microseconds remove "/1000000"
-- Uncomment the commented lines in case you want to have evidence of the other classes of expectations

-- LEGENDA
-- DSK/EX: disk reads per execution
-- BFF/EX: buffer gets per execution
-- RWS/EX: rows returned per execution
-- ELA/EX: elapsed time per execution
-- EXEC: executions

col INST for 9
col BEGIN for a16
col END for a16
select sn.instance_number INST, sn.snap_id, to_char(sn.begin_interval_time,'yyyy/mm/dd hh24:mi') BEGIN, to_char(sn.end_interval_time,'yyyy/mm/dd hh24:mi') END, 
       executions_delta EXEC, PLAN_HASH_VALUE PLAN, round(disk_reads_delta/executions_delta) DSK, round(buffer_gets_delta/executions_delta) BFF, 
	   round(ROWS_PROCESSED_DELTA/executions_delta) RWS, round(elapsed_time_delta/1000000/executions_delta,2) ELA
       -- , round(cpu_time_delta/1000000/executions_delta,2) CPU, round(IOWAIT_DELTA/1000000/executions_delta,2) IO, round(CCWAIT_DELTA/1000000/executions_delta,2) CC,
       -- round(APWAIT_DELTA/1000000/executions_delta,2) AP, round(CLWAIT_DELTA/1000000/executions_delta,2) CL
from dba_hist_sqlstat sq, dba_hist_snapshot sn
where sq.dbid = sn.dbid and sq.instance_number = sn.instance_number and sq.snap_id = sn.snap_id and sq.sql_id = '&sql_id' and executions_delta>0
order by 3,1 asc;

-- HISTORICAL SQL PLANS
-- The first query shows all the access plans present in AWR, the second shows only the specified one

select * from table(DBMS_XPLAN.DISPLAY_AWR('&SQL_ID',format=>'TYPICAL'));

select * from table(DBMS_XPLAN.DISPLAY_AWR('&SQL_ID','&PLAN_HASH_VALUE',format=>'TYPICAL'));

-- format=>'BASIC'
-- format=>'TYPICAL -PROJECTION -PREDICATE'
-- format=>'TYPICAL -PROJECTION PREDICATE'
-- format=>'ADVANCED'

-- RAC AVERAGE STATISTICS
--The following query shows the values ​​averaged between the two Oracle instances

select to_char(sn.begin_interval_time,'yyyy/mm/dd hh24:mi') BEGIN,
       to_char(sn.end_interval_time,'yyyy/mm/dd hh24:mi') END,
       sum(executions_delta) EXEC,
       round(sum(disk_reads_delta)/sum(executions_delta)) DSK,
       round(sum(buffer_gets_delta)/sum(executions_delta)) BFF,
       round(sum(elapsed_time_delta)/1000000/sum(executions_delta),2) ELA
from dba_hist_sqlstat sq, dba_hist_snapshot sn
where sq.sql_id = 'f0k2j5v6g83ub'
  and sq.snap_id = sn.snap_id
  and sq.dbid = sn.dbid
  and sq.instance_number = sn.instance_number
  and executions_delta>0
group by to_char(sn.begin_interval_time,'yyyy/mm/dd hh24:mi'), to_char(sn.end_interval_time,'yyyy/mm/dd hh24:mi')
order by 1 asc;

-- QUERY WITH MULTIPLE ACCESS PLANS

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

-- USEFUL NOTES

How to get execution statistics and history for a SQL [ID 1371778.1]
How To Interpret DBA_HIST_SQLSTAT [ID 471053.1]
Cannot Find Top SQL Statement in View DBA_HIST_SQLSTAT [ID 1424839.1]
