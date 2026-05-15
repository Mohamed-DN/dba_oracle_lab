-- Source: https://www.scriptdba.com/query-per-vedere-le-sessioni-rman/
-- Title: Query sessioni RMAN

Set lines 200
Set pages 60
select to_char(sysdate -(LAST_CALL_ET/86400),'DD-MON-YY hh24:mi:ss') LAST_CALL, s.status, s.process,s.program, s.schemaname,
s.sid, s.serial#, p.spid, s.osuser, S.machine, S.terminal, to_char(S.logon_time,'DD-MM-YYYY hh24.mi.ss') LOGON_TIME 
from gv$session S,
dba_users U,
gv$process P
where P.ADDR = S.PADDR
and S.user# = U.user_id
and s.type ='USER'
and s.username is not null
and s.program like '%rman%';

Set lines 200
Set pages 60
select to_char(sysdate -(LAST_CALL_ET/86400),'DD-MON-YY hh24:mi:ss') LAST_CALL, s.status, s.process,s.program, s.schemaname,
s.sid, s.serial#, p.spid, s.osuser, S.machine, S.terminal, to_char(S.logon_time,'DD-MM-YYYY hh24.mi.ss') LOGON_TIME 
from gv$session S,
dba_users U,
gv$process P
where P.ADDR = S.PADDR
and S.user# = U.user_id
and s.type ='USER'
and s.username is not null
and s.program like '%rman%';

