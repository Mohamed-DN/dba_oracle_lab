-- |----------------------------------------------------------------------------|
-- | DATABASE : Oracle                                                          |
-- | FILE     : asm_diskgroups.sql                                              |
-- | CLASS    : Automatic Storage Management                                    |
-- | PURPOSE  : Provide a summary report of all disk groups.                    |
-- | NOTE     : As with any code, ensure to test this script in a development   |
-- |            environment before attempting to run it in production.          |
-- +----------------------------------------------------------------------------+

SET LINESIZE  145
SET PAGESIZE  9999
SET VERIFY    off

COLUMN group_name             FORMAT a20           HEAD 'Disk Group|Name'
COLUMN sector_size            FORMAT 99,999        HEAD 'Sector|Size'
COLUMN block_size             FORMAT 99,999        HEAD 'Block|Size'
COLUMN allocation_unit_size   FORMAT 999,999,999   HEAD 'Allocation|Unit Size'
COLUMN state                  FORMAT a11           HEAD 'State'
COLUMN type                   FORMAT a6            HEAD 'Type'
COLUMN total_mb               FORMAT 999,999,999   HEAD 'Total Size (MB)'
COLUMN used_mb                FORMAT 999,999,999   HEAD 'Used Size (MB)'
COLUMN pct_used               FORMAT 999.99        HEAD 'Pct. Used'

break on report on disk_group_name skip 1

compute sum label "Grand Total: " of total_mb used_mb on report

SELECT
    name                                     group_name
  , group_number                             group_number
  , sector_size                              sector_size
  , block_size                               block_size
  , allocation_unit_size                     allocation_unit_size
  , state                                    state
  , type                                     type
  , total_mb                                 total_mb
  , (total_mb - free_mb)                     used_mb
--  , ROUND((1- (free_mb / total_mb))*100, 2)  pct_used
FROM
    v$asm_diskgroup
where name like '&NAME'
ORDER BY
    name;

***********************************************

set lines 300
set pages 300
col fail_group for a15
break on report on diskgroup on fail_group skip 1
col diskgroup for a10
set lines 300

select dg.name              diskgroup,
       d.failgroup          fail_group,
       substr(d.name, 6,12) cell_disk,
       d.name               grid_disk,
       d.disk_number,
       d.STATE, d.MODE_STATUS, d.MOUNT_STATUS, d.HEADER_STATUS
from  v$asm_diskgroup dg,
      v$asm_disk d
where dg.group_number = d.group_number
--and   dg.name ='&DG'
order by 1,2,3,4;

