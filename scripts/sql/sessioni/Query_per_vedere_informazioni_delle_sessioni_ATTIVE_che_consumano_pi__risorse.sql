-- Source: https://www.scriptdba.com/query-per-vedere-i-dettagli-delle-sessioni-attive-che-consumano-piu-risorsa-macchina/
-- Title: Query per vedere informazioni delle sessioni ATTIVE che consumano più risorse

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
col program for a34
col Secs for 999,99
col username for a12
col disk for 999999
col cld for 99
col exec for 999999
set linesize 400
col Is for 9
select a.inst_id as I , a.sid, a.username , a.sql_id, a.program ,machine , osuser,executions as exec , BUFFER_GETS/(executions+1) as buff_get,
disk_reads/(executions+1) as disk, ((ELAPSED_TIME)*power(10,-6))/(Executions+1) as Secs, buffer_gets/(fetches+0.1) as "Buf/Fetch"
from gv$session a , gv$sql b
 where a.inst_id=b.inst_id and
       a.sql_id=b.sql_id and
       a.sql_child_number=b.child_number and
       status='ACTIVE' and  
       service_name not like 'SYS%' and 
       username not like 'SYS%' and
       ( BUFFER_GETS/(executions+1) > 90000 or disk_reads/(executions+1)> 5000 )
order by a.sql_id;

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
col program for a34
col Secs for 999,99
col username for a12
col disk for 999999
col cld for 99
col exec for 999999
set linesize 400
col Is for 9
select a.inst_id as I , a.sid, a.username , a.sql_id, a.program ,machine , osuser,executions as exec , BUFFER_GETS/(executions+1) as buff_get,
disk_reads/(executions+1) as disk, ((ELAPSED_TIME)*power(10,-6))/(Executions+1) as Secs, buffer_gets/(fetches+0.1) as "Buf/Fetch"
from gv$session a , gv$sql b
 where a.inst_id=b.inst_id and
       a.sql_id=b.sql_id and
       a.sql_child_number=b.child_number and
       status='ACTIVE' and  
       service_name not like 'SYS%' and 
       username not like 'SYS%' and
       ( BUFFER_GETS/(executions+1) > 90000 or disk_reads/(executions+1)> 5000 )
order by a.sql_id;

