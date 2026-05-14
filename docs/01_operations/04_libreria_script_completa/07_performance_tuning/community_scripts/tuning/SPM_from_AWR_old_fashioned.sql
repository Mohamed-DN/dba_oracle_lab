-- HOW TO LOAD SQL PLANS INTO SPM FROM AWR (Doc ID 789888.1)
-- Utilizzare questa procedura su DB con release inferiori alla 12.2
-- Sostituire opportunamente sql_id, plan_hash_value, snap_id iniziale e finale

exec DBMS_SQLTUNE.CREATE_SQLSET('BAD_QUERY');

-- Nella query seguente indicare SQL_ID, piano e un range di snap_id che includa quella o quelle in cui il SQL_ID sia stato eseguito con il piano da caricare

declare
baseline_ref_cursor DBMS_SQLTUNE.SQLSET_CURSOR;
begin
open baseline_ref_cursor for
select VALUE(p) from table(DBMS_SQLTUNE.SELECT_WORKLOAD_REPOSITORY(89453, 89458,'sql_id='||CHR(39)||'8g7hanrk9vasx'||CHR(39)||' and plan_hash_value=2454473915',NULL,NULL,NULL,NULL,NULL,NULL,'ALL')) p;
DBMS_SQLTUNE.LOAD_SQLSET('BAD_QUERY', baseline_ref_cursor);
end;
/

-- Verifica contenuto SQLSET

SELECT NAME,OWNER,CREATED,STATEMENT_COUNT FROM DBA_SQLSET where name='BAD_QUERY';

NAME                           OWNER                          CREATED             STATEMENT_COUNT
------------------------------ ------------------------------ ------------------- ---------------
BAD_QUERY                     SYS                            30/05/2014 20:10:03               1

-- Caricamento in SPM
-- In Oracle 12c possono essere caricati ulteriori piani in automatico da Oracle.
-- Nel caso si voglia fissare definitivamente il piano utilizzare FIXED => YES

set serveroutput on
declare
my_integer pls_integer;
begin
my_integer := dbms_spm.load_plans_from_sqlset(sqlset_name => 'BAD_QUERY', sqlset_owner => 'SYS', fixed => 'YES', enabled => 'YES');
DBMS_OUTPUT.PUT_line(my_integer);
end;
/

-- Verifica caricamento del SQL_ID in SPM (vale solo per DB <= 12.1)

col sql_id for a20
select DBMS_SQLTUNE_UTIL0.SQLTEXT_TO_SQLID(SQL_TEXT||chr(0)) as SQL_ID,
       SQL_HANDLE, PLAN_NAME, ENABLED, ACCEPTED, FIXED
from DBA_SQL_PLAN_BASELINES b
where DBMS_SQLTUNE_UTIL0.SQLTEXT_TO_SQLID(SQL_TEXT||chr(0)) = '&sql_id'
order by 1;

-- Rimozione SQLSET

exec DBMS_SQLTUNE.DROP_SQLSET('BAD_QUERY');

-- FLUSH DEL PIANO D'ACCESSO CORRENTE
-- Conviene sempre fare il flush dell'attuale piano di esecuzione dalla Shared Pool di tutte le istanze
-- How To Flush an Object Out The Library Cache [SGA] Using The DBMS_SHARED_POOL Package (Doc ID 457309.1)

select distinct 'exec dbms_shared_pool.purge ('''||address||','||hash_value||''',''C'');' from gv$sql where sql_id = '2wtx9ppg797s9';

   INST_ID ADDRESS          HASH_VALUE PLAN_HASH_VALUE
---------- ---------------- ---------- ---------------
         1 000000040EFD8FB0 1584701193      1845714512
         2 000000021C565870 1584701193      1845714512

-- su istanza 1:
exec dbms_shared_pool.purge ('000000040EFD8FB0,1584701193 ','C'); 
-- su istanza 2:
exec dbms_shared_pool.purge ('000000021C565870,1584701193 ','C'); 

-- Dopo il flush la query è stata ricaricata e viene ora eseguita utilizzando SPM

select inst_id, plan_hash_value, sql_plan_baseline, executions from gv$sql where sql_id = '8g7hanrk9vasx';

   INST_ID PLAN_HASH_VALUE SQL_PLAN_BASELINE              EXECUTIONS
---------- --------------- ------------------------------ ----------
         1      2454473915 SQL_PLAN_549f521qj235b2a7bdeea          1
         2      2454473915 SQL_PLAN_549f521qj235b2a7bdeea          2

