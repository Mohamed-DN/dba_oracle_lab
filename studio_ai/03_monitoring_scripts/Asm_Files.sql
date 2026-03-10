-- |----------------------------------------------------------------------------|
-- | DATABASE : Oracle                                                          |
-- | FILE     : asm_files.sql                                                   |
-- | CLASS    : Automatic Storage Management                                    |
-- | PURPOSE  : Provide a summary report of all files (and file metadata)       |
-- |            information for all ASM disk groups.                            |
-- | NOTE     : As with any code, ensure to test this script in a development   |
-- |            environment before attempting to run it in production.          |
-- +----------------------------------------------------------------------------+

SET LINESIZE  150
SET PAGESIZE  9999
SET VERIFY    off

COLUMN full_alias_path        FORMAT a63                  HEAD 'File Name'
COLUMN system_created         FORMAT a8                   HEAD 'System|Created?'
COLUMN bytes                  FORMAT 9,999,999,999,999    HEAD 'Bytes'
COLUMN space                  FORMAT 9,999,999,999,999    HEAD 'Space'
COLUMN type                   FORMAT a18                  HEAD 'File Type'
COLUMN redundancy             FORMAT a12                  HEAD 'Redundancy'
COLUMN striped                FORMAT a8                   HEAD 'Striped'
COLUMN creation_date          FORMAT a20                  HEAD 'Creation Date'
COLUMN disk_group_name        noprint

BREAK ON report ON disk_group_name SKIP 1

compute sum label ""              of bytes space on disk_group_name
compute sum label "Grand Total: " of bytes space on report

SELECT
    CONCAT('+' || disk_group_name, SYS_CONNECT_BY_PATH(alias_name, '/')) full_alias_path
  , bytes
  , space
  , NVL(LPAD(type, 18), '<DIRECTORY>')  type
  , creation_date
  , disk_group_name
  , LPAD(system_created, 4) system_created
FROM
    ( SELECT
          g.name               disk_group_name
        , a.parent_index       pindex
        , a.name               alias_name
        , a.reference_index    rindex
        , a.system_created     system_created
        , f.bytes              bytes
        , f.space              space
        , f.type               type
        , TO_CHAR(f.creation_date, 'DD-MON-YYYY HH24:MI:SS')  creation_date
      FROM
          v$asm_file f RIGHT OUTER JOIN v$asm_alias     a USING (group_number, file_number)
                                   JOIN v$asm_diskgroup g USING (group_number)
    )
WHERE type IS NOT NULL
START WITH (MOD(pindex, POWER(2, 24))) = 0
    CONNECT BY PRIOR rindex = pindex
/

-- ***********************************************************
--
--	File: asm_files.sql
--	Description: ASM file level IO statistics
--
-- *********************************************************


col rootname format a10 heading "Rootname|/DB Name " noprint
col diskgroup_name format a8 heading "Diskgroup|Name" noprint
col type format a10 heading "File|Type"
col filename format a23 heading "File|Name"
col allocated_mb format 999,999 heading "Allocated|MB"
col primary_region format a8 heading "Primary|Region"
col Striped format a6 heading "Stripe|Type"
col hot_ios1k format 99,999 heading "Hot IO|/1000"
col cold_ios1k format 99,999 heading "ColdIO|/1000"
set pagesize 10000
set lines 80
set echo on

SELECT  rootname,d.name diskgroup_name,f.TYPE, a.name filename,
       space / 1048576 allocated_mb, primary_region, striped,
       round((hot_reads + hot_writes)/1000,2) hot_ios1k,
       round((cold_reads + cold_writes)/1000,2) cold_ios1k
  FROM (SELECT CONNECT_BY_ISLEAF, group_number, file_number, name,
               CONNECT_BY_ROOT name rootname, reference_index,
               parent_index
          FROM v$asm_alias a
       CONNECT BY PRIOR reference_index = parent_index) a
  JOIN (SELECT DISTINCT name
         FROM v$asm_alias
             /* top 8 bits of the parent_index is the group_number, so
                the following selects aliases whose parent is the group
                itself - eg top level directories within the disk group*/
        WHERE parent_index = group_number * POWER(2, 24)) b
           ON (a.rootname = b.name)
  JOIN v$asm_file f
       ON (a.group_number = f.group_number
         AND a.file_number = f.file_number)
  JOIN v$asm_diskgroup d
       ON (f.group_number = d.group_number)
 WHERE a.CONNECT_BY_ISLEAF = 1
 ORDER BY (cold_reads + cold_writes + hot_reads + hot_writes) DESC;
