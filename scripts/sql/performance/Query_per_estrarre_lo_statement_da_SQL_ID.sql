-- Source: https://www.scriptdba.com/testo-statement-da-sql_id/
-- Title: Query per estrarre lo statement da SQL_ID

set lines 300 
pages 999 
select sql_text from v$sqlarea where sql_id = '&sql_id';

set lines 300 
pages 999 
select sql_text from v$sqlarea where sql_id = '&sql_id';

