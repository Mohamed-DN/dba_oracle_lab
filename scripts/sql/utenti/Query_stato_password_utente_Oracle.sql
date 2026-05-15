-- Source: https://www.scriptdba.com/query-per-visualizzare-lo-stato-delle-password-degli-account-di-un-database-il-profilo-associato-e-i-ruoli-associati/
-- Title: Query stato password utente Oracle

set lines 300
set pages 999
col user for a15
col ACCOUNT_STATUS for a20
col PROFILE for a25
col granted_role for a35
select distinct username, account_status, profile, created, granted_role
from dba_users, dba_role_privs where username=grantee
order by 1;

set lines 300
set pages 999
col user for a15
col ACCOUNT_STATUS for a20
col PROFILE for a25
col granted_role for a35
select distinct username, account_status, profile, created, granted_role
from dba_users, dba_role_privs where username=grantee
order by 1;

