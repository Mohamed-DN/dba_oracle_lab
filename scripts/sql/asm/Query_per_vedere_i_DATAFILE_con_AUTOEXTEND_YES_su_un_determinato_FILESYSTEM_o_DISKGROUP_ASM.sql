-- Source: https://www.scriptdba.com/query-per-vedere-i-datafile-con-autoextend-yes-su-un-determinato-filesystem-o-diskgroup-asm/
-- Title: Query per vedere i DATAFILE con AUTOEXTEND YES su un determinato FILESYSTEM o DISKGROUP ASM

col file_name for a69
col tablespace_name for a20
set lines 300
set pages 999
select a.tablespace_name, a.file_name, a.bytes/1024/1024 MB_ATT,
a.MAXBYTES/1024/1024 MB_MAX,substr(a.AUTOEXTENSIBLE,1,1) AUTOEXT, b.status
from dba_data_files a, dba_tablespaces b
where a.file_name like '%&1%'
and a.tablespace_name = b.tablespace_name
and a.AUTOEXTENSIBLE='YES' 
order by MB_ATT;

col file_name for a69
col tablespace_name for a20
set lines 300
set pages 999
select a.tablespace_name, a.file_name, a.bytes/1024/1024 MB_ATT,
a.MAXBYTES/1024/1024 MB_MAX,substr(a.AUTOEXTENSIBLE,1,1) AUTOEXT, b.status
from dba_data_files a, dba_tablespaces b
where a.file_name like '%&1%'
and a.tablespace_name = b.tablespace_name
and a.AUTOEXTENSIBLE='YES' 
order by MB_ATT;

