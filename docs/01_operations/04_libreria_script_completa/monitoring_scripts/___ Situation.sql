


set lines 222 pages 4444
col inst_id for 9
col sid for 99999
col serial# for 999999
col username for a22
col program for a35
col machine for a35
col event for a50

-- ACTIVE SESSIONS

select inst_id, sid, serial#, username, program, machine, sql_id, last_call_et, event, seconds_in_wait "SECS"
from gv$session where username is not null and status='ACTIVE' and event not in ('class slave wait','OFS idle') order by username,sql_id,inst_id,sid;

-- LOCKS

col wait_class for a25
select blocking_instance, blocking_session, inst_id, sid, serial#, sql_id, event, wait_class, seconds_in_wait
from gv$session where blocking_session is not NULL order by blocking_instance, blocking_session, inst_id, sid;

select username, sid, serial#, program, machine, osuser, status, last_call_et, seconds_in_wait, sql_id, prev_sql_id, 'ALTER SYSTEM KILL SESSION ''' || sid || ',' || serial# || ''' immediate;'
from gv$session where inst_id=&inst_id and sid=&sid;

-- ACTIVE TRANSACTIONS

alter session set nls_date_format='dd/mm/yyyy hh24:mi:ss';
col machine for a30
SELECT b.inst_id, b.sid, b.serial#, b.username, b.machine, b.status, b.last_call_et, b.sql_id, b.prev_sql_id, a.start_date,
       ROUND(a.used_ublk*(SELECT block_size FROM dba_tablespaces WHERE tablespace_name LIKE 'UNDO%' AND rownum<2)/1024/1024,3) "UNDO_GENERATED(MB)"
FROM gv$transaction a, gv$session b WHERE a.inst_id = b.inst_id AND a.addr = b.taddr ORDER BY a.start_date;

-- ACTIVE SQL

SELECT username, sql_id, count(1) FROM gv$session 
WHERE username is not null and status='ACTIVE' 
GROUP BY username, sql_id ORDER BY 3,1;

-- SQL_TEXT
-- select sql_text from v$sqltext where sql_id='&SQL_ID' order by piece;

set long 999999999
select sql_fulltext from v$sqlarea where sql_id='d1s02myktu19h';

select sql_text from dba_hist_sqltext where sql_id='&SQL_ID';

-- SQL PLAN

select * from table(DBMS_XPLAN.DISPLAY_CURSOR('&SQL_ID'));

-- SQL STATS

alter session set nls_date_format='dd/mm/yyyy hh24:mi:ss';
col inst_id for 9
col first_load_time for a19
col last_load_time for a19
col parsing_schema_name for a20
SELECT inst_id, ROUND(disk_reads/executions) "DSK/EX", ROUND(buffer_gets/executions) "BFF/EX",
       ROUND(rows_processed/executions) "RWS/EX", ROUND((cpu_time/1000000)/executions,3) "CPU/EX",
       ROUND((elapsed_time/1000000)/executions,3) "ELA/EX", executions "EXEC", 
       first_load_time, last_load_time, plan_hash_value
FROM gv$sql s WHERE sql_id='&SQL_ID';

-- SESSIONS

col machine for a50
col program for a40
col username for a30
SELECT inst_id, username, machine, program, count(1) count FROM gv$session 
WHERE username is not null GROUP BY inst_id, username, machine, program ORDER BY username, machine, program;

SELECT username, machine, program, count(1) count FROM gv$session 
WHERE username is not null GROUP BY username, machine, program ORDER BY username, machine, program;

col limit_value for a11
col resource_name for a15
select inst_id, resource_name, current_utilization, max_utilization, limit_value from gv$resource_limit where resource_name='processes';

alter session set nls_date_format='dd/mm/yyyy hh24:mi:ss';
select logon_time, last_call_et, status, username, machine, prev_sql_id from gv$session where username is not null order by 1;

-- CDB SESSIONS

col pdb_name for a30
col machine for a50
col program for a40
col username for a30
select pdb.pdb_name, username, machine, program, count(1) from gv$session s, dba_pdbs pdb
where s.con_id=pdb.con_id and username is not null 
group by pdb.pdb_name, username, machine, program order by count(1);

-- SESSION_LONGOPS

select * from gv$session_longops where sofar!=totalwork order by 1,2;

-- PARALLEL SESSIONS

col username for a25
select s.username, px.inst_id, QCSID, QCSERIAL#, px.sid, px.serial#, SERVER_GROUP, SERVER_SET, px.SERVER#, px.DEGREE, px.REQ_DEGREE, px.con_id
from gv$px_session px, gv$session s where px.inst_id=s.inst_id and px.sid=s.sid order by 1,3,4,2,5,6;

-- JOBS RUNNING

select jr.sid, jr.job, j.log_user, j.priv_user, what from dba_jobs j, dba_jobs_running jr where j.job=jr.job;






