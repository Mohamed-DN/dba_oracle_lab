-- Source: https://www.scriptdba.com/query-per-vedere-i-tempfile-e-le-dimensioni-del-tablespace-temp/
-- Title: Query per vedere i TEMPFILE e le dimensioni del TABLESPACE TEMP

col file_name for a69 
col tablespace_name for a20 
set lines 200 
set pages 999 
select a.tablespace_name, 
--a.file_id, 
a.file_name, 
a.bytes/(1024*1024) MB_ATT, 
a.MAXBYTES/(1024*1024) MB_MAX,substr(a.AUTOEXTENSIBLE,1,1) AUTOEXT, b.status
from dba_temp_files a, dba_tablespaces b
where a.tablespace_name = b.tablespace_name
order by a.file_name;

col file_name for a69 
col tablespace_name for a20 
set lines 200 
set pages 999 
select a.tablespace_name, 
--a.file_id, 
a.file_name, 
a.bytes/(1024*1024) MB_ATT, 
a.MAXBYTES/(1024*1024) MB_MAX,substr(a.AUTOEXTENSIBLE,1,1) AUTOEXT, b.status
from dba_temp_files a, dba_tablespaces b
where a.tablespace_name = b.tablespace_name
order by a.file_name;

