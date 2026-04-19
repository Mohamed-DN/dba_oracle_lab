-- Generatore di comandi per estendere MAXSIZE sui BIGFILE Tablespaces
-- Ignora i tablespace di sistema e UNDO.

set lines 500 pages 3000
col bigfile for a4
col tablespace_name for a30
col file_name for a95
COL MAXBYTES FOR 9999999999999999
col "ACTUAL_SPACE" for 999999999999999999999999
col "comando" for a80

select comando,BIGFILE,ACTUAL_SPACE,MAXBYTES from (
select 'alter tablespace '||a.TABLESPACE_NAME||' AUTOEXTEND ON maxsize '||nvl(trunc(sum(a.bytes)*170/100),10737418240)||';' comando,
b.BIGFILE,
sum(a.bytes) as ACTUAL_SPACE,
MAXBYTES
from dba_data_files a 
join dba_tablespaces b on a.TABLESPACE_NAME=b.TABLESPACE_NAME 
where a.MAXBYTES = 35184372064256
and a.tablespace_name in
(select TABLESPACE_NAME from dba_tablespaces where BIGFILE='YES' and
TABLESPACE_NAME not in (
     'DBA_OP_DATA',
     'DBA_OP_INDX',
     'SYSAUX',
     'USERS',
     'SYSTEM',
     'UNDOTBS2',
     'UNDOTBS1',
     'UNDO_2',
     'UNDO_1',
     'UNDO1',
     'UNDO2')) 
group by a.FILE_NAME,b.BIGFILE,a.TABLESPACE_NAME,bytes,MAXBYTES
)
order by comando;
