-- Source: https://www.scriptdba.com/query-per-vedere-le-dimensioni-di-un-lob-segment/
-- Title: Query LOB segment Oracle

set lines 300
set pages 30
col owner for a15
col segment_name for a25
col segment_type for a25 
col TABLE_NAME for a30
col TABLESPACE_NAME for a20
select l.owner, l.table_name,l.segment_name, s.bytes/1024/1024 MB_ATT
from dba_lobs l, dba_segments s
where l.SEGMENT_NAME=s.segment_name
and s.segment_name='&lob_segment'
group by l.owner,l.table_name,l.segment_name,s.bytes order by 3 desc;

set lines 300
set pages 30
col owner for a15
col segment_name for a25
col segment_type for a25 
col TABLE_NAME for a30
col TABLESPACE_NAME for a20
select l.owner, l.table_name,l.segment_name, s.bytes/1024/1024 MB_ATT
from dba_lobs l, dba_segments s
where l.SEGMENT_NAME=s.segment_name
and s.segment_name='&lob_segment'
group by l.owner,l.table_name,l.segment_name,s.bytes order by 3 desc;

