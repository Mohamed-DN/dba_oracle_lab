-- Source: https://www.scriptdba.com/query-per-vedere-la-produzione-di-archive-nellarco-di-un-mese/
-- Title: Query REDO LOG numero switch

grep "Checkpoint not complete"  alert_nomedb.log |wc -l

grep "Checkpoint not complete"  alert_nomedb.log |wc -l

select to_char(first_time,'YYYY-MM-DD HH24'),count(*) from v$log_history group by
to_char(first_time,'YYYY-MM-DD HH24') order by
to_char(first_time,'YYYY-MM-DD HH24') ;

select to_char(first_time,'YYYY-MM-DD HH24'),count(*) from v$log_history group by
to_char(first_time,'YYYY-MM-DD HH24') order by
to_char(first_time,'YYYY-MM-DD HH24') ;

