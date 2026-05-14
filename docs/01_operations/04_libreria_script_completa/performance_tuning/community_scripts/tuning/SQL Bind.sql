-- Matching Signatures

col FORCE_MATCHING_SIGNATURE for 99999999999999999999
col esempio_sql_id1 for a20
col esempio_sql_id2 for a20
col parsing_schema_name for a30
SELECT 
  parsing_schema_name,
  FORCE_MATCHING_SIGNATURE,
  sum(EXECUTIONS) EXECUTIONS,
  count(distinct sql_id) sql_ids, 
  min(sql_id) esempio_sql_id1,
  max(sql_id) esempio_sql_id2
FROM gv$sqlarea s
WHERE executions > 0
and parsing_schema_name not in ('SYS','SYSMAN','DBSNMP','NAGIOS','SPLEX')
-- and FORCE_MATCHING_SIGNATURE = 11486882606509057499
group by parsing_schema_name, FORCE_MATCHING_SIGNATURE
order by sql_ids;

set long 999999999
select sql_fulltext from gv$sqlarea where sql_id='&SQL_ID';

-- BIND VARIABLES IN CACHE

col NAME for a20
col VALUE_STRING for a20
select ADDRESS, HASH_VALUE, CHILD_ADDRESS, CHILD_NUMBER, NAME, POSITION, DATATYPE_STRING, LAST_CAPTURED, VALUE_STRING from V$SQL_BIND_CAPTURE where sql_id='&SQL_ID' order by CHILD_NUMBER, POSITION;

select * from table(dbms_xplan.display_cursor('3b9t118mrx5yf','&child_no','typical +peeked_binds'));

-- BIND VARIABLES DA AWR

col begin_interval_time for a30
col name for a15
col position for 999
col value_string for a77
set pages 50000

select snap_id, begin_interval_time, plan_hash_value, name, position, value_string from 
(select sql_id,bind_data,sq.snap_id, begin_interval_time, plan_hash_value from dba_hist_sqlstat sq, dba_hist_snapshot sn
 where sq.snap_id=sn.snap_id and bind_data is not null and sql_id='&SQL_ID') x,
 table(dbms_sqltune.extract_binds(x.bind_data)) xx
order by 1,2,3,5;

OLD:

select sql_id,name, position, value_string,snap_id from 
(select sql_id,bind_data,snap_id from dba_hist_sqlstat 
 where bind_data is not null and sql_id='6129566gyvx21') x,
 table(dbms_sqltune.extract_binds(x.bind_data)) xx;
 
-- SQL simili (con lo stesso piano d'accesso)

select plan_hash_value, count(1)
from gv$sqlarea
group by plan_hash_value
having count(1)>100
order by 2;

select parsing_schema_name, executions, sql_text from gv$sqlarea where plan_hash_value=&plan_hash_value;

select sql_text from v$sqltext_with_newlines where sql_id='&SQL_ID' order by piece;

-- Oracle 11g

SELECT CHILD_NUMBER, EXECUTIONS, BUFFER_GETS, IS_BIND_SENSITIVE AS "BIND_SENSI", 
       IS_BIND_AWARE AS "BIND_AWARE", IS_SHAREABLE AS "BIND_SHARE"
FROM   V$SQL
WHERE  SQL_TEXT LIKE 'select /*ACS_1%';

-- OLD

select substr(SQL_text,1,50) SQL, count(*) from v$sql
group by substr(SQL_text,1,50) 
having count(*) > 5
order by count(*) desc;

select substr(SQL_text,1,50) SQL, count(*) from v$open_cursor
group by substr(SQL_text,1,50) 
having count(*) > 5
order by count(*) desc;

SELECT substr(sql_text,1,40) SQL, count(*), sum(executions) "TotExecs"
FROM v$sqlarea
WHERE executions < 5
GROUP BY substr(sql_text,1,40)
HAVING count(*) > 30 ORDER BY 2;
