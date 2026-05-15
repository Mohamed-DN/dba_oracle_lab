-- Source: https://www.scriptdba.com/query-per-recuperare-spazio-disco-allocato-dal-datafile-ma-non-utilizzato/
-- Title: Query per recuperare spazio disco allocato dai DATAFILE ma non utilizzato

set pages 999
set lines 300
select 'alter database datafile ''' || file_name || ''' resize ' || ceil( (nvl(hwm,1)*(select DISTINCT BLOCK_SIZE from dba_tablespaces))/1024/1024 ) || 'm;' cmd
from dba_data_files a, ( select file_id, max(block_id+blocks-1) hwm from dba_extents group by file_id) b
where a.file_id = b.file_id(+)
and a.file_name like '%/&file_system%'
and ceil(blocks*(select DISTINCT BLOCK_SIZE from dba_tablespaces)/1024/1024)- ceil((nvl(hwm,1)*(select DISTINCT BLOCK_SIZE from dba_tablespaces))/1024/1024 ) > 0;

set pages 999
set lines 300
select 'alter database datafile ''' || file_name || ''' resize ' || ceil( (nvl(hwm,1)*(select DISTINCT BLOCK_SIZE from dba_tablespaces))/1024/1024 ) || 'm;' cmd
from dba_data_files a, ( select file_id, max(block_id+blocks-1) hwm from dba_extents group by file_id) b
where a.file_id = b.file_id(+)
and a.file_name like '%/&file_system%'
and ceil(blocks*(select DISTINCT BLOCK_SIZE from dba_tablespaces)/1024/1024)- ceil((nvl(hwm,1)*(select DISTINCT BLOCK_SIZE from dba_tablespaces))/1024/1024 ) > 0;

set pages 999
set lines 300
select 'alter database datafile ''' || file_name || ''' resize ' || ceil( (nvl(hwm,1)*(select DISTINCT BLOCK_SIZE from dba_tablespaces))/1024/1024 ) || 'm;' cmd
from dba_data_files a, ( select file_id, max(block_id+blocks-1) hwm from dba_extents group by file_id) b
where a.file_id = b.file_id(+)
and a.tablespace_name ='&tbsp'
and ceil(blocks*(select DISTINCT BLOCK_SIZE from dba_tablespaces)/1024/1024)- ceil((nvl(hwm,1)*(select DISTINCT BLOCK_SIZE from dba_tablespaces))/1024/1024 ) > 0;

set pages 999
set lines 300
select 'alter database datafile ''' || file_name || ''' resize ' || ceil( (nvl(hwm,1)*(select DISTINCT BLOCK_SIZE from dba_tablespaces))/1024/1024 ) || 'm;' cmd
from dba_data_files a, ( select file_id, max(block_id+blocks-1) hwm from dba_extents group by file_id) b
where a.file_id = b.file_id(+)
and a.tablespace_name ='&tbsp'
and ceil(blocks*(select DISTINCT BLOCK_SIZE from dba_tablespaces)/1024/1024)- ceil((nvl(hwm,1)*(select DISTINCT BLOCK_SIZE from dba_tablespaces))/1024/1024 ) > 0;

