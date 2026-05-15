-- Source: https://www.scriptdba.com/query-per-vedere-i-datafile-con-le-relative-dimensioni-di-una-tablespace/
-- Title: Query per vedere i DATAFILE con le relative dimensioni di una TABLESPACE

col file_name for a80
col tablespace_name for a22 
set lines 200 
set pages 999 
col status for a7
select a.tablespace_name, 
--a.file_id, 
a.file_name, 
a.bytes/(1024*1024) MB_ATT, 
a.MAXBYTES/(1024*1024) MB_MAX,substr(a.AUTOEXTENSIBLE,1,1) AUTOEXT, b.status
from dba_data_files a, dba_tablespaces b
where a.TABLESPACE_NAME LIKE '%&tbsp%'
and a.tablespace_name = b.tablespace_name
--and a.AUTOEXTENSIBLE='YES' 
order by a.file_name;

col file_name for a80
col tablespace_name for a22 
set lines 200 
set pages 999 
col status for a7
select a.tablespace_name, 
--a.file_id, 
a.file_name, 
a.bytes/(1024*1024) MB_ATT, 
a.MAXBYTES/(1024*1024) MB_MAX,substr(a.AUTOEXTENSIBLE,1,1) AUTOEXT, b.status
from dba_data_files a, dba_tablespaces b
where a.TABLESPACE_NAME LIKE '%&tbsp%'
and a.tablespace_name = b.tablespace_name
--and a.AUTOEXTENSIBLE='YES' 
order by a.file_name;

