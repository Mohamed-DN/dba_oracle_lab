-- Source: https://www.scriptdba.com/query-per-vedere-le-dimensioni-di-tutte-le-tablespace-del-database-oracle/
-- Title: Query per vedere le dimensioni di tutte le TABLESPACE del database Oracle

set linesize 200
col tablespace_name for a25
col "Total Auto Mb"  for 999,999,999,999
col "Total Now Mb" for 999,999,999,999
col "Used Mb"   for 999,999,999,999
col "Free Mb"  for 999,999,999,999
col "Pos. Free Mb" for 999,999,999,999
col "Total Auto Mb"
col "% Used" for a10
col "% Possib. Used" for a10
col  dummy noprint
break on dummy
compute sum of "Total Mb" on dummy
compute sum of "Used Mb"  on dummy
compute sum of "Free Mb" on dummy
select null dummy ,
a.tablespace_name ,
a.total_possible as "Total Auto Mb" ,
a.total as "Total Now Mb",
a.total-nvl(b.free,0) as "Used Mb"
,nvl(b.free,0) as "Free Mb",
a.total_possible-(a.total-nvl(b.free,0)) as "Pos. Free Mb",
trunc(((a.total-nvl(b.free,0))/a.total)*100)||'%' as "% Used",
trunc(((a.total-nvl(b.free,0))/a.total_possible)*100)||'%' as "% Possib. Used"
from (select tablespace_name,trunc(sum(bytes)/1024/1024) free
from dba_free_space group by tablespace_name) b,
(select tablespace_name,trunc(sum(greatest(bytes,maxbytes))/1024/1024) total_possible ,
trunc(sum(bytes)/1024/1024) total
from dba_data_files group by tablespace_name) a
where a.tablespace_name = b.tablespace_name (+)
--and b.tablespace_name='USERS'
order by 2
/

set linesize 200
col tablespace_name for a25
col "Total Auto Mb"  for 999,999,999,999
col "Total Now Mb" for 999,999,999,999
col "Used Mb"   for 999,999,999,999
col "Free Mb"  for 999,999,999,999
col "Pos. Free Mb" for 999,999,999,999
col "Total Auto Mb"
col "% Used" for a10
col "% Possib. Used" for a10
col  dummy noprint
break on dummy
compute sum of "Total Mb" on dummy
compute sum of "Used Mb"  on dummy
compute sum of "Free Mb" on dummy
select null dummy ,
a.tablespace_name ,
a.total_possible as "Total Auto Mb" ,
a.total as "Total Now Mb",
a.total-nvl(b.free,0) as "Used Mb"
,nvl(b.free,0) as "Free Mb",
a.total_possible-(a.total-nvl(b.free,0)) as "Pos. Free Mb",
trunc(((a.total-nvl(b.free,0))/a.total)*100)||'%' as "% Used",
trunc(((a.total-nvl(b.free,0))/a.total_possible)*100)||'%' as "% Possib. Used"
from (select tablespace_name,trunc(sum(bytes)/1024/1024) free
from dba_free_space group by tablespace_name) b,
(select tablespace_name,trunc(sum(greatest(bytes,maxbytes))/1024/1024) total_possible ,
trunc(sum(bytes)/1024/1024) total
from dba_data_files group by tablespace_name) a
where a.tablespace_name = b.tablespace_name (+)
--and b.tablespace_name='USERS'
order by 2
/

