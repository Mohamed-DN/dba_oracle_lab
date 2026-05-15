-- Source: https://www.scriptdba.com/query-per-vedere-i-dettagli-di-una-sessione-da-sid/
-- Title: Query sessioni SID Oracle

Set lines 300
Set pages 60
Col LAST_CALL for a18
Col LOGON_TIME for a18
Col schemaname for a16
Col command for a24
Col machine for a16
Col action for a12
Col username for a16
Col osuser for a16
Col terminal for a16
select to_char(S.logon_time,'DD-MON-YYYY hh24.mi.ss') LOGON_TIME, s.status, s.inst_id,s.sql_id,s.process,s.program, s.schemaname,
s.sid, s.serial#, p.spid, p.pid, s.osuser, S.machine, S.terminal,to_char(sysdate -(LAST_CALL_ET/86400),'DD-MON-YY hh24:mi:ss') LAST_CALL , 
U.username, S.ACTION, decode(S.command,0, 'No command in progress.', 1, 'CREATE TABLE',2, 'INSERT', 3, 'SELECT', 4, 'CREATE CLUSTER',
5, 'ALTER CLUSTER', 6, 'UPDATE', 7, 'DELETE') COMMAND
from gv$session S,
dba_users U,
gv$process P
where P.ADDR = S.PADDR
and S.user# = U.user_id
and s.sid =&sid;

Set lines 300
Set pages 60
Col LAST_CALL for a18
Col LOGON_TIME for a18
Col schemaname for a16
Col command for a24
Col machine for a16
Col action for a12
Col username for a16
Col osuser for a16
Col terminal for a16
select to_char(S.logon_time,'DD-MON-YYYY hh24.mi.ss') LOGON_TIME, s.status, s.inst_id,s.sql_id,s.process,s.program, s.schemaname,
s.sid, s.serial#, p.spid, p.pid, s.osuser, S.machine, S.terminal,to_char(sysdate -(LAST_CALL_ET/86400),'DD-MON-YY hh24:mi:ss') LAST_CALL , 
U.username, S.ACTION, decode(S.command,0, 'No command in progress.', 1, 'CREATE TABLE',2, 'INSERT', 3, 'SELECT', 4, 'CREATE CLUSTER',
5, 'ALTER CLUSTER', 6, 'UPDATE', 7, 'DELETE') COMMAND
from gv$session S,
dba_users U,
gv$process P
where P.ADDR = S.PADDR
and S.user# = U.user_id
and s.sid =&sid;

