-- Source: https://www.scriptdba.com/query-per-vedere-i-consumi-e-le-sessioni-attive/
-- Title: Query per vedere l'utilizzo di risorse delle SESSIONI ATTIVE

col I for 9
col sid for 9999
col LAST_LOAD_TIME for a22
col buff_gets for 99999999999
col executions for 99999999999
col sql_text for a100 wrap
set long 10000
col osuser for a8
col machine for a10
col buff_get for 9999999999
col Secs for 999,99
col username for a16
col program for a34
col sql_child for 9999
col disk for 9999999
col cpu for 99999999
col cld for 999
col cpu for 99999999
set linesize 400
select a.inst_id as I, a.sid, a.username , a.sql_id, a.program ,machine , osuser, executions, BUFFER_GETS/(executions+1) as buff_get,DISK_READS/(executions+1) as disk , ((ELAPSED_TIME)*power(10,-6))/(Executions+1) as Secs
  from gv$session a , gv$sql b
 where a.inst_id=b.inst_id and 
       a.sql_child_number=b.child_number and
       a.sql_id=b.sql_id and status='ACTIVE' and
       service_name not like 'SYS%' and
       username not like 'SYS%' 
order by 3,4 ;

col I for 9
col sid for 9999
col LAST_LOAD_TIME for a22
col buff_gets for 99999999999
col executions for 99999999999
col sql_text for a100 wrap
set long 10000
col osuser for a8
col machine for a10
col buff_get for 9999999999
col Secs for 999,99
col username for a16
col program for a34
col sql_child for 9999
col disk for 9999999
col cpu for 99999999
col cld for 999
col cpu for 99999999
set linesize 400
select a.inst_id as I, a.sid, a.username , a.sql_id, a.program ,machine , osuser, executions, BUFFER_GETS/(executions+1) as buff_get,DISK_READS/(executions+1) as disk , ((ELAPSED_TIME)*power(10,-6))/(Executions+1) as Secs
  from gv$session a , gv$sql b
 where a.inst_id=b.inst_id and 
       a.sql_child_number=b.child_number and
       a.sql_id=b.sql_id and status='ACTIVE' and
       service_name not like 'SYS%' and
       username not like 'SYS%' 
order by 3,4 ;

