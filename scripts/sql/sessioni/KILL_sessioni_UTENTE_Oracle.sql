-- Source: https://www.scriptdba.com/query-per-eseguire-il-kill-di-tutte-le-sessioni-di-un-utente-su-un-database-single-instance/
-- Title: KILL sessioni UTENTE Oracle

select  'alter system kill session ''' || sid || ',' || serial# ||''' immediate;' 
from gv$session where USERNAME = '&USERNAME';

select  'alter system kill session ''' || sid || ',' || serial# ||''' immediate;' 
from gv$session where USERNAME = '&USERNAME';

alter user PIPPO account LOCK;

alter user PIPPO account LOCK;

