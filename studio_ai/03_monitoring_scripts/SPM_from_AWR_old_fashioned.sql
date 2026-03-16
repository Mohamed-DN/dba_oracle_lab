-- HOW TO LOAD SQL PLANS INTO SPM FROM AWR (Doc ID 789888.1)
-- Use this procedure on DBs with releases lower than 12.2
--Replace the leading and trailing sql_id, plan_hash_value, snap_id appropriately

exec DBMS_SQLTUNE.CREATE_SQLSET('BAD_QUERY');

-- In the following query indicate SQL_ID, plan and a snap_id range that includes the one or those in which the SQL_ID was executed with the plan to load

declare
baseline_ref_cursor DBMS_SQLTUNE.SQLSET_CURSOR;
begin
open baseline_ref_cursor for
select VALUE(p) from table(DBMS_SQLTUNE.SELECT_WORKLOAD_REPOSITORY(89453, 89458,'sql_id='||CHR(39)||'8g7hanrk9vasx'||CHR(39)||' and plan_hash_value=2454473915',NULL,NULL,NULL,NULL,NULL,NULL,'ALL')) p;
DBMS_SQLTUNE.LOAD_SQLSET('BAD_QUERY', baseline_ref_cursor);
end;
/

-- Check SQLSET contents

SELECT NAME,OWNER,CREATED,STATEMENT_COUNT FROM DBA_SQLSET where name='BAD_QUERY';

NAME                           OWNER                          CREATED             STATEMENT_COUNT
------------------------------ ------------------------------ ------------------- ---------------
BAD_QUERY                     SYS                            30/05/2014 20:10:03               1

--Loading into SPM
--In Oracle 12c additional plans can be loaded automatically from Oracle.
-- If you want to definitively fix the plan, use FIXED => YES

set serveroutput on
declare
my_integer pls_integer;
begin
my_integer := dbms_spm.load_plans_from_sqlset(sqlset_name => 'BAD_QUERY', sqlset_owner => 'SYS', fixed => 'YES', enabled => 'YES');
DBMS_OUTPUT.PUT_line(my_integer);
end;
/

-- Check loading of SQL_ID in SPM (valid only for DB <= 12.1)

col sql_id for a20
select DBMS_SQLTUNE_UTIL0.SQLTEXT_TO_SQLID(SQL_TEXT||chr(0)) as SQL_ID,
       SQL_HANDLE, PLAN_NAME, ENABLED, ACCEPTED, FIXED
from DBA_SQL_PLAN_BASELINES b
where DBMS_SQLTUNE_UTIL0.SQLTEXT_TO_SQLID(SQL_TEXT||chr(0)) = '&sql_id'
order by 1;

--Removing SQLSET

exec DBMS_SQLTUNE.DROP_SQLSET('BAD_QUERY');

-- FLUSH OF THE CURRENT ACCESS PLAN
-- It is always best to flush the current execution plan from the Shared Pool of all instances
-- How To Flush an Object Out The Library Cache [SGA] Using The DBMS_SHARED_POOL Package (Doc ID 457309.1)

select distinct 'exec dbms_shared_pool.purge ('''||address||','||hash_value||''',''C'');' from gv$sql where sql_id = '2wtx9ppg797s9';

   INST_ID ADDRESS          HASH_VALUE PLAN_HASH_VALUE
---------- ---------------- ---------- ---------------
         1 000000040EFD8FB0 1584701193      1845714512
         2 000000021C565870 1584701193      1845714512

-- on instance 1:
exec dbms_shared_pool.purge ('000000040EFD8FB0,1584701193 ','C'); 
-- on instance 2:
exec dbms_shared_pool.purge ('000000021C565870,1584701193 ','C'); 

-- After the flush the query was reloaded and is now executed using SPM

select inst_id, plan_hash_value, sql_plan_baseline, executions from gv$sql where sql_id = '8g7hanrk9vasx';

   INST_ID PLAN_HASH_VALUE SQL_PLAN_BASELINE              EXECUTIONS
---------- --------------- ------------------------------ ----------
         1      2454473915 SQL_PLAN_549f521qj235b2a7bdeea          1
         2      2454473915 SQL_PLAN_549f521qj235b2a7bdeea          2

