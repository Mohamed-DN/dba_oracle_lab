-- Source: https://www.scriptdba.com/query-per-vedere-le-analisi-sui-consumi-di-un-sql_id/
-- Title: Query per vedere se è cambiato il piano d'accesso ai dati - PLAN_HASH_VALUE

set lines 300 
col sql_id for a15
select sql_id, PLAN_HASH_VALUE, EXECUTIONS, BUFFER_GETS, ELAPSED_TIME, CPU_TIME, DISK_READS 
  from v$sqlarea 
 where sql_id='&sql_id';

set lines 300 
col sql_id for a15
select sql_id, PLAN_HASH_VALUE, EXECUTIONS, BUFFER_GETS, ELAPSED_TIME, CPU_TIME, DISK_READS 
  from v$sqlarea 
 where sql_id='&sql_id';

