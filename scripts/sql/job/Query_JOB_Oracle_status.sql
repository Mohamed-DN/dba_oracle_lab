-- Source: https://www.scriptdba.com/query-per-controllare-lo-stato-del-job/
-- Title: Query JOB Oracle status

set lines 200 pages 999
col log_user format a15
col priv_user format a15
col schema_user format a15
col last_run format a15
col next_run format a15
col what format a60
col fails format 999
select job
, log_user
, priv_user
, schema_user
, to_char(last_date, 'hh24:mi dd/mm/yy') last_run
, to_char(next_date, 'hh24:mi dd/mm/yy') next_run
, failures fails
, broken
, substr(what, 1, 60) what
from dba_jobs
where job=&job
order by 4;

set lines 200 pages 999
col log_user format a15
col priv_user format a15
col schema_user format a15
col last_run format a15
col next_run format a15
col what format a60
col fails format 999
select job
, log_user
, priv_user
, schema_user
, to_char(last_date, 'hh24:mi dd/mm/yy') last_run
, to_char(next_date, 'hh24:mi dd/mm/yy') next_run
, failures fails
, broken
, substr(what, 1, 60) what
from dba_jobs
where job=&job
order by 4;

