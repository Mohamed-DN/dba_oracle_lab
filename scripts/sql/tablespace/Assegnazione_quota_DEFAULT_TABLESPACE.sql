-- Source: https://www.scriptdba.com/query-per-creare-il-comando-per-assegnare-la-quota-di-un-utente-sul-proprio-default_tablespace/
-- Title: Assegnazione quota DEFAULT_TABLESPACE

select 'alter user &userid quota '||
decode(max_bytes, -1, 'unlimited',
ceil(max_bytes / 1024 / 1024) || 'M') ||
' on ' || tablespace_name || ';'
from dba_ts_quotas
where username = '&userid';

select 'alter user &userid quota '||
decode(max_bytes, -1, 'unlimited',
ceil(max_bytes / 1024 / 1024) || 'M') ||
' on ' || tablespace_name || ';'
from dba_ts_quotas
where username = '&userid';

