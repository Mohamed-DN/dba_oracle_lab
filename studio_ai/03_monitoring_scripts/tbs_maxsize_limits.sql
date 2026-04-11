-- MAXSIZE vs ACTUAL SIZE (Non-CDB/CDB Tablespaces)
-- Evidenzia lo spazio allocato massimo teorico rispetto allo spazio realmente in uso

set lines 1000
set pages 1000
set pause off
set echo off
set feedb on
column "MAXSIZE (GB)"      format 9,999,990.00
column "TOTAL PHYS ALLOC (GB)" format 9,999,990.00
column "USED (GB)"             format 9,999,990.00
column "FREE (GB)"             format 9,999,990.00
column "% USED"                format 990.00
col tablespace_name for a35

select
   a.tablespace_name,
   a.bytes_alloc/(1024*1024*1024) "MAXSIZE (GB)",
   a.physical_bytes/(1024*1024*1024) "TOTAL PHYS ALLOC (GB)",
   nvl(b.tot_used,0)/(1024*1024*1024) "USED (GB)",
   (nvl(b.tot_used,0)/a.bytes_alloc)*100 "% USED"
from
   (select
      tablespace_name,
      sum(bytes) physical_bytes,
      sum(decode(autoextensible,'NO',bytes,'YES',maxbytes)) bytes_alloc
    from
      dba_data_files
    group by
      tablespace_name ) a,
   (select
      tablespace_name,
      sum(bytes) tot_used
    from
      dba_segments
    group by
      tablespace_name ) b
where
   a.tablespace_name = b.tablespace_name (+)
and
   a.tablespace_name not in
   (select distinct tablespace_name from dba_temp_files)
and
  a.tablespace_name not like 'UNDO%'
order by 5; 
