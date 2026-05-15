-- Source: https://www.scriptdba.com/query-per-eseguire-il-kill-di-tutte-le-sessioni-su-tutte-le-istanze-del-rac-da-una-sola-istanza/
-- Title: KILL sessioni UTENTE Oracle su RAC

select  'alter system kill session ''' || sid || ',' || serial# || ','||'@'|| INST_ID || ''' immediate;' 
from gv$session where USERNAME = '&USERNAME';

select  'alter system kill session ''' || sid || ',' || serial# || ','||'@'|| INST_ID || ''' immediate;' 
from gv$session where USERNAME = '&USERNAME';

