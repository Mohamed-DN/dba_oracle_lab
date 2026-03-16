--# Show blocking sessions

SELECT blocking_sid
FROM ( SELECT blocking_sid, SUM(num_blocked) num_blocked, max(ctime) ctime
       FROM ( SELECT l.id1,
                     l.id2,
                     MAX(DECODE(l.block, 1, i.instance_name||'-'||l.sid, 2, i.instance_name||'-'||l.sid, 0 )) blocking_sid,  -- 2=potential block in RAC env--alwaysc   
                     SUM(DECODE(l.request, 0, 0, 1)) num_blocked,
                     max(ctime) ctime
              FROM gv$lock l,
                   gv$instance i
              WHERE ( l.block!= 0 OR l.request > 0 )
                AND l.inst_id = i.inst_id
              GROUP BY l.id1, l.id2 )
       GROUP BY blocking_sid
       ORDER BY num_blocked DESC )
WHERE num_blocked != 0
  AND blocking_sid != '0'
  and ctime/60>5;


SELECT blocking_sid, num_blocked
FROM ( SELECT blocking_sid, SUM(num_blocked) num_blocked
       FROM ( SELECT l.id1,
                     l.id2,
                     MAX(DECODE(l.block, 1, 'BLOCKER', 2, 'BLOCKER', 0 )) blocking_sid,  -- 2=potential block in RAC env--alwaysc   
                     SUM(DECODE(l.request, 0, 0, 1)) num_blocked
              FROM gv$lock l,
                   gv$instance i
              WHERE ( l.block!= 0 OR l.request > 0 )
                AND l.inst_id = i.inst_id
              GROUP BY l.id1, l.id2 )
       GROUP BY blocking_sid
       ORDER BY num_blocked DESC )
WHERE num_blocked != 0
  AND blocking_sid != '0';



WITH blocked_resources AS
  (  select id1,
            id2,
            SUM(ctime) as blocked_secs,
            MAX(request) as max_request,
            COUNT(1) as blocked_count
     from   v$lock
     where  request > 0
     group by id1, id2
  ),
blockers AS
  (  select L.*,
            BR.blocked_secs,
            BR.blocked_count
     from v$lock L,
          blocked_resources BR
     where BR.id1 = L.id1
       and BR.id2 = L.id2
       and L.lmode > 0
       and L.block <> 0 )
select B.id1||'_'||B.id2||'_'||S.sid||'_'||S.serial# as id,
       'SID, SERIAL:'||S.sid||','||S.serial#||',LOCK_TYPE:'||B.type||',PROGRAM:'||S.program||',MODULE:'||S.module||',ACTION:'||S.action||',MACHINE:'||S.machine||',  OSUSER:'||S.osuser||',USERNAME:'||S.username as info,
       B.blocked_secs,
       B.blocked_count
from v$session S,
     blockers B
where B.sid = S.sid;
*/

/*
select INST_ID, SID, TYPE, ID1, ID2, LMODE, REQUEST, CTIME, BLOCK
from gv$lock where (ID1,ID2,TYPE) in
(select ID1,ID2,TYPE from gv$lock where request>0); 
*/
