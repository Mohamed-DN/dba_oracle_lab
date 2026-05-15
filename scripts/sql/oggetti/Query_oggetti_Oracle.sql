-- Source: https://www.scriptdba.com/query-per-identificare-i-10-oggetti-piu-grandi/
-- Title: Query oggetti Oracle

set lines 400
col tablespace_name for a20
col partition_name for a16
col owner format a15
col segment_name format a32
col segment_type format a15
select tablespace_name, owner, segment_name, segment_type, partition_name, mb
from (
select tablespace_name, owner
, segment_name
, segment_type
, partition_name 
, bytes / 1024 / 1024 "MB"
from dba_segments
order by bytes desc)
where rownum < 10
/

set lines 400
col tablespace_name for a20
col partition_name for a16
col owner format a15
col segment_name format a32
col segment_type format a15
select tablespace_name, owner, segment_name, segment_type, partition_name, mb
from (
select tablespace_name, owner
, segment_name
, segment_type
, partition_name 
, bytes / 1024 / 1024 "MB"
from dba_segments
order by bytes desc)
where rownum < 10
/

