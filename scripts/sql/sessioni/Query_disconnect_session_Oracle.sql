-- Source: https://www.scriptdba.com/query-per-eseguire-la-disconnect-di-una-sessione-per-sid/
-- Title: Query disconnect session Oracle

select 'alter system disconnect session '''||SID||','||SERIAL#||''' immediate;'   from gv$session where SID=&sid;

select 'alter system disconnect session '''||SID||','||SERIAL#||''' immediate;'   from gv$session where SID=&sid;

select 'alter system disconnect session '''||SID||','||SERIAL#||'@'||INST_ID||' immediate;'   from gv$session where SID=&sid

