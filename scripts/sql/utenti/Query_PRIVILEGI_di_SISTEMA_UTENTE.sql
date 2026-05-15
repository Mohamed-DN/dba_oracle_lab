-- Source: https://www.scriptdba.com/query-per-visualizzare-i-privilegi-di-sistema-assegnati-a-un-determinato-utente-o-un-ruolo/
-- Title: Query PRIVILEGI di SISTEMA UTENTE

set lines 200
col grantee for a20
col privilege for a70
select grantee,privilege from dba_sys_privs where grantee ='&USERID';

set lines 200
col grantee for a20
col privilege for a70
select grantee,privilege from dba_sys_privs where grantee ='&USERID';

