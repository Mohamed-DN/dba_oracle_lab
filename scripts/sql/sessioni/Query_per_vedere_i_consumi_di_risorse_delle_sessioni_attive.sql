-- Source: https://www.scriptdba.com/query-per-vedere-i-consumi-di-risorse-delle-sessioni-attive/
-- Title: Query per vedere i consumi di risorse delle sessioni attive

col inst_id for 9999
col sid for 99999
col LAST_LOAD_TIME for a22
col buff_gets for 99999999999
col executions for 99999999999
col sql_text for a100 wrap
set long 10000
col osuser for a10
col machine for a12
col buff_get for 99999999999
col disk for 99999999999
col Secs for 999,99
col username for a16
set linesize 400
col event for a40
select a.inst_id , a.sid, a.username , a.sql_id, a.event , osuser,executions ,  BUFFER_GETS/(executions+1) as buff_get, DISK_READS/(executions+1) as disk, ((ELAPSED_TIME)*power(10,-6))/(Executions+1) as Secs
  from gv$session a , gv$sqlarea b
 where a.inst_id=b.inst_id and 
       a.sql_id=b.sql_id and 
       status='ACTIVE' and 
       username is not null
order by 5 ;

col inst_id for 9999
col sid for 99999
col LAST_LOAD_TIME for a22
col buff_gets for 99999999999
col executions for 99999999999
col sql_text for a100 wrap
set long 10000
col osuser for a10
col machine for a12
col buff_get for 99999999999
col disk for 99999999999
col Secs for 999,99
col username for a16
set linesize 400
col event for a40
select a.inst_id , a.sid, a.username , a.sql_id, a.event , osuser,executions ,  BUFFER_GETS/(executions+1) as buff_get, DISK_READS/(executions+1) as disk, ((ELAPSED_TIME)*power(10,-6))/(Executions+1) as Secs
  from gv$session a , gv$sqlarea b
 where a.inst_id=b.inst_id and 
       a.sql_id=b.sql_id and 
       status='ACTIVE' and 
       username is not null
order by 5 ;

