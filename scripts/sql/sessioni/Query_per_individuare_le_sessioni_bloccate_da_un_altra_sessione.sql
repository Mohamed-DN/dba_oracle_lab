-- Source: https://www.scriptdba.com/query-per-individuare-la-sessione-che-sta-bloccando-altre-sessioni/
-- Title: Query per individuare le sessioni bloccate da un'altra sessione

select a.inst_id as WInst ,a.sid as WSid, a.serial# as WSer, a.sql_id as WSql , a.seconds_in_wait as WSec,
 b.sid as BSid , b.serial# as BSer , a.event as WEvent , b.event as BEvent, b.sql_id as BSql
from gv$session a , gv$session b
where a.BLOCKING_SESSION_STATUS='VALID' and b.inst_id=a.BLOCKING_INSTANCE and b.sid=a.BLOCKING_SESSION;

select a.inst_id as WInst ,a.sid as WSid, a.serial# as WSer, a.sql_id as WSql , a.seconds_in_wait as WSec,
 b.sid as BSid , b.serial# as BSer , a.event as WEvent , b.event as BEvent, b.sql_id as BSql
from gv$session a , gv$session b
where a.BLOCKING_SESSION_STATUS='VALID' and b.inst_id=a.BLOCKING_INSTANCE and b.sid=a.BLOCKING_SESSION;

