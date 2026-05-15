-- Source: https://www.scriptdba.com/query-per-creare-il-comando-da-lanciare-nel-caso-in-cui-dobbiamo-duplicare-i-privilegi-di-un-utente-e-assegnarli-ad-un-altro/
-- Title: Query PRIVILEGI UTENTE replicati

select 'grant ' ||granted_role || ' to &userid' ||
decode(admin_option, 'NO', ';', 'YES', ' with admin option;') "ROLE"
from dba_role_privs
where grantee = '&userid';

select 'grant ' ||granted_role || ' to &userid' ||
decode(admin_option, 'NO', ';', 'YES', ' with admin option;') "ROLE"
from dba_role_privs
where grantee = '&userid';

select 'grant '||privilege||' on '||owner||'.'||table_name||' to '||grantee||';' 
from dba_tab_privs where grantor = '&userid';

select 'grant '||privilege||' on '||owner||'.'||table_name||' to '||grantee||';' 
from dba_tab_privs where grantor = '&userid';

select 'grant ' || privilege || ' to &quserid' ||
decode(admin_option, 'NO', ';', 'YES', ' with admin option;') "PRIV"
from dba_sys_privs
where grantee = '&userid';

select 'grant ' || privilege || ' to &quserid' ||
decode(admin_option, 'NO', ';', 'YES', ' with admin option;') "PRIV"
from dba_sys_privs
where grantee = '&userid';

