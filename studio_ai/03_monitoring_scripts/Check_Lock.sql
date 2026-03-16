set line 132
set pages 2000

col OBJECT_NAME for a30
col Holder for a30
col Waiter for a40
col "Lock Type" for a20

select 
distinct o.object_name, 
sh.username||'('||sh.sid||')' "Holder", 
sw.username||'('||sw.sid||')' "Waiter",
        decode(lh.lmode, 1, 'null', 2, 
              'row share', 3, 'row exclusive', 4,  'share', 
              5, 'share row exclusive' , 6, 'exclusive')  "Lock Type"
  from all_objects o, v$session sw, v$lock lw, v$session sh, v$lock lh
 where lh.id1  = o.object_id
  and  lh.id1  = lw.id1
  and  sh.sid  = lh.sid
  and  sw.sid  = lw.sid
  and  sh.lockwait is null
  and  sw.lockwait is not null
  and  lh.type = 'TM'
  and  lw.type = 'TM'
/

/*******************/

with machine FOR a20
col program FOR a30
col "sess" FOR a15

set lines 150 
set pages 2000

SELECT /*+ ORDERED */ 
       DECODE(request,0,'Holder: ','Waiter: ')||a.sid "sess",
       v.serial#,
       spid "PID ORACLE",
       v.process "PID CLIENT",
       v.machine,
       v.program, 
       a.type
  FROM V$LOCK a,
       v$session v,
       v$process p
 WHERE (a.id1, 
        a.id2, 
        a.type) IN (SELECT id1, 
                           id2, 
                           type 
                      FROM v$LOCK 
                     WHERE request>0) 
  AND p.addr = v.paddr 
  AND v.sid = a.sid
 ORDER BY a.id1, a.request
/


set line 3000

SELECT s1.username || '@' || s1.machine
    || ' ( SID=' || s1.sid || ' ) is blocking '
    || s2.username || '@' || s2.machine || ' ( SID=' || s2.sid
    || ' ) on object ' || obj.object_name
    AS Blocking_Status
FROM v$lock l1, v$session s1, v$lock l2, v$session s2, dba_objects obj
WHERE s1.sid=l1.sid and s2.sid=l2.sid
    AND l1.BLOCK=1 and l2.request > 0
    AND l1.id1 = l2.id1
    AND l2.id2 = l2.id2
    AND obj.object_id = s2.row_wait_obj#;



/*****************/

set pages 20
col username form A30
col sid form 9990
col type form A4
col lmode form 990
col request form 990
col objname form A25 Heading "Object Name"
REM col id1 form 999999900
REM col id2 form 999999900

set lines 300

SELECT sn.username, m.sid, m.type,
   DECODE(m.lmode, 0, 'None'
                 , 1, 'Null'
                 , 2, 'Row Share'
                 , 3, 'Row Excl.'
                 , 4, 'Share'
                 , 5, 'S/Row Excl.'
                 , 6, 'Exclusive'
                 , lmode, ltrim(to_char(lmode,'990'))) lmode,
   DECODE(m.request, 0, 'None'
                 , 1, 'Null'
                 , 2, 'Row Share'
                 , 3, 'Row Excl.'
                 , 4, 'Share'
                 , 5, 'S/Row Excl.'
                 , 6, 'Exclusive'
                 , request, ltrim(to_char(request,'990'))) request,
         obj1.object_name objname,
         obj2.object_name objname
FROM     v$session sn,
         v$lock m,
         dba_objects obj1,
         dba_objects obj2
WHERE    sn.sid = m.sid
AND      m.id1 = obj1.object_id (+)
AND      m.id2 = obj2.object_id (+)
AND      lmode != 4
ORDER BY id1,id2, m.request
/


/*******************/

SET PAUSE ON
SET PAUSE 'Press Return to Continue'
SET LINESIZE 300
SET PAGESIZE 60
COLUMN username FORMAT A15
COLUMN osuser FORMAT A8
COLUMN sid FORMAT 99999
COLUMN serial# FORMAT 99999
COLUMN process_id FORMAT A5
COLUMN wait_class FORMAT A12
COLUMN seconds_in_wait FORMAT 9999
COLUMN state FORMAT A17
COLUMN blocking_session 9999
COLUMN blocking_session_state a10
COLUMN module FORMAT a10
COLUMN logon_time FORMAT A20
 
SELECT 
    NVL(a.username, '(oracle)') AS username,
    a.osuser,
    a.inst_id,
    a.sid,
    a.serial#,
    a.sql_id,
    d.spid AS process_id,
    a.wait_class,
    a.seconds_in_wait,
    a.state,
    a.blocking_instance,
    a.blocking_session,
    a.blocking_session_status,
    a.module,
    TO_CHAR(a.logon_Time,'DD-MON-YYYY HH24:MI:SS') AS logon_time
FROM
    gv$session a,
    gv$process d
WHERE  
    a.paddr  = d.addr
AND
   a.inst_id = d.inst_id
AND    
    a.status = 'ACTIVE'
AND 
    a.blocking_session IS NOT NULL
ORDER BY 1,2
/

/**********************/

set lines 300
col lmode for 999999999999
col request for 999999999999
col id1 for 9999999999
col "sess" for a20

SELECT DECODE(request,0,'Holder: ','Waiter: ')||sid "sess",
         id1, id2, lmode, request, type
    FROM V$LOCK
   WHERE (id1, id2, type) IN
             (SELECT id1, id2, type FROM V$LOCK WHERE request>0)
   ORDER BY id1, request
/

sess                      ID1      ID2     Lock Held Lock Requested TY
-------------------- -------- -------- ------------- -------------- --
Holder: 101            720921    76656             6              0 TX
Waiter: 38             720921    76656             0              6 TX
Holder: 55            1245186    36923             6              0 TX
Waiter: 33            1245186    36923             0              6 TX
Waiter: 73            1245186    36923             0              6 TX

I check the PID of the client process that is locking and that is locked:
---------------------------------------------------------------

with machine FOR a20
col program FOR a30
col "sess"  FOR a15
SET lines 150 

 SELECT  /*+ ORDERED */ 
          DECODE(request,0,'Holder: ','Waiter: ')||a.sid "sess",
          v.serial#,
          spid            "PID ORACLE",
          v.process       "PID CLIENT",
          v.machine,
          v.program,                 
          a.type
    FROM  V$LOCK a,
          v$session v,
          v$process p
   WHERE (a.id1, 
          a.id2, 
          a.type) IN (SELECT id1, 
                             id2, 
                             type 
                      FROM   v$LOCK 
                      WHERE  request>0) 
   AND   p.addr = v.paddr 
   AND   v.sid = a.sid
   ORDER BY a.id1, a.request
/

--Oppure :

SELECT l.sid, s.blocking_session blocker, s.event, l.type, l.lmode, l.request, o.object_name, o.object_type
FROM   v$lock l, 
       dba_objects o, 
       v$session s
WHERE UPPER(s.username) = UPPER(‘&User’)
AND   l.id1        = o.object_id (+)
AND   l.sid        = s.sid
ORDER BY sid, type;



/*Or I can launch the following query from where 
  I see the pid and from where I see Lmode of the lock:
--------------------------------------------------
*/

set lines 300
with lm for 99
col rq for 99
col id1 for 9999999999
col id2 for 9999999999
set pages 3000
col program for a15
col hash_value for 99999999999999
col prev_hash_value for 99999999999999
col "session" for a12
col spid for A5
col event for A8
col usern for A8
 
 
select /*+ RULE */ distinct 
        DECODE(a.request,0,'Holder: ','Waiter: ')||wait.sid "Session", 
        ses.serial#, 
        substr(ses.username,1,8) usern,
        p.spid,
        ses.sql_hash_value,
        ses.prev_hash_value,
        substr(wait.event,1,8) event,
        substr(ses.program,1, 13) program,
        a.id1,
        a.id2,
        a.lmode lm, 
        a.request rq, 
        a.type
 from   v$session_wait wait, 
        v$session ses, 
        v$process p,
        v$lock a
 where  wait.sid = ses.sid 
 and    p.addr = ses.paddr
 and    ses.sid = a.sid
 and    (a.id1, a.id2, a.type) IN (SELECT id1, id2, type FROM V$LOCK WHERE (request>0 or lmode > 0) and type='TX')
 order by id1,id2;

Session      SERIAL# USERN    SPID  SQL_HASH_VALUE PREV_HASH_VALUE EVENT    PROGRAM                 ID1         ID2  LM  RQ TY
------------ ------- -------- ----- -------------- --------------- -------- --------------- ----------- ----------- --- --- --
Holder: 15      2512 EANDVIN  24554              0      2640453569 SQL*Net  sqlplus@h3mih        458791         915   6   0 TX
Waiter: 16       608 EANDVIN  26122     3252277217      3252277217 enqueue  sqlplus@h3mih        458791         915   0   6 TX

--- Lock of objects

set lines 124
set heading off
SELECT '------------------' from dual;
select '       LOCKS      ' FROM DUAL;
SELECT '------------------' from dual;
set heading on
set linesize 142
SET pages 200
column sid format 999
column res heading 'Resource Type' format a20
column id1 format 9999999
column id2 format 9999999
column lmode heading 'Lock Held' format a14
column request heading 'Lock Req.' format a14
column serial# format 99999
column username format a10
column terminal heading Term format a6
column tab format a30
column owner format a10

select  l.sid,
        s.serial#,
        s.username,
        decode(l.type,  'RW','RW - Row Wait Enqueue',
                        'TM','TM - DML Enqueue',
                        'TX','TX - Trans Enqueue',
                        'UL','UL - User',l.type||'System') res,
        t.name tab,
        u.name owner,
        l.id1,l.id2,
        decode(l.lmode, 1,'No Lock',
                        2,'Row Share',
                        3,'Row Exclusive',
                        4,'Share',
                        5,'Shr Row Excl',
                        6,'Exclusive',null) lmode,
        decode(l.request, 1,'No Lock',
                          2,'Row Share',
                          3,'Row Excl',
                          4,'Share',
                          5,'Shr Row Excl',
                          6,'Exclusive',null) request
from  v$lock l,
      v$session s,
      sys.user$ u,
      sys.obj$ t
where l.sid = s.sid
and   s.type != 'BACKGROUND'
and   t.obj# = l.id1
and   u.user# = t.owner# ;

---> Lock a particular object

set lines 124
set heading off
SELECT '------------------' from dual;
select '       LOCKS      ' FROM DUAL;
SELECT '------------------' from dual;
set heading on
set linesize 142
SET pages 200
column sid format 999
column res heading 'Resource Type' format a20
column id1 format 9999999
column id2 format 9999999
column lmode heading 'Lock Held' format a14
column request heading 'Lock Req.' format a14
column serial# format 99999
column username format a10
column terminal heading Term format a6
column tab format a30
column owner format a10

select  l.sid,
        s.serial#,
        s.username,
        decode(l.type,  'RW','RW - Row Wait Enqueue',
                        'TM','TM - DML Enqueue',
                        'TX','TX - Trans Enqueue',
                        'UL','UL - User',l.type||'System') res,
        t.name tab,
        u.name owner,
        l.id1,l.id2,
        decode(l.lmode, 1,'No Lock',
                        2,'Row Share',
                        3,'Row Exclusive',
                        4,'Share',
                        5,'Shr Row Excl',
                        6,'Exclusive',null) lmode,
        decode(l.request, 1,'No Lock',
                          2,'Row Share',
                          3,'Row Excl',
                          4,'Share',
                          5,'Shr Row Excl',
                          6,'Exclusive',null) request
from  v$lock l,
      v$session s,
      sys.user$ u,
      sys.obj$ t
where t.name like 'TRELD_REFILL_MASSIVE'
and   l.sid = s.sid
and   s.type != 'BACKGROUND'
and   t.obj# = l.id1
and   u.user# = t.owner# ;


/**************************/


SELECT 
  gvw.inst_id Waiter_Inst,
  gvw.sid Waiter_Sid,
  gvs_w.osuser waiter_osuser,
  gvs_w.program waiter_program,
  gvs_w.machine waiter_machine,
  gvs_w.client_identifier waiter_identifer,
  gvs_w.client_info waiter_thread,
  gvs_w.seconds_in_wait waiter_secs_in_wait,
  gvs_w.sql_id waiter_sql,
  dbms_rowid.rowid_create(
     1,
     gvs_w.ROW_WAIT_OBJ#,
     gvs_w.ROW_WAIT_FILE#,
     gvs_w.ROW_WAIT_BLOCK#,
     gvs_w.ROW_WAIT_ROW#
     ) waiter_rowid_Waiting_on, 
  gvs_w.event waiter_event, 
  decode(gvw.request, 
             0, 'None',
             1, 'NoLock',
             2, 'Row-Share',
             3, 'Row-Exclusive',
             4, 'Share-Table',
             5, 'Share-Row-Exclusive',
             6, 'Exclusive',
             'Nothing-') Waiter_Mode_Req,
  decode(gvh.type,
             'AE', 'Edition Enqueue',
             'AT', 'Lock held for the ALTER TABLE statement',
             'BL', 'Buffer hash table instance',
             'CF', 'Control file schema global enqueue',
             'CI', 'Cross-instance function invocation instance',
             'CU', 'Cursor bind',
'DF', 'datafile instance',
             'DL', 'Direct loader parallel index create',
             'DM', 'Mount/startup db primary/secondary instance',
             'DR', 'Distributed recovery process',
             'DX', 'Distrted_Transaxion',
             'FS', 'File set',
             'HW', 'Space management operations on a specific segment',
             'IN', 'Instance number',
             'IR', 'Instance recovery serialization global enqueue',
             'IS', 'Instance state',
             'IV', 'Library cache invalidation instance',
             'JQ', 'Job queue',
             'KK', 'Thread kick',
             'MM', 'Mount definition global enqueue',
             'MR', 'Media_recovery',
             'PF', 'Password File',
'PI', 'Parallel Operation',
'PS', 'Parallel Operation',
             'PR', 'Process startup',
             'RT', 'Redo thread global enqueue',
             'SC', 'System change number instance',
             'SM', 'SMON',
             'SN', 'Sequence number instance',
             'SQ', 'Sequence number enqueue',
             'SS', 'Sort segment',
             'ST', 'Space transaction enqueue',
             'SV', 'Sequence number value',
             'TA', 'Generic enqueue',
             'TS', 'Temporary segment enqueue (ID2=0) or New block allocation enqueue (ID2=1)',
             'TT', 'Temporary table enqueue',
             'UN', 'User name',
             'US', 'Undo segment DDL',
             'WL', 'Being-written redo log instance',
             'TX', 'Transaction (Left for backwards compatability)',
             'TM', 'Dml (Left for backwards compatability)',
             'UL', 'PLSQL User_lock (Left for backwards compatability)',
             'LS', 'LogStaartORswitch (Left for backwards compatability)',
             'RW', 'Row_wait (Left for backwards compatability)',
             'TE', 'Extend_table (Left for backwards compatability)',
             'Nothing or Library cache lock instance lock (LA..LP) or Library cache pin instance (NA..NZ)') Waiter_Lock_Type,
  gvh.inst_id Locker_Inst, 
  gvh.sid Locker_Sid, 
  gvs.osuser locker_osuser, 
  gvs.machine locker_machine, 
  gvs.program locker_program,
  gvs.client_identifier locker_identifer,
  gvs.client_info locker_thread,
  gvs.seconds_in_wait locker_secs_in_wait, 
  gvs.serial# Locker_Serial,
  gvs.event locker_event,
  gvs.sql_id locker_sql,
  gvs.prev_sql_id locker_prev_sql,
  gvs.status locker_Status, 
  gvs.module locker_Module,
  gvs_w.row_wait_obj# object_locked,
  gvh.ctime secs_object_locked
FROM gv$lock gvh, 
     gv$lock gvw, 
     gv$session gvs,
     gv$session gvs_w 
WHERE (gvh.id1, gvh.id2) 
IN (SELECT 
      id1, 
      id2 
    FROM gv$lock 
    WHERE request=0
    INTERSECT
    SELECT 
      id1, 
      id2 
    FROM gv$lock 
    WHERE lmode=0
    )
AND gvh.id1=gvw.id1
AND gvh.id2=gvw.id2
AND gvh.request=0
AND gvw.lmode=0
AND gvh.sid=gvs.sid
AND gvw.sid=gvs_w.sid
AND gvh.inst_id=gvs.inst_id
AND gvw.inst_id=gvs_w.inst_id
AND gvs_w.sql_id is not null
/




