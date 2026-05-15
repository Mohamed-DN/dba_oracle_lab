-- Source: https://www.scriptdba.com/query-dinamica-per-la-creazione-del-comando-di-compilazione-oggetti-invalidi/
-- Title: Query compilazione OGGETTI INVALIDI

set echo off
set head off
set feed off
set ver off
set pages 99
spool nome_sql.sql
select decode( OBJECT_TYPE, 'PACKAGE BODY','alter package ' || OWNER||'.'||OBJECT_NAME || ' compile body;', 'SYNONYM', (decode (OWNER, 'PUBLIC', 'alter public synonym '||OBJECT_NAME||' compile;',
'alter ' || OBJECT_TYPE || ' ' || OWNER||'.'||OBJECT_NAME || ' compile;')),
'alter ' || OBJECT_TYPE || ' ' || OWNER||'.'||OBJECT_NAME || ' compile;' )
from dba_objects
where STATUS = 'INVALID'
and OBJECT_TYPE in ( 'PACKAGE BODY', 'PACKAGE', 'FUNCTION', 'PROCEDURE', 'TRIGGER',
'VIEW', 'MATERIALIZED VIEW','SYNONYM')
order by OWNER, OBJECT_TYPE, OBJECT_NAME;
spool off

set echo off
set head off
set feed off
set ver off
set pages 99
spool nome_sql.sql
select decode( OBJECT_TYPE, 'PACKAGE BODY','alter package ' || OWNER||'.'||OBJECT_NAME || ' compile body;', 'SYNONYM', (decode (OWNER, 'PUBLIC', 'alter public synonym '||OBJECT_NAME||' compile;',
'alter ' || OBJECT_TYPE || ' ' || OWNER||'.'||OBJECT_NAME || ' compile;')),
'alter ' || OBJECT_TYPE || ' ' || OWNER||'.'||OBJECT_NAME || ' compile;' )
from dba_objects
where STATUS = 'INVALID'
and OBJECT_TYPE in ( 'PACKAGE BODY', 'PACKAGE', 'FUNCTION', 'PROCEDURE', 'TRIGGER',
'VIEW', 'MATERIALIZED VIEW','SYNONYM')
order by OWNER, OBJECT_TYPE, OBJECT_NAME;
spool off

