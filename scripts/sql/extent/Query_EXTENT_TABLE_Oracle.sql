-- Source: https://www.scriptdba.com/query-per-aumentare-il-numero-di-extent/
-- Title: Query EXTENT TABLE Oracle

set lines 300
select 'alter '||SEGMENT_TYPE||' '||OWNER||'.'||SEGMENT_NAME||' storage ( maxextents &MAX_EXTENTS);'
from dba_segments
where SEGMENT_NAME = '&NOME_SEG';

set lines 300
select 'alter '||SEGMENT_TYPE||' '||OWNER||'.'||SEGMENT_NAME||' storage ( maxextents &MAX_EXTENTS);'
from dba_segments
where SEGMENT_NAME = '&NOME_SEG';

