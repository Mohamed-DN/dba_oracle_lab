@$ORACLE_HOME/rdbms/admin/ashrpt.sql
@$ORACLE_HOME/rdbms/admin/ashrpti.sql (per RAC)

select inst_id, min(sample_time), max(sample_time) from gv$active_session_history group by inst_id order by 1;

-- https://blogs.oracle.com/oraclemagazine/beginning-performance-tuning-active-session-history

-- ##############################
-- ### ACTIVE_SESSION_HISTORY ###
-- ##############################

col sample_time for a25
select sample_time, inst_id, count(1) from gv$active_session_history
where sample_time between to_timestamp('15/05/2025 14:22:00','dd/mm/yyyy hh24:mi:ss')
                      and to_timestamp('15/05/2025 14:28:00','dd/mm/yyyy hh24:mi:ss') 
group by sample_time, inst_id order by sample_time, inst_id;

col sample_time for a25
col machine for a30
col event for a30
col username for a25
select sample_time, inst_id, username, machine, session_id, sql_id, event, blocking_inst_id, blocking_session, wait_time, round(time_waited/100000) time_waited
from gv$active_session_history ash, dba_users u
where sample_time between to_timestamp('15/05/2025 14:22:00','dd/mm/yyyy hh24:mi:ss')
                      and to_timestamp('15/05/2025 14:28:00','dd/mm/yyyy hh24:mi:ss') 
and ash.user_id=u.user_id 
-- and u.username='SICT'
order by sample_time, inst_id, session_id;

-- CDB

col sample_time for a25
col username for a40
col event for a44
select sample_time, inst_id, username, session_id, sql_id, event, blocking_inst_id, blocking_session, wait_time, round(time_waited/100000) time_waited
from gv$active_session_history ash, cdb_users u
where sample_time between to_timestamp('15/05/2025 14:22:00','dd/mm/yyyy hh24:mi:ss')
                      and to_timestamp('15/05/2025 14:28:00','dd/mm/yyyy hh24:mi:ss') 
and ash.con_id=u.con_id and ash.user_id=u.user_id and username not in ('SYSRAC')
order by sample_time, inst_id, session_id;

-- ####################################
-- ### DBA_HIST_ACTIVE_SESS_HISTORY ###
-- ####################################

col sample_time for a25
select sample_time, instance_number, count(1) from dba_hist_active_sess_history 
where sample_time between to_timestamp('15/05/2025 14:22:00','dd/mm/yyyy hh24:mi:ss')
                      and to_timestamp('15/05/2025 14:28:00','dd/mm/yyyy hh24:mi:ss') 
group by sample_time, instance_number order by sample_time;

col sample_time for a25
select sample_time, instance_number "INST", session_id, sql_id, event, blocking_inst_id, blocking_session, wait_time, round(time_waited/100000) time_waited 
from dba_hist_active_sess_history 
where sample_time between to_timestamp('15/05/2025 14:22:00','dd/mm/yyyy hh24:mi:ss')
                      and to_timestamp('15/05/2025 14:28:00','dd/mm/yyyy hh24:mi:ss') 
-- and blocking_session is not null
-- and user_id <> 0
-- and session_id=36
order by 1,2;

col sample_time for a25
col INST for 9999
col username for a30
col event for a40
select sample_time, instance_number "INST", session_id, username, sql_id, event, blocking_inst_id, blocking_session, wait_time, round(time_waited/100000) time_waited 
from dba_hist_active_sess_history ash, cdb_users u
where sample_time between to_timestamp('15/05/2025 14:22:00','dd/mm/yyyy hh24:mi:ss')
                      and to_timestamp('15/05/2025 14:28:00','dd/mm/yyyy hh24:mi:ss') 
and ash.con_id=u.con_id and ash.user_id=u.user_id
-- and blocking_session is not null
-- and user_id <> 0
-- and session_id=36
order by 1,2,3;

-- DBA_HIST_ACTIVE_SESS_HISTORY => GROUP BY ORARIA, DISTINTA PER MACHINE

select to_char(sample_time,'yyyy/mm/dd hh24') "DATA", machine, MIN(COUNT) "MIN", ROUND(AVG(COUNT)) "AVG", MAX(COUNT) "MAX" from
(select sample_time, machine, count(1) "COUNT"
from dba_hist_active_sess_history ash, dba_users u
where sample_time between to_timestamp('15/05/2025 14:22:00','dd/mm/yyyy hh24:mi:ss')
                      and to_timestamp('15/05/2025 14:28:00','dd/mm/yyyy hh24:mi:ss') 
and ash.user_id=u.user_id and u.username='ARCOTUSER'
group by sample_time, machine)
group by to_char(sample_time,'yyyy/mm/dd hh24'), machine order by to_char(sample_time,'yyyy/mm/dd hh24'), machine;

-- DBA_HIST_ACTIVE_SESS_HISTORY => COUNT DISTINTE PER MACHINE

col sample_time for a25
select inst_id, sample_time, count(1) from gv$active_session_history ash, dba_users u
where sample_time between to_timestamp('15/05/2025 14:22:00','dd/mm/yyyy hh24:mi:ss')
                      and to_timestamp('15/05/2025 14:28:00','dd/mm/yyyy hh24:mi:ss') 
and ash.user_id=u.user_id and u.username='ARCOTUSER'
group by inst_id, sample_time order by sample_time;

-- ASH report

@$ORACLE_HOME/rdbms/admin/ashrpt.sql
@$ORACLE_HOME/rdbms/admin/ashrpti.sql

-- ASH

select * from v$sgastat where name like 'ASH buffers';

select inst_id, min(sample_time), max(sample_time) from gv$active_session_history group by inst_id order by 1;

-- Most active SQL in the last 5 minutes

select inst_id, sql_id, count(*), round(100*count(*)/sum(count(*)) over (), 2) pctload
from gv$active_session_history
where sample_time > sysdate -5/24/60
and session_type <> 'BACKGROUND'
group by inst_id, sql_id
order by count(*);

-- Analisi lock

col SAMPLE_TIME for a30

select SAMPLE_TIME, INSTANCE_NUMBER, SESSION_ID, SQLT.SQL_ID, SQLT.SQL_TEXT, BLOCKING_INST_ID, BLOCKING_SESSION, EVENT
from DBA_HIST_ACTIVE_SESS_HISTORY ASH, DBA_HIST_SQLTEXT SQLT
where blocking_session_status = 'VALID' 
and ASH.SQL_ID = SQLT.SQL_ID
-- and SQLT.SQL_TEXT like 'insert%'
and SAMPLE_TIME > SYSDATE-4/24
-- and SAMPLE_TIME BETWEEN to_timestamp('2014-12-15 03:06:00', 'YYYY-MM-DD HH24:MI:SS') and to_timestamp('2014-12-15 03:15:00', 'YYYY-MM-DD HH24:MI:SS')
order by SAMPLE_TIME;

select SAMPLE_TIME, INSTANCE_NUMBER, SESSION_ID, SQLT.SQL_ID, SQLT.SQL_TEXT, EVENT
from DBA_HIST_ACTIVE_SESS_HISTORY ASH, DBA_HIST_SQLTEXT SQLT
where INSTANCE_NUMBER=2 and SESSION_ID = 876
and ASH.SQL_ID = SQLT.SQL_ID
and SAMPLE_TIME > SYSDATE-4/24
order by SAMPLE_TIME;

-- SQL that spent more time on I/O

select inst_id, ash.sql_id, count(*)
from gv$active_session_history ash, v$event_name evt
where ash.sample_time > sysdate - 1/24/60
and ash.session_state = 'WAITING'
and ash.event_id = evt.event_id
and evt.wait_class = 'User I/O'
group by inst_id, sql_id
order by count(*) desc;

SELECT sql_id, COUNT(*)
FROM gv$active_session_history ash, gv$event_name evt
WHERE ash.sample_time BETWEEN to_date ('03/02/2009 03:00:00','dd/mm/yyyy hh24:mi:ss')
                          AND to_date ('03/02/2009 04:05:00','dd/mm/yyyy hh24:mi:ss')
AND ash.session_state = 'WAITING'
AND ash.event_id = evt.event_id
-- AND evt.wait_class = 'User I/O'
GROUP BY sql_id
ORDER BY COUNT(*) DESC;

###

SELECT ash.sql_id, sample_time, user_id, CURRENT_OBJ#, program, module, action, count(1)
FROM dba_hist_active_sess_history ash, gv$event_name evt, dba_hist_sqltext txt
WHERE ash.sample_time BETWEEN to_date ('03/02/2009 04:03:00','dd/mm/yyyy hh24:mi:ss')
                          AND to_date ('03/02/2009 04:03:10','dd/mm/yyyy hh24:mi:ss')
AND ash.session_state = 'WAITING'
AND ash.event_id = evt.event_id
-- AND evt.wait_class = 'User I/O'
AND ash.sql_id = txt.sql_id
-- and ash.blocking_session is not null
GROUP BY ash.sql_id, sample_time, user_id, CURRENT_OBJ#, program, module, action ;

### ATTIVITA' FATTA DALL'ADVISOR

SELECT ash.sql_id, sample_time, user_id, CURRENT_OBJ#, program, module, action, count(1)
FROM dba_hist_active_sess_history ash, gv$event_name evt, dba_hist_sqltext txt
WHERE ash.sample_time BETWEEN to_date ('04/02/2009 00:00:00','dd/mm/yyyy hh24:mi:ss')
                          AND to_date ('04/02/2009 05:00:00','dd/mm/yyyy hh24:mi:ss')
AND ash.session_state = 'WAITING'
AND ash.event_id = evt.event_id
-- AND evt.wait_class = 'User I/O'
AND ash.sql_id = txt.sql_id
-- and ash.blocking_session is not null
and module = 'DBMS_SCHEDULER'
and current_obj#=3121146
GROUP BY ash.sql_id, sample_time, user_id, CURRENT_OBJ#, program, module, action
order by sample_time;

DBMS_LOB.SUBSTR(sql_text,1,30)

### Attività che comporti User I/O

select inst_id, ash.sql_id, count(*)
from gv$active_session_history ash, v$event_name evt
where ash.sample_time > sysdate - 1/24/60
and ash.session_state = 'WAITING'
and ash.event_id = evt.event_id
and evt.wait_class = 'User I/O'
group by inst_id, sql_id
order by count(*) desc;

### Query utili da provare

### What resource is currently in high demand?
### This query will give you for the last 30 minutes those resources that are in high demand on your system.

select active_session_history.event,
       sum(active_session_history.wait_time +
           active_session_history.time_waited) ttl_wait_time
  from v$active_session_history active_session_history
 where active_session_history.sample_time between sysdate - 60/2880 and sysdate
group by active_session_history.event
order by 2

### What user is waiting the most?
### what user is consuming the most resource at a point in time, independent of the total resources that the user has used
### who is waiting the most for resources at a point in time
### This SQL is written for a 30-minute interval from current system time so you may need to change.

select sesion.sid,
        sesion.username,
        sum(active_session_history.wait_time +
            active_session_history.time_waited) ttl_wait_time
   from v$active_session_history active_session_history,
        v$session sesion
  where active_session_history.sample_time between sysdate - 60/2880 and sysdate
    and active_session_history.session_id = sesion.sid
group by sesion.sid, sesion.username
order by 3

### What SQL is currently using the most resources?

select active_session_history.user_id,
       dba_users.username,
       sqlarea.sql_text,
       sum(active_session_history.wait_time +
           active_session_history.time_waited) ttl_wait_time
  from v$active_session_history active_session_history,
       v$sqlarea sqlarea,
       dba_users
 where active_session_history.sample_time between sysdate - 60/2880 and sysdate
   and active_session_history.sql_id = sqlarea.sql_id
   and active_session_history.user_id = dba_users.user_id
group by active_session_history.user_id,sqlarea.sql_text, dba_users.username
order by 4

### What object is currently causing the highest resource waits?

select dba_objects.object_name,
       dba_objects.object_type,
       active_session_history.event,
       sum(active_session_history.wait_time +
           active_session_history.time_waited) ttl_wait_time
  from v$active_session_history active_session_history,
       dba_objects
 where active_session_history.sample_time between sysdate - 60/2880 and sysdate
   and active_session_history.current_obj# = dba_objects.object_id
group by dba_objects.object_name, dba_objects.object_type, active_session_history.event
order by 4
