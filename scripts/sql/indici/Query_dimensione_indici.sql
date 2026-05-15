-- Source: https://www.scriptdba.com/query-per-verificare-la-dimensione-degli-indici/
-- Title: Query dimensione indici

set lines 200
set pages 99
col OWNER for a16
col INDEX_NAME for a30
col INDEX_TYPE for a21
col TABLESPACE_NAME for a24
col PARTITION_NAME for a24
select i.OWNER, i.INDEX_NAME, i.INDEX_TYPE, s.PARTITION_NAME, s.TABLESPACE_NAME, s.BYTES/1024/1024 as "Size MB", i.STATUS 
from dba_indexes i, dba_segments s
where i.OWNER not in ('SYS','SYSTEM') and 
i.OWNER = s.OWNER and
i.INDEX_NAME = s.SEGMENT_NAME 
order by 1,2,4;

set lines 200
set pages 99
col OWNER for a16
col INDEX_NAME for a30
col INDEX_TYPE for a21
col TABLESPACE_NAME for a24
col PARTITION_NAME for a24
select i.OWNER, i.INDEX_NAME, i.INDEX_TYPE, s.PARTITION_NAME, s.TABLESPACE_NAME, s.BYTES/1024/1024 as "Size MB", i.STATUS 
from dba_indexes i, dba_segments s
where i.OWNER not in ('SYS','SYSTEM') and 
i.OWNER = s.OWNER and
i.INDEX_NAME = s.SEGMENT_NAME 
order by 1,2,4;

