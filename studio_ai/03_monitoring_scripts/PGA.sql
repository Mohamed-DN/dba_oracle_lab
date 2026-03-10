-- Limiting process size with database parameter PGA_AGGREGATE_LIMIT (Doc ID 1520324.1)
-- How To Find Where The Memory Is Growing For A Process (Doc ID 822527.1)

-- PGA_AGGREGATE_TARGET (dinamico x tutte le sessioni insieme) (settato implica automatic & dynamic sizing SQL workarea)
-- WORKAREA_SIZE_POLICY => AUTO sistema automaticamente i parametri *_WORK_AREA

select inst_id, name, round(value/1024/1024) MB from gv$pgastat where unit='bytes' order by 1,2;

select inst_id, name, round(value/1024/1024) MB from gv$pgastat where name in ('maximum PGA allocated','total PGA allocated','total PGA inuse') order by 1,2;

SELECT username, pid, program, pga_used_mem, pga_alloc_mem, pga_max_mem FROM v$process order by 6;

V$SYSSTAT, V$SESSTAT, V$MYSTAT

SELECT se.sid, se.username, sn.name, st.value
FROM v$sesstat st, v$statname sn, v$session se
WHERE sn.name like 'workarea%'
AND st.statistic# = sn.statistic#
AND st.sid = se.sid
ORDER BY 4;

workarea memory allocated: total PGA allocated to a session
workarea executions - optimal: number of times workarea operations are performed in memory
workarea executions - onepass: disk usage
workarea executions - multipass: indication of the number of times a single operation is written to disk (!=0 -> PGA small)

-- DBA_HIST_PGASTAT
-- total PGA allocated
-- total PGA inuse
-- maximum PGA allocated

select P.SNAP_ID, P.INSTANCE_NUMBER, S.BEGIN_INTERVAL_TIME, ROUND(VALUE/1024/1024) MB from DBA_HIST_PGASTAT P, DBA_HIST_SNAPSHOT S
where P.SNAP_ID=S.SNAP_ID and P.INSTANCE_NUMBER=S.INSTANCE_NUMBER
and P.NAME='total PGA inuse' 
and ROUND(VALUE/1024/1024) > 20000 order by S.BEGIN_INTERVAL_TIME;

-- DBA_HIST_PROCESS_MEM_SUMMARY

select * from DBA_HIST_PROCESS_MEM_SUMMARY where 

-- WORST SQL_IDs
-- How to Find Top sql_id's That Consume PGA and Temporary Segments Most from ASH (Doc ID 2516606.1)

select *
from (select instance_number, sql_id, max(pga_sum_mb) pga_max
      from (select instance_number, sample_time, sql_id, round(sum(nvl(pga_allocated, 0))/1024/1024) pga_sum_mb
            from dba_hist_active_sess_history
            where sample_time between to_timestamp('&begin_timestamp', 'yyyy/mm/dd hh24:mi') and to_timestamp('&end_timestamp', 'yyyy/mm/dd hh24:mi')
            group by instance_number, sample_time, sql_id)
      group by instance_number, sql_id
order by pga_max desc);

Enter value for begin_timestamp: 2025/02/14 23:00
Enter value for end_timestamp: 2025/02/15 00:00