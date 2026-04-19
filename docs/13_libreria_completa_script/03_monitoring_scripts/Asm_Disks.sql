-- |----------------------------------------------------------------------------|
-- | DATABASE : Oracle                                                          |
-- | FILE     : asm_disks.sql                                                   |
-- | CLASS    : Automatic Storage Management                                    |
-- | PURPOSE  : Provide a summary report of all disks contained within all disk |
-- |            groups. This script is also responsible for queriing all        |
-- |            candidate disks - those that are not assigned to any disk       |
-- |            group.                                                          |
-- | NOTE     : As with any code, ensure to test this script in a development   |
-- |            environment before attempting to run it in production.          |
-- +----------------------------------------------------------------------------+

SET LINESIZE  145
SET PAGESIZE  9999
SET VERIFY    off

COLUMN disk_group_name        FORMAT a20           HEAD 'Disk Group Name'
COLUMN disk_file_path         FORMAT a30           HEAD 'Path'
COLUMN disk_file_name         FORMAT a20           HEAD 'File Name'
COLUMN disk_file_fail_group   FORMAT a20           HEAD 'Fail Group'
COLUMN total_mb               FORMAT 999,999,999   HEAD 'File Size (MB)'
COLUMN used_mb                FORMAT 999,999,999   HEAD 'Used Size (MB)'
COLUMN pct_used               FORMAT 999.99        HEAD 'Pct. Used'

break on report on disk_group_name skip 1

compute sum label ""              of total_mb used_mb on disk_group_name
compute sum label "Grand Total: " of total_mb used_mb on report

SELECT
    NVL(a.name, '[FORMER]')                          disk_group_name
  , b.path                                           disk_file_path
  , b.name                                           disk_file_name
  , b.failgroup                                      disk_file_fail_group
  , b.total_mb                                       total_mb
  , (b.total_mb - b.free_mb)                         used_mb
  , ROUND((1- (b.free_mb / b.total_mb))*100, 2)      pct_used
  , case
		when b.total_mb > 0 then ROUND((1- (b.free_mb / b.total_mb))*100, 2)
		else b.total_mb
	end pct_used
FROM
    v$asm_diskgroup a RIGHT OUTER JOIN v$asm_disk b USING (group_number)
WHERE a.name like '%'
ORDER BY
    a.name
/


****************************************************************************

SELECT GROUP_NUMBER, DISK_NUMBER, HEADER_STATUS, STATE, OS_MB, TOTAL_MB, FREE_MB, PATH
  FROM V$ASM_DISK WHERE GROUP_NUMBER = 1;

****************************************************************************

select GROUP_NUMBER,
			 DISK_NUMBER,
			 MOUNT_STATUS,
			 HEADER_STATUS,
			 MODE_STATUS,
			 STATE,
			 VOTING_FILE,
			 name,
			 path
  from v$asm_disk
 where name like 'DATA'
 order by HEADER_STATUS;

*****************************************************************************

set pages 40000 lines 1200
col PATH for a80
select DISK_NUMBER,MOUNT_STATUS,HEADER_STATUS,MODE_STATUS,STATE,PATH,OS_MB
FROM V$ASM_DISK
WHERE HEADER_STATUS LIKE '&STATUS'
order by DISK_NUMBER;

set pages 40000 lines 120
col PATH for a30
select DISK_NUMBER,MOUNT_STATUS,HEADER_STATUS,MODE_STATUS,STATE,PATH,OS_MB
FROM V$ASM_DISK
WHERE HEADER_STATUS NOT LIKE '&STATUS';

set pages 40000 lines 120
col PATH for a30
select DISK_NUMBER,MOUNT_STATUS,HEADER_STATUS,MODE_STATUS,STATE,PATH,OS_MB
FROM V$ASM_DISK
WHERE PATH LIKE '&PATH';

set pages 40000 lines 120
col PATH for a30
select DISK_NUMBER,MOUNT_STATUS,HEADER_STATUS,MODE_STATUS,STATE,PATH,OS_MB
FROM GV$ASM_DISK
WHERE HEADER_STATUS NOT LIKE '&STATUS';

set pages 40000 lines 120
col PATH for a30
select INST_ID,DISK_NUMBER,MOUNT_STATUS,HEADER_STATUS,MODE_STATUS,STATE,PATH,OS_MB
FROM GV$ASM_DISK
WHERE PATH LIKE '&PATH';
