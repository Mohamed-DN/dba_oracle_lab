-- Source: https://www.scriptdba.com/query-per-visualizzare-i-privilegi-sugli-specifici-oggetti-assegnati-a-un-determinato-utente/
-- Title: Query PRIVILEGI sugli OGGETTI UTENTE Oracle

set lines 200
col privilege for a20
col grantee for a20
col owner for a20
select owner OWN_TABLE,table_name,privilege, GRANTEE OWN_PRIVILEGE FROM DBA_TAB_PRIVS WHERE GRANTEE ='&USERID';

set lines 200
col privilege for a20
col grantee for a20
col owner for a20
select owner OWN_TABLE,table_name,privilege, GRANTEE OWN_PRIVILEGE FROM DBA_TAB_PRIVS WHERE GRANTEE ='&USERID';

