-- Source: https://www.scriptdba.com/query-per-identificare-le-lun-con-i-rispettivi-diskgroup-e-size-e-lun-candidate/
-- Title: Query ASM LUN CANDIDATE

set lines 300
col DISK_FILE_PATH for a40
break on disk_group_name
SELECT NVL(a.name, '[CANDIDATE]') disk_group_name
, b.path disk_file_path
, b.total_mb total_mb
,b.OS_MB
FROM
v$asm_diskgroup a RIGHT OUTER JOIN v$asm_disk b USING (group_number)
ORDER BY
a.name;

set lines 300
col DISK_FILE_PATH for a40
break on disk_group_name
SELECT NVL(a.name, '[CANDIDATE]') disk_group_name
, b.path disk_file_path
, b.total_mb total_mb
,b.OS_MB
FROM
v$asm_diskgroup a RIGHT OUTER JOIN v$asm_disk b USING (group_number)
ORDER BY
a.name;

