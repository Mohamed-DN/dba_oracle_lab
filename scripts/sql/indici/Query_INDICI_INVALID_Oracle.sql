-- Source: https://www.scriptdba.com/query-per-individuare-tutti-gli-indici-invalidati-degli-utenti-del-database/
-- Title: Query INDICI INVALID Oracle

set lines 180
col owner for a30
col index_name for a30
col index_type for a30
col status for a15
select owner, index_name,index_type,status
from dba_indexes
where owner not in ('SYSTEM','SYS')
and status <> 'VALID'
order by 1,2;

set lines 180
col owner for a30
col index_name for a30
col index_type for a30
col status for a15
select owner, index_name,index_type,status
from dba_indexes
where owner not in ('SYSTEM','SYS')
and status <> 'VALID'
order by 1,2;

