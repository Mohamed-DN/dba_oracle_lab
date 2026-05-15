-- Source: https://www.scriptdba.com/query-per-identificare-gli-oggetti-invalidi/
-- Title: Query oggetti INVALIDI

set lines 130
col owner for a20
col object_name for a40
col object_type for a25
col status for a20
select owner, object_type, object_name , status
from dba_objects 
where status != 'VALID'
order by
owner, object_type;

set lines 130
col owner for a20
col object_name for a40
col object_type for a25
col status for a20
select owner, object_type, object_name , status
from dba_objects 
where status != 'VALID'
order by
owner, object_type;

