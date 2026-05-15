-- Source: https://www.scriptdba.com/query-per-individuare-tutti-gli-indici-invalidi-che-puntano-a-tabelle-partizionate-degli-utenti-del-database/
-- Title: Query INDICI PARTIZIONATI INVALIDI Oracle

set lines 400
col owner for a10
col index_name for a25
select INDEX_OWNER,index_name,partition_name,status
from dba_ind_partitions
where status <>'VALID'
and index_owner not in ('SYSTEM','SYS')
order by 1,2;

set lines 400
col owner for a10
col index_name for a25
select INDEX_OWNER,index_name,partition_name,status
from dba_ind_partitions
where status <>'VALID'
and index_owner not in ('SYSTEM','SYS')
order by 1,2;

