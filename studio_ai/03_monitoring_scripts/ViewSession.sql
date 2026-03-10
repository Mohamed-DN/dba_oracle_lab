' prompt A-Script: Display active sessions... '

select
    count(*)
  , sql_id
  , case state when 'WAITING' then 'WAITING' else 'ON CPU' end state
  , case state when 'WAITING' then event else 'On CPU / runqueue' end event
from
    v$session
where
    status='ACTIVE'
and type !='BACKGROUND'
and wait_class != 'Idle'
and sid != (select sid from v$mystat where rownum=1)
group by
    sql_id
  , case state when 'WAITING' then 'WAITING' else 'ON CPU' end
  , case state when 'WAITING' then event else 'On CPU / runqueue' end
order by
    count(*) desc
/

'******'

SET LINES 400
COL osuser FOR a14
COL username FOR a14
COL machine FOR a20
COL sql_text FOR a42
COL event FOR a31
COL sql_id FOR a14
COL sid FOR 9999
COL hash_value FOR 99999999999999
COL p1 FOR a16
COL p2 FOR a16
COL p3 FOR a16
COL program FOR a40
COL inst_i FOR 99
COL SERVER FOR a40
SET PAGES 400

  SELECT DISTINCT --ses.inst_id,
                  wait.sid,
                  ses.serial#,
                  ses.sql_id,
                  SUBSTR (sql.sql_text, 1, 42) SQL_TEXT,
                  sql.hash_value,
                  wait.event,
                  --    wait.p1text||' = '||wait.p1 p1,
                  --    wait.p2text||' = '||wait.p2 p2,
                  --    wait.p3text||' = '||wait.p3 p3,
                  --    ses.osuser,
                  ses.username,
                  SUBSTR (ses.machine, 1, 20) machine,
                  ses.SERVICE_NAME,
                  ses.SERVER,
                  SUBSTR (ses.program, 1, 40) program
    FROM gv$session_wait wait, gv$session ses, gv$sql sql
   WHERE     wait.sid = ses.sid
         AND --audsid != userenv('sessionid') and
             ses.sql_hash_value = sql.hash_value
         AND wait.event = ses.event
         AND wait.event NOT IN
                ('rdbms ipc message',
                 'pmon timer',
                 'smon timer',
                 'wakeup time manager')
ORDER BY 3, 8;

***********
set lines 3000
set pages 30000
COLUMN   status ON FORMAT   a20
COLUMN   logon ON FORMAT a20
COLUMN   SERVICE_NAME ON FORMAT a20
COLUMN   osuser ON FORMAT   a10
COLUMN   program ON FORMAT   a50
COLUMN   machine ON FORMAT   a10
COLUMN   username ON FORMAT   a12
COLUMN   sql_text ON FORMAT   a30
COLUMN   SERVER FOR a15
COLUMN   spid ON FORMAT   a5
COLUMN   sid ON FORMAT   9999
COLUMN   spid ON FORMAT   99999
COLUMN   machine ON FORMAT a30

  SELECT DISTINCT a.status,
                  to_char(logon_time,'dd/mm/yyyy hh24:mi:ss') logon,
                  SPID,
                  SID,
                  --A.SERVICE_NAME,
                  --A.SERIAL#,
                 -- NVL (SQL_TEXT, 'BCK PROCESS O DIRECT OP.') SQL_TEXT,
                  SUBSTR(SQL_TEXT,1,30) SQL_TEXT,
                  A.OSUSER,
                  A.USERNAME,
                  A.MACHINE,
                  A.PROGRAM,
                  V.SQL_ID
                  --A.SERVER
    FROM GV$SESSION A, GV$SQL V, GV$PROCESS P
   WHERE     HASH_VALUE(+) = SQL_HASH_VALUE
         AND status = 'ACTIVE'
         AND A.PADDR = P.ADDR
         and A.USERNAME is not null
         --and A.MACHINE='FASTWEBIT\KM001OSM'
         --and A.USERNAME not in ('SYS','SYSTEM')
         --AND P.SPID =15838
		 --and osuser !='oracle'
		 --and SID in (1505)
ORDER BY 1,2;

*****************

set lines 3000
set pages 3000
COLUMN   pid ON FORMAT   999999
COLUMN   pid ON FORMAT   a10
COLUMN   sid ON FORMAT   99999
COLUMN   sql_id ON FORMAT A15
COLUMN   status for a10
COLUMN   ser# ON FORMAT   a15
COLUMN   box ON FORMAT   a30
COLUMN   username ON FORMAT   a12
COLUMN   os_user ON FORMAT   a15
COLUMN   program ON FORMAT   a50
COLUMN   log_on on FORMAT a20

select
       a.spid pid,
       b.sid sid,
       b.sql_id,
       b.status,
       to_char(b.logon_time,'dd/mm/yyyy hh24:mi:ss') log_on,
       substr(b.serial#,1,5) ser#,
       substr(b.machine,1,30) box,
       substr(b.username,1,10) username,
       substr(b.osuser,1,8) os_user,
       substr(b.program,1,90) program,
       b.SERVICE_NAME,
       b.status
from gv$session b, gv$process a
where
b.paddr = a.addr
--and type='USER'
--and status ='ACTIVE'
--and b.USERNAME not in ('SYS','SYSTEM')
--and b.machine like 'as002svn%'
and b.username='TAS_SV'
--  and b.program like '%sqlldr@RMEMM12%'
order by log_on desc,sid, b.status;


***********

SET HEADING ON
SET LINESIZE 3000
SET PAGESIZE 100
COLUMN username FORMAT A15
COLUMN osuser FORMAT A10
COLUMN sid FORMAT 9,999,999
COLUMN serial# FORMAT 9,999,999
COLUMN lockwait FORMAT A20
COLUMN status FORMAT A8
COLUMN module FORMAT A50
COLUMN machine FORMAT A60
--COLUMN program FORMAT A20
COLUMN sql_id FORMAT A15
COLUMN logon_time FORMAT A20

SELECT LPAD (' ', (LEVEL - 1) * 2, ' ') || NVL (s.username, '(oracle)')
              AS username,
           s.osuser,
           s.status,
           s.sid,
           s.sql_id,
           s.serial#,
           s.lockwait,
           s.module,
           s.machine,
           --s.program,
           TO_CHAR (s.logon_Time, 'DD-MON-YYYY HH24:MI:SS') AS logon_time
      FROM gv$session s
CONNECT BY PRIOR s.sid = s.blocking_session
START WITH s.blocking_session IS NULL
order by status,logon_time
/

****************************************************
set echo off
set time on
set timing on

set pages 10000
set lines 300

set trims on

col USERNAME       for a30
col MACHINE        for a40
col CLIENT_INFO    for a30

alter session set nls_date_format='dd/mm/yy hh24:mi:ss';

select
       V$S.LOGON_TIME,
       V$S.STATUS,
       V$S.SID,
       V$S.SERIAL#,
       V$S.USERNAME,
       V$S.PROCESS,
       V$S.PROGRAM,
       --V$P.SPID,
       V$S.MACHINE
       --v$S.SERVICE_NAME
  from gv$session V$S,
       gv$process V$P
 where
       V$S.PADDR = V$P.ADDR
    --and v$S.SID=297
   --and V$S.USERNAME not in ('SYS','SYSTEM')
  -- and v$S.PROGRAM like '%rman%'
   --and V$S.STATUS ='ACTIVE'
order by
	   V$S.LOGON_TIME,
         V$S.PROCESS,
         V$S.SID
/

********************************************

set echo off
set time on
set timing on

set pages 10000
set lines 300

set trims on

col USERNAME       for a30
col MACHINE        for a20
col CLIENT_INFO    for a30

alter session set nls_date_format='dd/mm/yy hh24:mi:ss';

select DISTINCT SERVICE_NAME
  from v$session V$S,
       v$process V$P
 where
       V$S.PADDR = V$P.ADDR
       and V$S.SID ='&SID'
order by
	   V$S.LOGON_TIME,
         V$S.PROCESS,
         V$S.SID
/

**********************************************

set echo off
set time on
set feed off

set pages 10000
set lines 300

col USERNAME       for a30
col MACHINE        for a20
col LOGON          for a20

alter session set nls_date_format='dd/mm/yyyy hh24';

select 
       V$S.SID,
       V$S.USERNAME,
       to_char(V$S.LOGON_TIME,'dd/mm/yyyy hh24:mi') LOGON,
       V$S.MACHINE,
       V$S.STATUS,
       COUNT(*)
 from v$session V$S,
       v$process V$P
 where 
       V$S.PADDR = V$P.ADDR
   and V$S.USERNAME not in ('SYS','OPS$ORACLE')
 group by 
       V$S.SID,
       V$S.USERNAME, 
       to_char(V$S.LOGON_TIME,'dd/mm/yyyy hh24:mi'),
       V$S.MACHINE,
       V$S.STATUS  
 order by MACHINE,LOGON
/

