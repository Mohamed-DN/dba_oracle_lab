-- Source: https://www.scriptdba.com/query-per-individuare-i-ruoli-assegnati-a-un-determinato-utente-del-database-oracle-selezionando-grantee-ossia-lutente-che-riceve-il-ruolo/
-- Title: Query RUOLI UTENTE Oracle

set lines 200
col GRANTED_ROLE for a40
col grantee for a30
select grantee,granted_role from dba_role_privs where grantee='&USERID';

set lines 200
col GRANTED_ROLE for a40
col grantee for a30
select grantee,granted_role from dba_role_privs where grantee='&USERID';

