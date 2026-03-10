

set echo off
set timing off
set pagesize 0
set line 2000
set heading off 
set verify off


SELECT TEXT
FROM ( 
SELECT 
  STEP,
  TEXT
FROM (
select 1 as step,chr(10)as TEXT FROM DUAL
  union
select 2 as step,'declare'as TEXT FROM DUAL
  union
select 3 as step,'  ar_profile_hints sys.sqlprof_attr;'as TEXT FROM DUAL
union
  select 4 as step,'begin'as TEXT FROM DUAL
union
  select 5 as step,chr(9)||'  ar_profile_hints := sys.sqlprof_attr('as TEXT FROM DUAL
union
  select 6 as step,chr(9)||chr(9)||'''BEGIN_OUTLINE_DATA'','as TEXT FROM DUAL
UNION
SELECT 7 as step,chr(9)||chr(9)||''''||regexp_replace(extractvalue(value(d), '/hint'),'''','''''')||''','
 from
 xmltable('/*/outline_data/hint'
 passing (
 select
 xmltype(other_xml) as xmlval
 from
  dba_hist_sql_plan
 where
 sql_id = '&hinted_sql_id'
 and plan_hash_value = &hinted_plan_hash
 and other_xml is not null
 )
 ) d
union
  select 8 as step,chr(9)||chr(9)||'''END_OUTLINE_DATA'''as TEXT FROM DUAL
union 
  SELECT 9 as step, ');'as TEXT FROM DUAL 
union
  SELECT 10 as step,'for sql_rec in ('as TEXT FROM DUAL
UNION
  SELECT 11 as step,chr(9)||'select t.sql_id, t.sql_text,p.plan_hash_value'as TEXT FROM DUAL
UNION
  SELECT 12 as step,chr(9)||' from dba_hist_sqltext t, dba_hist_sql_plan p'as TEXT FROM DUAL
UNION
  SELECT 13 as step,chr(9)|| 'where t.sql_id = p.sql_id and p.sql_id = ''&&orig_sql_id'' and p.plan_hash_value = &&orig_plan_hash and p.parent_id is null and rownum < 2'as TEXT FROM DUAL
UNION
  SELECT 16 as step,chr(9)||chr(9)||') loop'as TEXT FROM DUAL
UNION
  SELECT 17 as step,chr(9)||' DBMS_SQLTUNE.IMPORT_SQL_PROFILE('as TEXT FROM DUAL
UNION
  SELECT 18 as step,chr(9)||chr(9)||'sql_text => sql_rec.sql_text,force_match =>TRUE, profile => ar_profile_hints,name => ''PROF_''||sql_rec.sql_id||''_''||sql_rec.plan_hash_value'as TEXT FROM DUAL
UNION
  SELECT 19 as step,chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||');'as TEXT FROM DUAL
UNION
  SELECT 20 as step,chr(9)||'end loop;'as TEXT FROM DUAL 
UNION
  SELECT 21 as step,'end;'as TEXT FROM DUAL
UNION
  SELECT 22 as step,'/'as TEXT FROM DUAL
)
order by 1 asc
)


