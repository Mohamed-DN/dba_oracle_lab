-- Source: https://www.scriptdba.com/query-per-vedere-le-dimensioni-dei-lob-di-una-tabella/
-- Title: Query LOB Oracle di una tabella

set lines 180
col owner for a30
col segment_name for a45
col table_name for a45
select l.owner, l.SEGMENT_NAME, l.table_name, s.bytes/1024/1024 MB_ATT 
from dba_lobs l, dba_segments s
where l.SEGMENT_NAME=s.segment_name
and l.table_name ='&table_name';

set lines 180
col owner for a30
col segment_name for a45
col table_name for a45
select l.owner, l.SEGMENT_NAME, l.table_name, s.bytes/1024/1024 MB_ATT 
from dba_lobs l, dba_segments s
where l.SEGMENT_NAME=s.segment_name
and l.table_name ='&table_name';

