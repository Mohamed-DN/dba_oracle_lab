-- Source: https://www.scriptdba.com/query-statement-da-un-sql_id/
-- Title: Query per estrarre statement da un SQL_ID successivo EXPLAIN PLAN FOR dello statement

set serveroutput on
DECLARE
 ddl CLOB;
BEGIN
 select a.sql_fulltext
INTO ddl 
from v$sql a
 where a.sql_id = '&sql_id' and
 rownum <2;
dbms_output.put_line(ddl);
END;
/

set serveroutput on
DECLARE
 ddl CLOB;
BEGIN
 select a.sql_fulltext
INTO ddl 
from v$sql a
 where a.sql_id = '&sql_id' and
 rownum <2;
dbms_output.put_line(ddl);
END;
/

@$ORACLE_HOME/rdbms/admin/utlxplp.sql

@$ORACLE_HOME/rdbms/admin/utlxplp.sql

