-- Source: https://www.scriptdba.com/query-dinamica-per-la-creazione-del-comando-di-rebuild-degli-indici/
-- Title: Query dinamica per creazione comando REBUILD INDEX

SET LINES 170
select 'alter index '||i.OWNER||'.'||i.INDEX_NAME||' REBUILD;'
from dba_indexes i, dba_segments s
where i.OWNER not in ('SYS','SYSTEM') 
and i.OWNER = s.OWNER
and i.INDEX_NAME = s.SEGMENT_NAME
and i.STATUS <>'VALID';

SET LINES 170
select 'alter index '||i.OWNER||'.'||i.INDEX_NAME||' REBUILD;'
from dba_indexes i, dba_segments s
where i.OWNER not in ('SYS','SYSTEM') 
and i.OWNER = s.OWNER
and i.INDEX_NAME = s.SEGMENT_NAME
and i.STATUS <>'VALID';

SET LINES 170
select 'alter index '||i.index_OWNER||'.'||i.INDEX_NAME||' REBUILD PARTITION ' ||s.PARTITION_NAME|| ';'
from dba_ind_partitions i, dba_segments s
where i.INDEX_OWNER not in ('SYS','SYSTEM') 
and i.INDEX_OWNER = s.OWNER
and i.INDEX_NAME = s.SEGMENT_NAME
and i.partition_name = s.partition_name and i.STATUS <> 'VALID';

SET LINES 170
select 'alter index '||i.index_OWNER||'.'||i.INDEX_NAME||' REBUILD PARTITION ' ||s.PARTITION_NAME|| ';'
from dba_ind_partitions i, dba_segments s
where i.INDEX_OWNER not in ('SYS','SYSTEM') 
and i.INDEX_OWNER = s.OWNER
and i.INDEX_NAME = s.SEGMENT_NAME
and i.partition_name = s.partition_name and i.STATUS <> 'VALID';

