-- Source: https://www.scriptdba.com/query-per-visualizzare-le-informazioni-relative-agli-oggetti-con-meno-di-100-extent/
-- Title: Query oggetti Oracle con pochi EXTENT

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
where owner not in ('SYS','SYSTEM')
and (max_extents - extents) < 100
order by 2
/

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
where owner not in ('SYS','SYSTEM')
and (max_extents - extents) < 100
order by 2
/

