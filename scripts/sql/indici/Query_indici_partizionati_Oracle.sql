-- Source: https://www.scriptdba.com/query-per-verificare-la-dimensione-degli-indici-partizionati/
-- Title: Query indici partizionati Oracle

set lines 200
set pages 99
col INDEX_OWNER for a16
col INDEX_NAME for a24
col INDEX_TYPE for a10
col TABLESPACE_NAME for a24
col PARTITION_NAME for a24
select i.INDEX_OWNER, i.INDEX_NAME, s.SEGMENT_TYPE, s.PARTITION_NAME, s.TABLESPACE_NAME, s.BYTES/1024/1024 as "Size MB", i.STATUS
from dba_ind_partitions i, dba_segments s
where i.INDEX_OWNER not in ('SYS','SYSTEM') 
and i.INDEX_OWNER = s.OWNER
and i.INDEX_NAME = s.SEGMENT_NAME
and i.partition_name = s.partition_name
order by 1,2,4
/

set lines 200
set pages 99
col INDEX_OWNER for a16
col INDEX_NAME for a24
col INDEX_TYPE for a10
col TABLESPACE_NAME for a24
col PARTITION_NAME for a24
select i.INDEX_OWNER, i.INDEX_NAME, s.SEGMENT_TYPE, s.PARTITION_NAME, s.TABLESPACE_NAME, s.BYTES/1024/1024 as "Size MB", i.STATUS
from dba_ind_partitions i, dba_segments s
where i.INDEX_OWNER not in ('SYS','SYSTEM') 
and i.INDEX_OWNER = s.OWNER
and i.INDEX_NAME = s.SEGMENT_NAME
and i.partition_name = s.partition_name
order by 1,2,4
/

