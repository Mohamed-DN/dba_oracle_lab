-- Source: https://www.scriptdba.com/query-per-generare-la-ddl-di-creazione-utenza-ruoli-e-privilegi/
-- Title: DDL di creazione UTENZA, RUOLI e PRIVILEGI

--DDL Utente - grant

set head off
set pages 1000
set long 9999999
undef user
select dbms_metadata.get_ddl('USER',username) || '/' usercreate from dba_users where USERNAME = upper('&user')

--GRANT Utente
SELECT DBMS_METADATA.GET_GRANTED_DDL('ROLE_GRANT',upper('&&user')) FROM DUAL;
SELECT DBMS_METADATA.GET_GRANTED_DDL('SYSTEM_GRANT',upper('&&user')) FROM DUAL;
SELECT DBMS_METADATA.GET_GRANTED_DDL('OBJECT_GRANT',upper('&&user')) FROM DUAL;
SELECT DBMS_METADATA.GET_GRANTED_DDL('TABLESPACE_QUOTA',upper('&&user')) FROM DUAL;
/

--DDL Utente - grant

set head off
set pages 1000
set long 9999999
undef user
select dbms_metadata.get_ddl('USER',username) || '/' usercreate from dba_users where USERNAME = upper('&user')

--GRANT Utente
SELECT DBMS_METADATA.GET_GRANTED_DDL('ROLE_GRANT',upper('&&user')) FROM DUAL;

SELECT DBMS_METADATA.GET_GRANTED_DDL('SYSTEM_GRANT',upper('&&user')) FROM DUAL;

SELECT DBMS_METADATA.GET_GRANTED_DDL('OBJECT_GRANT',upper('&&user')) FROM DUAL;

SELECT DBMS_METADATA.GET_GRANTED_DDL('TABLESPACE_QUOTA',upper('&&user')) FROM DUAL;
/

