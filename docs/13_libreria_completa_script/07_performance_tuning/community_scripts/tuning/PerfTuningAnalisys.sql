
-- ===========================================================================================
1. Check alert per errori ORA- ricorrenti

   grep "ORA-" LISTENERLOG | uniq -c | sort -n

-- ===========================================================================================   
2. Check log listeners per bombardamento da parte di Microservizi / Application 

   -- vedere in generale quale servizio bombarda di piu' e capire perche non viene utilizzato un ConnPOol o perche si ritrova a aprire e chiudere conn in continuazione
   tail -1000 /u01/app/orabase/diag/tnslsnr/poddb01-sec-01/listener/trace/listener.log | grep SERVICE_NAME | cut -f 7 -d '=' | cut -f 1 -d ")"  | sort -n | uniq -c

     11 oracle
      7 poddb01-sec-01.dcse.cartasi.local
      9 PVAS1SEC
     12 root
    295 YAPP_RO

-- ===========================================================================================
3. Verificare che non si presentino situazioni di lock bloccanti nell''AWR per piu di 5 minuti

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
	
	-- vedere cosa stava facendo la sessione bloccata e la bloccante
	select *
	from dba_hist_active_sess_history
	where sql_exec_id = &sql_exc_id
	

-- ===========================================================================================
4. Verifica su EM13 per capire se nell''arco almeno dell''ultima settimana non si siano verificati eventi non standard ( lock, aumenti delleconnessioni al database, contention ) 


-- ===========================================================================================
5. Check che non ci sia un motivo perche i cursori dei sql id non siano shared

	select 
	  sql_id,count(*)
	from v$sql_shared_cursor
	group by sql_id
	having count(*) > 100
	order by 2 desc

	nel caso compaia una riga, indagare sul perche'' il sql non sia shared in funzione del rate di esecuzione ( prenderlo incosiderazione se e stato eseguito piu di 100 volte in totale)

-- ===========================================================================================
6.  Eseguire un check che gli indici siano utilizzati nei piani di esecuzione 

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

	-- valutare insieme agli applicativi l'opportunita' di mettere in invisible gli indici che non risukltano utilizzati per poi dropparli
	
	
-- ===========================================================================================
7.  Eseguire un check che non ci siano query con alti tempi di esecuzione ( esempio 300 millisec )

	SELECT ROUND(disk_reads/executions) "DSK/EX", ROUND(buffer_gets/executions) "BFF/EX",
		   ROUND(rows_processed/executions) "RWS/EX", ROUND((cpu_time/1000000)/executions,3) "CPU/EX",
		   ROUND((elapsed_time/1000000)/executions,3) "ELA/EX", executions "EXEC", 
		   first_load_time, last_load_time, parsing_schema_name, sql_id, plan_hash_value, sql_text
	FROM gv$sqlarea s
	WHERE executions > 100
	and parsing_schema_name like '%' --not in ('SYS','SYSMAN','DBSNMP','NAGIOS')
	-- and s.sql_id in (select sp.sql_id from v$sql_plan sp where sp.object_name='TABELLA')
	-- and upper(sql_text) like '%TABELLA%'
	and ROUND((elapsed_time/1000)/executions,3) > 300
	ORDER BY elapsed_time/executions DESC;


-- ===========================================================================================
8.  Eseguire un check che non ci siano query parallel che durano meno di un minuto

	SELECT ROUND(disk_reads/executions) "DSK/EX", ROUND(buffer_gets/executions) "BFF/EX",
		   ROUND(rows_processed/executions) "RWS/EX", ROUND((cpu_time/1000000)/executions,3) "CPU/EX",
		   ROUND((elapsed_time/1000000)/executions,3) "ELA/EX", executions "EXEC", 
		   first_load_time, last_load_time, parsing_schema_name, sql_id, plan_hash_value, sql_text
	FROM gv$sqlarea s
	WHERE executions > 100
	and parsing_schema_name not in ('SYS','SYSMAN','DBSNMP','NAGIOS')
	-- and s.sql_id in (select sp.sql_id from v$sql_plan sp where sp.object_name='TABELLA')
	-- and upper(sql_text) like '%TABELLA%'
	and ROUND((elapsed_time/1000)/executions,3) < 60000
	and px_servers_executions > 0
	ORDER BY elapsed_time/executions DESC;
	
	
-- ===========================================================================================
9.  Eseguire un check sugli indici con parallel degree > 1. Fare un check sulla dimensizone della tabella, se superiore a 10Gb hanno senso altrimenti mettere gli indici in noparallel

	select *
	from dba_indexes where degree <> 'DEFAULT' 
	and degree > 1

	
-- ===========================================================================================
10. Check che tabelle con dimensione superiore a 100GB siano partizionate


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
11. Check che su ambiente RAC le sequence abbiano la cache abilitata

	select 
	  'ALTER SEQUENCE ' || SEQUENCE_OWNER || '.' || SEQUENCE_NAME || ' CACHE 50;'
	from dba_sequences
	where sequence_owner not like '%SYS%'
	and cache_size = 0 
	and order_flag ='N' 
	/


-- ===========================================================================================
11. Check sulla dimensione degli indici ed eventuale rebuild

    --
    -- Check che gli indici abbiamo una dimenzione inferiore al 50% del size della tabella.
	-- Prendo in considerazione solo le tabelle piu' grandi di 10MB, altrimenti l'initial puo' creare falsi positivi
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
	   and TBL_SIZE_MB > 10 -- prendo solo le tabelle piu grosse di 10 mb per evitare falsi positivi
	 order by 3 desc,1,2
	 /
	 

-- ===========================================================================================
12. Check per capire se ci sono query che hanno piani pessimi rispetto ad altri


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


