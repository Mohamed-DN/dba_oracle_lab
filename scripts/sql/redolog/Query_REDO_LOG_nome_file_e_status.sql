-- Source: https://www.scriptdba.com/query-per-vedere-nomi-dimensioni-e-status-dei-redolog/
-- Title: Query REDO LOG nome file e status

set lines 200
set pages 99
col member format a60 
col status for a20
col "Size MB" format 9,999,999 
select lf.group#, lf.member ,lg.status, ceil(lg.bytes / 1024 / 1024) "Size MB" 
from v$logfile lf , v$log lg 
where lg.group# = lf.group# order by 1;

set lines 200
set pages 99
col member format a60 
col status for a20
col "Size MB" format 9,999,999 
select lf.group#, lf.member ,lg.status, ceil(lg.bytes / 1024 / 1024) "Size MB" 
from v$logfile lf , v$log lg 
where lg.group# = lf.group# order by 1;

