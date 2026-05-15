-- Source: https://www.scriptdba.com/query-per-vedere-i-dettagli-di-un-statement-da-sid/
-- Title: Query per vedere i dettagli di un statement da SID

set serveroutput on
DECLARE
 sid NUMBER;
 serial NUMBER;
 ddl CLOB;
BEGIN
 select b.sid, b.serial#, a.sql_text
INTO sid,serial,ddl
 from v$sql a, v$session b
where b.sid in (&seq_sid) and 
     (b.sql_address = a.address or 
      b.SQL_HASH_VALUE = a.hash_value);
dbms_output.put_line(ddl);
END;
/

set serveroutput on
DECLARE
 sid NUMBER;
 serial NUMBER;
 ddl CLOB;
BEGIN
 select b.sid, b.serial#, a.sql_text
INTO sid,serial,ddl
 from v$sql a, v$session b
where b.sid in (&seq_sid) and 
     (b.sql_address = a.address or 
      b.SQL_HASH_VALUE = a.hash_value);
dbms_output.put_line(ddl);
END;
/

