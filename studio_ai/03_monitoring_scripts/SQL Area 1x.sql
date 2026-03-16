-- BAD SQL

alter session set nls_date_format='dd/mm/yyyy hh24:mi:ss';
col first_load_time for a19
col last_load_time for a19
col parsing_schema_name for a20
SELECT ROUND(disk_reads/executions) "DSK/EX", ROUND(buffer_gets/executions) "BFF/EX",
       ROUND(rows_processed/executions) "RWS/EX", ROUND((cpu_time/1000000)/executions,3) "CPU/EX",
       ROUND((elapsed_time/1000000)/executions,3) "ELA/EX", executions "EXEC", 
       first_load_time, last_load_time, parsing_schema_name, sql_id, sql_text
FROM gv$sqlarea s
WHERE executions > 100
and parsing_schema_name not in ('SYS','SYSMAN','DBSNMP','NAGIOS')
-- and s.sql_id in (select sp.sql_id from v$sql_plan sp where sp.object_name='TABLE')
-- and upper(sql_text) like '%TABLE%'
and sql_text not like 'SELECT /* DS_SVC */%'
and sql_text not like '/* SQL Analyze%'
and executions<disk_reads
and disk_reads/executions> 100
ORDER BY disk_reads/executions;

-- SQL PLAN
-- How to Obtain a Formatted Explain Plan - Recommended Methods [ID 235530.1]

select * from table(DBMS_XPLAN.DISPLAY_CURSOR('&SQL_ID',format=>'TYPICAL'));
select * from table(DBMS_XPLAN.DISPLAY_AWR('&SQL_ID','&PLAN_HASH_VALUE',format=>'TYPICAL'));

-- format=>'BASIC'
-- format=>'TYPICAL -PROJECTION -PREDICATE'
-- format=>'TYPICAL -PROJECTION PREDICATE'
-- format=>'ADVANCED'

select * from TABLE(DBMS_XPLAN.DISPLAY_CURSOR(SQL_ID=>'&&SQL_ID',format=>'TYPICAL -PROJECTION PREDICATE'));

-- Check object usage in V$SQL_PLAN

select sql_id, plan_hash_value, count(1) from gv$sql_plan where object_name = '&object_name' group by sql_id, plan_hash_value;

select sql_id, sql_text from v$sqltext_with_newlines where sql_id in
   (select distinct sql_id from gv$sql_plan where object_name = '&object_name')
order by sql_id, piece;

-- SQL TEXT

select sql_text from v$sqltext_with_newlines where sql_id='&SQL_ID' order by piece;
select sql_id,SQL_FULLTEXT from v$sql where sql_id='&SQL_ID';

set long 999999999
select sql_text from dba_hist_sqltext where sql_id='&SQL_ID';

-- UTILS

select num_rows, last_analyzed, sample_size from dba_tables where owner='&Owner' and table_name='&Table_name';
select column_name, num_distinct, num_nulls, num_buckets, histogram from dba_tab_columns where owner='&Owner' and table_name='&Table_name' order by 1;
select NCHNUM, count(1) from DIAPASON.VAQCCTS group by NCHNUM order by 1;
select * from dba_histograms where owner='&Owner' and table_name='&Table_name' and column_name='&Column_name';
select bytes/1024/1024 MB from dba_segments where owner='&Owner' and segment_name='&Segment_name';

-- RAW TO

WITH
FUNCTION raw_to_date(i_var in raw) return date  as
o_var date;
begin
dbms_stats.convert_raw_value(i_var,o_var);
return o_var;
end;
FUNCTION raw_to_number(i_var in raw) return number  as
o_var number;
begin
dbms_stats.convert_raw_value(i_var,o_var);
return o_var;
end;
FUNCTION raw_to_varchar2(i_var in raw) return varchar2  as
o_var varchar2(32767);
begin
dbms_stats.convert_raw_value(i_var,o_var);
return o_var;
end;
FUNCTION raw_to_float(i_var in raw) return binary_float  as
o_var binary_float;
begin
dbms_stats.convert_raw_value(i_var,o_var);
return o_var;
end;
FUNCTION raw_to_double(i_var in raw) return binary_double  as
o_var binary_double;
begin
dbms_stats.convert_raw_value(i_var,o_var);
return o_var;
end;
select raw_to_xxx from dual;
/

-- DBA HIST SQLSTAT

select sn.instance_number INST, sn.snap_id,
       to_char(sn.begin_interval_time,'yyyy/mm/dd hh24:mi') BEGIN,
       to_char(sn.end_interval_time,'yyyy/mm/dd hh24:mi') END,
       executions_delta EXEC, PLAN_HASH_VALUE PLAN,
       round(disk_reads_delta/executions_delta) DSK,
       round(buffer_gets_delta/executions_delta) BFF,
       round(ROWS_PROCESSED_DELTA/executions_delta) RWS,
       round(elapsed_time_delta/1000000/executions_delta,2) ELA,
       round(cpu_time_delta/1000000/executions_delta,2) CPU,
       round(IOWAIT_DELTA/1000000/executions_delta,2) IO,
       round(CCWAIT_DELTA/1000000/executions_delta,2) CC,
       round(APWAIT_DELTA/1000000/executions_delta,2) AP,
       round(CLWAIT_DELTA/1000000/executions_delta,2) CL
from dba_hist_sqlstat sq, dba_hist_snapshot sn
where sq.sql_id = '&sql_id'
  and sq.snap_id = sn.snap_id
  and sq.dbid = sn.dbid
  and sq.instance_number = sn.instance_number
  and executions_delta>0
order by 3,1 asc;

-- ANALISI APPROFONDITA in microsecondi

SELECT inst_id,ROUND(disk_reads/executions) "DSK/EX", ROUND(buffer_gets/executions) "BFF/EX", 
       ROUND(rows_processed/executions) "RWS/EX", ROUND(cpu_time/executions) "CPU/EX", 
       ROUND(elapsed_time/executions) "ELA/EX", executions "EXEC",
ROUND(APPLICATION_WAIT_TIME/executions) APP,
ROUND(CONCURRENCY_WAIT_TIME/executions) CON,
ROUND(CLUSTER_WAIT_TIME/executions) CLU,
ROUND(USER_IO_WAIT_TIME/executions) IO,
ROUND(PLSQL_EXEC_TIME/executions) PL,
ROUND(JAVA_EXEC_TIME/executions) JAVA,
       first_load_time, last_load_time, username, sql_id, sql_text 
FROM gv$sqlarea s, all_users u 
WHERE executions > 0 
and s.parsing_user_id = u.user_id 
and u.username not in ('DBSNMP','SYS','MONITOR','ORACLE_OCM') 
-- and sql_text like '%23,24,27,28%'
and sql_id='&1'
ORDER BY disk_reads/executions DESC;

-- STATEMENTS WITH HIGH COSTS

select SQL_ID, PLAN_HASH_VALUE, max(cost) from v$sql_plan where cost>10000 group by SQL_ID, PLAN_HASH_VALUE order by 3;

-- LEGENDA

DSK/EX: disk reads per execution
BFF/EX: buffer gets per execution
RWS/EX: rows returned per execution
CPU/EX: CPU time per execution
ELA/EX: elapsed time per execution
EXEC: executions