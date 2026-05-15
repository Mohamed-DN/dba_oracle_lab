-- Source: https://www.scriptdba.com/query-per-visualizzare-il-numero-e-la-dimensione-di-extent-di-un-oggetto/
-- Title: Query EXTENT Oracle numero e dimensione

set lines 200
col OWNER for a12
col SEGMENT_NAME for a32
col SEGMENT_TYPE for a16
select owner
, segment_name
, segment_type
, BYTES/1024/1024 MB_ATT
, NEXT_EXTENT/1024/1024 MB_NEXT
, extents
, max_extents
from dba_segments
where segment_name='&Object_name'
order by 2;

set lines 200
col OWNER for a12
col SEGMENT_NAME for a32
col SEGMENT_TYPE for a16
select owner
, segment_name
, segment_type
, BYTES/1024/1024 MB_ATT
, NEXT_EXTENT/1024/1024 MB_NEXT
, extents
, max_extents
from dba_segments
where segment_name='&Object_name'
order by 2;

