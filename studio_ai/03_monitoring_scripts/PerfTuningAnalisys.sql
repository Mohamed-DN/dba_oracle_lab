
-- ===========================================================================================
1. Check alert for NOW-recurring errors

   grep "ORA-" LISTENERLOG | uniq -c | sort -n

-- ===========================================================================================   
2. Check log listeners for bombardment by Microservices / Application

   -- see in general which service bombs the most and understand why a ConnPOol is not used or why it finds itself opening and closing conn continuously
   tail -1000 /u01/app/orabase/diag/tnslsnr/poddb01-sec-01/listener/trace/listener.log | grep SERVICE_NAME | cut -f 7 -d '=' | cut -f 1 -d ")"  | sort -n | uniq -c

     11 oracle
      7 poddb01-sec-01.dcse.cartasi.local
      9 PVAS1SEC
     12 root
    295 YAPP_RO

-- ===========================================================================================
3. Check that no lock situations occur in the AWR for more than 5 minutes

    SELECT *
	FROM (
	select 
	  sql_exec_id,min(sample_time) LOCK_START_TIME,max(sample_time) LOCK_FINISH_TIME,(max(sample_time) - min(sample_time)) LOCK_TIME
	from dba_hist_active_sess_history
	where blocking_session is not null and
	sql_exec_id is not null
	and session_type <> 'BACKGROUND'
	group by sql_exec_id
	)
	where LOCK_TIME > INTERVAL '10' MINUTE
	order by 2
	
	-- see what the blocked session and the blocker were doing
	select *
	from dba_hist_active_sess_history
	where sql_exec_id = &sql_exc_id
	

-- ===========================================================================================
4. Check on EM13 to understand if no non-standard events have occurred over at least the last week (lock, increases in database connections, contention)


-- ===========================================================================================
5. Check that there is no reason why the sql id cursors are not shared

	select 
	  sql_id,count(*)
	from v$sql_shared_cursor
	group by sql_id
	having count(*) > 100
	order by 2 desc

if a line appears, investigate why the sql is not shared according to the execution rate (take this into consideration if it has been executed more than 100 times in total)

-- ===========================================================================================
6. Check that the indexes are used in the execution plans

    select
	  owner,index_name,index_type,table_owner,table_name,tablespace_name,'ALTER INDEX ' || OWNER || '.' || INDEX_NAME || ' INVISIBLE;'
	from dba_indexes
	where 1=1
	-- and owner like 'MKT%'
	and index_name not in ( 
	select
	  distinct object_name
	from dba_hist_sql_plan
	where object_type like '%INDEX%'
	)
	and uniqueness <> 'UNIQUE'
	and owner not in ( 'SYS','SYSTEM','APEX_040200','DBA_OP','MDSYS','FLOWS_FILES','DVSYS','OUTLN','DVSYS','OJVMSYS','XDB','PERFSTAT','WMSYS','LBACSYS','CTXSYS','GSMADMIN_INTERNAL','DBFW_CONSOLE_ACCESS','ORDDATA')
    and visibility = 'VISIBLE'

	--evaluate together with the applications the opportunity to make the indices that are not used invisible and then drop them
	
	
-- ===========================================================================================
7. Check that there are no queries with high execution times (e.g. 300 millisec)

	SELECT ROUND(disk_reads/executions) "DSK/EX", ROUND(buffer_gets/executions) "BFF/EX",
		   ROUND(rows_processed/executions) "RWS/EX", ROUND((cpu_time/1000000)/executions,3) "CPU/EX",
		   ROUND((elapsed_time/1000000)/executions,3) "ELA/EX", executions "EXEC", 
		   first_load_time, last_load_time, parsing_schema_name, sql_id, plan_hash_value, sql_text
	FROM gv$sqlarea s
	WHERE executions > 100
	and parsing_schema_name like '%' --not in ('SYS','SYSMAN','DBSNMP','NAGIOS')
	-- and s.sql_id in (select sp.sql_id from v$sql_plan sp where sp.object_name='TABLE')
	-- and upper(sql_text) like '%TABLE%'
	and ROUND((elapsed_time/1000)/executions,3) > 300
	ORDER BY elapsed_time/executions DESC;


-- ===========================================================================================
8. Check that there are no parallel queries that last less than a minute

	SELECT ROUND(disk_reads/executions) "DSK/EX", ROUND(buffer_gets/executions) "BFF/EX",
		   ROUND(rows_processed/executions) "RWS/EX", ROUND((cpu_time/1000000)/executions,3) "CPU/EX",
		   ROUND((elapsed_time/1000000)/executions,3) "ELA/EX", executions "EXEC", 
		   first_load_time, last_load_time, parsing_schema_name, sql_id, plan_hash_value, sql_text
	FROM gv$sqlarea s
	WHERE executions > 100
	and parsing_schema_name not in ('SYS','SYSMAN','DBSNMP','NAGIOS')
	-- and s.sql_id in (select sp.sql_id from v$sql_plan sp where sp.object_name='TABLE')
	-- and upper(sql_text) like '%TABLE%'
	and ROUND((elapsed_time/1000)/executions,3) < 60000
	and px_servers_executions > 0
	ORDER BY elapsed_time/executions DESC;
	
	
-- ===========================================================================================
9. Perform a check on the indexes with parallel degree > 1. Check the size of the table, if greater than 10Gb it makes sense otherwise put the indexes in noparallel

	select *
	from dba_indexes where degree <> 'DEFAULT' 
	and degree > 1

	
-- ===========================================================================================
10. Check that tables larger than 100GB are partitioned


	select 
	  segment_name, 
	  segment_type, 
	  SIZE_GB
	from (
	select 
	  segment_name,
	  segment_type,
	  trunc(sum(bytes)/1024/1024/1024) SIZE_GB 
	from dba_segments
	where segment_type like 'TABLE%'
	and partition_name is null
	group by segment_name,segment_type
	)
	where size_gb >= 100
	order by 2,1

	
-- ===========================================================================================
11. Check that the sequences have cache enabled in the RAC environment

	select 
	  'ALTER SEQUENCE ' || SEQUENCE_OWNER || '.' || SEQUENCE_NAME || ' CACHE 50;'
	from dba_sequences
	where sequence_owner not like '%SYS%'
	and cache_size = 0 
	and order_flag ='N' 
	/


-- ===========================================================================================
11. Check the size of the indexes and possible rebuild

    --
    -- Check that the indexes are less than 50% of the size of the table.
	-- I only take into account tables larger than 10MB, otherwise the initial can create false positives
	--
	
	with tab_part_size as (
	select
	  owner,
	  segment_name as table_name,
	  sum(bytes)/1024/1024 TBL_SIZE_MB
	from dba_segments
	where owner not in ('SYS','SYSTEM','OLSNODES','XDB','WMSYS','CTXSYS','ORDDATA','MDSYS','APEX_040200','DVSYS','OJVMSYS','OUTLN','GSMADMIN_INTERNAL' )
	and partition_name is null
	and segment_type like 'TABLE%'
	group by owner,segment_name 
	)
	select 
	  owner index_owner,
	  index_name,
	  trunc(IDX_SIZE_MB*100/TBL_SIZE_MB) SZ_IDX_VS_SZ_TBL
	from (
	select 
	  idx.owner,
	  index_name ,
	  tps.TBL_SIZE_MB,
	  sum(bytes)/1024/1024 IDX_SIZE_MB
	from dba_indexes idx,
		 tab_part_size tps ,
		 dba_segments seg
	where idx.table_name = tps.table_name
	  and idx.owner = tps.owner
	  and seg.segment_name = idx.index_name
	  and index_name not like 'SYS_IL%'
	group by idx.owner,
			 index_name ,
			 tps.TBL_SIZE_MB
	 )
	 where IDX_SIZE_MB*100/TBL_SIZE_MB > 50
	   and TBL_SIZE_MB> 10 -- I only take tables larger than 10 MB to avoid false positives
	 order by 3 desc,1,2
	 /
	 

-- ===========================================================================================
12. Check to understand if there are queries that have bad plans compared to others


select *
from (
select 
  sql_id,
  plan_hash_value,
  trunc(elapsed_time_avg*100/min_elapsed_time) as ELA_TIME_PERC_OVER_AVG
from (
select 
  sql_id,
  plan_hash_value,
  elapsed_time_avg,
  min(elapsed_time_avg) over ( partition by sql_id ) as min_elapsed_time
from(
select 
  sql_id, 
  plan_hash_value,
 avg(round(decode(executions_delta, 0, 0, elapsed_time_delta/executions_delta/1000000),6)) elapsed_time_avg
from dba_hist_sqlstat ss, dba_hist_snapshot sn
where 1=1 
--and sql_id = '5yfpv3mz8q294'
and parsing_schema_name  not in ('SYS','SYSTEM','OLSNODES','XDB','WMSYS','CTXSYS','ORDDATA','MDSYS','APEX_040200','DVSYS','OJVMSYS','OUTLN','GSMADMIN_INTERNAL' )
and sn.snap_id = ss.snap_id
and sn.instance_number = ss.instance_number
group by sql_id,plan_hash_value
)
)
where min_elapsed_time > 0
order by 3 desc
)
where ELA_TIME_PERC_OVER_AVG > 100
/


