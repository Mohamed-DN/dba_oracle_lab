-- To set a plan in SPM you must first check whether the correct plan is still present in the GV$SQL, or if for example it is present on the other instance, because the change in plan occurs only on one instance

select inst_id, address, hash_value, plan_hash_value from gv$sql where sql_id = '2wtx9ppg797s9';

-- LOADING FROM CURSOR CACHE
-- To be performed on the instance where the plan is still present

set serveroutput on
DECLARE
  my_plans PLS_INTEGER;
BEGIN
  my_plans := DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(sql_id => '2wtx9ppg797s9', plan_hash_value => 773418811, FIXED=>'YES', ENABLED=>'YES');
  DBMS_OUTPUT.put_line('Plans Loaded: ' || my_plans);
END;
/

-- LOADING FROM AWR
-- How to Create A SQL Plan Baseline From A Historical Execution Plan In The Automatic Workload Repository (AWR) [RDBMS Version 12.2 or Higher] (Doc ID 2885167.1)	
-- Valid only from 12.2 onwards, in case of releases lower than 12.2 use the file SPM_from_AWR_old_fashioned.sql

set serveroutput on
variable x number
begin
:x := dbms_spm.load_plans_from_awr( begin_snap=>47101,end_snap=>47103, basic_filter=>q'# sql_id='2wtx9ppg797s9' and plan_hash_value='766828282' #', FIXED=>'YES');
end;
/

print x


-- if pluggable, if possible carry out the procedure within the pluggable itself

select dbid, snap_id, to_char(end_interval_time, 'yyyy/mm/dd hh24:mi') getsnapshot_time, snap_level from DBA_HIST_SNAPSHOT order by dbid, snap_id;

set serveroutput on
variable x number
begin
:x := dbms_spm.load_plans_from_awr( begin_snap=>47101,end_snap=>47103,dbid=>4195056257, basic_filter=>q'# sql_id='2wtx9ppg797s9' and plan_hash_value='766828282' #', FIXED=>'YES');
end;
/

print x

-- LOADING FROM SQLSET
-- Use this procedure if you are transferring SQLSET from one database to another
-- It is possible to extract even just some SQL_IDs from an STS by valuing basic_filter => 'sql_text like ''select /*LOAD_STS*/%''' or basic_filter => 'sql_id=''b62q7nc33gzwx'''.

set serveroutput on
DECLARE
  my_plans PLS_INTEGER;
BEGIN
  my_plans := DBMS_SPM.LOAD_PLANS_FROM_SQLSET(sqlset_name => 'tset1', sqlset_owner=>'SYS', FIXED=>'YES', ENABLED=>'YES');
  DBMS_OUTPUT.put_line('Plans Loaded: ' || my_plans);
END;
/

-- DROP SQL

set serveroutput on
DECLARE
  my_plans PLS_INTEGER;
BEGIN
  my_plans := DBMS_SPM.DROP_SQL_PLAN_BASELINE (sql_handle => 'SQL_35808c4ffadda39e');
  DBMS_OUTPUT.put_line('Plans Removed: ' || my_plans);
END;
/

-- DROP SQL+PLAN specifico

set serveroutput on
DECLARE
   my_plans pls_integer;
BEGIN
   my_plans := DBMS_SPM.DROP_SQL_PLAN_BASELINE ('&original_sql_handle','&original_plan_name');
END;
/

-- FLUSH
-- You can force flush a SQL_ID from the cache, in case it fails to immediately change the plan in use, when there are still many sessions running of the wrong plan
-- The purge should be performed on each instance, using the output of the following query

select inst_id, address, hash_value, plan_hash_value from gv$sqlarea where sql_id = '2wtx9ppg797s9';

select distinct 'exec dbms_shared_pool.purge ('''||address||','||hash_value||''',''C'');' from gv$sql where sql_id = '2wtx9ppg797s9';


exec dbms_shared_pool.purge ('000000040EFD8FB0,1584701193 ','C'); 

-- CHECK SPM USAGE

select inst_id, plan_hash_value, sql_plan_baseline, executions from gv$sql where sql_id = '2wtx9ppg797s9';

-- USEFUL QUERIES

col SQL_HANDLE for a55
col PLAN_NAME for a55
SELECT SQL_HANDLE, PLAN_NAME, ENABLED, ACCEPTED, FIXED, CREATED FROM DBA_SQL_PLAN_BASELINES ORDER BY 1;

col sql_id for a20
select DBMS_SQLTUNE_UTIL0.SQLTEXT_TO_SQLID(SQL_TEXT||chr(0)) as SQL_ID,
       SQL_HANDLE, PLAN_NAME, ENABLED, ACCEPTED, FIXED, CREATED
from DBA_SQL_PLAN_BASELINES b
where DBMS_SQLTUNE_UTIL0.SQLTEXT_TO_SQLID(SQL_TEXT||chr(0)) = '&sql_id'
order by 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_SQL_PLAN_BASELINE(sql_handle=>'SYS_SQL_209d10fabbedc741', format=>'basic'));

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_SQL_PLAN_BASELINE('SQL_dc9f0eb58f7f58b1','SQL_PLAN_dt7sfqq7ryq5j44641156','ALL'));

select s.sql_id, b.sql_handle, b.plan_name, b.origin, b.accepted, s.sql_text
from dba_sql_plan_baselines b, gv$sql s
where s.exact_matching_signature = b.signature
and s.SQL_PLAN_BASELINE = b.plan_name
order by 1;

-- ASSOCIAZIONE SQL_ID - SQL_PLAN

set lines 150
col sql_id for a15
col signature for 999999999999999999999
col PLAN_NAME for a50
WITH
FUNCTION compute_sql_id (sql_text IN CLOB)
RETURN VARCHAR2 IS
 BASE_32 CONSTANT VARCHAR2(32) := '0123456789abcdfghjkmnpqrstuvwxyz';
 l_raw_128 RAW(128);
 l_hex_32 VARCHAR2(32);
 l_low_16 VARCHAR(16);
 l_q3 VARCHAR2(8);
 l_q4 VARCHAR2(8);
 l_low_16_m VARCHAR(16);
 l_number NUMBER;
 l_idx INTEGER;
 l_sql_id VARCHAR2(13);
BEGIN
 l_raw_128 := /* use md5 algorithm on sql_text and produce 128 bit hash */
 SYS.DBMS_CRYPTO.hash(TRIM(CHR(0) FROM sql_text)||CHR(0), SYS.DBMS_CRYPTO.hash_md5);
 l_hex_32 := RAWTOHEX(l_raw_128); /* 32 hex characters */
 l_low_16 := SUBSTR(l_hex_32, 17, 16); /* we only need lower 16 */
 l_q3 := SUBSTR(l_low_16, 1, 8); /* 3rd quarter (8 hex characters) */
 l_q4 := SUBSTR(l_low_16, 9, 8); /* 4th quarter (8 hex characters) */
 /* need to reverse order of each of the 4 pairs of hex characters */
 l_q3 := SUBSTR(l_q3, 7, 2)||SUBSTR(l_q3, 5, 2)||SUBSTR(l_q3, 3, 2)||SUBSTR(l_q3, 1, 2);
 l_q4 := SUBSTR(l_q4, 7, 2)||SUBSTR(l_q4, 5, 2)||SUBSTR(l_q4, 3, 2)||SUBSTR(l_q4, 1, 2);
 /* assembly back lower 16 after reversing order on each quarter */
 l_low_16_m := l_q3||l_q4;
 /* convert to number */
 SELECT TO_NUMBER(l_low_16_m, 'xxxxxxxxxxxxxxxx') INTO l_number FROM DUAL;
 /* 13 pieces base-32 (5 bits each) make 65 bits. we do have 64 bits */
 FOR i IN 1 .. 13
 LOOP
 l_idx := TRUNC(l_number / POWER(32, (13 - i))); /* index on BASE_32 */
 l_sql_id := l_sql_id||SUBSTR(BASE_32, (l_idx + 1), 1); /* stitch 13 characters */
 l_number := l_number - (l_idx * POWER(32, (13 - i))); /* for next piece */
 END LOOP;
 RETURN l_sql_id;
END compute_sql_id;
SELECT compute_sql_id(sql_text) sql_id, signature, PLAN_NAME
  FROM dba_sql_plan_baselines
/


-- USEFUL NOTES

Plan Stability Features (Including SPM) Start Point [ID 1359841.1]
HOW TO MOVE 10gR2 EXECUTION PLANS AND LOAD INTO 11g SPM [ID 801033.1]
SQL Plans from Oracle 10.2 SQL Tuning Set (STS) are Not Uploaded into SQL Plan Management (SPM) in Oracle 11.2 [ID 1496553.1]
HOW TO LOAD SQL PLANS INTO SPM FROM AWR [ID 789888.1]
Transporting SQL PLAN Baselines from one database to another. [ID 880485.1]

How to Enable SQL Plan Management Tracing [ID 789520.1]
How to Use SQL Plan Management (SPM) - Example Usage [ID 456518.1]
Loading Hinted Execution Plans into SQL Plan Baseline. [ID 787692.1]
How to Drop Plans from the SQL Plan Management (SPM) Repository [ID 790039.1]
Baseline Plan Not Used by Non DBA User Due to View Merging Restrictions when "OPTIMIZER_SECURE_VIEW_MERGING" is True [ID 1485903.1]
